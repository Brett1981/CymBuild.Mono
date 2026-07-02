using Concursus.API.Core;

namespace Concursus.API.Client;

public partial class FormHelper
{
    public async Task<UniversalSearchReply> UniversalSearchAsync(
        UniversalSearchRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        try
        {
            if (request.UserId <= 0 && UserService is not null)
            {
                request.UserId = UserService.UserId;
            }

            return await _coreClient.UniversalSearchAsync(request, cancellationToken: cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            return new UniversalSearchReply
            {
                IsSuccess = false,
                Message = ex.Message
            };
        }
    }
}
