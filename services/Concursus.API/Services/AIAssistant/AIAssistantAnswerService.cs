using System.Text.Json;
using Concursus.API.Core;
using static Concursus.API.Services.AIAssistant.AIAssistantAnswerService;

namespace Concursus.API.Services.AIAssistant;

public interface IAIAssistantAnswerService
{
    Task<AIAssistantAnswerResult> GenerateAnswerAsync(
        string userQuestion,
        string modeCode,
        string? languageCode,
        IReadOnlyList<AIAssistantKnowledgeItem> knowledgeItems,
        IReadOnlyList<BlueGenFileReference> attachedFiles,
        CancellationToken cancellationToken);
}

public sealed class AIAssistantAnswerService : IAIAssistantAnswerService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IBlueGenClient _blueGenClient;
    private readonly IAIAssistantPromptBuilder _promptBuilder;

    public AIAssistantAnswerService(
        IBlueGenClient blueGenClient,
        IAIAssistantPromptBuilder promptBuilder)
    {
        _blueGenClient = blueGenClient ?? throw new ArgumentNullException(nameof(blueGenClient));
        _promptBuilder = promptBuilder ?? throw new ArgumentNullException(nameof(promptBuilder));
    }

    public async Task<AIAssistantAnswerResult> GenerateAnswerAsync(
        string userQuestion,
        string modeCode,
        string? languageCode,
        IReadOnlyList<AIAssistantKnowledgeItem> knowledgeItems,
        IReadOnlyList<BlueGenFileReference> attachedFiles,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(userQuestion))
        {
            throw new ArgumentException("A user question is required.", nameof(userQuestion));
        }

        var safeKnowledgeItems = knowledgeItems ?? Array.Empty<AIAssistantKnowledgeItem>();
        var safeAttachedFiles = attachedFiles ?? Array.Empty<BlueGenFileReference>();

        var prompt = _promptBuilder.BuildPrompt(new AIAssistantPromptContext
        {
            UserQuestion = userQuestion,
            ModeCode = modeCode,
            LanguageCode = languageCode,
            KnowledgeItems = safeKnowledgeItems,
            AttachedFiles = safeAttachedFiles
        });

        var blueGenResult = await _blueGenClient
            .SendChatAsync(prompt, safeAttachedFiles, cancellationToken)
            .ConfigureAwait(false);

        var knowledgeSources = safeKnowledgeItems.Take(5).Select(item => new AIAssistantSource
        {
            Title = item.Title,
            TypeCode = item.ContentTypeCode,
            Url = !string.IsNullOrWhiteSpace(item.PreviewUrl)
                ? item.PreviewUrl
                : item.StorageUrl,
            KnowledgeItemGuid = item.Guid,
            VersionNumber = item.CurrentVersionNumber,
            Excerpt = item.Summary,
            IsAuthoritative = item.IsAuthoritative
        }).ToList();

        var attachmentSources = safeAttachedFiles.Select(file => new AIAssistantSource
        {
            Title = string.IsNullOrWhiteSpace(file.FileName) ? "Attached file" : $"Attached: {file.FileName}",
            TypeCode = "ATTACHMENT",
            Url = file.Url,
            KnowledgeItemGuid = string.Empty,
            VersionNumber = 0,
            Excerpt = string.IsNullOrWhiteSpace(file.ContentType) ? "User attachment" : file.ContentType,
            IsAuthoritative = false
        }).ToList();

        var sources = knowledgeSources.Concat(attachmentSources).ToList();

        var followUps = new List<AIAssistantFollowUp>
        {
            new() { Text = "Turn this into a checklist", Prompt = "Turn this answer into a short checklist." },
            new() { Text = "Explain the likely blockers", Prompt = "What are the likely blockers for this in CymBuild?" },
            new() { Text = "Show the admin view", Prompt = "Explain this from an admin/support perspective." }
        };

        var answerTypeCode = ResolveAnswerTypeCode(knowledgeSources.Count > 0, attachmentSources.Count > 0);

        return new AIAssistantAnswerResult
        {
            AnswerTypeCode = answerTypeCode,
            ContentMarkdown = blueGenResult.AnswerMarkdown,
            ContentPlainText = blueGenResult.AnswerPlainText,
            ConfidenceScore = blueGenResult.ConfidenceScore ?? ResolveFallbackConfidence(answerTypeCode),
            Sources = sources,
            FollowUps = followUps,
            SourcesJson = JsonSerializer.Serialize(sources, JsonOptions),
            FollowUpsJson = JsonSerializer.Serialize(followUps, JsonOptions),
            ModelCode = NormaliseBlueGenModelCode(blueGenResult.ModelCode),
            RawProviderJson = blueGenResult.RawJson
        };
    }

    private static string ResolveAnswerTypeCode(bool hasKnowledgeSources, bool hasAttachmentSources)
    {
        if (hasKnowledgeSources)
        {
            return "TRUSTED_KNOWLEDGE";
        }

        if (hasAttachmentSources)
        {
            return "ATTACHMENT_ANALYSIS";
        }

        return "GENERATED_SUGGESTION";
    }

    private static double ResolveFallbackConfidence(string answerTypeCode)
    {
        return answerTypeCode switch
        {
            "TRUSTED_KNOWLEDGE" => 0.82d,
            "ATTACHMENT_ANALYSIS" => 0.68d,
            _ => 0.45d
        };
    }

    private static string NormaliseBlueGenModelCode(string? modelCode)
    {
        if (string.IsNullOrWhiteSpace(modelCode))
        {
            return "BLUEGEN";
        }

        var trimmed = modelCode.Trim();

        return trimmed.StartsWith("BLUEGEN", StringComparison.OrdinalIgnoreCase)
            ? trimmed
            : $"BLUEGEN:{trimmed}";
    }

    public sealed class AIAssistantAnswerResult
    {
        public string AnswerTypeCode { get; init; } = "GENERATED_SUGGESTION";

        public string ContentMarkdown { get; init; } = string.Empty;

        public string ContentPlainText { get; init; } = string.Empty;

        public double ConfidenceScore { get; init; }

        public string SourcesJson { get; init; } = "[]";

        public string FollowUpsJson { get; init; } = "[]";

        public IReadOnlyList<AIAssistantSource> Sources { get; init; } = Array.Empty<AIAssistantSource>();

        public IReadOnlyList<AIAssistantFollowUp> FollowUps { get; init; } = Array.Empty<AIAssistantFollowUp>();

        public string ModelCode { get; init; } = "BLUEGEN";

        public string RawProviderJson { get; init; } = string.Empty;
    }
}
