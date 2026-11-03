using System.Diagnostics;

namespace CymBuild.Database.IntegrationTests.Infrastructure;

/// <summary>
/// Runs once before any SQL integration test executes. Verifies the dedicated
/// CymBuild_Test_* database named by <see cref="SqlTestDatabase.ConnectionStringEnvironmentVariable"/>
/// is provisioned and, if it is not, applies the missing schema/fixtures by invoking the
/// source-controlled provisioner (tools/Testing/Initialize-CymBuildSqlTestDatabase.ps1) instead
/// of duplicating its schema-application logic here. This removes the manual "run the
/// provisioner first" step that otherwise fails a fresh clone's first test run with a raw
/// "Invalid object name" SqlException.
/// </summary>
public sealed class SqlTestDatabaseProvisioningFixture : IAsyncLifetime
{
    public async ValueTask InitializeAsync()
    {
        var connectionStringValue = Environment.GetEnvironmentVariable(SqlTestDatabase.ConnectionStringEnvironmentVariable);
        if (string.IsNullOrWhiteSpace(connectionStringValue))
        {
            // Leave the missing-variable error to SqlTestDatabase.FromEnvironment(), which each
            // test already calls and which explains how to set the connection string.
            return;
        }

        // Re-validates the CymBuild_Test_* safety boundary before anything touches the database.
        SqlTestDatabase.FromEnvironment();

        var allowedDatabaseName = Environment.GetEnvironmentVariable(SqlTestDatabase.AllowedDatabaseEnvironmentVariable);
        var provisionerPath = Path.Combine(RepositoryRoot.Path, "tools", "Testing", "Initialize-CymBuildSqlTestDatabase.ps1");
        if (!File.Exists(provisionerPath))
        {
            throw new InvalidOperationException($"SQL test database provisioner not found: {provisionerPath}");
        }

        var verified = await RunProvisionerScriptAsync(
            provisionerPath, connectionStringValue, allowedDatabaseName, verifyOnly: true, throwOnFailure: false)
            .ConfigureAwait(false);
        if (verified)
        {
            return;
        }

        await RunProvisionerScriptAsync(
            provisionerPath, connectionStringValue, allowedDatabaseName, verifyOnly: false, throwOnFailure: true)
            .ConfigureAwait(false);
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;

    private static async Task<bool> RunProvisionerScriptAsync(
        string provisionerPath,
        string connectionString,
        string? allowedDatabaseName,
        bool verifyOnly,
        bool throwOnFailure)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = ResolvePowerShellExecutable(),
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-NonInteractive");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(provisionerPath);
        startInfo.ArgumentList.Add("-RepoRoot");
        startInfo.ArgumentList.Add(RepositoryRoot.Path);
        startInfo.ArgumentList.Add("-ConnectionString");
        startInfo.ArgumentList.Add(connectionString);
        if (!string.IsNullOrWhiteSpace(allowedDatabaseName))
        {
            startInfo.ArgumentList.Add("-AllowedDatabaseName");
            startInfo.ArgumentList.Add(allowedDatabaseName);
        }
        startInfo.ArgumentList.Add(verifyOnly ? "-VerifyOnly" : "-Apply");

        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("Failed to start the SQL test database provisioner process.");

        var stdOutTask = process.StandardOutput.ReadToEndAsync();
        var stdErrTask = process.StandardError.ReadToEndAsync();

        using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(120));
        try
        {
            await process.WaitForExitAsync(timeoutCts.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            TryKill(process);
            throw new InvalidOperationException(
                $"The SQL test database provisioner timed out after 120 seconds ({(verifyOnly ? "-VerifyOnly" : "-Apply")}).");
        }

        var stdOut = await stdOutTask.ConfigureAwait(false);
        var stdErr = await stdErrTask.ConfigureAwait(false);

        if (process.ExitCode == 0)
        {
            return true;
        }

        if (throwOnFailure)
        {
            throw new InvalidOperationException(
                $"Automatic SQL test database provisioning failed (exit code {process.ExitCode}).{Environment.NewLine}{stdOut}{Environment.NewLine}{stdErr}");
        }

        return false;
    }

    private static void TryKill(Process process)
    {
        try
        {
            process.Kill(entireProcessTree: true);
        }
        catch
        {
            // Best-effort: the process may have already exited.
        }
    }

    private static string ResolvePowerShellExecutable()
    {
        foreach (var candidate in new[] { "pwsh", "powershell" })
        {
            if (IsOnPath(candidate))
            {
                return candidate;
            }
        }

        throw new InvalidOperationException(
            "Neither 'pwsh' nor 'powershell' was found on PATH; cannot auto-provision the SQL test database. " +
            "Run tools/Testing/Initialize-CymBuildSqlTestDatabase.ps1 manually.");
    }

    private static bool IsOnPath(string executable)
    {
        var pathVariable = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        var extensions = OperatingSystem.IsWindows() ? new[] { ".exe", ".cmd", ".bat", string.Empty } : new[] { string.Empty };
        foreach (var directory in pathVariable.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            foreach (var extension in extensions)
            {
                if (File.Exists(Path.Combine(directory, executable + extension)))
                {
                    return true;
                }
            }
        }

        return false;
    }
}

internal static class RepositoryRoot
{
    private static readonly Lazy<string> RootValue = new(Find);

    internal static string Path => RootValue.Value;

    private static string Find()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(System.IO.Path.Combine(directory.FullName, "CymBuild.Monorepo.sln")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException(
            $"Could not locate CymBuild.Monorepo.sln above '{AppContext.BaseDirectory}'.");
    }
}
