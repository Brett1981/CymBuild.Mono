using System.Reflection;
using Concursus.PWA.Shared;
using Xunit;

namespace Concursus.PWA.Tests;

// CYB-551: OnClickHandler's nested try/catch blocks both record the same three
// Exception.Data keys on the same exception object before the outer catch used to
// rethrow. Exception.Data.Add throws ArgumentException on a duplicate key, and that
// second, unrelated exception - not the original error - was what escaped the Blazor
// event handler and tripped EditPage's CustomErrorBoundary, wiping the whole record.
// SetExceptionData is the fix's core mechanism (an idempotent Data.Contains-checked
// write); these tests characterise it directly via reflection, the same approach
// DuplicateCheckButtonTests uses for ButtonMenu's private helpers.
public sealed class ButtonMenuTests
{
    private static readonly Type ComponentType = typeof(ButtonMenu);

    private static void InvokeSetExceptionData(Exception exception, string key, object value)
    {
        var method = ComponentType.GetMethod("SetExceptionData", BindingFlags.Static | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("SetExceptionData method not found.");

        method.Invoke(null, new object[] { exception, key, value });
    }

    [Fact]
    public void SetExceptionData_SameKeyTwice_DoesNotThrow()
    {
        // This is exactly the shape that used to crash: OnClickHandler's inner catch sets
        // these keys and reports the exception via OnError, then (before the fix) rethrew
        // to an outer catch that tried to set the same keys again via the raw Data.Add API.
        var exception = new InvalidOperationException("Value of work must be set!");

        var recordedException = Record.Exception(() =>
        {
            InvokeSetExceptionData(exception, "MessageType", MessageDisplay.ShowMessageType.Error);
            InvokeSetExceptionData(exception, "AdditionalInfo", "An error occurred while trying to execute the action menu item.");
            InvokeSetExceptionData(exception, "PageMethod", "ButtonMenu/OnClickHandler()");

            InvokeSetExceptionData(exception, "MessageType", MessageDisplay.ShowMessageType.Error);
            InvokeSetExceptionData(exception, "AdditionalInfo", "An error occurred while trying to execute the action menu item.");
            InvokeSetExceptionData(exception, "PageMethod", "ButtonMenu/OnClickHandler()");
        });

        Assert.Null(recordedException);
    }

    [Fact]
    public void SetExceptionData_SameKeyTwice_SecondValueWins()
    {
        var exception = new InvalidOperationException("test");

        InvokeSetExceptionData(exception, "PageMethod", "First");
        InvokeSetExceptionData(exception, "PageMethod", "Second");

        Assert.Equal("Second", exception.Data["PageMethod"]);
    }

    [Fact]
    public void SetExceptionData_NewKey_AddsValue()
    {
        var exception = new InvalidOperationException("test");

        InvokeSetExceptionData(exception, "MessageType", MessageDisplay.ShowMessageType.Warning);

        Assert.Equal(MessageDisplay.ShowMessageType.Warning, exception.Data["MessageType"]);
    }

    // CYB-548: a double-click (or a slow-response retry) on a task-menu item - e.g. two
    // "Request Invoice" clicks - must not fire the action twice. OnNativeMenuItemClicked's
    // _isExecutingMenuItem guard is the client-side defense-in-depth for this (the server-side
    // fix is the UPDLOCK/HOLDLOCK lock added to SJob.ActivityCreateInvoiceRequest). These tests
    // characterise the guard directly via reflection, since OnClickHandler itself needs a full
    // set of injected services ([Inject] coreClient/NavManager/etc.) to run for real.

    private static void SetIsExecutingMenuItem(ButtonMenu component, bool value)
    {
        var field = ComponentType.GetField("_isExecutingMenuItem", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("_isExecutingMenuItem field not found.");

        field.SetValue(component, value);
    }

    private static bool GetIsExecutingMenuItem(ButtonMenu component)
    {
        var field = ComponentType.GetField("_isExecutingMenuItem", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("_isExecutingMenuItem field not found.");

        return (bool)field.GetValue(component)!;
    }

    private static bool GetIsTaskMenuOpen(ButtonMenu component)
    {
        var property = ComponentType.GetProperty("IsTaskMenuOpen", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("IsTaskMenuOpen property not found.");

        return (bool)property.GetValue(component)!;
    }

    private static void SetIsTaskMenuOpen(ButtonMenu component, bool value)
    {
        var property = ComponentType.GetProperty("IsTaskMenuOpen", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("IsTaskMenuOpen property not found.");

        property.SetValue(component, value);
    }

    private static Task InvokeOnNativeMenuItemClicked(ButtonMenu component, API.Client.MenuItem item)
    {
        var method = ComponentType.GetMethod("OnNativeMenuItemClicked", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("OnNativeMenuItemClicked method not found.");

        return (Task)method.Invoke(component, new object[] { item })!;
    }

    [Fact]
    public async Task OnNativeMenuItemClicked_AlreadyExecuting_IgnoresSecondClick()
    {
        var component = new ButtonMenu();
        SetIsExecutingMenuItem(component, true);
        SetIsTaskMenuOpen(component, true);

        await InvokeOnNativeMenuItemClicked(component, new API.Client.MenuItem { Text = "Request Invoice" });

        // A blocked second click must never reach CloseTaskMenu() or OnClickHandler - both the
        // busy flag and the task-menu-open state are left exactly as they were.
        Assert.True(GetIsExecutingMenuItem(component));
        Assert.True(GetIsTaskMenuOpen(component));
    }

    // A complementary "guard always resets, even on failure" test is intentionally not
    // included here: the non-blocked path calls the pre-existing CloseTaskMenu(), which calls
    // StateHasChanged() before the guard is even set - that throws outside a real Blazor render
    // tree (no render handle assigned), and this repo has no bUnit-style harness to provide one.
    // The reset behaviour (try/finally around OnClickHandler) was verified by direct code
    // reading and by the cymbuild-architecture-reviewer pass on this change, not by this test.
}
