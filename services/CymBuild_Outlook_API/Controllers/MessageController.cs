using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
public class MessageController : ControllerBase
{
    private readonly AppDbContext _context;

    public MessageController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/Message
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Message>>> GetMessage()
    {
        var Message = await _context.Messages.ToListAsync();
        foreach (var message in Message)
        {
            await PrepareMessageAsync(message);
        }
        return Message;
    }

    // GET: api/Message/5
    [HttpGet("{id}")]
    public async Task<ActionResult<Message>> GetMessage(int id)
    {
        var message = await _context.Messages.FindAsync(id);
        if (message == null)
        {
            return NotFound();
        }
        return message;
    }

    // POST: api/Message
    [HttpPost]
    public async Task<ActionResult<Message>> PostMessage(Message message)
    {
        message = await PrepareMessageAsync(message);
        _context.Messages.Add(message);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetMessage), new { id = message.ID }, message);
    }

    // PUT: api/Message/5
    [HttpPut("{id}")]
    public async Task<IActionResult> PutMessage(int id, Message message)
    {
        if (id != message.ID)
        {
            return BadRequest();
        }
        _context.Entry(message).State = EntityState.Modified;
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!_context.Messages.Any(e => e.ID == id))
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

    // DELETE: api/Message/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteMessage(int id)
    {
        var message = await _context.Messages.FindAsync(id);
        if (message == null)
        {
            return NotFound();
        }
        _context.Messages.Remove(message);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    private async Task<Message> PrepareMessageAsync(Message message)
    {
        if (message != null && !string.IsNullOrEmpty(message.ItemId))
        {
            //Make changes here if needed before saving the message
            if (message.ID != 0)
            {
                _ = PutMessage(message.ID, message);
            }
        }
        return message;
    }
}