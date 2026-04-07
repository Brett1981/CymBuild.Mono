#nullable enable

using Concursus.API.Sage.SOAP;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Phase 5 orchestration service for approved transaction -> Sage sales order submission.
    ///
    /// Important compatibility note:
    /// This implementation deliberately avoids hard-coding certain property names on
    /// existing event/status/claim/eligibility models where the current codebase may
    /// use slightly different naming than the scaffold.
    /// </summary>
    public sealed class TransactionToSageSubmissionService : ITransactionToSageSubmissionService
    {
        private static readonly JsonSerializerOptions ResponseJsonOptions = new()
        {
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        private readonly ITransactionToSageReadRepository _readRepository;
        private readonly ITransactionToSageEligibilityValidator _eligibilityValidator;
        private readonly ITransactionToSageIdempotencyService _idempotencyService;
        private readonly IApprovedTransactionForSagePayloadFactory _payloadFactory;
        private readonly ISageSalesOrderGateway _gateway;
        private readonly IOptionsMonitor<SageApiOptions> _sageOptions;
        private readonly IOptionsMonitor<SageTransactionSubmissionWorkerOptions> _workerOptions;
        private readonly ILogger<TransactionToSageSubmissionService> _logger;

        public TransactionToSageSubmissionService(
            ITransactionToSageReadRepository readRepository,
            ITransactionToSageEligibilityValidator eligibilityValidator,
            ITransactionToSageIdempotencyService idempotencyService,
            IApprovedTransactionForSagePayloadFactory payloadFactory,
            ISageSalesOrderGateway gateway,
            IOptionsMonitor<SageApiOptions> sageOptions,
            IOptionsMonitor<SageTransactionSubmissionWorkerOptions> workerOptions,
            ILogger<TransactionToSageSubmissionService> logger)
        {
            _readRepository = readRepository ?? throw new ArgumentNullException(nameof(readRepository));
            _eligibilityValidator = eligibilityValidator ?? throw new ArgumentNullException(nameof(eligibilityValidator));
            _idempotencyService = idempotencyService ?? throw new ArgumentNullException(nameof(idempotencyService));
            _payloadFactory = payloadFactory ?? throw new ArgumentNullException(nameof(payloadFactory));
            _gateway = gateway ?? throw new ArgumentNullException(nameof(gateway));
            _sageOptions = sageOptions ?? throw new ArgumentNullException(nameof(sageOptions));
            _workerOptions = workerOptions ?? throw new ArgumentNullException(nameof(workerOptions));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<TransactionToSageProcessResult> ProcessApprovedTransactionAsync(
            string outboxPayloadJson,
            CancellationToken cancellationToken = default)
        {
            TransactionApprovedForSageSubmissionEvent? approvedEvent = null;
            ApprovedTransactionForSageReadModel? transaction = null;

            string requestPayloadJson = string.Empty;
            string responsePayloadJson = string.Empty;

            bool claimAcquired = false;

            try
            {
                if (string.IsNullOrWhiteSpace(outboxPayloadJson))
                {
                    return TransactionToSageProcessResult.NonRetryableFailure(
                        Guid.Empty,
                        Guid.Empty,
                        "TransactionApprovedForSageSubmission payload was empty.",
                        "invalid_outbox_payload");
                }

                approvedEvent = _readRepository.DeserializeApprovedTransactionEvent(outboxPayloadJson);

                if (approvedEvent is null)
                {
                    return TransactionToSageProcessResult.NonRetryableFailure(
                        Guid.Empty,
                        Guid.Empty,
                        "Could not deserialize TransactionApprovedForSageSubmission event payload.",
                        "invalid_outbox_payload");
                }

                var transitionGuid = ResolveApprovedEventTransitionGuid(approvedEvent);
                var eventTransactionGuid = ResolveApprovedEventTransactionGuid(approvedEvent);

                _logger.LogInformation(
                    "Starting Sage submission processing. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, EventGuid={EventGuid}",
                    transitionGuid,
                    eventTransactionGuid,
                    approvedEvent.EventGuid);

                if (!approvedEvent.IsValidForProcessing())
                {
                    _logger.LogError(
                        "Approved transaction event is invalid for processing. EventGuid={EventGuid}, TransitionGuid={TransitionGuid}, TransitionId={TransitionId}, TransactionGuid={TransactionGuid}, TransactionId={TransactionId}, EventType={EventType}",
                        approvedEvent.EventGuid,
                        approvedEvent.TransitionGuid,
                        approvedEvent.TransitionId,
                        approvedEvent.TransactionGuid,
                        approvedEvent.TransactionId,
                        approvedEvent.EventType);

                    return TransactionToSageProcessResult.NonRetryableFailure(
                        transitionGuid,
                        eventTransactionGuid,
                        "Deserialized TransactionApprovedForSageSubmission event is missing required identifiers.",
                        "invalid_outbox_payload");
                }

                transaction = await _readRepository.GetApprovedTransactionForSageAsync(
                    transitionGuid,
                    cancellationToken);

                if (transaction is null)
                {
                    _logger.LogWarning(
                        "Approved transaction read model could not be loaded. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}",
                        transitionGuid,
                        eventTransactionGuid);

                    return TransactionToSageProcessResult.RetryableFailure(
                        transitionGuid,
                        eventTransactionGuid,
                        "Approved transaction read model could not be loaded.",
                        "read_model_not_found");
                }

                _logger.LogInformation(
                    "Loaded approved transaction read model. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, TransactionId={TransactionId}",
                    transaction.TransitionGuid,
                    transaction.TransactionGuid,
                    transaction.TransactionId);

                var status = await _idempotencyService.GetStatusAsync(
                    transaction.TransactionGuid,
                    cancellationToken);

                var alreadySubmitted = ResolveStatusIsSuccessfullySubmitted(status);

                var eligibility = await _eligibilityValidator.ValidateAsync(
                    transaction,
                    _sageOptions.CurrentValue.Enabled,
                    alreadySubmitted: alreadySubmitted,
                    cancellationToken);

                if (!eligibility.IsEligible)
                {
                    var eligibilityCode = ResolveEligibilityFailureCode(eligibility);

                    _logger.LogInformation(
                        "Approved transaction is not eligible for Sage submission. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, FailureCode={FailureCode}, Message={Message}",
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        eligibilityCode,
                        eligibility.Message);

                    return TransactionToSageProcessResult.NotEligible(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        eligibility.Message,
                        eligibilityCode);
                }

                if (alreadySubmitted)
                {
                    _logger.LogInformation(
                        "Transaction already submitted to Sage. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, SageOrderId={SageOrderId}, SageOrderNumber={SageOrderNumber}",
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        ResolveStringProperty(status, "SageOrderId"),
                        ResolveStringProperty(status, "SageOrderNumber"));

                    return TransactionToSageProcessResult.AlreadyProcessed(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        ResolveStringProperty(status, "SageOrderId"),
                        ResolveStringProperty(status, "SageOrderNumber"),
                        "Transaction has already been successfully submitted to Sage.");
                }

                var claimTimeoutMinutes = ResolveClaimTimeoutMinutes(_workerOptions.CurrentValue);

                var claim = await _idempotencyService.TryClaimAsync(
                    transaction.TransactionId,
                    transaction.TransactionGuid,
                    transaction.TransitionGuid,
                    transaction.ActorIdentityId ?? -1,
                    claimTimeoutMinutes,
                    cancellationToken);

                claimAcquired = ResolveClaimIsClaimed(claim);
                var isAlreadyCompleted = ResolveClaimIsAlreadyCompleted(claim);
                var staleClaimReclaimed = ResolveBoolProperty(claim, "StaleClaimReclaimed");

                _logger.LogInformation(
                    "Transaction Sage claim evaluated. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, ClaimAcquired={ClaimAcquired}, AlreadyProcessed={AlreadyProcessed}, InProgressElsewhere={InProgressElsewhere}, StaleClaimReclaimed={StaleClaimReclaimed}, StatusCode={StatusCode}, Message={Message}",
                    transaction.TransitionGuid,
                    transaction.TransactionGuid,
                    claimAcquired,
                    ResolveBoolProperty(claim, "AlreadyProcessed"),
                    ResolveBoolProperty(claim, "InProgressElsewhere"),
                    staleClaimReclaimed,
                    ResolveStringProperty(claim, "StatusCode"),
                    ResolveStringProperty(claim, "Message"));

                if (!claimAcquired)
                {
                    if (isAlreadyCompleted)
                    {
                        return TransactionToSageProcessResult.AlreadyProcessed(
                            transaction.TransitionGuid,
                            transaction.TransactionGuid,
                            ResolveStringProperty(claim, "SageOrderId"),
                            ResolveStringProperty(claim, "SageOrderNumber"),
                            "Transaction was already completed by a prior submission.");
                    }

                    return TransactionToSageProcessResult.RetryableFailure(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        "Transaction submission is currently marked in progress and could not be claimed.",
                        "submission_already_in_progress");
                }

                requestPayloadJson = _payloadFactory.BuildJson(transaction);
                var requestDto = _payloadFactory.Build(transaction);

                _logger.LogInformation(
                    "Built Sage request payload. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, AccountReference={AccountReference}, LineCount={LineCount}",
                    transaction.TransitionGuid,
                    transaction.TransactionGuid,
                    requestDto.AccountReference,
                    requestDto.Lines?.Count ?? 0);

                var responseDto = await _gateway.CreateSalesOrderAsync(requestDto, cancellationToken);
                responsePayloadJson = JsonSerializer.Serialize(responseDto, ResponseJsonOptions);

                _logger.LogInformation(
                    "Received Sage gateway response. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, WrapperStatus={WrapperStatus}, HttpStatusCode={HttpStatusCode}, OrderId={OrderId}",
                    transaction.TransitionGuid,
                    transaction.TransactionGuid,
                    responseDto.Status,
                    responseDto.HttpStatusCode,
                    responseDto.OrderId);

                if (responseDto.IsOk && !string.IsNullOrWhiteSpace(responseDto.OrderId))
                {
                    await _idempotencyService.MarkSuccessAsync(
                        transaction.TransactionGuid,
                        transaction.TransitionGuid,
                        sageOrderId: responseDto.OrderId,
                        sageOrderNumber: responseDto.OrderId,
                        responseStatus: responseDto.Status,
                        responseDetail: responseDto.Detail,
                        requestPayloadJson: requestPayloadJson,
                        responsePayloadJson: responsePayloadJson,
                        updatedByUserId: transaction.ActorIdentityId ?? -1,
                        cancellationToken: cancellationToken);

                    _logger.LogInformation(
                        "Transaction successfully submitted to Sage. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, SageOrderId={SageOrderId}",
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        responseDto.OrderId);

                    return TransactionToSageProcessResult.Success(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        responseDto.OrderId,
                        responseDto.OrderId,
                        "Transaction successfully submitted to Sage sales-orders endpoint.");
                }

                if (responseDto.IsOk && string.IsNullOrWhiteSpace(responseDto.OrderId))
                {
                    const string malformedSuccessMessage =
                        "Sage wrapper returned a successful status but did not provide an order identifier.";

                    await _idempotencyService.MarkFailureAsync(
                        transaction.TransactionGuid,
                        transaction.TransitionGuid,
                        errorMessage: malformedSuccessMessage,
                        isRetryable: false,
                        responseStatus: responseDto.Status,
                        responseDetail: responseDto.Detail,
                        requestPayloadJson: requestPayloadJson,
                        responsePayloadJson: responsePayloadJson,
                        updatedByUserId: transaction.ActorIdentityId ?? -1,
                        cancellationToken: cancellationToken);

                    _logger.LogError(
                        "Malformed successful Sage response. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, HttpStatusCode={HttpStatusCode}",
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        responseDto.HttpStatusCode);

                    return TransactionToSageProcessResult.NonRetryableFailure(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        malformedSuccessMessage,
                        "sage_malformed_success_payload");
                }

                var isRetryable = IsRetryableGatewayFailure(responseDto);
                var failureCode = ResolveGatewayFailureCode(responseDto);
                var failureMessage = string.IsNullOrWhiteSpace(responseDto.Detail)
                    ? "Sage sales-order submission failed."
                    : responseDto.Detail;

                await _idempotencyService.MarkFailureAsync(
                    transaction.TransactionGuid,
                    transaction.TransitionGuid,
                    errorMessage: failureMessage,
                    isRetryable: isRetryable,
                    responseStatus: responseDto.Status,
                    responseDetail: responseDto.Detail,
                    requestPayloadJson: requestPayloadJson,
                    responsePayloadJson: responsePayloadJson,
                    updatedByUserId: transaction.ActorIdentityId ?? -1,
                    cancellationToken: cancellationToken);

                _logger.LogWarning(
                    "Sage submission failed. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}, FailureCode={FailureCode}, IsRetryable={IsRetryable}, HttpStatusCode={HttpStatusCode}, Detail={Detail}",
                    transaction.TransitionGuid,
                    transaction.TransactionGuid,
                    failureCode,
                    isRetryable,
                    responseDto.HttpStatusCode,
                    responseDto.Detail);

                return isRetryable
                    ? TransactionToSageProcessResult.RetryableFailure(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        failureMessage,
                        failureCode)
                    : TransactionToSageProcessResult.NonRetryableFailure(
                        transaction.TransitionGuid,
                        transaction.TransactionGuid,
                        failureMessage,
                        failureCode);
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogError(
                    ex,
                    "Non-retryable Phase 5 mapping/submission failure. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}",
                    transaction?.TransitionGuid,
                    transaction?.TransactionGuid);

                if (transaction is not null && claimAcquired)
                {
                    await SafeMarkFailureAsync(
                        transaction,
                        ex.Message,
                        isRetryable: false,
                        requestPayloadJson,
                        responsePayloadJson,
                        cancellationToken);
                }

                return TransactionToSageProcessResult.NonRetryableFailure(
                    transaction?.TransitionGuid
                        ?? (approvedEvent is null ? Guid.Empty : ResolveApprovedEventTransitionGuidSafe(approvedEvent)),
                    transaction?.TransactionGuid
                        ?? (approvedEvent is null ? Guid.Empty : ResolveApprovedEventTransactionGuid(approvedEvent)),
                    ex.Message,
                    "mapping_validation_failed");
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Retryable Phase 5 submission failure. TransitionGuid={TransitionGuid}, TransactionGuid={TransactionGuid}",
                    transaction?.TransitionGuid,
                    transaction?.TransactionGuid);

                if (transaction is not null && claimAcquired)
                {
                    await SafeMarkFailureAsync(
                        transaction,
                        ex.Message,
                        isRetryable: true,
                        requestPayloadJson,
                        responsePayloadJson,
                        cancellationToken);
                }

                return TransactionToSageProcessResult.RetryableFailure(
                    transaction?.TransitionGuid
                        ?? (approvedEvent is null ? Guid.Empty : ResolveApprovedEventTransitionGuidSafe(approvedEvent)),
                    transaction?.TransactionGuid
                        ?? (approvedEvent is null ? Guid.Empty : ResolveApprovedEventTransactionGuid(approvedEvent)),
                    ex.Message,
                    "submission_exception");
            }
        }

        private async Task SafeMarkFailureAsync(
            ApprovedTransactionForSageReadModel transaction,
            string errorMessage,
            bool isRetryable,
            string requestPayloadJson,
            string responsePayloadJson,
            CancellationToken cancellationToken)
        {
            try
            {
                await _idempotencyService.MarkFailureAsync(
                    transaction.TransactionGuid,
                    transaction.TransitionGuid,
                    errorMessage,
                    isRetryable,
                    responseStatus: "Error",
                    responseDetail: errorMessage,
                    requestPayloadJson: requestPayloadJson ?? string.Empty,
                    responsePayloadJson: responsePayloadJson ?? string.Empty,
                    updatedByUserId: transaction.ActorIdentityId ?? -1,
                    cancellationToken: cancellationToken);
            }
            catch (Exception markFailureEx)
            {
                _logger.LogError(
                    markFailureEx,
                    "Failed to record Sage submission failure. TransactionGuid={TransactionGuid}, TransitionGuid={TransitionGuid}",
                    transaction.TransactionGuid,
                    transaction.TransitionGuid);
            }
        }

        private static int ResolveClaimTimeoutMinutes(SageTransactionSubmissionWorkerOptions options)
        {
            if (options is null)
            {
                return 15;
            }

            return options.ClaimTimeoutMinutes <= 0
                ? 15
                : options.ClaimTimeoutMinutes;
        }

        #region Compatibility Helpers

        private static Guid ResolveApprovedEventTransitionGuid(TransactionApprovedForSageSubmissionEvent approvedEvent)
        {
            if (approvedEvent is null)
            {
                throw new ArgumentNullException(nameof(approvedEvent));
            }

            if (approvedEvent.TransitionGuid != Guid.Empty)
            {
                return approvedEvent.TransitionGuid;
            }

            var value = ResolveGuidProperty(
                approvedEvent,
                "TransitionGuid",
                "TransactionBatchTransitionGuid",
                "BatchTransitionGuid",
                "SourceTransitionGuid");

            if (value != Guid.Empty)
            {
                return value;
            }

            throw new InvalidOperationException(
                "Approved transaction event does not expose a usable transition guid.");
        }

        private static Guid ResolveApprovedEventTransitionGuidSafe(TransactionApprovedForSageSubmissionEvent approvedEvent)
        {
            try
            {
                return ResolveApprovedEventTransitionGuid(approvedEvent);
            }
            catch
            {
                return Guid.Empty;
            }
        }

        private static Guid ResolveApprovedEventTransactionGuid(TransactionApprovedForSageSubmissionEvent approvedEvent)
        {
            if (approvedEvent is null)
            {
                return Guid.Empty;
            }

            if (approvedEvent.TransactionGuid != Guid.Empty)
            {
                return approvedEvent.TransactionGuid;
            }

            return ResolveGuidProperty(
                approvedEvent,
                "TransactionGuid",
                "ApprovedTransactionGuid",
                "SourceTransactionGuid");
        }

        private static bool ResolveStatusIsSuccessfullySubmitted(object? status)
        {
            if (status is null)
            {
                return false;
            }

            return ResolveBoolProperty(
                status,
                "IsSuccessfullySubmitted",
                "IsAlreadyProcessed",
                "IsSubmitted",
                "IsSuccess",
                "Success",
                "Completed",
                "IsCompleted");
        }

        private static bool ResolveClaimIsClaimed(object? claim)
        {
            if (claim is null)
            {
                return false;
            }

            return ResolveBoolProperty(
                claim,
                "ClaimAcquired",
                "IsClaimed",
                "Claimed",
                "Succeeded",
                "Success",
                "CanProcess");
        }

        private static bool ResolveClaimIsAlreadyCompleted(object? claim)
        {
            if (claim is null)
            {
                return false;
            }

            return ResolveBoolProperty(
                claim,
                "AlreadyProcessed",
                "IsAlreadyCompleted",
                "AlreadyCompleted",
                "IsDuplicateCompleted",
                "WasPreviouslySubmitted");
        }

        private static string ResolveEligibilityFailureCode(object? eligibility)
        {
            var code = ResolveStringProperty(
                eligibility,
                "FailureCode",
                "Code",
                "ReasonCode",
                "ErrorCode");

            return string.IsNullOrWhiteSpace(code)
                ? "not_eligible"
                : code;
        }

        private static bool IsRetryableGatewayFailure(SageCreateSalesOrderResponse? response)
        {
            if (response is null)
            {
                return true;
            }

            if (response.HttpStatusCode is null)
            {
                return true;
            }

            var statusCode = response.HttpStatusCode.Value;

            if (statusCode == 408 || statusCode == 425 || statusCode == 429)
            {
                return true;
            }

            if (statusCode >= 500)
            {
                return true;
            }

            return false;
        }

        private static string ResolveGatewayFailureCode(SageCreateSalesOrderResponse? response)
        {
            if (response is null)
            {
                return "sage_wrapper_unknown";
            }

            return response.HttpStatusCode switch
            {
                400 => "sage_validation_failed",
                401 => "sage_auth_failed",
                403 => "sage_forbidden",
                404 => "sage_endpoint_not_found",
                408 => "sage_timeout",
                409 => "sage_conflict",
                422 => "sage_unprocessable_entity",
                425 => "sage_too_early",
                429 => "sage_rate_limited",
                >= 500 => "sage_server_error",
                _ => "sage_wrapper_error"
            };
        }

        private static Guid ResolveGuidProperty(object source, params string[] names)
        {
            foreach (var name in names)
            {
                var property = source.GetType().GetProperty(
                    name,
                    BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);

                if (property is null)
                {
                    continue;
                }

                var rawValue = property.GetValue(source);

                if (rawValue is null)
                {
                    continue;
                }

                if (rawValue is Guid guidValue)
                {
                    return guidValue;
                }

                var textValue = rawValue.ToString();
                if (!string.IsNullOrWhiteSpace(textValue) && Guid.TryParse(textValue, out var parsedGuid))
                {
                    return parsedGuid;
                }
            }

            return Guid.Empty;
        }

        private static bool ResolveBoolProperty(object source, params string[] names)
        {
            foreach (var name in names)
            {
                var property = source.GetType().GetProperty(
                    name,
                    BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);

                if (property is null)
                {
                    continue;
                }

                var rawValue = property.GetValue(source);

                if (rawValue is bool boolValue)
                {
                    return boolValue;
                }

                if (rawValue is byte byteValue)
                {
                    return byteValue != 0;
                }

                if (rawValue is int intValue)
                {
                    return intValue != 0;
                }

                if (rawValue is long longValue)
                {
                    return longValue != 0;
                }

                if (rawValue is string text)
                {
                    if (bool.TryParse(text, out var parsedBool))
                    {
                        return parsedBool;
                    }

                    if (int.TryParse(text, out var parsedInt))
                    {
                        return parsedInt != 0;
                    }
                }
            }

            return false;
        }

        private static string? ResolveStringProperty(object? source, params string[] names)
        {
            if (source is null)
            {
                return null;
            }

            foreach (var name in names)
            {
                var property = source.GetType().GetProperty(
                    name,
                    BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);

                if (property is null)
                {
                    continue;
                }

                var rawValue = property.GetValue(source);

                if (rawValue is null)
                {
                    continue;
                }

                var text = rawValue.ToString();

                if (!string.IsNullOrWhiteSpace(text))
                {
                    return text.Trim();
                }
            }

            return null;
        }

        #endregion Compatibility Helpers
    }
}