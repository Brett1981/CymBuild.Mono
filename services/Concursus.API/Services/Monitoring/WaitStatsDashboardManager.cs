using Concursus.Common.Shared.Monitoring;
using Concursus.EF.Monitoring;

namespace Concursus.API.Services.Monitoring
{
    public sealed class WaitStatsDashboardManager : IWaitStatsDashboardManager
    {
        private readonly WaitStatsDashboardRepository _repository;

        public WaitStatsDashboardManager(WaitStatsDashboardRepository repository)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        }

        public async Task<WaitStatsDashboardResult> GetDashboardAsync(
            WaitStatsDashboardQuery query,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(query);

            if (query.TopCount <= 0)
            {
                query.TopCount = 15;
            }

            if (query.CpuPressureSignalThresholdPct <= 0)
            {
                query.CpuPressureSignalThresholdPct = 25.00m;
            }

            return await _repository.GetDashboardAsync(query, cancellationToken);
        }
    }
}