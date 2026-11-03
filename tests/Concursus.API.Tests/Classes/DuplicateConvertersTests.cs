using Concursus.API.Classes;
using Xunit;

namespace Concursus.API.Tests.Classes;

public sealed class DuplicateConvertersTests
{
    [Fact]
    public void ConvertEFDuplicateAssetsToCoreDuplicateAssets_MapsGuidAndFormattedAddress()
    {
        var efAsset = new Concursus.EF.Types.DuplicateAssets
        {
            Guid = "11111111-1111-1111-1111-111111111111",
            FormattedAddress = "1 Test Street, Testville, TS1 1ST"
        };

        var result = Converters.ConvertEFDuplicateAssetsToCoreDuplicateAssets(efAsset);

        Assert.Equal(efAsset.Guid, result.Guid);
        Assert.Equal(efAsset.FormattedAddress, result.FormattedAddress);
    }

    [Fact]
    public void ConvertEFDuplicateAssetsToCoreDuplicateAssets_NullInput_ReturnsEmptyInstance()
    {
        var result = Converters.ConvertEFDuplicateAssetsToCoreDuplicateAssets(null!);

        Assert.NotNull(result);
        Assert.Equal(string.Empty, result.Guid);
        Assert.Equal(string.Empty, result.FormattedAddress);
    }

    [Fact]
    public void ConvertEFDuplicateAccountsToCoreDuplicateAccounts_MapsGuidAndDisplayName()
    {
        var efAccount = new Concursus.EF.Types.DuplicateAccounts
        {
            Guid = "22222222-2222-2222-2222-222222222222",
            DisplayName = "Acme Ltd"
        };

        var result = Converters.ConvertEFDuplicateAccountsToCoreDuplicateAccounts(efAccount);

        Assert.Equal(efAccount.Guid, result.Guid);
        // Note: the Core proto message exposes this field as "DisplaName" (typo preserved from core.proto).
        Assert.Equal(efAccount.DisplayName, result.DisplaName);
    }

    [Fact]
    public void ConvertEFDuplicateAccountsToCoreDuplicateAccounts_NullInput_ReturnsEmptyInstance()
    {
        var result = Converters.ConvertEFDuplicateAccountsToCoreDuplicateAccounts(null!);

        Assert.NotNull(result);
        Assert.Equal(string.Empty, result.Guid);
        Assert.Equal(string.Empty, result.DisplaName);
    }

    [Fact]
    public void ConvertEFDuplicateContactsToCoreDuplicateContacts_MapsGuidAndDisplayName()
    {
        var efContact = new Concursus.EF.Types.DuplicateContacts
        {
            Guid = "33333333-3333-3333-3333-333333333333",
            DisplayName = "Jane Doe"
        };

        var result = Converters.ConvertEFDuplicateContactsToCoreDuplicateContacts(efContact);

        Assert.Equal(efContact.Guid, result.Guid);
        Assert.Equal(efContact.DisplayName, result.DisplayName);
    }

    [Fact]
    public void ConvertEFDuplicateContactsToCoreDuplicateContacts_NullInput_ReturnsEmptyInstance()
    {
        var result = Converters.ConvertEFDuplicateContactsToCoreDuplicateContacts(null!);

        Assert.NotNull(result);
        Assert.Equal(string.Empty, result.Guid);
        Assert.Equal(string.Empty, result.DisplayName);
    }
}
