using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class OutlookEmailsSysNotFiledController : ControllerBase
    {
        private readonly AppDbContext _context;

        public OutlookEmailsSysNotFiledController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/OutlookEmailsSysNotFiled
        [HttpGet]
        public async Task<ActionResult<IEnumerable<OutlookEmailSysNotFiled>>> GetEmailsSysNotFiled()
        {
            return await _context.OutlookEmailsSysNotFiled.ToListAsync();
        }

        // GET: api/OutlookEmailsSysNotFiled/5
        [HttpGet("{id}")]
        public async Task<ActionResult<OutlookEmailSysNotFiled>> GetEmailSysNotFiled(long id)
        {
            var emailSysNotFiled = await _context.OutlookEmailsSysNotFiled.FindAsync(id);

            if (emailSysNotFiled == null)
            {
                return NotFound();
            }

            return emailSysNotFiled;
        }
    }
}