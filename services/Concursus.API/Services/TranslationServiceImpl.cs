using Google.Api.Gax.ResourceNames;
using Google.Cloud.Translate.V3;
using Grpc.Core;

namespace Concursus.API.Services
{
    public class TranslationServiceImpl : TranslationService.TranslationServiceBase
    {
        private readonly string _projectId;
        private readonly ILogger<TranslationServiceImpl> _logger;

        public TranslationServiceImpl(IConfiguration config, ILogger<TranslationServiceImpl> logger)
        {
            _projectId = config["Google:ProjectId"];
            _logger = logger;

            // Check if GOOGLE_APPLICATION_CREDENTIALS is set
            var credentialsPath = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
            if (string.IsNullOrEmpty(credentialsPath))
            {
                _logger.LogError("GOOGLE_APPLICATION_CREDENTIALS environment variable is not set.");
                throw new InvalidOperationException("GOOGLE_APPLICATION_CREDENTIALS environment variable is not set.");
            }
            else
            {
                _logger.LogInformation($"GOOGLE_APPLICATION_CREDENTIALS is set to: {credentialsPath}");
                if (!System.IO.File.Exists(credentialsPath))
                {
                    _logger.LogError($"Google Cloud credentials file not found at path: {credentialsPath}");
                    throw new InvalidOperationException($"Google Cloud credentials file not found at path: {credentialsPath}");
                }
            }
        }

        public override async Task<TranslateResponse> TranslateText(TranslateRequest request, ServerCallContext context)
        {
            try
            {
                _logger.LogInformation("Starting translation for {TargetLanguage}", request.TargetLanguage);
                var translatedLabelTranslations = new List<GoogleLanguageLabelTranslation>();

                foreach (var label in request.LabelTranslation)
                {
                    var translatedText = await TranslateTextAsync(label.Text, request.TargetLanguage);
                    translatedLabelTranslations.Add(new GoogleLanguageLabelTranslation
                    {
                        LanguageGuid = label.LanguageGuid,
                        LanguageLabelGuid = label.LanguageLabelGuid,
                        Text = translatedText,
                        Guid = label.Guid
                    });
                }

                return new TranslateResponse
                {
                    TranslatedLabelTranslation = { translatedLabelTranslations }
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error translating text");
                throw new RpcException(new Status(StatusCode.Internal, "Internal server error"));
            }
        }

        private async Task<string> TranslateTextAsync(string text, string targetLanguage)
        {
            try
            {
                TranslationServiceClient client = await TranslationServiceClient.CreateAsync();

                TranslateTextRequest request = new TranslateTextRequest
                {
                    Contents = { text },
                    TargetLanguageCode = targetLanguage,
                    ParentAsLocationName = new LocationName(_projectId, "global")
                };

                var response = await client.TranslateTextAsync(request);
                return response.Translations[0].TranslatedText;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error calling Google Cloud Translate API");
                throw;
            }
        }
    }
}