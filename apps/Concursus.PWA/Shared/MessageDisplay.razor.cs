using Microsoft.AspNetCore.Components;
using System.Collections;

namespace Concursus.PWA.Shared;

public partial class MessageDisplay
{
    /*
     * To Use this display you must pass an Exception to the ErrorMessage property. even if for information only.
     * To use a type you need to set the Data property of the Exception to the type you want to display.
     *
        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Information);
        ex.Data.Add("PageMethod", "LoginDisplay/UpdateUserService()");
        await OnError.InvokeAsync(ex);
     */

    public enum ShowMessageType
    {
        Error,
        Information,
        Success,
        Warning
    }

    [Parameter] public string? ErrorMessage { get; set; }

    [Parameter] public EventCallback<string> errorPropertyChanged { get; set; }

    [Parameter] public string? ErrorStackTrace { get; set; }

    [Parameter] public ShowMessageType? MessageType { get; set; } = ShowMessageType.Error;
    [Parameter] public string? PageMethod { get; set; } = "Not Set";
    [Parameter] public bool ShowStackTrace { get; set; } = false;
    [Parameter] public Dictionary<string, object>? ExceptionData { get; set; }

    private bool IsExpanded { get; set; } = false;

    private void ToggleExpand()
    {
        IsExpanded = !IsExpanded;
    }

    protected ShowMessageType? MessageTypeBinding
    {
        get
        {
            if (MessageType is not null) return MessageType;

            return ShowMessageType.Error;
        }
        set
        {
            errorPropertyChanged.InvokeAsync();
            MessageType = value ?? ShowMessageType.Error;
        }
    }

    public void SetMessage(string message, ShowMessageType type)
    {
        ErrorMessage = message;
        MessageType = type;
        IsVisible = true;           // Always show on message set
        StateHasChanged();          // Ensure UI updates
    }

    protected string? StringValueBinding
    {
        get => ErrorMessage;  // Display only the raw error message
        set
        {
            errorPropertyChanged.InvokeAsync();
            ErrorMessage = value;  // No longer appending PageMethod here
        }
    }

    private string CssClass => MessageType switch
    {
        ShowMessageType.Error => "alert alert-danger d-flex align-items-center alert-dismissible fade show",
        ShowMessageType.Warning => "alert alert-warning d-flex align-items-center alert-dismissible fade show",
        ShowMessageType.Information => "alert alert-info d-flex align-items-center alert-dismissible fade show",
        ShowMessageType.Success => "alert alert-success d-flex align-items-center alert-dismissible fade show",
        _ => "alert alert-danger d-flex align-items-center alert-dismissible fade show",
    };

    public void UpdateExceptionData(Dictionary<string, object>? data)
    {
        ExceptionData = data;
        StateHasChanged();
    }

    public void UpdateStackTrace(string? stackTrace)
    {
        ErrorStackTrace = stackTrace;
        StateHasChanged();
    }

    private bool IsVisible { get; set; } = false;

    public bool ShowError(bool showError)
    {
        IsVisible = showError;
        StateHasChanged();
        return IsVisible = showError;
    }

    protected void CloseError()
    {
        IsVisible = false;
        StateHasChanged();
    }

    protected override Task OnInitializedAsync()
    {
        if (string.IsNullOrEmpty(ErrorStackTrace))
        {
            ErrorStackTrace = "No additional details available.";
        }

        // Extract exception data if available
        if (ErrorMessage != null)
        {
            var ex = new Exception(ErrorMessage);
            ExceptionData = ex.Data.Count > 0
                ? ex.Data.Cast<DictionaryEntry>()
                         .Where(de => de.Value != null)  // Filter out null values
                         .ToDictionary(
                            de => de.Key?.ToString() ?? "UnknownKey",
                            de => de.Value!)
                : null;
        }

        return Task.CompletedTask;
    }

    private void HandleOnChange(ChangeEventArgs args)
    {
        if (args.Value is not null)
            StringValueBinding = args.Value.ToString();
    }
}