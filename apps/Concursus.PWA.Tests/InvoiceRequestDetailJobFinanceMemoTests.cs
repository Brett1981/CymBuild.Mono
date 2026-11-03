using Concursus.API.Core;
using Concursus.PWA.Pages;
using Google.Protobuf.WellKnownTypes;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests;

/// <summary>
/// Covers CYB-499: the JOBFINANCEMEMO grid on InvoiceRequestDetail was bound to the wrong
/// ParentGuid (the navigating record's guid, not the Job's), and the Job guid extraction that
/// was meant to feed it ran in OnAfterRender, which does not reliably observe the child
/// EditPage's async DataObjectLoaded event. ResolveJobFinanceMemoParentGuid is the pure
/// extraction logic now driven by EditPage.DataObjectLoaded instead.
/// </summary>
public sealed class InvoiceRequestDetailJobFinanceMemoTests
{
    private const string JobIdEntityPropertyGuid = "dddabd42-c753-48fa-800f-a73c88fcadcd";

    private static DataProperty StringProperty(string entityPropertyGuid, string value) =>
        new()
        {
            EntityPropertyGuid = entityPropertyGuid,
            Value = Any.Pack(new StringValue { Value = value })
        };

    [Fact]
    public void ResolveJobFinanceMemoParentGuid_ReturnsJobGuid_WhenJobIdPropertyIsPresent()
    {
        var jobGuid = "3fa85f64-5717-4562-b3fc-2c963f66afa6";
        var dataObject = new DataObject
        {
            DataProperties = { StringProperty(JobIdEntityPropertyGuid, jobGuid) }
        };

        var result = InvoiceRequestDetail.ResolveJobFinanceMemoParentGuid(dataObject);

        Assert.Equal(jobGuid, result);
    }

    [Fact]
    public void ResolveJobFinanceMemoParentGuid_ReturnsNull_WhenJobIdPropertyIsMissing()
    {
        var dataObject = new DataObject
        {
            DataProperties = { StringProperty("some-other-property-guid", "irrelevant") }
        };

        var result = InvoiceRequestDetail.ResolveJobFinanceMemoParentGuid(dataObject);

        Assert.Null(result);
    }

    [Fact]
    public void ResolveJobFinanceMemoParentGuid_ReturnsNull_ForNewRecordWithNoDataProperties()
    {
        var dataObject = new DataObject();

        var result = InvoiceRequestDetail.ResolveJobFinanceMemoParentGuid(dataObject);

        Assert.Null(result);
    }

    [Fact]
    public void ResolveJobFinanceMemoParentGuid_DoesNotMatchOnAnUnrelatedGuidThatSharesNoValue()
    {
        // Guards against matching the wrong property if EntityPropertyGuid comparisons
        // are ever loosened (e.g. to case-insensitive substring matching).
        var dataObject = new DataObject
        {
            DataProperties =
            {
                StringProperty("8c1f4236-36a8-44ed-af70-c43f56840943", "requester-user-guid"),
                StringProperty(JobIdEntityPropertyGuid, "job-guid-value")
            }
        };

        var result = InvoiceRequestDetail.ResolveJobFinanceMemoParentGuid(dataObject);

        Assert.Equal("job-guid-value", result);
    }
}
