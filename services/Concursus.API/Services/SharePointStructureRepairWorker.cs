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

                await EnsureDataObjectReadyForRepairAsync(
                        efCore,
                        payload,
                        cancellationToken)
                    .ConfigureAwait(false);

                var dataObject = await efCore.DataObjectGet(
                        payload.DataObjectGuid,
                        Guid.Empty,
                        payload.EntityTypeGuid,
                        false)
                    .ConfigureAwait(false);

                if (dataObject == null || dataObject.Guid == Guid.Empty)
                {
                    var reason = dataObject?.ErrorReturned;
                    throw new InvalidOperationException(
                        string.IsNullOrWhiteSpace(reason)
                            ? $"DataObject not found after repair ensure: {payload.DataObjectGuid}"
                            : $"DataObject not found after repair ensure: {payload.DataObjectGuid}. {reason}");
                }

                await sharePoint.RepairSharePointStructureAsync(
                        dataObject,
                        efCore,
                        cancellationToken)
                    .ConfigureAwait(false);

                await MarkPublishedAsync(efCore, item.Id, cancellationToken).ConfigureAwait(false);
            }
            catch (SharePointStructureRepairSkipException ex)
            {
                _logger.LogWarning(
                    "SharePoint structure repair skipped. OutboxId={OutboxId}; Reason={Reason}",
                    item.Id,
                    ex.Message);

                await MarkSkippedAsync(efCore, item.Id, ex.Message, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                await MarkFailedAsync(efCore, item.Id, ex, cancellationToken).ConfigureAwait(false);
            }
        }

        private sealed class SharePointStructureRepairSkipException : Exception
        {
            public SharePointStructureRepairSkipException(string message) : base(message)
            {
            }
        }

        private sealed class MainHobtInfo
        {
            public int EntityTypeId { get; set; }
            public string SchemaName { get; set; } = string.Empty;
            public string ObjectName { get; set; } = string.Empty;
        }

        private sealed class ExistingDataObjectInfo
        {
            public int EntityTypeId { get; set; }
            public byte RowStatus { get; set; }
        }

        private async Task EnsureDataObjectReadyForRepairAsync(
            EF.Core efCore,
            SharePointStructureRepairRequestedPayload payload,
            CancellationToken cancellationToken)
        {
            var mainHobt = await ResolveMainHobtAsync(
                    efCore,
                    payload.EntityTypeGuid,
                    cancellationToken)
                .ConfigureAwait(false);

            var existingDataObject = await TryGetExistingDataObjectAsync(
                    efCore,
                    payload.DataObjectGuid,
                    cancellationToken)
                .ConfigureAwait(false);

            var businessRecordExists = await BusinessRecordExistsAsync(
                    efCore,
                    mainHobt,
                    payload.DataObjectGuid,
                    cancellationToken)
                .ConfigureAwait(false);

            if (existingDataObject != null)
            {
                if (existingDataObject.EntityTypeId != mainHobt.EntityTypeId)
                {
                    throw new InvalidOperationException(
                        $"DataObject {payload.DataObjectGuid} already exists but has EntityTypeId {existingDataObject.EntityTypeId}; expected {mainHobt.EntityTypeId} for {payload.EntityTypeGuid}.");
                }

                if (!businessRecordExists)
                {
                    if (existingDataObject.RowStatus != 0 && existingDataObject.RowStatus != 254)
                    {
                        await DeactivateOrphanedDataObjectAsync(
                                efCore,
                                payload.DataObjectGuid,
                                mainHobt.EntityTypeId,
                                cancellationToken)
                            .ConfigureAwait(false);

                        _logger.LogWarning(
                            "SharePoint structure repair deactivated orphaned DataObject. DataObjectGuid={DataObjectGuid}; EntityTypeGuid={EntityTypeGuid}; HoBT={SchemaName}.{ObjectName}",
                            payload.DataObjectGuid,
                            payload.EntityTypeGuid,
                            mainHobt.SchemaName,
                            mainHobt.ObjectName);
                    }

                    throw new SharePointStructureRepairSkipException(
                        $"Source record {payload.DataObjectGuid} does not exist or is inactive in {mainHobt.SchemaName}.{mainHobt.ObjectName}; SharePoint structure repair cannot continue.");
                }

                if (existingDataObject.RowStatus == 0 || existingDataObject.RowStatus == 254)
                {
                    await ReactivateDataObjectAsync(
                            efCore,
                            payload.DataObjectGuid,
                            cancellationToken)
                        .ConfigureAwait(false);

                    _logger.LogWarning(
                        "SharePoint structure repair reactivated inactive DataObject. DataObjectGuid={DataObjectGuid}; EntityTypeGuid={EntityTypeGuid}; HoBT={SchemaName}.{ObjectName}",
                        payload.DataObjectGuid,
                        payload.EntityTypeGuid,
                        mainHobt.SchemaName,
                        mainHobt.ObjectName);
                }

                return;
            }

            if (!businessRecordExists)
            {
                throw new SharePointStructureRepairSkipException(
                    $"Cannot create missing DataObject {payload.DataObjectGuid}; no active source record exists in {mainHobt.SchemaName}.{mainHobt.ObjectName}.");
            }

            await InsertDataObjectAsync(
                    efCore,
                    payload.DataObjectGuid,
                    mainHobt.EntityTypeId,
                    cancellationToken)
                .ConfigureAwait(false);

            _logger.LogWarning(
                "SharePoint structure repair created missing DataObject. DataObjectGuid={DataObjectGuid}; EntityTypeGuid={EntityTypeGuid}; EntityTypeId={EntityTypeId}; HoBT={SchemaName}.{ObjectName}",
                payload.DataObjectGuid,
                payload.EntityTypeGuid,
                mainHobt.EntityTypeId,
                mainHobt.SchemaName,
                mainHobt.ObjectName);
        }

        private static async Task<MainHobtInfo> ResolveMainHobtAsync(
            EF.Core efCore,
            Guid entityTypeGuid,
            CancellationToken cancellationToken)
        {
            const string sql = @"
SELECT TOP (1)
       et.ID AS EntityTypeId,
       eh.SchemaName,
       eh.ObjectName
FROM SCore.EntityTypes AS et
JOIN SCore.EntityHobts AS eh
    ON eh.EntityTypeID = et.ID
WHERE et.Guid = @EntityTypeGuid
  AND et.RowStatus NOT IN (0,254)
  AND eh.RowStatus NOT IN (0,254)
  AND eh.IsMainHoBT = 1
ORDER BY eh.ID;";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            };

            command.Parameters.Add("@EntityTypeGuid", SqlDbType.UniqueIdentifier).Value = entityTypeGuid;

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                throw new InvalidOperationException($"Could not resolve active main HoBT for EntityTypeGuid {entityTypeGuid}.");
            }

            return new MainHobtInfo
            {
                EntityTypeId = reader.GetInt32(reader.GetOrdinal("EntityTypeId")),
                SchemaName = reader.GetString(reader.GetOrdinal("SchemaName")),
                ObjectName = reader.GetString(reader.GetOrdinal("ObjectName"))
            };
        }

        private static async Task<ExistingDataObjectInfo?> TryGetExistingDataObjectAsync(
            EF.Core efCore,
            Guid dataObjectGuid,
            CancellationToken cancellationToken)
        {
            const string sql = @"
SELECT TOP (1)
       RowStatus,
       EntityTypeId
FROM SCore.DataObjects
WHERE Guid = @Guid;";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            };

            command.Parameters.Add("@Guid", SqlDbType.UniqueIdentifier).Value = dataObjectGuid;

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                return null;

            return new ExistingDataObjectInfo
            {
                RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                EntityTypeId = reader.GetInt32(reader.GetOrdinal("EntityTypeId"))
            };
        }

        private static async Task<bool> BusinessRecordExistsAsync(
            EF.Core efCore,
            MainHobtInfo mainHobt,
            Guid dataObjectGuid,
            CancellationToken cancellationToken)
        {
            var quotedSchemaName = QuoteSqlIdentifier(mainHobt.SchemaName);
            var quotedObjectName = QuoteSqlIdentifier(mainHobt.ObjectName);
            var fullObjectName = $"{quotedSchemaName}.{quotedObjectName}";

            const string metadataSql = @"
SELECT
    CASE WHEN OBJECT_ID(@FullObjectName) IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS ObjectExists,
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(@FullObjectName)
          AND c.name = N'RowStatus'
    ) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS HasRowStatus;";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            bool objectExists;
            bool hasRowStatus;

            await using (var metadataCommand = new SqlCommand(metadataSql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            })
            {
                metadataCommand.Parameters.Add("@FullObjectName", SqlDbType.NVarChar, 600).Value = fullObjectName;

                await using var reader = await metadataCommand.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

                if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                    return false;

                objectExists = reader.GetBoolean(reader.GetOrdinal("ObjectExists"));
                hasRowStatus = reader.GetBoolean(reader.GetOrdinal("HasRowStatus"));
            }

            if (!objectExists)
                return false;

            var sql = $@"
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM {fullObjectName}
    WHERE [Guid] = @Guid{(hasRowStatus ? " AND [RowStatus] NOT IN (0,254)" : string.Empty)}
) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;";

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            };

            command.Parameters.Add("@Guid", SqlDbType.UniqueIdentifier).Value = dataObjectGuid;

            var result = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);

            return result is bool exists && exists;
        }

        private static async Task InsertDataObjectAsync(
            EF.Core efCore,
            Guid dataObjectGuid,
            int entityTypeId,
            CancellationToken cancellationToken)
        {
            const string sql = @"
INSERT INTO SCore.DataObjects
(
    Guid,
    RowStatus,
    EntityTypeId
)
SELECT
    @Guid,
    1,
    @EntityTypeId
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS d WITH (UPDLOCK, HOLDLOCK)
    WHERE d.Guid = @Guid
);";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            };

            command.Parameters.Add("@Guid", SqlDbType.UniqueIdentifier).Value = dataObjectGuid;
            command.Parameters.Add("@EntityTypeId", SqlDbType.Int).Value = entityTypeId;

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        private static async Task ReactivateDataObjectAsync(
            EF.Core efCore,
            Guid dataObjectGuid,
            CancellationToken cancellationToken)
        {
            const string sql = @"
UPDATE SCore.DataObjects
SET RowStatus = 1
WHERE Guid = @Guid
  AND RowStatus IN (0,254);";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            };

            command.Parameters.Add("@Guid", SqlDbType.UniqueIdentifier).Value = dataObjectGuid;

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        private static async Task DeactivateOrphanedDataObjectAsync(
            EF.Core efCore,
            Guid dataObjectGuid,
            int entityTypeId,
            CancellationToken cancellationToken)
        {
            const string sql = @"
UPDATE SCore.DataObjects
SET RowStatus = 254
WHERE Guid = @Guid
  AND EntityTypeId = @EntityTypeId
  AND RowStatus NOT IN (0,254);";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 30
            };

            command.Parameters.Add("@Guid", SqlDbType.UniqueIdentifier).Value = dataObjectGuid;
            command.Parameters.Add("@EntityTypeId", SqlDbType.Int).Value = entityTypeId;

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        private static string QuoteSqlIdentifier(string identifier)
        {
            if (string.IsNullOrWhiteSpace(identifier))
                throw new InvalidOperationException("Cannot quote an empty SQL identifier.");

            return "[" + identifier.Replace("]", "]]", StringComparison.Ordinal) + "]";
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

        private static async Task MarkSkippedAsync(EF.Core efCore, long id, string reason, CancellationToken cancellationToken)
        {
            const string sql = @"
UPDATE SCore.IntegrationOutbox
SET PublishedOnUtc = SYSUTCDATETIME(),
    LastError = @LastError
WHERE ID = @ID
  AND RowStatus NOT IN (0,254);";

            await using var connection = efCore.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = id;
            command.Parameters.Add("@LastError", SqlDbType.NVarChar, -1).Value = "Skipped: " + reason;

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
