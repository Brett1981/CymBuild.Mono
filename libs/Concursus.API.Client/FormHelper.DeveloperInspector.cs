using Concursus.API.Core;

namespace Concursus.API.Client;

public partial class FormHelper
{
    public async Task<DeveloperInspectorResult> DeveloperInspectorGetAsync(
        DeveloperInspectorRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);

        try
        {
            return await _coreClient.DeveloperInspectorGetAsync(request, cancellationToken: cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            return new DeveloperInspectorResult
            {
                IsEnabled = false,
                IsSuccess = false,
                Message = ex.Message,
                ComponentName = request.ComponentName ?? string.Empty,
                Route = request.Route ?? string.Empty
            };
        }
    }
}
