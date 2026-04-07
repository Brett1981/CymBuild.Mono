namespace Concursus.API.Interfaces;

public interface ILookupService
{
    Task<LookupSearchResult> SearchAsync(
        string searchText,
        string context,
        bool forceApi,
        CancellationToken cancellationToken = default);

    Task<LookupAddressRecord> ResolveAsync(
        string id,
        string context,
        CancellationToken cancellationToken = default);
}

public sealed class LookupSearchResult
{
    public List<LookupAddressSuggestion> AddressSuggestions { get; } = new();
    public List<LookupAddressRecord> PostcodeAddresses { get; } = new();
}

public sealed class LookupAddressSuggestion
{
    public string Id { get; set; } = string.Empty;
    public string Suggestion { get; set; } = string.Empty;
    public string Udprn { get; set; } = string.Empty;
    public string Urls { get; set; } = string.Empty;
}

public sealed class LookupAddressRecord
{
    public string Number { get; set; } = string.Empty;
    public string FormattedAddress { get; set; } = string.Empty;
    public string Line1 { get; set; } = string.Empty;
    public string Line2 { get; set; } = string.Empty;
    public string Town { get; set; } = string.Empty;
    public string County { get; set; } = string.Empty;
    public string Postcode { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string Uprn { get; set; } = string.Empty;
    public string LocalAuthority { get; set; } = string.Empty;
    public string AuthorityCode { get; set; } = string.Empty;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}