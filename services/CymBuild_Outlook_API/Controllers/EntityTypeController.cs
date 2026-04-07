using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
[EnableCors("AddinCors")]
public class EntityTypeController : ControllerBase
{
    private readonly AppDbContext _context;

    public EntityTypeController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/EntityType
    [HttpGet]
    public async Task<ActionResult<IEnumerable<EntityType>>> GetEntityTypes()
    {
        return await _context.EntityTypes.ToListAsync();
    }

    // GET: api/EntityType/5
    [HttpGet("{id}")]
    public async Task<ActionResult<EntityType>> GetEntityType(int id)
    {
        var entityType = await _context.EntityTypes.FindAsync(id);

        if (entityType == null)
        {
            return NotFound();
        }

        return entityType;
    }

    // PUT: api/EntityType/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateEntityType(int id, EntityType entityType)
    {
        if (id != entityType.ID)
        {
            return BadRequest();
        }

        _context.Entry(entityType).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!EntityTypeExists(id))
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

    // POST: api/EntityType
    [HttpPost]
    public async Task<ActionResult<EntityType>> CreateEntityType(EntityType entityType)
    {
        _context.EntityTypes.Add(entityType);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetEntityType), new { id = entityType.ID }, entityType);
    }

    // DELETE: api/EntityType/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEntityType(int id)
    {
        var entityType = await _context.EntityTypes.FindAsync(id);
        if (entityType == null)
        {
            return NotFound();
        }

        _context.EntityTypes.Remove(entityType);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool EntityTypeExists(int id)
    {
        return _context.EntityTypes.Any(e => e.ID == id);
    }
}