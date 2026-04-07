using Concursus.API.Services.InvoiceAutomation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Concursus.API.Controllers;

[ApiController]
[Route("api/invoice-schedules")]
[Authorize]
public sealed class InvoiceSchedulesController : ControllerBase
{
    private readonly ILogger<InvoiceSchedulesController> _logger;
    private readonly InvoiceAutomationRepository _repo;

    public InvoiceSchedulesController(
        ILogger<InvoiceSchedulesController> logger,
        InvoiceAutomationRepository repo)
    {
        _logger = logger;
        _repo = repo;
    }

    public sealed class GenerateMonthlySeriesRequest
    {
        public DateOnly StartDateFirstInvoice { get; set; }
        public DateOnly EndDateFinalInvoice { get; set; }
        public decimal TotalValueNet { get; set; }
        public bool OverwriteExisting { get; set; } = false;
    }

    public sealed class GenerateMonthlySeriesResponse
    {
        public int InsertedCount { get; set; }
        public int MonthsCount { get; set; }
    }

    [HttpPost("{invoiceScheduleGuid:guid}/month-configurations/generate")]
    public async Task<ActionResult<GenerateMonthlySeriesResponse>> GenerateMonthlySeries(
        Guid invoiceScheduleGuid,
        [FromBody] GenerateMonthlySeriesRequest req,
        CancellationToken ct)
    {
        if (invoiceScheduleGuid == Guid.Empty)
            return BadRequest("InvoiceScheduleGuid is required.");

        if (req.TotalValueNet <= 0)
            return BadRequest("TotalValueNet must be > 0.");

        if (req.StartDateFirstInvoice > req.EndDateFinalInvoice)
            return BadRequest("StartDateFirstInvoice must be <= EndDateFinalInvoice.");

        _logger.LogInformation(
            "GenerateMonthlySeries: schedule={Guid}, start={Start}, end={End}, total={Total}, overwrite={Overwrite}",
            invoiceScheduleGuid, req.StartDateFirstInvoice, req.EndDateFinalInvoice, req.TotalValueNet, req.OverwriteExisting);

        var (inserted, months) = await _repo.GenerateMonthlyMonthConfigurationsAsync(
            invoiceScheduleGuid,
            req.StartDateFirstInvoice,
            req.EndDateFinalInvoice,
            req.TotalValueNet,
            req.OverwriteExisting,
            ct);

        return Ok(new GenerateMonthlySeriesResponse
        {
            InsertedCount = inserted,
            MonthsCount = months
        });
    }
}