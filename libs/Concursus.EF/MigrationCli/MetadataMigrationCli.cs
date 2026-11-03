using System.Data;
using System.Text.Json;
using Concursus.EF.MetadataMigration;
using Microsoft.Data.SqlClient;

namespace Concursus.EF.MigrationCli;

/// <summary>
/// Headless metadata migration for tools/Deployment/Publish-CymBuildServer.ps1 (verb
/// <c>metadata-auto</c>). Drives the same procedures and repository methods as the Metadata
/// Migration workbench, in the same order:
///   accepted run (preview still current) -> apply; otherwise
///   create -> stage (no retirements) -> select every Insert/Update row in a table with an apply
///   handler -> add dependencies -> validate -> build identity map -> preview -> accept -> apply.
/// Every successful outcome, including nothing to apply, ends by checking that the target's query
/// calls match its functions and procedures (SMigration.MetadataQuerySignature_Check).
/// Any validation failure, blocked preview row, unsupported table or drift stops the step: the
/// run is left as it is for the workbench, and the failure is written to the JSON report.
/// </summary>
public static class MetadataMigrationCli
{
    public const int ExitSuccess = 0;
    public const int ExitHandledFailure = 2;
    public const int ExitUsage = 4;

    /// <summary>
    /// Tables MetadataApply_Run has handlers for. Must match the allowlist in
    /// SMigration.MetadataValidate_Run (UnsupportedApplyHandler); a contract test enforces it.
    /// </summary>
    public static readonly IReadOnlyList<(string Schema, string Table)> HandledTables =
    [
        ("SCore", "LanguageLabels"),
        ("SCore", "LanguageLabelTranslations"),
        ("SCore", "EntityDataTypes"),
        ("SCore", "EntityTypes"),
        ("SCore", "EntityHobts"),
        ("SCore", "EntityPropertyGroups"),
        ("SCore", "EntityQueries"),
        ("SCore", "EntityProperties"),
        ("SCore", "EntityQueryParameters"),
        ("SCore", "EntityPropertyDependants"),
        ("SUserInterface", "Icons"),
        ("SUserInterface", "DropDownListDefinitions"),
        ("SUserInterface", "GridDefinitions"),
        ("SUserInterface", "GridViewDefinitions"),
        ("SUserInterface", "GridViewColumnDefinitions"),
        ("SJob", "MilestoneTypes"),
    ];

    /// <summary>Same rule as the API's MetadataMigrationStage: trimmed, '/' as '\', case-insensitive.</summary>
    public static bool IsSameSqlServer(string? sourceServerName, string? targetServerName)
    {
        static string Normalize(string? value) =>
            (value ?? string.Empty).Trim().Replace("/", "\\", StringComparison.Ordinal).ToUpperInvariant();

        var source = Normalize(sourceServerName);
        var target = Normalize(targetServerName);
        return source.Length > 0 && target.Length > 0 && string.Equals(source, target, StringComparison.Ordinal);
    }

    public static bool IsHandledTable(string schema, string table) =>
        HandledTables.Any(t => string.Equals(t.Schema, schema, StringComparison.OrdinalIgnoreCase)
                            && string.Equals(t.Table, table, StringComparison.OrdinalIgnoreCase));

    /// <summary>A staged row is auto-selected when it is an Insert/Update, not a retirement, not ignored, in a handled table.</summary>
    public static bool IsAutoSelectable(string schema, string table, string differenceType, int? sourceRowStatus, bool isIgnored) =>
        !isIgnored
        && (differenceType == "Insert" || differenceType == "Update")
        && (sourceRowStatus ?? 1) != 254
        && IsHandledTable(schema, table);

    public sealed record Report
    {
        public string Mode { get; set; } = "";
        public string Status { get; set; } = "";
        public Guid? RunGuid { get; set; }
        public int SelectedCount { get; set; }
        public int DependencyCount { get; set; }
        public int ApplyCount { get; set; }
        public int SkippedUnsupportedCount { get; set; }
        public List<string> SkippedUnsupportedTables { get; set; } = [];
        public List<string> Issues { get; set; } = [];
        public string Message { get; set; } = "";
    }

    private sealed record Options(
        string TargetServer, string TargetDatabase, string SourceServer, string SourceDatabase,
        string SourceEnvironment, string TargetEnvironment, string OutPath, string ConnectionTemplate);

    private sealed record StagedCandidate(string SchemaName, string TableName, Guid SourceRowGuid, string DifferenceType);

    public static async Task<int> RunAsync(string[] args, CancellationToken ct)
    {
        Options options;
        try
        {
            options = ParseOptions(args);
        }
        catch (ArgumentException ex)
        {
            Console.Error.WriteLine(ex.Message);
            Console.Error.WriteLine("Usage: metadata-auto --target-server S --target-database D --source-server S --source-database D [--source-environment DEV] [--target-environment QA] [--out file.json] [--connection-template CS]");
            return ExitUsage;
        }

        var report = new Report();
        int exitCode;
        try
        {
            exitCode = await ExecuteAsync(options, report, ct).ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            report.Status = "Failed";
            report.Message = ex.Message;
            exitCode = ExitHandledFailure;
        }

        await File.WriteAllTextAsync(
            options.OutPath,
            JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }),
            ct).ConfigureAwait(false);
        Console.WriteLine($"metadata-auto: {report.Status} ({report.Mode}) {report.Message}");
        return exitCode;
    }

    private static async Task<int> ExecuteAsync(Options o, Report report, CancellationToken ct)
    {
        var configuration = new ConnectionStringConfiguration(o.ConnectionTemplate);

        await using var target = await OpenAsync(o.ConnectionTemplate, o.TargetServer, o.TargetDatabase, ct).ConfigureAwait(false);

        var exitCode = await MigrateAsync(target, configuration, o, report, ct).ConfigureAwait(false);
        return exitCode == ExitSuccess
            ? await VerifyQuerySignaturesAsync(target, report, ct).ConfigureAwait(false)
            : exitCode;
    }

    private static async Task<int> MigrateAsync(SqlConnection target, ConnectionStringConfiguration configuration, Options o, Report report, CancellationToken ct)
    {
        var repository = new MetadataMigrationRepository(configuration);

        // 1. An accepted run whose acceptance is still current takes priority.
        var acceptedRun = await FindAcceptedUnappliedRunAsync(target, o, ct).ConfigureAwait(false);
        if (acceptedRun is Guid accepted)
        {
            report.RunGuid = accepted;
            var preview = await repository.GetApplyPreviewAsync(accepted, true, true, o.TargetServer, o.TargetDatabase, ct).ConfigureAwait(false);
            report.Mode = preview.IsAccepted ? "accepted" : "refreshed";
            return await AcceptAndApplyAsync(repository, target, o, accepted, preview, report, ct).ConfigureAwait(false);
        }

        // 2. Otherwise create, stage and select, exactly as the workbench does.
        report.Mode = "created";

        // CYB-584: SMigration.MetadataStage_Run and MetadataApplyIdentityMap_Build read the source by
        // three-part name, so they only reach a source on the same SQL Server. QA -> UAT
        // (10.100.34.114 -> SOC-SQLBRE01) staged nothing and reported "nothing-to-do" on 13, 14 and
        // 16 Oct. Across servers, stage and sync the registry over two connections, exactly as the
        // Metadata Migration workbench does (MetadataTwoConnectionStaging, shared with the API).
        var sameServer = IsSameSqlServer(o.SourceServer, o.TargetServer);
        await using var source = sameServer ? null : await OpenAsync(o.ConnectionTemplate, o.SourceServer, o.SourceDatabase, ct).ConfigureAwait(false);
        var bootstrap = new MigrationBootstrapRepository(configuration);
        var bootstrapResult = await bootstrap.EnsureMetadataWorkbenchAsync(o.TargetServer, o.TargetDatabase, o.TargetEnvironment, ct).ConfigureAwait(false);
        // CYB-584: the bootstrap no longer replaces existing procedures; say when this build disagrees.
        report.Issues.AddRange(bootstrapResult.DivergentModules.Select(module =>
            $"BootstrapDivergentModule: {module} in {o.TargetDatabase} differs from this build and was not replaced. Deploy schema to update it, or update this branch."));
        await ExecProcAsync(target, "SMigration.MetadataRegistry_Seed", [], 300, ct).ConfigureAwait(false);

        var runGuid = await CreateRunAsync(target, o, ct).ConfigureAwait(false);
        report.RunGuid = runGuid;
        if (source is null)
        {
            await ExecProcAsync(target, "SMigration.MetadataStage_Run", [new SqlParameter("@RunGuid", runGuid)], 600, ct).ConfigureAwait(false);
        }
        else
        {
            await MetadataTwoConnectionStaging.StageMetadataWithTwoConnectionsAsync(source, target, runGuid, includeRetirements: false, ct).ConfigureAwait(false);
        }

        // Staging records blockers (e.g. RegisteredSourceTableMissing) as Fail issues and stages
        // nothing for those tables. Never report "nothing-to-do" for a run that compared nothing.
        var stageFailures = await ReadFailIssuesAsync(target, runGuid, ct).ConfigureAwait(false);
        if (stageFailures.Count > 0)
        {
            report.Issues = stageFailures;
            return Fail(report, $"Staging failed ({stageFailures.Count} fail issue(s)); nothing was selected or applied. Resolve in the Metadata Migration workbench.");
        }

        var staged = await ReadActionableStagedRowsAsync(target, runGuid, ct).ConfigureAwait(false);
        var candidates = staged.Where(s => IsHandledTable(s.SchemaName, s.TableName)).ToList();
        var unsupported = staged.Where(s => !IsHandledTable(s.SchemaName, s.TableName)).ToList();
        report.SkippedUnsupportedCount = unsupported.Count;
        report.SkippedUnsupportedTables = unsupported.Select(s => $"{s.SchemaName}.{s.TableName}").Distinct().Order().ToList();

        if (candidates.Count == 0)
        {
            report.Mode = "nothing-to-do";
            report.Status = "Succeeded";
            report.Message = "No metadata differences to apply.";
            return ExitSuccess;
        }

        report.DependencyCount = await SelectAsync(target, runGuid, candidates, ct).ConfigureAwait(false);

        var unsupportedSelected = await ReadSelectedUnsupportedTablesAsync(target, runGuid, ct).ConfigureAwait(false);
        if (unsupportedSelected.Count > 0)
        {
            return Fail(report, $"Dependencies selected rows in tables without an apply handler: {string.Join(", ", unsupportedSelected)}. Resolve the selection in the Metadata Migration workbench.");
        }

        await ExecProcAsync(target, "SMigration.MetadataValidate_Run", [new SqlParameter("@RunGuid", runGuid)], 600, ct).ConfigureAwait(false);
        if (source is null)
        {
            await ExecProcAsync(target, "SMigration.MetadataApplyIdentityMap_Build", [new SqlParameter("@RunGuid", runGuid)], 600, ct).ConfigureAwait(false);
        }
        else
        {
            // The proc's own registry sync is same-server only: sync over two connections, then skip it.
            await MetadataTwoConnectionStaging.SyncMetadataRegistryFromEntityTypesAsync(source, target, runGuid, ct).ConfigureAwait(false);
            await ExecProcAsync(target, "SMigration.MetadataApplyIdentityMap_Build",
                [new SqlParameter("@RunGuid", runGuid), new SqlParameter("@SkipRegistrySync", SqlDbType.Bit) { Value = true }], 600, ct).ConfigureAwait(false);
        }

        var freshPreview = await repository.GetApplyPreviewAsync(runGuid, true, true, o.TargetServer, o.TargetDatabase, ct).ConfigureAwait(false);
        return await AcceptAndApplyAsync(repository, target, o, runGuid, freshPreview, report, ct).ConfigureAwait(false);
    }

    private static async Task<int> AcceptAndApplyAsync(
        MetadataMigrationRepository repository, SqlConnection target, Options o, Guid runGuid,
        MetadataMigrationRepository.ApplyPreviewResult preview, Report report, CancellationToken ct)
    {
        var applyRows = preview.Rows.Count(r => r.ApplyAction == "Apply");
        var blocked = preview.Rows.Count(r => r.ApplyAction == "Blocked");
        var runFailures = preview.Rows.Select(r => r.RunValidationFailureCount).DefaultIfEmpty(0).Max();
        report.SelectedCount = preview.Rows.Count(r => r.IsSelected);
        report.ApplyCount = applyRows;

        if (runFailures > 0 || blocked > 0)
        {
            report.Issues = await ReadFailIssuesAsync(target, runGuid, ct).ConfigureAwait(false);
            return Fail(report, $"Validation failed ({runFailures} fail issue(s), {blocked} blocked row(s)). Resolve in the Metadata Migration workbench.");
        }

        if (applyRows == 0)
        {
            report.Status = "Succeeded";
            report.Message = "Preview has no rows to apply.";
            return ExitSuccess;
        }

        if (!preview.IsAccepted)
        {
            var acceptance = await repository.AcceptApplyPreviewAsync(runGuid, true, preview.PreviewFingerprint, o.TargetServer, o.TargetDatabase, ct).ConfigureAwait(false);
            if (!acceptance.IsAccepted)
            {
                return Fail(report, $"Preview was not accepted: {acceptance.Message}");
            }
        }

        await repository.ApplyAsync(runGuid, forceApply: false, applySelectedOnly: true, o.TargetServer, o.TargetDatabase, ct).ConfigureAwait(false);
        report.Status = "Succeeded";
        report.Message = $"Applied {applyRows} metadata row(s).";
        return ExitSuccess;
    }

    // CYB-584: Validate only runs when a run has rows to apply. On 14 Oct the QA -> UAT run ended
    // "nothing-to-do" while every Activity save in UAT failed, because the Activities query passed 9
    // arguments to a function that now takes 11. Whatever the outcome, check the target's end state.
    private static async Task<int> VerifyQuerySignaturesAsync(
        SqlConnection target, Report report, CancellationToken ct)
    {
        const string checkProcedure = "SMigration.MetadataQuerySignature_Check";

        await using (var exists = new SqlCommand("SELECT OBJECT_ID(@Name, N'P');", target) { CommandTimeout = 60 })
        {
            exists.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar, 256) { Value = checkProcedure });
            if (await exists.ExecuteScalarAsync(ct).ConfigureAwait(false) is null or DBNull)
            {
                // Only the accepted-run path can get here (the created path bootstraps first). Do not
                // bootstrap from a verification step: it re-applies every workbench procedure.
                report.Issues.Add($"{checkProcedure} is not installed on the target, so query calls were not checked. The next new run installs it.");
                return ExitSuccess;
            }
        }

        var problems = new List<string>();
        await using (var command = new SqlCommand(checkProcedure, target) { CommandType = CommandType.StoredProcedure, CommandTimeout = 600 })
        {
            await using var reader = await command.ExecuteReaderAsync(ct).ConfigureAwait(false);
            while (await reader.ReadAsync(ct).ConfigureAwait(false))
            {
                problems.Add($"QueryCallSignatureMismatch: '{reader.GetString(1)}' {reader.GetString(4)}");
            }
        }

        if (problems.Count == 0)
        {
            return ExitSuccess;
        }

        report.Issues = problems.Take(50).ToList();
        var outcome = report.ApplyCount > 0 ? $"{report.Message} (the rows were applied)" : report.Message;
        return Fail(report, $"Post-apply check failed: {problems.Count} target metadata query call(s) do not match the function or procedure they call, so those screens fail. Fix the queries in the source and re-run. Migration outcome: {outcome}");
    }

    private static int Fail(Report report, string message)
    {
        report.Status = "Failed";
        report.Message = message;
        return ExitHandledFailure;
    }

    // Latest run for this target/source whose most recent preview acceptance is newer than its
    // most recent apply. Whether the acceptance is still current is decided by a fresh preview.
    private static async Task<Guid?> FindAcceptedUnappliedRunAsync(SqlConnection target, Options o, CancellationToken ct)
    {
        const string sql = """
            SELECT TOP (1) r.Guid
            FROM SMigration.Metadata_Run AS r
            CROSS APPLY (SELECT MAX(l.ID) AS AcceptedLogId FROM SMigration.Metadata_ExecutionLog AS l
                         WHERE l.RunGuid = r.Guid AND l.RowStatus NOT IN (0,254)
                           AND l.StepName = N'ApplyPreviewAcceptance' AND l.StepStatus = N'Accepted') AS accepted
            OUTER APPLY (SELECT MAX(l.ID) AS ApplyLogId FROM SMigration.Metadata_ExecutionLog AS l
                         WHERE l.RunGuid = r.Guid AND l.RowStatus NOT IN (0,254)
                           AND l.StepName IN (N'ApplyStart', N'ApplyMetadataComplete')) AS applied
            WHERE r.RowStatus NOT IN (0,254)
              AND r.IsValidateOnly = 0
              AND r.TargetDatabaseName = @TargetDatabaseName
              AND r.SourceDatabaseName = @SourceDatabaseName
              AND r.RunStatus IN (N'Validated', N'PartiallyApplied', N'AppliedCoreMetadata', N'AppliedUiMetadata')
              AND accepted.AcceptedLogId IS NOT NULL
              AND (applied.ApplyLogId IS NULL OR accepted.AcceptedLogId > applied.ApplyLogId)
            ORDER BY r.ID DESC;
            """;
        await using var command = new SqlCommand(sql, target) { CommandTimeout = 120 };
        command.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 255) { Value = o.TargetDatabase });
        command.Parameters.Add(new SqlParameter("@SourceDatabaseName", SqlDbType.NVarChar, 255) { Value = o.SourceDatabase });
        var result = await command.ExecuteScalarAsync(ct).ConfigureAwait(false);
        return result is Guid guid ? guid : null;
    }

    private static async Task<Guid> CreateRunAsync(SqlConnection target, Options o, CancellationToken ct)
    {
        await using var command = new SqlCommand("SMigration.MetadataRun_Create", target)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        command.Parameters.Add(new SqlParameter("@SourceEnvironment", SqlDbType.NVarChar, 20) { Value = o.SourceEnvironment });
        command.Parameters.Add(new SqlParameter("@TargetEnvironment", SqlDbType.NVarChar, 20) { Value = o.TargetEnvironment });
        command.Parameters.Add(new SqlParameter("@SourceServerName", SqlDbType.NVarChar, 255) { Value = o.SourceServer });
        command.Parameters.Add(new SqlParameter("@SourceDatabaseName", SqlDbType.NVarChar, 255) { Value = o.SourceDatabase });
        command.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 255) { Value = o.TargetServer });
        command.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 255) { Value = o.TargetDatabase });
        // The proc defaults to validate-only, which Accept and Apply reject.
        command.Parameters.Add(new SqlParameter("@IsValidateOnly", SqlDbType.Bit) { Value = false });
        var output = new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Direction = ParameterDirection.InputOutput, Value = DBNull.Value };
        command.Parameters.Add(output);
        await command.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
        return (Guid)output.Value;
    }

    private static async Task<List<StagedCandidate>> ReadActionableStagedRowsAsync(SqlConnection target, Guid runGuid, CancellationToken ct)
    {
        const string sql = """
            SELECT tr.SchemaName, tr.TableName, sr.SourceRowGuid, sr.DifferenceType, sr.SourceRowStatus,
                   CAST(CASE WHEN ign.ID IS NULL THEN 0 ELSE 1 END AS bit) AS IsIgnored
            FROM SMigration.Metadata_StagedRows AS sr
            INNER JOIN SMigration.Metadata_TableRegistry AS tr ON tr.Guid = sr.RegistryGuid AND tr.RowStatus NOT IN (0,254)
            INNER JOIN SMigration.Metadata_Run AS r ON r.Guid = sr.RunGuid
            LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
                ON ign.DatabaseName = r.TargetDatabaseName AND ign.RegistryGuid = sr.RegistryGuid
               AND ign.SourceRowGuid = sr.SourceRowGuid AND ign.RowStatus NOT IN (0,254)
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254)
              AND sr.DifferenceType IN (N'Insert', N'Update');
            """;
        await using var command = new SqlCommand(sql, target) { CommandTimeout = 300 };
        command.Parameters.Add(new SqlParameter("@RunGuid", runGuid));
        var rows = new List<StagedCandidate>();
        await using var reader = await command.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await reader.ReadAsync(ct).ConfigureAwait(false))
        {
            var schema = reader.GetString(0);
            var table = reader.GetString(1);
            var differenceType = reader.GetString(3);
            int? sourceRowStatus = reader.IsDBNull(4) ? null : Convert.ToInt32(reader.GetValue(4));
            var isIgnored = reader.GetBoolean(5);
            // Unhandled tables are kept here so they can be reported; IsAutoSelectable decides the rest.
            if (!isIgnored && (differenceType == "Insert" || differenceType == "Update") && (sourceRowStatus ?? 1) != 254)
            {
                rows.Add(new StagedCandidate(schema, table, reader.GetGuid(2), differenceType));
            }
        }

        return rows;
    }

    // Same as the workbench's bulk SelectionUpsert: per-row upsert, then dependencies once, in one transaction.
    private static async Task<int> SelectAsync(SqlConnection target, Guid runGuid, IReadOnlyList<StagedCandidate> rows, CancellationToken ct)
    {
        await using var transaction = (SqlTransaction)await target.BeginTransactionAsync(ct).ConfigureAwait(false);
        try
        {
            foreach (var row in rows)
            {
                await using var upsert = new SqlCommand("SMigration.MetadataRunSelection_Upsert", target, transaction)
                {
                    CommandType = CommandType.StoredProcedure,
                    CommandTimeout = 300
                };
                upsert.Parameters.Add(new SqlParameter("@RunGuid", runGuid));
                upsert.Parameters.Add(new SqlParameter("@SchemaName", SqlDbType.NVarChar, 128) { Value = row.SchemaName });
                upsert.Parameters.Add(new SqlParameter("@TableName", SqlDbType.NVarChar, 128) { Value = row.TableName });
                upsert.Parameters.Add(new SqlParameter("@SourceRowGuid", row.SourceRowGuid));
                upsert.Parameters.Add(new SqlParameter("@DifferenceType", SqlDbType.NVarChar, 30) { Value = row.DifferenceType });
                upsert.Parameters.Add(new SqlParameter("@IsSelected", SqlDbType.Bit) { Value = true });
                await upsert.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
            }

            var seedJson = JsonSerializer.Serialize(rows.Select(r => new { r.SchemaName, r.TableName, r.SourceRowGuid }));
            await using var dependencies = new SqlCommand("SMigration.MetadataRunSelection_AddDependencies", target, transaction)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 300
            };
            dependencies.Parameters.Add(new SqlParameter("@RunGuid", runGuid));
            dependencies.Parameters.Add(new SqlParameter("@SeedJson", SqlDbType.NVarChar, -1) { Value = seedJson });
            var added = await dependencies.ExecuteScalarAsync(ct).ConfigureAwait(false);

            await transaction.CommitAsync(ct).ConfigureAwait(false);
            return added is null or DBNull ? 0 : Convert.ToInt32(added);
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None).ConfigureAwait(false);
            throw;
        }
    }

    private static async Task<List<string>> ReadSelectedUnsupportedTablesAsync(SqlConnection target, Guid runGuid, CancellationToken ct)
    {
        const string sql = """
            SELECT DISTINCT tr.SchemaName, tr.TableName
            FROM SMigration.Metadata_RunSelections AS sel
            INNER JOIN SMigration.Metadata_TableRegistry AS tr ON tr.Guid = sel.RegistryGuid
            WHERE sel.RunGuid = @RunGuid AND sel.RowStatus NOT IN (0,254);
            """;
        await using var command = new SqlCommand(sql, target) { CommandTimeout = 120 };
        command.Parameters.Add(new SqlParameter("@RunGuid", runGuid));
        var tables = new List<string>();
        await using var reader = await command.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await reader.ReadAsync(ct).ConfigureAwait(false))
        {
            if (!IsHandledTable(reader.GetString(0), reader.GetString(1)))
            {
                tables.Add($"{reader.GetString(0)}.{reader.GetString(1)}");
            }
        }

        return tables;
    }

    private static async Task<List<string>> ReadFailIssuesAsync(SqlConnection target, Guid runGuid, CancellationToken ct)
    {
        const string sql = """
            SELECT TOP (50) IssueCode, IssueMessage
            FROM SMigration.Metadata_ValidationIssues
            WHERE RunGuid = @RunGuid AND RowStatus NOT IN (0,254) AND Severity = N'Fail'
            ORDER BY ID;
            """;
        await using var command = new SqlCommand(sql, target) { CommandTimeout = 120 };
        command.Parameters.Add(new SqlParameter("@RunGuid", runGuid));
        var issues = new List<string>();
        await using var reader = await command.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await reader.ReadAsync(ct).ConfigureAwait(false))
        {
            issues.Add($"{reader.GetString(0)}: {reader.GetString(1)}");
        }

        return issues;
    }

    private static async Task ExecProcAsync(SqlConnection connection, string procedure, SqlParameter[] parameters, int timeoutSeconds, CancellationToken ct)
    {
        await using var command = new SqlCommand(procedure, connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = timeoutSeconds
        };
        command.Parameters.AddRange(parameters);
        await command.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }

    private static async Task<SqlConnection> OpenAsync(string template, string server, string database, CancellationToken ct)
    {
        var builder = new SqlConnectionStringBuilder(template) { DataSource = server, InitialCatalog = database };
        var connection = new SqlConnection(builder.ConnectionString);
        await connection.OpenAsync(ct).ConfigureAwait(false);
        return connection;
    }

    /// <summary>"--key value" pairs, case-insensitive; a flag with no value is "true".</summary>
    public static IReadOnlyDictionary<string, string> ParseArguments(string[] args)
    {
        var parsed = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < args.Length; i++)
        {
            var key = args[i];
            if (!key.StartsWith("--", StringComparison.Ordinal)) continue;
            parsed[key] = i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal) ? args[++i] : "true";
        }

        return parsed;
    }

    private static Options ParseOptions(string[] args)
    {
        var parsed = ParseArguments(args);

        string Required(string key) =>
            parsed.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v : throw new ArgumentException($"Missing required argument {key}.");
        string Optional(string key, string fallback) =>
            parsed.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v : fallback;

        var targetServer = Required("--target-server");
        var targetDatabase = Required("--target-database");
        var options = new Options(
            targetServer,
            targetDatabase,
            Required("--source-server"),
            Required("--source-database"),
            Optional("--source-environment", "DEV"),
            Optional("--target-environment", "QA"),
            Optional("--out", "metadata-auto.json"),
            Optional("--connection-template", ConnectionStringConfiguration.ForIntegratedSecurity(targetServer, targetDatabase)["ConnectionStrings:DefaultConnection"]!));

        if (string.Equals(options.TargetEnvironment, "LIVE", StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("metadata-auto does not run against LIVE.");
        }

        return options;
    }
}
