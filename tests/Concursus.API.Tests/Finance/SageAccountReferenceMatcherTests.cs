using Concursus.API.Services.Finance;
using Xunit;

namespace Concursus.API.Tests.Finance;

/// <summary>
/// CYB-555: SFA ignores the account filter, so the inbound sync keeps only rows for the
/// account it asked for. Values are the shapes seen on LIVE.
/// </summary>
public sealed class SageAccountReferenceMatcherTests
{
    [Theory]
    [InlineData("UCB002", "UCB002")]
    [InlineData("ucb002", "UCB002")]
    [InlineData(" UCB002 ", "UCB002")]
    [InlineData("00030607", "30607")]
    [InlineData("30607", "00030607")]
    public void IsRequestedAccount_SameAccount_IsKept(string rowAccount, string requestedAccount)
    {
        Assert.True(SageAccountReferenceMatcher.IsRequestedAccount(rowAccount, requestedAccount));
    }

    [Theory]
    [InlineData("12955", "30607")]
    [InlineData("UCB002", "SAV002")]
    [InlineData("300607", "30607")]
    public void IsRequestedAccount_AnotherAccount_IsIgnored(string rowAccount, string requestedAccount)
    {
        Assert.False(SageAccountReferenceMatcher.IsRequestedAccount(rowAccount, requestedAccount));
    }

    [Theory]
    [InlineData(null, "30607")]
    [InlineData("", "30607")]
    [InlineData("30607", null)]
    [InlineData("30607", " ")]
    public void IsRequestedAccount_NoAccountToCompare_IsKept(string? rowAccount, string? requestedAccount)
    {
        Assert.True(SageAccountReferenceMatcher.IsRequestedAccount(rowAccount, requestedAccount));
    }
}
