using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace Concursus.EF;

public sealed partial class MetadataMigrationRepository
{
    private readonly string _connectionString;

    public MetadataMigrationRepository(IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? configuration.GetConnectionString("ShoreDB")
            ?? configuration.GetConnectionString("CymBuild")
            ?? throw new InvalidOperationException(
                "No database connection string was found for metadata migration. Expected one of: DefaultConnection, ShoreDB, CymBuild.");
    }

    public sealed record ApplyPreviewAcceptanceResult(
        bool IsAccepted,
        bool ApplySelectedOnly,
        string PreviewFingerprint,
        int ApplyCount,
        string AcceptedOnUtc,
        int AcceptedByUserId,
        string Message);

    public async Task<ApplyPreviewAcceptanceResult> AcceptApplyPreviewAsync(
        Guid runGuid,
        bool applySelectedOnly,
        string expectedPreviewFingerprint,
        string targetServerName,
        string targetDatabaseName,
        CancellationToken cancellationToken = default)
    {
        return await AcceptApplyPreviewWithDriftAsync(
            runGuid,
            applySelectedOnly,
            expectedPreviewFingerprint,
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);
    }

    public async Task UpsertValidationIssueIgnoreAsync(
        Guid runGuid,
        Guid validationIssueGuid,
        bool isIgnored,
        string reason,
        string targetServerName,
        string targetDatabaseName,
        CancellationToken cancellationToken = default)
    {
        ValidateRunAndTargetArguments(runGuid, targetServerName, targetDatabaseName);

        if (validationIssueGuid == Guid.Empty)
        {
            throw new ArgumentException("A validation issue Guid is required.", nameof(validationIssueGuid));
        }

        if (isIgnored && string.IsNullOrWhiteSpace(reason))
        {
            throw new ArgumentException("An ignore reason is required for audit.", nameof(reason));
        }

        await using var connection = await OpenConfiguredConnectionAsync(
            targetServerName,
            targetDatabaseName,
            cancellationToken).ConfigureAwait(false);

        await using var command = new SqlCommand("SMigration.MetadataValidationIssueIgnore_Upsert", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        command.Parameters.Add(new SqlParameter("@ValidationIssueGuid", SqlDbType.UniqueIdentifier) { Value = validationIssueGuid });
        command.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 500) { Value = reason?.Trim() ?? string.Empty });
        command.Parameters.Add(new SqlParameter("@IsIgnored", SqlDbType.Bit) { Value = isIgnored });

        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }
}
