using Concursus.API.Client.Classes;
using Concursus.Components.Shared.Services;
using Concursus.PWA.Services;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using System.Collections;
using static Concursus.PWA.Shared.MessageDisplay;
using UserGroup = Concursus.API.Client.Models.UserGroup;

namespace Concursus.PWA.Shared;

public partial class LoginDisplay
{
    protected MessageDisplay? _messageDisplay;
    [CascadingParameter] public SyncQueueState? SyncQueueCount { get; set; }
    public string PageMethod { get; set; } = "Not Set";
    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;

    private string UserName { get; set; } = "";

    public void BeginLogOut()
    {
        Navigation.NavigateToLogout("authentication/logout");
    }

    public void Dispose()
    {
        AuthenticationStateProvider.AuthenticationStateChanged -= HandleAuthenticationStateChanged;
        if (SyncQueueState != null)
            SyncQueueState.OnChange -= HandleSyncQueueUpdate;
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("LoginDisplay: Error message is empty. Aborting.");
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"LoginDisplay: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("LoginDisplay: MessageType not found in error.Data. Defaulted to Error.");
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

        Console.WriteLine("LoginDisplay: MessageDisplay updated and error shown.");

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
                Console.WriteLine($"LoginDisplay: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("LoginDisplay: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"LoginDisplay: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
    }

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
    protected override void OnInitialized()
    {
        if (SyncQueueState != null)
            SyncQueueState.OnChange += HandleSyncQueueUpdate;
    }

    private void HandleSyncQueueUpdate()
    {
        InvokeAsync(StateHasChanged);
    }

    protected override async Task OnInitializedAsync()
    {
        var authState = await AuthenticationStateProvider.GetAuthenticationStateAsync();
        await UpdateUserNameAsync(authState);

        // create a Handler to capture the authentication state changes
        AuthenticationStateProvider.AuthenticationStateChanged += HandleAuthenticationStateChanged;
    }

    protected override void OnParametersSet()
    {
        StateHasChanged(); // Ensure re-render when value changes
    }

    private async void HandleAuthenticationStateChanged(Task<AuthenticationState> authStateTask)
    {
        var authState = await authStateTask.ConfigureAwait(false);
        await UpdateUserNameAsync(authState);
        StateHasChanged(); // Notify the component to re-render
    }

    private async Task UpdateUserNameAsync(AuthenticationState authState)
    {
        try
        {
            UserName = authState.User?.Identity?.Name ?? "";

            if (string.IsNullOrEmpty(UserName))
            {
                return;
            }

            var userInfo = await CoreClient.UserInfoGetAsync(new API.Core.UserInfoGetRequest());

            if (userInfo == null)
            {
                return;
            }
            if (!string.IsNullOrEmpty(userInfo.ErrorReturned))
            {
                throw new Exception(userInfo.ErrorReturned);
            }

            UpdateUserService(userInfo.User);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Unable to update user information.");
            ex.Data.Add("PageMethod", "LoginDisplay/UpdateUserNameAsync()");
            OnError(ex);
        }
    }

    private void UpdateUserService(API.Core.User user)
    {
        try
        {
            UserService.UserGroups = user.UserGroups?
                .Select(group => new UserGroup
                {
                    GroupGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(group.GroupGuid).ToString(),
                    GroupId = group.GroupId,
                    GroupName = group.GroupName,
                    Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(group.Guid).ToString(),
                    Id = group.Id,
                    RowVersion = group.RowVersion,
                    UserId = group.UserId,
                    UserGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(group.UserGuid).ToString()
                })
                .ToList() ?? new List<UserGroup>();

            UserService.UserId = user.UserId;
            UserService.FirstName = user.FirstName;
            UserService.LastName = user.LastName;
            UserService.Email = user.Email;
            UserService.MobileNo = user.MobileNo;
            UserService.OnHoliday = user.OnHoliday;
            UserService.Guid = user.Guid;
            UserService.FullName = user.FullName;
            UserService.JobTitle = user.JobTitle;
            UserService.BillableRate = (decimal)user.BillableRate;
            UserService.Signature = user.Signature.ToByteArray();

            UserService.UserName = UserName;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Unable to update user service.");
            ex.Data.Add("PageMethod", "LoginDisplay/UpdateUserService()");
            OnError(ex);
        }
    }
}