using Concursus.API.Core;
using Concursus.Common.Shared.Helpers;
using Concursus.EF.Enums;
using Google.Protobuf;
using Google.Protobuf.Collections;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using ActionMenuItem = Concursus.EF.Types.ActionMenuItem;

namespace Concursus.API.Classes;

public class Converters
{
    #region Public Methods

    public static EF.Types.DataObject ConvertCoreDataObjectToEfDataObject(DataObject dataObject)
    {
        if (dataObject.DataProperties.Count == 0) return new EF.Types.DataObject();
        EF.Types.DataObject result = new()
        {
            DatabaseId = dataObject.DatabaseId,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.EntityTypeGuid),
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.Guid),
            HasValidationMessages = dataObject.HasValidationMessages,
            Label = dataObject.Label,
            RowStatus = (RowStatus)dataObject.RowStatus,
            RowVersion = dataObject.RowVersion,
            SharePointUrl = dataObject.SharePointUrl,
            SharePointSiteIdentifier = dataObject.SharePointSiteIdentifier,
            SharePointFolderPath = dataObject.SharePointFolderPath,
            SaveButtonDisabled = dataObject.SaveButtonDisabled //CBLD-382
        };

        foreach (var dataObjectDataPill in dataObject.DataPills)
        {
            result.DataPills.Add(ConvertCoreDataPillToEfDataPill(dataObjectDataPill));
        }

        foreach (var dataProperty in dataObject.DataProperties)
        {
            result.DataProperties.Add(ConvertCoreDataPropertyToEfDataProperty(dataProperty));
        }

        foreach (var objectSecurity in dataObject.ObjectSecurity)
        {
            result.ObjectSecurity.Add(ConvertCoreObjectSecurityToEfObjectSecurity(objectSecurity));
        }

        foreach (var dataObjectMergeDocument in dataObject.MergeDocuments)
        {
            result.MergeDocuments.Add(ConvertCoreMergeDocumentToEfMergeDocument(dataObjectMergeDocument));
        }

        foreach (var validationResult in dataObject.ValidationResults)
        {
            result.ValidationResults.Add(ConvertCoreValidationResultToEfValidationResult(validationResult));
        }

        foreach (var dataObjectActionMenuItem in dataObject.ActionMenuItems)
        {
            result.ActionMenuItems.Add(ConvertCoreActionMenuItemToEfActionMenuItem(dataObjectActionMenuItem));
        }

        return result;
    }

    public static EF.Types.DataProperty ConvertCoreDataPropertyToEfDataProperty(DataProperty dataProperty)
    {
        if (dataProperty == null) return new EF.Types.DataProperty();
        return new EF.Types.DataProperty()
        {
            EntityPropertyGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataProperty.EntityPropertyGuid),
            IsEnabled = dataProperty.IsEnabled,
            IsHidden = dataProperty.IsHidden,
            IsInvalid = dataProperty.IsInvalid,
            IsReadOnly = dataProperty.IsReadOnly,
            IsRestricted = dataProperty.IsRestricted,
            ValidationMessage = dataProperty.ValidationMessage,
            Value = DataPropertyConverter.NormalizeDateTimeIfApplicable(dataProperty.Value),
            IsVirtual = dataProperty.IsVirtual //CBLD-473
        };
    }

    public static EF.Types.DropDownListDefinition ConvertCoreDropDownListToEf(
        DropDownListDefinition dropDownListDefinition)
    {
        if (dropDownListDefinition == null)
            return new EF.Types.DropDownListDefinition();
        else
            return new EF.Types.DropDownListDefinition()
            {
                Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dropDownListDefinition.Guid),
                RowVersion = dropDownListDefinition.RowVersion,
                Code = dropDownListDefinition.Code,
                DefaultSortColumnName = dropDownListDefinition.DefaultSortColumnName,
                NameColumn = dropDownListDefinition.NameColumn,
                ValueColumn = dropDownListDefinition.ValueColumn,
                SqlQuery = dropDownListDefinition.SqlQuery,
                //IsDefaultColumn = dropDownListDefinition.IsDefaultColumn,
                DetailPageUrl = dropDownListDefinition.DetailPageUrl,
                IsDetailWindowed = dropDownListDefinition.IsDetailWindowed,
                InformationPageUrl = dropDownListDefinition.InformationPageUrl,
                GroupColumn = dropDownListDefinition.GroupColumn,
                ColourHexColumn = dropDownListDefinition.ColourHexColumn //CBLD-570
            };
    }

    //CBLD-259
    public static EF.Types.EntityPropertyActions ConvertCoreEntityPropertyActionsToEfEntityPropertyActions(
        Core.EntityPropertyActions entityPropertyActions)
    {
        if (entityPropertyActions == null) return new EF.Types.EntityPropertyActions();

        EF.Types.EntityPropertyActions propertyActions = new EF.Types.EntityPropertyActions()
        {
            RowStatus = (RowStatus)entityPropertyActions.RowStatus,
            RowVersion = entityPropertyActions.RowVersion,
            Guid = new Guid(entityPropertyActions.Guid),
            Statement = entityPropertyActions.Statement
        };

        return propertyActions;
    }

    public static EF.Types.EntityProperty ConvertCoreEntityPropertyToEfEntityProperty(
            EntityProperty entityProperty)
    {
        try
        {
            if (entityProperty == null) return new EF.Types.EntityProperty();

            EF.Types.EntityProperty _entityPropery = new EF.Types.EntityProperty()
            {
                Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.Guid),
                EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityTypeGuid),
                RowStatus = (RowStatus)entityProperty.RowStatus,
                RowVersion = entityProperty.RowVersion,
                DoNotTrackChanges = entityProperty.DoNotTrackChanges,
                EntityDataTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityDataTypeGuid),
                EntityDataTypeName = entityProperty.EntityDataTypeName,
                GroupSortOrder = entityProperty.GroupSortOrder,
                IsCompulsory = entityProperty.IsCompulsory,
                IsHidden = entityProperty.IsHidden,
                IsObjectLabel = entityProperty.IsObjectLabel,
                IsUppercase = entityProperty.IsUpperCase,
                IsImmutable = entityProperty.IsImmutable,
                IsReadOnly = entityProperty.IsReadOnly,
                Label = entityProperty.Label,
                MaxLength = entityProperty.MaxLength,
                LanguageLabelGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.LanguageLabelGuid),
                DropDownListDefinitionGuid =
                    Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.DropDownListDefinitionGuid),
                EntityHoBTGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityHoBTGuid),
                IsParentRelationship = entityProperty.IsParentRelationship,
                Name = entityProperty.Name,
                Precision = entityProperty.Precision,
                Scale = entityProperty.Scale,
                SortOrder = entityProperty.SortOrder,
                EntityPropertyGroupGuid =
                    Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityPropertyGroupGuid),
                IsDetailWindowed = entityProperty.IsDetailWindowed,
                DetailPageUri = entityProperty.DetailPageUri,
                ForeignEntityTypeGuid =
                    Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.ForeignEntityTypeGuid),
                InformationPageUri = entityProperty.InformationPageUri,
                DropDownListDefinition = ConvertCoreDropDownListToEf(entityProperty.DropDownListDefinition),
                SqlDefaultValueStatement = entityProperty.SqlDefaultValueStatement,
                FixedDefaultValue = entityProperty.FixedDefaultValue,
                IsIncludedInformation = entityProperty.IsIncludedInformation,
                AllowBulkChange = entityProperty.AllowBulkChange, //CBLD-260
                SelectedForBulkChange = entityProperty.SelectedForBulkChange, //CBLD-260
                Value = entityProperty.Value, //CBLD-260
                IsVirtual = entityProperty.IsVirtual, //OE: CBLD-473
                ShowOnMobile = entityProperty.ShowOnMobile,
                IsAlwaysVisibleInGroup = entityProperty.IsAlwaysVisibleInGroup,
                IsAlwaysVisibleInGroup_Mobile = entityProperty.IsAlwaysVisibleInGroupMobile,
                ExternalSearchPageUrl = entityProperty.ExternalSearchPageUrl,
                IsLatitude = entityProperty.IsLatitude,
                IsLongitude = entityProperty.IsLongitude
            };

            //CBLD-259
            foreach (var action in entityProperty.PropertyActions)
                _entityPropery.PropertyActions.Add(ConvertCoreEntityPropertyActionsToEfEntityPropertyActions(action));

            return _entityPropery;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Unknown, "SQL Exception: " + ex.Message), ex.Message);
        }
    }

    public static EF.Types.GridDataListRequest ConvertCoreGridDataListRequestToEf(
        GridDataListRequest gridDataListRequest)
    {
        if (gridDataListRequest == null) return new EF.Types.GridDataListRequest();
        EF.Types.GridDataListRequest rsl = new()
        {
            GridCode = gridDataListRequest.GridCode,
            GridViewCode = gridDataListRequest.GridViewCode,
            Page = gridDataListRequest.Page,
            PageSize = gridDataListRequest.PageSize,
            ParentGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(gridDataListRequest.ParentGuid)
        };

        return rsl;
    }

    public static EF.Types.GridDefinition ConvertCoreGridDefinitionToEfGridDefinition(GridDefinition request)
    {
        if (request == null) return new EF.Types.GridDefinition();
        EF.Types.GridDefinition rsl = new()
        {
            Code = request.Code,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid),
            Id = request.Id,
            Name = request.Name,
            PageUri = request.PageUri,
            TabName = request.TabName,
            ShowAsTiles = request.ShowAsTiles,
            RowVersion = request.RowVersion
        };

        foreach (var gridViewDefinition in request.Views)
            rsl.Views.Add(ConvertCoreGridViewDefinitionToEf(gridViewDefinition));

        return rsl;
    }

    public static EF.Types.GridViewAction ConvertCoreGridViewActiontoEfGridViewAction(Core.GridViewActions actions)
    {
        if (actions == null) return new EF.Types.GridViewAction();

        return new EF.Types.GridViewAction()
        {
            Title = actions.Title,
            Statement = actions.Statement,
            Guid = new Guid(actions.Guid)
        };
    }

    public static EF.Types.GridViewColumnDefinition ConvertCoreGridViewColumnDefinitionToEf(
            GridViewColumnDefinition request)
    {
        if (request == null) return new EF.Types.GridViewColumnDefinition();
        EF.Types.GridViewColumnDefinition rsl = new()
        {
            Id = request.Id,
            RowVersion = request.RowVersion,
            ColumnOrder = request.ColumnOrder,
            IsCombo = request.IsCombo,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid),
            IsFiltered = request.IsFiltered,
            IsHidden = request.IsHidden,
            IsPrimaryKey = request.IsPrimaryKey,
            Name = request.Name,
            Title = request.Title,
            GridViewDefinitionId = request.GridViewDefinitionId,
            Width = request.Width,
            DisplayFormat = request.DisplayFormat,
            //CBLD-338
            TopHeaderCategory = request.TopHeaderCategory,
            TopHeaderCategoryOrder = request.TopHeaderCategoryOrder
        };

        return rsl;
    }

    public static EF.Types.GridViewDefinition ConvertCoreGridViewDefinitionToEf(GridViewDefinition request)
    {
        if (request == null) return new EF.Types.GridViewDefinition();
        EF.Types.GridViewDefinition rsl = new()
        {
            Id = request.Id,
            RowVersion = request.RowVersion,
            Name = request.Name,
            Code = request.Code,
            DefaultSortColumnName = request.DefaultSortColumnName,
            DetailPageUri = request.DetailPageUri,
            DisplayGroupName = request.DisplayGroupName,
            DisplayOrder = request.DisplayOrder,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid),
            GridDefinitionId = request.GridDefinitionId,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid),
            IsDetailWindowed = request.IsDetailWindowed,
            MetricSqlQuery = request.MetricSqlQuery,
            ShowMetric = request.ShowMetric,
            SqlQuery = request.SqlQuery,
            AllowNew = request.AllowNew,
            DrawerIconCss = request.DrawIconCss,
            IsDefaultSortDescending = request.IsDefaultSortDescending,
            GridViewTypeId = request.GridViewTypeId, //OE - CBLD-265,
            AllowBulkChange = request.AllowBulkChange, // [OE: CBLD-260]
            ShowOnMobile = request.ShowOnMobile,
            TreeListFirstOrderBy = request.TreeListFirstOrderBy,
            TreeListSecondOrderBy = request.TreeListSecondOrderBy,
            TreeListThirdOrderBy = request.TreeListThirdOrderBy,
            TreeListGroupBy = request.TreeListGroupBy,
            TreeListOrderBy = request.TreeListOrderBy,
            FilteredListCreatedOnColumn = request.FilteredListCreatedOnColumn,
            FilteredListGroupBy = request.FilteredListGroupBy,
            FilteredListRedStatusIndicatorTxt = request.FilteredListRedStatusIndicatorTxt,
            FilteredListOrangeStatusIndicatorTxt = request.FilteredListOrangeStatusIndicatorTxt,
            FilteredListGreenStatusIndicatorTxt = request.FilteredListGreenStatusIndicatorTxt
        };

        foreach (var gridViewColumnDefinition in request.Columns)
            rsl.Columns.Add(ConvertCoreGridViewColumnDefinitionToEf(gridViewColumnDefinition));

        //CBLD-265
        foreach (var action in request.GridViewActions)
            rsl.GridViewActions.Add(ConvertCoreGridViewActiontoEfGridViewAction(action));

        return rsl;
    }

    public static EF.Types.RecentItem ConvertCoreRecentItemToEfRecentItem(RecentItem recentItem)
    {
        return new EF.Types.RecentItem()
        {
            DateTime = DateTime.SpecifyKind(recentItem.DateTime.ToDateTime(), DateTimeKind.Utc),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recentItem.EntityTypeGuid),
            Label = recentItem.Label,
            RecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recentItem.RecordGuid),
            UserGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recentItem.UserGuid),
            DetailPageUri = recentItem.DetailPageUri
        };
    }

    // Helper function for converting DateTimeOffset? to Timestamp
    public static Timestamp? ConvertDateTimeOffsetToTimestamp(DateTimeOffset? dateTimeOffset)
    {
        return dateTimeOffset.HasValue
            ? Timestamp.FromDateTimeOffset(dateTimeOffset.Value.ToUniversalTime())
            : (Timestamp?)null;  // Handle the case where dateTimeOffset is null
    }

    public static Core.ActionMenuItem ConvertEfActionMenuItemToCoreActionMenuItem(
            ActionMenuItem actionMenuItem)
    {
        if (actionMenuItem == null) return new Core.ActionMenuItem();
        return new Core.ActionMenuItem()
        {
            EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(actionMenuItem.EntityQueryGuid.ToString()).ToString(),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(actionMenuItem.EntityTypeGuid.ToString()).ToString(),
            IconCss = actionMenuItem.IconCss,
            Label = actionMenuItem.Label,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(actionMenuItem.Guid.ToString()).ToString(),
            Id = actionMenuItem.Id,
            Type = actionMenuItem.Type,
            SortOrder = actionMenuItem.SortOrder,
            RedirectToTargetGuid = actionMenuItem.RedirectToTargetGuid,
        };
    }

    //CBLD-408
    public static DashboardMetricForWidgets ConvertEfDashboardMetricForWidgetsToCore(EF.Types.DashboardMetricForWidgets dashboardMetric)
    {
        if (dashboardMetric == null) return new DashboardMetricForWidgets();
        var m = new DashboardMetricForWidgets()
        {
            EndAngle = dashboardMetric.EndAngle,
            Label = dashboardMetric.Label,
            MajorUnit = dashboardMetric.MajorUnit,
            Max = dashboardMetric.Max,
            Min = dashboardMetric.Min,
            MetricTypeName = dashboardMetric.MetricTypeName,
            MinorUnit = dashboardMetric.MinorUnit,
            Reverse = dashboardMetric.Reverse,
            StartAngle = dashboardMetric.StartAngle,
            MetricSqlQuery = dashboardMetric.MetricSqlQuery,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dashboardMetric.Guid.ToString()).ToString(),
            PageUri = dashboardMetric.PageUri,
            DisplayGroupName = dashboardMetric.DisplayGroupName,
            DisplayOrder = dashboardMetric.DisplayOrder,
            Code = dashboardMetric.Code,
            GridViewCode = dashboardMetric.GridViewCode
        };
        foreach (var r in dashboardMetric.Ranges) m.Ranges.Add(ConvertEfDashboardMetricRangeToCore(r));

        foreach (var v in dashboardMetric.Values) m.Values.Add(ConvertEfDashboardMetricValueToCore(v));
        ;
        return m;
    }

    public static DashboardMetricRange ConvertEfDashboardMetricRangeToCore(
        EF.Types.DashboardMetricRange dashboardMetricRange)
    {
        if (dashboardMetricRange == null) return new DashboardMetricRange();
        return new DashboardMetricRange()
        {
            MinValue = dashboardMetricRange.MinValue,
            MaxValue = dashboardMetricRange.MaxValue,
            ColourHex = dashboardMetricRange.ColourHex
        };
    }

    public static DashboardMetric ConvertEfDashboardMetricToCore(EF.Types.DashboardMetric dashboardMetric)
    {
        if (dashboardMetric == null) return new DashboardMetric();
        var m = new DashboardMetric()
        {
            EndAngle = dashboardMetric.EndAngle,
            Label = dashboardMetric.Label,
            MajorUnit = dashboardMetric.MajorUnit,
            Max = dashboardMetric.Max,
            Min = dashboardMetric.Min,
            MetricTypeName = dashboardMetric.MetricTypeName,
            MinorUnit = dashboardMetric.MinorUnit,
            Reverse = dashboardMetric.Reverse,
            StartAngle = dashboardMetric.StartAngle,
            MetricSqlQuery = dashboardMetric.MetricSqlQuery,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dashboardMetric.Guid.ToString()).ToString(),
            PageUri = dashboardMetric.PageUri,
            DisplayGroupName = dashboardMetric.DisplayGroupName,
            DisplayOrder = dashboardMetric.DisplayOrder,
        };
        foreach (var r in dashboardMetric.Ranges) m.Ranges.Add(ConvertEfDashboardMetricRangeToCore(r));

        foreach (var v in dashboardMetric.Values) m.Values.Add(ConvertEfDashboardMetricValueToCore(v));
        ;
        return m;
    }

    public static DashboardMetricValue ConvertEfDashboardMetricValueToCore(
        EF.Types.DashboardMetricValue dashboardMetricValue)
    {
        if (dashboardMetricValue == null) return new DashboardMetricValue();
        return new DashboardMetricValue()
        {
            Value = dashboardMetricValue.Value,
            ColourHex = dashboardMetricValue.ColourHex
        };
    }

    public static DataObject ConvertEfDataObjectToCoreDataObject(EF.Types.DataObject dataObject)
    {
        if (dataObject == null) return new DataObject();
        DataObject result = new()
        {
            DatabaseId = dataObject.DatabaseId,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.EntityTypeGuid.ToString()).ToString(),
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.Guid.ToString()).ToString(),
            HasValidationMessages = dataObject.HasValidationMessages,
            Label = dataObject.Label,
            RowStatus = (int)dataObject.RowStatus,
            RowVersion = dataObject.RowVersion,
            SharePointUrl = dataObject.SharePointUrl,
            HasDocuments = dataObject.HasDocuments,
            ProgressData = Functions.GenerateProgressData(dataObject.ProgressData),
            SharePointSiteIdentifier = dataObject.SharePointSiteIdentifier,
            SharePointFolderPath = dataObject.SharePointFolderPath,
            ErrorReturned = dataObject.ErrorReturned,
            SaveButtonDisabled = dataObject.SaveButtonDisabled //CBLD-382
        };
        foreach (var mergeDocument in dataObject.MergeDocuments)
            result.MergeDocuments.Add(ConvertEfMergeDocumentToCoreMergeDocument(mergeDocument));
        foreach (var actionMenuItem in dataObject.ActionMenuItems)
            result.ActionMenuItems.Add(ConvertEfActionMenuItemToCoreActionMenuItem(actionMenuItem));

        foreach (var dataPill in dataObject.DataPills) result.DataPills.Add(ConvertEfDataPillToCoreDataPill(dataPill));
        foreach (var dataProperty in dataObject.DataProperties)
            result.DataProperties.Add(ConvertEfDataPropertyToCoreDataProperty(dataProperty));

        foreach (var objectSecurity in dataObject.ObjectSecurity)
            result.ObjectSecurity.Add(ConvertEfObjectSecurityToCoreObjectSecurity(objectSecurity));
        foreach (var validationResults in dataObject.ValidationResults)
            result.ValidationResults.Add(ConvertEfValidationResultToCoreValidationResult(validationResults));
        return result;
    }

    public static DataPill ConvertEfDataPillToCoreDataPill(EF.Types.DataPill dataPill)
    {
        if (dataPill == null) return new DataPill();
        return new DataPill()
        {
            Class = dataPill.Class,
            SortOrder = dataPill.SortOrder,
            Value = dataPill.Value
        };
    }

    public static DataProperty ConvertEfDataPropertyToCoreDataProperty(EF.Types.DataProperty dataProperty)
    {
        if (dataProperty == null) return new DataProperty();
        return new DataProperty()
        {
            EntityPropertyGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataProperty.EntityPropertyGuid.ToString()).ToString(),
            IsEnabled = dataProperty.IsEnabled,
            IsHidden = dataProperty.IsHidden,
            IsInvalid = dataProperty.IsInvalid,
            IsReadOnly = dataProperty.IsReadOnly,
            IsRestricted = dataProperty.IsRestricted,
            ValidationMessage = dataProperty.ValidationMessage,
            Value = dataProperty.Value,
            IsVirtual = dataProperty.IsVirtual //CBLD-473
        };
    }

    public static DropDownListDefinitionGetResponse ConvertEfDropDownListDefinitionGetResponseToCore(
        EF.Types.DropDownListDefinitionGetResponse dropDownListDefinitionGetResponse)
    {
        if (dropDownListDefinitionGetResponse == null) return new DropDownListDefinitionGetResponse();
        DropDownListDefinitionGetResponse rsl = new()
        {
            DropDownListDefinition =
                ConvertEfDropDownListToCore(dropDownListDefinitionGetResponse.DropDownListDefinition)
        };
        return rsl;
    }

    public static DropDownListDefinition ConvertEfDropDownListToCore(
        EF.Types.DropDownListDefinition? dropDownListDefinition)
    {
        if (dropDownListDefinition == null)
            return new DropDownListDefinition();
        else
            return new DropDownListDefinition()
            {
                Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dropDownListDefinition.Guid.ToString()).ToString(),
                RowVersion = dropDownListDefinition.RowVersion,
                Code = dropDownListDefinition.Code,
                DefaultSortColumnName = dropDownListDefinition.DefaultSortColumnName,
                NameColumn = dropDownListDefinition.NameColumn,
                ValueColumn = dropDownListDefinition.ValueColumn,
                SqlQuery = dropDownListDefinition.SqlQuery,
                //IsDefaultColumn = dropDownListDefinition.IsDefaultColumn,
                DetailPageUrl = dropDownListDefinition.DetailPageUrl,
                IsDetailWindowed = dropDownListDefinition.IsDetailWindowed,
                InformationPageUrl = dropDownListDefinition.InformationPageUrl,
                GroupColumn = dropDownListDefinition.GroupColumn,
                ColourHexColumn = dropDownListDefinition.ColourHexColumn //CBLD-570
            };
    }

    public static EntityHoBT ConvertEfEntityHoBtToCoreEntityHoBt(EF.Types.EntityHoBT entityHoBt)
    {
        if (entityHoBt == null) return new EntityHoBT();
        var hobt = new EntityHoBT()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityHoBt.Guid.ToString()).ToString(),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityHoBt.EntityTypeGuid.ToString()).ToString(),
            IsMainHoBT = entityHoBt.IsMainHoBT,
            IsReadOnlyOffline = entityHoBt.IsReadOnlyOffline,
            ObjectName = entityHoBt.ObjectName,
            ObjectType = entityHoBt.ObjectType,
            RowStatus = (int)entityHoBt.RowStatus,
            RowVersion = entityHoBt.RowVersion,
            SchemaName = entityHoBt.SchemaName
        };
        return hobt;
    }

    //CBLD-259
    public static EntityPropertyActions ConvertEfEntityPropertyActionsToCoreEntityPropertyActions(EF.Types.EntityPropertyActions request)
    {
        if (request == null) return new EntityPropertyActions();

        EntityPropertyActions actions = new EntityPropertyActions()
        {
            RowStatus = (int)request.RowStatus,
            RowVersion = request.RowVersion,
            Guid = request.Guid.ToString(),
            Statement = request.Statement
        };

        return actions;
    }

    public static EntityPropertyDependant ConvertEfEntityPropertyDepenedantToCoreEntityPropertyDependent(
        EF.Types.EntityPropertyDependant edp)
    {
        if (edp == null) return new EntityPropertyDependant();
        return new EntityPropertyDependant()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(edp.Guid.ToString()).ToString(),
            RowStatus = (int)edp.RowStatus,
            RowVersion = edp.RowVersion,
            DependantEntityPropertyGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(edp.DependantEntityPropertyGuid.ToString()).ToString(),
            ParentEntityPropertyGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(edp.ParentEntityPropertyGuid.ToString()).ToString()
        };
    }

    public static EntityPropertyGroup ConvertEfEntityPropertyGroupToCoreEntityPropertyGroup(
        EF.Types.EntityPropertyGroup entityPropertyGroup)
    {
        if (entityPropertyGroup == null) return new EntityPropertyGroup();
        return new EntityPropertyGroup()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGroup.Guid.ToString()).ToString(),
            RowVersion = entityPropertyGroup.RowVersion,
            RowStatus = (int)entityPropertyGroup.RowStatus,
            Label = entityPropertyGroup.Label,
            LanguageLabelGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGroup.LanguageLabelGuid.ToString()).ToString(),
            Name = entityPropertyGroup.Name,
            SortOrder = entityPropertyGroup.SortOrder,
            Layout = entityPropertyGroup.Layout,
            ShowOnMobile = entityPropertyGroup.ShowOnMobile,
            IsCollapsable = entityPropertyGroup.IsCollapsable,
            IsDefaultCollapsed = entityPropertyGroup.IsDefaultCollapsed,
            IsDefaultCollapsedMobile = entityPropertyGroup.IsDefaultCollapsed_Mobile,
        };
    }

    public static EntityProperty ConvertEfEntityPropertyToCoreEntityProperty(
        EF.Types.EntityProperty entityProperty)
    {
        if (entityProperty == null) return new EntityProperty();
        var property = new EntityProperty()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.Guid.ToString()).ToString(),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityTypeGuid.ToString()).ToString(),
            RowStatus = (int)entityProperty.RowStatus,
            RowVersion = entityProperty.RowVersion,
            DoNotTrackChanges = entityProperty.DoNotTrackChanges,
            EntityDataTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityDataTypeGuid.ToString()).ToString(),
            EntityDataTypeName = entityProperty.EntityDataTypeName,
            GroupSortOrder = entityProperty.GroupSortOrder,
            IsCompulsory = entityProperty.IsCompulsory,
            IsHidden = entityProperty.IsHidden,
            IsObjectLabel = entityProperty.IsObjectLabel,
            IsUpperCase = entityProperty.IsUppercase,
            IsImmutable = entityProperty.IsImmutable,
            IsReadOnly = entityProperty.IsReadOnly,
            Label = entityProperty.Label,
            MaxLength = entityProperty.MaxLength,
            LanguageLabelGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.LanguageLabelGuid.ToString()).ToString(),
            DropDownListDefinitionGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.DropDownListDefinitionGuid.ToString()).ToString(),
            EntityHoBTGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityHoBTGuid.ToString()).ToString(),
            IsParentRelationship = entityProperty.IsParentRelationship,
            Name = entityProperty.Name,
            Precision = entityProperty.Precision,
            Scale = entityProperty.Scale,
            SortOrder = entityProperty.SortOrder,
            EntityPropertyGroupGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.EntityPropertyGroupGuid.ToString()).ToString(),
            IsDetailWindowed = entityProperty.IsDetailWindowed,
            DetailPageUri = entityProperty.DetailPageUri,
            ForeignEntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityProperty.ForeignEntityTypeGuid.ToString()).ToString(),
            InformationPageUri = entityProperty.InformationPageUri,
            DropDownListDefinition = ConvertEfDropDownListToCore(entityProperty.DropDownListDefinition),
            SqlDefaultValueStatement = entityProperty.SqlDefaultValueStatement,
            FixedDefaultValue = entityProperty.FixedDefaultValue,
            IsIncludedInformation = entityProperty.IsIncludedInformation,
            AllowBulkChange = entityProperty.AllowBulkChange, //CBLD-260
            IsVirtual = entityProperty.IsVirtual, //OE: CBLD-473
            ShowOnMobile = entityProperty.ShowOnMobile,
            IsAlwaysVisibleInGroup = entityProperty.IsAlwaysVisibleInGroup,
            IsAlwaysVisibleInGroupMobile = entityProperty.IsAlwaysVisibleInGroup_Mobile,
            ExternalSearchPageUrl = entityProperty.ExternalSearchPageUrl,
            IsLongitude = entityProperty.IsLongitude,
            IsLatitude = entityProperty.IsLatitude
        };

        //CBLD-259
        foreach (var action in entityProperty.PropertyActions)
            property.PropertyActions.Add(ConvertEfEntityPropertyActionsToCoreEntityPropertyActions(action));

        return property;
    }

    public static EntityQueryParameter ConvertEfEntityQueryParameterToCoreEntityQueryParameter(
        EF.Types.EntityQueryParameter entityQueryParameter)
    {
        if (entityQueryParameter == null) return new EntityQueryParameter();
        return new EntityQueryParameter()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityQueryParameter.Guid.ToString()).ToString(),
            Name = entityQueryParameter.Name,
            RowStatus = (int)entityQueryParameter.RowStatus,
            RowVersion = entityQueryParameter.RowVersion,
            MappedEntityPropertyGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityQueryParameter.MappedEntityPropertyGuid.ToString()).ToString()
        };
    }

    public static EntityQuery ConvertEfEntityQueryToCoreEntityQuery(EF.Types.EntityQuery entityQuery)
    {
        if (entityQuery == null) return new EntityQuery();
        return new EntityQuery()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityQuery.Guid.ToString()).ToString(),
            Name = entityQuery.Name,
            RowStatus = (int)entityQuery.RowStatus,
            EntityHoBTGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityQuery.EntityHoBTGuid.ToString()).ToString(),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityQuery.EntityTypeGuid.ToString()).ToString(),
            IsDefaultCreate = entityQuery.IsDefaultCreate,
            IsDefaultDataPills = entityQuery.IsDefaultDataPills,
            IsDefaultDelete = entityQuery.IsDefaultDelete,
            IsDefaultRead = entityQuery.IsDefaultRead,
            IsDefaultUpdate = entityQuery.IsDefaultUpdate,
            IsDefaultValidation = entityQuery.IsDefaultValidation,
            IsScalarExecute = entityQuery.IsScalarExecute,
            Statement = entityQuery.Statement,
            RowVersion = entityQuery.RowVersion,
            IsDefaultProgressData = entityQuery.IsDefaultProgressData
        };
    }

    public static EntityType ConvertEfEntityTypeToCoreEntityType(EF.Types.EntityType entityType,
        EntityTypeGetResponse entityTypeGetResponse)
    {
        if (entityType == null) return new EntityType();
        entityTypeGetResponse.EntityType = new EntityType
        {
            RowVersion = entityType.RowVersion,
            DoNotTrackChanges = entityType.DoNotTrackChanges,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityType.Guid.ToString()).ToString(),
            HasDocuments = entityType.HasDocuments,
            IsReadOnlyOffline = entityType.IsReadOnlyOffline,
            IsRequiredSystemData = entityType.IsRequiredSystemData,
            Label = entityType.Label,
            LanguageLabelGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(entityType.LanguageLabelGuid.ToString()).ToString(),
            Name = entityType.Name,
            RowStatus = (int)entityType.RowStatus,
            IconCss = entityType.IconCss
        };

        foreach (var h in entityType.EntityHoBTs)
        {
            var hobt = ConvertEfEntityHoBtToCoreEntityHoBt(h);

            foreach (var os in h.ObjectSecurity)
                hobt.ObjectSecurity.Add(ConvertEfObjectSecurityToCoreObjectSecurity(os));

            entityTypeGetResponse.EntityType.EntityHoBTs.Add(hobt);
        }

        foreach (var p in entityType.EntityProperties)
        {
            var property = ConvertEfEntityPropertyToCoreEntityProperty(p);

            foreach (var edp in p.DependantProperties)
                property.DependantProperties.Add(ConvertEfEntityPropertyDepenedantToCoreEntityPropertyDependent(edp));

            foreach (var os in p.ObjectSecurity)
                property.ObjectSecurity.Add(ConvertEfObjectSecurityToCoreObjectSecurity(os));

            entityTypeGetResponse.EntityType.EntityProperties.Add(property);
        }

        foreach (var g in entityType.EntityPropertyGroups)
            entityTypeGetResponse.EntityType.EntityPropertyGroups.Add(
                ConvertEfEntityPropertyGroupToCoreEntityPropertyGroup(g));

        foreach (var g in entityType.EntityQueries)
        {
            var eq = ConvertEfEntityQueryToCoreEntityQuery(g);

            foreach (var eqp in g.EntityQueryParameters)
                eq.EntityQueryParameters.Add(ConvertEfEntityQueryParameterToCoreEntityQueryParameter(eqp));

            entityTypeGetResponse.EntityType.EntityQueries.Add(eq);
        }

        foreach (var os in entityType.ObjectSecurity)
            entityTypeGetResponse.EntityType.ObjectSecurity.Add(ConvertEfObjectSecurityToCoreObjectSecurity(os));
        return entityTypeGetResponse.EntityType;
    }

    public static GridDataColumn ConvertEfGridDataColumnToCore(EF.Types.GridDataColumn gridDataColumn)
    {
        if (gridDataColumn == null) return new GridDataColumn();
        return new GridDataColumn()
        {
            Name = gridDataColumn.Name,
            Value = gridDataColumn.Value
        };
    }

    public static GridDefinition ConvertEfGridDefinitionToGridDefinition(EF.Types.GridDefinition request)
    {
        if (request == null) return new GridDefinition();
        GridDefinition rsl = new()
        {
            Code = request.Code,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid.ToString()).ToString(),
            Id = request.Id,
            Name = request.Name,
            PageUri = request.PageUri,
            RowVersion = request.RowVersion,
            TabName = request.TabName,
            ShowAsTiles = request.ShowAsTiles
        };

        foreach (var gridViewDefinition in request.Views)
            rsl.Views.Add(ConvertEfGridViewDefinitionToCoreGridViewDefinition(gridViewDefinition));

        return rsl;
    }

    public static Core.GridViewActions ConvertEfGridViewActionToCoreGridViewAction(EF.Types.GridViewAction actions)
    {
        if (actions == null) return new GridViewActions();

        return new GridViewActions()
        {
            Title = actions.Title,
            Statement = actions.Statement,
            Guid = actions.Guid.ToString()
        };
    }

    public static GridViewColumnDefinition ConvertEfGridViewColumnDefinitionToCore(
        EF.Types.GridViewColumnDefinition request)
    {
        if (request == null) return new GridViewColumnDefinition();
        GridViewColumnDefinition rsl = new()
        {
            Id = request.Id,
            RowVersion = request.RowVersion,
            ColumnOrder = request.ColumnOrder,
            IsCombo = request.IsCombo,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid.ToString()).ToString(),
            IsFiltered = request.IsFiltered,
            IsHidden = request.IsHidden,
            IsPrimaryKey = request.IsPrimaryKey,
            Name = request.Name,
            Title = request.Title,
            GridViewDefinitionId = request.GridViewDefinitionId,
            Width = request.Width,
            DisplayFormat = request.DisplayFormat,
            //CBLD-338
            TopHeaderCategory = request.TopHeaderCategory ?? "",
            TopHeaderCategoryOrder = request.TopHeaderCategoryOrder
        };

        return rsl;
    }

    public static GridViewDefinition ConvertEfGridViewDefinitionToCoreGridViewDefinition(
        EF.Types.GridViewDefinition request)
    {
        if (request == null) return new GridViewDefinition();
        GridViewDefinition rsl = new()
        {
            Id = request.Id,
            RowVersion = request.RowVersion,
            Name = request.Name,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid.ToString()).ToString(),
            Code = request.Code,
            DefaultSortColumnName = request.DefaultSortColumnName,
            DetailPageUri = request.DetailPageUri,
            DisplayGroupName = request.DisplayGroupName,
            DisplayOrder = request.DisplayOrder,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid.ToString()).ToString(),
            GridDefinitionId = request.GridDefinitionId,
            IsDetailWindowed = request.IsDetailWindowed,
            MetricSqlQuery = request.MetricSqlQuery,
            ShowMetric = request.ShowMetric,
            SqlQuery = request.SqlQuery,
            AllowNew = request.AllowNew,
            DrawIconCss = request.DrawerIconCss,
            IsDefaultSortDescending = request.IsDefaultSortDescending,
            GridViewTypeId = request.GridViewTypeId, //OE - CBLD-265,
            AllowBulkChange = request.AllowBulkChange, // [OE: CBLD-260]
            ShowOnMobile = request.ShowOnMobile,
            TreeListFirstOrderBy = request.TreeListFirstOrderBy,
            TreeListSecondOrderBy = request.TreeListSecondOrderBy,
            TreeListThirdOrderBy = request.TreeListThirdOrderBy,
            TreeListGroupBy = request.TreeListGroupBy,
            TreeListOrderBy = request.TreeListOrderBy,
            FilteredListCreatedOnColumn = request.FilteredListCreatedOnColumn,
            FilteredListGroupBy = request.FilteredListGroupBy,
            FilteredListRedStatusIndicatorTxt = request.FilteredListRedStatusIndicatorTxt,
            FilteredListOrangeStatusIndicatorTxt = request.FilteredListOrangeStatusIndicatorTxt,
            FilteredListGreenStatusIndicatorTxt = request.FilteredListGreenStatusIndicatorTxt
        };

        foreach (var gridViewColumnDefinition in request.Columns)
            rsl.Columns.Add(ConvertEfGridViewColumnDefinitionToCore(gridViewColumnDefinition));

        //CBLD-265
        if (request.GridViewActions != null)
            foreach (var action in request.GridViewActions)
                rsl.GridViewActions.Add(ConvertEfGridViewActionToCoreGridViewAction(action));

        return rsl;
    }

    public static AutomatedInvoicingKPIRes ConvertEFAutoInvoicingKIPToCore(EF.Types.AutomatedInvoicingKPI request)
    {
        if (request == null) return new AutomatedInvoicingKPIRes();
        AutomatedInvoicingKPIRes rsl = new()
        {
            Average = request.Average,
            Sum = request.Sum,
            NumberOfOverdue = request.NumberOfOverdue,
            NumberOfPaid = request.NumberOfPaid,
            NumberOfPending = request.NumberOfPending
        };

        return rsl;
    }

    //OE: CBLD-408
    public static GridViewDefinitionForWidgets ConvertEfGridViewDefinitionToCoreGridViewDefinition(
        EF.Types.GridViewDefinitionForWidgets request)
    {
        if (request == null) return new GridViewDefinitionForWidgets();
        GridViewDefinitionForWidgets rsl = new()
        {
            Id = request.Id,
            RowVersion = request.RowVersion,
            Name = request.Name,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid.ToString()).ToString(),
            Code = request.Code,
            DefaultSortColumnName = request.DefaultSortColumnName,
            DetailPageUri = request.DetailPageUri,
            DisplayGroupName = request.DisplayGroupName,
            DisplayOrder = request.DisplayOrder,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid.ToString()).ToString(),
            GridDefinitionId = request.GridDefinitionId,
            IsDetailWindowed = request.IsDetailWindowed,
            MetricSqlQuery = request.MetricSqlQuery,
            ShowMetric = request.ShowMetric,
            SqlQuery = request.SqlQuery,
            AllowNew = request.AllowNew,
            DrawIconCss = request.DrawerIconCss,
            IsDefaultSortDescending = request.IsDefaultSortDescending,
            GridViewTypeId = request.GridViewTypeId,
            GridViewCode = request.GridViewCode
        };

        foreach (var gridViewColumnDefinition in request.Columns)
            rsl.Columns.Add(ConvertEfGridViewColumnDefinitionToCore(gridViewColumnDefinition));

        //CBLD-265
        if (request.GridViewActions != null)
            foreach (var action in request.GridViewActions)
                rsl.GridViewActions.Add(ConvertEfGridViewActionToCoreGridViewAction(action));

        return rsl;
    }

    public static DataObject ConvertEfListDataObjectToCoreListDataObject(List<EF.Types.DataObject> dataObject)
    {
        throw new NotImplementedException();
    }

    public static MergeDocument ConvertEfMergeDocumentToCoreMergeDocument(EF.Types.MergeDocument mergeDocument)
    {
        if (mergeDocument == null) return new MergeDocument();
        return new MergeDocument()
        {
            DocumentId = mergeDocument.DocumentId,
            DriveId = mergeDocument.DriveId,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.EntityTypeGuid.ToString()).ToString(),
            FilenameTemplate = mergeDocument.FilenameTemplate,
            Name = mergeDocument.Name,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.Guid.ToString()).ToString(),
            Id = mergeDocument.Id,
            LinkedEntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.LinkedEntityTypeGuid.ToString()).ToString(),
            AllowPDFOnly = mergeDocument.AllowPDFOnly,
            AllowExcelOutputOnly = mergeDocument.AllowExcelOutputOnly,
            ProduceOneOutputPerRow = mergeDocument.ProduceOneOutputPerRow,
            Items = { mergeDocument.Items.Select(ConvertEfMergeDocumentItemToCoreMergeDocumentItem) }
        };
    }

    public static MergeDocumentItem ConvertEfMergeDocumentItemToCoreMergeDocumentItem(EF.Types.MergeDocumentItem item)
    {
        return new MergeDocumentItem()
        {
            Guid = item.Guid.ToString(),
            BookmarkName = item.BookmarkName,
            MergeDocumentItemType = item.MergeDocumentItemType,
            EntityType = item.EntityType,
            EntityTypeGuid = item.EntityTypeGuid.ToString(),
            LinkedEntityTypeGuid = item.LinkedEntityTypeGuid.ToString(),
            SubFolderPath = item.SubFolderPath,
            ImageColumns = item.ImageColumns ?? 0,
            Includes = { item.Includes.Select(ConvertEfMergeDocumentItemIncludeToCore) }
        };
    }

    public static List<MergeDocumentItem> ConvertEfMergeDocumentItemsToCoreMergeDocumentItems(List<EF.Types.MergeDocumentItem> item)
    {
        return item.Select(ConvertEfMergeDocumentItemToCoreMergeDocumentItem).ToList();
    }

    public static MergeDocumentItemInclude ConvertEfMergeDocumentItemIncludeToCore(EF.Types.MergeDocumentItemInclude include)
    {
        return new MergeDocumentItemInclude()
        {
            Guid = include.Guid.ToString(),
            SortOrder = include.SortOrder,
            SourceDocumentEntityProperty = include.SourceDocumentEntityProperty,
            SourceSharepointItemEntityProperty = include.SourceSharePointItemEntityProperty,
            IncludedMergeDocument = include.IncludedMergeDocument
        };
    }

    public static ObjectSecurity ConvertEfObjectSecurityToCoreObjectSecurity(
        EF.Types.ObjectSecurity objectSecurity)
    {
        if (objectSecurity == null) return new ObjectSecurity();
        ObjectSecurity rsl = new()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.Guid.ToString()).ToString(),
            CanRead = objectSecurity.CanRead,
            CanWrite = objectSecurity.CanWrite,
            GroupGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.GroupGuid.ToString()).ToString(),
            DataObjectGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.ObjectGuid.ToString()).ToString(),
            RowStatus = (int)objectSecurity.RowStatus,
            RowVersion = objectSecurity.RowVersion,
            UserGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.UserGuid.ToString()).ToString(),
            Id = objectSecurity.Id,
            UserIdentity = objectSecurity.UserIdentity ?? "",
            GroupIdentity = objectSecurity.GroupIdentity ?? ""
            //DefaultGroupIdentity = objectSecurity.DefaultGroupIdentity ?? ""
        };
        return rsl;
    }

    //CBLD-405: Added additional fields.
    public static OrganisationalUnit ConvertEfOrganisationalUnitToCoreOrganisationalUnit(
        EF.Types.OrganisationalUnit organisationalUnit)
    {
        if (organisationalUnit == null) return new OrganisationalUnit();
        return new OrganisationalUnit()
        {
            Id = organisationalUnit.Id,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(organisationalUnit.Guid.ToString()).ToString(),
            Name = organisationalUnit.Name,
            ParentOrganisationalUnitGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(organisationalUnit.ParentOrganisationalUnitGuid.ToString()).ToString(),
            IsBusinessUnit = organisationalUnit.IsBusinessUnit ?? false,
            IsDepartment = organisationalUnit.IsDepartment ?? false,
            IsDivision = organisationalUnit.IsDivision ?? false,
            IsTeam = organisationalUnit.IsTeam ?? false,
        };
    }

    public static RecentItem ConvertEfRecentItemToCoreRecentItem(EF.Types.RecentItem recentItem)
    {
        return new RecentItem()
        {
            DateTime = Timestamp.FromDateTime(new DateTime(((DateTime)recentItem.DateTime).Ticks, DateTimeKind.Utc)),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recentItem.EntityTypeGuid.ToString()).ToString(),
            Label = recentItem.Label,
            RecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recentItem.RecordGuid.ToString()).ToString(),
            UserGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recentItem.UserGuid.ToString()).ToString(),
            DetailPageUri = recentItem.DetailPageUri,
            EntityTypeLabel = recentItem.EntityTypeLabel
        };
    }

    public static RecordHistory ConvertEfRecordHistoryToCoreRecordHistory(EF.Types.RecordHistory recordHistory)
    {
        if (recordHistory == null) return new RecordHistory();
        return new RecordHistory()
        {
            Id = recordHistory.Id,
            RowId = recordHistory.RowId,
            UserId = recordHistory.UserId,
            ColumnName = recordHistory.ColumnName,
            DateTimeUtc = Timestamp.FromDateTime(DateTime.SpecifyKind(recordHistory.DateTimeUtc, DateTimeKind.Utc)),
            NewValue = recordHistory.NewValue,
            PreviousValue = recordHistory.PreviousValue,
            SchemaName = recordHistory.SchemaName,
            SqlUser = recordHistory.SqlUser,
            TableName = recordHistory.TableName,
            UserName = recordHistory.UserName
        };
    }

    public static ScheduleItemStatus ConvertEfScheduleItemStatusToCoreScheduleItemStatus(
        EF.Types.ScheduleItemStatus scheduleItemStatus)
    {
        if (scheduleItemStatus == null) return new ScheduleItemStatus();
        return new ScheduleItemStatus()
        {
            Id = scheduleItemStatus.Id,
            Color = scheduleItemStatus.Color,
            Name = scheduleItemStatus.Name
        };
    }

    public static ScheduleItem ConvertEfScheduleItemToCoreScheduleItem(EF.Types.ScheduleItem scheduleItem)
    {
        if (scheduleItem == null) return new ScheduleItem();
        return new ScheduleItem()
        {
            Description = scheduleItem.Description,
            End = Timestamp.FromDateTime(DateTime.SpecifyKind(scheduleItem.EndDateTimeUTC, DateTimeKind.Utc)),
            EndTimezone = scheduleItem.EndTimezone,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(scheduleItem.Guid.ToString()).ToString(),
            Id = scheduleItem.Id,
            IsAllDay = scheduleItem.IsAllDay,
            JobNumber = scheduleItem.JobNumber,
            RecurrenceExceptions = scheduleItem.RecurrenceExceptions,
            RecurrenceId = scheduleItem.RecurrenceId,
            RecurrenceRule = scheduleItem.RecurrenceRule,
            Start = Timestamp.FromDateTime(DateTime.SpecifyKind(scheduleItem.StartDateTimeUTC, DateTimeKind.Utc)),
            StartTimezone = scheduleItem.StartTimezone,
            StatusId = scheduleItem.StatusId,
            Title = scheduleItem.Title,
            TypeId = scheduleItem.TypeId,
            UserId = scheduleItem.UserId
        };
    }

    public static ScheduleItemType ConvertEfScheduleItemTypeToCoreScheduleItemType(
        EF.Types.ScheduleItemType scheduleItemType)
    {
        if (scheduleItemType == null) return new ScheduleItemType();
        return new ScheduleItemType()
        {
            Id = scheduleItemType.Id,
            Color = scheduleItemType.Color,
            Name = scheduleItemType.Name
        };
    }

    public static UserPreferences ConvertEfUserPreferencesToCoreUserPreferences(
        EF.Types.UserPreferences userPreferences)
    {
        if (userPreferences == null) return new UserPreferences();
        UserPreferences rsl = new()
        {
            Id = userPreferences.Id,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(userPreferences.Guid.ToString()).ToString(),
            SystemLanguageID = userPreferences.SystemLanguageID,
            WidgetLayout = userPreferences.WidgetLayout //CBLD-408
        };
        return rsl;
    }

    public static User ConvertEfUserToCoreUser(EF.Types.User user)
    {
        if (user == null) return new User();
        User rsl = new()
        {
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(user.Guid.ToString()).ToString(),
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            FullName = user.FullName,
            JobTitle = user.JobTitle,
            BillableRate = user.BillableRate.HasValue ? (double)user.BillableRate.Value : 0.00,
            MobileNo = user.MobileNo,
            OnHoliday = user.OnHoliday,
            UserId = user.UserId,
            Signature = user.Signature != null ? ByteString.CopyFrom(user.Signature) : ByteString.Empty, // Convert byte[] to ByteString
        };
        return rsl;
    }

    public static DriveItem ConvertMicrosoftGraphDriveItemToCoreDriveItem(Microsoft.Graph.Models.DriveItem driveItemInfo, string driveId)
    {
        //Convert Microsoft Graph DriveItem To Core DriveItem
        DriveItem rsl = new()
        {
            Id = driveItemInfo.Id,
            Name = driveItemInfo.Name,
            WebUrl = driveItemInfo.WebUrl,
            ParentReference = new Core.DriveItem.Types.ItemReference()
            {
                DriveId = driveItemInfo.ParentReference.DriveId,
                DriveType = driveItemInfo.ParentReference.DriveType,
                Id = driveItemInfo.ParentReference.Id,
                Path = driveItemInfo.ParentReference.Path,
            },
            DriveId = driveId,
            CreatedDateTime = ConvertDateTimeOffsetToTimestamp(driveItemInfo.CreatedDateTime),
            LastModifiedDateTime = ConvertDateTimeOffsetToTimestamp(driveItemInfo.LastModifiedDateTime),
            Size = (long)driveItemInfo.Size,
            CTag = driveItemInfo.CTag
        };
        return rsl;
    }

    public static EF.Types.PublicHoliday ConvertCorePublicHolidayToEfPublicHoliday(PublicHoliday holiday)
    {
        if (holiday == null) return new EF.Types.PublicHoliday();

        return new EF.Types.PublicHoliday
        {
            ID = holiday.ID,
            Date = holiday.Date.ToDateTime(),
            DayName = holiday.DayName,
            MonthName = holiday.MonthName,
            YearInWords = holiday.YearInWords,
            FormattedDate = holiday.FormattedDate,
            HolidayName = holiday.HolidayName,
            IsBankHoliday = holiday.IsBankHoliday,
            Region = holiday.Region,
            FiscalQuarter = holiday.FiscalQuarter,
            FiscalYear = holiday.FiscalYear,
            DayOfYear = holiday.DayOfYear,
            WeekOfYear = holiday.WeekOfYear
        };
    }

    public static QuoteDashboardData ConvertEFQuoteDashboardDataToCoreQuoteDashboardData(EF.Types.QuoteDashboardData data)
    {
        if (data == null) return new QuoteDashboardData();

        Timestamp timestamp = Timestamp.FromDateTime(data.Date.ToUniversalTime());

        return new QuoteDashboardData
        {
            QuoteID = Convert.ToInt32(data.QuoteID),
            QuoteNumber = data.QuoteNumber,
            Guid = data.Guid,
            Date = timestamp,
            Status = data.Status,
            Client = data.Client,
            QuoteType = data.QuoteType,
            QuoteValue = Convert.ToDouble(data.QuoteValue)
        };
    }

    public static PublicHoliday ConvertEFPublicHolidayToCorePublicHoliday(EF.Types.PublicHoliday holiday)
    {
        if (holiday == null) return new PublicHoliday();

        Timestamp timestamp = Timestamp.FromDateTime(holiday.Date.ToUniversalTime());

        return new PublicHoliday
        {
            ID = holiday.ID,
            Date = timestamp,
            DayName = holiday.DayName,
            MonthName = holiday.MonthName,
            YearInWords = holiday.YearInWords,
            FormattedDate = holiday.FormattedDate,
            HolidayName = holiday.HolidayName,
            IsBankHoliday = holiday.IsBankHoliday,
            Region = holiday.Region,
            FiscalQuarter = holiday.FiscalQuarter,
            FiscalYear = holiday.FiscalYear,
            DayOfYear = holiday.DayOfYear,
            WeekOfYear = holiday.WeekOfYear
        };
    }

    public static NonActivityEvents ConvertEFNonActivityEventsToCoreNonActivityEvents(EF.Types.NonActivityEvents nonActivityEvent)
    {
        try
        {
            if (nonActivityEvent == null) return new NonActivityEvents();

            //ToUniversalTIme seems to change the date by going back a day.
            Timestamp startTime = Timestamp.FromDateTime(DateTime.SpecifyKind(nonActivityEvent.StartTime, DateTimeKind.Utc));
            Timestamp endTime = Timestamp.FromDateTime(DateTime.SpecifyKind(nonActivityEvent.EndTime, DateTimeKind.Utc));

            return new NonActivityEvents
            {
                ID = nonActivityEvent.ID,
                EventName = nonActivityEvent.EventName,
                StartTime = startTime,
                EndTime = endTime,
                TeamId = nonActivityEvent.TeamId,
                MemberId = nonActivityEvent.MemberId,
                Guid = nonActivityEvent.Guid.ToString(),
                AbsenceTypeID = nonActivityEvent.AbsenceTypeID
            };
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex.ToString());
            return new NonActivityEvents();
        }
    }

    public static EF.Types.NonActivityEvents ConvertCoreNonActivityEventsToEFNonActivityEvents(NonActivityEvents nonActivityEvent)
    {
        if (nonActivityEvent == null) return new EF.Types.NonActivityEvents();

        return new EF.Types.NonActivityEvents
        {
            ID = nonActivityEvent.ID,
            EventName = nonActivityEvent.EventName,
            StartTime = nonActivityEvent.StartTime.ToDateTime(),
            EndTime = nonActivityEvent.StartTime.ToDateTime(),
            TeamId = nonActivityEvent.TeamId,
            MemberId = nonActivityEvent.MemberId
        };
    }

    //public static ScheduledActivity ConvertEFScheduledActivityToCoreNonActivityEvents(EF.Types.ScheduledActivity nonActivityEvent)
    //{
    //    if (nonActivityEvent == null) return new ScheduledActivity();

    // Timestamp startTime = Timestamp.FromDateTime(nonActivityEvent.StartTime.ToUniversalTime());
    // Timestamp endTime = Timestamp.FromDateTime(nonActivityEvent.EndTime.ToUniversalTime());

    //    return new NonActivityEvents
    //    {
    //        ID = nonActivityEvent.ID,
    //        EventName = nonActivityEvent.EventName,
    //        StartTime = startTime,
    //        EndTime = endTime,
    //        TeamId = nonActivityEvent.TeamId,
    //        MemberId = nonActivityEvent.MemberId
    //    };
    //}

    public static EF.Types.ScheduledActivity ConvertCoreScheduledActivityoEFScheduledActivity(ScheduledActivity activity)
    {
        if (activity == null) return new EF.Types.ScheduledActivity();

        return new EF.Types.ScheduledActivity
        {
            UserId = activity.UserId,
            StartDate = activity.StartDate.ToDateTime(),
            EndDate = activity.EndDate.ToDateTime(),
            Title = activity.Title,
            JobNumber = activity.JobNumber,
            Note = activity.Note
        };
    }

    public static ScheduledActivity ConvertEFScheduledActivtyToCoreScheduledActivity(EF.Types.ScheduledActivity activity)
    {
        if (activity == null) return new ScheduledActivity();

        return new ScheduledActivity
        {
            UserId = activity.UserId,
            StartDate = Timestamp.FromDateTime(DateTime.SpecifyKind(activity.StartDate, DateTimeKind.Utc)),
            EndDate = Timestamp.FromDateTime(DateTime.SpecifyKind(activity.EndDate, DateTimeKind.Utc)),
            Title = activity.Title,
            JobNumber = activity.JobNumber,
            Note = activity.Note
        };
    }

    public static OrganisationalUnitForUser ConvertEFOrganisationalUnitForUserToCoreOrganisationalUnitForUser(EF.Types.OrganisationUnitForUser orgUnit)
    {
        if (orgUnit == null) return new OrganisationalUnitForUser();

        var orgUnitForUser = new OrganisationalUnitForUser
        {
            OrganisationUnitId = orgUnit.OrganisationUnitId
        };

        return orgUnitForUser;
    }

    #endregion Public Methods

    #region Internal Methods

    internal static EF.Types.User ConvertCoreUserToEfUser(User user)
    {
        return new EF.Types.User()
        {
            Guid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(user.Guid).ToString()),
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            FullName = user.FullName,
            JobTitle = user.JobTitle,
            BillableRate = (decimal?)user.BillableRate,
            MobileNo = user.MobileNo,
            OnHoliday = user.OnHoliday,
            UserId = user.UserId,
            Signature = user.Signature.ToByteArray() // Convert ByteString to byte[]
        };
    }

    internal static RepeatedField<DataObject> ConvertEfDataObjectListToCoreDataObjectList(List<EF.Types.DataObject> newDataObjects)
    {
        RepeatedField<DataObject> dataObjects = new();
        foreach (var dataObject in newDataObjects)
        {
            dataObjects.Add(ConvertEfDataObjectToCoreDataObject(dataObject));
        }
        return dataObjects;
    }

    internal static Core.MergeDocumentItem ConvertEfToCoreMergeDocumentItem(EF.Types.MergeDocumentItem efModel)
    {
        return new Core.MergeDocumentItem
        {
            Guid = efModel.Guid.ToString(),
            MergeDocumentItemType = efModel.MergeDocumentItemType,
            BookmarkName = efModel.BookmarkName,
            EntityType = efModel.EntityType,
            EntityTypeGuid = efModel.EntityTypeGuid.ToString(),
            LinkedEntityTypeGuid = efModel.LinkedEntityTypeGuid.ToString(),
            SubFolderPath = efModel.SubFolderPath,
            ImageColumns = efModel.ImageColumns ?? 0,
            RowStatus = efModel.RowStatus.ToString(),
            RowVersion = efModel.RowVersion
        };
    }

    internal static Core.MergeDocumentItemInclude ConvertEfToCoreMergeDocumentItemInclude(EF.Types.MergeDocumentItemInclude efModel)
    {
        return new Core.MergeDocumentItemInclude
        {
            Guid = efModel.Guid.ToString(),
            SortOrder = efModel.SortOrder,
            SourceDocumentEntityProperty = efModel.SourceDocumentEntityProperty,
            SourceSharepointItemEntityProperty = efModel.SourceSharePointItemEntityProperty,
            IncludedMergeDocument = efModel.IncludedMergeDocument,
            MergeDocumentItemGuid = efModel.MergeDocumentItemGuid.ToString(),
            RowStatus = efModel.RowStatus.ToString(),
            RowVersion = efModel.RowVersion
        };
    }

    internal static Core.MergeDocumentItemType ConvertEfToCoreMergeDocumentItemType(EF.Types.MergeDocumentItemType efModel)
    {
        return new Core.MergeDocumentItemType
        {
            Id = efModel.Id,
            Guid = efModel.Guid.ToString(),
            Name = efModel.Name,
            IsImageType = efModel.IsImageType,
            RowStatus = efModel.RowStatus.ToString(),
            RowVersion = efModel.RowVersion
        };
    }

    #endregion Internal Methods

    #region Private Methods

    private static ActionMenuItem ConvertCoreActionMenuItemToEfActionMenuItem(Core.ActionMenuItem dataObjectActionMenuItem)
    {
        if (dataObjectActionMenuItem == null) return new ActionMenuItem();
        return new ActionMenuItem()
        {
            EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectActionMenuItem.EntityQueryGuid),
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectActionMenuItem.EntityTypeGuid),
            IconCss = dataObjectActionMenuItem.IconCss,
            Label = dataObjectActionMenuItem.Label,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectActionMenuItem.Guid),
            Id = dataObjectActionMenuItem.Id,
            Type = dataObjectActionMenuItem.Type,
            SortOrder = dataObjectActionMenuItem.SortOrder,
            RedirectToTargetGuid = dataObjectActionMenuItem.RedirectToTargetGuid
        };
    }

    private static EF.Types.DataPill ConvertCoreDataPillToEfDataPill(DataPill dataObjectDataPill)
    {
        if (dataObjectDataPill == null) return new EF.Types.DataPill();
        return new EF.Types.DataPill()
        {
            Class = dataObjectDataPill.Class,
            SortOrder = dataObjectDataPill.SortOrder,
            Value = dataObjectDataPill.Value
        };
    }

    private static EF.Types.MergeDocument ConvertCoreMergeDocumentToEfMergeDocument(MergeDocument dataObjectMergeDocument)
    {
        if (dataObjectMergeDocument == null) return new EF.Types.MergeDocument();
        var MergeDocument = new EF.Types.MergeDocument()
        {
            DocumentId = dataObjectMergeDocument.DocumentId,
            DriveId = dataObjectMergeDocument.DriveId,
            EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectMergeDocument.EntityTypeGuid),
            FilenameTemplate = dataObjectMergeDocument.FilenameTemplate,
            Name = dataObjectMergeDocument.Name,
            Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectMergeDocument.Guid),
            Id = dataObjectMergeDocument.Id,
            LinkedEntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(dataObjectMergeDocument.LinkedEntityTypeGuid),
            AllowPDFOnly = dataObjectMergeDocument.AllowPDFOnly,
            AllowExcelOutputOnly = dataObjectMergeDocument.AllowExcelOutputOnly,
            ProduceOneOutputPerRow = dataObjectMergeDocument.ProduceOneOutputPerRow
        };
        foreach (var item in dataObjectMergeDocument.Items)
        {
            MergeDocument.Items.Add(ConvertCoreMergeDocumentItemToEfMergeDocumentItem(item));
        }
        return MergeDocument;
    }

    private static EF.Types.MergeDocumentItem ConvertCoreMergeDocumentItemToEfMergeDocumentItem(MergeDocumentItem item)
    {
        var MergeDocumentItem = new EF.Types.MergeDocumentItem()
        {
            Guid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(item.Guid).ToString()),
            BookmarkName = item.BookmarkName,
            MergeDocumentItemType = item.MergeDocumentItemType,
            EntityType = item.EntityType,
            EntityTypeGuid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(item.EntityTypeGuid).ToString()),
            LinkedEntityTypeGuid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(item.LinkedEntityTypeGuid).ToString()),
            SubFolderPath = item.SubFolderPath,
            ImageColumns = item.ImageColumns,
            RowVersion = item.RowVersion
        };
        foreach (var include in item.Includes)
        {
            MergeDocumentItem.Includes.Add(ConvertCoreMergeDocumentItemIncludeToEfMergeDocumentItemInclude(include));
        }
        return MergeDocumentItem;
    }

    private static EF.Types.MergeDocumentItemInclude ConvertCoreMergeDocumentItemIncludeToEfMergeDocumentItemInclude(MergeDocumentItemInclude include)
    {
        return new EF.Types.MergeDocumentItemInclude()
        {
            Guid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(include.Guid).ToString()),
            SortOrder = include.SortOrder,
            SourceDocumentEntityProperty = include.SourceDocumentEntityProperty,
            SourceSharePointItemEntityProperty = include.SourceSharepointItemEntityProperty,
            IncludedMergeDocument = include.IncludedMergeDocument
        };
    }

    private static EF.Types.ObjectSecurity ConvertCoreObjectSecurityToEfObjectSecurity(ObjectSecurity objectSecurity)
    {
        if (objectSecurity == null) return new EF.Types.ObjectSecurity();
        EF.Types.ObjectSecurity rsl = new()
        {
            Guid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.Guid).ToString()),
            CanRead = objectSecurity.CanRead,
            CanWrite = objectSecurity.CanWrite,
            GroupGuid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.GroupGuid).ToString()),
            ObjectGuid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.DataObjectGuid).ToString()),
            RowStatus = (RowStatus)objectSecurity.RowStatus,
            RowVersion = objectSecurity.RowVersion,
            UserGuid = new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(objectSecurity.UserGuid).ToString()),
            Id = objectSecurity.Id,
            UserIdentity = objectSecurity.UserIdentity ?? "",
            GroupIdentity = objectSecurity.GroupIdentity ?? ""
            //DefaultGroupIdentity = objectSecurity.DefaultGroupIdentity ?? ""
        };
        return rsl;
    }

    private static EF.Types.ValidationResult ConvertCoreValidationResultToEfValidationResult(ValidationResults validationResult)
    {
        if (validationResult == null) return new EF.Types.ValidationResult();
        return new EF.Types.ValidationResult()
        {
            TargetGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(validationResult.TargetGuid),
            TargetType = validationResult.TargetType,
            IsHidden = validationResult.IsHidden,
            IsInformationOnly = validationResult.IsInformationOnly,
            IsInvalid = validationResult.IsInvalid,
            IsReadOnly = validationResult.IsReadOnly,
            Message = validationResult.Message
        };
    }

    private static ValidationResults ConvertEfValidationResultToCoreValidationResult(EF.Types.ValidationResult validationResults)
    {
        return new ValidationResults()
        {
            IsHidden = validationResults.IsHidden,
            IsInformationOnly = validationResults.IsInformationOnly,
            IsInvalid = validationResults.IsInvalid,
            IsReadOnly = validationResults.IsReadOnly,
            Message = validationResults.Message,
            TargetGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(validationResults.TargetGuid.ToString()).ToString(),
            TargetType = validationResults.TargetType,
        };
    }

    #endregion Private Methods
}