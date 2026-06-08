using Concursus.API.Client.Classes;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Controls;
using Concursus.Components.Shared.Modals;
using Concursus.PWA.Helpers;
using Microsoft.AspNetCore.Components;
using Newtonsoft.Json;
using System.Collections;
using System.Web;
using Telerik.Blazor.Components;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class Dashboard : IAsyncDisposable
{
    protected MessageDisplay? _messageDisplay = new();

    private readonly CancellationTokenSource _dashboardCancellationTokenSource = new();
    private bool _dashboardLoadsStarted;

    private RecentItemResponse? _recentItems;
    private ScheduleItemsGetResponse? _scheduleItems;

    private bool _metricsLoading = true;
    private bool _recentItemsLoading = true;
    private bool _scheduleItemsLoading = true;

    private string? _metricsError;
    private string? _recentItemsError;
    private string? _scheduleItemsError;

    [Inject] public CymBuildModalService ModalService { get; set; } = default!;

    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    private List<DashboardMetric> Metrics { get; set; } = new();

    protected override Task OnInitializedAsync()
    {
        return Task.CompletedTask;
    }

    protected void StartDashboardDataLoads()
    {
        if (_dashboardLoadsStarted)
        {
            return;
        }

        _dashboardLoadsStarted = true;

        var cancellationToken = _dashboardCancellationTokenSource.Token;

        _ = LoadMetricsAsync(cancellationToken);
        _ = LoadRecentItemsAsync(UserService?.UserId ?? -1, cancellationToken);
        _ = LoadScheduleItemsAsync(cancellationToken);
    }

    private async Task LoadMetricsAsync(CancellationToken cancellationToken)
    {
        try
        {
            _metricsLoading = true;
            _metricsError = null;
            await InvokeAsync(StateHasChanged);

            var dashboardMetricsGetResponse = await CoreClient.DashboardMetricsGetAsync(
                new DashboardMetricsGetRequest(),
                cancellationToken: cancellationToken);

            if (cancellationToken.IsCancellationRequested)
            {
                return;
            }

            Metrics = dashboardMetricsGetResponse?.Metrics?.ToList() ?? new List<DashboardMetric>();
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            _metricsError = "Unable to load dashboard metrics.";

            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error loading dashboard metrics.";
            ex.Data["PageMethod"] = "Dashboard/LoadMetricsAsync()";

            await OnError(ex);
        }
        finally
        {
            if (!cancellationToken.IsCancellationRequested)
            {
                _metricsLoading = false;
                await InvokeAsync(StateHasChanged);
            }
        }
    }

    private async Task LoadRecentItemsAsync(int userId, CancellationToken cancellationToken)
    {
        try
        {
            _recentItemsLoading = true;
            _recentItemsError = null;
            await InvokeAsync(StateHasChanged);

            if (userId == -1)
            {
                _recentItems = new RecentItemResponse();
                return;
            }

            var recentItemRequest = new RecentItemRequest
            {
                UserId = userId
            };

            _recentItems = await CoreClient.RecentItemsGetAsync(
                recentItemRequest,
                cancellationToken: cancellationToken);
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            _recentItemsError = "Unable to load recent items.";

            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error getting recent items list.";
            ex.Data["PageMethod"] = "Dashboard/LoadRecentItemsAsync()";

            await OnError(ex);
        }
        finally
        {
            if (!cancellationToken.IsCancellationRequested)
            {
                _recentItemsLoading = false;
                await InvokeAsync(StateHasChanged);
            }
        }
    }

    private async Task LoadScheduleItemsAsync(CancellationToken cancellationToken)
    {
        try
        {
            _scheduleItemsLoading = true;
            _scheduleItemsError = null;
            await InvokeAsync(StateHasChanged);

            var scheduleItemsGetRequest = new ScheduleItemsGetRequest
            {
                CurrentUserOnly = true
            };

            var listOfScheduleItems = await CoreClient.ScheduleItemsGetAsync(
                scheduleItemsGetRequest,
                cancellationToken: cancellationToken);

            if (cancellationToken.IsCancellationRequested)
            {
                return;
            }

            if (!string.IsNullOrEmpty(listOfScheduleItems?.ErrorReturned))
            {
                throw new InvalidOperationException(listOfScheduleItems.ErrorReturned);
            }

            var earlyDate = DateTime.UtcNow.AddDays(-7);
            var lateDate = DateTime.UtcNow.AddDays(7);

            _scheduleItems = new ScheduleItemsGetResponse();

            if (listOfScheduleItems?.ScheduleItems is null)
            {
                return;
            }

            foreach (var item in listOfScheduleItems.ScheduleItems)
            {
                var start = item.Start.ToDateTime();

                if (start.IsBetweenTwoDates(earlyDate, lateDate))
                {
                    _scheduleItems.ScheduleItems.Add(item);
                }
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            _scheduleItemsError = "Unable to load scheduled items.";

            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error getting schedule items list.";
            ex.Data["PageMethod"] = "Dashboard/LoadScheduleItemsAsync()";

            await OnError(ex);
        }
        finally
        {
            if (!cancellationToken.IsCancellationRequested)
            {
                _scheduleItemsLoading = false;
                await InvokeAsync(StateHasChanged);
            }
        }
    }

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

        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(
                de => de.Key?.ToString() ?? "UnknownKey",
                de => de.Value!)
            : null;

        if (exceptionData != null)
        {
            foreach (var kvp in exceptionData)
            {
                Console.WriteLine($"    {kvp.Key} = {kvp.Value}");
            }
        }

        if (_messageDisplay is not null)
        {
            _messageDisplay.UpdateExceptionData(exceptionData);
            _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
            _messageDisplay.ShowError(true);
        }

        Console.WriteLine("Dashboard: MessageDisplay updated and error shown.");

        if (MessageType == ShowMessageType.Error)
        {
            try
            {
                var context = new
                {
                    ErrorMessage = error.Message,
                    PageMethod = error.Data.Contains("PageMethod")
                        ? error.Data["PageMethod"]?.ToString() ?? "UnknownMethod"
                        : "UnknownMethod",
                    StackTrace = error.StackTrace ?? "No stack trace",
                    AdditionalInfo = error.Data.Contains("AdditionalInfo")
                        ? error.Data["AdditionalInfo"]?.ToString() ?? "None"
                        : "None",
                    Data = error.Data.Cast<DictionaryEntry>()
                        .ToDictionary(
                            de => de.Key?.ToString() ?? "UnknownKey",
                            de => de.Value?.ToString() ?? "null")
                };

                var description = InteractionTracker.GetReplicationStepsFormatted(InteractionTracker);
                error.Data["UserInteractionLog"] = description;

                Console.WriteLine($"Dashboard: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage) && _messageDisplay is not null)
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

        await InvokeAsync(StateHasChanged);
    }

    protected void HandleClickOnMetric(string id)
    {
        try
        {
            switch (id)
            {
                case "_schedule":
                    Navigation.NavigateTo("/schedule");
                    break;
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error navigating to the page";
            ex.Data["PageMethod"] = "Dashboard/HandleClickOnMetric()";
            _ = OnError(ex);
        }
    }

    private void HandleRowDoubleClick(GridRowClickEventArgs args)
    {
        try
        {
            dynamic model = args.Item;

            var onRowDoubleClickHandler = !string.IsNullOrEmpty(model?.DetailPageUri)
                ? "@HandleRowDoubleClick"
                : null;

            if (onRowDoubleClickHandler == null || model == null)
            {
                return;
            }

            var serializeParentDataObjectReferenced = HttpUtility.UrlEncode(
                JsonConvert.SerializeObject(ParentDataObjectReference ?? new DataObjectReference("", "")));

            if (ParentDataObjectReference == null ||
                ParentDataObjectReference.EntityTypeGuid == Guid.Empty &&
                ParentDataObjectReference.DataObjectGuid == Guid.Empty)
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
            {
                Navigation.NavigateTo(
                    model.DetailPageUri + "/" +
                    ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(model.EntityTypeGuid).ToString() + "/" +
                    Guid.Empty.ToString() + "/" +
                    serializeParentDataObjectReferenced + "/" +
                    HttpUtility.UrlEncode(Navigation.Uri));
            }
            else
            {
                Navigation.NavigateTo(
                    model.DetailPageUri + "/" +
                    ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(model.RecordGuid).ToString() + "/" +
                    serializeParentDataObjectReferenced + "/" +
                    HttpUtility.UrlEncode(Navigation.Uri));
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error handling row double click.";
            ex.Data["PageMethod"] = "Dashboard/HandleRowDoubleClick()";
            _ = OnError(ex);
        }
    }

    private async Task OpenScheduleInfoAsync(ScheduleItem item)
    {
        try
        {
            if (item == null)
            {
                return;
            }

            var parameters = new Dictionary<string, object?>
            {
                { nameof(ScheduleItemView.StartDateTime), UiFormattingHelper.FormatDateForUI(item.Start.ToDateTime(), false) },
                { nameof(ScheduleItemView.EndDateTime), UiFormattingHelper.FormatDateForUI(item.End.ToDateTime(), false) },
                { nameof(ScheduleItemView.Title), item.Title ?? string.Empty },
                { nameof(ScheduleItemView.Description), item.Description ?? string.Empty },
                { nameof(ScheduleItemView.JobNumber), item.JobNumber ?? string.Empty }
            };

            await ModalService.ShowAsync<ScheduleItemView>(
                "Schedule Info",
                parameters);
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error opening schedule info.";
            ex.Data["PageMethod"] = "Dashboard/OpenScheduleInfoAsync()";
            await OnError(ex);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (!_dashboardCancellationTokenSource.IsCancellationRequested)
        {
            await _dashboardCancellationTokenSource.CancelAsync();
        }

        _dashboardCancellationTokenSource.Dispose();
    }
}