using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
public class OutlookEmailMailboxController : ControllerBase
{
    private readonly AppDbContext _context;

    public OutlookEmailMailboxController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/OutlookEmailMailbox
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OutlookEmailMailbox>>> GetEmailMailboxes()
    {
        return await _context.OutlookEmailMailboxes.ToListAsync();
    }

    // GET: api/OutlookEmailMailbox/5
    [HttpGet("{id}")]
    public async Task<ActionResult<OutlookEmailMailbox>> GetEmailMailbox(int id)
    {
        var emailMailbox = await _context.OutlookEmailMailboxes.FindAsync(id);

        if (emailMailbox == null)
        {
            return NotFound();
        }

        return emailMailbox;
    }

    // PUT: api/OutlookEmailMailbox/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateEmailMailbox(int id, OutlookEmailMailbox emailMailbox)
    {
        if (id != emailMailbox.ID)
        {
            return BadRequest();
        }

        _context.Entry(emailMailbox).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!EmailMailboxExists(id))
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

    // POST: api/OutlookEmailMailbox
    [HttpPost]
    public async Task<ActionResult<OutlookEmailMailbox>> CreateEmailMailbox(OutlookEmailMailbox emailMailbox)
    {
        _context.OutlookEmailMailboxes.Add(emailMailbox);
        await _context.SaveChangesAsync();

        return CreatedAtAction("GetEmailMailbox", new { id = emailMailbox.ID }, emailMailbox);
    }

    // DELETE: api/OutlookEmailMailbox/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEmailMailbox(int id)
    {
        var emailMailbox = await _context.OutlookEmailMailboxes.FindAsync(id);
        if (emailMailbox == null)
        {
            return NotFound();
        }

        _context.OutlookEmailMailboxes.Remove(emailMailbox);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool EmailMailboxExists(int id)
    {
        return _context.OutlookEmailMailboxes.Any(e => e.ID == id);
    }
}