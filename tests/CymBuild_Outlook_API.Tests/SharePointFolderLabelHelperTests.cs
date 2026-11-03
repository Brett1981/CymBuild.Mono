using CymBuild_Outlook_Common.Dto;
using CymBuild_Outlook_Common.Helpers;
using Xunit;

namespace CymBuild_Outlook_API.Tests;

public sealed class SharePointFolderLabelHelperTests
{
    private static SharePointFolderDto Folder(string path)
        => new() { Name = path.Split('/').Last(), Path = path };

    [Fact]
    public void BuildLabels_UsesFolderName_WhenNameIsUnique()
    {
        var labels = SharePointFolderLabelHelper.BuildLabels(new[]
        {
            Folder("Emails"),
            Folder("Emails/Incoming Emails"),
            Folder("Drawings")
        });

        Assert.Equal("Emails", labels["Emails"]);
        Assert.Equal("Incoming Emails", labels["Emails/Incoming Emails"]);
        Assert.Equal("Drawings", labels["Drawings"]);
    }

    [Fact]
    public void BuildLabels_PrefixesParentFolder_WhenSubFoldersShareAName()
    {
        var labels = SharePointFolderLabelHelper.BuildLabels(new[]
        {
            Folder("Emails/Incoming Emails"),
            Folder("Emails/Incoming Emails/Attachments"),
            Folder("Emails/Outgoing Emails"),
            Folder("Emails/Outgoing Emails/Attachments")
        });

        Assert.Equal("Incoming Emails / Attachments", labels["Emails/Incoming Emails/Attachments"]);
        Assert.Equal("Outgoing Emails / Attachments", labels["Emails/Outgoing Emails/Attachments"]);
        Assert.Equal("Incoming Emails", labels["Emails/Incoming Emails"]);
    }

    [Fact]
    public void BuildLabels_DistinguishesParentFromSubFolder_WithTheSameName()
    {
        var labels = SharePointFolderLabelHelper.BuildLabels(new[]
        {
            Folder("Attachments"),
            Folder("Reports/Attachments")
        });

        Assert.Equal("Attachments", labels["Attachments"]);
        Assert.Equal("Reports / Attachments", labels["Reports/Attachments"]);
    }

    [Fact]
    public void BuildLabels_AddsMoreParentFolders_UntilLabelsAreUnique()
    {
        var labels = SharePointFolderLabelHelper.BuildLabels(new[]
        {
            Folder("Job A/Emails/Attachments"),
            Folder("Job B/Emails/Attachments")
        });

        Assert.Equal("Job A / Emails / Attachments", labels["Job A/Emails/Attachments"]);
        Assert.Equal("Job B / Emails / Attachments", labels["Job B/Emails/Attachments"]);
    }

    [Fact]
    public void BuildLabels_TreatsNamesCaseInsensitively()
    {
        var labels = SharePointFolderLabelHelper.BuildLabels(new[]
        {
            Folder("Incoming/Attachments"),
            Folder("Outgoing/attachments")
        });

        Assert.Equal("Incoming / Attachments", labels["Incoming/Attachments"]);
        Assert.Equal("Outgoing / attachments", labels["Outgoing/attachments"]);
    }

    [Fact]
    public void GetLabel_FallsBackToLastPathSegment_WhenPathIsNotKnown()
    {
        var labels = SharePointFolderLabelHelper.BuildLabels(Array.Empty<SharePointFolderDto>());

        Assert.Equal("Attachments", SharePointFolderLabelHelper.GetLabel(labels, "Emails/Attachments"));
        Assert.Equal(string.Empty, SharePointFolderLabelHelper.GetLabel(labels, null));
    }
}
