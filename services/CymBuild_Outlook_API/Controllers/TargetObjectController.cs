using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Dto;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
[EnableCors("AddinCors")]
public class TargetObjectController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly LoggingHelper _loggingHelper;

    public TargetObjectController(AppDbContext context, LoggingHelper loggingHelper)
    {
        _context = context;
        _loggingHelper = loggingHelper;
    }

    // GET: api/TargetObject
    [HttpGet]
    public async Task<ActionResult<IEnumerable<TargetObject>>> GetTargetObjects()
    {
        _loggingHelper.LogInfo("Getting all target objects", "GetTargetObjects()");
        return await _context.TargetObjects.ToListAsync();
    }

    // GET: api/TargetObject/5
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<TargetObjectDto>> GetTargetObject(Guid id)
    {
        _loggingHelper.LogInfo($"Getting target object with Guid {id}", "GetTargetObject()");

        try
        {
            var targetObject = await _context.GetTargetObjectAsync(id);

            if (targetObject == null)
            {
                _loggingHelper.LogWarning($"Target object with Guid {id} not found", "GetTargetObject()");
                return NotFound();
            }

            return Ok(targetObject);
        }
        catch (Exception ex)
        {
            _loggingHelper.LogError($"Error retrieving target object with Guid {id}", ex, "GetTargetObject()");
            return StatusCode(500, "Internal server error");
        }
    }

    // PUT: api/TargetObject/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateTargetObject(long id, TargetObject targetObject)
    {
        _loggingHelper.LogInfo($"Updating target object with ID {id}", "UpdateTargetObject()");

        if (id != targetObject.ID)
        {
            _loggingHelper.LogWarning($"Mismatched IDs: {id} and {targetObject.ID}", "UpdateTargetObject()");
            return BadRequest();
        }

        _context.Entry(targetObject).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
            _loggingHelper.LogInfo($"Updated target object with ID {id}", "UpdateTargetObject()");
        }
        catch (DbUpdateConcurrencyException ex)
        {
            if (!TargetObjectExists(id))
            {
                _loggingHelper.LogError($"Target object with ID {id} not found during update", ex, "UpdateTargetObject()");
                return NotFound();
            }
            else
            {
                _loggingHelper.LogError("Concurrency exception while updating target object", ex, "UpdateTargetObject()");
                throw;
            }
        }

        return NoContent();
    }

    // POST: api/TargetObject
    [HttpPost]
    public async Task<ActionResult<TargetObject>> CreateTargetObject(TargetObject targetObject)
    {
        _loggingHelper.LogInfo("Creating new target object", "CreateTargetObject()");
        _context.TargetObjects.Add(targetObject);
        await _context.SaveChangesAsync();
        _loggingHelper.LogInfo($"Created new target object with ID {targetObject.ID}", "CreateTargetObject()");

        return CreatedAtAction(nameof(GetTargetObject), new { id = targetObject.ID }, targetObject);
    }

    //api/TargetObject/Upsert
    [HttpPost("Upsert")]
    public async Task<ActionResult> UpsertTargetObject([FromBody] TargetObjectUpsertDto upsertDto)
    {
        _loggingHelper.LogInfo("Upserting target object", "UpsertTargetObject");
        int result = await _context.UpsertTargetObject(upsertDto);

        if (result == 0) // Check the expected result for success
        {
            _loggingHelper.LogInfo("Upsert operation succeeded", "UpsertTargetObject");
            return Ok();
        }
        else
        {
            _loggingHelper.LogError("Result of UpsertTargetObject", new Exception("Upsert operation failed"), "UpsertTargetObject()");
            return StatusCode(StatusCodes.Status500InternalServerError, "Error during the upsert operation.");
        }
    }

    // DELETE: api/TargetObject/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteTargetObject(long id)
    {
        _loggingHelper.LogInfo($"Deleting target object with ID {id}", "DeleteTargetObject()");
        var targetObject = await _context.TargetObjects.FindAsync(id);
        if (targetObject == null)
        {
            _loggingHelper.LogWarning($"Target object with ID {id} not found during delete", "DeleteTargetObject()");
            return NotFound();
        }

        _context.TargetObjects.Remove(targetObject);
        await _context.SaveChangesAsync();
        _loggingHelper.LogInfo($"Deleted target object with ID {id}", "DeleteTargetObject()");

        return NoContent();
    }

    private bool TargetObjectExists(long id)
    {
        return _context.TargetObjects.Any(e => e.ID == id);
    }
}