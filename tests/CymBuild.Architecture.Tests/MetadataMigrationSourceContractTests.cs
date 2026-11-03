using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class MetadataMigrationSourceContractTests
{
    private static readonly string[] ControlledApplyTables =
    [
        "SCore.LanguageLabels",
        "SCore.LanguageLabelTranslations",
        "SCore.EntityDataTypes",
        "SCore.EntityTypes",
        "SCore.EntityHobts",
        "SCore.EntityPropertyGroups",
        "SCore.EntityQueries",
        "SCore.EntityProperties",
        "SCore.EntityQueryParameters",
        "SCore.EntityPropertyDependants",
        "SUserInterface.Icons",
        "SUserInterface.DropDownListDefinitions",
        "SUserInterface.GridDefinitions",
        "SUserInterface.GridViewDefinitions",
        "SUserInterface.GridViewColumnDefinitions",
        "SJob.MilestoneTypes"
    ];

    [Fact]
    public void MetadataValidation_FailsClosedForTablesWithoutApplyHandlers()
    {
        var sql = ReadProcedure("SMigration.MetadataValidate_Run.sql");

        Assert.Contains("N'UnsupportedApplyHandler'", sql, StringComparison.Ordinal);
        Assert.Contains("sr.DifferenceType IN (N'Insert', N'Update')", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IgnoredRecords", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IdentityMapOverrides", sql, StringComparison.Ordinal);

        AssertControlledTableAllowList(sql);
    }

    [Fact]
    public void MetadataValidation_WarnsAboutStagedRowsThatAreNotSelected()
    {
        // CYB-574: QA2 had every Insert selected but almost no Updates, so changed queries were
        // staged, validated clean and silently never applied.
        var validate = ReadProcedure("SMigration.MetadataValidate_Run.sql");
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");

        Assert.Contains("N'UnselectedActionableRows'", validate, StringComparison.Ordinal);
        Assert.Contains("FROM SMigration.Metadata_RunSelections AS selection", validate, StringComparison.Ordinal);
        Assert.Contains("SelectAllActionableRecordsAsync", ui, StringComparison.Ordinal);
        Assert.Contains("\"UnselectedActionableRows\"", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidation_ChecksTargetQueryParametersForDuplicatesAndForeignMappings()
    {
        var validate = ReadProcedure("SMigration.MetadataValidate_Run.sql");
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");

        Assert.Contains("N'DuplicateQueryParameterName'", validate, StringComparison.Ordinal);
        Assert.Contains("HAVING COUNT(1) > 1", validate, StringComparison.Ordinal);
        Assert.Contains("N'QueryParameterMappingMismatch'", validate, StringComparison.Ordinal);
        Assert.Contains("h.EntityTypeID <> q.EntityTypeID", validate, StringComparison.Ordinal);

        // A duplicate parameter name breaks every call to the query, so Apply refuses it too.
        Assert.Contains("N'UnresolvedReference', N'DuplicateQueryParameterName', N'QueryCallSignatureMismatch')", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidation_FailsSelectedQueriesWhoseObjectIsMissingFromTheTarget()
    {
        // CYB-574: 'Invoice Requests Validate' reached QA2 as the default validation query
        // while SFin.tvf_InvoiceRequestsValidate existed only in DEV, so every save failed.
        var validate = ReadProcedure("SMigration.MetadataValidate_Run.sql");

        Assert.Contains("N'QueryObjectMissingInTarget'", validate, StringComparison.Ordinal);
        Assert.Contains("INNER JOIN #MetadataSelectedValidationRows AS selected", validate, StringComparison.Ordinal);
        Assert.Contains("OBJECT_ID(QUOTENAME(obj.SchemaName) + N'.' + QUOTENAME(obj.ObjectName)) IS NULL", validate, StringComparison.Ordinal);

        // The DEV-only WIP HoBT and its IsWIP/WIPReason properties broke Invoice Requests too.
        Assert.Contains("N'HobtObjectMissingInTarget'", validate, StringComparison.Ordinal);
        Assert.Contains("N'PropertyColumnMissingInTarget'", validate, StringComparison.Ordinal);
        Assert.Contains("FROM sys.columns AS c", validate, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidation_IgnoresStrayTabsAndLineBreaksInObjectNames()
    {
        // 2026-10-06 QA2 run: DEV's 'WIP Notes Upsert' query had SchemaName 'SFin' + CHAR(10).
        // LTRIM/RTRIM only remove spaces, so the lookup was [SFin<LF>].[...] and the existing
        // SFin.InvoiceRequestWIPNotesUpsert was reported as QueryObjectMissingInTarget.
        var validate = ReadProcedure("SMigration.MetadataValidate_Run.sql");

        foreach (var (alias, field) in new[]
        {
            ("sr", "SchemaName"), ("sr", "ObjectName"),
            ("hobtRow", "SchemaName"), ("hobtRow", "ObjectName"),
        })
        {
            Assert.Contains(
                $"LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(ISNULL(JSON_VALUE({alias}.SourcePayloadJson, N'$.{field}'), N''), NCHAR(9), N''), NCHAR(10), N''), NCHAR(13), N'')))",
                validate,
                StringComparison.Ordinal);
        }

        // Query, HoBT and property-column checks: six normalised names, none left un-normalised.
        Assert.Equal(6, CountOccurrences(validate, "NCHAR(9), N''), NCHAR(10), N''), NCHAR(13), N'')))"));
        Assert.DoesNotContain("LTRIM(RTRIM(ISNULL(JSON_VALUE(", validate, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidation_JudgesTheStateThisRunLeavesNotTheCurrentTarget()
    {
        // 2026-10-12 UAT_Test run B245E6D5: four warnings and one Fail described target rows the
        // run itself was about to correct (re-mapped parameters, a moved property whose selected
        // read query supplies it) or could retire (a duplicate parameter DEV had soft-deleted).
        var validate = NormaliseNewLines(ReadProcedure("SMigration.MetadataValidate_Run.sql"));

        // The default read query after this run names the property: selected staged source query
        // first (OPENJSON, as Statement exceeds JSON_VALUE's 4000 characters), else the target's.
        Assert.Contains("CROSS APPLY OPENJSON(readRow.SourcePayloadJson)", validate, StringComparison.Ordinal);
        Assert.Contains("AND readQuery.EntityHoBTID = prop.SourceHobtId\n            AND readQuery.IsDefaultRead = 1", validate, StringComparison.Ordinal);
        Assert.Contains("WHERE targetHobt.Guid = hobtRow.SourceRowGuid", validate, StringComparison.Ordinal);
        Assert.Contains("AND replacingRow.SourceRowGuid = targetRead.Guid", validate, StringComparison.Ordinal);
        Assert.DoesNotContain("JSON_VALUE(readRow.SourcePayloadJson, N'$.Statement')", validate, StringComparison.Ordinal);

        // A selected retirement removes a row from the duplicate-parameter count.
        Assert.Contains("AND retirement.SourceRowStatus = 254", validate, StringComparison.Ordinal);
        Assert.Contains("re-stage with Include retirements and select it", validate, StringComparison.Ordinal);

        // A selected parameter row is judged by its source mapping, not the target mapping it replaces.
        Assert.Contains("WHERE selected.RegistryGuid = @EntityQueryParametersRegistryGuid\n                AND selected.SourceRowGuid = p.Guid\n          );", validate, StringComparison.Ordinal);
        Assert.Contains("N'Source parameter ', src.ParameterName", validate, StringComparison.Ordinal);
        Assert.Contains("AND src.QueryEntityTypeId <> src.PropertyEntityTypeId", validate, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string text, string value)
    {
        var count = 0;
        for (var index = text.IndexOf(value, StringComparison.Ordinal); index >= 0; index = text.IndexOf(value, index + value.Length, StringComparison.Ordinal))
        {
            count++;
        }

        return count;
    }

    [Fact]
    public void MetadataApply_RemovesOtherActiveParametersWithTheSameNameAfterUpsert()
    {
        // CYB-574: an Update revived DEV's soft-deleted '@Guid' while the generated copy was
        // still active, leaving two on 'Invoice Request Items Validate'.
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");

        var upsertIndex = apply.IndexOf("EXEC SCore.EntityQueryParameterUpsert", StringComparison.Ordinal);
        var dedupIndex = apply.IndexOf("OUTPUT deleted.Guid INTO @EQP_RemovedDuplicates (Guid)", StringComparison.Ordinal);
        Assert.True(upsertIndex > 0 && dedupIndex > upsertIndex, "Duplicates must be removed after the source parameter is upserted.");
        Assert.Contains("AND stagedParameter.SourceRowGuid = other.Guid", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApply_PrefersTheRowsOwnGuidOverANameMatchAndRetiresTheStaleDuplicate()
    {
        // CYB-574: Quote AgentAccountId etc. were updated through a same-name duplicate on
        // SSop.Quotes on every run while the real (same-Guid) row stayed on Quote_ExtendedInfo.
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");

        Assert.Contains("AND NOT EXISTS (SELECT 1 FROM SCore.EntityProperties AS ownRow WHERE ownRow.Guid = @Guid)", apply, StringComparison.Ordinal);
        Assert.Contains("AND NOT EXISTS (SELECT 1 FROM SUserInterface.GridViewColumnDefinitions AS ownRow WHERE ownRow.Guid = @Guid)", apply, StringComparison.Ordinal);
        Assert.Contains("AND stagedProperty.SourceRowGuid = blocker.Guid", apply, StringComparison.Ordinal);
        Assert.Contains("AND stagedColumn.SourceRowGuid = blocker.Guid", apply, StringComparison.Ordinal);

        // The grid primary-key unique index ignores RowStatus, so the retired column gives up the key.
        Assert.Contains("IsPrimaryKey = 0", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApply_WritesTheColumnsTheUpsertProceduresSkip()
    {
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var hobtUpsert = ReadProcedure("SCore.EntityHoBTUpsert.sql");
        var entityTypeUpsert = ReadProcedure("SCore.EntityTypeUpsert.sql");

        // Facts that make the extra writes necessary.
        Assert.DoesNotContain("RowStatus = @RowStatus", hobtUpsert, StringComparison.Ordinal);
        Assert.DoesNotContain("IsOnBoarding", entityTypeUpsert, StringComparison.Ordinal);

        Assert.Contains("SET RowStatus = ISNULL(@EH_RowStatus, hobt.RowStatus),", apply, StringComparison.Ordinal);
        Assert.Contains("EntityTypeID = ISNULL(entityType.ID, hobt.EntityTypeID)", apply, StringComparison.Ordinal);
        Assert.Contains("COL_LENGTH(N'SCore.EntityTypes', N'IsOnBoarding') IS NOT NULL", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApply_ConvergenceIsVerifiedAfterCommitWithStagesOwnComparison()
    {
        var verify = ReadProcedure("SMigration.MetadataApply_VerifyConvergence.sql");
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.Drift.cs");

        Assert.Contains("N'ApplyDidNotConverge'", verify, StringComparison.Ordinal);
        Assert.Contains("EXEC SMigration.MetadataStage_NormaliseDifferences", verify, StringComparison.Ordinal);
        Assert.Contains("DELETE FROM SMigration.Metadata_Run", verify, StringComparison.Ordinal);
        Assert.DoesNotContain("THROW", verify, StringComparison.Ordinal);

        // Called only after both apply transactions committed, never inside them.
        var commitIndex = repository.IndexOf("await targetTransaction.CommitAsync", StringComparison.Ordinal);
        var verifyIndex = repository.IndexOf("await TryVerifyApplyConvergenceAsync(targetConnection, runGuid", StringComparison.Ordinal);
        Assert.True(commitIndex > 0 && verifyIndex > commitIndex, "Convergence must be verified after the apply commits.");
        Assert.Contains("new SqlCommand(\"SMigration.MetadataApply_VerifyConvergence\", connection)", repository, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApply_AdoptsGeneratedQueryParametersInsteadOfDuplicatingThem()
    {
        // CYB-574: SCore.EntityQueryUpsert regenerates the parameters of a non-manual query under
        // NEWID() Guids; inserting the source parameter as well left two '@Guid' rows on QA2.
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var queryUpsert = ReadProcedure("SCore.EntityQueryUpsert.sql");

        Assert.Contains("MERGE SCore.EntityQueryParameters AS tgt", queryUpsert, StringComparison.Ordinal);
        Assert.Contains("AND targetParameter.Name = @EQP_Name", apply, StringComparison.Ordinal);
        Assert.Contains("SET Guid = @EntityQueryParameterGuid", apply, StringComparison.Ordinal);
        Assert.Contains("stagedParameter.SourceRowGuid = targetParameter.Guid", apply, StringComparison.Ordinal);

        var adoptIndex = apply.IndexOf("SET Guid = @EntityQueryParameterGuid", StringComparison.Ordinal);
        var upsertIndex = apply.IndexOf("EXEC SCore.EntityQueryParameterUpsert", StringComparison.Ordinal);
        Assert.True(adoptIndex < upsertIndex, "The generated parameter must be adopted before the source parameter is upserted.");
    }

    [Fact]
    public void GridViewColumnMissingFromQuery_SkipsSelectStarGrids()
    {
        var sql = ReadProcedure("SMigration.MetadataValidate_Run.sql");

        // This check is a text-presence heuristic (word-boundary search over the SqlQuery
        // string), not a real result-set comparison. A SELECT * (optionally alias-/schema-
        // qualified, e.g. "root_hobt.*") never spells out any column name in the query text at
        // all, so the heuristic can never find one and would otherwise flag every active column
        // of every select-star grid as missing - confirmed live in CymBuild_DEV against real,
        // working grids (SUserInterface.GridViewDefinitions 'ENGJOBSFINANCE', 'WORKFLOWSTATUS'),
        // not evidence of a genuine query defect. The star must be searched for only in the
        // portion of the query before the first standalone FROM keyword, so a '*' used as
        // multiplication in a later WHERE/JOIN condition is never mistaken for a projection.
        Assert.Contains("PATINDEX(N'%[^A-Za-z0-9_]FROM[^A-Za-z0-9_]%', uq.UpperQuery)", sql, StringComparison.Ordinal);
        Assert.Contains("PATINDEX(N'%[^A-Za-z0-9_]*[^A-Za-z0-9_]%', sl.SelectListText) = 0;", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApply_RechecksHandlerCoverageBeforeOpeningTransaction()
    {
        var sql = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var guardPosition = sql.IndexOf("THROW 52005", StringComparison.Ordinal);
        var transactionPosition = sql.IndexOf("BEGIN TRANSACTION", StringComparison.Ordinal);

        Assert.True(guardPosition >= 0, "Metadata apply does not contain the unsupported-handler execution guard.");
        Assert.True(
            transactionPosition > guardPosition,
            "The unsupported-handler guard must run before MetadataApply_Run opens its deployment transaction.");
        Assert.Contains("IF ISNULL(@ApplySelectedOnly, 0) <> 1", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("ISNULL(@ApplySelectedOnly, 0) = 0", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_RunSelections", sql, StringComparison.Ordinal);

        AssertControlledTableAllowList(sql);
    }

    [Fact]
    public void MetadataApply_RejectsValidateOnlyRunsBeforeOpeningTransaction()
    {
        var sql = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var guardPosition = sql.IndexOf("THROW 52006", StringComparison.Ordinal);
        var transactionPosition = sql.IndexOf("BEGIN TRANSACTION", StringComparison.Ordinal);

        Assert.Contains("@IsValidateOnly = r.IsValidateOnly", sql, StringComparison.Ordinal);
        Assert.Contains("IF ISNULL(@IsValidateOnly, 1) = 1", sql, StringComparison.Ordinal);
        Assert.True(guardPosition >= 0, "Metadata apply does not reject validate-only runs.");
        Assert.True(
            transactionPosition > guardPosition,
            "The validate-only guard must run before MetadataApply_Run opens its deployment transaction.");
    }

    [Fact]
    public void MetadataApply_RequiresCurrentServerAcceptedPreviewFingerprint()
    {
        var sql = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var transactionPosition = sql.IndexOf("BEGIN TRANSACTION", StringComparison.Ordinal);
        var fingerprintPosition = sql.IndexOf("EXEC SMigration.MetadataApplyPreviewFingerprint_Get", StringComparison.Ordinal);
        var acceptanceGuardPosition = sql.IndexOf("THROW 52007", StringComparison.Ordinal);
        var applyStartPosition = sql.IndexOf("@StepName = N'ApplyStart'", StringComparison.Ordinal);

        Assert.Contains("N'ApplyPreviewAcceptance'", sql, StringComparison.Ordinal);
        Assert.Contains("$.previewFingerprint", sql, StringComparison.Ordinal);
        Assert.Contains("$.applySelectedOnly", sql, StringComparison.Ordinal);
        Assert.True(transactionPosition >= 0, "Metadata apply does not open a controlled deployment transaction.");
        Assert.True(fingerprintPosition > transactionPosition, "The accepted preview fingerprint must be recomputed inside the deployment transaction.");
        Assert.True(acceptanceGuardPosition > fingerprintPosition, "Apply must reject a missing or stale preview acceptance after recomputing its fingerprint.");
        Assert.True(applyStartPosition > acceptanceGuardPosition, "Apply must enforce preview acceptance before recording or performing deployment work.");
    }

    [Fact]
    public void MetadataPreviewFingerprint_BindsAllMutableApplyScopeInputs()
    {
        var sql = ReadProcedure("SMigration.MetadataApplyPreviewFingerprint_Get.sql");

        Assert.Contains("@ApplySelectedOnly", sql, StringComparison.Ordinal);
        Assert.Contains("@ValidatedOnUtc", sql, StringComparison.Ordinal);
        Assert.Contains("sr.SourcePayloadHash", sql, StringComparison.Ordinal);
        Assert.Contains("sr.TargetPayloadHash", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_RunSelections", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IgnoredRecords", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IdentityMapOverrides", sql, StringComparison.Ordinal);
        Assert.Contains("WITH (HOLDLOCK)", sql, StringComparison.Ordinal);
        Assert.Contains("HASHBYTES", sql, StringComparison.Ordinal);
        Assert.Contains("'SHA2_256'", sql, StringComparison.Ordinal);
        Assert.Contains("WITHIN GROUP", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataPreviewAcceptance_FollowsUiFormHelperGrpcEfSqlBoundary()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var service = ReadMetadataMigrationService();
        var efRepository = ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.cs")
            + ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.Drift.cs");
        var apiProgram = ReadRepositoryFile("services", "Concursus.API", "Program.cs");
        var acceptanceSql = ReadProcedure("SMigration.MetadataApplyPreview_Accept.sql");

        Assert.Contains("Accept for Deployment", ui, StringComparison.Ordinal);
        Assert.Contains("CurrentFormHelper.MetadataMigrationApplyPreviewAcceptAsync", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("@bind=\"ApplyPreviewReviewed\"", ui, StringComparison.Ordinal);
        Assert.Contains("_coreClient.MetadataMigrationApplyPreviewAcceptAsync", formHelper, StringComparison.Ordinal);
        Assert.Contains("rpc MetadataMigrationApplyPreviewAccept", proto, StringComparison.Ordinal);
        Assert.Contains("_metadataMigrationRepository.AcceptApplyPreviewAsync", service, StringComparison.Ordinal);
        Assert.Contains("SMigration.MetadataApplyPreview_Accept", efRepository, StringComparison.Ordinal);
        Assert.Contains("AddScoped<MetadataMigrationRepository>", apiProgram, StringComparison.Ordinal);
        Assert.Contains("@ExpectedPreviewFingerprint", acceptanceSql, StringComparison.Ordinal);
        Assert.Contains("@StepName = N'ApplyPreviewAcceptance'", acceptanceSql, StringComparison.Ordinal);
        Assert.Contains("SMigration.MetadataExecutionLog_Add", acceptanceSql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataPreviewAcceptance_UsesAnExplicitEfRepositoryAlias()
    {
        var coreService = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.cs");

        Assert.Contains(
            "using MetadataMigrationRepository = Concursus.EF.MetadataMigrationRepository;",
            coreService,
            StringComparison.Ordinal);
        Assert.DoesNotContain("using Concursus.EF;", coreService, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataDeploymentFingerprint_BindsScopeSourceAndTargetSnapshots()
    {
        var fingerprintSql = ReadProcedure("SMigration.MetadataApplyPreviewFingerprint_Get.sql");
        var acceptanceSql = ReadProcedure("SMigration.MetadataApplyPreview_Accept.sql");
        var previewSql = ReadProcedure("SMigration.MetadataApplyPreview_Get.sql");
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        Assert.Contains("@SourceSnapshotFingerprint", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("@TargetSnapshotFingerprint", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("@ScopeFingerprint VARBINARY(32) OUTPUT", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("N'scope='", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("N'|source='", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("N'|target='", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("THROW 52918", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("THROW 52919", fingerprintSql, StringComparison.Ordinal);

        foreach (var sql in new[] { acceptanceSql, previewSql, applySql })
        {
            Assert.Contains("@SourceSnapshotFingerprint", sql, StringComparison.Ordinal);
            Assert.Contains("@TargetSnapshotFingerprint", sql, StringComparison.Ordinal);
            Assert.Contains("@ScopeFingerprint", sql, StringComparison.Ordinal);
        }

        Assert.Contains("$.scopeFingerprint", acceptanceSql, StringComparison.Ordinal);
        Assert.Contains("$.sourceSnapshotFingerprint", acceptanceSql, StringComparison.Ordinal);
        Assert.Contains("$.targetSnapshotFingerprint", acceptanceSql, StringComparison.Ordinal);
        Assert.Contains("$.sourceSnapshotFingerprint", applySql, StringComparison.Ordinal);
        Assert.Contains("$.targetSnapshotFingerprint", applySql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApply_RetiredQueryParameterKeepsTargetReferencesTheSourceCannotResolve()
    {
        // 2026-10-12 UAT_Test run C7CA0A7D: retiring @QuoteJobType, whose mapped property is
        // retired in both environments and never staged, wrote NULL into MappedEntityPropertyID.
        var apply = NormaliseNewLines(ReadProcedure("SMigration.MetadataApply_Run.sql"));

        var lookup = apply.IndexOf("AND lookup.SourceRowId = @EQP_SourceMappedEntityPropertyID;", StringComparison.Ordinal);
        var fallback = apply.IndexOf("IF @EQP_RowStatus IN (0,254)\n    BEGIN", lookup, StringComparison.Ordinal);
        var upsert = apply.IndexOf("EXEC SCore.EntityQueryParameterUpsert", lookup, StringComparison.Ordinal);
        Assert.True(lookup > 0 && fallback > lookup && upsert > fallback, "The retirement fallback must run between the source lookup and the upsert.");

        Assert.Contains("@EQP_MappedEntityPropertyGuid = ISNULL(@EQP_MappedEntityPropertyGuid, targetProperty.Guid)", apply, StringComparison.Ordinal);
        Assert.Contains("WHERE targetParameter.Guid = ISNULL(@EQP_OverrideTargetGuid, @Guid);", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataDriftValidation_FindsSelectedRetirementsInTheSource()
    {
        // 2026-10-12 UAT_Test run 9F02560B: the drift re-read was active-only, so a selected
        // retirement (source RowStatus 254) was never found and acceptance failed with "the source
        // payload changed after staging" for SCore.EntityProperties AgentAddressId.
        var repository = NormaliseNewLines(ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.Drift.cs"));

        Assert.Contains("sr.SourceRowStatus\n            FROM SMigration.Metadata_TableRegistry AS tr WITH (HOLDLOCK)", repository, StringComparison.Ordinal);
        Assert.Contains(".Where(row => row.SourceRowStatus == 254 && selectedSourceRowGuids.Contains(row.SourceRowGuid))", repository, StringComparison.Ordinal);
        Assert.Contains("retiredOnly: true).ConfigureAwait(false);", repository, StringComparison.Ordinal);
        Assert.Contains("? hasRowStatus ? \"WHERE s.[RowStatus] = 254\" : \"WHERE 1 = 0\"", repository, StringComparison.Ordinal);

        // The retired rows join the source set before it is indexed and fingerprinted.
        var addRetired = repository.IndexOf(".Concat(retiredSourceRows.Where(row => selectedRetirementGuids.Contains(row.RowGuid)))", StringComparison.Ordinal);
        var index = repository.IndexOf("var sourceByGuid = BuildUniquePayloadIndex(sourceRows", StringComparison.Ordinal);
        Assert.True(addRetired > 0 && index > addRetired, "Selected retirements must be added before the source rows are indexed.");
    }

    [Fact]
    public void MetadataDriftValidation_ReReadsAndLocksBothEndpointsBeforeApply()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.Drift.cs");
        var snapshotPosition = repository.IndexOf("ReadAndValidateDriftSnapshotAsync(", StringComparison.Ordinal);
        var applyPosition = repository.IndexOf("ExecuteApplyAsync(", snapshotPosition, StringComparison.Ordinal);

        Assert.Contains("IsolationLevel.Serializable", repository, StringComparison.Ordinal);
        Assert.Contains("sourceTransaction", repository, StringComparison.Ordinal);
        Assert.Contains("targetTransaction", repository, StringComparison.Ordinal);
        Assert.Contains("FROM {objectName} AS s WITH (HOLDLOCK)", repository, StringComparison.Ordinal);
        Assert.Contains("PayloadsEquivalent", repository, StringComparison.Ordinal);
        Assert.Contains("ValidateStoredPayloadHash", repository, StringComparison.Ordinal);

        // Apply is always selected-row scoped (EnsureSelectedOnly), so drift validation only
        // considers registries with at least one selected row this run, and only the rows
        // actually selected - a table nobody selected anything from isn't being applied, so its
        // live state (schema, row set, unrelated row changes) can't block this run.
        Assert.Contains("ReadSelectedSourceRowGuidsAsync", repository, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_RunSelections", repository, StringComparison.Ordinal);
        Assert.Contains("selectedSourceRowGuids.Contains(row.SourceRowGuid)", repository, StringComparison.Ordinal);

        // Rows Stage_Run excluded for colliding with a different target row on some other unique
        // key (DuplicateTargetKey) are, by definition, never staged - the live source re-read
        // must also exclude them from this comparison, or a selected row referencing one of these
        // known, already-flagged conflicts would misfire drift even though nothing actually
        // drifted.
        Assert.Contains("KeyConflictSourceRowGuids", repository, StringComparison.Ordinal);
        Assert.Contains("N'DuplicateTargetKey'", repository, StringComparison.Ordinal);
        Assert.Contains("N'UnresolvedReference'", repository, StringComparison.Ordinal);
        Assert.Contains("MetadataMigrationDriftException", repository, StringComparison.Ordinal);
        Assert.True(snapshotPosition >= 0, "The EF repository does not re-read the live migration snapshot.");
        Assert.True(applyPosition > snapshotPosition, "The live drift snapshot must be validated before MetadataApply_Run executes.");
    }

    [Fact]
    public void MetadataPreviewAcceptanceAndApply_UseTheEfRepository()
    {
        var service = ReadMetadataMigrationService();
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.Drift.cs");

        Assert.Contains("_metadataMigrationRepository.GetApplyPreviewAsync", service, StringComparison.Ordinal);
        Assert.Contains("_metadataMigrationRepository.AcceptApplyPreviewAsync", service, StringComparison.Ordinal);
        Assert.Contains("_metadataMigrationRepository.ApplyAsync", service, StringComparison.Ordinal);
        Assert.DoesNotContain("new SqlCommand(\"SMigration.MetadataApplyPreview_Get\"", service, StringComparison.Ordinal);
        Assert.DoesNotContain("new SqlCommand(\"SMigration.MetadataApply_Run\"", service, StringComparison.Ordinal);
        Assert.Contains("new SqlCommand(\"SMigration.MetadataApplyPreview_Get\"", repository, StringComparison.Ordinal);
        Assert.Contains("new SqlCommand(\"SMigration.MetadataApplyPreview_Accept\"", repository, StringComparison.Ordinal);
        Assert.Contains("new SqlCommand(\"SMigration.MetadataApply_Run\"", repository, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataDriftExceptionHandling_IsQualifiedInPartialServiceCompilationUnit()
    {
        var service = ReadMetadataMigrationService();
        const string qualifiedCatch =
            "catch (Concursus.EF.MetadataMigrationRepository.MetadataMigrationDriftException ex)";

        Assert.Equal(
            3,
            Regex.Matches(service, Regex.Escape(qualifiedCatch), RegexOptions.CultureInvariant).Count);
        Assert.DoesNotContain(
            "catch (MetadataMigrationRepository.MetadataMigrationDriftException ex)",
            service,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataAuditUi_SurfacesRecordConflictsSeparatelyFromStructuralIssues()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");

        // The four record-scoped conflict codes get lost among structural issues
        // (RunNotFound, RegisteredTableMissing, ...) in the general Validation Issues table -
        // they need their own visible surface: a summary count and a dedicated panel that
        // reuses the existing ignore/restore mechanism rather than inventing a new one.
        Assert.Contains("ConflictIssueCodes", ui, StringComparison.Ordinal);
        Assert.Contains("\"DuplicateSourceGuid\"", ui, StringComparison.Ordinal);
        Assert.Contains("\"DuplicateTargetGuid\"", ui, StringComparison.Ordinal);
        Assert.Contains("\"DuplicateTargetKey\"", ui, StringComparison.Ordinal);
        Assert.Contains("\"UnresolvedReference\"", ui, StringComparison.Ordinal);
        Assert.Contains("SummaryCard(\"Conflicts\", ConflictCount,", ui, StringComparison.Ordinal);
        Assert.Contains("private RenderFragment ConflictsPanel()", ui, StringComparison.Ordinal);
        Assert.Contains("ToggleValidationIssueIgnoreAsync(row)", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataWorkbench_DoesNotGenerateDirectApplySql()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");

        Assert.Contains("Direct SQL preview, acceptance and Apply are intentionally unsupported.", ui, StringComparison.Ordinal);
        Assert.Contains("controlled FormHelper -> gRPC -> EF path", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("builder.AppendLine($\"-- EXEC SMigration.MetadataApply", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("return $\"EXEC SMigration.MetadataApply", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidatePreviewAndApply_AreSelectedOnlyAcrossEveryBoundary()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var service = ReadMetadataMigrationService();
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.Drift.cs");
        var validateSql = ReadProcedure("SMigration.MetadataValidate_Run.sql");
        var previewSql = ReadProcedure("SMigration.MetadataApplyPreview_Get.sql");
        var fingerprintSql = ReadProcedure("SMigration.MetadataApplyPreviewFingerprint_Get.sql");
        var acceptanceSql = ReadProcedure("SMigration.MetadataApplyPreview_Accept.sql");
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        Assert.Contains("Preview Selected", ui, StringComparison.Ordinal);
        Assert.Contains("Apply Selected", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("Preview All Valid", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("Apply All Valid", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("public async Task<string> MetadataMigrationApplyAsync(", formHelper, StringComparison.Ordinal);
        Assert.Contains("ApplySelectedOnly = true", formHelper, StringComparison.Ordinal);
        Assert.Equal(3, Regex.Matches(service, "if \\(!request\\.ApplySelectedOnly\\)", RegexOptions.CultureInvariant).Count);
        Assert.Contains("EnsureSelectedOnly(applySelectedOnly);", repository, StringComparison.Ordinal);

        Assert.Contains("N'NoSelectedRows'", validateSql, StringComparison.Ordinal);
        Assert.Contains("#MetadataSelectedValidationRows", validateSql, StringComparison.Ordinal);
        foreach (var sql in new[] { previewSql, fingerprintSql, acceptanceSql, applySql })
        {
            Assert.Contains("@ApplySelectedOnly BIT = 1", sql, StringComparison.Ordinal);
            Assert.Contains("IF ISNULL(@ApplySelectedOnly, 0) <> 1", sql, StringComparison.Ordinal);
            Assert.DoesNotContain("ISNULL(@ApplySelectedOnly, 0) = 0", sql, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void MetadataIgnoredRows_CannotRemainInTheSelectedScope()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var selectionSql = ReadProcedure("SMigration.MetadataRunSelection_Upsert.sql");
        var clearSelectionSql = ReadProcedure("SMigration.MetadataRunSelection_Clear.sql");
        var ignoredSql = ReadProcedure("SMigration.MetadataIgnoredRecord_Upsert.sql");

        Assert.Contains("!row.IsIgnored", ui, StringComparison.Ordinal);
        Assert.Contains("Ignored metadata records cannot be selected", selectionSql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IgnoredRecords", selectionSql, StringComparison.Ordinal);
        Assert.Contains("ValidatedOnUtc = NULL", selectionSql, StringComparison.Ordinal);
        Assert.Contains("ValidatedOnUtc = NULL", clearSelectionSql, StringComparison.Ordinal);
        Assert.Contains("EXEC SMigration.MetadataRunSelection_Upsert", ignoredSql, StringComparison.Ordinal);
        Assert.Contains("@IsSelected = 0", ignoredSql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidationIssueIgnore_FollowsUiFormHelperGrpcEfSqlBoundary()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var service = ReadMetadataMigrationService();
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigrationRepository.cs");
        var ignoreSql = ReadProcedure("SMigration.MetadataValidationIssueIgnore_Upsert.sql");

        Assert.Contains("CurrentFormHelper.MetadataMigrationValidationIssueIgnoreUpsertAsync", ui, StringComparison.Ordinal);
        Assert.Contains("_coreClient.MetadataMigrationValidationIssueIgnoreUpsertAsync", formHelper, StringComparison.Ordinal);
        Assert.Contains("rpc MetadataMigrationValidationIssueIgnoreUpsert", proto, StringComparison.Ordinal);
        Assert.Contains("_metadataMigrationRepository.UpsertValidationIssueIgnoreAsync", service, StringComparison.Ordinal);
        Assert.DoesNotContain("new SqlCommand(\"SMigration.MetadataValidationIssueIgnore_Upsert\"", service, StringComparison.Ordinal);
        Assert.Contains("new SqlCommand(\"SMigration.MetadataValidationIssueIgnore_Upsert\"", repository, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE [SMigration].[MetadataValidationIssueIgnore_Upsert]", ignoreSql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataValidationIssueIgnore_IsPersistentAuditedAndLimitedToSafeRecordIssues()
    {
        var tableSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables",
            "SMigration.Metadata_ValidationIssueIgnores.sql");
        var ignoreSql = ReadProcedure("SMigration.MetadataValidationIssueIgnore_Upsert.sql");
        var validateSql = ReadProcedure("SMigration.MetadataValidate_Run.sql");
        var previewSql = ReadProcedure("SMigration.MetadataApplyPreview_Get.sql");
        var acceptanceSql = ReadProcedure("SMigration.MetadataApplyPreview_Accept.sql");
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        Assert.Contains("[DatabaseName]", tableSql, StringComparison.Ordinal);
        Assert.Contains("[RegistryGuid]", tableSql, StringComparison.Ordinal);
        Assert.Contains("[SourceRowGuid]", tableSql, StringComparison.Ordinal);
        Assert.Contains("[IssueCode]", tableSql, StringComparison.Ordinal);
        Assert.Contains("[Reason]", tableSql, StringComparison.Ordinal);
        Assert.Contains("[IgnoredByUserId]", tableSql, StringComparison.Ordinal);
        Assert.Contains("[IgnoredOnUtc]", tableSql, StringComparison.Ordinal);
        Assert.Contains("WHERE [RowStatus] <> 0 AND [RowStatus] <> 254", tableSql, StringComparison.Ordinal);

        Assert.Contains("@IssueCode NOT IN (N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')", ignoreSql, StringComparison.Ordinal);
        Assert.Contains("An ignore reason is required for audit", ignoreSql, StringComparison.Ordinal);
        Assert.Contains("EXEC SMigration.MetadataDataObject_Ensure", ignoreSql, StringComparison.Ordinal);
        Assert.Contains("EXEC SMigration.MetadataExecutionLog_Add", ignoreSql, StringComparison.Ordinal);
        Assert.Contains("ValidatedOnUtc = NULL", ignoreSql, StringComparison.Ordinal);

        foreach (var sql in new[] { validateSql, previewSql, acceptanceSql, applySql })
        {
            Assert.Contains("SMigration.Metadata_ValidationIssueIgnores", sql, StringComparison.Ordinal);
            Assert.Contains("N'DuplicateSourceGuid'", sql, StringComparison.Ordinal);
            Assert.Contains("N'DuplicateTargetGuid'", sql, StringComparison.Ordinal);
            Assert.Contains("N'DuplicateTargetKey'", sql, StringComparison.Ordinal);
            Assert.Contains("N'UnresolvedReference'", sql, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void MetadataStageRun_CascadesExclusionThroughRegisteredForeignKeys()
    {
        var stageSql = ReadProcedure("SMigration.MetadataStage_Run.sql");

        // Excluding a conflicting row is correct, but anything that references it by foreign key
        // (e.g. an EntityProperties row whose EntityHoBTID points at an excluded EntityHobts row)
        // would otherwise silently try to apply an orphaned reference. Registries are processed
        // in ApplyOrder - the same dependency order Apply itself relies on - so a parent table's
        // exclusions are already recorded by the time a child table's cascade check runs.
        Assert.Contains("N'UnresolvedReference'", stageSql, StringComparison.Ordinal);
        Assert.Contains("cascade_fk_cursor", stageSql, StringComparison.Ordinal);
        Assert.Contains("sys.foreign_key_columns", stageSql, StringComparison.Ordinal);

        // The cascade must only follow foreign keys into other tables this pipeline actually
        // migrates - anything else (e.g. a core system table) has no Guid-based identity to
        // resolve across environments and is out of scope.
        Assert.Contains("EXISTS", stageSql, StringComparison.Ordinal);
        Assert.Contains("refTr.IsEnabled = 1", stageSql, StringComparison.Ordinal);

        // Rows flagged as unresolved references must never enter Metadata_StagedRows.
        Assert.Contains(
            "vi.IssueCode IN (N''DuplicateTargetKey'', N''UnresolvedReference'')",
            stageSql,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyRun_GuardsEntityHoBTResolutionBeforeInsertingEntityProperties()
    {
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        // EntityDataType, EntityPropertyGroup and DropDownListDefinition were already guarded
        // with a clear THROW when their lookup fails to resolve; EntityHoBTID had the identical
        // lookup pattern but no guard, so an unresolved reference reached SCore.EntityPropertyUpsert
        // as a raw NULL and failed with an opaque "Cannot insert the value NULL" constraint error
        // instead of a diagnosable message.
        Assert.Contains("IF @EP_EntityHoBTGuid IS NULL", applySql, StringComparison.Ordinal);
        Assert.Contains("EntityProperties apply could not resolve EntityHoBT source ID", applySql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyRun_SourceGuidLookupPrefersTheNaturalisedTargetGuid()
    {
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        // SMigration.MetadataStage_NormaliseDifferences can match a staged row onto an existing
        // target row by natural key (e.g. EntityProperties by EntityHoBTID+Name) when the source
        // and target Guids differ, classifying it NoChange with TargetPayloadJson pointing at
        // that existing target row. A NoChange row is never revisited by any per-table apply
        // cursor, so #MetadataSourceGuidLookup must be seeded with the already-resolved target
        // Guid up front - any other table's foreign key resolving through this lookup would
        // otherwise get the source's own Guid, which need not exist in target at all, and fail
        // on a NOT NULL foreign key instead of resolving correctly.
        Assert.Contains(
            "JSON_VALUE(sr.TargetPayloadJson, N'$.' + tr.GuidColumnName)",
            applySql,
            StringComparison.Ordinal);
        Assert.Contains("COALESCE(", applySql, StringComparison.Ordinal);

        // A persistent manual Metadata_IdentityMapOverrides mapping is the same kind of gap:
        // Stage_Run's generic capture does not consult this table at all, so the row stages as a
        // plain Insert with TargetPayloadJson NULL even though it must resolve to the override's
        // target Guid. The override must win over the naturalised-target-payload Guid since it is
        // an explicit, reviewed operator decision. Unlike a NoChange row, an overridden row IS
        // still revisited by its own per-table apply cursor (see
        // MetadataApplyRun_AppliesOverriddenRowsAsUpdatesToTheirMappedTarget below) so that its
        // field content actually reaches the mapped target record.
        Assert.Contains("override.TargetRowGuid,", applySql, StringComparison.Ordinal);
        Assert.Contains("LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS override", applySql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyRun_AppliesOverriddenRowsAsUpdatesToTheirMappedTarget()
    {
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        // A manual Identity Map override means "apply this row's content as an update to the
        // record I matched it to," not "never touch it." #MetadataRowsToApply must therefore
        // include overridden rows (it only ever excluded ignored records), and the
        // handler-coverage guard must stop exempting them too - an override on a table with no
        // controlled apply handler must still block the apply, not silently do nothing forever.
        // Both guards previously named their override-exclusion join alias uniquely
        // ("overrideApply" and "identityOverride" respectively) - neither must remain anywhere.
        Assert.Contains("INSERT INTO #MetadataRowsToApply", applySql, StringComparison.Ordinal);
        Assert.Contains("THROW 52005", applySql, StringComparison.Ordinal);
        Assert.DoesNotContain("overrideApply", applySql, StringComparison.Ordinal);
        Assert.DoesNotContain("identityOverride", applySql, StringComparison.Ordinal);

        // Every controlled per-table apply cursor must resolve its own row's identity through the
        // override before upserting - not just the shared #MetadataSourceGuidLookup used to
        // resolve OTHER tables' foreign keys pointing at it.
        // "AS ov" (not the original FK-lookup join's "AS override") appears once per per-table
        // apply cursor, plus once in the CYB-564 retirement pass (which retires the override's
        // mapped target row); \b avoids also matching "AS override" as a prefix.
        Assert.Equal(ControlledApplyTables.Length + 1, Regex.Matches(applySql, @"Metadata_IdentityMapOverrides AS ov\b", RegexOptions.CultureInvariant).Count);
        Assert.Contains("ISNULL(@ET_OverrideTargetGuid, @Guid)", applySql, StringComparison.Ordinal);
        Assert.Contains("ISNULL(@EPD_OverrideTargetGuid, @Guid)", applySql, StringComparison.Ordinal);
        Assert.Contains("ISNULL(@EQP_OverrideTargetGuid, @Guid)", applySql, StringComparison.Ordinal);
        Assert.Contains("ISNULL(@MT_OverrideTargetGuid, @Guid)", applySql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyPreview_ShowsOverriddenRowsAsApplyNotSkip()
    {
        var previewSql = ReadProcedure("SMigration.MetadataApplyPreview_Get.sql");

        // Since MetadataApply_Run now applies an overridden row as an update to its mapped
        // target, the preview must say so too - showing "Skip" here while apply actually does
        // something would make the preview lie about what deployment will do.
        Assert.DoesNotContain("WHEN ov.Guid IS NOT NULL THEN N'Skip'", previewSql, StringComparison.Ordinal);
        Assert.Contains(
            "WHEN ov.Guid IS NOT NULL THEN N'Record has a manual identity-map target match - applies as an update to that mapped target record.'",
            previewSql,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataPreviewFingerprint_BindsTheOverrideTargetSoAChangedMappingInvalidatesAcceptance()
    {
        var fingerprintSql = ReadProcedure("SMigration.MetadataApplyPreviewFingerprint_Get.sql");

        // The fingerprint's row-set must match MetadataApply_Run's #MetadataRowsToApply exactly,
        // so it can no longer exclude overridden rows either - but simply including them isn't
        // enough: an override's own TargetRowGuid must feed the per-row hash, or an operator
        // adding/changing/removing a mapping between preview-acceptance and apply would go
        // undetected, silently changing what apply does without invalidating the accepted
        // preview.
        Assert.Contains("LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS identityOverride", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("overrideTargetRowGuid=", fingerprintSql, StringComparison.Ordinal);
        Assert.Contains("identityOverride.TargetRowGuid", fingerprintSql, StringComparison.Ordinal);

        // The row-set's WHERE clause must exclude ignored records only - a second "NOT EXISTS"
        // there (as before) would mean overridden rows are still being dropped from the count.
        var rowSetStart = fingerprintSql.IndexOf("FROM SMigration.Metadata_StagedRows AS sr WITH (HOLDLOCK)", StringComparison.Ordinal);
        var rowSetEnd = fingerprintSql.IndexOf("SET @ApplyCount", StringComparison.Ordinal);
        var rowSetSql = fingerprintSql.Substring(rowSetStart, rowSetEnd - rowSetStart);

        Assert.Single(Regex.Matches(rowSetSql, "NOT EXISTS", RegexOptions.CultureInvariant));
    }

    [Fact]
    public void MetadataStageRun_DetectsAndExcludesDuplicateGuidsOnBothEndpoints()
    {
        var stageSql = ReadProcedure("SMigration.MetadataStage_Run.sql");

        Assert.Contains("N'DuplicateSourceGuid'", stageSql, StringComparison.Ordinal);
        Assert.Contains("N'DuplicateTargetGuid'", stageSql, StringComparison.Ordinal);
        Assert.Contains("Target metadata table contains duplicate active Guid values", stageSql, StringComparison.Ordinal);

        // Duplicate-Guid rows on either endpoint must never enter Metadata_StagedRows -
        // they need manual correction, not an automatic insert/update.
        Assert.Contains("AND NOT EXISTS", stageSql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataStageRun_DetectsOtherUniqueKeyCollisionsAcrossEnvironments()
    {
        var stageSql = ReadProcedure("SMigration.MetadataStage_Run.sql");

        // A registered table's uniqueness is not limited to its identity Guid (e.g. EntityTypes
        // also enforces a Name+RowStatus natural key). DEV and QA can independently create a row
        // with the same natural-key value under two different Guids; applying the DEV row would
        // then fail with a raw unique-constraint violation at Apply instead of a reviewable,
        // ignorable issue surfaced before Apply is ever attempted.
        Assert.Contains("N'DuplicateTargetKey'", stageSql, StringComparison.Ordinal);
        Assert.Contains("other_unique_index_cursor", stageSql, StringComparison.Ordinal);
        Assert.Contains("i.is_unique = 1", stageSql, StringComparison.Ordinal);

        // A table's surrogate auto-increment primary key must be excluded the same way the
        // identity Guid is - comparing two environments' ID values is meaningless and produces
        // false-positive collisions on every table with more than a handful of rows.
        Assert.Contains(
            "icc.SoleColumnName IN (@GuidColumnName, @PrimaryKeyColumnName)",
            stageSql,
            StringComparison.Ordinal);

        // A unique index keyed off another table's surrogate ID via a foreign key (e.g.
        // EntityHoBTID) is just as environment-specific as a raw primary key and must also be
        // excluded - except RowStatus, a fixed reference domain already treated as universally
        // comparable throughout this pipeline.
        Assert.Contains("sys.foreign_key_columns", stageSql, StringComparison.Ordinal);
        Assert.Contains("icc.HasForeignKeyColumn = 0", stageSql, StringComparison.Ordinal);
        Assert.Contains("c.name <> N'RowStatus'", stageSql, StringComparison.Ordinal);

        // Rows flagged with a conflicting natural key must never enter Metadata_StagedRows -
        // matching how duplicate Guids are excluded.
        Assert.Contains("vi.IssueCode IN (N''DuplicateTargetKey'', N''UnresolvedReference'')", stageSql, StringComparison.Ordinal);
    }

    [Fact]
    public void CrossServerStaging_AlsoDetectsOtherUniqueKeyCollisionsAcrossEnvironments()
    {
        var service = ReadMetadataMigrationService();

        // MetadataStage_Run.sql's other_unique_index_cursor detects this via a three-part
        // cross-database join, which only works when source and target are on the SAME SQL
        // Server instance. The two-connection path (StageMetadataWithTwoConnectionsAsync, used
        // for genuinely cross-server pairs like DEV->UAT) had no equivalent at all - a row like
        // SCore.EntityTypes 'Critical Project Notes' could collide on the Name+RowStatus natural
        // key under a different Guid on the target and sail straight through staging and
        // validation, only to fail as a raw "Cannot insert duplicate key row" SQL error at Apply.
        Assert.Contains("public static async Task<List<OtherUniqueIndexInfo>> ReadOtherUniqueIndexesAsync(", service, StringComparison.Ordinal);
        Assert.Contains("i.is_unique = 1", service, StringComparison.Ordinal);

        // Same identity exclusion as the same-server SQL path: the identity Guid/surrogate PK's
        // own index is never itself a natural key worth checking. Unlike the SQL path, a foreign
        // key column here is NOT a blanket exclusion any more - see
        // CrossServerStaging_ResolvesForeignKeyColumnsInCompositeUniqueKeys.
        Assert.Contains("NOT (icc.ColumnCount = 1 AND icc.SoleColumnName IN (@GuidColumnName, @PrimaryKeyColumnName))", service, StringComparison.Ordinal);

        // A conflicting row must be flagged (DuplicateTargetKey) and excluded from staging -
        // matching the existing DuplicateSourceGuid exclusion pattern - and the cleanup DELETE
        // must clear stale DuplicateTargetKey issues on re-stage the same way it already does for
        // DuplicateSourceGuid.
        Assert.Contains("\"DuplicateTargetKey\"", service, StringComparison.Ordinal);
        Assert.Contains("!duplicateGuids.Contains(row.RowGuid) && !duplicateTargetKeySourceGuids.Contains(row.RowGuid)", service, StringComparison.Ordinal);
        Assert.Contains("N'DuplicateTargetKey',", service, StringComparison.Ordinal);
    }

    [Fact]
    public void CrossServerStaging_CascadesExclusionThroughRegisteredForeignKeys()
    {
        var service = ReadMetadataMigrationService();

        // MetadataStage_Run.sql's cascade_fk_cursor detects this via a three-part cross-database
        // join and only runs for same-server pairs. The two-connection path had no equivalent -
        // confirmed live: a DEV->UAT run's SCore.EntityHobts row got excluded (DuplicateTargetKey),
        // but the SCore.EntityProperties row referencing it (EntityHoBTID) was never also
        // excluded, so it sailed through staging and validation clean and only failed as
        // "EntityProperties apply could not resolve EntityHoBT source ID 205 for property
        // CreatedBy" at Apply. Registries are processed in ApplyOrder (parent tables before
        // child tables), so a running per-table (SourceRowId -> Guid) map and a running per-table
        // excluded-Guid set, both keyed by "Schema.Table" and accumulated across the whole
        // registryRows loop, let a child's foreign key resolve to its parent's Guid and be
        // checked against that parent's own exclusions - transitively, across as many levels as
        // needed, the same guarantee MetadataStage_Run.sql relies on.
        Assert.Contains("public static async Task<List<ForeignKeyToRegisteredTableInfo>> ReadForeignKeysToRegisteredTablesAsync(", service, StringComparison.Ordinal);
        Assert.Contains("var idToGuidByTable = new Dictionary<string, Dictionary<long, Guid>>(StringComparer.OrdinalIgnoreCase);", service, StringComparison.Ordinal);
        Assert.Contains("var excludedGuidsByTable = new Dictionary<string, HashSet<Guid>>(StringComparer.OrdinalIgnoreCase);", service, StringComparison.Ordinal);

        // Same FK-metadata exclusions as the same-server SQL path: skip RowStatus, skip a
        // self-referencing FK, and only cascade into tables that are themselves registered and
        // enabled for this run.
        Assert.Contains("AND pc.name <> N'RowStatus'", service, StringComparison.Ordinal);
        Assert.Contains("AND NOT (rs.name = @SchemaName AND rt.name = @TableName)", service, StringComparison.Ordinal);
        Assert.Contains("FROM SMigration.Metadata_TableRegistry AS refTr", service, StringComparison.Ordinal);
        Assert.Contains("WHERE refTr.SchemaName = rs.name", service, StringComparison.Ordinal);

        // A cascaded row must be flagged (Warn/UnresolvedReference), excluded from staging, and
        // the cleanup DELETE must clear stale UnresolvedReference issues on re-stage the same way
        // it already does for DuplicateSourceGuid/DuplicateTargetKey.
        Assert.Contains("\"UnresolvedReference\"", service, StringComparison.Ordinal);
        Assert.Contains("!unresolvedReferenceSourceGuids.Contains(row.RowGuid)", service, StringComparison.Ordinal);
        Assert.Contains("N'UnresolvedReference',", service, StringComparison.Ordinal);
    }

    [Fact]
    public void CrossServerStaging_ResolvesForeignKeyColumnsInCompositeUniqueKeys()
    {
        var service = ReadMetadataMigrationService();

        // Both the same-server SQL path and the original two-connection C# port of it excluded a
        // unique index entirely the moment any of its columns was a foreign key (RowStatus
        // excepted) - comparing another table's raw auto-increment surrogate ID across
        // environments is meaningless. But that made the check a no-op for every composite
        // natural key that includes a foreign key column, e.g.
        // SUserInterface.GridViewDefinitions' GridDefinitionId+Code+RowStatus key - confirmed
        // live: a DEV->UAT run staged and validated clean, then failed at Apply with "Cannot
        // insert duplicate key row ... 'IX_UQ_GridViewDefinition_Code' ... (18, ENGJOBSFINANCE,
        // 1)". The same shape also silently goes unchecked on SCore.EntityProperties
        // (EntityHoBTID+Name+RowStatus), SCore.EntityPropertyDependants
        // (ParentEntityPropertyID+DependantPropertyID), SUserInterface.GridViewActions
        // (GridViewDefinitionId+EntityQueryId) and SUserInterface.GridViewWidgetQueries
        // (GridViewDefinitionId+EntityQueryId+WidgetTypeId) - confirmed live in CymBuild_DEV
        // against SMigration.Metadata_TableRegistry's actual enabled tables and their unique
        // indexes, not a guess. Rather than keep skipping these indexes, a foreign key column is
        // now resolved to the referenced row's Guid (via idToGuidByTable/targetIdToGuidByTable,
        // the same per-table maps the FK-cascade check already accumulates in ApplyOrder) so
        // source and target values become comparable; only a foreign key to a table outside the
        // enabled registry (e.g. the disabled SUserInterface.WidgetTypes) still disqualifies the
        // whole index, exactly as before, rather than guessing that its raw ID is safe to compare.
        Assert.Contains("public static string? BuildNaturalKeyWithForeignKeyResolution(", service, StringComparison.Ordinal);
        Assert.Contains("var targetIdToGuidByTable = new Dictionary<string, Dictionary<long, Guid>>(StringComparer.OrdinalIgnoreCase);", service, StringComparison.Ordinal);
        Assert.Contains("var enabledRegistryTableKeys = new HashSet<string>(", service, StringComparison.Ordinal);

        // The per-index skip must trigger only when a column's foreign key target falls outside
        // the enabled registry, not merely because it is a foreign key.
        Assert.Contains("column.ForeignKeyRefTableName is not null &&", service, StringComparison.Ordinal);
        Assert.Contains(
            "!enabledRegistryTableKeys.Contains($\"{column.ForeignKeyRefSchemaName}.{column.ForeignKeyRefTableName}\")",
            service,
            StringComparison.Ordinal);

        // Both sides of the comparison must resolve through the correct map: source rows via
        // idToGuidByTable, target rows via targetIdToGuidByTable - using the wrong map would
        // resolve a source-side ID against target-side Guids (or vice versa) and never match.
        Assert.Contains(
            "BuildNaturalKeyWithForeignKeyResolution(ParseJsonDictionary(targetRow.PayloadJson), index.Columns, targetIdToGuidByTable)",
            service,
            StringComparison.Ordinal);
        Assert.Contains(
            "BuildNaturalKeyWithForeignKeyResolution(ParseJsonDictionary(sourceRow.PayloadJson), index.Columns, idToGuidByTable)",
            service,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyIdentityMapBuild_SyncsRegistryScopeFromSourceNotTarget()
    {
        var sql = ReadProcedure("SMigration.MetadataApplyIdentityMap_Build.sql");

        // MetadataRegistry_SyncFromEntityTypes treats source EntityTypes as authoritative for
        // registry scope. Passing @SourceDatabaseName = NULL here falls back to the target
        // database's own (independently stale) EntityTypes.IsMetaData flags and silently
        // re-enables registry rows Stage had just correctly disabled from the source side.
        Assert.Contains("@SourceDatabaseName = r.SourceDatabaseName", sql, StringComparison.Ordinal);
        Assert.Contains("@SourceDatabaseName = @SourceDatabaseName,", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("@SourceDatabaseName = NULL,", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyIdentityMapBuild_CanSkipItsOwnSameServerOnlyRegistrySyncForCrossServerRuns()
    {
        var sql = ReadProcedure("SMigration.MetadataApplyIdentityMap_Build.sql");
        var service = ReadMetadataMigrationService();

        // Passing a non-NULL @SourceDatabaseName (the fix above) still isn't enough on its own:
        // MetadataRegistry_SyncFromEntityTypes resolves it via DB_ID(), which can only ever
        // reach a database on the SAME SQL Server instance this proc is executing on. For a
        // genuinely cross-server pair (DEV and UAT are different instances), DB_ID() of the
        // source database is always NULL here, so the proc's own internal sync silently falls
        // back to controlling scope from the TARGET's own (possibly stale) EntityTypes.IsMetaData
        // - independently disabling a table's registry row even when it's correctly enabled on
        // the true source, leaving every one of that table's staged rows unresolved regardless
        // of whether their Guids actually match target rows.
        Assert.Contains("@SkipRegistrySync BIT = 0", sql, StringComparison.Ordinal);
        Assert.Contains("IF ISNULL(@SkipRegistrySync, 0) = 0", sql, StringComparison.Ordinal);

        // The C# caller must detect the cross-server case, perform the real source-authoritative
        // sync itself over two genuine connections (the same fixed helper the two-connection
        // staging path uses), and tell the proc to skip its own sync so it doesn't immediately
        // undo that.
        Assert.Contains("public override async Task<MetadataMigrationBuildIdentityMapResponse> MetadataMigrationBuildIdentityMap(", service, StringComparison.Ordinal);
        Assert.Contains("await SyncMetadataRegistryFromEntityTypesAsync(sourceConnection, cn, runGuid, context.CancellationToken);", service, StringComparison.Ordinal);
        Assert.Contains("skipRegistrySync: true", service, StringComparison.Ordinal);
    }

    [Fact]
    public void CrossServerRegistrySync_TreatsSourceAsAuthoritativeAndCanDisable()
    {
        var service = ReadMetadataMigrationService();

        // The two-connection cross-server staging path (DEV<->UAT, different SQL Server
        // instances) has its own C# equivalent of MetadataRegistry_SyncFromEntityTypes.sql - it
        // previously unioned candidates from BOTH source and target and only ever enabled
        // registry rows, never disabled one. A table the target environment had independently
        // (and wrongly) flagged IsMetaData = 1 for stayed enabled in every cross-server run
        // regardless of the source's own flag - the opposite of "source is authoritative",
        // which every other sync path in this pipeline enforces (see
        // MetadataApplyIdentityMapBuild_SyncsRegistryScopeFromSourceNotTarget above).
        Assert.DoesNotContain("sourceCandidates.Concat(targetCandidates)", service, StringComparison.Ordinal);
        Assert.Contains(
            "await ReadMetadataRegistryCandidatesAsync(sourceConnection, cancellationToken)",
            service,
            StringComparison.Ordinal);

        // Candidates come from EntityHobts join alone (no IsMetaData = 1 filter in the query
        // itself) so both enabled and disabled tables are visible, letting the sync branch on
        // each candidate's own flag - the SQL-only path expresses this as one UPDATE that can set
        // IsEnabled to either 0 or 1; the C# path needs the same branch made explicit.
        Assert.DoesNotContain("AND ISNULL(et.IsMetaData, 0) = 1", service, StringComparison.Ordinal);
        Assert.Contains("CONVERT(BIT, ISNULL(et.IsMetaData, 0)) AS IsMetaData", service, StringComparison.Ordinal);
        Assert.Contains("if (candidate.IsMetaData)", service, StringComparison.Ordinal);
        Assert.Contains("await DisableMetadataRegistryCandidateAsync(targetConnection, tx, candidate, cancellationToken);", service, StringComparison.Ordinal);

        // Disabling must only ever update an existing, already-enabled row - never insert a new
        // disabled placeholder row, matching MetadataRegistry_SyncFromEntityTypes.sql's own
        // disable UPDATE (RowStatus NOT IN (0,254) AND IsEnabled = 1).
        Assert.Contains("SET IsEnabled = 0", service, StringComparison.Ordinal);
        Assert.Contains("WHERE SchemaName = @SchemaName", service, StringComparison.Ordinal);
        Assert.Contains("AND RowStatus NOT IN (0,254)", service, StringComparison.Ordinal);
        Assert.Contains("AND IsEnabled = 1;", service, StringComparison.Ordinal);
    }

    [Fact]
    public void IdentityMapOverride_SupportsColumnLevelSourceSelection()
    {
        var tableSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables",
            "SMigration.Metadata_IdentityMapOverrides.sql");
        var upsertSql = ReadProcedure("SMigration.MetadataIdentityMapOverride_Upsert.sql");

        Assert.Contains("[ColumnSourceSelectionJson] [nvarchar](max) NULL", tableSql, StringComparison.Ordinal);

        // Default (NULL) must mean "apply all columns from source" - today's unchanged
        // behaviour - and the row's own identity Guid/primary key can never be selected for
        // override, since the whole point of mapping to an existing target row is that
        // identity differs and the target's own Guid/ID always wins.
        Assert.Contains("@ColumnSourceSelectionJson NVARCHAR(MAX) = NULL", upsertSql, StringComparison.Ordinal);
        Assert.Contains("SET @ColumnSourceSelectionJson = NULLIF(NULLIF(@ColumnSourceSelectionJson, N''), N'[]');", upsertSql, StringComparison.Ordinal);
        Assert.Contains("WHERE selection.[value] IN (@GuidColumnName, @PrimaryKeyColumnName)", upsertSql, StringComparison.Ordinal);
        Assert.Contains("THROW 52406", upsertSql, StringComparison.Ordinal);

        // Deactivating an override must clear its stored column selection too, not just the mapping.
        Assert.Contains("ov.ColumnSourceSelectionJson = NULL", upsertSql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataPreviewFingerprint_BindsTheColumnSourceSelectionSoAChangedSelectionInvalidatesAcceptance()
    {
        var fingerprintSql = ReadProcedure("SMigration.MetadataApplyPreviewFingerprint_Get.sql");

        Assert.Contains(
            "N'|overrideColumnSourceSelection=', ISNULL(identityOverride.ColumnSourceSelectionJson, N'<null>')",
            fingerprintSql,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyRun_MergesOverriddenColumnsPerCursorAcrossEveryControlledTable()
    {
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        // Every one of the controlled apply cursors must declare and fetch its own
        // <Prefix>_ColumnSourceSelectionJson variable - a table where this is silently missing
        // would mean column-level control looks available in the UI but has no effect for that
        // table. The two inline-DML tables (EntityDataTypes, Icons) branch with
        // "IS NULL OR EXISTS" per SET clause instead of an "IS NOT NULL" guard block, so the
        // variable declaration itself is the one marker common to both cursor shapes.
        Assert.Equal(
            ControlledApplyTables.Length,
            Regex.Matches(applySql, @"_ColumnSourceSelectionJson NVARCHAR\(MAX\)", RegexOptions.CultureInvariant).Count);

        // Representative proc-call table (EntityTypes): merge happens by re-reading the live
        // target row's scalar columns and conditionally overwriting the source-parsed local
        // variable before the Upsert call - never the override's own FK/lookup-derived
        // variables, since those are cross-environment identity references this pipeline is
        // specifically resolving, not target-environment-owned data.
        Assert.Contains("FROM SCore.EntityTypes AS targetrow", applySql, StringComparison.Ordinal);
        Assert.Contains(
            "IF @ET_TargetRowFound = 1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@ET_ColumnSourceSelectionJson) WHERE [value] = N'Name') SET @Name = @ET_Target_Name;",
            applySql,
            StringComparison.Ordinal);
        Assert.DoesNotContain("@ET_Target_LanguageLabelGuid", applySql, StringComparison.Ordinal);

        // Representative inline-DML table (EntityDataTypes, no dedicated Upsert proc): the
        // merge expresses as a CASE per SET clause referencing the table's own current column
        // value directly, rather than a separate live re-read.
        Assert.Contains(
            "Name = CASE WHEN @EDT_ColumnSourceSelectionJson IS NULL OR EXISTS (SELECT 1 FROM OPENJSON(@EDT_ColumnSourceSelectionJson) WHERE [value] = N'Name') THEN ISNULL(@EDT_Name, N'') ELSE Name END,",
            applySql,
            StringComparison.Ordinal);
    }

    [Fact]
    public void IdentityMapOverrideColumnSelection_FollowsUiFormHelperGrpcEfSqlBoundary()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var service = ReadMetadataMigrationService();

        Assert.Contains("string columnSourceSelectionJson = 10;", proto, StringComparison.Ordinal);
        Assert.Contains("string overrideColumnSourceSelectionJson = 21;", proto, StringComparison.Ordinal);
        Assert.Contains("string columnSourceSelectionJson = \"\",", formHelper, StringComparison.Ordinal);
        Assert.Contains("ColumnSourceSelectionJson = columnSourceSelectionJson ?? string.Empty", formHelper, StringComparison.Ordinal);
        Assert.Contains("@ColumnSourceSelectionJson", service, StringComparison.Ordinal);
        Assert.Contains("BuildIdentityMapColumnSourceSelectionJson()", ui, StringComparison.Ordinal);
        Assert.Contains("IdentityMapColumnUseSource", ui, StringComparison.Ordinal);

        // The Guid/ID identity columns must never be offered as selectable in the UI either,
        // matching the server-side validation in MetadataIdentityMapOverride_Upsert.
        Assert.Contains(
            "private static readonly HashSet<string> IdentityMapNonSelectableColumns = new(StringComparer.OrdinalIgnoreCase) { \"Guid\", \"ID\" };",
            ui,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataStageRun_StagesSourceRetirementsOnlyWhenOptedInAndTargetStillActive()
    {
        var sql = ReadProcedure("SMigration.MetadataStage_Run.sql");

        // CYB-564: a source row soft-deleted to 254 was never staged at all, so its still-active
        // copy in the target (confirmed live: duplicate Quote Client/Agent fields on UAT) was never
        // retired. Retirement is opt-in per run and default-off, preserving active-only staging.
        Assert.Contains("@IncludeRetirements BIT = 0", sql, StringComparison.Ordinal);
        Assert.Contains("WHEN @HasRowStatus = 1 AND ISNULL(@IncludeRetirements, 0) = 1", sql, StringComparison.Ordinal);

        // Source-only: a 254 source row is eligible only when the target still holds an active
        // row with the same Guid. Rows that exist only in the target are never touched.
        Assert.Contains("OR (s.RowStatus = 254 AND EXISTS (SELECT 1 FROM ' + QUOTENAME(@TargetDatabaseName)", sql, StringComparison.Ordinal);
        Assert.Contains("AND rt.RowStatus NOT IN (0,254))))'", sql, StringComparison.Ordinal);

        // The widened clause drives the staged insert and the FK-exclusion cascade; duplicate-Guid
        // detection stays active-only on @SourceWhereClause.
        Assert.Contains("' + @SourceStagedWhereClause + N'\n    ' + @SourceAndClause + N' NOT EXISTS", NormaliseNewLines(sql), StringComparison.Ordinal);
        Assert.Contains("N' = s.' + QUOTENAME(@CascadeFkColumnName) + N'\n    ' + @SourceStagedWhereClause + N'", NormaliseNewLines(sql), StringComparison.Ordinal);
        Assert.Contains("GROUP BY CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')\n    HAVING COUNT_BIG(1) > 1", NormaliseNewLines(sql), StringComparison.Ordinal);
        Assert.Contains("    ' + @SourceWhereClause + N'\n    GROUP BY CONVERT(UNIQUEIDENTIFIER, s.", NormaliseNewLines(sql), StringComparison.Ordinal);
    }

    [Fact]
    public void CrossServerStaging_StagesSourceRetirementsOnlyWhenOptedInAndTargetStillActive()
    {
        var service = ReadMetadataMigrationService();

        // Same contract as MetadataStage_Run @IncludeRetirements, for the two-connection path that
        // DEV->UAT and UAT->LIVE actually use.
        Assert.Contains("bool includeRetirements,", service, StringComparison.Ordinal);
        Assert.Contains("ReadMetadataPayloadRowsAsync(sourceConnection, null, registry, columnNames, false, cancellationToken, retiredOnly: true)", service, StringComparison.Ordinal);
        Assert.Contains("? \"WHERE s.[RowStatus] = 254\"", service, StringComparison.Ordinal);

        // A table without RowStatus has no retired rows - retiredOnly must never fall back to all rows.
        Assert.Contains("? retiredOnly ? \"WHERE 1 = 0\" : string.Empty", service, StringComparison.Ordinal);

        // Source-only: staged only when the same-Guid target row is still active.
        Assert.Contains("targetRow.RowStatus is not null and not 0 and not 254", service, StringComparison.Ordinal);

        // Retire candidates join the FK cascade and the staged rows, but never the duplicate-Guid
        // or natural-key checks (their natural key legitimately matches the active target row).
        Assert.Contains(".Concat(retireCandidateRows))", service, StringComparison.Ordinal);
        Assert.Contains(".Concat(retireCandidateRows.Where(row => !unresolvedReferenceSourceGuids.Contains(row.RowGuid))))", service, StringComparison.Ordinal);
        Assert.Contains("foreach (var sourceRow in sourceRows.Where(row =>\n                    !duplicateGuids.Contains(row.RowGuid) &&\n                    (sourceCoveredGuids is null", NormaliseNewLines(service), StringComparison.Ordinal);
    }

    [Fact]
    public void StageRetirementOptIn_FollowsUiFormHelperGrpcSqlBoundary()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var service = ReadMetadataMigrationService();

        Assert.Contains("bool includeRetirements = 4;", proto, StringComparison.Ordinal);
        Assert.Contains("bool includeRetirements = false,", formHelper, StringComparison.Ordinal);
        Assert.Contains("IncludeRetirements = includeRetirements", formHelper, StringComparison.Ordinal);
        Assert.Contains("includeRetirements: request.IncludeRetirements", service, StringComparison.Ordinal);
        Assert.Contains("new SqlParameter(\"@IncludeRetirements\", SqlDbType.Bit)", service, StringComparison.Ordinal);
        Assert.Contains("@bind=\"IncludeRetirements\"", ui, StringComparison.Ordinal);
        Assert.Contains("MetadataMigrationStageAsync(CurrentRunGuid(), TargetServerName, TargetDatabaseName, IncludeRetirements)", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyRun_EnforcesStagedRetirementsForEveryHandledTable()
    {
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");

        // LanguageLabelUpsert, LanguageLabelTranslationUpsert, EntityHoBTUpsert and
        // DropDownListDefinitionUpsert never write RowStatus, so a staged retirement would
        // otherwise be applied as a silent no-op. One generic pass runs after every handler.
        var retirementPass = applySql.IndexOf("Retirement pass (CYB-564)", StringComparison.Ordinal);
        Assert.True(retirementPass > applySql.IndexOf("@StepName = N'ApplyMilestoneTypes'", StringComparison.Ordinal));
        Assert.True(retirementPass < applySql.IndexOf("RunStatus = N'AppliedUiMetadata'", StringComparison.Ordinal));

        Assert.Contains("AND sr.SourceRowStatus = 254", applySql, StringComparison.Ordinal);
        Assert.Contains("INNER JOIN #MetadataRowsToApply AS applyRows\n    ON applyRows.StagedRowId = sr.ID\nLEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov", NormaliseNewLines(applySql), StringComparison.Ordinal);
        Assert.Contains("N' = ISNULL(ov.TargetRowGuid, sr.SourceRowGuid)", applySql, StringComparison.Ordinal);
        Assert.Contains("OR EXISTS (SELECT 1 FROM OPENJSON(ov.ColumnSourceSelectionJson) WHERE [value] = N''RowStatus'')", applySql, StringComparison.Ordinal);
        Assert.Contains("@StepName = N'ApplyRetirements'", applySql, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataApplyRun_HasAControlledHandlerForEntityPropertyDependants()
    {
        var applySql = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var upsert = ReadProcedure("SCore.EntityPropertyDependantUpsert.sql");

        // CYB-564: registered and enabled, but had no handler, so a re-pointed dependant could
        // never be migrated. Both property columns resolve through the same source-Guid lookup
        // every other handler uses, and an unresolved one fails loudly rather than applying NULL.
        Assert.Contains("AND tr.TableName = N'EntityPropertyDependants'", applySql, StringComparison.Ordinal);
        Assert.Contains("AND lookup.SourceRowId = @EPD_SourceParentEntityPropertyID;", applySql, StringComparison.Ordinal);
        Assert.Contains("AND lookup.SourceRowId = @EPD_SourceDependantPropertyID;", applySql, StringComparison.Ordinal);
        Assert.Contains("THROW 52030, @MissingDependantPropertyMessage, 1;", applySql, StringComparison.Ordinal);
        Assert.Contains("@RowStatus = @EPD_RowStatus,", applySql, StringComparison.Ordinal);

        // The upsert gained an optional RowStatus so the existing metadata EntityQuery statement
        // that calls it keeps working unchanged.
        Assert.Contains("@RowStatus TINYINT = NULL", upsert, StringComparison.Ordinal);
        Assert.Contains("RowStatus = ISNULL(NULLIF(@RowStatus, 0), RowStatus)", upsert, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataRegistrySeed_NaturalKeysNameColumnsThatExist()
    {
        var seed = ReadProcedure("SMigration.MetadataRegistry_Seed.sql");

        Assert.Contains("N'EntityPropertyDependants', N'Guid', N'ID', 270, 1, 1, 1, 0, N'[\"ParentEntityPropertyID\",\"DependantPropertyID\"]'", seed, StringComparison.Ordinal);
        Assert.Contains("N'EntityPropertyActions', N'Guid', N'ID', 260, 1, 1, 1, 0, N'[\"EntityPropertyID\",\"Statement\"]'", seed, StringComparison.Ordinal);
        Assert.DoesNotContain("DependantEntityPropertyID", seed, StringComparison.Ordinal);
        Assert.DoesNotContain("ActionName", seed, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataStageNormalise_ComparesForeignKeysByResolvedGuidInsteadOfIgnoringThem()
    {
        var normalise = ReadProcedure("SMigration.MetadataStage_NormaliseDifferences.sql");

        // CYB-564: FK columns used to be dropped before hashing, so a genuine re-point (e.g.
        // @QuoteJobType mapped to a different EntityProperty) staged as NoChange.
        Assert.DoesNotContain("AND j.[key] NOT IN", normalise, StringComparison.Ordinal);
        Assert.Contains("CREATE TABLE #MetadataFkColumns", normalise, StringComparison.Ordinal);
        Assert.Contains("AND rc.name = refTr.PrimaryKeyColumnName", normalise, StringComparison.Ordinal);
        Assert.Contains("AND pc.name <> N'RowStatus'", normalise, StringComparison.Ordinal);

        // Source side resolves the same Guid Apply will write: override, then natural-key match,
        // then the source row's own Guid (the #MetadataSourceGuidLookup order).
        Assert.Contains("ov.TargetRowGuid,\n            TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(sr.TargetPayloadJson, N'$.' + tr.GuidColumnName)),\n            sr.SourceRowGuid", NormaliseNewLines(normalise), StringComparison.Ordinal);
        Assert.Contains("CASE WHEN srcRef.ResolvedGuid = tgtRef.RowGuid THEN 0 ELSE 1 END", normalise, StringComparison.Ordinal);

        // Identical sentinels (-1) always match; unresolvable columns keep the old behaviour.
        Assert.Contains("AND p.SourceIdValue <= 0 THEN 0", normalise, StringComparison.Ordinal);
        Assert.Contains("WHEN legacy.KeyName IS NOT NULL THEN 0", normalise, StringComparison.Ordinal);

        // TRY_CONVERT(BIGINT, ...) on an nvarchar(max) value over 8000 bytes (a long
        // EntityQueries.Statement) raises 8152 rather than returning NULL, which failed the whole
        // stage. Only short values may reach the BIGINT conversion.
        Assert.Contains("TRY_CONVERT(BIGINT, CASE WHEN LEN(kv.SourceValue) <= 20 THEN CONVERT(NVARCHAR(20), kv.SourceValue) END) AS SourceIdValue", normalise, StringComparison.Ordinal);
        Assert.Contains("TRY_CONVERT(BIGINT, CASE WHEN LEN(kv.TargetValue) <= 20 THEN CONVERT(NVARCHAR(20), kv.TargetValue) END) AS TargetIdValue", normalise, StringComparison.Ordinal);
        Assert.Contains("AND srcRef.SourceRowId = p.SourceIdValue", normalise, StringComparison.Ordinal);
        Assert.Contains("AND tgtRef.ID = p.TargetIdValue", normalise, StringComparison.Ordinal);
        Assert.DoesNotContain("TRY_CONVERT(BIGINT, p.SourceValue)", normalise, StringComparison.Ordinal);
        Assert.DoesNotContain("TRY_CONVERT(BIGINT, p.TargetValue)", normalise, StringComparison.Ordinal);

        // Rules absorbed from MetadataStage_NormaliseEnvironmentOnlyUpdates.
        Assert.Contains("WHEN p.KeyName = N'Statement' AND p.SchemaName = N'SCore' AND p.TableName = N'EntityQueries' THEN", normalise, StringComparison.Ordinal);
    }

    [Fact]
    public void ValidateAndApply_BlockASelectedRowWhoseNewParentIsNotBeingApplied()
    {
        var validate = ReadProcedure("SMigration.MetadataValidate_Run.sql");
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");

        // CYB-564: HoBT SJob.FeeAmendmentChase was selected without its new EntityType; Apply
        // resolved the parent to a source Guid missing from the target and failed with a raw
        // NOT NULL error on EntityHobts.EntityTypeID after a clean Validate.
        Assert.Contains("N'SelectedRowParentNotSelected',\n        LEFT(CONCAT", NormaliseNewLines(validate), StringComparison.Ordinal);
        Assert.Contains("N'UnresolvedReference', N'SelectedRowParentNotSelected',", validate, StringComparison.Ordinal);

        // Validate clears its own issue on re-run.
        Assert.Contains("N'GridViewColumnMissingFromQuery',\n          N'SelectedRowParentNotSelected',", NormaliseNewLines(validate), StringComparison.Ordinal);
        Assert.Contains("N'UnselectedActionableRows',\n          N'DuplicateQueryParameterName',\n          N'QueryParameterMappingMismatch',\n          N'QueryObjectMissingInTarget',\n          N'HobtObjectMissingInTarget',\n          N'PropertyColumnMissingInTarget',\n          N'QueryCallSignatureMismatch'\n      );", NormaliseNewLines(validate), StringComparison.Ordinal);

        // Apply repeats the check before writing, since the selection can change after Validate.
        Assert.Contains("THROW 52031, @MissingParentMessage, 1;", apply, StringComparison.Ordinal);
        Assert.True(
            apply.IndexOf("THROW 52031", StringComparison.Ordinal) < apply.IndexOf("DECLARE LanguageLabels_Cursor", StringComparison.Ordinal),
            "The missing-parent guard must run before the first apply handler.");
        Assert.Contains("AND NOT EXISTS (SELECT 1 FROM #MetadataRowsToApply AS parentApply WHERE parentApply.StagedRowId = parent.ID)", apply, StringComparison.Ordinal);

        foreach (var procedure in new[] { validate, apply })
        {
            // Only a new parent is a problem; an Update/NoChange or overridden parent already
            // exists in the target.
            Assert.Contains("AND parent.DifferenceType = N'Insert'", procedure, StringComparison.Ordinal);
            Assert.Contains("FROM SMigration.Metadata_IdentityMapOverrides AS parentOverride", procedure, StringComparison.Ordinal);
            Assert.Contains("TRY_CONVERT(BIGINT, JSON_VALUE(child.SourcePayloadJson, N'$.\"' + fk.ColumnName + N'\"')) AS ParentSourceRowId", procedure, StringComparison.Ordinal);
            Assert.Contains("AND rc.name = refTr.PrimaryKeyColumnName", procedure, StringComparison.Ordinal);
        }

        Assert.Contains("AND parent.SourceRowId = spr.ParentSourceRowId", validate, StringComparison.Ordinal);
        Assert.Contains("AND parent.SourceRowId = apr.ParentSourceRowId", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void RecordGrid_MarksRowsSelectedAutomaticallyAsDependencies()
    {
        var service = ReadMetadataMigrationService();
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var models = ReadRepositoryFile("libs", "Concursus.API.Client", "Models", "MetadataMigration", "MetadataMigrationModels.cs");
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");

        // SelectionSource travels from Metadata_RunSelections to the record grid.
        Assert.Contains("\"ISNULL(sel.SelectionSource, N'')\"", service, StringComparison.Ordinal);
        Assert.Contains("SelectionSource = stagedRow.SelectionSource", service, StringComparison.Ordinal);
        Assert.Contains("string selectionSource = 12;", proto, StringComparison.Ordinal);
        Assert.Contains("string selectionSource = 14;", proto, StringComparison.Ordinal);
        Assert.Contains("SelectionSource = row.SelectionSource ?? string.Empty,", formHelper, StringComparison.Ordinal);
        Assert.Contains("SelectionSource.Equals(\"Dependency\", StringComparison.OrdinalIgnoreCase)", models, StringComparison.Ordinal);

        // The grid marks dependency selections, and a manual tick shows as manual at once.
        Assert.Contains("@if (row.IsDependencySelected)", ui, StringComparison.Ordinal);
        Assert.Contains("<span class=\"bi bi-link-45deg\" aria-hidden=\"true\"></span> Auto", ui, StringComparison.Ordinal);
        Assert.Contains("row.SelectionSource = isChecked ? SelectionSourceManual : string.Empty;", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void ParentReferenceChecks_MaterialiseForeignKeyValuesBeforeJoiningParents()
    {
        // CYB-564: joining parents on a JSON_VALUE of the child payload let the optimiser
        // re-parse payloads per candidate pair; selection save on a ~14,000-row run hung past the
        // 300 second timeout. Every parent-reference check extracts the values first.
        var procedures = new[]
        {
            ReadProcedure("SMigration.MetadataRunSelection_AddDependencies.sql"),
            ReadProcedure("SMigration.MetadataValidate_Run.sql"),
            ReadProcedure("SMigration.MetadataApply_Run.sql")
        };

        foreach (var procedure in procedures)
        {
            Assert.DoesNotContain("AND parent.SourceRowId = TRY_CONVERT(", procedure, StringComparison.Ordinal);
        }

        var addDependencies = procedures[0];
        Assert.Contains("CREATE TABLE #ChildReferences", addDependencies, StringComparison.Ordinal);
        Assert.Contains("CREATE INDEX IX_ChildReferences_Parent ON #ChildReferences (RefRegistryGuid, ParentSourceRowId);", addDependencies, StringComparison.Ordinal);
        Assert.Contains("CREATE INDEX IX_Rows_Registry_SourceRowId ON #Rows (RegistryGuid, SourceRowId);", addDependencies, StringComparison.Ordinal);
        Assert.Contains("AND parent.SourceRowId = cr.ParentSourceRowId", addDependencies, StringComparison.Ordinal);
    }

    [Fact]
    public void SelectionSave_AlsoSelectsDependantsAndNewParents()
    {
        var addDependencies = NormaliseNewLines(ReadProcedure("SMigration.MetadataRunSelection_AddDependencies.sql"));
        var service = ReadMetadataMigrationService();
        var bootstrap = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_AddDependencies]", addDependencies, StringComparison.Ordinal);

        // Installed and converged by the bootstrap like the other selection procedures.
        Assert.Contains("MetadataProcedure(1105, \"MetadataRunSelection_AddDependencies\")", bootstrap, StringComparison.Ordinal);
        Assert.Contains("SMigration.MetadataRunSelection_AddDependencies.sql\",", bootstrap, StringComparison.Ordinal);

        // Called once per save, inside the selection transaction, only with selected rows.
        Assert.Contains("new SqlCommand(\"SMigration.MetadataRunSelection_AddDependencies\", cn, tx)", service, StringComparison.Ordinal);
        Assert.Contains(".Where(item => item.IsSelected)", service, StringComparison.Ordinal);
        Assert.Contains("AutoSelectedCount = autoSelectedCount,", service, StringComparison.Ordinal);

        // Down: only Insert/Update, non-ignored dependants, expanded from downward rows only.
        Assert.Contains("WHERE c.IsDownward = 1\n          AND childRow.IsSelectable = 1", addDependencies, StringComparison.Ordinal);
        Assert.Contains("WHEN sr.DifferenceType IN (N'Insert', N'Update')", addDependencies, StringComparison.Ordinal);
        Assert.Contains("FROM SMigration.Metadata_IgnoredRecords AS ignored", addDependencies, StringComparison.Ordinal);

        // Up: only new parents without an Identity Map override; they are not expanded downward.
        Assert.Contains("AND parentRow.DifferenceType = N'Insert'\n          AND parentRow.HasOverride = 0", addDependencies, StringComparison.Ordinal);
        Assert.Contains("e.ParentStagedRowId,\n            0,\n            0", addDependencies, StringComparison.Ordinal);

        // Same relationship set as Validate/Apply, and recorded as a dependency selection.
        Assert.Contains("AND rc.name = refTr.PrimaryKeyColumnName", addDependencies, StringComparison.Ordinal);
        Assert.Contains("SelectionSource = N'Dependency'", addDependencies, StringComparison.Ordinal);
        Assert.Contains("N'Dependency',\n                ISNULL(SCore.GetCurrentUserId(), -1)", addDependencies, StringComparison.Ordinal);
        Assert.Contains("EXEC SMigration.MetadataDataObject_Ensure", addDependencies, StringComparison.Ordinal);

        // A changed selection invalidates the previous validation.
        Assert.Contains("RunStatus = N'Staged',\n            ValidatedOnUtc = NULL", addDependencies, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataStageNormaliseEnvironmentOnlyUpdates_IsANoOpAndNoStagingPathCallsIt()
    {
        var environmentOnly = ReadProcedure("SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates.sql");
        var stageRun = ReadProcedure("SMigration.MetadataStage_Run.sql");
        var service = ReadMetadataMigrationService();

        // Its raw-ID rules would undo the Guid-resolved FK comparison, so it must not downgrade
        // anything - kept only so an older API build cannot reintroduce the old behaviour.
        Assert.DoesNotContain("SET DifferenceType", environmentOnly, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates", stageRun, StringComparison.Ordinal);
        Assert.DoesNotContain("EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates", service, StringComparison.Ordinal);
    }

    [Fact]
    public void NaturalKeyCollisionChecks_OnlyCompareRowsAFilteredUniqueIndexCovers()
    {
        var service = ReadMetadataMigrationService();
        var stageRun = ReadProcedure("SMigration.MetadataStage_Run.sql");

        // CYB-564: UAT's IX_UQ_EntityQueries_EntityHobtID_IsDefaultValidation is filtered
        // (WHERE IsDefaultValidation = 1). Ignoring the filter flagged SSop.QuotesUpsert
        // (IsDefaultValidation = 0) as DuplicateTargetKey, a Warn that silently excluded it, so
        // its statement and parameters never reached UAT.
        Assert.Contains("CASE WHEN i.has_filter = 1 THEN i.filter_definition END AS FilterDefinition", service, StringComparison.Ordinal);
        Assert.Contains("public static async Task<HashSet<Guid>> ReadGuidsCoveredByIndexFilterAsync(", service, StringComparison.Ordinal);
        Assert.Contains("foreach (var targetRow in targetRows.Where(row => targetCoveredGuids is null || targetCoveredGuids.Contains(row.RowGuid)))", service, StringComparison.Ordinal);
        Assert.Contains("(sourceCoveredGuids is null || sourceCoveredGuids.Contains(row.RowGuid))", service, StringComparison.Ordinal);

        // Same-server SQL path parity.
        Assert.Contains("CASE WHEN i.has_filter = 1 THEN i.filter_definition END", stageRun, StringComparison.Ordinal);
        Assert.Contains("INTO @OtherUniqueIndexId, @OtherUniqueIndexName, @OtherUniqueIndexFilter;", stageRun, StringComparison.Ordinal);
        Assert.Contains("+ @OtherIndexFilterPredicate + N'", stageRun, StringComparison.Ordinal);
    }

    private static string NormaliseNewLines(string text) => text.Replace("\r\n", "\n", StringComparison.Ordinal);

    private static string ReadProcedure(string fileName) =>
        ReadRepositoryFile(
            "Database",
            "CymBuild_DB",
            "Schema",
            "Programmability",
            "Procedures",
            fileName);

    // CYB-584: the two-connection (cross-server) staging moved from the API service into
    // libs/Concursus.EF so metadata-auto can use it too; contracts on it read both files.
    private static string ReadMetadataMigrationService() =>
        ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs")
        + "\n"
        + ReadRepositoryFile("libs", "Concursus.EF", "MetadataMigration", "MetadataTwoConnectionStaging.cs");

    private static string ReadRepositoryFile(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments));

    private static void AssertControlledTableAllowList(string sql)
    {
        foreach (var qualifiedTableName in ControlledApplyTables)
        {
            var parts = qualifiedTableName.Split('.', 2);
            Assert.Matches(
                new Regex(
                    $@"tr\.SchemaName\s*=\s*N'{Regex.Escape(parts[0])}'.*?N'{Regex.Escape(parts[1])}'",
                    RegexOptions.CultureInvariant | RegexOptions.Singleline),
                sql);
        }
    }
}
