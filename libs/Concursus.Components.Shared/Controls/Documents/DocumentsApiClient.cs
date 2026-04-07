using Concursus.API.Client;
using Concursus.API.Core;
using Microsoft.Extensions.Configuration;

namespace Concursus.Components.Shared.Controls.Documents;

internal sealed class DocumentsApiClient
{
    private readonly FormHelper _formHelper;
    private readonly IConfiguration _configuration;

    public DocumentsApiClient(FormHelper formHelper, IConfiguration configuration)
    {
        _formHelper = formHelper ?? throw new ArgumentNullException(nameof(formHelper));
        _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
    }

    public async Task<IReadOnlyList<DocumentsNavigationItem>> GetNavigationAsync(
        int userId,
        string recordGuid,
        int entityTypeId,
        CancellationToken cancellationToken = default)
    {
        var response = await _formHelper.DocumentsNavigationGetAsync(
            userId,
            recordGuid,
            entityTypeId,
            cancellationToken);

        return response.Items
            .OrderBy(x => x.NavigationSortOrder)
            .ThenBy(x => x.RecordSortValue)
            .ThenBy(x => x.RecordTitle)
            .ToList();
    }

    public async Task<DocumentsLocation> ResolveLocationAsync(
        string recordGuid,
        int entityTypeId,
        string entityQueryGuid,
        string? sharePointUrlHint = null,
        CancellationToken cancellationToken = default)
    {
        return await _formHelper.DocumentsResolveAsync(
            recordGuid,
            entityTypeId,
            entityQueryGuid,
            sharePointUrlHint,
            cancellationToken);
    }

    public async Task<DocumentsListResponse> ListAsync(
        string driveId,
        string folderId,
        int pageSize = 100,
        string? pageToken = null,
        string? searchText = null,
        CancellationToken cancellationToken = default)
    {
        return await _formHelper.DocumentsListAsync(
            driveId,
            folderId,
            pageSize,
            pageToken,
            searchText);
    }

    public string BuildDownloadUrl(string driveId, string itemId)
    {
        return _formHelper.BuildDocumentsDownloadUrl(_configuration, driveId, itemId);
    }
}