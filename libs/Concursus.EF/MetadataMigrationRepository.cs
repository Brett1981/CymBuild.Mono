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
}
