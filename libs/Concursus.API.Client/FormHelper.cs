using Concursus.API.Client.Classes;
using Concursus.API.Client.Models;
using Concursus.API.Client.Models.Finance;
using Concursus.API.Client.Models.Monitoring;
using Concursus.API.Core;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Monitoring;

using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Components;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using static Concursus.API.Core.Core;

namespace Concursus.API.Client;

public partial class FormHelper
{
    #region Private Fields

    private readonly Core.Core.CoreClient _coreClient;
    private readonly Sage200Microservice.API.Protos.Invoice.InvoiceService.InvoiceServiceClient _sageClient;
    private readonly string _entityTypeGuid;
    private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1, 1);

    #endregion Private Fields

    #region Public Constructors

    public FormHelper(Core.Core.CoreClient coreClient, Sage200Microservice.API.Protos.Invoice.InvoiceService.InvoiceServiceClient sageClient, string entityTypeGuid, UserService userService)
    {
        this._coreClient = coreClient;
        this._sageClient = sageClient;
        this._entityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityTypeGuid).ToString();
        FormControls = new List<FormControl>();
        EntityType = new EntityType();
        UserService = userService;
    }

    #endregion Public Constructors

    #region Public Properties

    public EntityType EntityType { get; set; }
    public List<FormControl> FormControls { get; set; }

    [Parameter] public EventCallback<(string, string, bool)> FormLoadmapPre { get; set; }

    public UserService UserService { get; set; }


    public enum InvoiceProcessingModeUi : byte
    {
        Automated = 0,
        Manual = 1,
        Paused = 2
    }

    #endregion Public Properties

    #region Public Methods

    public async Task<TransactionSageSubmissionRequeueClientResult> TransactionSageSubmissionRequeueAsync(
    IEnumerable<Guid> transactionGuids,
    CancellationToken cancellationToken = default)
    {
        if (transactionGuids is null)
        {
            throw new ArgumentNullException(nameof(transactionGuids));
        }

        var distinctGuids = transactionGuids
            .Where(x => x != Guid.Empty)
            .Distinct()
            .ToList();

        if (distinctGuids.Count == 0)
        {
            throw new ArgumentException("At least one valid transaction guid must be supplied.", nameof(transactionGuids));
        }

        var request = new TransactionSageSubmissionRequeueRequest();
        request.TransactionGuids.AddRange(distinctGuids.Select(x => x.ToString()));

        var reply = await _coreClient.TransactionSageSubmissionRequeueAsync(
            request,
            cancellationToken: cancellationToken);

        var result = new TransactionSageSubmissionRequeueClientResult
        {
            RequeuedTransactionCount = reply.RequeuedTransactionCount,
            ResetOutboxRowCount = reply.ResetOutboxRowCount,
            ResetStatusRowCount = reply.ResetStatusRowCount,
            Message = reply.Message ?? string.Empty
        };

        foreach (var item in reply.Items)
        {
            result.Items.Add(new TransactionSageSubmissionRequeueClientResultItem
            {
                TransactionId = item.TransactionId,
                TransactionGuid = Guid.TryParse(item.TransactionGuid, out var parsedGuid) ? parsedGuid : Guid.Empty,
                ResetStatusRow = item.ResetStatusRow,
                ResetOutboxRows = item.ResetOutboxRows
            });
        }

        return result;
    }

    public async Task<List<SageInboundDiagnosticsRowModel>> SageInboundDiagnosticsGetAsync(SageInboundDiagnosticsGetRequestModel request)
    {
        ArgumentNullException.ThrowIfNull(request);

        var grpcRequest = new SageInboundDiagnosticsGetRequest
        {
            StatusCode = request.StatusCode ?? string.Empty,
            SageAccountReference = request.SageAccountReference ?? string.Empty,
            SageDocumentNo = request.SageDocumentNo ?? string.Empty,
            IncludeOnlyRetryableFailures = request.OnlyRetryableFailures ?? false,
            IncludeOnlyRetryableFailuresSpecified = request.OnlyRetryableFailures.HasValue,
            InvoiceRequestId = request.InvoiceRequestId ?? 0,
            InvoiceRequestIdSpecified = request.InvoiceRequestId.HasValue,
            TransactionId = request.TransactionId ?? 0,
            TransactionIdSpecified = request.TransactionId.HasValue,
            JobId = request.JobId ?? 0,
            JobIdSpecified = request.JobId.HasValue
        };

        var reply = await _coreClient.SageInboundDiagnosticsGetAsync(grpcRequest);
        var result = new List<SageInboundDiagnosticsRowModel>(reply.Rows.Count);

        foreach (var row in reply.Rows)
        {
            result.Add(new SageInboundDiagnosticsRowModel
            {
                Id = row.Id,
                Guid = Guid.TryParse(row.Guid, out var rowGuid) ? rowGuid : Guid.Empty,
                CymBuildEntityTypeId = row.CymBuildEntityTypeId,
                CymBuildDocumentGuid = Guid.TryParse(row.CymBuildDocumentGuid, out var documentGuid) ? documentGuid : Guid.Empty,
                CymBuildDocumentId = row.CymBuildDocumentId,
                InvoiceRequestId = row.InvoiceRequestId,
                TransactionId = row.TransactionId,
                JobId = row.JobId,
                SageDataset = row.SageDataset,
                SageAccountReference = row.SageAccountReference,
                SageDocumentNo = row.SageDocumentNo,
                LastOperationName = row.LastOperationName,
                StatusCode = row.StatusCode,
                IsInProgress = row.IsInProgress,
                InProgressClaimedOnUtc = FromTimestamp(row.InProgressClaimedOnUtc),
                LastSucceededOnUtc = FromTimestamp(row.LastSucceededOnUtc),
                LastFailedOnUtc = FromTimestamp(row.LastFailedOnUtc),
                LastError = row.LastError,
                LastErrorIsRetryable = row.LastErrorIsRetryableSpecified ? row.LastErrorIsRetryable : null,
                LastSourceWatermarkUtc = FromTimestamp(row.LastSourceWatermarkUtc),
                UpdatedDateTimeUtc = FromTimestamp(row.UpdatedDateTimeUtc) ?? DateTime.UtcNow,
                LastAttemptedOnUtc = FromTimestamp(row.LastAttemptedOnUtc),
                LastCompletedOnUtc = FromTimestamp(row.LastCompletedOnUtc),
                LastAttemptIsSuccess = row.LastAttemptIsSuccessSpecified ? row.LastAttemptIsSuccess : null,
                LastAttemptErrorMessage = row.LastAttemptErrorMessage,
                LastAttemptIsRetryableFailure = row.LastAttemptIsRetryableFailureSpecified ? row.LastAttemptIsRetryableFailure : null,
                LastAttemptResponseStatus = row.LastAttemptResponseStatus,
                LastAttemptResponseDetail = row.LastAttemptResponseDetail,
                CanRequeue = row.CanRequeue,
                CanForceRequeue = row.CanForceRequeue
            });
        }

        return result;
    }

    public async Task<DocumentsCreateEmailDraftResponse> DocumentsCreateEmailDraftAsync(
    string subject,
    string body,
    bool isHtmlBody,
    IEnumerable<string>? toRecipients,
    IEnumerable<string>? ccRecipients,
    IEnumerable<string>? bccRecipients,
    IEnumerable<(string DriveId, string ItemId, string FileName)> attachments,
    string recordGuid,
    int entityTypeId,
    string recordNumber,
    string recordDescription,
    string recordLocation,
    CancellationToken cancellationToken = default)
    {
        var request = new DocumentsCreateEmailDraftRequest
        {
            Subject = subject ?? string.Empty,
            Body = body ?? string.Empty,
            IsHtmlBody = isHtmlBody,
            RecordGuid = recordGuid ?? string.Empty,
            EntityTypeId = entityTypeId,
            RecordNumber = recordNumber ?? string.Empty,
            RecordDescription = recordDescription ?? string.Empty,
            RecordLocation = recordLocation ?? string.Empty
        };

        if (toRecipients != null)
        {
            request.ToRecipients.AddRange(toRecipients.Where(x => !string.IsNullOrWhiteSpace(x)));
        }

        if (ccRecipients != null)
        {
            request.CcRecipients.AddRange(ccRecipients.Where(x => !string.IsNullOrWhiteSpace(x)));
        }

        if (bccRecipients != null)
        {
            request.BccRecipients.AddRange(bccRecipients.Where(x => !string.IsNullOrWhiteSpace(x)));
        }

        if (attachments != null)
        {
            foreach (var attachment in attachments)
            {
                if (string.IsNullOrWhiteSpace(attachment.DriveId) ||
                    string.IsNullOrWhiteSpace(attachment.ItemId))
                {
                    continue;
                }

                request.Attachments.Add(new DocumentsEmailAttachmentRef
                {
                    DriveId = attachment.DriveId,
                    ItemId = attachment.ItemId,
                    FileName = attachment.FileName ?? string.Empty
                });
            }
        }

        return await _coreClient.DocumentsCreateEmailDraftAsync(
            request,
            cancellationToken: cancellationToken);
    }

    public async Task<WaitStatsDashboardResponseModel> GetWaitStatsDashboardAsync(
    WaitStatsDashboardRequestModel request,
    CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        var grpcRequest = new GetWaitStatsDashboardRequest
        {
            TopCount = request.TopCount,
            CpuPressureSignalThresholdPct = (double)request.CpuPressureSignalThresholdPct
        };

        var grpcResponse = await _coreClient.GetWaitStatsDashboardAsync(
            grpcRequest,
            cancellationToken: cancellationToken);

        return new WaitStatsDashboardResponseModel
        {
            Summary = new WaitStatsDashboardSummaryModel
            {
                SnapshotUtc = grpcResponse.Summary.SnapshotUtc.ToDateTime(),
                DatabaseName = grpcResponse.Summary.DatabaseName,
                ServerName = grpcResponse.Summary.ServerName,
                SqlServerStartTime = grpcResponse.Summary.SqlServerStartTime.ToDateTime(),
                SecondsSinceRestart = grpcResponse.Summary.SecondsSinceRestart,
                TotalWaitTimeMs = grpcResponse.Summary.TotalWaitTimeMs,
                TotalWaitTimeSeconds = (decimal)grpcResponse.Summary.TotalWaitTimeSeconds,
                TotalSignalWaitTimeMs = grpcResponse.Summary.TotalSignalWaitTimeMs,
                TotalSignalWaitTimeSeconds = (decimal)grpcResponse.Summary.TotalSignalWaitTimeSeconds,
                TotalResourceWaitTimeMs = grpcResponse.Summary.TotalResourceWaitTimeMs,
                TotalResourceWaitTimeSeconds = (decimal)grpcResponse.Summary.TotalResourceWaitTimeSeconds,
                SignalWaitPct = (decimal)grpcResponse.Summary.SignalWaitPct,
                ResourceWaitPct = (decimal)grpcResponse.Summary.ResourceWaitPct,
                IsCpuPressureHighlighted = grpcResponse.Summary.IsCpuPressureHighlighted,
                CpuPressureMessage = grpcResponse.Summary.CpuPressureMessage
            },
            Categories = grpcResponse.Categories.Select(x => new WaitCategoryDistributionModel
            {
                WaitCategory = x.WaitCategory,
                WaitTimeMs = x.WaitTimeMs,
                WaitTimeSeconds = (decimal)x.WaitTimeSeconds,
                SignalWaitTimeMs = x.SignalWaitTimeMs,
                ResourceWaitTimeMs = x.ResourceWaitTimeMs,
                WaitingTasksCount = x.WaitingTasksCount,
                PctOfTotalWaitTime = (decimal)x.PctOfTotalWaitTime
            }).ToList(),
            TopWaits = grpcResponse.TopWaits.Select(x => new TopWaitTypeModel
            {
                WaitType = x.WaitType,
                WaitCategory = x.WaitCategory,
                WaitingTasksCount = x.WaitingTasksCount,
                WaitTimeMs = x.WaitTimeMs,
                WaitTimeSeconds = (decimal)x.WaitTimeSeconds,
                SignalWaitTimeMs = x.SignalWaitTimeMs,
                SignalWaitSeconds = (decimal)x.SignalWaitSeconds,
                ResourceWaitTimeMs = x.ResourceWaitTimeMs,
                ResourceWaitSeconds = (decimal)x.ResourceWaitSeconds,
                MaxWaitTimeMs = x.MaxWaitTimeMs,
                AvgWaitMsPerTask = (decimal)x.AvgWaitMsPerTask,
                PctOfTotalWaitTime = (decimal)x.PctOfTotalWaitTime,
                PctSignalWithinWait = (decimal)x.PctSignalWithinWait
            }).ToList(),
            ActiveWaits = grpcResponse.ActiveWaits.Select(x => new ActiveWaitModel
            {
                SnapshotUtc = x.SnapshotUtc.ToDateTime(),
                SessionId = x.SessionId,
                RequestId = x.RequestId,
                Status = x.Status,
                Command = x.Command,
                WaitType = string.IsNullOrWhiteSpace(x.WaitType) ? null : x.WaitType,
                CurrentWaitMs = x.CurrentWaitMs,
                LastWaitType = string.IsNullOrWhiteSpace(x.LastWaitType) ? null : x.LastWaitType,
                WaitResource = string.IsNullOrWhiteSpace(x.WaitResource) ? null : x.WaitResource,
                BlockingSessionId = x.HasBlockingSessionId ? x.BlockingSessionId : null,
                CpuTimeMs = x.CpuTimeMs,
                TotalElapsedTimeMs = x.TotalElapsedTimeMs,
                Reads = x.Reads,
                Writes = x.Writes,
                LogicalReads = x.LogicalReads,
                GrantedQueryMemory = x.GrantedQueryMemory,
                Dop = x.HasDop ? x.Dop : null,
                ParallelWorkerCount = x.HasParallelWorkerCount ? x.ParallelWorkerCount : null,
                DatabaseName = x.DatabaseName,
                HostName = string.IsNullOrWhiteSpace(x.HostName) ? null : x.HostName,
                ProgramName = string.IsNullOrWhiteSpace(x.ProgramName) ? null : x.ProgramName,
                LoginName = string.IsNullOrWhiteSpace(x.LoginName) ? null : x.LoginName,
                RunningStatement = string.IsNullOrWhiteSpace(x.RunningStatement) ? null : x.RunningStatement,
                BatchText = string.IsNullOrWhiteSpace(x.BatchText) ? null : x.BatchText
            }).ToList(),
            SignalResourceSummary = new SignalResourceWaitSummaryModel
            {
                TotalWaitTimeMs = grpcResponse.SignalResourceSummary.TotalWaitTimeMs,
                SignalWaitTimeMs = grpcResponse.SignalResourceSummary.SignalWaitTimeMs,
                ResourceWaitTimeMs = grpcResponse.SignalResourceSummary.ResourceWaitTimeMs,
                SignalWaitPct = (decimal)grpcResponse.SignalResourceSummary.SignalWaitPct,
                ResourceWaitPct = (decimal)grpcResponse.SignalResourceSummary.ResourceWaitPct,
                SignalWaitAssessment = grpcResponse.SignalResourceSummary.SignalWaitAssessment
            },
            Recommendations = grpcResponse.Recommendations.Select(x => new WaitRecommendationModel
            {
                Priority = x.Priority,
                Pattern = x.Pattern,
                Recommendation = x.Recommendation,
                SupportingMetric = x.SupportingMetric
            }).ToList()
        };
    }

    public async Task<CymBuildSchemaDashboardResponseModel> GetCymBuildSchemaDashboardAsync(
    CancellationToken cancellationToken = default)
    {
        var grpcResponse = await _coreClient.GetCymBuildSchemaDashboardAsync(
            new GetCymBuildSchemaDashboardRequest(),
            cancellationToken: cancellationToken);

        return new CymBuildSchemaDashboardResponseModel
        {
            Summary = new CymBuildSchemaSummaryModel
            {
                SnapshotUtc = grpcResponse.Summary.SnapshotUtc.ToDateTime(),
                SchemasMonitored = grpcResponse.Summary.SchemasMonitored,
                TotalObjectsMonitored = grpcResponse.Summary.TotalObjectsMonitored,
                TableCount = grpcResponse.Summary.TableCount,
                ViewCount = grpcResponse.Summary.ViewCount,
                ProcedureCount = grpcResponse.Summary.ProcedureCount,
                FunctionCount = grpcResponse.Summary.FunctionCount,
                NonSchemaBoundObjectCount = grpcResponse.Summary.NonSchemaBoundObjectCount,
                LargestTableName = grpcResponse.Summary.LargestTableName,
                LargestTableRowCount = grpcResponse.Summary.LargestTableRowCount,
                LargestTableReservedMB = (decimal)grpcResponse.Summary.LargestTableReservedMb
            },
            ObjectCounts = grpcResponse.ObjectCounts.Select(x => new CymBuildSchemaObjectCountModel
            {
                SchemaName = x.SchemaName,
                TableCount = x.TableCount,
                ViewCount = x.ViewCount,
                ProcedureCount = x.ProcedureCount,
                FunctionCount = x.FunctionCount,
                TotalObjectCount = x.TotalObjectCount
            }).ToList(),
            IntegrityChecks = grpcResponse.IntegrityChecks.Select(x => new CymBuildSchemaIntegrityCheckModel
            {
                CheckName = x.CheckName,
                IsOk = x.IsOk,
                StatusText = x.StatusText,
                Detail = x.Detail
            }).ToList(),
            LargestTables = grpcResponse.LargestTables.Select(x => new CymBuildSchemaLargestTableModel
            {
                SchemaName = x.SchemaName,
                TableName = x.TableName,
                RowCount = x.RowCount,
                ReservedMB = (decimal)x.ReservedMb,
                UsedMB = (decimal)x.UsedMb,
                DataMB = (decimal)x.DataMb,
                IndexMB = (decimal)x.IndexMb
            }).ToList(),
            SchemaBoundObjects = grpcResponse.SchemaBoundObjects.Select(x => new CymBuildSchemaBoundObjectModel
            {
                SchemaName = x.SchemaName,
                ObjectName = x.ObjectName,
                ObjectType = x.ObjectType,
                ObjectTypeDesc = x.ObjectTypeDesc,
                IsSchemaBound = x.IsSchemaBound,
                StatusText = x.StatusText
            }).ToList()
        };
    }
    public async Task<List<string>> GetInvoiceRequestItems(string InvoiceReqGuid, CancellationToken ct = default)
    {

        var req = new GetInvoiceRequestItemsByGuidReq() { InvoiceReqGuid = InvoiceReqGuid, UserId = UserService.UserId };

        var resp = await _coreClient.GetInvoiceRequestItemsByGuidAsync(req);

        return resp.Guid.ToList();

    }

    public async Task<bool> DeleteInvoiceRequestByGuid(string InvoiceReqGuid, CancellationToken ct = default)
    {
        var req = new DeleteInvoiceRequestReq() { Guid = InvoiceReqGuid };

        var resp = await _coreClient.DeleteInvoiceRequestAsync(req);

        if (resp.ErrorReturned == "")
        {
            return true;
        }

        return false;
    }


    public async Task<Guid> JobInvoiceScheduleGuidGetAsync(Guid jobGuid, CancellationToken ct = default)
    {
        var resp = await _coreClient.JobInvoiceSchedulesGetAsync(
            new JobInvoiceSchedulesGetRequest
            {
                UserId = UserService.UserId,
                ParentGuid = jobGuid.ToString()
            },
            cancellationToken: ct);

        // Expected: 1 schedule per job
        var first = resp.Schedules.FirstOrDefault();
        return (first is null || !Guid.TryParse(first.Guid, out var g)) ? Guid.Empty : g;
    }
    public async Task<InvoiceProcessingModeUi> JobInvoiceProcessingModeGetAsync(Guid jobGuid, CancellationToken ct = default)
    {
        var resp = await _coreClient.JobInvoiceProcessingModeGetAsync(
            new JobInvoiceProcessingModeGetRequest { JobGuid = jobGuid.ToString() },
            cancellationToken: ct);

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return (InvoiceProcessingModeUi)resp.Mode;
    }

    public async Task<(InvoiceProcessingModeUi OldMode, InvoiceProcessingModeUi NewMode)> JobInvoiceProcessingModeSetAsync(
        Guid jobGuid,
        InvoiceProcessingModeUi newMode,
        string reason,
        CancellationToken ct = default)
    {
        var userGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(UserService.Guid).ToString();

        var resp = await _coreClient.JobInvoiceProcessingModeSetAsync(
            new JobInvoiceProcessingModeSetRequest
            {
                JobGuid = jobGuid.ToString(),
                NewMode = (InvoiceProcessingMode)newMode,
                ChangedByUserGuid = userGuid,
                Reason = reason ?? "",
                Source = "JobDetail"
            },
            cancellationToken: ct);

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return ((InvoiceProcessingModeUi)resp.OldMode, (InvoiceProcessingModeUi)resp.NewMode);
    }

    public async Task<int> JobInvoicePendingTriggerCountGetAsync(Guid jobGuid, CancellationToken ct = default)
    {
        var resp = await _coreClient.JobInvoicePendingTriggerCountGetAsync(
            new JobInvoicePendingTriggerCountGetRequest { JobGuid = jobGuid.ToString() },
            cancellationToken: ct);

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return resp.PendingCount;
    }

    public async Task JobInvoiceGenerateFromPendingTriggersAsync(Guid jobGuid, string notes, CancellationToken ct = default)
    {
        var userGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(UserService.Guid).ToString();

        await _coreClient.JobInvoiceGenerateFromPendingTriggersAsync(
            new JobInvoiceGenerateFromPendingTriggersRequest
            {
                JobGuid = jobGuid.ToString(),
                RequesterUserGuid = userGuid,
                Notes = notes ?? ""
            },
            cancellationToken: ct);
    }
    /// <summary>
    /// Generic approve/reject decision for AUTHORISATION queue items (Quotes/Enquiries/etc).
    /// Server enforces: record must still be awaiting authorisation and user must have CanActionForUser=1.
    /// </summary>
    public async Task<AuthorisationDecisionResponse> AuthorisationDecisionAsync(
        Guid recordGuid,
        string entityTypeName,
        bool approve,
        string? comment,
        CancellationToken ct = default)
    {
        var req = new AuthorisationDecisionRequest
        {
            UserId = UserService.UserId,
            RecordGuid = recordGuid.ToString(),
            EntityTypeName = entityTypeName ?? "",
            Approve = approve,
            Comment = comment ?? string.Empty
        };

        return await _coreClient.AuthorisationDecisionAsync(req, cancellationToken: ct);
    }

    public async Task<DocumentsLocation> DocumentsResolveAsync(
    DataObject dataObject,
    int entityTypeId,
    string entityQueryGuid,
    CancellationToken ct = default)
    {
        if (dataObject is null)
            throw new ArgumentNullException(nameof(dataObject));

        return await DocumentsResolveAsync(
            dataObject.Guid,
            entityTypeId,
            entityQueryGuid,
            dataObject.SharePointUrl,
            ct);
    }

    public async Task<DocumentsListResponse> DocumentsListAsync(string driveId, string folderId, int pageSize = 100, string? pageToken = null, string? searchText = null)
    {
        var resp = await _coreClient.DocumentsListAsync(new DocumentsListRequest
        {
            DriveId = driveId,
            FolderId = folderId,
            PageSize = pageSize,
            PageToken = pageToken ?? "",
            SearchText = searchText ?? ""
        });

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return resp;
    }

    public string BuildDocumentsDownloadUrl(IConfiguration cfg, string driveId, string itemId)
    {
        var baseUrl = cfg["ShoreAPI:Url"]?.TrimEnd('/') ?? throw new InvalidOperationException("Missing ShoreAPI:Url");
        return $"{baseUrl}/api/documents/download?driveId={Uri.EscapeDataString(driveId)}&itemId={Uri.EscapeDataString(itemId)}";
    }

    public async Task<(string fileName, string contentType)> DocumentsDownloadFileStreamAsync(
     string driveId,
     string itemId,
     Func<byte[], Task> onChunkAsync,
     int chunkSizeBytes = 262144,
     CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(driveId))
            throw new ArgumentException("DriveId is required.", nameof(driveId));

        if (string.IsNullOrWhiteSpace(itemId))
            throw new ArgumentException("ItemId is required.", nameof(itemId));

        if (onChunkAsync is null)
            throw new ArgumentNullException(nameof(onChunkAsync));

        var call = _coreClient.DocumentsDownloadFileStream(
            new DocumentsDownloadFileStreamRequest
            {
                DriveId = driveId,
                ItemId = itemId,
                ChunkSizeBytes = chunkSizeBytes
            },
            cancellationToken: cancellationToken);

        string fileName = "download";
        string contentType = "application/octet-stream";
        var firstMessageSeen = false;

        await foreach (var message in call.ResponseStream.ReadAllAsync(cancellationToken))
        {
            if (!string.IsNullOrWhiteSpace(message.ErrorReturned))
                throw new Exception(message.ErrorReturned);

            if (!firstMessageSeen)
            {
                if (!string.IsNullOrWhiteSpace(message.FileName))
                    fileName = message.FileName;

                if (!string.IsNullOrWhiteSpace(message.ContentType))
                    contentType = message.ContentType;

                firstMessageSeen = true;
            }

            if (message.Data != null && message.Data.Length > 0)
            {
                await onChunkAsync(message.Data.ToByteArray());
            }
        }

        return (fileName, contentType);
    }

    public async Task<DocumentsListItem> DocumentsCreateFolderAsync(string siteId, string driveId, string parentFolderId, string folderName, string conflictBehavior = "rename")
    {
        var resp = await _coreClient.DocumentsCreateFolderAsync(new DocumentsCreateFolderRequest
        {
            SiteId = siteId ?? string.Empty,
            DriveId = driveId ?? string.Empty,
            ParentFolderId = parentFolderId ?? string.Empty,
            FolderName = folderName ?? string.Empty,
            ConflictBehavior = conflictBehavior ?? "rename"
        });

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return resp.Folder;
    }

    public async Task<DocumentsListItem> DocumentsUploadAsync(string siteId, string driveId, string folderId, string fileName, byte[] data, bool overwrite = true)
    {
        var resp = await _coreClient.DocumentsUploadAsync(new DocumentsUploadRequest
        {
            SiteId = siteId ?? string.Empty,
            DriveId = driveId ?? string.Empty,
            FolderId = folderId ?? string.Empty,
            FileName = fileName ?? string.Empty,
            Data = Google.Protobuf.ByteString.CopyFrom(data ?? Array.Empty<byte>()),
            Overwrite = overwrite
        });

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return resp.Item;
    }

    public async Task DocumentsDeleteAsync(string siteId, string driveId, string itemId)
    {
        var resp = await _coreClient.DocumentsDeleteAsync(new DocumentsDeleteRequest
        {
            SiteId = siteId ?? string.Empty,
            DriveId = driveId ?? string.Empty,
            ItemId = itemId ?? string.Empty
        });

        if (!resp.Success || !string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(string.IsNullOrWhiteSpace(resp.ErrorReturned) ? "Delete failed." : resp.ErrorReturned);
    }


    public async Task<List<PublicHoliday>> GetHolidaysAsync()
    {
        var resp = await _coreClient.GetHolidaysAsync(new HolidayReq());

        return resp.Holidays.ToList();
    }

    public async Task<List<NonActivityEvents>> GetNonActivityEvents(int UserId, DateTime StartDate, DateTime EndDate)
    {
        var resp = await _coreClient.GetNonActivityEventsAsync(new GetNonActivityEventsReq { UserId = UserId, StartDate = Timestamp.FromDateTime(DateTime.SpecifyKind(StartDate, DateTimeKind.Utc)), EndDate = Timestamp.FromDateTime(DateTime.SpecifyKind(EndDate, DateTimeKind.Utc)) });

        return resp.NonActivityEvents.ToList();
    }

    public async Task<List<ScheduledActivity>> GetScheduledActivities(int UserId, DateTime StartDate, DateTime EndDate)
    {
        var resp = await _coreClient.GetScheduledActivitiesAsync(new ScheduledActivitiesReq { UserId = UserId, StartDate = Timestamp.FromDateTime(DateTime.SpecifyKind(StartDate, DateTimeKind.Utc)), EndDate = Timestamp.FromDateTime(DateTime.SpecifyKind(EndDate, DateTimeKind.Utc)) });

        return resp.ScheduledActivities.ToList();
    }

    public async Task<int> GetOrganisationalUnitForUser(int UserId)
    {
        var resp = await _coreClient.GetOrganisationalUnitForUserAsync(new OrganisationalUnitForUserReq { UserId = UserId });
        return resp.OrganisationalUnitIDForUser.OrganisationUnitId;
    }

    public async Task<List<TeamMember>> GetTeamMembersAsync(int unitId)
    {
        var response = await _coreClient.GetTeamMembersAsync(new TeamRequest { OrganisationalUnitId = unitId });
        return response.TeamMembers.Select(tm => new TeamMember
        {
            Id = tm.Id,
            Name = tm.Name,
            Color = tm.Color
        }).ToList();
    }

    public async Task LogUsageAsync(Guid userId, string featureName)
    {
        try
        {
            var request = new UsageRequest
            {
                UserId = userId.ToString(),
                FeatureName = featureName
            };

            await _coreClient.LogUsageAsync(request);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to log usage: {ex.Message}");
        }
    }

    public async Task<List<UsageData>> GetUsageReportAsync(int days)
    {
        try
        {
            var request = new UsageReportRequest { Days = days };
            var response = await _coreClient.GetUsageReportAsync(request);
            return response.UsageData.ToList();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to fetch usage report: {ex.Message}");
            return new List<UsageData>();
        }
    }

    /// <summary>
    /// Submits an approve/reject decision for a job closure request.
    /// Server enforces: latest status must be Closure Request.
    /// </summary>
    public async Task<JobClosureDecisionResponse> JobClosureDecisionAsync(
        Guid jobGuid,
        bool approve,
        string? comment,
        CancellationToken ct = default)
    {
        var req = new JobClosureDecisionRequest
        {
            UserId = UserService.UserId,
            JobGuid = jobGuid.ToString(),
            Decision = approve
                ? JobClosureDecisionType.JobClosureDecisionApprove
                : JobClosureDecisionType.JobClosureDecisionReject,
            Comment = comment ?? string.Empty
        };

        return await _coreClient.JobClosureDecisionAsync(req, cancellationToken: ct);
    }
    public async Task<DataObjectDeleteResponse> DataObjectDeleteAsync(DataObject dataObject, string entityQueryGuid)
    {
        DataObjectDeleteResponse dataObjectDeleteResponse = new DataObjectDeleteResponse();

        dataObjectDeleteResponse = await _coreClient.DataObjectDeleteAsync(new DataObjectDeleteRequest()
        {
            DataObject = dataObject,
            EntityQueryGuid = Guid.Empty.ToString()
        });

        return dataObjectDeleteResponse;
    }

    //CBLD-415: Try to get the SharePoint url without upserting.

    public async Task<GetSharePointURLMessage> GetSharePointUrl(DataObject dataObject)
    {
        try
        {
            var response = await _coreClient.GetSharePointURLAsync(new GetSharePointURLMessageRequest()
            {
                DataObject = dataObject
            });

            return response;
        }
        catch (Exception ex)
        {
            return new GetSharePointURLMessage() { Message = "" };
        }
    }

    public async Task<string> ConvertTiffToPngAsync(byte[] tiffData)
    {
        var request = new ConvertImageRequest
        {
            ImageData = Google.Protobuf.ByteString.CopyFrom(tiffData)
        };

        var response = await _coreClient.ConvertTiffToPngAsync(request);

        // Return the Base64 string of the PNG image
        return response.Base64Png;
    }

    public async Task<SharepointDocumentsGetResponse> GetSharePointDocumentsAsync(MergeDocument mergeDocument, string OutputType = "Word")
    {
        var sharePointDocumentsGetRequest = new SharepointDocumentsGetRequest
        {
            SiteId = mergeDocument.DriveId,
            DocumentId = mergeDocument.DocumentId,
            DocumentGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.Guid).ToString(),
            RecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.RecordGuid).ToString(),
            ParentRecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.ParentRecordGuid).ToString(),
            EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(_entityTypeGuid).ToString(),
            LinkedEntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.LinkedEntityTypeGuid).ToString(),
            FilenameTemplate = mergeDocument.FilenameTemplate,
            AllowExcelOutputOnly = mergeDocument.AllowExcelOutputOnly,
            AllowPDFOnly = mergeDocument.AllowPDFOnly,
            MergeDocument = mergeDocument, //Pass the entire MergeDocument no need to get getting it later
            OutputType = OutputType
        };

        var response = await _coreClient.SharepointDocumentsGetAsync(sharePointDocumentsGetRequest);

        return response;
    }

    public async Task<List<DriveListItem>> GetSharePointSitesAsync(string sharePointSiteGuid, string TemplateFolderName)
    {
        List<DriveListItem> driveListItems = new();
        //try
        //{
        var sharePointDocumentDetailsGetRequest = new SharePointDocumentDetailsGetRequest()
        {
            SharePointSiteID = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(sharePointSiteGuid).ToString(),
            SharePointTemplateFolderName = TemplateFolderName
        };
        var sharePointDocumentDetailsGetResponse =
            await _coreClient.SharePointDocumentDetailsGetAsync(sharePointDocumentDetailsGetRequest);

        if (sharePointDocumentDetailsGetResponse.DriveListItem != null) driveListItems.AddRange(sharePointDocumentDetailsGetResponse.DriveListItem);
        //}
        //catch (Exception ex)
        //{
        //    Console.WriteLine("ERRORRAISED! \"PageMethod\", \"FormHelper/GetSharePointSitesAsync()\" \r\n" + ex.Message);
        //}
        return driveListItems;
    }

    /// <summary>
    /// Load the definition metadata from the specified Entity Type Guid.
    /// </summary>
    /// <returns> </returns>
    public async Task LoadMetaDataAsync(bool isInformationPage = false)
    {
        // Get the entity metadata
        var entityTypeGetResponse = await _coreClient.EntityTypeGetAsync(new EntityTypeGetRequest
        {
            Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(_entityTypeGuid).ToString(),
            IsInformationView = isInformationPage
        });

        EntityType = entityTypeGetResponse.EntityType;
    }

    //CBLD-260
    public async Task<EntityType> GetEntityType()
    {
        await LoadMetaDataAsync(false);
        return EntityType;
    }

    public async Task<ExecuteMenuItemResponse> MenuItemPostAsync(string entityQueryGuid, DataObject dataObject)
    {
        ExecuteMenuItemResponse executeMenuItemResponse = new ExecuteMenuItemResponse();

        executeMenuItemResponse = await _coreClient.ExecuteMenuItemPostAsync(new ExecuteMenuItemRequest()
        {
            DataObject = dataObject,
            EntityQueryGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityQueryGuid).ToString()
        });

        return executeMenuItemResponse;
    }

    //CBLD-265
    public async Task<ExecuteGridMenuItemResponse> GridMenuItemPostAsync(string Statement, string Guid)
    {
        ExecuteGridMenuItemResponse executeGridMenuItem = new ExecuteGridMenuItemResponse();

        executeGridMenuItem = await _coreClient.ExecuteGridMenuActionAsync(new ExecuteGridMenuItemRequest()
        {
            Statement = Statement,
            Guid = Guid
        });

        return executeGridMenuItem;
    }

    public async Task<DataObject> ReadDataObjectAsync(string recordGuid, DataObjectReference dataObjectReference, bool isInformationView = false, string ChildEntityGuid = "", ModalService? modalService = null, bool IsBulkUpdate = false, bool UpdateSharePoint = false, Dictionary<string, Any>? transientVirtualProperties = null)
    {
        if (recordGuid == Guid.Empty.ToString())
        {
            DataObject dataObject = new()
            {
                Guid = Guid.NewGuid().ToString(),
                RowStatus = 0,
                //EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObjectReference.EntityTypeGuid.ToString()).ToString()
                EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(_entityTypeGuid).ToString()
            };

            foreach (var ep in EntityType.EntityProperties)
            {
                ep.RowStatus = 0;
                EntityPropertyDefaultResponse? getValue = null;
                Core.DataProperty newProperty = new() { EntityPropertyGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(ep.Guid).ToString() };

                try
                {
                    if (ep.Name == "QuoteId")
                    {
                        //ep.SqlDefaultValueStatement = "-1";
                    }

                    if (ep.IsVirtual)
                    {
                        if (transientVirtualProperties != null &&
                            transientVirtualProperties.TryGetValue(ep.Name, out var transientValue))
                        {
                            newProperty.Value = transientValue;
                        }
                        else
                        {
                            switch (ep.EntityDataTypeName.ToLower())
                            {
                                case "bit":
                                    newProperty.Value = Any.Pack(new BoolValue { Value = false });
                                    break;
                                case "nvarchar":
                                case "nvarchar(max)":
                                    newProperty.Value = Any.Pack(new StringValue { Value = string.Empty });
                                    break;
                                case "int":
                                case "smallint":
                                case "tinyint":
                                    newProperty.Value = Any.Pack(new Int32Value { Value = 0 });
                                    break;
                                case "bigint":
                                    newProperty.Value = Any.Pack(new Int64Value { Value = 0 });
                                    break;
                                case "double":
                                    newProperty.Value = Any.Pack(new DoubleValue { Value = 0 });
                                    break;
                                case "uniqueidentifier":
                                    newProperty.Value = Any.Pack(new StringValue { Value = Guid.Empty.ToString() });
                                    break;
                                case "date":
                                case "datetime2":
                                    newProperty.Value = Any.Pack(new Empty());
                                    break;
                            }
                        }

                        dataObject.DataProperties.Add(newProperty);
                        continue;
                    }

                    getValue = await _coreClient.EntityPropertyDefaultGetAsync(new EntityPropertyDefaultRequest()
                    { EntityProperty = ep, ParentGuid = dataObjectReference.DataObjectGuid.ToString(), RecordGuid = dataObject.Guid });
                    if (!string.IsNullOrEmpty(getValue.ErrorReturned))
                    {
                        return new DataObject() { ErrorReturned = getValue.ErrorReturned };
                    }
                    if (getValue.DefaultValue != null)
                    {
                        newProperty.Value = getValue.DefaultValue;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine("ERRORRAISED! \"PageMethod\", \"FormHelper/ReadDataObjectAsync()\" \r\n" + ex.Message);
                    //return dataObject;
                }

                if (ep.DropDownListDefinitionGuid != Guid.Empty.ToString())
                {
                    //StringValue guidValue = new()
                    //{
                    //    Value = ep.IsParentRelationship ? ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid).ToString() : Guid.Empty.ToString()
                    //};
                    StringValue guidValue;
                    if (ep.IsParentRelationship) //&& ep.ForeignEntityTypeGuid == dataObjectReference.EntityTypeGuid.ToString())
                    {
                        guidValue = new StringValue()
                        { Value = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObjectReference.DataObjectGuid.ToString()).ToString() };
                    }
                    else
                    {
                        guidValue = new StringValue() { Value = Guid.Empty.ToString() };
                    }
                    newProperty.Value = getValue.DefaultValue ?? Any.Pack(guidValue);
                }
                else
                {
                    if (ep.IsParentRelationship)
                    {
                        StringValue guidValue;
                        if (ep.ForeignEntityTypeGuid == dataObjectReference.EntityTypeGuid.ToString())
                        {
                            guidValue = new StringValue()
                            { Value = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObjectReference.DataObjectGuid.ToString()).ToString() };
                        }
                        else
                        {
                            if (ep.ForeignEntityTypeGuid == Guid.Empty.ToString())
                            {
                                guidValue = new StringValue()
                                { Value = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObjectReference.DataObjectGuid.ToString()).ToString() };
                            }
                            else
                            {
                                guidValue = new StringValue() { Value = Guid.Empty.ToString() };
                            }
                        }

                        newProperty.Value = getValue.DefaultValue ?? Any.Pack(guidValue);
                    }
                    //if (ep.IsParentRelationship)
                    //{
                    //    StringValue guidValue = new()
                    //    {
                    //        Value = ep.IsParentRelationship ? dataObjectReference.DataObjectGuid.ToString() : Guid.Empty.ToString()
                    //    };

                    //    newProperty.Value = getValue.DefaultValue ?? Any.Pack(guidValue);
                    //}
                    else
                    {
                        if (newProperty.Value == null)
                            switch (ep.EntityDataTypeName.ToLower())
                            {
                                case "nvarchar":
                                case "nvarchar(max)":
                                    StringValue stringValue = new() { Value = "" };
                                    newProperty.Value = Any.Pack(stringValue);
                                    break;

                                case "int":
                                case "smallint":
                                case "tinyint":
                                    Int32Value int32Value = new() { Value = 0 };
                                    newProperty.Value = Any.Pack(int32Value);
                                    break;

                                case "bigint":
                                    Int64Value int64Value = new() { Value = 0 };
                                    newProperty.Value = Any.Pack(int64Value);
                                    break;

                                case "double":
                                    DoubleValue doubleValue = new() { Value = 0 };
                                    newProperty.Value = Any.Pack(doubleValue);
                                    break;

                                case "bit":
                                    BoolValue boolValue = new() { Value = false };
                                    newProperty.Value = Any.Pack(boolValue);
                                    break;

                                case "uniqueidentifier":
                                    StringValue guidValue = new() { Value = Guid.Empty.ToString() };
                                    newProperty.Value = Any.Pack(guidValue);
                                    break;

                                case "date":
                                    newProperty.Value = Any.Pack(new Empty());
                                    break;

                                case "datetime2":
                                    newProperty.Value = Any.Pack(new Empty());
                                    break;
                            }
                    }
                }

                dataObject.DataProperties.Add(newProperty);
            }

            var (message, newDataObject) = await UpsertDataObject(dataObject, null, true, IsBulkUpdate);
            if (!string.IsNullOrEmpty(newDataObject.ErrorReturned))
            {
                return new DataObject() { ErrorReturned = newDataObject.ErrorReturned };
            }
            if (!string.IsNullOrEmpty(message)) throw new Exception(message);
            dataObject = newDataObject;
            return dataObject;
        }

        DataObjectGetResponse dataObjectGetResponse = new DataObjectGetResponse();

        transientVirtualProperties ??= new Dictionary<string, Any>(StringComparer.OrdinalIgnoreCase);

        //Read the Old DataObject? Used for Modal Binding to the Parent Record
        if (!string.IsNullOrEmpty(ChildEntityGuid))
        {
            var request = new DataObjectGetRequest()
            {
                Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString(),
                EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(ChildEntityGuid).ToString(),
                ForInformationView = isInformationView
            };

            Console.WriteLine("TransientVirtualProperties count: " + request.TransientVirtualProperties.Count);
            foreach (var kvp in request.TransientVirtualProperties)
            {
                Console.WriteLine("Transient key: " + kvp.Key);
            }

            dataObjectGetResponse = await _coreClient.DataObjectGetAsync(request);
        }
        else
        {
            string entityTypeGuid;

            if (UpdateSharePoint)
            {
                entityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObjectReference.EntityTypeGuid.ToString()).ToString();
            }
            else
            {
                entityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(_entityTypeGuid).ToString();
            }

            var request = new DataObjectGetRequest()
            {
                Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString(),
                EntityTypeGuid = entityTypeGuid,
                ForInformationView = isInformationView
            };

            foreach (var kvp in transientVirtualProperties)
            {
                request.TransientVirtualProperties.Add(kvp.Key, kvp.Value);
            }

            dataObjectGetResponse = await _coreClient.DataObjectGetAsync(request);
        }
        if (!string.IsNullOrEmpty(dataObjectGetResponse.ErrorReturned))
        {
            return new DataObject() { ErrorReturned = dataObjectGetResponse.ErrorReturned };
        }
        _ = Task.Run(async () =>
        {
            await FormLoadMap(recordGuid, dataObjectReference.DataObjectGuid.ToString(), true);

            var modalResults = modalService?.GetLatestModal();

            // If modalResults is null or the EntityTypeGuids do not match, proceed. Otherwise,
            // return immediately.
            if (modalResults != null && modalResults.Value.DataObjectReference.EntityTypeGuid == dataObjectReference.EntityTypeGuid)
            {
                return;
            }

            var label = UserService.UserId != -1 ? dataObjectGetResponse.DataObject.Label : "Unknown";
            var userGuid = UserService.UserId != -1 ? ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(UserService.Guid).ToString() : "Unknown";

            var recentItem = new RecentItem
            {
                DateTime = Timestamp.FromDateTime(DateTime.UtcNow),
                Label = label,
                EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(_entityTypeGuid).ToString(),
                RecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString(),
                UserGuid = userGuid
            };

            await _coreClient.RecentItemsCreateAsync(recentItem);
        });
        return dataObjectGetResponse.DataObject;
    }

    public async Task<SharePointCreateResponse> SharePointCreate(SharePointCreateRequest sharePointCreateRequest)
    {
        SharePointCreateResponse sharePointCreateResponse = new SharePointCreateResponse();
        try
        {
            sharePointCreateResponse = await _coreClient.SharePointCreateAsync(sharePointCreateRequest);
        }
        catch (Exception ex)
        {
            Console.WriteLine("ERRORRAISED! \"PageMethod\", \"FormHelper/SharePointCreate()\" \r\n" + ex.Message);
        }

        return sharePointCreateResponse;
    }

    public async Task<(string, int)> CheckPhotoFilesAtUrl(string sharePointUrl)
    {
        try
        {
            // Make the gRPC call to CoreService to check for photo files
            var response = await _coreClient.CheckPhotoFilesAtUrlAsync(new PhotoFileCheckRequest
            {
                SharePointUrl = sharePointUrl
            });

            // Return the number of photos and any error message
            return (response.ErrorReturned, response.NumberOfPhotos);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error checking for photo files: {ex.Message}");
            return ($"Error: {ex.Message}", 0);
        }
    }



    public async Task<(string, DataObject)> UpsertDataObject(DataObject dataObject, Guid? entityQueryGuid,
        bool validateOnly = true, bool IsBulkUpdate = false, ModalService? modalService = null, DataObject DeltaDataObject = null)
    {
        //try
        //{
        // Below added to stop error Sequence contains no elements when null is passed in.
        if (DeltaDataObject == null) { DeltaDataObject = new(); }
        Console.WriteLine($"Upserting data object. RowVersion {dataObject.RowVersion}");
        var dataObjectUpsertResponse = await _coreClient.DataObjectUpsertAsync(new DataObjectUpsertRequest()
        {
            DataObject = dataObject,
            DeltaDataObject = DeltaDataObject, //OE - CBLD-436.
            ValidateOnly = validateOnly,
            EntityQueryGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityQueryGuid.ToString()).ToString(),
            SkipValidation = IsBulkUpdate
        });
        Console.WriteLine($"finished Upsert New DataObject.RowVersion {dataObjectUpsertResponse.DataObject.RowVersion}");
        if (!string.IsNullOrEmpty(dataObjectUpsertResponse.ErrorReturned))
        {
            return ("Error" + dataObjectUpsertResponse.ErrorReturned, dataObject);
        }
        dataObject = dataObjectUpsertResponse.DataObject;

        PrepareDecodedDataObject(dataObject);

        if (!validateOnly && dataObject.RowStatus == 0)
        {
            _ = Task.Run(async () =>
            {
                // Check to ensure only the Parent record is added to the Recent Items and not child records
                var modalResults = modalService?.GetLatestModal();

                // If modalResults is null or the EntityTypeGuids do not match, proceed. Otherwise,
                // return immediately.
                if (modalResults != null && modalResults.Value.DataObjectReference.EntityTypeGuid == ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject.EntityTypeGuid))
                {
                    return;
                }

                var label = UserService.UserId != -1 ? dataObject?.Label ?? "" : "Unknown";
                var userGuid = UserService.UserId != -1 ? ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(UserService?.Guid).ToString() : Guid.Empty.ToString();

                var recentItem = new RecentItem
                {
                    DateTime = Timestamp.FromDateTime(DateTime.UtcNow),
                    Label = label,
                    RecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject?.Guid).ToString(),
                    EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityQueryGuid?.ToString()).ToString(),
                    UserGuid = userGuid
                };

                await _coreClient.RecentItemsCreateAsync(recentItem);
            });
        }
        Console.WriteLine($"updated data object. RowVersion {dataObject.RowVersion}");
        if (dataObject.ValidationResults.Count > 0)
        {
            var message = string.Join("\r\n", dataObject.ValidationResults.Select(vr => vr.Message));
            return (message, dataObject);
        }
        else { return ("", dataObject); }
        //}
        //catch (Exception ex)
        //{
        //    Console.WriteLine("ERRORRAISED! \"PageMethod\", \"FormHelper/UpsertDataObject()\" \r\n" + ex.Message);
        //    return (ex.Message, dataObject);
        //}
    }

    public static void PrepareDecodedDataObject(DataObject dataObject)
    {
        string jsonData = JsonSerializer.Serialize(dataObject);
        //JObject jsonObject = JObject.Parse(jsonData);

        //// Assuming 'DataProperties' is the name of the property that holds the array
        //JArray dataProperties = (JArray)jsonObject["DataProperties"];

        //foreach (var property in dataProperties)
        //{
        //    JObject value = (JObject)property["Value"];
        //    string base64String = value["Value"].ToString();

        //    try
        //    {
        //        byte[] data = Convert.FromBase64String(base64String); // Decoding from base64
        //        property["DecodedValue"] = Encoding.UTF8.GetString(data); // Assuming it's UTF-8 encoded data
        //    }
        //    catch (FormatException ex)
        //    {
        //        Console.WriteLine($"Invalid Base64 string: {ex.Message}");
        //        // Handle the case where the base64 string is not valid
        //        property["DecodedValue"] = null; // or some default value
        //    }
        //}

        //ProtobufDataDecoder.DecodeDataObject(jsonData);
    }

    //OE: CBLD-408
    public async Task<string> GetWidgetLayout(int UserId)
    {
        try
        {
            // Make the gRPC call to CoreService to check for photo files
            var response = await _coreClient.UserPreferencesGetAsync(new UserPreferencesGetRequest
            {
                UserId = UserId
            });

            // Return the widget Layout
            return response.UserPreferences.WidgetLayout;
        }
        catch (Exception ex)
        {
            //TODO
            return "";
        }
    }

    public async Task<User> UpdateUserSignature(User user)
    {
        try
        {
            var response = await _coreClient.UpdateUserSignatureAsync(new UserInfoUpdateRequest
            {
                User = user
            });

            if (!string.IsNullOrEmpty(response.ErrorReturned))
            {
                Console.WriteLine($"Error Received saving signature. {response.ErrorReturned}");
            }
            user.Signature = response.User.Signature;
            return user;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error updating user signature: {ex.Message}");
            return user;
        }
    }

    public async Task<WidgetLayoutSaveResponse> SaveWidgetLayoutToDb(int userId, string WidgetLayout)
    {
        var response = await _coreClient.SaveWidgetLayoutAsync(new WidgetLayoutPOST { UserId = userId, WidgetLayout = WidgetLayout });

        return response;
    }

    public async Task<AddressLookupSearchResponse> AddressLookupSearchAsync(
    string searchText,
    string context,
    bool forceApi = false,
    CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(searchText))
        {
            return new AddressLookupSearchResponse
            {
                ErrorReturned = "Search text is required."
            };
        }

        return await _coreClient.AddressLookupSearchAsync(
            new AddressLookupSearchRequest
            {
                SearchText = searchText.Trim(),
                Context = string.IsNullOrWhiteSpace(context) ? "GBR" : context.Trim(),
                ForceApi = forceApi
            },
            cancellationToken: ct);
    }

    public async Task<AddressLookupResolveResponse> AddressLookupResolveAsync(
        string id,
        string context,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return new AddressLookupResolveResponse
            {
                ErrorReturned = "Address id is required."
            };
        }

        return await _coreClient.AddressLookupResolveAsync(
            new AddressLookupResolveRequest
            {
                Id = id.Trim(),
                Context = string.IsNullOrWhiteSpace(context) ? "GBR" : context.Trim()
            },
            cancellationToken: ct);
    }

    public async Task<DocumentsNavigationGetResponse> DocumentsNavigationGetAsync(
    int userId,
    string recordGuid,
    int entityTypeId,
    CancellationToken ct = default)
    {
        if (userId <= 0)
            throw new ArgumentException("UserId is required.", nameof(userId));

        if (!Guid.TryParse(recordGuid, out var parsedGuid) || parsedGuid == Guid.Empty)
            throw new ArgumentException("RecordGuid is required and must be a valid GUID.", nameof(recordGuid));

        if (entityTypeId <= 0)
            throw new ArgumentException("EntityTypeId is required.", nameof(entityTypeId));

        var resp = await _coreClient.DocumentsNavigationGetAsync(
            new DocumentsNavigationGetRequest
            {
                UserId = userId,
                RecordGuid = parsedGuid.ToString(),
                EntityTypeId = entityTypeId
            },
            cancellationToken: ct);

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return resp;
    }

    public async Task<DocumentsLocation> DocumentsResolveAsync(
    string recordGuid,
    int entityTypeId,
    string entityQueryGuid,
    string? sharePointUrlHint = null,
    CancellationToken ct = default)
    {
        if (!Guid.TryParse(recordGuid, out var parsedGuid) || parsedGuid == Guid.Empty)
            throw new ArgumentException("RecordGuid is required and must be a valid GUID.", nameof(recordGuid));

        if (entityTypeId <= 0)
            throw new ArgumentException("EntityTypeId is required.", nameof(entityTypeId));

        var resp = await _coreClient.DocumentsResolveAsync(
            new DocumentsResolveRequest
            {
                RecordGuid = parsedGuid.ToString(),
                EntityTypeId = entityTypeId,
                EntityQueryGuid = entityQueryGuid ?? string.Empty,
                SharePointUrlHint = sharePointUrlHint ?? string.Empty
            },
            cancellationToken: ct);

        if (!string.IsNullOrWhiteSpace(resp.ErrorReturned))
            throw new Exception(resp.ErrorReturned);

        return resp.Location;
    }

    public async Task<SageHealthGetResponse> SageHealthGetAsync(CancellationToken ct = default)
    {
        return await _coreClient.SageHealthGetAsync(new SageHealthGetRequest(), cancellationToken: ct);
    }

    public async Task<SageFetchSalesOrdersResponse> SageFetchSalesOrdersAsync(
        string dataset,
        string orderId,
        string? filterOperator = null,
        bool force = false,
        CancellationToken ct = default)
    {
        return await _coreClient.SageFetchSalesOrdersAsync(
            new SageFetchSalesOrdersRequest
            {
                Dataset = dataset ?? "group",
                OrderId = orderId ?? string.Empty,
                FilterOperator = filterOperator ?? string.Empty,
                Force = force
            },
            cancellationToken: ct);
    }

    public async Task<SageFetchCustomerTransactionsResponse> SageFetchCustomerTransactionsAsync(
        string dataset,
        string? accountReference = null,
        string? documentNo = null,
        int? sysTraderTranType = null,
        bool force = false,
        CancellationToken ct = default)
    {
        return await _coreClient.SageFetchCustomerTransactionsAsync(
            new SageFetchCustomerTransactionsRequest
            {
                Dataset = dataset ?? "group",
                AccountReference = accountReference ?? string.Empty,
                DocumentNo = documentNo ?? string.Empty,
                HasSysTraderTranType = sysTraderTranType.HasValue,
                SysTraderTranType = sysTraderTranType.GetValueOrDefault(),
                Force = force
            },
            cancellationToken: ct);
    }

    public async Task<Core.SageCreateSalesOrderResponse> SageCreateSalesOrderAsync(
        string dataset,
        string accountReference,
        string? customerOrderNo,
        string? documentDate,
        bool? useInvoiceAddress,
        bool? overrideOnHold,
        bool? allowCreditLimitException,
        string? analysisCode01Value,
        string? analysisCode02Value,
        string? analysisCode03Value,
        IEnumerable<SageCreateSalesOrderLine>? lines,
        CancellationToken ct = default)
    {
        var request = new Core.SageCreateSalesOrderRequest
        {
            Dataset = dataset ?? "group",
            AccountReference = accountReference ?? string.Empty,
            CustomerOrderNo = customerOrderNo ?? string.Empty,
            DocumentDate = documentDate ?? string.Empty,
            HasUseInvoiceAddress = useInvoiceAddress.HasValue,
            UseInvoiceAddress = useInvoiceAddress.GetValueOrDefault(),
            HasOverrideOnHold = overrideOnHold.HasValue,
            OverrideOnHold = overrideOnHold.GetValueOrDefault(),
            HasAllowCreditLimitException = allowCreditLimitException.HasValue,
            AllowCreditLimitException = allowCreditLimitException.GetValueOrDefault(),
            AnalysisCode01Value = analysisCode01Value ?? string.Empty,
            AnalysisCode02Value = analysisCode02Value ?? string.Empty,
            AnalysisCode03Value = analysisCode03Value ?? string.Empty
        };

        if (lines != null)
            request.Lines.AddRange(lines);

        return await _coreClient.SageCreateSalesOrderAsync(request, cancellationToken: ct);
    }

    public async Task<IReadOnlyList<SageSalesOrder>> SageFetchSalesOrdersItemsAsync(
    string dataset,
    string orderId,
    string? filterOperator = null,
    bool force = false,
    CancellationToken ct = default)
    {
        var response = await SageFetchSalesOrdersAsync(
            dataset,
            orderId,
            filterOperator,
            force,
            ct);

        if (!string.IsNullOrWhiteSpace(response.ErrorReturned))
            throw new Exception(response.ErrorReturned);

        return response.SalesOrders;
    }

    public async Task<IReadOnlyList<SageCustomerTransaction>> SageFetchCustomerTransactionItemsAsync(
        string dataset,
        string? accountReference = null,
        string? documentNo = null,
        int? sysTraderTranType = null,
        bool force = false,
        CancellationToken ct = default)
    {
        var response = await SageFetchCustomerTransactionsAsync(
            dataset,
            accountReference,
            documentNo,
            sysTraderTranType,
            force,
            ct);

        if (!string.IsNullOrWhiteSpace(response.ErrorReturned))
            throw new Exception(response.ErrorReturned);

        return response.Transactions;
    }

    public async Task<SageInboundPaymentSyncEnqueueClientResult> SageInboundPaymentSyncEnqueueAsync(
    Guid cymBuildDocumentGuid,
    bool forceRequeue = false,
    CancellationToken ct = default)
    {
        if (cymBuildDocumentGuid == Guid.Empty)
            throw new ArgumentException("A valid CymBuild document guid is required.", nameof(cymBuildDocumentGuid));

        var reply = await _coreClient.SageInboundPaymentSyncEnqueueAsync(
            new SageInboundPaymentSyncEnqueueRequestMessage
            {
                CymBuildDocumentGuid = cymBuildDocumentGuid.ToString(),
                ForceRequeue = forceRequeue
            },
            cancellationToken: ct);

        return new SageInboundPaymentSyncEnqueueClientResult
        {
            CymBuildDocumentGuid = Guid.TryParse(reply.CymBuildDocumentGuid, out var parsedGuid)
                ? parsedGuid
                : Guid.Empty,
            IsSuccess = reply.IsSuccess,
            Message = reply.Message ?? string.Empty
        };
    }


    public async Task<SageInboundPaymentSyncClientResult> SageInboundPaymentSyncAsync(
    Guid cymBuildDocumentGuid,
    bool force = false,
    CancellationToken ct = default)
    {
        if (cymBuildDocumentGuid == Guid.Empty)
            throw new ArgumentException("A valid CymBuild document guid is required.", nameof(cymBuildDocumentGuid));

        var reply = await _coreClient.SageInboundPaymentSyncAsync(
            new SageInboundPaymentSyncRequestMessage
            {
                CymBuildDocumentGuid = cymBuildDocumentGuid.ToString(),
                Force = force
            },
            cancellationToken: ct);

        var result = new SageInboundPaymentSyncClientResult
        {
            CymBuildDocumentGuid = Guid.TryParse(reply.CymBuildDocumentGuid, out var parsedGuid)
                ? parsedGuid
                : Guid.Empty,
            IsSuccess = reply.IsSuccess,
            IsRetryableFailure = reply.IsRetryableFailure,
            Message = reply.Message ?? string.Empty,
            ExternalTransactionCount = reply.ExternalTransactionCount,
            ExternalAllocationCount = reply.ExternalAllocationCount,
            ReconciledInvoiceCount = reply.ReconciledInvoiceCount,
            ReconciledAllocationCount = reply.ReconciledAllocationCount,
            UpdatedInvoiceRequestCount = reply.UpdatedInvoiceRequestCount
        };

        foreach (var item in reply.Items)
        {
            result.Items.Add(new SageInboundPaymentSyncClientResultItem
            {
                ExternalTransactionId = item.ExternalTransactionId,
                MatchedTransactionId = item.MatchedTransactionId,
                MatchedInvoiceRequestId = item.MatchedInvoiceRequestId,
                MatchedJobId = item.MatchedJobId,
                MatchRule = item.MatchRule ?? string.Empty
            });
        }

        return result;
    }
    private static DateTime? FromTimestamp(Timestamp? timestamp)
    {
        return timestamp == null ? null : timestamp.ToDateTime();
    }
    #endregion Public Methods

    #region Protected Methods

    protected async Task FormLoadMap(string recordGuid, string parentGuid, bool loadMap)
    {
        try
        {
            await FormLoadmapPre.InvokeAsync((ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString(), ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid).ToString(), loadMap));
        }
        catch (Exception ex)
        {
            Console.WriteLine("ERRORRAISED! \"PageMethod\", \"FormHelper/FormLoadMap()\" \r\n" + ex.Message);
        }
    }

    #endregion Protected Methods
}