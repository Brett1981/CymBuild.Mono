using Concursus.API.Client.Models;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.API.Client.Tests.FormHelper;

/// <summary>
/// Covers only the "read an existing record" branch of ReadDataObjectAsync (recordGuid != Guid.Empty).
/// The "new record" branch (recordGuid == Guid.Empty) walks EntityType.EntityProperties to build
/// per-field defaults via multiple EntityPropertyDefaultGetAsync round trips and an internal
/// UpsertDataObject call - that is a much larger, separate surface deliberately left for future work.
/// </summary>
public sealed class DataObjectReadFormHelperTests
{
    private static RecordingCallInvoker CreateInvoker(
        Func<DataObjectGetRequest, DataObjectGetResponse> onGet,
        Action<DataObjectGetRequest>? capture = null)
    {
        return new RecordingCallInvoker
        {
            // ReadDataObjectAsync also fires an unawaited background RecentItemsCreate call
            // after returning; tolerate it here instead of racing the main assertion against it.
            UnaryHandler = request => request switch
            {
                DataObjectGetRequest getRequest => Handle(getRequest),
                RecentItem => new RecentItem(),
                _ => throw new InvalidOperationException($"Unexpected request type '{request.GetType().Name}'.")
            }
        };

        DataObjectGetResponse Handle(DataObjectGetRequest getRequest)
        {
            capture?.Invoke(getRequest);
            return onGet(getRequest);
        }
    }

    [Fact]
    public async Task ReadDataObjectAsync_ExistingRecord_MapsRequestUsingCurrentEntityType()
    {
        var entityTypeGuid = Guid.NewGuid();
        var recordGuid = Guid.NewGuid();
        var returnedDataObject = new DataObject { Guid = recordGuid.ToString() };
        DataObjectGetRequest? captured = null;

        var invoker = CreateInvoker(
            _ => new DataObjectGetResponse { DataObject = returnedDataObject },
            request => captured = request);
        var helper = FormHelperTestFactory.Create(invoker, entityTypeGuid: entityTypeGuid.ToString());
        var reference = new DataObjectReference(Guid.NewGuid().ToString(), Guid.NewGuid().ToString());

        var result = await helper.ReadDataObjectAsync(recordGuid.ToString(), reference, isInformationView: true);

        Assert.NotNull(captured);
        Assert.Equal(recordGuid.ToString(), captured!.Guid);
        Assert.Equal(entityTypeGuid.ToString(), captured.EntityTypeGuid);
        Assert.True(captured.ForInformationView);
        Assert.Same(returnedDataObject, result);
    }

    [Fact]
    public async Task ReadDataObjectAsync_WithChildEntityGuid_UsesChildEntityTypeGuidInstead()
    {
        var childEntityGuid = Guid.NewGuid();
        DataObjectGetRequest? captured = null;

        var invoker = CreateInvoker(
            _ => new DataObjectGetResponse { DataObject = new DataObject() },
            request => captured = request);
        var helper = FormHelperTestFactory.Create(invoker, entityTypeGuid: Guid.NewGuid().ToString());
        var reference = new DataObjectReference(Guid.NewGuid().ToString(), Guid.NewGuid().ToString());

        await helper.ReadDataObjectAsync(Guid.NewGuid().ToString(), reference, ChildEntityGuid: childEntityGuid.ToString());

        Assert.Equal(childEntityGuid.ToString(), captured!.EntityTypeGuid);
    }

    [Fact]
    public async Task ReadDataObjectAsync_UpdateSharePointTrue_UsesDataObjectReferenceEntityType()
    {
        var referenceEntityTypeGuid = Guid.NewGuid();
        DataObjectGetRequest? captured = null;

        var invoker = CreateInvoker(
            _ => new DataObjectGetResponse { DataObject = new DataObject() },
            request => captured = request);
        var helper = FormHelperTestFactory.Create(invoker, entityTypeGuid: Guid.NewGuid().ToString());
        var reference = new DataObjectReference(Guid.NewGuid().ToString(), referenceEntityTypeGuid.ToString());

        await helper.ReadDataObjectAsync(Guid.NewGuid().ToString(), reference, UpdateSharePoint: true);

        Assert.Equal(referenceEntityTypeGuid.ToString(), captured!.EntityTypeGuid);
    }

    [Fact]
    public async Task ReadDataObjectAsync_PropagatesTransientVirtualProperties_WhenNoChildEntityGuid()
    {
        DataObjectGetRequest? captured = null;
        var invoker = CreateInvoker(
            _ => new DataObjectGetResponse { DataObject = new DataObject() },
            request => captured = request);
        var helper = FormHelperTestFactory.Create(invoker, entityTypeGuid: Guid.NewGuid().ToString());
        var reference = new DataObjectReference(Guid.NewGuid().ToString(), Guid.NewGuid().ToString());
        var transientProperties = new Dictionary<string, Any>
        {
            ["JobDescription"] = Any.Pack(new StringValue { Value = "Test" })
        };

        await helper.ReadDataObjectAsync(
            Guid.NewGuid().ToString(), reference, transientVirtualProperties: transientProperties);

        Assert.True(captured!.TransientVirtualProperties.ContainsKey("JobDescription"));
    }

    [Fact]
    public async Task ReadDataObjectAsync_ServerReturnsError_ReturnsFreshDataObjectWithOnlyTheError()
    {
        var invoker = CreateInvoker(_ => new DataObjectGetResponse { ErrorReturned = "Record not found." });
        var helper = FormHelperTestFactory.Create(invoker, entityTypeGuid: Guid.NewGuid().ToString());
        var reference = new DataObjectReference(Guid.NewGuid().ToString(), Guid.NewGuid().ToString());

        var result = await helper.ReadDataObjectAsync(Guid.NewGuid().ToString(), reference);

        Assert.Equal("Record not found.", result.ErrorReturned);
        Assert.Equal(string.Empty, result.Guid);
    }
}
