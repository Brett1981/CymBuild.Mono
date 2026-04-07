using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Dto;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
[EnableCors("AddinCors")]
public class OutlookEmailController : ControllerBase
{
    private readonly AppDbContext _context;

    public OutlookEmailController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/OutlookEmail
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OutlookEmail>>> GetEmails()
    {
        return await _context.OutlookEmails.ToListAsync();
    }

    // GET: api/OutlookEmail/5
    [HttpGet("{id}")]
    public async Task<ActionResult<OutlookEmail>> GetOutlookEmail(long id)
    {
        var outlookEmail = await _context.OutlookEmails.FindAsync(id);

        if (outlookEmail == null)
        {
            return NotFound();
        }

        return outlookEmail;
    }

    // PUT: api/OutlookEmail/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateOutlookEmail(long id, OutlookEmail outlookEmail)
    {
        if (id != outlookEmail.ID)
        {
            return BadRequest();
        }

        _context.Entry(outlookEmail).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!OutlookEmailExists(id))
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

    // POST: api/OutlookEmail
    [HttpPost]
    public async Task<ActionResult<OutlookEmail>> CreateOutlookEmail(OutlookEmail outlookEmail)
    {
        _context.OutlookEmails.Add(outlookEmail);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetOutlookEmail), new { id = outlookEmail.ID }, outlookEmail);
    }

    //api/OutlookEmail/SysProcessingUpdate
    [HttpPost("SysProcessingUpdate")]
    public async Task<ActionResult> SysProcessingUpdate([FromBody] EmailSysProcessingUpdateDto updateDto)
    {
        int result = await _context.UpdateEmailSysProcessing(updateDto);
        if (result > 0) // Check the expected result for success (Number of rows affected)
            return Ok();
        else
            return StatusCode(StatusCodes.Status500InternalServerError, "Error updating the email system processing");
    }

    //api/OutlookEmail/Upsert
    [HttpPost("Upsert")]
    public async Task<ActionResult> UpsertEmail([FromBody] EmailUpsertDto upsertDto)
    {
        int result = await _context.UpsertOutlookEmail(upsertDto);

        if (result > 0) // Check the expected result for success (Number of rows affected)
            return Ok();
        else
            return StatusCode(StatusCodes.Status500InternalServerError, "Error during the upsert operation.");
    }

    // DELETE: api/OutlookEmail/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOutlookEmail(long id)
    {
        var outlookEmail = await _context.OutlookEmails.FindAsync(id);
        if (outlookEmail == null)
        {
            return NotFound();
        }

        _context.OutlookEmails.Remove(outlookEmail);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool OutlookEmailExists(long id)
    {
        return _context.OutlookEmails.Any(e => e.ID == id);
    }
}