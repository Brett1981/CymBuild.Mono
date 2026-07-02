using System.Text;
using Concursus.API.Core;

namespace Concursus.API.Services.AIAssistant;

public interface IAIAssistantPromptBuilder
{
    string BuildPrompt(AIAssistantPromptContext context);
}

public sealed class AIAssistantPromptBuilder : IAIAssistantPromptBuilder
{
    public string BuildPrompt(AIAssistantPromptContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        var modeCode = string.Equals(context.ModeCode, "EXPERT", StringComparison.OrdinalIgnoreCase)
            ? "EXPERT"
            : "BEGINNER";

        var builder = new StringBuilder();

        builder.AppendLine("You are the CymBuild in-product AI assistant.");
        builder.AppendLine();
        builder.AppendLine("Your job is to help CymBuild users learn, navigate, troubleshoot, and complete tasks.");
        builder.AppendLine("Use plain English. Be practical. Prefer step-by-step guidance.");
        builder.AppendLine("Never invent CymBuild behaviour if the provided knowledge does not support it.");
        builder.AppendLine("If the answer is uncertain, say what should be checked next.");
        builder.AppendLine();

        builder.AppendLine("CymBuild architecture rules:");
        builder.AppendLine("- UI uses FormHelper, never direct API calls.");
        builder.AppendLine("- FormHelper calls gRPC API.");
        builder.AppendLine("- API uses EF/SQL and approved services.");
        builder.AppendLine("- Workflow status is not updated directly.");
        builder.AppendLine("- Latest workflow transition is the current state.");
        builder.AppendLine();

        builder.AppendLine();
        builder.AppendLine($"Answer mode: {modeCode}");
        if (modeCode == "BEGINNER")
        {
            builder.AppendLine("Beginner mode: explain with more context and simple steps.");
        }
        else
        {
            builder.AppendLine("Expert mode: be concise and action-focused.");
        }

        if (!string.IsNullOrWhiteSpace(context.LanguageCode))
        {
            builder.AppendLine($"Preferred language code: {context.LanguageCode}");
        }

        builder.AppendLine();
        builder.AppendLine("User question:");
        builder.AppendLine(context.UserQuestion.Trim());

        if (context.KnowledgeItems.Count > 0)
        {
            builder.AppendLine();
            builder.AppendLine("Trusted CymBuild knowledge sources:");
            for (var i = 0; i < context.KnowledgeItems.Count; i++)
            {
                var item = context.KnowledgeItems[i];
                builder.AppendLine($"Source {i + 1}: {item.Title}");
                builder.AppendLine($"Type: {item.ContentTypeCode}");
                builder.AppendLine($"Authoritative: {item.IsAuthoritative}");
                builder.AppendLine($"URL: {item.StorageUrl}");
                if (!string.IsNullOrWhiteSpace(item.Summary))
                {
                    builder.AppendLine("Summary:");
                    builder.AppendLine(item.Summary);
                }
                builder.AppendLine();
            }
        }
        else
        {
            builder.AppendLine();
            builder.AppendLine("No trusted knowledge source was found. Provide a cautious generated suggestion and clearly say what should be checked.");
        }

        if (context.AttachedFiles.Count > 0)
        {
            builder.AppendLine();
            builder.AppendLine("User-provided attachments:");
            builder.AppendLine("The user attached the following file(s). Inspect them before answering. If an attachment is a screenshot, describe the visible CymBuild screen, fields, panels, buttons, data, errors, and likely purpose. If the attachment cannot be inspected by the provider, say that clearly and do not pretend to have seen it.");

            for (var i = 0; i < context.AttachedFiles.Count; i++)
            {
                var file = context.AttachedFiles[i];
                builder.AppendLine($"Attachment {i + 1}: {file.FileName}");
                builder.AppendLine($"Content type: {file.ContentType}");
                builder.AppendLine($"URL/reference: {file.Url}");
            }
        }

        builder.AppendLine();
        builder.AppendLine("Return the answer using this structure when useful:");
        builder.AppendLine("1. Short answer");
        builder.AppendLine("2. Step-by-step guidance");
        builder.AppendLine("3. Things to check");
        builder.AppendLine("4. Suggested follow-up questions");
        builder.AppendLine();
        builder.AppendLine("Do not include unsupported claims.");

        return builder.ToString();
    }
}

public sealed class AIAssistantPromptContext
{
    public string UserQuestion { get; init; } = string.Empty;

    public string ModeCode { get; init; } = "BEGINNER";

    public string? LanguageCode { get; init; }

    public IReadOnlyList<AIAssistantKnowledgeItem> KnowledgeItems { get; init; } = Array.Empty<AIAssistantKnowledgeItem>();

    public IReadOnlyList<BlueGenFileReference> AttachedFiles { get; init; } = Array.Empty<BlueGenFileReference>();
}
