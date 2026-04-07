using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
public class OutlookEmailConversationController : ControllerBase
{
    private readonly AppDbContext _context;

    public OutlookEmailConversationController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/OutlookEmailConversation
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OutlookEmailConversation>>> GetEmailConversations()
    {
        return await _context.OutlookEmailConversations.ToListAsync();
    }

    // GET: api/OutlookEmailConversation/5
    [HttpGet("{id}")]
    public async Task<ActionResult<OutlookEmailConversation>> GetEmailConversation(long id)
    {
        var emailConversation = await _context.OutlookEmailConversations.FindAsync(id);

        if (emailConversation == null)
        {
            return NotFound();
        }

        return emailConversation;
    }

    // PUT: api/OutlookEmailConversation/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateEmailConversation(long id, OutlookEmailConversation emailConversation)
    {
        if (id != emailConversation.ID)
        {
            return BadRequest();
        }

        _context.Entry(emailConversation).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!EmailConversationExists(id))
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

    // POST: api/OutlookEmailConversation
    [HttpPost]
    public async Task<ActionResult<OutlookEmailConversation>> CreateEmailConversation(OutlookEmailConversation emailConversation)
    {
        _context.OutlookEmailConversations.Add(emailConversation);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetEmailConversation), new { id = emailConversation.ID }, emailConversation);
    }

    // DELETE: api/OutlookEmailConversation/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEmailConversation(long id)
    {
        var emailConversation = await _context.OutlookEmailConversations.FindAsync(id);
        if (emailConversation == null)
        {
            return NotFound();
        }

        _context.OutlookEmailConversations.Remove(emailConversation);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool EmailConversationExists(long id)
    {
        return _context.OutlookEmailConversations.Any(e => e.ID == id);
    }
}