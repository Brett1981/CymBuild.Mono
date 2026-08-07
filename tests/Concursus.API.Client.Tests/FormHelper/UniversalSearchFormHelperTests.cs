using Concursus.API.Client.Models;
using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class UniversalSearchFormHelperTests
{
    [Fact]
    public async Task UniversalSearchAsync_RejectsNullRequest()
    {
        var helper = FormHelperTestFactory.Create(new RecordingCallInvoker());

        await Assert.ThrowsAsync<ArgumentNullException>(() => helper.UniversalSearchAsync(null!));
    }

    [Fact]
    public async Task UniversalSearchAsync_UsesCurrentUserWhenRequestUserIsMissing()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new UniversalSearchReply
            {
                IsSuccess = true,
                Message = "ok"
            }
        };
        var helper = FormHelperTestFactory.Create(
            invoker,
            new UserService { UserId = 42 });
        var request = new UniversalSearchRequest { UserId = 0 };

        var reply = await helper.UniversalSearchAsync(request);

        Assert.True(reply.IsSuccess);
        Assert.Equal(42, request.UserId);
        Assert.Same(request, invoker.LastRequest);
        Assert.EndsWith("/UniversalSearch", Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task UniversalSearchAsync_PreservesExplicitRequestUser()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new UniversalSearchReply { IsSuccess = true }
        };
        var helper = FormHelperTestFactory.Create(
            invoker,
            new UserService { UserId = 42 });
        var request = new UniversalSearchRequest { UserId = 99 };

        await helper.UniversalSearchAsync(request);

        Assert.Equal(99, Assert.IsType<UniversalSearchRequest>(invoker.LastRequest).UserId);
    }

    [Fact]
    public async Task UniversalSearchAsync_ConvertsGrpcFailureIntoClientReply()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => throw new InvalidOperationException("search unavailable")
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var reply = await helper.UniversalSearchAsync(new UniversalSearchRequest());

        Assert.False(reply.IsSuccess);
        Assert.Equal("search unavailable", reply.Message);
    }
}
