using Concursus.API.Core;

namespace Concursus.Components.Shared.Controls.Documents;

internal sealed class DocumentsState
{
    public DocumentsLocation? CurrentLocation { get; set; }
    public DocumentsNavigationItem? SelectedNavigationItem { get; set; }

    public List<DocumentsNavigationItem> NavigationItems { get; } = new();
    public List<DocumentsListItem> FileRows { get; } = new();
    public List<FolderTreeNodeModel> FolderNodes { get; } = new();
    public List<BreadcrumbModel> Breadcrumbs { get; } = new();

    public string? CurrentFolderId { get; set; }
    public string? NextPageToken { get; set; }

    public bool NavigationLoading { get; set; }
    public bool FoldersLoading { get; set; }
    public bool FilesLoading { get; set; }

    public string? FatalError { get; set; }
    public string SearchText { get; set; } = string.Empty;

    public void Reset()
    {
        CurrentLocation = null;
        SelectedNavigationItem = null;
        NavigationItems.Clear();
        FileRows.Clear();
        FolderNodes.Clear();
        Breadcrumbs.Clear();
        CurrentFolderId = null;
        NextPageToken = null;
        FatalError = null;
    }
}

internal sealed class BreadcrumbModel
{
    public string Name { get; set; } = string.Empty;
    public string FolderId { get; set; } = string.Empty;
}

internal sealed class FolderTreeNodeModel
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool HasChildren { get; set; }
    public bool ChildrenLoaded { get; set; }
    public List<FolderTreeNodeModel> Children { get; set; } = new();
}