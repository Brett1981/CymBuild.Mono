using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class DataObjectUpsertFormHelperTests
{
    [Fact]
    public async Task UpsertDataObject_NullDataObject_ReturnsErrorWithoutCallingGrpc()
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(null!, null);

        Assert.Equal("Error: Cannot upsert a null DataObject.", message);
        Assert.NotNull(result);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task UpsertDataObject_MapsRequestFields()
    {
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString(), RowStatus = 1 };
        var entityQueryGuid = Guid.NewGuid();
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse { DataObject = new DataObject { RowStatus = 1 } }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.UpsertDataObject(dataObject, entityQueryGuid, validateOnly: false, IsBulkUpdate: true);

        var request = Assert.IsType<DataObjectUpsertRequest>(invoker.LastRequest);
        Assert.Same(dataObject, request.DataObject);
        Assert.NotNull(request.DeltaDataObject);
        Assert.False(request.ValidateOnly);
        Assert.True(request.SkipValidation);
        Assert.Equal(entityQueryGuid.ToString(), request.EntityQueryGuid);
    }

    [Fact]
    public async Task UpsertDataObject_EntityQueryGuid_DefaultsToEmptyWhenNotSupplied()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse { DataObject = new DataObject() }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.UpsertDataObject(new DataObject(), entityQueryGuid: null);

        var request = Assert.IsType<DataObjectUpsertRequest>(invoker.LastRequest);
        Assert.Equal(Guid.Empty.ToString(), request.EntityQueryGuid);
        Assert.NotNull(request.DeltaDataObject);
    }

    [Fact]
    public async Task UpsertDataObject_ServerReturnsError_ReturnsPrefixedMessageAndOriginalDataObject()
    {
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString() };
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse { ErrorReturned = "Validation failed." }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(dataObject, null);

        Assert.Equal("Error: Validation failed.", message);
        Assert.Same(dataObject, result);
    }

    [Fact]
    public async Task UpsertDataObject_ServerReturnsNoDataObject_ReturnsError()
    {
        var dataObject = new DataObject();
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(dataObject, null);

        Assert.Equal("Error: DataObjectUpsertAsync returned no DataObject.", message);
        Assert.Same(dataObject, result);
    }

    [Fact]
    public async Task UpsertDataObject_ValidateOnly_CopiesServerResultsOntoTheOriginalInstance()
    {
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString() };
        var returned = new DataObject
        {
            RowVersion = "new-row-version",
            HasValidationMessages = true,
            SaveButtonDisabled = true
        };
        returned.ValidationResults.Add(new ValidationResults { IsInvalid = true, Message = "Name is required." });
        returned.DataPills.Add(new DataPill { Value = "Pill" });
        returned.DataProperties.Add(new DataProperty { EntityPropertyGuid = Guid.NewGuid().ToString() });

        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse { DataObject = returned }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(dataObject, null, validateOnly: true);

        Assert.Equal(string.Empty, message);
        Assert.Same(dataObject, result);
        Assert.Equal("new-row-version", dataObject.RowVersion);
        Assert.True(dataObject.HasValidationMessages);
        Assert.True(dataObject.SaveButtonDisabled);
        Assert.Single(dataObject.ValidationResults);
        Assert.Single(dataObject.DataPills);
        Assert.Single(dataObject.DataProperties);
    }

    [Fact]
    public async Task UpsertDataObject_NotValidateOnly_WithInvalidValidationResults_ReturnsJoinedMessage()
    {
        var returned = new DataObject { RowStatus = 1 };
        returned.ValidationResults.Add(new ValidationResults { IsInvalid = true, Message = "Field A is required." });
        returned.ValidationResults.Add(new ValidationResults { IsInvalid = false, Message = "Ignored - not invalid." });
        returned.ValidationResults.Add(new ValidationResults { IsInvalid = true, Message = "Field B is required." });

        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse { DataObject = returned }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(new DataObject(), null, validateOnly: false);

        Assert.Equal("Field A is required.\r\nField B is required.", message);
        Assert.Same(returned, result);
        Assert.True(result.HasValidationMessages);
    }

    [Fact]
    public async Task UpsertDataObject_NotValidateOnly_Success_ReturnsEmptyMessageAndServerDataObject()
    {
        var returned = new DataObject { Guid = Guid.NewGuid().ToString(), RowStatus = 1 };
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectUpsertResponse { DataObject = returned }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(new DataObject(), null, validateOnly: false);

        Assert.Equal(string.Empty, message);
        Assert.Same(returned, result);
    }

    /// <summary>
    /// When the server returns RowStatus = 0 on a non-validate-only upsert, FormHelper fires a
    /// background (unawaited) RecentItemsCreate call. The handler here tolerates both request
    /// shapes so the main assertion isn't racy against that fire-and-forget call.
    /// </summary>
    [Fact]
    public async Task UpsertDataObject_NewlyInsertedRecord_StillReturnsSuccessfully()
    {
        var returned = new DataObject { Guid = Guid.NewGuid().ToString(), RowStatus = 0 };
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => request switch
            {
                DataObjectUpsertRequest => new DataObjectUpsertResponse { DataObject = returned },
                RecentItem => new RecentItem(),
                _ => throw new InvalidOperationException($"Unexpected request type '{request.GetType().Name}'.")
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var (message, result) = await helper.UpsertDataObject(new DataObject(), Guid.NewGuid(), validateOnly: false);

        Assert.Equal(string.Empty, message);
        Assert.Same(returned, result);
    }
}
