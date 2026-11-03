using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-415 / CYB-465 / CYB-468 (LIVE 26.2 fixes 5ec9df91, dd4a1af9, d256d7db; missing from release/26.4):
// - the file-processing SignalR hub must not block (or break) EditPage initialisation;
// - the initial form state is awaited, not fired with Task.Run(FormSubmitted);
// - a windowed record created in a pop-out (e.g. a Client Account from an Enquiry) is refreshed in
//   place after save, never re-initialised with OnInitializedAsync (which reset it to a blank record).
public sealed class Cyb415EditPageInitialisationSourceContractTests
{
    private static readonly string Source = File.ReadAllText(RepositoryLayout.PathFromRoot(
        ["apps", "Concursus.PWA", "Shared", "EditPage.razor.cs"]));

    [Fact]
    public void OnInitializedAsync_DoesNotWaitForTheFileProcessingHub()
    {
        var init = Method("protected override async Task OnInitializedAsync()");

        Assert.DoesNotContain("hubConnection.StartAsync", init, StringComparison.Ordinal);
        Assert.DoesNotContain("new HubConnectionBuilder()", init, StringComparison.Ordinal);
        Assert.Contains("_ = InvokeAsync(TryInitialiseFileProcessingHubAsync);", init, StringComparison.Ordinal);

        var hub = Method("private async Task TryInitialiseFileProcessingHubAsync()");
        Assert.Contains("new CancellationTokenSource(TimeSpan.FromSeconds(5))", hub, StringComparison.Ordinal);
        Assert.Contains("hubConnection.StartAsync(startupTimeout.Token)", hub, StringComparison.Ordinal);
    }

    [Fact]
    public void InitialFormState_IsAwaitedRatherThanFireAndForget()
    {
        Assert.DoesNotMatch(new Regex(@"Task\.Run\(\s*async\s*\(\)\s*=>\s*\{\s*await\s+FormSubmitted\("), Source);
        Assert.Contains("await InitialiseLoadedEditStateAsync();", Method("protected override async Task OnInitializedAsync()"), StringComparison.Ordinal);
    }

    [Fact]
    public void WindowedNewRecord_IsRefreshedInPlaceAfterSave()
    {
        var reload = Method("private async Task ReloadDataForNewRecordAsync()");

        Assert.Contains("await RefreshCurrentSavedWindowedRecordAsync();", reload, StringComparison.Ordinal);

        // Every OnInitializedAsync() re-run must be guarded by !Windowed.
        foreach (Match call in Regex.Matches(reload, @"await OnInitializedAsync\(\);"))
        {
            var before = reload[..call.Index];
            var guard = Math.Max(before.LastIndexOf("if (!Windowed)", StringComparison.Ordinal),
                                 before.LastIndexOf("else if (!Windowed)", StringComparison.Ordinal));
            var otherBranch = before.LastIndexOf("else", StringComparison.Ordinal);
            Assert.True(guard >= 0 && guard >= otherBranch - 5, "OnInitializedAsync() must only re-run for non-windowed records.");
        }
    }

    [Fact]
    public void EditState_IsRebasedAfterASuccessfulSave()
    {
        Assert.Contains("private async Task RebaseEditStateAfterSuccessfulSaveAsync(bool refreshFromServer)", Source, StringComparison.Ordinal);
        Assert.Contains("await RebaseEditStateAfterSuccessfulSaveAsync(refreshFromServer: false);", Source, StringComparison.Ordinal);
    }

    private static string Method(string signature)
    {
        var start = Source.IndexOf(signature, StringComparison.Ordinal);
        Assert.True(start >= 0, $"'{signature}' not found in EditPage.razor.cs.");

        var open = Source.IndexOf('{', start);
        var depth = 0;
        for (var i = open; i < Source.Length; i++)
        {
            if (Source[i] == '{') depth++;
            else if (Source[i] == '}' && --depth == 0) return Source[start..(i + 1)];
        }

        return Source[start..];
    }
}
