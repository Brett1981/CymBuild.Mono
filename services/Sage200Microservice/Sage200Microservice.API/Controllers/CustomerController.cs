using Microsoft.AspNetCore.Mvc;
using Sage200Microservice.Data.Models;
using Sage200Microservice.Data.Repositories;
using Sage200Microservice.Services.Interfaces;

namespace Sage200Microservice.API.Controllers
{
    /// <summary>
    /// Controller for managing customer operations with Sage 200
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class CustomerController : ControllerBase
    {
        private readonly ICustomerService _customerService;
        private readonly IApiLogRepository _apiLogRepository;

        /// <summary>
        /// Initializes a new instance of the CustomerController
        /// </summary>
        /// <param name="customerService">  The customer service </param>
        /// <param name="apiLogRepository"> The API log repository </param>
        public CustomerController(ICustomerService customerService, IApiLogRepository apiLogRepository)
        {
            _customerService = customerService;
            _apiLogRepository = apiLogRepository;
        }

        /// <summary>
        /// Creates a new customer in Sage 200
        /// </summary>
        /// <param name="request"> The customer details </param>
        /// <returns> The result of the customer creation operation </returns>
        /// <response code="200"> Returns the created customer details </response>
        /// <response code="400"> If the customer creation failed </response>
        /// <response code="500"> If there was an internal server error </response>
        [HttpPost]
        [ProducesResponseType(typeof(CreateCustomerResult), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(CreateCustomerResult), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(CreateCustomerResult), StatusCodes.Status500InternalServerError)]
        public async Task<ActionResult<CreateCustomerResult>> CreateCustomer([FromBody] CreateCustomerRequest request)
        {
            // Log the API call
            var apiLog = new ApiLog
            {
                Endpoint = "/api/customer",
                RequestMethod = "POST",
                RequestPayload = $"CustomerName: {request.CustomerName}, CustomerCode: {request.CustomerCode}",
                Timestamp = DateTime.UtcNow,
                CallerId = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown",
                ApiType = "REST"
            };

            try
            {
                // Convert request to our internal model
                var customer = new Customer
                {
                    CustomerName = request.CustomerName,
                    CustomerCode = request.CustomerCode,
                    AddressLine1 = request.AddressLine1,
                    AddressLine2 = request.AddressLine2,
                    City = request.City,
                    Postcode = request.Postcode,
                    Telephone = request.Telephone,
                    Email = request.Email,
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown"
                };

                // Call our service to create the customer
                var result = await _customerService.CreateCustomerAsync(customer);

                // Update API log with response
                apiLog.ResponsePayload = $"Success: {result.Success}, Message: {result.Message}, CustomerId: {result.CustomerId}";
                apiLog.HttpStatusCode = result.Success ? 200 : 500;
                await _apiLogRepository.AddAsync(apiLog);

                if (!result.Success)
                {
                    return BadRequest(new CreateCustomerResult { Success = false, Message = result.Message });
                }

                return Ok(new CreateCustomerResult
                {
                    Success = result.Success,
                    Message = result.Message,
                    CustomerId = result.CustomerId,
                    CustomerCode = result.CustomerCode
                });
            }
            catch (Exception ex)
            {
                // Update API log with error response
                apiLog.ResponsePayload = ex.Message;
                apiLog.HttpStatusCode = 500;
                await _apiLogRepository.AddAsync(apiLog);

                return StatusCode(500, new CreateCustomerResult { Success = false, Message = $"Error creating customer: {ex.Message}" });
            }
        }

        /// <summary>
        /// Gets a customer by their customer code
        /// </summary>
        /// <param name="customerCode"> The customer code </param>
        /// <returns> The customer details </returns>
        /// <response code="200"> Returns the customer details </response>
        /// <response code="404"> If the customer was not found </response>
        /// <response code="500"> If there was an internal server error </response>
        [HttpGet("{customerCode}")]
        [ProducesResponseType(typeof(SageCustomerResult), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(SageCustomerResult), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(SageCustomerResult), StatusCodes.Status500InternalServerError)]
        public async Task<ActionResult<SageCustomerResult>> GetCustomer(string customerCode)
        {
            // Log the API call
            var apiLog = new ApiLog
            {
                Endpoint = $"/api/customer/{customerCode}",
                RequestMethod = "GET",
                RequestPayload = string.Empty,
                Timestamp = DateTime.UtcNow,
                CallerId = Request.Headers["caller-id"].FirstOrDefault() ?? "Unknown",
                ApiType = "REST"
            };

            try
            {
                var customer = await _customerService.GetCustomerByCodeAsync(customerCode);

                // Update API log with response
                apiLog.ResponsePayload = $"Customer found: {customer?.name}";
                apiLog.HttpStatusCode = 200;
                await _apiLogRepository.AddAsync(apiLog);

                if (customer == null)
                {
                    return NotFound(new SageCustomerResult { Success = false, Message = "Customer not found" });
                }

                return Ok(new SageCustomerResult
                {
                    Success = true,
                    Message = "Customer retrieved successfully",
                    Customer = customer
                });
            }
            catch (Exception ex)
            {
                // Update API log with error response
                apiLog.ResponsePayload = ex.Message;
                apiLog.HttpStatusCode = 500;
                await _apiLogRepository.AddAsync(apiLog);

                return StatusCode(500, new SageCustomerResult { Success = false, Message = $"Error retrieving customer: {ex.Message}" });
            }
        }
    }

    /// <summary>
    /// Request model for creating a customer
    /// </summary>
    public class CreateCustomerRequest
    {
        /// <summary>
        /// The name of the customer
        /// </summary>
        /// <example> Acme Corporation </example>
        public string CustomerName { get; set; }

        /// <summary>
        /// The unique code for the customer
        /// </summary>
        /// <example> ACME001 </example>
        public string CustomerCode { get; set; }

        /// <summary>
        /// The first line of the customer's address
        /// </summary>
        /// <example> 123 Main Street </example>
        public string AddressLine1 { get; set; }

        /// <summary>
        /// The second line of the customer's address
        /// </summary>
        /// <example> Suite 100 </example>
        public string AddressLine2 { get; set; }

        /// <summary>
        /// The city of the customer's address
        /// </summary>
        /// <example> London </example>
        public string City { get; set; }

        /// <summary>
        /// The postcode of the customer's address
        /// </summary>
        /// <example> EC1A 1BB </example>
        public string Postcode { get; set; }

        /// <summary>
        /// The telephone number of the customer
        /// </summary>
        /// <example> +44 20 1234 5678 </example>
        public string Telephone { get; set; }

        /// <summary>
        /// The email address of the customer
        /// </summary>
        /// <example> contact@acme.com </example>
        public string Email { get; set; }
    }

    /// <summary>
    /// Response model for customer creation
    /// </summary>
    public class CreateCustomerResult
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
        /// The ID of the created customer
        /// </summary>
        public long CustomerId { get; set; }

        /// <summary>
        /// The unique code of the created customer
        /// </summary>
        public string CustomerCode { get; set; }
    }

    /// <summary>
    /// Response model for customer retrieval
    /// </summary>
    public class SageCustomerResult
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
        /// The customer details
        /// </summary>
        public Sage200Microservice.Services.Models.SageCustomer Customer { get; set; }
    }
}