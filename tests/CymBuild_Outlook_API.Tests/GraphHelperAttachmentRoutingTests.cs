using CymBuild_Outlook_Common.Helpers;
using CymBuild_Outlook_Common.Models.SharePoint;
using Xunit;

namespace CymBuild_Outlook_API.Tests;

public sealed class GraphHelperAttachmentRoutingTests
{
    [Fact]
    public void MatchAttachmentRouting_MatchesById()
    {
        var routings = new List<AttachmentFilingRequest>
        {
            new() { AttachmentId = "att-1", AttachmentName = "Drawing.pdf", DestinationFolderPath = "Site/Job/Drawings" },
            new() { AttachmentId = "att-2", AttachmentName = "Quote.pdf", DestinationFolderPath = "Site/Job/Quotes" }
        };

        var match = GraphHelper.MatchAttachmentRouting(routings, attachmentId: "att-2", attachmentName: "Quote.pdf");

        Assert.NotNull(match);
        Assert.Equal("Site/Job/Quotes", match!.DestinationFolderPath);
    }

    [Fact]
    public void MatchAttachmentRouting_FallsBackToNameWhenIdDiffers()
    {
        // Office.js attachment ids and Graph's own attachment ids for the same item are not guaranteed
        // to be identical, so a name match is the documented fallback.
        var routings = new List<AttachmentFilingRequest>
        {
            new() { AttachmentId = "office-js-id-123", AttachmentName = "Report.docx", DestinationFolderPath = "Site/Job/Reports" }
        };

        var match = GraphHelper.MatchAttachmentRouting(routings, attachmentId: "graph-id-456", attachmentName: "Report.docx");

        Assert.NotNull(match);
        Assert.Equal("Site/Job/Reports", match!.DestinationFolderPath);
    }

    [Fact]
    public void MatchAttachmentRouting_ReturnsNullWhenAttachmentWasNotSelected()
    {
        var routings = new List<AttachmentFilingRequest>
        {
            new() { AttachmentId = "att-1", AttachmentName = "Drawing.pdf" }
        };

        var match = GraphHelper.MatchAttachmentRouting(routings, attachmentId: "att-99", attachmentName: "Unrelated.pdf");

        Assert.Null(match);
    }

    [Fact]
    public void MatchAttachmentRouting_ReturnsNullForEmptyRoutingList()
    {
        var match = GraphHelper.MatchAttachmentRouting(new List<AttachmentFilingRequest>(), attachmentId: "att-1", attachmentName: "Drawing.pdf");

        Assert.Null(match);
    }
}
