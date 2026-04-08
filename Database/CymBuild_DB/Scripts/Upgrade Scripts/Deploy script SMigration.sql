/*
How to run it
____________________________________________________________________________
Step A — load from source

Run this in the target database we want to import into.

Use the source database name and the business unit group guid from UAT.
____________________________________________________________________________
DECLARE @RunGuid UNIQUEIDENTIFIER = NEWID();

EXEC SMigration.OnboardingStage_LoadFromSource
    @SourceDatabase = N'CymBuild_Dev',
    @BusinessUnitGroupGuid = '315CF5D4-37EB-4966-AB77-4CCAB627A613', -- example Fire Engineering
    @RunGuid = @RunGuid,
    @Notes = N'Initial onboarding promotion from UAT';

SELECT @RunGuid AS RunGuid;

____________________________________________________________________________

Step B — validate
____________________________________________________________________________
EXEC SMigration.OnboardingValidate
    @RunGuid = 'PUT-RUN-GUID-HERE';

SELECT *
FROM SMigration.Onboarding_ValidationIssues
WHERE RunGuid = 'PUT-RUN-GUID-HERE'
ORDER BY ID;
____________________________________________________________________________

Step C — import
____________________________________________________________________________
EXEC SMigration.OnboardingImport_Apply
    @RunGuid = 'PUT-RUN-GUID-HERE',
    @AllowWarnings = 1;

____________________________________________________________________________
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* =========================================================================================
   SMigration schema
   ========================================================================================= */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'SMigration')
BEGIN
    EXEC('CREATE SCHEMA SMigration AUTHORIZATION dbo;');
END
GO

/* =========================================================================================
   Optional run header table
   ========================================================================================= */
IF OBJECT_ID(N'SMigration.Onboarding_Run', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Run
    (
        RunGuid             UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT PK_SMigration_Onboarding_Run PRIMARY KEY,
        CreatedUtc          DATETIME2(3)     NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_CreatedUtc DEFAULT (SYSUTCDATETIME()),
        SourceDatabase      SYSNAME          NOT NULL,
        SourceBusinessUnitGroupGuid UNIQUEIDENTIFIER NULL,
        Notes               NVARCHAR(1000)   NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_Notes DEFAULT (N'')
    );
END
GO

/* =========================================================================================
   Validation / issue table
   ========================================================================================= */
IF OBJECT_ID(N'SMigration.Onboarding_ValidationIssues', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_ValidationIssues
    (
        ID                  BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SMigration_Onboarding_ValidationIssues PRIMARY KEY,
        RunGuid             UNIQUEIDENTIFIER     NOT NULL,
        EntityName          NVARCHAR(200)        NOT NULL,
        StageTable          NVARCHAR(200)        NOT NULL,
        StageGuid           UNIQUEIDENTIFIER     NULL,
        Severity            NVARCHAR(20)         NOT NULL,   -- Error / Warning / Info
        IssueCode           NVARCHAR(100)        NOT NULL,
        IssueMessage        NVARCHAR(2000)       NOT NULL,
        CreatedUtc          DATETIME2(3)         NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_ValidationIssues_CreatedUtc DEFAULT (SYSUTCDATETIME())
    );
END
GO

/* =========================================================================================
   Stage tables
   ========================================================================================= */
IF OBJECT_ID(N'SMigration.Onboarding_Groups', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Groups
    (
        RunGuid             UNIQUEIDENTIFIER NOT NULL,
        GroupGuid           UNIQUEIDENTIFIER NOT NULL,
        RowStatus           TINYINT          NOT NULL,
        DirectoryId         NVARCHAR(100)    NOT NULL,
        Code                NVARCHAR(30)     NOT NULL,
        Name                NVARCHAR(250)    NOT NULL,
        Source              NVARCHAR(250)    NOT NULL,
        IsBusinessUnitGroup BIT              NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Groups_IsBusinessUnitGroup DEFAULT (0),

        CONSTRAINT PK_SMigration_Onboarding_Groups
            PRIMARY KEY CLUSTERED (RunGuid, GroupGuid)
    );

    CREATE INDEX IX_SMigration_Onboarding_Groups_RunGuid
        ON SMigration.Onboarding_Groups (RunGuid);

    CREATE INDEX IX_SMigration_Onboarding_Groups_Code
        ON SMigration.Onboarding_Groups (RunGuid, Code);

    CREATE INDEX IX_SMigration_Onboarding_Groups_Name
        ON SMigration.Onboarding_Groups (RunGuid, Name);
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_Identities', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Identities
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        IdentityGuid            UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        FullName                NVARCHAR(250)    NOT NULL,
        EmailAddress            NVARCHAR(150)    NOT NULL,
        UserGuid                UNIQUEIDENTIFIER NOT NULL,
        JobTitle                NVARCHAR(50)     NOT NULL,
        OrganisationalUnitGuid  UNIQUEIDENTIFIER NOT NULL,
        IsActive                BIT              NOT NULL,
        ContactGuid             UNIQUEIDENTIFIER NOT NULL,
        BillableRate            DECIMAL(19,2)    NOT NULL,
        Signature               VARBINARY(MAX)   NOT NULL,

        CONSTRAINT PK_SMigration_Onboarding_Identities
            PRIMARY KEY CLUSTERED (RunGuid, IdentityGuid)
    );

    CREATE INDEX IX_SMigration_Onboarding_Identities_RunGuid
        ON SMigration.Onboarding_Identities (RunGuid);

    CREATE INDEX IX_SMigration_Onboarding_Identities_Email
        ON SMigration.Onboarding_Identities (RunGuid, EmailAddress);

    CREATE INDEX IX_SMigration_Onboarding_Identities_OU
        ON SMigration.Onboarding_Identities (RunGuid, OrganisationalUnitGuid);
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_UserGroups', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_UserGroups
    (
        RunGuid             UNIQUEIDENTIFIER NOT NULL,
        UserGroupGuid       UNIQUEIDENTIFIER NOT NULL,
        RowStatus           TINYINT          NOT NULL,
        IdentityGuid        UNIQUEIDENTIFIER NOT NULL,
        GroupGuid           UNIQUEIDENTIFIER NOT NULL,

        CONSTRAINT PK_SMigration_Onboarding_UserGroups
            PRIMARY KEY CLUSTERED (RunGuid, UserGroupGuid)
    );

    CREATE INDEX IX_SMigration_Onboarding_UserGroups_RunGuid
        ON SMigration.Onboarding_UserGroups (RunGuid);

    CREATE INDEX IX_SMigration_Onboarding_UserGroups_Identity_Group
        ON SMigration.Onboarding_UserGroups (RunGuid, IdentityGuid, GroupGuid);
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_WorkflowStatusNotificationGroups', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_WorkflowStatusNotificationGroups
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        WorkflowNotificationGroupGuid UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        WorkflowGuid            UNIQUEIDENTIFIER NOT NULL,
        WorkflowStatusGuid      UNIQUEIDENTIFIER NOT NULL,
        GroupGuid               UNIQUEIDENTIFIER NOT NULL,
        CanAction               BIT              NOT NULL,

        CONSTRAINT PK_SMigration_Onboarding_WorkflowStatusNotificationGroups
            PRIMARY KEY CLUSTERED (RunGuid, WorkflowNotificationGroupGuid)
    );

    CREATE INDEX IX_SMigration_Onboarding_WSNG_RunGuid
        ON SMigration.Onboarding_WorkflowStatusNotificationGroups (RunGuid);

    CREATE INDEX IX_SMigration_Onboarding_WSNG_Lookup
        ON SMigration.Onboarding_WorkflowStatusNotificationGroups
        (
            RunGuid,
            WorkflowGuid,
            WorkflowStatusGuid,
            GroupGuid
        );
END
GO

/* =========================================================================================
   Reset proc
   ========================================================================================= */
CREATE OR ALTER PROCEDURE SMigration.OnboardingStage_Reset
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM SMigration.Onboarding_ValidationIssues
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_WorkflowStatusNotificationGroups
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_UserGroups
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_Identities
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_Groups
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_Run
    WHERE RunGuid = @RunGuid;
END
GO

/* =========================================================================================
   Load from source database
   - Business-unit scoped by @BusinessUnitGroupGuid
   - Also brings any groups attached to the scoped identities
   - Also brings workflow notification groups for the groups in scope
   ========================================================================================= */
CREATE OR ALTER PROCEDURE SMigration.OnboardingStage_LoadFromSource
    @SourceDatabase SYSNAME,
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER,
    @RunGuid UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(1000) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    EXEC SMigration.OnboardingStage_Reset @RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_Run
    (
        RunGuid,
        SourceDatabase,
        SourceBusinessUnitGroupGuid,
        Notes
    )
    VALUES
    (
        @RunGuid,
        @SourceDatabase,
        @BusinessUnitGroupGuid,
        @Notes
    );

    DECLARE @sql NVARCHAR(MAX) = N'
    /* ============================================================
       Stage Groups
       - Business Unit group itself
       - Any group assigned to identities who are members of that BU
       ============================================================ */
    ;WITH BuMembers AS
    (
        SELECT DISTINCT ug.IdentityID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
            ON g.ID = ug.GroupID
        WHERE ug.RowStatus NOT IN (0,254)
          AND g.RowStatus  NOT IN (0,254)
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    RelevantGroups AS
    (
        SELECT g.Guid, g.RowStatus, g.DirectoryId, g.Code, g.Name, g.Source,
               CAST(CASE WHEN g.Guid = @BusinessUnitGroupGuid THEN 1 ELSE 0 END AS bit) AS IsBusinessUnitGroup
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        WHERE g.RowStatus NOT IN (0,254)
          AND g.Guid = @BusinessUnitGroupGuid

        UNION

        SELECT g.Guid, g.RowStatus, g.DirectoryId, g.Code, g.Name, g.Source,
               CAST(0 AS bit) AS IsBusinessUnitGroup
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
            ON ug.GroupID = g.ID
        INNER JOIN BuMembers bm
            ON bm.IdentityID = ug.IdentityID
        WHERE g.RowStatus  NOT IN (0,254)
          AND ug.RowStatus NOT IN (0,254)
    )
    INSERT INTO SMigration.Onboarding_Groups
    (
        RunGuid, GroupGuid, RowStatus, DirectoryId, Code, Name, Source, IsBusinessUnitGroup
    )
    SELECT DISTINCT
        @RunGuid, rg.Guid, rg.RowStatus, rg.DirectoryId, rg.Code, rg.Name, rg.Source, rg.IsBusinessUnitGroup
    FROM RelevantGroups rg;

    /* ============================================================
       Stage Identities
       Scoped to identities in the business unit group
       ============================================================ */
    INSERT INTO SMigration.Onboarding_Identities
    (
        RunGuid,
        IdentityGuid,
        RowStatus,
        FullName,
        EmailAddress,
        UserGuid,
        JobTitle,
        OrganisationalUnitGuid,
        IsActive,
        ContactGuid,
        BillableRate,
        Signature
    )
    SELECT DISTINCT
        @RunGuid,
        i.Guid,
        i.RowStatus,
        i.FullName,
        i.EmailAddress,
        i.UserGuid,
        i.JobTitle,
        ou.Guid,
        i.IsActive,
        c.Guid,
        i.BillableRate,
        i.Signature
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
        ON ug.IdentityID = i.ID
       AND ug.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        ON g.ID = ug.GroupID
       AND g.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
        ON ou.ID = i.OriganisationalUnitId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
        ON c.ID = i.ContactId
    WHERE i.RowStatus NOT IN (0,254)
      AND g.Guid = @BusinessUnitGroupGuid;

    /* ============================================================
       Stage UserGroups
       Only for staged identities and staged groups
       ============================================================ */
    INSERT INTO SMigration.Onboarding_UserGroups
    (
        RunGuid, UserGroupGuid, RowStatus, IdentityGuid, GroupGuid
    )
    SELECT DISTINCT
        @RunGuid,
        ug.Guid,
        ug.RowStatus,
        i.Guid,
        g.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
        ON i.ID = ug.IdentityID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        ON g.ID = ug.GroupID
    WHERE ug.RowStatus NOT IN (0,254)
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Identities si
          WHERE si.RunGuid = @RunGuid
            AND si.IdentityGuid = i.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Groups sg
          WHERE sg.RunGuid = @RunGuid
            AND sg.GroupGuid = g.Guid
      );

    /* ============================================================
       Stage WorkflowStatusNotificationGroups
       Only for staged groups
       ============================================================ */
    INSERT INTO SMigration.Onboarding_WorkflowStatusNotificationGroups
    (
        RunGuid,
        WorkflowNotificationGroupGuid,
        RowStatus,
        WorkflowGuid,
        WorkflowStatusGuid,
        GroupGuid,
        CanAction
    )
    SELECT DISTINCT
        @RunGuid,
        wng.Guid,
        wng.RowStatus,
        wf.Guid,
        wng.WorkflowStatusGuid,
        g.Guid,
        wng.CanAction
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups wng
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow wf
        ON wf.ID = wng.WorkflowID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        ON g.ID = wng.GroupID
    WHERE wng.RowStatus NOT IN (0,254)
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Groups sg
          WHERE sg.RunGuid = @RunGuid
            AND sg.GroupGuid = g.Guid
      );
    ';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    SELECT
        @RunGuid AS RunGuid,
        (SELECT COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid) AS GroupCount,
        (SELECT COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid) AS IdentityCount,
        (SELECT COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid) AS UserGroupCount,
        (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid) AS WorkflowNotificationGroupCount;
END
GO

/* =========================================================================================
   Validation proc
   ========================================================================================= */
CREATE OR ALTER PROCEDURE SMigration.OnboardingValidate
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM SMigration.Onboarding_ValidationIssues
    WHERE RunGuid = @RunGuid;

    /* Missing org unit for identities */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'Identity',
        N'SMigration.Onboarding_Identities',
        s.IdentityGuid,
        N'Error',
        N'MISSING_ORGUNIT',
        N'Identity references an OrganisationalUnit Guid that does not exist in target.'
    FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCore.OrganisationalUnits ou
        ON ou.Guid = s.OrganisationalUnitGuid
    WHERE s.RunGuid = @RunGuid
      AND ou.ID IS NULL;

    /* Missing contact for identities */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'Identity',
        N'SMigration.Onboarding_Identities',
        s.IdentityGuid,
        N'Error',
        N'MISSING_CONTACT',
        N'Identity references a Contact Guid that does not exist in target.'
    FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCrm.Contacts c
        ON c.Guid = s.ContactGuid
    WHERE s.RunGuid = @RunGuid
      AND c.ID IS NULL;

    /* Group name collision */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'Group',
        N'SMigration.Onboarding_Groups',
        s.GroupGuid,
        N'Warning',
        N'GROUP_NAME_GUID_MISMATCH',
        N'A target group exists with same Name but different Guid.'
    FROM SMigration.Onboarding_Groups s
    INNER JOIN SCore.Groups g
        ON g.Name = s.Name
       AND g.Guid <> s.GroupGuid
    WHERE s.RunGuid = @RunGuid;

    /* Identity email collision */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'Identity',
        N'SMigration.Onboarding_Identities',
        s.IdentityGuid,
        N'Warning',
        N'IDENTITY_EMAIL_GUID_MISMATCH',
        N'A target identity exists with same EmailAddress but different Guid.'
    FROM SMigration.Onboarding_Identities s
    INNER JOIN SCore.Identities i
        ON i.EmailAddress = s.EmailAddress
       AND i.Guid <> s.IdentityGuid
    WHERE s.RunGuid = @RunGuid;

    /* Missing usergroup identity */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'UserGroup',
        N'SMigration.Onboarding_UserGroups',
        s.UserGroupGuid,
        N'Error',
        N'MISSING_IDENTITY_FOR_USERGROUP',
        N'UserGroup references an Identity Guid that does not exist in target.'
    FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.Identities i
        ON i.Guid = s.IdentityGuid
    WHERE s.RunGuid = @RunGuid
      AND i.ID IS NULL;

    /* Missing usergroup group */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'UserGroup',
        N'SMigration.Onboarding_UserGroups',
        s.UserGroupGuid,
        N'Error',
        N'MISSING_GROUP_FOR_USERGROUP',
        N'UserGroup references a Group Guid that does not exist in target.'
    FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.Groups g
        ON g.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid
      AND g.ID IS NULL;

    /* Missing workflow for notification group */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'WorkflowStatusNotificationGroup',
        N'SMigration.Onboarding_WorkflowStatusNotificationGroups',
        s.WorkflowNotificationGroupGuid,
        N'Error',
        N'MISSING_WORKFLOW',
        N'WorkflowStatusNotificationGroup references a Workflow Guid that does not exist in target.'
    FROM SMigration.Onboarding_WorkflowStatusNotificationGroups s
    LEFT JOIN SCore.Workflow wf
        ON wf.Guid = s.WorkflowGuid
    WHERE s.RunGuid = @RunGuid
      AND wf.ID IS NULL;

    /* Missing group for notification group */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (
        RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
    )
    SELECT
        @RunGuid,
        N'WorkflowStatusNotificationGroup',
        N'SMigration.Onboarding_WorkflowStatusNotificationGroups',
        s.WorkflowNotificationGroupGuid,
        N'Error',
        N'MISSING_GROUP',
        N'WorkflowStatusNotificationGroup references a Group Guid that does not exist in target.'
    FROM SMigration.Onboarding_WorkflowStatusNotificationGroups s
    LEFT JOIN SCore.Groups g
        ON g.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid
      AND g.ID IS NULL;

    SELECT *
    FROM SMigration.Onboarding_ValidationIssues
    WHERE RunGuid = @RunGuid
    ORDER BY
        CASE Severity WHEN N'Error' THEN 1 WHEN N'Warning' THEN 2 ELSE 3 END,
        EntityName,
        IssueCode;
END
GO

/* =========================================================================================
   Import proc
   - Stops if validation errors exist
   - Updates existing rows by Guid
   - Inserts missing rows with source Guid preserved
   ========================================================================================= */
CREATE OR ALTER PROCEDURE SMigration.OnboardingImport_Apply
    @RunGuid UNIQUEIDENTIFIER,
    @AllowWarnings BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC SMigration.OnboardingValidate @RunGuid = @RunGuid;

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_ValidationIssues
        WHERE RunGuid = @RunGuid
          AND Severity = N'Error'
    )
    BEGIN
        ;THROW 60000, N'SMigration validation failed. Resolve errors in SMigration.Onboarding_ValidationIssues before import.', 1;
    END

    IF (@AllowWarnings = 0)
    AND EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_ValidationIssues
        WHERE RunGuid = @RunGuid
          AND Severity = N'Warning'
    )
    BEGIN
        ;THROW 60000, N'SMigration validation contains warnings and @AllowWarnings = 0.', 1;
    END

    BEGIN TRAN;

    /* ============================================================
       1. Groups
       ============================================================ */
    UPDATE tgt
        SET tgt.RowStatus   = src.RowStatus,
            tgt.DirectoryId = src.DirectoryId,
            tgt.Code        = src.Code,
            tgt.Name        = src.Name,
            tgt.Source      = src.Source
    FROM SCore.Groups tgt
    INNER JOIN SMigration.Onboarding_Groups src
        ON src.GroupGuid = tgt.Guid
    WHERE src.RunGuid = @RunGuid
      AND
      (
            tgt.RowStatus   <> src.RowStatus
         OR tgt.DirectoryId <> src.DirectoryId
         OR tgt.Code        <> src.Code
         OR tgt.Name        <> src.Name
         OR tgt.Source      <> src.Source
      );

    DECLARE @Guid UNIQUEIDENTIFIER, @IsInsert BIT;

    DECLARE cur_groups CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.GroupGuid
        FROM SMigration.Onboarding_Groups src
        LEFT JOIN SCore.Groups tgt
            ON tgt.Guid = src.GroupGuid
        WHERE src.RunGuid = @RunGuid
          AND tgt.ID IS NULL;

    OPEN cur_groups;
    FETCH NEXT FROM cur_groups INTO @Guid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'Groups',
            @IsInsert = @IsInsert OUTPUT;

        INSERT INTO SCore.Groups
        (
            RowStatus,
            Guid,
            DirectoryId,
            Code,
            Name,
            Source
        )
        SELECT
            src.RowStatus,
            src.GroupGuid,
            src.DirectoryId,
            src.Code,
            src.Name,
            src.Source
        FROM SMigration.Onboarding_Groups src
        WHERE src.RunGuid = @RunGuid
          AND src.GroupGuid = @Guid;

        FETCH NEXT FROM cur_groups INTO @Guid;
    END

    CLOSE cur_groups;
    DEALLOCATE cur_groups;

    /* ============================================================
       2. Identities
       ============================================================ */
    UPDATE tgt
        SET tgt.RowStatus            = src.RowStatus,
            tgt.FullName             = src.FullName,
            tgt.EmailAddress         = src.EmailAddress,
            tgt.UserGuid             = src.UserGuid,
            tgt.JobTitle             = src.JobTitle,
            tgt.OriganisationalUnitId= ou.ID,
            tgt.IsActive             = src.IsActive,
            tgt.ContactId            = c.ID,
            tgt.BillableRate         = src.BillableRate,
            tgt.Signature            = src.Signature
    FROM SCore.Identities tgt
    INNER JOIN SMigration.Onboarding_Identities src
        ON src.IdentityGuid = tgt.Guid
    INNER JOIN SCore.OrganisationalUnits ou
        ON ou.Guid = src.OrganisationalUnitGuid
    INNER JOIN SCrm.Contacts c
        ON c.Guid = src.ContactGuid
    WHERE src.RunGuid = @RunGuid
      AND
      (
            tgt.RowStatus             <> src.RowStatus
         OR tgt.FullName              <> src.FullName
         OR tgt.EmailAddress          <> src.EmailAddress
         OR tgt.UserGuid              <> src.UserGuid
         OR tgt.JobTitle              <> src.JobTitle
         OR tgt.OriganisationalUnitId <> ou.ID
         OR tgt.IsActive              <> src.IsActive
         OR tgt.ContactId             <> c.ID
         OR tgt.BillableRate          <> src.BillableRate
         OR ISNULL(DATALENGTH(tgt.Signature),0) <> ISNULL(DATALENGTH(src.Signature),0)
         OR ISNULL(CONVERT(VARBINARY(MAX), tgt.Signature), 0x) <> ISNULL(CONVERT(VARBINARY(MAX), src.Signature), 0x)
      );

    DECLARE cur_identities CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.IdentityGuid
        FROM SMigration.Onboarding_Identities src
        LEFT JOIN SCore.Identities tgt
            ON tgt.Guid = src.IdentityGuid
        WHERE src.RunGuid = @RunGuid
          AND tgt.ID IS NULL;

    OPEN cur_identities;
    FETCH NEXT FROM cur_identities INTO @Guid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'Identities',
            @IsInsert = @IsInsert OUTPUT;

        INSERT INTO SCore.Identities
        (
            RowStatus,
            Guid,
            FullName,
            EmailAddress,
            UserGuid,
            JobTitle,
            OriganisationalUnitId,
            IsActive,
            ContactId,
            BillableRate,
            Signature
        )
        SELECT
            src.RowStatus,
            src.IdentityGuid,
            src.FullName,
            src.EmailAddress,
            src.UserGuid,
            src.JobTitle,
            ou.ID,
            src.IsActive,
            c.ID,
            src.BillableRate,
            src.Signature
        FROM SMigration.Onboarding_Identities src
        INNER JOIN SCore.OrganisationalUnits ou
            ON ou.Guid = src.OrganisationalUnitGuid
        INNER JOIN SCrm.Contacts c
            ON c.Guid = src.ContactGuid
        WHERE src.RunGuid = @RunGuid
          AND src.IdentityGuid = @Guid;

        FETCH NEXT FROM cur_identities INTO @Guid;
    END

    CLOSE cur_identities;
    DEALLOCATE cur_identities;

    /* ============================================================
       3. UserGroups
       ============================================================ */
    UPDATE tgt
        SET tgt.RowStatus = src.RowStatus,
            tgt.IdentityID = i.ID,
            tgt.GroupID = g.ID
    FROM SCore.UserGroups tgt
    INNER JOIN SMigration.Onboarding_UserGroups src
        ON src.UserGroupGuid = tgt.Guid
    INNER JOIN SCore.Identities i
        ON i.Guid = src.IdentityGuid
    INNER JOIN SCore.Groups g
        ON g.Guid = src.GroupGuid
    WHERE src.RunGuid = @RunGuid
      AND
      (
            tgt.RowStatus  <> src.RowStatus
         OR tgt.IdentityID <> i.ID
         OR tgt.GroupID    <> g.ID
      );

    DECLARE cur_usergroups CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.UserGroupGuid
        FROM SMigration.Onboarding_UserGroups src
        LEFT JOIN SCore.UserGroups tgt
            ON tgt.Guid = src.UserGroupGuid
        WHERE src.RunGuid = @RunGuid
          AND tgt.ID IS NULL;

    OPEN cur_usergroups;
    FETCH NEXT FROM cur_usergroups INTO @Guid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'UserGroups',
            @IsInsert = @IsInsert OUTPUT;

        INSERT INTO SCore.UserGroups
        (
            Guid,
            RowStatus,
            IdentityID,
            GroupID
        )
        SELECT
            src.UserGroupGuid,
            src.RowStatus,
            i.ID,
            g.ID
        FROM SMigration.Onboarding_UserGroups src
        INNER JOIN SCore.Identities i
            ON i.Guid = src.IdentityGuid
        INNER JOIN SCore.Groups g
            ON g.Guid = src.GroupGuid
        WHERE src.RunGuid = @RunGuid
          AND src.UserGroupGuid = @Guid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.UserGroups x
              WHERE x.RowStatus NOT IN (0,254)
                AND x.IdentityID = i.ID
                AND x.GroupID = g.ID
          );

        FETCH NEXT FROM cur_usergroups INTO @Guid;
    END

    CLOSE cur_usergroups;
    DEALLOCATE cur_usergroups;

    /* ============================================================
       4. WorkflowStatusNotificationGroups
       ============================================================ */
    UPDATE tgt
        SET tgt.RowStatus          = src.RowStatus,
            tgt.WorkflowID         = wf.ID,
            tgt.WorkflowStatusGuid = src.WorkflowStatusGuid,
            tgt.GroupID            = g.ID,
            tgt.CanAction          = src.CanAction
    FROM SCore.WorkflowStatusNotificationGroups tgt
    INNER JOIN SMigration.Onboarding_WorkflowStatusNotificationGroups src
        ON src.WorkflowNotificationGroupGuid = tgt.Guid
    INNER JOIN SCore.Workflow wf
        ON wf.Guid = src.WorkflowGuid
    INNER JOIN SCore.Groups g
        ON g.Guid = src.GroupGuid
    WHERE src.RunGuid = @RunGuid
      AND
      (
            tgt.RowStatus          <> src.RowStatus
         OR tgt.WorkflowID         <> wf.ID
         OR tgt.WorkflowStatusGuid <> src.WorkflowStatusGuid
         OR tgt.GroupID            <> g.ID
         OR tgt.CanAction          <> src.CanAction
      );

    DECLARE cur_wsng CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.WorkflowNotificationGroupGuid
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups src
        LEFT JOIN SCore.WorkflowStatusNotificationGroups tgt
            ON tgt.Guid = src.WorkflowNotificationGroupGuid
        WHERE src.RunGuid = @RunGuid
          AND tgt.ID IS NULL;

    OPEN cur_wsng;
    FETCH NEXT FROM cur_wsng INTO @Guid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'WorkflowStatusNotificationGroups',
            @IsInsert = @IsInsert OUTPUT;

        INSERT INTO SCore.WorkflowStatusNotificationGroups
        (
            RowStatus,
            Guid,
            WorkflowID,
            WorkflowStatusGuid,
            GroupID,
            CanAction
        )
        SELECT
            src.RowStatus,
            src.WorkflowNotificationGroupGuid,
            wf.ID,
            src.WorkflowStatusGuid,
            g.ID,
            src.CanAction
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups src
        INNER JOIN SCore.Workflow wf
            ON wf.Guid = src.WorkflowGuid
        INNER JOIN SCore.Groups g
            ON g.Guid = src.GroupGuid
        WHERE src.RunGuid = @RunGuid
          AND src.WorkflowNotificationGroupGuid = @Guid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.WorkflowStatusNotificationGroups x
              WHERE x.RowStatus NOT IN (0,254)
                AND x.WorkflowID = wf.ID
                AND x.WorkflowStatusGuid = src.WorkflowStatusGuid
                AND x.GroupID = g.ID
          );

        FETCH NEXT FROM cur_wsng INTO @Guid;
    END

    CLOSE cur_wsng;
    DEALLOCATE cur_wsng;

    COMMIT TRAN;

    SELECT
        @RunGuid AS RunGuid,
        N'Import complete' AS Status;
END
GO