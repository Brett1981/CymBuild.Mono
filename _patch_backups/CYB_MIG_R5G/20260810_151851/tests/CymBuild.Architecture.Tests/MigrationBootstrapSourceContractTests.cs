using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class MigrationBootstrapSourceContractTests
{
    [Fact]
    public void BootstrapRepository_UsesTransactionalLockedVerifiedSourceControlledSql()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");

        Assert.Contains("IsolationLevel.Serializable", repository, StringComparison.Ordinal);
        Assert.Contains("sys.sp_getapplock", repository, StringComparison.Ordinal);
        Assert.Contains("@LockOwner = N'Transaction'", repository, StringComparison.Ordinal);
        Assert.Contains("MigrationBootstrap:AllowLive", repository, StringComparison.Ordinal);
        Assert.Contains("IsLiveLikeEndpoint", repository, StringComparison.Ordinal);
        Assert.Contains("GetManifestResourceStream", repository, StringComparison.Ordinal);
        Assert.Contains("SHA256.HashData", repository, StringComparison.Ordinal);
        Assert.Contains("missingAfter.Count > 0", repository, StringComparison.Ordinal);
        Assert.Contains("await transaction.CommitAsync", repository, StringComparison.Ordinal);
        Assert.Contains("await transaction.RollbackAsync", repository, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataBootstrap_EmbedsEveryCanonicalTableAndProcedureWithoutLegacyBundle()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var project = ReadRepositoryFile("libs", "Concursus.EF", "Concursus.EF.csproj");
        var tableDirectory = RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Schema", "Tables");
        var procedureDirectory = RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures");

        var tableObjectNames = Directory
            .EnumerateFiles(tableDirectory, "SMigration.Metadata_*.sql", SearchOption.TopDirectoryOnly)
            .Select(Path.GetFileNameWithoutExtension)
            .Select(name => name!["SMigration.".Length..])
            .OrderBy(name => name, StringComparer.Ordinal)
            .ToArray();
        var procedureObjectNames = Directory
            .EnumerateFiles(procedureDirectory, "SMigration.Metadata*.sql", SearchOption.TopDirectoryOnly)
            .Select(Path.GetFileNameWithoutExtension)
            .Select(name => name!["SMigration.".Length..])
            .OrderBy(name => name, StringComparer.Ordinal)
            .ToArray();

        Assert.Equal(10, tableObjectNames.Length);
        Assert.Equal(25, procedureObjectNames.Length);

        foreach (var objectName in tableObjectNames)
        {
            Assert.Contains($"\"{objectName}\"", repository, StringComparison.Ordinal);
        }

        foreach (var objectName in procedureObjectNames)
        {
            Assert.Contains($"\"{objectName}\"", repository, StringComparison.Ordinal);
        }

        Assert.Contains("SMigration.Metadata_*.sql", project, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata*.sql", project, StringComparison.Ordinal);
        Assert.DoesNotContain("SQL_CI_Packs_Metadata", project, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SMigration.Metadata.Schema.sql", project, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SchemaBootstrap_UsesIdempotentSourceControlledScriptsAndDboOwnership()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var project = ReadRepositoryFile("libs", "Concursus.EF", "Concursus.EF.csproj");
        var workbenchSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaWorkbench.Bootstrap.sql");
        var metadataSchemaSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "Metadata",
            "SMigration.MetadataWorkbench.Bootstrap.Schema.sql");

        Assert.Contains("SchemaBootstrapResources", repository, StringComparison.Ordinal);
        Assert.Contains("SMigration.SchemaWorkbench.Bootstrap.sql", project, StringComparison.Ordinal);
        Assert.Contains("SMigration.SchemaExclusions.Bootstrap.sql", project, StringComparison.Ordinal);
        Assert.Contains("IF SCHEMA_ID(N'SMigration') IS NULL", workbenchSql, StringComparison.Ordinal);
        Assert.Contains("CREATE SCHEMA [SMigration] AUTHORIZATION [dbo]", workbenchSql, StringComparison.Ordinal);
        Assert.Contains("CREATE SCHEMA [SMigration] AUTHORIZATION [dbo]", metadataSchemaSql, StringComparison.Ordinal);
        Assert.DoesNotContain("ESGL\\", metadataSchemaSql, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void RunCreation_AutomaticallyBootstrapsBeforeUsingMigrationRoutines()
    {
        var schemaService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.SchemaMigration.cs");
        var metadataService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");

        var schemaTargetBootstrap = schemaService.IndexOf(
            "EnsureSchemaWorkbenchAsync(", StringComparison.Ordinal);
        var schemaSourceBootstrap = schemaService.IndexOf(
            "EnsureSchemaWorkbenchAsync(", schemaTargetBootstrap + 1, StringComparison.Ordinal);
        var schemaOpenConnection = schemaService.IndexOf(
            "OpenSqlAsync(", schemaSourceBootstrap, StringComparison.Ordinal);
        var metadataBootstrap = metadataService.IndexOf(
            "EnsureMetadataWorkbenchAsync(", StringComparison.Ordinal);
        var metadataSeed = metadataService.IndexOf(
            "SMigration.MetadataRegistry_Seed", StringComparison.Ordinal);

        Assert.Contains("Authorize(Roles = \"User.ReadWrite,SysAdmin\")", schemaService, StringComparison.Ordinal);
        Assert.Contains("Authorize(Roles = \"User.ReadWrite,SysAdmin\")", metadataService, StringComparison.Ordinal);
        Assert.True(schemaTargetBootstrap >= 0, "Schema run creation does not bootstrap the target.");
        Assert.True(schemaSourceBootstrap > schemaTargetBootstrap, "Schema run creation does not bootstrap the source.");
        Assert.True(schemaOpenConnection > schemaSourceBootstrap, "Schema bootstrap must complete before the run connection is used.");
        Assert.True(metadataBootstrap >= 0, "Metadata run creation does not bootstrap the target.");
        Assert.True(metadataSeed > metadataBootstrap, "Metadata bootstrap must complete before registry seed/run creation.");
        Assert.Contains(
            "(DatabaseRole: \"Target\", Result: targetBootstrap)",
            schemaService,
            StringComparison.Ordinal);
        Assert.Contains(
            "(DatabaseRole: \"Source\", Result: sourceBootstrap)",
            schemaService,
            StringComparison.Ordinal);
        Assert.Contains(
            "$\"Bootstrap{bootstrap.DatabaseRole}\"",
            schemaService,
            StringComparison.Ordinal);
        Assert.Contains("\"BootstrapTarget\"", metadataService, StringComparison.Ordinal);
        Assert.Contains("ScriptSha256", schemaService, StringComparison.Ordinal);
        Assert.Contains("ScriptSha256", metadataService, StringComparison.Ordinal);
    }

    [Fact]
    public void BootstrapCapableEndpoints_UseEstablishedWriteOrSysAdminRoles()
    {
        var schemaService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.SchemaMigration.cs");
        var metadataService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");

        Assert.Contains(
            "[Microsoft.AspNetCore.Authorization.Authorize(Roles = \"User.ReadWrite,SysAdmin\")]\n    public override async Task<SchemaMigrationRunResponse> SchemaMigrationRunCreate(",
            schemaService.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);
        Assert.Contains(
            "[Microsoft.AspNetCore.Authorization.Authorize(Roles = \"User.ReadWrite,SysAdmin\")]\n    public override async Task<SchemaMigrationRunsResponse> SchemaMigrationRuns(",
            schemaService.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);
        Assert.Contains(
            "[Microsoft.AspNetCore.Authorization.Authorize(Roles = \"User.ReadWrite,SysAdmin\")]\n    public override async Task<MetadataMigrationRunResponse> MetadataMigrationRunCreate(",
            metadataService.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);
        Assert.Contains(
            "[Microsoft.AspNetCore.Authorization.Authorize(Roles = \"User.ReadWrite,SysAdmin\")]\n    public override async Task<MetadataMigrationRunsResponse> MetadataMigrationRuns(",
            metadataService.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);

        Assert.DoesNotContain("Authorize(Roles = \"SysAdmin\")", schemaService, StringComparison.Ordinal);
        Assert.DoesNotContain("Authorize(Roles = \"SysAdmin\")", metadataService, StringComparison.Ordinal);
    }

    [Fact]
    public void Bootstrap_RemainsBehindUiFormHelperGrpcEfSqlBoundary()
    {
        var schemaUi = ReadRepositoryFile(
            "apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor");
        var metadataUi = ReadRepositoryFile(
            "apps", "Concursus.PWA", "Pages", "Admin", "MetadataMigration.razor");
        var schemaFormHelper = ReadRepositoryFile(
            "libs", "Concursus.API.Client", "FormHelper.SchemaMigration.cs");
        var metadataFormHelper = ReadRepositoryFile(
            "libs", "Concursus.API.Client", "FormHelper.MetadataMigration.cs");
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var program = ReadRepositoryFile("services", "Concursus.API", "Program.cs");
        var coreService = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.cs");

        Assert.Contains("CurrentFormHelper.SchemaMigrationRunCreateAsync", schemaUi, StringComparison.Ordinal);
        Assert.Contains("CurrentFormHelper.MetadataMigrationRunCreateAsync", metadataUi, StringComparison.Ordinal);
        Assert.Contains("_coreClient.SchemaMigrationRunCreateAsync", schemaFormHelper, StringComparison.Ordinal);
        Assert.Contains("_coreClient.MetadataMigrationRunCreateAsync", metadataFormHelper, StringComparison.Ordinal);
        Assert.Contains("rpc SchemaMigrationRunCreate", proto, StringComparison.Ordinal);
        Assert.Contains("rpc MetadataMigrationRunCreate", proto, StringComparison.Ordinal);
        Assert.Contains("AddScoped<MigrationBootstrapRepository>", program, StringComparison.Ordinal);
        Assert.Contains(
            "using MigrationBootstrapRepository = Concursus.EF.MigrationBootstrapRepository;",
            coreService,
            StringComparison.Ordinal);
        Assert.DoesNotContain("Initialize-CymBuildSchemaMigration.ps1", schemaUi, StringComparison.Ordinal);
        Assert.DoesNotContain("Initialise Schema Migration", schemaUi, StringComparison.Ordinal);
        Assert.DoesNotContain("new SqlConnection", schemaUi, StringComparison.Ordinal);
        Assert.DoesNotContain("new SqlConnection", metadataUi, StringComparison.Ordinal);
    }

    [Fact]
    public void BootstrapFailure_RemainsFailClosedWithoutCreatingARun()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var schemaService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.SchemaMigration.cs");
        var metadataService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");

        Assert.Contains("No migration run was created", repository, StringComparison.Ordinal);
        Assert.Contains("the bootstrap transaction was rolled back", repository, StringComparison.Ordinal);
        Assert.Contains("MigrationBootstrapException", schemaService, StringComparison.Ordinal);
        Assert.Contains("StatusCode.FailedPrecondition", schemaService, StringComparison.Ordinal);
        Assert.Contains("MigrationBootstrapException", metadataService, StringComparison.Ordinal);
        Assert.Contains("StatusCode.FailedPrecondition", metadataService, StringComparison.Ordinal);
    }

    private static string ReadRepositoryFile(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments));
}
