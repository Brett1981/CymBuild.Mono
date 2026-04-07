using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using DocumentFormat.OpenXml.Spreadsheet;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using Telerik.Blazor.Components;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class DynamicTreeListGridView
{
    #region Protected Fields

    protected FormHelper? formHelper;

    #endregion Protected Fields

    #region Private Fields

    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private Type? _detailPageType;
    private MessageDisplay _messageDisplay = new();
    private GridViewDefinition? _viewDefinition;
    private Guid EntityTypeGuid;
    private List<ExpandoObject> gridData = new List<ExpandoObject>();
    private List<ExpandoObject> groupedData = new List<ExpandoObject>();
    private string modalId = Guid.Empty.ToString();

    #endregion Private Fields

    #region Public Properties

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();

    [Parameter]
    public GridViewDefinition? ViewDefinition
    {
        get => _viewDefinition;
        set
        {
            _viewDefinition = value;
            //if (GridRef is not null) RefreshMe().ConfigureAwait(true);
        }
    }

    #endregion Public Properties

    #region Protected Properties

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    #endregion Protected Properties

    #region Private Properties

    private string currentGridCode { get; set; } = "";
    private TelerikTreeList<ExpandoObject>? GridRef { get; set; }
    private TelerikWindow? ModalWindow { get; set; }
    private bool reReadData { get; set; } = false;
    private int? SearchBoxWidth { get; set; } = 200;
    private IEnumerable<ExpandoObject> SelectedItems { get; set; } = new List<ExpandoObject>();
    private bool WindowIsClosable { get; set; } = true;
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }
    private string FirstOrderBy { get; set; } = "";
    private string SecondOrderBy { get; set; } = "";
    private string ThirdOrderBy { get; set; } = "";

    private string GroupBy { get; set; } = "";
    private string[] GroupByValues { get; set; }

    private string OrderBy { get; set; } = "";
    private string[] OrderByValues { get; set; }

    #endregion Private Properties

    #region Public Methods

    protected override async Task OnInitializedAsync()
    {
        if (ViewDefinition is not null)
        {
            FirstOrderBy = ViewDefinition.TreeListFirstOrderBy;
            SecondOrderBy = ViewDefinition.TreeListSecondOrderBy;
            ThirdOrderBy = ViewDefinition.TreeListThirdOrderBy;

            GroupBy = ViewDefinition.TreeListGroupBy;
            GetGroupBy();

            OrderBy = ViewDefinition.TreeListOrderBy;
            GetOrderBy();

            if (!groupedData.Any())
                await ReadItems();
        }
    }

    private void OnRowRenderHandler(TreeListRowRenderEventArgs args)
    {
        // Cast the row item back to ExpandoObject (or dictionary)
        var dict = (IDictionary<string, object>)args.Item;

        if (dict.ContainsKey("ApplyCSS") && dict["ApplyCSS"] is bool applyCss && applyCss)
        {
            args.Class = "treelist-toggle-header"; // apply your CSS
        }
        else if (dict.ContainsKey("SecondLevelCSS") && dict["SecondLevelCSS"] is bool secondCSS && secondCSS)
        {
            if (SecondOrderBy != "")
                args.Class = "treelist-toggle-header-2";
        }
    }

    public void AddProperty(ExpandoObject expando, string propertyName, object propertyValue)
    {
        try
        {
            // ExpandoObject supports IDictionary so we can extend it like this
            var expandoDict = expando as IDictionary<string, object>;
            if (expandoDict.ContainsKey(propertyName))
                expandoDict[propertyName] = propertyValue;
            else
                expandoDict.Add(propertyName, propertyValue);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to add a property to the ExpandoObject.");
            ex.Data.Add("PageMethod", "DynamicGridView/AddProperty()");
            OnError(ex);
        }
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("DynamicBatchGridView: Error message is empty. Aborting.");
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"DynamicBatchGridView: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("DynamicBatchGridView: MessageType not found in error.Data. Defaulted to Error.");
        }

        // Extract all exception data
        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(
                de => de.Key?.ToString() ?? "UnknownKey",
                de => de.Value!)
            : null;

        if (exceptionData != null)
        {
            foreach (var kvp in exceptionData)
                Console.WriteLine($"    {kvp.Key} = {kvp.Value}");
        }

        _messageDisplay.UpdateExceptionData(exceptionData);
        _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
        _messageDisplay.ShowError(true);

        Console.WriteLine("DynamicBatchGridView: MessageDisplay updated and error shown.");

        // AI Error Reporting (only for actual errors)
        if (MessageType == ShowMessageType.Error)
        {
            try
            {
                var context = new
                {
                    ErrorMessage = error.Message,
                    PageMethod = error.Data.Contains("PageMethod") ? error.Data["PageMethod"]?.ToString() ?? "UnknownMethod" : "UnknownMethod",
                    StackTrace = error.StackTrace ?? "No stack trace",
                    AdditionalInfo = error.Data.Contains("AdditionalInfo") ? error.Data["AdditionalInfo"]?.ToString() ?? "None" : "None",
                    Data = error.Data.Cast<DictionaryEntry>()
                        .ToDictionary(
                            de => de.Key?.ToString() ?? "UnknownKey",
                            de => de.Value?.ToString() ?? "null"
                        )
                };

                var log = InteractionTracker.GetAllLogs();
                var description = InteractionTracker.GetReplicationStepsFormatted(InteractionTracker);
                error.Data["UserInteractionLog"] = description;
                Console.WriteLine($"DynamicBatchGridView: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("DynamicBatchGridView: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"DynamicBatchGridView: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
    }

    public async Task RefreshMe()
    {
        try
        {
            if (GridRef != null)
                GridRef.Rebind();

            await RebindTreeList();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to refresh the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/RefreshMe()");
            OnError(ex);
        }
    }

    public void GetOrderBy()
    {
        string[] OrderByValues = OrderBy.Split(",");

        for (int i = 0; i < OrderByValues.Length; i++)
            OrderByValues[i] = OrderByValues[i].Trim();

        this.OrderByValues = OrderByValues;
    }

    public void GetGroupBy()
    {
        string[] GroupByValues = GroupBy.Split(",");

        for (int i = 0; i < GroupByValues.Length; i++)
            GroupByValues[i] = GroupByValues[i].Trim();

        this.GroupByValues = GroupByValues;
    }

    #endregion Public Methods

    #region Protected Methods

    protected async Task CloseWindow()
    {
        try
        {
            object? value;
            if (_detailPageParameters.TryGetValue("ModalId", out value))
            {
                if (value is string modalId)
                {
                    modalService.UnregisterModal(modalId);
                }
            }

            WindowIsVisible = false;
            GridRef?.Rebind();

            await RefreshMe();

            StateHasChanged();
            await OnActionCompleted.InvokeAsync();  // Notify that an action has completed
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to close the window.");
            ex.Data.Add("PageMethod", "DynamicGridView/CloseWindow()");
            OnError(ex);
        }
    }

    protected async Task ReadItems()
    {
        try
        {
            if (ViewDefinition != null)
            {
                // PART 1: Fix for ensuring that upon changing drawers, the values are updated properly
                if (currentGridCode != ViewDefinition.Code)
                {
                    SelectedItems = null;
                }

                // Create the grid request
                GridDataListRequest gridDataListRequest = new()
                {
                    GridCode = GridCode,
                    GridViewCode = ViewDefinition.Code,
                    Page = 1,
                    PageSize = 10000,
                    ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
                };

                currentGridCode = ViewDefinition.Code;

                // Only run if ParentGuid is valid or FullGrid is true
                if (gridDataListRequest.ParentGuid != Guid.Empty.ToString() || FullGrid)
                {
                    var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);

                    gridData = new();
                    reReadData = false;

                    // Populate gridData with the fetched rows
                    foreach (var r in gridDataListReply.DataTable)
                    {
                        dynamic dataObj = new ExpandoObject();

                        foreach (var c in r.Columns)
                        {
                            var value = c.Value;
                            var name = c.Name;

                            // Format date fields if needed
                            if (DateTime.TryParse(value, out var dateTimeValue))
                            {
                                value = UiFormattingHelper.FormatDynamicDate(name, dateTimeValue);
                            }

                            AddProperty(dataObj, name, value);
                        }

                        gridData.Add(dataObj);
                    }

                    // Group by Consultant (FirstOrderBy)
                    groupedData = new List<ExpandoObject>();

                    var consultantGroups = gridData.GroupBy(row =>
                    {
                        var dict = (IDictionary<string, object>)row;
                        return dict.ContainsKey(FirstOrderBy) ? dict[FirstOrderBy] : "Unknown";
                    });

                    foreach (var consultantGroup in consultantGroups)
                    {
                        dynamic consultantParent = new ExpandoObject();
                        var dict = (IDictionary<string, object>)consultantParent;

                        // Unique ID for Consultant group
                        var consultantId = Guid.NewGuid();
                        dict["TreeListID"] = consultantId;
                        dict["ParentID"] = null;
                        dict["ApplyCSS"] = true;
                        dict[FirstOrderBy] = consultantGroup.Key;

                        // Add other columns dynamically
                        foreach (var col in gridDataListReply.DataTable.First().Columns)
                        {
                            if (col.Name == "TreeListID" || col.Name == FirstOrderBy)
                                continue;

                            if (!dict.ContainsKey(col.Name))
                                dict[col.Name] = "";
                        }

                        groupedData.Add(consultantParent);

                        // Second-level grouping (Month, etc.)
                        if (!string.IsNullOrEmpty(SecondOrderBy))
                        {
                            var monthGroups = consultantGroup.GroupBy(row =>
                            {
                                var dict = (IDictionary<string, object>)row;
                                return dict.ContainsKey(SecondOrderBy) ? dict[SecondOrderBy] : "Unknown";
                            });

                            foreach (var monthGroup in monthGroups)
                            {
                                dynamic monthParent = new ExpandoObject();
                                var monthDict = (IDictionary<string, object>)monthParent;

                                var monthId = Guid.NewGuid();
                                monthDict["TreeListID"] = monthId;
                                monthDict["ParentID"] = consultantId;
                                monthDict["ApplyCSS"] = false;
                                monthDict["SecondLevelCSS"] = true;
                                monthDict[SecondOrderBy] = monthGroup.Key;

                                foreach (var col in gridDataListReply.DataTable.First().Columns)
                                {
                                    if (col.Name == "TreeListID" || col.Name == SecondOrderBy)
                                        continue;

                                    if (!monthDict.ContainsKey(col.Name))
                                        monthDict[col.Name] = "";
                                }

                                groupedData.Add(monthParent);

                                // Third-level grouping (if ThirdOrderBy is set)
                                if (!string.IsNullOrEmpty(ThirdOrderBy))
                                {
                                    var thirdGroups = monthGroup.GroupBy(row =>
                                    {
                                        var dict = (IDictionary<string, object>)row;
                                        return dict.ContainsKey(ThirdOrderBy) ? dict[ThirdOrderBy] : "Unknown";
                                    });

                                    foreach (var thirdGroup in thirdGroups)
                                    {
                                        dynamic thirdParent = new ExpandoObject();
                                        var thirdDict = (IDictionary<string, object>)thirdParent;

                                        var thirdId = Guid.NewGuid();
                                        thirdDict["TreeListID"] = thirdId;
                                        thirdDict["ParentID"] = monthId;
                                        thirdDict["ApplyCSS"] = false;
                                        thirdDict["ThirdLevelCSS"] = true;
                                        thirdDict[ThirdOrderBy] = thirdGroup.Key;

                                        foreach (var col in gridDataListReply.DataTable.First().Columns)
                                        {
                                            if (col.Name == "TreeListID" || col.Name == ThirdOrderBy)
                                                continue;

                                            if (!thirdDict.ContainsKey(col.Name))
                                                thirdDict[col.Name] = "";
                                        }

                                        groupedData.Add(thirdParent);

                                        // Jobs under third level
                                        foreach (var job in thirdGroup)
                                        {
                                            var jobDict = (IDictionary<string, object>)job;
                                            jobDict["ParentID"] = thirdId;
                                            jobDict[ThirdOrderBy] = "";

                                            if (!jobDict.ContainsKey("TreeListID"))
                                                jobDict["TreeListID"] = Guid.NewGuid();

                                            groupedData.Add(job);
                                        }
                                    }
                                }
                                else
                                {
                                    // Fallback: Jobs directly under Month
                                    foreach (var job in monthGroup)
                                    {
                                        var jobDict = (IDictionary<string, object>)job;
                                        jobDict["ParentID"] = monthId;
                                        jobDict[SecondOrderBy] = "";

                                        if (!jobDict.ContainsKey("TreeListID"))
                                            jobDict["TreeListID"] = Guid.NewGuid();

                                        groupedData.Add(job);
                                    }
                                }
                            }
                        }
                        else
                        {
                            // Fallback: Jobs directly under Consultant
                            foreach (var job in consultantGroup)
                            {
                                var jobDict = (IDictionary<string, object>)job;
                                jobDict["ParentID"] = consultantId;

                                if (!jobDict.ContainsKey("TreeListID"))
                                    jobDict["TreeListID"] = Guid.NewGuid();

                                groupedData.Add(job);
                            }
                        }
                    }

                    if (OrderByValues.Any())
                    {
                        IOrderedEnumerable<ExpandoObject> ordered = null;

                        object SafeGetValue(ExpandoObject obj, string key)
                        {
                            var dict = (IDictionary<string, object>)obj;
                            if (dict.TryGetValue(key, out var value))
                                return value ?? ""; // prevent null issues in sort
                            return ""; // default for missing keys
                        }

                        for (int i = 0; i < OrderByValues.Length; i++)
                        {
                            var key = OrderByValues[i];

                            if (i == 0)
                                ordered = groupedData.OrderBy(x => SafeGetValue(x, key));
                            else
                                ordered = ordered.ThenBy(x => SafeGetValue(x, key));
                        }

                        groupedData = ordered.ToList();
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to read items for the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/ReadItems()");
            OnError(ex);
        }
    }

    #endregion Protected Methods

    #region Private Methods

    private async Task RebindTreeList()
    {
        try
        {
            //groupedData = new();
            GridRef?.Rebind();
            //StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to rebind the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/RebindGrid()");
            OnError(ex);
        }
    }

    private void ScrollToTop()
    {
        // Scroll to the top of the page
        JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
    }

    private void WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
            WindowIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
        else
            Console.WriteLine("The user tried to close the window but the code didn't let them");
    }

    private void OnRowDoubleClickHandler(TreeListRowClickEventArgs args)
    {
        var onRowDoubleClickHandler = !string.IsNullOrEmpty(ViewDefinition?.DetailPageUri) ? "@OnRowDoubleClickHandler" : null;
        if (onRowDoubleClickHandler == null) return;

        dynamic model = args.Item;
        //Do nothing if empty guid
        if (model.Guid == Guid.Empty.ToString()) return;

        if (ViewDefinition == null) return;

        string parentGuid = model.Guid;
        // CBLD - 462: SB - Check to see if the Entity Guid in the current ParentDataOnjectReference
        // is different than where its going
        var isParentDataObjectReferenceDifferent = ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

        //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
        var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, parentGuid, ViewDefinition.EntityTypeGuid);

        if (ViewDefinition.IsDetailWindowed)
        {
            //Get new ModalId, add it to Parameter and register it
            modalId = Guid.NewGuid().ToString();
            _detailPageParameters.Clear();
            _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
            _detailPageParameters.Add("Windowed", true);
            _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
            _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, RebindTreeList));
            _detailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString());
            _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
            _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
            _detailPageParameters.Add("ModalId", modalId);
            _detailPageParameters.Add("IsMainRecordContext", false);

            modalService.RegisterModal(modalId, parentDataObjectReference);
            WindowIsVisible = true;

            InteractionTracker.Log(NavManager.Uri, $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid").ToString()}'");
        }
        else
        {
            // Step 1: Parse safe GUID
            string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString();

            if (guid == Guid.Empty.ToString())
                return;

            // Step 2: Serialized reference should already be encoded (confirm this!)
            string sPDOR = serializedParentDataObjectReference;
            // Step 3: ENCODE the full URL you are appending
            string uri = System.Web.HttpUtility.UrlEncode(NavManager.BaseUri);
            // Step 4: Combine
            string url = $"{ViewDefinition.DetailPageUri}/{guid}/{sPDOR}/{uri}";

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(
                                ViewDefinition.DetailPageUri +
                                "/" +
                                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() +
                                "/" +
                                parentDataObjectReference.DataObjectGuid +
                                "/" +
                                serializedParentDataObjectReference +
                                "/" +
                                System.Web.HttpUtility.UrlEncode(NavManager.Uri)
                                    );
            }
            else
            {
                if (isParentDataObjectReferenceDifferent)
                {
                    //CLD-611
                    //Page not refreshing (url does change though) when we try to go to the same record type through the history tab in a modal
                    var navigateToDetailPage = "/" + ViewDefinition.DetailPageUri + "/";
                    var currentUri = NavManager.Uri;

                    if (currentUri.Contains(navigateToDetailPage))
                    {
                        NavManager.NavigateTo(url, true);
                    }
                    else
                    {
                        NavManager.NavigateTo(url, false);
                    }
                }
                else
                {
                    NavManager.NavigateTo(url, true);
                }

                InteractionTracker.Log(
                        NavManager.Uri, $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid").ToString()}'");
            }
        }
    }

    #endregion Private Methods
}