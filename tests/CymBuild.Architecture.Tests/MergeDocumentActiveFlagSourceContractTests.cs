using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-496: merge documents can be made inactive. An inactive document is hidden from the
/// Document Tasks list and refused at generation for everyone except full Super Users (SU)
/// and System Administrators (SYSADM); included sub-documents and invoice previews are
/// unaffected. SCore.tvf_UserCanUseInactiveMergeDocuments is the single definition of who may
/// still use an inactive document. The SQL behaviour of that rule is covered by
/// CymBuild.Database.IntegrationTests (UserCanUseInactiveMergeDocumentsTests); these tests pin
/// the wiring that the R4 SQL schema does not reach.
/// </summary>
public sealed class MergeDocumentActiveFlagSourceContractTests
{
    private static readonly string SchemaRoot = RepositoryLayout.PathFromRoot("Database", "CymBuild_DB", "Schema");

    [Fact]
    public void UserCanUseInactiveRule_IsLimitedToFullSuperUsersAndSystemAdministrators()
    {
        var source = ReadSql("Programmability", "Functions", "SCore.tvf_UserCanUseInactiveMergeDocuments.sql");

        Assert.Contains("g.Code IN (N'SU', N'SYSADM')", source, StringComparison.Ordinal);
        Assert.Contains("ug.RowStatus NOT IN (0, 254)", source, StringComparison.Ordinal);
        Assert.Contains("g.RowStatus NOT IN (0, 254)", source, StringComparison.Ordinal);

        // The scoped superuser groups must not be granted access to inactive documents.
        // (They are named in the header comment only, never in the SELECT.)
        var body = source[source.IndexOf("RETURN", StringComparison.Ordinal)..];
        Assert.DoesNotContain("JOBSU", body, StringComparison.Ordinal);
        Assert.DoesNotContain("QUOTESU", body, StringComparison.Ordinal);
        Assert.DoesNotContain("ENQUIRYSU", body, StringComparison.Ordinal);
    }

    [Fact]
    public void DocumentTasksList_HidesInactiveDocumentsUnlessTheUserMayUseThem()
    {
        var source = ReadSql("Programmability", "Functions", "SCore.tvf_MergeDocumentsForEntityType.sql");

        Assert.Contains("md.IsActive", source, StringComparison.Ordinal);
        Assert.Contains("SCore.tvf_UserCanUseInactiveMergeDocuments (@UserId) AS ia", source, StringComparison.Ordinal);
        Assert.Matches(new Regex(@"\(md\.IsActive = 1\)\s*OR\s*\(ia\.CanUseInactive = 1\)"), source);

        // Existing visibility rules are kept.
        Assert.Contains("(md.RowStatus NOT IN (0, 254))", source, StringComparison.Ordinal);
        Assert.Contains("(os.CanRead = 1)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void IncludedSubDocuments_AreNotFilteredByTheActiveFlag()
    {
        var source = ReadSql("Programmability", "Functions", "SCore.tvf_MergeDocumentForItemInclude.sql");

        Assert.DoesNotContain("IsActive", source, StringComparison.Ordinal);
        Assert.DoesNotContain("tvf_UserCanUseInactiveMergeDocuments", source, StringComparison.Ordinal);
    }

    [Fact]
    public void MergeDocumentsUpsert_DefaultsNewDocumentsToActiveAndKeepsTheFlagWhenOmitted()
    {
        var source = ReadSql("Programmability", "Procedures", "SCore.MergeDocumentsUpsert.sql");

        Assert.Matches(new Regex(@"@IsActive BIT = NULL"), source);
        Assert.Contains("ISNULL(@IsActive, 1)", source, StringComparison.Ordinal);
        Assert.Contains("IsActive = ISNULL(@IsActive, IsActive)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SharepointDocumentsGet_RefusesInactiveDocumentsBeforeAnySharePointWork()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("services", "Concursus.API", "Services", "CoreService.cs"));
        var method = ExtractMethod(source, "public override async Task<SharepointDocumentsGetResponse> SharepointDocumentsGet(");

        var guard = method.IndexOf("IsMergeDocumentInactiveForUser(", StringComparison.Ordinal);
        var sharePointWork = method.IndexOf("new SharePoint(", StringComparison.Ordinal);

        Assert.True(guard >= 0, "SharepointDocumentsGet must check IsMergeDocumentInactiveForUser.");
        Assert.True(sharePointWork > guard, "The inactive check must run before any SharePoint location/folder work.");

        // The client-supplied Guid is used to identify the document, falling back to DocumentGuid.
        Assert.Contains("request.MergeDocument?.Guid", method, StringComparison.Ordinal);
        Assert.Contains("request.DocumentGuid", method, StringComparison.Ordinal);
    }

    [Fact]
    public void InactiveGuard_ReadsTheDatabaseThroughTheSharedRule()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "Core.cs"));
        var method = ExtractMethod(source, "public async Task<bool> IsMergeDocumentInactiveForUser(");

        Assert.Contains("SCore.tvf_UserCanUseInactiveMergeDocuments(@UserId)", method, StringComparison.Ordinal);
        Assert.Contains("FROM SCore.MergeDocuments AS md", method, StringComparison.Ordinal);
        // Uncached: an admin's toggle must apply at generation immediately.
        Assert.DoesNotContain("_mergeDocCache", method, StringComparison.Ordinal);
    }

    [Fact]
    public void MergeDocumentMapper_TreatsReadsWithoutTheColumnAsActive()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "Core.cs"));

        Assert.Contains("IsActive = reader.GetBooleanSafe(\"IsActive\", true),", source, StringComparison.Ordinal);
    }

    [Fact]
    public void DocumentTaskView_FlagsInactiveDocumentsForTheUsersWhoCanStillSeeThem()
    {
        var codeBehind = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "DocumentTaskView.razor.cs"));
        var markup = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "DocumentTaskView.razor"));

        Assert.Contains("IsActive = item.IsActive,", codeBehind, StringComparison.Ordinal);
        Assert.Contains("@if (!item.IsActive)", markup, StringComparison.Ordinal);
        Assert.Contains(">Inactive</span>", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataScript_IsKeyedByStableGuidsAndWiresSaveAndRead()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Scripts", "Upgrade Scripts", "CYB-496_MergeDocuments_IsActive.sql"));

        Assert.DoesNotContain("IDENTITY_INSERT", source, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotMatch(new Regex(@"WHERE\s+\(?\s*ID\s*=\s*\d+", RegexOptions.IgnoreCase), source);

        Assert.Contains("@PropertyGuid            UNIQUEIDENTIFIER = '4AFA8E03-6D1F-4AF0-827A-2D3D647D4532'", source, StringComparison.Ordinal);
        Assert.Contains("EXEC SCore.EntityPropertyUpsert", source, StringComparison.Ordinal);
        Assert.Contains("EXEC SCore.EntityQueryParameterUpsert", source, StringComparison.Ordinal);
        Assert.Contains("@SqlDefaultValueStatement      = N'SELECT CONVERT(BIT, 1)'", source, StringComparison.Ordinal);
        Assert.Contains("@IsActive = @IsActive", source, StringComparison.Ordinal);
        Assert.Contains("root_hobt.IsActive,", source, StringComparison.Ordinal);
    }

    private static string ReadSql(params string[] segments) =>
        File.ReadAllText(Path.Combine([SchemaRoot, .. segments]));

    private static string ExtractMethod(string source, string signature)
    {
        var start = source.IndexOf(signature, StringComparison.Ordinal);
        Assert.True(start >= 0, $"Method not found: {signature}");

        var open = source.IndexOf('{', start);
        var depth = 0;
        for (var i = open; i < source.Length; i++)
        {
            if (source[i] == '{') depth++;
            else if (source[i] == '}' && --depth == 0) return source[start..(i + 1)];
        }

        throw new InvalidOperationException($"Unbalanced braces after {signature}");
    }
}
