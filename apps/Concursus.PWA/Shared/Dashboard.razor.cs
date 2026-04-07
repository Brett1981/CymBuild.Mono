using Blazored.Modal;
using Blazored.Modal.Services;
using Concursus.API.Client.Classes;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Controls;
using Microsoft.AspNetCore.Components;
using Newtonsoft.Json;
using System.Collections;
using System.Web;
using Telerik.Blazor.Components;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class Dashboard
{
    protected MessageDisplay? _messageDisplay = new();
    private bool _hasLoaded = false;
    private RecentItemResponse? _recentItems;
    private ScheduleItemsGetResponse? _scheduleItems;
    [CascadingParameter] public IModalService Modal { get; set; } = default!;
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    private List<DashboardMetric> Metrics { get; set; } = new();

    //public void OnError(Exception error)
    //{
    //    if (string.IsNullOrEmpty(error.Message)) return;

    // ErrorMessage = error.Message; PageMethod = (error.Data.Contains("PageMethod") ?
    // error.Data["PageMethod"]?.ToString() : "Not Set") ?? string.Empty;

    // if (error.Data.Contains("MessageType")) { MessageType =
    // (MessageDisplay.ShowMessageType)(error.Data["MessageType"] ??
    // MessageDisplay.ShowMessageType.Information); } else { MessageType =
    // MessageDisplay.ShowMessageType.Error; }

    // // Extract all exception data and pass it to the MessageDisplay component if (messageDisplay
    // != null) { // Pass Exception Data using the new method messageDisplay?.UpdateExceptionData(
    // error.Data.Count > 0 ? error.Data.Cast<DictionaryEntry>() .ToDictionary( de =>
    // de.Key?.ToString() ?? "UnknownKey", de => de.Value!) : null );

    // // Update the stack trace dynamically messageDisplay?.UpdateStackTrace(error.StackTrace);

    // messageDisplay?.ShowError(true); }

    // // Recover from error (if using a custom boundary) // customErrorBoundary.Recover();

    //    StateHasChanged();
    //}

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("Dashboard: Error message is empty. Aborting.");
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"Dashboard: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("Dashboard: MessageType not found in error.Data. Defaulted to Error.");
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

        Console.WriteLine("Dashboard: MessageDisplay updated and error shown.");

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
                Console.WriteLine($"Dashboard: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("Dashboard: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"Dashboard: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
    }

    protected void HandleClickOnMetric(string id)
    {
        try
        {
            //Loop through the metrics and find the one that was clicked and open its relevent blazor page. i.e. if the metric is "_schedule" then Navigate to the Schedule.razor page.
            switch (id)
            {
                case "_schedule":
                    Navigation.NavigateTo("/schedule");
                    break;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error navigating to the page");
            ex.Data.Add("PageMethod", "Dashboard/HandleClickOnMetric()");
            OnError(ex);
        }
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            var dashboardMetricsGetResponse = await CoreClient.DashboardMetricsGetAsync(new DashboardMetricsGetRequest());

            Metrics = dashboardMetricsGetResponse.Metrics.ToList();

            await base.OnInitializedAsync();

            return;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "Dashboard/OnInitializedAsync()");
            OnError(ex);
        }
    }

    private async void GetRecentListAsync(int userId)
    {
        try
        {
            var recentItemRequest = new RecentItemRequest { UserId = userId };
            _recentItems = await CoreClient.RecentItemsGetAsync(recentItemRequest);

            GetScheduleListAsync(userId);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error getting recent items List.");
            ex.Data.Add("PageMethod", "Dashboard/GetRecentListAsync()");
            OnError(ex);
        }
    }

    // ReSharper disable once MethodTooLong
    private async void GetScheduleListAsync(int userId)
    {
        try
        {
            var scheduleItemsGetRequest = new ScheduleItemsGetRequest() { CurrentUserOnly = true };
            var listOfScheduleItems = await CoreClient.ScheduleItemsGetAsync(scheduleItemsGetRequest);
            if (listOfScheduleItems == null) return;
            if (!string.IsNullOrEmpty(listOfScheduleItems.ErrorReturned))
            { throw new Exception(listOfScheduleItems.ErrorReturned); }
            var earlyDate = DateTime.Now.AddDays(-7);
            var lateDate = DateTime.Now.AddDays(7);
            _scheduleItems = new ScheduleItemsGetResponse();
            foreach (var item in listOfScheduleItems.ScheduleItems)
            {
                var start = item.Start.ToDateTime();

                if (start.IsBetweenTwoDates(earlyDate, lateDate))
                {
                    _scheduleItems.ScheduleItems.Add(item);
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error getting schedule items List.");
            ex.Data.Add("PageMethod", "Dashboard/GetScheduleListAsync()");
            OnError(ex);
        }

        if (!_hasLoaded)
        {
            _hasLoaded = true;
            StateHasChanged();
        }
    }

    private void HandleRowDoubleClick(GridRowClickEventArgs args)
    {
        try
        {
            dynamic model = args.Item;
            var onRowDoubleClickHandler = !string.IsNullOrEmpty(model?.DetailPageUri) ? "@HandleRowDoubleClick" : null;
            if (onRowDoubleClickHandler == null) return;

            if (model == null) return; // Check for null

            string serializeParentDataObjectReferenced = HttpUtility.UrlEncode(JsonConvert.SerializeObject(ParentDataObjectReference ?? new DataObjectReference("", ""))); ;
            if (ParentDataObjectReference == null || ParentDataObjectReference.EntityTypeGuid == Guid.Empty
                && ParentDataObjectReference.DataObjectGuid == Guid.Empty)
            {
                try
                {
                    ParentDataObjectReference = new DataObjectReference(model.RecordGuid, model.EntityTypeGuid);
                    serializeParentDataObjectReferenced = HttpUtility.UrlEncode(JsonConvert.SerializeObject(ParentDataObjectReference));
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex);
                }
            }

            if (model.DetailPageUri == "DynamicEdit")
                Navigation.NavigateTo(model.DetailPageUri + "/" + ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(model.EntityTypeGuid).ToString()
                                      + "/" + Guid.Empty.ToString() + "/" +
                                      serializeParentDataObjectReferenced + "/" + HttpUtility.UrlEncode(Navigation.Uri));
            else
                Navigation.NavigateTo(model.DetailPageUri + "/" + ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(model.RecordGuid).ToString() + "/" +
                                      serializeParentDataObjectReferenced + "/" + HttpUtility.UrlEncode(Navigation.Uri));
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error handling row double click.");
            ex.Data.Add("PageMethod", "Dashboard/HandleRowDoubleClick()");
            OnError(ex);
        }
    }

    // apply ellipsis to specific columns
    private void OnCellRenderHandler(GridCellRenderEventArgs args)
    {
        args.Class = "custom-ellipsis";
    }

    // apply ellipsis to specific columns using OnRowRender
    private void OnRowRenderHandler(GridRowRenderEventArgs args)
    {
        args.Class = "custom-ellipsis";
    }

    private void ScheduleRowDoubleClick(GridRowClickEventArgs args)
    {
        try
        {
            dynamic model = args.Item;

            // Open the modal and pass data as parameters
            ShowModal<ScheduleItemView>(new ModalParameters
            {
                { "StartDateTime", model.Start.ToDateTime().ToUniversalTime().ToString("dd/MM/yyyy HH:mm:ss") },
                { "EndDateTime", model.End.ToDateTime().ToUniversalTime().ToString("dd/MM/yyyy HH:mm:ss") },
                { "Title", model.Title },
                { "Description", model.Description },
                { "JobNumber", model.JobNumber }
                // Add other properties as needed
            });
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error handling schedule row double click.");
            ex.Data.Add("PageMethod", "Dashboard/ScheduleRowDoubleClick()");
            OnError(ex);
        }
    }

    private void ShowModal<TModal>(ModalParameters parameters) where TModal : ComponentBase
    {
        try
        {
            var modalOptions = new ModalOptions
            {
                AnimationType = ModalAnimationType.FadeInOut,
                HideHeader = false,
                UseCustomLayout = true,
                Position = ModalPosition.Middle,
            };
            Modal.Show<TModal>("Schedule Info", parameters, modalOptions);
            //modal.Close();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error showing modal.");
            ex.Data.Add("PageMethod", "Dashboard/ShowModal()");
            OnError(ex);
        }
    }
}