using Sage200Microservice.Data.Models;
using Sage200Microservice.Services.Models;

namespace Sage200Microservice.Services.Interfaces
{
    public interface IInvoiceService
    {
        Task<(bool Success, string Message, long OrderId, string OrderReference)> CreateSalesOrderInvoiceAsync(Invoice invoice, List<OrderLine> lines);

        Task<(bool Success, string Message, bool IsPaid, bool IsCredited, decimal OutstandingValue, decimal AllocatedValue, List<SageAllocationHistoryItem> AllocationHistory)> CheckInvoiceStatusAsync(string invoiceReference);

        Task ProcessOutstandingInvoicesAsync();
    }
}