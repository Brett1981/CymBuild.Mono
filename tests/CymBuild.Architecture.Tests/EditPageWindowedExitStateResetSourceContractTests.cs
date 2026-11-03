using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// Regression coverage for CYB-484: "reopen previously viewed record, close it, click New"
// returned every workflow status instead of just the statuses reachable from the record's
// current status.
//
// Root cause: EditPage.razor.cs's HandleExitAsync() has two exit paths - Windowed (modal
// grids: DataObjectTransition history, and every other grid whose detail opens in a modal)
// and non-Windowed (full-page navigation). Only the non-Windowed path called
// PWAFunctions.ResetStateService(stateService) on exit. Closing a Windowed modal left
// stateService.ChildRecordGuid/OriginalRecordGuid pointing at whatever record was last
// viewed/edited in that modal.
//
// ShoreInput.razor.cs's workflow-status lookup (LoadNativeLookupItemsAsync) falls back to
// stateService.ChildRecordGuid whenever the field's own RecordGuid is Guid.Empty - which is
// exactly the case for a brand-new record opened via a grid's "New" button. Without the
// reset, that fallback resolved to the *previous* modal's real, already-saved record Guid
// instead of Guid.Empty, so SCore.WorkflowGetNextStatus treated the new record as an edit of
// an existing transition and returned its "viewing history" branch (all statuses) rather than
// the current-status-scoped ones.
//
// This is a generic Windowed-modal state leak, not specific to the workflow-status dropdown -
// any lookup relying on the empty-RecordGuid fallback for a "New" record opened after viewing
// another record in the same grid is affected. Fix: reset stateService in the Windowed branch
// too, once the background continuation has used it to update the parent grid's bound
// selection.
//
// The same leak also had two other exit paths that never went through HandleExitAsync at all:
// - EditPage.PerformACanceledState's Windowed branch: the "no changes, just exit" and
//   "Save & Exit with no changes" short-circuits in FormSubmitted call this directly instead
//   of HandleExitAsync.
// - DynamicGridView.CloseWindow: the detail panel's own "Close" (X) button in the panel header
//   calls this directly, bypassing EditPage entirely.
// Both needed the identical PWAFunctions.ResetStateService(stateService) fix.
public sealed class EditPageWindowedExitStateResetSourceContractTests
{
    [Fact]
    public void HandleExitAsync_WindowedBranch_ResetsStateServiceBeforeReturning()
    {
        var codeBehind = ReadPwaSharedFile("EditPage.razor.cs");
        var windowedBranch = ExtractHandleExitAsyncWindowedBranch(codeBehind);

        Assert.Contains(
            "PWAFunctions.ResetStateService(stateService)",
            windowedBranch,
            StringComparison.Ordinal);
    }

    [Fact]
    public void HandleExitAsync_WindowedBranch_ResetsStateServiceAfterReadingItForTheBoundSelectionUpdate()
    {
        var codeBehind = ReadPwaSharedFile("EditPage.razor.cs");
        var windowedBranch = ExtractHandleExitAsyncWindowedBranch(codeBehind);

        var recordStateDataIndex = windowedBranch.IndexOf(
            "new RecordStateData(stateService)",
            StringComparison.Ordinal);
        var resetIndex = windowedBranch.IndexOf(
            "PWAFunctions.ResetStateService(stateService)",
            StringComparison.Ordinal);

        Assert.True(
            recordStateDataIndex >= 0,
            "HandleExitAsync's Windowed branch must still read RecordStateData(stateService) to decide " +
            "whether to update the parent grid's bound selection.");
        Assert.True(
            resetIndex > recordStateDataIndex,
            "PWAFunctions.ResetStateService(stateService) must run after RecordStateData(stateService) has " +
            "been read - resetting first would always make the bound-selection guard fields empty.");
    }

    [Fact]
    public void HandleExitAsync_NonWindowedBranch_StillResetsStateService()
    {
        var codeBehind = ReadPwaSharedFile("EditPage.razor.cs");
        var nonWindowedBranch = ExtractHandleExitAsyncNonWindowedBranch(codeBehind);

        Assert.Contains(
            "PWAFunctions.ResetStateService(stateService)",
            nonWindowedBranch,
            StringComparison.Ordinal);
    }

    // FormSubmitted's "no changes, just exit" and "Save & Exit with no changes" short-circuits
    // call PerformACanceledState directly instead of HandleExitAsync - this leak needed the
    // identical fix in a second place.
    [Fact]
    public void PerformACanceledState_WindowedBranch_ResetsStateService()
    {
        var codeBehind = ReadPwaSharedFile("EditPage.razor.cs");
        var method = ExtractMethodBody(codeBehind, "PerformACanceledState");
        var windowedBranch = ExtractBranch(method, "if (Windowed)", "else");

        Assert.Contains(
            "PWAFunctions.ResetStateService(stateService)",
            windowedBranch,
            StringComparison.Ordinal);
    }

    [Fact]
    public void PerformACanceledState_NonWindowedBranch_StillResetsStateService()
    {
        var codeBehind = ReadPwaSharedFile("EditPage.razor.cs");
        var method = ExtractMethodBody(codeBehind, "PerformACanceledState");
        var elseIndex = method.IndexOf("else", StringComparison.Ordinal);
        Assert.True(elseIndex >= 0, "PerformACanceledState must have an else branch for non-Windowed exits.");

        Assert.Contains(
            "PWAFunctions.ResetStateService(stateService)",
            method[elseIndex..],
            StringComparison.Ordinal);
    }

    // The detail panel's own "Close" (X) button (DynamicGridView.razor's
    // dynamic-grid-view-v2-detail-panel-close button) calls DynamicGridView.CloseWindow()
    // directly - it never routes through EditPage at all, so it needed the fix in a third,
    // unrelated component.
    [Fact]
    public void DynamicGridView_CloseWindow_ResetsStateService()
    {
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");
        var method = ExtractMethodBody(codeBehind, "CloseWindow");

        Assert.Contains(
            "PWAFunctions.ResetStateService(stateService)",
            method,
            StringComparison.Ordinal);
    }

    [Fact]
    public void DynamicGridView_InjectsStateServiceForCloseWindowToUse()
    {
        var razor = File.ReadAllText(
            RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "DynamicGridView.razor"));

        Assert.Contains("@inject StateService stateService", razor, StringComparison.Ordinal);
    }

    private static string ExtractHandleExitAsyncWindowedBranch(string codeBehind)
    {
        var method = ExtractMethodBody(codeBehind, "HandleExitAsync");
        return ExtractBranch(method, "if (Windowed)", "else");
    }

    private static string ExtractHandleExitAsyncNonWindowedBranch(string codeBehind)
    {
        var method = ExtractMethodBody(codeBehind, "HandleExitAsync");
        var elseIndex = method.IndexOf("else", StringComparison.Ordinal);
        Assert.True(elseIndex >= 0, "HandleExitAsync must have an else branch for non-Windowed exits.");
        return method[elseIndex..];
    }

    private static string ExtractBranch(string method, string branchStart, string branchEnd)
    {
        var startIndex = method.IndexOf(branchStart, StringComparison.Ordinal);
        Assert.True(startIndex >= 0, $"Could not find '{branchStart}' inside HandleExitAsync.");

        var endIndex = method.IndexOf(branchEnd, startIndex, StringComparison.Ordinal);
        Assert.True(endIndex > startIndex, $"Could not find '{branchEnd}' after '{branchStart}' inside HandleExitAsync.");

        return method[startIndex..endIndex];
    }

    private static string ExtractMethodBody(string codeBehind, string methodName)
    {
        var signatureMatch = Regex.Match(
            codeBehind,
            $@"(?:private|protected|public|internal)\s+(?:async\s+)?(?:Task|void)\s+{Regex.Escape(methodName)}\s*\([^)]*\)\s*\{{",
            RegexOptions.Compiled);

        Assert.True(signatureMatch.Success, $"Could not find method '{methodName}'.");

        var bodyStart = signatureMatch.Index + signatureMatch.Length - 1; // include the opening brace
        var depth = 0;
        for (var i = bodyStart; i < codeBehind.Length; i++)
        {
            if (codeBehind[i] == '{')
            {
                depth++;
            }
            else if (codeBehind[i] == '}')
            {
                depth--;
                if (depth == 0)
                {
                    return codeBehind[bodyStart..(i + 1)];
                }
            }
        }

        throw new InvalidOperationException($"Could not find the closing brace for method '{methodName}'.");
    }

    private static string ReadPwaSharedFile(string fileName)
    {
        return File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                fileName));
    }
}
