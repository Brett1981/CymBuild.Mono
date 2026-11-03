using Xunit;
using System.Text.RegularExpressions;

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
    public void Bootstrap_InstallsMissingModulesButNeverReplacesExistingOnes()
    {
        // CYB-584, 2026-10-16: a workbench built without CYB-584 re-applied its embedded copies and
        // replaced CymBuild_QA's newer MetadataValidate_Run / MetadataApply_Run mid-deployment (default
        // trace: CymBuild.MetadataMigrationBootstrap). A build cannot tell older from newer, so an
        // existing module with a different definition is reported, never replaced.
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var execute = repository[repository.IndexOf("private async Task<string> ExecuteEmbeddedSqlScriptAsync", StringComparison.Ordinal)..];

        var current = execute.IndexOf("IsModuleCurrentAsync(", StringComparison.Ordinal);
        var exists = execute.IndexOf("ModuleExistsAsync(", StringComparison.Ordinal);
        var report = execute.IndexOf("divergentModules.Add(moduleName);", StringComparison.Ordinal);
        var run = execute.IndexOf("ExecuteNonQueryAsync", StringComparison.Ordinal);

        Assert.True(current >= 0 && exists > current && report > exists && run > report,
            "A module batch must be skipped when current, reported and skipped when it exists, and only run when missing.");
        Assert.Contains("IReadOnlyList<string> DivergentModules);", repository, StringComparison.Ordinal);

        // Surfaced where the bootstrap result is logged or reported.
        var cli = ReadRepositoryFile("libs", "Concursus.EF", "MigrationCli", "MetadataMigrationCli.cs");
        var api = ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");
        var engine = ReadSchemaEngineFile("SchemaMigrationEngine.cs");
        Assert.Contains("bootstrapResult.DivergentModules", cli, StringComparison.Ordinal);
        Assert.Contains("bootstrap.DivergentModules", api, StringComparison.Ordinal);
        Assert.Contains("bootstrap.Result.DivergentModules", engine, StringComparison.Ordinal);
    }

    [Fact]
    public void Bootstrap_NeverReplacesLifecycleProceduresWhileALifecycleStepRuns()
    {
        // 2026-10-13: a workbench bootstrap re-created SCore.SCHEMABINDING mid post-deployment on
        // CymBuild_QA2 (SQL 2801), leaving every foreign key to SCore.DataObjects disabled.
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var lockSource = ReadRepositoryFile("libs", "Concursus.EF", "SchemaLifecycleLock.cs");
        var engineStore = ReadSchemaEngineFile("SchemaMigrationEngine.Store.cs");
        var runner = ReadRepositoryFile("tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        // Bootstrap: unchanged modules are skipped; any replacement first takes the lock exclusively.
        var execute = repository[repository.IndexOf("private async Task<string> ExecuteEmbeddedSqlScriptAsync", StringComparison.Ordinal)..];
        var skip = execute.IndexOf("IsModuleCurrentAsync(", StringComparison.Ordinal);
        var takeLock = execute.IndexOf("AcquireLifecycleLockAsync(", StringComparison.Ordinal);
        var run = execute.IndexOf("ExecuteNonQueryAsync", StringComparison.Ordinal);
        Assert.True(skip >= 0 && takeLock > skip && run > takeLock, "Bootstrap must skip current modules, then lock, then execute.");
        Assert.Contains("SchemaLifecycleLock.Resource", repository, StringComparison.Ordinal);
        Assert.Contains("@LockMode = N'Exclusive'", repository, StringComparison.Ordinal);

        // Lifecycle callers hold the same resource in Shared mode.
        Assert.Contains("public const string Resource = \"CymBuild.SchemaLifecycle\";", lockSource, StringComparison.Ordinal);
        Assert.Contains("@LockMode = N'Shared', @LockOwner = N'Session'", lockSource, StringComparison.Ordinal);
        Assert.Contains("SchemaLifecycleLock.WrapLifecycleSql(executionSql)", engineStore, StringComparison.Ordinal);

        Assert.Contains("$resource = 'CymBuild.SchemaLifecycle'", runner, StringComparison.Ordinal);
        Assert.Contains("@LockMode = N'Shared', @LockOwner = N'Session'", runner, StringComparison.Ordinal);
        var lifecycleCalls = Regex.Matches(runner, @"Invoke-SqlScriptText[^\r\n]*(PreDeploymentScript|postDeploymentSql|recoveryPostDeploymentSql)[^\r\n]*");
        Assert.Equal(3, lifecycleCalls.Count);
        Assert.All(lifecycleCalls, m => Assert.Contains("Get-CymBuildLifecycleLockedSql", m.Value, StringComparison.Ordinal));
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

        Assert.Equal(11, tableObjectNames.Length);
        Assert.Equal(29, procedureObjectNames.Length);

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
    public void SchemaBootstrap_DeclaresSourceSyncStalenessColumns()
    {
        var workbenchSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaWorkbench.Bootstrap.sql");
        var canonicalTableSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables", "SMigration.Schema_Run.sql");

        Assert.Contains("[SourceSyncedOnUtc] DATETIME2(7) NULL", workbenchSql, StringComparison.Ordinal);
        Assert.Contains("[SourceSyncCommit] NVARCHAR(64) NULL", workbenchSql, StringComparison.Ordinal);
        Assert.Contains(
            "(N'Schema_Run', N'SourceSyncedOnUtc', N'datetime2', 8, 1, 0)",
            workbenchSql,
            StringComparison.Ordinal);
        Assert.Contains(
            "(N'Schema_Run', N'SourceSyncCommit', N'nvarchar', 128, 1, 0)",
            workbenchSql,
            StringComparison.Ordinal);
        Assert.Contains("[SourceSyncedOnUtc] [datetime2](7) NULL", canonicalTableSql, StringComparison.Ordinal);
        Assert.Contains("[SourceSyncCommit] [nvarchar](64) NULL", canonicalTableSql, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaBootstrap_SchemaRunNotesWidthMatchesCanonicalTable()
    {
        var workbenchSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaWorkbench.Bootstrap.sql");
        var canonicalTableSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables", "SMigration.Schema_Run.sql");

        // Bootstrap only creates Schema_Run when missing and otherwise rejects any existing
        // column whose width differs from its @ExpectedColumns entry (see the bootstrap's own
        // "found missing or incompatible columns" check) - so both the CREATE TABLE fallback
        // and the expected-width row must track the canonical table's actual Notes width, not
        // whatever width Schema_Run.Notes had when the bootstrap script was first written.
        Assert.Contains("[Notes] [nvarchar](max) NOT NULL", canonicalTableSql, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("[Notes] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_Run_Notes]", workbenchSql, StringComparison.Ordinal);
        Assert.Contains("(N'Schema_Run', N'Notes', N'nvarchar', -1, 0, 0)", workbenchSql, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_RefusesWhenSelectedSourceHasNotBeenSyncedRecently()
    {
        var schemaService = ReadSchemaMigrationSource();

        Assert.Contains("IsSourceSyncStale(run.SourceSyncedOnUtc", schemaService, StringComparison.Ordinal);
        Assert.Contains("enforceSourceSyncGate: true", ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.SchemaMigration.cs"), StringComparison.Ordinal);
        Assert.Contains("SourceSyncStalenessThreshold = TimeSpan.FromMinutes(30)", schemaService, StringComparison.Ordinal);
        Assert.Contains("Run -SyncSource for this RunGuid first", schemaService, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_RefusesWhatIfAndApplyOnStaleComparedPlan()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("if ($WhatIf -or $Apply) {", runner, StringComparison.Ordinal);
        Assert.Contains("exceeds the 30-minute staleness limit for -WhatIf/-Apply", runner, StringComparison.Ordinal);
        Assert.Contains("sr.SourceSyncedOnUtc", runner, StringComparison.Ordinal);
        Assert.Contains("sr.SourceSyncCommit", runner, StringComparison.Ordinal);
        Assert.Contains("[SourceSyncedOnUtc] = @SourceSyncedOnUtc", runner, StringComparison.Ordinal);
        Assert.Contains("[SourceSyncCommit] = @SourceSyncCommit", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void RunCreation_AutomaticallyBootstrapsBeforeUsingMigrationRoutines()
    {
        var schemaService = ReadSchemaMigrationSource();
        var schemaEngine = ReadSchemaEngineFile("SchemaMigrationEngine.cs");
        var metadataService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");

        var createRunStart = schemaEngine.IndexOf(
            "public async Task<SchemaRunRecord> CreateRunAsync(", StringComparison.Ordinal);
        Assert.True(createRunStart >= 0, "SchemaMigrationEngine.CreateRunAsync was not found.");
        Assert.Contains("await SchemaEngine.CreateRunAsync(", schemaService, StringComparison.Ordinal);
        var schemaTargetBootstrap = schemaEngine.IndexOf(
            "EnsureSchemaWorkbenchAsync(", createRunStart, StringComparison.Ordinal);
        var schemaSourceBootstrap = schemaEngine.IndexOf(
            "EnsureSchemaWorkbenchAsync(", schemaTargetBootstrap + 1, StringComparison.Ordinal);
        var schemaOpenConnection = schemaEngine.IndexOf(
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
        var schemaService = ReadSchemaMigrationSource();
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
    public void SchemaCompare_KeyConstraintSnapshot_DelimitsReservedFillFactorAlias()
    {
        var schemaService = ReadSchemaMigrationSource();

        Assert.Contains(
            "CONVERT(INT, CASE WHEN i.fill_factor IN (0, 100) THEN 0 ELSE i.fill_factor END) AS [FillFactor]",
            schemaService,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "CONVERT(INT, CASE WHEN i.fill_factor IN (0, 100) THEN 0 ELSE i.fill_factor END) AS FillFactor",
            schemaService,
            StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaValidation_LoadsPersistedDefinitionsBeforeCheckingSnapshotVersions()
    {
        var schemaService = ReadSchemaMigrationSource();
        var schemaEngine = ReadSchemaEngineFile("SchemaMigrationEngine.cs");
        var validateStart = schemaEngine.IndexOf(
            "public async Task<SchemaValidationResult> ValidateAsync(",
            StringComparison.Ordinal);
        var nextMethodStart = schemaEngine.IndexOf(
            "public Task<SchemaSelectionCounts> SaveSelectionAsync(",
            validateStart,
            StringComparison.Ordinal);
        var validateMethod = schemaEngine[validateStart..nextMethodStart];

        Assert.Contains("await SchemaEngine.ValidateAsync(", schemaService, StringComparison.Ordinal);

        Assert.Contains("includeDefinitions: true", validateMethod, StringComparison.Ordinal);
        Assert.DoesNotContain("includeDefinitions: false", validateMethod, StringComparison.Ordinal);
        Assert.Contains("CYB_CONSTRAINT_V2|", schemaService, StringComparison.Ordinal);
        Assert.Contains("CYB_TABLE_V2|", schemaService, StringComparison.Ordinal);
        Assert.Contains("CYB_INDEX_V2|", schemaService, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_UsesDeclarativeTableAndIndexSnapshots()
    {
        var schemaService = ReadSchemaMigrationSource();
        var tableSnapshotStart = schemaService.IndexOf("public const string Tables = @\"", StringComparison.Ordinal);
        var tableTypeSnapshotStart = schemaService.IndexOf("public const string TableTypes = @\"", tableSnapshotStart, StringComparison.Ordinal);
        var tableSnapshot = schemaService[tableSnapshotStart..tableTypeSnapshotStart];

        Assert.Contains("N'CYB_TABLE_V2|'", schemaService, StringComparison.Ordinal);
        Assert.Contains("DefaultConstraintName", schemaService, StringComparison.Ordinal);
        Assert.Contains("IdentityIncrement", schemaService, StringComparison.Ordinal);
        Assert.Contains("N'CYB_INDEX_V2|'", schemaService, StringComparison.Ordinal);
        Assert.Contains("i.type AS IndexTypeId", schemaService, StringComparison.Ordinal);
        Assert.Contains("p.data_compression_desc AS DataCompression", schemaService, StringComparison.Ordinal);
        Assert.Contains("ORDER BY c.name", tableSnapshot, StringComparison.Ordinal);
        Assert.DoesNotContain("c.column_id AS ColumnId", tableSnapshot, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_CanonicalisesOnlySystemNamedDefaultConstraints()
    {
        var schemaService = ReadSchemaMigrationSource();
        var tableSnapshotStart = schemaService.IndexOf("public const string Tables = @\"", StringComparison.Ordinal);
        var tableTypeSnapshotStart = schemaService.IndexOf("public const string TableTypes = @\"", tableSnapshotStart, StringComparison.Ordinal);
        var defaultSnapshotStart = schemaService.IndexOf("public const string DefaultConstraints = @\"", StringComparison.Ordinal);
        var indexSnapshotStart = schemaService.IndexOf("public const string Indexes = @\"", defaultSnapshotStart, StringComparison.Ordinal);
        var tableSnapshot = schemaService[tableSnapshotStart..tableTypeSnapshotStart];
        var defaultSnapshot = schemaService[defaultSnapshotStart..indexSnapshotStart];

        Assert.Contains("WHEN dc.is_system_named = 1 THEN", tableSnapshot, StringComparison.Ordinal);
        Assert.Contains("ELSE dc.name", tableSnapshot, StringComparison.Ordinal);
        Assert.Contains("CONCAT(N'DF_', sch.name, N'_', t.name, N'_', c.name)", tableSnapshot, StringComparison.Ordinal);
        Assert.Contains("WHEN dc.is_system_named = 1 THEN", defaultSnapshot, StringComparison.Ordinal);
        Assert.Contains("ELSE dc.name", defaultSnapshot, StringComparison.Ordinal);
        Assert.Contains("defaultIdentity.CanonicalName", defaultSnapshot, StringComparison.Ordinal);
        Assert.Contains("END AS ConstraintName", defaultSnapshot, StringComparison.Ordinal);
        Assert.Contains("HASHBYTES", defaultSnapshot, StringComparison.Ordinal);
        Assert.Contains("INNER JOIN sys.schemas AS sch", defaultSnapshot, StringComparison.Ordinal);
        Assert.DoesNotContain("CONVERT(NVARCHAR(256), dc.name)", defaultSnapshot, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_R7D11NormalisesLifecycleTriggersAndSystemNamedKeyConstraints()
    {
        var schemaService = ReadSchemaMigrationSource();
        var keySnapshotStart = schemaService.IndexOf("public const string KeyConstraints = @\"", StringComparison.Ordinal);
        var foreignKeySnapshotStart = schemaService.IndexOf("public const string ForeignKeyConstraints = @\"", keySnapshotStart, StringComparison.Ordinal);
        var keySnapshot = schemaService[keySnapshotStart..foreignKeySnapshotStart];
        var comparisonStart = schemaService.IndexOf(
            "public static List<SchemaComparisonDraft> BuildSchemaComparisonRows(",
            StringComparison.Ordinal);
        var validationStart = schemaService.IndexOf(
            "public static List<SchemaValidationDraft> BuildSchemaValidationIssues(",
            comparisonStart,
            StringComparison.Ordinal);
        var comparisonMethod = schemaService[comparisonStart..validationStart];

        Assert.Contains("IsLifecycleManagedRecordHistoryTrigger(selected)", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("row.ObjectName.StartsWith(\"tg_\"", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("row.ObjectName.EndsWith(\"_RecordHistory\"", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("LifecycleManagedRecordHistoryTriggerCount", schemaService, StringComparison.Ordinal);

        Assert.Contains("CONVERT(BIT, k.is_system_named) AS IsSystemNamed", keySnapshot, StringComparison.Ordinal);
        Assert.Contains("FindStructurallyEquivalentSystemNamedConstraintKeys(source, target)", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("IsSystemNamedKeyConstraint", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("sourceGroup.Value.Count != 1", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("targetRows.Count != 1", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("\\\"IsSystemNamed\\\":true", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("\\\"ConstraintKind\\\":\\\"PRIMARY_KEY\\\"", comparisonMethod, StringComparison.Ordinal);
        Assert.Contains("\\\"ConstraintKind\\\":\\\"UNIQUE\\\"", comparisonMethod, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_TreatsCreateAlterSpellingAsTheSameModuleDefinition()
    {
        var schemaService = ReadSchemaMigrationSource();

        Assert.Contains(
            "(?:CREATEORALTER|ALTER)(FUNCTION|VIEW|PROCEDURE|PROC|TRIGGER)",
            schemaService,
            StringComparison.Ordinal);
        Assert.Contains("\"CREATE$1\"", schemaService, StringComparison.Ordinal);
        Assert.Contains("public const string SchemaSnapshotContract = \"R7C4\"", schemaService, StringComparison.Ordinal);
        Assert.Contains("SchemaSnapshotContract,", schemaService, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_ConstraintAndIndexSnapshots_IncludeOnlyPhysicalUserTables()
    {
        var schemaService = ReadSchemaMigrationSource();
        var normalized = schemaService.Replace("\r\n", "\n", StringComparison.Ordinal);

        Assert.Contains(
            "FROM sys.key_constraints AS k\nINNER JOIN sys.tables AS parentTable\n    ON parentTable.object_id = k.parent_object_id",
            normalized,
            StringComparison.Ordinal);
        Assert.Contains(
            "FROM sys.foreign_keys AS fk\nINNER JOIN sys.tables AS parentTable\n    ON parentTable.object_id = fk.parent_object_id",
            normalized,
            StringComparison.Ordinal);
        Assert.Contains(
            "FROM sys.check_constraints AS cc\nINNER JOIN sys.tables AS parentTable\n    ON parentTable.object_id = cc.parent_object_id",
            normalized,
            StringComparison.Ordinal);
        Assert.Contains(
            "INNER JOIN sys.tables AS parentTable\n    ON parentTable.object_id = dc.parent_object_id\nINNER JOIN sys.schemas AS sch\n    ON sch.schema_id = parentTable.schema_id",
            normalized,
            StringComparison.Ordinal);
        Assert.Contains(
            "FROM sys.indexes AS i\nINNER JOIN sys.tables AS parentTable\n    ON parentTable.object_id = i.object_id",
            normalized,
            StringComparison.Ordinal);
        Assert.Equal(
            5,
            normalized.Split("INNER JOIN sys.tables AS parentTable", StringSplitOptions.None).Length - 1);
        Assert.Equal(
            5,
            normalized.Split("parentTable.is_ms_shipped = 0", StringSplitOptions.None).Length - 1);
        Assert.DoesNotContain(
            "FROM sys.indexes AS i\nINNER JOIN sys.objects AS o",
            normalized,
            StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaValidation_RecognisesDeclarativeTableAndIndexRunnerSupport()
    {
        var schemaService = ReadSchemaMigrationSource();

        Assert.Contains("TABLE_ALIGN_SELECTED", schemaService, StringComparison.Ordinal);
        Assert.Contains("INDEX_CREATE_SELECTED", schemaService, StringComparison.Ordinal);
        Assert.Contains("INDEX_REPLACE_SELECTED", schemaService, StringComparison.Ordinal);
        Assert.Contains("objectType is \"Constraint\" or \"Index\"", schemaService, StringComparison.Ordinal);
        Assert.Contains("INDEX_REMOVAL_SELECTED", schemaService, StringComparison.Ordinal);
        Assert.DoesNotContain("unsupportedStandaloneType", schemaService, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "The controlled runner does not yet deploy standalone",
            schemaService,
            StringComparison.Ordinal);
        Assert.Contains(
            "Foreign-key and check constraints are recreated WITH NOCHECK",
            schemaService,
            StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaComparisonNotes_PrioritiseSpecificMissingIndexArmBeforeGeneralMissingTargetArm()
    {
        var schemaService = ReadSchemaMigrationSource();
        var methodStart = schemaService.IndexOf(
            "public static string BuildSchemaComparisonNote(",
            StringComparison.Ordinal);
        Assert.True(methodStart >= 0, "BuildSchemaComparisonNote was not found.");

        var methodEnd = schemaService.IndexOf(
            "public static bool IsNewTableComparison(",
            methodStart,
            StringComparison.Ordinal);

        Assert.True(methodEnd > methodStart, "BuildSchemaComparisonNote boundary was not found.");

        var method = schemaService[methodStart..methodEnd];
        var missingIndexArm = method.IndexOf(
            "\"MissingInTarget\" when objectType == \"Index\"",
            StringComparison.Ordinal);
        var generalMissingTargetArm = method.IndexOf(
            "\"MissingInTarget\" =>",
            StringComparison.Ordinal);

        Assert.True(missingIndexArm >= 0, "The MissingInTarget Index arm is missing.");
        Assert.True(
            generalMissingTargetArm > missingIndexArm,
            "The specific MissingInTarget Index arm must precede the general arm so the switch remains reachable.");
    }

    [Fact]
    public void SchemaRunner_MaterializesGuardedExistingTableConvergence()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("function New-MaterializedTableSourceFiles", runner, StringComparison.Ordinal);
        Assert.Contains("CYB_TABLE_V2|", runner, StringComparison.Ordinal);
        Assert.Contains("Migrations\\Generated\\Tables", runner, StringComparison.Ordinal);
        Assert.Contains("TRY_CONVERT($typeSql", runner, StringComparison.Ordinal);
        Assert.Contains("Get-CymBuildBackfillExpression", runner, StringComparison.Ordinal);
        Assert.Contains("WHERE $columnIdentifier IS NULL", runner, StringComparison.Ordinal);
        Assert.Contains("ALTER TABLE $tableIdentifier DROP COLUMN", runner, StringComparison.Ordinal);
        Assert.Contains("BEGIN TRANSACTION", runner, StringComparison.Ordinal);
        Assert.Contains("ROLLBACK TRANSACTION", runner, StringComparison.Ordinal);
        Assert.Contains("DeclarativeTableAlter", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_ResolvesDefaultConstraintsByColumnAndUsesPortableNames()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("function Get-CymBuildDeterministicDefaultConstraintName", runner, StringComparison.Ordinal);
        Assert.Contains("[System.Text.Encoding]::Unicode.GetBytes", runner, StringComparison.Ordinal);
        Assert.Contains("$nameHash.Length - 20", runner, StringComparison.Ordinal);
        Assert.Contains("function Add-CymBuildDropDefaultConstraintByColumnSql", runner, StringComparison.Ordinal);
        Assert.Contains("$constraintDeploymentName", runner, StringComparison.Ordinal);
        Assert.Contains("-PropertyName \"ConstraintName\" -Required", runner, StringComparison.Ordinal);
        Assert.Contains("@CymBuildDefaultConstraintName = dc.name", runner, StringComparison.Ordinal);
        Assert.Contains("dc.parent_column_id", runner, StringComparison.Ordinal);
        Assert.Contains("QUOTENAME(@CymBuildDefaultConstraintName)", runner, StringComparison.Ordinal);
        Assert.Contains("Default constraint name $escapedLabel is already used by another column", runner, StringComparison.Ordinal);
        Assert.Contains("Default-constraint column $schemaName.$parentObjectName.$parentColumnName already has a different constraint", runner, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "OBJECT_ID($(Quote-CymBuildSqlStringLiteral -Value \"[$schemaName].[$targetDefaultName]\"), N'D')",
            runner,
            StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_MaterializesProgrammableObjectsAsCreateOrAlter()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("function Test-CymBuildProgrammableDefinitionIsIdempotent", runner, StringComparison.Ordinal);
        Assert.Contains("$canonicalSourceDefinition = Convert-SchemaScriptForDeployment", runner, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER FUNCTION", runner, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE", runner, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER TRIGGER", runner, StringComparison.Ordinal);
        Assert.Contains("CYB-361 R7C4 selected DEV schema source sync", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_RejectsRunsComparedBeforeR7C4()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("sr.SummaryJson", runner, StringComparison.Ordinal);
        Assert.Contains("function Assert-RunUsesR7C4SnapshotContract", runner, StringComparison.Ordinal);
        Assert.Contains("Assert-RunUsesR7C4SnapshotContract -RunRow $runRow", runner, StringComparison.Ordinal);
        Assert.Contains("Earlier accepted runs cannot be reused", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_EmitsValidatedUnquotedCollationNamesForTableColumns()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("function ConvertTo-CymBuildCollationSql", runner, StringComparison.Ordinal);
        Assert.Contains("\\A[A-Za-z0-9_]+\\z", runner, StringComparison.Ordinal);
        Assert.Contains(
            "COLLATE $(ConvertTo-CymBuildCollationSql -Value $collationName)",
            runner,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "COLLATE $(Quote-CymBuildSqlIdentifier -Value $collationName)",
            runner,
            StringComparison.Ordinal);
        Assert.Contains("return $collationName", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_MaterializesRowstoreIndexesAndDefersTheirPreflightUntilAfterTables()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("function New-MaterializedIndexSourceFiles", runner, StringComparison.Ordinal);
        Assert.Contains("CYB_INDEX_V2|", runner, StringComparison.Ordinal);
        Assert.Contains("IndexTypeId", runner, StringComparison.Ordinal);
        Assert.Contains("CREATE $uniqueSql$indexType INDEX", runner, StringComparison.Ordinal);
        Assert.Contains("DROP INDEX $indexIdentifier ON $tableIdentifier", runner, StringComparison.Ordinal);
        Assert.Contains("Unique index contains duplicate source key values", runner, StringComparison.Ordinal);
        Assert.Contains("$deferredPreflightItems", runner, StringComparison.Ordinal);
        Assert.Contains("ManualDeploymentPostStructurePreflight", runner, StringComparison.Ordinal);
        Assert.Contains("WITH NOCHECK ADD CONSTRAINT", runner, StringComparison.Ordinal);
        Assert.Contains("SkipSourceMaterialization", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_IndexDataSpacePreflightUsesSqlServerCatalog()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");
        var indexDirectory = RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Schema", "Indexes");
        var preflightFiles = Directory
            .EnumerateFiles(indexDirectory, "*.preflight.sql", SearchOption.TopDirectoryOnly)
            .OrderBy(path => path, StringComparer.Ordinal)
            .ToArray();

        Assert.Contains(
            "IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] =",
            runner,
            StringComparison.Ordinal);
        Assert.DoesNotContain("DATA_SPACE_ID(", runner, StringComparison.Ordinal);
        Assert.NotEmpty(preflightFiles);

        foreach (var preflightFile in preflightFiles)
        {
            var preflightSql = File.ReadAllText(preflightFile);
            Assert.DoesNotContain("DATA_SPACE_ID(", preflightSql, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void SchemaRunner_ReadsNestedJsonPropertiesCompatiblyAndApprovesCurrentObjectSecuritySnapshot()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");
        var helperStart = runner.IndexOf("function Get-CymBuildObjectProperty", StringComparison.Ordinal);
        var helperEnd = runner.IndexOf("function Get-CymBuildConstraintPayload", helperStart, StringComparison.Ordinal);

        Assert.True(helperStart >= 0, "Get-CymBuildObjectProperty was not found.");
        Assert.True(helperEnd > helperStart, "Get-CymBuildObjectProperty boundary was not found.");

        var helper = runner[helperStart..helperEnd];
        Assert.Contains(
            "$property = $InputObject.PSObject.Properties[$PropertyName]",
            helper,
            StringComparison.Ordinal);
        Assert.Contains("$value = $property.Value", helper, StringComparison.Ordinal);
        Assert.Contains("$value -is [System.Collections.ICollection]", helper, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "$InputObject.PSObject.Properties.Name -contains $PropertyName",
            helper,
            StringComparison.Ordinal);
        Assert.Contains(
            "F8196E022BF3112E9064A03D5C684F01104A9D1DCCEFC66C00E88FFC96218465",
            runner,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "6BB3BF24C7B4A3991239D04BD8F0726389DCDE6AE5BC4E0B71FBFB5B5FF9751C",
            runner,
            StringComparison.Ordinal);
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
        var schemaService = ReadSchemaMigrationSource();
        var metadataService = ReadRepositoryFile(
            "services", "Concursus.API", "Services", "CoreService.MetadataMigration.cs");

        Assert.Contains("No migration run was created", repository, StringComparison.Ordinal);
        Assert.Contains("the bootstrap transaction was rolled back", repository, StringComparison.Ordinal);
        Assert.Contains("MigrationBootstrapException", schemaService, StringComparison.Ordinal);
        Assert.Contains("StatusCode.FailedPrecondition", schemaService, StringComparison.Ordinal);
        Assert.Contains("MigrationBootstrapException", metadataService, StringComparison.Ordinal);
        Assert.Contains("StatusCode.FailedPrecondition", metadataService, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaValidateAndDeploymentPlan_UseOnlyExplicitlySelectedRows()
    {
        var ui = ReadRepositoryFile(
            "apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor");
        var service = ReadSchemaMigrationSource();
        var planSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SMigration.SchemaDeploymentPlan_Get.sql");
        var exclusionsBootstrap = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaExclusions.Bootstrap.sql");
        var workbenchBootstrap = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaWorkbench.Bootstrap.sql");
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("No selection means nothing is validated or deployed", ui, StringComparison.Ordinal);
        Assert.Contains("rows.Where(x => x.IsSelected)", service, StringComparison.Ordinal);
        Assert.Contains("NO_SELECTED_ROWS", service, StringComparison.Ordinal);
        Assert.DoesNotContain("DefaultSafeDeployable", service, StringComparison.Ordinal);
        Assert.Contains("ISNULL(selectionState.[IsSelected], CONVERT(BIT, 0)) = 1", planSql, StringComparison.Ordinal);
        Assert.DoesNotContain("WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, 1)", planSql, StringComparison.Ordinal);
        Assert.Contains("ISNULL(selectionState.[IsSelected], CONVERT(BIT, 0)) = 1", exclusionsBootstrap, StringComparison.Ordinal);
        Assert.Contains("ISNULL(sel.[IsSelected], CONVERT(BIT, 0)) = 1", workbenchBootstrap, StringComparison.Ordinal);
        Assert.Contains("The selected deployment plan is empty", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_SynchronizesAndVerifiesOnlyAcceptedSelectedDevSource()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");
        var readme = ReadRepositoryFile("tools", "SchemaDeployment", "README.md");

        Assert.Contains("[switch]$SyncSource", runner, StringComparison.Ordinal);
        Assert.Contains("[switch]$VerifySource", runner, StringComparison.Ordinal);
        Assert.Contains("Assert-RunCanSynchronizeSource", runner, StringComparison.Ordinal);
        Assert.Contains(
            "source is exactly DEV / CymBuild_Dev",
            runner,
            StringComparison.Ordinal);
        Assert.Contains(
            "Schema source synchronization requires an explicit saved selection",
            runner,
            StringComparison.Ordinal);
        Assert.Contains(
            "-not [bool]$_[\"HasExplicitSelection\"] -or -not [bool]$_[\"IsSelected\"]",
            runner,
            StringComparison.Ordinal);
        Assert.Contains("CYB_SCHEMA_SOURCE_SYNC_V1", runner, StringComparison.Ordinal);
        Assert.Contains("source-sync-manifest.json", runner, StringComparison.Ordinal);
        Assert.Contains("Restore-CymBuildSourceSyncFiles", runner, StringComparison.Ordinal);
        Assert.Contains(
            "Every schema source file written by this invocation was restored",
            runner,
            StringComparison.Ordinal);
        Assert.Contains("Source-sync rollback byte verification failed", runner, StringComparison.Ordinal);
        Assert.Contains(
            "Source sync never deletes or reuses an old canonical create script",
            runner,
            StringComparison.Ordinal);
        Assert.Contains("Get-CymBuildSchemaDefinitionHash", runner, StringComparison.Ordinal);
        Assert.Contains(
            "$normalizedDefinition = ConvertTo-CymBuildNormalizedSchemaDefinition -Definition $Definition",
            runner,
            StringComparison.Ordinal);
        Assert.Contains("return (Get-TextSha256 -Text $normalizedDefinition)", runner, StringComparison.Ordinal);
        Assert.Contains(
            "The persisted $($definitionCheck.Label) definition hash",
            runner,
            StringComparison.Ordinal);

        var sourceModeReturn = runner.IndexOf(
            "Selected DEV schema source $sourceAction successfully.",
            StringComparison.Ordinal);
        var targetPreflight = runner.IndexOf(
            "Set-SchemaPreflightContext -Connection $connection",
            StringComparison.Ordinal);
        Assert.True(sourceModeReturn >= 0, "The source-sync completion boundary was not found.");
        Assert.True(
            targetPreflight > sourceModeReturn,
            "Source sync and verification must return before target preflight/deployment starts.");

        Assert.Contains("## R7C selected DEV source sync", readme, StringComparison.Ordinal);
        Assert.Contains("no active selected rows: empty plan and fail closed", readme, StringComparison.Ordinal);
        Assert.DoesNotContain("no active selection rows: all deployable differences", readme, StringComparison.Ordinal);
    }

    /// <summary>
    /// SQL Server's CREATE/ALTER INDEX rejects an explicit FILLFACTOR literal of 0 ("Fillfactor 0
    /// is not a valid percentage; fillfactor must be between 1 and 100") - confirmed against a real
    /// target server after R7D13A started emitting it unconditionally. Omitting the option instead
    /// is not a safe substitute: it makes the deployed index inherit the target server's configured
    /// default fill factor, which is not guaranteed to be 0 (proven against SOC-SQLDEVBRE01\GENERAL,
    /// whose server-level default is 80, causing post-deployment verification failures). SQL Server
    /// persists an explicit FILLFACTOR = 100 in sys.indexes.fill_factor as 0, the same catalog value
    /// a captured 0 represents, so the generator must emit 100 explicitly when the captured value is
    /// 0, matching the PRIMARY KEY/UNIQUE constraint path immediately above it in the same file.
    /// </summary>
    [Fact]
    public void SchemaRunner_IndexMaterializationEmitsExplicitFillFactorAndReplacesAtomically()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains(
            "[void]$options.Add(\"FILLFACTOR = $(if ($fillFactor -gt 0) { $fillFactor } else { 100 })\")",
            runner.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);
        Assert.Contains("[void]$options.Add(\"DROP_EXISTING = ON\")", runner, StringComparison.Ordinal);
        Assert.Contains(
            "The existing target index remains available if replacement fails.",
            runner,
            StringComparison.Ordinal);
        Assert.Contains(
            "preserve the target index for atomic replacement during finalize",
            runner,
            StringComparison.Ordinal);
    }

    /// <summary>
    /// Behavioural guard on the actual deployable artefacts (not just the generator source): no
    /// committed index or constraint SQL file may contain a literal FILLFACTOR = 0, regardless of
    /// which code path produced it, because SQL Server refuses to execute it.
    /// </summary>
    [Fact]
    public void GeneratedSchemaSource_NeverEmitsLiteralZeroFillFactor()
    {
        var invalidFillFactor = new Regex(@"FILLFACTOR\s*=\s*0\b", RegexOptions.None);
        var violations = new List<string>();

        foreach (var directory in new[] { "Indexes", "Constraints" })
        {
            var fullPath = RepositoryLayout.PathFromRoot("Database", "CymBuild_DB", "Schema", directory);
            if (!Directory.Exists(fullPath))
            {
                continue;
            }

            foreach (var file in Directory.EnumerateFiles(fullPath, "*.sql", SearchOption.TopDirectoryOnly))
            {
                var content = File.ReadAllText(file);
                if (invalidFillFactor.IsMatch(content))
                {
                    violations.Add(Path.GetFileName(file));
                }
            }
        }

        Assert.True(
            violations.Count == 0,
            "Committed schema source contains a literal FILLFACTOR = 0, which SQL Server's "
            + "CREATE/ALTER INDEX rejects. Emit FILLFACTOR = 100 instead. Files: "
            + string.Join(", ", violations));
    }

    [Fact]
    public void SchemaRunner_VerifiesGeneratedSourceAgainstCurrentGeneratorOutput()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("Generator contract : R7D13", runner, StringComparison.Ordinal);
        Assert.Contains(
            "ConvertTo-CymBuildNormalizedGeneratedSourceContent",
            runner,
            StringComparison.Ordinal);
        Assert.Contains("$generatedContentMatches", runner, StringComparison.Ordinal);
        Assert.Contains(
            "does not match the current deterministic generator output. Run -SyncSource",
            runner,
            StringComparison.Ordinal);
        Assert.Contains(
            "Write-CymBuildTextFile -Path $Path -Content $Content",
            runner,
            StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaMigrationUi_ShowsCompleteDevSourceAndDeploymentCommandSequence()
    {
        var ui = ReadRepositoryFile(
            "apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor");

        Assert.Contains("IsAuthoritativeDevSource", ui, StringComparison.Ordinal);
        Assert.Contains("1. Generate source", ui, StringComparison.Ordinal);
        Assert.Contains("2. Review and test", ui, StringComparison.Ordinal);
        Assert.Contains("3. Verify committed source", ui, StringComparison.Ordinal);
        Assert.Contains("-SyncSource", ui, StringComparison.Ordinal);
        Assert.Contains("-VerifySource", ui, StringComparison.Ordinal);
        Assert.Contains("Invoke-CymBuildFastTests.ps1", ui, StringComparison.Ordinal);
        Assert.Contains("DEV source runs generate and verify the package once", ui, StringComparison.Ordinal);
        Assert.Contains("later environments reuse that committed package", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void Bootstrap_ChecksSelectedOnlyProceduresFromSourceControlEveryRun()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var selectedOnlyProcedures = new[]
        {
            "MetadataRunSelection_Clear",
            "MetadataRunSelection_Upsert",
            "MetadataIgnoredRecord_Upsert",
            "MetadataValidate_Run",
            "MetadataApplyPreviewFingerprint_Get",
            "MetadataApplyPreview_Accept",
            "MetadataApplyPreview_Get",
            "MetadataApply_Run"
        };

        Assert.Contains("MetadataAlwaysCheckedResources", repository, StringComparison.Ordinal);
        Assert.Contains("static _ => SchemaBootstrapResources", repository, StringComparison.Ordinal);
        Assert.Contains("if (resources.Count > 0", repository, StringComparison.Ordinal);

        foreach (var procedure in selectedOnlyProcedures)
        {
            Assert.Contains(procedure, repository, StringComparison.Ordinal);

            var sql = ReadRepositoryFile(
                "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
                $"SMigration.{procedure}.sql");
            Assert.Contains($"CREATE OR ALTER PROCEDURE [SMigration].[{procedure}]", sql, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void Bootstrap_InstallsAndConvergesMetadataValidationIssueIgnoreObjects()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var tableSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables",
            "SMigration.Metadata_ValidationIssueIgnores.sql");
        var procedureSql = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SMigration.MetadataValidationIssueIgnore_Upsert.sql");

        Assert.Contains("MetadataTable(145, \"Metadata_ValidationIssueIgnores\")", repository, StringComparison.Ordinal);
        Assert.Contains("MetadataProcedure(1195, \"MetadataValidationIssueIgnore_Upsert\")", repository, StringComparison.Ordinal);
        Assert.Contains("MetadataValidationIssueIgnore_Upsert.sql", repository, StringComparison.Ordinal);
        Assert.Contains("CREATE TABLE [SMigration].[Metadata_ValidationIssueIgnores]", tableSql, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE [SMigration].[MetadataValidationIssueIgnore_Upsert]", procedureSql, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaBootstrap_InstallsR7DExecutionAttemptAndCheckpointTables()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var project = ReadRepositoryFile("libs", "Concursus.EF", "Concursus.EF.csproj");
        var bootstrap = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaR7D.ExecutionHardening.Bootstrap.sql");
        var attempts = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables",
            "SMigration.Schema_DeploymentAttempts.sql");
        var checkpoints = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Tables",
            "SMigration.Schema_DeploymentObjectCheckpoints.sql");

        Assert.Contains("Schema_DeploymentAttempts", repository, StringComparison.Ordinal);
        Assert.Contains("Schema_DeploymentObjectCheckpoints", repository, StringComparison.Ordinal);
        Assert.Contains("SchemaR7D.ExecutionHardening.Bootstrap.sql", repository, StringComparison.Ordinal);
        Assert.Contains("SchemaR7D.ExecutionHardening.Bootstrap.sql", project, StringComparison.Ordinal);
        Assert.Contains("CREATE TABLE [SMigration].[Schema_DeploymentAttempts]", bootstrap, StringComparison.Ordinal);
        Assert.Contains("CREATE TABLE [SMigration].[Schema_DeploymentObjectCheckpoints]", bootstrap, StringComparison.Ordinal);
        Assert.Contains("incompatible partial shape", bootstrap, StringComparison.Ordinal);
        Assert.Contains("UX_Schema_DeploymentAttempts_Run_Attempt_Active", attempts, StringComparison.Ordinal);
        Assert.Contains("UX_Schema_DeploymentObjectCheckpoints_Attempt_Object_Phase_Active", checkpoints, StringComparison.Ordinal);
        Assert.Contains("WHERE [RowStatus] <> 0 AND [RowStatus] <> 254", attempts, StringComparison.Ordinal);
        Assert.Contains("WHERE [RowStatus] <> 0 AND [RowStatus] <> 254", checkpoints, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaBootstrap_R7DAuditDataObjectsUseExactStableOwnership()
    {
        var bootstrap = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Migrations", "CYB361",
            "SMigration.SchemaR7D.ExecutionHardening.Bootstrap.sql");
        var ensureProcedure = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SMigration.SchemaDataObject_Ensure.sql");
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("D7A10001-3610-47D0-A001-000000000001", bootstrap, StringComparison.Ordinal);
        Assert.Contains("D7A10001-3610-47D0-A002-000000000001", bootstrap, StringComparison.Ordinal);
        Assert.Contains("D7A10002-3610-47D0-A001-000000000002", bootstrap, StringComparison.Ordinal);
        Assert.Contains("D7A10002-3610-47D0-A002-000000000002", bootstrap, StringComparison.Ordinal);
        Assert.Contains("N'Schema Deployment Attempts'", bootstrap, StringComparison.Ordinal);
        Assert.Contains("N'Schema Deployment Object Checkpoints'", bootstrap, StringComparison.Ordinal);
        Assert.Contains("@RequireExactEntityType = 1", bootstrap, StringComparison.Ordinal);
        Assert.Contains("SET @AuditEntityTypeId = NULL;", bootstrap, StringComparison.Ordinal);
        Assert.Contains("@LegacyFallbackEntityTypeId", bootstrap, StringComparison.Ordinal);
        Assert.Contains("entityType.[Name] = N'EntityTypes'", bootstrap, StringComparison.Ordinal);
        Assert.Contains("dataObject.[EntityTypeId] <> @LegacyFallbackEntityTypeId", bootstrap, StringComparison.Ordinal);
        Assert.Contains("dataObject.[EntityTypeId] = @LegacyFallbackEntityTypeId", bootstrap, StringComparison.Ordinal);
        Assert.Contains("UPDATE dataObject", bootstrap, StringComparison.Ordinal);
        Assert.Contains("R7D active deployment-attempt DataObject ownership verification failed", bootstrap, StringComparison.Ordinal);
        Assert.Contains("R7D active deployment-checkpoint DataObject ownership verification failed", bootstrap, StringComparison.Ordinal);
        Assert.Contains("AS [checkpoint]", bootstrap, StringComparison.Ordinal);
        Assert.DoesNotContain("AS checkpoint", bootstrap, StringComparison.Ordinal);
        Assert.DoesNotContain("checkpoint.[", bootstrap, StringComparison.Ordinal);

        Assert.Contains("@RequireExactEntityType BIT = 0", ensureProcedure, StringComparison.Ordinal);
        Assert.Contains("@HasExactEntityType", ensureProcedure, StringComparison.Ordinal);
        Assert.Contains("cannot reactivate a DataObject by updating RowStatus directly", ensureProcedure, StringComparison.Ordinal);
        Assert.DoesNotContain("[RowStatus] = CASE WHEN", ensureProcedure, StringComparison.Ordinal);

        Assert.Contains("@RequireExactEntityType = 1", runner, StringComparison.Ordinal);
        Assert.Contains("HasAttemptOwnership", runner, StringComparison.Ordinal);
        Assert.Contains("HasCheckpointOwnership", runner, StringComparison.Ordinal);
        Assert.Contains("HasAuditDataObjectCompliance", runner, StringComparison.Ordinal);
        Assert.Contains("AS [checkpoint]", runner, StringComparison.Ordinal);
        Assert.DoesNotContain("AS checkpoint", runner, StringComparison.Ordinal);
        Assert.DoesNotContain("checkpoint.[", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaBootstrap_R7D8ConvergesLifecycleProceduresOnSourceAndTarget()
    {
        var repository = ReadRepositoryFile("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");
        var project = ReadRepositoryFile("libs", "Concursus.EF", "Concursus.EF.csproj");
        var service = ReadSchemaMigrationSource();
        var procedures = new[]
        {
            "SCHEMABINDING",
            "SchemaBindingApplySingleObject",
            "RebuildRecordHistoryTriggers",
            "PostDeploymentScript"
        };

        Assert.Contains("var targetBootstrap", service, StringComparison.Ordinal);
        Assert.Contains("var sourceBootstrap", service, StringComparison.Ordinal);
        Assert.Contains("EnsureSchemaWorkbenchAsync", service, StringComparison.Ordinal);
        Assert.Contains("static _ => SchemaBootstrapResources", repository, StringComparison.Ordinal);

        foreach (var procedure in procedures)
        {
            Assert.Contains($"\"SCore\", \"{procedure}\"", repository, StringComparison.Ordinal);
            Assert.Contains($"Schema.SCore.{procedure}.sql", repository, StringComparison.Ordinal);
            Assert.Contains($"SCore.{procedure}.sql", project, StringComparison.Ordinal);

            var sql = ReadRepositoryFile(
                "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
                $"SCore.{procedure}.sql");
            Assert.Contains($"CREATE OR ALTER PROCEDURE [SCore].[{procedure}]", sql, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void SchemaRunner_R7DUsesSessionLockAndRejectsPartialApply()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("CYB-361 R7D selected DEV source-sync", runner, StringComparison.Ordinal);
        Assert.Contains("[int]$ApplyLockTimeoutSeconds = 0", runner, StringComparison.Ordinal);
        Assert.Contains("sys.sp_getapplock", runner, StringComparison.Ordinal);
        Assert.Contains("@LockMode = N'Exclusive'", runner, StringComparison.Ordinal);
        Assert.Contains("@LockOwner = N'Session'", runner, StringComparison.Ordinal);
        Assert.Contains("sys.sp_releaseapplock", runner, StringComparison.Ordinal);
        Assert.Contains("Another schema deployment apply is already active", runner, StringComparison.Ordinal);
        Assert.Contains("-Apply cannot be combined with -AllowPartial", runner, StringComparison.Ordinal);
        Assert.Contains("Assert-RunUsesR7DBootstrapEvidence", runner, StringComparison.Ordinal);
        Assert.Contains("SchemaR7D.ExecutionHardening.Bootstrap.sql", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_R7DRechecksPlanAndTargetBeforePreDeployment()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");
        var mainStart = runner.IndexOf("function Invoke-CymBuildSchemaDeployment", StringComparison.Ordinal);
        var main = runner[mainStart..];
        var lockIndex = main.IndexOf("Acquire-CymBuildSchemaDeploymentLock -Connection $connection", StringComparison.Ordinal);
        var planIndex = main.IndexOf("$lockedPlanFingerprint", StringComparison.Ordinal);
        var baselineIndex = main.IndexOf("Assert-CymBuildTargetBaseline", StringComparison.Ordinal);
        var contextIndex = main.IndexOf("Set-SchemaPreflightContext -Connection $connection", StringComparison.Ordinal);
        var preDeploymentIndex = main.IndexOf("Running SCore.PreDeploymentScript", StringComparison.Ordinal);

        Assert.True(lockIndex >= 0, "The apply-lock boundary was not found.");
        Assert.True(planIndex > lockIndex, "The selected plan must be fingerprinted again under the apply lock.");
        Assert.True(baselineIndex > planIndex, "Target drift must be checked after the locked plan check.");
        Assert.True(contextIndex > baselineIndex, "Target drift must be checked before preflight context is set.");
        Assert.True(preDeploymentIndex > contextIndex, "Target drift must be checked before SCore.PreDeploymentScript.");
        Assert.Contains("TargetHash", runner, StringComparison.Ordinal);
        Assert.Contains("target-drift-failures.csv", runner, StringComparison.Ordinal);
        Assert.Contains("No pre-deployment script or selected DDL was run", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_R7DPersistsAttemptsCheckpointsAndVerifiesBeforeSuccess()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");
        var mainStart = runner.IndexOf("function Invoke-CymBuildSchemaDeployment", StringComparison.Ordinal);
        var main = runner[mainStart..];
        var appliedVerificationIndex = main.IndexOf("Assert-CymBuildAppliedSourceVerification", StringComparison.Ordinal);
        var postDeploymentIndex = main.IndexOf("Running SCore.PostDeploymentScript", StringComparison.Ordinal);
        var lifecycleReapplyIndex = main.IndexOf("Invoke-CymBuildSelectedPostDeploymentReapply", StringComparison.Ordinal);
        var verificationIndex = main.IndexOf("Assert-CymBuildPostDeploymentVerification", StringComparison.Ordinal);
        var successIndex = main.IndexOf("$finalStatus = \"DeploymentApplied\"", StringComparison.Ordinal);

        Assert.Contains("Start-CymBuildSchemaDeploymentAttempt", runner, StringComparison.Ordinal);
        Assert.Contains("Complete-CymBuildSchemaDeploymentAttempt", runner, StringComparison.Ordinal);
        Assert.Contains("Set-CymBuildSchemaObjectCheckpoint", runner, StringComparison.Ordinal);
        Assert.Contains("SchemaDataObject_Ensure", runner, StringComparison.Ordinal);
        Assert.Contains("CYB_SCHEMA_DEPLOYMENT_R7D", runner, StringComparison.Ordinal);
        Assert.Contains("TargetBaseline", runner, StringComparison.Ordinal);
        Assert.Contains("Verification", runner, StringComparison.Ordinal);
        Assert.Contains("post-apply-verification-failures.csv", runner, StringComparison.Ordinal);
        Assert.Contains("SourceHash", runner, StringComparison.Ordinal);
        Assert.True(appliedVerificationIndex >= 0, "The pre-post-deployment verification boundary was not found.");
        Assert.True(postDeploymentIndex > appliedVerificationIndex, "Accepted source state must be verified before PostDeployment can rewrite lifecycle-managed objects.");
        Assert.True(postDeploymentIndex >= 0, "The post-deployment boundary was not found.");
        Assert.True(lifecycleReapplyIndex > postDeploymentIndex, "Selected lifecycle-generated objects must be reapplied from canonical source after PostDeployment.");
        Assert.True(verificationIndex > lifecycleReapplyIndex, "Final verification must run after selected lifecycle-generated objects are reapplied.");
        Assert.True(verificationIndex > postDeploymentIndex, "Verification must run after post-deployment restoration.");
        Assert.True(successIndex > verificationIndex, "DeploymentApplied must be written only after verification succeeds.");
    }

    [Fact]
    public void SchemaRunner_R7DVerificationAllowsControlledSchemaBindingLifecycleState()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("[switch]$IgnoreOperationalSchemaBinding", runner, StringComparison.Ordinal);
        Assert.Contains("\\GWITH\\s+SCHEMABINDING\\b", runner, StringComparison.Ordinal);
        Assert.Contains("SupportsOperationalSchemaBindingLifecycle", runner, StringComparison.Ordinal);
        Assert.Contains("$objectType.Equals(\"Function\"", runner, StringComparison.Ordinal);
        Assert.Contains("$objectType.Equals(\"View\"", runner, StringComparison.Ordinal);
        Assert.Contains("OperationalSourceHash", runner, StringComparison.Ordinal);
        Assert.Contains("OperationalTargetHash", runner, StringComparison.Ordinal);
        Assert.Contains("$acceptedOperationalTargetHash", runner, StringComparison.Ordinal);
        Assert.Contains("$acceptedOperationalSourceHash", runner, StringComparison.Ordinal);
        Assert.Contains("$matchesAcceptedSourceOnRetry", runner, StringComparison.Ordinal);
        // The target-side operational-schema-binding match is intentionally NOT gated by
        // -RetryFailedDeployment: Compare itself runs every comparison through
        // SCore.PreDeploymentScript -> snapshot -> SCore.PostDeploymentScript, so a
        // schema-bound Function/View's live target is routinely back in its bound shape
        // by the time WhatIf/Apply re-snapshots it on an ordinary first run, not only on a
        // retry. Gating this behind -RetryFailedDeployment made every such object
        // permanently undeployable (evidence: artifacts/schema-deployment runs from
        // 2026-09-04 and 2026-09-08 that never reached a successful QA apply).
        Assert.Contains("$matchesOperationalTarget = [bool]$item.SupportsOperationalSchemaBindingLifecycle -and", runner, StringComparison.Ordinal);
        Assert.DoesNotContain("$matchesOperationalTargetOnRetry", runner, StringComparison.Ordinal);
        // The source-side operational match remains retry-only: it tolerates a target that
        // already carries the accepted SOURCE definition from a prior partial/failed apply,
        // which is only a valid state to resume from, never a routine first-run baseline.
        Assert.Contains("$matchesOperationalSourceOnRetry = $RetryFailedDeployment -and", runner, StringComparison.Ordinal);
        Assert.Contains("-RetryFailedDeployment cannot skip SCore.PreDeploymentScript or SCore.PostDeploymentScript", runner, StringComparison.Ordinal);
        Assert.Contains("AcceptedTargetOperationalSchemaBinding", runner, StringComparison.Ordinal);
        Assert.Contains("AcceptedSourceOperationalSchemaBinding", runner, StringComparison.Ordinal);
        Assert.Contains("ObservedOperationalHash", runner, StringComparison.Ordinal);
        Assert.Contains("normalizing only the controlled WITH SCHEMABINDING lifecycle clause", runner, StringComparison.Ordinal);
        Assert.Contains("immutable accepted target/source state", runner, StringComparison.Ordinal);
        Assert.DoesNotContain("if ($RetryFailedDeployment) { $succeeded = $true", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_R7D7RequiresAcceptedCommittedSourceWithoutImplicitMaterialisation()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("$sourceWriteAllowed = [bool]$SyncSource", runner, StringComparison.Ordinal);
        Assert.Contains("$sourceMatchRequired = $true", runner, StringComparison.Ordinal);
        Assert.Contains("$shouldEvaluateProgrammableSource = $isProgrammableObject", runner, StringComparison.Ordinal);
        Assert.Contains("Assert-CymBuildSelectedSourceControlState", runner, StringComparison.Ordinal);
        Assert.Contains("selected-source-control-failures.csv", runner, StringComparison.Ordinal);
        Assert.Contains("SelectedSourceFingerprint", runner, StringComparison.Ordinal);
        Assert.Contains("CYMBUILD_GIT_EXE", runner, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "$sourceWriteAllowed = -not $SkipSourceMaterialization -and -not $VerifySource",
            runner,
            StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_R7D7UsesStrictCorrelatedPostDeploymentAndLifecycleAttribution()
    {
        var runner = ReadRepositoryFile(
            "tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");
        var postDeployment = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.PostDeploymentScript.sql");

        Assert.Contains("@ThrowOnIssues = 1", runner, StringComparison.Ordinal);
        Assert.Contains("$postDeploymentInvoked = $true", runner, StringComparison.Ordinal);
        Assert.Contains("-not $postDeploymentInvoked", runner, StringComparison.Ordinal);
        Assert.Contains("post-deployment-issues.csv", runner, StringComparison.Ordinal);
        Assert.Contains("restricted to DEV apply diagnostics", runner, StringComparison.Ordinal);
        Assert.Contains("PrePostDeploymentVerification", runner, StringComparison.Ordinal);
        Assert.Contains("-AllowOperationalSchemaBinding $false", runner, StringComparison.Ordinal);
        Assert.Contains("PostLifecycleReapply", runner, StringComparison.Ordinal);
        Assert.Contains("ManualDeploymentPostLifecycleReapply", runner, StringComparison.Ordinal);
        Assert.Contains("@RunGuid UNIQUEIDENTIFIER = NULL", postDeployment, StringComparison.Ordinal);
        Assert.Contains("@RunGuid = @RunGuid", postDeployment, StringComparison.Ordinal);
        Assert.Contains("N'Schema binding verification'", postDeployment, StringComparison.Ordinal);
        Assert.Contains("sm.definition LIKE N'%--WITH SCHEMABINDING%'", postDeployment, StringComparison.Ordinal);
        Assert.Contains("sm.is_schema_bound = 1", postDeployment, StringComparison.Ordinal);
        Assert.Contains("sm.is_schema_bound = 0", postDeployment, StringComparison.Ordinal);
        Assert.Contains("the prepared marker alone does not fail deployment", postDeployment, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_R7D9RestoresEveryPreparedDatabaseBeforePersistingSuccess()
    {
        var schemaService = ReadSchemaMigrationSource();
        var schemaPage = ReadRepositoryFile(
            "apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor");
        var schemaEngine = ReadSchemaEngineFile("SchemaMigrationEngine.cs");
        var compareStart = schemaEngine.IndexOf(
            "public async Task CompareAsync(",
            StringComparison.Ordinal);
        var validateStart = schemaEngine.IndexOf(
            "public async Task<SchemaValidationResult> ValidateAsync(",
            compareStart,
            StringComparison.Ordinal);
        var compareMethod = schemaEngine[compareStart..validateStart];

        Assert.Contains("await SchemaEngine.CompareAsync(", schemaService, StringComparison.Ordinal);
        var snapshotIndex = compareMethod.IndexOf("BuildSchemaComparisonRows(", StringComparison.Ordinal);
        var restorationIndex = compareMethod.IndexOf("RestoreSchemaComparePreparationAsync(", StringComparison.Ordinal);
        var persistenceIndex = compareMethod.IndexOf("BeginTransactionAsync", restorationIndex, StringComparison.Ordinal);

        Assert.True(snapshotIndex >= 0, "Schema comparison snapshots are not built.");
        Assert.True(restorationIndex > snapshotIndex, "Prepared databases must be restored after snapshot capture.");
        Assert.True(persistenceIndex > restorationIndex, "Successful comparison rows must not be persisted before restoration succeeds.");
        Assert.Contains("CancellationToken.None", compareMethod, StringComparison.Ordinal);
        Assert.Contains("@ThrowOnIssues = 1, @RunGuid = @RunGuid", schemaService, StringComparison.Ordinal);
        Assert.Contains("SourcePostDeployment", schemaService, StringComparison.Ordinal);
        Assert.Contains("TargetPostDeployment", schemaService, StringComparison.Ordinal);
        Assert.Contains("on both success and failure", schemaPage, StringComparison.Ordinal);
        Assert.Contains("The comparison is not saved if restoration fails", schemaPage, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaCompare_R7D9TreatsOnlyTheControlledSchemaBindingClauseAsOperationallyEquivalent()
    {
        var schemaService = ReadSchemaMigrationSource();
        var applySingle = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.SchemaBindingApplySingleObject.sql");
        var postDeployment = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.PostDeploymentScript.sql");

        Assert.Contains("RemoveOperationalSchemaBindingClause", schemaService, StringComparison.Ordinal);
        Assert.Contains("SupportsOperationalSchemaBindingLifecycle", schemaService, StringComparison.Ordinal);
        Assert.Contains("sourceRow.OperationalHash.Equals(targetRow.OperationalHash", schemaService, StringComparison.Ordinal);
        Assert.Contains(@"\GWITH\s+SCHEMABINDING\b", schemaService, StringComparison.Ordinal);
        Assert.Contains("@PreparedMarkerRemoved", applySingle, StringComparison.Ordinal);
        Assert.Contains("Remove it only while scanning executable SQL", applySingle, StringComparison.Ordinal);
        Assert.Contains("@SchemaBindingCleanupWork", postDeployment, StringComparison.Ordinal);
        Assert.Contains("sm.is_schema_bound = 1", postDeployment, StringComparison.Ordinal);
        Assert.Contains("N'Warning'", postDeployment, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "A remaining marker\n            therefore proves that post-deployment did not restore that module",
            postDeployment.Replace("\r\n", "\n", StringComparison.Ordinal),
            StringComparison.Ordinal);
    }

    [Fact]
    public void PostDeployment_R7D10ScopesRetriesAndKeepsBestEffortBindingDiagnostic()
    {
        var applySingle = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.SchemaBindingApplySingleObject.sql");
        var schemaBinding = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.SCHEMABINDING.sql");
        var postDeployment = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.PostDeploymentScript.sql");
        var schemaService = ReadSchemaMigrationSource();

        Assert.Contains("WHEN @ThrowOnError = 0 THEN N'Warning'", applySingle, StringComparison.Ordinal);
        Assert.Contains("@Apply = 0 AND sm.is_schema_bound = 1", schemaBinding, StringComparison.Ordinal);
        Assert.Contains("@Apply = 1", schemaBinding, StringComparison.Ordinal);
        Assert.Contains("AND sm.is_schema_bound = 0", schemaBinding, StringComparison.Ordinal);
        Assert.Contains("DECLARE @InvocationStartLogId INT = 0", postDeployment, StringComparison.Ordinal);
        Assert.Equal(4, Regex.Matches(postDeployment, @"AND ID > @InvocationStartLogId").Count);
        Assert.Contains("@SchemaBindingPreparedWork", postDeployment, StringComparison.Ordinal);
        Assert.Contains("is schema-bound and operational", postDeployment, StringComparison.Ordinal);
        Assert.Contains("is_schema_bound is authoritative", postDeployment, StringComparison.Ordinal);
        Assert.Contains("ReadPostDeploymentFailureDiagnosticsAsync", schemaService, StringComparison.Ordinal);
        Assert.Contains("Correlated SCore.PostDeploymentRunLog errors", schemaService, StringComparison.Ordinal);
        Assert.Contains("log RunGuid", schemaService, StringComparison.Ordinal);
    }

    [Fact]
    public void PostDeployment_R7D7SafelyBuildsHistoryTriggersFromPhysicalColumns()
    {
        var rebuild = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.RebuildRecordHistoryTriggers.sql");

        Assert.Contains("CREATE OR ALTER TRIGGER", rebuild, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("JOIN\tsys.columns physicalColumn", rebuild, StringComparison.Ordinal);
        Assert.Contains("Skipped active EntityProperty", rebuild, StringComparison.Ordinal);
        Assert.Contains("QUOTENAME(@ColumnName)", rebuild, StringComparison.Ordinal);
        Assert.Contains("@ThrowOnError BIT = 1", rebuild, StringComparison.Ordinal);
        Assert.DoesNotContain("DROP TRIGGER ", rebuild, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PostDeployment_R7D7SchemaBindingParserIgnoresCommentsAndEscalatesHardErrors()
    {
        var applySingle = ReadRepositoryFile(
            "Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.SchemaBindingApplySingleObject.sql");

        Assert.Contains("@LexicalState", applySingle, StringComparison.Ordinal);
        Assert.Contains("@BlockDepth", applySingle, StringComparison.Ordinal);
        Assert.Contains("Unterminated block comment in module definition", applySingle, StringComparison.Ordinal);
        Assert.Contains("WHEN @ThrowOnError = 0 THEN N'Warning'", applySingle, StringComparison.Ordinal);
        Assert.Contains("WHEN ERROR_NUMBER() IN (3729, 4513) THEN N'Warning'", applySingle, StringComparison.Ordinal);
        Assert.Contains("ELSE N'Error'", applySingle, StringComparison.Ordinal);
    }

    [Fact]
    public void SchemaRunner_R7DSnapshotSqlExactlyMatchesApiSnapshotQueries()
    {
        static string NormalizeLineEndings(string value) =>
            value.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');

        var service = ReadSchemaEngineFile("SchemaSnapshotSql.cs");
        var snapshot = ReadRepositoryFile(
            "tools", "SchemaDeployment", "SchemaTargetSnapshot.R7D.sql");
        var queryNames = new[]
        {
            "Schemas", "Tables", "TableTypes", "Modules", "Sequences",
            "KeyConstraints", "ForeignKeyConstraints", "CheckConstraints",
            "DefaultConstraints", "Indexes"
        };

        foreach (var queryName in queryNames)
        {
            var serviceMatch = Regex.Match(
                service,
                $"public const string {queryName} = @\"(?<sql>.*?)\";",
                RegexOptions.Singleline | RegexOptions.CultureInvariant);
            Assert.True(serviceMatch.Success, $"API snapshot query {queryName} was not found.");
            var expectedSql = NormalizeLineEndings(
                serviceMatch.Groups["sql"].Value.Replace("\"\"", "\"").Trim());

            var runnerMatch = Regex.Match(
                snapshot,
                $@"(?ms)^-- CYMBUILD SNAPSHOT QUERY: {queryName}\s*\r?\n(?<sql>.*?)(?=^\s*GO\s*$)",
                RegexOptions.CultureInvariant);
            Assert.True(runnerMatch.Success, $"Runner snapshot query {queryName} was not found.");
            var actualSql = NormalizeLineEndings(runnerMatch.Groups["sql"].Value.Trim());

            Assert.Equal(expectedSql, actualSql);
        }
    }

    private static string ReadRepositoryFile(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments));

    // The Schema Migration workbench is CoreService.SchemaMigration.cs (RPC surface) delegating to the
    // shared engine in libs/Concursus.EF/SchemaMigration (also used by the headless CLI). Source
    // contracts that are not about one specific file read both, so they hold wherever the code lives.
    internal static string ReadSchemaMigrationSource()
    {
        var engineFiles = Directory
            .GetFiles(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "SchemaMigration"), "*.cs")
            .OrderBy(path => path, StringComparer.Ordinal)
            .Select(File.ReadAllText);

        return string.Join(
            "\n",
            new[] { ReadRepositoryFile("services", "Concursus.API", "Services", "CoreService.SchemaMigration.cs") }
                .Concat(engineFiles));
    }

    private static string ReadSchemaEngineFile(string fileName) =>
        ReadRepositoryFile("libs", "Concursus.EF", "SchemaMigration", fileName);
}
