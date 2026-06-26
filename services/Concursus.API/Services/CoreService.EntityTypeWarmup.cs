using System;
using System.Threading.Tasks;

namespace Concursus.API.Services;

public partial class CoreService
{
    private void TriggerCoreEntityTypeWarmup(string source)
    {
        // Fire-and-forget by design: this warms EF metadata while the dashboard/user
        // shell continues loading. DataObjectGet will coalesce with the same in-flight
        // warmup if the user opens a record before the warmup has completed.
        _ = Task.Run(async () =>
        {
            try
            {
                var sw = System.Diagnostics.Stopwatch.StartNew();
                await _serviceBase._entityFramework.WarmCommonEntityTypeCacheAsync();
                sw.Stop();

                Console.WriteLine($"[CymBuildPerf] Layer=gRPC Method=EntityTypeWarmup Step=Complete Source={source} DurationMs={sw.ElapsedMilliseconds}");
            }
            catch (Exception ex)
            {
                try
                {
                    _serviceBase.logger.LogException(ex, $"EntityType warmup failed. Source={source} | ");
                }
                catch
                {
                    Console.WriteLine($"[CymBuildPerf] Layer=gRPC Method=EntityTypeWarmup Step=Failed Source={source} Error={ex.Message}");
                }
            }
        });
    }
}
