using Microsoft.JSInterop;

namespace Concursus.PWA.Tests;

internal sealed class RecordingJsRuntime : IJSRuntime
{
    private readonly List<JsInvocation> _invocations = new();

    public IReadOnlyList<JsInvocation> Invocations => _invocations;

    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, object?[]? args)
    {
        return RecordInvocation<TValue>(identifier, args);
    }

    public ValueTask<TValue> InvokeAsync<TValue>(
        string identifier,
        CancellationToken cancellationToken,
        object?[]? args)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return RecordInvocation<TValue>(identifier, args);
    }

    private ValueTask<TValue> RecordInvocation<TValue>(string identifier, object?[]? args)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(identifier);

        _invocations.Add(new JsInvocation(
            identifier,
            args is null ? Array.Empty<object?>() : args.ToArray()));

        return ValueTask.FromResult(default(TValue)!);
    }
}

internal sealed record JsInvocation(string Identifier, IReadOnlyList<object?> Arguments);
