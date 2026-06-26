using Concursus.API.Classes;
using Concursus.API.Core;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using System.Diagnostics;
using System.Data;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService : Core.Core.CoreBase
{
    #region Public Methods

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<DashboardMetricsGetResponse> DashboardMetricsGet(DashboardMetricsGetRequest request,
        ServerCallContext context)
    {
        var message = "Exception occured getting Doashboard Metrics - ";

        try
        {
            var metricList = await EF.UserInterface.DashboardMetricsGet(_serviceBase._entityFramework);

            DashboardMetricsGetResponse rsl = new();

            foreach (var metric in metricList)
            {
                var m = Converters.ConvertEfDashboardMetricToCore(metric);

                rsl.Metrics.Add(m);
            }

            return rsl;
        }
        catch (Exception ex)
        {
            message += ex.Message;

            _serviceBase.logger.LogException(ex);

            throw new RpcException(new Status(StatusCode.Unknown, message));
        }
    }

    public override async Task<AutomatedInvoicingKPIRes> GetAutomatedInvoicingKPI(AutomatedInvoicingKPIReq request, ServerCallContext context)
    {
        var message = "Exception occured getting KPI for automated Invoicing";

        AutomatedInvoicingKPIRes rsl = new();

        try
        {
            var KPIValues = await EF.UserInterface.GetAutomatedInvoicingKPI(_serviceBase._entityFramework);

            rsl.Sum = KPIValues.Sum;
            rsl.Average = KPIValues.Average;
            rsl.NumberOfOverdue = KPIValues.NumberOfOverdue;
            rsl.NumberOfPaid = KPIValues.NumberOfPaid;
            rsl.NumberOfPending = KPIValues.NumberOfPending;

            return rsl;

        }
        catch (Exception ex)
        {
            message += ex.Message;

            _serviceBase.logger.LogException(ex);

            throw new RpcException(new Status(StatusCode.Unknown, message));
        }
    }

    //OE: CBLD-408
    public override async Task<WidgetLayoutGetResponse> WidgetLayoutGet(WidgetLayoutGetRequest request,
        ServerCallContext context)
    {
        var message = "Exception occured getting Widget Dashboard Layout - ";
        WidgetLayoutGetResponse rsl = new();

        try
        {
            //_userOverride comes from the appsettings.json -> enables "hijacking" user profiles
            var _userOverride = "";
            _userOverride = _config.GetValue<string>("Environment:UserOverride");

            var WidgetLayout = await EF.UserInterface.WidgetLayoutGet(_serviceBase._entityFramework, _userOverride);

            foreach (var gauge in WidgetLayout.DashboardMetrics)
            {
                var ga = Converters.ConvertEfDashboardMetricForWidgetsToCore(gauge);
                rsl.DashboardMetrics.Add(ga);
            }

            foreach (var grid in WidgetLayout.GridViewDefinitions)
            {
                var gr = Converters.ConvertEfGridViewDefinitionToCoreGridViewDefinition(grid);
                rsl.GridViewDefinitions.Add(gr);
            }

            rsl.WidgetLayout = WidgetLayout.WidgetLayout;
        }
        catch (Exception ex)
        {
            message += ex.Message;

            _serviceBase.logger.LogException(ex);

            throw new RpcException(new Status(StatusCode.Unknown, message));
        }

        return rsl;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<DropDownDataListReply> DropDownDataList(DropDownDataListRequest request, ServerCallContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        var dropDownGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid);
        var message = $"Exception occurred getting DropDownDataList for {dropDownGuid} - ";

        if (string.IsNullOrEmpty(dropDownGuid.ToString()))
        {
            message += "You must provide the Drop Down Guid.";
            _serviceBase.logger.LogError(message);
            throw new RpcException(new Status(StatusCode.InvalidArgument, message));
        }

        try
        {
            // Prepare EF Request
            var efRequest = new EF.Types.DropDownDataListRequest
            {
                Guid = dropDownGuid,
                IsAddingAllowed = request.IsAddingAllowed,
                ParentGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.ParentGuid),
                RecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid),
                CurrentSelectedValueGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.CurrentSelectedValueGuid),
            };

            efRequest.Filters.AddRange(Functions.ConvertToCoreFilterRequest(request.Filters)); // Handle multiple filters properly

            // Fetch Dropdown Data
            var efResult = await EF.UserInterface.DropDownDataList(_serviceBase._entityFramework, efRequest);
            var result = new DropDownDataListReply();

            foreach (var di in efResult.Items)
            {
                result.Items.Add(new DropDownDataListItem()
                {
                    Name = di.Name,
                    Value = di.Value,
                    Group = di.Group,
                    ColourHex = di.ColourHex //CBLD-570
                });
            }

            stopwatch.Stop();

            if (stopwatch.ElapsedMilliseconds >= 250)
            {
                _serviceBase.logger.LogInformation(
                    $"[CymBuildPerf] Layer=gRPC Method=DropDownDataList Step=Complete Guid={dropDownGuid} DurationMs={stopwatch.ElapsedMilliseconds} RowCount={result.Items.Count} FilterCount={request.Filters.Count} HasSelectedValue={Functions.ParseAndReturnEmptyGuidIfInvalid(request.CurrentSelectedValueGuid) != Guid.Empty} HasParentGuid={Functions.ParseAndReturnEmptyGuidIfInvalid(request.ParentGuid) != Guid.Empty} HasRecordGuid={Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid) != Guid.Empty}");
            }

            return result;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            _serviceBase.logger.LogError(
                $"[CymBuildPerf] Layer=gRPC Method=DropDownDataList Step=Failed Guid={dropDownGuid} DurationMs={stopwatch.ElapsedMilliseconds} FilterCount={request.Filters.Count} Error={ex.Message}");

            message += ex.Message;
            _serviceBase.logger.LogError(message);
            throw new RpcException(new Status(StatusCode.Unknown, message));
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<DropDownListDefinitionGetResponse> DropDownListDefinitionGet(
        DropDownListDefinitionGetRequest request, ServerCallContext context)
    {
        var message = "Exception occured getting DropDownListDefinition for " + Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid).ToString() + " - ";

        if (Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid).ToString() == "")
        {
            message += "You must provide the Drop Down Guid.";

            _serviceBase.logger.LogError(message);

            throw new RpcException(new Status(StatusCode.InvalidArgument, message));
        }

        try
        {
            var efRequest =
                await EF.UserInterface.DropDownDataListDefinitionGet(_serviceBase._entityFramework,
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid));

            var rsl = Converters.ConvertEfDropDownListDefinitionGetResponseToCore(efRequest);

            return rsl;
        }
        catch (Exception ex)
        {
            message += ex.Message;

            _serviceBase.logger.LogError(message);

            throw new RpcException(new Status(StatusCode.Unknown, message));
        }
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<ExecuteMenuItemResponse> ExecuteMenuItemPost(ExecuteMenuItemRequest request,
        ServerCallContext context)
    {
        var message = "Exception occurred getting ExecuteMenuItemPost for EntityQueryGuid " + Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid).ToString() +
                      " - ";
        try
        {
            EF.Types.ExecuteEntityQueryRequest efRequest = new()
            {
                EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                DataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DataObject)
            };

            var response = _serviceBase._entityFramework.ExecuteEntityQuery(efRequest);

            ExecuteMenuItemResponse efResponse = new()
            {
                DataObject = Converters.ConvertEfDataObjectToCoreDataObject(response.Result.DataObject),
                ExitOnSuccess = response.Result == null ? true : response.Result.ExitOnSuccess
            };
            if (!string.IsNullOrEmpty(efResponse.DataObject.ErrorReturned))
            {
                throw new RpcException(new Status(StatusCode.FailedPrecondition, efResponse.DataObject.ErrorReturned));
            }
            return efResponse;
        }
        catch (Exception ex)
        {
            var preMessage = $"Error in ExecuteMenuItemPost: EntityTypeGuid-{request.DataObject.EntityTypeGuid}|Guid-{request.DataObject.Guid}  |  ";
            _serviceBase.logger.LogException(ex, preMessage);

            return new ExecuteMenuItemResponse() { ErrorReturned = preMessage + ex.Message };
        }
    }

    //CBLD-265
    public override async Task<ExecuteGridMenuItemResponse> ExecuteGridMenuAction(ExecuteGridMenuItemRequest request, ServerCallContext context)
    {
        try
        {
            EF.Types.ExecuteGridViewActionQueryRequest _request = new()
            {
                Statement = request.Statement,
                Guid = request.Guid
            };

            var response = await _serviceBase._entityFramework.ExecuteGridViewActionQuery(_request);

            ExecuteGridMenuItemResponse _response = new()
            {
                RowsAffected = response.RowsAffected,
                ErrorReturned = response.ErrorReturned
            };

            return _response;
        }
        catch (Exception ex)
        {
            return new ExecuteGridMenuItemResponse() { ErrorReturned = ex.Message };
        }
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GridDataListReply> GridDataList(GridDataListRequest request, ServerCallContext context)
    {
        return await GridDataListWithInFlightCoalescingAsync(request, context);
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GridDefinitionListReply> GridDefinitionList(GridDefinitionListRequest request,
        ServerCallContext context)
    {
        GridDefinitionListReply rsl = new();

        try
        {
            var gridDefinition = await EF.UserInterface.GetGridDefinition(_serviceBase._entityFramework, request.Code,
                 request.ForUi, request.ForExport);

            var gd = Converters.ConvertEfGridDefinitionToGridDefinition(gridDefinition);

            rsl.Grids.Add(gd);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
        }

        return rsl;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GridViewColumnDefinitionsReply> GridViewColumnDefinitions(
        GridViewColumnDefinitionsRequest request, ServerCallContext context)
    {
        GridViewColumnDefinitionsReply rsl = new();

        try
        {
            var efResult =
                await EF.UserInterface.GridViewColumnDefinitions(_serviceBase._entityFramework,
                    request.GridViewDefinitionId);

            foreach (var gvcd in efResult) rsl.Columns.Add(Converters.ConvertEfGridViewColumnDefinitionToCore(gvcd));
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
        }

        return rsl;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GridViewDefinitionsReply> GridViewDefinitions(GridViewDefinitionsRequest request, ServerCallContext context)
    {
        GridViewDefinitionsReply response = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            var gridViewDefinition = await EF.UserInterface.GetGridViewDefinition(connection, request.Id);
            response.Views.Add(Converters.ConvertEfGridViewDefinitionToCoreGridViewDefinition(gridViewDefinition));
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw; // Rethrow the exception to ensure it's not silently swallowed.
        }
        finally
        {
            // Ensure the connection is always closed and disposed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        return response;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<RecentItemResponse> RecentItemsGet(RecentItemRequest recentItem,
        ServerCallContext context)
    {
        List<EF.Types.RecentItem> ListOfRecentItems = new();
        RecentItemResponse rsl = new();
        try
        {
            ListOfRecentItems = await EF.UserInterface.RecentItemsGet(_serviceBase._entityFramework, recentItem.UserId);
            rsl.RecentItems.AddRange(ListOfRecentItems.Select(x => Converters.ConvertEfRecentItemToCoreRecentItem(x)));
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);

            throw new RpcException(new Status(StatusCode.Unknown, "SQL Exception: " + ex.Message), ex.Message);
        }

        return rsl;
    }

    #endregion Public Methods
}