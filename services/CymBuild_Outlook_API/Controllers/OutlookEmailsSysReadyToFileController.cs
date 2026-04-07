using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class OutlookEmailsSysReadyToFileController : ControllerBase
    {
        private readonly AppDbContext _context;

        public OutlookEmailsSysReadyToFileController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/OutlookEmailsSysReadyToFile
        [HttpGet]
        public async Task<ActionResult<IEnumerable<OutlookEmailSysReadyToFile>>> GetEmailsSysReadyToFile()
        {
            return await _context.OutlookEmailsSysReadyToFile.ToListAsync();
        }

        // GET: api/OutlookEmailsSysReadyToFile/5
        [HttpGet("{id}")]
        public async Task<ActionResult<OutlookEmailSysReadyToFile>> GetEmailSysReadyToFile(long id)
        {
            var emailSysReadyToFile = await _context.OutlookEmailsSysReadyToFile.FindAsync(id);

            if (emailSysReadyToFile == null)
            {
                return NotFound();
            }

            return emailSysReadyToFile;
        }
    }
}