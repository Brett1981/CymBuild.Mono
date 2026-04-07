#nullable enable

using Concursus.API.Sage.SOAP;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Dedicated hosted worker for Phase 5 Sage transaction submission.
    ///
    /// Responsibilities:
    /// - poll SCore.IntegrationOutbox for TransactionApprovedForSageSubmission events
    /// - honour both worker-level enablement and Integrations:SageApi:Enabled
    /// - claim one outbox row at a time
    /// - invoke ITransactionToSageSubmissionService
    /// - mark the outbox row as succeeded or failed
    ///
    /// This hardened version adds:
    /// - more granular progress logging
    /// - exception message + full exception logging
    /// - defensive error handling around failure recording
    /// - clearer diagnosis of whether the worker fails:
    ///   * before scope creation
    ///   * during DI resolution
    ///   * during outbox claim
    ///   * during submission
    ///   * during failure recording
    /// </summary>
    public sealed class SageTransactionSubmissionWorker : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly IOptionsMonitor<SageApiOptions> _sageApiOptions;
        private readonly IOptionsMonitor<SageTransactionSubmissionWorkerOptions> _workerOptions;
        private readonly ILogger<SageTransactionSubmissionWorker> _logger;

        public SageTransactionSubmissionWorker(
            IServiceScopeFactory scopeFactory,
            IOptionsMonitor<SageApiOptions> sageApiOptions,
            IOptionsMonitor<SageTransactionSubmissionWorkerOptions> workerOptions,
            ILogger<SageTransactionSubmissionWorker> logger)
        {
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            _sageApiOptions = sageApiOptions ?? throw new ArgumentNullException(nameof(sageApiOptions));
            _workerOptions = workerOptions ?? throw new ArgumentNullException(nameof(workerOptions));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));

            _logger.LogInformation("SageTransactionSubmissionWorker constructed.");
        }

        /// <summary>
        /// Main worker loop.
        /// </summary>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("SageTransactionSubmissionWorker ExecuteAsync entered.");
            _logger.LogInformation("SageTransactionSubmissionWorker started.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var workerOptions = _workerOptions.CurrentValue;
                    var sageOptions = _sageApiOptions.CurrentValue;

                    _logger.LogDebug(
                        "SageTransactionSubmissionWorker tick. WorkerEnabled={WorkerEnabled}, EventType={EventType}, IntervalSeconds={IntervalSeconds}, MaxAttempts={MaxAttempts}, ClaimTimeoutMinutes={ClaimTimeoutMinutes}, SageEnabled={SageEnabled}, BaseUrl={BaseUrl}",
                        workerOptions.Enabled,
                        workerOptions.EventType,
                        workerOptions.IntervalSeconds,
                        workerOptions.MaxAttempts,
                        workerOptions.ClaimTimeoutMinutes,
                        sageOptions.Enabled,
                        sageOptions.BaseUrl);

                    if (!workerOptions.Enabled)
                    {
                        _logger.LogInformation(
                            "SageTransactionSubmissionWorker is disabled by worker configuration. EventType={EventType}",
                            workerOptions.EventType);

                        await DelayAsync(workerOptions.IntervalSeconds, stoppingToken);
                        continue;
                    }

                    if (!sageOptions.Enabled)
                    {
                        _logger.LogInformation(
                            "SageTransactionSubmissionWorker is idling because Integrations:SageApi:Enabled = false.");

                        await DelayAsync(workerOptions.IntervalSeconds, stoppingToken);
                        continue;
                    }

                    var handledAny = await ProcessNextAvailableItemAsync(workerOptions, stoppingToken);

                    if (!handledAny)
                    {
                        _logger.LogDebug("SageTransactionSubmissionWorker found no eligible outbox rows.");
                        await DelayAsync(workerOptions.IntervalSeconds, stoppingToken);
                    }
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    _logger.LogInformation("SageTransactionSubmissionWorker stopping due to cancellation.");
                }
                catch (Exception ex)
                {
                    _logger.LogError(
                        ex,
                        "Unhandled error in SageTransactionSubmissionWorker main loop. Message={Message}. FullException={FullException}",
                        ex.Message,
                        ex.ToString());

                    await DelayAsync(_workerOptions.CurrentValue.IntervalSeconds, stoppingToken);
                }
            }

            _logger.LogInformation("SageTransactionSubmissionWorker stopped.");
        }

        /// <summary>
        /// Attempts to claim and process a single eligible outbox row.
        /// Returns true when a row was claimed and processed (successfully or unsuccessfully).
        /// Returns false when no eligible row was available.
        /// </summary>
        private async Task<bool> ProcessNextAvailableItemAsync(
            SageTransactionSubmissionWorkerOptions workerOptions,
            CancellationToken cancellationToken)
        {
            _logger.LogInformation(
                "SageTransactionSubmissionWorker attempting outbox claim. EventType={EventType}, MaxAttempts={MaxAttempts}, ClaimTimeoutMinutes={ClaimTimeoutMinutes}",
                workerOptions.EventType,
                workerOptions.MaxAttempts,
                workerOptions.ClaimTimeoutMinutes);

            _logger.LogDebug("SageTransactionSubmissionWorker creating DI scope.");

            using var scope = _scopeFactory.CreateScope();

            _logger.LogDebug("Resolving ITransactionApprovedOutboxRepository.");
            var outboxRepository = scope.ServiceProvider.GetRequiredService<ITransactionApprovedOutboxRepository>();

            _logger.LogDebug("Resolving ITransactionToSageSubmissionService.");
            var submissionService = scope.ServiceProvider.GetRequiredService<ITransactionToSageSubmissionService>();

            var token = Guid.NewGuid().ToString("N");

            _logger.LogDebug(
                "SageTransactionSubmissionWorker created processing token {Token}.",
                token);

            _logger.LogDebug("Calling TryClaimNextAsync.");

            var outboxItem = await outboxRepository.TryClaimNextAsync(
                workerOptions.EventType,
                token,
                workerOptions.MaxAttempts,
                workerOptions.ClaimTimeoutMinutes,
                cancellationToken);

            if (outboxItem is null)
            {
                _logger.LogDebug("SageTransactionSubmissionWorker claim returned no row.");
                return false;
            }

            _logger.LogInformation(
                "SageTransactionSubmissionWorker claimed outbox row. OutboxId={OutboxId}, EventType={EventType}, Attempts={Attempts}, CreatedOnUtc={CreatedOnUtc}",
                outboxItem.OutboxId,
                outboxItem.EventType,
                outboxItem.PublishAttempts,
                outboxItem.CreatedOnUtc);

            try
            {
                _logger.LogInformation(
                    "Invoking ITransactionToSageSubmissionService for OutboxId={OutboxId}.",
                    outboxItem.OutboxId);

                var result = await submissionService.ProcessApprovedTransactionAsync(
                    outboxItem.PayloadJson,
                    cancellationToken);

                var isSuccess = ResolveResultIsSuccess(result);
                var isRetryable = ResolveResultIsRetryable(result);
                var message = ResolveResultMessage(result);

                _logger.LogInformation(
                    "Sage transaction submission service returned. OutboxId={OutboxId}, IsSuccess={IsSuccess}, IsRetryable={IsRetryable}, Message={Message}",
                    outboxItem.OutboxId,
                    isSuccess,
                    isRetryable,
                    message);

                if (isSuccess)
                {
                    await outboxRepository.MarkSucceededAsync(
                        outboxItem.OutboxId,
                        token,
                        message,
                        cancellationToken);

                    _logger.LogInformation(
                        "Sage transaction outbox row marked succeeded. OutboxId={OutboxId}",
                        outboxItem.OutboxId);

                    return true;
                }

                var failureMessage = string.IsNullOrWhiteSpace(message)
                    ? "Sage transaction submission returned an unsuccessful result."
                    : message;

                await SafeMarkFailedAsync(
                    outboxRepository,
                    outboxItem.OutboxId,
                    token,
                    failureMessage,
                    isRetryable,
                    cancellationToken);

                _logger.LogWarning(
                    "Sage transaction outbox row marked failed. OutboxId={OutboxId}, Retryable={Retryable}, Message={Message}",
                    outboxItem.OutboxId,
                    isRetryable,
                    failureMessage);

                return true;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                _logger.LogInformation(
                    "Sage transaction outbox processing cancelled. OutboxId={OutboxId}",
                    outboxItem.OutboxId);

                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Unhandled exception while processing Sage transaction outbox row. OutboxId={OutboxId}, Message={Message}, FullException={FullException}",
                    outboxItem.OutboxId,
                    ex.Message,
                    ex.ToString());

                await SafeMarkFailedAsync(
                    outboxRepository,
                    outboxItem.OutboxId,
                    token,
                    ex.ToString(),
                    isRetryable: true,
                    cancellationToken);

                return true;
            }
        }

        /// <summary>
        /// Safely records a failed outbox row.
        /// This ensures we log both the original exception and any secondary failure
        /// that occurs while attempting to record that failure.
        /// </summary>
        private async Task SafeMarkFailedAsync(
            ITransactionApprovedOutboxRepository outboxRepository,
            long outboxId,
            string token,
            string error,
            bool isRetryable,
            CancellationToken cancellationToken)
        {
            try
            {
                await outboxRepository.MarkFailedAsync(
                    outboxId,
                    token,
                    string.IsNullOrWhiteSpace(error)
                        ? "Unhandled Sage transaction submission worker failure."
                        : error,
                    isRetryable,
                    cancellationToken);
            }
            catch (Exception markFailedEx)
            {
                _logger.LogError(
                    markFailedEx,
                    "Failed to record Sage transaction outbox failure. OutboxId={OutboxId}, Retryable={Retryable}, Message={Message}, FullException={FullException}",
                    outboxId,
                    isRetryable,
                    markFailedEx.Message,
                    markFailedEx.ToString());
            }
        }

        /// <summary>
        /// Delays the worker loop using the configured interval.
        /// </summary>
        private static Task DelayAsync(int intervalSeconds, CancellationToken cancellationToken)
        {
            var seconds = intervalSeconds <= 0 ? 10 : intervalSeconds;
            return Task.Delay(TimeSpan.FromSeconds(seconds), cancellationToken);
        }

        #region Compatibility Helpers

        /// <summary>
        /// Resolves whether the returned process result represents success.
        /// Supports multiple possible property names for compatibility.
        /// </summary>
        private static bool ResolveResultIsSuccess(object? result)
        {
            if (result is null)
            {
                return false;
            }

            return ResolveBoolProperty(
                result,
                "IsSuccess",
                "Success",
                "Succeeded");
        }

        /// <summary>
        /// Resolves whether the returned process result should be retried.
        /// Defaults to true when no clearer signal is available.
        /// </summary>
        private static bool ResolveResultIsRetryable(object? result)
        {
            if (result is null)
            {
                return true;
            }

            if (TryResolveBoolProperty(
                result,
                out var value,
                "IsRetryable",
                "Retryable",
                "ShouldRetry",
                "IsRetryableFailure"))
            {
                return value;
            }

            if (ResolveBoolProperty(result, "IsNonRetryable", "NonRetryable"))
            {
                return false;
            }

            return true;
        }

        /// <summary>
        /// Resolves the most useful human-readable message from the result.
        /// </summary>
        private static string? ResolveResultMessage(object? result)
        {
            return ResolveStringProperty(
                result,
                "Message",
                "Detail",
                "ErrorMessage",
                "StatusMessage");
        }

        /// <summary>
        /// Resolves a boolean property by trying multiple possible names.
        /// </summary>
        private static bool ResolveBoolProperty(object source, params string[] names)
        {
            return TryResolveBoolProperty(source, out var value, names) && value;
        }

        /// <summary>
        /// Attempts to resolve a boolean property from an object by reflection.
        /// Supports bool, byte, int, and string-backed values.
        /// </summary>
        private static bool TryResolveBoolProperty(object source, out bool value, params string[] names)
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
                    value = boolValue;
                    return true;
                }

                if (rawValue is byte byteValue)
                {
                    value = byteValue != 0;
                    return true;
                }

                if (rawValue is int intValue)
                {
                    value = intValue != 0;
                    return true;
                }

                if (rawValue is string text && bool.TryParse(text, out var parsed))
                {
                    value = parsed;
                    return true;
                }
            }

            value = false;
            return false;
        }

        /// <summary>
        /// Attempts to resolve a string property from an object by reflection.
        /// </summary>
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