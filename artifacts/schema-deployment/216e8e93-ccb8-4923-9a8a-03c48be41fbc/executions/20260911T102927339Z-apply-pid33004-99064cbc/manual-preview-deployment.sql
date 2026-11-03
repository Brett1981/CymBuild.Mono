/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLDEVBRE01\GENERAL
    Target database : CymBuild_QA
    Run Guid        : 216e8e93-ccb8-4923-9a8a-03c48be41fbc
    Generated UTC   : 2026-09-11T10:29:31.4679615Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_QA];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 1, @read_only = 0;
GO
EXEC [SCore].[PreDeploymentScript];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;
GO

/* Deploy StoredProcedure SMigration.MetadataApply_Run using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataApply_Run.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[MetadataApply_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataApply_Run]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0,
    @ApplySelectedOnly BIT = 1,
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISNULL(@ApplySelectedOnly, 0) <> 1
        THROW 52008, 'Metadata apply requires an explicit selected-row scope.', 1;

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
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue
          WHERE ignoredIssue.DatabaseName = @TargetDatabaseName
            AND ignoredIssue.RegistryGuid = vi.RegistryGuid
            AND ignoredIssue.SourceRowGuid = vi.SourceRowGuid
            AND ignoredIssue.IssueCode = vi.IssueCode
            AND ignoredIssue.RowStatus NOT IN (0,254)
      )
      AND
      (
          vi.IssueCode IN (N'RunNotFound', N'NoSelectedRows', N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS selected
              INNER JOIN SMigration.Metadata_StagedRows AS selectedRow
                  ON selectedRow.RunGuid = selected.RunGuid
                 AND selectedRow.RegistryGuid = selected.RegistryGuid
                 AND selectedRow.SourceRowGuid = selected.SourceRowGuid
                 AND selectedRow.RowStatus NOT IN (0,254)
              WHERE selected.RunGuid = vi.RunGuid
                AND selected.RowStatus NOT IN (0,254)
                AND selectedRow.DifferenceType IN (N'Insert', N'Update')
                AND selectedRow.RegistryGuid = vi.RegistryGuid
                AND (vi.SourceRowGuid IS NULL OR selectedRow.SourceRowGuid = vi.SourceRowGuid)
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IgnoredRecords AS selectedIgnored
                    WHERE selectedIgnored.DatabaseName = @TargetDatabaseName
                      AND selectedIgnored.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedIgnored.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedIgnored.RowStatus NOT IN (0,254)
                )
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IdentityMapOverrides AS selectedOverride
                    WHERE selectedOverride.DatabaseName = @TargetDatabaseName
                      AND selectedOverride.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedOverride.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedOverride.RowStatus NOT IN (0,254)
                )
          )
      );

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
          AND EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS selection
              WHERE selection.RunGuid = sr.RunGuid
                AND selection.RegistryGuid = sr.RegistryGuid
                AND selection.SourceRowGuid = sr.SourceRowGuid
                AND selection.RowStatus NOT IN (0,254)
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
              OR
              (tr.SchemaName = N'SJob' AND tr.TableName IN
              (
                  N'MilestoneTypes'
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

    -- A source row can be identified with an existing (different-Guid) target row two ways,
    -- neither of which is ever revisited by a per-table apply cursor below because both leave
    -- the row out of scope for insert/update (nothing to change or, for an override, deliberately
    -- excluded from #MetadataRowsToApply so no duplicate is created):
    --   1. A persistent manual Metadata_IdentityMapOverrides mapping (set from the Identity Map
    --      UI). Stage_Run's generic per-table capture does not consult this table at all, so such
    --      a row is staged as a plain Insert with TargetPayloadJson NULL even though it must
    --      resolve to the override's target Guid, never its own.
    --   2. SMigration.MetadataStage_NormaliseDifferences "naturalising" a row onto an existing
    --      target row matched by natural key (e.g. EntityProperties by EntityHoBTID+Name) when
    --      the source and target Guids differ, classifying it NoChange with TargetPayloadJson
    --      pointed at that existing target row's own identity.
    -- Any OTHER table's foreign key that resolves through this lookup must use that
    -- already-resolved target Guid - not the source's own Guid, which may not exist in target at
    -- all - or it silently resolves to nothing and the dependent insert/update fails on a NOT
    -- NULL foreign key. The manual override wins when both are somehow present, since it is an
    -- explicit, reviewed operator decision.
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
        COALESCE(
            override.TargetRowGuid,
            TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(sr.TargetPayloadJson, N'$.' + tr.GuidColumnName)),
            sr.SourceRowGuid)
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS override
        ON override.DatabaseName = @TargetDatabaseName
       AND override.RegistryGuid = sr.RegistryGuid
       AND override.SourceRowGuid = sr.SourceRowGuid
       AND override.RowStatus NOT IN (0,254)
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
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_RunSelections AS sel
          WHERE sel.RunGuid = sr.RunGuid
            AND sel.RegistryGuid = sr.RegistryGuid
            AND sel.SourceRowGuid = sr.SourceRowGuid
            AND sel.RowStatus NOT IN (0,254)
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

    IF NOT EXISTS (SELECT 1 FROM #MetadataRowsToApply)
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
    DECLARE @_Message AS NVARCHAR(50) = N'Metadata apply scoped to selected rows.'

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

    IF @EP_EntityHoBTGuid IS NULL
    BEGIN
        DECLARE @MissingEntityHoBTMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityHoBT source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityHoBTID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityHobts is staged/applied before SCore.EntityProperties.');
        THROW 52029, @MissingEntityHoBTMessage, 1;
    END;

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

/* =========================================================
   12. SJob.MilestoneTypes
   Simple reference lookup table with no business FK to resolve
   (only RowStatus and the disabled DataObjects FK). Delegates to
   the existing SJob.MilestoneTypesUpsert proc for DataObjects-atomic
   insert/update. That proc has no @RowStatus parameter, so RowStatus
   is set explicitly afterward to honor staged retirements/reactivations.
   ========================================================= */
DECLARE
    @MT_RowStatus TINYINT,
    @MT_Name NVARCHAR(100),
    @MT_Code NVARCHAR(20),
    @MT_IsActive BIT,
    @MT_IsInvoiceTrigger BIT,
    @MT_IsReviewRequired BIT,
    @MT_HelpText NVARCHAR(2000),
    @MT_HasDescription BIT,
    @MT_IsCompulsory BIT,
    @MT_IncludeStart BIT,
    @MT_IncludeSchedule BIT,
    @MT_IncludeDueDate BIT,
    @MT_HasExternalSubmission BIT,
    @MT_HasReference BIT,
    @MT_HasQuotedHours BIT,
    @MilestoneTypeGuid UNIQUEIDENTIFIER;

DECLARE MilestoneTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsActive')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInvoiceTrigger')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReviewRequired')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasDescription')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IncludeStart')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IncludeSchedule')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IncludeDueDate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasExternalSubmission')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasReference')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasQuotedHours'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN #MetadataRowsToApply AS applyRows
        ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SJob'
      AND tr.TableName = N'MilestoneTypes'
    ORDER BY sr.SourceRowId;

OPEN MilestoneTypes_Cursor;

FETCH NEXT FROM MilestoneTypes_Cursor
INTO
    @Guid,
    @MT_RowStatus,
    @MT_Name,
    @MT_Code,
    @MT_IsActive,
    @MT_IsInvoiceTrigger,
    @MT_IsReviewRequired,
    @MT_HelpText,
    @MT_HasDescription,
    @MT_IsCompulsory,
    @MT_IncludeStart,
    @MT_IncludeSchedule,
    @MT_IncludeDueDate,
    @MT_HasExternalSubmission,
    @MT_HasReference,
    @MT_HasQuotedHours;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @MilestoneTypeGuid = @Guid;

    EXEC SJob.MilestoneTypesUpsert
        @Name = @MT_Name,
        @Code = @MT_Code,
        @IsActive = @MT_IsActive,
        @IsInvoiceTrigger = @MT_IsInvoiceTrigger,
        @IsReviewRequired = @MT_IsReviewRequired,
        @HelpText = @MT_HelpText,
        @Hasdescription = @MT_HasDescription,
        @IsCompulsory = @MT_IsCompulsory,
        @IncludeStart = @MT_IncludeStart,
        @IncludeSchedule = @MT_IncludeSchedule,
        @IncludeDueDate = @MT_IncludeDueDate,
        @HasExternalSubmission = @MT_HasExternalSubmission,
        @Guid = @MilestoneTypeGuid OUTPUT,
        @HasReference = @MT_HasReference,
        @HasQuotedHours = @MT_HasQuotedHours;

    UPDATE SJob.MilestoneTypes
    SET RowStatus = ISNULL(NULLIF(@MT_RowStatus, 0), RowStatus)
    WHERE Guid = @MilestoneTypeGuid;

    FETCH NEXT FROM MilestoneTypes_Cursor
    INTO
        @Guid,
        @MT_RowStatus,
        @MT_Name,
        @MT_Code,
        @MT_IsActive,
        @MT_IsInvoiceTrigger,
        @MT_IsReviewRequired,
        @MT_HelpText,
        @MT_HasDescription,
        @MT_IsCompulsory,
        @MT_IncludeStart,
        @MT_IncludeSchedule,
        @MT_IncludeDueDate,
        @MT_HasExternalSubmission,
        @MT_HasReference,
        @MT_HasQuotedHours;
END;

CLOSE MilestoneTypes_Cursor;
DEALLOCATE MilestoneTypes_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMilestoneTypes',
    @StepStatus = N'Succeeded',
    @Message = N'Job milestone types applied.',
    @DetailsJson = N'{}';

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
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityDataTypes","SUserInterface.Icons","SCore.EntityTypes","SCore.EntityHobts","SUserInterface.DropDownListDefinitions","SCore.EntityPropertyGroups","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions","SJob.MilestoneTypes"]}';

COMMIT TRANSACTION;
END;

GO

GO

/* Deploy StoredProcedure SMigration.MetadataApplyPreview_Accept using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataApplyPreview_Accept.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreview_Accept]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyPreview_Accept]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 1,
    @ExpectedPreviewFingerprint VARCHAR(64),
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
        @TargetDatabaseName SYSNAME,
        @FailCount INT = 0,
        @PreviewFingerprint VARBINARY(32),
        @ScopeFingerprint VARBINARY(32),
        @ExpectedPreviewFingerprintBinary VARBINARY(32),
        @PreviewFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
        @ApplyCount INT = 0,
        @AcceptedByUserId INT = ISNULL(SCore.GetCurrentUserId(), -1),
        @AcceptedOnUtc DATETIME2,
        @ExistingAcceptanceId BIGINT,
        @DetailsJson NVARCHAR(MAX),
        @Message NVARCHAR(2000);

    IF ISNULL(@ApplySelectedOnly, 0) <> 1
        THROW 52920, 'Metadata apply preview acceptance requires an explicit selected-row scope.', 1;

    IF LEN(ISNULL(@ExpectedPreviewFingerprint, '')) <> 64
        THROW 52911, 'A valid 64-character apply preview fingerprint is required for acceptance.', 1;

    SET @ExpectedPreviewFingerprintBinary = TRY_CONVERT(VARBINARY(32), @ExpectedPreviewFingerprint, 2);

    IF @ExpectedPreviewFingerprintBinary IS NULL
        THROW 52911, 'A valid hexadecimal apply preview fingerprint is required for acceptance.', 1;

    BEGIN TRANSACTION;

    SELECT
        @RunStatus = r.RunStatus,
        @IsValidateOnly = r.IsValidateOnly,
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r WITH (UPDLOCK, HOLDLOCK)
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52912, 'Metadata apply preview acceptance could not find the selected run.', 1;

    IF ISNULL(@IsValidateOnly, 1) = 1
        THROW 52913, 'Validate-only metadata runs cannot be accepted for deployment.', 1;

    IF @RunStatus NOT IN
    (
        N'Validated',
        N'PartiallyApplied',
        N'AppliedCoreMetadata',
        N'AppliedUiMetadata'
    )
        THROW 52914, 'Metadata apply preview acceptance requires a validated or retryable metadata run.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi WITH (HOLDLOCK)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue WITH (HOLDLOCK)
          WHERE ignoredIssue.DatabaseName = @TargetDatabaseName
            AND ignoredIssue.RegistryGuid = vi.RegistryGuid
            AND ignoredIssue.SourceRowGuid = vi.SourceRowGuid
            AND ignoredIssue.IssueCode = vi.IssueCode
            AND ignoredIssue.RowStatus NOT IN (0,254)
      )
      AND
      (
          vi.IssueCode IN (N'RunNotFound', N'NoSelectedRows', N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS selected
              INNER JOIN SMigration.Metadata_StagedRows AS selectedRow
                  ON selectedRow.RunGuid = selected.RunGuid
                 AND selectedRow.RegistryGuid = selected.RegistryGuid
                 AND selectedRow.SourceRowGuid = selected.SourceRowGuid
                 AND selectedRow.RowStatus NOT IN (0,254)
              WHERE selected.RunGuid = vi.RunGuid
                AND selected.RowStatus NOT IN (0,254)
                AND selectedRow.DifferenceType IN (N'Insert', N'Update')
                AND selectedRow.RegistryGuid = vi.RegistryGuid
                AND (vi.SourceRowGuid IS NULL OR selectedRow.SourceRowGuid = vi.SourceRowGuid)
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IgnoredRecords AS selectedIgnored
                    WHERE selectedIgnored.DatabaseName = @TargetDatabaseName
                      AND selectedIgnored.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedIgnored.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedIgnored.RowStatus NOT IN (0,254)
                )
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IdentityMapOverrides AS selectedOverride
                    WHERE selectedOverride.DatabaseName = @TargetDatabaseName
                      AND selectedOverride.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedOverride.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedOverride.RowStatus NOT IN (0,254)
                )
          )
      );

    IF ISNULL(@FailCount, 0) > 0
        THROW 52915, 'Metadata apply preview cannot be accepted while validation failures exist.', 1;

    EXEC SMigration.MetadataApplyPreviewFingerprint_Get
        @RunGuid = @RunGuid,
        @ApplySelectedOnly = @ApplySelectedOnly,
        @SourceSnapshotFingerprint = @SourceSnapshotFingerprint,
        @TargetSnapshotFingerprint = @TargetSnapshotFingerprint,
        @PreviewFingerprint = @PreviewFingerprint OUTPUT,
        @ScopeFingerprint = @ScopeFingerprint OUTPUT,
        @ApplyCount = @ApplyCount OUTPUT;

    IF ISNULL(@ApplyCount, 0) = 0
        THROW 52916, 'Metadata apply preview acceptance requires at least one actionable metadata row.', 1;

    IF @PreviewFingerprint <> @ExpectedPreviewFingerprintBinary
        THROW 52917, 'The metadata apply preview changed before acceptance. Reload and review the current preview before accepting it for deployment.', 1;

    SET @PreviewFingerprintHex = CONVERT(VARCHAR(64), @PreviewFingerprint, 2);
    SET @ScopeFingerprintHex = CONVERT(VARCHAR(64), @ScopeFingerprint, 2);

    SELECT TOP (1)
        @ExistingAcceptanceId = el.ID,
        @AcceptedOnUtc = el.CreatedOnUtc,
        @AcceptedByUserId = ISNULL(TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.acceptedByUserId')), -1)
    FROM SMigration.Metadata_ExecutionLog AS el WITH (HOLDLOCK)
    WHERE el.RunGuid = @RunGuid
      AND el.RowStatus NOT IN (0,254)
      AND el.StepName = N'ApplyPreviewAcceptance'
      AND el.StepStatus = N'Accepted'
      AND JSON_VALUE(el.DetailsJson, '$.previewFingerprint') = @PreviewFingerprintHex
      AND JSON_VALUE(el.DetailsJson, '$.scopeFingerprint') = @ScopeFingerprintHex
      AND JSON_VALUE(el.DetailsJson, '$.sourceSnapshotFingerprint') = UPPER(@SourceSnapshotFingerprint)
      AND JSON_VALUE(el.DetailsJson, '$.targetSnapshotFingerprint') = UPPER(@TargetSnapshotFingerprint)
      AND TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.applySelectedOnly')) = CONVERT(INT, ISNULL(@ApplySelectedOnly, 0))
    ORDER BY el.ID DESC;

    IF @ExistingAcceptanceId IS NULL
    BEGIN
        SET @AcceptedOnUtc = SYSUTCDATETIME();

        SELECT
            @DetailsJson =
            (
                SELECT
                    @PreviewFingerprintHex AS previewFingerprint,
                    @ScopeFingerprintHex AS scopeFingerprint,
                    UPPER(@SourceSnapshotFingerprint) AS sourceSnapshotFingerprint,
                    UPPER(@TargetSnapshotFingerprint) AS targetSnapshotFingerprint,
                    CONVERT(INT, ISNULL(@ApplySelectedOnly, 0)) AS applySelectedOnly,
                    @ApplyCount AS applyCount,
                    @AcceptedByUserId AS acceptedByUserId,
                    @AcceptedOnUtc AS acceptedOnUtc
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            );

        EXEC SMigration.MetadataExecutionLog_Add
            @RunGuid = @RunGuid,
            @StepName = N'ApplyPreviewAcceptance',
            @StepStatus = N'Accepted',
            @Message = N'Metadata apply preview reviewed and accepted for deployment.',
            @DetailsJson = @DetailsJson;

        SET @Message = N'Metadata apply preview accepted for deployment.';
    END
    ELSE
    BEGIN
        SET @Message = N'This unchanged metadata apply preview is already accepted for deployment.';
    END;

    COMMIT TRANSACTION;

    SELECT
        CONVERT(BIT, 1) AS IsAccepted,
        CONVERT(BIT, ISNULL(@ApplySelectedOnly, 0)) AS ApplySelectedOnly,
        @PreviewFingerprintHex AS PreviewFingerprint,
        @ApplyCount AS ApplyCount,
        @AcceptedOnUtc AS AcceptedOnUtc,
        @AcceptedByUserId AS AcceptedByUserId,
        @Message AS Message;
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataApplyPreview_Get using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataApplyPreview_Get.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreview_Get]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyPreview_Get]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 1,
    @IncludeIgnored BIT = 1,
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISNULL(@ApplySelectedOnly, 0) <> 1
        THROW 52301, 'Metadata apply preview requires an explicit selected-row scope.', 1;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @RunFailureCount INT = 0,
        @PreviewFingerprint VARBINARY(32),
        @ScopeFingerprint VARBINARY(32),
        @PreviewFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
        @PreviewApplyCount INT = 0,
        @AcceptedOnUtc DATETIME2,
        @AcceptedByUserId INT = -1,
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    BEGIN TRANSACTION;

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52300, 'Metadata apply preview could not find the selected run.', 1;

    SELECT
        @RunFailureCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue
          WHERE ignoredIssue.DatabaseName = @TargetDatabaseName
            AND ignoredIssue.RegistryGuid = vi.RegistryGuid
            AND ignoredIssue.SourceRowGuid = vi.SourceRowGuid
            AND ignoredIssue.IssueCode = vi.IssueCode
            AND ignoredIssue.RowStatus NOT IN (0,254)
      )
      AND
      (
          vi.IssueCode IN (N'RunNotFound', N'NoSelectedRows', N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS selected
              INNER JOIN SMigration.Metadata_StagedRows AS selectedRow
                  ON selectedRow.RunGuid = selected.RunGuid
                 AND selectedRow.RegistryGuid = selected.RegistryGuid
                 AND selectedRow.SourceRowGuid = selected.SourceRowGuid
                 AND selectedRow.RowStatus NOT IN (0,254)
              WHERE selected.RunGuid = vi.RunGuid
                AND selected.RowStatus NOT IN (0,254)
                AND selectedRow.DifferenceType IN (N'Insert', N'Update')
                AND selectedRow.RegistryGuid = vi.RegistryGuid
                AND (vi.SourceRowGuid IS NULL OR selectedRow.SourceRowGuid = vi.SourceRowGuid)
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IgnoredRecords AS selectedIgnored
                    WHERE selectedIgnored.DatabaseName = @TargetDatabaseName
                      AND selectedIgnored.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedIgnored.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedIgnored.RowStatus NOT IN (0,254)
                )
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IdentityMapOverrides AS selectedOverride
                    WHERE selectedOverride.DatabaseName = @TargetDatabaseName
                      AND selectedOverride.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedOverride.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedOverride.RowStatus NOT IN (0,254)
                )
          )
      );

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

    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        ISNULL(sr.SourceRowId, -1) AS SourceRowId,
        sr.DifferenceType,
        CONVERT(BIT, CASE WHEN sel.Guid IS NULL THEN 0 ELSE 1 END) AS IsSelected,
        CONVERT(BIT, CASE WHEN ign.Guid IS NULL THEN 0 ELSE 1 END) AS IsIgnored,
        CONVERT(BIT, CASE WHEN @RunFailureCount > 0 THEN 1 ELSE 0 END) AS HasValidationFailure,
        CASE
            WHEN @RunFailureCount > 0 THEN N'Blocked'
            WHEN ign.Guid IS NOT NULL THEN N'Skip'
            WHEN ov.Guid IS NOT NULL THEN N'Skip'
            ELSE N'Apply'
        END AS ApplyAction,
        CASE
            WHEN @RunFailureCount > 0 THEN N'Run has validation failure(s).'
            WHEN ign.Guid IS NOT NULL THEN N'Record is ignored for this target database.'
            WHEN ov.Guid IS NOT NULL THEN N'Record has a manual identity-map target match and will not be blindly inserted by automated apply.'
            ELSE N''
        END AS SkipReason,
        ISNULL(changed.ChangedColumns, N'') AS ChangedColumns,
        @RunFailureCount AS RunValidationFailureCount
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_RunSelections AS sel
        ON sel.RunGuid = sr.RunGuid
       AND sel.RegistryGuid = sr.RegistryGuid
       AND sel.SourceRowGuid = sr.SourceRowGuid
       AND sel.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
        ON ign.DatabaseName = @TargetDatabaseName
       AND ign.RegistryGuid = sr.RegistryGuid
       AND ign.SourceRowGuid = sr.SourceRowGuid
       AND ign.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            STRING_AGG(CONVERT(NVARCHAR(MAX), diff.ColumnName), N', ') AS ChangedColumns
        FROM
        (
            SELECT
                COALESCE(src.[key], tgt.[key]) AS ColumnName
            FROM OPENJSON(ISNULL(sr.SourcePayloadJson, N'{}')) AS src
            FULL OUTER JOIN OPENJSON(ISNULL(sr.TargetPayloadJson, N'{}')) AS tgt
                ON tgt.[key] = src.[key]
            WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'')
        ) AS diff
    ) AS changed
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND sel.Guid IS NOT NULL
      AND (ISNULL(@IncludeIgnored, 0) = 1 OR ign.Guid IS NULL)
    ORDER BY
        CASE
            WHEN @RunFailureCount > 0 THEN 0
            WHEN ign.Guid IS NOT NULL THEN 3
            WHEN ov.Guid IS NOT NULL THEN 2
            ELSE 1
        END,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId;

    SELECT TOP (1)
        @AcceptedOnUtc = el.CreatedOnUtc,
        @AcceptedByUserId = ISNULL(TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.acceptedByUserId')), -1)
    FROM SMigration.Metadata_ExecutionLog AS el
    WHERE el.RunGuid = @RunGuid
      AND el.RowStatus NOT IN (0,254)
      AND el.StepName = N'ApplyPreviewAcceptance'
      AND el.StepStatus = N'Accepted'
      AND JSON_VALUE(el.DetailsJson, '$.previewFingerprint') = @PreviewFingerprintHex
      AND JSON_VALUE(el.DetailsJson, '$.scopeFingerprint') = @ScopeFingerprintHex
      AND JSON_VALUE(el.DetailsJson, '$.sourceSnapshotFingerprint') = UPPER(@SourceSnapshotFingerprint)
      AND JSON_VALUE(el.DetailsJson, '$.targetSnapshotFingerprint') = UPPER(@TargetSnapshotFingerprint)
      AND TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.applySelectedOnly')) = CONVERT(INT, ISNULL(@ApplySelectedOnly, 0))
    ORDER BY el.ID DESC;

    COMMIT TRANSACTION;

    SELECT
        @PreviewFingerprintHex AS PreviewFingerprint,
        @PreviewApplyCount AS PreviewApplyCount,
        CONVERT(BIT, CASE WHEN @AcceptedOnUtc IS NULL THEN 0 ELSE 1 END) AS IsAccepted,
        @AcceptedOnUtc AS AcceptedOnUtc,
        @AcceptedByUserId AS AcceptedByUserId;
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataApplyPreviewFingerprint_Get using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataApplyPreviewFingerprint_Get.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreviewFingerprint_Get]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyPreviewFingerprint_Get]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 1,
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64),
    @PreviewFingerprint VARBINARY(32) OUTPUT,
    @ScopeFingerprint VARBINARY(32) OUTPUT,
    @ApplyCount INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISNULL(@ApplySelectedOnly, 0) <> 1
        THROW 52920, 'Metadata apply preview fingerprint requires an explicit selected-row scope.', 1;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @ValidatedOnUtc DATETIME2,
        @SourceSnapshotFingerprintBinary VARBINARY(32),
        @TargetSnapshotFingerprintBinary VARBINARY(32),
        @SourceSnapshotFingerprintHex VARCHAR(64),
        @TargetSnapshotFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
        @FingerprintRows NVARCHAR(MAX),
        @ScopeFingerprintEnvelope NVARCHAR(MAX),
        @DeploymentFingerprintEnvelope NVARCHAR(MAX);

    IF LEN(ISNULL(@SourceSnapshotFingerprint, '')) <> 64
        THROW 52918, 'A valid 64-character source snapshot fingerprint is required.', 1;

    SET @SourceSnapshotFingerprintBinary = TRY_CONVERT(VARBINARY(32), @SourceSnapshotFingerprint, 2);

    IF @SourceSnapshotFingerprintBinary IS NULL
        THROW 52918, 'A valid hexadecimal source snapshot fingerprint is required.', 1;

    IF LEN(ISNULL(@TargetSnapshotFingerprint, '')) <> 64
        THROW 52919, 'A valid 64-character target snapshot fingerprint is required.', 1;

    SET @TargetSnapshotFingerprintBinary = TRY_CONVERT(VARBINARY(32), @TargetSnapshotFingerprint, 2);

    IF @TargetSnapshotFingerprintBinary IS NULL
        THROW 52919, 'A valid hexadecimal target snapshot fingerprint is required.', 1;

    SET @SourceSnapshotFingerprintHex = CONVERT(VARCHAR(64), @SourceSnapshotFingerprintBinary, 2);
    SET @TargetSnapshotFingerprintHex = CONVERT(VARCHAR(64), @TargetSnapshotFingerprintBinary, 2);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName,
        @ValidatedOnUtc = r.ValidatedOnUtc
    FROM SMigration.Metadata_Run AS r WITH (HOLDLOCK)
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52910, 'Metadata apply preview fingerprint could not find the selected run.', 1;

    IF OBJECT_ID(N'tempdb..#MetadataApplyPreviewFingerprintRows') IS NOT NULL
        DROP TABLE #MetadataApplyPreviewFingerprintRows;

    CREATE TABLE #MetadataApplyPreviewFingerprintRows
    (
        ApplyOrder INT NOT NULL,
        RegistryGuid UNIQUEIDENTIFIER NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        RowFingerprint VARCHAR(64) NOT NULL,
        CONSTRAINT PK_MetadataApplyPreviewFingerprintRows PRIMARY KEY CLUSTERED
        (
            ApplyOrder,
            RegistryGuid,
            SourceRowGuid
        )
    );

    INSERT INTO #MetadataApplyPreviewFingerprintRows
    (
        ApplyOrder,
        RegistryGuid,
        SourceRowGuid,
        RowFingerprint
    )
    SELECT
        tr.ApplyOrder,
        sr.RegistryGuid,
        sr.SourceRowGuid,
        CONVERT
        (
            VARCHAR(64),
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    NVARCHAR(MAX),
                    CONCAT
                    (
                        N'schema=', tr.SchemaName,
                        N'|table=', tr.TableName,
                        N'|applyOrder=', CONVERT(NVARCHAR(20), tr.ApplyOrder),
                        N'|registryGuid=', CONVERT(NVARCHAR(36), sr.RegistryGuid),
                        N'|sourceRowGuid=', CONVERT(NVARCHAR(36), sr.SourceRowGuid),
                        N'|sourceRowId=', ISNULL(CONVERT(NVARCHAR(30), sr.SourceRowId), N'<null>'),
                        N'|sourceRowStatus=', ISNULL(CONVERT(NVARCHAR(10), sr.SourceRowStatus), N'<null>'),
                        N'|differenceType=', sr.DifferenceType,
                        N'|sourcePayloadHash=', CONVERT(VARCHAR(64), sr.SourcePayloadHash, 2),
                        N'|targetPayloadHash=', ISNULL(CONVERT(VARCHAR(64), sr.TargetPayloadHash, 2), N'<null>')
                    )
                )
            ),
            2
        )
    FROM SMigration.Metadata_StagedRows AS sr WITH (HOLDLOCK)
    INNER JOIN SMigration.Metadata_TableRegistry AS tr WITH (HOLDLOCK)
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_RunSelections AS selection WITH (HOLDLOCK)
          WHERE selection.RunGuid = sr.RunGuid
            AND selection.RegistryGuid = sr.RegistryGuid
            AND selection.SourceRowGuid = sr.SourceRowGuid
            AND selection.RowStatus NOT IN (0,254)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored WITH (HOLDLOCK)
          WHERE ignored.DatabaseName = @TargetDatabaseName
            AND ignored.RegistryGuid = sr.RegistryGuid
            AND ignored.SourceRowGuid = sr.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IdentityMapOverrides AS identityOverride WITH (HOLDLOCK)
          WHERE identityOverride.DatabaseName = @TargetDatabaseName
            AND identityOverride.RegistryGuid = sr.RegistryGuid
            AND identityOverride.SourceRowGuid = sr.SourceRowGuid
            AND identityOverride.RowStatus NOT IN (0,254)
      );

    SET @ApplyCount = @@ROWCOUNT;

    SELECT
        @FingerprintRows = STRING_AGG(CONVERT(NVARCHAR(MAX), rowsToHash.RowFingerprint), N'|')
            WITHIN GROUP
            (
                ORDER BY
                    rowsToHash.ApplyOrder,
                    rowsToHash.RegistryGuid,
                    rowsToHash.SourceRowGuid
            )
    FROM #MetadataApplyPreviewFingerprintRows AS rowsToHash;

    SELECT
        @ScopeFingerprintEnvelope =
        (
            SELECT
                CONVERT(NVARCHAR(36), @RunGuid) AS runGuid,
                @TargetDatabaseName AS targetDatabaseName,
                CONVERT(INT, ISNULL(@ApplySelectedOnly, 0)) AS applySelectedOnly,
                CONVERT(NVARCHAR(33), @ValidatedOnUtc, 126) AS validatedOnUtc,
                @ApplyCount AS applyCount,
                ISNULL(@FingerprintRows, N'') AS rowFingerprints
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

    SET @ScopeFingerprint = HASHBYTES('SHA2_256', @ScopeFingerprintEnvelope);
    SET @ScopeFingerprintHex = CONVERT(VARCHAR(64), @ScopeFingerprint, 2);

    SET @DeploymentFingerprintEnvelope = CONVERT
    (
        NVARCHAR(MAX),
        CONCAT
        (
            N'scope=', @ScopeFingerprintHex,
            N'|source=', @SourceSnapshotFingerprintHex,
            N'|target=', @TargetSnapshotFingerprintHex
        )
    );

    SET @PreviewFingerprint = HASHBYTES('SHA2_256', @DeploymentFingerprintEnvelope);
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataIgnoredRecord_Upsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataIgnoredRecord_Upsert.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecord_Upsert]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecord_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIgnoredRecord_Upsert]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128),
    @SourceRowGuid UNIQUEIDENTIFIER,
    @Reason NVARCHAR(500) = N'',
    @IsIgnored BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @IgnoreGuid UNIQUEIDENTIFIER,
        @RegistryGuid UNIQUEIDENTIFIER,
        @DifferenceType NVARCHAR(30),
        @TargetDatabaseName SYSNAME,
        @TargetServerName NVARCHAR(255),
        @TargetEnvironment NVARCHAR(20),
        @StableRecordKey NVARCHAR(600),
        @CurrentUserId INT = ISNULL(SCore.GetCurrentUserId(), -1);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName,
        @TargetServerName = r.TargetServerName,
        @TargetEnvironment = r.TargetEnvironment
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52200, 'Metadata ignore could not find the selected run.', 1;

    SELECT TOP (1)
        @RegistryGuid = tr.Guid,
        @DifferenceType = sr.DifferenceType
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND tr.SchemaName = @SchemaName
      AND tr.TableName = @TableName
      AND sr.SourceRowGuid = @SourceRowGuid;

    IF @RegistryGuid IS NULL
        THROW 52201, 'Metadata ignore could not find the staged record for the selected run.', 1;

    SET @StableRecordKey = CONCAT(@TargetDatabaseName, N':', @SchemaName, N'.', @TableName, N':', CONVERT(NVARCHAR(36), @SourceRowGuid));

    IF ISNULL(@IsIgnored, 0) = 1
    BEGIN
        SELECT TOP (1)
            @IgnoreGuid = ign.Guid
        FROM SMigration.Metadata_IgnoredRecords AS ign
        WHERE ign.DatabaseName = @TargetDatabaseName
          AND ign.RegistryGuid = @RegistryGuid
          AND ign.SourceRowGuid = @SourceRowGuid
        ORDER BY CASE WHEN ign.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END, ign.ID DESC;

        SET @IgnoreGuid = ISNULL(@IgnoreGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @IgnoreGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_IgnoredRecords';

        IF EXISTS (SELECT 1 FROM SMigration.Metadata_IgnoredRecords AS ign WHERE ign.Guid = @IgnoreGuid)
        BEGIN
            UPDATE SMigration.Metadata_IgnoredRecords
            SET
                RowStatus = 1,
                DatabaseName = @TargetDatabaseName,
                ServerName = ISNULL(@TargetServerName, N''),
                EnvironmentName = ISNULL(@TargetEnvironment, N''),
                RegistryGuid = @RegistryGuid,
                SchemaName = @SchemaName,
                TableName = @TableName,
                SourceRowGuid = @SourceRowGuid,
                StableRecordKey = @StableRecordKey,
                DifferenceType = ISNULL(@DifferenceType, N''),
                IgnoreScope = N'TargetDatabase',
                Reason = ISNULL(@Reason, N''),
                IgnoredByUserId = @CurrentUserId,
                IgnoredOnUtc = SYSUTCDATETIME(),
                UnignoredByUserId = NULL,
                UnignoredOnUtc = NULL,
                LastSeenRunGuid = @RunGuid,
                LastSeenOnUtc = SYSUTCDATETIME()
            WHERE Guid = @IgnoreGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Metadata_IgnoredRecords
            (
                Guid,
                RowStatus,
                DatabaseName,
                ServerName,
                EnvironmentName,
                RegistryGuid,
                SchemaName,
                TableName,
                SourceRowGuid,
                StableRecordKey,
                DifferenceType,
                IgnoreScope,
                Reason,
                IgnoredByUserId,
                IgnoredOnUtc,
                UnignoredByUserId,
                UnignoredOnUtc,
                LastSeenRunGuid,
                LastSeenOnUtc
            )
            SELECT
                @IgnoreGuid,
                1,
                @TargetDatabaseName,
                ISNULL(@TargetServerName, N''),
                ISNULL(@TargetEnvironment, N''),
                @RegistryGuid,
                @SchemaName,
                @TableName,
                @SourceRowGuid,
                @StableRecordKey,
                ISNULL(@DifferenceType, N''),
                N'TargetDatabase',
                ISNULL(@Reason, N''),
                @CurrentUserId,
                SYSUTCDATETIME(),
                NULL,
                NULL,
                @RunGuid,
                SYSUTCDATETIME();
        END;

        -- Ignored records are outside the selected-only validation and apply scope.
        -- Clear any persisted selection immediately so the UI and pipeline see the
        -- same durable contract.
        EXEC SMigration.MetadataRunSelection_Upsert
            @RunGuid = @RunGuid,
            @SchemaName = @SchemaName,
            @TableName = @TableName,
            @SourceRowGuid = @SourceRowGuid,
            @DifferenceType = @DifferenceType,
            @IsSelected = 0;
    END
    ELSE
    BEGIN
        DECLARE @RecordsToClear TABLE
        (
            IgnoreGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
        );

        INSERT INTO @RecordsToClear
        (
            IgnoreGuid
        )
        SELECT
            ign.Guid
        FROM SMigration.Metadata_IgnoredRecords AS ign
        WHERE ign.DatabaseName = @TargetDatabaseName
          AND ign.RegistryGuid = @RegistryGuid
          AND ign.SourceRowGuid = @SourceRowGuid
          AND ign.RowStatus NOT IN (0,254);

        DECLARE @GuidToClear UNIQUEIDENTIFIER;
        DECLARE IgnoreCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT clearRows.IgnoreGuid
            FROM @RecordsToClear AS clearRows
            ORDER BY clearRows.IgnoreGuid;

        OPEN IgnoreCursor;
        FETCH NEXT FROM IgnoreCursor INTO @GuidToClear;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.DeleteDataObject
                @Guid = @GuidToClear;
            FETCH NEXT FROM IgnoreCursor INTO @GuidToClear;
        END;
        CLOSE IgnoreCursor;
        DEALLOCATE IgnoreCursor;

        UPDATE ign
        SET
            ign.RowStatus = 254,
            ign.UnignoredByUserId = @CurrentUserId,
            ign.UnignoredOnUtc = SYSUTCDATETIME(),
            ign.LastSeenRunGuid = @RunGuid,
            ign.LastSeenOnUtc = SYSUTCDATETIME()
        FROM SMigration.Metadata_IgnoredRecords AS ign
        INNER JOIN @RecordsToClear AS clearRows
            ON clearRows.IgnoreGuid = ign.Guid
        WHERE ign.RowStatus NOT IN (0,254);
    END;
END
GO

GO

/* Deploy StoredProcedure SMigration.MetadataRunSelection_Clear using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataRunSelection_Clear.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Clear]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_Clear]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128) = N'',
    @TableName NVARCHAR(128) = N'',
    @DifferenceType NVARCHAR(30) = N''
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SelectionsToClear TABLE
    (
        SelectionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );

    INSERT INTO @SelectionsToClear
    (
        SelectionGuid
    )
    SELECT
        sel.Guid
    FROM SMigration.Metadata_RunSelections AS sel
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sel.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sel.RunGuid = @RunGuid
      AND sel.RowStatus NOT IN (0,254)
      AND (@SchemaName = N'' OR tr.SchemaName = @SchemaName)
      AND (@TableName = N'' OR tr.TableName = @TableName)
      AND (@DifferenceType = N'' OR sel.DifferenceType = @DifferenceType);

    DECLARE @SelectionGuid UNIQUEIDENTIFIER;

    DECLARE SelectionCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            clearRows.SelectionGuid
        FROM @SelectionsToClear AS clearRows
        ORDER BY clearRows.SelectionGuid;

    OPEN SelectionCursor;
    FETCH NEXT FROM SelectionCursor INTO @SelectionGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.DeleteDataObject
            @Guid = @SelectionGuid;

        FETCH NEXT FROM SelectionCursor INTO @SelectionGuid;
    END;

    CLOSE SelectionCursor;
    DEALLOCATE SelectionCursor;

    UPDATE sel
    SET
        sel.RowStatus = 254,
        sel.SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
        sel.SelectedOnUtc = SYSUTCDATETIME()
    FROM SMigration.Metadata_RunSelections AS sel
    INNER JOIN @SelectionsToClear AS clearRows
        ON clearRows.SelectionGuid = sel.Guid
    WHERE sel.RowStatus NOT IN (0,254);

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = N'Staged',
        ValidatedOnUtc = NULL
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'SelectionClear',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata migration run selection cleared.',
        @DetailsJson = N'{}';
END
GO

GO

/* Deploy StoredProcedure SMigration.MetadataRunSelection_Upsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataRunSelection_Upsert.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_Upsert]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128),
    @SourceRowGuid UNIQUEIDENTIFIER,
    @DifferenceType NVARCHAR(30) = N'',
    @IsSelected BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RegistryGuid UNIQUEIDENTIFIER,
        @StagedDifferenceType NVARCHAR(30),
        @TargetDatabaseName SYSNAME,
        @SelectionGuid UNIQUEIDENTIFIER;

    SELECT
        @TargetDatabaseName = run.TargetDatabaseName
    FROM SMigration.Metadata_Run AS run
    WHERE run.Guid = @RunGuid
      AND run.RowStatus NOT IN (0,254);

    SELECT TOP (1)
        @RegistryGuid = tr.Guid,
        @StagedDifferenceType = sr.DifferenceType
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND tr.SchemaName = @SchemaName
      AND tr.TableName = @TableName
      AND sr.SourceRowGuid = @SourceRowGuid
      AND (@DifferenceType = N'' OR sr.DifferenceType = @DifferenceType);

    IF @RegistryGuid IS NULL
        THROW 52100, 'The selected metadata staged row was not found.', 1;

    IF @StagedDifferenceType NOT IN (N'Insert', N'Update') AND ISNULL(@IsSelected, 0) = 1
        THROW 52101, 'Only Insert and Update metadata rows can be selected for apply.', 1;

    IF ISNULL(@IsSelected, 0) = 1
       AND EXISTS
       (
           SELECT 1
           FROM SMigration.Metadata_IgnoredRecords AS ignored
           WHERE ignored.DatabaseName = @TargetDatabaseName
             AND ignored.RegistryGuid = @RegistryGuid
             AND ignored.SourceRowGuid = @SourceRowGuid
             AND ignored.RowStatus NOT IN (0,254)
       )
        THROW 52102, 'Ignored metadata records cannot be selected. Unignore the record before selecting it.', 1;

    SELECT TOP (1)
        @SelectionGuid = sel.Guid
    FROM SMigration.Metadata_RunSelections AS sel
    WHERE sel.RunGuid = @RunGuid
      AND sel.RegistryGuid = @RegistryGuid
      AND sel.SourceRowGuid = @SourceRowGuid;

    IF ISNULL(@IsSelected, 0) = 1
    BEGIN
        SET @SelectionGuid = ISNULL(@SelectionGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @SelectionGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_RunSelections';

        IF EXISTS
        (
            SELECT 1
            FROM SMigration.Metadata_RunSelections AS sel
            WHERE sel.Guid = @SelectionGuid
        )
        BEGIN
            UPDATE SMigration.Metadata_RunSelections
            SET
                RowStatus = 1,
                DifferenceType = @StagedDifferenceType,
                SelectionSource = N'Manual',
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE Guid = @SelectionGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Metadata_RunSelections
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                DifferenceType,
                SelectionSource,
                SelectedByUserId,
                SelectedOnUtc
            )
            SELECT
                @SelectionGuid,
                1,
                @RunGuid,
                @RegistryGuid,
                @SourceRowGuid,
                @StagedDifferenceType,
                N'Manual',
                ISNULL(SCore.GetCurrentUserId(), -1),
                SYSUTCDATETIME();
        END;
    END
    ELSE
    BEGIN
        IF @SelectionGuid IS NOT NULL
        BEGIN
            EXEC SCore.DeleteDataObject
                @Guid = @SelectionGuid;

            UPDATE SMigration.Metadata_RunSelections
            SET
                RowStatus = 254,
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE Guid = @SelectionGuid
              AND RowStatus NOT IN (0,254);
        END;
    END;

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = N'Staged',
        ValidatedOnUtc = NULL
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
END
GO

GO

/* Deploy StoredProcedure SMigration.MetadataStage_Run using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataStage_Run.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.MetadataStage_Run
    Source schema hash : 3B34F6E9A8445FF8BCFCE0F8D6817FD49F676D0E218C082CCE6DC3A57991361A
    Definition SHA-256 : A2542686CAE64A4D0747B3F1A02DC539676984BAF013431DD71EE6D4DD54CB23

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SMigration].[MetadataStage_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceDatabaseName SYSNAME,
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @ColumnList NVARCHAR(MAX),
        @HasRowStatus BIT,
        @SourceWhereClause NVARCHAR(MAX),
        @SourceAndClause NVARCHAR(MAX),
        @DuplicateWhereClause NVARCHAR(MAX),
        @TargetWhereClause NVARCHAR(MAX),
        @TargetDuplicateWhereClause NVARCHAR(MAX),
        @BothActiveWhereClause NVARCHAR(MAX),
        @SourceRowStatusExpression NVARCHAR(MAX),
        @OtherUniqueIndexId INT,
        @OtherUniqueIndexName SYSNAME,
        @OtherIndexColumnList NVARCHAR(MAX),
        @OtherIndexJoinPredicate NVARCHAR(MAX),
        @CascadeFkColumnName SYSNAME,
        @CascadeRefSchemaName SYSNAME,
        @CascadeRefTableName SYSNAME,
        @CascadeRefColumnName SYSNAME,
        @CascadeRefRegistryGuid UNIQUEIDENTIFIER,
        @CascadeRefGuidColumnName SYSNAME,
        @Sql NVARCHAR(MAX);

    SELECT
        @SourceDatabaseName = r.SourceDatabaseName,
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @SourceDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    EXEC SMigration.MetadataRegistry_SyncFromEntityTypes
        @SourceDatabaseName = @SourceDatabaseName,
        @TargetDatabaseName = @TargetDatabaseName;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
    )
    BEGIN
        ;THROW 51001, 'No enabled metadata registry rows exist. Run SMigration.MetadataRegistry_Seed first.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_StagedRows
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'DuplicateSourceGuid',
          N'DuplicateTargetGuid',
          N'DuplicateTargetKey',
          N'UnresolvedReference',
          N'RegisteredGuidColumnMissing',
          N'RegisteredTableMissing',
          N'RegisteredSourceTableMissing'
      );

    DECLARE registry_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            tr.Guid,
            tr.SchemaName,
            tr.TableName,
            tr.GuidColumnName,
            tr.PrimaryKeyColumnName
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
        ORDER BY
            tr.ApplyOrder,
            tr.SchemaName,
            tr.TableName;

    OPEN registry_cursor;

    FETCH NEXT FROM registry_cursor
    INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ColumnList = NULL;
        SET @HasRowStatus = 0;
        SET @Sql = NULL;

        IF OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredTableMissing',
                CONCAT(N'Registered metadata table does not exist in target: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF OBJECT_ID(QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredSourceTableMissing',
                CONCAT(N'Registered metadata table does not exist in source: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.schemas AS s
            INNER JOIN sys.tables AS t
                ON t.schema_id = s.schema_id
            INNER JOIN sys.columns AS c
                ON c.object_id = t.object_id
            WHERE s.name = @SchemaName
              AND t.name = @TableName
              AND c.name = @GuidColumnName
        )
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredGuidColumnMissing',
                CONCAT(N'Registered metadata table does not have Guid column: ', @SchemaName, N'.', @TableName, N'.', @GuidColumnName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'","GuidColumnName":"', @GuidColumnName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SELECT
            @HasRowStatus =
                CASE WHEN EXISTS
                (
                    SELECT 1
                    FROM sys.schemas AS s
                    INNER JOIN sys.tables AS t
                        ON t.schema_id = s.schema_id
                    INNER JOIN sys.columns AS c
                        ON c.object_id = t.object_id
                    WHERE s.name = @SchemaName
                      AND t.name = @TableName
                      AND c.name = N'RowStatus'
                )
                THEN 1 ELSE 0 END;

        SELECT
            @ColumnList =
                STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N',')
                WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.schemas AS s
        INNER JOIN sys.tables AS t
            ON t.schema_id = s.schema_id
        INNER JOIN sys.columns AS c
            ON c.object_id = t.object_id
        WHERE s.name = @SchemaName
          AND t.name = @TableName
          AND c.is_computed = 0
          AND c.system_type_id <> 189;

        IF @ColumnList IS NULL
        BEGIN
            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SET @SourceRowStatusExpression =
            CASE WHEN @HasRowStatus = 1
                THEN N'TRY_CONVERT(TINYINT, s.RowStatus)'
                ELSE N'NULL'
            END;

        SET @SourceWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE s.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @SourceAndClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'AND'
                ELSE N'WHERE'
            END;

        SET @DuplicateWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE sd.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @TargetWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE t.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @TargetDuplicateWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE td.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @BothActiveWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE s.RowStatus NOT IN (0,254) AND t.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        -- A registered table can enforce uniqueness on more than its identity Guid (e.g. a
        -- Name+RowStatus natural key). Two environments can independently create a row with the
        -- same natural-key value under two different Guids; applying the source row would then
        -- fail with a raw unique-constraint violation instead of a reviewable, ignorable issue.
        -- Detect every such "other" unique index up front and flag conflicting rows the same way
        -- duplicate Guids are flagged: a non-blocking DuplicateTargetKey issue, and the row is
        -- excluded from Metadata_StagedRows below so it is never auto-applied.
        DECLARE other_unique_index_cursor CURSOR LOCAL FAST_FORWARD FOR
            WITH IndexColumnCounts AS
            (
                SELECT
                    ic.object_id,
                    ic.index_id,
                    COUNT(*) AS ColumnCount,
                    MIN(c.name) AS SoleColumnName,
                    -- RowStatus is excluded from this: it is a small, fixed reference domain
                    -- (0/1/254/...) seeded identically everywhere, and is already treated as a
                    -- universally-comparable value throughout this entire pipeline (every
                    -- "active row" filter compares it directly). Any other foreign key column
                    -- (e.g. EntityHoBTID) references another table's own auto-increment
                    -- surrogate ID, which is environment-specific and not safe to compare.
                    MAX
                    (
                        CASE
                            WHEN fkc.parent_column_id IS NOT NULL AND c.name <> N'RowStatus' THEN 1
                            ELSE 0
                        END
                    ) AS HasForeignKeyColumn
                FROM sys.index_columns AS ic
                INNER JOIN sys.columns AS c
                    ON c.object_id = ic.object_id
                   AND c.column_id = ic.column_id
                LEFT JOIN sys.foreign_key_columns AS fkc
                    ON fkc.parent_object_id = ic.object_id
                   AND fkc.parent_column_id = ic.column_id
                WHERE ic.is_included_column = 0
                GROUP BY ic.object_id, ic.index_id
            )
            SELECT
                i.index_id,
                i.name
            FROM sys.indexes AS i
            INNER JOIN sys.tables AS it
                ON it.object_id = i.object_id
            INNER JOIN sys.schemas AS isch
                ON isch.schema_id = it.schema_id
            INNER JOIN IndexColumnCounts AS icc
                ON icc.object_id = i.object_id
               AND icc.index_id = i.index_id
            WHERE isch.name = @SchemaName
              AND it.name = @TableName
              AND i.is_unique = 1
              -- Exclude the identity Guid's own unique index (handled by the duplicate-Guid
              -- checks above), the table's surrogate primary key (an auto-increment ID is
              -- environment-specific; coincidentally matching another environment's row by
              -- number is meaningless, not a real natural-key collision), and any index that
              -- keys off another table's surrogate ID via a foreign key for the same reason.
              AND NOT (icc.ColumnCount = 1 AND icc.SoleColumnName IN (@GuidColumnName, @PrimaryKeyColumnName))
              AND icc.HasForeignKeyColumn = 0;

        OPEN other_unique_index_cursor;

        FETCH NEXT FROM other_unique_index_cursor
        INTO @OtherUniqueIndexId, @OtherUniqueIndexName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @OtherIndexColumnList = NULL;
            SET @OtherIndexJoinPredicate = NULL;

            SELECT
                @OtherIndexColumnList =
                    STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N',')
                    WITHIN GROUP (ORDER BY ic.key_ordinal),
                @OtherIndexJoinPredicate =
                    STRING_AGG(CONVERT(NVARCHAR(MAX), N's.' + QUOTENAME(c.name) + N' = t.' + QUOTENAME(c.name)), N' AND ')
                    WITHIN GROUP (ORDER BY ic.key_ordinal)
            FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
              AND ic.index_id = @OtherUniqueIndexId
              AND ic.is_included_column = 0;

            IF @OtherIndexJoinPredicate IS NOT NULL
            BEGIN
                SET @Sql = N'
INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    d.SourceRowGuid,
    N''Warn'',
    N''DuplicateTargetKey'',
    CONCAT(N''Target unique key (' + REPLACE(@OtherUniqueIndexName, '''', '''''') + N') on ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' already has a different row with the same value: '', CONVERT(NVARCHAR(36), d.SourceRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","IndexName":"' + REPLACE(@OtherUniqueIndexName, '''', '''''') + N'","Columns":"' + REPLACE(@OtherIndexColumnList, '''', '''''') + N'","ConflictingTargetGuid":"'',
        CONVERT(NVARCHAR(36), d.ConflictingTargetGuid),
        N''"}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT DISTINCT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        CONVERT(UNIQUEIDENTIFIER, t.' + QUOTENAME(@GuidColumnName) + N') AS ConflictingTargetGuid
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    INNER JOIN ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS t
        ON ' + @OtherIndexJoinPredicate + N'
    ' + @BothActiveWhereClause + N'
    ' + @SourceAndClause + N' CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') <> CONVERT(UNIQUEIDENTIFIER, t.' + QUOTENAME(@GuidColumnName) + N')
) AS d;';

                EXEC sys.sp_executesql
                    @Sql,
                    N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
                    @RunGuid = @RunGuid,
                    @RegistryGuid = @RegistryGuid;
            END;

            FETCH NEXT FROM other_unique_index_cursor
            INTO @OtherUniqueIndexId, @OtherUniqueIndexName;
        END;

        CLOSE other_unique_index_cursor;
        DEALLOCATE other_unique_index_cursor;

        -- Excluding a conflicting row (duplicate Guid/key) is correct, but any other registered
        -- table that references it by foreign key would otherwise silently try to apply an
        -- orphaned row (its lookup resolves to nothing, e.g. a NULL foreign key at Apply time).
        -- Registries are processed in ApplyOrder, the same dependency order Apply itself relies
        -- on, so by the time a child table is processed here every parent table it could
        -- reference has already recorded its own exclusions in Metadata_ValidationIssues for
        -- this run - cascade through those the same way, one foreign key relationship at a time.
        DECLARE cascade_fk_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                pc.name AS ChildColumnName,
                rs.name AS RefSchemaName,
                rt.name AS RefTableName,
                rc.name AS RefColumnName
            FROM sys.foreign_key_columns AS fkc
            INNER JOIN sys.columns AS pc
                ON pc.object_id = fkc.parent_object_id
               AND pc.column_id = fkc.parent_column_id
            INNER JOIN sys.tables AS rt
                ON rt.object_id = fkc.referenced_object_id
            INNER JOIN sys.schemas AS rs
                ON rs.schema_id = rt.schema_id
            INNER JOIN sys.columns AS rc
                ON rc.object_id = fkc.referenced_object_id
               AND rc.column_id = fkc.referenced_column_id
            WHERE fkc.parent_object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
              AND pc.name <> N'RowStatus'
              AND NOT (rs.name = @SchemaName AND rt.name = @TableName)
              AND EXISTS
              (
                  SELECT 1
                  FROM SMigration.Metadata_TableRegistry AS refTr
                  WHERE refTr.SchemaName = rs.name
                    AND refTr.TableName = rt.name
                    AND refTr.RowStatus NOT IN (0,254)
                    AND refTr.IsEnabled = 1
              );

        OPEN cascade_fk_cursor;

        FETCH NEXT FROM cascade_fk_cursor
        INTO @CascadeFkColumnName, @CascadeRefSchemaName, @CascadeRefTableName, @CascadeRefColumnName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT
                @CascadeRefRegistryGuid = refTr.Guid,
                @CascadeRefGuidColumnName = refTr.GuidColumnName
            FROM SMigration.Metadata_TableRegistry AS refTr
            WHERE refTr.SchemaName = @CascadeRefSchemaName
              AND refTr.TableName = @CascadeRefTableName
              AND refTr.RowStatus NOT IN (0,254)
              AND refTr.IsEnabled = 1;

            IF @CascadeRefRegistryGuid IS NOT NULL AND NULLIF(@CascadeRefGuidColumnName, N'') IS NOT NULL
            BEGIN
                SET @Sql = N'
INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    d.SourceRowGuid,
    N''Warn'',
    N''UnresolvedReference'',
    CONCAT(N''Row in ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' references ' + REPLACE(@CascadeRefSchemaName, '''', '''''') + N'.' + REPLACE(@CascadeRefTableName, '''', '''''') + N' Guid '', CONVERT(NVARCHAR(36), d.ReferencedGuid), N'' which is excluded from this run and needs manual correction upstream first: '', CONVERT(NVARCHAR(36), d.SourceRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","ForeignKeyColumn":"' + REPLACE(@CascadeFkColumnName, '''', '''''') + N'","ReferencedSchemaName":"' + REPLACE(@CascadeRefSchemaName, '''', '''''') + N'","ReferencedTableName":"' + REPLACE(@CascadeRefTableName, '''', '''''') + N'","ReferencedGuid":"'',
        CONVERT(NVARCHAR(36), d.ReferencedGuid),
        N''"}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT DISTINCT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        CONVERT(UNIQUEIDENTIFIER, rp.' + QUOTENAME(@CascadeRefGuidColumnName) + N') AS ReferencedGuid
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    INNER JOIN ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@CascadeRefSchemaName) + N'.' + QUOTENAME(@CascadeRefTableName) + N' AS rp
        ON rp.' + QUOTENAME(@CascadeRefColumnName) + N' = s.' + QUOTENAME(@CascadeFkColumnName) + N'
    ' + @SourceWhereClause + N'
    ' + @SourceAndClause + N' EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ValidationIssues AS vi
        WHERE vi.RunGuid = @RunGuid
          AND vi.RegistryGuid = @CascadeRefRegistryGuid
          AND vi.SourceRowGuid = CONVERT(UNIQUEIDENTIFIER, rp.' + QUOTENAME(@CascadeRefGuidColumnName) + N')
          AND vi.IssueCode IN (N''DuplicateSourceGuid'', N''DuplicateTargetGuid'', N''DuplicateTargetKey'', N''UnresolvedReference'')
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ValidationIssues AS existing
        WHERE existing.RunGuid = @RunGuid
          AND existing.RegistryGuid = @RegistryGuid
          AND existing.SourceRowGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
          AND existing.IssueCode = N''UnresolvedReference''
    )
) AS d;';

                EXEC sys.sp_executesql
                    @Sql,
                    N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER, @CascadeRefRegistryGuid UNIQUEIDENTIFIER',
                    @RunGuid = @RunGuid,
                    @RegistryGuid = @RegistryGuid,
                    @CascadeRefRegistryGuid = @CascadeRefRegistryGuid;
            END;

            SET @CascadeRefRegistryGuid = NULL;
            SET @CascadeRefGuidColumnName = NULL;

            FETCH NEXT FROM cascade_fk_cursor
            INTO @CascadeFkColumnName, @CascadeRefSchemaName, @CascadeRefTableName, @CascadeRefColumnName;
        END;

        CLOSE cascade_fk_cursor;
        DEALLOCATE cascade_fk_cursor;

        SET @Sql = N'
INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    d.SourceRowGuid,
    N''Fail'',
    N''DuplicateSourceGuid'',
    CONCAT(N''Source metadata table contains duplicate active Guid values: ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' / '', CONVERT(NVARCHAR(36), d.SourceRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","DuplicateCount":'',
        CONVERT(NVARCHAR(30), d.DuplicateCount),
        N''}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        COUNT_BIG(1) AS DuplicateCount
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    GROUP BY CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    HAVING COUNT_BIG(1) > 1
) AS d;

INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    d.TargetRowGuid,
    N''Warn'',
    N''DuplicateTargetGuid'',
    CONCAT(N''Target metadata table contains duplicate active Guid values (needs manual correction; excluded from staging and apply): ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' / '', CONVERT(NVARCHAR(36), d.TargetRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","DuplicateCount":'',
        CONVERT(NVARCHAR(30), d.DuplicateCount),
        N''}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, t.' + QUOTENAME(@GuidColumnName) + N') AS TargetRowGuid,
        COUNT_BIG(1) AS DuplicateCount
    FROM ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS t
    ' + @TargetWhereClause + N'
    GROUP BY CONVERT(UNIQUEIDENTIFIER, t.' + QUOTENAME(@GuidColumnName) + N')
    HAVING COUNT_BIG(1) > 1
) AS d;

INSERT INTO SMigration.Metadata_StagedRows
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    SourceRowId,
    SourceRowStatus,
    SourcePayloadJson,
    SourcePayloadHash,
    TargetPayloadJson,
    TargetPayloadHash,
    DifferenceType,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    src.SourceRowGuid,
    src.SourceRowId,
    src.SourceRowStatus,
    src.SourcePayloadJson,
    HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson)),
    tgt.TargetPayloadJson,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN NULL
        ELSE HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson))
    END,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN N''Insert''
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson))
           <> HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''Update''
        ELSE N''NoChange''
    END,
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        TRY_CONVERT(BIGINT, s.' + QUOTENAME(@PrimaryKeyColumnName) + N') AS SourceRowId,
        ' + @SourceRowStatusExpression + N' AS SourceRowStatus,
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sj
            WHERE sj.' + QUOTENAME(@GuidColumnName) + N' = s.' + QUOTENAME(@GuidColumnName) + N'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS SourcePayloadJson
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    ' + @SourceAndClause + N' NOT EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT
                CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N') AS DuplicateGuid
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sd
            ' + @DuplicateWhereClause + N'
            GROUP BY CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N')
            HAVING COUNT_BIG(1) > 1
        ) AS dup
        WHERE dup.DuplicateGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT
                CONVERT(UNIQUEIDENTIFIER, td.' + QUOTENAME(@GuidColumnName) + N') AS DuplicateGuid
            FROM ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS td
            ' + @TargetDuplicateWhereClause + N'
            GROUP BY CONVERT(UNIQUEIDENTIFIER, td.' + QUOTENAME(@GuidColumnName) + N')
            HAVING COUNT_BIG(1) > 1
        ) AS tdup
        WHERE tdup.DuplicateGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ValidationIssues AS vi
        WHERE vi.RunGuid = @RunGuid
          AND vi.RegistryGuid = @RegistryGuid
          AND vi.IssueCode IN (N''DuplicateTargetKey'', N''UnresolvedReference'')
          AND vi.SourceRowGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    )
) AS src
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS tj
            WHERE tj.' + QUOTENAME(@GuidColumnName) + N' = src.SourceRowGuid
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid;

        FETCH NEXT FROM registry_cursor
        INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;
    END;

    CLOSE registry_cursor;
    DEALLOCATE registry_cursor;

    EXEC SMigration.MetadataStage_NormaliseDifferences
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates
    @RunGuid = @RunGuid;

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = N'Staged',
        SummaryJson =
        (
            SELECT
                CONCAT
                (
                    N'{"insertCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                    N',"updateCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                    N',"noChangeCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                    N',"totalCount":',
                    CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                    N'}'
                )
            FROM SMigration.Metadata_StagedRows AS sr
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254)
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'StageRun',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata staging completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataValidate_Run using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataValidate_Run.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataValidate_Run]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataValidate_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FailCount INT = 0;
    DECLARE @WarnCount INT = 0;
    DECLARE @InfoCount INT = 0;
    DECLARE @TargetDatabaseName SYSNAME;

    SELECT
        @TargetDatabaseName = run.TargetDatabaseName
    FROM SMigration.Metadata_Run AS run
    WHERE run.Guid = @RunGuid
      AND run.RowStatus NOT IN (0,254);

    BEGIN TRANSACTION;

    CREATE TABLE #MetadataSelectedValidationRows
    (
        RegistryGuid UNIQUEIDENTIFIER NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_MetadataSelectedValidationRows PRIMARY KEY CLUSTERED
        (
            RegistryGuid,
            SourceRowGuid
        )
    );

    INSERT INTO #MetadataSelectedValidationRows
    (
        RegistryGuid,
        SourceRowGuid
    )
    SELECT DISTINCT
        sr.RegistryGuid,
        sr.SourceRowGuid
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_RunSelections AS selection
        ON selection.RunGuid = sr.RunGuid
       AND selection.RegistryGuid = sr.RegistryGuid
       AND selection.SourceRowGuid = sr.SourceRowGuid
       AND selection.RowStatus NOT IN (0,254)
    INNER JOIN SMigration.Metadata_Run AS run
        ON run.Guid = sr.RunGuid
       AND run.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = run.TargetDatabaseName
            AND ignored.RegistryGuid = sr.RegistryGuid
            AND ignored.SourceRowGuid = sr.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IdentityMapOverrides AS identityOverride
          WHERE identityOverride.DatabaseName = run.TargetDatabaseName
            AND identityOverride.RegistryGuid = sr.RegistryGuid
            AND identityOverride.SourceRowGuid = sr.SourceRowGuid
            AND identityOverride.RowStatus NOT IN (0,254)
      );

    -- Only clear validation issues owned by this validation proc.
    -- Do NOT delete staging-discovered blockers such as
    -- DuplicateSourceGuid/DuplicateTargetGuid/DuplicateTargetKey/UnresolvedReference.
    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'RunNotFound',
          N'NoSelectedRows',
          N'DuplicateStagedRow',
          N'UnsupportedApplyHandler',
          N'GridViewColumnMissingFromQuery'
      );

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
    BEGIN
        INSERT INTO SMigration.Metadata_ValidationIssues
        (
            Guid,
            RowStatus,
            RunGuid,
            RegistryGuid,
            SourceRowGuid,
            Severity,
            IssueCode,
            IssueMessage,
            DetailsJson,
            CreatedOnUtc
        )
        SELECT
            NEWID(),
            1,
            @RunGuid,
            NULL,
            NULL,
            N'Fail',
            N'RunNotFound',
            N'Metadata migration run does not exist or is inactive.',
            N'{}',
            SYSUTCDATETIME();
    END;

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
       AND NOT EXISTS (SELECT 1 FROM #MetadataSelectedValidationRows)
    BEGIN
        INSERT INTO SMigration.Metadata_ValidationIssues
        (
            Guid,
            RowStatus,
            RunGuid,
            RegistryGuid,
            SourceRowGuid,
            Severity,
            IssueCode,
            IssueMessage,
            DetailsJson,
            CreatedOnUtc
        )
        SELECT
            NEWID(),
            1,
            @RunGuid,
            NULL,
            NULL,
            N'Fail',
            N'NoSelectedRows',
            N'No metadata rows are selected. Select at least one non-ignored Insert or Update row before validation.',
            N'{}',
            SYSUTCDATETIME();
    END;

    INSERT INTO SMigration.Metadata_ValidationIssues
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SourceRowGuid,
        Severity,
        IssueCode,
        IssueMessage,
        DetailsJson,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        @RunGuid,
        sr.RegistryGuid,
        sr.SourceRowGuid,
        N'Fail',
        N'DuplicateStagedRow',
        N'The staged run contains duplicate rows for the same table and source row Guid.',
        CONCAT(N'{"SourceRowGuid":"', CONVERT(NVARCHAR(36), sr.SourceRowGuid), N'"}'),
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN #MetadataSelectedValidationRows AS selected
        ON selected.RegistryGuid = sr.RegistryGuid
       AND selected.SourceRowGuid = sr.SourceRowGuid
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
    GROUP BY
        sr.RegistryGuid,
        sr.SourceRowGuid
    HAVING COUNT_BIG(1) > 1;

    /*
        Staging can discover metadata tables dynamically from EntityTypes, while
        MetadataApply_Run intentionally uses explicit, reviewed handlers. Fail
        closed when an actionable staged table has no apply handler so a run
        cannot report success while silently leaving metadata unapplied.
    */
    INSERT INTO SMigration.Metadata_ValidationIssues
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SourceRowGuid,
        Severity,
        IssueCode,
        IssueMessage,
        DetailsJson,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        @RunGuid,
        sr.RegistryGuid,
        NULL,
        N'Fail',
        N'UnsupportedApplyHandler',
        CONCAT
        (
            N'No controlled metadata apply handler exists for ',
            tr.SchemaName,
            N'.',
            tr.TableName,
            N'.'
        ),
        CONCAT
        (
            N'{"SchemaName":"',
            STRING_ESCAPE(tr.SchemaName, 'json'),
            N'","TableName":"',
            STRING_ESCAPE(tr.TableName, 'json'),
            N'"}'
        ),
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    INNER JOIN SMigration.Metadata_Run AS run
        ON run.Guid = sr.RunGuid
       AND run.RowStatus NOT IN (0,254)
    INNER JOIN #MetadataSelectedValidationRows AS selected
        ON selected.RegistryGuid = sr.RegistryGuid
       AND selected.SourceRowGuid = sr.SourceRowGuid
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = run.TargetDatabaseName
            AND ignored.RegistryGuid = sr.RegistryGuid
            AND ignored.SourceRowGuid = sr.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IdentityMapOverrides AS identityOverride
          WHERE identityOverride.DatabaseName = run.TargetDatabaseName
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
          OR
          (tr.SchemaName = N'SJob' AND tr.TableName IN
          (
              N'MilestoneTypes'
          ))
      )
    GROUP BY
        sr.RegistryGuid,
        tr.SchemaName,
        tr.TableName;

    /*
        A GridViewDefinitions row's SqlQuery is free text, hand-maintained independently of its
        child GridViewColumnDefinitions rows - nothing enforces that every active column Name is
        actually projected by the query. The mismatch is invisible until a user opens the grid:
        CoreService's GridDataList reads each column purely by name
        (reader.GetOrdinal(column.Name) in libs/Concursus.EF/UserInterface.cs), so a column
        definition with no matching column in the query throws at render time instead of here.

        Compare, for every (GridViewDefinitions, GridViewColumnDefinitions) pair where at least one
        side is part of this run's selection, the grid's current source SqlQuery text against each
        active source column's Name. This is a text-presence heuristic (word-boundary search), not
        a real result-set comparison - no dynamic SQL or cross-database context switch is
        attempted. It will not catch a column aliased under a different name, but it catches the
        actual failure mode seen in production: a column definition added with nothing in the
        query selecting it at all. Column names containing SQL LIKE wildcard characters
        (%, _, [, ]) are not expected in this codebase and are not specially escaped here.
    */
    DECLARE @GridViewDefinitionsRegistryGuid UNIQUEIDENTIFIER;
    DECLARE @GridViewColumnDefinitionsRegistryGuid UNIQUEIDENTIFIER;

    SELECT @GridViewDefinitionsRegistryGuid = tr.Guid
    FROM SMigration.Metadata_TableRegistry AS tr
    WHERE tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
      AND tr.RowStatus NOT IN (0,254);

    SELECT @GridViewColumnDefinitionsRegistryGuid = tr.Guid
    FROM SMigration.Metadata_TableRegistry AS tr
    WHERE tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
      AND tr.RowStatus NOT IN (0,254);

    IF @GridViewDefinitionsRegistryGuid IS NOT NULL AND @GridViewColumnDefinitionsRegistryGuid IS NOT NULL
    BEGIN
        CREATE TABLE #GridViewDefinitionSource
        (
            SourceRowGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            SourceRowId BIGINT NOT NULL,
            Code NVARCHAR(20) NOT NULL,
            SqlQuery NVARCHAR(MAX) NOT NULL
        );

        -- OPENJSON's WITH clause (unlike JSON_VALUE) does not truncate NVARCHAR(MAX) at 4000
        -- characters, which matters here since SqlQuery routinely exceeds that.
        INSERT INTO #GridViewDefinitionSource
        (
            SourceRowGuid,
            SourceRowId,
            Code,
            SqlQuery
        )
        SELECT
            sr.SourceRowGuid,
            sr.SourceRowId,
            j.Code,
            j.SqlQuery
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.SourcePayloadJson)
            WITH
            (
                Code NVARCHAR(20) '$.Code',
                SqlQuery NVARCHAR(MAX) '$.SqlQuery'
            ) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.RegistryGuid = @GridViewDefinitionsRegistryGuid
          AND sr.SourceRowId IS NOT NULL;

        CREATE TABLE #GridViewColumnSource
        (
            SourceRowGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            GridViewDefinitionId BIGINT NOT NULL,
            Name NVARCHAR(100) NOT NULL
        );

        INSERT INTO #GridViewColumnSource
        (
            SourceRowGuid,
            GridViewDefinitionId,
            Name
        )
        SELECT
            sr.SourceRowGuid,
            j.GridViewDefinitionId,
            j.Name
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.SourcePayloadJson)
            WITH
            (
                GridViewDefinitionId BIGINT '$.GridViewDefinitionId',
                Name NVARCHAR(100) '$.Name'
            ) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.RegistryGuid = @GridViewColumnDefinitionsRegistryGuid
          AND NULLIF(j.Name, N'') IS NOT NULL;

        -- Anchor each issue to whichever side of the pair is actually part of this run's
        -- selection, so it is picked up by the FailCount/summary filter below regardless of
        -- whether the grid's query or the column's definition is what changed in this run.
        INSERT INTO SMigration.Metadata_ValidationIssues
        (
            Guid,
            RowStatus,
            RunGuid,
            RegistryGuid,
            SourceRowGuid,
            Severity,
            IssueCode,
            IssueMessage,
            DetailsJson,
            CreatedOnUtc
        )
        SELECT
            NEWID(),
            1,
            @RunGuid,
            CASE WHEN colSelected.SourceRowGuid IS NOT NULL THEN @GridViewColumnDefinitionsRegistryGuid ELSE @GridViewDefinitionsRegistryGuid END,
            CASE WHEN colSelected.SourceRowGuid IS NOT NULL THEN col.SourceRowGuid ELSE grid.SourceRowGuid END,
            N'Fail',
            N'GridViewColumnMissingFromQuery',
            CONCAT
            (
                N'GridViewColumnDefinitions.Name ''', col.Name,
                N''' has no matching column in GridViewDefinitions ''', grid.Code,
                N''' SqlQuery. The grid will fail at render time (reader.GetOrdinal) unless the query is updated to project a same-named column.'
            ),
            CONCAT
            (
                N'{"GridViewDefinitionCode":"', STRING_ESCAPE(grid.Code, 'json'),
                N'","ColumnName":"', STRING_ESCAPE(col.Name, 'json'), N'"}'
            ),
            SYSUTCDATETIME()
        FROM #GridViewColumnSource AS col
        INNER JOIN #GridViewDefinitionSource AS grid
            ON grid.SourceRowId = col.GridViewDefinitionId
        LEFT JOIN #MetadataSelectedValidationRows AS colSelected
            ON colSelected.RegistryGuid = @GridViewColumnDefinitionsRegistryGuid
           AND colSelected.SourceRowGuid = col.SourceRowGuid
        LEFT JOIN #MetadataSelectedValidationRows AS gridSelected
            ON gridSelected.RegistryGuid = @GridViewDefinitionsRegistryGuid
           AND gridSelected.SourceRowGuid = grid.SourceRowGuid
        WHERE
        (
            colSelected.SourceRowGuid IS NOT NULL
            OR gridSelected.SourceRowGuid IS NOT NULL
        )
        AND PATINDEX
        (
            N'%[^A-Za-z0-9_]' + col.Name + N'[^A-Za-z0-9_]%',
            N' ' + grid.SqlQuery + N' '
        ) = 0;

        DROP TABLE #GridViewColumnSource;
        DROP TABLE #GridViewDefinitionSource;
    END;

    UPDATE ignored
    SET
        ignored.LastSeenRunGuid = @RunGuid,
        ignored.LastSeenOnUtc = SYSUTCDATETIME()
    FROM SMigration.Metadata_ValidationIssueIgnores AS ignored
    INNER JOIN SMigration.Metadata_ValidationIssues AS issue
        ON issue.RunGuid = @RunGuid
       AND issue.RegistryGuid = ignored.RegistryGuid
       AND issue.SourceRowGuid = ignored.SourceRowGuid
       AND issue.IssueCode = ignored.IssueCode
       AND issue.RowStatus NOT IN (0,254)
    WHERE ignored.DatabaseName = @TargetDatabaseName
      AND ignored.RowStatus NOT IN (0,254);

    SELECT
        @FailCount = SUM(CASE WHEN vi.Severity = N'Fail' THEN 1 ELSE 0 END),
        @WarnCount = SUM(CASE WHEN vi.Severity = N'Warn' THEN 1 ELSE 0 END),
        @InfoCount = SUM(CASE WHEN vi.Severity = N'Info' THEN 1 ELSE 0 END)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue
          WHERE ignoredIssue.DatabaseName = @TargetDatabaseName
            AND ignoredIssue.RegistryGuid = vi.RegistryGuid
            AND ignoredIssue.SourceRowGuid = vi.SourceRowGuid
            AND ignoredIssue.IssueCode = vi.IssueCode
            AND ignoredIssue.RowStatus NOT IN (0,254)
      )
      AND
      (
          vi.IssueCode IN (N'RunNotFound', N'NoSelectedRows', N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
          OR EXISTS
          (
              SELECT 1
              FROM #MetadataSelectedValidationRows AS selected
              WHERE selected.RegistryGuid = vi.RegistryGuid
                AND
                (
                    vi.SourceRowGuid IS NULL
                    OR selected.SourceRowGuid = vi.SourceRowGuid
                )
          )
      );

    SET @FailCount = ISNULL(@FailCount, 0);
    SET @WarnCount = ISNULL(@WarnCount, 0);
    SET @InfoCount = ISNULL(@InfoCount, 0);

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = CASE WHEN @FailCount > 0 THEN N'ValidationFailed' ELSE N'Validated' END,
        ValidatedOnUtc = SYSUTCDATETIME(),
        SummaryJson = CONCAT
        (
            N'{"failCount":',
            CONVERT(NVARCHAR(30), @FailCount),
            N',"warnCount":',
            CONVERT(NVARCHAR(30), @WarnCount),
            N',"infoCount":',
            CONVERT(NVARCHAR(30), @InfoCount),
            N'}'
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
    DECLARE @_StepStatus AS NVARCHAR(15) = (CASE WHEN @FailCount > 0 THEN N'Failed' ELSE N'Succeeded' END)
    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ValidateRun',
        @StepStatus = @_StepStatus,
        @Message = N'Metadata migration validation completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;

    SELECT
        @FailCount AS FailCount,
        @WarnCount AS WarnCount,
        @InfoCount AS InfoCount;
END;
GO

GO
DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();
EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;
GO
