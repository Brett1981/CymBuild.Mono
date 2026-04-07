using Concursus.EF.Dto;

namespace Concursus.EF.Interfaces
{
    public interface IEmployeeSyncService
    {
        Task ProcessEmployeeAsync(EmployeeKafkaDto dto);
    }
}