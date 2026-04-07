using Concursus.EF.Dto;
using Concursus.EF.Interfaces;

namespace Concursus.EF.Services
{
    public class OrganisationalUnitSyncService : IOrganisationalUnitSyncService
    {
        //private readonly MyDbContext _context;
        //public OrganisationalUnitSyncService(MyDbContext context) => _context = context;
        public async Task UpdateOrganisationalUnitAsync(OrganisationalUnitKafkaDto dto)
        {
            //var unit = await _context.OrganisationalUnits
            //    .FirstOrDefaultAsync(u => u.CostCentreCode == dto.CostCentreCode);
            //if (unit == null) return;
            //AuditHelper.Audit(_context, unit, nameof(unit.Name), unit.Name, dto.Name);
            //unit.Name = dto.Name;
            //await _context.SaveChangesAsync();
        }
    }
}