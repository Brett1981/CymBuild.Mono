using Concursus.API.Core;
using System.Collections.Concurrent;
using System.Diagnostics;

namespace Concursus.API.Services;

public partial class CoreService
{
    // Patch 06A: server-side metadata cache.
    // Client-side caches already prevent repeated loads inside a running browser session.
    // This server-side cache removes repeated cold EF/SQL metadata work across pages/sessions
    // while keeping business row data uncached.
    private sealed record TimedEntityTypeGetResponse(EntityTypeGetResponse Response, DateTimeOffset CreatedOnUtc);
    private sealed record TimedGridDefinitionListReply(GridDefinitionListReply Reply, DateTimeOffset CreatedOnUtc);

    private static readonly ConcurrentDictionary<string, TimedEntityTypeGetResponse> EntityTypeGetServerCache =
        new(StringComparer.OrdinalIgnoreCase);

    private static readonly ConcurrentDictionary<string, Lazy<Task<TimedEntityTypeGetResponse>>> EntityTypeGetServerInFlight =
        new(StringComparer.OrdinalIgnoreCase);

    private static readonly ConcurrentDictionary<string, TimedGridDefinitionListReply> GridDefinitionListServerCache =
        new(StringComparer.OrdinalIgnoreCase);

    private static readonly ConcurrentDictionary<string, Lazy<Task<TimedGridDefinitionListReply>>> GridDefinitionListServerInFlight =
        new(StringComparer.OrdinalIgnoreCase);

    private static readonly TimeSpan ServerMetadataCacheTtl = TimeSpan.FromMinutes(10);

    private static string BuildEntityTypeGetServerCacheKey(EntityTypeGetRequest request)
    {
        return string.Join("|",
            $"Guid={request.Guid}",
            $"InformationView={request.IsInformationView}");
    }

    private static string BuildGridDefinitionListServerCacheKey(GridDefinitionListRequest request)
    {
        return string.Join("|",
            $"Code={request.Code}",
            $"ForUi={request.ForUi}",
            $"ForExport={request.ForExport}");
    }

    private static bool TryGetEntityTypeGetServerCache(string cacheKey, out EntityTypeGetResponse response)
    {
        response = new EntityTypeGetResponse();

        if (!EntityTypeGetServerCache.TryGetValue(cacheKey, out var cached))
        {
            return false;
        }

        if (DateTimeOffset.UtcNow - cached.CreatedOnUtc > ServerMetadataCacheTtl)
        {
            EntityTypeGetServerCache.TryRemove(cacheKey, out _);
            return false;
        }

        response = cached.Response.Clone();
        return true;
    }

    private static bool TryGetGridDefinitionListServerCache(string cacheKey, out GridDefinitionListReply response)
    {
        response = new GridDefinitionListReply();

        if (!GridDefinitionListServerCache.TryGetValue(cacheKey, out var cached))
        {
            return false;
        }

        if (DateTimeOffset.UtcNow - cached.CreatedOnUtc > ServerMetadataCacheTtl)
        {
            GridDefinitionListServerCache.TryRemove(cacheKey, out _);
            return false;
        }

        response = cached.Reply.Clone();
        return true;
    }

    private void LogMetadataServerPerf(string method, string key, Stopwatch stopwatch, bool cacheHit, bool inFlight)
    {
        try
        {
            _serviceBase.logger.LogInformation(
                $"[CymBuildPerf] Layer=gRPC Method={method} Step=MetadataCache Key={key} DurationMs={stopwatch.ElapsedMilliseconds} CacheHit={cacheHit} InFlight={inFlight}");
        }
        catch
        {
            // Logging must never affect user workflows.
        }
    }
}
