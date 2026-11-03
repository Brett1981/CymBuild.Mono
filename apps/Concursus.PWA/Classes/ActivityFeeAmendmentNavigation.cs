using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Modals;
using Concursus.PWA.Pages;

namespace Concursus.PWA.Classes;

/// <summary>
/// CYB-333: after a billable activity answered "not part of the agreed fee" is saved, the server
/// raises a linked Pending fee amendment and it is opened in a modal for the user to complete.
/// The Job Fees table only changes once that amendment is Agreed.
/// </summary>
public static class ActivityFeeAmendmentNavigation
{
    public const string FeeAmendmentModalTitle = "Fee Amendment";

    // Matches FeeAmendmentDetail.razor's EntityTypeGuid.
    private const string FeeAmendmentEntityTypeGuid = "7d1bda7a-befc-48f0-ab3b-d44264381109";

    // Raised above the grid's windowed detail panel, which the activity may be open in (see app.css).
    public const string FeeAmendmentModalCssClass = "cb-v2-modal-xl cb-v2-modal-activity-fee-amendment";

    // The Job page's Fees table, which shows the agreed fee and Variation the amendment changes.
    public const string JobFeesGridCode = "JOBFEES";

    /// <summary>
    /// Opens the fee amendment raised for the saved activity in a modal. The activity page carries on
    /// with its normal post-save handling underneath; the modal is hosted at app level, so it stays
    /// open across that navigation.
    /// </summary>
    public static async Task OpenRaisedFeeAmendmentAsync(
        FormHelper formHelper,
        CymBuildModalService modalService,
        RefreshService refreshService,
        object eventReceiver,
        DataObject savedActivity)
    {
        if (!Guid.TryParse(savedActivity.Guid, out var activityGuid) || activityGuid == Guid.Empty)
        {
            return;
        }

        var response = await formHelper.ActivityFeeAmendmentEnsureAsync(activityGuid);

        if (!string.IsNullOrEmpty(response.ErrorReturned))
        {
            throw new InvalidOperationException(
                $"The activity was saved, but its fee amendment could not be created: {response.ErrorReturned}");
        }

        if (!response.WasCreated || !Guid.TryParse(response.FeeAmendmentGuid, out var feeAmendmentGuid))
        {
            return;
        }

        // Not awaited: the returned task only completes when the user closes the modal.
        var modalClosed = modalService.ShowWindowedEntityAsync<FeeAmendmentDetail>(
            eventReceiver,
            FeeAmendmentModalTitle,
            feeAmendmentGuid,
            Guid.Parse(FeeAmendmentEntityTypeGuid),
            returnUrl: string.Empty,
            isMainRecordContext: false,
            sizeCssClass: FeeAmendmentModalCssClass);

        _ = RequestJobFeesRefreshWhenClosedAsync(modalClosed, refreshService);
    }

    /// <summary>
    /// CYB-335: agreeing the amendment in the modal changes the Job Fees table (Agreed, Variation),
    /// but the activity panel that opened it has already closed, so no grid callback reaches the Job
    /// page. Signal it through the app-wide RefreshService once the modal closes (saved or not).
    /// </summary>
    private static async Task RequestJobFeesRefreshWhenClosedAsync(
        Task<CymBuildModalResult> modalClosed,
        RefreshService refreshService)
    {
        await modalClosed;
        refreshService.RequestGridRefresh(JobFeesGridCode);
    }
}
