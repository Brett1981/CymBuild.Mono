using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
public class OutlookEmailFromAddressController : ControllerBase
{
    private readonly AppDbContext _context;

    public OutlookEmailFromAddressController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/OutlookEmailFromAddress
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OutlookEmailFromAddress>>> GetEmailFromAddresses()
    {
        return await _context.OutlookEmailFromAddresses.ToListAsync();
    }

    // GET: api/OutlookEmailFromAddress/5
    [HttpGet("{id}")]
    public async Task<ActionResult<OutlookEmailFromAddress>> GetEmailFromAddress(int id)
    {
        var emailFromAddress = await _context.OutlookEmailFromAddresses.FindAsync(id);

        if (emailFromAddress == null)
        {
            return NotFound();
        }

        return emailFromAddress;
    }

    // PUT: api/OutlookEmailFromAddress/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateEmailFromAddress(int id, OutlookEmailFromAddress emailFromAddress)
    {
        if (id != emailFromAddress.ID)
        {
            return BadRequest();
        }

        _context.Entry(emailFromAddress).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!EmailFromAddressExists(id))
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

    // POST: api/OutlookEmailFromAddress
    [HttpPost]
    public async Task<ActionResult<OutlookEmailFromAddress>> CreateEmailFromAddress(OutlookEmailFromAddress emailFromAddress)
    {
        _context.OutlookEmailFromAddresses.Add(emailFromAddress);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetEmailFromAddress), new { id = emailFromAddress.ID }, emailFromAddress);
    }

    // DELETE: api/OutlookEmailFromAddress/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEmailFromAddress(int id)
    {
        var emailFromAddress = await _context.OutlookEmailFromAddresses.FindAsync(id);
        if (emailFromAddress == null)
        {
            return NotFound();
        }

        _context.OutlookEmailFromAddresses.Remove(emailFromAddress);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool EmailFromAddressExists(int id)
    {
        return _context.OutlookEmailFromAddresses.Any(e => e.ID == id);
    }
}