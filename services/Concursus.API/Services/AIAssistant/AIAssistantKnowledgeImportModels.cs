namespace Concursus.API.Services.AIAssistant;

public sealed record AIAssistantKnowledgeImportOptions
{
    public string SiteId { get; init; } = string.Empty;
    public string DriveName { get; init; } = "Documents";
    public string SitePath { get; init; } = string.Empty;
    public string DriveId { get; init; } = string.Empty;

    // Relative to the selected document library root. For the CymBuild Teams/SharePoint library this is normally:
    // General/Training Material
    public string RootFolderPath { get; init; } = "General/Training Material";

    // Optional but recommended. When supplied, the importer resolves the folder from the SharePoint sharing URL first,
    // which avoids site-id/library/path ambiguity.
    public string RootFolderSharingUrl { get; init; } = string.Empty;

    public IReadOnlyList<string> IncludeFolderNames { get; init; } = new[]
    {
        "Business Process Documentations",
        "Developer Documentations",
        "User Documentations",
        "QA",
        "Changes"
    };

    public IReadOnlyList<string> SupportedExtensions { get; init; } = new[] { ".docx", ".txt", ".md" };
    public int MaxChunkCharacters { get; init; } = 9000;
    public int MaxFilesPerRun { get; init; } = 250;
}

public sealed record AIAssistantKnowledgeImportResult
{
    public int FilesFound { get; init; }
    public int FilesSkipped { get; init; }
    public int ItemsUpserted { get; init; }
    public int Failures { get; init; }
    public List<AIAssistantKnowledgeImportLogEntry> Log { get; init; } = new();
}

public sealed record AIAssistantKnowledgeImportLogEntry
{
    public string Level { get; init; } = "INFO";
    public string FileName { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
    public string KnowledgeItemGuid { get; init; } = string.Empty;
}

public sealed record ExtractedKnowledgeDocument(
    string Title,
    string SourceUrl,
    string PreviewUrl,
    string FolderPath,
    string Extension,
    string ExtractedText);

public sealed record KnowledgeChunk(
    string Title,
    string Slug,
    string Summary,
    string Text);

internal sealed record SharePointFolderReference(string DriveId, string ItemId, string DisplayName);
