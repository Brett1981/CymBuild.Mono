using Sage200Microservice.Data.Models;
using Sage200Microservice.Services.Models;

namespace Sage200Microservice.Services.Interfaces
{
    public interface ICustomerService
    {
        Task<(bool Success, string Message, long CustomerId, string CustomerCode)> CreateCustomerAsync(Customer customer);

        Task<SageCustomer> GetCustomerByCodeAsync(string customerCode);
    }
}