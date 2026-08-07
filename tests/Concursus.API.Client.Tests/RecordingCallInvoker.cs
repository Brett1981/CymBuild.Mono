using Grpc.Core;

namespace Concursus.API.Client.Tests;

internal sealed class RecordingCallInvoker : CallInvoker
{
    public Func<object, object>? UnaryHandler { get; set; }

    public string? LastMethodFullName { get; private set; }

    public object? LastRequest { get; private set; }

    public CallOptions LastCallOptions { get; private set; }

    public override TResponse BlockingUnaryCall<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        string? host,
        CallOptions options,
        TRequest request)
    {
        Capture(method, options, request);
        return Invoke<TResponse>(request!);
    }

    public override AsyncUnaryCall<TResponse> AsyncUnaryCall<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        string? host,
        CallOptions options,
        TRequest request)
    {
        Capture(method, options, request);

        Task<TResponse> responseTask;
        try
        {
            responseTask = Task.FromResult(Invoke<TResponse>(request!));
        }
        catch (Exception ex)
        {
            responseTask = Task.FromException<TResponse>(ex);
        }

        return new AsyncUnaryCall<TResponse>(
            responseTask,
            Task.FromResult(new Metadata()),
            static () => Status.DefaultSuccess,
            static () => new Metadata(),
            static () => { });
    }

    public override AsyncServerStreamingCall<TResponse> AsyncServerStreamingCall<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        string? host,
        CallOptions options,
        TRequest request) =>
        throw new NotSupportedException("Streaming RPCs are not required by these fast tests.");

    public override AsyncClientStreamingCall<TRequest, TResponse> AsyncClientStreamingCall<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        string? host,
        CallOptions options) =>
        throw new NotSupportedException("Streaming RPCs are not required by these fast tests.");

    public override AsyncDuplexStreamingCall<TRequest, TResponse> AsyncDuplexStreamingCall<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        string? host,
        CallOptions options) =>
        throw new NotSupportedException("Streaming RPCs are not required by these fast tests.");

    private void Capture<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        CallOptions options,
        TRequest request)
    {
        LastMethodFullName = method.FullName;
        LastRequest = request;
        LastCallOptions = options;
    }

    private TResponse Invoke<TResponse>(object request)
    {
        if (UnaryHandler is null)
        {
            throw new InvalidOperationException("No unary response handler has been configured.");
        }

        var response = UnaryHandler(request);
        return response is TResponse typedResponse
            ? typedResponse
            : throw new InvalidOperationException(
                $"The configured response type '{response?.GetType().FullName ?? "<null>"}' " +
                $"does not match '{typeof(TResponse).FullName}'.");
    }
}
