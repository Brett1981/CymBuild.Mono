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
        "SUserInterface.Icons",
        "SUserInterface.DropDownListDefinitions",
        "SUserInterface.GridDefinitions",
        "SUserInterface.GridViewDefinitions",
        "SUserInterface.GridViewColumnDefinitions"
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
    public void MetadataApply_RechecksHandlerCoverageBeforeOpeningTransaction()
    {
        var sql = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var guardPosition = sql.IndexOf("THROW 52005", StringComparison.Ordinal);
        var transactionPosition = sql.IndexOf("BEGIN TRANSACTION", StringComparison.Ordinal);

        Assert.True(guardPosition >= 0, "Metadata apply does not contain the unsupported-handler execution guard.");
        Assert.True(
            transactionPosition > guardPosition,
            "The unsupported-handler guard must run before MetadataApply_Run opens its deployment transaction.");
        Assert.Contains("ISNULL(@ApplySelectedOnly, 0) = 0", sql, StringComparison.Ordinal);
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
        var service = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");
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
        Assert.Contains("SetEquals(stagedByGuid.Keys)", repository, StringComparison.Ordinal);
        Assert.Contains("MetadataMigrationDriftException", repository, StringComparison.Ordinal);
        Assert.True(snapshotPosition >= 0, "The EF repository does not re-read the live migration snapshot.");
        Assert.True(applyPosition > snapshotPosition, "The live drift snapshot must be validated before MetadataApply_Run executes.");
    }

    [Fact]
    public void MetadataPreviewAcceptanceAndApply_UseTheEfRepository()
    {
        var service = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");
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
        var service = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");
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
    public void MetadataWorkbench_DoesNotGenerateDirectApplySql()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");

        Assert.Contains("Direct SQL preview, acceptance and Apply are intentionally unsupported.", ui, StringComparison.Ordinal);
        Assert.Contains("controlled FormHelper -> gRPC -> EF path", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("builder.AppendLine($\"-- EXEC SMigration.MetadataApply", ui, StringComparison.Ordinal);
        Assert.DoesNotContain("return $\"EXEC SMigration.MetadataApply", ui, StringComparison.Ordinal);
    }

    private static string ReadProcedure(string fileName) =>
        ReadRepositoryFile(
            "Database",
            "CymBuild_DB",
            "Schema",
            "Programmability",
            "Procedures",
            fileName);

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
