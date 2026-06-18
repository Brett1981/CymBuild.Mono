/*
    CymBuild Workflow Organisational Unit Dependency Apply v14

    Purpose
    -------
    Aligns SCore.OrganisationalUnits rows required by active cleaned-UAT workflow config into DEV.

    v14 fix
    -------
    v14 intentionally exported only ID/RowStatus/Guid/Name and correctly blocked when DEV
    required additional non-default columns. v14 exports and applies the full required OU
    config shape used by CymBuild:
      - ParentID, AddressId, ContactId, OfficialAddressId, OfficialContactId
      - OrgNode, DepartmentPrefix, CostCentreCode, DefaultSecurityGroupId, QuoteThreshold

    Scope
    -----
    Applies only:
      - SCore.OrganisationalUnits rows required by active workflow config, including ancestors
      - Matching SCore.DataObjects rows for those OrganisationalUnits

    It does NOT copy users, memberships, ObjectSecurity or runtime workflow history.

    Run order note
    --------------
    Run the v14 group alignment script before this OU script, because OU.DefaultSecurityGroupId
    has a foreign key to SCore.Groups.ID.
*/

/* ===== SOURCE SNAPSHOT START - paste generated v14 SqlText lines below this comment ===== */

/* ===== SOURCE SNAPSHOT END ===== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RunGuid uniqueidentifier = NEWID();
DECLARE @StartedOnUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @DryRun bit = 0;
DECLARE @TargetObjectId int = OBJECT_ID(N'SCore.OrganisationalUnits', N'U');
DECLARE @OuIDIsIdentity bit;
DECLARE @EntityType_OrganisationalUnit int;

PRINT CONCAT(N'CymBuild workflow OrganisationalUnit dependency run v14: ', CONVERT(nvarchar(36), @RunGuid));

IF @TargetObjectId IS NULL
BEGIN
    THROW 73300, N'SCore.OrganisationalUnits table was not found in the target database.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'ID')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'RowStatus')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'Guid')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'Name')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'ParentID')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'AddressId')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'ContactId')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'OfficialAddressId')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'OfficialContactId')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'OrgNode')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'DepartmentPrefix')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'CostCentreCode')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'DefaultSecurityGroupId')
   OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @TargetObjectId AND name = N'QuoteThreshold')
BEGIN
    THROW 73301, N'SCore.OrganisationalUnits does not contain the expected v14 columns.', 1;
END;

IF EXISTS (SELECT 1 FROM @SourceOrganisationalUnits AS sou GROUP BY sou.ID HAVING COUNT_BIG(1) > 1)
BEGIN
    THROW 73303, N'Source OrganisationalUnit snapshot contains duplicate IDs.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1 AND sou.Guid IS NOT NULL
    GROUP BY sou.Guid
    HAVING COUNT_BIG(1) > 1
)
BEGIN
    THROW 73304, N'Source OrganisationalUnit snapshot contains duplicate GUIDs.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1
      AND EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS targetOu
          WHERE targetOu.ID = sou.ID
            AND targetOu.Guid <> sou.Guid
      )
)
BEGIN
    SELECT
        sou.ID AS SourceOrganisationalUnitID,
        sou.Guid AS SourceOrganisationalUnitGuid,
        sou.Name AS SourceOrganisationalUnitName,
        targetOu.ID AS TargetOrganisationalUnitID,
        targetOu.Guid AS TargetOrganisationalUnitGuid,
        targetOu.Name AS TargetOrganisationalUnitName,
        targetOu.RowStatus AS TargetRowStatus
    FROM @SourceOrganisationalUnits AS sou
    INNER JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = sou.ID
    WHERE sou.ID <> -1 AND targetOu.Guid <> sou.Guid
    ORDER BY sou.ID;

    THROW 73305, N'An OrganisationalUnit ID exists in target with a different GUID. Use onboarding/security master alignment before applying.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1 AND sou.Guid IS NOT NULL
      AND EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS targetOu
          WHERE targetOu.Guid = sou.Guid
            AND targetOu.ID <> sou.ID
      )
)
BEGIN
    SELECT
        sou.ID AS SourceOrganisationalUnitID,
        sou.Guid AS SourceOrganisationalUnitGuid,
        sou.Name AS SourceOrganisationalUnitName,
        targetOu.ID AS TargetOrganisationalUnitID,
        targetOu.Guid AS TargetOrganisationalUnitGuid,
        targetOu.Name AS TargetOrganisationalUnitName,
        targetOu.RowStatus AS TargetRowStatus
    FROM @SourceOrganisationalUnits AS sou
    INNER JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.Guid = sou.Guid
    WHERE sou.ID <> -1 AND targetOu.ID <> sou.ID
    ORDER BY sou.ID;

    THROW 73306, N'An OrganisationalUnit GUID exists in target under a different ID. Use onboarding/security master alignment before applying.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1
      AND sou.ParentID <> sou.ID
      AND sou.ParentID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM @SourceOrganisationalUnits AS parentSource WHERE parentSource.ID = sou.ParentID)
      AND NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits AS parentTarget WHERE parentTarget.ID = sou.ParentID)
)
BEGIN
    SELECT sou.ID, sou.Name, sou.ParentID AS MissingParentID
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1
      AND sou.ParentID <> sou.ID
      AND sou.ParentID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM @SourceOrganisationalUnits AS parentSource WHERE parentSource.ID = sou.ParentID)
      AND NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits AS parentTarget WHERE parentTarget.ID = sou.ParentID)
    ORDER BY sou.ID;

    THROW 73310, N'Source OrganisationalUnit snapshot does not include all required parent OrganisationalUnits.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1
      AND NOT EXISTS
      (
          SELECT 1
          FROM SCore.Groups AS grp
          WHERE grp.ID = sou.DefaultSecurityGroupId
            AND grp.RowStatus NOT IN (0,254)
      )
)
BEGIN
    SELECT sou.ID, sou.Name, sou.DefaultSecurityGroupId AS MissingDefaultSecurityGroupId
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1
      AND NOT EXISTS
      (
          SELECT 1
          FROM SCore.Groups AS grp
          WHERE grp.ID = sou.DefaultSecurityGroupId
            AND grp.RowStatus NOT IN (0,254)
      )
    ORDER BY sou.ID;

    THROW 73311, N'One or more OrganisationalUnits reference a DefaultSecurityGroupId that does not exist in target. Run group alignment first.', 1;
END;

SELECT TOP (1) @EntityType_OrganisationalUnit = dob.EntityTypeId
FROM SCore.OrganisationalUnits AS ou
INNER JOIN SCore.DataObjects AS dob ON dob.Guid = ou.Guid AND dob.RowStatus NOT IN (0,254)
WHERE ou.ID <> -1 AND ou.RowStatus NOT IN (0,254)
ORDER BY CASE WHEN ou.ID IN (3,16,18,20) THEN 0 ELSE 1 END, ou.ID;

IF @EntityType_OrganisationalUnit IS NULL
BEGIN
    SELECT ou.ID, ou.Guid, ou.Name, ou.RowStatus
    FROM SCore.OrganisationalUnits AS ou
    WHERE ou.RowStatus NOT IN (0,254)
    ORDER BY ou.ID;

    THROW 73307, N'Could not resolve OrganisationalUnit EntityTypeId from existing SCore.DataObjects rows.', 1;
END;

SET @OuIDIsIdentity = CONVERT(bit, COLUMNPROPERTY(@TargetObjectId, N'ID', N'IsIdentity'));

IF OBJECT_ID(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits
    (
        RunGuid uniqueidentifier NOT NULL,
        BackedUpOnUtc datetime2(7) NOT NULL,
        BackupAction nvarchar(30) NOT NULL,
        ID int NOT NULL,
        RowStatus tinyint NULL,
        Guid uniqueidentifier NULL,
        Name nvarchar(250) NULL,
        ParentID int NULL,
        AddressId int NULL,
        ContactId int NULL,
        OfficialAddressId int NULL,
        OfficialContactId int NULL,
        OrgNodePath nvarchar(4000) NULL,
        DepartmentPrefix nvarchar(10) NULL,
        CostCentreCode nvarchar(50) NULL,
        DefaultSecurityGroupId int NULL,
        QuoteThreshold decimal(19,2) NULL,
        CONSTRAINT PK_WorkflowConfigAlignBackup_OrganisationalUnits PRIMARY KEY (RunGuid, ID)
    );
END;
ELSE
BEGIN
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'ParentID') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD ParentID int NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'AddressId') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD AddressId int NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'ContactId') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD ContactId int NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'OfficialAddressId') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD OfficialAddressId int NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'OfficialContactId') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD OfficialContactId int NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'OrgNodePath') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD OrgNodePath nvarchar(4000) NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'DepartmentPrefix') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD DepartmentPrefix nvarchar(10) NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'CostCentreCode') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD CostCentreCode nvarchar(50) NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'DefaultSecurityGroupId') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD DefaultSecurityGroupId int NULL;
    IF COL_LENGTH(N'SCore.WorkflowConfigAlignBackup_OrganisationalUnits', N'QuoteThreshold') IS NULL ALTER TABLE SCore.WorkflowConfigAlignBackup_OrganisationalUnits ADD QuoteThreshold decimal(19,2) NULL;
END;

BEGIN TRANSACTION;

INSERT INTO SCore.WorkflowConfigAlignBackup_OrganisationalUnits
(
    RunGuid, BackedUpOnUtc, BackupAction, ID, RowStatus, Guid, Name, ParentID, AddressId, ContactId,
    OfficialAddressId, OfficialContactId, OrgNodePath, DepartmentPrefix, CostCentreCode, DefaultSecurityGroupId, QuoteThreshold
)
SELECT
    @RunGuid, @StartedOnUtc,
    CASE WHEN targetOu.ID IS NULL THEN N'MissingBeforeApply' ELSE N'BeforeApply' END,
    sou.ID, targetOu.RowStatus, targetOu.Guid, targetOu.Name, targetOu.ParentID, targetOu.AddressId, targetOu.ContactId,
    targetOu.OfficialAddressId, targetOu.OfficialContactId,
    CASE WHEN targetOu.OrgNode IS NULL THEN NULL ELSE CONVERT(nvarchar(4000), targetOu.OrgNode.ToString()) END,
    targetOu.DepartmentPrefix, targetOu.CostCentreCode, targetOu.DefaultSecurityGroupId, targetOu.QuoteThreshold
FROM @SourceOrganisationalUnits AS sou
LEFT JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = sou.ID
WHERE sou.ID <> -1;

IF @DryRun = 0
BEGIN
    IF @OuIDIsIdentity = 1 SET IDENTITY_INSERT SCore.OrganisationalUnits ON;

    DECLARE @InsertedRows int = 1;
    DECLARE @InsertPass int = 0;

    WHILE @InsertedRows > 0 AND @InsertPass < 100
    BEGIN
        SET @InsertPass += 1;

        INSERT INTO SCore.OrganisationalUnits
        (
            ID, RowStatus, Guid, Name, ParentID, AddressId, ContactId, OfficialAddressId, OfficialContactId,
            OrgNode, DepartmentPrefix, CostCentreCode, DefaultSecurityGroupId, QuoteThreshold
        )
        SELECT
            sou.ID, sou.RowStatus, sou.Guid, sou.Name, sou.ParentID, sou.AddressId, sou.ContactId,
            sou.OfficialAddressId, sou.OfficialContactId,
            CASE WHEN sou.OrgNodePath IS NULL THEN NULL ELSE hierarchyid::Parse(sou.OrgNodePath) END,
            sou.DepartmentPrefix, sou.CostCentreCode, sou.DefaultSecurityGroupId, sou.QuoteThreshold
        FROM @SourceOrganisationalUnits AS sou
        WHERE sou.ID <> -1
          AND NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits AS targetOu WHERE targetOu.ID = sou.ID)
          AND EXISTS (SELECT 1 FROM SCore.OrganisationalUnits AS parentOu WHERE parentOu.ID = sou.ParentID);

        SET @InsertedRows = @@ROWCOUNT;
    END;

    IF @OuIDIsIdentity = 1 SET IDENTITY_INSERT SCore.OrganisationalUnits OFF;

    IF EXISTS
    (
        SELECT 1
        FROM @SourceOrganisationalUnits AS sou
        WHERE sou.ID <> -1
          AND NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits AS targetOu WHERE targetOu.ID = sou.ID)
    )
    BEGIN
        SELECT sou.ID, sou.Name, sou.ParentID,
            CASE WHEN parentOu.ID IS NULL THEN N'Missing parent in target' ELSE N'Unknown' END AS InsertBlocker
        FROM @SourceOrganisationalUnits AS sou
        LEFT JOIN SCore.OrganisationalUnits AS parentOu ON parentOu.ID = sou.ParentID
        WHERE sou.ID <> -1
          AND NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits AS targetOu WHERE targetOu.ID = sou.ID)
        ORDER BY sou.ID;

        THROW 73312, N'One or more OrganisationalUnits could not be inserted because dependencies were not satisfied.', 1;
    END;

    UPDATE targetOu
    SET
        targetOu.RowStatus = sou.RowStatus,
        targetOu.Guid = sou.Guid,
        targetOu.Name = sou.Name,
        targetOu.ParentID = sou.ParentID,
        targetOu.AddressId = sou.AddressId,
        targetOu.ContactId = sou.ContactId,
        targetOu.OfficialAddressId = sou.OfficialAddressId,
        targetOu.OfficialContactId = sou.OfficialContactId,
        targetOu.OrgNode = CASE WHEN sou.OrgNodePath IS NULL THEN NULL ELSE hierarchyid::Parse(sou.OrgNodePath) END,
        targetOu.DepartmentPrefix = sou.DepartmentPrefix,
        targetOu.CostCentreCode = sou.CostCentreCode,
        targetOu.DefaultSecurityGroupId = sou.DefaultSecurityGroupId,
        targetOu.QuoteThreshold = sou.QuoteThreshold
    FROM SCore.OrganisationalUnits AS targetOu
    INNER JOIN @SourceOrganisationalUnits AS sou ON sou.ID = targetOu.ID
    WHERE sou.ID <> -1
      AND
      (
          ISNULL(targetOu.RowStatus, CONVERT(tinyint,255)) <> ISNULL(sou.RowStatus, CONVERT(tinyint,255))
          OR ISNULL(targetOu.Guid, CONVERT(uniqueidentifier,N'00000000-0000-0000-0000-000000000000')) <> ISNULL(sou.Guid, CONVERT(uniqueidentifier,N'00000000-0000-0000-0000-000000000000'))
          OR ISNULL(targetOu.Name, N'') <> ISNULL(sou.Name, N'')
          OR ISNULL(targetOu.ParentID, -2147483648) <> ISNULL(sou.ParentID, -2147483648)
          OR ISNULL(targetOu.AddressId, -2147483648) <> ISNULL(sou.AddressId, -2147483648)
          OR ISNULL(targetOu.ContactId, -2147483648) <> ISNULL(sou.ContactId, -2147483648)
          OR ISNULL(targetOu.OfficialAddressId, -2147483648) <> ISNULL(sou.OfficialAddressId, -2147483648)
          OR ISNULL(targetOu.OfficialContactId, -2147483648) <> ISNULL(sou.OfficialContactId, -2147483648)
          OR ISNULL(CONVERT(nvarchar(4000), targetOu.OrgNode.ToString()), N'<NULL>') <> ISNULL(sou.OrgNodePath, N'<NULL>')
          OR ISNULL(targetOu.DepartmentPrefix, N'') <> ISNULL(sou.DepartmentPrefix, N'')
          OR ISNULL(targetOu.CostCentreCode, N'') <> ISNULL(sou.CostCentreCode, N'')
          OR ISNULL(targetOu.DefaultSecurityGroupId, -2147483648) <> ISNULL(sou.DefaultSecurityGroupId, -2147483648)
          OR ISNULL(targetOu.QuoteThreshold, CONVERT(decimal(19,2), -999999999999.99)) <> ISNULL(sou.QuoteThreshold, CONVERT(decimal(19,2), -999999999999.99))
      );

    UPDATE dob
    SET dob.RowStatus = CONVERT(tinyint,1), dob.EntityTypeId = @EntityType_OrganisationalUnit
    FROM SCore.DataObjects AS dob
    INNER JOIN @SourceOrganisationalUnits AS sou ON sou.Guid = dob.Guid
    WHERE sou.ID <> -1
      AND (dob.RowStatus IN (0,254) OR dob.EntityTypeId <> @EntityType_OrganisationalUnit);

    INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
    SELECT sou.Guid, CONVERT(tinyint,1), @EntityType_OrganisationalUnit
    FROM @SourceOrganisationalUnits AS sou
    WHERE sou.ID <> -1
      AND sou.Guid IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM SCore.DataObjects AS dob WHERE dob.Guid = sou.Guid);
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    LEFT JOIN SCore.OrganisationalUnits AS targetOu
        ON targetOu.ID = sou.ID
       AND targetOu.Guid = sou.Guid
       AND ISNULL(targetOu.Name, N'') = ISNULL(sou.Name, N'')
       AND targetOu.RowStatus NOT IN (0,254)
       AND ISNULL(targetOu.ParentID, -2147483648) = ISNULL(sou.ParentID, -2147483648)
       AND ISNULL(targetOu.AddressId, -2147483648) = ISNULL(sou.AddressId, -2147483648)
       AND ISNULL(targetOu.ContactId, -2147483648) = ISNULL(sou.ContactId, -2147483648)
       AND ISNULL(targetOu.OfficialAddressId, -2147483648) = ISNULL(sou.OfficialAddressId, -2147483648)
       AND ISNULL(targetOu.OfficialContactId, -2147483648) = ISNULL(sou.OfficialContactId, -2147483648)
       AND ISNULL(CONVERT(nvarchar(4000), targetOu.OrgNode.ToString()), N'<NULL>') = ISNULL(sou.OrgNodePath, N'<NULL>')
       AND ISNULL(targetOu.DepartmentPrefix, N'') = ISNULL(sou.DepartmentPrefix, N'')
       AND ISNULL(targetOu.CostCentreCode, N'') = ISNULL(sou.CostCentreCode, N'')
       AND ISNULL(targetOu.DefaultSecurityGroupId, -2147483648) = ISNULL(sou.DefaultSecurityGroupId, -2147483648)
       AND ISNULL(targetOu.QuoteThreshold, CONVERT(decimal(19,2), -999999999999.99)) = ISNULL(sou.QuoteThreshold, CONVERT(decimal(19,2), -999999999999.99))
    WHERE sou.ID <> -1 AND targetOu.ID IS NULL
)
BEGIN
    SELECT
        sou.ID AS SourceOrganisationalUnitID,
        sou.Guid AS SourceOrganisationalUnitGuid,
        sou.Name AS SourceOrganisationalUnitName,
        sou.ParentID,
        sou.DefaultSecurityGroupId,
        targetOu.ID AS TargetOrganisationalUnitID,
        targetOu.Guid AS TargetOrganisationalUnitGuid,
        targetOu.Name AS TargetOrganisationalUnitName,
        targetOu.RowStatus AS TargetRowStatus,
        targetOu.ParentID AS TargetParentID,
        targetOu.DefaultSecurityGroupId AS TargetDefaultSecurityGroupId
    FROM @SourceOrganisationalUnits AS sou
    LEFT JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = sou.ID
    WHERE sou.ID <> -1
      AND NOT EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS exactOu
          WHERE exactOu.ID = sou.ID
            AND exactOu.Guid = sou.Guid
            AND ISNULL(exactOu.Name, N'') = ISNULL(sou.Name, N'')
            AND exactOu.RowStatus NOT IN (0,254)
            AND ISNULL(exactOu.ParentID, -2147483648) = ISNULL(sou.ParentID, -2147483648)
            AND ISNULL(exactOu.AddressId, -2147483648) = ISNULL(sou.AddressId, -2147483648)
            AND ISNULL(exactOu.ContactId, -2147483648) = ISNULL(sou.ContactId, -2147483648)
            AND ISNULL(exactOu.OfficialAddressId, -2147483648) = ISNULL(sou.OfficialAddressId, -2147483648)
            AND ISNULL(exactOu.OfficialContactId, -2147483648) = ISNULL(sou.OfficialContactId, -2147483648)
            AND ISNULL(CONVERT(nvarchar(4000), exactOu.OrgNode.ToString()), N'<NULL>') = ISNULL(sou.OrgNodePath, N'<NULL>')
            AND ISNULL(exactOu.DepartmentPrefix, N'') = ISNULL(sou.DepartmentPrefix, N'')
            AND ISNULL(exactOu.CostCentreCode, N'') = ISNULL(sou.CostCentreCode, N'')
            AND ISNULL(exactOu.DefaultSecurityGroupId, -2147483648) = ISNULL(sou.DefaultSecurityGroupId, -2147483648)
            AND ISNULL(exactOu.QuoteThreshold, CONVERT(decimal(19,2), -999999999999.99)) = ISNULL(sou.QuoteThreshold, CONVERT(decimal(19,2), -999999999999.99))
      )
    ORDER BY sou.ID;

    THROW 73308, N'OrganisationalUnit dependency apply did not produce exact active OrganisationalUnit alignment.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @SourceOrganisationalUnits AS sou
    LEFT JOIN SCore.DataObjects AS dob
        ON dob.Guid = sou.Guid AND dob.EntityTypeId = @EntityType_OrganisationalUnit AND dob.RowStatus NOT IN (0,254)
    WHERE sou.ID <> -1 AND dob.Guid IS NULL
)
BEGIN
    SELECT sou.ID, sou.Guid, sou.Name, @EntityType_OrganisationalUnit AS ExpectedEntityTypeID
    FROM @SourceOrganisationalUnits AS sou
    LEFT JOIN SCore.DataObjects AS dob
        ON dob.Guid = sou.Guid AND dob.EntityTypeId = @EntityType_OrganisationalUnit AND dob.RowStatus NOT IN (0,254)
    WHERE sou.ID <> -1 AND dob.Guid IS NULL
    ORDER BY sou.ID;

    THROW 73309, N'SCore.DataObjects rows are missing or inactive for required OrganisationalUnits.', 1;
END;

IF @DryRun = 1
BEGIN
    ROLLBACK TRANSACTION;
    PRINT N'Dry run completed and rolled back successfully.';
END;
ELSE
BEGIN
    COMMIT TRANSACTION;
    PRINT N'Workflow OrganisationalUnit dependency apply v14 completed successfully.';
END;

SELECT
    N'Workflow OrganisationalUnit dependency apply completed' AS Result,
    @RunGuid AS RunGuid,
    @DryRun AS DryRun,
    @EntityType_OrganisationalUnit AS OrganisationalUnitEntityTypeID,
    (SELECT COUNT_BIG(1) FROM @SourceOrganisationalUnits WHERE ID <> -1) AS SourceRequiredOrganisationalUnits,
    (SELECT COUNT_BIG(1) FROM @SourceOrganisationalUnits AS sou INNER JOIN SCore.OrganisationalUnits AS ou ON ou.ID = sou.ID AND ou.Guid = sou.Guid AND ou.RowStatus NOT IN (0,254) WHERE sou.ID <> -1) AS TargetAlignedOrganisationalUnits;
