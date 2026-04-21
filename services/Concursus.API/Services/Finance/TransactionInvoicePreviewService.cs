#nullable enable

using Concursus.API.Classes;
using Concursus.API.Components;
using Concursus.API.Interfaces;
using Concursus.Common.Shared.Models.Finance;
using Concursus.EF.Finance;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace Concursus.API.Services.Finance
{
    public sealed class TransactionInvoicePreviewService : ITransactionInvoicePreviewService
    {
        private readonly ITransactionInvoicePreviewRepository _transactionInvoicePreviewRepository;
        private readonly WordDocumentService _wordDocumentService;
        private readonly IConfiguration _config;
        private readonly ISharepointService _sharepointService;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly ILogger<TransactionInvoicePreviewService> _logger;

        private static readonly Guid FinanceInvoicePreviewMergeDocumentGuid =
            Guid.Parse("5AEA2D5D-3B1D-4AC7-A0A3-D4CC5AC2CB2B");


        public TransactionInvoicePreviewService(
            ITransactionInvoicePreviewRepository transactionInvoicePreviewRepository,
            WordDocumentService wordDocumentService,
            IConfiguration config,
            ISharepointService sharepointService,
            IHttpContextAccessor httpContextAccessor,
            ILogger<TransactionInvoicePreviewService> logger)
        {
            _transactionInvoicePreviewRepository = transactionInvoicePreviewRepository
                ?? throw new ArgumentNullException(nameof(transactionInvoicePreviewRepository));
            _wordDocumentService = wordDocumentService
                ?? throw new ArgumentNullException(nameof(wordDocumentService));
            _config = config ?? throw new ArgumentNullException(nameof(config));
            _sharepointService = sharepointService ?? throw new ArgumentNullException(nameof(sharepointService));
            _httpContextAccessor = httpContextAccessor ?? throw new ArgumentNullException(nameof(httpContextAccessor));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<TransactionInvoicePreviewGenerateResult> GenerateAsync(
            TransactionInvoicePreviewGenerateRequest request,
            int generatedByUserId,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);

            if (generatedByUserId <= 0)
            {
                generatedByUserId = 1615;
            }
            if (request.TransactionGuid == Guid.Empty)
            {
                return new TransactionInvoicePreviewGenerateResult
                {
                    TransactionGuid = Guid.Empty,
                    IsSuccess = false,
                    Message = "A valid transaction guid is required.",
                    IsCurrent = false
                };
            }

            if (FinanceInvoicePreviewMergeDocumentGuid == Guid.Parse("11111111-1111-1111-1111-111111111111"))
            {
                return new TransactionInvoicePreviewGenerateResult
                {
                    TransactionGuid = request.TransactionGuid,
                    IsSuccess = false,
                    Message = "Invoice preview is not configured yet. The Finance Invoice Preview merge document guid is still set to the placeholder value.",
                    IsCurrent = false
                };
            }

            try
            {
                var existing = await _transactionInvoicePreviewRepository
                    .GetCurrentAsync(request.TransactionGuid, cancellationToken)
                    .ConfigureAwait(false);

                if (!request.ForceRegenerate && existing is not null)
                {
                    var guard = await _transactionInvoicePreviewRepository
                        .GetPostingGuardAsync(request.TransactionGuid, cancellationToken)
                        .ConfigureAwait(false);

                    if (guard.HasPreview && guard.PreviewMatchesCurrentTransaction)
                    {
                        return new TransactionInvoicePreviewGenerateResult
                        {
                            TransactionGuid = request.TransactionGuid,
                            IsSuccess = true,
                            Message = "Current invoice preview already exists.",
                            ReservedInvoiceNumber = existing.ReservedInvoiceNumber,
                            SharePointDriveId = existing.SharePointDriveId,
                            SharePointItemId = existing.SharePointItemId,
                            SharePointWebUrl = existing.SharePointWebUrl,
                            Filename = existing.Filename,
                            MimeType = existing.MimeType,
                            GeneratedDateTimeUtc = existing.GeneratedDateTimeUtc,
                            IsCurrent = existing.IsCurrent
                        };
                    }
                }

                var reservedInvoiceNumber = await _transactionInvoicePreviewRepository
                    .ReserveInvoiceNumberAsync(request.TransactionGuid, cancellationToken)
                    .ConfigureAwait(false);

                if (string.IsNullOrWhiteSpace(reservedInvoiceNumber))
                {
                    return new TransactionInvoicePreviewGenerateResult
                    {
                        TransactionGuid = request.TransactionGuid,
                        IsSuccess = false,
                        Message = "Invoice preview could not be generated because no reserved invoice number could be created for the selected transaction.",
                        IsCurrent = false
                    };
                }

                var targetSharePointUrl = await ResolveTransactionJobSharePointUrlAsync(
                    request.TransactionGuid,
                    cancellationToken).ConfigureAwait(false);

                var validation = await _wordDocumentService.ValidateFinanceInvoicePreviewAsync(
                    FinanceInvoicePreviewMergeDocumentGuid,
                    request.TransactionGuid,
                    reservedInvoiceNumber,
                    targetSharePointUrl,
                    cancellationToken).ConfigureAwait(false);

                if (!validation.IsValid)
                {
                    return new TransactionInvoicePreviewGenerateResult
                    {
                        TransactionGuid = request.TransactionGuid,
                        IsSuccess = false,
                        Message = validation.Message,
                        ReservedInvoiceNumber = reservedInvoiceNumber,
                        IsCurrent = false
                    };
                }

                var generated = await _wordDocumentService.GenerateFinanceInvoicePreviewPdfAsync(
                    FinanceInvoicePreviewMergeDocumentGuid,
                    request.TransactionGuid,
                    reservedInvoiceNumber,
                    targetSharePointUrl,
                    cancellationToken).ConfigureAwait(false);

                if (generated.FileBytes == null || generated.FileBytes.Length == 0)
                {
                    return new TransactionInvoicePreviewGenerateResult
                    {
                        TransactionGuid = request.TransactionGuid,
                        IsSuccess = false,
                        Message = "Invoice preview generation completed, but the generated PDF file was empty.",
                        ReservedInvoiceNumber = reservedInvoiceNumber,
                        IsCurrent = false
                    };
                }

                var fileHash = ComputeSha256(generated.FileBytes);

                await _transactionInvoicePreviewRepository.InsertPreviewAsync(
                    request.TransactionGuid,
                    FinanceInvoicePreviewMergeDocumentGuid,
                    reservedInvoiceNumber,
                    generated.DriveId,
                    generated.ItemId,
                    generated.WebUrl,
                    generated.Filename,
                    generated.MimeType,
                    fileHash,
                    generatedByUserId,
                    cancellationToken).ConfigureAwait(false);

                var current = await _transactionInvoicePreviewRepository
                    .GetCurrentAsync(request.TransactionGuid, cancellationToken)
                    .ConfigureAwait(false);

                return new TransactionInvoicePreviewGenerateResult
                {
                    TransactionGuid = request.TransactionGuid,
                    IsSuccess = true,
                    Message = "Invoice preview generated successfully.",
                    ReservedInvoiceNumber = reservedInvoiceNumber,
                    SharePointDriveId = current?.SharePointDriveId ?? generated.DriveId,
                    SharePointItemId = current?.SharePointItemId ?? generated.ItemId,
                    SharePointWebUrl = current?.SharePointWebUrl ?? generated.WebUrl,
                    Filename = current?.Filename ?? generated.Filename,
                    MimeType = current?.MimeType ?? generated.MimeType,
                    GeneratedDateTimeUtc = current?.GeneratedDateTimeUtc ?? DateTime.UtcNow,
                    IsCurrent = current?.IsCurrent ?? true
                };
            }
            catch (SqlException ex)
            {
                _logger.LogError(ex, "Invoice preview generation failed for TransactionGuid={TransactionGuid}.", request.TransactionGuid);

                return new TransactionInvoicePreviewGenerateResult
                {
                    TransactionGuid = request.TransactionGuid,
                    IsSuccess = false,
                    Message = BuildFriendlySqlPreviewError(ex),
                    IsCurrent = false
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Invoice preview generation failed for TransactionGuid={TransactionGuid}.", request.TransactionGuid);

                return new TransactionInvoicePreviewGenerateResult
                {
                    TransactionGuid = request.TransactionGuid,
                    IsSuccess = false,
                    Message = BuildFriendlyPreviewError(ex),
                    IsCurrent = false
                };
            }
        }

        private int ResolveGeneratedByUserId()
        {
            var serviceBase = new Concursus.API.Services.ServiceBase(
                _config,
                _httpContextAccessor,
                new Logging(_logger, _config));

            if (serviceBase._userId <= 0)
            {
                throw new InvalidOperationException(
                    "Invoice preview could not be saved because the current authenticated user id could not be resolved.");
            }

            return serviceBase._userId;
        }

        public Task<TransactionInvoicePrintModel?> GetInvoicePrintModelAsync(
            Guid transactionGuid,
            TransactionInvoiceRenderMode renderMode,
            CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("A valid transaction guid is required.", nameof(transactionGuid));
            }

            return _transactionInvoicePreviewRepository.GetInvoicePrintModelAsync(
                transactionGuid,
                renderMode,
                cancellationToken);
        }

        private async Task<string> ResolveTransactionJobSharePointUrlAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken)
        {
            var jobContext = await _transactionInvoicePreviewRepository
                .GetJobContextAsync(transactionGuid, cancellationToken)
                .ConfigureAwait(false);

            if (jobContext is null)
            {
                throw new InvalidOperationException(
                    $"Invoice preview could not resolve a Job for transaction '{transactionGuid}'.");
            }

            var serviceBase = new Concursus.API.Services.ServiceBase(
                _config,
                _httpContextAccessor,
                new Logging(_logger, _config));

            var sharePoint = new SharePoint(_config, _sharepointService);

            try
            {
                const string jobEntityTypeGuid = "63542427-46ab-4078-abd1-1d583c24315c";

                var jobDataObject = await serviceBase._entityFramework.DataObjectGet(
                    jobContext.JobGuid,
                    Guid.Empty,
                    Guid.Parse(jobEntityTypeGuid),
                    false).ConfigureAwait(false);

                if (jobDataObject is null)
                {
                    throw new InvalidOperationException(
                        $"Invoice preview could not load the Job data object for transaction '{transactionGuid}'.");
                }

                var sharePointResponse = await sharePoint.GetSharePointLocation(
                    jobEntityTypeGuid,
                    jobDataObject,
                    serviceBase._entityFramework,
                    serviceBase,
                    null,
                    null).ConfigureAwait(false);

                var resolvedUrl = sharePointResponse?.DataObject?.SharePointUrl ?? string.Empty;

                if (string.IsNullOrWhiteSpace(resolvedUrl))
                {
                    throw new InvalidOperationException(
                        $"Invoice preview could not resolve a SharePointUrl for Job '{jobContext.JobGuid}'.");
                }

                return resolvedUrl;
            }
            finally
            {
                sharePoint.Dispose();
            }
        }

        private static string BuildFriendlySqlPreviewError(SqlException ex)
        {
            var message = ex.Message ?? string.Empty;

            if (message.Contains("Invalid object name 'SFin.Transaction_InvoiceMergeInfo'", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the SQL view SFin.Transaction_InvoiceMergeInfo has not been deployed yet.";
            }

            if (message.Contains("Invalid object name 'SFin.tvf_TransactionInvoiceLines'", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the SQL function SFin.tvf_TransactionInvoiceLines has not been deployed yet.";
            }

            if (message.Contains("Invalid object name 'SFin.TransactionInvoicePreviews'", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the SQL table SFin.TransactionInvoicePreviews has not been deployed yet.";
            }

            return $"Invoice preview could not be generated because a database dependency failed: {message}";
        }

        private static string BuildFriendlyPreviewError(Exception ex)
        {
            var message = ex.Message ?? string.Empty;

            if (message.Contains("Merge document", StringComparison.OrdinalIgnoreCase) &&
                message.Contains("was not found", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the Finance Invoice Preview merge document has not been configured in SCore.MergeDocuments.";
            }

            if (message.Contains("Microsoft.Graph.IAuthenticationProviderOption", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated due to a system configuration issue with Microsoft Graph libraries. Please contact support.";
            }

            if (message.Contains("No invoice header merge data was returned", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the selected transaction did not return any header merge data.";
            }

            if (message.Contains("SharePointUrl", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the invoice header merge source does not provide SharePointUrl.";
            }

            if (message.Contains("could not be found in any drive", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the configured SharePoint template document could not be found.";
            }

            if (message.Contains("template document could not be downloaded", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the Word template could not be downloaded from SharePoint.";
            }

            if (message.Contains("generated invoice preview was not returned from SharePoint upload", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the generated file was not returned after SharePoint upload.";
            }

            if (message.Contains("generated PDF was uploaded but the content could not be re-downloaded", StringComparison.OrdinalIgnoreCase))
            {
                return "Invoice preview could not be generated because the PDF was created but could not be read back from SharePoint.";
            }

            return $"Invoice preview could not be generated: {message}";
        }

        public Task<TransactionInvoicePreviewInfo?> GetCurrentAsync(Guid transactionGuid, CancellationToken cancellationToken = default)
            => _transactionInvoicePreviewRepository.GetCurrentAsync(transactionGuid, cancellationToken);

        public Task<TransactionInvoicePostingGuardResult> GetPostingGuardAsync(Guid transactionGuid, CancellationToken cancellationToken = default)
            => _transactionInvoicePreviewRepository.GetPostingGuardAsync(transactionGuid, cancellationToken);

        private static string ComputeSha256(byte[] bytes)
        {
            using var sha = SHA256.Create();
            return Convert.ToHexString(sha.ComputeHash(bytes));
        }
    }

    public sealed class GeneratedFinanceInvoicePreviewPdf
    {
        public string DriveId { get; set; } = string.Empty;
        public string ItemId { get; set; } = string.Empty;
        public string WebUrl { get; set; } = string.Empty;
        public string Filename { get; set; } = string.Empty;
        public string MimeType { get; set; } = "application/pdf";
        public byte[] FileBytes { get; set; } = Array.Empty<byte>();
    }

    public interface IWordDocumentService
    {
        Task<GeneratedFinanceInvoicePreviewPdf> GenerateFinanceInvoicePreviewPdfAsync(
            Guid mergeDocumentGuid,
            Guid transactionGuid,
            string reservedInvoiceNumber,
            CancellationToken cancellationToken = default);
    }
}