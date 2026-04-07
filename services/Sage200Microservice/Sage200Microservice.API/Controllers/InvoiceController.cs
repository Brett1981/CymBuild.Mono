using Microsoft.AspNetCore.Mvc;
using Sage200Microservice.Data.Repositories;
using Sage200Microservice.Services.Interfaces;

namespace Sage200Microservice.API.Controllers
{
    /// <summary>
    /// Controller for managing invoice operations with Sage 200
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class InvoiceController : ControllerBase
    {
        private readonly IInvoiceService _invoiceService;
        private readonly IApiLogRepository _apiLogRepository;

        /// <summary>
        /// Initializes a new instance of the InvoiceController
        /// </summary>
        /// <param name="invoiceService">   The invoice service </param>
        /// <param name="apiLogRepository"> The API log repository </param>
        public InvoiceController(IInvoiceService invoiceService, IApiLogRepository apiLogRepository)
        {
            _invoiceService = invoiceService;
            _apiLogRepository = apiLogRepository;
        }

        /// <summary>
        /// Creates a new sales order invoice in Sage 200
        /// </summary>
        /// <param name="request"> The sales order invoice details </param>
        /// <returns> The result of the sales order invoice creation operation </returns>
        /// <response code="200"> Returns the created sales order invoice details </response>
        /// <response code="400"> If the sales order invoice creation failed </response>
        /// <response code="500"> If there was an internal server error </response>
        [HttpPost]
        [ProducesResponseType(typeof(CreateSalesOrderInvoiceResult), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(CreateSalesOrderInvoiceResult), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(CreateSalesOrderInvoiceResult), StatusCodes.Status500InternalServerError)]
        public async Task<ActionResult<CreateSalesOrderInvoiceResult>> CreateSalesOrderInvoice([FromBody] CreateSalesOrderInvoiceRequest request)
        {
            // Log the API call
            var apiLog = new Sage200Microservice.Data.Models.ApiLog
            {
                Endpoint = "/api/invoice",
                RequestMethod = "POST",
                RequestPayload = $"CustomerId: {request.CustomerId}, Lines count: {request.Lines?.Count}",
                Timestamp = DateTime.UtcNow,
                CallerId = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown",
                ApiType = "REST"
            };

            try
            {
                // Convert request to our internal models
                var invoice = new Sage200Microservice.Data.Models.Invoice
                {
                    CustomerId = request.CustomerId,
                    InvoiceReference = $"SO-{DateTime.UtcNow:yyyyMMddHHmmss}",
                    GrossValue = request.Lines.Sum(l => l.Quantity * l.UnitPrice),
                    OutstandingValue = request.Lines.Sum(l => l.Quantity * l.UnitPrice),
                    Status = "Unpaid",
                    CreatedAt = DateTime.UtcNow,
                    LastCheckedAt = DateTime.UtcNow,
                    CreatedBy = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown"
                };

                var lines = request.Lines.Select(l => new Sage200Microservice.Services.Models.OrderLine
                {
                    ProductCode = l.ProductCode,
                    Quantity = l.Quantity,
                    UnitPrice = l.UnitPrice
                }).ToList();

                // Call our service to create the sales order invoice
                var result = await _invoiceService.CreateSalesOrderInvoiceAsync(invoice, lines);

                // Update API log with response
                apiLog.ResponsePayload = $"Success: {result.Success}, Message: {result.Message}, OrderId: {result.OrderId}";
                apiLog.HttpStatusCode = result.Success ? 200 : 500;
                await _apiLogRepository.AddAsync(apiLog);

                if (!result.Success)
                {
                    return BadRequest(new CreateSalesOrderInvoiceResult { Success = false, Message = result.Message });
                }

                return Ok(new CreateSalesOrderInvoiceResult
                {
                    Success = result.Success,
                    Message = result.Message,
                    OrderId = result.OrderId,
                    OrderReference = result.OrderReference
                });
            }
            catch (Exception ex)
            {
                // Update API log with error response
                apiLog.ResponsePayload = ex.Message;
                apiLog.HttpStatusCode = 500;
                await _apiLogRepository.AddAsync(apiLog);

                return StatusCode(500, new CreateSalesOrderInvoiceResult { Success = false, Message = $"Error creating sales order invoice: {ex.Message}" });
            }
        }

        /// <summary>
        /// Checks the status of an invoice in Sage 200
        /// </summary>
        /// <param name="invoiceReference"> The invoice reference </param>
        /// <returns> The status of the invoice </returns>
        /// <response code="200"> Returns the invoice status details </response>
        /// <response code="400"> If the invoice status check failed </response>
        /// <response code="500"> If there was an internal server error </response>
        [HttpGet("{invoiceReference}/status")]
        [ProducesResponseType(typeof(InvoiceStatusResult), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(InvoiceStatusResult), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(InvoiceStatusResult), StatusCodes.Status500InternalServerError)]
        public async Task<ActionResult<InvoiceStatusResult>> CheckInvoiceStatus(string invoiceReference)
        {
            // Log the API call
            var apiLog = new Sage200Microservice.Data.Models.ApiLog
            {
                Endpoint = $"/api/invoice/{invoiceReference}/status",
                RequestMethod = "GET",
                RequestPayload = string.Empty,
                Timestamp = DateTime.UtcNow,
                CallerId = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown",
                ApiType = "REST"
            };

            try
            {
                // Call our service to check the invoice status
                var result = await _invoiceService.CheckInvoiceStatusAsync(invoiceReference);

                // Update API log with response
                apiLog.ResponsePayload = $"Success: {result.Success}, IsPaid: {result.IsPaid}, OutstandingValue: {result.OutstandingValue}";
                apiLog.HttpStatusCode = result.Success ? 200 : 500;
                await _apiLogRepository.AddAsync(apiLog);

                if (!result.Success)
                {
                    return BadRequest(new InvoiceStatusResult { Success = false, Message = result.Message });
                }

                return Ok(new InvoiceStatusResult
                {
                    Success = result.Success,
                    Message = result.Message,
                    InvoiceReference = invoiceReference,
                    IsPaid = result.IsPaid,
                    IsCredited = result.IsCredited,
                    OutstandingValue = result.OutstandingValue,
                    AllocatedValue = result.AllocatedValue,
                    GrossValue = result.OutstandingValue + result.AllocatedValue,
                    AllocationHistory = result.AllocationHistory
                });
            }
            catch (Exception ex)
            {
                // Update API log with error response
                apiLog.ResponsePayload = ex.Message;
                apiLog.HttpStatusCode = 500;
                await _apiLogRepository.AddAsync(apiLog);

                return StatusCode(500, new InvoiceStatusResult { Success = false, Message = $"Error checking invoice status: {ex.Message}" });
            }
        }

        /// <summary>
        /// Processes all outstanding invoices by checking their status in Sage 200
        /// </summary>
        /// <returns> The result of the processing operation </returns>
        /// <response code="200"> Returns success if all invoices were processed </response>
        /// <response code="500"> If there was an internal server error </response>
        [HttpPost("process-outstanding")]
        [ProducesResponseType(typeof(ProcessResult), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProcessResult), StatusCodes.Status500InternalServerError)]
        public async Task<ActionResult<ProcessResult>> ProcessOutstandingInvoices()
        {
            // Log the API call
            var apiLog = new Sage200Microservice.Data.Models.ApiLog
            {
                Endpoint = "/api/invoice/process-outstanding",
                RequestMethod = "POST",
                RequestPayload = string.Empty,
                Timestamp = DateTime.UtcNow,
                CallerId = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown",
                ApiType = "REST"
            };

            try
            {
                await _invoiceService.ProcessOutstandingInvoicesAsync();

                // Update API log with response
                apiLog.ResponsePayload = "Outstanding invoices processed successfully";
                apiLog.HttpStatusCode = 200;
                await _apiLogRepository.AddAsync(apiLog);

                return Ok(new ProcessResult { Success = true, Message = "Outstanding invoices processed successfully" });
            }
            catch (Exception ex)
            {
                // Update API log with error response
                apiLog.ResponsePayload = ex.Message;
                apiLog.HttpStatusCode = 500;
                await _apiLogRepository.AddAsync(apiLog);

                return StatusCode(500, new ProcessResult { Success = false, Message = $"Error processing outstanding invoices: {ex.Message}" });
            }
        }
    }

    /// <summary>
    /// Request model for creating a sales order invoice
    /// </summary>
    public class CreateSalesOrderInvoiceRequest
    {
        /// <summary>
        /// The ID of the customer
        /// </summary>
        /// <example> 12345 </example>
        public int CustomerId { get; set; }

        /// <summary>
        /// The list of order lines
        /// </summary>
        public List<OrderLineRequest> Lines { get; set; }
    }

    /// <summary>
    /// Request model for an order line
    /// </summary>
    public class OrderLineRequest
    {
        /// <summary>
        /// The product code
        /// </summary>
        /// <example> PROD001 </example>
        public string ProductCode { get; set; }

        /// <summary>
        /// The quantity of the product
        /// </summary>
        /// <example> 5.0 </example>
        public decimal Quantity { get; set; }

        /// <summary>
        /// The unit price of the product
        /// </summary>
        /// <example> 19.99 </example>
        public decimal UnitPrice { get; set; }
    }

    /// <summary>
    /// Response model for sales order invoice creation
    /// </summary>
    public class CreateSalesOrderInvoiceResult
    {
        /// <summary>
        /// Indicates whether the operation was successful
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// A message describing the result of the operation
        /// </summary>
        public string Message { get; set; }

        /// <summary>
        /// The ID of the created order
        /// </summary>
        public long OrderId { get; set; }

        /// <summary>
        /// The reference of the created order
        /// </summary>
        public string OrderReference { get; set; }
    }

    /// <summary>
    /// Response model for invoice status check
    /// </summary>
    public class InvoiceStatusResult
    {
        /// <summary>
        /// Indicates whether the operation was successful
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// A message describing the result of the operation
        /// </summary>
        public string Message { get; set; }

        /// <summary>
        /// The invoice reference
        /// </summary>
        public string InvoiceReference { get; set; }

        /// <summary>
        /// Indicates whether the invoice is fully paid
        /// </summary>
        public bool IsPaid { get; set; }

        /// <summary>
        /// Indicates whether the invoice has been credited
        /// </summary>
        public bool IsCredited { get; set; }

        /// <summary>
        /// The outstanding value of the invoice
        /// </summary>
        public decimal OutstandingValue { get; set; }

        /// <summary>
        /// The allocated value of the invoice
        /// </summary>
        public decimal AllocatedValue { get; set; }

        /// <summary>
        /// The gross value of the invoice
        /// </summary>
        public decimal GrossValue { get; set; }

        /// <summary>
        /// The allocation history of the invoice
        /// </summary>
        public List<Sage200Microservice.Services.Models.SageAllocationHistoryItem> AllocationHistory { get; set; }
    }

    /// <summary>
    /// Response model for processing operations
    /// </summary>
    public class ProcessResult
    {
        /// <summary>
        /// Indicates whether the operation was successful
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// A message describing the result of the operation
        /// </summary>
        public string Message { get; set; }
    }
}