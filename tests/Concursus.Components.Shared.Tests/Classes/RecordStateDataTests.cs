using Concursus.API.Client.Models;
using Concursus.Components.Shared.Classes;

namespace Concursus.Components.Shared.Tests.Classes;

// RecordStateData is what EditPage.HandleExitAsync's Windowed branch reads (via
// OriginalGuid/ChildGuid/OriginalItem) to decide whether the record just closed in a modal
// should update the parent grid's bound selection. See
// CymBuild.Architecture.Tests.EditPageWindowedExitStateResetSourceContractTests and
// Concursus.PWA.Tests.PWAFunctionsTests for the CYB-484 regression this guards.
public sealed class RecordStateDataTests
{
    [Fact]
    public void Constructor_ParsesValidGuidsFromEachStateServiceField()
    {
        var originalGuid = Guid.NewGuid();
        var childGuid = Guid.NewGuid();
        var originalItem = Guid.NewGuid();
        var childItem = Guid.NewGuid();
        var originalType = Guid.NewGuid();
        var childType = Guid.NewGuid();

        var stateService = new StateService
        {
            OriginalRecordGuid = originalGuid.ToString(),
            ChildRecordGuid = childGuid.ToString(),
            OriginalRecordItem = originalItem.ToString(),
            ChildRecordItem = childItem.ToString(),
            OriginalRecordType = originalType.ToString(),
            ChildRecordType = childType.ToString()
        };

        var recordData = new RecordStateData(stateService);

        Assert.Equal(originalGuid, recordData.OriginalGuid);
        Assert.Equal(childGuid, recordData.ChildGuid);
        Assert.Equal(originalItem, recordData.OriginalItem);
        Assert.Equal(childItem, recordData.ChildItem);
        Assert.Equal(originalType, recordData.OriginalRecordType);
        Assert.Equal(childType, recordData.ChildRecordType);
    }

    [Fact]
    public void Constructor_DefaultStateService_ProducesAllEmptyGuids()
    {
        // A freshly-reset (or never-populated) StateService - e.g. immediately after
        // PWAFunctions.ResetStateService - must read back as "no bound-selection update
        // needed", not as a record needing to be pushed into the parent grid.
        var recordData = new RecordStateData(new StateService());

        Assert.Equal(Guid.Empty, recordData.OriginalGuid);
        Assert.Equal(Guid.Empty, recordData.ChildGuid);
        Assert.Equal(Guid.Empty, recordData.OriginalItem);
        Assert.Equal(Guid.Empty, recordData.ChildItem);
        Assert.Equal(Guid.Empty, recordData.OriginalRecordType);
        Assert.Equal(Guid.Empty, recordData.ChildRecordType);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("not-a-guid")]
    public void Constructor_InvalidOrMissingValues_FallBackToEmptyGuid(string? invalidValue)
    {
        var stateService = new StateService
        {
            OriginalRecordGuid = invalidValue!,
            ChildRecordGuid = invalidValue!
        };

        var recordData = new RecordStateData(stateService);

        Assert.Equal(Guid.Empty, recordData.OriginalGuid);
        Assert.Equal(Guid.Empty, recordData.ChildGuid);
    }

    [Fact]
    public void HandleExitAsyncBoundSelectionGuard_IsFalse_WhenChildRecordGuidWasNeverSet()
    {
        // Mirrors EditPage.HandleExitAsync's Windowed-branch guard:
        //   OriginalGuid != Empty && ChildGuid != Empty && OriginalGuid != ChildGuid && OriginalItem != Empty
        // This is the "New" record case (RecordGuid was Guid.Empty, so PrepareStateChanges never
        // populated ChildRecordGuid): the guard must stay false so no bound-selection update runs
        // before stateService is reset.
        var stateService = new StateService
        {
            OriginalRecordGuid = Guid.NewGuid().ToString(),
            OriginalRecordItem = Guid.NewGuid().ToString()
        };

        var recordData = new RecordStateData(stateService);
        var guardIsTrue =
            recordData.OriginalGuid != Guid.Empty &&
            recordData.ChildGuid != Guid.Empty &&
            recordData.OriginalGuid != recordData.ChildGuid &&
            recordData.OriginalItem != Guid.Empty;

        Assert.False(guardIsTrue);
    }

    [Fact]
    public void HandleExitAsyncBoundSelectionGuard_IsTrue_WhenViewingADistinctChildRecordWithAnIdentifyingItem()
    {
        var stateService = new StateService
        {
            OriginalRecordGuid = Guid.NewGuid().ToString(),
            ChildRecordGuid = Guid.NewGuid().ToString(),
            OriginalRecordItem = Guid.NewGuid().ToString()
        };

        var recordData = new RecordStateData(stateService);
        var guardIsTrue =
            recordData.OriginalGuid != Guid.Empty &&
            recordData.ChildGuid != Guid.Empty &&
            recordData.OriginalGuid != recordData.ChildGuid &&
            recordData.OriginalItem != Guid.Empty;

        Assert.True(guardIsTrue);
    }
}
