using System.Text.Json;
using Concursus.API.Core;

namespace Concursus.API.Services.AIAssistant;

public interface IAIAssistantAnswerService
{
    Task<AIAssistantAnswerResult> GenerateAnswerAsync(
        string userQuestion,
        string modeCode,
        string? languageCode,
        IReadOnlyList<AIAssistantKnowledgeItem> knowledgeItems,
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
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(userQuestion))
        {
            throw new ArgumentException("A user question is required.", nameof(userQuestion));
        }

        var prompt = _promptBuilder.BuildPrompt(new AIAssistantPromptContext
        {
            UserQuestion = userQuestion,
            ModeCode = modeCode,
            LanguageCode = languageCode,
            KnowledgeItems = knowledgeItems
        });

        var blueGenResult = await _blueGenClient
            .SendChatAsync(prompt, Array.Empty<BlueGenFileReference>(), cancellationToken)
            .ConfigureAwait(false);

        var sources = knowledgeItems.Take(5).Select(item => new AIAssistantSource
        {
            Title = item.Title,
            TypeCode = item.ContentTypeCode,
            Url = item.StorageUrl,
            KnowledgeItemGuid = item.Guid,
            VersionNumber = item.CurrentVersionNumber,
            Excerpt = item.Summary,
            IsAuthoritative = item.IsAuthoritative
        }).ToList();

        var followUps = new List<AIAssistantFollowUp>
        {
            new() { Text = "Turn this into a checklist", Prompt = "Turn this answer into a short checklist." },
            new() { Text = "Explain the likely blockers", Prompt = "What are the likely blockers for this in CymBuild?" },
            new() { Text = "Show the admin view", Prompt = "Explain this from an admin/support perspective." }
        };

        return new AIAssistantAnswerResult
        {
            AnswerTypeCode = sources.Count > 0 ? "TRUSTED_KNOWLEDGE" : "GENERATED_SUGGESTION",
            ContentMarkdown = blueGenResult.AnswerMarkdown,
            ContentPlainText = blueGenResult.AnswerPlainText,
            ConfidenceScore = blueGenResult.ConfidenceScore ?? (sources.Count > 0 ? 0.82d : 0.45d),
            Sources = sources,
            FollowUps = followUps,
            SourcesJson = JsonSerializer.Serialize(sources, JsonOptions),
            FollowUpsJson = JsonSerializer.Serialize(followUps, JsonOptions),
            ModelCode = blueGenResult.ModelCode,
            RawProviderJson = blueGenResult.RawJson
        };
    }
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
