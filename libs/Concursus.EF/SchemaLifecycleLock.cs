using System.Text;
using System.Text.RegularExpressions;

namespace Concursus.EF;

/// <summary>
/// Keeps the migration bootstrap from replacing the schema lifecycle procedures while they run.
/// SCore.PreDeploymentScript / SCore.PostDeploymentScript hold <see cref="Resource"/> in Shared mode;
/// the bootstrap takes it Exclusive before re-creating any module, and skips modules whose
/// definition is already current. Without this, a workbench opened during a deployment re-created
/// SCore.SCHEMABINDING mid post-deployment on CymBuild_QA2 (2026-10-13, SQL 2801), leaving every
/// foreign key to SCore.DataObjects disabled.
/// The schema runner (tools/SchemaDeployment/Invoke-CymBuildSchemaDeployment.ps1) uses the same resource.
/// </summary>
public static class SchemaLifecycleLock
{
    public const string Resource = "CymBuild.SchemaLifecycle";

    /// <summary>How long a lifecycle step waits for a bootstrap that is replacing its procedures.</summary>
    public const int LifecycleWaitMilliseconds = 600_000;

    /// <summary>How long a bootstrap waits for a running lifecycle step before failing.</summary>
    public const int BootstrapWaitMilliseconds = 60_000;

    private static readonly Regex ModuleHeader = new(
        @"\A(?:CREATE\s+OR\s+ALTER|CREATE|ALTER)\s+(?:PROCEDURE|PROC|FUNCTION|VIEW|TRIGGER)\s+(?<name>(?:\[[^\]]+\]|\w+)\s*\.\s*(?:\[[^\]]+\]|\w+))",
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    private static readonly Regex ModuleVerb = new(
        @"\A(?:CREATE\s+OR\s+ALTER|CREATE|ALTER)\s+(?<kind>PROCEDURE|PROC|FUNCTION|VIEW|TRIGGER)\s+",
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    /// <summary>
    /// Wraps lifecycle SQL so it runs holding the lock in Shared mode on the session, released on
    /// success or failure. Several lifecycle steps can run together; only a bootstrap is excluded.
    /// </summary>
    public static string WrapLifecycleSql(string executionSql) => $"""
        DECLARE @CymBuildLifecycleLock int;
        EXEC @CymBuildLifecycleLock = sys.sp_getapplock @Resource = N'{Resource}', @LockMode = N'Shared', @LockOwner = N'Session', @LockTimeout = {LifecycleWaitMilliseconds};
        IF @CymBuildLifecycleLock < 0
            THROW 60381, N'Could not acquire the schema lifecycle lock {Resource}: a migration bootstrap is replacing the lifecycle procedures. Try again shortly.', 1;
        BEGIN TRY
        {executionSql}
        END TRY
        BEGIN CATCH
            EXEC sys.sp_releaseapplock @Resource = N'{Resource}', @LockOwner = N'Session';
            THROW;
        END CATCH;
        EXEC sys.sp_releaseapplock @Resource = N'{Resource}', @LockOwner = N'Session';
        """;

    /// <summary>
    /// Returns the two-part name when the batch creates or alters a procedure, function, view or
    /// trigger (leading comments allowed); otherwise null.
    /// </summary>
    public static string? TryGetModuleName(string batch)
    {
        var body = StripLeadingComments(batch);
        var match = ModuleHeader.Match(body);
        return match.Success ? Regex.Replace(match.Groups["name"].Value, @"\s+", string.Empty) : null;
    }

    /// <summary>
    /// Text used to decide whether a module is already current: from the CREATE/ALTER keyword on,
    /// with line endings and trailing whitespace normalised. SQL Server stores CREATE OR ALTER as
    /// "CREATE   " (OR ALTER blanked), so the leading verb is compared as plain CREATE.
    /// </summary>
    public static string NormalizeModuleDefinition(string definition)
    {
        var body = StripLeadingComments(definition);
        body = ModuleVerb.Replace(body, "CREATE ${kind} ", 1);
        var lines = body.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n').Split('\n');
        var builder = new StringBuilder(body.Length);
        foreach (var line in lines)
        {
            builder.Append(line.TrimEnd()).Append('\n');
        }

        return builder.ToString().Trim();
    }

    private static string StripLeadingComments(string text)
    {
        var body = (text ?? string.Empty).TrimStart('﻿').TrimStart();
        while (true)
        {
            if (body.StartsWith("--", StringComparison.Ordinal))
            {
                var end = body.IndexOf('\n');
                body = end < 0 ? string.Empty : body[(end + 1)..].TrimStart();
            }
            else if (body.StartsWith("/*", StringComparison.Ordinal))
            {
                var end = body.IndexOf("*/", 2, StringComparison.Ordinal);
                body = end < 0 ? string.Empty : body[(end + 2)..].TrimStart();
            }
            else
            {
                return body;
            }
        }
    }
}
