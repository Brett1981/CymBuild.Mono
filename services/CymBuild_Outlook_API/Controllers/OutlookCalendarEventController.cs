using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Dto;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
public class OutlookCalendarEventController : ControllerBase
{
    private readonly AppDbContext _context;

    public OutlookCalendarEventController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/OutlookCalendarEvent
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OutlookCalendarEvent>>> GetCalendarEvents()
    {
        return await _context.OutlookCalendarEvents.ToListAsync();
    }

    // GET: api/OutlookCalendarEvent/5
    [HttpGet("{id}")]
    public async Task<ActionResult<OutlookCalendarEvent>> GetCalendarEvent(long id)
    {
        var calendarEvent = await _context.OutlookCalendarEvents.FindAsync(id);

        if (calendarEvent == null)
        {
            return NotFound();
        }

        return calendarEvent;
    }

    // PUT: api/OutlookCalendarEvent/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCalendarEvent(long id, OutlookCalendarEvent calendarEvent)
    {
        if (id != calendarEvent.ID)
        {
            return BadRequest();
        }

        _context.Entry(calendarEvent).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!CalendarEventExists(id))
            {
                return NotFound();
            }
            else
            {
                throw;
            }
        }

        return NoContent();
    }

    // POST: api/OutlookCalendarEvent/Create
    [HttpPost("Create")]
    public async Task<ActionResult<OutlookCalendarEvent>> CreateCalendarEvent(OutlookCalendarEvent calendarEvent)
    {
        _context.OutlookCalendarEvents.Add(calendarEvent);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetCalendarEvent), new { id = calendarEvent.ID }, calendarEvent);
    }

    // POST: api/OutlookCalendarEvent/Upsert
    [HttpPost("Upsert")]
    public async Task<ActionResult> UpsertCalendarEvent([FromBody] CalendarEventUpsertDto upsertDto)
    {
        int result = await _context.UpsertOutlookCalendarEvent(upsertDto);
        if (result == 0) // Assuming the stored procedure returns 0 for success
            return Ok();
        else
            return StatusCode(StatusCodes.Status500InternalServerError, "Error upserting the calendar event");
    }

    // DELETE: api/OutlookCalendarEvent/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCalendarEvent(long id)
    {
        var calendarEvent = await _context.OutlookCalendarEvents.FindAsync(id);
        if (calendarEvent == null)
        {
            return NotFound();
        }

        _context.OutlookCalendarEvents.Remove(calendarEvent);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool CalendarEventExists(long id)
    {
        return _context.OutlookCalendarEvents.Any(e => e.ID == id);
    }
}