/*
    CymBuild Workflow Group Config Apply From Clean UAT v14

    Purpose
    -------
    Aligns active SCore.Groups rows from the cleaned UAT workflow source snapshot into
    the target database before workflow config alignment.

    v14 includes the group fixes from v6-v8 and aligns these SCore.Groups columns:
      - ID
      - RowStatus
      - Guid
      - DirectoryID
      - Code
      - Name

    Scope
    -----
    This is intentionally GROUP CONFIG ONLY:
      - SCore.Groups
      - SCore.DataObjects rows required for those groups

    It does NOT copy:
      - SCore.UserGroups
      - Users
      - Group memberships
      - ObjectSecurity
      - Wider permissions

    Safety
    ------
    - Idempotent.
    - Explicit columns only.
    - No SELECT *.
    - No deletes.
    - Blocks ID/GUID/Name/Code/DirectoryID conflicts rather than guessing.
    - Creates or repairs matching SCore.DataObjects rows for group config rows.
    - Does not alter protected sentinel ID = -1.

    Usage
    -----
    1. Run 01_UAT_Generate_Workflow_Config_Source_Block_v14.sql against cleaned UAT.
    2. Paste the generated source block below.
    3. Run this script against DEV.
    4. Rerun the workflow/group compare.
    5. Run workflow config apply after group alignment is clean.
*/

/* ===== SOURCE SNAPSHOT START - paste generated SqlText lines below this comment ===== */

/* ===== SOURCE SNAPSHOT END ===== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RunGuid uniqueidentifier = NEWID();
DECLARE @StartedOnUtc datetime2(7) = SYSUTCDATETIME();

DECLARE @DryRun bit = 0;
DECLARE @AllowCreateMissingGroups bit = 1;
DECLARE @AllowReactivateHiddenGroups bit = 1;
DECLARE @RequireSourceGroupIDAlignment bit = 1;

PRINT CONCAT(N'CymBuild workflow/group config dependency run v14: ', CONVERT(nvarchar(36), @RunGuid));

IF OBJECT_ID(N'SCore.Groups', N'U') IS NULL
BEGIN
    ;THROW 73301, N'SCore.Groups does not exist in this database.', 1;
END;

IF OBJECT_ID(N'SCore.DataObjects', N'U') IS NULL
BEGIN
    ;THROW 73302, N'SCore.DataObjects does not exist in this database.', 1;
END;

IF OBJECT_ID(N'SCore.EntityTypes', N'U') IS NULL
BEGIN
    ;THROW 73303, N'SCore.EntityTypes does not exist in this database.', 1;
END;

IF COL_LENGTH(N'SCore.Groups', N'ID') IS NULL
   OR COL_LENGTH(N'SCore.Groups', N'RowStatus') IS NULL
   OR COL_LENGTH(N'SCore.Groups', N'Guid') IS NULL
   OR COL_LENGTH(N'SCore.Groups', N'DirectoryID') IS NULL
   OR COL_LENGTH(N'SCore.Groups', N'Code') IS NULL
   OR COL_LENGTH(N'SCore.Groups', N'Name') IS NULL
BEGIN
    ;THROW 73304, N'SCore.Groups does not expose the expected ID, RowStatus, Guid, DirectoryID, Code and Name columns.', 1;
END;


DECLARE @GroupsDirectoryIDAllowsNull bit;
DECLARE @GroupsCodeAllowsNull bit;

SELECT
    @GroupsDirectoryIDAllowsNull = CONVERT(bit, c.is_nullable)
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'SCore.Groups')
  AND c.name = N'DirectoryID';

SELECT
    @GroupsCodeAllowsNull = CONVERT(bit, c.is_nullable)
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'SCore.Groups')
  AND c.name = N'Code';

IF @GroupsDirectoryIDAllowsNull IS NULL OR @GroupsCodeAllowsNull IS NULL
BEGIN
    ;THROW 73314, N'Could not resolve SCore.Groups DirectoryID/Code nullability.', 1;
END;

/*
    v8 note:
    Some source/UAT groups intentionally have NULL DirectoryID because they are internal CymBuild
    groups rather than directory-backed Entra/AD groups. In this DEV database DirectoryID may be
    NOT NULL, so NULL must be represented as an empty string on write. Validation treats NULL and
    empty string as equivalent for DirectoryID/Code alignment.
*/

/*
    If SCore.Groups has extra mandatory columns without defaults, this group config
    script cannot safely create rows. In that case use the wider onboarding/security process.
*/
IF EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    INNER JOIN sys.objects AS o
        ON o.object_id = c.object_id
    LEFT JOIN sys.default_constraints AS dc
        ON dc.parent_object_id = c.object_id
       AND dc.parent_column_id = c.column_id
    WHERE o.object_id = OBJECT_ID(N'SCore.Groups')
      AND c.is_nullable = 0
      AND c.is_identity = 0
      AND c.is_computed = 0
      AND dc.object_id IS NULL
      AND c.name NOT IN (N'ID', N'RowStatus', N'Guid', N'DirectoryID', N'Code', N'Name', N'RowVersion')
)
BEGIN
    SELECT
        c.name AS RequiredColumnWithoutDefault,
        TYPE_NAME(c.user_type_id) AS ColumnType,
        c.max_length,
        c.precision,
        c.scale
    FROM sys.columns AS c
    INNER JOIN sys.objects AS o
        ON o.object_id = c.object_id
    LEFT JOIN sys.default_constraints AS dc
        ON dc.parent_object_id = c.object_id
       AND dc.parent_column_id = c.column_id
    WHERE o.object_id = OBJECT_ID(N'SCore.Groups')
      AND c.is_nullable = 0
      AND c.is_identity = 0
      AND c.is_computed = 0
      AND dc.object_id IS NULL
      AND c.name NOT IN (N'ID', N'RowStatus', N'Guid', N'DirectoryID', N'Code', N'Name', N'RowVersion')
    ORDER BY
        c.column_id;

    ;THROW 73305, N'SCore.Groups has mandatory columns outside ID/RowStatus/Guid/DirectoryID/Code/Name. Use onboarding/security group deployment or extend this script with those explicit columns.', 1;
END;

DECLARE @GroupEntityTypeID int;

SELECT
    @GroupEntityTypeID = et.ID
FROM SCore.EntityTypes AS et
WHERE et.Guid = CONVERT(uniqueidentifier,N'39a06a5e-e869-46ab-9f2f-99d4c166ab33')
  AND et.RowStatus NOT IN (0,254);

IF @GroupEntityTypeID IS NULL
BEGIN
    SELECT
        @GroupEntityTypeID = et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.Name = N'Groups'
      AND et.RowStatus NOT IN (0,254);
END;

IF @GroupEntityTypeID IS NULL
BEGIN
    ;THROW 73306, N'Could not resolve SCore.EntityTypes row for Groups. Cannot insert SCore.Groups without SCore.DataObjects EntityTypeId.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM @SourceGroups AS sg
)
BEGIN
    ;THROW 73307, N'@SourceGroups is empty. Run/paste the v14 UAT source generator output before running this script.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceGroups AS sg
    WHERE sg.ID <> -1
      AND
      (
          sg.Guid IS NULL
          OR NULLIF(LTRIM(RTRIM(sg.Name)), N'') IS NULL
      )
)
BEGIN
    SELECT
        sg.ID AS SourceGroupID,
        sg.Guid AS SourceGroupGuid,
        sg.DirectoryID AS SourceGroupDirectoryID,
        sg.Code AS SourceGroupCode,
        sg.Name AS SourceGroupName
    FROM @SourceGroups AS sg
    WHERE sg.ID <> -1
      AND
      (
          sg.Guid IS NULL
          OR NULLIF(LTRIM(RTRIM(sg.Name)), N'') IS NULL
      )
    ORDER BY
        sg.ID;

    ;THROW 73308, N'UAT source contains active non-sentinel groups with missing Guid or Name.', 1;
END;

DECLARE @GroupsToAlign TABLE
(
    SourceGroupID int NOT NULL PRIMARY KEY,
    SourceGroupGuid uniqueidentifier NOT NULL,
    SourceGroupDirectoryID nvarchar(200) NULL,
    SourceGroupCode nvarchar(200) NULL,
    SourceGroupName nvarchar(200) NOT NULL,
    RequiredByWorkflowNotification bit NOT NULL
);

INSERT INTO @GroupsToAlign
(
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    RequiredByWorkflowNotification
)
SELECT
    sg.ID AS SourceGroupID,
    sg.Guid AS SourceGroupGuid,
    NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), sg.DirectoryID))), N'') AS SourceGroupDirectoryID,
    NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), sg.Code))), N'') AS SourceGroupCode,
    sg.Name AS SourceGroupName,
    sg.RequiredByWorkflowNotification
FROM @SourceGroups AS sg
WHERE sg.ID <> -1;

DECLARE @GroupConflicts TABLE
(
    ConflictType nvarchar(100) NOT NULL,
    SourceGroupID int NOT NULL,
    SourceGroupGuid uniqueidentifier NOT NULL,
    SourceGroupDirectoryID nvarchar(200) NULL,
    SourceGroupCode nvarchar(200) NULL,
    SourceGroupName nvarchar(200) NOT NULL,
    TargetGroupID int NULL,
    TargetGroupGuid uniqueidentifier NULL,
    TargetGroupDirectoryID nvarchar(200) NULL,
    TargetGroupCode nvarchar(200) NULL,
    TargetGroupName nvarchar(200) NULL,
    TargetRowStatus tinyint NULL
);

INSERT INTO @GroupConflicts
(
    ConflictType,
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    TargetGroupID,
    TargetGroupGuid,
    TargetGroupDirectoryID,
    TargetGroupCode,
    TargetGroupName,
    TargetRowStatus
)
SELECT
    N'Target ID occupied by a different group' AS ConflictType,
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    grp.ID,
    grp.Guid,
    CONVERT(nvarchar(200), grp.DirectoryID),
    CONVERT(nvarchar(200), grp.Code),
    grp.Name,
    grp.RowStatus
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON grp.ID = gta.SourceGroupID
WHERE grp.Guid IS NULL
   OR grp.Guid <> gta.SourceGroupGuid
   OR grp.Name IS NULL
   OR grp.Name <> gta.SourceGroupName;

INSERT INTO @GroupConflicts
(
    ConflictType,
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    TargetGroupID,
    TargetGroupGuid,
    TargetGroupDirectoryID,
    TargetGroupCode,
    TargetGroupName,
    TargetRowStatus
)
SELECT
    N'Target GUID exists with a different ID' AS ConflictType,
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    grp.ID,
    grp.Guid,
    CONVERT(nvarchar(200), grp.DirectoryID),
    CONVERT(nvarchar(200), grp.Code),
    grp.Name,
    grp.RowStatus
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON grp.Guid = gta.SourceGroupGuid
WHERE grp.ID <> gta.SourceGroupID;

INSERT INTO @GroupConflicts
(
    ConflictType,
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    TargetGroupID,
    TargetGroupGuid,
    TargetGroupDirectoryID,
    TargetGroupCode,
    TargetGroupName,
    TargetRowStatus
)
SELECT
    N'Target name exists with a different ID or GUID' AS ConflictType,
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    grp.ID,
    grp.Guid,
    CONVERT(nvarchar(200), grp.DirectoryID),
    CONVERT(nvarchar(200), grp.Code),
    grp.Name,
    grp.RowStatus
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON grp.Name = gta.SourceGroupName
WHERE grp.ID <> gta.SourceGroupID
   OR grp.Guid IS NULL
   OR grp.Guid <> gta.SourceGroupGuid;

INSERT INTO @GroupConflicts
(
    ConflictType,
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    TargetGroupID,
    TargetGroupGuid,
    TargetGroupDirectoryID,
    TargetGroupCode,
    TargetGroupName,
    TargetRowStatus
)
SELECT
    N'Target Code exists with a different ID' AS ConflictType,
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    grp.ID,
    grp.Guid,
    CONVERT(nvarchar(200), grp.DirectoryID),
    CONVERT(nvarchar(200), grp.Code),
    grp.Name,
    grp.RowStatus
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N'') = gta.SourceGroupCode
WHERE gta.SourceGroupCode IS NOT NULL
  AND grp.ID <> gta.SourceGroupID;

INSERT INTO @GroupConflicts
(
    ConflictType,
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    TargetGroupID,
    TargetGroupGuid,
    TargetGroupDirectoryID,
    TargetGroupCode,
    TargetGroupName,
    TargetRowStatus
)
SELECT
    N'Target DirectoryID exists with a different ID' AS ConflictType,
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    grp.ID,
    grp.Guid,
    CONVERT(nvarchar(200), grp.DirectoryID),
    CONVERT(nvarchar(200), grp.Code),
    grp.Name,
    grp.RowStatus
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N'') = gta.SourceGroupDirectoryID
WHERE gta.SourceGroupDirectoryID IS NOT NULL
  AND grp.ID <> gta.SourceGroupID;

IF @RequireSourceGroupIDAlignment = 1 AND EXISTS (SELECT 1 FROM @GroupConflicts)
BEGIN
    SELECT
        gc.ConflictType,
        gc.SourceGroupID,
        gc.SourceGroupGuid,
        gc.SourceGroupDirectoryID,
        gc.SourceGroupCode,
        gc.SourceGroupName,
        gc.TargetGroupID,
        gc.TargetGroupGuid,
        gc.TargetGroupDirectoryID,
        gc.TargetGroupCode,
        gc.TargetGroupName,
        gc.TargetRowStatus
    FROM @GroupConflicts AS gc
    ORDER BY
        gc.SourceGroupName,
        gc.ConflictType,
        gc.TargetGroupID;

    ;THROW 73309, N'Cannot align groups because target group ID/GUID/Name/Code/DirectoryID conflicts exist. Use onboarding/security cleanup first.', 1;
END;

IF OBJECT_ID(N'SCore.WorkflowConfigAlignBackup_Groups', N'U') IS NOT NULL
BEGIN
    DROP TABLE SCore.WorkflowConfigAlignBackup_Groups;
END;

CREATE TABLE SCore.WorkflowConfigAlignBackup_Groups
(
    RunGuid uniqueidentifier NOT NULL,
    BackedUpOnUtc datetime2(7) NOT NULL,
    BackupAction nvarchar(30) NOT NULL,
    ID int NOT NULL,
    RowStatus tinyint NULL,
    Guid uniqueidentifier NULL,
    DirectoryID nvarchar(200) NULL,
    Code nvarchar(200) NULL,
    Name nvarchar(200) NULL,
    CONSTRAINT PK_WorkflowConfigAlignBackup_Groups PRIMARY KEY (RunGuid, ID)
);

IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_Groups', N'DirectoryID') IS NULL
BEGIN
    ALTER TABLE SCore.WorkflowConfigAlignBackup_Groups
    ADD DirectoryID nvarchar(200) NULL;
END;

IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_Groups', N'Code') IS NULL
BEGIN
    ALTER TABLE SCore.WorkflowConfigAlignBackup_Groups
    ADD Code nvarchar(200) NULL;
END;

DECLARE @GroupsToInsert TABLE
(
    SourceGroupID int NOT NULL PRIMARY KEY,
    SourceGroupGuid uniqueidentifier NOT NULL,
    SourceGroupDirectoryID nvarchar(200) NULL,
    SourceGroupCode nvarchar(200) NULL,
    SourceGroupName nvarchar(200) NOT NULL,
    RequiredByWorkflowNotification bit NOT NULL
);

INSERT INTO @GroupsToInsert
(
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    RequiredByWorkflowNotification
)
SELECT
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    gta.RequiredByWorkflowNotification
FROM @GroupsToAlign AS gta
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.Groups AS grp
    WHERE grp.ID = gta.SourceGroupID
       OR grp.Guid = gta.SourceGroupGuid
       OR grp.Name = gta.SourceGroupName
       OR (gta.SourceGroupCode IS NOT NULL AND NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N'') = gta.SourceGroupCode)
       OR (gta.SourceGroupDirectoryID IS NOT NULL AND NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N'') = gta.SourceGroupDirectoryID)
);

DECLARE @GroupsToReactivate TABLE
(
    SourceGroupID int NOT NULL PRIMARY KEY,
    SourceGroupGuid uniqueidentifier NOT NULL,
    SourceGroupDirectoryID nvarchar(200) NULL,
    SourceGroupCode nvarchar(200) NULL,
    SourceGroupName nvarchar(200) NOT NULL,
    RequiredByWorkflowNotification bit NOT NULL
);

INSERT INTO @GroupsToReactivate
(
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    RequiredByWorkflowNotification
)
SELECT
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    gta.RequiredByWorkflowNotification
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON grp.ID = gta.SourceGroupID
   AND grp.Guid = gta.SourceGroupGuid
   AND grp.Name = gta.SourceGroupName
WHERE grp.RowStatus IN (0,254);

DECLARE @GroupsToMetadataUpdate TABLE
(
    SourceGroupID int NOT NULL PRIMARY KEY,
    SourceGroupGuid uniqueidentifier NOT NULL,
    SourceGroupDirectoryID nvarchar(200) NULL,
    SourceGroupCode nvarchar(200) NULL,
    SourceGroupName nvarchar(200) NOT NULL,
    RequiredByWorkflowNotification bit NOT NULL
);

INSERT INTO @GroupsToMetadataUpdate
(
    SourceGroupID,
    SourceGroupGuid,
    SourceGroupDirectoryID,
    SourceGroupCode,
    SourceGroupName,
    RequiredByWorkflowNotification
)
SELECT
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupDirectoryID,
    gta.SourceGroupCode,
    gta.SourceGroupName,
    gta.RequiredByWorkflowNotification
FROM @GroupsToAlign AS gta
INNER JOIN SCore.Groups AS grp
    ON grp.ID = gta.SourceGroupID
   AND grp.Guid = gta.SourceGroupGuid
   AND grp.Name = gta.SourceGroupName
WHERE grp.ID <> -1
  AND
  (
      grp.RowStatus IN (0,254)
      OR COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N''), N'<NULL>') <> COALESCE(gta.SourceGroupDirectoryID, N'<NULL>')
      OR COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N''), N'<NULL>') <> COALESCE(gta.SourceGroupCode, N'<NULL>')
  );

SELECT
    N'Missing group rows to insert' AS ResultSetName,
    gti.SourceGroupID,
    gti.SourceGroupGuid,
    gti.SourceGroupDirectoryID,
    gti.SourceGroupCode,
    gti.SourceGroupName,
    gti.RequiredByWorkflowNotification
FROM @GroupsToInsert AS gti
ORDER BY
    gti.SourceGroupID;

SELECT
    N'Hidden/deleted matching group rows to reactivate' AS ResultSetName,
    gtr.SourceGroupID,
    gtr.SourceGroupGuid,
    gtr.SourceGroupDirectoryID,
    gtr.SourceGroupCode,
    gtr.SourceGroupName,
    gtr.RequiredByWorkflowNotification
FROM @GroupsToReactivate AS gtr
ORDER BY
    gtr.SourceGroupID;

SELECT
    N'Existing group rows to metadata-align' AS ResultSetName,
    gtu.SourceGroupID,
    gtu.SourceGroupGuid,
    gtu.SourceGroupDirectoryID,
    gtu.SourceGroupCode,
    gtu.SourceGroupName,
    gtu.RequiredByWorkflowNotification
FROM @GroupsToMetadataUpdate AS gtu
ORDER BY
    gtu.SourceGroupID;

IF @AllowCreateMissingGroups = 0 AND EXISTS (SELECT 1 FROM @GroupsToInsert)
BEGIN
    ;THROW 73310, N'Missing UAT source groups exist and @AllowCreateMissingGroups is disabled.', 1;
END;

IF @AllowReactivateHiddenGroups = 0 AND EXISTS (SELECT 1 FROM @GroupsToReactivate)
BEGIN
    ;THROW 73311, N'Hidden/deleted matching UAT source groups exist and @AllowReactivateHiddenGroups is disabled.', 1;
END;

DECLARE @GroupsIDIsIdentity bit = CONVERT(bit, COLUMNPROPERTY(OBJECT_ID(N'SCore.Groups'), N'ID', N'IsIdentity'));

SELECT
    N'Source groups with NULL DirectoryID that will be written as empty string because target DirectoryID is NOT NULL' AS ResultSetName,
    gta.SourceGroupID,
    gta.SourceGroupGuid,
    gta.SourceGroupName,
    gta.SourceGroupCode
FROM @GroupsToAlign AS gta
WHERE @GroupsDirectoryIDAllowsNull = CONVERT(bit, 0)
  AND gta.SourceGroupDirectoryID IS NULL
ORDER BY
    gta.SourceGroupID;

DECLARE @IdentityInsertEnabled bit = CONVERT(bit, 0);

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO SCore.WorkflowConfigAlignBackup_Groups
    (
        RunGuid,
        BackedUpOnUtc,
        BackupAction,
        ID,
        RowStatus,
        Guid,
        DirectoryID,
        Code,
        Name
    )
    SELECT
        @RunGuid,
        @StartedOnUtc,
        N'UPDATE',
        grp.ID,
        grp.RowStatus,
        grp.Guid,
        CONVERT(nvarchar(200), grp.DirectoryID),
        CONVERT(nvarchar(200), grp.Code),
        grp.Name
    FROM SCore.Groups AS grp
    INNER JOIN @GroupsToMetadataUpdate AS gtu
        ON gtu.SourceGroupID = grp.ID
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SCore.WorkflowConfigAlignBackup_Groups AS existingBackup
        WHERE existingBackup.RunGuid = @RunGuid
          AND existingBackup.ID = grp.ID
    );

    INSERT INTO SCore.WorkflowConfigAlignBackup_Groups
    (
        RunGuid,
        BackedUpOnUtc,
        BackupAction,
        ID,
        RowStatus,
        Guid,
        DirectoryID,
        Code,
        Name
    )
    SELECT
        @RunGuid,
        @StartedOnUtc,
        N'INSERT',
        gti.SourceGroupID,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
    FROM @GroupsToInsert AS gti
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SCore.WorkflowConfigAlignBackup_Groups AS existingBackup
        WHERE existingBackup.RunGuid = @RunGuid
          AND existingBackup.ID = gti.SourceGroupID
    );

    IF @DryRun = 0
    BEGIN
        UPDATE grp
        SET
            RowStatus = CONVERT(tinyint, 1),
            Guid = gtu.SourceGroupGuid,
            DirectoryID =
                CASE
                    WHEN @GroupsDirectoryIDAllowsNull = CONVERT(bit, 1) THEN gtu.SourceGroupDirectoryID
                    ELSE COALESCE(gtu.SourceGroupDirectoryID, N'')
                END,
            Code =
                CASE
                    WHEN @GroupsCodeAllowsNull = CONVERT(bit, 1) THEN gtu.SourceGroupCode
                    ELSE COALESCE(gtu.SourceGroupCode, N'')
                END,
            Name = gtu.SourceGroupName
        FROM SCore.Groups AS grp
        INNER JOIN @GroupsToMetadataUpdate AS gtu
            ON gtu.SourceGroupID = grp.ID;
    END;

    IF @DryRun = 0 AND EXISTS (SELECT 1 FROM @GroupsToInsert)
    BEGIN
        IF @GroupsIDIsIdentity = 1
        BEGIN
            SET IDENTITY_INSERT SCore.Groups ON;
            SET @IdentityInsertEnabled = CONVERT(bit, 1);
        END;

        INSERT INTO SCore.Groups
        (
            ID,
            RowStatus,
            Guid,
            DirectoryID,
            Code,
            Name
        )
        SELECT
            gti.SourceGroupID,
            CONVERT(tinyint, 1) AS RowStatus,
            gti.SourceGroupGuid,
            CASE
                WHEN @GroupsDirectoryIDAllowsNull = CONVERT(bit, 1) THEN gti.SourceGroupDirectoryID
                ELSE COALESCE(gti.SourceGroupDirectoryID, N'')
            END AS DirectoryID,
            CASE
                WHEN @GroupsCodeAllowsNull = CONVERT(bit, 1) THEN gti.SourceGroupCode
                ELSE COALESCE(gti.SourceGroupCode, N'')
            END AS Code,
            gti.SourceGroupName
        FROM @GroupsToInsert AS gti
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.Groups AS grp
            WHERE grp.ID = gti.SourceGroupID
               OR grp.Guid = gti.SourceGroupGuid
               OR grp.Name = gti.SourceGroupName
               OR (gti.SourceGroupCode IS NOT NULL AND NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N'') = gti.SourceGroupCode)
               OR (gti.SourceGroupDirectoryID IS NOT NULL AND NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N'') = gti.SourceGroupDirectoryID)
        );

        IF @GroupsIDIsIdentity = 1
        BEGIN
            SET IDENTITY_INSERT SCore.Groups OFF;
            SET @IdentityInsertEnabled = CONVERT(bit, 0);
        END;
    END;

    IF @DryRun = 0
    BEGIN
        UPDATE dob
        SET
            RowStatus = CONVERT(tinyint, 1),
            EntityTypeId = @GroupEntityTypeID
        FROM SCore.DataObjects AS dob
        INNER JOIN @GroupsToAlign AS gta
            ON gta.SourceGroupGuid = dob.Guid
        WHERE dob.RowStatus IN (0,254)
           OR dob.EntityTypeId <> @GroupEntityTypeID;

        INSERT INTO SCore.DataObjects
        (
            Guid,
            RowStatus,
            EntityTypeId
        )
        SELECT
            gta.SourceGroupGuid,
            CONVERT(tinyint, 1) AS RowStatus,
            @GroupEntityTypeID AS EntityTypeId
        FROM @GroupsToAlign AS gta
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.DataObjects AS dob
            WHERE dob.Guid = gta.SourceGroupGuid
        );
    END;

    IF EXISTS
    (
        SELECT 1
        FROM @GroupsToAlign AS gta
        LEFT JOIN SCore.Groups AS grp
            ON grp.ID = gta.SourceGroupID
           AND grp.Guid = gta.SourceGroupGuid
           AND grp.Name = gta.SourceGroupName
           AND grp.RowStatus NOT IN (0,254)
           AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N''), N'<NULL>') = COALESCE(gta.SourceGroupDirectoryID, N'<NULL>')
           AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N''), N'<NULL>') = COALESCE(gta.SourceGroupCode, N'<NULL>')
        WHERE grp.ID IS NULL
    )
    BEGIN
        SELECT
            gta.SourceGroupID,
            gta.SourceGroupGuid,
            gta.SourceGroupDirectoryID,
            gta.SourceGroupCode,
            gta.SourceGroupName,
            grp.ID AS TargetGroupID,
            grp.Guid AS TargetGroupGuid,
            CONVERT(nvarchar(200), grp.DirectoryID) AS TargetGroupDirectoryID,
            CONVERT(nvarchar(200), grp.Code) AS TargetGroupCode,
            grp.Name AS TargetGroupName,
            grp.RowStatus AS TargetRowStatus
        FROM @GroupsToAlign AS gta
        LEFT JOIN SCore.Groups AS grp
            ON grp.ID = gta.SourceGroupID
            OR grp.Guid = gta.SourceGroupGuid
            OR grp.Name = gta.SourceGroupName
            OR (gta.SourceGroupCode IS NOT NULL AND NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N'') = gta.SourceGroupCode)
            OR (gta.SourceGroupDirectoryID IS NOT NULL AND NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N'') = gta.SourceGroupDirectoryID)
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.Groups AS exactGroup
            WHERE exactGroup.ID = gta.SourceGroupID
              AND exactGroup.Guid = gta.SourceGroupGuid
              AND exactGroup.Name = gta.SourceGroupName
              AND exactGroup.RowStatus NOT IN (0,254)
              AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), exactGroup.DirectoryID))), N''), N'<NULL>') = COALESCE(gta.SourceGroupDirectoryID, N'<NULL>')
              AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), exactGroup.Code))), N''), N'<NULL>') = COALESCE(gta.SourceGroupCode, N'<NULL>')
        )
        ORDER BY
            gta.SourceGroupID,
            gta.SourceGroupName;

        ;THROW 73312, N'Group config dependency apply did not produce exact active group alignment including DirectoryID and Code.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM @GroupsToAlign AS gta
        LEFT JOIN SCore.DataObjects AS dob
            ON dob.Guid = gta.SourceGroupGuid
           AND dob.EntityTypeId = @GroupEntityTypeID
           AND dob.RowStatus NOT IN (0,254)
        WHERE dob.Guid IS NULL
    )
    BEGIN
        SELECT
            gta.SourceGroupID,
            gta.SourceGroupGuid,
            gta.SourceGroupName,
            @GroupEntityTypeID AS ExpectedEntityTypeID
        FROM @GroupsToAlign AS gta
        LEFT JOIN SCore.DataObjects AS dob
            ON dob.Guid = gta.SourceGroupGuid
           AND dob.EntityTypeId = @GroupEntityTypeID
           AND dob.RowStatus NOT IN (0,254)
        WHERE dob.Guid IS NULL
        ORDER BY
            gta.SourceGroupID,
            gta.SourceGroupName;

        ;THROW 73313, N'SCore.DataObjects rows are missing or inactive for aligned UAT source groups.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @IdentityInsertEnabled = 1
    BEGIN
        SET IDENTITY_INSERT SCore.Groups OFF;
    END;

    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    ;THROW;
END CATCH;

SELECT
    @RunGuid AS RunGuid,
    @DryRun AS DryRun,
    (SELECT COUNT_BIG(1) FROM @GroupsToAlign) AS SourceGroupsAligned,
    (SELECT COUNT_BIG(1) FROM @GroupsToInsert) AS GroupsInserted,
    (SELECT COUNT_BIG(1) FROM @GroupsToReactivate) AS GroupsReactivated,
    (SELECT COUNT_BIG(1) FROM @GroupsToMetadataUpdate) AS GroupsMetadataUpdated,
    (SELECT COUNT_BIG(1) FROM @GroupsToAlign WHERE RequiredByWorkflowNotification = 1) AS WorkflowNotificationTargetGroups,
    (SELECT COUNT_BIG(1) FROM @GroupsToAlign WHERE RequiredByWorkflowNotification = 0) AS NonNotificationGroupsAligned;

PRINT N'Workflow/group config dependency apply v14 completed successfully.';
PRINT CONCAT(N'Rollback group dependency RunGuid: ', CONVERT(nvarchar(36), @RunGuid));
