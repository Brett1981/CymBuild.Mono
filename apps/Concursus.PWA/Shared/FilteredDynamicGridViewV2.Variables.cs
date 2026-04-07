using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System.Dynamic;
using Telerik.Blazor.Components;


namespace Concursus.PWA.Shared
{
    public partial class FilteredDynamicGridViewV2 : ComponentBase
    {


        //CBLD-393
        private static string dataObjGuid = "";

        private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();

        private System.Type? _detailPageType;

        private MessageDisplay _messageDisplay = new();

        private List<string> _operationsWithMultipleStateChanged = new List<string>() {
            "FilterDescriptors",
            "GroupDescriptors",
            "SearchFilter"
        };


        private List<ExpandoObject> gridData = new List<ExpandoObject>();

        // Ensure this is unique for each modal instance
        private string modalId = Guid.Empty.ToString();


        protected string ErrorMessage { get; set; } = "";
        protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
        protected string PageMethod { get; set; } = "Not Set";
        protected FormHelper? formHelper;

        // -------------------------
        // Detail Window (same pattern as DynamicGridView)
        // -------------------------
        private TelerikWindow? ModalWindow { get; set; }
        private bool WindowIsClosable { get; set; } = true;
        private bool WindowIsVisible { get; set; }
        private string? WindowTitle { get; set; }

        private GridViewDefinition? _viewDefinition;
        private string _detailPageTypeName = "";


        private bool BatchGridVisible { get; set; } = false;
        private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; } // Exposes the grid data
        private bool DoubleStateChanged { get; set; }
        private TelerikGrid<ExpandoObject>? GridRef { get; set; }
        private string GridStateChangedProperty { get; set; } = string.Empty;
        private string GridStateChangedPropertyClass { get; set; } = string.Empty;
        private string GridStateString { get; set; } = string.Empty;
        private int OnStateChangedCount { get; set; }
        private bool ComingFromModal { get; set; } = false;

        /* =============================================================================
           Authoriser Closure Review Queue (NEW)
           These fields/methods MUST exist in the same partial class used by the razor.
        ============================================================================= */

        private const string ClosureReviewQueueGridCode = "AUTHOREVIEW";

        private bool IsClosureReviewQueueGrid =>
            string.Equals(GridCode, ClosureReviewQueueGridCode, StringComparison.OrdinalIgnoreCase);

        private bool _closureModalVisible;
        private bool _closureBusy;
        private string _closureModalTitle = "Closure Review";
        private string _closureValidationMessage = "";
        private string _closureComment = "";

        private Guid _closureRecordGuid = Guid.Empty;

        private string _closureEntityTypeName = "";     // "Jobs" / "Quotes" / "Enquiries"
        private string _closureNumber = "";             // canonical Number (#.)
        private string _closureStatus = "";
        private string _closureDiscipline = "";
        private string _closureLastUpdated = "";

        private string _closureDisplayRef = "";
        private string _closureClient = "";
        private string _closureAgent = "";
        private string _closureAddress = "";

        /* Jobs */
        private string _closureJobDescription = "";
        private string _closureJobType = "";

        /* Quotes */
        private string _closureQuoteAgreedFee = "";
        private string _closureQuoteNet = "";
        private string _closureQuoteDateAccepted = "";

        /* Enquiries */
        private string _closureEnquiryTotalFee = "";



        //Values which we can group data by.
        private IEnumerable<string> GroupByOptions { get; set; } = new List<string>();
        private bool GroupByColumn { get; set; } = false;
        //We will get the translation (e.g. set in the dev) for the column we filter by. (e.g. OrgUnit = "Organisation Unit")
        private string GroupByColumTranslation { get; set; } = "";


        private double Threshold { get; set; } = -1; //Set it to -1 for now.
        private int OrganisationalUnitID { get; set; } = -1;


        // -------------------------
        // Modal open/close handlers
        // -------------------------
        private void OpenClosureReviewModal(IDictionary<string, object> row)
            => OpenClosureModalInternal(row, "Review ");

        private void OpenClosureApproveModal(IDictionary<string, object> row)
        {
            var entityType = TryGetStringFromRow(row, "EntityTypeName");

            OpenClosureModalInternal(row, "Approve ");
        }

        private void OpenClosureRejectModal(IDictionary<string, object> row)
        {
            var entityType = TryGetStringFromRow(row, "EntityTypeName");

            OpenClosureModalInternal(row, "Reject ");
        }

        private void OpenClosureModalInternal(IDictionary<string, object> row, string title)
        {
            _closureValidationMessage = "";
            _closureBusy = false;

            _closureRecordGuid = TryGetGuidFromRow(row, "Guid");

            _closureEntityTypeName = TryGetStringFromRow(row, "EntityTypeName"); // Jobs/Quotes/Enquiries
            _closureNumber = TryGetStringFromRow(row, "Number");                // #.
            _closureStatus = TryGetStringFromRow(row, "LatestWorkflowStatusName");
            _closureDiscipline = TryGetStringFromRow(row, "DisciplineName");
            _closureLastUpdated = TryGetStringFromRow(row, "LatestTransitionUtc");

            _closureDisplayRef = TryGetStringFromRow(row, "DisplayRef");
            _closureClient = TryGetStringFromRow(row, "DisplayClientName");
            _closureAgent = TryGetStringFromRow(row, "DisplayAgentName");
            _closureAddress = TryGetStringFromRow(row, "DisplayAddress");

            // Jobs
            _closureJobDescription = TryGetStringFromRow(row, "JobDescription");
            _closureJobType = TryGetStringFromRow(row, "JobTypeName");

            // Quotes
            _closureQuoteAgreedFee = TryGetStringFromRow(row, "QuoteAgreedFee");
            _closureQuoteNet = TryGetStringFromRow(row, "QuoteNet");
            _closureQuoteDateAccepted = TryGetStringFromRow(row, "QuoteDateAccepted");

            // Enquiries
            _closureEnquiryTotalFee = TryGetStringFromRow(row, "EnquiryTotalFee");

            // Title
            var typeLabel = string.IsNullOrWhiteSpace(_closureEntityTypeName) ? "Record" : _closureEntityTypeName.Trim();
            var numberLabel = string.IsNullOrWhiteSpace(_closureNumber) ? "" : $" {_closureNumber}";
            _closureModalTitle = $"{title + _closureStatus}: {typeLabel}{numberLabel}";

            _closureComment = ""; // Approve may be empty; reject validated later
            _closureModalVisible = true;
        }



        private void CloseClosureModal()
        {
            _closureModalVisible = false;
            _closureBusy = false;
            _closureValidationMessage = "";
            _closureComment = "";

            _closureRecordGuid = Guid.Empty;

            _closureEntityTypeName = "";
            _closureNumber = "";
            _closureStatus = "";
            _closureDiscipline = "";
            _closureLastUpdated = "";

            _closureDisplayRef = "";
            _closureClient = "";
            _closureAgent = "";
            _closureAddress = "";

            _closureJobDescription = "";
            _closureJobType = "";

            _closureQuoteAgreedFee = "";
            _closureQuoteNet = "";
            _closureQuoteDateAccepted = "";

            _closureEnquiryTotalFee = "";
        }

        private static bool TryGetBoolFromRow(IDictionary<string, object> row, string key)
        {
            if (row is null) return false;
            if (!row.TryGetValue(key, out var v) || v is null) return false;

            if (v is bool b) return b;

            if (v is byte by) return by != 0;
            if (v is sbyte sby) return sby != 0;
            if (v is short sh) return sh != 0;
            if (v is int i) return i != 0;
            if (v is long l) return l != 0;

            var s = v.ToString();
            if (string.IsNullOrWhiteSpace(s)) return false;

            return s == "1"
                || s.Equals("true", StringComparison.OrdinalIgnoreCase)
                || s.Equals("yes", StringComparison.OrdinalIgnoreCase);
        }


        // -------------------------
        // Navigation
        // -------------------------
        private void OpenFullRecord()
        {
            try
            {
                if (_closureRecordGuid == Guid.Empty || ViewDefinition is null) return;

                // Map entity -> detail page component name
                _detailPageTypeName = _closureEntityTypeName switch
                {
                    "Enquiries" => "EnquiryDetail",
                    "Quotes" => "QuoteDetail",
                    "Jobs" => "JobDetail",
                    _ => ""
                };

                if (string.IsNullOrWhiteSpace(_detailPageTypeName)) return;

                var guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(_closureRecordGuid.ToString()).ToString();

                var (parentDataObjectReference, serializedParentDataObjectReference) =
                    PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, guid, ViewDefinition.EntityTypeGuid);

                // If configured as windowed, open the modal windowed detail
                if (ViewDefinition.IsDetailWindowed)
                {
                    _ = GetScrollBarPos();

                    modalId = Guid.NewGuid().ToString();
                    _detailPageParameters.Clear();

                    _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                    _detailPageParameters.Add("Windowed", true);
                    _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                    _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
                    _detailPageParameters.Add("RecordGuid", guid);
                    _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                    _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                    _detailPageParameters.Add("ModalId", modalId);
                    _detailPageParameters.Add("IsMainRecordContext", false);

                    modalService.RegisterModal(modalId, parentDataObjectReference);

                    WindowTitle = $"{_closureEntityTypeName} {_closureNumber}".Trim();
                    WindowIsVisible = true;
                    ComingFromModal = true;

                    return;
                }

                // Fallback: normal navigation if not windowed
                var returnUri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
                var url = $"{_detailPageTypeName}/{guid}/{serializedParentDataObjectReference}/{returnUri}";
                NavManager.NavigateTo(url, false);
            }
            catch (Exception ex)
            {
                ErrorMessage = ex.Message;
                PageMethod = "FilteredDynamicGridViewV2/OpenFullRecord()";
                StateHasChanged();
            }
        }

        private void WindowVisibleChangedHandler(bool currVisible)
        {
            if (WindowIsClosable)
                WindowIsVisible = currVisible;
        }

        protected async Task CloseWindow()
        {
            try
            {
                if (_detailPageParameters.TryGetValue("ModalId", out var value) && value is string mid)
                {
                    modalService.UnregisterModal(mid);
                }

                WindowIsVisible = false;

                // Rebind the grid after closing the detail modal
                GridRef?.Rebind();
                await RefreshMe();

                // Restore scroll position if you want same behaviour as DynamicGridView
                await SetScrollBarPos();
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/CloseWindow()");
                await OnError(ex);
            }
        }

        protected async Task GridUpdated()
        {
            try
            {
                GridRef?.Rebind();
                await RefreshMe();
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/GridUpdated()");
                await OnError(ex);
            }
        }


        // -------------------------
        // Submit actions (Approve/Reject)
        // -------------------------
        private async Task SubmitClosureApprove()
        {
            await SubmitClosureDecisionAsync(approve: true);
        }

        private async Task SubmitClosureReject()
        {
            if (string.IsNullOrWhiteSpace(_closureComment))
            {
                _closureValidationMessage = "Rejection requires a comment.";
                return;
            }

            await SubmitClosureDecisionAsync(approve: false);
        }

        private async Task SubmitClosureDecisionAsync(bool approve)
        {
            if (_closureRecordGuid == Guid.Empty)
            {
                _closureValidationMessage = "Unable to action this record (GUID missing).";
                return;
            }

            var entityType = _closureEntityTypeName?.Trim() ?? "";

            var isJobs = string.Equals(entityType, "Jobs", StringComparison.OrdinalIgnoreCase);
            var isQuotes = string.Equals(entityType, "Quotes", StringComparison.OrdinalIgnoreCase);
            var isEnquiries = string.Equals(entityType, "Enquiries", StringComparison.OrdinalIgnoreCase);

            if (!isJobs && !isQuotes && !isEnquiries)
            {
                Toast.ShowWarning($"Approve/Reject is not supported for entity type '{entityType}' in this queue.");
                return;
            }

            if (!approve && string.IsNullOrWhiteSpace(_closureComment))
            {
                _closureValidationMessage = "Rejection requires a comment.";
                return;
            }

            _closureValidationMessage = "";
            _closureBusy = true;

            try
            {
                if (isJobs)
                {
                    // Keep existing job-specific behaviour (no regression)
                    var req = new JobClosureDecisionRequest
                    {
                        UserId = userService.UserId,
                        JobGuid = _closureRecordGuid.ToString(),
                        Decision = approve
                            ? JobClosureDecisionType.JobClosureDecisionApprove
                            : JobClosureDecisionType.JobClosureDecisionReject,
                        Comment = _closureComment ?? ""
                    };

                    var resp = await coreClient.JobClosureDecisionAsync(req);

                    if (!resp.Success)
                    {
                        Toast.ShowError(resp.Message);
                        return;
                    }

                    Toast.ShowSuccess(approve
                        ? "Closure approved. Job marked Completed."
                        : "Closure rejected. Returned to the team.");
                }
                else
                {
                    // generic authorisation decision (Quotes/Enquiries)
                    var req = new AuthorisationDecisionRequest
                    {
                        UserId = userService.UserId,
                        RecordGuid = _closureRecordGuid.ToString(),
                        EntityTypeName = entityType,
                        Approve = approve,
                        Comment = _closureComment ?? ""
                    };

                    var resp = await coreClient.AuthorisationDecisionAsync(req);

                    if (!resp.Success)
                    {
                        Toast.ShowError(resp.Message);
                        return;
                    }

                    Toast.ShowSuccess(approve
                        ? $"{entityType} approved."
                        : $"{entityType} rejected.");
                }

                CloseClosureModal();
                await RebindGridSafeAsync();

                if (OnActionCompleted.HasDelegate)
                {
                    await OnActionCompleted.InvokeAsync();
                }
            }
            catch (Exception ex)
            {
                Toast.ShowError($"Decision failed: {ex.Message}");
                ErrorMessage = ex.Message;
                PageMethod = "FilteredDynamicGridViewV2/SubmitClosureDecisionAsync()";
            }
            finally
            {
                _closureBusy = false;
                await InvokeAsync(StateHasChanged);
            }
        }


        /// <summary>
        /// Safe grid refresh:
        /// - Prefer TelerikGrid.Rebind()
        /// - Fallback to RefreshService.RequestGridRefresh(GridCode)
        /// </summary>
        private async Task RebindGridSafeAsync()
        {
            try
            {
                if (GridRef is not null)
                {
                    GridRef.Rebind();
                    return;
                }

                // Fallback: ask global grid system to refresh this grid code
                // (DynamicGrid listens to RefreshService in some setups)
             refreshservice?.RequestGridRefresh(GridCode);
            }
            catch
            {
                // best-effort refresh
            }
        }

        // -------------------------
        // Row helpers (fix “does not exist” compile errors)
        // -------------------------
        private static string TryGetStringFromRow(IDictionary<string, object> row, string key)
        {
            if (row is null) return "";
            if (!row.TryGetValue(key, out var v) || v is null) return "";
            return v.ToString() ?? "";
        }

        private static Guid TryGetGuidFromRow(IDictionary<string, object> row, string key)
        {
            if (row is null) return Guid.Empty;
            if (!row.TryGetValue(key, out var v) || v is null) return Guid.Empty;

            if (v is Guid g) return g;
            return Guid.TryParse(v.ToString(), out var parsed) ? parsed : Guid.Empty;
        }
    }
}
