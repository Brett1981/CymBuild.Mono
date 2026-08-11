using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace Concursus.EF;

public sealed class MetadataMigrationRepository
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
        if (runGuid == Guid.Empty)
        {
            throw new ArgumentException("A metadata migration run Guid is required.", nameof(runGuid));
        }

        if (string.IsNullOrWhiteSpace(targetServerName))
        {
            throw new ArgumentException("A target SQL Server name is required.", nameof(targetServerName));
        }

        if (string.IsNullOrWhiteSpace(targetDatabaseName))
        {
            throw new ArgumentException("A target database name is required.", nameof(targetDatabaseName));
        }

        if (string.IsNullOrWhiteSpace(expectedPreviewFingerprint)
            || expectedPreviewFingerprint.Length != 64)
        {
            throw new ArgumentException("A 64-character preview fingerprint is required.", nameof(expectedPreviewFingerprint));
        }

        var connectionStringBuilder = new SqlConnectionStringBuilder(_connectionString)
        {
            DataSource = targetServerName.Trim(),
            InitialCatalog = targetDatabaseName.Trim()
        };

        await using var connection = new SqlConnection(connectionStringBuilder.ConnectionString);
        await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

        await using var command = new SqlCommand("SMigration.MetadataApplyPreview_Accept", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
        command.Parameters.Add(new SqlParameter("@ApplySelectedOnly", SqlDbType.Bit) { Value = applySelectedOnly });
        command.Parameters.Add(new SqlParameter("@ExpectedPreviewFingerprint", SqlDbType.VarChar, 64)
        {
            Value = expectedPreviewFingerprint
        });

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            throw new InvalidOperationException("Metadata apply preview acceptance returned no result.");
        }

        return new ApplyPreviewAcceptanceResult(
            IsAccepted: Convert.ToBoolean(reader["IsAccepted"]),
            ApplySelectedOnly: Convert.ToBoolean(reader["ApplySelectedOnly"]),
            PreviewFingerprint: Convert.ToString(reader["PreviewFingerprint"]) ?? string.Empty,
            ApplyCount: Convert.ToInt32(reader["ApplyCount"]),
            AcceptedOnUtc: Convert.ToString(reader["AcceptedOnUtc"]) ?? string.Empty,
            AcceptedByUserId: Convert.ToInt32(reader["AcceptedByUserId"]),
            Message: Convert.ToString(reader["Message"]) ?? string.Empty);
    }
}
