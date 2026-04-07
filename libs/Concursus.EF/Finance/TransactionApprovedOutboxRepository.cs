#nullable enable

using System;
using System.Data;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;

namespace Concursus.EF.Finance
{
    /// <summary>
    /// SQL-backed repository used by the Sage transaction submission worker
    /// to claim and complete SCore.IntegrationOutbox rows.
    ///
    /// This implementation:
    /// - uses row-level update claiming semantics
    /// - avoids double-processing through a publishing token
    /// - honours retryable vs non-retryable failure handling
    /// - aligns the publishing token with SQL uniqueidentifier usage
    /// - ensures readers are disposed before transaction commit
    /// </summary>
    public sealed class TransactionApprovedOutboxRepository : ITransactionApprovedOutboxRepository
    {
        private readonly Core _core;

        public TransactionApprovedOutboxRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        /// <summary>
        /// Attempts to claim the next eligible outbox row for processing.
        /// </summary>
        public async Task<TransactionApprovedOutboxItem?> TryClaimNextAsync(
            string eventType,
            string publishingToken,
            int maxAttempts,
            int claimTimeoutMinutes,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(eventType))
            {
                throw new ArgumentException("Event type is required.", nameof(eventType));
            }

            if (string.IsNullOrWhiteSpace(publishingToken))
            {
                throw new ArgumentException("Publishing token is required.", nameof(publishingToken));
            }

            if (!Guid.TryParse(publishingToken, out var publishingTokenGuid))
            {
                throw new ArgumentException(
                    "Publishing token must be a valid GUID string.",
                    nameof(publishingToken));
            }

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken);

            await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

            const string sql = """
DECLARE @Claimed TABLE
(
    ID bigint NOT NULL,
    EventType nvarchar(250) NOT NULL,
    PayloadJson nvarchar(max) NOT NULL,
    PublishAttempts int NOT NULL,
    CreatedOnUtc datetime2(7) NOT NULL
);

;WITH next_item AS
(
    SELECT TOP (1)
           io.ID
    FROM   SCore.IntegrationOutbox io WITH (READPAST, UPDLOCK, ROWLOCK)
    WHERE  io.RowStatus NOT IN (0, 254)
      AND  io.EventType = @EventType
      AND  io.PublishedOnUtc IS NULL
      AND  ISNULL(io.PublishAttempts, 0) < @MaxAttempts
      AND
           (
               io.PublishingStartedOnUtc IS NULL
               OR io.PublishingStartedOnUtc < DATEADD(MINUTE, -@ClaimTimeoutMinutes, SYSUTCDATETIME())
           )
    ORDER BY io.ID ASC
)
UPDATE io
SET    io.PublishingStartedOnUtc = SYSUTCDATETIME(),
       io.PublishingToken = @PublishingToken,
       io.LastError = NULL
OUTPUT inserted.ID,
       inserted.EventType,
       inserted.PayloadJson,
       ISNULL(inserted.PublishAttempts, 0),
       inserted.CreatedOnUtc
INTO   @Claimed (ID, EventType, PayloadJson, PublishAttempts, CreatedOnUtc)
FROM   SCore.IntegrationOutbox io
JOIN   next_item ni
       ON ni.ID = io.ID;

SELECT TOP (1)
       c.ID,
       c.EventType,
       c.PayloadJson,
       c.PublishAttempts,
       c.CreatedOnUtc
FROM   @Claimed c;
""";

            try
            {
                await using var command = QueryBuilder.CreateCommand(sql, connection, transaction);
                command.CommandType = CommandType.Text;

                command.Parameters.Add(new SqlParameter("@EventType", SqlDbType.NVarChar, 250)
                {
                    Value = eventType
                });

                command.Parameters.Add(new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier)
                {
                    Value = publishingTokenGuid
                });

                command.Parameters.Add(new SqlParameter("@MaxAttempts", SqlDbType.Int)
                {
                    Value = maxAttempts
                });

                command.Parameters.Add(new SqlParameter("@ClaimTimeoutMinutes", SqlDbType.Int)
                {
                    Value = claimTimeoutMinutes
                });

                TransactionApprovedOutboxItem? result = null;

                // Critical: dispose the reader before committing the transaction.
                await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
                {
                    if (await reader.ReadAsync(cancellationToken))
                    {
                        result = new TransactionApprovedOutboxItem
                        {
                            OutboxId = reader.GetInt64(reader.GetOrdinal("ID")),
                            EventType = reader.GetString(reader.GetOrdinal("EventType")),
                            PayloadJson = reader.GetString(reader.GetOrdinal("PayloadJson")),
                            PublishAttempts = reader.GetInt32(reader.GetOrdinal("PublishAttempts")),
                            CreatedOnUtc = reader.GetDateTime(reader.GetOrdinal("CreatedOnUtc"))
                        };
                    }
                }

                await transaction.CommitAsync(cancellationToken);
                return result;
            }
            catch (Exception ex)
            {
                await RollbackSafeAsync(transaction);

                ex.Data["SQL"] = BuildSqlWithParams(
                    sql,
                    new[]
                    {
                        new SqlParameter("@EventType", SqlDbType.NVarChar, 250) { Value = eventType },
                        new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier) { Value = publishingTokenGuid },
                        new SqlParameter("@MaxAttempts", SqlDbType.Int) { Value = maxAttempts },
                        new SqlParameter("@ClaimTimeoutMinutes", SqlDbType.Int) { Value = claimTimeoutMinutes }
                    });

                throw new Exception(
                    $"Exception occurred in TryClaimNextAsync: {ex.Message}",
                    ex);
            }
        }

        /// <summary>
        /// Marks a claimed row as successfully completed.
        /// </summary>
        public async Task MarkSucceededAsync(
            long outboxId,
            string publishingToken,
            string? detail,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(publishingToken))
            {
                throw new ArgumentException("Publishing token is required.", nameof(publishingToken));
            }

            if (!Guid.TryParse(publishingToken, out var publishingTokenGuid))
            {
                throw new ArgumentException(
                    "Publishing token must be a valid GUID string.",
                    nameof(publishingToken));
            }

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken);

            const string sql = """
UPDATE SCore.IntegrationOutbox
SET    PublishedOnUtc = SYSUTCDATETIME(),
       PublishAttempts = ISNULL(PublishAttempts, 0) + 1,
       LastError = @Detail,
       PublishingStartedOnUtc = NULL,
       PublishingToken = NULL
WHERE  ID = @OutboxId
  AND  PublishingToken = @PublishingToken;
""";

            try
            {
                await using var command = QueryBuilder.CreateCommand(sql, connection, transaction: null);
                command.CommandType = CommandType.Text;

                command.Parameters.Add(new SqlParameter("@OutboxId", SqlDbType.BigInt)
                {
                    Value = outboxId
                });

                command.Parameters.Add(new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier)
                {
                    Value = publishingTokenGuid
                });

                command.Parameters.Add(new SqlParameter("@Detail", SqlDbType.NVarChar, -1)
                {
                    Value = (object?)detail ?? DBNull.Value
                });

                await command.ExecuteNonQueryAsync(cancellationToken);
            }
            catch (Exception ex)
            {
                ex.Data["SQL"] = BuildSqlWithParams(
                    sql,
                    new[]
                    {
                        new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId },
                        new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier) { Value = publishingTokenGuid },
                        new SqlParameter("@Detail", SqlDbType.NVarChar, -1) { Value = (object?)detail ?? DBNull.Value }
                    });

                throw new Exception(
                    $"Exception occurred in MarkSucceededAsync: {ex.Message}",
                    ex);
            }
        }

        /// <summary>
        /// Marks a claimed row as failed.
        /// Retryable failures remain pending.
        /// Non-retryable failures are completed so the worker does not retry forever.
        /// </summary>
        public async Task MarkFailedAsync(
            long outboxId,
            string publishingToken,
            string error,
            bool isRetryable,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(publishingToken))
            {
                throw new ArgumentException("Publishing token is required.", nameof(publishingToken));
            }

            if (!Guid.TryParse(publishingToken, out var publishingTokenGuid))
            {
                throw new ArgumentException(
                    "Publishing token must be a valid GUID string.",
                    nameof(publishingToken));
            }

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken);

            const string sql = """
UPDATE SCore.IntegrationOutbox
SET    PublishedOnUtc =
           CASE WHEN @IsRetryable = 1 THEN NULL ELSE SYSUTCDATETIME() END,
       PublishAttempts = ISNULL(PublishAttempts, 0) + 1,
       LastError = @Error,
       PublishingStartedOnUtc = NULL,
       PublishingToken = NULL
WHERE  ID = @OutboxId
  AND  PublishingToken = @PublishingToken;
""";

            try
            {
                await using var command = QueryBuilder.CreateCommand(sql, connection, transaction: null);
                command.CommandType = CommandType.Text;

                command.Parameters.Add(new SqlParameter("@OutboxId", SqlDbType.BigInt)
                {
                    Value = outboxId
                });

                command.Parameters.Add(new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier)
                {
                    Value = publishingTokenGuid
                });

                command.Parameters.Add(new SqlParameter("@Error", SqlDbType.NVarChar, -1)
                {
                    Value = string.IsNullOrWhiteSpace(error)
                        ? "Unhandled Sage submission worker failure."
                        : error
                });

                command.Parameters.Add(new SqlParameter("@IsRetryable", SqlDbType.Bit)
                {
                    Value = isRetryable
                });

                await command.ExecuteNonQueryAsync(cancellationToken);
            }
            catch (Exception ex)
            {
                ex.Data["SQL"] = BuildSqlWithParams(
                    sql,
                    new[]
                    {
                        new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId },
                        new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier) { Value = publishingTokenGuid },
                        new SqlParameter("@Error", SqlDbType.NVarChar, -1)
                        {
                            Value = string.IsNullOrWhiteSpace(error)
                                ? "Unhandled Sage submission worker failure."
                                : error
                        },
                        new SqlParameter("@IsRetryable", SqlDbType.Bit) { Value = isRetryable }
                    });

                throw new Exception(
                    $"Exception occurred in MarkFailedAsync: {ex.Message}",
                    ex);
            }
        }

        private static async Task RollbackSafeAsync(SqlTransaction? transaction)
        {
            if (transaction is null)
            {
                return;
            }

            try
            {
                await transaction.RollbackAsync();
            }
            catch
            {
                // Intentionally swallow rollback errors so the original exception is preserved.
            }
        }

        private static string BuildSqlWithParams(string query, SqlParameter[] parameters)
        {
            var formattedParams = parameters
                .Select(p => $"{p.ParameterName} = '{p.Value}'")
                .ToArray();

            return $"{query}{Environment.NewLine}Params:{Environment.NewLine}{string.Join(Environment.NewLine, formattedParams)}";
        }
    }
}