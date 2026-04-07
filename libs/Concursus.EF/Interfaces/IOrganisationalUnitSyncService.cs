using Concursus.EF.Dto;

namespace Concursus.EF.Interfaces
{
    public interface IOrganisationalUnitSyncService
    {
        Task UpdateOrganisationalUnitAsync(OrganisationalUnitKafkaDto dto);
    }
}