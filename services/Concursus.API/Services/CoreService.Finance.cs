using Concursus.API.Core;
using Concursus.Common.Shared.Models.Finance;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;

namespace Concursus.API.Services
{
    [Authorize]
    public partial class CoreService
    {
        public override async Task<TransactionInvoicePrintModelReplyMessage> TransactionInvoicePrintModelGet(
            TransactionInvoicePrintModelGetRequestMessage request,
            ServerCallContext context)
        {
            if (request is null || string.IsNullOrWhiteSpace(request.TransactionGuid))
            {
                throw new RpcException(new Status(StatusCode.InvalidArgument, "A valid transaction guid must be supplied."));
            }

            if (!Guid.TryParse(request.TransactionGuid, out var transactionGuid))
            {
                throw new RpcException(new Status(StatusCode.InvalidArgument, "Invalid transaction guid."));
            }

            var renderMode = request.RenderMode == TransactionInvoiceRenderModeMessage.TransactionInvoiceRenderModeFinal
                ? TransactionInvoiceRenderMode.Final
                : TransactionInvoiceRenderMode.Preview;

            var previewService = context.GetHttpContext()
                .RequestServices
                .GetRequiredService<ITransactionInvoicePreviewService>();

            var result = await previewService
                .GetInvoicePrintModelAsync(transactionGuid, renderMode, context.CancellationToken)
                .ConfigureAwait(false);

            if (result is null)
            {
                return new TransactionInvoicePrintModelReplyMessage();
            }

            var reply = new TransactionInvoicePrintModelReplyMessage
            {
                TransactionGuid = result.TransactionGuid.ToString(),
                RenderMode = result.RenderMode == TransactionInvoiceRenderMode.Final
                    ? TransactionInvoiceRenderModeMessage.TransactionInvoiceRenderModeFinal
                    : TransactionInvoiceRenderModeMessage.TransactionInvoiceRenderModePreview,
                CustomerReference = result.CustomerReference ?? string.Empty,
                InvoiceToBlock = result.InvoiceToBlock ?? string.Empty,
                TaxPointDate = ToTimestamp(result.TaxPointDate),
                TaxPointDateSpecified = result.TaxPointDate != default,
                PaymentTerms = result.PaymentTerms ?? string.Empty,
                CostCentre = result.CostCentre ?? string.Empty,
                Department = result.Department ?? string.Empty,
                InvoiceNumber = result.InvoiceNumber ?? string.Empty,
                SalesOrderNumber = result.SalesOrderNumber ?? string.Empty,
                PurchaseOrderNumber = result.PurchaseOrderNumber ?? string.Empty,
                TotalAmountExcludingVat = Convert.ToDouble(result.TotalAmountExcludingVat),
                TotalVat = Convert.ToDouble(result.TotalVat),
                TotalAmountDue = Convert.ToDouble(result.TotalAmountDue)
            };

            foreach (var line in result.Lines)
            {
                reply.Lines.Add(new TransactionInvoicePrintLineMessage
                {
                    Description = line.Description ?? string.Empty,
                    Quantity = Convert.ToDouble(line.Quantity),
                    UnitPrice = Convert.ToDouble(line.UnitPrice),
                    AmountExVat = Convert.ToDouble(line.AmountExVat),
                    VatCode = line.VatCode ?? string.Empty,
                    VatAmount = Convert.ToDouble(line.VatAmount)
                });
            }

            return reply;
        }

        public override async Task<TransactionInvoicePreviewGenerateReplyMessage> TransactionInvoicePreviewGenerate(
    TransactionInvoicePreviewGenerateRequestMessage request,
    ServerCallContext context)
        {
            try
            {
                if (request is null || string.IsNullOrWhiteSpace(request.TransactionGuid))
                {
                    return new TransactionInvoicePreviewGenerateReplyMessage
                    {
                        IsSuccess = false,
                        Message = "A valid transaction guid must be supplied."
                    };
                }

                if (!Guid.TryParse(request.TransactionGuid, out var transactionGuid))
                {
                    return new TransactionInvoicePreviewGenerateReplyMessage
                    {
                        IsSuccess = false,
                        Message = "The selected transaction has an invalid guid."
                    };
                }

                var previewService = context.GetHttpContext()
                    .RequestServices
                    .GetRequiredService<ITransactionInvoicePreviewService>();

                var result = await previewService.GenerateAsync(
                    new TransactionInvoicePreviewGenerateRequest
                    {
                        TransactionGuid = transactionGuid,
                        ForceRegenerate = request.ForceRegenerate
                    },
                    _serviceBase._userId,
                    context.CancellationToken).ConfigureAwait(false);

                return new TransactionInvoicePreviewGenerateReplyMessage
                {
                    TransactionGuid = result.TransactionGuid.ToString(),
                    IsSuccess = result.IsSuccess,
                    Message = result.Message ?? string.Empty,
                    ReservedInvoiceNumber = result.ReservedInvoiceNumber ?? string.Empty,
                    SharePointDriveId = result.SharePointDriveId ?? string.Empty,
                    SharePointItemId = result.SharePointItemId ?? string.Empty,
                    SharePointWebUrl = result.SharePointWebUrl ?? string.Empty,
                    Filename = result.Filename ?? string.Empty,
                    MimeType = result.MimeType ?? string.Empty,
                    GeneratedDateTimeUtc = ToTimestamp(result.GeneratedDateTimeUtc),
                    GeneratedDateTimeUtcSpecified = result.GeneratedDateTimeUtc.HasValue,
                    IsCurrent = result.IsCurrent
                };
            }
            catch (Exception ex)
            {
                _serviceBase.logger.LogException(ex);

                return new TransactionInvoicePreviewGenerateReplyMessage
                {
                    IsSuccess = false,
                    Message = $"Invoice preview could not be generated: {ex.Message}"
                };
            }
        }

        public override async Task<TransactionInvoicePreviewInfoMessage> TransactionInvoicePreviewGetCurrent(
    TransactionInvoicePreviewGetCurrentRequestMessage request,
    ServerCallContext context)
        {
            if (request is null || string.IsNullOrWhiteSpace(request.TransactionGuid))
                throw new RpcException(new Status(StatusCode.InvalidArgument, "A valid transaction guid must be supplied."));

            if (!Guid.TryParse(request.TransactionGuid, out var transactionGuid))
                throw new RpcException(new Status(StatusCode.InvalidArgument, "Invalid transaction guid."));

            var previewService = context.GetHttpContext()
                .RequestServices
                .GetRequiredService<ITransactionInvoicePreviewService>();

            var result = await previewService.GetCurrentAsync(transactionGuid, context.CancellationToken).ConfigureAwait(false);
            if (result is null)
                return new TransactionInvoicePreviewInfoMessage();

            return new TransactionInvoicePreviewInfoMessage
            {
                Id = result.Id,
                Guid = result.Guid.ToString(),
                TransactionGuid = result.TransactionGuid.ToString(),
                ReservedInvoiceNumber = result.ReservedInvoiceNumber ?? string.Empty,
                SharePointDriveId = result.SharePointDriveId ?? string.Empty,
                SharePointItemId = result.SharePointItemId ?? string.Empty,
                SharePointWebUrl = result.SharePointWebUrl ?? string.Empty,
                Filename = result.Filename ?? string.Empty,
                MimeType = result.MimeType ?? string.Empty,
                FileHash = result.FileHash ?? string.Empty,
                GeneratedDateTimeUtc = ToTimestamp(result.GeneratedDateTimeUtc),
                GeneratedDateTimeUtcSpecified = true,
                IsCurrent = result.IsCurrent,
                IsPostedToSage = result.IsPostedToSage
            };
        }

        public override async Task<TransactionInvoicePreviewPostingGuardReplyMessage> TransactionInvoicePreviewPostingGuardGet(
    TransactionInvoicePreviewPostingGuardRequestMessage request,
    ServerCallContext context)
        {
            if (request is null || string.IsNullOrWhiteSpace(request.TransactionGuid))
                throw new RpcException(new Status(StatusCode.InvalidArgument, "A valid transaction guid must be supplied."));

            if (!Guid.TryParse(request.TransactionGuid, out var transactionGuid))
                throw new RpcException(new Status(StatusCode.InvalidArgument, "Invalid transaction guid."));

            var previewService = context.GetHttpContext()
                .RequestServices
                .GetRequiredService<ITransactionInvoicePreviewService>();

            var result = await previewService.GetPostingGuardAsync(transactionGuid, context.CancellationToken).ConfigureAwait(false);

            return new TransactionInvoicePreviewPostingGuardReplyMessage
            {
                TransactionGuid = result.TransactionGuid.ToString(),
                HasPreview = result.HasPreview,
                HasReservedInvoiceNumber = result.HasReservedInvoiceNumber,
                PreviewMatchesCurrentTransaction = result.PreviewMatchesCurrentTransaction,
                CanPostToSage = result.CanPostToSage,
                ReservedInvoiceNumber = result.ReservedInvoiceNumber ?? string.Empty,
                BlockingReason = result.BlockingReason ?? string.Empty
            };
        }
    }
}
