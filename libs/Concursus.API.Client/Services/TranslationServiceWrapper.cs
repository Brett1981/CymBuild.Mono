using Concursus.API;

namespace CymBuild.API.Client.Services
{
    public class TranslationServiceWrapper
    {
        private readonly TranslationService.TranslationServiceClient _client;

        public TranslationServiceWrapper(TranslationService.TranslationServiceClient client)
        {
            _client = client;
        }

        public async Task<TranslateResponse> TranslateTextAsync(TranslateRequest request)
        {
            return await _client.TranslateTextAsync(request);
        }
    }
}