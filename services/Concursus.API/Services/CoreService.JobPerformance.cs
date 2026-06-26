using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;

namespace Concursus.API.Services;

public partial class CoreService
{
    public override async Task<JobFinancialOverviewGetResponse> JobFinancialOverviewGet(
        JobFinancialOverviewGetRequest request,
        ServerCallContext context)
    {
        try
        {
            if (request is null || !Guid.TryParse(request.JobGuid, out var jobGuid) || jobGuid == Guid.Empty)
            {
                return new JobFinancialOverviewGetResponse
                {
                    ErrorReturned = "jobGuid must be a valid GUID."
                };
            }

            var userId = request.UserId > 0 ? request.UserId : _serviceBase._userId;

            var row = await _serviceBase._entityFramework
                .GetJobFinancialOverviewAsync(userId, jobGuid, context.CancellationToken)
                .ConfigureAwait(false);

            return new JobFinancialOverviewGetResponse
            {
                Overview = MapJobFinancialOverview(row),
                ErrorReturned = string.Empty
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "JobFinancialOverviewGet failed.");
            return new JobFinancialOverviewGetResponse
            {
                ErrorReturned = ex.Message
            };
        }
    }

    public override async Task<JobSummaryGetResponse> JobSummaryGet(
        JobSummaryGetRequest request,
        ServerCallContext context)
    {
        try
        {
            if (request is null || !Guid.TryParse(request.JobGuid, out var jobGuid) || jobGuid == Guid.Empty)
            {
                return new JobSummaryGetResponse
                {
                    ErrorReturned = "jobGuid must be a valid GUID."
                };
            }

            var userId = request.UserId > 0 ? request.UserId : _serviceBase._userId;

            var row = await _serviceBase._entityFramework
                .GetJobSummaryAsync(userId, jobGuid, context.CancellationToken)
                .ConfigureAwait(false);

            if (row is null)
            {
                return new JobSummaryGetResponse
                {
                    ErrorReturned = string.Empty
                };
            }

            return new JobSummaryGetResponse
            {
                Summary = new JobSummaryDto
                {
                    JobId = row.JobId,
                    JobGuid = row.JobGuid.ToString(),
                    RowStatus = row.RowStatus,
                    Number = row.Number ?? string.Empty,
                    DisplayTitle = row.DisplayTitle ?? string.Empty,
                    JobDescription = row.JobDescription ?? string.Empty,
                    ClientName = row.ClientName ?? string.Empty,
                    SurveyorName = row.SurveyorName ?? string.Empty,
                    CurrentStatusId = row.CurrentStatusId,
                    CurrentStatusGuid = row.CurrentStatusGuid.ToString(),
                    CurrentStatusName = row.CurrentStatusName ?? string.Empty,
                    IsActive = row.IsActive,
                    IsComplete = row.IsComplete,
                    IsCancelled = row.IsCancelled,
                    CannotBeInvoiced = row.CannotBeInvoiced,
                    InvoiceProcessingMode = (InvoiceProcessingMode)row.InvoiceProcessingMode,
                    OpenMilestoneCount = row.OpenMilestoneCount,
                    OpenActivityCount = row.OpenActivityCount,
                    OpenActionCount = row.OpenActionCount,
                    PendingInvoiceRequestCount = row.PendingInvoiceRequestCount,
                    ActiveInvoiceScheduleCount = row.ActiveInvoiceScheduleCount,
                    CanCreateReplacementInvoiceSchedule = row.CanCreateReplacementInvoiceSchedule,
                    FinancialOverview = MapJobFinancialOverview(row.FinancialOverview)
                },
                ErrorReturned = string.Empty
            };
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "JobSummaryGet failed.");
            return new JobSummaryGetResponse
            {
                ErrorReturned = ex.Message
            };
        }
    }

    private static JobFinancialOverviewDto MapJobFinancialOverview(Concursus.EF.JobFinancialOverviewRow? row)
    {
        if (row is null)
        {
            return new JobFinancialOverviewDto();
        }

        return new JobFinancialOverviewDto
        {
            JobGuid = row.JobGuid.ToString(),
            AgreedFeeTotal = Convert.ToDouble(row.AgreedFeeTotal),
            AgreedFeeIncludingCap = Convert.ToDouble(row.AgreedFeeIncludingCap),
            ScheduledTotal = Convert.ToDouble(row.ScheduledTotal),
            InvoiceRequestPendingTotal = Convert.ToDouble(row.InvoiceRequestPendingTotal),
            InvoicedNet = Convert.ToDouble(row.InvoicedNet),
            InvoicedGross = Convert.ToDouble(row.InvoicedGross),
            PaidNet = Convert.ToDouble(row.PaidNet),
            PaidGross = Convert.ToDouble(row.PaidGross),
            RemainingNet = Convert.ToDouble(row.RemainingNet),
            ActiveInvoiceScheduleCount = row.ActiveInvoiceScheduleCount,
            SystemGeneratedManualScheduleCount = row.SystemGeneratedManualScheduleCount,
            PendingInvoiceRequestCount = row.PendingInvoiceRequestCount,
            ReconciliationRequiredInvoiceRequestCount = row.ReconciliationRequiredInvoiceRequestCount,
            BlockedInvoiceRequestCount = row.BlockedInvoiceRequestCount,
            CanCreateReplacementInvoiceSchedule = row.CanCreateReplacementInvoiceSchedule
        };
    }
}
