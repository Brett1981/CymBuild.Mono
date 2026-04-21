using System;
using System.Threading.Tasks;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public abstract class AssistantGrpcServiceBase
{
    internal static readonly Timestamp UnixEpochTimestamp = Timestamp.FromDateTime(DateTime.SpecifyKind(DateTime.UnixEpoch, DateTimeKind.Utc));

    internal static Guid ParseRequiredGuid(string value, string fieldName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} is required.");
        }

        if (!Guid.TryParse(value, out var guid) || guid == Guid.Empty)
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} must be a valid non-empty GUID.");
        }

        return guid;
    }

    internal static string RequireText(string? value, string fieldName, int? maxLength = null)
    {
        var trimmed = value?.Trim();

        if (string.IsNullOrWhiteSpace(trimmed))
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} is required.");
        }

        if (maxLength.HasValue && trimmed.Length > maxLength.Value)
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} exceeds max length of {maxLength.Value}.");
        }

        return trimmed;
    }

    internal static int RequirePositiveInt(int value, string fieldName)
    {
        if (value <= 0)
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} must be greater than zero.");
        }

        return value;
    }

    internal static int RequireNonNegativeInt(int value, string fieldName)
    {
        if (value < 0)
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} must be zero or greater.");
        }

        return value;
    }

    internal static string? NullIfWhiteSpace(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    internal static RpcException CreateRpcException(StatusCode statusCode, string message)
        => new(new Status(statusCode, message));

    internal static Timestamp ToTimestamp(DateTime? valueUtc)
        => valueUtc.HasValue
            ? Timestamp.FromDateTime(DateTime.SpecifyKind(valueUtc.Value, DateTimeKind.Utc))
            : UnixEpochTimestamp;

    internal static StringValue? ToStringValue(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : new StringValue { Value = value };

    internal static Int32Value? ToInt32Value(int? value)
        => value.HasValue ? new Int32Value { Value = value.Value } : null;

    internal static T Execute<T>(Func<T> action, ILogger logger, string operationName)
    {
        try
        {
            return action();
        }
        catch (RpcException)
        {
            throw;
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogWarning(ex, "Assistant gRPC {OperationName} not found.", operationName);
            throw CreateRpcException(StatusCode.NotFound, ex.Message);
        }
        catch (ArgumentException ex)
        {
            logger.LogWarning(ex, "Assistant gRPC {OperationName} invalid argument.", operationName);
            throw CreateRpcException(StatusCode.InvalidArgument, ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            logger.LogWarning(ex, "Assistant gRPC {OperationName} failed precondition.", operationName);
            throw CreateRpcException(StatusCode.FailedPrecondition, ex.Message);
        }
        catch (OperationCanceledException ex)
        {
            logger.LogInformation(ex, "Assistant gRPC {OperationName} cancelled.", operationName);
            throw CreateRpcException(StatusCode.Cancelled, "The request was cancelled.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Assistant gRPC {OperationName} failed.", operationName);
            throw CreateRpcException(StatusCode.Internal, "An unexpected assistant service error occurred.");
        }
    }

    internal static async Task<T> ExecuteAsync<T>(Func<Task<T>> action, ILogger logger, string operationName)
    {
        try
        {
            return await action().ConfigureAwait(false);
        }
        catch (RpcException)
        {
            throw;
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogWarning(ex, "Assistant gRPC {OperationName} not found.", operationName);
            throw CreateRpcException(StatusCode.NotFound, ex.Message);
        }
        catch (ArgumentException ex)
        {
            logger.LogWarning(ex, "Assistant gRPC {OperationName} invalid argument.", operationName);
            throw CreateRpcException(StatusCode.InvalidArgument, ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            logger.LogWarning(ex, "Assistant gRPC {OperationName} failed precondition.", operationName);
            throw CreateRpcException(StatusCode.FailedPrecondition, ex.Message);
        }
        catch (OperationCanceledException ex)
        {
            logger.LogInformation(ex, "Assistant gRPC {OperationName} cancelled.", operationName);
            throw CreateRpcException(StatusCode.Cancelled, "The request was cancelled.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Assistant gRPC {OperationName} failed.", operationName);
            throw CreateRpcException(StatusCode.Internal, "An unexpected assistant service error occurred.");
        }
    }
}
