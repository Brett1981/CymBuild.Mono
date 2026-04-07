using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Microsoft.AspNetCore.Mvc;

namespace Concursus.API.Sage.SOAP.Controllers.Testing
{
    [ApiController]
    [Route("api/test/sage")]
    public sealed class SageTestController : ControllerBase
    {
        private readonly ISageApiClient _sageApiClient;

        public SageTestController(ISageApiClient sageApiClient)
        {
            _sageApiClient = sageApiClient;
        }

        [HttpGet("health")]
        public async Task<IActionResult> Health(CancellationToken cancellationToken)
        {
            var result = await _sageApiClient.GetHealthAsync(cancellationToken);
            return Ok(result);
        }

        [HttpGet("sales-orders")]
        public async Task<IActionResult> SalesOrders(
            [FromQuery] string orderId,
            [FromQuery] SageDataset dataset = SageDataset.group,
            CancellationToken cancellationToken = default)
        {
            var result = await _sageApiClient.FetchSalesOrdersAsync(dataset, orderId, cancellationToken: cancellationToken);
            return Ok(result);
        }

        [HttpGet("customer-transactions")]
        public async Task<IActionResult> CustomerTransactions(
            [FromQuery] string? accountReference,
            [FromQuery] string? documentNo,
            [FromQuery] SageDataset dataset = SageDataset.group,
            CancellationToken cancellationToken = default)
        {
            var result = await _sageApiClient.FetchCustomerTransactionsAsync(
                dataset,
                accountReference,
                documentNo,
                cancellationToken: cancellationToken);

            return Ok(result);
        }

        [HttpPost("sales-orders")]
        public async Task<IActionResult> CreateSalesOrder(
            [FromBody] SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _sageApiClient.CreateSalesOrderAsync(request, cancellationToken);
            return Ok(result);
        }
    }
}
