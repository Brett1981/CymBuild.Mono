using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

[Route("api/[controller]")]
[ApiController]
public class PreferenceController : ControllerBase
{
    private readonly AppDbContext _context;

    public PreferenceController(AppDbContext context)
    {
        _context = context;
    }

    // GET: api/Preference
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Preference>>> GetPreferences()
    {
        return await _context.Preferences.ToListAsync();
    }

    // GET: api/Preference/5
    [HttpGet("{id}")]
    public async Task<ActionResult<Preference>> GetPreference(int id)
    {
        var preference = await _context.Preferences.FindAsync(id);

        if (preference == null)
        {
            return NotFound();
        }

        return preference;
    }

    // PUT: api/Preference/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdatePreference(int id, Preference preference)
    {
        if (id != preference.ID)
        {
            return BadRequest();
        }

        _context.Entry(preference).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!PreferenceExists(id))
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

    // POST: api/Preference
    [HttpPost]
    public async Task<ActionResult<Preference>> CreatePreference(Preference preference)
    {
        _context.Preferences.Add(preference);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetPreference), new { id = preference.ID }, preference);
    }

    // DELETE: api/Preference/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeletePreference(int id)
    {
        var preference = await _context.Preferences.FindAsync(id);
        if (preference == null)
        {
            return NotFound();
        }

        _context.Preferences.Remove(preference);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    private bool PreferenceExists(int id)
    {
        return _context.Preferences.Any(e => e.ID == id);
    }
}