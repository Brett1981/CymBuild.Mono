using Concursus.API.Core;

namespace Concursus.API.Client;

public partial class FormHelper
{
    public async Task<AIAssistantKnowledgeImportRunResponse> AIAssistantKnowledgeImportRunAsync(
        int userId,
        bool publishImmediately = true,
        bool authoritative = true,
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantKnowledgeImportRunAsync(
            new AIAssistantKnowledgeImportRunRequest
            {
                UserId = userId,
                PublishImmediately = publishImmediately,
                Authoritative = authoritative
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);
        return response;
    }
}
