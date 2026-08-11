SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[MetadataApply_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataApply_Run]')
GO

CREATE PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0,
    @ApplySelectedOnly BIT = 0,
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @IsValidateOnly BIT,
        @TargetEnvironment NVARCHAR(20),
        @TargetDatabaseName SYSNAME,
        @SourceDatabaseName SYSNAME,
        @FailCount INT = 0,
        @PreviewFingerprint VARBINARY(32),
        @ScopeFingerprint VARBINARY(32),
        @PreviewFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
        @PreviewApplyCount INT = 0,
        @ApplyDetailsJson NVARCHAR(MAX),
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    SELECT
        @RunStatus = r.RunStatus,
        @IsValidateOnly = r.IsValidateOnly,
        @TargetEnvironment = r.TargetEnvironment,
        @TargetDatabaseName = r.TargetDatabaseName,
        @SourceDatabaseName = r.SourceDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52000, 'Metadata run was not found or is inactive.', 1;

    IF ISNULL(@IsValidateOnly, 1) = 1
        THROW 52006, 'Validate-only metadata runs cannot be applied. Create and validate a deployment-enabled run before apply.', 1;

    IF @RunStatus NOT IN
    (
        N'Validated',
        N'PartiallyApplied',
        N'AppliedCoreMetadata',
        N'AppliedUiMetadata'
    )
        THROW 52001, 'Metadata run must be Validated, PartiallyApplied, AppliedCoreMetadata or AppliedUiMetadata before apply.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail';

    IF ISNULL(@FailCount, 0) > 0
        THROW 52002, 'Metadata run has validation failures and cannot be applied.', 1;

    IF @TargetEnvironment = N'LIVE' AND ISNULL(@ForceApply, 0) = 0
        THROW 52003, 'LIVE metadata apply requires @ForceApply = 1.', 1;

    /*
        Metadata_TableRegistry can be extended dynamically, but this procedure
        deliberately applies only tables with explicit, reviewed handlers.
        Re-check handler coverage at execution time so stale or bypassed
        validation cannot produce a false-success apply.
    */
    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND
          (
              ISNULL(@ApplySelectedOnly, 0) = 0
              OR EXISTS
              (
                  SELECT 1
                  FROM SMigration.Metadata_RunSelections AS selection
                  WHERE selection.RunGuid = sr.RunGuid
                    AND selection.RegistryGuid = sr.RegistryGuid
                    AND selection.SourceRowGuid = sr.SourceRowGuid
                    AND selection.RowStatus NOT IN (0,254)
              )
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_IgnoredRecords AS ignored
              WHERE ignored.DatabaseName = @TargetDatabaseName
                AND ignored.RegistryGuid = sr.RegistryGuid
                AND ignored.SourceRowGuid = sr.SourceRowGuid
                AND ignored.RowStatus NOT IN (0,254)
          )
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_IdentityMapOverrides AS identityOverride
              WHERE identityOverride.DatabaseName = @TargetDatabaseName
                AND identityOverride.RegistryGuid = sr.RegistryGuid
                AND identityOverride.SourceRowGuid = sr.SourceRowGuid
                AND identityOverride.RowStatus NOT IN (0,254)
          )
          AND NOT
          (
              (tr.SchemaName = N'SCore' AND tr.TableName IN
              (
                  N'LanguageLabels',
                  N'LanguageLabelTranslations',
                  N'EntityDataTypes',
                  N'EntityTypes',
                  N'EntityHobts',
                  N'EntityPropertyGroups',
                  N'EntityQueries',
                  N'EntityProperties',
                  N'EntityQueryParameters'
              ))
              OR
              (tr.SchemaName = N'SUserInterface' AND tr.TableName IN
              (
                  N'Icons',
                  N'DropDownListDefinitions',
                  N'GridDefinitions',
                  N'GridViewDefinitions',
                  N'GridViewColumnDefinitions'
              ))
          )
    )
        THROW 52005, 'Metadata apply contains an actionable table without a controlled apply handler. Re-stage, validate and add a source-controlled handler before deployment.', 1;

    BEGIN TRANSACTION;

    /*
        Apply must be bound to the exact preview accepted through the controlled
        server-side acceptance path. The fingerprint procedure uses HOLDLOCK
        reads so the accepted staged/selection/ignore/override scope cannot
        change between this check and the deployment writes in this transaction.
    */
    EXEC SMigration.MetadataApplyPreviewFingerprint_Get
        @RunGuid = @RunGuid,
        @ApplySelectedOnly = @ApplySelectedOnly,
        @SourceSnapshotFingerprint = @SourceSnapshotFingerprint,
        @TargetSnapshotFingerprint = @TargetSnapshotFingerprint,
        @PreviewFingerprint = @PreviewFingerprint OUTPUT,
        @ScopeFingerprint = @ScopeFingerprint OUTPUT,
        @ApplyCount = @PreviewApplyCount OUTPUT;

    SET @PreviewFingerprintHex = CONVERT(VARCHAR(64), @PreviewFingerprint, 2);
    SET @ScopeFingerprintHex = CONVERT(VARCHAR(64), @ScopeFingerprint, 2);

    IF ISNULL(@PreviewApplyCount, 0) = 0
        THROW 52007, 'Metadata apply requires at least one actionable row in the accepted preview scope.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ExecutionLog AS acceptedPreview WITH (HOLDLOCK)
        WHERE acceptedPreview.RunGuid = @RunGuid
          AND acceptedPreview.RowStatus NOT IN (0,254)
          AND acceptedPreview.StepName = N'ApplyPreviewAcceptance'
          AND acceptedPreview.StepStatus = N'Accepted'
          AND JSON_VALUE(acceptedPreview.DetailsJson, '$.previewFingerprint') = @PreviewFingerprintHex
          AND JSON_VALUE(acceptedPreview.DetailsJson, '$.scopeFingerprint') = @ScopeFingerprintHex
          AND JSON_VALUE(acceptedPreview.DetailsJson, '$.sourceSnapshotFingerprint') = UPPER(@SourceSnapshotFingerprint)
          AND JSON_VALUE(acceptedPreview.DetailsJson, '$.targetSnapshotFingerprint') = UPPER(@TargetSnapshotFingerprint)
          AND TRY_CONVERT(INT, JSON_VALUE(acceptedPreview.DetailsJson, '$.applySelectedOnly')) = CONVERT(INT, ISNULL(@ApplySelectedOnly, 0))
    )
        THROW 52007, 'Metadata apply requires a current server-side accepted preview for the same scope. Reload, review and accept the preview before deployment.', 1;

    SELECT
        @ApplyDetailsJson =
        (
            SELECT
                @PreviewFingerprintHex AS previewFingerprint,
                @ScopeFingerprintHex AS scopeFingerprint,
                UPPER(@SourceSnapshotFingerprint) AS sourceSnapshotFingerprint,
                UPPER(@TargetSnapshotFingerprint) AS targetSnapshotFingerprint,
                CONVERT(INT, ISNULL(@ApplySelectedOnly, 0)) AS applySelectedOnly,
                @PreviewApplyCount AS applyCount
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyStart',
        @StepStatus = N'Started',
        @Message = N'Metadata apply started.',
        @DetailsJson = @ApplyDetailsJson;

    
    IF OBJECT_ID(N'tempdb..#MetadataSourceGuidLookup') IS NOT NULL
        DROP TABLE #MetadataSourceGuidLookup;

    CREATE TABLE #MetadataSourceGuidLookup
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        SourceRowId BIGINT NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_MetadataSourceGuidLookup PRIMARY KEY CLUSTERED
        (
            SchemaName,
            TableName,
            SourceRowId
        )
    );

    INSERT INTO #MetadataSourceGuidLookup
    (
        SchemaName,
        TableName,
        SourceRowId,
        SourceRowGuid
    )
    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId,
        sr.SourceRowGuid
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.SourceRowId IS NOT NULL
      AND sr.SourceRowGuid IS NOT NULL;

    IF OBJECT_ID(N'tempdb..#MetadataRowsToApply') IS NOT NULL
        DROP TABLE #MetadataRowsToApply;

    CREATE TABLE #MetadataRowsToApply
    (
        StagedRowId BIGINT NOT NULL,
        CONSTRAINT PK_MetadataRowsToApply PRIMARY KEY CLUSTERED (StagedRowId)
    );

    INSERT INTO #MetadataRowsToApply
    (
        StagedRowId
    )
    SELECT
        sr.ID
    FROM SMigration.Metadata_StagedRows AS sr
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND
      (
          ISNULL(@ApplySelectedOnly, 0) = 0
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS sel
              WHERE sel.RunGuid = sr.RunGuid
                AND sel.RegistryGuid = sr.RegistryGuid
                AND sel.SourceRowGuid = sr.SourceRowGuid
                AND sel.RowStatus NOT IN (0,254)
          )
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignApply
          WHERE ignApply.DatabaseName = @TargetDatabaseName
            AND ignApply.RegistryGuid = sr.RegistryGuid
            AND ignApply.SourceRowGuid = sr.SourceRowGuid
            AND ignApply.RowStatus NOT IN (0,254)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IdentityMapOverrides AS overrideApply
          WHERE overrideApply.DatabaseName = @TargetDatabaseName
            AND overrideApply.RegistryGuid = sr.RegistryGuid
            AND overrideApply.SourceRowGuid = sr.SourceRowGuid
            AND overrideApply.RowStatus NOT IN (0,254)
      );

    IF ISNULL(@ApplySelectedOnly, 0) = 1
       AND NOT EXISTS (SELECT 1 FROM #MetadataRowsToApply)
        THROW 52004, 'Apply selected requires at least one selected Insert or Update metadata row.', 1;

    DECLARE @ApplySelectionDetailsJson NVARCHAR(MAX);

    SELECT
        @ApplySelectionDetailsJson =
        (
            SELECT
                ISNULL(@ApplySelectedOnly, 0) AS applySelectedOnly,
                COUNT_BIG(1) AS [rowCount]
            FROM #MetadataRowsToApply
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    DECLARE @_Message AS NVARCHAR(50) = CASE WHEN ISNULL(@ApplySelectedOnly, 0) = 1 THEN N'Metadata apply scoped to selected rows.' ELSE N'Metadata apply scoped to all valid rows.' END

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplySelectionScope',
        @StepStatus = N'Succeeded',
        @Message = @_Message,
        @DetailsJson = @ApplySelectionDetailsJson;
/* =========================================================
       1. SCore.LanguageLabels
       ========================================================= */
    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Name NVARCHAR(500);

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name')
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;
    END;

    CLOSE LanguageLabels_Cursor;
    DEALLOCATE LanguageLabels_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabels',
        @StepStatus = N'Succeeded',
        @Message = N'Language labels applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       2. SCore.LanguageLabelTranslations
       ========================================================= */
    DECLARE
        @Text NVARCHAR(500),
        @TextPlural NVARCHAR(500),
        @HelpText NVARCHAR(MAX),
        @LanguageLabelGuidRef UNIQUEIDENTIFIER,
        @LanguageGuidRef UNIQUEIDENTIFIER,
        @SourceLanguageLabelId BIGINT,
        @SourceLanguageId BIGINT,
        @Sql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb..#LanguageLabelTranslationsToApply') IS NOT NULL
        DROP TABLE #LanguageLabelTranslationsToApply;

    CREATE TABLE #LanguageLabelTranslationsToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Text NVARCHAR(500) NULL,
        TextPlural NVARCHAR(500) NULL,
        HelpText NVARCHAR(MAX) NULL,
        SourceLanguageLabelId BIGINT NULL,
        SourceLanguageId BIGINT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageId'))),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'LanguageLabelTranslations';

    DECLARE LanguageLabelTranslations_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            Text,
            TextPlural,
            HelpText,
            SourceLanguageLabelId,
            SourceLanguageId
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @LanguageLabelGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @SourceLanguageLabelId;

        SELECT
            @LanguageGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'Languages'
          AND lookup.SourceRowId = @SourceLanguageId;

        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;
    END;

    CLOSE LanguageLabelTranslations_Cursor;
    DEALLOCATE LanguageLabelTranslations_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabelTranslations',
        @StepStatus = N'Succeeded',
        @Message = N'Language label translations applied.',
        @DetailsJson = N'{}';


    
/* =========================================================
       3. SCore.EntityDataTypes
       Required reference metadata for EntityProperties and EntityQueryParameters.
       No dedicated EntityDataTypeUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       ========================================================= */
    DECLARE
        @EDT_RowStatus TINYINT,
        @EDT_Name NVARCHAR(250),
        @EDT_QuoteValue BIT,
        @EDT_IsInsert BIT;

    DECLARE EntityDataTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.QuoteValue'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityDataTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityDataTypes_Cursor;

    FETCH NEXT FROM EntityDataTypes_Cursor
    INTO
        @Guid,
        @EDT_RowStatus,
        @EDT_Name,
        @EDT_QuoteValue;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EDT_IsInsert = 0;

        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'EntityDataTypes',
            @IsInsert = @EDT_IsInsert OUTPUT;

        IF @EDT_IsInsert = 1
        BEGIN
            INSERT INTO SCore.EntityDataTypes
            (
                Guid,
                RowStatus,
                Name,
                QuoteValue
            )
            VALUES
            (
                @Guid,
                ISNULL(NULLIF(@EDT_RowStatus, 0), 1),
                ISNULL(@EDT_Name, N''),
                ISNULL(@EDT_QuoteValue, 0)
            );
        END;
        ELSE
        BEGIN
            UPDATE SCore.EntityDataTypes
            SET
                RowStatus = ISNULL(NULLIF(@EDT_RowStatus, 0), RowStatus),
                Name = ISNULL(@EDT_Name, N''),
                QuoteValue = ISNULL(@EDT_QuoteValue, 0)
            WHERE Guid = @Guid;
        END;

        FETCH NEXT FROM EntityDataTypes_Cursor
        INTO
            @Guid,
            @EDT_RowStatus,
            @EDT_Name,
            @EDT_QuoteValue;
    END;

    CLOSE EntityDataTypes_Cursor;
    DEALLOCATE EntityDataTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityDataTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity data types applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       4. SUserInterface.Icons
       Required reference metadata for EntityTypes and GridViewDefinitions.
       No dedicated IconUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       Natural key fallback is Name to avoid duplicate icon CSS classes.
       ========================================================= */
    DECLARE
        @ICON_RowStatus TINYINT,
        @ICON_Name NVARCHAR(50),
        @ICON_SourceRowId BIGINT,
        @ICON_IsInsert BIT,
        @ICON_ExistingGuid UNIQUEIDENTIFIER,
        @ICON_GuidToApply UNIQUEIDENTIFIER;

    DECLARE Icons_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            sr.SourceRowId
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SUserInterface'
          AND tr.TableName = N'Icons'
        ORDER BY sr.SourceRowId;

    OPEN Icons_Cursor;

    FETCH NEXT FROM Icons_Cursor
    INTO
        @Guid,
        @ICON_RowStatus,
        @ICON_Name,
        @ICON_SourceRowId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ICON_ExistingGuid = NULL;
        SET @ICON_GuidToApply = @Guid;
        SET @ICON_IsInsert = 0;

        SELECT TOP (1)
            @ICON_ExistingGuid = i.Guid
        FROM SUserInterface.Icons AS i
        WHERE i.Name = ISNULL(@ICON_Name, N'')
          AND i.RowStatus NOT IN (0,254)
          AND i.Guid <> @Guid
        ORDER BY i.ID;

        IF @ICON_ExistingGuid IS NOT NULL
        BEGIN
            SET @ICON_GuidToApply = @ICON_ExistingGuid;

            UPDATE lookup
            SET SourceRowGuid = @ICON_ExistingGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'Icons'
              AND lookup.SourceRowId = @ICON_SourceRowId;
        END;

        EXEC SCore.UpsertDataObject
            @Guid = @ICON_GuidToApply,
            @SchemeName = N'SUserInterface',
            @ObjectName = N'Icons',
            @IsInsert = @ICON_IsInsert OUTPUT;

        IF @ICON_IsInsert = 1
        BEGIN
            INSERT INTO SUserInterface.Icons
            (
                Guid,
                RowStatus,
                Name
            )
            VALUES
            (
                @ICON_GuidToApply,
                ISNULL(NULLIF(@ICON_RowStatus, 0), 1),
                ISNULL(@ICON_Name, N'')
            );
        END;
        ELSE
        BEGIN
            UPDATE SUserInterface.Icons
            SET
                RowStatus = ISNULL(NULLIF(@ICON_RowStatus, 0), RowStatus),
                Name = ISNULL(@ICON_Name, N'')
            WHERE Guid = @ICON_GuidToApply;
        END;

        FETCH NEXT FROM Icons_Cursor
        INTO
            @Guid,
            @ICON_RowStatus,
            @ICON_Name,
            @ICON_SourceRowId;
    END;

    CLOSE Icons_Cursor;
    DEALLOCATE Icons_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyIcons',
        @StepStatus = N'Succeeded',
        @Message = N'Icons applied.',
        @DetailsJson = N'{}';


/* =========================================================
       3. SCore.EntityTypes
       Required reference metadata for EntityQueries/GridViews/DropDownLists.
       Applies staged EntityTypes before dependent metadata.
       ========================================================= */
    DECLARE
        @ET_RowStatus TINYINT,
        @ET_IsReadOnlyOffline BIT,
        @ET_IsRequiredSystemData BIT,
        @ET_HasDocuments BIT,
        @ET_SourceLanguageLabelID BIGINT,
        @ET_DoNotTrackChanges BIT,
        @ET_SourceIconID BIGINT,
        @ET_IsRootEntity BIT,
        @ET_DetailPageUrl NVARCHAR(250),
        @ET_IsMetaData BIT,
        @ET_IsDeletable BIT,
        @ET_LanguageLabelGuid UNIQUEIDENTIFIER,
        @ET_IconGuid UNIQUEIDENTIFIER;

    DECLARE EntityTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRequiredSystemData')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasDocuments')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.IconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.IconId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRootEntity')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMetaData')),
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDeletable')), 1)
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityTypes_Cursor;

    FETCH NEXT FROM EntityTypes_Cursor
    INTO
        @Guid,
        @ET_RowStatus,
        @Name,
        @ET_IsReadOnlyOffline,
        @ET_IsRequiredSystemData,
        @ET_HasDocuments,
        @ET_SourceLanguageLabelID,
        @ET_DoNotTrackChanges,
        @ET_SourceIconID,
        @ET_IsRootEntity,
        @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ET_LanguageLabelGuid = NULL;
        SET @ET_IconGuid = NULL;

        SELECT
            @ET_LanguageLabelGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @ET_SourceLanguageLabelID;

        SELECT
            @ET_IconGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'Icons'
          AND lookup.SourceRowId = @ET_SourceIconID;

        DECLARE @EntityTypeGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityTypeUpsert
            @Name = @Name,
            @RowStatus = @ET_RowStatus,
            @IsReadOnlyOffline = @ET_IsReadOnlyOffline,
            @IsRequiredSystemData = @ET_IsRequiredSystemData,
            @HasDocuments = @ET_HasDocuments,
            @LanguageLabelGuid = @ET_LanguageLabelGuid,
            @DoNotTrackChanges = @ET_DoNotTrackChanges,
            @IconGuid = @ET_IconGuid,
            @IsRootEntity = @ET_IsRootEntity,
            @DetailPageUrl = @ET_DetailPageUrl,
            @IsMetaData = @ET_IsMetaData,
            @IsDeletable = @ET_IsDeletable,
            @Guid = @EntityTypeGuidToApply OUTPUT;

        FETCH NEXT FROM EntityTypes_Cursor
        INTO
            @Guid,
            @ET_RowStatus,
            @Name,
            @ET_IsReadOnlyOffline,
            @ET_IsRequiredSystemData,
            @ET_HasDocuments,
            @ET_SourceLanguageLabelID,
            @ET_DoNotTrackChanges,
            @ET_SourceIconID,
            @ET_IsRootEntity,
            @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;
    END;

    CLOSE EntityTypes_Cursor;
    DEALLOCATE EntityTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity types applied.',
        @DetailsJson = N'{}';


    /* =========================================================
       4. SCore.EntityHobts
       Required reference metadata for EntityQueries and EntityProperties.
       Applies staged HoBTs after EntityTypes and before dependent metadata.
       ========================================================= */
    DECLARE
        @EH_RowStatus TINYINT,
        @EH_SchemaName NVARCHAR(250),
        @EH_ObjectName NVARCHAR(250),
        @EH_SourceEntityTypeID BIGINT,
        @EH_ObjectType NVARCHAR(1),
        @EH_IsMainHoBT BIT,
        @EH_IsReadOnlyOffline BIT,
        @EH_EntityTypeGuid UNIQUEIDENTIFIER;

    DECLARE EntityHobts_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectType'), N'T'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMainHoBT')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityHobts'
        ORDER BY sr.SourceRowId;

    OPEN EntityHobts_Cursor;

    FETCH NEXT FROM EntityHobts_Cursor
    INTO
        @Guid,
        @EH_RowStatus,
        @EH_SchemaName,
        @EH_ObjectName,
        @EH_SourceEntityTypeID,
        @EH_ObjectType,
        @EH_IsMainHoBT,
        @EH_IsReadOnlyOffline;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EH_EntityTypeGuid = NULL;

        SELECT
            @EH_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @EH_SourceEntityTypeID;

        IF @EH_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingHoBTEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityHobts apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EH_SourceEntityTypeID), N'<NULL>'), N' for HoBT ', COALESCE(@EH_SchemaName + N'.' + @EH_ObjectName, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityHobts.');
            THROW 52021, @MissingHoBTEntityTypeMessage, 1;
        END;

        DECLARE @EntityHoBTGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityHoBTUpsert
            @SchemaName = @EH_SchemaName,
            @ObjectName = @EH_ObjectName,
            @ObjectType = @EH_ObjectType,
            @IsMainHoBT = @EH_IsMainHoBT,
            @IsReadOnlyOffline = @EH_IsReadOnlyOffline,
            @EntityTypeGuid = @EH_EntityTypeGuid,
            @Guid = @EntityHoBTGuidToApply OUTPUT;

        FETCH NEXT FROM EntityHobts_Cursor
        INTO
            @Guid,
            @EH_RowStatus,
            @EH_SchemaName,
            @EH_ObjectName,
            @EH_SourceEntityTypeID,
            @EH_ObjectType,
            @EH_IsMainHoBT,
            @EH_IsReadOnlyOffline;
    END;

    CLOSE EntityHobts_Cursor;
    DEALLOCATE EntityHobts_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityHobts',
        @StepStatus = N'Succeeded',
        @Message = N'Entity HoBTs applied.',
        @DetailsJson = N'{}';

    /* =========================================================
   10. SUserInterface.DropDownListDefinitions
   ========================================================= */

DECLARE
    @DDL_Code NVARCHAR(20),
    @DDL_NameColumn NVARCHAR(254),
    @DDL_ValueColumn NVARCHAR(254),
    @DDL_SqlQuery NVARCHAR(MAX),
    @DDL_DefaultSortColumnName NVARCHAR(254),
    @DDL_IsDefaultColumn BIT,
    @DDL_IsDetailWindowed BIT,
    @DDL_DetailPageURI NVARCHAR(250),
    @DDL_SourceEntityTypeID BIGINT,
    @DDL_InformationPageURI NVARCHAR(250),
    @DDL_GroupColumn NVARCHAR(254),
    @DDL_ColourHexColumn NVARCHAR(7),
    @DDL_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER;

DECLARE DropDownListDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.NameColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ValueColumn'),
        ddlJsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultColumn')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.InformationPageUrl'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.GroupColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ColourHexColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl')
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery'
    ) AS ddlJsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'DropDownListDefinitions'
    ORDER BY sr.SourceRowId;

OPEN DropDownListDefinitions_Cursor;

FETCH NEXT FROM DropDownListDefinitions_Cursor
INTO
    @Guid,
    @DDL_Code,
    @DDL_NameColumn,
    @DDL_ValueColumn,
    @DDL_SqlQuery,
    @DDL_DefaultSortColumnName,
    @DDL_IsDefaultColumn,
    @DDL_IsDetailWindowed,
    @DDL_DetailPageURI,
    @DDL_SourceEntityTypeID,
    @DDL_InformationPageURI,
    @DDL_GroupColumn,
    @DDL_ColourHexColumn,
    @DDL_ExternalSearchPageUrl;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DDL_EntityTypeGuid = NULL;
    IF @DDL_SourceEntityTypeID IS NULL OR @DDL_SourceEntityTypeID <= 0
    BEGIN
        SET @DDL_EntityTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @DDL_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @DDL_SourceEntityTypeID;
    END;

    IF @DDL_EntityTypeGuid IS NULL
    BEGIN
        DECLARE @MissingDDLTargetEntityTypeMessage NVARCHAR(4000) = CONCAT(N'DropDownListDefinitions apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @DDL_SourceEntityTypeID), N'<NULL>'), N' for drop-down list ', COALESCE(@DDL_Code, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SUserInterface.DropDownListDefinitions.');
        THROW 52028, @MissingDDLTargetEntityTypeMessage, 1;
    END;

    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.DropDownListDefinitionUpsert
        @Code = @DDL_Code,
        @NameColumn = @DDL_NameColumn,
        @ValueColumn = @DDL_ValueColumn,
        @SqlQuery = @DDL_SqlQuery,
        @DefaultSortColumnName = @DDL_DefaultSortColumnName,
        @IsDefaultColumn = @DDL_IsDefaultColumn,
        @IsDetailWindowed = @DDL_IsDetailWindowed,
        @DetailPageURI = @DDL_DetailPageURI,
        @EntityTypeGuid = @DDL_EntityTypeGuid,
        @InformationPageURI = @DDL_InformationPageURI,
        @GroupColumn = @DDL_GroupColumn,
        @Guid = @DropDownListDefinitionGuid OUTPUT,
        @ColourHexColumn = @DDL_ColourHexColumn,
        @ExternalSearchPageUrl = @DDL_ExternalSearchPageUrl;

    FETCH NEXT FROM DropDownListDefinitions_Cursor
    INTO
        @Guid,
        @DDL_Code,
        @DDL_NameColumn,
        @DDL_ValueColumn,
        @DDL_SqlQuery,
        @DDL_DefaultSortColumnName,
        @DDL_IsDefaultColumn,
        @DDL_IsDetailWindowed,
        @DDL_DetailPageURI,
        @DDL_SourceEntityTypeID,
        @DDL_InformationPageURI,
        @DDL_GroupColumn,
        @DDL_ColourHexColumn,
        @DDL_ExternalSearchPageUrl;
END;

CLOSE DropDownListDefinitions_Cursor;
DEALLOCATE DropDownListDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyDropDownListDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Drop-down list definitions applied.',
    @DetailsJson = N'{}';


/* =========================================================
       8. SCore.EntityPropertyGroups
       Required reference metadata for EntityProperties.
       ========================================================= */
    DECLARE
        @EPG_RowStatus TINYINT,
        @EPG_Name NVARCHAR(250),
        @EPG_IsHidden BIT,
        @EPG_SortOrder INT,
        @EPG_SourceLanguageLabelID BIGINT,
        @EPG_SourceEntityTypeID BIGINT,
        @EPG_SourcePropertyGroupLayoutID BIGINT,
        @EPG_ShowOnMobile BIT,
        @EPG_IsCollapsable BIT,
        @EPG_IsDefaultCollapsed BIT,
        @EPG_IsDefaultCollapsed_Mobile BIT,
        @EPG_LanguageLabelGuid UNIQUEIDENTIFIER,
        @EPG_EntityTypeGuid UNIQUEIDENTIFIER,
        @EPG_PropertyGroupLayoutGuid UNIQUEIDENTIFIER;

    DECLARE EntityPropertyGroups_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
            TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutID'), JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCollapsable')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed_Mobile'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityPropertyGroups'
        ORDER BY sr.SourceRowId;

    OPEN EntityPropertyGroups_Cursor;

    FETCH NEXT FROM EntityPropertyGroups_Cursor
    INTO
        @Guid,
        @EPG_RowStatus,
        @EPG_Name,
        @EPG_IsHidden,
        @EPG_SortOrder,
        @EPG_SourceLanguageLabelID,
        @EPG_SourceEntityTypeID,
        @EPG_SourcePropertyGroupLayoutID,
        @EPG_ShowOnMobile,
        @EPG_IsCollapsable,
        @EPG_IsDefaultCollapsed,
        @EPG_IsDefaultCollapsed_Mobile;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EPG_LanguageLabelGuid = NULL;
        SET @EPG_EntityTypeGuid = NULL;
        SET @EPG_PropertyGroupLayoutGuid = NULL;

        IF @EPG_SourceLanguageLabelID IS NULL OR @EPG_SourceLanguageLabelID <= 0
        BEGIN
            SET @EPG_LanguageLabelGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_LanguageLabelGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'LanguageLabels'
              AND lookup.SourceRowId = @EPG_SourceLanguageLabelID;
        END;

        IF @EPG_SourceEntityTypeID IS NULL OR @EPG_SourceEntityTypeID <= 0
        BEGIN
            SET @EPG_EntityTypeGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_EntityTypeGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'EntityTypes'
              AND lookup.SourceRowId = @EPG_SourceEntityTypeID;
        END;

        IF @EPG_SourcePropertyGroupLayoutID IS NULL OR @EPG_SourcePropertyGroupLayoutID <= 0
        BEGIN
            SET @EPG_PropertyGroupLayoutGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_PropertyGroupLayoutGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'PropertyGroupLayouts'
              AND lookup.SourceRowId = @EPG_SourcePropertyGroupLayoutID;
        END;

        IF @EPG_LanguageLabelGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLanguageLabelMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve LanguageLabel source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceLanguageLabelID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.LanguageLabels is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52025, @MissingEPGLanguageLabelMessage, 1;
        END;

        IF @EPG_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEPGEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceEntityTypeID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52026, @MissingEPGEntityTypeMessage, 1;
        END;

        IF @EPG_PropertyGroupLayoutGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLayoutMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve PropertyGroupLayout source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourcePropertyGroupLayoutID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.PropertyGroupLayouts is included as reference metadata if this is not the zero/default layout.');
            THROW 52027, @MissingEPGLayoutMessage, 1;
        END;

        DECLARE @EntityPropertyGroupGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityPropertyGroupUpsert
            @Name = @EPG_Name,
            @RowStatus = @EPG_RowStatus,
            @IsHidden = @EPG_IsHidden,
            @SortOrder = @EPG_SortOrder,
            @LanguageLabelGuid = @EPG_LanguageLabelGuid,
            @EntityTypeGuid = @EPG_EntityTypeGuid,
            @PropertyGroupLayoutGuid = @EPG_PropertyGroupLayoutGuid,
            @ShowOnMobile = @EPG_ShowOnMobile,
            @IsCollapsable = @EPG_IsCollapsable,
            @IsDefaultCollapsed = @EPG_IsDefaultCollapsed,
            @IsDefaultCollapsed_Mobile = @EPG_IsDefaultCollapsed_Mobile,
            @Guid = @EntityPropertyGroupGuid OUTPUT;

        FETCH NEXT FROM EntityPropertyGroups_Cursor
        INTO
            @Guid,
            @EPG_RowStatus,
            @EPG_Name,
            @EPG_IsHidden,
            @EPG_SortOrder,
            @EPG_SourceLanguageLabelID,
            @EPG_SourceEntityTypeID,
            @EPG_SourcePropertyGroupLayoutID,
            @EPG_ShowOnMobile,
            @EPG_IsCollapsable,
            @EPG_IsDefaultCollapsed,
            @EPG_IsDefaultCollapsed_Mobile;
    END;

    CLOSE EntityPropertyGroups_Cursor;
    DEALLOCATE EntityPropertyGroups_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityPropertyGroups',
        @StepStatus = N'Succeeded',
        @Message = N'Entity property groups applied.',
        @DetailsJson = N'{}';

/* =========================================================
       5. SCore.EntityQueries
       ========================================================= */
    DECLARE
        @Statement NVARCHAR(MAX),
        @EntityTypeGuid UNIQUEIDENTIFIER,
        @EntityHoBTGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT,
        @IsDefaultRead BIT,
        @IsDefaultUpdate BIT,
        @IsDefaultDelete BIT,
        @IsScalarExecute BIT,
        @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT,
        @IsMergeDocumentQuery BIT,
        @IsProgressData BIT,
        @SchemaName NVARCHAR(255),
        @ObjectName NVARCHAR(255),
        @IsManualStatement BIT,
        @RowStatus TINYINT,
        @SourceEntityTypeId BIGINT,
        @SourceEntityHoBTId BIGINT;

    IF OBJECT_ID(N'tempdb..#EntityQueriesToApply') IS NOT NULL
        DROP TABLE #EntityQueriesToApply;

    CREATE TABLE #EntityQueriesToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NULL,
        Name NVARCHAR(500) NULL,
        Statement NVARCHAR(MAX) NULL,
        SourceEntityTypeId BIGINT NULL,
        SourceEntityHoBTId BIGINT NULL,
        IsDefaultCreate BIT NULL,
        IsDefaultRead BIT NULL,
        IsDefaultUpdate BIT NULL,
        IsDefaultDelete BIT NULL,
        IsScalarExecute BIT NULL,
        IsDefaultValidation BIT NULL,
        IsDefaultDataPills BIT NULL,
        IsMergeDocumentQuery BIT NULL,
        IsProgressData BIT NULL,
        SchemaName NVARCHAR(255) NULL,
        ObjectName NVARCHAR(255) NULL,
        IsManualStatement BIT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #EntityQueriesToApply
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        jsonPayload.Statement,
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCreate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultRead')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultUpdate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDelete')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsScalarExecute')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultValidation')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDataPills')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMergeDocumentQuery')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsProgressData')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsManualStatement')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS jsonPayload
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries';

    DECLARE EntityQueries_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            RowStatus,
            Name,
            Statement,
            SourceEntityTypeId,
            SourceEntityHoBTId,
            IsDefaultCreate,
            IsDefaultRead,
            IsDefaultUpdate,
            IsDefaultDelete,
            IsScalarExecute,
            IsDefaultValidation,
            IsDefaultDataPills,
            IsMergeDocumentQuery,
            IsProgressData,
            SchemaName,
            ObjectName,
            IsManualStatement
        FROM #EntityQueriesToApply
        ORDER BY SourceRowId;

    OPEN EntityQueries_Cursor;

    FETCH NEXT FROM EntityQueries_Cursor
    INTO
        @Guid,
        @RowStatus,
        @Name,
        @Statement,
        @SourceEntityTypeId,
        @SourceEntityHoBTId,
        @IsDefaultCreate,
        @IsDefaultRead,
        @IsDefaultUpdate,
        @IsDefaultDelete,
        @IsScalarExecute,
        @IsDefaultValidation,
        @IsDefaultDataPills,
        @IsMergeDocumentQuery,
        @IsProgressData,
        @SchemaName,
        @ObjectName,
        @IsManualStatement;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EntityTypeGuid = NULL;
        SET @EntityHoBTGuid = NULL;

        SELECT
            @EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @SourceEntityTypeId;

        SELECT
            @EntityHoBTGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityHobts'
          AND lookup.SourceRowId = @SourceEntityHoBTId;

        IF @EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityQueries apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @SourceEntityTypeId), N'<NULL>'), N' for query ', COALESCE(@Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityQueries.');
            THROW 52020, @MissingEntityTypeMessage, 1;
        END;

        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityQueryUpsert
            @Name = @Name,
            @RowStatus = @RowStatus,
            @Statement = @Statement,
            @EntityTypeGuid = @EntityTypeGuid,
            @IsDefaultCreate = @IsDefaultCreate,
            @IsDefaultRead = @IsDefaultRead,
            @IsDefaultUpdate = @IsDefaultUpdate,
            @IsDefaultDelete = @IsDefaultDelete,
            @IsScalarExecute = @IsScalarExecute,
            @IsDefaultValidation = @IsDefaultValidation,
            @EntityHoBTGuid = @EntityHoBTGuid,
            @IsDefaultDataPills = @IsDefaultDataPills,
            @IsMergeDocumentQuery = @IsMergeDocumentQuery,
            @IsProgressData = @IsProgressData,
            @SchemaName = @SchemaName,
            @ObjectName = @ObjectName,
            @IsManualStatement = @IsManualStatement,
            @Guid = @EntityQueryGuid OUTPUT;

        FETCH NEXT FROM EntityQueries_Cursor
        INTO
            @Guid,
            @RowStatus,
            @Name,
            @Statement,
            @SourceEntityTypeId,
            @SourceEntityHoBTId,
            @IsDefaultCreate,
            @IsDefaultRead,
            @IsDefaultUpdate,
            @IsDefaultDelete,
            @IsScalarExecute,
            @IsDefaultValidation,
            @IsDefaultDataPills,
            @IsMergeDocumentQuery,
            @IsProgressData,
            @SchemaName,
            @ObjectName,
            @IsManualStatement;
    END;

    CLOSE EntityQueries_Cursor;
    DEALLOCATE EntityQueries_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityQueries',
        @StepStatus = N'Succeeded',
        @Message = N'Entity queries applied.',
        @DetailsJson = N'{}';

/* =========================================================
   5. SCore.EntityProperties
   ========================================================= */

DECLARE
    @EP_RowStatus TINYINT,
    @EP_Name NVARCHAR(500),
    @EP_SourceLanguageLabelID BIGINT,
    @EP_SourceEntityHoBTID BIGINT,
    @EP_SourceEntityDataTypeID BIGINT,
    @EP_SourceEntityPropertyGroupID BIGINT,
    @EP_SourceDropDownListDefinitionID BIGINT,
    @EP_SourceRowId BIGINT,
    @EP_LanguageLabelGuid UNIQUEIDENTIFIER,
    @EP_EntityHoBTGuid UNIQUEIDENTIFIER,
    @EP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER,
    @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER,
    @EP_IsReadOnly BIT,
    @EP_IsImmutable BIT,
    @EP_IsUppercase BIT,
    @EP_IsHidden BIT,
    @EP_IsCompulsory BIT,
    @EP_MaxLength INT,
    @EP_Precision INT,
    @EP_Scale INT,
    @EP_DoNotTrackChanges BIT,
    @EP_SortOrder SMALLINT,
    @EP_GroupSortOrder SMALLINT,
    @EP_IsObjectLabel BIT,
    @EP_IsParentRelationship BIT,
    @EP_IsIncludedInformation BIT,
    @EP_IsLatitude BIT,
    @EP_IsLongitude BIT,
    @EP_FixDefaultValue NVARCHAR(100),
    @EP_SqlDefaultValueStatement NVARCHAR(MAX),
    @EP_AllowBulkChange BIT,
    @EP_IsVirtual BIT,
    @EP_ShowOnMobile BIT,
    @EP_IsAlwaysVisibleInGroup BIT,
    @EP_IsAlwaysVisibleInGroup_Mobile BIT;

IF OBJECT_ID(N'tempdb..#EntityPropertiesToApply') IS NOT NULL
    DROP TABLE #EntityPropertiesToApply;

CREATE TABLE #EntityPropertiesToApply
(
    Guid UNIQUEIDENTIFIER NOT NULL,
    RowStatus TINYINT NULL,
    Name NVARCHAR(500) NULL,
    SourceLanguageLabelID BIGINT NULL,
    SourceEntityHoBTID BIGINT NULL,
    SourceEntityDataTypeID BIGINT NULL,
    IsReadOnly BIT NULL,
    IsImmutable BIT NULL,
    IsUppercase BIT NULL,
    IsHidden BIT NULL,
    IsCompulsory BIT NULL,
    MaxLength INT NULL,
    PrecisionValue INT NULL,
    ScaleValue INT NULL,
    DoNotTrackChanges BIT NULL,
    SourceEntityPropertyGroupID BIGINT NULL,
    SortOrder SMALLINT NULL,
    GroupSortOrder SMALLINT NULL,
    IsObjectLabel BIT NULL,
    SourceDropDownListDefinitionID BIGINT NULL,
    IsParentRelationship BIT NULL,
    IsIncludedInformation BIT NULL,
    IsLatitude BIT NULL,
    IsLongitude BIT NULL,
    FixDefaultValue NVARCHAR(100) NULL,
    SqlDefaultValueStatement NVARCHAR(MAX) NULL,
    AllowBulkChange BIT NULL,
    IsVirtual BIT NULL,
    ShowOnMobile BIT NULL,
    IsAlwaysVisibleInGroup BIT NULL,
    IsAlwaysVisibleInGroup_Mobile BIT NULL,
    SourceRowId BIGINT NULL
);

INSERT INTO #EntityPropertiesToApply
SELECT
    sr.SourceRowGuid,
    TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
    JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnly')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsImmutable')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsUppercase')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MaxLength')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Precision')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Scale')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupId'))),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GroupSortOrder')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsObjectLabel')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsParentRelationship')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsIncludedInformation')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLatitude')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLongitude')),
    ISNULL
    (
        COALESCE
        (
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixedDefaultValue'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixDefaultValue')
        ),
        N''
    ),
    epjson.SqlDefaultValueStatement,
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsVirtual')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup_Mobile')),
    sr.SourceRowId
FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
OUTER APPLY OPENJSON(sr.SourcePayloadJson)
WITH
(
    SqlDefaultValueStatement NVARCHAR(MAX) N'$.SqlDefaultValueStatement'
) AS epjson
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND tr.SchemaName = N'SCore'
  AND tr.TableName = N'EntityProperties';

DECLARE EntityProperties_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        Guid,
        RowStatus,
        Name,
        SourceLanguageLabelID,
        SourceEntityHoBTID,
        SourceEntityDataTypeID,
        IsReadOnly,
        IsImmutable,
        IsUppercase,
        IsHidden,
        IsCompulsory,
        MaxLength,
        PrecisionValue,
        ScaleValue,
        DoNotTrackChanges,
        SourceEntityPropertyGroupID,
        SortOrder,
        GroupSortOrder,
        IsObjectLabel,
        SourceDropDownListDefinitionID,
        IsParentRelationship,
        IsIncludedInformation,
        IsLatitude,
        IsLongitude,
        FixDefaultValue,
        SqlDefaultValueStatement,
        AllowBulkChange,
        IsVirtual,
        ShowOnMobile,
        IsAlwaysVisibleInGroup,
        IsAlwaysVisibleInGroup_Mobile,
        SourceRowId
    FROM #EntityPropertiesToApply
    ORDER BY SourceRowId;

OPEN EntityProperties_Cursor;

FETCH NEXT FROM EntityProperties_Cursor
INTO
    @Guid,
    @EP_RowStatus,
    @EP_Name,
    @EP_SourceLanguageLabelID,
    @EP_SourceEntityHoBTID,
    @EP_SourceEntityDataTypeID,
    @EP_IsReadOnly,
    @EP_IsImmutable,
    @EP_IsUppercase,
    @EP_IsHidden,
    @EP_IsCompulsory,
    @EP_MaxLength,
    @EP_Precision,
    @EP_Scale,
    @EP_DoNotTrackChanges,
    @EP_SourceEntityPropertyGroupID,
    @EP_SortOrder,
    @EP_GroupSortOrder,
    @EP_IsObjectLabel,
    @EP_SourceDropDownListDefinitionID,
    @EP_IsParentRelationship,
    @EP_IsIncludedInformation,
    @EP_IsLatitude,
    @EP_IsLongitude,
    @EP_FixDefaultValue,
    @EP_SqlDefaultValueStatement,
    @EP_AllowBulkChange,
    @EP_IsVirtual,
    @EP_ShowOnMobile,
    @EP_IsAlwaysVisibleInGroup,
    @EP_IsAlwaysVisibleInGroup_Mobile,
    @EP_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EP_LanguageLabelGuid = NULL;
    SET @EP_EntityHoBTGuid = NULL;
    SET @EP_EntityDataTypeGuid = NULL;
    SET @EP_EntityPropertyGroupGuid = NULL;
    SET @EP_DropDownListDefinitionGuid = NULL;
    SET @EP_FixDefaultValue = ISNULL(@EP_FixDefaultValue, N'');
    SELECT
        @EP_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @EP_SourceLanguageLabelID;

    SELECT
        @EP_EntityHoBTGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityHobts'
      AND lookup.SourceRowId = @EP_SourceEntityHoBTID;

    IF @EP_SourceEntityDataTypeID IS NULL OR @EP_SourceEntityDataTypeID <= 0
    BEGIN
        SET @EP_EntityDataTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityDataTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityDataTypes'
          AND lookup.SourceRowId = @EP_SourceEntityDataTypeID;
    END;

    IF @EP_SourceEntityPropertyGroupID IS NULL OR @EP_SourceEntityPropertyGroupID <= 0
    BEGIN
        SET @EP_EntityPropertyGroupGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityPropertyGroupGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityPropertyGroups'
          AND lookup.SourceRowId = @EP_SourceEntityPropertyGroupID;
    END;

    IF @EP_SourceDropDownListDefinitionID IS NULL OR @EP_SourceDropDownListDefinitionID <= 0
    BEGIN
        SET @EP_DropDownListDefinitionGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_DropDownListDefinitionGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'DropDownListDefinitions'
          AND lookup.SourceRowId = @EP_SourceDropDownListDefinitionID;
    END;

    IF @EP_EntityDataTypeGuid IS NULL
    BEGIN
        DECLARE @MissingEntityDataTypeMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityDataType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityDataTypeID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityDataTypes is staged/applied before SCore.EntityProperties.');
        THROW 52022, @MissingEntityDataTypeMessage, 1;
    END;

    IF @EP_EntityPropertyGroupGuid IS NULL
    BEGIN
        DECLARE @MissingEntityPropertyGroupMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityPropertyGroup source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityPropertyGroupID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityPropertyGroups is staged/applied before SCore.EntityProperties.');
        THROW 52023, @MissingEntityPropertyGroupMessage, 1;
    END;

    IF @EP_DropDownListDefinitionGuid IS NULL
    BEGIN
        DECLARE @MissingDropDownListDefinitionMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve DropDownListDefinition source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceDropDownListDefinitionID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.DropDownListDefinitions is applied before SCore.EntityProperties.');
        THROW 52024, @MissingDropDownListDefinitionMessage, 1;
    END;

    DECLARE @ExistingEntityPropertyGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingEntityPropertyGuid = ep.Guid
    FROM SCore.EntityProperties AS ep
    INNER JOIN SCore.EntityHobts AS eh
        ON eh.ID = ep.EntityHoBTID
       AND eh.RowStatus NOT IN (0,254)
    WHERE eh.Guid = @EP_EntityHoBTGuid
      AND ep.Name = @EP_Name
      AND ep.RowStatus NOT IN (0,254)
      AND ep.Guid <> @Guid
    ORDER BY ep.ID;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = ISNULL(@ExistingEntityPropertyGuid, @Guid);

    IF @ExistingEntityPropertyGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingEntityPropertyGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityProperties'
          AND lookup.SourceRowId = @EP_SourceRowId;
    END;

    EXEC SCore.EntityPropertyUpsert
        @Name = @EP_Name,
        @RowStatus = @EP_RowStatus,
        @LanguageLabelGuid = @EP_LanguageLabelGuid,
        @EntityHobtGuid = @EP_EntityHoBTGuid,
        @EntityDataTypeGuid = @EP_EntityDataTypeGuid,
        @IsReadOnly = @EP_IsReadOnly,
        @IsImmutable = @EP_IsImmutable,
        @IsUppercase = @EP_IsUppercase,
        @IsHidden = @EP_IsHidden,
        @IsCompulsory = @EP_IsCompulsory,
        @MaxLength = @EP_MaxLength,
        @Precision = @EP_Precision,
        @Scale = @EP_Scale,
        @DoNotTrackChanges = @EP_DoNotTrackChanges,
        @EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid,
        @SortOrder = @EP_SortOrder,
        @GroupSortOrder = @EP_GroupSortOrder,
        @IsObjectLabel = @EP_IsObjectLabel,
        @DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid,
        @IsParentRelationship = @EP_IsParentRelationship,
        @IsIncludedInformation = @EP_IsIncludedInformation,
        @IsLatitude = @EP_IsLatitude,
        @IsLongitude = @EP_IsLongitude,
        @FixDefaultValue = @EP_FixDefaultValue,
        @SqlDefaultValueStatement = @EP_SqlDefaultValueStatement,
        @AllowBulkChange = @EP_AllowBulkChange,
        @IsVirtual = @EP_IsVirtual,
        @ShowOnMobile = @EP_ShowOnMobile,
        @IsAlwaysVisibleInGroup = @EP_IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @EP_IsAlwaysVisibleInGroup_Mobile,
        @Guid = @EntityPropertyGuid OUTPUT;

    FETCH NEXT FROM EntityProperties_Cursor
    INTO
        @Guid,
        @EP_RowStatus,
        @EP_Name,
        @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID,
        @EP_IsReadOnly,
        @EP_IsImmutable,
        @EP_IsUppercase,
        @EP_IsHidden,
        @EP_IsCompulsory,
        @EP_MaxLength,
        @EP_Precision,
        @EP_Scale,
        @EP_DoNotTrackChanges,
        @EP_SourceEntityPropertyGroupID,
        @EP_SortOrder,
        @EP_GroupSortOrder,
        @EP_IsObjectLabel,
        @EP_SourceDropDownListDefinitionID,
        @EP_IsParentRelationship,
        @EP_IsIncludedInformation,
        @EP_IsLatitude,
        @EP_IsLongitude,
        @EP_FixDefaultValue,
        @EP_SqlDefaultValueStatement,
        @EP_AllowBulkChange,
        @EP_IsVirtual,
        @EP_ShowOnMobile,
        @EP_IsAlwaysVisibleInGroup,
        @EP_IsAlwaysVisibleInGroup_Mobile,
        @EP_SourceRowId;
END;

CLOSE EntityProperties_Cursor;
DEALLOCATE EntityProperties_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityProperties',
    @StepStatus = N'Succeeded',
    @Message = N'Entity properties applied.',
    @DetailsJson = N'{}';

/* =========================================================
   6. SCore.EntityQueryParameters
   ========================================================= */

DECLARE
    @EQP_RowStatus TINYINT,
    @EQP_Name NVARCHAR(500),
    @EQP_SourceEntityQueryID BIGINT,
    @EQP_SourceEntityDataTypeID BIGINT,
    @EQP_SourceMappedEntityPropertyID BIGINT,
    @EQP_EntityQueryGuid UNIQUEIDENTIFIER,
    @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER,
    @EQP_DefaultValue NVARCHAR(200),
    @EQP_IsInput BIT,
    @EQP_IsOutput BIT,
    @EQP_IsReturnColumn BIT;

DECLARE EntityQueryParameters_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultValue'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsOutput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn'))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueryParameters'
    ORDER BY sr.SourceRowId;

OPEN EntityQueryParameters_Cursor;

FETCH NEXT FROM EntityQueryParameters_Cursor
INTO
    @Guid,
    @EQP_RowStatus,
    @EQP_Name,
    @EQP_SourceEntityQueryID,
    @EQP_SourceEntityDataTypeID,
    @EQP_SourceMappedEntityPropertyID,
    @EQP_DefaultValue,
    @EQP_IsInput,
    @EQP_IsOutput,
    @EQP_IsReturnColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EQP_EntityQueryGuid = NULL;
    SET @EQP_EntityDataTypeGuid = NULL;
    SET @EQP_MappedEntityPropertyGuid = NULL;
    SELECT
        @EQP_EntityQueryGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityQueries'
      AND lookup.SourceRowId = @EQP_SourceEntityQueryID;

    SELECT
        @EQP_EntityDataTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityDataTypes'
      AND lookup.SourceRowId = @EQP_SourceEntityDataTypeID;

    SELECT
        @EQP_MappedEntityPropertyGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityProperties'
      AND lookup.SourceRowId = @EQP_SourceMappedEntityPropertyID;

    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityQueryParameterUpsert
        @Name = @EQP_Name,
        @RowStatus = @EQP_RowStatus,
        @EntityQueryGuid = @EQP_EntityQueryGuid,
        @EntityDataTypeGuid = @EQP_EntityDataTypeGuid,
        @MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid,
        @DefaultValue = @EQP_DefaultValue,
        @IsInput = @EQP_IsInput,
        @IsOutput = @EQP_IsOutput,
        @IsReturnColumn = @EQP_IsReturnColumn,
        @Guid = @EntityQueryParameterGuid OUTPUT;

    FETCH NEXT FROM EntityQueryParameters_Cursor
    INTO
        @Guid,
        @EQP_RowStatus,
        @EQP_Name,
        @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID,
        @EQP_DefaultValue,
        @EQP_IsInput,
        @EQP_IsOutput,
        @EQP_IsReturnColumn;
END;

CLOSE EntityQueryParameters_Cursor;
DEALLOCATE EntityQueryParameters_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityQueryParameters',
    @StepStatus = N'Succeeded',
    @Message = N'Entity query parameters applied.',
    @DetailsJson = N'{}';


/* =========================================================
   7. SUserInterface.GridDefinitions
   ========================================================= */

DECLARE
    @GD_RowStatus TINYINT,
    @GD_Code NVARCHAR(30),
    @GD_TabName NVARCHAR(250),
    @GD_ShowAsTiles BIT,
    @GD_PageUri NVARCHAR(250),
    @GD_SourceLanguageLabelID BIGINT,
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridDefinitions_Cursor;

FETCH NEXT FROM GridDefinitions_Cursor
INTO
    @Guid,
    @GD_RowStatus,
    @GD_Code,
    @GD_TabName,
    @GD_ShowAsTiles,
    @GD_PageUri,
    @GD_SourceLanguageLabelID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;
    SELECT
        @GD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GD_SourceLanguageLabelID;

    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridDefinitionUpsert
        @Code = @GD_Code,
        @RowStatus = @GD_RowStatus,
        @TabName = @GD_TabName,
        @ShowAsTiles = @GD_ShowAsTiles,
        @PageUri = @GD_PageUri,
        @LanguageLabelGuid = @GD_LanguageLabelGuid,
        @Guid = @GridDefinitionGuid OUTPUT;

    FETCH NEXT FROM GridDefinitions_Cursor
    INTO
        @Guid,
        @GD_RowStatus,
        @GD_Code,
        @GD_TabName,
        @GD_ShowAsTiles,
        @GD_PageUri,
        @GD_SourceLanguageLabelID;
END;

CLOSE GridDefinitions_Cursor;
DEALLOCATE GridDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   8. SUserInterface.GridViewDefinitions
   ========================================================= */

DECLARE
    @GVD_RowStatus TINYINT,
    @GVD_Code NVARCHAR(20),
    @GVD_SourceGridDefinitionID BIGINT,
    @GVD_DetailPageUri NVARCHAR(250),
    @GVD_SqlQuery NVARCHAR(MAX),
    @GVD_DefaultSortColumnName NVARCHAR(250),
    @GVD_SecurableCode NVARCHAR(20),
    @GVD_DisplayOrder INT,
    @GVD_DisplayGroupName NVARCHAR(50),
    @GVD_MetricSqlQuery NVARCHAR(MAX),
    @GVD_ShowMetric BIT,
    @GVD_IsDetailWindowed BIT,
    @GVD_SourceEntityTypeID BIGINT,
    @GVD_SourceMetricTypeID BIGINT,
    @GVD_MetricMin INT,
    @GVD_MetricMax INT,
    @GVD_MetricMinorUnit INT,
    @GVD_MetricMajorUnit INT,
    @GVD_MetricStartAngle INT,
    @GVD_MetricEndAngle INT,
    @GVD_MetricReversed BIT,
    @GVD_MetricRange1Min DECIMAL(18,0),
    @GVD_MetricRange1Max DECIMAL(18,0),
    @GVD_MetricRange1ColourHex NVARCHAR(10),
    @GVD_MetricRange2Min DECIMAL(18,0),
    @GVD_MetricRange2Max DECIMAL(18,0),
    @GVD_MetricRange2ColourHex NVARCHAR(10),
    @GVD_IsDefaultSortDescending BIT,
    @GVD_ShowOnMobile BIT,
    @GVD_AllowNew BIT,
    @GVD_AllowExcelExport BIT,
    @GVD_AllowPdfExport BIT,
    @GVD_AllowCsvExport BIT,
    @GVD_SourceLanguageLabelID BIGINT,
    @GVD_SourceDrawerIconID BIGINT,
    @GVD_SourceGridViewTypeID BIGINT,
    @GVD_AllowBulkChange BIT,
    @GVD_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_TreeListOrderBy NVARCHAR(100),
    @GVD_TreeListGroupBy NVARCHAR(100),
    @GVD_ShowOnDashboard BIT,
    @GVD_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGroupBy NVARCHAR(100),
    @GVD_IsHidden BIT,
    @GVD_GridDefinitionGuid UNIQUEIDENTIFIER,
    @GVD_EntityTypeGuid UNIQUEIDENTIFIER,
    @GVD_MetricTypeGuid UNIQUEIDENTIFIER,
    @GVD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVD_DrawerIconGuid UNIQUEIDENTIFIER,
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER;

DECLARE GridViewDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUri'),
        jsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SecurableCode'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayOrder')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayGroupName'),
        jsonValues.MetricSqlQuery,
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowMetric')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMin')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMax')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMinorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMajorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricStartAngle')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricEndAngle')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricReversed')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1ColourHex'),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2ColourHex'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultSortDescending')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowNew')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowExcelExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowPdfExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowCsvExport')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListFirstOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListSecondOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListThirdOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnDashboard')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListCreatedOnColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListRedStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListOrangeStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGreenStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden'))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery',
        MetricSqlQuery NVARCHAR(MAX) N'$.MetricSqlQuery'
    ) AS jsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewDefinitions_Cursor;

FETCH NEXT FROM GridViewDefinitions_Cursor
INTO
    @Guid,
    @GVD_RowStatus,
    @GVD_Code,
    @GVD_SourceGridDefinitionID,
    @GVD_DetailPageUri,
    @GVD_SqlQuery,
    @GVD_DefaultSortColumnName,
    @GVD_SecurableCode,
    @GVD_DisplayOrder,
    @GVD_DisplayGroupName,
    @GVD_MetricSqlQuery,
    @GVD_ShowMetric,
    @GVD_IsDetailWindowed,
    @GVD_SourceEntityTypeID,
    @GVD_SourceMetricTypeID,
    @GVD_MetricMin,
    @GVD_MetricMax,
    @GVD_MetricMinorUnit,
    @GVD_MetricMajorUnit,
    @GVD_MetricStartAngle,
    @GVD_MetricEndAngle,
    @GVD_MetricReversed,
    @GVD_MetricRange1Min,
    @GVD_MetricRange1Max,
    @GVD_MetricRange1ColourHex,
    @GVD_MetricRange2Min,
    @GVD_MetricRange2Max,
    @GVD_MetricRange2ColourHex,
    @GVD_IsDefaultSortDescending,
    @GVD_ShowOnMobile,
    @GVD_AllowNew,
    @GVD_AllowExcelExport,
    @GVD_AllowPdfExport,
    @GVD_AllowCsvExport,
    @GVD_SourceLanguageLabelID,
    @GVD_SourceDrawerIconID,
    @GVD_SourceGridViewTypeID,
    @GVD_AllowBulkChange,
    @GVD_TreeListFirstOrderBy,
    @GVD_TreeListSecondOrderBy,
    @GVD_TreeListThirdOrderBy,
    @GVD_TreeListOrderBy,
    @GVD_TreeListGroupBy,
    @GVD_ShowOnDashboard,
    @GVD_FilteredListCreatedOnColumn,
    @GVD_FilteredListRedStatusIndicatorTxt,
    @GVD_FilteredListOrangeStatusIndicatorTxt,
    @GVD_FilteredListGreenStatusIndicatorTxt,
    @GVD_FilteredListGroupBy,
    @GVD_IsHidden;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVD_GridDefinitionGuid = NULL;
    SET @GVD_EntityTypeGuid = NULL;
    SET @GVD_MetricTypeGuid = NULL;
    SET @GVD_LanguageLabelGuid = NULL;
    SET @GVD_DrawerIconGuid = NULL;
    SET @GVD_GridViewTypeGuid = NULL;
    SELECT
        @GVD_GridDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridDefinitions'
      AND lookup.SourceRowId = @GVD_SourceGridDefinitionID;

    SELECT
        @GVD_EntityTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityTypes'
      AND lookup.SourceRowId = @GVD_SourceEntityTypeID;

    SELECT
        @GVD_MetricTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'MetricTypes'
      AND lookup.SourceRowId = @GVD_SourceMetricTypeID;

    SELECT
        @GVD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVD_SourceLanguageLabelID;

    SELECT
        @GVD_DrawerIconGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'Icons'
      AND lookup.SourceRowId = @GVD_SourceDrawerIconID;

    SELECT
        @GVD_GridViewTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewTypes'
      AND lookup.SourceRowId = @GVD_SourceGridViewTypeID;

    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewDefinitionUpsert
        @Code = @GVD_Code,
        @RowStatus = @GVD_RowStatus,
        @GridDefinitionGuid = @GVD_GridDefinitionGuid,
        @DetailPageUri = @GVD_DetailPageUri,
        @SqlQuery = @GVD_SqlQuery,
        @DefaultSortColumnName = @GVD_DefaultSortColumnName,
        @SecurableCode = @GVD_SecurableCode,
        @DisplayOrder = @GVD_DisplayOrder,
        @DisplayGroupName = @GVD_DisplayGroupName,
        @MetricSqlQuery = @GVD_MetricSqlQuery,
        @ShowMetric = @GVD_ShowMetric,
        @IsDetailWindowed = @GVD_IsDetailWindowed,
        @EntityTypeGuid = @GVD_EntityTypeGuid,
        @MetricTypeGuid = @GVD_MetricTypeGuid,
        @MetricMin = @GVD_MetricMin,
        @MetricMax = @GVD_MetricMax,
        @MetricMinorUnit = @GVD_MetricMinorUnit,
        @MetricMajorUnit = @GVD_MetricMajorUnit,
        @MetricStartAngle = @GVD_MetricStartAngle,
        @MetricEndAngle = @GVD_MetricEndAngle,
        @MetricReversed = @GVD_MetricReversed,
        @MetricRange1Min = @GVD_MetricRange1Min,
        @MetricRange1Max = @GVD_MetricRange1Max,
        @MetricRange1ColourHex = @GVD_MetricRange1ColourHex,
        @MetricRange2Min = @GVD_MetricRange2Min,
        @MetricRange2Max = @GVD_MetricRange2Max,
        @MetricRange2ColourHex = @GVD_MetricRange2ColourHex,
        @IsDefaultSortDescending = @GVD_IsDefaultSortDescending,
        @AllowNew = @GVD_AllowNew,
        @AllowExcelExport = @GVD_AllowExcelExport,
        @AllowPdfExport = @GVD_AllowPdfExport,
        @AllowCsvExport = @GVD_AllowCsvExport,
        @LanguageLabelGuid = @GVD_LanguageLabelGuid,
        @DrawerIconGuid = @GVD_DrawerIconGuid,
        @GridViewTypeGuid = @GVD_GridViewTypeGuid,
        @AllowBulkChange = @GVD_AllowBulkChange,
        @Guid = @GridViewDefinitionGuid OUTPUT,
        @ShowOnMobile = @GVD_ShowOnMobile,
        @TreeListFirstOrderBy = @GVD_TreeListFirstOrderBy,
        @TreeListSecondOrderBy = @GVD_TreeListSecondOrderBy,
        @TreeListThirdOrderBy = @GVD_TreeListThirdOrderBy,
        @TreeListOrderBy = @GVD_TreeListOrderBy,
        @TreeListGroupBy = @GVD_TreeListGroupBy,
        @ShowOnDashboard = @GVD_ShowOnDashboard,
        @FilteredListCreatedOnColumn = @GVD_FilteredListCreatedOnColumn,
        @FilteredListRedStatusIndicatorTxt = @GVD_FilteredListRedStatusIndicatorTxt,
        @FilteredListOrangeStatusIndicatorTxt = @GVD_FilteredListOrangeStatusIndicatorTxt,
        @FilteredListGreenStatusIndicatorTxt = @GVD_FilteredListGreenStatusIndicatorTxt,
        @FilteredListGroupBy = @GVD_FilteredListGroupBy,
        @IsHidden = @GVD_IsHidden;

    FETCH NEXT FROM GridViewDefinitions_Cursor
    INTO
        @Guid,
        @GVD_RowStatus,
        @GVD_Code,
        @GVD_SourceGridDefinitionID,
        @GVD_DetailPageUri,
        @GVD_SqlQuery,
        @GVD_DefaultSortColumnName,
        @GVD_SecurableCode,
        @GVD_DisplayOrder,
        @GVD_DisplayGroupName,
        @GVD_MetricSqlQuery,
        @GVD_ShowMetric,
        @GVD_IsDetailWindowed,
        @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID,
        @GVD_MetricMin,
        @GVD_MetricMax,
        @GVD_MetricMinorUnit,
        @GVD_MetricMajorUnit,
        @GVD_MetricStartAngle,
        @GVD_MetricEndAngle,
        @GVD_MetricReversed,
        @GVD_MetricRange1Min,
        @GVD_MetricRange1Max,
        @GVD_MetricRange1ColourHex,
        @GVD_MetricRange2Min,
        @GVD_MetricRange2Max,
        @GVD_MetricRange2ColourHex,
        @GVD_IsDefaultSortDescending,
        @GVD_ShowOnMobile,
        @GVD_AllowNew,
        @GVD_AllowExcelExport,
        @GVD_AllowPdfExport,
        @GVD_AllowCsvExport,
        @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID,
        @GVD_AllowBulkChange,
        @GVD_TreeListFirstOrderBy,
        @GVD_TreeListSecondOrderBy,
        @GVD_TreeListThirdOrderBy,
        @GVD_TreeListOrderBy,
        @GVD_TreeListGroupBy,
        @GVD_ShowOnDashboard,
        @GVD_FilteredListCreatedOnColumn,
        @GVD_FilteredListRedStatusIndicatorTxt,
        @GVD_FilteredListOrangeStatusIndicatorTxt,
        @GVD_FilteredListGreenStatusIndicatorTxt,
        @GVD_FilteredListGroupBy,
        @GVD_IsHidden;
END;

CLOSE GridViewDefinitions_Cursor;
DEALLOCATE GridViewDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   9. SUserInterface.GridViewColumnDefinitions
   ========================================================= */

DECLARE
    @GVCD_RowStatus TINYINT,
    @GVCD_Name NVARCHAR(250),
    @GVCD_SourceGridViewDefinitionID BIGINT,
    @GVCD_ColumnOrder INT,
    @GVCD_IsPrimaryKey BIT,
    @GVCD_IsHidden BIT,
    @GVCD_IsFiltered BIT,
    @GVCD_IsCombo BIT,
    @GVCD_DisplayFormat NVARCHAR(50),
    @GVCD_Width NVARCHAR(10),
    @GVCD_SourceLanguageLabelID BIGINT,
    @GVCD_TopHeaderCategory NVARCHAR(50),
    @GVCD_TopHeaderCategoryOrder INT,
    @GVCD_SourceRowId BIGINT,
    @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridViewColumnDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.ColumnOrder')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsPrimaryKey')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsFiltered')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCombo')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayFormat'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Width'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategory'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategoryOrder')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewColumnDefinitions_Cursor;

FETCH NEXT FROM GridViewColumnDefinitions_Cursor
INTO
    @Guid,
    @GVCD_RowStatus,
    @GVCD_Name,
    @GVCD_SourceGridViewDefinitionID,
    @GVCD_ColumnOrder,
    @GVCD_IsPrimaryKey,
    @GVCD_IsHidden,
    @GVCD_IsFiltered,
    @GVCD_IsCombo,
    @GVCD_DisplayFormat,
    @GVCD_Width,
    @GVCD_SourceLanguageLabelID,
    @GVCD_TopHeaderCategory,
    @GVCD_TopHeaderCategoryOrder,
    @GVCD_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVCD_GridViewDefinitionGuid = NULL;
    SET @GVCD_LanguageLabelGuid = NULL;
    SELECT
        @GVCD_GridViewDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewDefinitions'
      AND lookup.SourceRowId = @GVCD_SourceGridViewDefinitionID;

    SELECT
        @GVCD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVCD_SourceLanguageLabelID;

    DECLARE @ExistingGridViewColumnDefinitionGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingGridViewColumnDefinitionGuid = gvcd.Guid
    FROM SUserInterface.GridViewColumnDefinitions AS gvcd
    INNER JOIN SUserInterface.GridViewDefinitions AS gvd
        ON gvd.ID = gvcd.GridViewDefinitionID
       AND gvd.RowStatus NOT IN (0,254)
    WHERE gvd.Guid = @GVCD_GridViewDefinitionGuid
      AND gvcd.RowStatus NOT IN (0,254)
      AND gvcd.Guid <> @Guid
      AND
      (
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 1
              AND gvcd.IsPrimaryKey = 1
          )
          OR
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 0
              AND gvcd.Name = @GVCD_Name
          )
      )
    ORDER BY
        CASE WHEN ISNULL(@GVCD_IsPrimaryKey, 0) = 1 AND gvcd.IsPrimaryKey = 1 THEN 0 ELSE 1 END,
        gvcd.ID;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@ExistingGridViewColumnDefinitionGuid, @Guid);

    IF @ExistingGridViewColumnDefinitionGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingGridViewColumnDefinitionGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'GridViewColumnDefinitions'
          AND lookup.SourceRowId = @GVCD_SourceRowId;
    END;

    EXEC SUserInterface.GridViewColumnDefinitionUpsert
        @Name = @GVCD_Name,
        @RowStatus = @GVCD_RowStatus,
        @GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid,
        @ColumnOrder = @GVCD_ColumnOrder,
        @IsPrimaryKey = @GVCD_IsPrimaryKey,
        @IsHidden = @GVCD_IsHidden,
        @IsFiltered = @GVCD_IsFiltered,
        @IsCombo = @GVCD_IsCombo,
        @DisplayFormat = @GVCD_DisplayFormat,
        @Width = @GVCD_Width,
        @LanguageLabelGuid = @GVCD_LanguageLabelGuid,
        @Guid = @GridViewColumnDefinitionGuid OUTPUT,
        @TopHeaderCategory = @GVCD_TopHeaderCategory,
        @TopHeaderCategoryOrder = @GVCD_TopHeaderCategoryOrder;

    FETCH NEXT FROM GridViewColumnDefinitions_Cursor
    INTO
        @Guid,
        @GVCD_RowStatus,
        @GVCD_Name,
        @GVCD_SourceGridViewDefinitionID,
        @GVCD_ColumnOrder,
        @GVCD_IsPrimaryKey,
        @GVCD_IsHidden,
        @GVCD_IsFiltered,
        @GVCD_IsCombo,
        @GVCD_DisplayFormat,
        @GVCD_Width,
        @GVCD_SourceLanguageLabelID,
        @GVCD_TopHeaderCategory,
        @GVCD_TopHeaderCategoryOrder,
        @GVCD_SourceRowId;
END;

CLOSE GridViewColumnDefinitions_Cursor;
DEALLOCATE GridViewColumnDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewColumnDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view column definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   11. Labels
   ========================================================= */

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyLabels',
    @StepStatus = N'Succeeded',
    @Message = N'Labels are applied through SCore.LanguageLabels and SCore.LanguageLabelTranslations handlers.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations"]}';

UPDATE SMigration.Metadata_Run
SET
    RunStatus = N'AppliedUiMetadata',
    AppliedOnUtc = SYSUTCDATETIME()
WHERE Guid = @RunGuid
  AND RowStatus NOT IN (0,254);

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMetadataComplete',
    @StepStatus = N'Succeeded',
    @Message = N'Core and UI metadata apply handlers completed.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityDataTypes","SUserInterface.Icons","SCore.EntityTypes","SCore.EntityHobts","SUserInterface.DropDownListDefinitions","SCore.EntityPropertyGroups","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions"]}';

COMMIT TRANSACTION;
END;

GO
