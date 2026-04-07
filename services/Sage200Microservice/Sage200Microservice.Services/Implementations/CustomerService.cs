using Microsoft.Extensions.Logging;
using Sage200Microservice.Data.Repositories;
using Sage200Microservice.Services.Interfaces;
using Sage200Microservice.Services.Tracing;

namespace Sage200Microservice.Services.Implementations
{
    public class CustomerService : ICustomerService
    {
        private readonly ILogger<CustomerService> _logger;
        private readonly ICustomerRepository _customerRepository;
        private readonly ISageApiClient _sageApiClient;

        public CustomerService(
            ILogger<CustomerService> logger,
            ICustomerRepository customerRepository,
            ISageApiClient sageApiClient)
        {
            _logger = logger;
            _customerRepository = customerRepository;
            _sageApiClient = sageApiClient;
        }

        public async Task<(bool Success, string Message, long CustomerId, string CustomerCode)> CreateCustomerAsync(Sage200Microservice.Data.Models.Customer customer)
        {
            return await TracingHelper.TraceOperationAsync<(bool Success, string Message, long CustomerId, string CustomerCode)>(
                "CustomerService.CreateCustomer",
                async () =>
                {
                    try
                    {
                        using var activity = TracingHelper.CreateChildActivity("CustomerService.CreateCustomer");
                        activity?.SetTag("customer.name", customer.CustomerName);
                        activity?.SetTag("customer.code", customer.CustomerCode);

                        // Set IsSynced to false initially
                        customer.IsSynced = false;

                        try
                        {
                            // Create a request object for the Sage 200 API
                            var sageCustomerRequest = new
                            {
                                name = customer.CustomerName,
                                customer_code = customer.CustomerCode,
                                main_address = new
                                {
                                    address_1 = customer.AddressLine1,
                                    address_2 = customer.AddressLine2,
                                    town = customer.City,
                                    postcode = customer.Postcode
                                },
                                telephone = customer.Telephone,
                                email = customer.Email
                            };

                            using var apiCallActivity = TracingHelper.CreateChildActivity("SageApi.CreateCustomer");
                            apiCallActivity?.SetTag("sage.operation", "create_customer");
                            apiCallActivity?.SetTag("sage.customer_name", customer.CustomerName);
                            apiCallActivity?.SetTag("sage.customer_code", customer.CustomerCode);

                            // Call the Sage 200 API to create the customer
                            var sageCustomer = await _sageApiClient.PostAsync<object, Sage200Microservice.Services.Models.SageCustomer>("customers", sageCustomerRequest);

                            apiCallActivity?.SetTag("sage.customer_id", sageCustomer.id);
                            apiCallActivity?.SetTag("sage.response.success", true);

                            // Update our customer object with the Sage ID
                            customer.SageId = sageCustomer.id;
                            customer.IsSynced = true;

                            using var dbActivity = TracingHelper.CreateChildActivity("Database.SaveCustomer");
                            dbActivity?.SetTag("db.operation", "insert");
                            dbActivity?.SetTag("db.entity", "Customer");

                            // Save customer to our local database
                            var savedCustomer = await _customerRepository.AddAsync(customer);

                            dbActivity?.SetTag("db.customer_id", savedCustomer.Id);
                            dbActivity?.SetTag("db.success", true);

                            return (true, "Customer created successfully", savedCustomer.Id, savedCustomer.CustomerCode);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error calling Sage 200 API to create customer {CustomerName}", customer.CustomerName);

                            // If the API call fails, still save the customer to our local database
                            // but mark it as not synced with Sage 200
                            customer.IsSynced = false;

                            using var dbActivity = TracingHelper.CreateChildActivity("Database.SaveCustomer");
                            dbActivity?.SetTag("db.operation", "insert");
                            dbActivity?.SetTag("db.entity", "Customer");
                            dbActivity?.SetTag("db.is_synced", false);

                            var savedCustomer = await _customerRepository.AddAsync(customer);

                            dbActivity?.SetTag("db.customer_id", savedCustomer.Id);
                            dbActivity?.SetTag("db.success", true);

                            return (false, $"Customer saved locally but not synced with Sage 200: {ex.Message}", savedCustomer.Id, savedCustomer.CustomerCode);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error creating customer {CustomerName}", customer.CustomerName);
                        return (false, $"Error creating customer: {ex.Message}", 0, customer.CustomerCode);
                    }
                });
        }

        public async Task<Sage200Microservice.Services.Models.SageCustomer> GetCustomerByCodeAsync(string customerCode)
        {
            return await TracingHelper.TraceOperationAsync<Sage200Microservice.Services.Models.SageCustomer>(
                "CustomerService.GetCustomerByCode",
                async () =>
                {
                    using var activity = TracingHelper.CreateChildActivity("CustomerService.GetCustomerByCode");
                    activity?.SetTag("customer.code", customerCode);

                    try
                    {
                        using var apiCallActivity = TracingHelper.CreateChildActivity("SageApi.GetCustomer");
                        apiCallActivity?.SetTag("sage.operation", "get_customer");
                        apiCallActivity?.SetTag("sage.customer_code", customerCode);

                        // Call the Sage 200 API to get the customer
                        var sageCustomer = await _sageApiClient.GetAsync<Sage200Microservice.Services.Models.SageCustomer>($"customers?customer_code={customerCode}");

                        apiCallActivity?.SetTag("sage.customer_id", sageCustomer.id);
                        apiCallActivity?.SetTag("sage.response.success", true);

                        return sageCustomer;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Error calling Sage 200 API to get customer {CustomerCode}, falling back to local data", customerCode);

                        using var dbActivity = TracingHelper.CreateChildActivity("Database.GetCustomer");
                        dbActivity?.SetTag("db.operation", "select");
                        dbActivity?.SetTag("db.entity", "Customer");
                        dbActivity?.SetTag("db.customer_code", customerCode);

                        // If the API call fails, check if we have the customer in our local database
                        var localCustomer = await _customerRepository.GetByCodeAsync(customerCode);

                        if (localCustomer != null)
                        {
                            dbActivity?.SetTag("db.found", true);
                            dbActivity?.SetTag("db.customer_id", localCustomer.Id);

                            // Return a SageCustomer object created from our local data
                            return new Sage200Microservice.Services.Models.SageCustomer
                            {
                                id = localCustomer.SageId ?? 0,
                                customer_code = localCustomer.CustomerCode,
                                name = localCustomer.CustomerName,
                                main_address = new Sage200Microservice.Services.Models.SageCustomerAddress
                                {
                                    address_1 = localCustomer.AddressLine1,
                                    address_2 = localCustomer.AddressLine2,
                                    town = localCustomer.City,
                                    postcode = localCustomer.Postcode
                                },
                                telephone = localCustomer.Telephone,
                                email = localCustomer.Email
                            };
                        }

                        // If we don't have the customer locally either, rethrow the exception
                        throw new Exception($"Customer with code {customerCode} not found in Sage 200 or local database", ex);
                    }
                });
        }
    }
}