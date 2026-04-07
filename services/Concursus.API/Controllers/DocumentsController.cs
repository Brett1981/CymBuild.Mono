using Concursus.API.Components;
using Concursus.API.Services.Graph;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Concursus.API.Controllers;

[ApiController]
[Route("api/documents")]
[Authorize]
public sealed class DocumentsController : ControllerBase
{
    private readonly IDelegatedGraphClientFactory _delegatedGraphFactory;
    private readonly SharePoint _sharePoint;

    public DocumentsController(IDelegatedGraphClientFactory delegatedGraphFactory, SharePoint sharePoint)
    {
        _delegatedGraphFactory = delegatedGraphFactory;
        _sharePoint = sharePoint;
    }

    [HttpGet("download")]
    public async Task<IActionResult> Download(
        [FromQuery] string driveId,
        [FromQuery] string itemId,
        CancellationToken ct)
    {
        var graph = await _delegatedGraphFactory.CreateAsync(User, ct);

        var (stream, fileName, contentType) =
            await _sharePoint.GetFileContentStreamDelegatedAsync(graph, driveId, itemId, ct);

        // FileStreamResult disposes stream after response completes
        return new FileStreamResult(stream, contentType ?? "application/octet-stream")
        {
            FileDownloadName = fileName ?? "download",
            EnableRangeProcessing = true
        };
    }
}
