SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingImport_Apply]')
GO




/* ================================================================================================
   Apply import

   CymBuild-safe apply rules:
   - Preview mode performs no writes.
   - Real apply is transaction protected and rollback-safe.
   - Every true insert creates/uses SCore.DataObjects via SCore.UpsertDataObject first.
   - Sentinel GUIDs are ignored.
   - Business-key collisions are updated/remapped/skipped instead of inserted as duplicates.
   - Relationship/bridge tables are de-duplicated by their natural key before insert.
   ================================================================================================ */
CREATE OR ALTER PROCEDURE [SMigration].[OnboardingImport_Apply]
    @RunGuid UNIQUEIDENTIFIER,
    @AllowWarnings BIT = 1,
    @PreviewOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @IsInsert BIT,
        @cnt INT,
        @StartedTran BIT = 0;

    DECLARE @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    DECLARE
        @SourceBusinessUnitGroupGuid UNIQUEIDENTIFIER = NULL,
        @SourceBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER = NULL,
        @TargetBusinessUnitGroupGuid UNIQUEIDENTIFIER = NULL,
        @TargetBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER = NULL,
        @SourceBusinessUnitGroupName NVARCHAR(250) = NULL;

    SELECT
        @SourceBusinessUnitGroupGuid = runHeader.SourceBusinessUnitGroupGuid,
        @SourceBusinessUnitOrganisationalUnitGuid = runHeader.SourceBusinessUnitOrganisationalUnitGuid
    FROM SMigration.Onboarding_Run AS runHeader
    WHERE runHeader.RunGuid = @RunGuid;

    EXEC SMigration.OnboardingValidate @RunGuid = @RunGuid;

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_ValidationIssues
        WHERE RunGuid = @RunGuid
          AND Severity = N'Error'
    )
    BEGIN
        ;THROW 60000, N'SMigration validation failed. Resolve errors before import.', 1;
    END;

    IF @AllowWarnings = 0
       AND EXISTS
       (
           SELECT 1
           FROM SMigration.Onboarding_ValidationIssues
           WHERE RunGuid = @RunGuid
             AND Severity = N'Warning'
       )
    BEGIN
        ;THROW 60000, N'SMigration validation contains warnings and @AllowWarnings = 0.', 1;
    END;

    IF @PreviewOnly = 1
    BEGIN
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'All', N'Preview', 0, N'Preview only; no changes applied.';
        EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;
        RETURN;
    END;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            SET @StartedTran = 1;
            BEGIN TRAN;
        END;

        EXEC SMigration.OnboardingRunStageSelection_ApplyToStage @RunGuid = @RunGuid;

        /* ========================================================================================
           Shared remap tables
           ======================================================================================== */
        DECLARE @WorkflowGuidRemap TABLE
        (
            SourceWorkflowGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetWorkflowGuid UNIQUEIDENTIFIER NOT NULL
        );
        
        DECLARE @GroupGuidRemap TABLE
        (
            SourceGroupGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetGroupGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @AddressGuidRemap TABLE
        (
            SourceAddressGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetAddressGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @ContactGuidRemap TABLE
        (
            SourceContactGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetContactGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @OrganisationalUnitGuidRemap TABLE
        (
            SourceOrganisationalUnitGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetOrganisationalUnitGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @IdentityGuidRemap TABLE
        (
            SourceIdentityGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetIdentityGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @JobTypeGuidRemap TABLE
        (
            SourceJobTypeGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetJobTypeGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @ActivityTypeGuidRemap TABLE
        (
            SourceActivityTypeGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetActivityTypeGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @MilestoneTypeGuidRemap TABLE
        (
            SourceMilestoneTypeGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetMilestoneTypeGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @JobTypeActivityTypeGuidRemap TABLE
        (
            SourceJobTypeActivityTypeGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetJobTypeActivityTypeGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @JobTypeMilestoneTemplateGuidRemap TABLE
        (
            SourceJobTypeMilestoneTemplateGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetJobTypeMilestoneTemplateGuid UNIQUEIDENTIFIER NOT NULL
        );

        DECLARE @ProductGuidRemap TABLE
        (
            SourceProductGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            TargetProductGuid UNIQUEIDENTIFIER NOT NULL
        );

        /* ========================================================================================
           1. Groups
           Match order:
           1) Guid
           2) Code
           3) Name
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.DirectoryId = s.DirectoryId,
               t.Code = s.Code,
               t.Name = s.Name,
               t.Source = s.Source
        FROM SCore.Groups AS t
        INNER JOIN SMigration.Onboarding_Groups AS s
            ON s.GroupGuid = t.Guid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.GroupGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Groups', N'Update', @cnt, N'Updated groups matched by Guid.';

        INSERT INTO @GroupGuidRemap
        (
            SourceGroupGuid,
            TargetGroupGuid
        )
        SELECT
            s.GroupGuid,
            t.Guid
        FROM SMigration.Onboarding_Groups AS s
        INNER JOIN SCore.Groups AS t
            ON t.ID > 0
           AND t.Guid <> s.GroupGuid
           AND
           (
                NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
                AND LOWER(LTRIM(RTRIM(t.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
           )
        WHERE s.RunGuid = @RunGuid
          AND s.GroupGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Groups AS x
              WHERE x.Guid = s.GroupGuid
                AND x.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM @GroupGuidRemap AS m
              WHERE m.SourceGroupGuid = s.GroupGuid
          );

        INSERT INTO @GroupGuidRemap
        (
            SourceGroupGuid,
            TargetGroupGuid
        )
        SELECT
            s.GroupGuid,
            t.Guid
        FROM SMigration.Onboarding_Groups AS s
        INNER JOIN SCore.Groups AS t
            ON t.ID > 0
           AND t.Guid <> s.GroupGuid
           AND LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
        WHERE s.RunGuid = @RunGuid
          AND s.GroupGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Groups AS x
              WHERE x.Guid = s.GroupGuid
                AND x.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM @GroupGuidRemap AS m
              WHERE m.SourceGroupGuid = s.GroupGuid
          );

        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.DirectoryId = s.DirectoryId,
               t.Code = s.Code,
               t.Name = s.Name,
               t.Source = s.Source
        FROM @GroupGuidRemap AS m
        INNER JOIN SMigration.Onboarding_Groups AS s
            ON s.RunGuid = @RunGuid
           AND s.GroupGuid = m.SourceGroupGuid
        INNER JOIN SCore.Groups AS t
            ON t.Guid = m.TargetGroupGuid
           AND t.ID > 0;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Groups', N'Update', @cnt, N'Updated groups matched by Code/Name.';

        DECLARE cur_groups CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.GroupGuid
        FROM SMigration.Onboarding_Groups AS s
        WHERE s.RunGuid = @RunGuid
          AND s.GroupGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Groups AS t
              WHERE t.Guid = s.GroupGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM @GroupGuidRemap AS m
              WHERE m.SourceGroupGuid = s.GroupGuid
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Groups AS t
              WHERE t.ID > 0
                AND
                (
                    (
                        NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
                        AND LOWER(LTRIM(RTRIM(t.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
                    )
                    OR LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
                )
          );

        OPEN cur_groups;
        FETCH NEXT FROM cur_groups INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCore',
                @ObjectName = N'Groups',
                @IncludeDefaultSecurity = 0,
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
                s.RowStatus,
                s.GroupGuid,
                s.DirectoryId,
                s.Code,
                s.Name,
                s.Source
            FROM SMigration.Onboarding_Groups AS s
            WHERE s.RunGuid = @RunGuid
              AND s.GroupGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_groups INTO @Guid;
        END;

        CLOSE cur_groups;
        DEALLOCATE cur_groups;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Groups', N'Insert', @cnt, N'Inserted new groups only.';

        UPDATE ug
           SET ug.GroupGuid = m.TargetGroupGuid
        FROM SMigration.Onboarding_UserGroups AS ug
        INNER JOIN @GroupGuidRemap AS m
            ON m.SourceGroupGuid = ug.GroupGuid
        WHERE ug.RunGuid = @RunGuid;

        UPDATE wsng
           SET wsng.GroupGuid = m.TargetGroupGuid
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS wsng
        INNER JOIN @GroupGuidRemap AS m
            ON m.SourceGroupGuid = wsng.GroupGuid
        WHERE wsng.RunGuid = @RunGuid;

        UPDATE ou
           SET ou.DefaultSecurityGroupGuid = m.TargetGroupGuid
        FROM SMigration.Onboarding_OrganisationalUnits AS ou
        INNER JOIN @GroupGuidRemap AS m
            ON m.SourceGroupGuid = ou.DefaultSecurityGroupGuid
        WHERE ou.RunGuid = @RunGuid;

        /*
           R4 F4 parent OU identity-map foundation.
           A selected source business unit may already exist in the target under a different Guid.
           Resolve that root by: exact OU Guid, mapped/default security group, then a conservative name fallback.
           This lets child OUs map to the existing target parent rather than forcing a same-Guid parent.
        */
        SELECT TOP (1)
            @TargetBusinessUnitGroupGuid = m.TargetGroupGuid
        FROM @GroupGuidRemap AS m
        WHERE m.SourceGroupGuid = @SourceBusinessUnitGroupGuid;

        IF @TargetBusinessUnitGroupGuid IS NULL
           AND EXISTS
           (
               SELECT 1
               FROM SCore.Groups AS existingBusinessUnitGroup
               WHERE existingBusinessUnitGroup.Guid = @SourceBusinessUnitGroupGuid
                 AND existingBusinessUnitGroup.ID > 0
           )
        BEGIN
            SET @TargetBusinessUnitGroupGuid = @SourceBusinessUnitGroupGuid;
        END;

        SELECT TOP (1)
            @SourceBusinessUnitGroupName = sourceBusinessUnitGroup.Name
        FROM SMigration.Onboarding_Groups AS sourceBusinessUnitGroup
        WHERE sourceBusinessUnitGroup.RunGuid = @RunGuid
          AND sourceBusinessUnitGroup.GroupGuid = @SourceBusinessUnitGroupGuid;

        SELECT TOP (1)
            @TargetBusinessUnitOrganisationalUnitGuid = targetBusinessUnitOu.Guid
        FROM SCore.OrganisationalUnits AS targetBusinessUnitOu
        WHERE targetBusinessUnitOu.Guid = @SourceBusinessUnitOrganisationalUnitGuid
          AND targetBusinessUnitOu.ID > 0
        ORDER BY
            CASE WHEN targetBusinessUnitOu.RowStatus NOT IN (0, 254) THEN 0 ELSE 1 END,
            targetBusinessUnitOu.ID;

        IF @TargetBusinessUnitOrganisationalUnitGuid IS NULL
           AND @TargetBusinessUnitGroupGuid IS NOT NULL
           AND @TargetBusinessUnitGroupGuid <> @ZeroGuid
        BEGIN
            SELECT TOP (1)
                @TargetBusinessUnitOrganisationalUnitGuid = targetBusinessUnitOu.Guid
            FROM SCore.OrganisationalUnits AS targetBusinessUnitOu
            INNER JOIN SCore.Groups AS targetBusinessUnitGroup
                ON targetBusinessUnitGroup.ID = targetBusinessUnitOu.DefaultSecurityGroupId
            WHERE targetBusinessUnitGroup.Guid = @TargetBusinessUnitGroupGuid
              AND targetBusinessUnitOu.ID > 0
            ORDER BY
                CASE WHEN targetBusinessUnitOu.RowStatus NOT IN (0, 254) THEN 0 ELSE 1 END,
                targetBusinessUnitOu.ID;
        END;

        IF @TargetBusinessUnitOrganisationalUnitGuid IS NULL
           AND NULLIF(LTRIM(RTRIM(ISNULL(@SourceBusinessUnitGroupName, N''))), N'') IS NOT NULL
        BEGIN
            SELECT TOP (1)
                @TargetBusinessUnitOrganisationalUnitGuid = targetBusinessUnitOu.Guid
            FROM SCore.OrganisationalUnits AS targetBusinessUnitOu
            WHERE targetBusinessUnitOu.ID > 0
              AND LOWER(LTRIM(RTRIM(targetBusinessUnitOu.Name))) = LOWER(LTRIM(RTRIM(@SourceBusinessUnitGroupName)))
            ORDER BY
                CASE WHEN targetBusinessUnitOu.RowStatus NOT IN (0, 254) THEN 0 ELSE 1 END,
                targetBusinessUnitOu.ID;
        END;

        IF @SourceBusinessUnitOrganisationalUnitGuid IS NOT NULL
           AND @SourceBusinessUnitOrganisationalUnitGuid <> @ZeroGuid
           AND @TargetBusinessUnitOrganisationalUnitGuid IS NOT NULL
           AND @TargetBusinessUnitOrganisationalUnitGuid <> @ZeroGuid
        BEGIN
            INSERT INTO @OrganisationalUnitGuidRemap
            (
                SourceOrganisationalUnitGuid,
                TargetOrganisationalUnitGuid
            )
            SELECT
                @SourceBusinessUnitOrganisationalUnitGuid,
                @TargetBusinessUnitOrganisationalUnitGuid
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM @OrganisationalUnitGuidRemap AS existingBusinessUnitMap
                WHERE existingBusinessUnitMap.SourceOrganisationalUnitGuid = @SourceBusinessUnitOrganisationalUnitGuid
            );

            EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'OrganisationalUnits', N'Map', 1, N'Mapped source business unit OU to existing target OU for parent resolution.';
        END;

        /* ========================================================================================
           2. Addresses
           Guid-safe only, with sentinel protection.
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.AddressNumber = s.AddressNumber,
               t.Name = s.Name,
               t.Number = s.Number,
               t.AddressLine1 = s.AddressLine1,
               t.AddressLine2 = s.AddressLine2,
               t.AddressLine3 = s.AddressLine3,
               t.Town = s.Town,
               t.CountyID = c.ID,
               t.Postcode = s.Postcode,
               t.CountryID = co.ID,
               t.LegacySystemID = s.LegacySystemID,
               t.FormattedAddressCR = SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, CHAR(13)),
               t.FormattedAddressComma = SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, N',')
        FROM SCrm.Addresses AS t
        INNER JOIN SMigration.Onboarding_Addresses AS s
            ON s.AddressGuid = t.Guid
        LEFT JOIN SCrm.Counties AS c
            ON c.Guid = s.CountyGuid
        LEFT JOIN SCrm.Countries AS co
            ON co.Guid = s.CountryGuid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.AddressGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Addresses', N'Update', @cnt, N'Updated addresses matched by Guid.';

        DECLARE cur_addr CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.AddressGuid
        FROM SMigration.Onboarding_Addresses AS s
        WHERE s.RunGuid = @RunGuid
          AND s.AddressGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCrm.Addresses AS t
              WHERE t.Guid = s.AddressGuid
                AND t.ID > 0
          );

        OPEN cur_addr;
        FETCH NEXT FROM cur_addr INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCrm',
                @ObjectName = N'Addresses',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SCrm.Addresses
            (
                RowStatus,
                Guid,
                AddressNumber,
                Name,
                Number,
                AddressLine1,
                AddressLine2,
                AddressLine3,
                Town,
                CountyID,
                Postcode,
                CountryID,
                LegacyID,
                FormattedAddressCR,
                FormattedAddressComma,
                LegacySystemID
            )
            SELECT
                s.RowStatus,
                s.AddressGuid,
                s.AddressNumber,
                s.Name,
                s.Number,
                s.AddressLine1,
                s.AddressLine2,
                s.AddressLine3,
                s.Town,
                c.ID,
                s.Postcode,
                co.ID,
                NULL,
                SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, CHAR(13)),
                SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, N','),
                s.LegacySystemID
            FROM SMigration.Onboarding_Addresses AS s
            LEFT JOIN SCrm.Counties AS c
                ON c.Guid = s.CountyGuid
            LEFT JOIN SCrm.Countries AS co
                ON co.Guid = s.CountryGuid
            WHERE s.RunGuid = @RunGuid
              AND s.AddressGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_addr INTO @Guid;
        END;

        CLOSE cur_addr;
        DEALLOCATE cur_addr;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Addresses', N'Insert', @cnt, N'Inserted new addresses only.';

        /* ========================================================================================
           3. Contacts
           Guid-safe only.
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.PrimaryAccountID = a.ID,
               t.PrimaryAddressID = addr.ID,
               t.FirstName = s.FirstName,
               t.Initials = s.Initials,
               t.Surname = s.Surname,
               t.PostNominals = s.PostNominals,
               t.TitleId = tt.ID,
               t.DisplayName = s.DisplayName,
               t.IsPerson = s.IsPerson,
               t.PositionID = p.ID,
               t.LegacySystemID = s.LegacySystemID
        FROM SCrm.Contacts AS t
        INNER JOIN SMigration.Onboarding_Contacts AS s
            ON s.ContactGuid = t.Guid
        LEFT JOIN SCrm.Accounts AS a
            ON a.Guid = s.PrimaryAccountGuid
        INNER JOIN SCrm.Addresses AS addr
            ON addr.Guid = s.PrimaryAddressGuid
        LEFT JOIN SCrm.ContactTitles AS tt
            ON tt.Guid = s.TitleGuid
        LEFT JOIN SCrm.ContactPositions AS p
            ON p.Guid = s.PositionGuid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.ContactGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Contacts', N'Update', @cnt, N'Updated contacts matched by Guid.';

        DECLARE cur_contact CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.ContactGuid
        FROM SMigration.Onboarding_Contacts AS s
        WHERE s.RunGuid = @RunGuid
          AND s.ContactGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCrm.Contacts AS t
              WHERE t.Guid = s.ContactGuid
                AND t.ID > 0
          );

        OPEN cur_contact;
        FETCH NEXT FROM cur_contact INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCrm',
                @ObjectName = N'Contacts',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SCrm.Contacts
            (
                RowStatus,
                Guid,
                PrimaryAccountID,
                PrimaryAddressID,
                FirstName,
                Initials,
                Surname,
                PostNominals,
                TitleId,
                DisplayName,
                IsPerson,
                PositionID,
                LegacyID,
                LegacySystemID
            )
            SELECT
                s.RowStatus,
                s.ContactGuid,
                a.ID,
                addr.ID,
                s.FirstName,
                s.Initials,
                s.Surname,
                s.PostNominals,
                tt.ID,
                s.DisplayName,
                s.IsPerson,
                p.ID,
                NULL,
                s.LegacySystemID
            FROM SMigration.Onboarding_Contacts AS s
            LEFT JOIN SCrm.Accounts AS a
                ON a.Guid = s.PrimaryAccountGuid
            INNER JOIN SCrm.Addresses AS addr
                ON addr.Guid = s.PrimaryAddressGuid
            LEFT JOIN SCrm.ContactTitles AS tt
                ON tt.Guid = s.TitleGuid
            LEFT JOIN SCrm.ContactPositions AS p
                ON p.Guid = s.PositionGuid
            WHERE s.RunGuid = @RunGuid
              AND s.ContactGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_contact INTO @Guid;
        END;

        CLOSE cur_contact;
        DEALLOCATE cur_contact;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Contacts', N'Insert', @cnt, N'Inserted new contacts only.';

        /* ========================================================================================
           4. OrganisationalUnits
           Match order:
           1) Guid
           2) Name
           ======================================================================================== */
        DECLARE cur_ou CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.OrganisationalUnitGuid
        FROM SMigration.Onboarding_OrganisationalUnits AS s
        WHERE s.RunGuid = @RunGuid
          AND s.OrganisationalUnitGuid <> @ZeroGuid
        ORDER BY ISNULL(s.OrgLevel, 0), s.Name;

        OPEN cur_ou;
        FETCH NEXT FROM cur_ou INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE
                @ParentGuid UNIQUEIDENTIFIER,
                @ParentName NVARCHAR(250),
                @ResolvedParentGuid UNIQUEIDENTIFIER,
                @Name NVARCHAR(250),
                @AddressGuid UNIQUEIDENTIFIER,
                @ContactGuid UNIQUEIDENTIFIER,
                @OfficialAddressGuid UNIQUEIDENTIFIER,
                @OfficialContactGuid UNIQUEIDENTIFIER,
                @DepartmentPrefix NVARCHAR(10),
                @CostCentreCode NVARCHAR(50),
                @DefaultSecurityGroupGuid UNIQUEIDENTIFIER,
                @QuoteThreshold DECIMAL(19, 2),
                @ExistingGuid UNIQUEIDENTIFIER,
                @ApplyOuGuid UNIQUEIDENTIFIER;

            SELECT
                @ParentGuid = s.ParentOrganisationalUnitGuid,
                @ParentName = s.ParentOrganisationalUnitName,
                @Name = s.Name,
                @AddressGuid = s.AddressGuid,
                @ContactGuid = s.ContactGuid,
                @OfficialAddressGuid = s.OfficialAddressGuid,
                @OfficialContactGuid = s.OfficialContactGuid,
                @DepartmentPrefix = s.DepartmentPrefix,
                @CostCentreCode = s.CostCentreCode,
                @DefaultSecurityGroupGuid = s.DefaultSecurityGroupGuid,
                @QuoteThreshold = s.QuoteThreshold
            FROM SMigration.Onboarding_OrganisationalUnits AS s
            WHERE s.RunGuid = @RunGuid
              AND s.OrganisationalUnitGuid = @Guid;

            SET @ResolvedParentGuid = @ParentGuid;

            SELECT
                @ResolvedParentGuid = m.TargetOrganisationalUnitGuid
            FROM @OrganisationalUnitGuidRemap AS m
            WHERE m.SourceOrganisationalUnitGuid = @ParentGuid;

            SELECT
                @DefaultSecurityGroupGuid = m.TargetGroupGuid
            FROM @GroupGuidRemap AS m
            WHERE m.SourceGroupGuid = @DefaultSecurityGroupGuid;

            IF @ResolvedParentGuid IS NOT NULL
               AND @ResolvedParentGuid <> @ZeroGuid
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM SCore.OrganisationalUnits AS parentCheck
                   WHERE parentCheck.Guid = @ResolvedParentGuid
                     AND parentCheck.ID > 0
               )
            BEGIN
                DECLARE @StagedParentName NVARCHAR(250) = NULL;

                SELECT TOP (1)
                    @StagedParentName = parentStage.Name
                FROM SMigration.Onboarding_OrganisationalUnits AS parentStage
                WHERE parentStage.RunGuid = @RunGuid
                  AND parentStage.OrganisationalUnitGuid = @ParentGuid;

                SET @StagedParentName = NULLIF(LTRIM(RTRIM(ISNULL(@StagedParentName, N''))), N'');

                IF @StagedParentName IS NULL
                BEGIN
                    SET @StagedParentName = NULLIF(LTRIM(RTRIM(ISNULL(@ParentName, N''))), N'');
                END;

                IF @StagedParentName IS NOT NULL
                BEGIN
                    SELECT TOP (1)
                        @ResolvedParentGuid = targetParent.Guid
                    FROM SCore.OrganisationalUnits AS targetParent
                    WHERE targetParent.ID > 0
                      AND LOWER(LTRIM(RTRIM(targetParent.Name))) = LOWER(LTRIM(RTRIM(@StagedParentName)))
                    ORDER BY
                        CASE WHEN targetParent.RowStatus NOT IN (0, 254) THEN 0 ELSE 1 END,
                        targetParent.ID;

                    IF @ResolvedParentGuid IS NOT NULL
                       AND @ResolvedParentGuid <> @ZeroGuid
                    BEGIN
                        INSERT INTO @OrganisationalUnitGuidRemap
                        (
                            SourceOrganisationalUnitGuid,
                            TargetOrganisationalUnitGuid
                        )
                        SELECT
                            @ParentGuid,
                            @ResolvedParentGuid
                        WHERE NOT EXISTS
                        (
                            SELECT 1
                            FROM @OrganisationalUnitGuidRemap AS existingParentMap
                            WHERE existingParentMap.SourceOrganisationalUnitGuid = @ParentGuid
                        );
                    END;
                END;
            END;

            IF @ResolvedParentGuid IS NOT NULL
               AND @ResolvedParentGuid <> @ZeroGuid
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM SCore.OrganisationalUnits AS parentCheck
                   WHERE parentCheck.Guid = @ResolvedParentGuid
                     AND parentCheck.ID > 0
               )
               AND @ParentGuid = @SourceBusinessUnitOrganisationalUnitGuid
               AND @TargetBusinessUnitOrganisationalUnitGuid IS NOT NULL
               AND @TargetBusinessUnitOrganisationalUnitGuid <> @ZeroGuid
            BEGIN
                SET @ResolvedParentGuid = @TargetBusinessUnitOrganisationalUnitGuid;
            END;

            SET @ExistingGuid = NULL;

            SELECT TOP (1)
                @ExistingGuid = ou.Guid
            FROM SCore.OrganisationalUnits AS ou
            WHERE ou.Guid = @Guid
              AND ou.ID > 0;

            IF @ExistingGuid IS NULL
            BEGIN
                SELECT TOP (1)
                    @ExistingGuid = ou.Guid
                FROM SCore.OrganisationalUnits AS ou
                WHERE ou.ID > 0
                  AND LOWER(LTRIM(RTRIM(ou.Name))) = LOWER(LTRIM(RTRIM(@Name)))
                ORDER BY
                    CASE WHEN ou.RowStatus NOT IN (0, 254) THEN 0 ELSE 1 END,
                    ou.ID;
            END;

            SET @ApplyOuGuid = ISNULL(@ExistingGuid, @Guid);

            IF @ExistingGuid IS NOT NULL
               AND @ExistingGuid <> @Guid
            BEGIN
                INSERT INTO @OrganisationalUnitGuidRemap
                (
                    SourceOrganisationalUnitGuid,
                    TargetOrganisationalUnitGuid
                )
                SELECT
                    @Guid,
                    @ExistingGuid
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM @OrganisationalUnitGuidRemap AS x
                    WHERE x.SourceOrganisationalUnitGuid = @Guid
                );
            END;

            IF @ExistingGuid IS NULL
               AND
               (
                   @ResolvedParentGuid IS NULL
                   OR @ResolvedParentGuid = @ZeroGuid
                   OR NOT EXISTS
                   (
                       SELECT 1
                       FROM SCore.OrganisationalUnits AS parentCheck
                       WHERE parentCheck.Guid = @ResolvedParentGuid
                         AND parentCheck.ID > 0
                   )
               )
            BEGIN
                DECLARE @ParentResolutionMessage NVARCHAR(2048);

                SET @ParentResolutionMessage = CONCAT(
                    N'Unable to apply OrganisationalUnit "', ISNULL(@Name, N''),
                    N'" because its parent organisational unit could not be resolved in the target database. Source parent Guid: ',
                    CONVERT(NVARCHAR(36), ISNULL(@ParentGuid, @ZeroGuid)),
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(ISNULL(@ParentName, N''))), N'') IS NULL THEN N''
                        ELSE CONCAT(N'. Source parent Name: ', @ParentName)
                    END,
                    N'. Restage this run if the source parent name is missing, select/include the parent OU in this run, or ensure the target has a matching parent OU/default security group mapping before applying.'
                );

                THROW 62431, @ParentResolutionMessage, 1;
            END;

            IF @ExistingGuid IS NULL
               AND EXISTS
               (
                   SELECT 1
                   FROM SCore.DataObjects AS dataObject
                   WHERE dataObject.Guid = @ApplyOuGuid
               )
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM SCore.OrganisationalUnits AS existingOu
                   WHERE existingOu.Guid = @ApplyOuGuid
               )
            BEGIN
                DECLARE
                    @RepairParentId INT,
                    @RepairParentOrgNode HIERARCHYID,
                    @RepairLastChild HIERARCHYID,
                    @RepairNewOrgNode HIERARCHYID,
                    @RepairAddressId INT,
                    @RepairContactId INT,
                    @RepairOfficialAddressId INT,
                    @RepairOfficialContactId INT,
                    @RepairDefaultSecurityGroupId INT;

                SELECT
                    @RepairParentId = parentOu.ID,
                    @RepairParentOrgNode = parentOu.OrgNode
                FROM SCore.OrganisationalUnits AS parentOu
                WHERE parentOu.Guid = @ResolvedParentGuid
                  AND parentOu.ID > 0;

                IF @RepairParentId IS NULL OR @RepairParentOrgNode IS NULL
                BEGIN
                    DECLARE @RepairParentResolutionMessage NVARCHAR(2048);

                    SET @RepairParentResolutionMessage = CONCAT(
                        N'Unable to repair orphan OrganisationalUnit DataObject for "', ISNULL(@Name, N''),
                        N'" because the parent organisational unit could not be resolved in the target database. Source parent Guid: ',
                        CONVERT(NVARCHAR(36), ISNULL(@ParentGuid, @ZeroGuid)),
                        N'. Select/include the parent OU in this run, or ensure the target has a matching parent OU/default security group mapping before applying.'
                    );

                    THROW 62430, @RepairParentResolutionMessage, 1;
                END;

                SELECT @RepairAddressId = addr.ID
                FROM SCrm.Addresses AS addr
                WHERE addr.Guid = @AddressGuid;

                SELECT @RepairContactId = contact.ID
                FROM SCrm.Contacts AS contact
                WHERE contact.Guid = @ContactGuid;

                SELECT @RepairOfficialAddressId = addr.ID
                FROM SCrm.Addresses AS addr
                WHERE addr.Guid = @OfficialAddressGuid;

                SELECT @RepairOfficialContactId = contact.ID
                FROM SCrm.Contacts AS contact
                WHERE contact.Guid = @OfficialContactGuid;

                SELECT @RepairDefaultSecurityGroupId = grp.ID
                FROM SCore.Groups AS grp
                WHERE grp.Guid = @DefaultSecurityGroupGuid;

                SELECT @RepairLastChild = MAX(childOu.OrgNode)
                FROM SCore.OrganisationalUnits AS childOu
                WHERE childOu.OrgNode.GetAncestor(1) = @RepairParentOrgNode;

                SET @RepairNewOrgNode = @RepairParentOrgNode.GetDescendant(@RepairLastChild, NULL);

                INSERT INTO SCore.OrganisationalUnits
                (
                    RowStatus,
                    Guid,
                    Name,
                    AddressId,
                    ContactId,
                    OfficialAddressId,
                    OfficialContactId,
                    DepartmentPrefix,
                    CostCentreCode,
                    DefaultSecurityGroupId,
                    ParentID,
                    OrgNode,
                    QuoteThreshold
                )
                VALUES
                (
                    1,
                    @ApplyOuGuid,
                    @Name,
                    @RepairAddressId,
                    @RepairContactId,
                    @RepairOfficialAddressId,
                    @RepairOfficialContactId,
                    @DepartmentPrefix,
                    @CostCentreCode,
                    @RepairDefaultSecurityGroupId,
                    @RepairParentId,
                    @RepairNewOrgNode,
                    @QuoteThreshold
                );

                EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'OrganisationalUnits', N'RepairInsert', 1, N'Repaired an orphan DataObject by inserting the missing OrganisationalUnit row.';
            END
            ELSE
            BEGIN
                EXEC SCore.OrganisationalUnitsUpsert
                    @ParentOrganisationalUnitGuid = @ResolvedParentGuid,
                    @Name = @Name,
                    @AddressGuid = @AddressGuid,
                    @ContactGuid = @ContactGuid,
                    @OfficialAddressGuid = @OfficialAddressGuid,
                    @OfficialContactGuid = @OfficialContactGuid,
                    @DepartmentPrefix = @DepartmentPrefix,
                    @CostCentreCode = @CostCentreCode,
                    @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,
                    @Guid = @ApplyOuGuid OUTPUT,
                    @QuoteThreshold = @QuoteThreshold;
            END;

            SET @cnt += 1;

            FETCH NEXT FROM cur_ou INTO @Guid;
        END;

        CLOSE cur_ou;
        DEALLOCATE cur_ou;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'OrganisationalUnits', N'Upsert', @cnt, N'Applied Guid/name-safe OU upserts.';

        UPDATE i
           SET i.OrganisationalUnitGuid = m.TargetOrganisationalUnitGuid
        FROM SMigration.Onboarding_Identities AS i
        INNER JOIN @OrganisationalUnitGuidRemap AS m
            ON m.SourceOrganisationalUnitGuid = i.OrganisationalUnitGuid
        WHERE i.RunGuid = @RunGuid;

        UPDATE jt
           SET jt.OrganisationalUnitGuid = m.TargetOrganisationalUnitGuid
        FROM SMigration.Onboarding_JobTypes AS jt
        INNER JOIN @OrganisationalUnitGuidRemap AS m
            ON m.SourceOrganisationalUnitGuid = jt.OrganisationalUnitGuid
        WHERE jt.RunGuid = @RunGuid;

        /* ========================================================================================
           5. Identities
           Match order:
           1) Guid
           2) EmailAddress, trimmed/case-insensitive
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.FullName = s.FullName,
               t.EmailAddress = s.EmailAddress,
               t.UserGuid = s.UserGuid,
               t.JobTitle = s.JobTitle,
               t.OriganisationalUnitId = ou.ID,
               t.IsActive = s.IsActive,
               t.ContactId = c.ID,
               t.BillableRate = s.BillableRate,
               t.Signature = s.Signature
        FROM SCore.Identities AS t
        INNER JOIN SMigration.Onboarding_Identities AS s
            ON s.IdentityGuid = t.Guid
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        INNER JOIN SCrm.Contacts AS c
            ON c.Guid = s.ContactGuid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.IdentityGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Identities', N'Update', @cnt, N'Updated identities matched by Guid.';

        ;WITH EmailMatches AS
        (
            SELECT
                s.IdentityGuid AS SourceIdentityGuid,
                t.Guid AS TargetIdentityGuid,
                ROW_NUMBER() OVER
                (
                    PARTITION BY s.IdentityGuid
                    ORDER BY
                        CASE WHEN t.RowStatus NOT IN (0, 254) THEN 0 ELSE 1 END,
                        t.ID
                ) AS MatchRank
            FROM SMigration.Onboarding_Identities AS s
            INNER JOIN SCore.Identities AS t
                ON t.ID > 0
               AND LOWER(LTRIM(RTRIM(t.EmailAddress))) = LOWER(LTRIM(RTRIM(s.EmailAddress)))
            WHERE s.RunGuid = @RunGuid
              AND s.IdentityGuid <> @ZeroGuid
              AND NULLIF(LTRIM(RTRIM(s.EmailAddress)), N'') IS NOT NULL
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SCore.Identities AS x
                  WHERE x.Guid = s.IdentityGuid
                    AND x.ID > 0
              )
        )
        INSERT INTO @IdentityGuidRemap
        (
            SourceIdentityGuid,
            TargetIdentityGuid
        )
        SELECT
            em.SourceIdentityGuid,
            em.TargetIdentityGuid
        FROM EmailMatches AS em
        WHERE em.MatchRank = 1;

        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.FullName = s.FullName,
               t.EmailAddress = s.EmailAddress,
               t.UserGuid = s.UserGuid,
               t.JobTitle = s.JobTitle,
               t.OriganisationalUnitId = ou.ID,
               t.IsActive = s.IsActive,
               t.ContactId = c.ID,
               t.BillableRate = s.BillableRate,
               t.Signature = s.Signature
        FROM @IdentityGuidRemap AS m
        INNER JOIN SMigration.Onboarding_Identities AS s
            ON s.RunGuid = @RunGuid
           AND s.IdentityGuid = m.SourceIdentityGuid
        INNER JOIN SCore.Identities AS t
            ON t.Guid = m.TargetIdentityGuid
           AND t.ID > 0
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        INNER JOIN SCrm.Contacts AS c
            ON c.Guid = s.ContactGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Identities', N'Update', @cnt, N'Updated identities matched by EmailAddress.';

        UPDATE ug
           SET ug.IdentityGuid = m.TargetIdentityGuid
        FROM SMigration.Onboarding_UserGroups AS ug
        INNER JOIN @IdentityGuidRemap AS m
            ON m.SourceIdentityGuid = ug.IdentityGuid
        WHERE ug.RunGuid = @RunGuid;

        DECLARE cur_ident CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.IdentityGuid
        FROM SMigration.Onboarding_Identities AS s
        WHERE s.RunGuid = @RunGuid
          AND s.IdentityGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Identities AS t
              WHERE t.Guid = s.IdentityGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Identities AS t
              WHERE t.ID > 0
                AND NULLIF(LTRIM(RTRIM(s.EmailAddress)), N'') IS NOT NULL
                AND LOWER(LTRIM(RTRIM(t.EmailAddress))) = LOWER(LTRIM(RTRIM(s.EmailAddress)))
          );

        OPEN cur_ident;
        FETCH NEXT FROM cur_ident INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE
                @FullName NVARCHAR(250),
                @EmailAddress NVARCHAR(150),
                @UserGuid UNIQUEIDENTIFIER,
                @JobTitle NVARCHAR(50),
                @OUguid UNIQUEIDENTIFIER,
                @IsActive BIT,
                @ContactGuid2 UNIQUEIDENTIFIER,
                @BillableRate DECIMAL(19, 2),
                @Signature VARBINARY(MAX),
                @RowsInserted INT,
                @NewIdentityId INT;

            SELECT
                @FullName = s.FullName,
                @EmailAddress = s.EmailAddress,
                @UserGuid = s.UserGuid,
                @JobTitle = s.JobTitle,
                @OUguid = s.OrganisationalUnitGuid,
                @IsActive = s.IsActive,
                @ContactGuid2 = s.ContactGuid,
                @BillableRate = s.BillableRate,
                @Signature = s.Signature
            FROM SMigration.Onboarding_Identities AS s
            WHERE s.RunGuid = @RunGuid
              AND s.IdentityGuid = @Guid;

            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCore',
                @ObjectName = N'Identities',
                @IncludeDefaultSecurity = 0,
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
                1,
                @Guid,
                @FullName,
                @EmailAddress,
                @UserGuid,
                @JobTitle,
                ou.ID,
                @IsActive,
                c.ID,
                @BillableRate,
                @Signature
            FROM SCore.OrganisationalUnits AS ou
            INNER JOIN SCrm.Contacts AS c
                ON c.Guid = @ContactGuid2
            WHERE ou.Guid = @OUguid;

            SET @RowsInserted = @@ROWCOUNT;
            SET @cnt += @RowsInserted;

            IF @RowsInserted > 0
            BEGIN
                SELECT
                    @NewIdentityId = i.ID
                FROM SCore.Identities AS i
                WHERE i.Guid = @Guid;

                IF @NewIdentityId IS NOT NULL
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM SCore.UserPreferences AS up
                       WHERE up.ID = @NewIdentityId
                   )
                BEGIN
                    INSERT INTO SCore.UserPreferences
                    (
                        ID,
                        Guid,
                        RowStatus,
                        SystemLanguageID,
                        WidgetLayout,
                        OutlookSettings
                    )
                    VALUES
                    (
                        @NewIdentityId,
                        @Guid,
                        1,
                        1,
                        N'{"ItemStates": []}',
                        N'{}'
                    );
                END;
            END;

            FETCH NEXT FROM cur_ident INTO @Guid;
        END;

        CLOSE cur_ident;
        DEALLOCATE cur_ident;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'Identities', N'Insert', @cnt, N'Inserted new identities only.';

        /* Ensure all active identities have required 1:1 UserPreferences rows */
        INSERT INTO SCore.UserPreferences
        (
            ID,
            Guid,
            RowStatus,
            SystemLanguageID,
            WidgetLayout,
            OutlookSettings
        )
        SELECT
            i.ID,
            i.Guid,
            1,
            1,
            N'{"ItemStates": []}',
            N'{}'
        FROM SCore.Identities AS i
        WHERE i.ID > 0
          AND i.RowStatus NOT IN (0,254)
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.UserPreferences AS up
              WHERE up.ID = i.ID
          );

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'UserPreferences',
            N'Insert',
            @cnt,
            N'Inserted missing UserPreferences rows for staged identities.';

        /* ========================================================================================
           6. UserGroups
           Natural key: IdentityID + GroupID + RowStatus.

           Rules:
           - Ignore sentinel GUID rows.
           - Resolve staged IdentityGuid and GroupGuid before comparing.
           - Do not update a Guid-matched row into a natural-key duplicate.
           - Do not insert if another row already owns IdentityID + GroupID + RowStatus.
           - Create SCore.DataObjects only for true insert candidates.
           ======================================================================================== */

        DECLARE @UserGroupInsertCandidates TABLE
        (
            UserGroupGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            RowStatus INT NOT NULL,
            IdentityID INT NOT NULL,
            GroupID INT NOT NULL
        );

        ;WITH SourceUserGroups AS
        (
            SELECT
                s.UserGroupGuid,
                s.RowStatus,
                i.ID AS IdentityID,
                g.ID AS GroupID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY i.ID, g.ID, s.RowStatus
                    ORDER BY s.UserGroupGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_UserGroups AS s
            INNER JOIN SCore.Identities AS i
                ON i.Guid = s.IdentityGuid
               AND i.ID > 0
            INNER JOIN SCore.Groups AS g
                ON g.Guid = s.GroupGuid
               AND g.ID > 0
            WHERE s.RunGuid = @RunGuid
              AND s.UserGroupGuid <> @ZeroGuid
        )
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.IdentityID = s.IdentityID,
               t.GroupID = s.GroupID
        FROM SCore.UserGroups AS t
        INNER JOIN SourceUserGroups AS s
            ON s.UserGroupGuid = t.Guid
        WHERE t.ID > 0
          AND s.NaturalRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.UserGroups AS x
              WHERE x.ID <> t.ID
                AND x.IdentityID = s.IdentityID
                AND x.GroupID = s.GroupID
                AND x.RowStatus = s.RowStatus
          );

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'UserGroups',
            N'Update',
            @cnt,
            N'Updated user groups matched by Guid where no natural-key collision exists.';

        ;WITH SourceUserGroups AS
        (
            SELECT
                s.UserGroupGuid,
                s.RowStatus,
                i.ID AS IdentityID,
                g.ID AS GroupID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY i.ID, g.ID, s.RowStatus
                    ORDER BY s.UserGroupGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_UserGroups AS s
            INNER JOIN SCore.Identities AS i
                ON i.Guid = s.IdentityGuid
               AND i.ID > 0
            INNER JOIN SCore.Groups AS g
                ON g.Guid = s.GroupGuid
               AND g.ID > 0
            WHERE s.RunGuid = @RunGuid
              AND s.UserGroupGuid <> @ZeroGuid
        )
        INSERT INTO @UserGroupInsertCandidates
        (
            UserGroupGuid,
            RowStatus,
            IdentityID,
            GroupID
        )
        SELECT
            s.UserGroupGuid,
            s.RowStatus,
            s.IdentityID,
            s.GroupID
        FROM SourceUserGroups AS s
        WHERE s.NaturalRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.UserGroups AS t
              WHERE t.Guid = s.UserGroupGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.UserGroups AS t
              WHERE t.IdentityID = s.IdentityID
                AND t.GroupID = s.GroupID
                AND t.RowStatus = s.RowStatus
          );

        /*
           Guard against target identity-seed drift before inserting SCore.UserGroups.
           Some environments contain user-created rows whose ID is higher than the current
           identity seed. SQL Server would otherwise attempt to allocate an existing ID and
           fail with PK_UserGroups even though the staged natural key is not a duplicate.
        */
        DECLARE @MaxUserGroupIdentityValue INT;

        SELECT
            @MaxUserGroupIdentityValue = ISNULL(MAX(targetUserGroup.ID), 0)
        FROM SCore.UserGroups AS targetUserGroup WITH (HOLDLOCK);

        DBCC CHECKIDENT (N'SCore.UserGroups', RESEED, @MaxUserGroupIdentityValue) WITH NO_INFOMSGS;

        DECLARE cur_ug CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            c.UserGroupGuid
        FROM @UserGroupInsertCandidates AS c;

        OPEN cur_ug;
        FETCH NEXT FROM cur_ug INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCore',
                @ObjectName = N'UserGroups',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            FETCH NEXT FROM cur_ug INTO @Guid;
        END;

        CLOSE cur_ug;
        DEALLOCATE cur_ug;

        INSERT INTO SCore.UserGroups
        (
            Guid,
            RowStatus,
            IdentityID,
            GroupID
        )
        SELECT
            c.UserGroupGuid,
            c.RowStatus,
            c.IdentityID,
            c.GroupID
        FROM @UserGroupInsertCandidates AS c
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.UserGroups AS t
            WHERE t.Guid = c.UserGroupGuid
              AND t.ID > 0
        )
          AND NOT EXISTS
        (
            SELECT 1
            FROM SCore.UserGroups AS t
            WHERE t.IdentityID = c.IdentityID
              AND t.GroupID = c.GroupID
              AND t.RowStatus = c.RowStatus
        );

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'UserGroups',
            N'Insert',
            @cnt,
            N'Inserted distinct missing user groups only.';

/* ========================================================================================
   7. Workflows
   Match order:
   1) Guid
   2) Name, trimmed/case-insensitive
   3) Insert true missing workflow

   Required before WorkflowStatusNotificationGroups.
   ======================================================================================== */
        UPDATE t
        SET
            t.RowStatus = s.RowStatus,
            t.OrganisationalUnitId = ou.ID,
            t.EntityTypeID = et.ID,
            t.EntityHoBTID = eh.ID,
            t.Name = s.Name,
            t.Description = s.Description,
            t.Enabled = s.Enabled
        FROM SCore.Workflow AS t
        INNER JOIN SMigration.Onboarding_Workflows AS s
            ON s.WorkflowGuid = t.Guid
           AND t.ID > 0
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        INNER JOIN SCore.EntityTypes AS et
            ON et.Guid = s.EntityTypeGuid
        LEFT JOIN SCore.EntityHobts AS eh
            ON eh.Guid = s.EntityHoBTGuid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.WorkflowGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'Workflows',
            N'Update',
            @cnt,
            N'Updated workflows matched by Guid.';

        ;WITH NameMatches AS
        (
            SELECT
                s.WorkflowGuid AS SourceWorkflowGuid,
                t.Guid AS TargetWorkflowGuid,
                ROW_NUMBER() OVER
                (
                    PARTITION BY s.WorkflowGuid
                    ORDER BY
                        CASE WHEN t.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END,
                        t.ID
                ) AS MatchRank
            FROM SMigration.Onboarding_Workflows AS s
            INNER JOIN SCore.Workflow AS t
                ON LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
               AND t.ID > 0
            WHERE s.RunGuid = @RunGuid
              AND s.WorkflowGuid <> @ZeroGuid
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SCore.Workflow AS x
                  WHERE x.Guid = s.WorkflowGuid
                    AND x.ID > 0
              )
        )
        INSERT INTO @WorkflowGuidRemap
        (
            SourceWorkflowGuid,
            TargetWorkflowGuid
        )
        SELECT
            nm.SourceWorkflowGuid,
            nm.TargetWorkflowGuid
        FROM NameMatches AS nm
        WHERE nm.MatchRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM @WorkflowGuidRemap AS x
              WHERE x.SourceWorkflowGuid = nm.SourceWorkflowGuid
          );

         UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.OrganisationalUnitId = ou.ID,
               t.EntityTypeID = et.ID,
               t.EntityHoBTID = eh.ID,
               t.Name = s.Name,
               t.Description = s.Description,
               t.Enabled = s.Enabled
        FROM @WorkflowGuidRemap AS m
        INNER JOIN SMigration.Onboarding_Workflows AS s
            ON s.RunGuid = @RunGuid
           AND s.WorkflowGuid = m.SourceWorkflowGuid
        INNER JOIN SCore.Workflow AS t
            ON t.Guid = m.TargetWorkflowGuid
           AND t.ID > 0
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        INNER JOIN SCore.EntityTypes AS et
            ON et.Guid = s.EntityTypeGuid
        LEFT JOIN SCore.EntityHobts AS eh
            ON eh.Guid = s.EntityHoBTGuid;

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'Workflows',
            N'Update',
            @cnt,
            N'Updated workflows matched by Name.';

        /* Remap staged notification groups to resolved workflow Guid */
        UPDATE wsng
           SET wsng.WorkflowGuid = m.TargetWorkflowGuid
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS wsng
        INNER JOIN @WorkflowGuidRemap AS m
            ON m.SourceWorkflowGuid = wsng.WorkflowGuid
        WHERE wsng.RunGuid = @RunGuid;

        UPDATE wt
           SET wt.WorkflowGuid = m.TargetWorkflowGuid
        FROM SMigration.Onboarding_WorkflowTransitions AS wt
        INNER JOIN @WorkflowGuidRemap AS m
            ON m.SourceWorkflowGuid = wt.WorkflowGuid
        WHERE wt.RunGuid = @RunGuid;

        /* True inserts only */
        DECLARE cur_workflows CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.WorkflowGuid
        FROM SMigration.Onboarding_Workflows AS s
        WHERE s.RunGuid = @RunGuid
          AND s.WorkflowGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Workflow AS t
              WHERE t.Guid = s.WorkflowGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.Workflow AS t
              WHERE t.ID > 0
                AND LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
          );

        OPEN cur_workflows;
        FETCH NEXT FROM cur_workflows INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCore',
                @ObjectName = N'Workflow',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SCore.Workflow
            (
                RowStatus,
                Guid,
                OrganisationalUnitId,
                EntityTypeID,
                EntityHoBTID,
                Name,
                Description,
                Enabled
            )
            SELECT
                s.RowStatus,
                s.WorkflowGuid,
                ou.ID,
                et.ID,
                eh.ID,
                s.Name,
                s.Description,
                s.Enabled
            FROM SMigration.Onboarding_Workflows AS s
            INNER  JOIN SCore.OrganisationalUnits AS ou
                ON ou.Guid = s.OrganisationalUnitGuid
            INNER  JOIN SCore.EntityTypes AS et
                ON et.Guid = s.EntityTypeGuid
            LEFT JOIN SCore.EntityHobts AS eh
                ON eh.Guid = s.EntityHoBTGuid
            WHERE s.RunGuid = @RunGuid
                AND s.WorkflowGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_workflows INTO @Guid;
        END;

        CLOSE cur_workflows;
        DEALLOCATE cur_workflows;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'Workflows',
            N'Insert',
            @cnt,
            N'Inserted new workflows only.';

            /* ========================================================================================
           WorkflowTransitions
           ======================================================================================== */

        UPDATE t
        SET
            t.RowStatus = s.RowStatus,
            t.WorkflowID = wf.ID,
            t.FromStatusID = ISNULL(fromWs.ID, -1),
            t.ToStatusID = ISNULL(toWs.ID, -1),
            t.IsFinal = s.IsFinal,
            t.Enabled = s.Enabled,
            t.SortOrder = s.SortOrder,
            t.Description = s.Description
        FROM SCore.WorkflowTransition AS t
        INNER JOIN SMigration.Onboarding_WorkflowTransitions AS s
            ON s.WorkflowTransitionGuid = t.Guid
        INNER JOIN SCore.Workflow AS wf
            ON wf.Guid = s.WorkflowGuid
        LEFT JOIN SCore.WorkflowStatus AS fromWs
            ON fromWs.Guid = s.FromStatusGuid
           AND s.FromStatusGuid <> @ZeroGuid
        LEFT JOIN SCore.WorkflowStatus AS toWs
            ON toWs.Guid = s.ToStatusGuid
           AND s.ToStatusGuid <> @ZeroGuid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.WorkflowTransitionGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'WorkflowTransitions',
            N'Update',
            @cnt,
            N'Updated workflow transitions matched by Guid.';

        DECLARE cur_workflow_transitions CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.WorkflowTransitionGuid
        FROM SMigration.Onboarding_WorkflowTransitions AS s
        WHERE s.RunGuid = @RunGuid
          AND s.WorkflowTransitionGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.WorkflowTransition AS t
              WHERE t.Guid = s.WorkflowTransitionGuid
                AND t.ID > 0
          );

        OPEN cur_workflow_transitions;
        FETCH NEXT FROM cur_workflow_transitions INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCore',
                @ObjectName = N'WorkflowTransition',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SCore.WorkflowTransition
            (
                RowStatus,
                Guid,
                WorkflowID,
                FromStatusID,
                ToStatusID,
                IsFinal,
                Enabled,
                SortOrder,
                Description
            )
            SELECT
                s.RowStatus,
                s.WorkflowTransitionGuid,
                wf.ID,
                ISNULL(fromWs.ID, -1),
                ISNULL(toWs.ID, -1),
                s.IsFinal,
                s.Enabled,
                s.SortOrder,
                s.Description
            FROM SMigration.Onboarding_WorkflowTransitions AS s
            INNER JOIN SCore.Workflow AS wf
                ON wf.Guid = s.WorkflowGuid
            LEFT JOIN SCore.WorkflowStatus AS fromWs
                ON fromWs.Guid = s.FromStatusGuid
               AND s.FromStatusGuid <> @ZeroGuid
            LEFT JOIN SCore.WorkflowStatus AS toWs
                ON toWs.Guid = s.ToStatusGuid
               AND s.ToStatusGuid <> @ZeroGuid
            WHERE s.RunGuid = @RunGuid
              AND s.WorkflowTransitionGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_workflow_transitions INTO @Guid;
        END;

        CLOSE cur_workflow_transitions;
        DEALLOCATE cur_workflow_transitions;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'WorkflowTransitions',
            N'Insert',
            @cnt,
            N'Inserted missing workflow transitions.';


        DECLARE cur_wsng CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.WorkflowNotificationGroupGuid
        FROM
        (
            SELECT
                s.WorkflowNotificationGroupGuid,
                s.RowStatus,
                wf.ID AS WorkflowID,
                s.WorkflowStatusGuid,
                g.ID AS GroupID,
                s.CanAction,
                ROW_NUMBER() OVER
                (
                    PARTITION BY wf.ID, s.WorkflowStatusGuid, g.ID
                    ORDER BY s.WorkflowNotificationGroupGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS s
            INNER JOIN SCore.Workflow AS wf
                ON wf.Guid = s.WorkflowGuid
            INNER JOIN SCore.Groups AS g
                ON g.Guid = s.GroupGuid
            WHERE s.RunGuid = @RunGuid
              AND s.WorkflowNotificationGroupGuid <> @ZeroGuid
        ) AS src
        WHERE src.NaturalRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.WorkflowStatusNotificationGroups AS t
              WHERE t.Guid = src.WorkflowNotificationGroupGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
            (
                SELECT 1
                FROM SCore.WorkflowStatusNotificationGroups AS t
                WHERE t.WorkflowID = src.WorkflowID
                  AND t.WorkflowStatusGuid = src.WorkflowStatusGuid
                  AND t.GroupID = src.GroupID
                  AND t.RowStatus NOT IN (0, 254)
            );

        OPEN cur_wsng;
        FETCH NEXT FROM cur_wsng INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SCore',
                @ObjectName = N'WorkflowStatusNotificationGroups',
                @IncludeDefaultSecurity = 0,
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
                s.RowStatus,
                s.WorkflowNotificationGroupGuid,
                wf.ID,
                s.WorkflowStatusGuid,
                g.ID,
                s.CanAction
            FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS s
            INNER JOIN SCore.Workflow AS wf
                ON wf.Guid = s.WorkflowGuid
            INNER JOIN SCore.Groups AS g
                ON g.Guid = s.GroupGuid
            WHERE s.RunGuid = @RunGuid
              AND s.WorkflowNotificationGroupGuid = @Guid
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SCore.WorkflowStatusNotificationGroups AS x
                  WHERE x.WorkflowID = wf.ID
                    AND x.WorkflowStatusGuid = s.WorkflowStatusGuid
                    AND x.GroupID = g.ID
                    AND x.RowStatus NOT IN (0, 254)
              );

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_wsng INTO @Guid;
        END;

        CLOSE cur_wsng;
        DEALLOCATE cur_wsng;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'WorkflowStatusNotificationGroups', N'Insert', @cnt, N'Inserted distinct missing workflow notification groups only.';


        /* ========================================================================================
           8. JobTypes
           Match order:
           1) Guid
           2) Name + OrganisationalUnitID
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.Name = s.Name,
               t.IsActive = s.IsActive,
               t.SequenceID = s.SequenceID,
               t.UseTimeSheets = s.UseTimeSheets,
               t.UsePlanChecks = s.UsePlanChecks,
               t.OrganisationalUnitID = ou.ID
        FROM SJob.JobTypes AS t
        INNER JOIN SMigration.Onboarding_JobTypes AS s
            ON s.JobTypeGuid = t.Guid
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.JobTypeGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypes', N'Update', @cnt, N'Updated job types matched by Guid.';

        INSERT INTO @JobTypeGuidRemap
        (
            SourceJobTypeGuid,
            TargetJobTypeGuid
        )
        SELECT
            s.JobTypeGuid,
            t.Guid
        FROM SMigration.Onboarding_JobTypes AS s
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        INNER JOIN SJob.JobTypes AS t
            ON t.ID > 0
           AND t.Guid <> s.JobTypeGuid
           AND LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
           AND t.OrganisationalUnitID = ou.ID
        WHERE s.RunGuid = @RunGuid
          AND s.JobTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypes AS x
              WHERE x.Guid = s.JobTypeGuid
                AND x.ID > 0
          );

        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.Name = s.Name,
               t.IsActive = s.IsActive,
               t.SequenceID = s.SequenceID,
               t.UseTimeSheets = s.UseTimeSheets,
               t.UsePlanChecks = s.UsePlanChecks,
               t.OrganisationalUnitID = ou.ID
        FROM @JobTypeGuidRemap AS m
        INNER JOIN SMigration.Onboarding_JobTypes AS s
            ON s.RunGuid = @RunGuid
           AND s.JobTypeGuid = m.SourceJobTypeGuid
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        INNER JOIN SJob.JobTypes AS t
            ON t.Guid = m.TargetJobTypeGuid
           AND t.ID > 0;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypes', N'Update', @cnt, N'Updated job types matched by Name/OU.';

        UPDATE jtat
           SET jtat.JobTypeGuid = m.TargetJobTypeGuid
        FROM SMigration.Onboarding_JobTypeActivityTypes AS jtat
        INNER JOIN @JobTypeGuidRemap AS m
            ON m.SourceJobTypeGuid = jtat.JobTypeGuid
        WHERE jtat.RunGuid = @RunGuid;

        UPDATE jtmt
           SET jtmt.JobTypeGuid = m.TargetJobTypeGuid
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS jtmt
        INNER JOIN @JobTypeGuidRemap AS m
            ON m.SourceJobTypeGuid = jtmt.JobTypeGuid
        WHERE jtmt.RunGuid = @RunGuid;

        UPDATE p
           SET p.CreatedJobTypeGuid = m.TargetJobTypeGuid
        FROM SMigration.Onboarding_Products AS p
        INNER JOIN @JobTypeGuidRemap AS m
            ON m.SourceJobTypeGuid = p.CreatedJobTypeGuid
        WHERE p.RunGuid = @RunGuid;

        DECLARE cur_jt CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.JobTypeGuid
        FROM SMigration.Onboarding_JobTypes AS s
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.Guid = s.OrganisationalUnitGuid
        WHERE s.RunGuid = @RunGuid
          AND s.JobTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypes AS t
              WHERE t.Guid = s.JobTypeGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypes AS t
              WHERE t.ID > 0
                AND LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
                AND t.OrganisationalUnitID = ou.ID
          );

        OPEN cur_jt;
        FETCH NEXT FROM cur_jt INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SJob',
                @ObjectName = N'JobTypes',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SJob.JobTypes
            (
                RowStatus,
                Guid,
                Name,
                IsActive,
                SequenceID,
                UseTimeSheets,
                UsePlanChecks,
                OrganisationalUnitID
            )
            SELECT
                s.RowStatus,
                s.JobTypeGuid,
                s.Name,
                s.IsActive,
                s.SequenceID,
                s.UseTimeSheets,
                s.UsePlanChecks,
                ou.ID
            FROM SMigration.Onboarding_JobTypes AS s
            INNER JOIN SCore.OrganisationalUnits AS ou
                ON ou.Guid = s.OrganisationalUnitGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_jt INTO @Guid;
        END;

        CLOSE cur_jt;
        DEALLOCATE cur_jt;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypes', N'Insert', @cnt, N'Inserted new job types only.';


        /* ========================================================================================
           9. ActivityTypes
           Match order:
           1) Guid
           2) Name
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.Name = s.Name,
               t.IsActive = s.IsActive,
               t.SortOrder = s.SortOrder,
               t.IsFeeTrigger = s.IsFeeTrigger,
               t.IsLiveTrigger = s.IsLiveTrigger,
               t.IsAdmin = s.IsAdmin,
               t.IsScheduleItem = s.IsScheduleItem,
               t.Colour = s.Colour,
               t.IsMeeting = s.IsMeeting,
               t.IsSiteVisit = s.IsSiteVisit,
               t.IsBillable = s.IsBillable,
               t.IsCommencementTrigger = s.IsCommencementTrigger
        FROM SJob.ActivityTypes AS t
        INNER JOIN SMigration.Onboarding_ActivityTypes AS s
            ON s.ActivityTypeGuid = t.Guid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.ActivityTypeGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'ActivityTypes', N'Update', @cnt, N'Updated activity types matched by Guid.';

        INSERT INTO @ActivityTypeGuidRemap
        (
            SourceActivityTypeGuid,
            TargetActivityTypeGuid
        )
        SELECT
            s.ActivityTypeGuid,
            t.Guid
        FROM SMigration.Onboarding_ActivityTypes AS s
        INNER JOIN SJob.ActivityTypes AS t
            ON t.ID > 0
           AND t.Guid <> s.ActivityTypeGuid
           AND LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
        WHERE s.RunGuid = @RunGuid
          AND s.ActivityTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.ActivityTypes AS x
              WHERE x.Guid = s.ActivityTypeGuid
                AND x.ID > 0
          );

        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.Name = s.Name,
               t.IsActive = s.IsActive,
               t.SortOrder = s.SortOrder,
               t.IsFeeTrigger = s.IsFeeTrigger,
               t.IsLiveTrigger = s.IsLiveTrigger,
               t.IsAdmin = s.IsAdmin,
               t.IsScheduleItem = s.IsScheduleItem,
               t.Colour = s.Colour,
               t.IsMeeting = s.IsMeeting,
               t.IsSiteVisit = s.IsSiteVisit,
               t.IsBillable = s.IsBillable,
               t.IsCommencementTrigger = s.IsCommencementTrigger
        FROM @ActivityTypeGuidRemap AS m
        INNER JOIN SMigration.Onboarding_ActivityTypes AS s
            ON s.RunGuid = @RunGuid
           AND s.ActivityTypeGuid = m.SourceActivityTypeGuid
        INNER JOIN SJob.ActivityTypes AS t
            ON t.Guid = m.TargetActivityTypeGuid
           AND t.ID > 0;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'ActivityTypes', N'Update', @cnt, N'Updated activity types matched by Name.';

        UPDATE jtat
           SET jtat.ActivityTypeGuid = m.TargetActivityTypeGuid
        FROM SMigration.Onboarding_JobTypeActivityTypes AS jtat
        INNER JOIN @ActivityTypeGuidRemap AS m
            ON m.SourceActivityTypeGuid = jtat.ActivityTypeGuid
        WHERE jtat.RunGuid = @RunGuid;

        DECLARE cur_at CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.ActivityTypeGuid
        FROM SMigration.Onboarding_ActivityTypes AS s
        WHERE s.RunGuid = @RunGuid
          AND s.ActivityTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.ActivityTypes AS t
              WHERE t.Guid = s.ActivityTypeGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.ActivityTypes AS t
              WHERE t.ID > 0
                AND LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
          );

        OPEN cur_at;
        FETCH NEXT FROM cur_at INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SJob',
                @ObjectName = N'ActivityTypes',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SJob.ActivityTypes
            (
                RowStatus,
                Guid,
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
            SELECT
                s.RowStatus,
                s.ActivityTypeGuid,
                s.Name,
                s.IsActive,
                s.SortOrder,
                s.IsFeeTrigger,
                s.IsLiveTrigger,
                s.IsAdmin,
                s.IsScheduleItem,
                s.Colour,
                s.IsMeeting,
                s.IsSiteVisit,
                s.IsBillable,
                s.IsCommencementTrigger
            FROM SMigration.Onboarding_ActivityTypes AS s
            WHERE s.RunGuid = @RunGuid
              AND s.ActivityTypeGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_at INTO @Guid;
        END;

        CLOSE cur_at;
        DEALLOCATE cur_at;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'ActivityTypes', N'Insert', @cnt, N'Inserted new activity types only.';

        /* ========================================================================================
           10. MilestoneTypes
           Match order:
           1) Guid
           2) Code
           3) Name
           ======================================================================================== */
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.Code = s.Code,
               t.Name = s.Name,
               t.IsActive = s.IsActive,
               t.IsInvoiceTrigger = s.IsInvoiceTrigger,
               t.IsReviewRequired = s.IsReviewRequired,
               t.HelpText = s.HelpText,
               t.HasQuotedHours = s.HasQuotedHours,
               t.HasDescription = s.HasDescription,
               t.HasReference = s.HasReference,
               t.IsCompulsory = s.IsCompulsory,
               t.IncludeStart = s.IncludeStart,
               t.IncludeSchedule = s.IncludeSchedule,
               t.IncludeDueDate = s.IncludeDueDate,
               t.HasExternalSubmission = s.HasExternalSubmission
        FROM SJob.MilestoneTypes AS t
        INNER JOIN SMigration.Onboarding_MilestoneTypes AS s
            ON s.MilestoneTypeGuid = t.Guid
        WHERE s.RunGuid = @RunGuid
          AND t.ID > 0
          AND s.MilestoneTypeGuid <> @ZeroGuid;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'MilestoneTypes', N'Update', @cnt, N'Updated milestone types matched by Guid.';

        INSERT INTO @MilestoneTypeGuidRemap
        (
            SourceMilestoneTypeGuid,
            TargetMilestoneTypeGuid
        )
        SELECT
            s.MilestoneTypeGuid,
            t.Guid
        FROM SMigration.Onboarding_MilestoneTypes AS s
        INNER JOIN SJob.MilestoneTypes AS t
            ON t.ID > 0
           AND t.Guid <> s.MilestoneTypeGuid
           AND
           (
                (
                    NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
                    AND LOWER(LTRIM(RTRIM(t.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
                )
                OR LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
           )
        WHERE s.RunGuid = @RunGuid
          AND s.MilestoneTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.MilestoneTypes AS x
              WHERE x.Guid = s.MilestoneTypeGuid
                AND x.ID > 0
          );

        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.Code = s.Code,
               t.Name = s.Name,
               t.IsActive = s.IsActive,
               t.IsInvoiceTrigger = s.IsInvoiceTrigger,
               t.IsReviewRequired = s.IsReviewRequired,
               t.HelpText = s.HelpText,
               t.HasQuotedHours = s.HasQuotedHours,
               t.HasDescription = s.HasDescription,
               t.HasReference = s.HasReference,
               t.IsCompulsory = s.IsCompulsory,
               t.IncludeStart = s.IncludeStart,
               t.IncludeSchedule = s.IncludeSchedule,
               t.IncludeDueDate = s.IncludeDueDate,
               t.HasExternalSubmission = s.HasExternalSubmission
        FROM @MilestoneTypeGuidRemap AS m
        INNER JOIN SMigration.Onboarding_MilestoneTypes AS s
            ON s.RunGuid = @RunGuid
           AND s.MilestoneTypeGuid = m.SourceMilestoneTypeGuid
        INNER JOIN SJob.MilestoneTypes AS t
            ON t.Guid = m.TargetMilestoneTypeGuid
           AND t.ID > 0;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'MilestoneTypes', N'Update', @cnt, N'Updated milestone types matched by Code/Name.';

        UPDATE jtmt
           SET jtmt.MilestoneTypeGuid = m.TargetMilestoneTypeGuid
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS jtmt
        INNER JOIN @MilestoneTypeGuidRemap AS m
            ON m.SourceMilestoneTypeGuid = jtmt.MilestoneTypeGuid
        WHERE jtmt.RunGuid = @RunGuid;

        DECLARE cur_mt CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.MilestoneTypeGuid
        FROM SMigration.Onboarding_MilestoneTypes AS s
        WHERE s.RunGuid = @RunGuid
          AND s.MilestoneTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.MilestoneTypes AS t
              WHERE t.Guid = s.MilestoneTypeGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.MilestoneTypes AS t
              WHERE t.ID > 0
                AND
                (
                    (
                        NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
                        AND LOWER(LTRIM(RTRIM(t.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
                    )
                    OR LOWER(LTRIM(RTRIM(t.Name))) = LOWER(LTRIM(RTRIM(s.Name)))
                )
          );

        OPEN cur_mt;
        FETCH NEXT FROM cur_mt INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SJob',
                @ObjectName = N'MilestoneTypes',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SJob.MilestoneTypes
            (
                RowStatus,
                Guid,
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
            SELECT
                s.RowStatus,
                s.MilestoneTypeGuid,
                s.Code,
                s.Name,
                s.IsActive,
                s.IsInvoiceTrigger,
                s.IsReviewRequired,
                s.HelpText,
                s.HasQuotedHours,
                s.HasDescription,
                s.HasReference,
                s.IsCompulsory,
                s.IncludeStart,
                s.IncludeSchedule,
                s.IncludeDueDate,
                s.HasExternalSubmission
            FROM SMigration.Onboarding_MilestoneTypes AS s
            WHERE s.RunGuid = @RunGuid
              AND s.MilestoneTypeGuid = @Guid;

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_mt INTO @Guid;
        END;

        CLOSE cur_mt;
        DEALLOCATE cur_mt;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'MilestoneTypes', N'Insert', @cnt, N'Inserted new milestone types only.';

        /* ========================================================================================
           11. JobTypeActivityTypes
           Natural key: JobTypeID + ActivityTypeID.
           ======================================================================================== */
        ;WITH SourceJtat AS
        (
            SELECT
                s.JobTypeActivityTypeGuid,
                s.RowStatus,
                jt.ID AS JobTypeID,
                at.ID AS ActivityTypeID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY jt.ID, at.ID
                    ORDER BY s.JobTypeActivityTypeGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_JobTypeActivityTypes AS s
            INNER JOIN SJob.JobTypes AS jt
                ON jt.Guid = s.JobTypeGuid
            INNER JOIN SJob.ActivityTypes AS at
                ON at.Guid = s.ActivityTypeGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeActivityTypeGuid <> @ZeroGuid
        )
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.JobTypeID = s.JobTypeID,
               t.ActivityTypeID = s.ActivityTypeID
        FROM SJob.JobTypeActivityTypes AS t
        INNER JOIN SourceJtat AS s
            ON s.JobTypeActivityTypeGuid = t.Guid
        WHERE t.ID > 0
          AND s.NaturalRank = 1;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypeActivityTypes', N'Update', @cnt, N'Updated JTAT matched by Guid.';

        INSERT INTO @JobTypeActivityTypeGuidRemap
        (
            SourceJobTypeActivityTypeGuid,
            TargetJobTypeActivityTypeGuid
        )
        SELECT
            s.JobTypeActivityTypeGuid,
            t.Guid
        FROM SMigration.Onboarding_JobTypeActivityTypes AS s
        INNER JOIN SJob.JobTypes AS jt
            ON jt.Guid = s.JobTypeGuid
        INNER JOIN SJob.ActivityTypes AS at
            ON at.Guid = s.ActivityTypeGuid
        INNER JOIN SJob.JobTypeActivityTypes AS t
            ON t.JobTypeID = jt.ID
           AND t.ActivityTypeID = at.ID
           AND t.RowStatus NOT IN (0, 254)
        WHERE s.RunGuid = @RunGuid
          AND s.JobTypeActivityTypeGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypeActivityTypes AS x
              WHERE x.Guid = s.JobTypeActivityTypeGuid
                AND x.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM @JobTypeActivityTypeGuidRemap AS m
              WHERE m.SourceJobTypeActivityTypeGuid = s.JobTypeActivityTypeGuid
          );

        UPDATE pja
           SET pja.JobTypeActivityTypeGuid = m.TargetJobTypeActivityTypeGuid
        FROM SMigration.Onboarding_ProductJobActivities AS pja
        INNER JOIN @JobTypeActivityTypeGuidRemap AS m
            ON m.SourceJobTypeActivityTypeGuid = pja.JobTypeActivityTypeGuid
        WHERE pja.RunGuid = @RunGuid;

        DECLARE cur_jtat CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.JobTypeActivityTypeGuid
        FROM
        (
            SELECT
                s.JobTypeActivityTypeGuid,
                s.RowStatus,
                jt.ID AS JobTypeID,
                at.ID AS ActivityTypeID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY jt.ID, at.ID
                    ORDER BY s.JobTypeActivityTypeGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_JobTypeActivityTypes AS s
            INNER JOIN SJob.JobTypes AS jt
                ON jt.Guid = s.JobTypeGuid
            INNER JOIN SJob.ActivityTypes AS at
                ON at.Guid = s.ActivityTypeGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeActivityTypeGuid <> @ZeroGuid
        ) AS src
        WHERE src.NaturalRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypeActivityTypes AS t
              WHERE t.Guid = src.JobTypeActivityTypeGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypeActivityTypes AS t
              WHERE t.JobTypeID = src.JobTypeID
                AND t.ActivityTypeID = src.ActivityTypeID
                AND t.RowStatus NOT IN (0, 254)
          );

        OPEN cur_jtat;
        FETCH NEXT FROM cur_jtat INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SJob',
                @ObjectName = N'JobTypeActivityTypes',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SJob.JobTypeActivityTypes
            (
                RowStatus,
                Guid,
                JobTypeID,
                ActivityTypeID
            )
            SELECT
                s.RowStatus,
                s.JobTypeActivityTypeGuid,
                jt.ID,
                at.ID
            FROM SMigration.Onboarding_JobTypeActivityTypes AS s
            INNER JOIN SJob.JobTypes AS jt
                ON jt.Guid = s.JobTypeGuid
            INNER JOIN SJob.ActivityTypes AS at
                ON at.Guid = s.ActivityTypeGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeActivityTypeGuid = @Guid
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SJob.JobTypeActivityTypes AS x
                  WHERE x.JobTypeID = jt.ID
                    AND x.ActivityTypeID = at.ID
                    AND x.RowStatus NOT IN (0, 254)
              );

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_jtat INTO @Guid;
        END;

        CLOSE cur_jtat;
        DEALLOCATE cur_jtat;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypeActivityTypes', N'Insert', @cnt, N'Inserted distinct missing JTAT rows only.';

        /* ========================================================================================
           12. JobTypeMilestoneTemplates
           Natural key: JobTypeID + MilestoneTypeID + SortOrder.
           ======================================================================================== */
        ;WITH SourceJtmt AS
        (
            SELECT
                s.JobTypeMilestoneTemplateGuid,
                s.RowStatus,
                jt.ID AS JobTypeID,
                mt.ID AS MilestoneTypeID,
                s.Description,
                s.SortOrder,
                ROW_NUMBER() OVER
                (
                    PARTITION BY jt.ID, mt.ID, s.SortOrder
                    ORDER BY s.JobTypeMilestoneTemplateGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS s
            INNER JOIN SJob.JobTypes AS jt
                ON jt.Guid = s.JobTypeGuid
            INNER JOIN SJob.MilestoneTypes AS mt
                ON mt.Guid = s.MilestoneTypeGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeMilestoneTemplateGuid <> @ZeroGuid
        )
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.JobTypeID = s.JobTypeID,
               t.MilestoneTypeID = s.MilestoneTypeID,
               t.Description = s.Description,
               t.SortOrder = s.SortOrder
        FROM SJob.JobTypeMilestoneTemplates AS t
        INNER JOIN SourceJtmt AS s
            ON s.JobTypeMilestoneTemplateGuid = t.Guid
        WHERE t.ID > 0
          AND s.NaturalRank = 1;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypeMilestoneTemplates', N'Update', @cnt, N'Updated JTMT matched by Guid.';

        INSERT INTO @JobTypeMilestoneTemplateGuidRemap
        (
            SourceJobTypeMilestoneTemplateGuid,
            TargetJobTypeMilestoneTemplateGuid
        )
        SELECT
            s.JobTypeMilestoneTemplateGuid,
            t.Guid
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS s
        INNER JOIN SJob.JobTypes AS jt
            ON jt.Guid = s.JobTypeGuid
        INNER JOIN SJob.MilestoneTypes AS mt
            ON mt.Guid = s.MilestoneTypeGuid
        INNER JOIN SJob.JobTypeMilestoneTemplates AS t
            ON t.JobTypeID = jt.ID
           AND t.MilestoneTypeID = mt.ID
           AND t.SortOrder = s.SortOrder
           AND t.RowStatus NOT IN (0, 254)
        WHERE s.RunGuid = @RunGuid
          AND s.JobTypeMilestoneTemplateGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypeMilestoneTemplates AS x
              WHERE x.Guid = s.JobTypeMilestoneTemplateGuid
                AND x.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM @JobTypeMilestoneTemplateGuidRemap AS m
              WHERE m.SourceJobTypeMilestoneTemplateGuid = s.JobTypeMilestoneTemplateGuid
          );

        UPDATE pja
           SET pja.JobTypeMilestoneTemplateGuid = m.TargetJobTypeMilestoneTemplateGuid
        FROM SMigration.Onboarding_ProductJobActivities AS pja
        INNER JOIN @JobTypeMilestoneTemplateGuidRemap AS m
            ON m.SourceJobTypeMilestoneTemplateGuid = pja.JobTypeMilestoneTemplateGuid
        WHERE pja.RunGuid = @RunGuid;

        DECLARE cur_jtmt CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.JobTypeMilestoneTemplateGuid
        FROM
        (
            SELECT
                s.JobTypeMilestoneTemplateGuid,
                s.RowStatus,
                jt.ID AS JobTypeID,
                mt.ID AS MilestoneTypeID,
                s.Description,
                s.SortOrder,
                ROW_NUMBER() OVER
                (
                    PARTITION BY jt.ID, mt.ID, s.SortOrder
                    ORDER BY s.JobTypeMilestoneTemplateGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS s
            INNER JOIN SJob.JobTypes AS jt
                ON jt.Guid = s.JobTypeGuid
            INNER JOIN SJob.MilestoneTypes AS mt
                ON mt.Guid = s.MilestoneTypeGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeMilestoneTemplateGuid <> @ZeroGuid
        ) AS src
        WHERE src.NaturalRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypeMilestoneTemplates AS t
              WHERE t.Guid = src.JobTypeMilestoneTemplateGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobTypeMilestoneTemplates AS t
              WHERE t.JobTypeID = src.JobTypeID
                AND t.MilestoneTypeID = src.MilestoneTypeID
                AND t.SortOrder = src.SortOrder
                AND t.RowStatus NOT IN (0, 254)
          );

        OPEN cur_jtmt;
        FETCH NEXT FROM cur_jtmt INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SJob',
                @ObjectName = N'JobTypeMilestoneTemplates',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SJob.JobTypeMilestoneTemplates
            (
                RowStatus,
                Guid,
                JobTypeID,
                MilestoneTypeID,
                Description,
                SortOrder
            )
            SELECT
                s.RowStatus,
                s.JobTypeMilestoneTemplateGuid,
                jt.ID,
                mt.ID,
                s.Description,
                s.SortOrder
            FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS s
            INNER JOIN SJob.JobTypes AS jt
                ON jt.Guid = s.JobTypeGuid
            INNER JOIN SJob.MilestoneTypes AS mt
                ON mt.Guid = s.MilestoneTypeGuid
            WHERE s.RunGuid = @RunGuid
              AND s.JobTypeMilestoneTemplateGuid = @Guid
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SJob.JobTypeMilestoneTemplates AS x
                  WHERE x.JobTypeID = jt.ID
                    AND x.MilestoneTypeID = mt.ID
                    AND x.SortOrder = s.SortOrder
                    AND x.RowStatus NOT IN (0, 254)
              );

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_jtmt INTO @Guid;
        END;

        CLOSE cur_jtmt;
        DEALLOCATE cur_jtmt;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'JobTypeMilestoneTemplates', N'Insert', @cnt, N'Inserted distinct missing JTMT rows only.';

        /* ========================================================================================
           13. Products

           Product rule:
           - LIVE / UAT_Test is the source of truth for existing products.
           - Do NOT overwrite existing target product values from UAT.
           - Existing products are matched by Guid first, then Code for relationship remapping only.
           - Only genuinely missing staged onboarding products are inserted.
           ======================================================================================== */

        ------------------------------------------------------------
        -- Existing products matched by Guid are preserved.
        ------------------------------------------------------------
        SET @cnt = 0;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'Products',
            N'SkipUpdate',
            @cnt,
            N'Existing products matched by Guid preserved because target/LIVE is product source of truth.';

        ------------------------------------------------------------
        -- Build remap for products already present by Code.
        -- This is for downstream relationship rows only.
        -- It must not update SProd.Products.
        ------------------------------------------------------------
        INSERT INTO @ProductGuidRemap
        (
            SourceProductGuid,
            TargetProductGuid
        )
        SELECT
            s.ProductGuid,
            t.Guid
        FROM SMigration.Onboarding_Products AS s
        INNER JOIN SProd.Products AS t
            ON t.ID > 0
           AND t.Guid <> s.ProductGuid
           AND t.RowStatus NOT IN (0,254)
           AND NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
           AND LOWER(LTRIM(RTRIM(t.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
        WHERE s.RunGuid = @RunGuid
          AND s.ProductGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SProd.Products AS x
              WHERE x.Guid = s.ProductGuid
                AND x.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM @ProductGuidRemap AS m
              WHERE m.SourceProductGuid = s.ProductGuid
          );

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'Products',
            N'Remap',
            @cnt,
            N'Remapped staged products to existing target products by Code; target product values preserved.';

        ------------------------------------------------------------
        -- Apply product remap to staged ProductJobActivities.
        ------------------------------------------------------------
        UPDATE pja
           SET pja.ProductGuid = m.TargetProductGuid
        FROM SMigration.Onboarding_ProductJobActivities AS pja
        INNER JOIN @ProductGuidRemap AS m
            ON m.SourceProductGuid = pja.ProductGuid
        WHERE pja.RunGuid = @RunGuid;

        SET @cnt = @@ROWCOUNT;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'ProductJobActivities',
            N'Remap',
            @cnt,
            N'Remapped staged ProductJobActivities to existing target products.';

        ------------------------------------------------------------
        -- Insert only genuinely missing staged products.
        ------------------------------------------------------------
        DECLARE cur_prod CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.ProductGuid
        FROM SMigration.Onboarding_Products AS s
        INNER JOIN SJob.JobTypes AS jt
            ON jt.Guid = s.CreatedJobTypeGuid
           AND jt.ID > 0
        WHERE s.RunGuid = @RunGuid
          AND s.ProductGuid <> @ZeroGuid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SProd.Products AS t
              WHERE t.Guid = s.ProductGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SProd.Products AS t
              WHERE t.ID > 0
                AND t.RowStatus NOT IN (0,254)
                AND NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
                AND LOWER(LTRIM(RTRIM(t.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
          );

        OPEN cur_prod;
        FETCH NEXT FROM cur_prod INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SProd',
                @ObjectName = N'Products',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SProd.Products
            (
                RowStatus,
                Guid,
                Code,
                Description,
                CreatedJobType,
                NeverConsolidate,
                RibaStageId
            )
            SELECT
            s.RowStatus,
            s.ProductGuid,
            s.Code,
            s.Description,
            jt.ID,
            s.NeverConsolidate,
            CASE
                WHEN s.RibaStageGuid IS NULL OR s.RibaStageGuid = @ZeroGuid THEN -1
                ELSE COALESCE(rs.ID, -1)
            END AS RibaStageId
        FROM SMigration.Onboarding_Products AS s
        INNER JOIN SJob.JobTypes AS jt
            ON jt.Guid = s.CreatedJobTypeGuid
           AND jt.ID > 0
        LEFT JOIN SJob.RibaStages AS rs
            ON rs.Guid = s.RibaStageGuid
           AND rs.ID > 0
           AND s.RibaStageGuid <> @ZeroGuid
        WHERE s.RunGuid = @RunGuid
          AND s.ProductGuid = @Guid
          AND NOT EXISTS
          (
              SELECT 1
              FROM SProd.Products AS existing
              WHERE existing.Guid = s.ProductGuid
                AND existing.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SProd.Products AS existing
              WHERE existing.ID > 0
                AND existing.RowStatus NOT IN (0,254)
                AND NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
                AND LOWER(LTRIM(RTRIM(existing.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
          );

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_prod INTO @Guid;
        END;

        CLOSE cur_prod;
        DEALLOCATE cur_prod;

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Import',
            N'Products',
            N'Insert',
            @cnt,
            N'Inserted genuinely new staged products only; existing target products preserved.';

        /* ========================================================================================
           14. ProductJobActivities
           Natural key: ProductId + JobTypeActivityTypeId + ActivityTitle + offsets + milestone template.
           ======================================================================================== */
        ;WITH SourcePja AS
        (
            SELECT
                s.ProductJobActivityGuid,
                s.RowStatus,
                p.ID AS ProductId,
                jtat.ID AS JobTypeActivityTypeId,
                s.ActivityTitle,
                s.OffsetDays,
                s.OffsetWeeks,
                s.OffsetMonths,
                jtmt.ID AS JobTypeMilestoneTemplateId,
                s.PercentageOfProductValue,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        p.ID,
                        jtat.ID,
                        LOWER(LTRIM(RTRIM(ISNULL(s.ActivityTitle, N'')))),
                        ISNULL(s.OffsetDays, 0),
                        ISNULL(s.OffsetWeeks, 0),
                        ISNULL(s.OffsetMonths, 0),
                        COALESCE(CONVERT(NVARCHAR(50), jtmt.ID), N'NULL')
                    ORDER BY s.ProductJobActivityGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_ProductJobActivities AS s
            INNER JOIN SProd.Products AS p
                ON p.Guid = s.ProductGuid
            INNER JOIN SJob.JobTypeActivityTypes AS jtat
                ON jtat.Guid = s.JobTypeActivityTypeGuid
            LEFT JOIN SJob.JobTypeMilestoneTemplates AS jtmt
                ON jtmt.Guid = s.JobTypeMilestoneTemplateGuid
            WHERE s.RunGuid = @RunGuid
              AND s.ProductJobActivityGuid <> @ZeroGuid
        )
        UPDATE t
           SET t.RowStatus = s.RowStatus,
               t.ProductId = s.ProductId,
               t.JobTypeActivityTypeId = s.JobTypeActivityTypeId,
               t.ActivityTitle = s.ActivityTitle,
               t.OffsetDays = s.OffsetDays,
               t.OffsetWeeks = s.OffsetWeeks,
               t.OffsetMonths = s.OffsetMonths,
               t.JobTypeMilestoneTemplateId = s.JobTypeMilestoneTemplateId,
               t.PercentageOfProductValue = s.PercentageOfProductValue
        FROM SJob.ProductJobActivities AS t
        INNER JOIN SourcePja AS s
            ON s.ProductJobActivityGuid = t.Guid
        WHERE t.ID > 0
          AND s.NaturalRank = 1;

        SET @cnt = @@ROWCOUNT;
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'ProductJobActivities', N'Update', @cnt, N'Updated product job activities matched by Guid.';

        DECLARE cur_pja CURSOR LOCAL FAST_FORWARD FOR
        SELECT src.ProductJobActivityGuid
        FROM
        (
            SELECT
                s.ProductJobActivityGuid,
                s.RowStatus,
                p.ID AS ProductId,
                jtat.ID AS JobTypeActivityTypeId,
                s.ActivityTitle,
                s.OffsetDays,
                s.OffsetWeeks,
                s.OffsetMonths,
                jtmt.ID AS JobTypeMilestoneTemplateId,
                s.PercentageOfProductValue,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        p.ID,
                        jtat.ID,
                        LOWER(LTRIM(RTRIM(ISNULL(s.ActivityTitle, N'')))),
                        ISNULL(s.OffsetDays, 0),
                        ISNULL(s.OffsetWeeks, 0),
                        ISNULL(s.OffsetMonths, 0),
                        COALESCE(CONVERT(NVARCHAR(50), jtmt.ID), N'NULL')
                    ORDER BY s.ProductJobActivityGuid
                ) AS NaturalRank
            FROM SMigration.Onboarding_ProductJobActivities AS s
            INNER JOIN SProd.Products AS p
                ON p.Guid = s.ProductGuid
            INNER JOIN SJob.JobTypeActivityTypes AS jtat
                ON jtat.Guid = s.JobTypeActivityTypeGuid
            LEFT JOIN SJob.JobTypeMilestoneTemplates AS jtmt
                ON jtmt.Guid = s.JobTypeMilestoneTemplateGuid
            WHERE s.RunGuid = @RunGuid
              AND s.ProductJobActivityGuid <> @ZeroGuid
        ) AS src
        WHERE src.NaturalRank = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.ProductJobActivities AS t
              WHERE t.Guid = src.ProductJobActivityGuid
                AND t.ID > 0
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.ProductJobActivities AS t
              WHERE t.ProductId = src.ProductId
                AND t.JobTypeActivityTypeId = src.JobTypeActivityTypeId
                AND LOWER(LTRIM(RTRIM(ISNULL(t.ActivityTitle, N'')))) = LOWER(LTRIM(RTRIM(ISNULL(src.ActivityTitle, N''))))
                AND ISNULL(t.OffsetDays, 0) = ISNULL(src.OffsetDays, 0)
                AND ISNULL(t.OffsetWeeks, 0) = ISNULL(src.OffsetWeeks, 0)
                AND ISNULL(t.OffsetMonths, 0) = ISNULL(src.OffsetMonths, 0)
                AND (
                    t.JobTypeMilestoneTemplateId = src.JobTypeMilestoneTemplateId
                    OR
                    (
                        t.JobTypeMilestoneTemplateId IS NULL
                        AND src.JobTypeMilestoneTemplateId IS NULL
                    )
                )
                AND t.RowStatus NOT IN (0, 254)
          );

        OPEN cur_pja;
        FETCH NEXT FROM cur_pja INTO @Guid;

        SET @cnt = 0;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.UpsertDataObject
                @Guid = @Guid,
                @SchemeName = N'SJob',
                @ObjectName = N'ProductJobActivities',
                @IncludeDefaultSecurity = 0,
                @IsInsert = @IsInsert OUTPUT;

            INSERT INTO SJob.ProductJobActivities
            (
                RowStatus,
                Guid,
                ProductId,
                JobTypeActivityTypeId,
                ActivityTitle,
                OffsetDays,
                OffsetWeeks,
                OffsetMonths,
                JobTypeMilestoneTemplateId,
                PercentageOfProductValue
            )
            SELECT
                s.RowStatus,
                s.ProductJobActivityGuid,
                p.ID,
                jtat.ID,
                s.ActivityTitle,
                s.OffsetDays,
                s.OffsetWeeks,
                s.OffsetMonths,
                jtmt.ID,
                s.PercentageOfProductValue
            FROM SMigration.Onboarding_ProductJobActivities AS s
            INNER JOIN SProd.Products AS p
                ON p.Guid = s.ProductGuid
            INNER JOIN SJob.JobTypeActivityTypes AS jtat
                ON jtat.Guid = s.JobTypeActivityTypeGuid
            LEFT JOIN SJob.JobTypeMilestoneTemplates AS jtmt
                ON jtmt.Guid = s.JobTypeMilestoneTemplateGuid
            WHERE s.RunGuid = @RunGuid
              AND s.ProductJobActivityGuid = @Guid
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SJob.ProductJobActivities AS x
                  WHERE x.ProductId = p.ID
                    AND x.JobTypeActivityTypeId = jtat.ID
                    AND LOWER(LTRIM(RTRIM(ISNULL(x.ActivityTitle, N'')))) = LOWER(LTRIM(RTRIM(ISNULL(s.ActivityTitle, N''))))
                    AND ISNULL(x.OffsetDays, 0) = ISNULL(s.OffsetDays, 0)
                    AND ISNULL(x.OffsetWeeks, 0) = ISNULL(s.OffsetWeeks, 0)
                    AND ISNULL(x.OffsetMonths, 0) = ISNULL(s.OffsetMonths, 0)
                    AND
                        (
                            x.JobTypeMilestoneTemplateId = jtmt.ID
                            OR
                            (
                                x.JobTypeMilestoneTemplateId IS NULL
                                AND jtmt.ID IS NULL
                            )
                        )
                    AND x.RowStatus NOT IN (0, 254)
              );

            SET @cnt += @@ROWCOUNT;

            FETCH NEXT FROM cur_pja INTO @Guid;
        END;

        CLOSE cur_pja;
        DEALLOCATE cur_pja;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'ProductJobActivities', N'Insert', @cnt, N'Inserted distinct missing product job activities only.';

        IF @StartedTran = 1
        BEGIN
            COMMIT TRAN;
        END;

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'All', N'Summary', 0, N'Import complete.';
        EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;
    END TRY
    BEGIN CATCH
        DECLARE
            @ErrorNumber INT = ERROR_NUMBER(),
            @ErrorSeverity INT = ERROR_SEVERITY(),
            @ErrorState INT = ERROR_STATE(),
            @ErrorLine INT = ERROR_LINE(),
            @ErrorProcedure NVARCHAR(128) = ERROR_PROCEDURE(),
            @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();

        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRAN;
        END;

        BEGIN TRY
            EXEC SMigration.OnboardingLog_Add
                @RunGuid,
                N'Import',
                N'All',
                N'Error',
                0,
                @ErrorMessage;
        END TRY
        BEGIN CATCH
            -- Do not mask original failure.
        END CATCH;

        ;THROW;
    END CATCH;
END
GO