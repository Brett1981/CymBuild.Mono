using Concursus.API.Services;
using Concursus.Common.Shared.Helpers;
using Xunit;
using static Concursus.Common.Shared.Enums;
using SharePointComponent = Concursus.API.Components.SharePoint;

namespace Concursus.API.Tests.SharePoint;

// CYB-405 / CYB-507: department-specific SharePoint folders for new Enquiries, Quotes and Jobs.
public sealed class DepartmentFolderStructureTests
{
    private const string BuildingSafetyConsultancyGuid = "FC76773B-841E-46EF-BCDD-511A7E38BE74";
    private const string FireEngineeringSilGuid = "5EE48AEB-B85F-4F2F-9010-B8C4B1C85DEB";
    private const string FireEngineeringUkGuid = "E3F5F61F-0313-44D5-B47A-669408A067B1";
    private const string CdmGuid = "2C9489BD-EAE8-4703-90D7-56C94E802EDA";
    private const string UnmappedGuid = "7ADC0989-A468-47E5-A206-DAEC008F9E9D"; // Sustainability Compliance

    private static readonly string[] BuildingSafetyConsultancyFolders =
    [
        "Drawings",
        "Incoming Emails",
        "Outgoing Emails",
        "Fees Proposals",
        "Photographs",
        "Reports",
        "Technical Documents"
    ];

    private readonly SharepointService _service = new();

    public enum RecordKind
    {
        Enquiry,
        Quote,
        Job
    }

    private SharepointDirectory Build(RecordKind kind, string? organisationalUnitGuid) => kind switch
    {
        RecordKind.Enquiry => SharePointComponent.BuildEnquirySharepointDirectory(_service, organisationalUnitGuid),
        RecordKind.Quote => SharePointComponent.BuildQuoteSharepointDirectory(_service, organisationalUnitGuid),
        _ => SharePointComponent.BuildJobSharepointDirectory(_service, organisationalUnitGuid)
    };

    [Theory]
    [InlineData(OrganisationalUnits.BuildingSafetyConsultancy, BuildingSafetyConsultancyGuid)]
    [InlineData(OrganisationalUnits.FireEngineeringSIL, FireEngineeringSilGuid)]
    public void OrganisationalUnitHelper_MapsNewDepartmentGuids(OrganisationalUnits unit, string guid)
    {
        Assert.Equal(guid, OrganisationalUnitHelper.GetId(unit));
        Assert.Equal(unit, OrganisationalUnitHelper.GetById(guid.ToLowerInvariant()));
    }

    [Theory]
    [InlineData(RecordKind.Enquiry)]
    [InlineData(RecordKind.Quote)]
    [InlineData(RecordKind.Job)]
    public void BuildingSafetyConsultancy_GetsItsOwnFolders(RecordKind kind)
    {
        var directory = Build(kind, BuildingSafetyConsultancyGuid);

        Assert.Equal(BuildingSafetyConsultancyFolders, directory.FolderNames);
        Assert.Empty(directory.SubFoldersToCreate);
    }

    [Theory]
    [InlineData(RecordKind.Enquiry)]
    [InlineData(RecordKind.Quote)]
    [InlineData(RecordKind.Job)]
    public void FireEngineeringSil_MatchesFireEngineeringUk(RecordKind kind)
    {
        var sil = Build(kind, FireEngineeringSilGuid);
        var uk = Build(kind, FireEngineeringUkGuid);

        Assert.NotEmpty(sil.FolderNames);
        Assert.Equal(uk.FolderNames, sil.FolderNames);
        Assert.Equal(
            uk.SubFoldersToCreate.OrderBy(x => x.Key),
            sil.SubFoldersToCreate.OrderBy(x => x.Key));
    }

    [Fact]
    public void FireEngineeringSil_JobFolders_AreTheFireEngineeringStructure()
    {
        var directory = Build(RecordKind.Job, FireEngineeringSilGuid);

        Assert.Equal(
            ["Fees", "Correspondence", "Emails (Incoming)", "Emails (Outgoing)", "Drawings", "Photographs", "Reports", "Technical Documents"],
            directory.FolderNames);
        Assert.Equal(["Quotations"], directory.SubFoldersToCreate["Fees"]);
        Assert.Equal(["POs"], directory.SubFoldersToCreate["Fees/Quotations"]);
        Assert.Equal(["Contracts"], directory.SubFoldersToCreate["Correspondence"]);
    }

    [Theory]
    [InlineData(RecordKind.Enquiry)]
    [InlineData(RecordKind.Quote)]
    public void UnmappedDepartment_StillGetsNoEnquiryOrQuoteFolders(RecordKind kind)
    {
        var directory = Build(kind, UnmappedGuid);

        Assert.Empty(directory.FolderNames);
        Assert.Empty(directory.SubFoldersToCreate);
    }

    [Fact]
    public void UnmappedDepartment_StillGetsDefaultJobFolders()
    {
        var directory = Build(RecordKind.Job, UnmappedGuid);

        Assert.Equal(
            ["Admin", "Certs", "Design Information", "Design Risk Management", "Emails", "Finance", "Photos", "Reports"],
            directory.FolderNames);
        Assert.Empty(directory.SubFoldersToCreate);
    }

    [Fact]
    public void Cdm_JobFolders_AreUnchanged()
    {
        var directory = Build(RecordKind.Job, CdmGuid);

        Assert.Contains("Meeting Minutes", directory.FolderNames);
        Assert.DoesNotContain("Certs", directory.FolderNames);
        Assert.DoesNotContain("Incoming Emails", directory.FolderNames);
    }
}
