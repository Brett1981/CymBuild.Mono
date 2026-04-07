using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class RowStatusController : ControllerBase
    {
        private readonly AppDbContext _context;

        public RowStatusController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/RowStatus
        [HttpGet]
        public async Task<ActionResult<IEnumerable<RowStatus>>> GetRowStatuses()
        {
            return await _context.RowStatuses.ToListAsync();
        }

        // GET: api/RowStatus/5
        [HttpGet("{id}")]
        public async Task<ActionResult<RowStatus>> GetRowStatus(byte id)
        {
            var rowStatus = await _context.RowStatuses.FindAsync(id);

            if (rowStatus == null)
            {
                return NotFound();
            }

            return rowStatus;
        }

        // PUT: api/RowStatus/5
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateRowStatus(byte id, RowStatus rowStatus)
        {
            if (id != rowStatus.ID)
            {
                return BadRequest();
            }

            _context.Entry(rowStatus).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!RowStatusExists(id))
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

        // POST: api/RowStatus
        [HttpPost]
        public async Task<ActionResult<RowStatus>> CreateRowStatus(RowStatus rowStatus)
        {
            _context.RowStatuses.Add(rowStatus);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetRowStatus), new { id = rowStatus.ID }, rowStatus);
        }

        // DELETE: api/RowStatus/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteRowStatus(byte id)
        {
            var rowStatus = await _context.RowStatuses.FindAsync(id);
            if (rowStatus == null)
            {
                return NotFound();
            }

            _context.RowStatuses.Remove(rowStatus);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool RowStatusExists(byte id)
        {
            return _context.RowStatuses.Any(e => e.ID == id);
        }
    }
}