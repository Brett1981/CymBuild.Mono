using Concursus.API.Services.InvoiceAutomation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

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

    public sealed class DrawdownBulkEditRequest
    {
        public List<DrawdownBulkEditRowRequest> Rows { get; set; } = new();
    }

    public sealed class DrawdownBulkEditRowRequest
    {
        public Guid Guid { get; set; }
        public int PeriodNumber { get; set; }
        public decimal Amount { get; set; }
        public decimal Percentage { get; set; }
        public DateTime? OnDayOfMonth { get; set; }
        public string Description { get; set; } = string.Empty;
        public Guid? RibaStageGuid { get; set; }
    }

    public sealed class DrawdownBulkEditResponse
    {
        public int UpdatedCount { get; set; }
    }

    public sealed class DrawdownStageLookupResponse
    {
        public Guid Guid { get; set; }
        public string Name { get; set; } = string.Empty;
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

    [HttpGet("{invoiceScheduleGuid:guid}/drawdown-stages")]
    public async Task<ActionResult<List<DrawdownStageLookupResponse>>> GetDrawdownStages(
        Guid invoiceScheduleGuid,
        CancellationToken ct)
    {
        if (invoiceScheduleGuid == Guid.Empty)
            return BadRequest("InvoiceScheduleGuid is required.");

        var stages = await _repo.GetDrawdownStageLookupAsync(invoiceScheduleGuid, GetCurrentUserEmail(), ct);

        return Ok(stages.Select(x => new DrawdownStageLookupResponse
        {
            Guid = x.Guid,
            Name = x.Name
        }).ToList());
    }

    [HttpPut("{invoiceScheduleGuid:guid}/month-configurations")]
    public async Task<ActionResult<DrawdownBulkEditResponse>> SaveMonthlyDrawdowns(
        Guid invoiceScheduleGuid,
        [FromBody] DrawdownBulkEditRequest req,
        CancellationToken ct)
    {
        if (invoiceScheduleGuid == Guid.Empty)
            return BadRequest("InvoiceScheduleGuid is required.");

        if (req.Rows.Count == 0)
            return BadRequest("At least one row is required.");

        var rows = req.Rows.Select(MapDrawdownRow).ToList();
        var updated = await _repo.SaveMonthlyDrawdownsAsync(invoiceScheduleGuid, rows, ct);

        return Ok(new DrawdownBulkEditResponse { UpdatedCount = updated });
    }

    [HttpPut("{invoiceScheduleGuid:guid}/percentage-configurations")]
    public async Task<ActionResult<DrawdownBulkEditResponse>> SavePercentageDrawdowns(
        Guid invoiceScheduleGuid,
        [FromBody] DrawdownBulkEditRequest req,
        CancellationToken ct)
    {
        if (invoiceScheduleGuid == Guid.Empty)
            return BadRequest("InvoiceScheduleGuid is required.");

        if (req.Rows.Count == 0)
            return BadRequest("At least one row is required.");

        var rows = req.Rows.Select(MapDrawdownRow).ToList();
        var updated = await _repo.SavePercentageDrawdownsAsync(invoiceScheduleGuid, rows, ct);

        return Ok(new DrawdownBulkEditResponse { UpdatedCount = updated });
    }

    private static InvoiceAutomationRepository.DrawdownBulkEditRow MapDrawdownRow(DrawdownBulkEditRowRequest row)
    {
        if (row.Guid == Guid.Empty)
            throw new InvalidOperationException("Drawdown row Guid is required.");

        if (row.OnDayOfMonth is null)
            throw new InvalidOperationException("OnDayOfMonth is required.");

        return new InvoiceAutomationRepository.DrawdownBulkEditRow
        {
            Guid = row.Guid,
            PeriodNumber = row.PeriodNumber,
            Amount = row.Amount,
            Percentage = row.Percentage,
            OnDayOfMonth = row.OnDayOfMonth.Value.Date,
            Description = row.Description ?? string.Empty,
            RibaStageGuid = row.RibaStageGuid
        };
    }

    private string? GetCurrentUserEmail()
    {
        return User.FindFirst("preferred_username")?.Value
            ?? User.FindFirst(ClaimTypes.Email)?.Value
            ?? User.FindFirst("email")?.Value
            ?? User.FindFirst("upn")?.Value
            ?? User.Identity?.Name;
    }

}