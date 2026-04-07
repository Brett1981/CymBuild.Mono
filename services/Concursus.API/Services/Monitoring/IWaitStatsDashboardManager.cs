

using Concursus.Common.Shared.Monitoring;

namespace Concursus.API.Services.Monitoring
{
    public interface IWaitStatsDashboardManager
    {
        Task<WaitStatsDashboardResult> GetDashboardAsync(WaitStatsDashboardQuery query, CancellationToken cancellationToken = default);
    }

}
