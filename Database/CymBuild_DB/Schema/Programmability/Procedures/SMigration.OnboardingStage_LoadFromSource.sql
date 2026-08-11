SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

/* ================================================================================================
   Load onboarding migration stage from source DB.

   CymBuild rules preserved:
   - Source DB is read-only.
   - Target staging tables are deployment target only.
   - No manual DB promotion.
   - Explicit columns only.
   - Sentinel GUID rows are ignored.
   - RowStatus NOT IN (0,254) used for active migration scope where appropriate.
   - Workflow parent rows are staged before WorkflowStatusNotificationGroups.

   Critical workflow note:
   Active WorkflowStatusNotificationGroups may reference a Workflow parent whose RowStatus is not
   active in the source. Therefore Workflow parent staging intentionally does NOT filter wf.RowStatus.
   Filtering wf.RowStatus here was the cause of StagedWorkflows = 0 while WSNG rows were staged,
   which then caused MISSING_WORKFLOW validation errors.
   ================================================================================================ */
PRINT (N'Create procedure [SMigration].[OnboardingStage_LoadFromSource]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingStage_LoadFromSource]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingStage_LoadFromSource]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingStage_LoadFromSource]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingStage_LoadFromSource]')
GO

/* ================================================================================================
   Load onboarding migration stage from source DB.

   CymBuild rules preserved:
   - Source DB is read-only.
   - Target staging tables are deployment target only.
   - No manual DB promotion.
   - Explicit columns only.
   - Sentinel GUID rows are ignored.
   - RowStatus NOT IN (0,254) used for active migration scope where appropriate.
   - Workflow parent rows are staged before WorkflowStatusNotificationGroups.

   Critical workflow note:
   Active WorkflowStatusNotificationGroups may reference a Workflow parent whose RowStatus is not
   active in the source. Therefore Workflow parent staging intentionally does NOT filter wf.RowStatus.
   Filtering wf.RowStatus here was the cause of StagedWorkflows = 0 while WSNG rows were staged,
   which then caused MISSING_WORKFLOW validation errors.
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingStage_LoadFromSource]
    @SourceDatabase SYSNAME,
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER,
    @SourceServerName SYSNAME = N'',
    @TargetServerName SYSNAME = N'',
    @TargetDatabaseName SYSNAME = N'',
    @RunGuid UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(1000) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    EXEC SMigration.OnboardingStage_Reset @RunGuid = @RunGuid;

    DECLARE @SourceBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER = NULL;
    DECLARE @sql NVARCHAR(MAX);

    /* Resolve source BU OU by matching default security group first. */
    SET @sql = N'
    SELECT TOP (1)
        @OutGuid = ou.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = ou.DefaultSecurityGroupId
    WHERE g.Guid = @BusinessUnitGroupGuid
      AND ou.ID > 0
      AND g.ID > 0
    ORDER BY ou.ID;';

    EXEC sp_executesql
        @sql,
        N'@BusinessUnitGroupGuid UNIQUEIDENTIFIER, @OutGuid UNIQUEIDENTIFIER OUTPUT',
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @OutGuid = @SourceBusinessUnitOrganisationalUnitGuid OUTPUT;

    /* Fallback: match OU name to group name. */
    IF @SourceBusinessUnitOrganisationalUnitGuid IS NULL
    BEGIN
        SET @sql = N'
        SELECT TOP (1)
            @OutGuid = ou.Guid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.Guid = @BusinessUnitGroupGuid
        WHERE ou.Name = g.Name
          AND ou.ID > 0
          AND g.ID > 0
        ORDER BY ou.ID;';

        EXEC sp_executesql
            @sql,
            N'@BusinessUnitGroupGuid UNIQUEIDENTIFIER, @OutGuid UNIQUEIDENTIFIER OUTPUT',
            @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
            @OutGuid = @SourceBusinessUnitOrganisationalUnitGuid OUTPUT;
    END;

    EXEC SMigration.OnboardingRun_Reserve
        @RunGuid = @RunGuid,
        @SourceDatabase = @SourceDatabase,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @SourceServerName = @SourceServerName,
        @TargetServerName = @TargetServerName,
        @TargetDatabaseName = @TargetDatabaseName,
        @SourceBusinessUnitOrganisationalUnitGuid = @SourceBusinessUnitOrganisationalUnitGuid,
        @Notes = @Notes;

    IF @SourceBusinessUnitOrganisationalUnitGuid IS NULL
    BEGIN
        DECLARE @SourceBusinessUnitError NVARCHAR(2048) = CONCAT(
            N'Could not resolve selected source business unit group ',
            CONVERT(NVARCHAR(36), @BusinessUnitGroupGuid),
            N' to a source organisational unit in database ',
            QUOTENAME(@SourceDatabase),
            N'. The OnBoarding business unit must be a group used as SCore.OrganisationalUnits.DefaultSecurityGroupId, or have an organisational unit with the same name. Reload the OnBoarding business-unit lookup after deploying this patch; the lookup now only returns resolvable business-unit groups.'
        );

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Stage',
            N'All',
            N'Failed',
            0,
            @SourceBusinessUnitError;

        THROW 51000, @SourceBusinessUnitError, 1;
    END;

    /* ============================================================================================
       1. Groups
       ============================================================================================ */
    SET @sql = N'
    ;WITH StageIdentityIds AS
    (
        SELECT DISTINCT
            i.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
            ON ug.IdentityID = i.ID
           AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ug.GroupID
           AND g.RowStatus NOT IN (0,254)
        WHERE i.RowStatus NOT IN (0,254)
          AND i.ID > 0
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    StageOU AS
    (
        SELECT
            ou.ID,
            g.ID AS DefaultGroupID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ou.DefaultSecurityGroupId
        CROSS JOIN
        (
            SELECT OrgNode
            FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits
            WHERE Guid = @BusinessUnitOuGuid
        ) AS b
        WHERE ou.RowStatus NOT IN (0,254)
          AND ou.ID > 0
          AND
          (
              ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
              OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1
          )
    ),
    RelevantGroups AS
    (
        SELECT
            g.ID,
            g.Guid,
            g.RowStatus,
            g.DirectoryId,
            g.Code,
            g.Name,
            g.Source
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        WHERE g.Guid = @BusinessUnitGroupGuid
          AND g.ID > 0

        UNION

        SELECT DISTINCT
            g.ID,
            g.Guid,
            g.RowStatus,
            g.DirectoryId,
            g.Code,
            g.Name,
            g.Source
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
            ON ug.GroupID = g.ID
        INNER JOIN StageIdentityIds AS s
            ON s.ID = ug.IdentityID
        WHERE g.RowStatus NOT IN (0,254)
          AND ug.RowStatus NOT IN (0,254)
          AND g.ID > 0

        UNION

        SELECT DISTINCT
            g.ID,
            g.Guid,
            g.RowStatus,
            g.DirectoryId,
            g.Code,
            g.Name,
            g.Source
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        INNER JOIN StageOU AS sou
            ON sou.DefaultGroupID = g.ID
        WHERE g.RowStatus NOT IN (0,254)
          AND g.ID > 0
    )
    INSERT INTO SMigration.Onboarding_Groups
    (
        RunGuid,
        GroupGuid,
        RowStatus,
        DirectoryId,
        Code,
        Name,
        Source,
        IsBusinessUnitGroup
    )
    SELECT DISTINCT
        @RunGuid,
        rg.Guid,
        rg.RowStatus,
        rg.DirectoryId,
        rg.Code,
        rg.Name,
        rg.Source,
        CAST(CASE WHEN rg.Guid = @BusinessUnitGroupGuid THEN 1 ELSE 0 END AS BIT)
    FROM RelevantGroups AS rg
    WHERE rg.ID > 0
      AND rg.Guid <> ''00000000-0000-0000-0000-000000000000'';';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* ============================================================================================
       2. OrganisationalUnits
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_OrganisationalUnits
    (
        RunGuid,
        OrganisationalUnitGuid,
        RowStatus,
        Name,
        ParentOrganisationalUnitGuid,
        ParentOrganisationalUnitName,
        AddressGuid,
        ContactGuid,
        OfficialAddressGuid,
        OfficialContactGuid,
        DepartmentPrefix,
        CostCentreCode,
        DefaultSecurityGroupGuid,
        QuoteThreshold,
        OrgLevel
    )
    SELECT
        @RunGuid,
        ou.Guid,
        ou.RowStatus,
        ou.Name,
        parent.Guid,
        parent.Name,
        a.Guid,
        c.Guid,
        oa.Guid,
        oc.Guid,
        ou.DepartmentPrefix,
        ou.CostCentreCode,
        g.Guid,
        ou.QuoteThreshold,
        ou.OrgNode.GetLevel()
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS parent
        ON parent.ID = ou.ParentID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS a
        ON a.ID = ou.AddressId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
        ON c.ID = ou.ContactId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS oa
        ON oa.ID = ou.OfficialAddressId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS oc
        ON oc.ID = ou.OfficialContactId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = ou.DefaultSecurityGroupId
    CROSS JOIN
    (
        SELECT OrgNode
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits
        WHERE Guid = @BusinessUnitOuGuid
    ) AS b
    WHERE ou.RowStatus NOT IN (0,254)
      AND ou.ID > 0
      AND ou.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND
      (
          ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
          OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

        /* Workflows in scope:
           - notification-group parents
           - active workflows for staged source OUs
        */
        SET @sql = N'
        ;WITH SourceWorkflows AS
        (
            SELECT DISTINCT
                wf.Guid AS WorkflowGuid,
                wf.RowStatus,
                ou.Guid AS OrganisationalUnitGuid,
                et.Guid AS EntityTypeGuid,
                eh.Guid AS EntityHoBTGuid,
                wf.Name,
                wf.Description,
                wf.Enabled
            FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
                ON ou.ID = wf.OrganisationalUnitId
            LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityTypes AS et
                ON et.ID = wf.EntityTypeID
            LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityHoBTs AS eh
                ON eh.ID = wf.EntityHoBTID
            WHERE wf.ID > 0
              AND wf.Guid <> ''00000000-0000-0000-0000-000000000000''
              AND
              (
                  wf.RowStatus NOT IN (0,254)
                  OR EXISTS
                  (
                      SELECT 1
                      FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS wsng
                      WHERE wsng.WorkflowID = wf.ID
                        AND wsng.RowStatus NOT IN (0,254)
                        AND wsng.ID > 0
                  )
              )
              AND
              (
                  wf.OrganisationalUnitId = -1
                  OR EXISTS
                  (
                      SELECT 1
                      FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS businessUnit
                      WHERE businessUnit.Guid = @BusinessUnitOuGuid
                        AND businessUnit.ID > 0
                        AND ou.OrgNode.IsDescendantOf(businessUnit.OrgNode) = 1
                  )
              )
        )
        INSERT INTO SMigration.Onboarding_Workflows
        (
            RunGuid,
            WorkflowGuid,
            RowStatus,
            OrganisationalUnitGuid,
            EntityTypeGuid,
            EntityHoBTGuid,
            Name,
            Description,
            Enabled
        )
        SELECT
            @RunGuid,
            sw.WorkflowGuid,
            sw.RowStatus,
            sw.OrganisationalUnitGuid,
            sw.EntityTypeGuid,
            sw.EntityHoBTGuid,
            sw.Name,
            sw.Description,
            sw.Enabled
        FROM SourceWorkflows AS sw
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_Workflows AS existing
            WHERE existing.RunGuid = @RunGuid
              AND existing.WorkflowGuid = sw.WorkflowGuid
        );
        ';

        EXEC sp_executesql
            @sql,
            N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* ============================================================================================
       3. Addresses required by staged OUs
       ============================================================================================ */
    SET @sql = N'
    ;WITH RelevantAddressGuids AS
    (
        SELECT AddressGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid

        UNION

        SELECT OfficialAddressGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid
    )
    INSERT INTO SMigration.Onboarding_Addresses
    (
        RunGuid,
        AddressGuid,
        RowStatus,
        AddressNumber,
        Name,
        Number,
        AddressLine1,
        AddressLine2,
        AddressLine3,
        Town,
        CountyGuid,
        Postcode,
        CountryGuid,
        LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        a.Guid,
        a.RowStatus,
        a.AddressNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        county.Guid,
        a.Postcode,
        country.Guid,
        a.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS a
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Counties AS county
        ON county.ID = a.CountyID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Countries AS country
        ON country.ID = a.CountryID
    INNER JOIN RelevantAddressGuids AS r
        ON r.Guid = a.Guid
    WHERE a.ID > 0
      AND a.Guid <> ''00000000-0000-0000-0000-000000000000'';';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       4. Contacts required by OUs and identities
       ============================================================================================ */
    SET @sql = N'
    ;WITH IdentityContactGuids AS
    (
        SELECT DISTINCT
            c.Guid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
            ON ug.IdentityID = i.ID
           AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ug.GroupID
           AND g.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
            ON c.ID = i.ContactId
        WHERE i.RowStatus NOT IN (0,254)
          AND i.ID > 0
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    OUContactGuids AS
    (
        SELECT ContactGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid

        UNION

        SELECT OfficialContactGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid
    ),
    RelevantContactGuids AS
    (
        SELECT Guid FROM IdentityContactGuids
        UNION
        SELECT Guid FROM OUContactGuids
    )
    INSERT INTO SMigration.Onboarding_Contacts
    (
        RunGuid,
        ContactGuid,
        RowStatus,
        PrimaryAccountGuid,
        PrimaryAddressGuid,
        FirstName,
        Initials,
        Surname,
        PostNominals,
        TitleGuid,
        DisplayName,
        IsPerson,
        PositionGuid,
        LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        c.Guid,
        c.RowStatus,
        acct.Guid,
        addr.Guid,
        c.FirstName,
        c.Initials,
        c.Surname,
        c.PostNominals,
        title.Guid,
        c.DisplayName,
        c.IsPerson,
        pos.Guid,
        c.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Accounts AS acct
        ON acct.ID = c.PrimaryAccountID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS addr
        ON addr.ID = c.PrimaryAddressID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.ContactTitles AS title
        ON title.ID = c.TitleId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.ContactPositions AS pos
        ON pos.ID = c.PositionID
    INNER JOIN RelevantContactGuids AS r
        ON r.Guid = c.Guid
    WHERE c.ID > 0
      AND c.Guid <> ''00000000-0000-0000-0000-000000000000'';';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    /* ============================================================================================
       5. Addresses required by staged contacts
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Addresses
    (
        RunGuid,
        AddressGuid,
        RowStatus,
        AddressNumber,
        Name,
        Number,
        AddressLine1,
        AddressLine2,
        AddressLine3,
        Town,
        CountyGuid,
        Postcode,
        CountryGuid,
        LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        a.Guid,
        a.RowStatus,
        a.AddressNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        county.Guid,
        a.Postcode,
        country.Guid,
        a.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS a
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Counties AS county
        ON county.ID = a.CountyID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Countries AS country
        ON country.ID = a.CountryID
    INNER JOIN SMigration.Onboarding_Contacts AS c
        ON c.RunGuid = @RunGuid
       AND c.PrimaryAddressGuid = a.Guid
    WHERE a.ID > 0
      AND a.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Addresses AS x
          WHERE x.RunGuid = @RunGuid
            AND x.AddressGuid = a.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       6. Identities
       ============================================================================================ */
    SET @sql = N'
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
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
        ON ug.IdentityID = i.ID
       AND ug.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = ug.GroupID
       AND g.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = i.OriganisationalUnitId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
        ON c.ID = i.ContactId
    WHERE i.RowStatus NOT IN (0,254)
      AND i.ID > 0
      AND i.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND g.Guid = @BusinessUnitGroupGuid;';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    /* ============================================================================================
       7. UserGroups
       ============================================================================================ */
    SET @sql = N'
    ;WITH SourceUserGroups AS
    (
        SELECT
            @RunGuid AS RunGuid,
            ug.Guid AS UserGroupGuid,
            ug.RowStatus,
            i.Guid AS IdentityGuid,
            g.Guid AS GroupGuid,
            ROW_NUMBER() OVER
            (
                PARTITION BY ug.Guid
                ORDER BY ug.ID
            ) AS DuplicateRank
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
            ON i.ID = ug.IdentityID
           AND i.ID > 0
           AND i.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ug.GroupID
           AND g.ID > 0
           AND g.RowStatus NOT IN (0,254)
        WHERE ug.RowStatus NOT IN (0,254)
          AND ug.ID > 0
          AND ug.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_Identities AS oi
              WHERE oi.RunGuid = @RunGuid
                AND oi.IdentityGuid = i.Guid
          )
          AND EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_Groups AS og
              WHERE og.RunGuid = @RunGuid
                AND og.GroupGuid = g.Guid
          )
    )
    INSERT INTO SMigration.Onboarding_UserGroups
    (
        RunGuid,
        UserGroupGuid,
        RowStatus,
        IdentityGuid,
        GroupGuid
    )
    SELECT
        sug.RunGuid,
        sug.UserGroupGuid,
        sug.RowStatus,
        sug.IdentityGuid,
        sug.GroupGuid
    FROM SourceUserGroups AS sug
    WHERE sug.DuplicateRank = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_UserGroups AS existing
          WHERE existing.RunGuid = sug.RunGuid
            AND existing.UserGroupGuid = sug.UserGroupGuid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

        
    /* ============================================================================================
       8. Workflows required by staged workflow notification groups.
       Do not filter wf.RowStatus here. See header note.
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Workflows
    (
        RunGuid,
        WorkflowGuid,
        RowStatus,
        OrganisationalUnitGuid,
        EntityTypeGuid,
        EntityHoBTGuid,
        Name,
        Description,
        Enabled
    )
    SELECT DISTINCT
        @RunGuid,
        wf.Guid,
        wf.RowStatus,
        ou.Guid,
        et.Guid,
        eh.Guid,
        wf.Name,
        wf.Description,
        wf.Enabled
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS wsng
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
        ON wf.ID = wsng.WorkflowID
       AND wf.ID > 0
       AND wf.Guid <> ''00000000-0000-0000-0000-000000000000''
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = wsng.GroupID
       AND g.RowStatus NOT IN (0,254)
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = wf.OrganisationalUnitId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityTypes AS et
        ON et.ID = wf.EntityTypeID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityHoBTs AS eh
        ON eh.ID = wf.EntityHoBTID
    WHERE wsng.RowStatus NOT IN (0,254)
      AND wsng.ID > 0
      AND wsng.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Groups AS sg
          WHERE sg.RunGuid = @RunGuid
            AND sg.GroupGuid = g.Guid
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Workflows AS existing
          WHERE existing.RunGuid = @RunGuid
            AND existing.WorkflowGuid = wf.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

/* WorkflowStatuses required by staged workflows, transitions and notification groups */
    SET @sql = N'
    ;WITH WorkflowStatusGuids AS
    (
        SELECT DISTINCT fromWs.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowTransition AS wt
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wt.WorkflowID
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS fromWs
            ON fromWs.ID = wt.FromStatusID
           AND wt.FromStatusID > 0
        WHERE wt.ID > 0
          AND wt.RowStatus NOT IN (0,254)
          AND fromWs.RowStatus NOT IN (0,254)
          AND fromWs.Guid <> ''00000000-0000-0000-0000-000000000000''

        UNION

        SELECT DISTINCT toWs.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowTransition AS wt
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wt.WorkflowID
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS toWs
            ON toWs.ID = wt.ToStatusID
           AND wt.ToStatusID > 0
        WHERE wt.ID > 0
          AND wt.RowStatus NOT IN (0,254)
          AND toWs.RowStatus NOT IN (0,254)
          AND toWs.Guid <> ''00000000-0000-0000-0000-000000000000''

        UNION

        SELECT DISTINCT ws.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS wsng
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wsng.WorkflowID
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS ws
            ON ws.Guid = wsng.WorkflowStatusGuid
        WHERE wsng.ID > 0
          AND wsng.RowStatus NOT IN (0,254)
          AND ws.RowStatus NOT IN (0,254)
          AND ws.Guid <> ''00000000-0000-0000-0000-000000000000''

        UNION

        SELECT DISTINCT ws.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS ws
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
            ON ou.ID = ws.OrganisationalUnitId
        CROSS JOIN
        (
            SELECT OrgNode
            FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits
            WHERE Guid = @BusinessUnitOuGuid
        ) AS b
        WHERE ws.ID > 0
          AND ws.RowStatus NOT IN (0,254)
          AND ws.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND
          (
              ws.OrganisationalUnitId = -1
              OR ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
          )
    )
    INSERT INTO SMigration.Onboarding_WorkflowStatuses
    (
        RunGuid,
        WorkflowStatusGuid,
        RowStatus,
        OrganisationalUnitGuid,
        Name,
        Description,
        ShowInEnquiries,
        ShowInQuotes,
        ShowInJobs,
        Enabled,
        IsPredefined,
        SortOrder,
        Colour,
        Icon,
        SendNotification,
        IsCompleteStatus,
        IsCustomerWaitingStatus,
        RequiresUsersAction,
        IsActiveStatus,
        AuthorisationNeeded,
        IsAuthStatus
    )
    SELECT DISTINCT
        @RunGuid,
        ws.Guid,
        ws.RowStatus,
        ou.Guid,
        ws.Name,
        ws.Description,
        ws.ShowInEnquiries,
        ws.ShowInQuotes,
        ws.ShowInJobs,
        ws.Enabled,
        ws.IsPredefined,
        ws.SortOrder,
        ws.Colour,
        ws.Icon,
        ws.SendNotification,
        ws.IsCompleteStatus,
        ws.IsCustomerWaitingStatus,
        ws.RequiresUsersAction,
        ws.IsActiveStatus,
        ws.AuthorisationNeeded,
        ws.IsAuthStatus
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS ws
    INNER JOIN WorkflowStatusGuids AS relevant
        ON relevant.WorkflowStatusGuid = ws.Guid
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = ws.OrganisationalUnitId
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_WorkflowStatuses AS existing
        WHERE existing.RunGuid = @RunGuid
          AND existing.WorkflowStatusGuid = ws.Guid
    );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

/* WorkflowTransitions for staged workflows */
        SET @sql = N'
        INSERT INTO SMigration.Onboarding_WorkflowTransitions
        (
            RunGuid,
            WorkflowTransitionGuid,
            RowStatus,
            WorkflowGuid,
            FromStatusGuid,
            ToStatusGuid,
            IsFinal,
            Enabled,
            SortOrder,
            Description
        )
        SELECT
            @RunGuid,
            wt.Guid,
            wt.RowStatus,
            wf.Guid,
            ISNULL(fromWs.Guid, ''00000000-0000-0000-0000-000000000000''),
            ISNULL(toWs.Guid, ''00000000-0000-0000-0000-000000000000''),
            wt.IsFinal,
            wt.Enabled,
            wt.SortOrder,
            ISNULL(wt.Description, N'''')
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowTransition AS wt
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wt.WorkflowID
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS fromWs
            ON fromWs.ID = wt.FromStatusID
           AND wt.FromStatusID > 0
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS toWs
            ON toWs.ID = wt.ToStatusID
           AND wt.ToStatusID > 0
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        WHERE wt.ID > 0
          AND wt.RowStatus NOT IN (0,254)
          AND wt.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_WorkflowTransitions AS existing
              WHERE existing.RunGuid = @RunGuid
                AND existing.WorkflowTransitionGuid = wt.Guid
          );
        ';

        EXEC sp_executesql
            @sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;

    /* ============================================================================================
       9. WorkflowStatusNotificationGroups
       ============================================================================================ */
    SET @sql = N'
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
        x.Guid,
        x.RowStatus,
        wf.Guid,
        x.WorkflowStatusGuid,
        g.Guid,
        x.CanAction
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS x
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
        ON wf.ID = x.WorkflowID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = x.GroupID
    WHERE x.RowStatus NOT IN (0,254)
      AND x.ID > 0
      AND x.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Groups AS sg
          WHERE sg.RunGuid = @RunGuid
            AND sg.GroupGuid = g.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       10. JobTypes under staged OUs
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypes
    (
        RunGuid,
        JobTypeGuid,
        RowStatus,
        Name,
        IsActive,
        SequenceID,
        UseTimeSheets,
        UsePlanChecks,
        OrganisationalUnitGuid
    )
    SELECT DISTINCT
        @RunGuid,
        jt.Guid,
        jt.RowStatus,
        jt.Name,
        jt.IsActive,
        jt.SequenceID,
        jt.UseTimeSheets,
        jt.UsePlanChecks,
        ou.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = jt.OrganisationalUnitID
    WHERE jt.RowStatus NOT IN (0,254)
      AND jt.ID > 0
      AND jt.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_OrganisationalUnits AS sou
          WHERE sou.RunGuid = @RunGuid
            AND sou.OrganisationalUnitGuid = ou.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS businessUnit
          WHERE businessUnit.Guid = @BusinessUnitOuGuid
            AND businessUnit.ID > 0
            AND ou.OrgNode.IsDescendantOf(businessUnit.OrgNode) = 1
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* ============================================================================================
       11. ActivityTypes only those used by staged jobtypes
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_ActivityTypes
    (
        RunGuid,
        ActivityTypeGuid,
        RowStatus,
        Name,
        IsActive,
        SortOrder,
        IsFeeTrigger,
        IsLiveTrigger,
        IsAdmin,
        IsScheduleItem,
        Colour,
        IsMeeting,
        IsSiteVisit,
        IsBillable,
        IsCommencementTrigger
    )
    SELECT DISTINCT
        @RunGuid,
        at.Guid,
        at.RowStatus,
        at.Name,
        at.IsActive,
        at.SortOrder,
        at.IsFeeTrigger,
        at.IsLiveTrigger,
        at.IsAdmin,
        at.IsScheduleItem,
        at.Colour,
        at.IsMeeting,
        at.IsSiteVisit,
        at.IsBillable,
        at.IsCommencementTrigger
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.ActivityTypes AS at
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes AS jtat
        ON jtat.ActivityTypeID = at.ID
       AND jtat.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtat.JobTypeID
    WHERE at.RowStatus NOT IN (0,254)
      AND at.ID > 0
      AND at.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       12. MilestoneTypes only those used by staged jobtypes
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_MilestoneTypes
    (
        RunGuid,
        MilestoneTypeGuid,
        RowStatus,
        Code,
        Name,
        IsActive,
        IsInvoiceTrigger,
        IsReviewRequired,
        HelpText,
        HasQuotedHours,
        HasDescription,
        HasReference,
        IsCompulsory,
        IncludeStart,
        IncludeSchedule,
        IncludeDueDate,
        HasExternalSubmission
    )
    SELECT DISTINCT
        @RunGuid,
        mt.Guid,
        mt.RowStatus,
        mt.Code,
        mt.Name,
        mt.IsActive,
        mt.IsInvoiceTrigger,
        mt.IsReviewRequired,
        mt.HelpText,
        mt.HasQuotedHours,
        mt.HasDescription,
        mt.HasReference,
        mt.IsCompulsory,
        mt.IncludeStart,
        mt.IncludeSchedule,
        mt.IncludeDueDate,
        mt.HasExternalSubmission
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.MilestoneTypes AS mt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates AS jtmt
        ON jtmt.MilestoneTypeID = mt.ID
       AND jtmt.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtmt.JobTypeID
    WHERE mt.RowStatus NOT IN (0,254)
      AND mt.ID > 0
      AND mt.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       13. JobTypeActivityTypes
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypeActivityTypes
    (
        RunGuid,
        JobTypeActivityTypeGuid,
        RowStatus,
        JobTypeGuid,
        ActivityTypeGuid
    )
    SELECT DISTINCT
        @RunGuid,
        jtat.Guid,
        jtat.RowStatus,
        jt.Guid,
        at.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes AS jtat
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtat.JobTypeID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.ActivityTypes AS at
        ON at.ID = jtat.ActivityTypeID
    WHERE jtat.RowStatus NOT IN (0,254)
      AND jtat.ID > 0
      AND jtat.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_ActivityTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.ActivityTypeGuid = at.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       14. JobTypeMilestoneTemplates
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypeMilestoneTemplates
    (
        RunGuid,
        JobTypeMilestoneTemplateGuid,
        RowStatus,
        JobTypeGuid,
        MilestoneTypeGuid,
        Description,
        SortOrder
    )
    SELECT DISTINCT
        @RunGuid,
        jtmt.Guid,
        jtmt.RowStatus,
        jt.Guid,
        mt.Guid,
        jtmt.Description,
        jtmt.SortOrder
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates AS jtmt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtmt.JobTypeID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.MilestoneTypes AS mt
        ON mt.ID = jtmt.MilestoneTypeID
    WHERE jtmt.RowStatus NOT IN (0,254)
      AND jtmt.ID > 0
      AND jtmt.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_MilestoneTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.MilestoneTypeGuid = mt.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       15. Products
       ============================================================================================ */
    /* Products for staged job types */
        SET @sql = N'
        INSERT INTO SMigration.Onboarding_Products
        (
            RunGuid,
            ProductGuid,
            RowStatus,
            Code,
            Description,
            CreatedJobTypeGuid,
            NeverConsolidate,
            RibaStageGuid
        )
        SELECT DISTINCT
            @RunGuid,
            p.Guid,
            p.RowStatus,
            p.Code,
            p.Description,
            jt.Guid,
            p.NeverConsolidate,
            ISNULL(rs.Guid, ''00000000-0000-0000-0000-000000000000'')
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SProd.Products AS p
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
            ON jt.ID = p.CreatedJobType
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.RibaStages AS rs
            ON rs.ID = p.RibaStageId
        INNER JOIN SMigration.Onboarding_JobTypes AS sjt
            ON sjt.RunGuid = @RunGuid
           AND sjt.JobTypeGuid = jt.Guid
        WHERE p.ID > 0
          AND p.RowStatus NOT IN (0,254)
          AND p.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_Products AS existing
              WHERE existing.RunGuid = @RunGuid
                AND existing.ProductGuid = p.Guid
          );
        ';

        EXEC sp_executesql
            @sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;

    /* ============================================================================================
       16. ProductJobActivities
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_ProductJobActivities
    (
        RunGuid,
        ProductJobActivityGuid,
        RowStatus,
        ProductGuid,
        JobTypeActivityTypeGuid,
        ActivityTitle,
        OffsetDays,
        OffsetWeeks,
        OffsetMonths,
        JobTypeMilestoneTemplateGuid,
        PercentageOfProductValue
    )
    SELECT DISTINCT
        @RunGuid,
        pja.Guid,
        pja.RowStatus,
        p.Guid,
        jtat.Guid,
        pja.ActivityTitle,
        pja.OffsetDays,
        pja.OffsetWeeks,
        pja.OffsetMonths,
        jtmt.Guid,
        pja.PercentageOfProductValue
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.ProductJobActivities AS pja
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SProd.Products AS p
        ON p.ID = pja.ProductId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes AS jtat
        ON jtat.ID = pja.JobTypeActivityTypeId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates AS jtmt
        ON jtmt.ID = pja.JobTypeMilestoneTemplateId
    WHERE pja.RowStatus NOT IN (0,254)
      AND pja.ID > 0
      AND pja.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Products AS s
          WHERE s.RunGuid = @RunGuid
            AND s.ProductGuid = p.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypeActivityTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeActivityTypeGuid = jtat.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       Apply persisted run entity scope before counts/validation/apply.
       This preserves the existing full scope when no run-specific selections exist.
       ============================================================================================ */
    EXEC SMigration.OnboardingRunEntitySelection_ApplyToStage @RunGuid = @RunGuid;

    /* ============================================================================================
       Stage execution log counts
       ============================================================================================ */
    DECLARE @c INT;

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Groups', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'OrganisationalUnits', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Addresses', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Contacts', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Identities', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'UserGroups', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Workflows', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowStatuses', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowTransitions', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowStatusNotificationGroups', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'ActivityTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'MilestoneTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypeActivityTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypeMilestoneTemplates', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Products', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'ProductJobActivities', N'Stage', @c, N'';

    /* ============================================================================================
       Stage summary output
       ============================================================================================ */
    SELECT
        RunGuid = @RunGuid,
        GroupCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid),
        IdentityCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid),
        UserGroupCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid),
        WorkflowCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid),
        WorkflowTransitionCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid),
        WorkflowNotificationGroupCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid),
        JobTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid),
        ActivityTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid),
        MilestoneTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid),
        ProductCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid),
        JobTypeActivityTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid),
        JobTypeMilestoneTemplateCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid),
        ProductJobActivityCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid);
END
GO