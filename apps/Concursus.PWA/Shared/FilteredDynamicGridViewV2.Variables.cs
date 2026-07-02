using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System.Dynamic;

namespace Concursus.PWA.Shared
{
    public partial class FilteredDynamicGridViewV2 : ComponentBase
    {
        // CBLD-393
        private static string dataObjGuid = "";

        private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();

        private System.Type? _detailPageType;

        private MessageDisplay _messageDisplay = new();

        private List<string> _operationsWithMultipleStateChanged = new List<string>()
        {
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
        // Detail Window (native shell, same behaviour as previous windowed detail)
        // -------------------------
        private bool WindowIsClosable { get; set; } = true;
        private bool WindowIsVisible { get; set; }
        private string? WindowTitle { get; set; }

        private GridViewDefinition? _viewDefinition;
        private string _detailPageTypeName = "";

        private bool BatchGridVisible { get; set; } = false;
        private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; }
        private bool DoubleStateChanged { get; set; }
        private string GridStateChangedProperty { get; set; } = string.Empty;
        private string GridStateChangedPropertyClass { get; set; } = string.Empty;
        private string GridStateString { get; set; } = string.Empty;
        private int OnStateChangedCount { get; set; }
        private bool ComingFromModal { get; set; } = false;

        // -------------------------
        // Native grid state
        // -------------------------
        private string _nativeGridParameterKey = string.Empty;
        private int NativePage { get; set; } = 1;
        private int NativePageSize { get; set; } = 50;
        private int NativeTotalRows { get; set; }
        private bool NativeIsLoading { get; set; }
        private string NativeSortColumn { get; set; } = string.Empty;
        private bool NativeSortDescending { get; set; }
        private string NativeSearchText { get; set; } = string.Empty;
        private bool NativeFilterPanelOpen { get; set; } = false;
        private Dictionary<string, string> NativeColumnFilters { get; set; } = new(StringComparer.OrdinalIgnoreCase);

        /* =============================================================================
           Authoriser Closure Review Queue
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

        private string _closureEntityTypeName = "";
        private string _closureNumber = "";
        private string _closureStatus = "";
        private string _closureDiscipline = "";
        private string _closureLastUpdated = "";

        private string _closureDisplayRef = "";
        private string _closureClient = "";
        private string _closureAgent = "";
        private string _closureAddress = "";

        private string _closureJobDescription = "";
        private string _closureJobType = "";

        private string _closureQuoteAgreedFee = "";
        private string _closureQuoteNet = "";
        private string _closureQuoteDateAccepted = "";

        private string _closureEnquiryTotalFee = "";

        // Values which we can group data by.
        private IEnumerable<string> GroupByOptions { get; set; } = new List<string>();
        private bool GroupByColumn { get; set; } = false;
        private string GroupByColumTranslation { get; set; } = "";

        private double Threshold { get; set; } = -1;
        private int OrganisationalUnitID { get; set; } = -1;

        // -------------------------
        // Modal open/close handlers
        // -------------------------
        private void OpenClosureReviewModal(IDictionary<string, object> row)
            => OpenClosureModalInternal(row, "Review ");

        private void OpenClosureApproveModal(IDictionary<string, object> row)
            => OpenClosureModalInternal(row, "Approve ");

        private void OpenClosureRejectModal(IDictionary<string, object> row)
            => OpenClosureModalInternal(row, "Reject ");

        private void OpenClosureModalInternal(IDictionary<string, object> row, string title)
        {
            _closureValidationMessage = "";
            _closureBusy = false;

            _closureRecordGuid = TryGetGuidFromRow(row, "Guid");

            _closureEntityTypeName = TryGetStringFromRow(row, "EntityTypeName");
            _closureNumber = TryGetStringFromRow(row, "Number");
            _closureStatus = TryGetStringFromRow(row, "LatestWorkflowStatusName");
            _closureDiscipline = TryGetStringFromRow(row, "DisciplineName");
            _closureLastUpdated = TryGetStringFromRow(row, "LatestTransitionLocal");

            _closureDisplayRef = TryGetStringFromRow(row, "DisplayRef");
            _closureClient = TryGetStringFromRow(row, "DisplayClientName");
            _closureAgent = TryGetStringFromRow(row, "DisplayAgentName");
            _closureAddress = TryGetStringFromRow(row, "DisplayAddress");

            _closureJobDescription = TryGetStringFromRow(row, "JobDescription");
            _closureJobType = TryGetStringFromRow(row, "JobTypeName");

            _closureQuoteAgreedFee = TryGetStringFromRow(row, "QuoteAgreedFee");
            _closureQuoteNet = TryGetStringFromRow(row, "QuoteNet");
            _closureQuoteDateAccepted = TryGetStringFromRow(row, "QuoteDateAccepted");

            _closureEnquiryTotalFee = TryGetStringFromRow(row, "EnquiryTotalFee");

            var typeLabel = string.IsNullOrWhiteSpace(_closureEntityTypeName) ? "Record" : _closureEntityTypeName.Trim();
            var numberLabel = string.IsNullOrWhiteSpace(_closureNumber) ? "" : $" {_closureNumber}";
            _closureModalTitle = $"{title + _closureStatus}: {typeLabel}{numberLabel}";

            _closureComment = "";
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

                await ReloadNativeGridAsync(NativePage);
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
                await ReloadNativeGridAsync(NativePage);
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

        private async Task RebindGridSafeAsync()
        {
            try
            {
                await ReloadNativeGridAsync(NativePage);
            }
            catch
            {
                try
                {
                    refreshservice?.RequestGridRefresh(GridCode);
                }
                catch
                {
                    // best-effort refresh
                }
            }
        }

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
