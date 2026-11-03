using Grpc.Core;

namespace Concursus.API.Tests;

/// <summary>
/// Minimal ServerCallContext for unit-testing gRPC service methods directly, following the
/// pattern Microsoft documents for grpc-dotnet (Grpc.AspNetCore) - the Grpc.Core.Testing
/// package's TestServerCallContext targets the older C-core Grpc.Core implementation and
/// isn't a fit for this repo's Grpc.AspNetCore-hosted services.
/// </summary>
internal sealed class TestServerCallContext : ServerCallContext
{
    private readonly CancellationToken _cancellationToken;

    private TestServerCallContext(CancellationToken cancellationToken)
    {
        _cancellationToken = cancellationToken;
    }

    public static TestServerCallContext Create(CancellationToken cancellationToken = default) =>
        new(cancellationToken);

    protected override Task WriteResponseHeadersAsyncCore(Metadata responseHeaders) => Task.CompletedTask;

    protected override ContextPropagationToken CreatePropagationTokenCore(ContextPropagationOptions? options) =>
        throw new NotSupportedException("Context propagation is not required by these fast tests.");

    protected override string MethodCore => "TestMethod";

    protected override string HostCore => "TestHost";

    protected override string PeerCore => "TestPeer";

    protected override DateTime DeadlineCore => DateTime.MaxValue;

    protected override Metadata RequestHeadersCore { get; } = new();

    protected override CancellationToken CancellationTokenCore => _cancellationToken;

    protected override Metadata ResponseTrailersCore { get; } = new();

    protected override Status StatusCore { get; set; }

    protected override WriteOptions? WriteOptionsCore { get; set; }

    protected override AuthContext AuthContextCore { get; } =
        new("TestAuthType", new Dictionary<string, List<AuthProperty>>());
}
