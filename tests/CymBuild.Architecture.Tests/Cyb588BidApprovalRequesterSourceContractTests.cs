using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-588: the Bid Approval notification went only to the department's Bid Team
// group, never to the person who sent the enquiry for Bid Team Review.
public sealed class Cyb588BidApprovalRequesterSourceContractTests
{
    private const string BidTeamReview = "675CA95D-F03D-4DBC-B83C-3D21BF138635";
    private const string ApprovedForQuote = "3070A373-0E0A-4261-B942-66CB512EE1B6";
    private const string DeclinedToQuote = "60B8D960-8F6C-495D-B2E7-F19EBD5506EE";

    [Fact]
    public void Recipients_IncludeTheBidReviewRequester_WhenABidIsApprovedOrDeclined()
    {
        var sql = ReadView();

        Assert.Contains("CREATE OR ALTER VIEW [SCore].[IntegrationOutboxNotificationRecipients]", sql, StringComparison.Ordinal);
        Assert.Contains("CYB-588-BID-REQUESTER", sql, StringComparison.Ordinal);
        Assert.Contains($"reqStatus.Guid = '{BidTeamReview}' -- Bid Team Review", sql, StringComparison.Ordinal);
        Assert.Contains($"'{ApprovedForQuote}', -- Approved For Quote", sql, StringComparison.Ordinal);
        Assert.Contains($"'{DeclinedToQuote}'  -- Declined To Quote", sql, StringComparison.Ordinal);

        // The requester is whoever saved the latest Bid Team Review before this decision.
        Assert.Contains("AND (sr.TransitionId IS NULL OR req.ID < sr.TransitionId)", sql, StringComparison.Ordinal);
        Assert.Contains("ORDER BY req.ID DESC", sql, StringComparison.Ordinal);
        Assert.Contains("AND i.IsActive = 1\n       AND i.ID = requester.CreatedByUserId", sql.Replace("\r\n", "\n"), StringComparison.Ordinal);

        // Group recipients are kept; the requester is added alongside them.
        Assert.Contains("FROM Users u\n\n    UNION ALL", sql.Replace("\r\n", "\n"), StringComparison.Ordinal);
        Assert.Contains("FROM AllRecipients u;", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("SELECT *", sql, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Recipients_KeepTheirColumns_ForTheGridBuiltFromThisView()
    {
        // SCore.UpsertGridFromSchemaObject builds a grid from this view's columns.
        var sql = ReadView().Replace("\r\n", "\n");
        var finalSelect = sql.Substring(sql.LastIndexOf("\nSELECT\n", StringComparison.Ordinal));

        foreach (var column in new[]
                 {
                     "u.OutboxId", "u.OutboxGuid", "u.CreatedOnUtc", "u.EventType", "u.PublishedOnUtc",
                     "u.PublishAttempts", "u.LastError", "u.DataObjectGuid", "u.TransitionId", "u.WorkflowId",
                     "u.WorkflowStatusGuidResolved AS WorkflowStatusGuid", "u.GroupID", "u.GroupCode",
                     "u.GroupName", "u.CanAction", "u.IdentityID", "u.FullName", "u.EmailAddress"
                 })
        {
            Assert.Contains(column, finalSelect, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void Publisher_SendsOnceToARequesterWhoIsAlsoInTheBidTeam()
    {
        var repository = File.ReadAllText(
            RepositoryLayout.PathFromRoot("services", "Concursus.API", "Services", "Outbox", "WorkflowOutboxRepository.cs"));

        Assert.Contains("SELECT DISTINCT EmailAddress\nFROM SCore.IntegrationOutboxNotificationRecipients", repository.Replace("\r\n", "\n"), StringComparison.Ordinal);
    }

    private static string ReadView()
    {
        return File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Schema",
                "Views",
                "SCore.IntegrationOutboxNotificationRecipients.sql"));
    }
}
