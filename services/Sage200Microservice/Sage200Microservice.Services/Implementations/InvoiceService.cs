using Microsoft.Extensions.Logging;
using Sage200Microservice.Data.Repositories;
using Sage200Microservice.Services.Interfaces;

namespace Sage200Microservice.Services.Implementations
{
    public class InvoiceService : IInvoiceService
    {
        private readonly ILogger<InvoiceService> _logger;
        private readonly IInvoiceRepository _invoiceRepository;
        private readonly IInvoiceStatusHistoryRepository _statusHistoryRepository;
        private readonly ISageApiClient _sageApiClient;

        public InvoiceService(
            ILogger<InvoiceService> logger,
            IInvoiceRepository invoiceRepository,
            IInvoiceStatusHistoryRepository statusHistoryRepository,
            ISageApiClient sageApiClient)
        {
            _logger = logger;
            _invoiceRepository = invoiceRepository;
            _statusHistoryRepository = statusHistoryRepository;
            _sageApiClient = sageApiClient;
        }

        public async Task<(bool Success, string Message, long OrderId, string OrderReference)> CreateSalesOrderInvoiceAsync(
            Sage200Microservice.Data.Models.Invoice invoice,
            List<Sage200Microservice.Services.Models.OrderLine> lines)
        {
            try
            {
                _logger.LogInformation("Creating sales order invoice for customer {CustomerId} with {LineCount} lines",
                    invoice.CustomerId, lines.Count);

                // Create a request object for the Sage 200 API
                var sageOrderRequest = new
                {
                    customer_id = invoice.CustomerId,
                    order_date = DateTime.UtcNow,
                    lines = lines.Select(l => new
                    {
                        product_code = l.ProductCode,
                        quantity = l.Quantity,
                        unit_price = l.UnitPrice
                    }).ToList()
                };

                // Call the Sage 200 API to create the sales order
                var sageOrder = await _sageApiClient.PostAsync<object, Sage200Microservice.Services.Models.SageSalesOrder>("sales/orders", sageOrderRequest);

                // Update our invoice object with the Sage order details
                invoice.SageId = sageOrder.id;
                invoice.InvoiceReference = sageOrder.document_no;
                invoice.IsSynced = true;

                // Save invoice to our local database
                var savedInvoice = await _invoiceRepository.AddAsync(invoice);

                // Create an initial status history record
                var statusHistory = new Sage200Microservice.Data.Models.InvoiceStatusHistory
                {
                    InvoiceReference = invoice.InvoiceReference,
                    GrossValue = invoice.GrossValue,
                    OutstandingValue = invoice.OutstandingValue,
                    AllocatedValue = 0,
                    Status = invoice.Status,
                    CheckTimestamp = DateTime.UtcNow,
                    Source = "Creation",
                    CheckedBy = invoice.CreatedBy
                };

                await _statusHistoryRepository.AddAsync(statusHistory);

                _logger.LogInformation("Sales order invoice created successfully with reference {InvoiceReference}", invoice.InvoiceReference);

                return (true, "Sales order invoice created successfully", savedInvoice.Id, savedInvoice.InvoiceReference);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating sales order invoice for customer {CustomerId}", invoice.CustomerId);
                return (false, $"Error creating sales order invoice: {ex.Message}", 0, null);
            }
        }

        public async Task<(bool Success, string Message, bool IsPaid, bool IsCredited, decimal OutstandingValue, decimal AllocatedValue, List<Sage200Microservice.Services.Models.SageAllocationHistoryItem> AllocationHistory)> CheckInvoiceStatusAsync(string invoiceReference)
        {
            try
            {
                _logger.LogInformation("Checking status of invoice {InvoiceReference}", invoiceReference);

                // Call the Sage 200 API to get the invoice status
                var sageInvoice = await _sageApiClient.GetAsync<Sage200Microservice.Services.Models.SageSalesOrder>($"sales/invoices?document_no={invoiceReference}");

                // Get the invoice from our local database
                var invoice = await _invoiceRepository.GetByReferenceAsync(invoiceReference);

                if (invoice == null)
                {
                    _logger.LogWarning("Invoice {InvoiceReference} not found in local database", invoiceReference);

                    // Create a new invoice record if it doesn't exist locally
                    invoice = new Sage200Microservice.Data.Models.Invoice
                    {
                        InvoiceReference = invoiceReference,
                        SageId = sageInvoice.id,
                        CustomerId = (int)sageInvoice.customer_id,
                        GrossValue = sageInvoice.document_gross_value,
                        OutstandingValue = sageInvoice.document_outstanding_value,
                        Status = sageInvoice.document_outstanding_value == 0 ? "Paid" :
                                (sageInvoice.document_outstanding_value < sageInvoice.document_gross_value ? "PartiallyPaid" : "Unpaid"),
                        CreatedAt = sageInvoice.order_date,
                        LastCheckedAt = DateTime.UtcNow,
                        CreatedBy = "System",
                        IsSynced = true
                    };

                    await _invoiceRepository.AddAsync(invoice);
                }
                else
                {
                    // Update the invoice status in our local database
                    invoice.OutstandingValue = sageInvoice.document_outstanding_value;
                    invoice.Status = sageInvoice.document_outstanding_value == 0 ? "Paid" :
                                    (sageInvoice.document_outstanding_value < sageInvoice.document_gross_value ? "PartiallyPaid" : "Unpaid");
                    invoice.LastCheckedAt = DateTime.UtcNow;
                    invoice.IsSynced = true;

                    await _invoiceRepository.UpdateAsync(invoice);
                }

                // Create a status history record
                var allocatedValue = sageInvoice.document_gross_value - sageInvoice.document_outstanding_value;
                var statusHistory = new Sage200Microservice.Data.Models.InvoiceStatusHistory
                {
                    InvoiceReference = invoiceReference,
                    GrossValue = sageInvoice.document_gross_value,
                    OutstandingValue = sageInvoice.document_outstanding_value,
                    AllocatedValue = allocatedValue,
                    Status = invoice.Status,
                    CheckTimestamp = DateTime.UtcNow,
                    Source = "Manual",
                    CheckedBy = "System"
                };

                await _statusHistoryRepository.AddAsync(statusHistory);

                _logger.LogInformation("Invoice {InvoiceReference} status checked: OutstandingValue={OutstandingValue}, Status={Status}",
                    invoiceReference, sageInvoice.document_outstanding_value, invoice.Status);

                return (
                    true,
                    "Invoice status checked successfully",
                    sageInvoice.document_outstanding_value == 0,
                    sageInvoice.allocation_history_items?.Any(i => i.trader_transaction_type == "CreditNote") ?? false,
                    sageInvoice.document_outstanding_value,
                    allocatedValue,
                    sageInvoice.allocation_history_items ?? new List<Sage200Microservice.Services.Models.SageAllocationHistoryItem>()
                );
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking status of invoice {InvoiceReference}", invoiceReference);
                return (false, $"Error checking invoice status: {ex.Message}", false, false, 0, 0, new List<Sage200Microservice.Services.Models.SageAllocationHistoryItem>());
            }
        }

        public async Task ProcessOutstandingInvoicesAsync()
        {
            try
            {
                _logger.LogInformation("Processing outstanding invoices");

                // Get all outstanding invoices
                var outstandingInvoices = await _invoiceRepository.GetOutstandingInvoicesAsync();

                _logger.LogInformation("Found {Count} outstanding invoices to process", outstandingInvoices.Count().ToString());

                foreach (var invoice in outstandingInvoices)
                {
                    try
                    {
                        var result = await CheckInvoiceStatusAsync(invoice.InvoiceReference);

                        if (!result.Success)
                        {
                            _logger.LogWarning("Failed to check status of invoice {InvoiceReference}: {Message}",
                                invoice.InvoiceReference, result.Message);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error processing invoice {InvoiceReference}", invoice.InvoiceReference);
                    }
                }

                _logger.LogInformation("Finished processing outstanding invoices");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing outstanding invoices");
                throw;
            }
        }
    }
}