using Concursus.API.Core;
using Concursus.API.Interfaces;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    public override async Task<AddressLookupSearchResponse> AddressLookupSearch(
        AddressLookupSearchRequest request,
        ServerCallContext context)
    {
        var response = new AddressLookupSearchResponse();

        try
        {
            var result = await _lookupService.SearchAsync(
                request.SearchText,
                request.Context,
                request.ForceApi,
                context.CancellationToken);

            foreach (var suggestion in result.AddressSuggestions)
            {
                response.AddressSuggestions.Add(new LookupAddressSuggestionContract
                {
                    Id = suggestion.Id ?? string.Empty,
                    Suggestion = suggestion.Suggestion ?? string.Empty,
                    Udprn = suggestion.Udprn ?? string.Empty,
                    Urls = suggestion.Urls ?? string.Empty
                });
            }

            foreach (var address in result.PostcodeAddresses)
            {
                response.PostcodeAddresses.Add(MapLookupAddressRecord(address));
            }
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
        }

        return response;
    }

    public override async Task<AddressLookupResolveResponse> AddressLookupResolve(
        AddressLookupResolveRequest request,
        ServerCallContext context)
    {
        var response = new AddressLookupResolveResponse();

        try
        {
            var address = await _lookupService.ResolveAsync(
                request.Id,
                request.Context,
                context.CancellationToken);

            response.Address = MapLookupAddressRecord(address);
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
        }

        return response;
    }

    private static LookupAddressRecordContract MapLookupAddressRecord(LookupAddressRecord source)
    {
        return new LookupAddressRecordContract
        {
            Number = source.Number ?? string.Empty,
            FormattedAddress = source.FormattedAddress ?? string.Empty,
            Line1 = source.Line1 ?? string.Empty,
            Line2 = source.Line2 ?? string.Empty,
            Town = source.Town ?? string.Empty,
            County = source.County ?? string.Empty,
            Postcode = source.Postcode ?? string.Empty,
            Country = source.Country ?? string.Empty,
            Uprn = source.Uprn ?? string.Empty,
            LocalAuthority = source.LocalAuthority ?? string.Empty,
            AuthorityCode = source.AuthorityCode ?? string.Empty,
            HasLatitude = source.Latitude.HasValue,
            Latitude = source.Latitude.GetValueOrDefault(),
            HasLongitude = source.Longitude.HasValue,
            Longitude = source.Longitude.GetValueOrDefault()
        };
    }
}