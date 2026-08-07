using Concursus.API.Classes;
using Concursus.API.Components;
using Concursus.API.Core;
using Concursus.API.Interfaces;
using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Services.AIAssistant;
using Concursus.API.Services.Finance;
using Concursus.API.Services.Graph;
using Concursus.API.Services.Monitoring;
using Microsoft.Extensions.Caching.Memory;
using Concursus.Common.Shared;
using Concursus.Common.Shared.Classes;
using Concursus.Common.Shared.Data;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Monitoring;
using Concursus.EF.Finance;
using Concursus_EF;
using DocumentFormat.OpenXml.ExtendedProperties;

//using Concursus.EF.Types;
using Google.Protobuf.Collections;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Drawing;
using System.Drawing.Imaging;
using static Concursus.Common.Shared.Enums;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService : Core.Core.CoreBase
{
    #region Private Fields

    private readonly IConfiguration _config;
    private readonly ServiceBase _serviceBase;
    private readonly ISharepointService _sharepointService;
    private readonly JobClosureDecisionRepository _repo;
    private readonly ILookupService _lookupService;
    private readonly ISageApiClient _sageApiClient;
    private readonly ITransactionSageSubmissionAdminService _transactionSageSubmissionAdminService;
    private readonly IDelegatedGraphClientFactory _delegatedGraphClientFactory;
    private readonly ISageInboundPaymentSyncService _sageInboundPaymentSyncService;
    private readonly ISageInboundDiagnosticsRepository _sageInboundDiagnosticsRepository;
    private readonly IAIAssistantAnswerService? _aiAssistantAnswerService;
    private readonly IBlueGenClient? _blueGenClient;
    private readonly IMemoryCache _memoryCache;

    private static readonly Guid JobEntityTypeGuid =
    Guid.Parse("63542427-46ab-4078-abd1-1d583c24315c");

    private static readonly Guid QuoteEntityTypeGuid =
        Guid.Parse("1c4794c1-f956-4c32-b886-5500ac778a56");

    #endregion Private Fields

    #region Public Constructors

    public CoreService(
        ILogger<CoreService> logger,
        IConfiguration config,
        IHttpContextAccessor httpContextAccessor,
        ISharepointService sharepointService,
        JobClosureDecisionRepository repo,
        ILookupService lookupService,
        ISageApiClient sageApiClient,
        ITransactionSageSubmissionAdminService transactionSageSubmissionAdminService,
        IDelegatedGraphClientFactory delegatedGraphClientFactory,
        ISageInboundPaymentSyncService sageInboundPaymentSyncService,
        ISageInboundDiagnosticsRepository sageInboundDiagnosticsRepository,
        IMemoryCache memoryCache,
        IAIAssistantAnswerService? aiAssistantAnswerService = null,
        IBlueGenClient? blueGenClient = null
        )
    {
        _config = config;
        _serviceBase = new ServiceBase(config, httpContextAccessor, new Logging(logger, config));
        _sharepointService = sharepointService;
        _repo = repo;
        _lookupService = lookupService ?? throw new ArgumentNullException(nameof(lookupService));
        _sageApiClient = sageApiClient ?? throw new ArgumentNullException(nameof(sageApiClient));
        _transactionSageSubmissionAdminService = transactionSageSubmissionAdminService ?? throw new ArgumentNullException(nameof(transactionSageSubmissionAdminService));
        _delegatedGraphClientFactory = delegatedGraphClientFactory ?? throw new ArgumentNullException(nameof(delegatedGraphClientFactory));
        _sageInboundPaymentSyncService = sageInboundPaymentSyncService ?? throw new ArgumentNullException(nameof(sageInboundPaymentSyncService));
        _sageInboundDiagnosticsRepository = sageInboundDiagnosticsRepository ?? throw new ArgumentNullException(nameof(sageInboundDiagnosticsRepository));
        _aiAssistantAnswerService = aiAssistantAnswerService;
        _blueGenClient = blueGenClient;
        _memoryCache = memoryCache ?? throw new ArgumentNullException(nameof(memoryCache));

        _serviceBase.logger.LogTrace("Core Service Initialised");
    }
    #endregion Public Constructors

    #region Public Methods




    public override async Task<QuoteCreateJobsStageScheduleValidationResponse> QuoteCreateJobsStageScheduleValidate(
        QuoteCreateJobsStageScheduleValidationRequest request,
        ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.QuoteGuid, out var quoteGuid) || quoteGuid == Guid.Empty)
            {
                const string invalidMessage = "A valid Quote Guid is required before creating a Job.";
                return new QuoteCreateJobsStageScheduleValidationResponse
                {
                    IsValid = false,
                    Message = invalidMessage,
                    ErrorReturned = invalidMessage
                };
            }

            var result = await _serviceBase._entityFramework
                .QuoteCreateJobsStageScheduleValidateAsync(
                    quoteGuid,
                    request.AllowQuoteItemStageFallback,
                    context.CancellationToken)
                .ConfigureAwait(false);

            return new QuoteCreateJobsStageScheduleValidationResponse
            {
                IsValid = result.IsValid,
                RequiresQuoteItemStageFallbackConfirmation = result.RequiresQuoteItemStageFallbackConfirmation,
                Message = result.Message ?? string.Empty,
                ErrorReturned = result.ErrorReturned ?? string.Empty
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "QuoteCreateJobsStageScheduleValidate failed.");
            return new QuoteCreateJobsStageScheduleValidationResponse
            {
                IsValid = false,
                Message = ex.Message,
                ErrorReturned = ex.Message
            };
        }
    }

    public override async Task<GetWaitStatsDashboardResponse> GetWaitStatsDashboard(
    GetWaitStatsDashboardRequest request,
    ServerCallContext context)
    {
        try
        {
            var response = new GetWaitStatsDashboardResponse();

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand("SMonitor.usp_WaitStatsDashboard", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 60
            };

            cmd.Parameters.Add(new SqlParameter("@TopCount", SqlDbType.Int)
            {
                Value = request.TopCount <= 0 ? 15 : request.TopCount
            });

            cmd.Parameters.Add(new SqlParameter("@CpuPressureSignalThresholdPct", SqlDbType.Decimal)
            {
                Precision = 9,
                Scale = 2,
                Value = request.CpuPressureSignalThresholdPct <= 0 ? 25.00m : Convert.ToDecimal(request.CpuPressureSignalThresholdPct)
            });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

            // Result set 1: Summary
            if (await reader.ReadAsync(context.CancellationToken))
            {
                response.Summary = new WaitStatsDashboardSummaryContract
                {
                    SnapshotUtc = Timestamp.FromDateTime(DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("SnapshotUtc")), DateTimeKind.Utc)),
                    DatabaseName = Convert.ToString(reader["DatabaseName"]) ?? string.Empty,
                    ServerName = Convert.ToString(reader["ServerName"]) ?? string.Empty,
                    SqlServerStartTime = Timestamp.FromDateTime(DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("SqlServerStartTime")), DateTimeKind.Utc)),
                    SecondsSinceRestart = Convert.ToInt32(reader["SecondsSinceRestart"]),
                    TotalWaitTimeMs = Convert.ToInt64(reader["TotalWaitTimeMs"]),
                    TotalWaitTimeSeconds = Convert.ToDouble(reader["TotalWaitTimeSeconds"]),
                    TotalSignalWaitTimeMs = Convert.ToInt64(reader["TotalSignalWaitTimeMs"]),
                    TotalSignalWaitTimeSeconds = Convert.ToDouble(reader["TotalSignalWaitTimeSeconds"]),
                    TotalResourceWaitTimeMs = Convert.ToInt64(reader["TotalResourceWaitTimeMs"]),
                    TotalResourceWaitTimeSeconds = Convert.ToDouble(reader["TotalResourceWaitTimeSeconds"]),
                    SignalWaitPct = Convert.ToDouble(reader["SignalWaitPct"]),
                    ResourceWaitPct = Convert.ToDouble(reader["ResourceWaitPct"]),
                    IsCpuPressureHighlighted = Convert.ToBoolean(reader["IsCpuPressureHighlighted"]),
                    CpuPressureMessage = Convert.ToString(reader["CpuPressureMessage"]) ?? string.Empty
                };
            }

            // Result set 2: Categories
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Categories.Add(new WaitCategoryDistributionContract
                {
                    WaitCategory = Convert.ToString(reader["WaitCategory"]) ?? string.Empty,
                    WaitTimeMs = Convert.ToInt64(reader["WaitTimeMs"]),
                    WaitTimeSeconds = Convert.ToDouble(reader["WaitTimeSeconds"]),
                    SignalWaitTimeMs = Convert.ToInt64(reader["SignalWaitTimeMs"]),
                    ResourceWaitTimeMs = Convert.ToInt64(reader["ResourceWaitTimeMs"]),
                    WaitingTasksCount = Convert.ToInt64(reader["WaitingTasksCount"]),
                    PctOfTotalWaitTime = Convert.ToDouble(reader["PctOfTotalWaitTime"])
                });
            }

            // Result set 3: Top waits
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.TopWaits.Add(new TopWaitTypeContract
                {
                    WaitType = Convert.ToString(reader["wait_type"]) ?? string.Empty,
                    WaitCategory = Convert.ToString(reader["WaitCategory"]) ?? string.Empty,
                    WaitingTasksCount = Convert.ToInt64(reader["waiting_tasks_count"]),
                    WaitTimeMs = Convert.ToInt64(reader["wait_time_ms"]),
                    WaitTimeSeconds = Convert.ToDouble(reader["wait_time_seconds"]),
                    SignalWaitTimeMs = Convert.ToInt64(reader["signal_wait_time_ms"]),
                    SignalWaitSeconds = Convert.ToDouble(reader["signal_wait_seconds"]),
                    ResourceWaitTimeMs = Convert.ToInt64(reader["resource_wait_time_ms"]),
                    ResourceWaitSeconds = Convert.ToDouble(reader["resource_wait_seconds"]),
                    MaxWaitTimeMs = Convert.ToInt64(reader["max_wait_time_ms"]),
                    AvgWaitMsPerTask = Convert.ToDouble(reader["avg_wait_ms_per_task"]),
                    PctOfTotalWaitTime = Convert.ToDouble(reader["pct_of_total_wait_time"]),
                    PctSignalWithinWait = Convert.ToDouble(reader["pct_signal_within_wait"])
                });
            }

            // Result set 4: Active waits
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                var blockingSessionId = reader["blocking_session_id"] == DBNull.Value
                    ? (int?)null
                    : Convert.ToInt32(reader["blocking_session_id"]);

                var dop = reader["dop"] == DBNull.Value
                    ? (int?)null
                    : Convert.ToInt32(reader["dop"]);

                var parallelWorkerCount = reader["parallel_worker_count"] == DBNull.Value
                    ? (int?)null
                    : Convert.ToInt32(reader["parallel_worker_count"]);

                response.ActiveWaits.Add(new ActiveWaitContract
                {
                    SnapshotUtc = Timestamp.FromDateTime(DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("SnapshotUtc")), DateTimeKind.Utc)),
                    SessionId = Convert.ToInt32(reader["session_id"]),
                    RequestId = Convert.ToInt32(reader["request_id"]),
                    Status = Convert.ToString(reader["status"]) ?? string.Empty,
                    Command = Convert.ToString(reader["command"]) ?? string.Empty,
                    WaitType = Convert.ToString(reader["wait_type"]) ?? string.Empty,
                    CurrentWaitMs = Convert.ToInt64(reader["current_wait_ms"]),
                    LastWaitType = Convert.ToString(reader["last_wait_type"]) ?? string.Empty,
                    WaitResource = Convert.ToString(reader["wait_resource"]) ?? string.Empty,
                    HasBlockingSessionId = blockingSessionId.HasValue,
                    BlockingSessionId = blockingSessionId.GetValueOrDefault(),
                    CpuTimeMs = Convert.ToInt64(reader["cpu_time_ms"]),
                    TotalElapsedTimeMs = Convert.ToInt64(reader["total_elapsed_time_ms"]),
                    Reads = Convert.ToInt64(reader["reads"]),
                    Writes = Convert.ToInt64(reader["writes"]),
                    LogicalReads = Convert.ToInt64(reader["logical_reads"]),
                    GrantedQueryMemory = Convert.ToInt64(reader["granted_query_memory"]),
                    HasDop = dop.HasValue,
                    Dop = dop.GetValueOrDefault(),
                    HasParallelWorkerCount = parallelWorkerCount.HasValue,
                    ParallelWorkerCount = parallelWorkerCount.GetValueOrDefault(),
                    DatabaseName = Convert.ToString(reader["database_name"]) ?? string.Empty,
                    HostName = Convert.ToString(reader["host_name"]) ?? string.Empty,
                    ProgramName = Convert.ToString(reader["program_name"]) ?? string.Empty,
                    LoginName = Convert.ToString(reader["login_name"]) ?? string.Empty,
                    RunningStatement = Convert.ToString(reader["running_statement"]) ?? string.Empty,
                    BatchText = Convert.ToString(reader["batch_text"]) ?? string.Empty
                });
            }

            // Result set 5: Signal/resource summary
            await reader.NextResultAsync(context.CancellationToken);
            if (await reader.ReadAsync(context.CancellationToken))
            {
                response.SignalResourceSummary = new SignalResourceWaitSummaryContract
                {
                    TotalWaitTimeMs = Convert.ToInt64(reader["TotalWaitTimeMs"]),
                    SignalWaitTimeMs = Convert.ToInt64(reader["SignalWaitTimeMs"]),
                    ResourceWaitTimeMs = Convert.ToInt64(reader["ResourceWaitTimeMs"]),
                    SignalWaitPct = Convert.ToDouble(reader["SignalWaitPct"]),
                    ResourceWaitPct = Convert.ToDouble(reader["ResourceWaitPct"]),
                    SignalWaitAssessment = Convert.ToString(reader["SignalWaitAssessment"]) ?? string.Empty
                };
            }

            // Result set 6: Recommendations
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Recommendations.Add(new WaitRecommendationContract
                {
                    Priority = Convert.ToInt32(reader["Priority"]),
                    Pattern = Convert.ToString(reader["Pattern"]) ?? string.Empty,
                    Recommendation = Convert.ToString(reader["Recommendation"]) ?? string.Empty,
                    SupportingMetric = Convert.ToString(reader["SupportingMetric"]) ?? string.Empty
                });
            }

            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "GetWaitStatsDashboard failed.");
            throw new RpcException(new Status(StatusCode.Internal, ex.Message));
        }
    }

    public override async Task<GetCymBuildSchemaDashboardResponse> GetCymBuildSchemaDashboard(
    GetCymBuildSchemaDashboardRequest request,
    ServerCallContext context)
    {
        try
        {
            var response = new GetCymBuildSchemaDashboardResponse();

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand("SMonitor.usp_CymBuildSchemaDashboard", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 60
            };

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

            // Result set 1: Summary
            if (await reader.ReadAsync(context.CancellationToken))
            {
                response.Summary = new CymBuildSchemaSummaryContract
                {
                    SnapshotUtc = Timestamp.FromDateTime(DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("SnapshotUtc")), DateTimeKind.Utc)),
                    SchemasMonitored = Convert.ToInt32(reader["SchemasMonitored"]),
                    TotalObjectsMonitored = Convert.ToInt32(reader["TotalObjectsMonitored"]),
                    TableCount = Convert.ToInt32(reader["TableCount"]),
                    ViewCount = Convert.ToInt32(reader["ViewCount"]),
                    ProcedureCount = Convert.ToInt32(reader["ProcedureCount"]),
                    FunctionCount = Convert.ToInt32(reader["FunctionCount"]),
                    NonSchemaBoundObjectCount = Convert.ToInt32(reader["NonSchemaBoundObjectCount"]),
                    LargestTableName = Convert.ToString(reader["LargestTableName"]) ?? string.Empty,
                    LargestTableRowCount = reader["LargestTableRowCount"] == DBNull.Value ? 0 : Convert.ToInt64(reader["LargestTableRowCount"]),
                    LargestTableReservedMb = reader["LargestTableReservedMB"] == DBNull.Value ? 0 : Convert.ToDouble(reader["LargestTableReservedMB"])
                };
            }

            // Result set 2: Object counts
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.ObjectCounts.Add(new CymBuildSchemaObjectCountContract
                {
                    SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                    TableCount = Convert.ToInt32(reader["TableCount"]),
                    ViewCount = Convert.ToInt32(reader["ViewCount"]),
                    ProcedureCount = Convert.ToInt32(reader["ProcedureCount"]),
                    FunctionCount = Convert.ToInt32(reader["FunctionCount"]),
                    TotalObjectCount = Convert.ToInt32(reader["TotalObjectCount"])
                });
            }

            // Result set 3: Integrity checks
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.IntegrityChecks.Add(new CymBuildSchemaIntegrityCheckContract
                {
                    CheckName = Convert.ToString(reader["CheckName"]) ?? string.Empty,
                    IsOk = Convert.ToBoolean(reader["IsOk"]),
                    StatusText = Convert.ToString(reader["StatusText"]) ?? string.Empty,
                    Detail = Convert.ToString(reader["Detail"]) ?? string.Empty
                });
            }

            // Result set 4: Largest tables
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.LargestTables.Add(new CymBuildSchemaLargestTableContract
                {
                    SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                    TableName = Convert.ToString(reader["TableName"]) ?? string.Empty,
                    RowCount = Convert.ToInt64(reader["RowCount"]),
                    ReservedMb = Convert.ToDouble(reader["ReservedMB"]),
                    UsedMb = Convert.ToDouble(reader["UsedMB"]),
                    DataMb = Convert.ToDouble(reader["DataMB"]),
                    IndexMb = Convert.ToDouble(reader["IndexMB"])
                });
            }

            // Result set 5: Schema-bound objects
            await reader.NextResultAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.SchemaBoundObjects.Add(new CymBuildSchemaBoundObjectContract
                {
                    SchemaName = Convert.ToString(reader["SchemaName"]) ?? string.Empty,
                    ObjectName = Convert.ToString(reader["ObjectName"]) ?? string.Empty,
                    ObjectType = Convert.ToString(reader["ObjectType"]) ?? string.Empty,
                    ObjectTypeDesc = Convert.ToString(reader["ObjectTypeDesc"]) ?? string.Empty,
                    IsSchemaBound = Convert.ToBoolean(reader["IsSchemaBound"]),
                    StatusText = Convert.ToString(reader["StatusText"]) ?? string.Empty
                });
            }

            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "GetCymBuildSchemaDashboard failed.");
            throw new RpcException(new Status(StatusCode.Internal, ex.Message));
        }
    }

    public override async Task<JobInvoiceProcessingModeGetResponse> JobInvoiceProcessingModeGet(
    JobInvoiceProcessingModeGetRequest request,
    ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.JobGuid, out var jobGuid))
                return new JobInvoiceProcessingModeGetResponse { ErrorReturned = "Invalid jobGuid." };

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand(@"
SELECT TOP (1) InvoiceProcessingMode
FROM SJob.Jobs
WHERE Guid = @JobGuid AND RowStatus NOT IN (0,254);", cn);

            cmd.Parameters.Add(new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid });

            var modeObj = await cmd.ExecuteScalarAsync(context.CancellationToken);
            if (modeObj is null or DBNull)
                return new JobInvoiceProcessingModeGetResponse { ErrorReturned = "Job not found (or inactive)." };

            var mode = (InvoiceProcessingMode)Convert.ToInt32(modeObj);
            return new JobInvoiceProcessingModeGetResponse { Mode = mode, ErrorReturned = "" };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "JobInvoiceProcessingModeGet failed.");
            return new JobInvoiceProcessingModeGetResponse { ErrorReturned = ex.Message };
        }
    }

    public override async Task<JobInvoiceProcessingModeSetResponse> JobInvoiceProcessingModeSet(
        JobInvoiceProcessingModeSetRequest request,
        ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.JobGuid, out var jobGuid))
                return new JobInvoiceProcessingModeSetResponse { ErrorReturned = "Invalid jobGuid." };

            Guid? changedByUserGuid = null;
            if (!string.IsNullOrWhiteSpace(request.ChangedByUserGuid))
            {
                if (!Guid.TryParse(request.ChangedByUserGuid, out var parsed))
                    return new JobInvoiceProcessingModeSetResponse { ErrorReturned = "Invalid changedByUserGuid." };
                changedByUserGuid = parsed;
            }

            // Read old mode
            InvoiceProcessingMode oldMode;

            await using var cn = await OpenSqlAsync(context.CancellationToken);

            await using (var readCmd = new SqlCommand(@"
SELECT TOP (1) InvoiceProcessingMode
FROM SJob.Jobs
WHERE Guid = @JobGuid AND RowStatus NOT IN (0,254);", cn))
            {
                readCmd.Parameters.Add(new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid });
                var oldObj = await readCmd.ExecuteScalarAsync(context.CancellationToken);
                if (oldObj is null or DBNull)
                    return new JobInvoiceProcessingModeSetResponse { ErrorReturned = "Job not found (or inactive)." };

                oldMode = (InvoiceProcessingMode)Convert.ToInt32(oldObj);
            }



            // Apply via your audited proc (and legacy ManualInvoicingEnabled sync)
            await using (var cmd = new SqlCommand("SFin.JobInvoiceProcessingMode_Set", cn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid });
                cmd.Parameters.Add(new SqlParameter("@NewMode", SqlDbType.TinyInt) { Value = (byte)request.NewMode });
                cmd.Parameters.Add(new SqlParameter("@ChangedByUserGuid", SqlDbType.UniqueIdentifier)
                {
                    Value = (object?)changedByUserGuid ?? DBNull.Value
                });
                cmd.Parameters.Add(new SqlParameter("@Reason", SqlDbType.NVarChar, 500) { Value = request.Reason ?? "" });
                cmd.Parameters.Add(new SqlParameter("@Source", SqlDbType.NVarChar, 50) { Value = string.IsNullOrWhiteSpace(request.Source) ? "UI" : request.Source });
                cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId});


                await cmd.ExecuteNonQueryAsync(context.CancellationToken);
            }

            return new JobInvoiceProcessingModeSetResponse
            {
                OldMode = oldMode,
                NewMode = request.NewMode,
                ErrorReturned = ""
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "JobInvoiceProcessingModeSet failed.");
            return new JobInvoiceProcessingModeSetResponse { ErrorReturned = ex.Message };
        }
    }

    public override async Task<InvoiceScheduleDrawdownStageLookupGetResponse> InvoiceScheduleDrawdownStageLookupGet(
    InvoiceScheduleDrawdownStageLookupGetRequest request,
    ServerCallContext context)
    {
        try
        {
            Guid invoiceScheduleGuid = Guid.Empty;

            if (!string.IsNullOrWhiteSpace(request.InvoiceScheduleGuid) &&
                Guid.TryParse(request.InvoiceScheduleGuid, out var parsedInvoiceScheduleGuid))
            {
                invoiceScheduleGuid = parsedInvoiceScheduleGuid;
            }

            var userId = request.UserId > 0
                ? request.UserId
                : _serviceBase._userId;

            var rows = await _serviceBase._entityFramework
                .InvoiceScheduleDrawdownStageLookupGetAsync(
                    userId,
                    invoiceScheduleGuid,
                    context.CancellationToken)
                .ConfigureAwait(false);

            var response = new InvoiceScheduleDrawdownStageLookupGetResponse();

            foreach (var row in rows)
            {
                response.Rows.Add(new InvoiceScheduleDrawdownStageLookupRow
                {
                    Guid = row.Guid.ToString(),
                    Name = row.Name ?? string.Empty
                });
            }

            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "InvoiceScheduleDrawdownStageLookupGet failed.");

            return new InvoiceScheduleDrawdownStageLookupGetResponse
            {
                ErrorReturned = ex.Message
            };
        }
    }

    public override async Task<InvoiceScheduleDrawdownsBulkUpdateResponse> InvoiceScheduleDrawdownsBulkUpdate(
    InvoiceScheduleDrawdownsBulkUpdateRequest request,
    ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.InvoiceScheduleGuid, out var invoiceScheduleGuid) ||
                invoiceScheduleGuid == Guid.Empty)
            {
                return new InvoiceScheduleDrawdownsBulkUpdateResponse
                {
                    Success = false,
                    ErrorReturned = "Invoice schedule guid is required."
                };
            }

            var rows = new List<Concursus.EF.Core.InvoiceScheduleDrawdownBulkUpdateRow>();

            foreach (var row in request.Rows)
            {
                if (!Guid.TryParse(row.Guid, out var rowGuid) || rowGuid == Guid.Empty)
                {
                    continue;
                }

                Guid? ribaStageGuid = null;

                if (Guid.TryParse(row.RibaStageGuid, out var parsedRibaStageGuid) &&
                    parsedRibaStageGuid != Guid.Empty)
                {
                    ribaStageGuid = parsedRibaStageGuid;
                }

                DateTime? onDayOfMonth = null;

                if (DateTime.TryParse(row.OnDayOfMonth, out var parsedDate))
                {
                    onDayOfMonth = parsedDate.Date;
                }

                rows.Add(new Concursus.EF.Core.InvoiceScheduleDrawdownBulkUpdateRow
                {
                    Guid = rowGuid,
                    PeriodNumber = row.PeriodNumber,
                    Amount = Convert.ToDecimal(row.Amount),
                    Percentage = Convert.ToDecimal(row.Percentage),
                    OnDayOfMonth = onDayOfMonth,
                    Description = row.Description ?? string.Empty,
                    RibaStageGuid = ribaStageGuid
                });
            }

            var updatedCount = await _serviceBase._entityFramework
                .InvoiceScheduleDrawdownsBulkUpdateAsync(
                    request.UserId,
                    invoiceScheduleGuid,
                    request.GridCode,
                    rows,
                    request.BypassReadOnlyForAutomationReenable,
                    context.CancellationToken)
                .ConfigureAwait(false);

            return new InvoiceScheduleDrawdownsBulkUpdateResponse
            {
                Success = true,
                UpdatedCount = updatedCount,
                Message = $"Saved {updatedCount} drawdown row(s)."
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "InvoiceScheduleDrawdownsBulkUpdate failed.");

            return new InvoiceScheduleDrawdownsBulkUpdateResponse
            {
                Success = false,
                ErrorReturned = ex.Message
            };
        }
    }

    public override async Task<InvoiceScheduleConfigurationTotalsGetResponse> InvoiceScheduleConfigurationTotalsGet(
    InvoiceScheduleConfigurationTotalsGetRequest request,
    ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.InvoiceScheduleGuid, out var invoiceScheduleGuid) ||
                invoiceScheduleGuid == Guid.Empty)
            {
                return new InvoiceScheduleConfigurationTotalsGetResponse
                {
                    ErrorReturned = "invoiceScheduleGuid must be a valid GUID."
                };
            }

            var userId = request.UserId > 0
                ? request.UserId
                : _serviceBase._userId;

            var totals = await _serviceBase._entityFramework
                .GetInvoiceScheduleConfigurationTotalsAsync(
                    userId,
                    invoiceScheduleGuid,
                    context.CancellationToken)
                .ConfigureAwait(false);

            return new InvoiceScheduleConfigurationTotalsGetResponse
            {
                MonthlyTotalAmount = Convert.ToDouble(totals.MonthlyTotalAmount),
                PercentageTotalPercentage = Convert.ToDouble(totals.PercentageTotalPercentage),
                PercentageTotalAmount = Convert.ToDouble(totals.PercentageTotalAmount),
                ScheduleAmount = Convert.ToDouble(totals.ScheduleAmount),
                ErrorReturned = string.Empty
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "InvoiceScheduleConfigurationTotalsGet failed.");

            return new InvoiceScheduleConfigurationTotalsGetResponse
            {
                ErrorReturned = ex.Message
            };
        }
    }

    public override async Task<JobInvoiceSchedulesGetResponse> JobInvoiceSchedulesGet(
    JobInvoiceSchedulesGetRequest request,
    ServerCallContext context)
    {
        if (!Guid.TryParse(request.ParentGuid, out var jobGuid) || jobGuid == Guid.Empty)
            throw new RpcException(new Status(StatusCode.InvalidArgument, "parentGuid must be a valid GUID."));

        var ct = context.CancellationToken;

        var rows = await _serviceBase._entityFramework.GetJobInvoiceSchedulesAsync(
            request.UserId,
            jobGuid,
            ct);

        var resp = new JobInvoiceSchedulesGetResponse();

        foreach (var r in rows)
        {
            resp.Schedules.Add(new JobInvoiceScheduleDto
            {
                Id = r.Id,
                Guid = r.Guid.ToString(),
                Name = r.Name ?? string.Empty,
                DescriptionOfWork = r.DescriptionOfWork ?? string.Empty,
                Amount = (double)r.Amount,
                TriggerId = r.TriggerId ?? string.Empty,
                ExpectedDateUtc = r.ExpectedDateUtc.HasValue
                    ? Timestamp.FromDateTime(DateTime.SpecifyKind(r.ExpectedDateUtc.Value, DateTimeKind.Utc))
                    : null,

                RibaStageGuid = r.RibaStageGuid?.ToString() ?? string.Empty,
                RibaStageName = r.RibaStageName ?? string.Empty
            });
        }

        return resp;
    }

    private async Task QueueSharePointStructureRepairAsync(
    DataObject dataObject,
    DataObjectUpsertRequest? request,
    CancellationToken cancellationToken)
    {
        if (dataObject == null)
            return;

        var dataObjectGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.Guid);
        var entityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.EntityTypeGuid);

        if (dataObjectGuid == Guid.Empty || entityTypeGuid == Guid.Empty)
            return;

        var payload = new
        {
            DataObjectGuid = dataObjectGuid,
            EntityTypeGuid = entityTypeGuid,
            EntityQueryGuid = request?.EntityQueryGuid ?? string.Empty,
            RequestedOnUtc = DateTime.UtcNow
        };

        var payloadJson = System.Text.Json.JsonSerializer.Serialize(payload);

        const string sql = @"
            IF NOT EXISTS
            (
                SELECT 1
                FROM SCore.IntegrationOutbox AS o
                WHERE o.EventType = N'SharePointStructureRepairRequested'
                  AND o.RowStatus NOT IN (0,254)
                  AND o.PublishedOnUtc IS NULL
                  AND JSON_VALUE(o.PayloadJson, '$.DataObjectGuid') = CONVERT(NVARCHAR(36), @DataObjectGuid)
            )
            BEGIN
                INSERT INTO SCore.IntegrationOutbox
                (
                    Guid,
                    EventType,
                    PayloadJson,
                    CreatedOnUtc,
                    PublishedOnUtc,
                    PublishAttempts,
                    LastError,
                    RowStatus
                )
                VALUES
                (
                    NEWID(),
                    N'SharePointStructureRepairRequested',
                    @PayloadJson,
                    SYSUTCDATETIME(),
                    NULL,
                    0,
                    N'',
                    1
                );
            END;";

        await using var cn = await OpenSqlAsync(cancellationToken).ConfigureAwait(false);
        await using var cmd = new SqlCommand(sql, cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 30
        };

        cmd.Parameters.Add("@DataObjectGuid", SqlDbType.UniqueIdentifier).Value = dataObjectGuid;
        cmd.Parameters.Add("@PayloadJson", SqlDbType.NVarChar, -1).Value = payloadJson;

        await cmd.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    public override async Task<JobInvoicePendingTriggerCountGetResponse> JobInvoicePendingTriggerCountGet(
        JobInvoicePendingTriggerCountGetRequest request,
        ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.JobGuid, out var jobGuid))
                return new JobInvoicePendingTriggerCountGetResponse { ErrorReturned = "Invalid jobGuid." };

            await using var cn = await OpenSqlAsync(context.CancellationToken);

            // IMPORTANT: TriggerInstances have no JobId. We link via QuoteItems schedule->job scope,
            // and your TVF expects JobId after resolving JobGuid -> JobId.
            await using var cmd = new SqlCommand(@"
                        DECLARE @JobId INT =
                        (
                            SELECT TOP (1) ID
                            FROM SJob.Jobs
                            WHERE Guid = @JobGuid AND RowStatus NOT IN (0,254)
                        );

                        IF (@JobId IS NULL)
                        BEGIN
                            SELECT CAST(NULL AS INT);
                            RETURN;
                        END

                        SELECT COUNT(1)
                        FROM SFin.tvf_InvoiceAutomation_PendingTriggerInstancesForJob(@JobId);", cn);

            cmd.Parameters.Add(new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid });

            var countObj = await cmd.ExecuteScalarAsync(context.CancellationToken);
            if (countObj is null or DBNull)
                return new JobInvoicePendingTriggerCountGetResponse { ErrorReturned = "Job not found (or inactive)." };

            return new JobInvoicePendingTriggerCountGetResponse
            {
                PendingCount = Convert.ToInt32(countObj),
                ErrorReturned = ""
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "JobInvoicePendingTriggerCountGet failed.");
            return new JobInvoicePendingTriggerCountGetResponse { ErrorReturned = ex.Message };
        }
    }

    public override async Task<Google.Protobuf.WellKnownTypes.Empty> JobInvoiceGenerateFromPendingTriggers(
        JobInvoiceGenerateFromPendingTriggersRequest request,
        ServerCallContext context)
    {
        try
        {
            if (!Guid.TryParse(request.JobGuid, out var jobGuid))
                throw new RpcException(new Status(StatusCode.InvalidArgument, "Invalid jobGuid."));

            if (!Guid.TryParse(request.RequesterUserGuid, out var requesterUserGuid))
                throw new RpcException(new Status(StatusCode.InvalidArgument, "Invalid requesterUserGuid."));

            await using var cn = await OpenSqlAsync(context.CancellationToken);

            await using var cmd = new SqlCommand("SFin.InvoiceAutomation_GenerateFromPendingTriggerInstances_ForJob", cn)
            {
                CommandType = CommandType.StoredProcedure
            };

            cmd.Parameters.Add(new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid });
            cmd.Parameters.Add(new SqlParameter("@RequesterUserGuid", SqlDbType.UniqueIdentifier) { Value = requesterUserGuid });
            cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = request.Notes ?? "" });

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);
            return new Google.Protobuf.WellKnownTypes.Empty();
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "JobInvoiceGenerateFromPendingTriggers failed.");
            throw new RpcException(new Status(StatusCode.Internal, ex.Message));
        }
    }

    /*
     * CBLD-616: Imports legacy statuses by executing a stored procedure ([SCore].[DataObjectTransitionImportLegacyStatus])
     * **/

    public override async Task<ImportLegacyStatusesRes> ImportLegacyStatuses(ImportLegacyStatusesReq request, ServerCallContext context)
    {
        try
        {
            bool finished = await _serviceBase._entityFramework.ImportLegacyStatuses();

            return new ImportLegacyStatusesRes { Status = finished, ErrorReturned = "" };
        }
        catch (Exception ex)
        {
            var errorMessage = $"Error in ImportLegacyStatuses: {ex.Message}";
            _serviceBase.logger.LogException(ex, errorMessage);

            // Return the response with the error message
            return new ImportLegacyStatusesRes { Status = false, ErrorReturned = errorMessage };
        }
    }

    public override async Task<PhotoFileCheckResponse> CheckPhotoFilesAtUrl(PhotoFileCheckRequest request, ServerCallContext context)
    {
        try
        {
            // Ensure the URL is valid
            if (string.IsNullOrWhiteSpace(request.SharePointUrl))
            {
                return new PhotoFileCheckResponse { ErrorReturned = "Invalid SharePoint URL." };
            }

            // Call the SharePoint class to check for photos at the given URL
            var sharePointHelper = new SharePoint(_config, _sharepointService);
            var numberOfPhotos = await sharePointHelper.CheckForPhotosAsync(request.SharePointUrl);

            // Return the response with the number of photo files found
            return new PhotoFileCheckResponse
            {
                NumberOfPhotos = numberOfPhotos,
                ErrorReturned = string.Empty // No error if everything goes well
            };
        }
        catch (Exception ex)
        {
            var errorMessage = $"Error in CheckPhotoFilesAtUrl: {ex.Message}";
            _serviceBase.logger.LogException(ex, errorMessage);

            // Return the response with the error message
            return new PhotoFileCheckResponse { ErrorReturned = errorMessage };
        }
    }

    public override async Task<ConvertImageResponse> ConvertTiffToPng(ConvertImageRequest request, ServerCallContext context)
    {
        try
        {
            using var memoryStream = new MemoryStream(request.ImageData.ToByteArray());
            using var image = Image.FromStream(memoryStream); // Load TIFF image
            using var pngStream = new MemoryStream();
            image.Save(pngStream, ImageFormat.Png); // Convert to PNG
            var pngBytes = pngStream.ToArray();

            var base64Png = Convert.ToBase64String(pngBytes);

            return new ConvertImageResponse
            {
                Base64Png = base64Png
            };
        }
        catch (Exception ex)
        {
            // Handle exceptions
            throw new RpcException(new Status(StatusCode.Internal, $"Error converting image: {ex.Message}"));
        }
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<DataObjectDeleteResponse> DataObjectDelete(DataObjectDeleteRequest request,
        ServerCallContext context)
    {
        try
        {
            return new DataObjectDeleteResponse()
            {
                Success = await _serviceBase._entityFramework.DataObjectDelete(new EF.Types.DataObjectDeleteRequest()
                {
                    EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                    DataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DataObject)
                })
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new DataObjectDeleteResponse() { Success = false, ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<GetSignatoryInfoResponse> GetSignatoryInfo(GetSignatoryInfoRequest request, ServerCallContext context)
    {
        try
        {
            // Convert GUID strings to actual GUID objects
            Guid jobGuid = string.IsNullOrEmpty(request.JobGuid) ? Guid.Empty : Guid.Parse(request.JobGuid);
            Guid quoteGuid = string.IsNullOrEmpty(request.QuoteGuid) ? Guid.Empty : Guid.Parse(request.QuoteGuid);
            Guid enquiryGuid = string.IsNullOrEmpty(request.EnquiryGuid) ? Guid.Empty : Guid.Parse(request.EnquiryGuid);

            // Call the existing method to fetch signatory info
            var signatories = await _serviceBase._entityFramework.GetSignatoryInfo(jobGuid, quoteGuid, enquiryGuid);

            // Convert the result to the gRPC response format
            var response = new GetSignatoryInfoResponse();
            response.Signatures.AddRange(signatories.Select(s => new SignatureInfo
            {
                EmailAddress = s.EmailAddress,
                FullName = s.FullName,
                JobGuid = s.JobGuid.ToString(),
                EnquiryGuid = s.EnquiryGuid.ToString(),
                QuoteGuid = s.QuoteGuid.ToString(),
                IsActive = s.IsActive,
                JobTitle = s.JobTitle,
                JobTypeName = s.JobTypeName,
                Signature = Google.Protobuf.ByteString.CopyFrom(s.Signature),
                UserGuid = s.UserGuid.ToString()
            }));

            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw new RpcException(new Status(StatusCode.Internal, $"Error fetching signatory info: {ex.Message}"));
        }
    }

    private async Task ApplyTransientVirtualPropertiesToDataObjectAsync(
    EF.Types.DataObject dataObject,
    DataObjectGetRequest request,
    Guid entityTypeGuid)
    {
        if (dataObject == null)
        {
            return;
        }

        if (request.TransientVirtualProperties == null || request.TransientVirtualProperties.Count == 0)
        {
            return;
        }

        var entityType = await _serviceBase._entityFramework.GetEntityType(
            entityTypeGuid,
            false,
            false,
            false,
            request.ForInformationView);

        if (entityType?.EntityProperties == null || entityType.EntityProperties.Count == 0)
        {
            return;
        }

        foreach (var transientProperty in request.TransientVirtualProperties)
        {
            var entityProperty = entityType.EntityProperties
                .FirstOrDefault(x =>
                    string.Equals(x.Name, transientProperty.Key, StringComparison.OrdinalIgnoreCase));

            if (entityProperty == null)
            {
                continue;
            }

            var dataProperty = dataObject.DataProperties
                .FirstOrDefault(x => x.EntityPropertyGuid == entityProperty.Guid);

            if (dataProperty == null)
            {
                dataProperty = new EF.Types.DataProperty
                {
                    EntityPropertyGuid = entityProperty.Guid,
                    IsVirtual = entityProperty.IsVirtual,
                    IsHidden = entityProperty.IsHidden,
                    IsReadOnly = entityProperty.IsReadOnly,
                    IsInvalid = false,
                    ValidationMessage = string.Empty
                };

                dataObject.DataProperties.Add(dataProperty);
            }

            dataProperty.Value = transientProperty.Value;
            dataProperty.IsVirtual = entityProperty.IsVirtual;
            dataProperty.IsHidden = entityProperty.IsHidden;
            dataProperty.IsReadOnly = entityProperty.IsReadOnly;
        }
    }
    public override async Task<DataObjectGetResponse> DataObjectGet(
    DataObjectGetRequest request,
    ServerCallContext context)
    {
        if (string.IsNullOrEmpty(Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid).ToString()))
        {
            request.EntityQueryGuid = Guid.Empty.ToString();
        }

        try
        {
            if (request.ObjectGuids?.Count == 0)
            {
                var entityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid);

                var dataObject = await _serviceBase._entityFramework.DataObjectGet(
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid),
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                    entityTypeGuid,
                    request.ForInformationView,
                    request.TransientVirtualProperties?.ToDictionary(x => x.Key, x => x.Value));

                await ApplyTransientVirtualPropertiesToDataObjectAsync(
                    dataObject,
                    request,
                    entityTypeGuid);

                var coreDataObject = Converters.ConvertEfDataObjectToCoreDataObject(dataObject);

                if (ShouldQueueSharePointStructureRepair(coreDataObject, entityTypeGuid))
                {
                    await QueueSharePointStructureRepairAsync(
                            coreDataObject,
                            null,
                            context.CancellationToken)
                        .ConfigureAwait(false);
                }

                return new DataObjectGetResponse
                {
                    DataObject = coreDataObject
                };
            }

            int pageSize = 50;
            var newDataObjects = new List<EF.Types.DataObject>();
            var entityTypeGuidForPagedRequest = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid);

            for (int i = 0; i < request.ObjectGuids.Count; i += pageSize)
            {
                var pagedGuids = request.ObjectGuids.Skip(i).Take(pageSize).ToList();

                var dataObjects = await _serviceBase._entityFramework.DataObjectGet(
                    Functions.ParseAndReturnListEmptyGuidIfInvalid(new RepeatedField<string> { pagedGuids }),
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                    entityTypeGuidForPagedRequest,
                    request.ForInformationView,
                    request.TransientVirtualProperties?.ToDictionary(x => x.Key, x => x.Value));

                foreach (var dataObjectItem in dataObjects)
                {
                    var coreDataObject = Converters.ConvertEfDataObjectToCoreDataObject(dataObjectItem);

                    if (ShouldQueueSharePointStructureRepair(coreDataObject, entityTypeGuidForPagedRequest))
                    {
                        await QueueSharePointStructureRepairAsync(
                                coreDataObject,
                                null,
                                context.CancellationToken)
                            .ConfigureAwait(false);
                    }

                    newDataObjects.Add(dataObjectItem);
                }
            }

            return new DataObjectGetResponse
            {
                DataObject = new DataObject()
            };
        }
        catch (Exception ex)
        {
            var preMessage = $"Error in DataObjectGet: EntityTypeGuid-{request.EntityTypeGuid}|Guid-{request.Guid}  |  ";
            _serviceBase.logger.LogException(ex, preMessage);

            return new DataObjectGetResponse
            {
                ErrorReturned = preMessage + ex.Message
            };
        }
    }

    public override async Task<DataObjectListGetResponse> DataObjectListGetSingle(DataObjectGetRequest request, ServerCallContext context)
    {
        var response = new DataObjectListGetResponse();

        if (string.IsNullOrEmpty(Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid).ToString()))
            request.EntityQueryGuid = Guid.Empty.ToString();

        try
        {
            // Process the request for a single ObjectGuid
            var dataObjectBatch = await _serviceBase._entityFramework.DataObjectGet(
                Functions.ParseAndReturnListEmptyGuidIfInvalid(request.ObjectGuids),
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid),
                request.ForInformationView
            );

            var newDataObjects = new List<EF.Types.DataObject>();

            foreach (var dataObjectItem in dataObjectBatch)
            {
                if (dataObjectItem.HasDocuments)
                {
                    var _SharePoint = new SharePoint(_config, _sharepointService);
                    var dataObjectUpdateResponse = await _SharePoint.GetSharePointLocation(
                        Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid).ToString(),
                        dataObjectItem, _serviceBase._entityFramework, _serviceBase, null);

                    if (dataObjectUpdateResponse.DataObject.DataProperties.Count > 0)
                    {
                        newDataObjects.Add(dataObjectUpdateResponse.DataObject);
                    }

                    // Dispose of SharePoint object after use
                    _SharePoint.Dispose();
                }
            }

            // Prepare the response with the data objects
            response.DataObjects.AddRange(Converters.ConvertEfDataObjectListToCoreDataObjectList(newDataObjects));
        }
        catch (Exception ex)
        {
            var preMessage = $"Error in DataObjectGet: EntityTypeGuid-{request.EntityTypeGuid}|Guid-{request.Guid}  |  ";
            _serviceBase.logger.LogException(ex, preMessage);

            response.ErrorReturned = preMessage + ex.Message;
        }

        return response;
    }

    public override async Task<DataObjectUpsertResponse> DataObjectUpsert(DataObjectUpsertRequest request,
        ServerCallContext context)
    {
        try
        {
            var calendarEventId = "";
            if (!request.ValidateOnly)
            {
                if (request.DataObject.EntityTypeGuid == "571a9397-7e28-4bef-8ddc-fd4c56787bde")
                {
                    SchedulerHelper schedulerHelper = new(_config);
                    calendarEventId =
                        await schedulerHelper.CreateScheduleItemAsync(request.DataObject, _serviceBase.Identity);
                }
            }

            var dataObjectUpsertResponse = await _serviceBase._entityFramework.DataObjectUpsert(
                new EF.Types.DataObjectUpsertRequest
                {
                    DataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DataObject),
                    DeltaDataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DeltaDataObject ?? new DataObject()), //OE - CBLD-436
                    EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                    ValidateOnly = request.ValidateOnly,
                    SkipValidation = request.SkipValidation,
                });

            //if (!request.ValidateOnly)
            //{
            //    if (dataObjectUpsertResponse.DataObject.HasDocuments)
            //    {
            //        var sharePoint = new SharePoint(_config, _sharepointService);
            //        dataObjectUpsertResponse = await sharePoint.GetSharePointLocation(
            //            Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectUpsertResponse.DataObject.EntityTypeGuid
            //                .ToString()).ToString()
            //            , dataObjectUpsertResponse.DataObject
            //            , _serviceBase._entityFramework
            //            , _serviceBase
            //            , request);
            //    }
            //}

            return new DataObjectUpsertResponse
            {
                DataObject = Converters.ConvertEfDataObjectToCoreDataObject(dataObjectUpsertResponse.DataObject),
                ErrorReturned = dataObjectUpsertResponse.DataObject.ErrorReturned
            };
        }
        catch (Exception ex)
        {
            var preMessage = $"Error in DataObjectUpsertResponse: EntityTypeGuid-{request.DataObject.EntityTypeGuid}|Guid-{request.DataObject.Guid}  |  ";
            _serviceBase.logger.LogException(ex, preMessage);

            return new DataObjectUpsertResponse() { ErrorReturned = preMessage + ex.Message };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<EntityPropertyDefaultResponse> EntityPropertyDefaultGet(
        EntityPropertyDefaultRequest request, ServerCallContext context)
    {
        EntityPropertyDefaultResponse entityPropertyDefaultResponse = new();

        if (request.EntityProperty != null)
            try
            {
                var EFEntityProperty = Converters.ConvertCoreEntityPropertyToEfEntityProperty(request.EntityProperty);
                var entityProperty = await _serviceBase._entityFramework.GetEntityPropertyDefault(EFEntityProperty,
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.ParentGuid), Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid));

                if (entityProperty != null)
                    entityPropertyDefaultResponse.DefaultValue =
                        Functions.ConvertSystemTypeToGoogleProtobufWellknownTypes(entityProperty);
            }
            catch (Exception ex)
            {
                var preMessage = $"Error in EntityPropertyDefaultGet: EntityTypeGuid-{request.EntityProperty.EntityTypeGuid}|Guid-{request.EntityProperty.Guid}  |  ";
                _serviceBase.logger.LogException(ex, preMessage);

                return new EntityPropertyDefaultResponse() { ErrorReturned = preMessage + ex.Message };
            }

        return entityPropertyDefaultResponse;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<EntityTypeGetResponse> EntityTypeGet(EntityTypeGetRequest request,
        ServerCallContext context)
    {
        EntityTypeGetResponse entityTypeGetResponse = new();

        try
        {
            var entityType = await _serviceBase._entityFramework.GetEntityType(Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid), false, false, false, request.IsInformationView);

            entityTypeGetResponse.EntityType =
                Converters.ConvertEfEntityTypeToCoreEntityType(entityType, entityTypeGetResponse);
        }
        catch (Exception ex)
        {
            var preMessage = $"Error in EntityTypeGet: Guid-{request.Guid}  |  ";
            _serviceBase.logger.LogException(ex, preMessage);
            return new EntityTypeGetResponse() { ErrorReturned = preMessage + ex.Message };
        }

        return entityTypeGetResponse;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GetMergeDocumentItemIncludesResponse> GetMergeDocumentItemIncludes(
    GetMergeDocumentItemIncludesRequest request, ServerCallContext context)
    {
        try
        {
            // Extract parameters
            var parentGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.MergeDocumentItemGuid.ToString());
            var userId = _serviceBase._userId; // Fetch the current user ID

            // Call EF method
            var efResults = await _serviceBase._entityFramework.GetMergeDocumentItemIncludes(parentGuid, userId);

            // Convert EF results to Core models
            var coreResults = efResults.Select(ef => Converters.ConvertEfToCoreMergeDocumentItemInclude(ef)).ToList();

            // Return response
            return new GetMergeDocumentItemIncludesResponse
            {
                MergeDocumentItemIncludes = { coreResults }
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new GetMergeDocumentItemIncludesResponse
            {
                MergeDocumentItemIncludes = { },
                ErrorReturned = ex.Message
            };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GetMergeDocumentItemsResponse> GetMergeDocumentItems(
    GetMergeDocumentItemsRequest request, ServerCallContext context)
    {
        try
        {
            // Extract parameters
            var parentGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.MergeDocumentGuid.ToString());
            var userId = _serviceBase._userId; // Fetch the current user ID

            // Call EF method
            var efResults = await _serviceBase._entityFramework.GetMergeDocumentItems(parentGuid, userId);

            // Convert EF results to Core models
            var coreResults = efResults.Select(ef => Converters.ConvertEfToCoreMergeDocumentItem(ef)).ToList();

            // Return response
            return new GetMergeDocumentItemsResponse
            {
                MergeDocumentItems = { coreResults }
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new GetMergeDocumentItemsResponse
            {
                MergeDocumentItems = { },
                ErrorReturned = ex.Message
            };
        }
    }


    public override async Task<BusinessUnitsGetResponse> BusinessUnitsGet(
       BusinessUnitsGetRequest request, ServerCallContext context)
    {
        //Ensure the UserId never equals to -1.
        if (string.IsNullOrEmpty(request.UserId.ToString()) || request.UserId == -1 || request.UserId == 0)
        {
            request.UserId = _serviceBase._entityFramework.UserId;
        }
        try
        {
            var efResult = await _serviceBase._entityFramework.BusinessUnitsGet(request.UserId);

            BusinessUnitsGetResponse rsl = new();

            foreach (var ou in efResult)
                rsl.OrganisationalUnits.Add(Converters.ConvertEfBusinessUnitToCoreBusinessUnit(ou));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new BusinessUnitsGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<DepartmentsGetResponse> DepartmentsGet(
      DepartmentsGetRequest request, ServerCallContext context)
    {
        //Ensure the UserId never equals to -1.
        if (string.IsNullOrEmpty(request.UserId.ToString()) || request.UserId == -1 || request.UserId == 0)
        {
            request.UserId = _serviceBase._entityFramework.UserId;
        }
        try
        {
            var efResult = await _serviceBase._entityFramework.DepartmentsGet(request.UserId, request.BusinessUnitGuid);

            DepartmentsGetResponse rsl = new();

            foreach (var ou in efResult)
                rsl.Department.Add(Converters.ConvertEfDepartmentToCoreDepartment(ou));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new DepartmentsGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<GetUsersForDepartmentResponse> GetUsersForDepartment(GetUsersForDepartmentRequest request, ServerCallContext context)
    {
        try
        {
            var efResult = await _serviceBase._entityFramework.GetUsersForDepartment(request.DepartmentGuid);

            GetUsersForDepartmentResponse rsl = new();

            foreach (var ou in efResult) rsl.Users.Add(Converters.ConvertEfUserToCoreUser(ou));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new GetUsersForDepartmentResponse() { ErrorReturned = ex.Message };
        }
    }


    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GetMergeDocumentItemTypesResponse> GetMergeDocumentItemTypes(
    GetMergeDocumentItemTypesRequest request, ServerCallContext context)
    {
        try
        {
            // Extract user ID (or perform authorization logic)
            var userId = request.UserId;

            // Call EF method to retrieve data
            var efResults = await _serviceBase._entityFramework.GetMergeDocumentItemTypes(userId);

            // Convert EF results to Core models
            var coreResults = efResults.Select(ef => Converters.ConvertEfToCoreMergeDocumentItemType(ef)).ToList();

            // Return response
            return new GetMergeDocumentItemTypesResponse
            {
                MergeDocumentItemTypes = { coreResults }
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new GetMergeDocumentItemTypesResponse
            {
                MergeDocumentItemTypes = { },
                ErrorReturned = ex.Message
            };
        }
    }

    //CBLD-415.
    public override async Task<GetSharePointURLMessage> GetSharePointURL(GetSharePointURLMessageRequest request, ServerCallContext context)
    {
        var sharePoint = new SharePoint(_config, _sharepointService);
        var _dataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DataObject);
        var message = await sharePoint.GetSharePointURL(_dataObject, _serviceBase._entityFramework);

        return new GetSharePointURLMessage()
        {
            Message = message
        };
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override Task<NotificationsForUserGetResponse> NotificationsForUserGet(
        NotificationsForUserGetRequest request, ServerCallContext context)
    {
        try
        {
            NotificationsForUserGetResponse notificationsForUserGetResponse = new();

            return Task.FromResult(notificationsForUserGetResponse);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return Task.FromResult(new NotificationsForUserGetResponse() { ErrorReturned = ex.Message });
        }
    }

    [Authorize(Roles = "SysAdmin")]
    public override async Task<ObjectSecurityListResponse> ObjectSecurityList(ObjectSecurityListRequest request,
        ServerCallContext context)
    {
        try
        {
            ObjectSecurityListResponse rsl = new();

            var objectSecurityListResponse = await EF.Security.ObjectSecurityList(_serviceBase._entityFramework,
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.GroupGuid), Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid));

            foreach (var os in objectSecurityListResponse)
                rsl.ObjectSecurity.Add(Converters.ConvertEfObjectSecurityToCoreObjectSecurity(os));

            return rsl;
        }
        catch (Exception ex)
        {
            var preMessage = $"Error in ObjectSecurityList: GroupGuid-{request.GroupGuid}|RecordGuid-{request.RecordGuid}  |  ";
            _serviceBase.logger.LogException(ex, preMessage);
            return new ObjectSecurityListResponse() { ErrorReturned = preMessage + ex.Message };
        }
    }

    public override async Task<ObjectSharePointPathCollectionGetResponse> ObjectSharePointPathCollectionGet(ObjectSharePointPathCollectionGetRequest request, ServerCallContext context)
    {
        var response = new ObjectSharePointPathCollectionGetResponse();

        try
        {
            // Fetch data from EF service
            var ospResponse = await _serviceBase._entityFramework.ObjectSharePointPathCollectionGet();

            // Ensure we have data
            if (ospResponse != null && ospResponse.Any())
            {
                foreach (var path in ospResponse)
                {
                    // Convert each EF object to gRPC response object and add to the response list
                    var grpcObject = new ObjectSharePointPath
                    {
                        ObjectGuid = path.ObjectGuid.ToString(), // Convert Guid to string as gRPC doesn't have Guid
                        SharePointSiteIdentifier = path.SharePointSiteIdentifier,
                        FolderPath = path.FolderPath,
                        FullSharePointUrl = path.FullSharePointUrl
                    };

                    // Add converted item to the response's repeated field
                    response.ObjectSharePointPaths.Add(grpcObject);
                }
            }
        }
        catch (Exception ex)
        {
            // If there's an error, return an empty response in the response
            return new ObjectSharePointPathCollectionGetResponse
            {
            };
        }

        // Return the populated response
        return response;
    }

    public override async Task<OrganisationalUnitsGetResponse> OrganisationalUnitsGet(
        OrganisationalUnitsGetRequest request, ServerCallContext context)
    {
        //Ensure the UserId never equals to -1.
        if (string.IsNullOrEmpty(request.UserId.ToString()) || request.UserId == -1)
        {
            request.UserId = _serviceBase._entityFramework.UserId;
        }
        try
        {
            var efResult = await _serviceBase._entityFramework.OrganisationalUnitsGet(request.UserId);

            OrganisationalUnitsGetResponse rsl = new();

            foreach (var ou in efResult)
                rsl.OrganisationalUnits.Add(Converters.ConvertEfOrganisationalUnitToCoreOrganisationalUnit(ou));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new OrganisationalUnitsGetResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<RecentItem> RecentItemsCreate(RecentItem recentItem, ServerCallContext context)
    {
        try
        {
            var EFRecentItem = Converters.ConvertCoreRecentItemToEfRecentItem(recentItem);
            await _serviceBase._entityFramework.RecentItemsCreate(EFRecentItem);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new RecentItem() { ErrorReturned = ex.Message };
        }

        return recentItem;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<RecordHistoryGetResponse> RecordHistoryGet(RecordHistoryGetRequest request,
        ServerCallContext context)
    {
        try
        {
            RecordHistoryGetResponse rsl = new();

            var historyList = await EF.RecordHistory.RecordHistoryGet(_serviceBase._entityFramework, request.RecordId);

            foreach (var rh in historyList)
                rsl.RecordHistory.Add(Converters.ConvertEfRecordHistoryToCoreRecordHistory(rh));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new RecordHistoryGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override Task<RecordUrlGetResponse> RecordUrlGet(RecordUrlGetRequest request, ServerCallContext context)
    {
        try
        {
            RecordUrlGetResponse reply = new();
            var ShoreSection = _config.GetSection("Shore");
            var url = "";

            if (ShoreSection != null)
            {
                var GenericUrlTypesSection = ShoreSection.GetSection("GenericUrlTypes");
                url = GenericUrlTypesSection.GetValue<string>(request.EntityType) ?? "";
            }

            url = url.Replace("[[rowId]]", request.RowId.ToString());

            if (url.Contains("[[filingLocation]]"))
            {
                FilePath filePath = new()
                {
                    FilingLocation = FilingLocation.Local,
                    ServerBaseLocation = _config.GetValue<string>("ServerBaseLoc") ?? "",
                    RecordId = request.RowId,
                    FileName = "x"
                };

                switch (request.EntityType)
                {
                    case "BCJob":
                        filePath.RootFolder = RootFolder.Bcfolder;
                        break;

                    case "ShoreJob":
                        filePath.RootFolder = RootFolder.Shorefolder;
                        break;

                    case "Quote":
                        filePath.RootFolder = RootFolder.Quotefolder;
                        break;

                    case "User":
                        filePath.RootFolder = RootFolder.Usersfolder;
                        break;
                }

                url = url.Replace("[[filingLocation]]", Storage.GetFilingLocation(filePath));
            }

            reply.Url = url;

            return Task.FromResult(reply);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return Task.FromResult(new RecordUrlGetResponse() { ErrorReturned = ex.Message });
        }
    }

    public override async Task<WidgetLayoutSaveResponse> SaveWidgetLayout(WidgetLayoutPOST request, ServerCallContext context)
    {
        try
        {
            WidgetLayoutSaveResponse rsl = new();

            var WidgetLayout = await _serviceBase._entityFramework.SaveWidgetLayout(request.UserId, request.WidgetLayout);

            return rsl;
        }
        catch (Exception ex)
        {
            return new WidgetLayoutSaveResponse() { ErrorMessage = ex.Message };
        }
    }

    public override async Task<ScheduleItemsGetResponse> ScheduleItemsGet(ScheduleItemsGetRequest request,
            ServerCallContext context)
    {
        try
        {
            var efResult = await _serviceBase._entityFramework.ScheduleItemsGet(request.CurrentUserOnly);

            ScheduleItemsGetResponse rsl = new();

            foreach (var si in efResult) rsl.ScheduleItems.Add(Converters.ConvertEfScheduleItemToCoreScheduleItem(si));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new ScheduleItemsGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<ScheduleItemStatusGetResponse> ScheduleItemStatusGet(
        ScheduleItemStatusGetRequest request, ServerCallContext context)
    {
        try
        {
            var efResult = await _serviceBase._entityFramework.ScheduleItemStatusGet();

            ScheduleItemStatusGetResponse rsl = new();

            foreach (var sis in efResult)
                rsl.ScheduleItemStatus.Add(Converters.ConvertEfScheduleItemStatusToCoreScheduleItemStatus(sis));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new ScheduleItemStatusGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<ScheduleItemTypesGetResponse> ScheduleItemTypesGet(ScheduleItemTypesGetRequest request,
        ServerCallContext context)
    {
        try
        {
            var efResult = await _serviceBase._entityFramework.ScheduleItemTypesGet();

            ScheduleItemTypesGetResponse rsl = new();

            foreach (var sit in efResult)
                rsl.ScheduleItemTypes.Add(Converters.ConvertEfScheduleItemTypeToCoreScheduleItemType(sit));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new ScheduleItemTypesGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<SharePointCreateResponse> SharePointCreate(
        SharePointCreateRequest request,
        ServerCallContext context)
    {
        try
        {
            if (request?.DataObject == null)
            {
                return new SharePointCreateResponse
                {
                    DataObject = new DataObject(),
                    Success = false,
                    ErrorReturned = "DataObject is required."
                };
            }

            var dataObjectGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.DataObject.Guid);
            var entityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.DataObject.EntityTypeGuid);

            if (dataObjectGuid == Guid.Empty || entityTypeGuid == Guid.Empty)
            {
                return new SharePointCreateResponse
                {
                    DataObject = request.DataObject,
                    Success = false,
                    ErrorReturned = "DataObject Guid and EntityTypeGuid are required to create or repair a SharePoint document location."
                };
            }

            // SharePointCreate is called by UI paths that expect the location to be available in
            // the response. Queueing the repair only leaves the caller with an empty SharePointUrl
            // and causes the document browser to keep polling until the outbox item exhausts its
            // attempts. Therefore explicit/manual SharePointCreate performs the repair synchronously
            // and persists the repaired location before returning.
            using var sharePoint = new SharePoint(_config, _sharepointService);

            var efDataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DataObject);

            var upsertRequest = new DataObjectUpsertRequest
            {
                DataObject = request.DataObject,
                EntityQueryGuid = string.IsNullOrWhiteSpace(request.DataObjectUpsertRequest?.EntityQueryGuid)
                    ? Guid.Empty.ToString()
                    : request.DataObjectUpsertRequest.EntityQueryGuid,
                ValidateOnly = false
            };

            var repairResponse = await sharePoint.GetSharePointLocation(
                    entityTypeGuid.ToString(),
                    efDataObject,
                    _serviceBase._entityFramework,
                    _serviceBase,
                    upsertRequest)
                .ConfigureAwait(false);

            var repairedDataObject = repairResponse?.DataObject != null
                ? Converters.ConvertEfDataObjectToCoreDataObject(repairResponse.DataObject)
                : request.DataObject;

            if (string.IsNullOrWhiteSpace(repairedDataObject.SharePointUrl))
            {
                // Keep the background repair safety net, but do not report success to the caller.
                await QueueSharePointStructureRepairAsync(
                        request.DataObject,
                        upsertRequest,
                        context.CancellationToken)
                    .ConfigureAwait(false);

                return new SharePointCreateResponse
                {
                    DataObject = repairedDataObject,
                    Success = false,
                    ErrorReturned = "SharePoint repair did not return a SharePointUrl. A background repair has been queued."
                };
            }

            return new SharePointCreateResponse
            {
                DataObject = repairedDataObject,
                Success = true,
                ErrorReturned = string.Empty
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "Error in SharePointCreate");

            return new SharePointCreateResponse
            {
                DataObject = request?.DataObject ?? new DataObject(),
                Success = false,
                ErrorReturned = ex.Message
            };
        }
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<SharePointDocumentDetailsGetResponse> SharePointDocumentDetailsGet(
        SharePointDocumentDetailsGetRequest request, ServerCallContext context)
    {
        try
        {
            var test =
                await _serviceBase._entityFramework.GetSharepointSiteIdentifier(Functions.ParseAndReturnEmptyGuidIfInvalid(request.SharePointSiteID));// Functions.ParseAndReturnEmptyGuidIfInvalid("3e4137a6-926b-4859-9e4e-f1d31173abd7"))

            SharePointDocumentDetailsGetResponse rsl = new();

            SharePoint sharePoint = new(_config, _sharepointService);

            rsl.DriveListItem.Add(await sharePoint.GetSharePointDocumentDetails(test, "form Templates", request.SharePointTemplateFolderName));

            //OE - Added on 25/07/24
            sharePoint.Dispose();

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new SharePointDocumentDetailsGetResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<SharepointDocumentsGetResponse> SharepointDocumentsGet(
    SharepointDocumentsGetRequest request, ServerCallContext context)
    {
        try
        {
            // Initialize SharePoint instance
            var sharePoint = new SharePoint(_config, _sharepointService);

            // Retrieve data object and entity type
            var dataObject = await _serviceBase._entityFramework.DataObjectGet(
                                Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid),
                                Guid.Empty,
                                Functions.ParseAndReturnEmptyGuidIfInvalid(request.LinkedEntityTypeGuid),
                                false);
            var entityType = await _serviceBase._entityFramework.GetEntityType(
                                Functions.ParseAndReturnEmptyGuidIfInvalid(request.LinkedEntityTypeGuid),
                                false, false);

            // Get merge data based on the retrieved data object and entity type
            var mergeData = Functions.GetMergeData(dataObject, entityType);
            Niah.WriteLine("[INFO] Merge Data Count:", mergeData.Count());
            // Retrieve SharePoint information for the specified record
            var point = new SharePoint(_config, _sharepointService);
            var dataObjectSharePoint = await _serviceBase._entityFramework.DataObjectGet(
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid),
                Functions.ParseAndReturnEmptyGuidIfInvalid(Guid.Empty.ToString()),
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid),
                false);
            var dataObjectUpdateResponse = await point.GetSharePointLocation(
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid).ToString(),
                dataObjectSharePoint,
                _serviceBase._entityFramework,
                _serviceBase,
                null);

            dataObject = dataObjectUpdateResponse.DataObject;
            // Initialize response object
            var sharepointDocumentsGetResponse = new SharepointDocumentsGetResponse();

            // 08A: initial DataObjectGet now carries merge-document headers only.
            // Hydrate the selected merge document here, only when the user actually generates it.
            var mergeDocument = request.MergeDocument ?? new MergeDocument();
            if (mergeDocument.Items.Count == 0 &&
                Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.Guid) != Guid.Empty)
            {
                var swMergeDocHydrate = System.Diagnostics.Stopwatch.StartNew();
                var fullMergeDocuments = await _serviceBase._entityFramework.GetMergeDocuments(
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid),
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid));

                var selectedMergeDocument = fullMergeDocuments.FirstOrDefault(x =>
                    x.Guid == Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.Guid));

                if (selectedMergeDocument != null)
                {
                    mergeDocument = Converters.ConvertEfMergeDocumentToCoreMergeDocument(selectedMergeDocument);
                }

                swMergeDocHydrate.Stop();
                Console.WriteLine($"[CymBuildPerf] Layer=gRPC Method=SharepointDocumentsGet Step=MergeDocumentHydratedOnDemand DocumentGuid={mergeDocument.Guid} ItemCount={mergeDocument.Items.Count} DurationMs={swMergeDocHydrate.ElapsedMilliseconds}");
            }

            //OE: The dataobject gets upserted in here.
            if (!request.AllowExcelOutputOnly)
            {
                var UserId = _serviceBase._entityFramework.UserId;
                sharepointDocumentsGetResponse = await sharePoint.GetSharePointDocumentsWithMergeDocument(
                    _serviceBase._entityFramework,
                    request.RecordGuid,
                    request.SiteId,
                    request.FilenameTemplate,
                    dataObject.SharePointUrl,
                    request.DocumentId,
                    mergeData,
                    mergeDocument,
                    request.OutputType,
                    UserId,
                    false,
                    _serviceBase,
                    request.EntityTypeGuid
                    );
            }
            else
            {
                // Call the Excel version if AllowExcelOutputOnly is true.
                var UserId = _serviceBase._entityFramework.UserId;
                sharepointDocumentsGetResponse = await sharePoint.GetSharePointDocumentsWithMergeDocumentExcel(
                    _serviceBase._entityFramework,
                    request.RecordGuid,
                    request.SiteId,
                    request.FilenameTemplate,
                    dataObject.SharePointUrl,
                    request.DocumentId,
                    mergeData,
                    mergeDocument,
                    "Excel",
                    UserId,
                    false,
                    _serviceBase,
                    request.EntityTypeGuid);
            }

            //OE - Added on 25/07/24
            sharePoint.Dispose();

            return sharepointDocumentsGetResponse;
        }
        catch (Exception ex)
        {
            // Log exception and rethrow
            _serviceBase.logger.LogException(ex);
            return new SharepointDocumentsGetResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<UserInfoUpdateResponse> UpdateUserSignature(UserInfoUpdateRequest request,
        ServerCallContext context)
    {
        try
        {
            var efUser = Converters.ConvertCoreUserToEfUser(request.User);
            var efResult = await _serviceBase._entityFramework.UpdateUserSignature(efUser);

            return new UserInfoUpdateResponse()
            {
                User = Converters.ConvertEfUserToCoreUser(efResult)
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new UserInfoUpdateResponse() { ErrorReturned = ex.Message };
        }
    }

    //        return new SharePointFileUploadResponse
    //        {
    //            IsSuccess = true
    //        };
    //    }
    //    catch (Exception ex)
    //    {
    //        return new SharePointFileUploadResponse
    //        {
    //            IsSuccess = false,
    //            ErrorMessage = ex.Message
    //        };
    //    }
    //}
    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<Core.UploadStatus> UploadFileChunk(IAsyncStreamReader<ChunkMsg> requestStream, ServerCallContext context)
    {
        string fileName = string.Empty;
        string filePath = string.Empty;
        byte[] fileData;

        SharePoint sharePoint = new(_config, _sharepointService);
        try
        {
            using (var memoryStream = new MemoryStream())
            {
                await foreach (var chunk in requestStream.ReadAllAsync())
                {
                    if (string.IsNullOrEmpty(fileName))
                    {
                        // Initialize fileName and filePath from the first chunk
                        fileName = chunk.FileName;
                        filePath = chunk.StorageUrl;
                    }

                    // Write chunk data to memory stream
                    await memoryStream.WriteAsync(chunk.Chunk.ToByteArray());
                }

                fileData = memoryStream.ToArray(); // Combine all chunks into a byte array
            }

            // Call the method to upload the file to SharePoint or another storage
            await sharePoint.UploadFileToSharePoint(filePath, fileName, fileData);

            return new Core.UploadStatus
            {
                Success = true,
                Message = "File uploaded successfully."
            };
        }
        catch (Exception ex)
        {
            return new Core.UploadStatus
            {
                Success = false,
                Message = $"Error uploading file: {ex.Message}"
            };
        }
    }

    //Get User Record By Guid
    public override async Task<UserGetByGuidResponse> UserGetByGuid(UserGetByGuidRequest request, ServerCallContext context)
    {
        try
        {
            var efResult = await _serviceBase._entityFramework.GetUserByGuid(Guid.Parse(request.Guid));

            UserGetByGuidResponse rsl = new();

            rsl.User = Converters.ConvertEfUserToCoreUser(efResult);

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new UserGetByGuidResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "SysAdmin")]
    public override async Task<UserGroupListResponse> UserGroupList(UserGroupListRequest request,
        ServerCallContext context)
    {
        try
        {
            await EF.Security.UserGroupList(_serviceBase._entityFramework, request.UserId);

            return new UserGroupListResponse();
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new UserGroupListResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<UserInfoGetResponse> UserInfoGet(UserInfoGetRequest request, ServerCallContext context)
    {
        try
        {
            UserInfoGetResponse response;

            if (string.IsNullOrEmpty(request.Username))
            {
                response = await Functions.GetUserResponseFromCurrentIdentityAsync(_serviceBase);
            }
            else
            {
                response = await Functions.GetUserResponseByUsernameAsync(request, _serviceBase);
            }

            TriggerCoreEntityTypeWarmup("UserInfoGet");

            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new UserInfoGetResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<UserPreferencesGetResponse> UserPreferencesGet(UserPreferencesGetRequest request,
        ServerCallContext context)
    {
        try
        {
            UserPreferencesGetResponse rsl = new();

            var userPreferences = await _serviceBase._entityFramework.GetUserPreferences(request.UserId);

            rsl.UserPreferences = Converters.ConvertEfUserPreferencesToCoreUserPreferences(userPreferences);

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new UserPreferencesGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<UsersGetResponse> UsersGet(UsersGetRequest request, ServerCallContext context)
    {
        try
        {
            var efResult = await _serviceBase._entityFramework.UsersGet();

            UsersGetResponse rsl = new();

            foreach (var ou in efResult) rsl.Users.Add(Converters.ConvertEfUserToCoreUser(ou));

            return rsl;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            return new UsersGetResponse() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<UsageResponse> LogUsage(UsageRequest request, ServerCallContext context)
    {
        try
        {
            await _serviceBase._entityFramework.LogUsage(Guid.Parse(request.UserId), request.FeatureName);
            return new UsageResponse { Message = "Usage logged successfully." };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogError($"Error logging usage: {ex.Message}");
            return new UsageResponse { Message = $"Unable to Update Usage Table Error recieved - {ex.Message}" };
            //throw new RpcException(new Status(StatusCode.Internal, "Error logging usage"));
        }
    }

    public override async Task<UsageReportResponse> GetUsageReport(UsageReportRequest request, ServerCallContext context)
    {
        try
        {
            if (request.StartDateUtc == null || request.EndDateUtc == null)
                throw new ArgumentException("StartDateUtc and EndDateUtc must be provided.");

            // These are already UTC, no parsing or conversion needed
            var startDate = DateTime.SpecifyKind(request.StartDateUtc.ToDateTime(), DateTimeKind.Utc);
            var endDate = DateTime.SpecifyKind(request.EndDateUtc.ToDateTime(), DateTimeKind.Utc);

            if (endDate <= startDate)
                throw new ArgumentException("EndDateUtc must be after StartDateUtc.");

            var usageData = await _serviceBase._entityFramework.GetUsageReport(startDate, endDate, request.UserGuid);

            var response = new UsageReportResponse();
            response.UsageData.AddRange(usageData.Select(u => new UsageData
            {
                Username = u.Username,
                FeatureName = u.FeatureName,
                UsageCount = u.UsageCount,
                WeeklyAverage = u.WeeklyAverage,
                FirstAccessed = u.FirstAccessed,
                LastAccessed = u.LastAccessed
            }));

            return response;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error retrieving usage report for UserGuid: {request.UserGuid}, Start: {request.StartDateUtc?.ToDateTime()}, End: {request.EndDateUtc?.ToDateTime()} - Error: {ex.Message}");
            throw new RpcException(new Status(StatusCode.Internal, $"Error retrieving usage report: {ex.Message}"));
        }
    }

    public override async Task<UserUsageLast7DaysResponse> GetUserUsageLast7Days(Empty request, ServerCallContext context)
    {
        try
        {
            var usageData = await _serviceBase._entityFramework.GetUserUsageLast7Days();
            var response = new UserUsageLast7DaysResponse();
            foreach (var user in usageData)
            {
                var item = new UserUsageLast7DaysData
                {
                    Username = user.Username,
                    UserGuid = user.UserGuid.ToString(),
                    UsageCountLast7Days = user.UsageCountLast7Days,
                    UsageCountPrevious7Days = user.UsageCountPrevious7Days,
                    ActiveDaysLast7Days = user.ActiveDaysLast7Days,
                    FeaturesUsedLast7Days = user.FeaturesUsedLast7Days,
                    UsageTrend = user.UsageTrend
                };
                if (user.LastAccessedLast7Days.HasValue)
                {
                    item.LastAccessedLast7Days = Timestamp.FromDateTime(
                        DateTime.SpecifyKind(user.LastAccessedLast7Days.Value, DateTimeKind.Utc));
                }
                response.Users.Add(item);
            }
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw new RpcException(new Status(StatusCode.Internal, "The seven-day user usage report could not be retrieved."));
        }
    }

    public override async Task<GetQuoteDashboardDataRes> GetQuoteDashboardData(GetQuoteDashboardDataReq req, ServerCallContext context)
    {
        try
        {
            var resp = new GetQuoteDashboardDataRes();
            var QuoteDashboardData = await _serviceBase._entityFramework.GetQuoteDashboardData();

            foreach (var q in QuoteDashboardData)
            {
                resp.Res.Add(Converters.ConvertEFQuoteDashboardDataToCoreQuoteDashboardData(q));
            }

            return resp;
        }
        catch (Exception ex)
        {
            return new GetQuoteDashboardDataRes() { ErrorReturned = ex.Message };
        }
    }

    /// <summary>
    /// Returns the quote threshold / business unit.
    /// </summary>
    /// <param name="req">     </param>
    /// <param name="context"> </param>
    /// <returns> </returns>
    public override async Task<GetQuoteThresholdRes> GetThresholdsForOrgUnit(GetQuoteThresholdReq req, ServerCallContext context)
    {
        try
        {
            var resp = new GetQuoteThresholdRes();

            double Threshold = await _serviceBase._entityFramework.GetThresholdsForOrgUnit(req.UserId);

            resp.QuoteThreshold = Threshold;

            return resp;
        }
        catch (Exception ex)
        {
            return new GetQuoteThresholdRes() { ErrorReturned = ex.Message };
        }
    }

    public override async Task<GetInvoiceRequestItemsByGuidRes> GetInvoiceRequestItemsByGuid(GetInvoiceRequestItemsByGuidReq req, ServerCallContext context)
    {
        try
        {
            var resp = new GetInvoiceRequestItemsByGuidRes();

            var guid = await _serviceBase._entityFramework.GetInvoiceRequestItemsByGuid(req.UserId, req.InvoiceReqGuid);

            foreach(var i in guid)
            {
                resp.Guid.Add(i);
            }

            return resp;
        }
        catch (Exception ex)
        {
            return new GetInvoiceRequestItemsByGuidRes();
        }
    }

    public override async Task<DeleteInvoiceRequestRes> DeleteInvoiceRequest(DeleteInvoiceRequestReq request, ServerCallContext context)
    {
        try
        {
            bool finished = await _serviceBase._entityFramework.MarkInvoiceRequestAsMerged(request.Guid);

            return new DeleteInvoiceRequestRes { Status = finished, ErrorReturned = "" };
        }
        catch (Exception ex)
        {
            var errorMessage = $"Error deleting invoice request: {ex.Message}";
            _serviceBase.logger.LogException(ex, errorMessage);

            // Return the response with the error message
            return new DeleteInvoiceRequestRes { Status = false, ErrorReturned = errorMessage };
        }
    }

    public override async Task<JobClosureDecisionResponse> JobClosureDecision(JobClosureDecisionRequest request, ServerCallContext context)
    {
        if (!Guid.TryParse(request.JobGuid, out var jobGuid))
        {
            return new JobClosureDecisionResponse
            {
                Success = false,
                Message = "Invalid JobGuid.",
                JobGuid = request.JobGuid ?? "",
                Decision = request.Decision
            };
        }

        var decision = request.Decision switch
        {
            JobClosureDecisionType.JobClosureDecisionApprove => (byte)1,
            JobClosureDecisionType.JobClosureDecisionReject => (byte)2,
            _ => (byte)0
        };

        if (decision == 0)
        {
            return new JobClosureDecisionResponse
            {
                Success = false,
                Message = "Decision must be Approve or Reject.",
                JobGuid = request.JobGuid,
                Decision = request.Decision
            };
        }

        if (decision == 2 && string.IsNullOrWhiteSpace(request.Comment))
        {
            return new JobClosureDecisionResponse
            {
                Success = false,
                Message = "Rejection requires a comment.",
                JobGuid = request.JobGuid,
                Decision = request.Decision
            };
        }

        var result = await _repo.ApplyDecisionAsync(jobGuid, request.UserId, decision, request.Comment, context.CancellationToken);

        return new JobClosureDecisionResponse
        {
            Success = result.Success,
            Message = result.Message,
            JobGuid = request.JobGuid,
            Decision = request.Decision,
            StoredComment = result.StoredComment,
            DecisionDateTimeUtc = Timestamp.FromDateTime(DateTime.SpecifyKind(result.DecisionDateTimeUtc, DateTimeKind.Utc))
        };
    }

    // Generic approval/rejection for AUTHORISATION queue rows (Quotes/Enquiries/other)
    public override async Task<AuthorisationDecisionResponse> AuthorisationDecision(
    AuthorisationDecisionRequest request,
    ServerCallContext context)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.RecordGuid) || !Guid.TryParse(request.RecordGuid, out var recordGuid))
            {
                return new AuthorisationDecisionResponse
                {
                    Success = false,
                    Message = "Invalid RecordGuid.",
                    RecordGuid = request.RecordGuid ?? "",
                    EntityTypeName = request.EntityTypeName ?? "",
                    Approve = request.Approve
                };
            }

            var result = await _serviceBase._entityFramework.AuthorisationDecisionAsync(
                userId: request.UserId,
                recordGuid: recordGuid,
                entityTypeName: request.EntityTypeName ?? "",
                approve: request.Approve,
                comment: request.Comment,
                ct: context.CancellationToken);

            return new AuthorisationDecisionResponse
            {
                Success = result.Success,
                Message = result.Message ?? "",

                RecordGuid = request.RecordGuid ?? "",
                EntityTypeName = request.EntityTypeName ?? "",
                Approve = request.Approve,

                StoredComment = result.StoredComment ?? "",
                DecisionDateTimeUtc = result.DecisionDateTimeUtc.HasValue
                    ? Google.Protobuf.WellKnownTypes.Timestamp.FromDateTime(
                        DateTime.SpecifyKind(result.DecisionDateTimeUtc.Value, DateTimeKind.Utc))
                    : new Google.Protobuf.WellKnownTypes.Timestamp(),

                FromStatusGuid = result.FromStatusGuid?.ToString() ?? "",
                ToStatusGuid = result.ToStatusGuid?.ToString() ?? ""
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogError($"AuthorisationDecision failed for {request.RecordGuid} {request.EntityTypeName}");

            return new AuthorisationDecisionResponse
            {
                Success = false,
                Message = ex.Message,
                RecordGuid = request.RecordGuid ?? "",
                EntityTypeName = request.EntityTypeName ?? "",
                Approve = request.Approve
            };
        }
    }


    public override async Task<PublicHolidayListResponse> GetHolidays(HolidayReq req, ServerCallContext context)
    {
        try
        {
            var publicHolidays = await _serviceBase._entityFramework.GetBankHolidays();

            var resp = new PublicHolidayListResponse();

            foreach (var holiday in publicHolidays)
            {
                resp.Holidays.Add(Converters.ConvertEFPublicHolidayToCorePublicHoliday(holiday));
            }

            return resp;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error retrieving public bank holidays");
            throw new RpcException(new Status(StatusCode.Internal, $"Error retrieving public bank holidays"));
        }
    }

    public override async Task<NonActivityEventsResp> GetNonActivityEvents(GetNonActivityEventsReq req, ServerCallContext context)
    {
        try
        {
            var nonActivityEvents = await _serviceBase._entityFramework.GetNonActivityEvents(req.UserId, req.StartDate.ToDateTime(), req.EndDate.ToDateTime());
            var resp = new NonActivityEventsResp();

            foreach (var nA in nonActivityEvents)
            {
                resp.NonActivityEvents.Add(Converters.ConvertEFNonActivityEventsToCoreNonActivityEvents(nA));
            }

            return resp;
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex);
            throw new RpcException(new Status(StatusCode.Internal, $"Error retrieving non-activity events for Schedule"));
        }
    }

    public override async Task<TeamMemberListResponse> GetTeamMembers(TeamRequest request, ServerCallContext context)
    {
        try
        {
            var team = await _serviceBase._entityFramework.GetTeamMembersAsync(request.OrganisationalUnitId);
            return new TeamMemberListResponse
            {
                TeamMembers = { team.Select(t => new TeamMember
            {
                Id = t.IdentityId.ToString(),
                Name = t.FullName,
                Color = t.Color
            })}
            };
        }
        catch (Exception ex)
        {
            return new TeamMemberListResponse { ErrorReturned = ex.Message };
        }
    }

    public override async Task<ScheduledActivitiesRes> GetScheduledActivities(ScheduledActivitiesReq req, ServerCallContext context)
    {
        try
        {
            var ScheduledActivities = await _serviceBase._entityFramework.GetScheduledActivities(req.UserId, req.StartDate.ToDateTime(), req.EndDate.ToDateTime());
            //var ScheduledActivities = await _serviceBase._entityFramework.GetScheduledActivities(req.UserId);
            var resp = new ScheduledActivitiesRes();

            foreach (var activity in ScheduledActivities)
            {
                resp.ScheduledActivities.Add(Converters.ConvertEFScheduledActivtyToCoreScheduledActivity(activity));
            }

            return resp;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"Error retrieving non-activity events for Schedule"));
        }
    }

    public override async Task<OrganisationalUnitForUserRes> GetOrganisationalUnitForUser(OrganisationalUnitForUserReq req, ServerCallContext context)
    {
        try
        {
            var OrgUnitForUser = await _serviceBase._entityFramework.GetOrganisationUnitForUsers(req.UserId);
            var resp = new OrganisationalUnitForUserRes();

            resp.OrganisationalUnitIDForUser = Converters.ConvertEFOrganisationalUnitForUserToCoreOrganisationalUnitForUser(OrgUnitForUser);

            return resp;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"Error retrieving non-activity events for Schedule"));
        }
    }


    private static bool ShouldQueueSharePointStructureRepair(
        DataObject dataObject,
        Guid entityTypeGuid)
    {
        if (dataObject == null || !dataObject.HasDocuments)
        {
            return false;
        }

        return string.IsNullOrWhiteSpace(dataObject.SharePointUrl)
            || string.IsNullOrWhiteSpace(dataObject.SharePointFolderPath);
    }

    #endregion Public Methods

    //[Authorize(Roles = "User.ReadWrite")]
    //public override async Task<SharePointFileUploadResponse> UploadFile(SharePointFileUploadRequest request, ServerCallContext context)
    //{
    //    try
    //    {
    //        // Convert ByteString to byte[]
    //        byte[] fileData = request.Data.ToByteArray();

    // // Store the file at the location specified by storageUrl var sharePoint = new
    // SharePoint(_config); // Assuming Config is set in CoreService

    #region Private Methods
    private string ResolveSqlConnectionString()
    {
        // Try the common names used across your solutions/environments.
        var cs =
            _config.GetConnectionString("ShoreDB")
            ?? _config.GetConnectionString("CymBuild")
            ?? _config.GetConnectionString("DefaultConnection")
            ?? _config.GetConnectionString("ConnectionString");

        if (string.IsNullOrWhiteSpace(cs))
            throw new InvalidOperationException("No SQL connection string found. Expected one of: Concursus, CymBuild, DefaultConnection, ConnectionString.");

        return cs;
    }

    private async Task<SqlConnection> OpenSqlAsync(CancellationToken ct)
    {
        var cn = new SqlConnection(ResolveSqlConnectionString());
        await cn.OpenAsync(ct);
        return cn;
    }
    // // Call the method to upload the file await
    // sharePoint.UploadFileToSharePoint(request.StorageUrl, request.FileName, fileData);
    private RepeatedField<DataPill> GenerateDataPills(List<EF.Types.DataPill> dataPills)
    {
        //foreach EF.Types.DataPill in dataPills, map each field to a new Core.DataPill and return a List of RepeatedField<Core.DataPill>
        RepeatedField<DataPill> result = new();

        foreach (var dataPill in dataPills) result.Add(Converters.ConvertEfDataPillToCoreDataPill(dataPill));

        return result;
    }

    #endregion Private Methods
}
