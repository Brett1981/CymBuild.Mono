/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLBRE01\SQL2022
    Target database : CymBuild_UAT
    Run Guid        : 89ffb9ba-0000-4e9c-a5cf-29af09eb995a
    Generated UTC   : 2026-09-16T12:52:37.8567272Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_UAT];
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
          -- A row with a manual Identity Map override is NOT exempt from the handler-coverage
          -- guard: it will now actually be applied (as an update to the mapped target row via
          -- #MetadataRowsToApply below), so it needs a controlled handler exactly like any other
          -- actionable row. An override on a table with no handler must still block the apply.
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
      );
      -- A row with a manual Identity Map override is deliberately INCLUDED here (unlike ignored
      -- records): the override means "apply this row's content as an update to the record I
      -- matched it to," not "never touch it." Each per-table cursor below resolves the override's
      -- TargetRowGuid (via its own LEFT JOIN to Metadata_IdentityMapOverrides) instead of the
      -- row's own SourceRowGuid, so SCore.UpsertDataObject correctly detects it as an update
      -- against the matched target rather than inserting a duplicate.

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
        @Name NVARCHAR(500),
        @OverrideTargetGuid UNIQUEIDENTIFIER,
        @LL_ColumnSourceSelectionJson NVARCHAR(MAX),
        @LL_Target_Name NVARCHAR(500),
        @LL_TargetRowFound BIT;

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            ov.TargetRowGuid,
            ov.ColumnSourceSelectionJson
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
            ON ov.DatabaseName = @TargetDatabaseName
           AND ov.RegistryGuid = sr.RegistryGuid
           AND ov.SourceRowGuid = sr.SourceRowGuid
           AND ov.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name, @OverrideTargetGuid, @LL_ColumnSourceSelectionJson;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = ISNULL(@OverrideTargetGuid, @Guid);

        IF @OverrideTargetGuid IS NOT NULL AND @LL_ColumnSourceSelectionJson IS NOT NULL
        BEGIN
            SET @LL_TargetRowFound = 0;
            SET @LL_Target_Name = NULL;

            SELECT @LL_Target_Name = targetrow.Name
            FROM SCore.LanguageLabels AS targetrow
            WHERE targetrow.Guid = @OverrideTargetGuid;

            IF @@ROWCOUNT > 0 SET @LL_TargetRowFound = 1;

            -- Only trust the "keep target value" merge when the override's target row actually
            -- resolved; a stale/unresolved override must fall back to the source value instead
            -- of silently reusing whatever a prior loop iteration left in @LL_Target_Name.
            IF @LL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@LL_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @Name = @LL_Target_Name;
        END;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name, @OverrideTargetGuid, @LL_ColumnSourceSelectionJson;
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
        @LLT_OverrideTargetGuid UNIQUEIDENTIFIER,
        @LLT_ColumnSourceSelectionJson NVARCHAR(MAX),
        @LLT_Target_Text NVARCHAR(500),
        @LLT_Target_TextPlural NVARCHAR(500),
        @LLT_Target_HelpText NVARCHAR(MAX),
        @LLT_TargetRowFound BIT,
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
        SourceRowId BIGINT NULL,
        OverrideTargetGuid UNIQUEIDENTIFIER NULL,
        ColumnSourceSelectionJson NVARCHAR(MAX) NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId,
        OverrideTargetGuid,
        ColumnSourceSelectionJson
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageId'))),
        sr.SourceRowId,
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
            SourceLanguageId,
            OverrideTargetGuid,
            ColumnSourceSelectionJson
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId, @LLT_OverrideTargetGuid, @LLT_ColumnSourceSelectionJson;

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

        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = ISNULL(@LLT_OverrideTargetGuid, @Guid);

        IF @LLT_OverrideTargetGuid IS NOT NULL AND @LLT_ColumnSourceSelectionJson IS NOT NULL
        BEGIN
            SET @LLT_TargetRowFound = 0;
            SET @LLT_Target_Text = NULL;
            SET @LLT_Target_TextPlural = NULL;
            SET @LLT_Target_HelpText = NULL;

            SELECT
                @LLT_Target_Text = targetrow.Text,
                @LLT_Target_TextPlural = targetrow.TextPlural,
                @LLT_Target_HelpText = targetrow.HelpText
            FROM SCore.LanguageLabelTranslations AS targetrow
            WHERE targetrow.Guid = @LLT_OverrideTargetGuid;

            IF @@ROWCOUNT > 0 SET @LLT_TargetRowFound = 1;

            -- Only trust the "keep target value" merge when the override's target row actually
            -- resolved; a stale/unresolved override must fall back to the source value instead
            -- of silently reusing whatever a prior loop iteration left in these variables.
            IF @LLT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@LLT_ColumnSourceSelectionJson) WHERE [value] = N'Text') SET @Text = @LLT_Target_Text;
            IF @LLT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@LLT_ColumnSourceSelectionJson) WHERE [value] = N'TextPlural') SET @TextPlural = @LLT_Target_TextPlural;
            IF @LLT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@LLT_ColumnSourceSelectionJson) WHERE [value] = N'HelpText') SET @HelpText = @LLT_Target_HelpText;
        END;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId, @LLT_OverrideTargetGuid, @LLT_ColumnSourceSelectionJson;
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
        @EDT_IsInsert BIT,
        @EDT_OverrideTargetGuid UNIQUEIDENTIFIER,
        @EDT_GuidToApply UNIQUEIDENTIFIER,
        @EDT_ColumnSourceSelectionJson NVARCHAR(MAX);

    DECLARE EntityDataTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.QuoteValue')),
            ov.TargetRowGuid,
            ov.ColumnSourceSelectionJson
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
            ON ov.DatabaseName = @TargetDatabaseName
           AND ov.RegistryGuid = sr.RegistryGuid
           AND ov.SourceRowGuid = sr.SourceRowGuid
           AND ov.RowStatus NOT IN (0,254)
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
        @EDT_QuoteValue,
        @EDT_OverrideTargetGuid,
        @EDT_ColumnSourceSelectionJson;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EDT_IsInsert = 0;
        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        SET @EDT_GuidToApply = ISNULL(@EDT_OverrideTargetGuid, @Guid);

        EXEC SCore.UpsertDataObject
            @Guid = @EDT_GuidToApply,
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
                @EDT_GuidToApply,
                ISNULL(NULLIF(@EDT_RowStatus, 0), 1),
                ISNULL(@EDT_Name, N''),
                ISNULL(@EDT_QuoteValue, 0)
            );
        END;
        ELSE
        BEGIN
            -- An override's column selection means "keep the target's current value for any
            -- column not selected" - an UPDATE can express that directly by referencing the
            -- table's own current column value on the ELSE branch.
            UPDATE SCore.EntityDataTypes
            SET
                RowStatus = CASE WHEN @EDT_ColumnSourceSelectionJson IS NULL OR EXISTS (SELECT 1 FROM OPENJSON(@EDT_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') THEN ISNULL(NULLIF(@EDT_RowStatus, 0), RowStatus) ELSE RowStatus END,
                Name = CASE WHEN @EDT_ColumnSourceSelectionJson IS NULL OR EXISTS (SELECT 1 FROM OPENJSON(@EDT_ColumnSourceSelectionJson) WHERE [value] = N'Name') THEN ISNULL(@EDT_Name, N'') ELSE Name END,
                QuoteValue = CASE WHEN @EDT_ColumnSourceSelectionJson IS NULL OR EXISTS (SELECT 1 FROM OPENJSON(@EDT_ColumnSourceSelectionJson) WHERE [value] = N'QuoteValue') THEN ISNULL(@EDT_QuoteValue, 0) ELSE QuoteValue END
            WHERE Guid = @EDT_GuidToApply;
        END;

        FETCH NEXT FROM EntityDataTypes_Cursor
        INTO
            @Guid,
            @EDT_RowStatus,
            @EDT_Name,
            @EDT_QuoteValue,
            @EDT_OverrideTargetGuid,
            @EDT_ColumnSourceSelectionJson;
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
        @ICON_OverrideTargetGuid UNIQUEIDENTIFIER,
        @ICON_GuidToApply UNIQUEIDENTIFIER,
        @ICON_ColumnSourceSelectionJson NVARCHAR(MAX);

    DECLARE Icons_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            sr.SourceRowId,
            ov.TargetRowGuid,
            ov.ColumnSourceSelectionJson
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
            ON ov.DatabaseName = @TargetDatabaseName
           AND ov.RegistryGuid = sr.RegistryGuid
           AND ov.SourceRowGuid = sr.SourceRowGuid
           AND ov.RowStatus NOT IN (0,254)
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
        @ICON_SourceRowId,
        @ICON_OverrideTargetGuid,
        @ICON_ColumnSourceSelectionJson;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ICON_ExistingGuid = NULL;
        SET @ICON_GuidToApply = @Guid;
        SET @ICON_IsInsert = 0;

        IF @ICON_OverrideTargetGuid IS NOT NULL
        BEGIN
            -- A manual Identity Map override is an explicit, reviewed operator decision and
            -- wins over the natural-key (Name) match below.
            SET @ICON_GuidToApply = @ICON_OverrideTargetGuid;
        END;
        ELSE
        BEGIN
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
                RowStatus = CASE WHEN @ICON_ColumnSourceSelectionJson IS NULL OR EXISTS (SELECT 1 FROM OPENJSON(@ICON_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') THEN ISNULL(NULLIF(@ICON_RowStatus, 0), RowStatus) ELSE RowStatus END,
                Name = CASE WHEN @ICON_ColumnSourceSelectionJson IS NULL OR EXISTS (SELECT 1 FROM OPENJSON(@ICON_ColumnSourceSelectionJson) WHERE [value] = N'Name') THEN ISNULL(@ICON_Name, N'') ELSE Name END
            WHERE Guid = @ICON_GuidToApply;
        END;

        FETCH NEXT FROM Icons_Cursor
        INTO
            @Guid,
            @ICON_RowStatus,
            @ICON_Name,
            @ICON_SourceRowId,
            @ICON_OverrideTargetGuid,
            @ICON_ColumnSourceSelectionJson;
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
        @ET_IconGuid UNIQUEIDENTIFIER,
        @ET_OverrideTargetGuid UNIQUEIDENTIFIER,
        @ET_ColumnSourceSelectionJson NVARCHAR(MAX),
        @ET_Target_RowStatus TINYINT,
        @ET_Target_Name NVARCHAR(250),
        @ET_Target_IsReadOnlyOffline BIT,
        @ET_Target_IsRequiredSystemData BIT,
        @ET_Target_HasDocuments BIT,
        @ET_Target_DoNotTrackChanges BIT,
        @ET_Target_IsRootEntity BIT,
        @ET_Target_DetailPageUrl NVARCHAR(250),
        @ET_Target_IsMetaData BIT,
        @ET_Target_IsDeletable BIT,
        @ET_TargetRowFound BIT;

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
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDeletable')), 1),
            ov.TargetRowGuid,
            ov.ColumnSourceSelectionJson
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
            ON ov.DatabaseName = @TargetDatabaseName
           AND ov.RegistryGuid = sr.RegistryGuid
           AND ov.SourceRowGuid = sr.SourceRowGuid
           AND ov.RowStatus NOT IN (0,254)
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
            @ET_IsDeletable,
            @ET_OverrideTargetGuid,
            @ET_ColumnSourceSelectionJson;

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

        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        DECLARE @EntityTypeGuidToApply UNIQUEIDENTIFIER = ISNULL(@ET_OverrideTargetGuid, @Guid);

        -- An override's column selection only ever governs plain scalar columns - FK/lookup
        -- columns (LanguageLabelGuid, IconGuid) always come from source, since they are
        -- cross-environment identity references this pipeline is specifically resolving,
        -- not target-environment-owned data.
        IF @ET_OverrideTargetGuid IS NOT NULL AND @ET_ColumnSourceSelectionJson IS NOT NULL
        BEGIN
            SET @ET_TargetRowFound = 0;
            SET @ET_Target_RowStatus = NULL;
            SET @ET_Target_Name = NULL;
            SET @ET_Target_IsReadOnlyOffline = NULL;
            SET @ET_Target_IsRequiredSystemData = NULL;
            SET @ET_Target_HasDocuments = NULL;
            SET @ET_Target_DoNotTrackChanges = NULL;
            SET @ET_Target_IsRootEntity = NULL;
            SET @ET_Target_DetailPageUrl = NULL;
            SET @ET_Target_IsMetaData = NULL;
            SET @ET_Target_IsDeletable = NULL;

            SELECT
                @ET_Target_RowStatus = targetrow.RowStatus,
                @ET_Target_Name = targetrow.Name,
                @ET_Target_IsReadOnlyOffline = targetrow.IsReadOnlyOffline,
                @ET_Target_IsRequiredSystemData = targetrow.IsRequiredSystemData,
                @ET_Target_HasDocuments = targetrow.HasDocuments,
                @ET_Target_DoNotTrackChanges = targetrow.DoNotTrackChanges,
                @ET_Target_IsRootEntity = targetrow.IsRootEntity,
                @ET_Target_DetailPageUrl = targetrow.DetailPageUrl,
                @ET_Target_IsMetaData = targetrow.IsMetaData,
                @ET_Target_IsDeletable = targetrow.IsDeletable
            FROM SCore.EntityTypes AS targetrow
            WHERE targetrow.Guid = @ET_OverrideTargetGuid;

            IF @@ROWCOUNT > 0 SET @ET_TargetRowFound = 1;

            -- Only trust the "keep target value" merge when the override's target row actually
            -- resolved; a stale/unresolved override must fall back to the source value instead
            -- of silently reusing whatever a prior loop iteration left in these variables.
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @ET_RowStatus = @ET_Target_RowStatus;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @Name = @ET_Target_Name;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'IsReadOnlyOffline') SET @ET_IsReadOnlyOffline = @ET_Target_IsReadOnlyOffline;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'IsRequiredSystemData') SET @ET_IsRequiredSystemData = @ET_Target_IsRequiredSystemData;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'HasDocuments') SET @ET_HasDocuments = @ET_Target_HasDocuments;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'DoNotTrackChanges') SET @ET_DoNotTrackChanges = @ET_Target_DoNotTrackChanges;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'IsRootEntity') SET @ET_IsRootEntity = @ET_Target_IsRootEntity;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'DetailPageUrl') SET @ET_DetailPageUrl = @ET_Target_DetailPageUrl;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'IsMetaData') SET @ET_IsMetaData = @ET_Target_IsMetaData;
            IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'IsDeletable') SET @ET_IsDeletable = @ET_Target_IsDeletable;
        END;

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
            @ET_IsDeletable,
            @ET_OverrideTargetGuid,
            @ET_ColumnSourceSelectionJson;
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
        @EH_EntityTypeGuid UNIQUEIDENTIFIER,
        @EH_OverrideTargetGuid UNIQUEIDENTIFIER,
        @EH_ColumnSourceSelectionJson NVARCHAR(MAX),
        @EH_Target_RowStatus TINYINT,
        @EH_Target_SchemaName NVARCHAR(250),
        @EH_Target_ObjectName NVARCHAR(250),
        @EH_Target_ObjectType NVARCHAR(1),
        @EH_Target_IsMainHoBT BIT,
        @EH_Target_IsReadOnlyOffline BIT,
        @EH_TargetRowFound BIT;

    DECLARE EntityHobts_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectType'), N'T'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMainHoBT')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline')),
            ov.TargetRowGuid,
            ov.ColumnSourceSelectionJson
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
            ON ov.DatabaseName = @TargetDatabaseName
           AND ov.RegistryGuid = sr.RegistryGuid
           AND ov.SourceRowGuid = sr.SourceRowGuid
           AND ov.RowStatus NOT IN (0,254)
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
        @EH_IsReadOnlyOffline,
        @EH_OverrideTargetGuid,
        @EH_ColumnSourceSelectionJson;

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

        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        DECLARE @EntityHoBTGuidToApply UNIQUEIDENTIFIER = ISNULL(@EH_OverrideTargetGuid, @Guid);

        IF @EH_OverrideTargetGuid IS NOT NULL AND @EH_ColumnSourceSelectionJson IS NOT NULL
        BEGIN
            SET @EH_TargetRowFound = 0;
            SET @EH_Target_RowStatus = NULL;
            SET @EH_Target_SchemaName = NULL;
            SET @EH_Target_ObjectName = NULL;
            SET @EH_Target_ObjectType = NULL;
            SET @EH_Target_IsMainHoBT = NULL;
            SET @EH_Target_IsReadOnlyOffline = NULL;

            SELECT
                @EH_Target_RowStatus = targetrow.RowStatus,
                @EH_Target_SchemaName = targetrow.SchemaName,
                @EH_Target_ObjectName = targetrow.ObjectName,
                @EH_Target_ObjectType = targetrow.ObjectType,
                @EH_Target_IsMainHoBT = targetrow.IsMainHoBT,
                @EH_Target_IsReadOnlyOffline = targetrow.IsReadOnlyOffline
            FROM SCore.EntityHobts AS targetrow
            WHERE targetrow.Guid = @EH_OverrideTargetGuid;

            IF @@ROWCOUNT > 0 SET @EH_TargetRowFound = 1;

            -- Only trust the "keep target value" merge when the override's target row actually
            -- resolved; a stale/unresolved override must fall back to the source value instead
            -- of silently reusing whatever a prior loop iteration left in these variables.
            IF @EH_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EH_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @EH_RowStatus = @EH_Target_RowStatus;
            IF @EH_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EH_ColumnSourceSelectionJson) WHERE [value] = N'SchemaName') SET @EH_SchemaName = @EH_Target_SchemaName;
            IF @EH_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EH_ColumnSourceSelectionJson) WHERE [value] = N'ObjectName') SET @EH_ObjectName = @EH_Target_ObjectName;
            IF @EH_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EH_ColumnSourceSelectionJson) WHERE [value] = N'ObjectType') SET @EH_ObjectType = @EH_Target_ObjectType;
            IF @EH_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EH_ColumnSourceSelectionJson) WHERE [value] = N'IsMainHoBT') SET @EH_IsMainHoBT = @EH_Target_IsMainHoBT;
            IF @EH_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EH_ColumnSourceSelectionJson) WHERE [value] = N'IsReadOnlyOffline') SET @EH_IsReadOnlyOffline = @EH_Target_IsReadOnlyOffline;
        END;

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
            @EH_IsReadOnlyOffline,
            @EH_OverrideTargetGuid,
            @EH_ColumnSourceSelectionJson;
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
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER,
    @DDL_OverrideTargetGuid UNIQUEIDENTIFIER,
    @DDL_ColumnSourceSelectionJson NVARCHAR(MAX),
    @DDL_Target_Code NVARCHAR(20),
    @DDL_Target_NameColumn NVARCHAR(254),
    @DDL_Target_ValueColumn NVARCHAR(254),
    @DDL_Target_SqlQuery NVARCHAR(MAX),
    @DDL_Target_DefaultSortColumnName NVARCHAR(254),
    @DDL_Target_IsDefaultColumn BIT,
    @DDL_Target_IsDetailWindowed BIT,
    @DDL_Target_DetailPageUrl NVARCHAR(250),
    @DDL_Target_InformationPageUrl NVARCHAR(250),
    @DDL_Target_GroupColumn NVARCHAR(254),
    @DDL_Target_ColourHexColumn NVARCHAR(7),
    @DDL_Target_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_TargetRowFound BIT;

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
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl'),
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
    @DDL_ExternalSearchPageUrl,
    @DDL_OverrideTargetGuid,
    @DDL_ColumnSourceSelectionJson;

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

    -- A manual Identity Map override means "update the record I matched this to," not
    -- "insert my own Guid" - resolve to the override's target before upserting.
    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@DDL_OverrideTargetGuid, @Guid);

    IF @DDL_OverrideTargetGuid IS NOT NULL AND @DDL_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @DDL_TargetRowFound = 0;
        SET @DDL_Target_Code = NULL;
        SET @DDL_Target_NameColumn = NULL;
        SET @DDL_Target_ValueColumn = NULL;
        SET @DDL_Target_SqlQuery = NULL;
        SET @DDL_Target_DefaultSortColumnName = NULL;
        SET @DDL_Target_IsDefaultColumn = NULL;
        SET @DDL_Target_IsDetailWindowed = NULL;
        SET @DDL_Target_DetailPageUrl = NULL;
        SET @DDL_Target_InformationPageUrl = NULL;
        SET @DDL_Target_GroupColumn = NULL;
        SET @DDL_Target_ColourHexColumn = NULL;
        SET @DDL_Target_ExternalSearchPageUrl = NULL;

        SELECT
            @DDL_Target_Code = targetrow.Code,
            @DDL_Target_NameColumn = targetrow.NameColumn,
            @DDL_Target_ValueColumn = targetrow.ValueColumn,
            @DDL_Target_SqlQuery = targetrow.SqlQuery,
            @DDL_Target_DefaultSortColumnName = targetrow.DefaultSortColumnName,
            @DDL_Target_IsDefaultColumn = TRY_CONVERT(BIT, targetrow.IsDefaultColumn),
            @DDL_Target_IsDetailWindowed = targetrow.IsDetailWindowed,
            @DDL_Target_DetailPageUrl = targetrow.DetailPageUrl,
            @DDL_Target_InformationPageUrl = targetrow.InformationPageUrl,
            @DDL_Target_GroupColumn = targetrow.GroupColumn,
            @DDL_Target_ColourHexColumn = targetrow.ColourHexColumn,
            @DDL_Target_ExternalSearchPageUrl = targetrow.ExternalSearchPageUrl
        FROM SUserInterface.DropDownListDefinitions AS targetrow
        WHERE targetrow.Guid = @DDL_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @DDL_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'Code') SET @DDL_Code = @DDL_Target_Code;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'NameColumn') SET @DDL_NameColumn = @DDL_Target_NameColumn;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'ValueColumn') SET @DDL_ValueColumn = @DDL_Target_ValueColumn;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'SqlQuery') SET @DDL_SqlQuery = @DDL_Target_SqlQuery;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'DefaultSortColumnName') SET @DDL_DefaultSortColumnName = @DDL_Target_DefaultSortColumnName;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultColumn') SET @DDL_IsDefaultColumn = @DDL_Target_IsDefaultColumn;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'IsDetailWindowed') SET @DDL_IsDetailWindowed = @DDL_Target_IsDetailWindowed;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'DetailPageUrl') SET @DDL_DetailPageURI = @DDL_Target_DetailPageUrl;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'InformationPageUrl') SET @DDL_InformationPageURI = @DDL_Target_InformationPageUrl;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'GroupColumn') SET @DDL_GroupColumn = @DDL_Target_GroupColumn;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'ColourHexColumn') SET @DDL_ColourHexColumn = @DDL_Target_ColourHexColumn;
        IF @DDL_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@DDL_ColumnSourceSelectionJson) WHERE [value] = N'ExternalSearchPageUrl') SET @DDL_ExternalSearchPageUrl = @DDL_Target_ExternalSearchPageUrl;
    END;

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
        @DDL_ExternalSearchPageUrl,
        @DDL_OverrideTargetGuid,
        @DDL_ColumnSourceSelectionJson;
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
        @EPG_PropertyGroupLayoutGuid UNIQUEIDENTIFIER,
        @EPG_OverrideTargetGuid UNIQUEIDENTIFIER,
        @EPG_ColumnSourceSelectionJson NVARCHAR(MAX),
        @EPG_Target_RowStatus TINYINT,
        @EPG_Target_Name NVARCHAR(250),
        @EPG_Target_IsHidden BIT,
        @EPG_Target_SortOrder INT,
        @EPG_Target_ShowOnMobile BIT,
        @EPG_Target_IsCollapsable BIT,
        @EPG_Target_IsDefaultCollapsed BIT,
        @EPG_Target_IsDefaultCollapsed_Mobile BIT,
        @EPG_TargetRowFound BIT;

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
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed_Mobile')),
            ov.TargetRowGuid,
            ov.ColumnSourceSelectionJson
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
            ON ov.DatabaseName = @TargetDatabaseName
           AND ov.RegistryGuid = sr.RegistryGuid
           AND ov.SourceRowGuid = sr.SourceRowGuid
           AND ov.RowStatus NOT IN (0,254)
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
        @EPG_IsDefaultCollapsed_Mobile,
        @EPG_OverrideTargetGuid,
        @EPG_ColumnSourceSelectionJson;

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

        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        DECLARE @EntityPropertyGroupGuid UNIQUEIDENTIFIER = ISNULL(@EPG_OverrideTargetGuid, @Guid);

        IF @EPG_OverrideTargetGuid IS NOT NULL AND @EPG_ColumnSourceSelectionJson IS NOT NULL
        BEGIN
            SET @EPG_TargetRowFound = 0;
            SET @EPG_Target_RowStatus = NULL;
            SET @EPG_Target_Name = NULL;
            SET @EPG_Target_IsHidden = NULL;
            SET @EPG_Target_SortOrder = NULL;
            SET @EPG_Target_ShowOnMobile = NULL;
            SET @EPG_Target_IsCollapsable = NULL;
            SET @EPG_Target_IsDefaultCollapsed = NULL;
            SET @EPG_Target_IsDefaultCollapsed_Mobile = NULL;

            SELECT
                @EPG_Target_RowStatus = targetrow.RowStatus,
                @EPG_Target_Name = targetrow.Name,
                @EPG_Target_IsHidden = targetrow.IsHidden,
                @EPG_Target_SortOrder = targetrow.SortOrder,
                @EPG_Target_ShowOnMobile = targetrow.ShowOnMobile,
                @EPG_Target_IsCollapsable = targetrow.IsCollapsable,
                @EPG_Target_IsDefaultCollapsed = targetrow.IsDefaultCollapsed,
                @EPG_Target_IsDefaultCollapsed_Mobile = targetrow.IsDefaultCollapsed_Mobile
            FROM SCore.EntityPropertyGroups AS targetrow
            WHERE targetrow.Guid = @EPG_OverrideTargetGuid;

            IF @@ROWCOUNT > 0 SET @EPG_TargetRowFound = 1;

            -- Only trust the "keep target value" merge when the override's target row actually
            -- resolved; a stale/unresolved override must fall back to the source value instead
            -- of silently reusing whatever a prior loop iteration left in these variables.
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @EPG_RowStatus = @EPG_Target_RowStatus;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @EPG_Name = @EPG_Target_Name;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'IsHidden') SET @EPG_IsHidden = @EPG_Target_IsHidden;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'SortOrder') SET @EPG_SortOrder = @EPG_Target_SortOrder;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'ShowOnMobile') SET @EPG_ShowOnMobile = @EPG_Target_ShowOnMobile;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'IsCollapsable') SET @EPG_IsCollapsable = @EPG_Target_IsCollapsable;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultCollapsed') SET @EPG_IsDefaultCollapsed = @EPG_Target_IsDefaultCollapsed;
            IF @EPG_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EPG_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultCollapsed_Mobile') SET @EPG_IsDefaultCollapsed_Mobile = @EPG_Target_IsDefaultCollapsed_Mobile;
        END;

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
            @EPG_IsDefaultCollapsed_Mobile,
            @EPG_OverrideTargetGuid,
            @EPG_ColumnSourceSelectionJson;
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
    @EP_IsAlwaysVisibleInGroup_Mobile BIT,
    @EP_OverrideTargetGuid UNIQUEIDENTIFIER,
    @EP_ColumnSourceSelectionJson NVARCHAR(MAX),
    @EP_Target_RowStatus TINYINT,
    @EP_Target_Name NVARCHAR(500),
    @EP_Target_IsReadOnly BIT,
    @EP_Target_IsImmutable BIT,
    @EP_Target_IsUppercase BIT,
    @EP_Target_IsHidden BIT,
    @EP_Target_IsCompulsory BIT,
    @EP_Target_MaxLength INT,
    @EP_Target_Precision INT,
    @EP_Target_Scale INT,
    @EP_Target_DoNotTrackChanges BIT,
    @EP_Target_SortOrder SMALLINT,
    @EP_Target_GroupSortOrder SMALLINT,
    @EP_Target_IsObjectLabel BIT,
    @EP_Target_IsParentRelationship BIT,
    @EP_Target_IsIncludedInformation BIT,
    @EP_Target_IsLatitude BIT,
    @EP_Target_IsLongitude BIT,
    @EP_Target_FixedDefaultValue NVARCHAR(50),
    @EP_Target_SqlDefaultValueStatement NVARCHAR(4000),
    @EP_Target_AllowBulkChange BIT,
    @EP_Target_IsVirtual BIT,
    @EP_Target_ShowOnMobile BIT,
    @EP_Target_IsAlwaysVisibleInGroup BIT,
    @EP_Target_IsAlwaysVisibleInGroup_Mobile BIT,
    @EP_TargetRowFound BIT;

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
    SourceRowId BIGINT NULL,
    OverrideTargetGuid UNIQUEIDENTIFIER NULL,
    ColumnSourceSelectionJson NVARCHAR(MAX) NULL
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
    sr.SourceRowId,
    ov.TargetRowGuid,
    ov.ColumnSourceSelectionJson
FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
    ON ov.DatabaseName = @TargetDatabaseName
   AND ov.RegistryGuid = sr.RegistryGuid
   AND ov.SourceRowGuid = sr.SourceRowGuid
   AND ov.RowStatus NOT IN (0,254)
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
        SourceRowId,
        OverrideTargetGuid,
        ColumnSourceSelectionJson
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
    @EP_SourceRowId,
    @EP_OverrideTargetGuid,
    @EP_ColumnSourceSelectionJson;

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

    -- A manual Identity Map override is an explicit, reviewed operator decision and wins over
    -- the natural-key (EntityHoBT+Name) match below.
    IF @EP_OverrideTargetGuid IS NULL
    BEGIN
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
    END;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = ISNULL(@EP_OverrideTargetGuid, ISNULL(@ExistingEntityPropertyGuid, @Guid));

    IF @ExistingEntityPropertyGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingEntityPropertyGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityProperties'
          AND lookup.SourceRowId = @EP_SourceRowId;
    END;

    IF @EP_OverrideTargetGuid IS NOT NULL AND @EP_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @EP_TargetRowFound = 0;
        SET @EP_Target_RowStatus = NULL;
        SET @EP_Target_Name = NULL;
        SET @EP_Target_IsReadOnly = NULL;
        SET @EP_Target_IsImmutable = NULL;
        SET @EP_Target_IsUppercase = NULL;
        SET @EP_Target_IsHidden = NULL;
        SET @EP_Target_IsCompulsory = NULL;
        SET @EP_Target_MaxLength = NULL;
        SET @EP_Target_Precision = NULL;
        SET @EP_Target_Scale = NULL;
        SET @EP_Target_DoNotTrackChanges = NULL;
        SET @EP_Target_SortOrder = NULL;
        SET @EP_Target_GroupSortOrder = NULL;
        SET @EP_Target_IsObjectLabel = NULL;
        SET @EP_Target_IsParentRelationship = NULL;
        SET @EP_Target_IsIncludedInformation = NULL;
        SET @EP_Target_IsLatitude = NULL;
        SET @EP_Target_IsLongitude = NULL;
        SET @EP_Target_FixedDefaultValue = NULL;
        SET @EP_Target_SqlDefaultValueStatement = NULL;
        SET @EP_Target_AllowBulkChange = NULL;
        SET @EP_Target_IsVirtual = NULL;
        SET @EP_Target_ShowOnMobile = NULL;
        SET @EP_Target_IsAlwaysVisibleInGroup = NULL;
        SET @EP_Target_IsAlwaysVisibleInGroup_Mobile = NULL;

        SELECT
            @EP_Target_RowStatus = targetrow.RowStatus,
            @EP_Target_Name = targetrow.Name,
            @EP_Target_IsReadOnly = targetrow.IsReadOnly,
            @EP_Target_IsImmutable = targetrow.IsImmutable,
            @EP_Target_IsUppercase = targetrow.IsUppercase,
            @EP_Target_IsHidden = targetrow.IsHidden,
            @EP_Target_IsCompulsory = targetrow.IsCompulsory,
            @EP_Target_MaxLength = targetrow.MaxLength,
            @EP_Target_Precision = targetrow.Precision,
            @EP_Target_Scale = targetrow.Scale,
            @EP_Target_DoNotTrackChanges = targetrow.DoNotTrackChanges,
            @EP_Target_SortOrder = targetrow.SortOrder,
            @EP_Target_GroupSortOrder = targetrow.GroupSortOrder,
            @EP_Target_IsObjectLabel = targetrow.IsObjectLabel,
            @EP_Target_IsParentRelationship = targetrow.IsParentRelationship,
            @EP_Target_IsIncludedInformation = targetrow.IsIncludedInformation,
            @EP_Target_IsLatitude = targetrow.IsLatitude,
            @EP_Target_IsLongitude = targetrow.IsLongitude,
            @EP_Target_FixedDefaultValue = targetrow.FixedDefaultValue,
            @EP_Target_SqlDefaultValueStatement = targetrow.SqlDefaultValueStatement,
            @EP_Target_AllowBulkChange = targetrow.AllowBulkChange,
            @EP_Target_IsVirtual = targetrow.IsVirtual,
            @EP_Target_ShowOnMobile = targetrow.ShowOnMobile,
            @EP_Target_IsAlwaysVisibleInGroup = targetrow.IsAlwaysVisibleInGroup,
            @EP_Target_IsAlwaysVisibleInGroup_Mobile = targetrow.IsAlwaysVisibleInGroup_Mobile
        FROM SCore.EntityProperties AS targetrow
        WHERE targetrow.Guid = @EP_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @EP_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @EP_RowStatus = @EP_Target_RowStatus;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @EP_Name = @EP_Target_Name;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsReadOnly') SET @EP_IsReadOnly = @EP_Target_IsReadOnly;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsImmutable') SET @EP_IsImmutable = @EP_Target_IsImmutable;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsUppercase') SET @EP_IsUppercase = @EP_Target_IsUppercase;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsHidden') SET @EP_IsHidden = @EP_Target_IsHidden;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsCompulsory') SET @EP_IsCompulsory = @EP_Target_IsCompulsory;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'MaxLength') SET @EP_MaxLength = @EP_Target_MaxLength;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'Precision') SET @EP_Precision = @EP_Target_Precision;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'Scale') SET @EP_Scale = @EP_Target_Scale;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'DoNotTrackChanges') SET @EP_DoNotTrackChanges = @EP_Target_DoNotTrackChanges;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'SortOrder') SET @EP_SortOrder = @EP_Target_SortOrder;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'GroupSortOrder') SET @EP_GroupSortOrder = @EP_Target_GroupSortOrder;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsObjectLabel') SET @EP_IsObjectLabel = @EP_Target_IsObjectLabel;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsParentRelationship') SET @EP_IsParentRelationship = @EP_Target_IsParentRelationship;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsIncludedInformation') SET @EP_IsIncludedInformation = @EP_Target_IsIncludedInformation;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsLatitude') SET @EP_IsLatitude = @EP_Target_IsLatitude;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsLongitude') SET @EP_IsLongitude = @EP_Target_IsLongitude;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'FixedDefaultValue') SET @EP_FixDefaultValue = @EP_Target_FixedDefaultValue;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'SqlDefaultValueStatement') SET @EP_SqlDefaultValueStatement = @EP_Target_SqlDefaultValueStatement;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'AllowBulkChange') SET @EP_AllowBulkChange = @EP_Target_AllowBulkChange;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsVirtual') SET @EP_IsVirtual = @EP_Target_IsVirtual;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'ShowOnMobile') SET @EP_ShowOnMobile = @EP_Target_ShowOnMobile;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsAlwaysVisibleInGroup') SET @EP_IsAlwaysVisibleInGroup = @EP_Target_IsAlwaysVisibleInGroup;
        IF @EP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EP_ColumnSourceSelectionJson) WHERE [value] = N'IsAlwaysVisibleInGroup_Mobile') SET @EP_IsAlwaysVisibleInGroup_Mobile = @EP_Target_IsAlwaysVisibleInGroup_Mobile;
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
        @EP_SourceRowId,
        @EP_OverrideTargetGuid,
        @EP_ColumnSourceSelectionJson;
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
        @SourceEntityHoBTId BIGINT,
        @EQ_OverrideTargetGuid UNIQUEIDENTIFIER,
        @EQ_ColumnSourceSelectionJson NVARCHAR(MAX),
        @EQ_Target_RowStatus TINYINT,
        @EQ_Target_Name NVARCHAR(500),
        @EQ_Target_Statement NVARCHAR(MAX),
        @EQ_Target_IsDefaultCreate BIT,
        @EQ_Target_IsDefaultRead BIT,
        @EQ_Target_IsDefaultUpdate BIT,
        @EQ_Target_IsDefaultDelete BIT,
        @EQ_Target_IsScalarExecute BIT,
        @EQ_Target_IsDefaultValidation BIT,
        @EQ_Target_IsDefaultDataPills BIT,
        @EQ_Target_IsMergeDocumentQuery BIT,
        @EQ_Target_IsProgressData BIT,
        @EQ_Target_SchemaName NVARCHAR(255),
        @EQ_Target_ObjectName NVARCHAR(255),
        @EQ_Target_IsManualStatement BIT,
        @EQ_TargetRowFound BIT;

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
        SourceRowId BIGINT NULL,
        OverrideTargetGuid UNIQUEIDENTIFIER NULL,
        ColumnSourceSelectionJson NVARCHAR(MAX) NULL
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
        sr.SourceRowId,
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
            IsManualStatement,
            OverrideTargetGuid,
            ColumnSourceSelectionJson
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
        @IsManualStatement,
        @EQ_OverrideTargetGuid,
        @EQ_ColumnSourceSelectionJson;

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

        -- A manual Identity Map override means "update the record I matched this to," not
        -- "insert my own Guid" - resolve to the override's target before upserting.
        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = ISNULL(@EQ_OverrideTargetGuid, @Guid);

        IF @EQ_OverrideTargetGuid IS NOT NULL AND @EQ_ColumnSourceSelectionJson IS NOT NULL
        BEGIN
            SET @EQ_TargetRowFound = 0;
            SET @EQ_Target_RowStatus = NULL;
            SET @EQ_Target_Name = NULL;
            SET @EQ_Target_Statement = NULL;
            SET @EQ_Target_IsDefaultCreate = NULL;
            SET @EQ_Target_IsDefaultRead = NULL;
            SET @EQ_Target_IsDefaultUpdate = NULL;
            SET @EQ_Target_IsDefaultDelete = NULL;
            SET @EQ_Target_IsScalarExecute = NULL;
            SET @EQ_Target_IsDefaultValidation = NULL;
            SET @EQ_Target_IsDefaultDataPills = NULL;
            SET @EQ_Target_IsMergeDocumentQuery = NULL;
            SET @EQ_Target_IsProgressData = NULL;
            SET @EQ_Target_SchemaName = NULL;
            SET @EQ_Target_ObjectName = NULL;
            SET @EQ_Target_IsManualStatement = NULL;

            SELECT
                @EQ_Target_RowStatus = targetrow.RowStatus,
                @EQ_Target_Name = targetrow.Name,
                @EQ_Target_Statement = targetrow.Statement,
                @EQ_Target_IsDefaultCreate = targetrow.IsDefaultCreate,
                @EQ_Target_IsDefaultRead = targetrow.IsDefaultRead,
                @EQ_Target_IsDefaultUpdate = targetrow.IsDefaultUpdate,
                @EQ_Target_IsDefaultDelete = targetrow.IsDefaultDelete,
                @EQ_Target_IsScalarExecute = targetrow.IsScalarExecute,
                @EQ_Target_IsDefaultValidation = targetrow.IsDefaultValidation,
                @EQ_Target_IsDefaultDataPills = targetrow.IsDefaultDataPills,
                @EQ_Target_IsMergeDocumentQuery = targetrow.IsMergeDocumentQuery,
                @EQ_Target_IsProgressData = targetrow.IsProgressData,
                @EQ_Target_SchemaName = targetrow.SchemaName,
                @EQ_Target_ObjectName = targetrow.ObjectName,
                @EQ_Target_IsManualStatement = targetrow.IsManualStatement
            FROM SCore.EntityQueries AS targetrow
            WHERE targetrow.Guid = @EQ_OverrideTargetGuid;

            IF @@ROWCOUNT > 0 SET @EQ_TargetRowFound = 1;

            -- Only trust the "keep target value" merge when the override's target row actually
            -- resolved; a stale/unresolved override must fall back to the source value instead
            -- of silently reusing whatever a prior loop iteration left in these variables.
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @RowStatus = @EQ_Target_RowStatus;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @Name = @EQ_Target_Name;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'Statement') SET @Statement = @EQ_Target_Statement;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultCreate') SET @IsDefaultCreate = @EQ_Target_IsDefaultCreate;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultRead') SET @IsDefaultRead = @EQ_Target_IsDefaultRead;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultUpdate') SET @IsDefaultUpdate = @EQ_Target_IsDefaultUpdate;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultDelete') SET @IsDefaultDelete = @EQ_Target_IsDefaultDelete;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsScalarExecute') SET @IsScalarExecute = @EQ_Target_IsScalarExecute;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultValidation') SET @IsDefaultValidation = @EQ_Target_IsDefaultValidation;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultDataPills') SET @IsDefaultDataPills = @EQ_Target_IsDefaultDataPills;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsMergeDocumentQuery') SET @IsMergeDocumentQuery = @EQ_Target_IsMergeDocumentQuery;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsProgressData') SET @IsProgressData = @EQ_Target_IsProgressData;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'SchemaName') SET @SchemaName = @EQ_Target_SchemaName;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'ObjectName') SET @ObjectName = @EQ_Target_ObjectName;
            IF @EQ_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQ_ColumnSourceSelectionJson) WHERE [value] = N'IsManualStatement') SET @IsManualStatement = @EQ_Target_IsManualStatement;
        END;

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
            @IsManualStatement,
            @EQ_OverrideTargetGuid,
            @EQ_ColumnSourceSelectionJson;
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
    @EQP_IsReturnColumn BIT,
    @EQP_OverrideTargetGuid UNIQUEIDENTIFIER,
    @EQP_ColumnSourceSelectionJson NVARCHAR(MAX),
    @EQP_Target_RowStatus TINYINT,
    @EQP_Target_Name NVARCHAR(500),
    @EQP_Target_DefaultValue NVARCHAR(200),
    @EQP_Target_IsInput BIT,
    @EQP_Target_IsOutput BIT,
    @EQP_Target_IsReturnColumn BIT,
    @EQP_TargetRowFound BIT;

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
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn')),
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
    @EQP_IsReturnColumn,
    @EQP_OverrideTargetGuid,
    @EQP_ColumnSourceSelectionJson;

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

    -- A manual Identity Map override means "update the record I matched this to," not
    -- "insert my own Guid" - resolve to the override's target before upserting.
    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = ISNULL(@EQP_OverrideTargetGuid, @Guid);

    IF @EQP_OverrideTargetGuid IS NOT NULL AND @EQP_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @EQP_TargetRowFound = 0;
        SET @EQP_Target_RowStatus = NULL;
        SET @EQP_Target_Name = NULL;
        SET @EQP_Target_DefaultValue = NULL;
        SET @EQP_Target_IsInput = NULL;
        SET @EQP_Target_IsOutput = NULL;
        SET @EQP_Target_IsReturnColumn = NULL;

        SELECT
            @EQP_Target_RowStatus = targetrow.RowStatus,
            @EQP_Target_Name = targetrow.Name,
            @EQP_Target_DefaultValue = targetrow.DefaultValue,
            @EQP_Target_IsInput = targetrow.IsInput,
            @EQP_Target_IsOutput = targetrow.IsOutput,
            @EQP_Target_IsReturnColumn = targetrow.IsReturnColumn
        FROM SCore.EntityQueryParameters AS targetrow
        WHERE targetrow.Guid = @EQP_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @EQP_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.
        IF @EQP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQP_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @EQP_RowStatus = @EQP_Target_RowStatus;
        IF @EQP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQP_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @EQP_Name = @EQP_Target_Name;
        IF @EQP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQP_ColumnSourceSelectionJson) WHERE [value] = N'DefaultValue') SET @EQP_DefaultValue = @EQP_Target_DefaultValue;
        IF @EQP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQP_ColumnSourceSelectionJson) WHERE [value] = N'IsInput') SET @EQP_IsInput = @EQP_Target_IsInput;
        IF @EQP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQP_ColumnSourceSelectionJson) WHERE [value] = N'IsOutput') SET @EQP_IsOutput = @EQP_Target_IsOutput;
        IF @EQP_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@EQP_ColumnSourceSelectionJson) WHERE [value] = N'IsReturnColumn') SET @EQP_IsReturnColumn = @EQP_Target_IsReturnColumn;
    END;

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
        @EQP_IsReturnColumn,
        @EQP_OverrideTargetGuid,
        @EQP_ColumnSourceSelectionJson;
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
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GD_OverrideTargetGuid UNIQUEIDENTIFIER,
    @GD_ColumnSourceSelectionJson NVARCHAR(MAX),
    @GD_Target_RowStatus TINYINT,
    @GD_Target_Code NVARCHAR(30),
    @GD_Target_TabName NVARCHAR(250),
    @GD_Target_ShowAsTiles BIT,
    @GD_Target_PageUri NVARCHAR(250),
    @GD_TargetRowFound BIT;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
    @GD_SourceLanguageLabelID,
    @GD_OverrideTargetGuid,
    @GD_ColumnSourceSelectionJson;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;
    SELECT
        @GD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GD_SourceLanguageLabelID;

    -- A manual Identity Map override means "update the record I matched this to," not
    -- "insert my own Guid" - resolve to the override's target before upserting.
    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@GD_OverrideTargetGuid, @Guid);

    IF @GD_OverrideTargetGuid IS NOT NULL AND @GD_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @GD_TargetRowFound = 0;
        SET @GD_Target_RowStatus = NULL;
        SET @GD_Target_Code = NULL;
        SET @GD_Target_TabName = NULL;
        SET @GD_Target_ShowAsTiles = NULL;
        SET @GD_Target_PageUri = NULL;

        SELECT
            @GD_Target_RowStatus = targetrow.RowStatus,
            @GD_Target_Code = targetrow.Code,
            @GD_Target_TabName = targetrow.TabName,
            @GD_Target_ShowAsTiles = targetrow.ShowAsTiles,
            @GD_Target_PageUri = targetrow.PageUri
        FROM SUserInterface.GridDefinitions AS targetrow
        WHERE targetrow.Guid = @GD_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @GD_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.
        IF @GD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GD_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @GD_RowStatus = @GD_Target_RowStatus;
        IF @GD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GD_ColumnSourceSelectionJson) WHERE [value] = N'Code') SET @GD_Code = @GD_Target_Code;
        IF @GD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GD_ColumnSourceSelectionJson) WHERE [value] = N'TabName') SET @GD_TabName = @GD_Target_TabName;
        IF @GD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GD_ColumnSourceSelectionJson) WHERE [value] = N'ShowAsTiles') SET @GD_ShowAsTiles = @GD_Target_ShowAsTiles;
        IF @GD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GD_ColumnSourceSelectionJson) WHERE [value] = N'PageUri') SET @GD_PageUri = @GD_Target_PageUri;
    END;

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
        @GD_SourceLanguageLabelID,
        @GD_OverrideTargetGuid,
        @GD_ColumnSourceSelectionJson;
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
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER,
    @GVD_OverrideTargetGuid UNIQUEIDENTIFIER,
    @GVD_ColumnSourceSelectionJson NVARCHAR(MAX),
    @GVD_Target_RowStatus TINYINT,
    @GVD_Target_Code NVARCHAR(20),
    @GVD_Target_DetailPageUri NVARCHAR(250),
    @GVD_Target_SqlQuery NVARCHAR(MAX),
    @GVD_Target_DefaultSortColumnName NVARCHAR(250),
    @GVD_Target_SecurableCode NVARCHAR(20),
    @GVD_Target_DisplayOrder INT,
    @GVD_Target_DisplayGroupName NVARCHAR(50),
    @GVD_Target_MetricSqlQuery NVARCHAR(MAX),
    @GVD_Target_ShowMetric BIT,
    @GVD_Target_IsDetailWindowed BIT,
    @GVD_Target_MetricMin INT,
    @GVD_Target_MetricMax INT,
    @GVD_Target_MetricMinorUnit INT,
    @GVD_Target_MetricMajorUnit INT,
    @GVD_Target_MetricStartAngle INT,
    @GVD_Target_MetricEndAngle INT,
    @GVD_Target_MetricReversed BIT,
    @GVD_Target_MetricRange1Min DECIMAL(18,0),
    @GVD_Target_MetricRange1Max DECIMAL(18,0),
    @GVD_Target_MetricRange1ColourHex NVARCHAR(10),
    @GVD_Target_MetricRange2Min DECIMAL(18,0),
    @GVD_Target_MetricRange2Max DECIMAL(18,0),
    @GVD_Target_MetricRange2ColourHex NVARCHAR(10),
    @GVD_Target_IsDefaultSortDescending BIT,
    @GVD_Target_ShowOnMobile BIT,
    @GVD_Target_AllowNew BIT,
    @GVD_Target_AllowExcelExport BIT,
    @GVD_Target_AllowPdfExport BIT,
    @GVD_Target_AllowCsvExport BIT,
    @GVD_Target_AllowBulkChange BIT,
    @GVD_Target_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_Target_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_Target_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_Target_TreeListOrderBy NVARCHAR(100),
    @GVD_Target_TreeListGroupBy NVARCHAR(100),
    @GVD_Target_ShowOnDashboard BIT,
    @GVD_Target_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_Target_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_Target_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_Target_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_Target_FilteredListGroupBy NVARCHAR(100),
    @GVD_Target_IsHidden BIT,
    @GVD_TargetRowFound BIT;

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
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
    @GVD_IsHidden,
    @GVD_OverrideTargetGuid,
    @GVD_ColumnSourceSelectionJson;

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

    -- A manual Identity Map override means "update the record I matched this to," not
    -- "insert my own Guid" - resolve to the override's target before upserting.
    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@GVD_OverrideTargetGuid, @Guid);

    IF @GVD_OverrideTargetGuid IS NOT NULL AND @GVD_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @GVD_TargetRowFound = 0;
        SET @GVD_Target_RowStatus = NULL;
        SET @GVD_Target_Code = NULL;
        SET @GVD_Target_DetailPageUri = NULL;
        SET @GVD_Target_SqlQuery = NULL;
        SET @GVD_Target_DefaultSortColumnName = NULL;
        SET @GVD_Target_SecurableCode = NULL;
        SET @GVD_Target_DisplayOrder = NULL;
        SET @GVD_Target_DisplayGroupName = NULL;
        SET @GVD_Target_MetricSqlQuery = NULL;
        SET @GVD_Target_ShowMetric = NULL;
        SET @GVD_Target_IsDetailWindowed = NULL;
        SET @GVD_Target_MetricMin = NULL;
        SET @GVD_Target_MetricMax = NULL;
        SET @GVD_Target_MetricMinorUnit = NULL;
        SET @GVD_Target_MetricMajorUnit = NULL;
        SET @GVD_Target_MetricStartAngle = NULL;
        SET @GVD_Target_MetricEndAngle = NULL;
        SET @GVD_Target_MetricReversed = NULL;
        SET @GVD_Target_MetricRange1Min = NULL;
        SET @GVD_Target_MetricRange1Max = NULL;
        SET @GVD_Target_MetricRange1ColourHex = NULL;
        SET @GVD_Target_MetricRange2Min = NULL;
        SET @GVD_Target_MetricRange2Max = NULL;
        SET @GVD_Target_MetricRange2ColourHex = NULL;
        SET @GVD_Target_IsDefaultSortDescending = NULL;
        SET @GVD_Target_ShowOnMobile = NULL;
        SET @GVD_Target_AllowNew = NULL;
        SET @GVD_Target_AllowExcelExport = NULL;
        SET @GVD_Target_AllowPdfExport = NULL;
        SET @GVD_Target_AllowCsvExport = NULL;
        SET @GVD_Target_AllowBulkChange = NULL;
        SET @GVD_Target_TreeListFirstOrderBy = NULL;
        SET @GVD_Target_TreeListSecondOrderBy = NULL;
        SET @GVD_Target_TreeListThirdOrderBy = NULL;
        SET @GVD_Target_TreeListOrderBy = NULL;
        SET @GVD_Target_TreeListGroupBy = NULL;
        SET @GVD_Target_ShowOnDashboard = NULL;
        SET @GVD_Target_FilteredListCreatedOnColumn = NULL;
        SET @GVD_Target_FilteredListRedStatusIndicatorTxt = NULL;
        SET @GVD_Target_FilteredListOrangeStatusIndicatorTxt = NULL;
        SET @GVD_Target_FilteredListGreenStatusIndicatorTxt = NULL;
        SET @GVD_Target_FilteredListGroupBy = NULL;
        SET @GVD_Target_IsHidden = NULL;

        SELECT
            @GVD_Target_RowStatus = targetrow.RowStatus,
            @GVD_Target_Code = targetrow.Code,
            @GVD_Target_DetailPageUri = targetrow.DetailPageUri,
            @GVD_Target_SqlQuery = targetrow.SqlQuery,
            @GVD_Target_DefaultSortColumnName = targetrow.DefaultSortColumnName,
            @GVD_Target_SecurableCode = targetrow.SecurableCode,
            @GVD_Target_DisplayOrder = targetrow.DisplayOrder,
            @GVD_Target_DisplayGroupName = targetrow.DisplayGroupName,
            @GVD_Target_MetricSqlQuery = targetrow.MetricSqlQuery,
            @GVD_Target_ShowMetric = targetrow.ShowMetric,
            @GVD_Target_IsDetailWindowed = targetrow.IsDetailWindowed,
            @GVD_Target_MetricMin = targetrow.MetricMin,
            @GVD_Target_MetricMax = targetrow.MetricMax,
            @GVD_Target_MetricMinorUnit = targetrow.MetricMinorUnit,
            @GVD_Target_MetricMajorUnit = targetrow.MetricMajorUnit,
            @GVD_Target_MetricStartAngle = targetrow.MetricStartAngle,
            @GVD_Target_MetricEndAngle = targetrow.MetricEndAngle,
            @GVD_Target_MetricReversed = targetrow.MetricReversed,
            @GVD_Target_MetricRange1Min = targetrow.MetricRange1Min,
            @GVD_Target_MetricRange1Max = targetrow.MetricRange1Max,
            @GVD_Target_MetricRange1ColourHex = targetrow.MetricRange1ColourHex,
            @GVD_Target_MetricRange2Min = targetrow.MetricRange2Min,
            @GVD_Target_MetricRange2Max = targetrow.MetricRange2Max,
            @GVD_Target_MetricRange2ColourHex = targetrow.MetricRange2ColourHex,
            @GVD_Target_IsDefaultSortDescending = targetrow.IsDefaultSortDescending,
            @GVD_Target_ShowOnMobile = targetrow.ShowOnMobile,
            @GVD_Target_AllowNew = targetrow.AllowNew,
            @GVD_Target_AllowExcelExport = targetrow.AllowExcelExport,
            @GVD_Target_AllowPdfExport = targetrow.AllowPdfExport,
            @GVD_Target_AllowCsvExport = targetrow.AllowCsvExport,
            @GVD_Target_AllowBulkChange = targetrow.AllowBulkChange,
            @GVD_Target_TreeListFirstOrderBy = targetrow.TreeListFirstOrderBy,
            @GVD_Target_TreeListSecondOrderBy = targetrow.TreeListSecondOrderBy,
            @GVD_Target_TreeListThirdOrderBy = targetrow.TreeListThirdOrderBy,
            @GVD_Target_TreeListOrderBy = targetrow.TreeListOrderBy,
            @GVD_Target_TreeListGroupBy = targetrow.TreeListGroupBy,
            @GVD_Target_ShowOnDashboard = targetrow.ShowOnDashboard,
            @GVD_Target_FilteredListCreatedOnColumn = targetrow.FilteredListCreatedOnColumn,
            @GVD_Target_FilteredListRedStatusIndicatorTxt = targetrow.FilteredListRedStatusIndicatorTxt,
            @GVD_Target_FilteredListOrangeStatusIndicatorTxt = targetrow.FilteredListOrangeStatusIndicatorTxt,
            @GVD_Target_FilteredListGreenStatusIndicatorTxt = targetrow.FilteredListGreenStatusIndicatorTxt,
            @GVD_Target_FilteredListGroupBy = targetrow.FilteredListGroupBy,
            @GVD_Target_IsHidden = targetrow.IsHidden
        FROM SUserInterface.GridViewDefinitions AS targetrow
        WHERE targetrow.Guid = @GVD_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @GVD_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @GVD_RowStatus = @GVD_Target_RowStatus;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'Code') SET @GVD_Code = @GVD_Target_Code;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'DetailPageUri') SET @GVD_DetailPageUri = @GVD_Target_DetailPageUri;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'SqlQuery') SET @GVD_SqlQuery = @GVD_Target_SqlQuery;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'DefaultSortColumnName') SET @GVD_DefaultSortColumnName = @GVD_Target_DefaultSortColumnName;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'SecurableCode') SET @GVD_SecurableCode = @GVD_Target_SecurableCode;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'DisplayOrder') SET @GVD_DisplayOrder = @GVD_Target_DisplayOrder;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'DisplayGroupName') SET @GVD_DisplayGroupName = @GVD_Target_DisplayGroupName;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricSqlQuery') SET @GVD_MetricSqlQuery = @GVD_Target_MetricSqlQuery;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'ShowMetric') SET @GVD_ShowMetric = @GVD_Target_ShowMetric;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'IsDetailWindowed') SET @GVD_IsDetailWindowed = @GVD_Target_IsDetailWindowed;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricMin') SET @GVD_MetricMin = @GVD_Target_MetricMin;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricMax') SET @GVD_MetricMax = @GVD_Target_MetricMax;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricMinorUnit') SET @GVD_MetricMinorUnit = @GVD_Target_MetricMinorUnit;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricMajorUnit') SET @GVD_MetricMajorUnit = @GVD_Target_MetricMajorUnit;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricStartAngle') SET @GVD_MetricStartAngle = @GVD_Target_MetricStartAngle;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricEndAngle') SET @GVD_MetricEndAngle = @GVD_Target_MetricEndAngle;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricReversed') SET @GVD_MetricReversed = @GVD_Target_MetricReversed;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricRange1Min') SET @GVD_MetricRange1Min = @GVD_Target_MetricRange1Min;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricRange1Max') SET @GVD_MetricRange1Max = @GVD_Target_MetricRange1Max;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricRange1ColourHex') SET @GVD_MetricRange1ColourHex = @GVD_Target_MetricRange1ColourHex;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricRange2Min') SET @GVD_MetricRange2Min = @GVD_Target_MetricRange2Min;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricRange2Max') SET @GVD_MetricRange2Max = @GVD_Target_MetricRange2Max;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'MetricRange2ColourHex') SET @GVD_MetricRange2ColourHex = @GVD_Target_MetricRange2ColourHex;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'IsDefaultSortDescending') SET @GVD_IsDefaultSortDescending = @GVD_Target_IsDefaultSortDescending;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'ShowOnMobile') SET @GVD_ShowOnMobile = @GVD_Target_ShowOnMobile;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'AllowNew') SET @GVD_AllowNew = @GVD_Target_AllowNew;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'AllowExcelExport') SET @GVD_AllowExcelExport = @GVD_Target_AllowExcelExport;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'AllowPdfExport') SET @GVD_AllowPdfExport = @GVD_Target_AllowPdfExport;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'AllowCsvExport') SET @GVD_AllowCsvExport = @GVD_Target_AllowCsvExport;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'AllowBulkChange') SET @GVD_AllowBulkChange = @GVD_Target_AllowBulkChange;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'TreeListFirstOrderBy') SET @GVD_TreeListFirstOrderBy = @GVD_Target_TreeListFirstOrderBy;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'TreeListSecondOrderBy') SET @GVD_TreeListSecondOrderBy = @GVD_Target_TreeListSecondOrderBy;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'TreeListThirdOrderBy') SET @GVD_TreeListThirdOrderBy = @GVD_Target_TreeListThirdOrderBy;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'TreeListOrderBy') SET @GVD_TreeListOrderBy = @GVD_Target_TreeListOrderBy;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'TreeListGroupBy') SET @GVD_TreeListGroupBy = @GVD_Target_TreeListGroupBy;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'ShowOnDashboard') SET @GVD_ShowOnDashboard = @GVD_Target_ShowOnDashboard;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'FilteredListCreatedOnColumn') SET @GVD_FilteredListCreatedOnColumn = @GVD_Target_FilteredListCreatedOnColumn;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'FilteredListRedStatusIndicatorTxt') SET @GVD_FilteredListRedStatusIndicatorTxt = @GVD_Target_FilteredListRedStatusIndicatorTxt;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'FilteredListOrangeStatusIndicatorTxt') SET @GVD_FilteredListOrangeStatusIndicatorTxt = @GVD_Target_FilteredListOrangeStatusIndicatorTxt;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'FilteredListGreenStatusIndicatorTxt') SET @GVD_FilteredListGreenStatusIndicatorTxt = @GVD_Target_FilteredListGreenStatusIndicatorTxt;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'FilteredListGroupBy') SET @GVD_FilteredListGroupBy = @GVD_Target_FilteredListGroupBy;
        IF @GVD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVD_ColumnSourceSelectionJson) WHERE [value] = N'IsHidden') SET @GVD_IsHidden = @GVD_Target_IsHidden;
    END;

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
        @GVD_IsHidden,
        @GVD_OverrideTargetGuid,
        @GVD_ColumnSourceSelectionJson;
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
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVCD_OverrideTargetGuid UNIQUEIDENTIFIER,
    @GVCD_ColumnSourceSelectionJson NVARCHAR(MAX),
    @GVCD_Target_RowStatus TINYINT,
    @GVCD_Target_Name NVARCHAR(250),
    @GVCD_Target_ColumnOrder INT,
    @GVCD_Target_IsPrimaryKey BIT,
    @GVCD_Target_IsHidden BIT,
    @GVCD_Target_IsFiltered BIT,
    @GVCD_Target_IsCombo BIT,
    @GVCD_Target_DisplayFormat NVARCHAR(50),
    @GVCD_Target_Width NVARCHAR(10),
    @GVCD_Target_TopHeaderCategory NVARCHAR(50),
    @GVCD_Target_TopHeaderCategoryOrder INT,
    @GVCD_TargetRowFound BIT;

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
        sr.SourceRowId,
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
    @GVCD_SourceRowId,
    @GVCD_OverrideTargetGuid,
    @GVCD_ColumnSourceSelectionJson;

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

    -- A manual Identity Map override is an explicit, reviewed operator decision and wins over
    -- the natural-key (GridViewDefinition+PrimaryKey/Name) match below.
    IF @GVCD_OverrideTargetGuid IS NULL
    BEGIN
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
    END;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@GVCD_OverrideTargetGuid, ISNULL(@ExistingGridViewColumnDefinitionGuid, @Guid));

    IF @ExistingGridViewColumnDefinitionGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingGridViewColumnDefinitionGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'GridViewColumnDefinitions'
          AND lookup.SourceRowId = @GVCD_SourceRowId;
    END;

    IF @GVCD_OverrideTargetGuid IS NOT NULL AND @GVCD_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @GVCD_TargetRowFound = 0;
        SET @GVCD_Target_RowStatus = NULL;
        SET @GVCD_Target_Name = NULL;
        SET @GVCD_Target_ColumnOrder = NULL;
        SET @GVCD_Target_IsPrimaryKey = NULL;
        SET @GVCD_Target_IsHidden = NULL;
        SET @GVCD_Target_IsFiltered = NULL;
        SET @GVCD_Target_IsCombo = NULL;
        SET @GVCD_Target_DisplayFormat = NULL;
        SET @GVCD_Target_Width = NULL;
        SET @GVCD_Target_TopHeaderCategory = NULL;
        SET @GVCD_Target_TopHeaderCategoryOrder = NULL;

        SELECT
            @GVCD_Target_RowStatus = targetrow.RowStatus,
            @GVCD_Target_Name = targetrow.Name,
            @GVCD_Target_ColumnOrder = targetrow.ColumnOrder,
            @GVCD_Target_IsPrimaryKey = targetrow.IsPrimaryKey,
            @GVCD_Target_IsHidden = targetrow.IsHidden,
            @GVCD_Target_IsFiltered = targetrow.IsFiltered,
            @GVCD_Target_IsCombo = targetrow.IsCombo,
            @GVCD_Target_DisplayFormat = targetrow.DisplayFormat,
            @GVCD_Target_Width = targetrow.Width,
            @GVCD_Target_TopHeaderCategory = targetrow.TopHeaderCategory,
            @GVCD_Target_TopHeaderCategoryOrder = targetrow.TopHeaderCategoryOrder
        FROM SUserInterface.GridViewColumnDefinitions AS targetrow
        WHERE targetrow.Guid = @GVCD_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @GVCD_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @GVCD_RowStatus = @GVCD_Target_RowStatus;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @GVCD_Name = @GVCD_Target_Name;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'ColumnOrder') SET @GVCD_ColumnOrder = @GVCD_Target_ColumnOrder;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'IsPrimaryKey') SET @GVCD_IsPrimaryKey = @GVCD_Target_IsPrimaryKey;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'IsHidden') SET @GVCD_IsHidden = @GVCD_Target_IsHidden;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'IsFiltered') SET @GVCD_IsFiltered = @GVCD_Target_IsFiltered;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'IsCombo') SET @GVCD_IsCombo = @GVCD_Target_IsCombo;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'DisplayFormat') SET @GVCD_DisplayFormat = @GVCD_Target_DisplayFormat;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'Width') SET @GVCD_Width = @GVCD_Target_Width;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'TopHeaderCategory') SET @GVCD_TopHeaderCategory = @GVCD_Target_TopHeaderCategory;
        IF @GVCD_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@GVCD_ColumnSourceSelectionJson) WHERE [value] = N'TopHeaderCategoryOrder') SET @GVCD_TopHeaderCategoryOrder = @GVCD_Target_TopHeaderCategoryOrder;
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
        @GVCD_SourceRowId,
        @GVCD_OverrideTargetGuid,
        @GVCD_ColumnSourceSelectionJson;
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
    @MT_OverrideTargetGuid UNIQUEIDENTIFIER,
    @MilestoneTypeGuid UNIQUEIDENTIFIER,
    @MT_ColumnSourceSelectionJson NVARCHAR(MAX),
    @MT_Target_RowStatus TINYINT,
    @MT_Target_Name NVARCHAR(100),
    @MT_Target_Code NVARCHAR(20),
    @MT_Target_IsActive BIT,
    @MT_Target_IsInvoiceTrigger BIT,
    @MT_Target_IsReviewRequired BIT,
    @MT_Target_HelpText NVARCHAR(2000),
    @MT_Target_HasDescription BIT,
    @MT_Target_IsCompulsory BIT,
    @MT_Target_IncludeStart BIT,
    @MT_Target_IncludeSchedule BIT,
    @MT_Target_IncludeDueDate BIT,
    @MT_Target_HasExternalSubmission BIT,
    @MT_Target_HasReference BIT,
    @MT_Target_HasQuotedHours BIT,
    @MT_TargetRowFound BIT;

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
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasQuotedHours')),
        ov.TargetRowGuid,
        ov.ColumnSourceSelectionJson
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN #MetadataRowsToApply AS applyRows
        ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
    @MT_HasQuotedHours,
    @MT_OverrideTargetGuid,
    @MT_ColumnSourceSelectionJson;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- A manual Identity Map override means "update the record I matched this to," not
    -- "insert my own Guid" - resolve to the override's target before upserting.
    SET @MilestoneTypeGuid = ISNULL(@MT_OverrideTargetGuid, @Guid);

    IF @MT_OverrideTargetGuid IS NOT NULL AND @MT_ColumnSourceSelectionJson IS NOT NULL
    BEGIN
        SET @MT_TargetRowFound = 0;
        SET @MT_Target_RowStatus = NULL;
        SET @MT_Target_Name = NULL;
        SET @MT_Target_Code = NULL;
        SET @MT_Target_IsActive = NULL;
        SET @MT_Target_IsInvoiceTrigger = NULL;
        SET @MT_Target_IsReviewRequired = NULL;
        SET @MT_Target_HelpText = NULL;
        SET @MT_Target_HasDescription = NULL;
        SET @MT_Target_IsCompulsory = NULL;
        SET @MT_Target_IncludeStart = NULL;
        SET @MT_Target_IncludeSchedule = NULL;
        SET @MT_Target_IncludeDueDate = NULL;
        SET @MT_Target_HasExternalSubmission = NULL;
        SET @MT_Target_HasReference = NULL;
        SET @MT_Target_HasQuotedHours = NULL;

        SELECT
            @MT_Target_RowStatus = targetrow.RowStatus,
            @MT_Target_Name = targetrow.Name,
            @MT_Target_Code = targetrow.Code,
            @MT_Target_IsActive = targetrow.IsActive,
            @MT_Target_IsInvoiceTrigger = targetrow.IsInvoiceTrigger,
            @MT_Target_IsReviewRequired = targetrow.IsReviewRequired,
            @MT_Target_HelpText = targetrow.HelpText,
            @MT_Target_HasDescription = targetrow.HasDescription,
            @MT_Target_IsCompulsory = targetrow.IsCompulsory,
            @MT_Target_IncludeStart = targetrow.IncludeStart,
            @MT_Target_IncludeSchedule = targetrow.IncludeSchedule,
            @MT_Target_IncludeDueDate = targetrow.IncludeDueDate,
            @MT_Target_HasExternalSubmission = targetrow.HasExternalSubmission,
            @MT_Target_HasReference = targetrow.HasReference,
            @MT_Target_HasQuotedHours = targetrow.HasQuotedHours
        FROM SJob.MilestoneTypes AS targetrow
        WHERE targetrow.Guid = @MT_OverrideTargetGuid;

        IF @@ROWCOUNT > 0 SET @MT_TargetRowFound = 1;

        -- Only trust the "keep target value" merge when the override's target row actually
        -- resolved; a stale/unresolved override must fall back to the source value instead
        -- of silently reusing whatever a prior loop iteration left in these variables.

        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'RowStatus') SET @MT_RowStatus = @MT_Target_RowStatus;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @MT_Name = @MT_Target_Name;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'Code') SET @MT_Code = @MT_Target_Code;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IsActive') SET @MT_IsActive = @MT_Target_IsActive;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IsInvoiceTrigger') SET @MT_IsInvoiceTrigger = @MT_Target_IsInvoiceTrigger;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IsReviewRequired') SET @MT_IsReviewRequired = @MT_Target_IsReviewRequired;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'HelpText') SET @MT_HelpText = @MT_Target_HelpText;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'HasDescription') SET @MT_HasDescription = @MT_Target_HasDescription;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IsCompulsory') SET @MT_IsCompulsory = @MT_Target_IsCompulsory;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IncludeStart') SET @MT_IncludeStart = @MT_Target_IncludeStart;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IncludeSchedule') SET @MT_IncludeSchedule = @MT_Target_IncludeSchedule;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'IncludeDueDate') SET @MT_IncludeDueDate = @MT_Target_IncludeDueDate;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'HasExternalSubmission') SET @MT_HasExternalSubmission = @MT_Target_HasExternalSubmission;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'HasReference') SET @MT_HasReference = @MT_Target_HasReference;
        IF @MT_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@MT_ColumnSourceSelectionJson) WHERE [value] = N'HasQuotedHours') SET @MT_HasQuotedHours = @MT_Target_HasQuotedHours;
    END;

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
        @MT_HasQuotedHours,
        @MT_OverrideTargetGuid,
        @MT_ColumnSourceSelectionJson;
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

/* Deploy StoredProcedure SSop.QuotesRevise using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SSop.QuotesRevise.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SSop.QuotesRevise
    Source schema hash : 4EF9D311B06BDBA9B8C04AACEB2C97A1997CB3DB751CDECB0084184C3F71DCC7
    Definition SHA-256 : 90EA7E91DC1D5E94F121C0225FE05E6697201D71CCB7835C3F399C7DFEB8499C

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SSop].[QuotesRevise]
    @SourceGuid UNIQUEIDENTIFIER,
    @TargetGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SourceID INT,
        @ID INT,
        @IsInsert BIT;

    SELECT @SourceID = q.ID
    FROM SSop.Quotes AS q
    WHERE q.Guid = @SourceGuid
      AND q.RowStatus NOT IN (0,254);

    IF (@SourceID IS NULL)
        THROW 60000, N'Invalid source Quote', 1;

    IF EXISTS
    (
        SELECT 1
        FROM SSop.Quotes AS q
        WHERE q.Guid = @SourceGuid
          AND q.RowStatus NOT IN (0,254)
          AND q.DateAccepted IS NOT NULL
    )
    BEGIN
        ;THROW 60000, N'You cannot revise an accepted quote', 1;
    END;

    EXEC SCore.UpsertDataObject
        @Guid = @TargetGuid,
        @SchemeName = N'SSop',
        @ObjectName = N'Quotes',
        @IncludeDefaultSecurity = 1,
        @IsInsert = @IsInsert OUTPUT;

    INSERT SSop.Quotes
    (
        RowStatus,
        Guid,
        OrganisationalUnitID,
        QuotingUserId,
        Number,
        UprnId,
        ClientAccountId,
        ClientAddressId,
        ClientContactId,
        ContractID,
        Date,
        Overview,
        ExpiryDate,
        QuoteSourceId,
        IsSubjectToNDA,
        AgentAccountId,
        AgentAddressId,
        AgentContactId,
        ExternalReference,
        FeeCap,
        RevisionNumber,
        OriginalQuoteId,
        EnquiryServiceID,
        DescriptionOfWorks,
        QuotingConsultantId,
        ExclusionsAndLimitations,
        ProjectId,
        AgentContractID,
        MarketId,
        SectorId,
        JobTypeId,
        DataClassificationID,
        SecurityClassificationID
    )
    SELECT
        0,
        @TargetGuid,
        q.OrganisationalUnitID,
        q.QuotingUserId,
        q.Number,
        q.UprnId,
        q.ClientAccountId,
        q.ClientAddressId,
        q.ClientContactId,
        q.ContractID,
        GETDATE(),
        q.Overview,
        DATEADD(MONTH, 6, GETDATE()),
        q.QuoteSourceId,
        q.IsSubjectToNDA,
        q.AgentAccountId,
        q.AgentAddressId,
        q.AgentContactId,
        q.ExternalReference,
        q.FeeCap,
        ISNULL(latest_revision.rev, 0) + 1,
        CASE
            WHEN q.OriginalQuoteId = -1 THEN q.ID
            ELSE q.OriginalQuoteId
        END,
        q.EnquiryServiceID,
        q.DescriptionOfWorks,
        q.QuotingConsultantId,
        q.ExclusionsAndLimitations,
        q.ProjectId,
        q.AgentContractID,
        q.MarketId,
        q.SectorId,
        q.JobTypeId,
        q.DataClassificationID,
        q.SecurityClassificationID
    FROM SSop.Quotes AS q
    OUTER APPLY
    (
        SELECT MAX(q1.RevisionNumber) AS rev
        FROM SSop.Quotes AS q1
        WHERE q1.OriginalQuoteId =
            CASE
                WHEN q.OriginalQuoteId = -1 THEN q.ID
                ELSE q.OriginalQuoteId
            END
          AND q1.RowStatus NOT IN (0,254)
    ) AS latest_revision
    WHERE q.ID = @SourceID;

    SELECT @ID = CONVERT(INT, SCOPE_IDENTITY());

    DECLARE @QuoteItems SCore.TwoGuidUniqueList;

    INSERT @QuoteItems
    (
        GuidValue,
        GuidValueTwo
    )
    SELECT
        qi.Guid,
        NEWID()
    FROM SSop.QuoteItems AS qi
    WHERE qi.QuoteId = @SourceID
      AND qi.RowStatus NOT IN (0,254);

    DECLARE @QuotePaymentStages SCore.TwoGuidUniqueList;

    INSERT @QuotePaymentStages
    (
        GuidValue,
        GuidValueTwo
    )
    SELECT
        qps.Guid,
        NEWID()
    FROM SSop.QuotePaymentStages AS qps
    WHERE qps.QuoteId = @SourceID
      AND qps.RowStatus NOT IN (0,254);

    DECLARE @QuoteMemos SCore.TwoGuidUniqueList;

    INSERT @QuoteMemos
    (
        GuidValue,
        GuidValueTwo
    )
    SELECT
        qm.Guid,
        NEWID()
    FROM SSop.QuoteMemos AS qm
    WHERE qm.QuoteID = @SourceID
      AND qm.RowStatus NOT IN (0,254);

    DECLARE @NewGuidList SCore.GuidUniqueList;

    INSERT @NewGuidList
    (
        GuidValue
    )
    SELECT qi.GuidValueTwo
    FROM @QuoteItems AS qi;

    EXEC SCore.DataObjectBulkUpsert
        @GuidList = @NewGuidList,
        @SchemeName = N'SSop',
        @ObjectName = N'QuoteItems',
        @IsInsert = @IsInsert OUTPUT;

    DELETE FROM @NewGuidList;

    INSERT @NewGuidList
    (
        GuidValue
    )
    SELECT qps.GuidValueTwo
    FROM @QuotePaymentStages AS qps;

    EXEC SCore.DataObjectBulkUpsert
        @GuidList = @NewGuidList,
        @SchemeName = N'SSop',
        @ObjectName = N'QuotePaymentStages',
        @IsInsert = @IsInsert OUTPUT;

    DELETE FROM @NewGuidList;

    INSERT @NewGuidList
    (
        GuidValue
    )
    SELECT qm.GuidValueTwo
    FROM @QuoteMemos AS qm;

    EXEC SCore.DataObjectBulkUpsert
        @GuidList = @NewGuidList,
        @SchemeName = N'SSop',
        @ObjectName = N'QuoteMemos',
        @IsInsert = @IsInsert OUTPUT;

    INSERT SSop.QuoteItems
    (
        RowStatus,
        Guid,
        QuoteId,
        ProductId,
        Details,
        Net,
        VatRate,
        DoNotConsolidateJob,
        SortOrder,
        Quantity
    )
    SELECT
        1,
        qil.GuidValueTwo,
        @ID,
        qi.ProductId,
        qi.Details,
        qi.Net,
        qi.VatRate,
        qi.DoNotConsolidateJob,
        qi.SortOrder,
        qi.Quantity
    FROM SSop.QuoteItems AS qi
    JOIN @QuoteItems AS qil
        ON qil.GuidValue = qi.Guid
    JOIN SSop.QuoteSections AS oqs
        ON oqs.ID = qi.QuoteSectionId;

    INSERT SSop.QuotePaymentStages
    (
        RowStatus,
        Guid,
        QuoteId,
        PaymentFrequencyTypeId,
        PaymentFrequency,
        Value,
        PercentageOfTotal,
        PayAfterStageId
    )
    SELECT
        1,
        qpsl.GuidValueTwo,
        @ID,
        qps.PaymentFrequencyTypeId,
        qps.PaymentFrequency,
        qps.Value,
        qps.PercentageOfTotal,
        qps.PayAfterStageId
    FROM SSop.QuotePaymentStages AS qps
    JOIN @QuotePaymentStages AS qpsl
        ON qps.Guid = qpsl.GuidValue;

    INSERT SSop.QuoteMemos
    (
        RowStatus,
        Guid,
        QuoteID,
        Memo,
        CreatedDateTimeUTC,
        CreatedByUserId
    )
    SELECT
        1,
        qms.GuidValueTwo,
        @ID,
        qm.Memo,
        qm.CreatedDateTimeUTC,
        qm.CreatedByUserId
    FROM SSop.QuoteMemos AS qm
    JOIN @QuoteMemos AS qms
        ON qm.Guid = qms.GuidValue;

    UPDATE SSop.Quotes
    SET RowStatus = 1
    WHERE ID = @ID;

    DECLARE
        @QuoteRevisedStatusGuid UNIQUEIDENTIFIER,
        @QuotingStatusGuid UNIQUEIDENTIFIER,
        @NewTransitionGuid UNIQUEIDENTIFIER;

    SELECT TOP (1)
        @QuoteRevisedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name IN (N'Quote Revised', N'Revised')
    ORDER BY
        CASE
            WHEN ws.Name = N'Quote Revised' THEN 0
            WHEN ws.Name = N'Revised' THEN 1
            ELSE 2
        END,
        ws.ID;

    SELECT TOP (1)
        @QuotingStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Quoting'
    ORDER BY ws.ID;

    IF (@QuoteRevisedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Quote Revised workflow status. Please confirm the Quote Revised/Revised WorkflowStatus exists and has ShowInQuotes = 1.', 1;

    IF (@QuotingStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Quote Quoting workflow status.', 1;

    SET @NewTransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @NewTransitionGuid,
        @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
        @StatusGuid = @QuoteRevisedStatusGuid,
        @Comment = N'Quote revised.',
        @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @TargetGuid,
        @IsImported = 1;


	--CYB-319: Set "Revised" on the original record.
	DECLARE @PreviousVersionLastStatusGuid UNIQUEIDENTIFIER,
			@PreviousVersionNewTransitionGuid UNIQUEIDENTIFIER = NEWID(); --new transition GUID.

	--Get the last status from the quote that got revised.
	SELECT TOP(1) @PreviousVersionLastStatusGuid = wfs.Guid
	FROM SCore.DataObjectTransition root_hobt
	LEFT JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = root_hobt.StatusID)
	WHERE 
			(root_hobt.DataObjectGuid = @SourceGuid)
		AND (root_hobt.RowStatus NOT IN (0,254))
	ORDER BY root_hobt.ID DESC;


    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @PreviousVersionNewTransitionGuid,
        @OldStatusGuid = @PreviousVersionLastStatusGuid,
        @StatusGuid = @QuoteRevisedStatusGuid,
        @Comment = N'Quote revised.',
        @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @SourceGuid,
        @IsImported = 1;


    SET @NewTransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @NewTransitionGuid,
        @OldStatusGuid = @QuoteRevisedStatusGuid,
        @StatusGuid = @QuotingStatusGuid,
        @Comment = N'Revision opened for quoting.',
        @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @TargetGuid,
        @IsImported = 1;
END;
GO

GO

/* Deploy StoredProcedure SSop.QuotesUpsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SSop.QuotesUpsert.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SSop.QuotesUpsert
    Source schema hash : 525F5BD2096E67FB006D758BD2DB925A64426C662B20A430A5F0E306FEC3ACE1
    Definition SHA-256 : 53248C73211E561C0C61BE49927DD6E57C7E391F95B5CC923B6E379685990BF3

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SSop].[QuotesUpsert]
(
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @QuotingUserGuid UNIQUEIDENTIFIER,
    @ContractGuid UNIQUEIDENTIFIER,
    @Date DATE,
    @Overview NVARCHAR(MAX),
    @ExpiryDate DATE,
    @DateSent DATE,
    @DateAccepted DATE,
    @DateRejected DATE,
    @RejectionReason NVARCHAR(MAX),
    @FeeCap DECIMAL(19, 2),
    @IsFinal BIT,
    @ExternalReference NVARCHAR(50),
    @QuotingConsultantGuid UNIQUEIDENTIFIER,
    @AppointmentFromRibaStageGuid UNIQUEIDENTIFIER,
    @CurrentStageGuid UNIQUEIDENTIFIER,
    @DeadDate DATE,
    @EnquiryServiceGuid UNIQUEIDENTIFIER,
    @ProjectGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
    @JobType UNIQUEIDENTIFIER,
    @DeclinedToQuoteReason NVARCHAR(MAX),
    @DescriptionOfWorks NVARCHAR(MAX),
    @ExclusionsAndLimitations NVARCHAR(MAX),
    @AgentContractGuid UNIQUEIDENTIFIER,
    @IsSubjectToNDA BIT,
    @SectorGuid UNIQUEIDENTIFIER,
    @MarketGuid UNIQUEIDENTIFIER,
    @DataClassificationGuid UNIQUEIDENTIFIER,
    @SecurityClassificationGuid UNIQUEIDENTIFIER,
	--		[CYB-321]
	@JobTypeGuid  UNIQUEIDENTIFIER,
	@PropertyGuid UNIQUEIDENTIFIER,
	@ClientAccountGuid UNIQUEIDENTIFIER,
	@ClientAddressGuid UNIQUEIDENTIFIER,
	@ClientContactGuid UNIQUEIDENTIFIER,
	@AgentAccountGuid  UNIQUEIDENTIFIER,
	@AgentAddressGuid  UNIQUEIDENTIFIER,
	@AgentContactGuid  UNIQUEIDENTIFIER

)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrganisationalUnitId INT = -1,
            @QuotingUserId INT,
            @ContractId INT = -1,
            @IsInsert BIT = 0,
            @QuoteId INT,
            @QuoteNumber INT,
            @QuotingConsultantId INT,
            @AppointmentFromRibaStageId INT,
            @CurrentStageId INT,
            @EnquiryServiceID INT,
            @ProjectID INT,
            @JobTypeId INT,
            @AgentContractID INT = -1,
            @SectorId INT = -1,
            @MarketId INT = -1,
            @DataClassificationId INT = -1,
            @SecurityClassificationId INT = -1,

			@PropertyId INT = -1,
			@ClientAccountId INT = -1,
			@ClientAddressId INT = -1,
			@ClientContactId INT = -1,
			@AgentAccountId INT = -1,
			@AgentAddressId INT = -1,
			@AgentContactId INT = -1;


    SELECT @OrganisationalUnitId = ou.ID
    FROM SCore.OrganisationalUnits AS ou
    WHERE ou.Guid = @OrganisationalUnitGuid;

    SELECT @QuotingUserId = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @QuotingUserGuid;

    SELECT @QuotingConsultantId = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @QuotingConsultantGuid;

    SELECT @ContractId = c.ID
    FROM SSop.Contracts AS c
    WHERE c.Guid = @ContractGuid;

    SELECT @AppointmentFromRibaStageId = rs.ID
    FROM SJob.RibaStages AS rs
    WHERE rs.Guid = @AppointmentFromRibaStageGuid;

    SELECT @EnquiryServiceID = es.ID
    FROM SSop.EnquiryServices AS es
    WHERE es.Guid = @EnquiryServiceGuid;

    SELECT @CurrentStageId = rs.ID
    FROM SJob.RibaStages AS rs
    WHERE rs.Guid = @CurrentStageGuid;

    SELECT @ProjectID = p.ID
    FROM SSop.Projects AS p
    WHERE p.Guid = @ProjectGuid;

    SELECT @JobTypeId = jt.ID
    FROM SJob.JobTypes AS jt
    WHERE jt.Guid = @JobType;

    SELECT @AgentContractID = c.ID
    FROM SSop.Contracts AS c
    WHERE c.Guid = @AgentContractGuid;

    SELECT @SectorId = s.ID
    FROM SCore.Sectors AS s
    WHERE s.Guid = @SectorGuid;

    SELECT @MarketId = m.ID
    FROM SCore.Markets AS m
    WHERE m.Guid = @MarketGuid;

	SELECT @PropertyId = a.ID
	FROM SJob.Assets a
	WHERE a.Guid = @PropertyGuid;

	SELECT @ClientAccountId = c.ID
	FROM SCrm.Accounts c
	WHERE c.Guid = @ClientAccountGuid;

	SELECT @ClientAddressId = ca.ID
	FROM SCrm.Addresses ca
	WHERE ca.Guid = @ClientAddressGuid;

	SELECT @ClientContactId = cc.ID
	FROM SCrm.Contacts cc
	WHERE cc.Guid  = @ClientContactGuid;

	SELECT @AgentAccountId = a.ID
	FROM SCrm.Accounts a
	WHERE a.Guid = @AgentAccountGuid;

	SELECT @AgentAddressId = aa.ID
	FROM SCrm.Addresses aa
	WHERE aa.Guid = @AgentAddressGuid;

	SELECT @AgentContactId = ac.ID
	FROM SCrm.Contacts ac
	WHERE ac.Guid  = @AgentContactGuid;


    -------------------------------------------------------------------------
    -- CYB-340
    -- Quote classification is editable independently from Project.
    -- Project is not updated from Quote.
    -- Existing Jobs are not updated from Quote save.
    -- Jobs created later from this Quote should inherit from the Quote creation path.
    -------------------------------------------------------------------------
    SELECT @DataClassificationId = dc.ID
    FROM SCore.DataClassifications AS dc
    WHERE dc.Guid = @DataClassificationGuid
      AND dc.RowStatus NOT IN (0,254);

    SELECT @SecurityClassificationId = sc.ID
    FROM SCore.SecurityClassifications AS sc
    WHERE sc.Guid = @SecurityClassificationGuid
      AND sc.RowStatus NOT IN (0,254);

    SET @DataClassificationId = ISNULL(@DataClassificationId, -1);
    SET @SecurityClassificationId = ISNULL(@SecurityClassificationId, -1);

    EXEC sys.sp_set_session_context
        @key = N'new_entity_type_guid',
        @value = '1c4794c1-f956-4c32-b886-5500ac778a56',
        @read_only = 0;

    EXEC sys.sp_set_session_context
        @key = N'record_guid',
        @value = @EnquiryServiceGuid,
        @read_only = 0;

    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SSop',
        @ObjectName = N'Quotes',
        @IsInsert = @IsInsert OUTPUT;

    EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
    EXEC sys.sp_set_session_context @key = N'record_guid', @value = NULL, @read_only = 0;

    IF (@IsInsert = 1)
    BEGIN
        IF (@DateSent IS NOT NULL OR @DateAccepted IS NOT NULL)
            THROW 60031, N'CYB-101: Cannot set DateSent/DateAccepted on quote creation until at least one Quote Item exists.', 1;

        INSERT SSop.Quotes
        (
            RowStatus,
            Guid,
            OrganisationalUnitID,
            QuotingUserId,
            ContractID,
            Date,
            Overview,
            ExpiryDate,
            DateSent,
            DateAccepted,
            DateRejected,
            RejectionReason,
            FeeCap,
            IsFinal,
            ExternalReference,
            QuotingConsultantId,
            AppointmentFromRibaStageId,
            CurrentRibaStageId,
            DeadDate,
            EnquiryServiceID,
            ProjectId,
            JobTypeId,
            DeclinedToQuoteReason,
            DescriptionOfWorks,
            ExclusionsAndLimitations,
            AgentContractID,
            IsSubjectToNDA,
            SectorId,
            MarketId,
            DataClassificationID,
            SecurityClassificationID
        )
        VALUES
        (
            0,
            @Guid,
            @OrganisationalUnitId,
            @QuotingUserId,
            @ContractId,
            @Date,
            @Overview,
            @ExpiryDate,
            @DateSent,
            @DateAccepted,
            @DateRejected,
            @RejectionReason,
            @FeeCap,
            @IsFinal,
            @ExternalReference,
            @QuotingConsultantId,
            @AppointmentFromRibaStageId,
            @CurrentStageId,
            @DeadDate,
            @EnquiryServiceID,
            @ProjectID,
            @JobTypeId,
            @DeclinedToQuoteReason,
            @DescriptionOfWorks,
            @ExclusionsAndLimitations,
            @AgentContractID,
            @IsSubjectToNDA,
            @SectorId,
            @MarketId,
            @DataClassificationId,
            @SecurityClassificationId
        );

        DECLARE @DynamicQuotingStatusForQuotes UNIQUEIDENTIFIER;
        DECLARE @DataObjectTransitionQuoteGuid UNIQUEIDENTIFIER = NEWID();

        SELECT @DynamicQuotingStatusForQuotes = ws.Guid
        FROM SCore.WorkflowStatus AS ws
        WHERE ws.RowStatus NOT IN (0,254)
          AND ws.ShowInQuotes = 1
          AND ws.Name = N'Quoting'
          AND ws.Description = N'Automatically generated status';

        EXEC SCore.DataObjectTransitionUpsert
            @Guid = @DataObjectTransitionQuoteGuid,
            @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
            @StatusGuid = @DynamicQuotingStatusForQuotes,
            @Comment = N'System Imported.',
            @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
            @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
            @DataObjectGuid = @Guid,
            @IsImported = 1;

        DECLARE @EnquiryGuid UNIQUEIDENTIFIER;
        DECLARE @DataObjectTransitionEnquiryGuid UNIQUEIDENTIFIER = NEWID();

        SELECT TOP (1) @EnquiryGuid = e.Guid
        FROM SSop.EnquiryServices AS es
        LEFT JOIN SSop.Enquiries AS e
            ON e.ID = es.EnquiryId
        WHERE es.ID = @EnquiryServiceID;

        EXEC SCore.DataObjectTransitionUpsert
            @Guid = @DataObjectTransitionEnquiryGuid,
            @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
            @StatusGuid = @DynamicQuotingStatusForQuotes,
            @Comment = N'System Imported.',
            @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
            @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
            @DataObjectGuid = @EnquiryGuid,
            @IsImported = 1;

        SELECT @QuoteId = CONVERT(INT, SCOPE_IDENTITY());
    END;
    ELSE
    BEGIN
        DECLARE @_quotingConsultant INT,
                @_isFinal BIT,
                @_emailRecipient NVARCHAR(MAX),
                @_emailBody NVARCHAR(MAX),
                @_emailSubject NVARCHAR(MAX),
                @_quoteNumber NVARCHAR(MAX),
                @QuoteItemCount INT = 0,
                @ExistingEffectiveQuoteJobTypeId INT = -1,
                @NewEffectiveQuoteJobTypeId INT = -1;

        SELECT @_quotingConsultant = q.QuotingConsultantId,
               @_isFinal = q.IsFinal,
               @_quoteNumber = q.Number,
               @QuoteId = q.ID
        FROM SSop.Quotes AS q
        WHERE q.Guid = @Guid
          AND q.RowStatus NOT IN (0,254);

        IF ISNULL(@QuoteId, -1) <= 0
        BEGIN
            THROW 604160, N'CYB-416: Quote could not be resolved for update.', 1;
        END;

        SELECT @QuoteItemCount = COUNT(1)
        FROM SSop.QuoteItems AS qi
        WHERE qi.QuoteId = @QuoteId
          AND qi.RowStatus NOT IN (0,254);

        IF (@DateSent IS NOT NULL OR @DateAccepted IS NOT NULL)
        BEGIN
            IF (ISNULL(@QuoteItemCount, 0) <= 0)
                THROW 60032, N'CYB-101: Cannot set Quote to Sent/Accepted (DateSent/DateAccepted) until at least one Quote Item exists.', 1;
        END;

        ---------------------------------------------------------------------
        -- CYB-416
        -- A quote job type cannot be changed once active quote items exist.
        -- Quote item products are scoped by job type and later drive job
        -- creation, delivery and finance behaviour.
        ---------------------------------------------------------------------
        IF ISNULL(@QuoteItemCount, 0) > 0
        BEGIN
            SELECT @ExistingEffectiveQuoteJobTypeId =
                COALESCE
                (
                    NULLIF(NULLIF(q.JobTypeId, 0), -1),
                    NULLIF(NULLIF(es.JobTypeId, 0), -1),
                    (
                        SELECT MIN(NULLIF(NULLIF(p.CreatedJobType, 0), -1))
                        FROM SSop.QuoteItems AS qiExisting
                        JOIN SProd.Products AS p
                            ON p.ID = qiExisting.ProductId
                           AND p.RowStatus NOT IN (0,254)
                        WHERE qiExisting.QuoteId = q.ID
                          AND qiExisting.RowStatus NOT IN (0,254)
                          AND ISNULL(p.CreatedJobType, -1) <> -1
                    ),
                    -1
                )
            FROM SSop.Quotes AS q
            LEFT JOIN SSop.EnquiryServices AS es
                ON es.ID = q.EnquiryServiceID
               AND es.RowStatus NOT IN (0,254)
            WHERE q.ID = @QuoteId
              AND q.Guid = @Guid
              AND q.RowStatus NOT IN (0,254);

            SET @NewEffectiveQuoteJobTypeId = ISNULL(NULLIF(NULLIF(@JobTypeId, 0), -1), -1);

            IF ISNULL(@ExistingEffectiveQuoteJobTypeId, -1) > 0
            BEGIN
                IF ISNULL(@NewEffectiveQuoteJobTypeId, -1) <= 0
                BEGIN
                    SET @JobTypeId = @ExistingEffectiveQuoteJobTypeId;
                    SET @NewEffectiveQuoteJobTypeId = @ExistingEffectiveQuoteJobTypeId;
                END;

                IF @NewEffectiveQuoteJobTypeId <> @ExistingEffectiveQuoteJobTypeId
                BEGIN
                    THROW 604161, N'CYB-416: Job type cannot be changed while quote items exist. Remove the quote items first, then change the job type.', 1;
                END;
            END;
            ELSE
            BEGIN
                IF ISNULL(@NewEffectiveQuoteJobTypeId, -1) > 0
                BEGIN
                    THROW 604162, N'CYB-416: Job type cannot be set or changed while quote items exist. Remove the quote items first, then change the job type.', 1;
                END;
            END;
        END;

        UPDATE SSop.Quotes
        SET OrganisationalUnitID = @OrganisationalUnitId,
            QuotingUserId = @QuotingUserId,
            ContractID = @ContractId,
            Date = @Date,
            Overview = @Overview,
            ExpiryDate = @ExpiryDate,
            DateSent = @DateSent,
            DateAccepted = @DateAccepted,
            DateRejected = @DateRejected,
            RejectionReason = @RejectionReason,
            FeeCap = @FeeCap,
            IsFinal = @IsFinal,
            ExternalReference = @ExternalReference,
            QuotingConsultantId = @QuotingConsultantId,
            AppointmentFromRibaStageId = @AppointmentFromRibaStageId,
            CurrentRibaStageId = @CurrentStageId,
            DeadDate = @DeadDate,
            EnquiryServiceID = @EnquiryServiceID,
            ProjectId = @ProjectID,
            JobTypeId = @JobTypeId,
            DeclinedToQuoteReason = @DeclinedToQuoteReason,
            DescriptionOfWorks = @DescriptionOfWorks,
            ExclusionsAndLimitations = @ExclusionsAndLimitations,
            AgentContractID = @AgentContractID,
            IsSubjectToNDA = @IsSubjectToNDA,
            SectorId = @SectorId,
            MarketId = @MarketId,
            DataClassificationID = @DataClassificationId,
            SecurityClassificationID = @SecurityClassificationId,
			UprnId = @PropertyId,
			ClientAccountId = @ClientAccountId,
			ClientAddressId = @ClientAddressId,
			ClientContactId = @ClientContactId,
			AgentAccountId  = @AgentAccountId,
			AgentAddressId  = @AgentAddressId,
			AgentContactId  = @AgentContactId
        WHERE Guid = @Guid;

        IF (@QuotingConsultantId <> @_quotingConsultant)
        BEGIN
            SELECT @_emailRecipient = i.EmailAddress
            FROM SCore.Identities AS i
            WHERE i.ID = @QuotingConsultantId;

            SET @_emailBody = N'You have been assigned as the consultant for quote <a href="'
                + SCore.GetCurrentApplicationUrl() + N'/QuoteDetail/' + CONVERT(NVARCHAR(MAX), @Guid)
                + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT(NVARCHAR(MAX), @Guid)
                + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
                + @_quoteNumber + N'</a>. Please take a moment to review this record.';

            SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' assigned to your user.';

            EXEC SAlert.CreateNotification
                @Recipients = @_emailRecipient,
                @Subject = @_emailSubject,
                @Body = @_emailBody,
                @BodyFormat = N'TEXT',
                @Importance = N'NORMAL';
        END;

        IF (@IsFinal <> @_isFinal)
           AND (@IsFinal = 1)
           AND (@DateSent IS NULL)
        BEGIN
            SELECT @_emailRecipient = STRING_AGG(i.EmailAddress, N';')
            FROM SCore.Identities AS i
            JOIN SCore.UserGroups AS ug
                ON ug.IdentityID = i.ID
            JOIN SCore.Groups AS g
                ON g.ID = ug.GroupID
            WHERE g.Code = N'CDMSA';

            SET @_emailBody = N'Quote <a href="' + SCore.GetCurrentApplicationUrl() + N'/QuoteDetail/'
                + CONVERT(NVARCHAR(MAX), @Guid)
                + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT(NVARCHAR(MAX), @Guid)
                + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
                + @_quoteNumber
                + N'</a> has been marked as final. Please review this record and send out the quote.';

            SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' ready to send.';

            EXEC SAlert.CreateNotification
                @Recipients = @_emailRecipient,
                @Subject = @_emailSubject,
                @Body = @_emailBody,
                @BodyFormat = N'TEXT',
                @Importance = N'NORMAL';
        END;
    END;

    IF (@IsInsert = 1)
    BEGIN
        SELECT @QuoteNumber = NEXT VALUE FOR SSop.QuoteNumber;

        UPDATE SSop.Quotes
        SET Number = @QuoteNumber,
            RowStatus = 1
        WHERE ID = @QuoteId;
    END;

    DECLARE @FilingObjectName NVARCHAR(250),
            @FilingLocation NVARCHAR(MAX);

    SELECT @FilingLocation =
    (
        SELECT ss.SiteIdentifier,
               spf.FolderPath
        FROM SCore.ObjectSharePointFolder AS spf
        JOIN SCore.SharepointSites AS ss
            ON ss.ID = spf.SharepointSiteId
        WHERE spf.ObjectGuid = @Guid
        FOR JSON PATH
    );

    DECLARE @QuoteNumberString NVARCHAR(30);

    SELECT @FilingObjectName = q.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / ' + agent.Name
                               + N' - ' + q.Overview,
           @QuoteNumberString = q.Number
    FROM SSop.Quotes AS q
    JOIN SJob.Assets AS p
        ON p.ID = q.UprnId
    JOIN SCrm.Accounts AS client
        ON client.ID = q.ClientAccountId
    JOIN SCrm.Accounts AS agent
        ON agent.ID = q.AgentAccountId
    WHERE q.Guid = @Guid;

    EXEC SOffice.TargetObjectUpsert
        @EntityTypeGuid = N'1c4794c1-f956-4c32-b886-5500ac778a56',
        @RecordGuid = @Guid,
        @Number = @QuoteNumberString,
        @Name = @FilingObjectName,
        @FilingLocation = @FilingLocation;
END
GO

GO
DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();
EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;
GO
