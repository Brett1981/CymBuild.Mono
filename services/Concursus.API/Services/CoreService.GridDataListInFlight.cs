using Concursus.API.Classes;
using Concursus.API.Core;
using Grpc.Core;
using System.Collections.Concurrent;
using System.Diagnostics;

namespace Concursus.API.Services;

public partial class CoreService
{
    private static readonly ConcurrentDictionary<string, Lazy<Task<GridDataListReply>>> GridDataListInFlightRequests = new(StringComparer.Ordinal);

    private async Task<GridDataListReply> GridDataListWithInFlightCoalescingAsync(GridDataListRequest request, ServerCallContext context)
    {
        var gridId = $"{request?.GridCode}/{request?.GridViewCode}";
        var key = BuildGridDataListInFlightKey(request);

        Lazy<Task<GridDataListReply>> lazyTask;
        var isOwner = false;

        while (true)
        {
            var candidate = new Lazy<Task<GridDataListReply>>(
                () => ExecuteGridDataListCoreAsync(request?.Clone() ?? new GridDataListRequest(), context),
                System.Threading.LazyThreadSafetyMode.ExecutionAndPublication);

            if (GridDataListInFlightRequests.TryAdd(key, candidate))
            {
                lazyTask = candidate;
                isOwner = true;
                break;
            }

            if (GridDataListInFlightRequests.TryGetValue(key, out lazyTask!))
            {
                break;
            }
        }

        var sw = Stopwatch.StartNew();

        if (!isOwner)
        {
            _serviceBase.logger.LogInformation(
                $"[CymBuildPerf] Layer=gRPC Method=GridDataList Step=InFlightCoalesced Grid={gridId} KeyHash={key.GetHashCode()} InFlight=True");
        }

        try
        {
            var reply = await lazyTask.Value.ConfigureAwait(false);

            sw.Stop();

            if (!isOwner)
            {
                _serviceBase.logger.LogInformation(
                    $"[CymBuildPerf] Layer=gRPC Method=GridDataList Step=InFlightReturned Grid={gridId} KeyHash={key.GetHashCode()} DurationMs={sw.ElapsedMilliseconds} Rows={reply.TotalRows}");
            }

            return reply.Clone();
        }
        finally
        {
            if (lazyTask.IsValueCreated && lazyTask.Value.IsCompleted)
            {
                GridDataListInFlightRequests.TryRemove(new KeyValuePair<string, Lazy<Task<GridDataListReply>>>(key, lazyTask));
            }
        }
    }

    private async Task<GridDataListReply> ExecuteGridDataListCoreAsync(GridDataListRequest request, ServerCallContext context)
    {
        var gridId = $"{request.GridCode}/{request.GridViewCode}";
        var baseMsg = $"Exception occurred getting GridDataList for {gridId} - ";
        var sw = Stopwatch.StartNew();

        if (string.IsNullOrWhiteSpace(request.GridCode))
        {
            var msg = baseMsg + "You must provide the Grid Code.";
            _serviceBase.logger.LogError($"Message - {msg}");
            throw new RpcException(new Status(StatusCode.InvalidArgument, msg));
        }

        if (string.IsNullOrWhiteSpace(request.GridViewCode))
        {
            var msg = baseMsg + "You must provide the Grid View Code.";
            _serviceBase.logger.LogError($"Message - {msg}");
            throw new RpcException(new Status(StatusCode.InvalidArgument, msg));
        }

        try
        {
            var efRequest = Converters.ConvertCoreGridDataListRequestToEf(request);

            if (request.Filters != null && request.Filters.Count > 0)
            {
                foreach (var f in request.Filters)
                {
                    efRequest.Filters.Add(Functions.ConvertToServerFilterRequest(f.CompositeFilters));
                }
            }

            if (request.Sort != null && request.Sort.Count > 0)
            {
                efRequest.Sort.Add(Functions.ConvertToServerSortRequest(request.Sort));
            }

            var userOverride = _config.GetValue<string>("Environment:UserOverride") ?? string.Empty;

            var efResult = await EF.UserInterface.GridDataList(_serviceBase._entityFramework, efRequest, userOverride).ConfigureAwait(false);

            var reply = new GridDataListReply { TotalRows = efResult.TotalRows };

            foreach (var gdr in efResult.DataTable)
            {
                var row = new GridDataRow();
                foreach (var col in gdr.Columns)
                {
                    row.Columns.Add(Converters.ConvertEfGridDataColumnToCore(col));
                }
                reply.DataTable.Add(row);
            }

            sw.Stop();
            _serviceBase.logger.LogInformation(
                $"GridDataList OK for {gridId}. Rows={reply.TotalRows} in {sw.ElapsedMilliseconds}ms");

            return reply;
        }
        catch (Exception ex)
        {
            sw.Stop();

            StatusCode code = StatusCode.Unknown;
            var exText = ex.ToString();

            if (ex is TimeoutException || ex.InnerException is TimeoutException)
            {
                code = StatusCode.DeadlineExceeded;
            }
#if NET6_0_OR_GREATER
            else if (ex is Microsoft.Data.SqlClient.SqlException sqlEx && sqlEx.Number == -2)
            {
                code = StatusCode.DeadlineExceeded;
            }
            else if (ex.InnerException is Microsoft.Data.SqlClient.SqlException sqlExInner && sqlExInner.Number == -2)
            {
                code = StatusCode.DeadlineExceeded;
            }
#endif

            var msg = baseMsg + ex.Message;

            _serviceBase.logger.LogError($"GridDataList FAILED for {gridId} after {sw.ElapsedMilliseconds}ms: {exText} \r\nError: - {ex.Message}");

            throw new RpcException(new Status(code, msg));
        }
    }

    private string BuildGridDataListInFlightKey(GridDataListRequest? request)
    {
        if (request == null)
        {
            return "<null-request>";
        }

        var userKey = BuildGridDataListUserKey();
        var userOverride = _config.GetValue<string>("Environment:UserOverride") ?? string.Empty;
        var filterKey = request.Filters == null || request.Filters.Count == 0
            ? string.Empty
            : string.Join(";", request.Filters.Select(f => f.ToString()));
        var sortKey = request.Sort == null || request.Sort.Count == 0
            ? string.Empty
            : string.Join(";", request.Sort.Select(s => s.ToString()));

        return string.Join("|", new[]
        {
            userKey,
            userOverride,
            request.GridCode ?? string.Empty,
            request.GridViewCode ?? string.Empty,
            request.ParentGuid ?? string.Empty,
            request.Page.ToString(System.Globalization.CultureInfo.InvariantCulture),
            request.PageSize.ToString(System.Globalization.CultureInfo.InvariantCulture),
            filterKey,
            sortKey
        });
    }

    private string BuildGridDataListUserKey()
    {
        var user = _serviceBase.User;
        if (user == null)
        {
            return string.Empty;
        }

        var claimKey = string.Join("|",
            user.Claims
                .Where(c =>
                    string.Equals(c.Type, "oid", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(c.Type, "upn", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(c.Type, "preferred_username", StringComparison.OrdinalIgnoreCase) ||
                    c.Type.EndsWith("/nameidentifier", StringComparison.OrdinalIgnoreCase) ||
                    c.Type.EndsWith("/objectidentifier", StringComparison.OrdinalIgnoreCase))
                .Select(c => $"{c.Type}={c.Value}")
                .OrderBy(v => v, StringComparer.Ordinal));

        if (!string.IsNullOrWhiteSpace(claimKey))
        {
            return claimKey;
        }

        return user.Identity?.Name ?? string.Empty;
    }
}
