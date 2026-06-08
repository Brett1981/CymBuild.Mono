using Concursus.API.Components;
using Concursus.API.Models;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;

namespace Concursus.API.Services
{
    public sealed class SharePointStructureRepairWorker : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<SharePointStructureRepairWorker> _logger;

        public SharePointStructureRepairWorker(
            IServiceScopeFactory scopeFactory,
            ILogger<SharePointStructureRepairWorker> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessNextAsync(stoppingToken).ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "SharePoint structure repair worker failed.");
                }

                await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken).ConfigureAwait(false);
            }
        }

        private async Task ProcessNextAsync(CancellationToken cancellationToken)
        {
            await using var scope = _scopeFactory.CreateAsyncScope();

            var efCore = scope.ServiceProvider.GetRequiredService<EF.Core>();
            var sharePoint = scope.ServiceProvider.GetRequiredService<SharePoint>();

            var item = await TryClaimNextAsync(efCore, cancellationToken).ConfigureAwait(false);

            if (item == null)
                return;

            try
            {
                var payload = JsonSerializer.Deserialize<SharePointStructureRepairRequestedPayload>(item.PayloadJson);

                if (payload == null || payload.DataObjectGuid == Guid.Empty)
                    throw new InvalidOperationException("Invalid SharePoint repair payload.");

                var dataObject = await efCore.DataObjectGet(
                        payload.DataObjectGuid,
                        Guid.Empty,
                        payload.EntityTypeGuid,
                        false)
                    .ConfigureAwait(false);

                if (dataObject == null || dataObject.Guid == Guid.Empty)
                    throw new InvalidOperationException($"DataObject not found: {payload.DataObjectGuid}");

                await sharePoint.RepairSharePointStructureAsync(
                        dataObject,
                        efCore,
                        cancellationToken)
                    .ConfigureAwait(false);

                await MarkPublishedAsync(efCore, item.Id, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                await MarkFailedAsync(efCore, item.Id, ex, cancellationToken).ConfigureAwait(false);
            }
        }

        private sealed class ClaimedOutboxItem
        {
            public long Id { get; set; }
            public string PayloadJson { get; set; } = string.Empty;
        }

        private static async Task<ClaimedOutboxItem?> TryClaimNextAsync(EF.Core efCore, CancellationToken cancellationToken)
        {
            const string sql = @"
;WITH NextItem AS
(
    SELECT TOP (1)
           o.ID
    FROM SCore.IntegrationOutbox AS o WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE o.EventType = N'SharePointStructureRepairRequested'
      AND o.RowStatus NOT IN (0,254)
      AND o.PublishedOnUtc IS NULL
      AND ISNULL(o.PublishAttempts, 0) < 10
    ORDER BY o.CreatedOnUtc ASC, o.ID ASC
)
UPDATE o
SET PublishAttempts = ISNULL(o.PublishAttempts, 0) + 1
OUTPUT inserted.ID,
       inserted.PayloadJson
FROM SCore.IntegrationOutbox AS o
JOIN NextItem AS ni
    ON ni.ID = o.ID;";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                return null;

            return new ClaimedOutboxItem
            {
                Id = reader.GetInt64(reader.GetOrdinal("ID")),
                PayloadJson = reader.GetString(reader.GetOrdinal("PayloadJson"))
            };
        }

        private static async Task MarkPublishedAsync(EF.Core efCore, long id, CancellationToken cancellationToken)
        {
            const string sql = @"
UPDATE SCore.IntegrationOutbox
SET PublishedOnUtc = SYSUTCDATETIME(),
    LastError = N''
WHERE ID = @ID
  AND RowStatus NOT IN (0,254);";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = id;

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        private static async Task MarkFailedAsync(EF.Core efCore, long id, Exception exception, CancellationToken cancellationToken)
        {
            const string sql = @"
UPDATE SCore.IntegrationOutbox
SET LastError = @LastError
WHERE ID = @ID
  AND RowStatus NOT IN (0,254);";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = id;
            command.Parameters.Add("@LastError", SqlDbType.NVarChar, -1).Value = exception.ToString();

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
    }
}
