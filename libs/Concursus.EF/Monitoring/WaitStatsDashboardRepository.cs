using Microsoft.Data.SqlClient;
using Concursus.Common.Shared.Monitoring;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Data.Common;

namespace Concursus.EF.Monitoring
{
    public sealed class WaitStatsDashboardRepository
    {
        private readonly string _connectionString;

        public WaitStatsDashboardRepository(IConfiguration configuration)
        {
            ArgumentNullException.ThrowIfNull(configuration);

            _connectionString =
                configuration.GetConnectionString("DefaultConnection")
                ?? configuration.GetConnectionString("Concursus")
                ?? throw new InvalidOperationException("No SQL connection string found for WaitStatsDashboardRepository.");
        }

        public async Task<WaitStatsDashboardResult> GetDashboardAsync(
            WaitStatsDashboardQuery query,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(query);

            var result = new WaitStatsDashboardResult();

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);

            await using var command = new SqlCommand("SMonitor.usp_WaitStatsDashboard", connection)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 60
            };

            command.Parameters.Add(new SqlParameter("@TopCount", SqlDbType.Int)
            {
                Value = query.TopCount
            });

            command.Parameters.Add(new SqlParameter("@CpuPressureSignalThresholdPct", SqlDbType.Decimal)
            {
                Precision = 9,
                Scale = 2,
                Value = query.CpuPressureSignalThresholdPct
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            if (await reader.ReadAsync(cancellationToken))
            {
                result.Summary = MapSummary(reader);
            }

            await reader.NextResultAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                result.Categories.Add(MapCategory(reader));
            }

            await reader.NextResultAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                result.TopWaits.Add(MapTopWait(reader));
            }

            await reader.NextResultAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                result.ActiveWaits.Add(MapActiveWait(reader));
            }

            await reader.NextResultAsync(cancellationToken);
            if (await reader.ReadAsync(cancellationToken))
            {
                result.SignalResourceSummary = MapSignalResourceSummary(reader);
            }

            await reader.NextResultAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                result.Recommendations.Add(MapRecommendation(reader));
            }

            return result;
        }

        private static WaitStatsDashboardSummaryDto MapSummary(DbDataReader reader)
            => new()
            {
                SnapshotUtc = reader.GetDateTime(reader.GetOrdinal("SnapshotUtc")),
                DatabaseName = Convert.ToString(reader["DatabaseName"]) ?? string.Empty,
                ServerName = Convert.ToString(reader["ServerName"]) ?? string.Empty,
                SqlServerStartTime = reader.GetDateTime(reader.GetOrdinal("SqlServerStartTime")),
                SecondsSinceRestart = Convert.ToInt32(reader["SecondsSinceRestart"]),
                TotalWaitTimeMs = Convert.ToInt64(reader["TotalWaitTimeMs"]),
                TotalWaitTimeSeconds = Convert.ToDecimal(reader["TotalWaitTimeSeconds"]),
                TotalSignalWaitTimeMs = Convert.ToInt64(reader["TotalSignalWaitTimeMs"]),
                TotalSignalWaitTimeSeconds = Convert.ToDecimal(reader["TotalSignalWaitTimeSeconds"]),
                TotalResourceWaitTimeMs = Convert.ToInt64(reader["TotalResourceWaitTimeMs"]),
                TotalResourceWaitTimeSeconds = Convert.ToDecimal(reader["TotalResourceWaitTimeSeconds"]),
                SignalWaitPct = Convert.ToDecimal(reader["SignalWaitPct"]),
                ResourceWaitPct = Convert.ToDecimal(reader["ResourceWaitPct"]),
                IsCpuPressureHighlighted = Convert.ToBoolean(reader["IsCpuPressureHighlighted"]),
                CpuPressureMessage = Convert.ToString(reader["CpuPressureMessage"]) ?? string.Empty
            };

        private static WaitCategoryDistributionDto MapCategory(DbDataReader reader)
            => new()
            {
                WaitCategory = Convert.ToString(reader["WaitCategory"]) ?? string.Empty,
                WaitTimeMs = Convert.ToInt64(reader["WaitTimeMs"]),
                WaitTimeSeconds = Convert.ToDecimal(reader["WaitTimeSeconds"]),
                SignalWaitTimeMs = Convert.ToInt64(reader["SignalWaitTimeMs"]),
                ResourceWaitTimeMs = Convert.ToInt64(reader["ResourceWaitTimeMs"]),
                WaitingTasksCount = Convert.ToInt64(reader["WaitingTasksCount"]),
                PctOfTotalWaitTime = Convert.ToDecimal(reader["PctOfTotalWaitTime"])
            };

        private static TopWaitTypeDto MapTopWait(DbDataReader reader)
            => new()
            {
                WaitType = Convert.ToString(reader["wait_type"]) ?? string.Empty,
                WaitCategory = Convert.ToString(reader["WaitCategory"]) ?? string.Empty,
                WaitingTasksCount = Convert.ToInt64(reader["waiting_tasks_count"]),
                WaitTimeMs = Convert.ToInt64(reader["wait_time_ms"]),
                WaitTimeSeconds = Convert.ToDecimal(reader["wait_time_seconds"]),
                SignalWaitTimeMs = Convert.ToInt64(reader["signal_wait_time_ms"]),
                SignalWaitSeconds = Convert.ToDecimal(reader["signal_wait_seconds"]),
                ResourceWaitTimeMs = Convert.ToInt64(reader["resource_wait_time_ms"]),
                ResourceWaitSeconds = Convert.ToDecimal(reader["resource_wait_seconds"]),
                MaxWaitTimeMs = Convert.ToInt64(reader["max_wait_time_ms"]),
                AvgWaitMsPerTask = Convert.ToDecimal(reader["avg_wait_ms_per_task"]),
                PctOfTotalWaitTime = Convert.ToDecimal(reader["pct_of_total_wait_time"]),
                PctSignalWithinWait = Convert.ToDecimal(reader["pct_signal_within_wait"])
            };

        private static ActiveWaitDto MapActiveWait(DbDataReader reader)
            => new()
            {
                SnapshotUtc = reader.GetDateTime(reader.GetOrdinal("SnapshotUtc")),
                SessionId = Convert.ToInt32(reader["session_id"]),
                RequestId = Convert.ToInt32(reader["request_id"]),
                Status = Convert.ToString(reader["status"]) ?? string.Empty,
                Command = Convert.ToString(reader["command"]) ?? string.Empty,
                WaitType = SafeString(reader, "wait_type"),
                CurrentWaitMs = Convert.ToInt64(reader["current_wait_ms"]),
                LastWaitType = SafeString(reader, "last_wait_type"),
                WaitResource = SafeString(reader, "wait_resource"),
                BlockingSessionId = SafeNullableInt(reader, "blocking_session_id"),
                CpuTimeMs = Convert.ToInt64(reader["cpu_time_ms"]),
                TotalElapsedTimeMs = Convert.ToInt64(reader["total_elapsed_time_ms"]),
                Reads = Convert.ToInt64(reader["reads"]),
                Writes = Convert.ToInt64(reader["writes"]),
                LogicalReads = Convert.ToInt64(reader["logical_reads"]),
                GrantedQueryMemory = Convert.ToInt64(reader["granted_query_memory"]),
                Dop = SafeNullableInt(reader, "dop"),
                ParallelWorkerCount = SafeNullableInt(reader, "parallel_worker_count"),
                DatabaseName = Convert.ToString(reader["database_name"]) ?? string.Empty,
                HostName = SafeString(reader, "host_name"),
                ProgramName = SafeString(reader, "program_name"),
                LoginName = SafeString(reader, "login_name"),
                RunningStatement = SafeString(reader, "running_statement"),
                BatchText = SafeString(reader, "batch_text")
            };

        private static SignalResourceWaitSummaryDto MapSignalResourceSummary(DbDataReader reader)
            => new()
            {
                TotalWaitTimeMs = Convert.ToInt64(reader["TotalWaitTimeMs"]),
                SignalWaitTimeMs = Convert.ToInt64(reader["SignalWaitTimeMs"]),
                ResourceWaitTimeMs = Convert.ToInt64(reader["ResourceWaitTimeMs"]),
                SignalWaitPct = Convert.ToDecimal(reader["SignalWaitPct"]),
                ResourceWaitPct = Convert.ToDecimal(reader["ResourceWaitPct"]),
                SignalWaitAssessment = Convert.ToString(reader["SignalWaitAssessment"]) ?? string.Empty
            };

        private static WaitRecommendationDto MapRecommendation(DbDataReader reader)
            => new()
            {
                Priority = Convert.ToInt32(reader["Priority"]),
                Pattern = Convert.ToString(reader["Pattern"]) ?? string.Empty,
                Recommendation = Convert.ToString(reader["Recommendation"]) ?? string.Empty,
                SupportingMetric = Convert.ToString(reader["SupportingMetric"]) ?? string.Empty
            };

        private static string? SafeString(DbDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : Convert.ToString(reader.GetValue(ordinal));
        }

        private static int? SafeNullableInt(DbDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : Convert.ToInt32(reader.GetValue(ordinal));
        }
    }
}