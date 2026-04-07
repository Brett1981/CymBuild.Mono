using Concursus.EF.Dto;
using Concursus.EF.Interfaces;

namespace Concursus.EF.Services
{
    public class EmployeeSyncService : IEmployeeSyncService
    {
        //private readonly MyDbContext _context;
        //public EmployeeSyncService(MyDbContext context) => _context = context;
        public async Task ProcessEmployeeAsync(EmployeeKafkaDto dto)
        {
            //var unit = await _context.OrganisationalUnits
            //    .FirstOrDefaultAsync(o => o.CostCentreCode == dto.BusinessUnit);
            //if (unit == null) return;
            //var identity = await _context.Identities
            //            .FirstOrDefaultAsync(i => i.UserGuid == Guid.Parse(dto.EmployeeId));
            //bool isNew = identity == null;
            //identity ??= new Identity { UserGuid = Guid.Parse(dto.EmployeeId) };
            //string fullName = $"{dto.FirstName} {dto.LastName}";
            //var now = DateTime.UtcNow;
            //AuditHelper.Audit(_context, identity, nameof(identity.FullName), identity.FullName, fullName);
            //AuditHelper.Audit(_context, identity, nameof(identity.EmailAddress), identity.EmailAddress, dto.Email);
            //AuditHelper.Audit(_context, identity, nameof(identity.JobTitle), identity.JobTitle, dto.JobTitle);
            //AuditHelper.Audit(_context, identity, nameof(identity.OrganisationalUnitId), identity.OrganisationalUnitId, unit.ID);
            //identity.FullName = fullName;
            //identity.EmailAddress = dto.Email;
            //identity.JobTitle = dto.JobTitle;
            //identity.OrganisationalUnitId = unit.ID;
            //identity.RowStatus = 1;
            //identity.IsActive = true;
            //if (isNew) _context.Identities.Add(identity);
            //await _context.SaveChangesAsync();
        }
    }
}