// File: Controllers/InvoiceAutomationController.cs
using Concursus.API.Services.InvoiceAutomation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace Concursus.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class InvoiceAutomationController : ControllerBase
{
    private readonly InvoiceAutomationRepository _repo;
    private readonly IOptionsMonitor<InvoiceAutomationOptions> _options;
    private readonly ILogger<InvoiceAutomationController> _logger;

    public InvoiceAutomationController(
        InvoiceAutomationRepository repo,
        IOptionsMonitor<InvoiceAutomationOptions> options,
        ILogger<InvoiceAutomationController> logger)
    {
        _repo = repo;
        _options = options;
        _logger = logger;
    }

    [HttpGet("status")]
    public async Task<ActionResult<InvoiceAutomationStatusDto>> GetStatus(CancellationToken ct)
    {
        var opt = _options.CurrentValue;
        var dto = await _repo.GetStatusAsync(opt, ct);
        return Ok(dto);
    }

    /// <summary>
    /// Manual kick (safe): acquires same applock as worker and runs Phase4→6 once.
    /// Useful to prove orchestration works in the deployed environment even if the worker isn't alive.
    /// </summary>
    [HttpPost("run-now")]
    public async Task<IActionResult> RunNow(CancellationToken ct)
    {
        var opt = _options.CurrentValue;

        if (!opt.Enabled)
            return Conflict("InvoiceAutomation is disabled in configuration.");

        if (opt.RequesterUserGuid == Guid.Empty)
            return Problem("InvoiceAutomation:RequesterUserGuid is empty. Worker/run-now cannot run.", statusCode: 500);

        var runGuid = Guid.NewGuid();

        await _repo.WithExclusiveAppLockAsync(
            lockName: opt.SqlAppLockName,
            timeoutMs: opt.SqlAppLockTimeoutMs,
            action: async (conn, tx, innerCt) =>
            {
                var nowUtc = DateTime.UtcNow;

                if (opt.RunMaterialiseSweepEachTick)
                    await _repo.MaterialiseTriggerInstancesAsync(conn, nowUtc, maxAttempts: 5, innerCt);

                await _repo.RunPhase4To6Async(
                    conn,
                    runGuid: runGuid,
                    requesterUserGuid: opt.RequesterUserGuid,
                    defaultPaymentStatusGuid: opt.DefaultPaymentStatusGuid,
                    notes: "Manual kick via /api/invoiceautomation/run-now",
                    nowUtc: nowUtc,
                    ct: innerCt);
            },
            ct: ct);

        _logger.LogInformation("InvoiceAutomation run-now executed. RunGuid={RunGuid}", runGuid);
        return Ok(new { RunGuid = runGuid });
    }

}