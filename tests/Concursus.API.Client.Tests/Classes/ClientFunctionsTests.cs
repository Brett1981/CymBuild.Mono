using Concursus.API.Client.Classes;
using Concursus.API.Client.Models;
using Google.Protobuf.Collections;

namespace Concursus.API.Client.Tests.Classes;

public sealed class ClientFunctionsTests
{
    [Fact]
    public void ParseGuid_ReturnsParsedGuidOrEmpty()
    {
        var expected = Guid.NewGuid();

        Assert.Equal(expected, ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(expected.ToString()));
        Assert.Equal(Guid.Empty, ClientFunctions.ParseAndReturnEmptyGuidIfInvalid("invalid"));
    }

    [Fact]
    public void ParseGuidList_PreservesPositionAndUsesEmptyForInvalidValues()
    {
        var expected = Guid.NewGuid();
        var values = new RepeatedField<string>
        {
            expected.ToString(),
            "invalid"
        };

        var result = ClientFunctions.ParseAndReturnListEmptyGuidIfInvalid(values);

        Assert.Equal(new[] { expected, Guid.Empty }, result);
        Assert.Empty(ClientFunctions.ParseAndReturnListEmptyGuidIfInvalid(null));
    }

    [Theory]
    [InlineData(" report?.pdf ", "report.pdf")]
    [InlineData("a/b:c*d\"e<f>g|h#i%j.txt", "abcdefghij.txt")]
    [InlineData("...safe...", "safe")]
    public void SanitizeFileName_RemovesIllegalCharactersAndBoundaryPunctuation(
        string input,
        string expected)
    {
        Assert.Equal(expected, ClientFunctions.SanitizeFileName(input));
    }

    [Fact]
    public void IsBetweenTwoDates_UsesExclusiveBoundaries()
    {
        var start = new DateTime(2026, 8, 5, 10, 0, 0, DateTimeKind.Utc);
        var end = start.AddHours(2);

        Assert.False(start.IsBetweenTwoDates(start, end));
        Assert.True(start.AddMinutes(1).IsBetweenTwoDates(start, end));
        Assert.False(end.IsBetweenTwoDates(start, end));
    }

    [Fact]
    public void ResetStateService_ClearsAllRecordNavigationValues()
    {
        var state = new StateService
        {
            OriginalRecordItem = "item",
            OriginalRecordType = "type",
            OriginalRecordGuid = "guid",
            ChildRecordItem = "child-item",
            ChildRecordType = "child-type",
            ChildRecordGuid = "child-guid"
        };

        ClientFunctions.ResetStateService(state);

        Assert.Equal(Guid.Empty.ToString(), state.OriginalRecordItem);
        Assert.Equal(Guid.Empty.ToString(), state.OriginalRecordType);
        Assert.Equal(Guid.Empty.ToString(), state.OriginalRecordGuid);
        Assert.Equal(Guid.Empty.ToString(), state.ChildRecordItem);
        Assert.Equal(Guid.Empty.ToString(), state.ChildRecordType);
        Assert.Equal(Guid.Empty.ToString(), state.ChildRecordGuid);
    }
}
