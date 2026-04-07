SET IDENTITY_INSERT SCore.EntityQueries ON
GO
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000', N'', N'', -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (1, 1, '20c21419-0ffd-4ca3-ac2f-a58cfc782a97', N'Entities Read', N'SELECT root_hobt.ID,
  root_hobt.RowStatus,
  root_hobt.RowVersion,
  root_hobt.Guid,
  root_hobt.Name,
  root_hobt.DoNotTrackChanges,
  root_hobt.HasDocuments,
  root_hobt.IsReadOnlyOffline,
  root_hobt.IsRequiredSystemData,
  root_hobt.IsRootEntity,
  root_hobt.DetailPageUrl,
  root_hobt.IsMetaData,
  ll.Guid AS LanguageLabelID,
  i.guid AS IconId
FROM SCore.EntityTypes   AS root_hobt
JOIN SCore.LanguageLabels AS ll ON (root_hobt.LanguageLabelID = ll.ID)
JOIN SUserInterface.Icons i ON (root_hobt.IconId = i.ID)', 4, 4, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (4, 1, '2e4d8e19-f4ba-40a1-91ac-1bb5597d1675', N'[SCore].[EntityPropertyUpsert]', N'EXEC [SCore].[EntityPropertyUpsert]  
	@Name = @Name, 
	@RowStatus = @RowStatus, 
	@LanguageLabelGuid = @LanguageLabelGuid, 
	@EntityHobtGuid = @EntityHobtGuid, 
	@EntityDataTypeGuid = @EntityDataTypeGuid, 
	@IsReadOnly = @IsReadOnly, 
	@IsImmutable = @IsImmutable, 
	@IsUppercase = @IsUppercase, 
	@IsHidden = @IsHidden, 
	@IsCompulsory = @IsCompulsory, 
	@MaxLength = @MaxLength, 
	@Precision = @Precision, 
	@Scale = @Scale, 
	@DoNotTrackChanges = @DoNotTrackChanges, 
	@EntityPropertyGroupGuid = @EntityPropertyGroupGuid, 
	@SortOrder = @SortOrder, 
	@GroupSortOrder = @GroupSortOrder, 
	@IsObjectLabel = @IsObjectLabel, 
	@DropDownListDefinitionGuid = @DropDownListDefinitionGuid, 
	@IsParentRelationship = @IsParentRelationship, 
	@IsIncludedInformation = @IsIncludedInformation, 
	@IsLatitude = @IsLatitude, 
	@IsLongitude = @IsLongitude, 
	@FixDefaultValue = @FixDefaultValue, 
	@SqlDefaultValueStatement = @SqlDefaultValueStatement, 
	@AllowBulkChange = @AllowBulkChange, 
	@IsVirtual = @IsVirtual, 
	@Guid = @Guid,
        @ShowOnMobile = @ShowOnMobile,
        @IsAlwaysVisibleInGroup = @IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @IsAlwaysVisibleInGroup_Mobile', 6, 6, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityPropertyUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (5, 1, 'abc8fab8-ce33-4804-a437-e9e0a7126c7c', N'[SCore].[EntityTypeUpsert]', N'EXEC [SCore].[EntityTypeUpsert]  @Name = @Name, @RowStatus = @RowStatus, @IsReadOnlyOffline = @IsReadOnlyOffline, @IsRequiredSystemData = @IsRequiredSystemData, @HasDocuments = @HasDocuments, @LanguageLabelGuid = @LanguageLabelGuid, @DoNotTrackChanges = @DoNotTrackChanges, @IconGuid = @IconGuid, @IsRootEntity = @IsRootEntity, @DetailPageUrl = @DetailPageUrl, @IsMetaData = @IsMetaData, @Guid = @Guid', 4, 4, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityTypeUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (6, 1, '4e6d2935-2cc8-45a7-969f-08200b832209', N'Entity Queries Read', N'SELECT	root_hobt.ID,
		root_hobt.RowVersion,
		root_hobt.RowStatus,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Statement,
		root_hobt.IsDefaultCreate,
		root_hobt.IsDefaultDelete,
		root_hobt.IsDefaultRead,
		root_hobt.IsDefaultUpdate,
		root_hobt.IsScalarExecute,
		et.Guid	 AS EntityTypeID,
		root_hobt.IsDefaultValidation,
		eh.Guid	 AS EntityHoBTID,
        root_hobt.IsDefaultDataPills,
        root_hobt.IsMergeDocumentQuery,
        root_hobt.IsProgressData,
		root_hobt.SchemaName,
		root_hobt.ObjectName,
		root_hobt.IsManualStatement,
		root_hobt.UsesProcessGuid
FROM	SCore.EntityQueriesV AS root_hobt
JOIN	SCore.EntityTypesV	 AS et ON (et.ID = root_hobt.EntityTypeID)
JOIN	SCore.EntityHobtsV	 AS eh ON (eh.ID = root_hobt.EntityHoBTID)', 7, 7, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityQueries', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (7, 1, 'e8f8705d-14e5-4dd8-978c-f2746c3bdaae', N'Entity Properties Read', N'SELECT 
	root_hobt.AllowBulkChange,
	root_hobt.DoNotTrackChanges,
	[C44B8A2A-8C24-41F0-B85E-E163A4D8E555].Guid AS DropDownListDefinitionID,
	[59E622E7-EDA9-4DB3-A4D5-9439D80D26C1].Guid AS EntityDataTypeID,
	[77B88FCE-FCC3-4C92-94E6-CC61249845C3].Guid AS EntityHoBTID,
	[216CAEF2-7139-41F2-8C27-D5B9B4517B1A].Guid AS EntityPropertyGroupID,
	root_hobt.FixedDefaultValue,
	root_hobt.GroupSortOrder,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsCompulsory,
        root_hobt.ShowOnMobile,
	root_hobt.IsHidden,
	root_hobt.IsImmutable,
	root_hobt.IsIncludedInformation,
	root_hobt.IsLatitude,
	root_hobt.IsLongitude,
	root_hobt.IsObjectLabel,
	root_hobt.IsParentRelationship,
	root_hobt.IsReadOnly,
	root_hobt.IsUppercase,
	root_hobt.IsVirtual,
	[E1D97654-B776-4BB6-A913-3A5B2E250685].Guid AS LanguageLabelID,
	root_hobt.MaxLength,
	root_hobt.Name,
	root_hobt.Precision,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Scale,
	root_hobt.SortOrder,
	root_hobt.SqlDefaultValueStatement,
        root_hobt.IsAlwaysVisibleInGroup,
        root_hobt.IsAlwaysVisibleInGroup_Mobile
FROM SCore.EntityProperties AS root_hobt 
JOIN SCore.LanguageLabels AS [E1D97654-B776-4BB6-A913-3A5B2E250685] ON ([E1D97654-B776-4BB6-A913-3A5B2E250685].ID = root_hobt.LanguageLabelID) 
 JOIN SCore.EntityHobts AS [77B88FCE-FCC3-4C92-94E6-CC61249845C3] ON ([77B88FCE-FCC3-4C92-94E6-CC61249845C3].ID = root_hobt.EntityHoBTID) 
 JOIN SCore.EntityDataTypes AS [59E622E7-EDA9-4DB3-A4D5-9439D80D26C1] ON ([59E622E7-EDA9-4DB3-A4D5-9439D80D26C1].ID = root_hobt.EntityDataTypeID) 
 JOIN SCore.EntityPropertyGroups AS [216CAEF2-7139-41F2-8C27-D5B9B4517B1A] ON ([216CAEF2-7139-41F2-8C27-D5B9B4517B1A].ID = root_hobt.EntityPropertyGroupID) 
 JOIN SUserInterface.DropDownListDefinitions AS [C44B8A2A-8C24-41F0-B85E-E163A4D8E555] ON ([C44B8A2A-8C24-41F0-B85E-E163A4D8E555].ID = root_hobt.DropDownListDefinitionID) 
', 6, 6, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityProperties', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (9, 1, '365000b9-6eac-41b1-b687-cd3af288b091', N'Entity HoBTs', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.SchemaName,
		root_hobt.ObjectName,
		et.Guid	 AS EntityTypeID,
		root_hobt.ObjectType,
		root_hobt.IsMainHoBT,
		root_hobt.IsReadOnlyOffline
FROM	SCore.EntityHobtsV AS root_hobt
JOIN	SCore.EntityTypesV AS et ON (et.ID = root_hobt.EntityTypeID)', 5, 5, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (10, 1, '47b69375-a632-4c9f-aeee-99acbb973294', N'[SCore].[EntityQueryUpsert]', N'EXEC [SCore].[EntityQueryUpsert ]  @Name = @Name, @RowStatus = @RowStatus, @Statement = @Statement, @EntityTypeGuid = @EntityTypeGuid, @IsDefaultCreate = @IsDefaultCreate, @IsDefaultRead = @IsDefaultRead, @IsDefaultUpdate = @IsDefaultUpdate, @IsDefaultDelete = @IsDefaultDelete, @IsScalarExecute = @IsScalarExecute, @IsDefaultValidation = @IsDefaultValidation, @EntityHoBTGuid = @EntityHoBTGuid, @IsDefaultDataPills = @IsDefaultDataPills, @IsMergeDocumentQuery = @IsMergeDocumentQuery, @IsProgressData = @IsProgressData, @SchemaName = @SchemaName, @ObjectName = @ObjectName, @IsManualStatement = @IsManualStatement, @Guid = @Guid', 7, 7, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityQueryUpsert ', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (11, 1, '7e7d7350-d2ec-4618-bdb5-d876fcdb324c', N'[SCore].[EntityQueryParameterUpsert]', N'EXEC [SCore].[EntityQueryParameterUpsert]  @Name = @Name, @RowStatus = @RowStatus, @EntityQueryGuid = @EntityQueryGuid, @EntityDataTypeGuid = @EntityDataTypeGuid, @MappedEntityPropertyGuid = @MappedEntityPropertyGuid, @DefaultValue = @DefaultValue, @IsInput = @IsInput, @IsOutput = @IsOutput, @IsReturnColumn = @IsReturnColumn, @Guid = @Guid', 8, 8, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (12, 1, '519f7dad-b8d1-470c-be0b-c4031600a7c9', N'Entity Query Parameters Read', N'SELECT  root_hobt.ID,
        root_hobt.Guid,
        root_hobt.IsInput,
        root_hobt.IsOutput,
        root_hobt.IsReturnColumn,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Name,
        root_hobt.DefaultValue,
        eq.Guid as EntityQueryID, 
        ep.Guid as MappedEntityPropertyID,
        edt.Guid as EntityDataTypeID
FROM    SCore.EntityQueryParameters root_hobt
JOIN    SCore.EntityQueries eq on (eq.ID = root_hobt.EntityQueryID)
JOIN    SCore.EntityProperties ep on (ep.ID = root_hobt.MappedEntityPropertyID)
JOIN    SCore.EntityDataTypes edt on (edt.ID = root_hobt.EntityDataTypeID)', 8, 8, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (13, 1, 'a00b0d17-f554-4fcb-bd86-77079b6ea2cc', N'Grid Definitions Read', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Code,
        root_hobt.PageUri,
        root_hobt.TabName,
        root_hobt.ShowAsTiles,
        ll.Guid AS LanguageLabelId
FROM
        SUserInterface.GridDefinitions root_hobt
JOIN
        SCore.LanguageLabels ll ON (root_hobt.LanguageLabelId = ll.ID)', 11, 11, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (14, 1, 'feded95a-b1e2-420e-923d-07ea2fd33f91', N'Drop Down List Definition Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid, 
		root_hobt.Code, 
		root_hobt.NameColumn,
		root_hobt.ValueColumn,
		root_hobt.SqlQuery,
		root_hobt.DefaultSortColumnName, 
		root_hobt.IsDefaultColumn,
		root_hobt.DetailPageUrl,
		root_hobt.IsDetailWindowed,
        root_hobt.InformationPageUrl, 
        root_hobt.GroupColumn,
        root_hobt.ColourHexColumn,
        root_hobt.ExternalSearchPageUrl,
	et.Guid as EntityTypeId
FROM	SUserInterface.DropDownListDefinitions root_hobt
JOIN	SCore.EntityTypes et ON (et.ID = root_hobt.EntityTypeId)', 10, 10, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (16, 1, '4e5648a1-f913-44b2-8cfa-da43e50c5f62', N'Grid View Definitions Read', N'SELECT
        root_hobt.ID,
        root_hobt.Guid,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Code,
        gd.Guid AS GridDefinitionId,
        root_hobt.DetailPageUri,
        root_hobt.SqlQuery,
        root_hobt.DefaultSortColumnName,
        root_hobt.SecurableCode,
        root_hobt.DisplayOrder,
        root_hobt.DisplayGroupName,
        root_hobt.MetricSqlQuery,
        root_hobt.ShowMetric,
        root_hobt.IsDetailWindowed,
        et.Guid AS EntityTypeID,
        mt.Guid AS MetricTypeID,
        root_hobt.MetricMin,
        root_hobt.MetricMax,
        root_hobt.MetricMinorUnit,
        root_hobt.MetricMajorUnit,
        root_hobt.MetricStartAngle,
        root_hobt.MetricEndAngle,
        root_hobt.MetricReversed,
        root_hobt.MetricRange1Min,
        root_hobt.MetricRange1Max,
        root_hobt.MetricRange1ColourHex,
        root_hobt.MetricRange2Min,
        root_hobt.MetricRange2Max,
        root_hobt.MetricRange2ColourHex,
        root_hobt.IsDefaultSortDescending,
        root_hobt.AllowBulkChange,
        root_hobt.AllowNew,
        root_hobt.AllowExcelExport,
        root_hobt.AllowPdfExport,
        root_hobt.AllowCsvExport,
        ll.Guid AS LanguageLabelID,
        i.Guid AS DrawerIconId,
		gvt.Guid AS GridViewTypeId,
        root_hobt.ShowOnMobile,
		root_hobt.TreeListFirstOrderBy,
		root_hobt.TreeListSecondOrderBy,
		root_hobt.TreeListThirdOrderBy,
		root_hobt.TreeListOrderBy,
		root_hobt.TreeListGroupBy,
        root_hobt.ShowOnDashboard,
		root_hobt.FilteredListCreatedOnColumn,
		root_hobt.FilteredListRedStatusIndicatorTxt,
		root_hobt.FilteredListOrangeStatusIndicatorTxt,
		root_hobt.FilteredListGreenStatusIndicatorTxt,
		root_hobt.FilteredListGroupBy
FROM
        SUserInterface.GridViewDefinitions AS root_hobt
JOIN
        SCore.EntityTypes AS et ON (et.ID = root_hobt.EntityTypeID)
JOIN	
		SUserInterface.GridViewTypes gvt ON (gvt.ID = root_hobt.GridViewTypeId)
JOIN
        SUserInterface.MetricTypes AS mt ON (mt.ID = root_hobt.MetricTypeID)
JOIN
        SUserInterface.GridDefinitions AS gd ON (gd.ID = root_hobt.GridDefinitionId)
JOIN
        SCore.LanguageLabels ll ON (root_hobt.LanguageLabelID = ll.ID)
JOIN
        SUserInterface.Icons i ON (root_hobt.DrawerIconId = i.ID)', 12, 12, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'GridViewDefinitions', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (17, 1, '9a2c13dc-1ad1-47a0-85fd-83e35527d04f', N'Grid View Column Definition Read', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Name,
        root_hobt.ColumnOrder,
        root_hobt.IsPrimaryKey,
        root_hobt.IsHidden,
        root_hobt.IsFiltered,
        root_hobt.IsCombo,
        root_hobt.IsLongitude,
        root_hobt.IsLatitude,
        root_hobt.DisplayFormat,
        root_hobt.Width,
        ll.Guid AS LanguageLabelId,
        gvd.Guid AS GridViewDefinitionId,
        root_hobt.TopHeaderCategory,
       root_hobt.TopHeaderCategoryOrder
FROM
        SUserInterface.GridViewColumnDefinitions root_hobt
JOIN
        SUserInterface.GridViewDefinitions gvd ON (gvd.ID = root_hobt.GridViewDefinitionId) 
JOIN    SCore.LanguageLabels ll on (root_hobt.LanguageLabelId = ll.ID)', 13, 13, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (19, 1, 'd5f28838-2c0b-416c-9d53-76e51fe476e9', N'GridViewDefinitionUpsert', N'EXEC [SUserInterface].[GridViewDefinitionUpsert]  
	@Code = @Code, 
	@RowStatus = @RowStatus, 
	@GridDefinitionGuid = @GridDefinitionGuid, 
	@DetailPageUri = @DetailPageUri, 
	@SqlQuery = @SqlQuery, 
	@DefaultSortColumnName = @DefaultSortColumnName, 
	@SecurableCode = @SecurableCode, 
	@DisplayOrder = @DisplayOrder, 
	@DisplayGroupName = @DisplayGroupName, 
	@MetricSqlQuery = @MetricSqlQuery, 
	@ShowMetric = @ShowMetric, 
	@IsDetailWindowed = @IsDetailWindowed, 
	@EntityTypeGuid = @EntityTypeGuid, 
	@MetricTypeGuid = @MetricTypeGuid, 
	@MetricMin = @MetricMin, 
	@MetricMax = @MetricMax, 
	@MetricMinorUnit = @MetricMinorUnit, 
	@MetricMajorUnit = @MetricMajorUnit, 
	@MetricStartAngle = @MetricStartAngle, 
	@MetricEndAngle = @MetricEndAngle, 
	@MetricReversed = @MetricReversed, 
	@MetricRange1Min = @MetricRange1Min, 
	@MetricRange1Max = @MetricRange1Max, 
	@MetricRange1ColourHex = @MetricRange1ColourHex, 
	@MetricRange2Min = @MetricRange2Min, 
	@MetricRange2Max = @MetricRange2Max, 
	@MetricRange2ColourHex = @MetricRange2ColourHex, 
	@IsDefaultSortDescending = @IsDefaultSortDescending, 
	@AllowNew = @AllowNew, 
	@AllowExcelExport = @AllowExcelExport, 
	@AllowPdfExport = @AllowPdfExport, 
	@AllowCsvExport = @AllowCsvExport, 
	@LanguageLabelGuid = @LanguageLabelGuid, 
	@DrawerIconGuid = @DrawerIconGuid, 
	@GridViewTypeGuid = @GridViewTypeGuid, 
	@AllowBulkChange = @AllowBulkChange, 
	@Guid = @Guid,
        @ShowOnMobile = @ShowOnMobile,
	@TreeListFirstOrderBy = @TreeListFirstOrderBy,
	@TreeListSecondOrderBy = @TreeListSecondOrderBy,
	@TreeListThirdOrderBy = @TreeListThirdOrderBy,
	@TreeListOrderBy = @TreeListOrderBy,
	@TreeListGroupBy = @TreeListGroupBy,
        @ShowOnDashboard = @ShowOnDashboard,
@FilteredListCreatedOnColumn = 	@FilteredListCreatedOnColumn,
@FilteredListRedStatusIndicatorTxt = @FilteredListRedStatusIndicatorTxt,		
@FilteredListOrangeStatusIndicatorTxt	= @FilteredListOrangeStatusIndicatorTxt,
@FilteredListGreenStatusIndicatorTxt = @FilteredListGreenStatusIndicatorTxt,
@FilteredListGroupBy = @FilteredListGroupBy
', 12, 12, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'GridViewDefinitionUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (20, 1, 'b98c8bde-30c9-408d-b7a2-e5482849f74d', N'[SUserInterface].[GridViewColumnDefinitionUpsert]', N'EXEC [SUserInterface].[GridViewColumnDefinitionUpsert]
  @Name                   = @Name,
  @RowStatus              = @RowStatus,
  @GridViewDefinitionGuid = @GridViewDefinitionGuid,
  @ColumnOrder            = @ColumnOrder,
  @IsPrimaryKey           = @IsPrimaryKey,
  @IsHidden               = @IsHidden,
  @IsFiltered             = @IsFiltered,
  @IsCombo                = @IsCombo,
  @DisplayFormat          = @DisplayFormat,
  @Width                  = @Width,
  @LanguageLabelGuid      = @LanguageLabelGuid,
  @Guid                   = @Guid,
 @TopHeaderCategory = @TopHeaderCategory,
@TopHeaderCategoryOrder = @TopHeaderCategoryOrder', 13, 13, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (21, 1, '9fdfa849-971b-4014-9c46-3a73b8143cf6', N'[SUserInterface].[DropDownListDefinitionUpsert]', N'EXEC SUserInterface.DropDownListDefinitionUpsert @Code = @Code,
												 @NameColumn = @NameColumn,
												 @ValueColumn = @ValueColumn,
												 @SqlQuery = @SqlQuery,
												 @DefaultSortColumnName = @DefaultSortColumnName,
												 @IsDefaultColumn = @IsDefaultColumn,
												 @DetailPageURI = @DetailPageURI,
												 @IsDetailWindowed = @IsDetailWindowed, 
												 @EntityTypeGuid = @EntityTypeGuid,
 												 @InformationPageUri = @InformationPageUri,  
                                                                                                 @GroupColumn = @GroupColumn,
												 @Guid = @Guid,
                                                                                                 @ColourHexColumn = @ColourHexColumn,
                                                                                                  @ExternalSearchPageUrl = @ExternalSearchPageLink;', 10, 10, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'DropDownListDefinitions', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (22, 1, 'fa4b0028-755a-4635-b058-32623c3afa0c', N'Assets Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.AssetNumber,
		root_hobt.Name,
		root_hobt.Number,
		root_hobt.AddressLine1,
		root_hobt.AddressLine2,
		root_hobt.AddressLine3,
		root_hobt.Town,
		root_hobt.Postcode,
		root_hobt.FormattedAddressComma,
		root_hobt.FormattedAddressCR,
		root_hobt.Longitude,
		root_hobt.Latitude,
		root_hobt.IsHighRiskBuilding,
		root_hobt.IsComplexBuilding,
		root_hobt.CreatedDate,
		root_hobt.BuildingHeightInMetres,
		root_hobt.ListLabel,
                root_hobt.GovernmentUPRN,
		wa.Guid AS WaterAuthorityAccountID,
		fa.Guid AS FireAuthorityAccountID,
		la.Guid AS LocalAuthorityAccountID,
		oa.Guid AS OwnerAccountId,
		p.Guid AS ParentAssetID,
		c.Guid AS CountyID,
		cr.Guid AS CountryID
FROM	SJob.Assets root_hobt
JOIN	SCrm.Accounts wa ON (wa.ID = root_hobt.WaterAuthorityAccountID)
JOIN	SCrm.Accounts fa ON (fa.ID = root_hobt.FireAuthorityAccountID)
JOIN	SCrm.Accounts la ON (la.ID = root_hobt.LocalAuthorityAccountID)
JOIN	SCrm.Accounts oa ON (oa.ID = root_hobt.OwnerAccountId)
JOIN	SJob.Assets p ON (p.ID = root_hobt.ParentAssetID)
JOIN	SCrm.Counties c ON (c.ID = root_hobt.CountyId)
JOIN	SCrm.Countries cr ON (cr.ID = root_hobt.CountryID) ', 27, 22, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (23, 1, '7d3ce5a9-46bd-4c3e-9d84-1413012f8f8c', N'Entity Property Groups Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Name, 
        root_hobt.IsHidden,
        root_hobt.SortOrder,
		pgl.Guid AS PropertyGroupLayoutID,
        ll.Guid as LanguageLabelID,
        et.Guid as EntityTypeID,
        ShowOnMobile,
        IsCollapsable,
        IsDefaultCollapsed,
        IsDefaultCollapsed_Mobile
FROM    SCore.EntityPropertyGroups root_hobt
JOIN	SUserInterface.PropertyGroupLayouts pgl ON (pgl.ID = root_hobt.PropertyGroupLayoutID)
JOIN    SCore.LanguageLabels ll on (ll.ID = root_hobt.LanguageLabelID)
JOIN    SCore.EntityTypes et on (et.ID = root_hobt.EntityTypeID)', 14, 14, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (24, 1, '8e984089-7598-410e-b91d-433ee4efdf88', N'Entity Property Groups Upsert', N'EXEC [SCore].[EntityPropertyGroupUpsert]
    @Name = @Name,
    @RowStatus = @RowStatus,
    @IsHidden = @IsHidden,
    @SortOrder = @SortOrder,
    @LanguageLabelGuid = @LanguageLabelGuid,
    @EntityTypeGuid = @EntityTypeGuid,
     @PropertyGroupLayoutGuid= @PropertyGroupLayoutGuid,
    @ShowOnMobile = @ShowOnMobile,
    @IsCollapsable = @IsCollapsable,
    @IsDefaultCollapsed = @IsDefaultCollapsed,
    @IsDefaultCollapsed_Mobile = @IsDefaultCollapsed_Mobile,
    @Guid = @Guid OUT
     ', 14, 14, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (25, 1, '98e14e7a-1819-4cfb-ac88-55ee5c04f2c0', N'Grid Definition Upsert', N'EXEC [SUserInterface].[GridDefinitionUpsert]
  @Code              = @Code,
  @LanguageLabelGuid = @LanguageLabelGuid,
  @RowStatus         = @RowStatus,
  @TabName           = @TabName,
  @ShowAsTiles       = @ShowAsTiles,
  @PageUri           = @PageUri,
  @Guid              = @Guid OUT', 11, 11, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (26, 1, '1b1092e2-b4fe-4d6e-85e2-4310c28d67b1', N'Shore Jobs Validation', N'SELECT * FROM [SJob].[Jobs_ShoreExtValidate] (
    @Guid, @JobTypeGuid )', 9, 27, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (30, 1, 'a29deace-3166-451c-a1ec-0ddf84d0dfa0', N'Jobs Read', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.AgreedFee,
        root_hobt.RibaStage1Fee,
        root_hobt.RibaStage2Fee,
        root_hobt.RibaStage3Fee,
        root_hobt.RibaStage4Fee,
        root_hobt.RibaStage5Fee,
        root_hobt.RibaStage6Fee,
        root_hobt.RibaStage7Fee,
        root_hobt.PreConstructionStageFee,
        root_hobt.ConstructionStageFee,
        root_hobt.ArchiveBoxReference,
        root_hobt.ArchiveReferenceLink,
        root_hobt.CreatedOn,
        root_hobt.ExternalReference,
        root_hobt.IsSubjectToNDA,
        root_hobt.JobCancelled,
        root_hobt.JobCompleted,
        root_hobt.JobDescription,
        root_hobt.JobStarted,
		root_hobt.DeadDate,
        root_hobt.Number,
        root_hobt.VersionID,
        root_hobt.IsCompleteForReview,
        root_hobt.ReviewedDateTimeUTC,
        root_hobt.LegacyID,
        root_hobt.AppFormReceived,
        root_hobt.FeeCap,
        root_hobt.JobDormant,
        root_hobt.CurrentRibaStageId,
        root_hobt.JobTypeID,
        root_hobt.SurveyorID,
        root_hobt.CreatedByUserID,
        root_hobt.ClientAccountID,
        root_hobt.ClientAddressID,
        root_hobt.ClientContactID,
        root_hobt.AgentAccountID,
        root_hobt.AgentAddressID,
        root_hobt.AgentContactID,
        root_hobt.FinanceAccountID,
        root_hobt.FinanceAddressID,
        root_hobt.FinanceContactID,
        root_hobt.OrganisationalUnitID,
        root_hobt.QuoteItemID,
        root_hobt.UprnID,
        root_hobt.ValueOfWorkID,
        root_hobt.ReviewedByUserID,
        root_hobt.ContractID,
        root_hobt.PurchaseOrderNumber,
        root_hobt.ProjectId,
        root_hobt.ValueOfWork,
        root_hobt.ClientAppointmentReceived,
	root_hobt.AppointedFromStageId,
        root_hobt.BillingInstruction,
        root_hobt.CannotBeInvoiced,
	root_hobt.CannotBeInvoicedReason,
        root_hobt.AgentContractID,
        root_hobt.CompletedForReviewDate,
        root_hobt.SectorId,
        root_hobt.MarketId
FROM
        SJob.Jobs_Read AS root_hobt', 9, 9, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'Jobs', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (32, 1, '666525ce-54d8-4a94-bdbf-0ca324906b75', N'Shore Jobs Read', N'SELECT		root_hobt.ID,
			root_hobt.RowStatus,
			root_hobt.RowVersion,
			root_hobt.Guid,
			sj.IAID,
			sj.Date,
			sj.DateRec,
			sj.FeeDate,
			sj.AgreementSent,
			sj.AgreementReceived,
			sj.InvoiceText,
			sj.OffList
FROM		SJob.Jobs		   AS root_hobt
LEFT JOIN	SJob.Jobs_ShoreExt AS sj ON (sj.ID = root_hobt.ID)

', 9, 27, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (33, 1, '9e997a1b-eeec-40d8-820d-a30b0fd02286', N'Activity Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Date,
		root_hobt.EndDate,
		root_hobt.Notes,
		root_hobt.Title,
		cu.Guid	 AS CreatedByUserID,
		uu.Guid	 AS LastUpdatedByUserID,
		j.Guid	 AS JobID,
		root_hobt.InvoicingQuantity,
root_hobt.InvoicingValue,
		root_hobt.VersionID,
		root_hobt.ExchangeId,
		root_hobt.LegacyID,
		root_hobt.IsAdditionalWork,
		m.Guid	 AS MileStoneID,
		s.Guid	 AS ActivityStatusID,
		t.Guid	 AS ActivityTypeID,
		i.Guid	 AS SurveyorID,
		rs.Guid	 AS RibaStageID,
		root_hobt.NewExpiryDate
FROM	SJob.Activities		AS root_hobt
JOIN	SJob.ActivityStatus AS s ON (s.ID	= root_hobt.ActivityStatusID)
JOIN	SJob.ActivityTypes	AS t ON (t.ID	= root_hobt.ActivityTypeID)
JOIN	SCore.Identities	AS i ON (i.ID	= root_hobt.SurveyorID)
JOIN	SCore.Identities	AS cu ON (cu.ID = root_hobt.CreatedByUserID)
JOIN	SCore.Identities	AS uu ON (uu.ID = root_hobt.LastUpdatedByUserID)
JOIN	SJob.Milestones		AS m ON (m.ID	= root_hobt.MilestoneID)
JOIN	SJob.Jobs			AS j ON (j.ID	= root_hobt.JobID)
JOIN	SJob.RibaStages		AS rs ON (rs.ID = root_hobt.RibaStageId)', 30, 25, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (34, 1, '2149afc2-38c9-4080-9e6d-97b87571703e', N'Activity Upsert', N'EXEC [SJob].[ActivitiesUpsert]  @JobGuid = @JobGuid, @SurveyorGuid = @SurveyorGuid, @Date = @Date, @EndDate = @EndDate, @ActivityTypeGuid = @ActivityTypeGuid, @ActivityStatusGuid = @ActivityStatusGuid, @Title = @Title, @Notes = @Notes, @EditedByUserGuid = @EditedByUserGuid, @IsAdditionalWork = @IsAdditionalWork, @RibaStageGuid = @RibaStageGuid, @MilestoneGuid = @MilestoneGuid, @InvoicingQuantity = @InvoicingQuantity, @InvoicingValue = @InvoicingValue, @Guid = @Guid, @NewExpiryDate = @NewExpiryDate', 30, 25, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActivitiesUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (35, 1, '525ee1de-5248-4e7e-bc84-25abaf7673e3', N'Jobs Progress', N'SELECT * FROM  [SJob].[JobMilestoneMetric] root_hobt
WHERE (root_hobt.[Guid] = @Guid)', 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobMilestoneMetric', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (36, 1, 'cfda039f-af78-4740-9540-ba86deeae28c', N'Project Directory Roles Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SJob.ProjectDirectoryRoles root_hobt ', 36, 32, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (37, 1, '7e4e18af-fd8f-402e-8ca7-f9d9ea35a6d9', N'Entity Query Validation', N'SELECT * FROM [SCore].[EntityQueriesValidate] ( @Guid, @IsDefaultRead, @Statement, @IsManualStatement) root_hobt', 7, 7, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SCore', N'EntityQueriesValidate', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (38, 1, 'd8bb9d92-d489-4635-925c-35d551dbe000', N'Job Pills', N'SELECT * FROM [SJob].[tvf_Jobs_DataPills] ( @Guid, @AppFormReceived, @ClientAppointmentReceived, @ClientAccountGuid, @AgentAccountGuid, @FinanceAccountGuid, @JobCompleted, @JobCancelled, @JobDormant, @JobStarted, @OrganisationalUnitGuid, @IsNDA, @JobTypeGuid, @CannotBeInvoiced, @CannotBeInvoicedReason, @ContractGuid, @AgentContractGuid, @ProjectGuid) root_hobt', 9, 9, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SJob', N'tvf_Jobs_DataPills', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (39, 1, '3fa662ce-d41f-4f68-affe-6123d85503c3', N'Accounts Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Code,
		root_hobt.IsPurchaseLedger,
		root_hobt.IsSalesLedger,
		root_hobt.IsLocalAuthority,
		root_hobt.IsFireAuthority,
		root_hobt.IsWaterAuthority,
		root_hobt.CompanyRegistrationNumber,
		root_hobt.LegacyID,
		s.Guid	AS AccountStatusID,
		pa.Guid AS ParentAccountID,
		rmi.Guid AS RelationshipManagerUserId,
		ac.Guid AS MainAccountContactId,
		aa.Guid AS MainAccountAddressId,
        root_hobt.BillingInstruction,
		root_hobt.ConcatenatedNameCode
FROM	SCrm.Accounts	   AS root_hobt
JOIN	SCrm.AccountStatus AS s ON (s.ID   = root_hobt.AccountStatusID)
JOIN	SCrm.Accounts	   AS pa ON (pa.ID = root_hobt.ParentAccountID)
JOIN	Score.Identities AS rmi ON (rmi.ID = root_hobt.RelationshipManagerUserId)
JOIN	SCrm.AccountContacts ac ON (ac.ID = root_hobt.MainAccountContactId)
JOIN	SCrm.AccountAddresses aa ON (aa.ID = root_hobt.MainAccountAddressId)', 15, 15, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (40, 1, '87603db1-4921-4fd2-b251-df9592e0215b', N'Addresses Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.AddressNumber,
		root_hobt.Name,
		root_hobt.Number,
		root_hobt.AddressLine1,
		root_hobt.AddressLine2,
		root_hobt.AddressLine3,
		root_hobt.Town,
		root_hobt.Postcode,
		root_hobt.FormattedAddressCR,
		root_hobt.FormattedAddressComma,
		root_hobt.LegacyID,
		c1.Guid AS CountyID,
		c2.Guid AS CountryID 
FROM	SCrm.Addresses AS root_hobt
JOIN	SCrm.Counties  AS c1 ON (c1.ID = root_hobt.CountyID)
JOIN	SCrm.Countries AS c2 ON (c2.ID = root_hobt.CountryID)', 18, 16, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (41, 1, 'b81979ac-bb8c-4f2f-b422-7999f4d4d150', N'Contacts Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.FirstName,
		root_hobt.Surname,
		root_hobt.DisplayName,
		root_hobt.IsPerson,
		root_hobt.Initials,
		root_hobt.LegacyID,
		root_hobt.PostNominals,
		pa.Guid	  AS PrimaryAccountID,
		padd.Guid AS PrimaryAddressID,
		ct.Guid	  AS TitleId,
		cp.Guid	  AS PositionID
FROM	SCrm.Contacts		  AS root_hobt
JOIN	SCrm.Accounts		  AS pa ON (pa.ID	  = root_hobt.PrimaryAccountID)
JOIN	SCrm.Addresses		  AS padd ON (padd.ID = root_hobt.PrimaryAddressID)
JOIN	SCrm.ContactTitles	  AS ct ON (ct.ID	  = root_hobt.TitleId)
JOIN	SCrm.ContactPositions AS cp ON (cp.ID	  = root_hobt.PositionID)', 25, 20, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (42, 1, '29ff1609-6f09-40b1-a56a-7c0b684cc69b', N'Assets Upsert', N'EXEC [SJob].[AssetsUpsert]  
	@ParentAssetGuid = @ParentAssetGuid, 
	@Name = @Name, 
	@Number = @Number, 
	@AddressLine1 = @AddressLine1, 
	@AddressLine2 = @AddressLine2, 
	@AddressLine3 = @AddressLine3, 
	@Town = @Town, 
	@CountyGuid = @CountyGuid, 
	@Postcode = @Postcode, 
	@CountryGuid = @CountryGuid, 
	@LocalAuthorityAccountGuid = @LocalAuthorityAccountGuid, 
	@FireAuthorityAccountGuid = @FireAuthorityAccountGuid, 
	@WaterAuthorityAccountGuid = @WaterAuthorityAccountGuid, 
	@Latitude = @Latitude, 
	@Longitude = @Longitude, 
	@IsHighRiskBuilding = @IsHighRiskBuilding, 
	@IsComplexBuilding = @IsComplexBuilding, 
	@BuildingHeightInMetres = @BuildingHeightInMetres, 
	@OwnerAccountGuid = @OwnerAccountGuid, 
	@Guid = @Guid,
        @GovernmentUPRN = @GovernmentUPRN', 27, 22, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'AssetsUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (43, 1, 'b2eb99a2-3c4c-456b-b3af-9ef437691943', N'Language Labels Read', N'SELECT * FROM SCore.LanguageLabels root_hobt', 2, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (44, 1, '47883e33-5001-453d-adcc-37084b8a9f3e', N'Lange Label Translations Read', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Text,
        root_hobt.TextPlural,
        root_hobt.HelpText,
        l.Guid  AS LanguageID,
        ll.Guid AS LanguageLabelID
FROM
        SCore.LanguageLabelTranslations root_hobt
JOIN
        SCore.Languages l ON (l.ID = root_hobt.LanguageID)
JOIN
        SCore.LanguageLabels ll ON (ll.ID = root_hobt.LanguageLabelID)', 3, 3, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (45, 1, '2b1131eb-a9e7-49f5-84ad-97e2c0c91014', N'Accounts Upsert', N'EXEC SCrm.AccountsUpsert @Name = @Name,							-- nvarchar(250)
						 @Code = @Code,							-- nvarchar(10)
						 @AccountStatusGuid = @AccountStatusGuid,				-- uniqueidentifier
						 @ParentAccountGuid = @ParentAccountGuid,				-- uniqueidentifier
						 @IsPurchaseLedger = @IsPurchaseLedger,				-- bit
						 @IsSalesLedger = @IsSalesLedger,					-- bit
						 @IsLocalAuthority = @IsLocalAuthority,				-- bit
						 @IsFireAuthority = @IsFireAuthority,				-- bit
						 @IsWaterAuthority = @IsWaterAuthority,				-- bit
						 @RelationshipManagerUserGuid = @RelationshipManagerUserGuid,	-- uniqueidentifier
						 @CompanyRegistrationNumber = @CompanyRegistrationNumber,		-- nvarchar(50)
						 @MainAccountAddressGuid = @MainAccountAddressGuid,
						 @MainAccountContactGuid = @MainAccountContactGuid,
						 @Guid = @Guid,							-- uniqueidentifier 
                                                  @BillingInstruction = @BillingInstruction', 15, 15, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (46, 1, '8e42949b-244a-472f-90d4-9431f45ff813', N'Language Labels Upsert', N'EXEC SCore.LanguageLabelUpsert @Name = @Name,			
							   @Guid = @Guid OUT', 2, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (47, 1, 'c573431e-057c-4c1c-8af9-0bf6660103f1', N'Language Translation Upsert', N'EXEC [SCore].[LanguageLabelTranslationUpsert]
  @Text              = @Text,
  @TextPlural        = @TextPlural,
  @HelpText          = @HelpText,
  @LanguageLabelGuid = @LanguageLabelGuid,
  @LanguageGuid      = @LanguageGuid,
  @Guid              = @Guid OUT', 3, 3, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (48, 1, 'adcad963-2814-49ea-a2b8-ebb96acfcee0', N'Account Addresses Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		a.guid AS AddressID,
		acc.Guid AS AccountID
FROM	SCrm.AccountAddresses root_hobt
JOIN	SCrm.Addresses a ON (a.ID = root_hobt.AddressID)
JOIN	SCrm.Accounts acc ON (acc.ID = root_hobt.AccountID)', 16, 35, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (49, 1, 'e7f5d451-41be-4db3-a161-a77064d6da62', N'Milestone Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Description,
		root_hobt.StartDateTimeUTC,
		root_hobt.DueDateTimeUTC,
		root_hobt.ScheduledDateTimeUTC,
		root_hobt.CompletedDateTimeUTC,
		root_hobt.QuotedHours,
		root_hobt.IsComplete,
		root_hobt.EstimatedRemainingHours,
		root_hobt.SortOrder,
		root_hobt.IsNotApplicable,
		root_hobt.ReviewedDateTimeUTC,
		root_hobt.SubmittedDateTimeUTC,
		root_hobt.SubmissionExpiryDate,
		mt.Guid AS MilestoneTypeID,
		root_hobt.QuoteLineID,
		root_hobt.Reference,
		si.Guid AS StartedByUserId,
		ci.guid AS CompletedByUserId,
		ri.Guid AS ReviewerUserId,
		sbi.Guid AS SubmittedBy,
		j.Guid AS JobID
FROM	SJob.Milestones root_hobt
JOIN	SJob.MilestoneTypes mt ON (mt.ID = root_hobt.MilestoneTypeID)
JOIN	SCore.Identities si ON (si.ID = root_hobt.StartedByUserId)
JOIN	SCore.Identities ci ON (ci.ID = root_hobt.CompletedByUserId)
JOIN	SCore.Identities ri ON (ri.ID = root_hobt.ReviewerUserId)
JOIN	SCore.Identities sbi ON (sbi.ID = root_hobt.SubmittedBy)
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)', 33, 30, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'Milestones', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (56, 1, '80207016-496f-4f3e-b84b-09017eec05fc', N'[SJob].[MilestonesUpsert]', N'EXEC [SJob].[MilestonesUpsert ]  @JobGuid = @JobGuid, @MilestoneTypeGuid = @MilestoneTypeGuid, @Description = @Description, @StartDateTimeUTC = @StartDateTimeUTC, @DueDateTimeUTC = @DueDateTimeUTC, @ScheduledDateTimeUTC = @ScheduledDateTimeUTC, @CompletedDateTimeUTC = @CompletedDateTimeUTC, @QuotedHours = @QuotedHours, @EstimateHoursRemaining = @EstimateHoursRemaining, @SortOrder = @SortOrder, @StartedByUserGuid = @StartedByUserGuid, @CompletedByUserGuid = @CompletedByUserGuid, @IsNotApplicable = @IsNotApplicable, @ReviewedDateTimeUTC = @ReviewedDateTimeUTC, @ReviewerUserGuid = @ReviewerUserGuid, @Reference = @Reference, @SubmittedDateTimeUTC = @SubmittedDateTimeUTC, @SubmittedByGuid = @SubmittedByGuid, @SubmissionExpiryDate = @SubmissionExpiryDate, @Guid = @Guid', 33, 30, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'MilestonesUpsert ', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (57, 1, 'f99b17f4-ab13-4b01-b26c-f45c6b186e89', N'[SJob].[JobMemosUpsert]', N'EXEC [SJob].[JobMemosUpsert]  @JobGuid = @JobGuid, @Memo = @Memo, @CreatedDateTimeUTC = @CreatedDateTimeUTC, @CreatedByUserGuid = @CreatedByUserGuid, @Guid = @Guid ', 44, 42, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (58, 1, '00bb9bb1-6aa6-4376-9b17-93da8d2adbb1', N'[SJob].[JobPurposeGroupsUpsert]', N'EXEC [SJob].[JobPurposeGroupsUpsert]  @JobGuid = @JobGuid, @PurposeGroupGuid = @PurposeGroupGuid, @Guid = @Guid', 46, 44, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (59, 1, '1a51511c-3499-4c49-8876-d11c436b4445', N'ProjectDirectoryUpsert', N'EXEC [SSop].[ProjectDirectoryUpsert]  @JobGuid = @JobGuid, @ProjectDirectoryRoleGuid = @ProjectDirectoryRoleGuid, @AccountGuid = @AccountGuid, @ContactGuid = @ContactGuid, @ProjectGuid = @ProjectGuid, @Guid = @Guid', 35, 31, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectDirectoryUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (60, 1, 'ea4b1ef6-950f-4a4b-a9b8-98c225cbd4e4', N'Job Memos Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Memo, 
		root_hobt.CreatedDateTimeUTC,
		j.guid AS JobID,
		i.guid AS CreatedByUserId
FROM	SJob.JobMemos root_hobt
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
JOIN	SCore.Identities i ON (i.ID = root_hobt.CreatedByUserId)', 44, 42, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (61, 1, '6e808309-c85f-446d-9de8-479dcb6f7562', N'Job Actions Read', N'SELECT
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Notes,
		root_hobt.LegacyID,
		root_hobt.IsComplete,
		root_hobt.CreatedDateTimeUTC,
		j.Guid  AS JobId,
		m.Guid  AS MilestoneId,
		ac.Guid AS ActivityId,
		s.Guid  AS SurveyorId,
		cu.Guid AS CreatedByUserId,
		i.Guid AS AssigneeUserId,
		ap.Guid AS ActionPriorityId,
		aty.Guid AS ActionTypeId,
		ast.Guid AS ActionStatusId
FROM
		SJob.Actions root_hobt
JOIN
		SJob.Jobs j ON (j.ID = root_hobt.JobId)
JOIN
		SJob.Milestones m ON (m.ID = root_hobt.MilestoneId)
JOIN
		SJob.Activities ac ON (ac.ID = root_hobt.ActivityId)
JOIN
		SCore.Identities s ON (s.ID = root_hobt.SurveyorId)
JOIN
		SCore.Identities cu ON (cu.ID = root_hobt.CreatedByUserId)
JOIN
		SJob.ActionPriorities ap ON (root_hobt.ActionPriorityId = ap.ID)
JOIN
		SJob.ActionStatus ast ON (root_hobt.ActionStatusId = ast.ID)
JOIN
		SJob.ActionTypes aty ON (root_hobt.ActionTypeId = aty.ID)
JOIN
		SCore.Identities i ON (root_hobt.AssigneeUserId = i.ID)', 43, 41, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (65, 1, '7ab99233-40d0-4567-867a-5df3d8e38881', N'Project Directory Read', N'SELECT 
	root_hobt.Guid
,	[DFBC2B7E-9655-44D7-966E-E749E7F702AA].Guid AS JobID
,	[59D35AD9-A62C-417B-AE34-255C0FA2E3D5].Guid AS AccountID
,	root_hobt.RowVersion
,	root_hobt.RowStatus
,	root_hobt.ID
,	[9D0F7D88-097A-43BF-B667-2C58F8E7AAA3].Guid AS ProjectDirectoryRoleID
,	[9A444DB8-F290-4443-BAC6-D77999EA1DD9].Guid AS ContactID
,	[DED3069E-FA1A-4DD6-8EDC-0C2924215B54].Guid AS ProjectID

FROM SJob.ProjectDirectory AS root_hobt 
JOIN SJob.Jobs AS [DFBC2B7E-9655-44D7-966E-E749E7F702AA] ON ([DFBC2B7E-9655-44D7-966E-E749E7F702AA].ID = root_hobt.JobID) 
 JOIN SCrm.Accounts AS [59D35AD9-A62C-417B-AE34-255C0FA2E3D5] ON ([59D35AD9-A62C-417B-AE34-255C0FA2E3D5].ID = root_hobt.AccountID) 
 JOIN SJob.ProjectDirectoryRoles AS [9D0F7D88-097A-43BF-B667-2C58F8E7AAA3] ON ([9D0F7D88-097A-43BF-B667-2C58F8E7AAA3].ID = root_hobt.ProjectDirectoryRoleID) 
 JOIN SCrm.Contacts AS [9A444DB8-F290-4443-BAC6-D77999EA1DD9] ON ([9A444DB8-F290-4443-BAC6-D77999EA1DD9].ID = root_hobt.ContactID) 
 JOIN SSop.Projects AS [DED3069E-FA1A-4DD6-8EDC-0C2924215B54] ON ([DED3069E-FA1A-4DD6-8EDC-0C2924215B54].ID = root_hobt.ProjectID) 
', 35, 31, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ProjectDirectory', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (66, 1, 'b7a45c76-8cfd-4d63-ad64-2d2114e48053', N'[SJob].[JobActionsUpsert]', N'EXEC [SJob].[ActionsUpsert]  @JobGuid = @JobGuid, @MilestoneGuid = @MilestoneGuid, @ActivityGuid = @ActivityGuid, @SurveyorGuid = @SurveyorGuid, @Notes = @Notes, @IsComplete = @IsComplete, @CreatedByUserGuid = @CreatedByUserGuid, @ActionStatusGuid = @ActionStatusGuid, @ActionTypeGuid = @ActionTypeGuid, @ActionPriorityGuid = @ActionPriorityGuid, @AssigneeUserGuid = @AssigneeUserGuid, @Guid = @Guid', 43, 41, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActionsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (67, 1, 'fc82bb58-acd9-46ad-85bc-85ef362cf605', N'[SJob].[JobsUpsert]', N'EXEC [SJob].[JobsUpsert]  
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@JobTypeGuid = @JobTypeGuid, 
	@UprnGuid = @UprnGuid, 
	@ClientAccountGuid = @ClientAccountGuid, 
	@ClientAddressGuid = @ClientAddressGuid, 
	@ClientContactGuid = @ClientContactGuid, 
	@AgentAccountGuid = @AgentAccountGuid, 
	@AgentAddressGuid = @AgentAddressGuid, 
	@AgentContactGuid = @AgentContactGuid, 
	@FinanceAccountGuid = @FinanceAccountGuid, 
	@FinanceAddressGuid = @FinanceAddressGuid, 
	@FinanceContactGuid = @FinanceContactGuid, 
	@SurveyorGuid = @SurveyorGuid, 
	@JobDescription = @JobDescription, 
	@IsSubjectToNDA = @IsSubjectToNDA, 
	@JobStarted = @JobStarted, 
	@JobCompleted = @JobCompleted, 
	@JobCancelled = @JobCancelled, 
	@ValueOfWorkGuid = @ValueOfWorkGuid, 
	@AgreedFee = @AgreedFee, 
	@RibaStage1Fee = @RibaStage1Fee, 
	@RibaStage2Fee = @RibaStage2Fee, 
	@RibaStage3Fee = @RibaStage3Fee, 
	@RibaStage4Fee = @RibaStage4Fee, 
	@RibaStage5Fee = @RibaStage5Fee, 
	@RibaStage6Fee = @RibaStage6Fee, 
	@RibaStage7Fee = @RibaStage7Fee, 
	@PreConstructionStageFee = @PreConstructionStageFee, 
	@ConstructionStageFee = @ConstructionStageFee, 
	@ArchiveReferenceLink = @ArchiveReferenceLink, 
	@ArchiveBoxReference = @ArchiveBoxReference, 
	@CreatedOn = @CreatedOn, 
	@ExternalReference = @ExternalReference, 
	@IsCompleteForReview = @IsCompleteForReview, 
	@ReviewedByUserGuid = @ReviewedByUserGuid, 
	@ReviewDateTimeUTC = @ReviewDateTimeUTC, 
	@AppFormReceived = @AppFormReceived, 
	@FeeCap = @FeeCap, 
	@CurrentRibaStageGuid = @CurrentRibaStageGuid, 
	@JobDormant = @JobDormant, 
	@PurchaseOrderNumber = @PurchaseOrderNumber, 
	@ContractGuid = @ContractGuid, 
	@ProjectGuid = @ProjectGuid, 
	@ValueOfWork = @ValueOfWork, 
	@ClientAppointmentReceived = @ClientAppointmentReceived, 
	@AppointedFromStageGuid = @AppointedFromStageGuid, 
	@DeadDate = @DeadDate, 
	@Guid = @Guid, 
	@BillingInstruction = @BillingInstruction,
        @CannotBeInvoiced = @CannotBeInvoiced,
         @CannotBeInvoicedReason = @CannotBeInvoicedReason,
         @AgentContractGuid = @AgentContractGuid,
         @CompleteForReviewDate = @CompleteForReviewDate,
          @SectorGuid = @SectorGuid,
          @MarketGuid = @MarketGuid', 9, 9, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobsUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (68, 1, '3a9bcc94-13cd-48cb-bf7b-ec44e1f3137d', N'Account Contacts Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		a.guid AS PrimaryAccountAddressID,
		acc.Guid AS AccountID,
		c.Guid AS ContactID
FROM	SCrm.AccountContacts root_hobt
JOIN	SCrm.AccountAddresses a ON (a.ID = root_hobt.PrimaryAccountAddressID)
JOIN	SCrm.Accounts acc ON (acc.ID = root_hobt.AccountID)
JOIN	SCrm.Contacts c ON (c.ID = root_hobt.ContactID)', 17, 36, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (69, 1, '536d44f0-9344-44e8-ad19-c780863015a8', N'[SCrm].[AccountAddressesUpsert]', N'EXEC [SCrm].[AccountAddressesUpsert]  @AccountGuid = @AccountGuid, @AddressGuid = @AddressGuid, @Guid = @Guid', 16, 35, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (70, 1, '9546f57f-280a-47bb-9f77-cbfbeb44af1a', N'[SCrm].[AccountContactsUpsert]', N'EXEC [SCrm].[AccountContactsUpsert]  @AccountGuid = @AccountGuid, @ContactGuid = @ContactGuid, @PrimaryAccountAddressGuid = @PrimaryAccountAddressGuid, @Guid = @Guid', 17, 36, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (74, 1, '6ceb6ed0-88c7-4237-81ba-fea5d0c7c819', N'[SJob].[ActivitiesValidate]', N'SELECT * FROM [SJob].[ActivitiesValidate] ( @Guid, @ActivityStatusGuid, @Start, @End, @InvoicingValue, @InvoicingQuantity, @JobGuid, @NewExpiryDate, @ActivityTypeGuid) root_hobt', 30, 25, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SJob', N'ActivitiesValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (75, 1, 'c6ca2478-8fc4-49c0-89b5-cd85be5a1aae', N'Languages Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Locale
FROM	SCore.Languages root_hobt', 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (76, 1, 'f2c90630-f9ff-4267-8378-c25b4e70abd9', N'[SCore].[LanguageUpsert]', N'EXEC [SCore].[LanguageUpsert]  @Name = @Name, @Locale = @Locale, @Guid = @Guid', 1, -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (77, 1, '4d536e82-d79e-4222-ac2c-576b212a823a', N'[SCore].[EntityHoBTUpsert]', N'EXEC [SCore].[EntityHoBTUpsert]  @SchemaName = @SchemaName, @ObjectName = @ObjectName, @ObjectType = @ObjectType, @IsMainHoBT = @IsMainHoBT, @IsReadOnlyOffline = @IsReadOnlyOffline, @EntityTypeGuid = @EntityTypeGuid, @Guid = @Guid', 5, 5, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (78, 1, '47e10307-aa6b-44a2-8c9c-ef2399be5b93', N'[SCrm].[AddressUpsert]', N'EXEC [SCrm].[AddressUpsert]  @AddressNumber = @AddressNumber, @Name = @Name, @Number = @Number, @AddressLine1 = @AddressLine1, @AddressLine2 = @AddressLine2, @AddressLine3 = @AddressLine3, @Town = @Town, @CountyGuid = @CountyGuid, @Postcode = @Postcode, @CountryGuid = @CountryGuid, @Guid = @Guid', 18, 16, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (79, 1, 'bc9eae4f-fa5b-48a9-96a1-3cafb63242cf', N'[SCrm].[ContactUpsert]', N'EXEC SCrm.ContactUpsert @FirstName = @FirstName,
						@Surname = @Surname,
						@DisplayName = @DisplayName,
						@IsPerson = @IsPerson,
						@PrimaryAccountGuid = @PrimaryAccountGuid,
						@PrimaryAddressGuid = @PrimaryAddressGuid,
						@TitleGuid = @TitleGuid,
						@PositionGuid = @PositionGuid,
						@Initials = @Initials,
						@PostNominals = @PostNominals,
						@Guid = @Guid;', 25, 20, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (80, 1, 'e845a1e1-b062-4f00-9b46-88e6de01492a', N'[SCrm].[ContactDetailUpsert]', N'EXEC [SCrm].[ContactDetailUpsert]  @Name = @Name, @Value = @Value, @ContactGuid = @ContactGuid, @ContactDetailTypeGuid = @ContactDetailTypeGuid, @IsDefault = @IsDefault, @Guid = @Guid', 22, 17, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCrm', N'ContactDetailUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (81, 1, 'd6d03324-e5b6-4d82-a9cf-8efe1fb62b06', N'Contact Detail Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Value,
root_hobt.IsDefault,
		c.Guid AS ContactId,
		cdt.Guid AS ContactDetailTypeId
FROM	SCrm.ContactDetails root_hobt
JOIN	SCrm.Contacts c ON (c.ID = root_hobt.ContactID)
JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = root_hobt.ContactDetailTypeID)', 22, 17, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (82, 1, '7917b62a-2f87-4d5c-beee-8e8df1eaa770', N'Quotes Read', N'SELECT 
	[01FDD623-FA79-43E2-AC7B-FA45BEF7FC73].Guid AS ClientAddressId
,	[04DD32E8-AE80-4F81-BD9A-F646441AFBE4].Guid AS ClientContactId
,	[F530931A-6E91-4BEB-BF2C-4C48B58C07D9].Guid AS ContractID
,	root_hobt.Date
,	root_hobt.Guid
,	root_hobt.ID
,	root_hobt.Number
,	[07C15164-1D8B-452D-9CEC-EEF64056AB52].Guid AS OrganisationalUnitID
,	root_hobt.Overview
,	[EE947786-1E4A-40D8-B0AD-E2D0B039CF6E].Guid AS QuotingUserId
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.DateAccepted
,	root_hobt.DateRejected
,	root_hobt.DateSent
,	root_hobt.ExpiryDate
,	[3AFE632D-2EE2-4FD8-8FFC-E696E84E095C].Guid AS QuoteSourceId
,	root_hobt.RejectionReason
,	[3FDEF099-DBC8-4F1D-B8D7-529600A0B62D].Guid AS AgentAddressId
,	[5AA9C5DF-307E-4DEE-9EE0-7B97115E1315].Guid AS AgentContactId
,	root_hobt.ExternalReference
,	root_hobt.IsSubjectToNDA
,	root_hobt.ChaseDate1
,	root_hobt.ChaseDate2
,	root_hobt.FeeCap
,	root_hobt.IsFinal
,	root_hobt.LegacyId
,	root_hobt.SendInfoToAgent
,	root_hobt.SendInfoToClient
,	[7E3459EE-8083-4C0E-9652-03D71A98F857].Guid AS QuotingConsultantId
,	[FC51FD71-51A1-4B7A-BA50-F0C2F2816225].Guid AS AppointmentFromRibaStageId
,	[DA716B55-56FA-40CE-B1E3-50A56F2F233A].Guid AS ProjectId
,	root_hobt.ValueOfWork
,	[34B965DC-8D1F-4066-81BB-852157CBB00F].Guid AS OriginalQuoteId
,	root_hobt.RevisionNumber
,	[93001C06-FD4A-4965-B8EA-EDAF8C16A21E].Guid AS CurrentRibaStageId
,	root_hobt.DeadDate
,	[30E87213-B425-43FC-B37C-6F1F3EDE3AE0].Guid AS EnquiryServiceID
,	root_hobt.ExclusionsAndLimitations
,	root_hobt.LegacySystemID
,   root_hobt.DateDeclinedToQuote
,   root_hobt.DeclinedToQuoteReason
,   AgentContract.Guid AS AgentContractID
,	sectors.Guid AS SectorId
,   market.Guid AS MarketId
FROM SSop.Quotes AS root_hobt 
JOIN SCrm.AccountAddresses AS [01FDD623-FA79-43E2-AC7B-FA45BEF7FC73] ON ([01FDD623-FA79-43E2-AC7B-FA45BEF7FC73].ID = root_hobt.ClientAddressId) 
 JOIN SCrm.AccountContacts AS [04DD32E8-AE80-4F81-BD9A-F646441AFBE4] ON ([04DD32E8-AE80-4F81-BD9A-F646441AFBE4].ID = root_hobt.ClientContactId) 
 JOIN SSop.Contracts AS [F530931A-6E91-4BEB-BF2C-4C48B58C07D9] ON ([F530931A-6E91-4BEB-BF2C-4C48B58C07D9].ID = root_hobt.ContractID) 
JOIN SSop.Contracts AS AgentContract ON (AgentContract.ID = root_hobt.AgentContractID)
 JOIN SCore.OrganisationalUnits AS [07C15164-1D8B-452D-9CEC-EEF64056AB52] ON ([07C15164-1D8B-452D-9CEC-EEF64056AB52].ID = root_hobt.OrganisationalUnitID) 
 JOIN SCore.Identities AS [EE947786-1E4A-40D8-B0AD-E2D0B039CF6E] ON ([EE947786-1E4A-40D8-B0AD-E2D0B039CF6E].ID = root_hobt.QuotingUserId) 
 JOIN SSop.QuoteSources AS [3AFE632D-2EE2-4FD8-8FFC-E696E84E095C] ON ([3AFE632D-2EE2-4FD8-8FFC-E696E84E095C].ID = root_hobt.QuoteSourceId) 
 JOIN SCrm.AccountAddresses AS [3FDEF099-DBC8-4F1D-B8D7-529600A0B62D] ON ([3FDEF099-DBC8-4F1D-B8D7-529600A0B62D].ID = root_hobt.AgentAddressId) 
 JOIN SCrm.AccountContacts AS [5AA9C5DF-307E-4DEE-9EE0-7B97115E1315] ON ([5AA9C5DF-307E-4DEE-9EE0-7B97115E1315].ID = root_hobt.AgentContactId) 
 JOIN SCore.Identities AS [7E3459EE-8083-4C0E-9652-03D71A98F857] ON ([7E3459EE-8083-4C0E-9652-03D71A98F857].ID = root_hobt.QuotingConsultantId) 
 JOIN SJob.RibaStages AS [FC51FD71-51A1-4B7A-BA50-F0C2F2816225] ON ([FC51FD71-51A1-4B7A-BA50-F0C2F2816225].ID = root_hobt.AppointmentFromRibaStageId) 
 JOIN SSop.Projects AS [DA716B55-56FA-40CE-B1E3-50A56F2F233A] ON ([DA716B55-56FA-40CE-B1E3-50A56F2F233A].ID = root_hobt.ProjectId) 
 JOIN SSop.Quotes AS [34B965DC-8D1F-4066-81BB-852157CBB00F] ON ([34B965DC-8D1F-4066-81BB-852157CBB00F].ID = root_hobt.OriginalQuoteId) 
 JOIN SJob.RibaStages AS [93001C06-FD4A-4965-B8EA-EDAF8C16A21E] ON ([93001C06-FD4A-4965-B8EA-EDAF8C16A21E].ID = root_hobt.CurrentRibaStageId) 
 JOIN SSop.EnquiryServices AS [30E87213-B425-43FC-B37C-6F1F3EDE3AE0] ON ([30E87213-B425-43FC-B37C-6F1F3EDE3AE0].ID = root_hobt.EnquiryServiceID) 
 JOIN SCore.Sectors AS sectors ON (root_hobt.SectorId = sectors.ID)
 JOIN SCore.Markets as market ON (root_hobt.MarketId = market.ID)
', 55, 52, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'Quotes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (83, 1, '40dbbdf9-c750-4db6-adbf-2e5c53fdcbd2', N'Contracts Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.StartDate,
		root_hobt.EndDate,
		root_hobt.NextReviewDate,
		root_hobt.Details,
		i.Guid AS SignatoryId,
		acc.Guid AS AccountID,
		pl.Guid AS PriceListId,
		ctrt.Guid AS ContractTypeID
FROM	SSop.Contracts root_hobt
JOIN	SCore.Identities i ON (i.ID = root_hobt.SignatoryId)
JOIN	SCrm.Accounts acc ON (acc.ID = root_hobt.AccountID)
JOIN	SSop.PriceLists pl ON (pl.ID = root_hobt.PriceListId)
JOIN    SSop.ContractTypes ctrt ON (ctrt.ID = root_hobt.ContractTypeId)', 50, 47, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (84, 1, '8ffd98c5-d67a-4a34-9d4a-ea89c8f87853', N'[SSop].[ContractsUpsert]', N'EXEC [SSop].[ContractsUpsert]  @AccountGuid = @AccountGuid, @SignatoryGuid = @SignatoryGuid, @Details = @Details, @StartDate = @StartDate, @EndDate = @EndDate, @NextReviewDate = @NextReviewDate, @PriceListGuid = @PriceListGuid, @Guid = @Guid, @ContractTypeGuid = @ContractTypeGuid', 50, 47, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (85, 1, '62cc9e9b-1be3-42c8-a283-561d04345c67', N'[SSop].[QuotesUpsert]', N'EXEC [SSop].[QuotesUpsert]  
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@QuotingUserGuid = @QuotingUserGuid, 
	@ContractGuid = @ContractGuid, 
	@Date = @Date, 
	@Overview = @Overview, 
	@ExpiryDate = @ExpiryDate, 
	@DateSent = @DateSent, 
	@DateAccepted = @DateAccepted, 
	@DateRejected = @DateRejected, 
	@RejectionReason = @RejectionReason, 
	@FeeCap = @FeeCap, 
	@IsFinal = @IsFinal, 
	@ExternalReference = @ExternalReference, 
	@QuotingConsultantGuid = @QuotingConsultantGuid, 
	@AppointmentFromRibaStageGuid = @AppointmentFromRibaStageGuid, 
	@CurrentStageGuid = @CurrentStageGuid, 
	@DeadDate = @DeadDate, 
	@EnquiryServiceGuid = @EnquiryServiceGuid, 
	@ProjectGuid = @ProjectGuid, 
	@Guid = @Guid, 
	@JobType = @JobType, 
	@DeclinedToQuoteReason = @DeclinedToQuoteReason, 
	@DescriptionOfWorks = @DescriptionOfWorks, 
	@ExclusionsAndLimitations = @ExclusionsAndLimitations,
        @AgentContractGuid = @AgentContractGuid,
        @IsSubjectToNDA = @IsSubjectToNDA,
        @SectorGuid = @SectorGuid,
        @MarketGuid = @MarketGuid
        ', 55, 52, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuotesUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (86, 1, '92f55f6f-5af4-4887-8098-823a7a83093d', N'Quote Sections Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Overview,
		root_hobt.ShowProducts,
		root_hobt.ConsolidateJobs,
		root_hobt.SortOrder,
		root_hobt.NumberOfMeetings,
		root_hobt.NumberOfSiteVisits,
		q.Guid AS QuoteId,
		vow.Guid AS ValueOfWorkId,
		cqs.Guid AS CombineWithSectionId,
		rs.Guid AS RibaStageId
FROM	SSop.QuoteSections root_hobt
JOIN	SSop.Quotes q ON (q.ID = root_hobt.QuoteId)
JOIN	SJob.ValuesOfWork vow ON (vow.ID = root_hobt.ValueOfWorkId) 
JOIN	SSop.QuoteSections cqs ON (cqs.id = root_hobt.CombineWithSectionId)
JOIN	SJob.RibaStages rs ON (rs.ID = root_hobt.RibaStageId)
WHERE	(root_hobt.RowStatus NOT IN (0, 254))', 56, 53, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (87, 1, '504794d2-b562-44bc-83d5-80f7b8dcac62', N'Quote Items Read', N'SELECT 
	[A47D9C7E-9DCA-4AE0-B3AD-73A0690EDD92].Guid AS CreatedJobId,
	root_hobt.Details,
	root_hobt.DoNotConsolidateJob,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.LegacyId,
	root_hobt.LegacySystemID,
	root_hobt.Net,
	[6BA255D5-2339-4286-A86C-494A2AB1DA4A].Guid AS ProductId,
	[6E8FD1FD-157F-4B88-80CD-C0589CAD9D2A].Guid AS ProvideAtStageID,
	root_hobt.Quantity,
	[7EC6389A-C5BA-4B84-BE24-096C86DF6770].Guid AS QuoteId,
	[EEA4BD07-8A21-4B1B-8050-819EA27E1B11].Guid AS QuoteSectionId,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SortOrder,
	root_hobt.VatRate,
    root_hobt.NumberOfSiteVisits,
    root_hobt.NumberOfMeetings,
	invsc.Guid AS InvoicingSchedule 
FROM SSop.QuoteItems AS root_hobt 
JOIN SProd.Products AS [6BA255D5-2339-4286-A86C-494A2AB1DA4A] ON ([6BA255D5-2339-4286-A86C-494A2AB1DA4A].ID = root_hobt.ProductId) 
 JOIN SSop.QuoteSections AS [EEA4BD07-8A21-4B1B-8050-819EA27E1B11] ON ([EEA4BD07-8A21-4B1B-8050-819EA27E1B11].ID = root_hobt.QuoteSectionId) 
 JOIN SJob.Jobs AS [A47D9C7E-9DCA-4AE0-B3AD-73A0690EDD92] ON ([A47D9C7E-9DCA-4AE0-B3AD-73A0690EDD92].ID = root_hobt.CreatedJobId) 
 JOIN SJob.RibaStages AS [6E8FD1FD-157F-4B88-80CD-C0589CAD9D2A] ON ([6E8FD1FD-157F-4B88-80CD-C0589CAD9D2A].ID = root_hobt.ProvideAtStageID) 
 JOIN SSop.Quotes AS [7EC6389A-C5BA-4B84-BE24-096C86DF6770] ON ([7EC6389A-C5BA-4B84-BE24-096C86DF6770].ID = root_hobt.QuoteId) 
 JOIN SFin.InvoiceSchedules AS invsc ON (root_hobt.InvoicingSchedule = invsc.ID)
 
', 58, 55, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteItems', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (90, 1, '3d455e91-093a-4c73-bf55-0f2fd69933f3', N'[SSop].[QuoteSectionsUpsert]', N'EXEC [SSop].[QuoteSectionsUpsert]  @QuoteGuid = @QuoteGuid, @Name = @Name, @Overview = @Overview, @ShowProducts = @ShowProducts, @ConsolidateJobs = @ConsolidateJobs, @SortOrder = @SortOrder, @RibaStageGuid = @RibaStageGuid, @CombineWithSectionGuid = @CombineWithSectionGuid, @NumberOfMeetings = @NumberOfMeetings, @NumberOfSiteVisits = @NumberOfSiteVisits, @ValueOfWorkGuid = @ValueOfWorkGuid, @Guid = @Guid  ', 56, 53, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (91, 1, '358909e8-c62d-4c50-8b6d-28f5721aa1ab', N'[SSop].[QuoteItemsUpsert]', N'EXEC [SSop].[QuoteItemsUpsert]  
	@QuoteGuid = @QuoteGuid, 
	@ProductGuid = @ProductGuid, 
	@Details = @Details, 
	@Net = @Net, 
	@VatRate = @VatRate, 
	@DoNotConsolidateJob = @DoNotConsolidateJob, 
	@SortOrder = @SortOrder, 
	@Quantity = @Quantity, 
	@ProvidedAtStageGuid = @ProvidedAtStageGuid, 
	@Guid = @Guid,
        @NumberOfSiteVisits = @NumberOfSiteVisits,
        @NumberOfMeetings = @NumberOfMeetings,
        @InvoicingScheduleGuid = @InvoicingScheduleGuid', 58, 55, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteItemsUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (92, 1, 'fff024c0-5207-4225-b660-126009cfaff9', N'Products Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Code,
		root_hobt.Description,
		root_hobt.NeverConsolidate,
		jt.Guid AS CreatedJobType,
		rs.Guid AS RibaStageId
FROM	SProd.Products root_hobt
JOIN	SJob.JobTypes jt ON (jt.ID = root_hobt.CreatedJobType)
JOIN	SJob.RibaStages rs ON (rs.Id = root_hobt.RibaStageId)
WHERE	(root_hobt.RowStatus NOT IN (0, 254))', 51, 48, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (93, 1, '67cc01c9-028a-434c-b146-45eb8eef940d', N'[SProd].[ProductsUpsert]', N'EXEC [SProd].[ProductsUpsert]  @Code = @Code, @Description = @Description, @CreatedJobTypeGuid = @CreatedJobTypeGuid, @NeverConsolidate = @NeverConsolidate, @RibaStageGuid = @RibaStageGuid, @Guid = @Guid', 51, 48, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (94, 1, '11e9b80f-cebd-4c45-831f-9889aac225a4', N'[SSop].[QuoteCreateJobs]', N'EXEC [SSop].[QuoteCreateJobs]  @Guid = @Guid', 55, 52, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (96, 1, '79a9a4a2-31e7-4c07-83c5-3da8d47aa013', N'Transactions Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		tt.Guid	 AS TransactionTypeID,
		a.Guid	 AS AccountID,
		j.Guid	 AS JobID,
		root_hobt.Number,
		root_hobt.SageTransactionReference,
		root_hobt.Date,
		root_hobt.PurchaseOrderNumber,
		root_hobt.LegacyId,
		root_hobt.CreatedDateTimeUTC,
		ou.Guid AS OrganisationalUnitID,
		cu.Guid AS CreatedByUserID,
		i.Guid AS SurveyorUserID,
		ct.Guid AS CreditTermsId
FROM	SFin.Transactions	  AS root_hobt
JOIN	SFin.TransactionTypes AS tt ON (tt.ID = root_hobt.TransactionTypeID)
JOIN	SCrm.Accounts		  AS a ON (a.ID	  = root_hobt.AccountID)
JOIN	SJob.Jobs			  AS j ON (j.ID	  = root_hobt.JobID)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = root_hobt.OrganisationalUnitID)
JOIN	SCore.Identities cu ON (cu.ID = root_hobt.CreatedByUserID)
JOIN	SCore.Identities i ON (i.ID = root_hobt.SurveyorUserID)
JOIN	SFin.CreditTerms ct ON (ct.ID = root_hobt.CreditTermsId)', 37, 33, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (98, 1, 'c74f1ce3-bba9-43f3-8def-ac37f82283a1', N'[SFin].[TransactionsUpsert]', N'EXEC SFin.TransactionsUpsert @AccountGuid = @AccountGuid,
							 @JobGuid = @JobGuid,
							 @TransactionTypeGuid = @TransactionTypeGuid,
							 @Date = @Date,
							 @PurchaseOrderNumber = @PurchaseOrderNumber,
							 @SageTransactionReference = @SageTransactionReference,
							 @OrganisationalUnitGuid = @OrganisationalUnitGuid,
							 @CreatedByUserGuid = @CreatedByUserGuid,
							 @SurveyorGuid = @SurveyorGuid,
							 @CreditTermsGuid = @CreditTermsGuid,
							 @Guid = @Guid;', 37, 33, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (99, 1, 'e3764f3e-450e-4821-8b09-786df3c38481', N'Quotes Data Pills', N'SELECT * FROM [SSop].[tvf_QuotesDataPills] ( @Guid, @DateAccepted, @DateRejected, @ProjectGuid, @ContractGuid, @AgentContractGuid) root_hobt', 55, 52, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SSop', N'tvf_QuotesDataPills', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (100, 1, 'dcebcccf-d0d9-44cf-9903-2d347213fd3f', N'Entity Property Dependents Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		ep.Guid AS ParentEntityPropertyID,
		dep.Guid AS DependantPropertyID
FROM	SCore.EntityPropertyDependants root_hobt
JOIN	SCore.EntityProperties ep ON (ep.ID = root_hobt.ParentEntityPropertyID)
JOIN	SCore.EntityProperties dep ON (dep.ID = root_hobt.DependantPropertyID)', 65, 61, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (102, 1, 'd3b3a93b-3099-438c-8efb-19fc992dc669', N'[SCore].[EntityPropertyDependantUpsert]', N'EXEC [SCore].[EntityPropertyDependantUpsert]  @ParentEntityPropertyGuid = @ParentEntityPropertyGuid, @DependantEntityPropertyGuid = @DependantEntityPropertyGuid, @Guid = @Guid', 65, 61, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (103, 1, 'eadbb21c-f120-4ec1-9ea7-37881363974e', N'[SSop].[QuotesValidate]', N'SELECT * FROM [SSop].[tvf_QuotesValidate] ( @Guid, @DateSent, @DeadDate, @DateRejected,  @IsFinal, @RevisionNumber, @OrganisationalUnitGuid, @DateDeclinedToQuote, @DeclinedToQuoteReason, @ContractGuid, @AgentContractGuid) root_hobt', 55, 52, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SSop', N'tvf_QuotesValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (104, 1, '124cf0e7-d92b-4234-a63a-d9ef28def687', N'Org Units Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		p.Guid ParentID,
		a.Guid AS AddressId,
		c.Guid AS ContactId,
		o_a.Guid OfficialAddressId,
		o_c.Guid OfficialContactId,
		N'''' OrgNode,
		root_hobt.OrgLevel,
		root_hobt.IsDivision,
		root_hobt.IsBusinessUnit,
		root_hobt.IsDepartment,
		root_hobt.IsTeam,
		root_hobt.DepartmentPrefix,
		root_hobt.CostCentreCode,
		sg.Guid AS DefaultSecurityGroupId,
                root_hobt.QuoteThreshold
FROM	SCore.OrganisationalUnits root_hobt
JOIN	SCore.OrganisationalUnits p ON (p.id = root_hobt.ParentId)
JOIN	SCrm.Addresses a ON (a.ID = root_hobt.AddressId)
JOIN	SCrm.Addresses o_a ON (o_a.id = root_hobt.OfficialAddressId)
JOIN	SCrm.Contacts c ON (c.Id = root_hobt.ContactId)
JOIN	SCrm.Contacts o_c ON (o_c.Id = root_hobt.OfficialContactId)
JOIN	SCore.Groups sg ON (sg.ID = root_hobt.DefaultSecurityGroupId)', 67, 63, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (105, 1, '6198ecbc-e32b-406e-828a-e83b60f56025', N'[SCrm].[AccountStatusUpsert]', N'EXEC [SCrm].[AccountStatusUpsert]  @Name = @Name, @IsHold = @IsHold, @Guid = @Guid', 39, -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (106, 1, '9b1c81c0-527c-4e59-81cd-131ea5d9a03c', N'Account Status Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.IsHold
FROM	SCrm.AccountStatus root_hobt', 39, 37, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (107, 1, '824f5dee-f400-4848-a2a6-ad6f8d2f9928', N'[SJob].[ActivityStatusUpsert]', N'EXEC [SJob].[ActivityStatusUpsert]  @Name = @Name, @Colour = @Colour, @SortOrder = @SortOrder, @IsCompleteStatus = @IsCompleteStatus, @Guid = @Guid', 29, 24, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (108, 1, '78f970a1-8d8e-4fde-9dd5-42c271ee0713', N'Activity Status Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.IsActive,
		root_hobt.SortOrder,
		root_hobt.IsCompleteStatus,
		root_hobt.Colour
FROM	SJob.ActivityStatus root_hobt', 29, 24, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (109, 1, 'd9971f91-e690-41f8-a54c-5d0ae7ffe37a', N'[SJob].[ActivityTypesUpsert]', N'EXEC [SJob].[ActivityTypesUpsert]  
	@Name = @Name, 
	@IsActive = @IsActive, 
	@SortOrder = @SortOrder, 
	@IsFeeTrigger = @IsFeeTrigger, 
	@IsLiveTrigger = @IsLiveTrigger, 
	@IsAdmin = @IsAdmin, 
	@IsScheduleItem = @IsScheduleItem, 
	@Colour = @Colour, 
	@IsMeeting = @IsMeeting, 
	@IsSiteVisit = @IsSiteVisit, 
	@IsCommencementTrigger = @IsCommencementTrigger, 
	@Guid = @Guid, 
	@IsBillable = @IsBillable', 28, 23, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActivityTypesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (110, 1, '3891bf14-e7eb-4f29-8b04-c94cc95f063b', N'Activity Types Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.IsActive,
		root_hobt.SortOrder,
		root_hobt.IsFeeTrigger,
		root_hobt.IsLiveTrigger,
		root_hobt.IsAdmin,
		root_hobt.IsScheduleItem,
		root_hobt.Colour,
		root_hobt.IsMeeting,
		root_hobt.IsSiteVisit,
		root_hobt.IsBillable,
		root_hobt.IsCommencementTrigger
FROM	SJob.ActivityTypes root_hobt', 28, 23, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActivityTypes ', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (111, 1, '7b1a18a8-cb9a-433d-ac41-59384a94f8fe', N'[SCrm].[ContactDetailTypesUpsert]', N'EXEC [SCrm].[ContactDetailTypesUpsert]  @Name = @Name, @Guid = @Guid', 23, -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (112, 1, '4fca977e-6562-4139-b3e5-ea06f8d8129e', N'Contact Detail Types Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.ContactDetailTypes root_hobt', 23, 18, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (113, 1, '73e3506a-d32c-40ef-acb7-46e17b6c239e', N'[SCrm].[ContactPositionsUpsert]', N'EXEC [SCrm].[ContactPositionsUpsert]  @Name = @Name, @Guid = @Guid', 24, 19, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (114, 1, '7840c97e-145f-42a0-ba59-fe87821aaff6', N'Contact Positions Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.ContactPositions root_hobt', 24, 19, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (115, 1, '214d5d55-44d2-466c-abac-ca6c078e16fd', N'[SCrm].[ContactTitlesUpsert]', N'EXEC [SCrm].[ContactTitlesUpsert]  @Name = @Name, @Guid = @Guid', 26, -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (116, 1, '0923892d-a027-47d1-bd65-fe32fc2b5ed1', N'Contact Titles Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.ContactTitles root_hobt', 26, 21, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (117, 1, '6f17711d-4f06-464b-9e4e-53dc5c42a195', N'[SCrm].[CountiesUpsert]', N'EXEC [SCrm].[CountiesUpsert]  @Name = @Name, @CountryGuid = @CountryGuid, @Guid = @Guid', 68, 64, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (118, 1, '49e85584-c20d-41bd-b452-b0babae8f0fc', N'Counties Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		c.Guid AS CountryID
FROM	SCrm.Counties root_hobt
JOIN	SCrm.Countries c ON (c.ID = root_hobt.CountryID)', 68, 64, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (119, 1, '2d9130b9-8003-4246-a9f1-12b6a703659f', N'[SCrm].[CountriesUpsert]', N'EXEC [SCrm].[CountriesUpsert]  @Name = @Name, @Guid = @Guid', 69, 65, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (120, 1, 'f6172031-0bfa-4847-89a6-5ad7c4009258', N'Countries Read', N'SELECT	root_hobt.ID,
		root_hobt.Guid,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Name
FROM	SCrm.Countries root_hobt', 69, 65, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (121, 1, 'd6745e2f-a0e1-410d-a9cd-8bd80260c2c5', N'[SJob].[JobTypesUpsert]', N'EXEC [SJob].[JobTypesUpsert ]  @Name = @Name, @IsActive = @IsActive, @UseTimeSheets = @UseTimeSheets, @OrganisationalUnitGuid = @OrganisationalUnitGuid, @Guid = @Guid', 41, 39, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobTypesUpsert ', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (122, 1, '4a774537-6960-4d84-a5cb-515a07358b8a', N'Job Types Read', N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsActive,
	root_hobt.Name,
	[8C9FF97B-D7E8-4BF2-A153-ED7D08A9787A].Guid AS OrganisationalUnitID,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SequenceID,
	root_hobt.UsePlanChecks,
	root_hobt.UseTimeSheets
FROM SJob.JobTypes AS root_hobt 
JOIN SCore.OrganisationalUnits AS [8C9FF97B-D7E8-4BF2-A153-ED7D08A9787A] ON ([8C9FF97B-D7E8-4BF2-A153-ED7D08A9787A].ID = root_hobt.OrganisationalUnitID) 
', 41, 39, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobTypes', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (123, 1, 'd802f6c7-7b1e-4836-bd6d-b8c1f1560cd1', N'[SCore].[MergeDocumentsUpsert]', N'EXEC [SCore].[MergeDocumentsUpsert]  
	@Name = @Name, 
	@FilenameTemplate = @FilenameTemplate, 
	@EntityTypeGuid = @EntityTypeGuid, 
	@SharepointSiteGuid = @SharepointSiteGuid, 
	@DocumentId = @DocumentId, 
	@LinkedEntityTypeGuid = @LinkedEntityTypeGuid, 
	@AllowPDFOutputOnly = @AllowPDFOutputOnly, 
	@AllowExcelOutputOnly = @AllowExcelOutputOnly, 
	@ProduceOneOutputPerRow = @ProduceOneOutputPerRow, 
	@Guid = @Guid', 60, 57, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (125, 1, '65c80205-75bc-4f89-a64b-b2fafa07fb56', N'Merge Documents Read', N'SELECT 
	root_hobt.AllowPDFOutputOnly,
        root_hobt.AllowExcelOutputOnly,
	root_hobt.DocumentId,
	[2F88C3FF-B564-4B42-84BA-8B527EBABED6].Guid AS EntityTypeId,
	root_hobt.FilenameTemplate,
	root_hobt.Guid,
	root_hobt.ID,
	[FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0].Guid AS LinkedEntityTypeId,
	root_hobt.Name,
	root_hobt.ProduceOneOutputPerRow,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	[6551966B-1294-437E-8E20-E9771C9F2D1E].Guid AS SharepointSiteId
FROM SCore.MergeDocuments AS root_hobt 
JOIN SCore.EntityTypes AS [2F88C3FF-B564-4B42-84BA-8B527EBABED6] ON ([2F88C3FF-B564-4B42-84BA-8B527EBABED6].ID = root_hobt.EntityTypeId) 
 JOIN SCore.EntityTypes AS [FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0] ON ([FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0].ID = root_hobt.LinkedEntityTypeId) 
 JOIN SCore.SharepointSites AS [6551966B-1294-437E-8E20-E9771C9F2D1E] ON ([6551966B-1294-437E-8E20-E9771C9F2D1E].ID = root_hobt.SharepointSiteId) 
', 60, 57, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocuments', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (126, 1, 'f9ca1132-166e-4781-ae00-bbc959c5d682', N'[SJob].[MilestoneTypesUpsert]', N'EXEC [SJob].[MilestoneTypesUpsert]  @Name = @Name, @Code = @Code, @IsActive = @IsActive, @IsInvoiceTrigger = @IsInvoiceTrigger, @IsReviewRequired = @IsReviewRequired, @HelpText = @HelpText, @Hasdescription = @Hasdescription, @IsCompulsory = @IsCompulsory, @IncludeStart = @IncludeStart, @IncludeSchedule = @IncludeSchedule, @IncludeDueDate = @IncludeDueDate, @HasExternalSubmission = @HasExternalSubmission, @Guid = @Guid', 48, 45, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'MilestoneTypesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (127, 1, '9d5ac47d-f9dc-4d2a-acc8-4010d026af64', N'Milestone Types Read', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Code,
        root_hobt.Name,
        root_hobt.IsActive,
        root_hobt.IsInvoiceTrigger,
        root_hobt.IsReviewRequired,
        root_hobt.HelpText,
        root_hobt.HasQuotedHours,
        root_hobt.HasDescription,
        root_hobt.HasReference,
        root_hobt.IsCompulsory,
        root_hobt.IncludeStart,
        root_hobt.IncludeSchedule,
        root_hobt.HasExternalSubmission,
        root_hobt.IncludeDueDate
FROM
        SJob.MilestoneTypes root_hobt', 48, 45, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'MilestoneTypes ', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (128, 1, 'd35d532a-5a8c-4f46-a6ee-e2d4dd264a62', N'[SCore].[OrganisationalUnitsUpsert]', N'EXEC SCore.OrganisationalUnitsUpsert @ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid ,	-- uniqueidentifier
									 @Name = @Name,							-- nvarchar(250)
									 @AddressGuid = @AddressGuid,					-- uniqueidentifier
									 @ContactGuid = @ContactGuid,					-- uniqueidentifier
									 @OfficialAddressGuid = @OfficialAddressGuid,			-- uniqueidentifier
									 @OfficialContactGuid = @OfficialContactGuid,			-- uniqueidentifier
									 @DepartmentPrefix = @DepartmentPrefix,				-- nvarchar(10)
									 @CostCentreCode = @CostCentreCode,					-- nvarchar(50)
									 @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,
                                                                         @QuoteThreshold= @QuoteThreshold,
									 @Guid = @Guid OUTPUT					-- uniqueidentifier', 67, 63, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (129, 1, 'b122dcf0-5972-44dc-b4d6-026d586c083c', N'[SSop].[PriceListsUpsert]', N'EXEC [SSop].[PriceListsUpsert]  @Name = @Name, @IsActive = @IsActive, @UpliftOnStandardPrice = @UpliftOnStandardPrice, @Guid = @Guid', 52, 49, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (130, 1, '7747ab86-1919-4b86-8a11-48ca8960bea0', N'Price Lists Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.IsActive,
		root_hobt.UpliftOnStandardPrice, 
		root_hobt.Name
FROM	SSop.PriceLists root_hobt', 52, 49, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (131, 1, '7e749af3-0719-4bd2-894a-e785e54a2033', N'[SJob].[ProjectDirectoryRolesUpsert]', N'EXEC [SJob].[ProjectDirectoryRolesUpsert]  @Name = @Name, @Guid = @Guid', 36, 32, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (132, 1, '4373c225-49cc-4755-8f53-293635306a00', N'[SJob].[PurposeGroupsUpsert]', N'EXEC [SJob].[PurposeGroupsUpsert]  @Name = @Name, @Guid = @Guid', 45, 43, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (133, 1, '0f4252f4-6df4-4463-81e1-504b86f83a38', N'Purpose Groups Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SJob.PurposeGroups root_hobt', 45, 43, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (134, 1, 'e1b7a911-7385-4dae-988d-85e42a100eb8', N'[SSop].[QuoteSourcesUpsert]', N'EXEC [SSop].[QuoteSourcesUpsert]  @Name = @Name, @Guid = @Guid', 62, 58, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (135, 1, '07716d08-0bf4-49cc-a055-2b5b4f0e7e2c', N'Quote Sources Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SSop.QuoteSources root_hobt', 62, 58, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (136, 1, '260a522f-2734-41f2-9844-512037d9f76f', N'[SJob].[RibaStagesUpsert]', N'EXEC [SJob].[RibaStagesUpsert]  @Number = @Number, @Description = @Description, @Guid = @Guid', 70, -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (137, 1, '1f99ed94-d831-486e-bffb-f483175ab7e8', N'Riba Stages Read', N'SELECT root_hobt.ID,
	   root_hobt.RowStatus,
	   root_hobt.RowVersion,
	   root_hobt.Guid,
	   root_hobt.Number,
	   root_hobt.Description
FROM	SJob.RibaStages root_hobt', 70, 66, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (139, 1, '2393e5b7-e9ec-4b2f-a6ec-799fb13195de', N'[SJob].[ValuesOfWorkUpsert]', N'EXEC [SJob].[ValuesOfWorkUpsert]  @Name = @Name, @SortOrder = @SortOrder, @Guid = @Guid', 49, 46, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (140, 1, '5173ef5c-9f46-443d-9548-a35e7611adf1', N'Values of Work Read', N'SELECT root_hobt.ID,
	   root_hobt.RowStatus,
	   root_hobt.RowVersion,
	   root_hobt.Guid,
	   root_hobt.Name,
	   root_hobt.SortOrder
FROM	SJob.ValuesOfWork root_hobt', 49, 46, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (141, 1, '84af4f4d-38c4-4ead-a7ff-dbb3671ac807', N'Quote Items Validate', N'SELECT * FROM [SSop].[tvf_QuoteItemsValidate] ( @CreatedJobGuid, @Guid, @InvoicingScheduleGuid, @QuoteGuid, @DoNotConsolidate) root_hobt', 58, 55, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SSop', N'tvf_QuoteItemsValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (142, 1, '091e7b63-b41b-4981-a818-e7bcebfc3008', N'Quote Sections Validate', N'SELECT * FROM SJob.QuoteSectionsValidate (@QuoteGuid, @Guid) root_hobt', 56, 53, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (143, 1, '49edd11f-9fc5-4de5-9264-4347ef35a8a5', N'Transaction Allocations Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus, root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.AllocatedAmount,
		st.Guid AS SourceTransactionID,
		tt.Guid AS TargetTransactionID
FROM	[SFin].[TransactionAllocations] root_hobt
JOIN	SFin.Transactions st ON (st.ID = root_hobt.SourceTransactionID)
JOIN	SFin.Transactions tt ON (tt.ID = root_hobt.TargetTransactionID)', 64, 60, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (145, 1, '6fac55f0-4f06-4f64-b743-671682e5151a', N'Transaction Allocations Upsert', N'EXECUTE SFin.TransactionAllocationsUpsert @SourceTransactionGuid = @SourceTransactionGuid,	-- uniqueidentifier
										  @TargetTransactionGuid = @TargetTransactionGuid,	-- uniqueidentifier
										  @AllocatedValue = @AllocatedValue,			-- decimal(9, 2)
										  @Guid = @Guid						-- uniqueidentifier', 64, 60, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (146, 1, '3ac1373a-24dc-4035-99d8-dac78b00b2f9', N'Price List Products Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid, 
root_hobt.Price,
		p.Guid AS ProductId,
		pl.Guid AS PriceListId
FROM	SSop.PriceListProducts root_hobt
JOIN	SSop.PriceLists pl ON (pl.ID = root_hobt.PriceListId)
JOIN	SProd.Products p ON (p.ID = root_hobt.ProductId)', 53, 50, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (147, 1, '48626a9e-0270-4169-9f6d-aa83f4979e59', N'[SSop].[PriceListProductsUpsert]', N'EXEC [SSop].[PriceListProductsUpsert]  @PriceListGuid = @PriceListGuid, @ProductGuid = @ProductGuid, @Price = @Price, @Guid = @Guid', 53, 50, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (148, 1, 'e10f83e0-be27-42ee-8df7-073ac8952096', N'Job Type Activity Types Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		jt.Guid JobTypeID,
		ty.Guid ActivityTypeID
FROM	SJob.JobTypeActivityTypes root_hobt
JOIN	SJob.JobTypes jt ON (jt.ID = root_hobt.JobTypeID)
JOIN	SJob.ActivityTypes ty ON (ty.ID = root_hobt.ActivityTypeID)', 81, 73, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (149, 1, '9a0c002a-38c6-4e76-8c87-efc2987e3e13', N'[SJob].[JobTypeMilestoneTemplateUpsert]', N'EXEC [SJob].[JobTypeMilestoneTemplateUpsert]  @JobTypeGuid = @JobTypeGuid, @MilestoneTypeGuid = @MilestoneTypeGuid, @Description = @Description, @SortOrder = @SortOrder, @Guid = @Guid', 79, 71, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (150, 1, '2803f5fc-4bf8-45ae-9533-37297d634002', N'[SJob].[JobTypeActivityTypesUpsert]', N'EXEC [SJob].[JobTypeActivityTypesUpsert]  @JobTypeGuid = @JobTypeGuid, @ActivityTypeGuid = @ActivityTypeGuid, @Guid = @Guid', 81, 73, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (152, 1, 'c64c431d-1b79-4e6f-93f2-727bfd53f207', N'[SJob].[JobTypeProjectDirectoryRolesUpsert]', N'EXEC [SJob].[JobTypeProjectDirectoryRolesUpsert]  @JobTypeGuid = @JobTypeGuid, @ProjectDirectoryRoleGuid = @ProjectDirectoryRoleGuid, @Guid = @Guid', 80, 72, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (153, 1, 'a7fd763c-7a15-4f62-8439-c728a51e279a', N'Job Type Milestone Templates Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		ty.Guid AS JobTypeID,
		mt.Guid AS MilestoneTypeID,
		root_hobt.Description,
		root_hobt.SortOrder
FROM	SJob.JobTypeMilestoneTemplates root_hobt
JOIN	SJob.JobTypes ty ON (ty.ID = root_hobt.JobTypeID)
JOIN	SJob.MilestoneTypes mt ON (mt.ID = root_hobt.MilestoneTypeID)', 79, 71, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (154, 1, '0337ddf0-64e1-4279-8054-6d16ff6769de', N'Job Type Project Directory Roles Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		ty.Guid AS JobTypeID,
		pdr.Guid AS ProjectDirectoryRoleID,
		root_hobt.SortOrder
FROM	SJob.JobTypeProjectDirectoryRoles root_hobt
JOIN	SJob.JobTypes ty ON (ty.ID = root_hobt.JobTypeID)
JOIN	SJob.ProjectDirectoryRoles pdr ON (pdr.ID = root_hobt.ProjectDirectoryRoleID)', 80, 72, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (155, 1, 'd332ee02-33fe-4304-8b13-4041f40807bf', N'[SCrm].[AccountMemoUpsert]', N'EXEC [SCrm].[AccountMemoUpsert]  @AccountGuid = @AccountGuid, @Memo = @Memo, @Guid = @Guid', 82, 74, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (156, 1, 'b660d18b-b81a-4123-8ad2-fbb9fcbcd1b8', N'Account Memos Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Memo,
		root_hobt.CreatedDateTimeUTC,
		a.Guid AS AccountId,
		i.Guid AS CreatedByUserId
FROM	SCrm.AccountMemos AS root_hobt
JOIN	SCrm.Accounts	  AS a ON (a.ID = root_hobt.AccountID)
JOIN	SCore.Identities  AS i ON (i.ID = root_hobt.CreatedByUserId)', 82, 74, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (157, 1, 'd961c0f9-32b0-4245-a0a4-20ddf1b18f9d', N'Assets Data Pills', N'SELECT	* FROM SJob.tvf_Assets_DataPills(@Guid, @RowStatus, @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyGuid, @PostCode)  root_hobt  ', 27, 22, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (158, 1, '22934ea5-d5d4-4673-9794-ad7ff963ce8a', N'Enquiry Data Pills', N'SELECT * FROM [SSop].[tvf_Enquiry_DataPills] ( @Guid, @RowStatus, @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyGuid, @PostCode, @ClientAccountGuid, @ClientName, @AgentAccountGuid, @AgentName, @ProjectGuid, @IsSubjectToNDA, @FinanceAccountGuid, @UseClientAsFinance, @ContractGuid, @AgentContractGuid) root_hobt', 83, 75, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SSop', N'tvf_Enquiry_DataPills', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (159, 1, '20507f53-b78a-44bb-81f7-db7693ac031f', N'Enquiries Read', N'SELECT 
	[62A7CA41-57FE-4541-9B7B-64C2BECBD403].Guid AS AgentAccountContactId,
	[C6D3628B-9EF6-46E7-A04B-455D7256E180].Guid AS AgentAccountId,
	[518A2AAD-697B-4134-B39D-20C20B5FCD92].Guid AS AgentAddressId,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentAddressNameNumber,
	root_hobt.AgentAddressPostCode,
	[609B9A6E-F1BE-4A80-BFA8-A66F28E3F29A].Guid AS AgentContactDetailType,
	root_hobt.AgentContactDetailTypeName,
	root_hobt.AgentContactDetailTypeValue,
	root_hobt.AgentContactDisplayName,
	[9B125B55-B220-4023-AA54-BABCDF6AFD1B].Guid AS AgentCountryId,
	[7EA7CAB9-F5BC-4B00-AE06-276E3B772910].Guid AS AgentCountyId,
	root_hobt.AgentName,
	root_hobt.AgentTown,
	root_hobt.ChaseDate1,
	root_hobt.ChaseDate2,
	[CCDDA156-B2D7-4F37-AA9E-1CB98F3C11FD].Guid AS ClientAccountContactId,
	[C1AFB8A2-4596-4C64-8267-7F49B9BE04D6].Guid AS ClientAccountId,
	[3611CED8-53C2-4FA8-9ACC-F508149BC716].Guid AS ClientAddressCountryId,
	[A0DB71C1-2E2B-4559-95E4-9CEBF2F01BA5].Guid AS ClientAddressCountyId,
	[8D6A7C6A-9D55-4C03-82F1-75B6BB5BB3CC].Guid AS ClientAddressId,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientAddressNameNumber,
	root_hobt.ClientAddressPostCode,
	root_hobt.ClientAddressTown,
	[C70D2DDB-45EB-4292-B1E9-2F7F97171CA8].Guid AS ClientContactDetailType,
	root_hobt.ClientContactDetailTypeName,
	root_hobt.ClientContactDetailTypeValue,
	root_hobt.ClientContactDisplayName,
	root_hobt.ClientName,
	root_hobt.ConstructionStageMonths,
	[2B074135-3D54-49A9-ACDE-C82FDB5F9067].Guid AS CreatedByUserId,
	[D020A007-8E39-450B-8575-69D76529659A].Guid AS CurrentProjectRibaStageID,
	root_hobt.Date,
	root_hobt.DeadDate,
	root_hobt.DeclinedToQuoteDate,
	root_hobt.DeclinedToQuoteReason,
	root_hobt.DescriptionOfWorks,
	[DE5A2964-7F7D-4194-962C-11F3FA18DB55].Guid AS EnquirySourceId,
	root_hobt.EnterNewAgentDetails,
	root_hobt.EnterNewClientDetails,
	root_hobt.EnterNewFinanceDetails,
	root_hobt.EnterNewStructureDetails,
	root_hobt.ExpectedProcurementRoute,
	root_hobt.ExternalReference,
	[B7C58113-E763-4B52-82D5-21501514AF8C].Guid AS FinanceAccountId,
	root_hobt.FinanceAccountName,
	[BC7CF205-B05B-41AC-B0CC-E23AEDC459D8].Guid AS FinanceAddressId,
	root_hobt.FinanceAddressLine1,
	root_hobt.FinanceAddressLine2,
	root_hobt.FinanceAddressLine3,
	root_hobt.FinanceAddressNameNumber,
	[302CDB8A-058A-4BEB-9B64-2FC2EACF10D9].Guid AS FinanceContactDetailType,
	root_hobt.FinanceContactDetailTypeName,
	root_hobt.FinanceContactDetailTypeValue,
	root_hobt.FinanceContactDisplayName,
	[02B19759-9D35-447C-9AE2-3C7B9027FEB1].Guid AS FinanceContactId,
	[70FEA0EA-C279-484C-931D-2D23F42D01C3].Guid AS FinanceCountyId,
	root_hobt.FinancePostCode,
	root_hobt.FinanceTown,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsClientFinanceAccount,
	root_hobt.IsReadyForQuoteReview,
	CASE WHEN [9066A2DA-692E-4EFD-A2F0-FF124E2F366E].IsSubjectToNDA = 1 THEN [9066A2DA-692E-4EFD-A2F0-FF124E2F366E].IsSubjectToNDA ELSE root_hobt.IsSubjectToNDA END AS IsSubjectToNDA,
	--root_hobt.IsSubjectToNDA,
	root_hobt.KeyDates,
	root_hobt.Notes,
	root_hobt.Number,
	[1C4B6562-A512-4FC9-85EE-F6A2193EBECE].Guid AS OrganisationalUnitID,
	root_hobt.PreConstructionStageMonths,
	[9066A2DA-692E-4EFD-A2F0-FF124E2F366E].Guid AS ProjectId,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	[C1B43942-F1B0-42DD-8AB7-E1D2C02DFA1B].Guid AS PropertyCountryId,
	[EF3E7956-4ECB-49B0-B930-8DB68D545FFB].Guid AS PropertyCountyId,
	[FE002E4D-3B56-499F-93DA-5D43259CBC76].Guid AS PropertyId,
	root_hobt.PropertyNameNumber,
	root_hobt.PropertyPostCode,
	root_hobt.PropertyTown,
	root_hobt.ProposalLetter,
	root_hobt.QuotingDeadlineDate,
	root_hobt.RibaStage0Months,
	root_hobt.RibaStage1Months,
	root_hobt.RibaStage2Months,
	root_hobt.RibaStage3Months,
	root_hobt.RibaStage4Months,
	root_hobt.RibaStage5Months,
	root_hobt.RibaStage6Months,
	root_hobt.RibaStage7Months,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SendInfoToAgent,
	root_hobt.SendInfoToClient,
	[9264744B-5F58-461B-953B-0C16D80B8FC7].Guid AS SignatoryIdentityId,
	root_hobt.ValueOfWork,
	ClientContract.Guid AS ContractID,
	AgentContract.Guid AS AgentContractID,
	root_hobt.AssetJSONDetails
FROM SSop.Enquiries AS root_hobt 
JOIN SCrm.Accounts AS [C6D3628B-9EF6-46E7-A04B-455D7256E180] ON ([C6D3628B-9EF6-46E7-A04B-455D7256E180].ID = root_hobt.AgentAccountId) 
 JOIN SCrm.AccountAddresses AS [518A2AAD-697B-4134-B39D-20C20B5FCD92] ON ([518A2AAD-697B-4134-B39D-20C20B5FCD92].ID = root_hobt.AgentAddressId) 
 JOIN SCrm.Countries AS [9B125B55-B220-4023-AA54-BABCDF6AFD1B] ON ([9B125B55-B220-4023-AA54-BABCDF6AFD1B].ID = root_hobt.AgentCountryId) 
 JOIN SCrm.Counties AS [7EA7CAB9-F5BC-4B00-AE06-276E3B772910] ON ([7EA7CAB9-F5BC-4B00-AE06-276E3B772910].ID = root_hobt.AgentCountyId) 
 JOIN SCrm.Accounts AS [C1AFB8A2-4596-4C64-8267-7F49B9BE04D6] ON ([C1AFB8A2-4596-4C64-8267-7F49B9BE04D6].ID = root_hobt.ClientAccountId) 
 JOIN SCrm.Countries AS [3611CED8-53C2-4FA8-9ACC-F508149BC716] ON ([3611CED8-53C2-4FA8-9ACC-F508149BC716].ID = root_hobt.ClientAddressCountryId) 
 JOIN SCrm.Counties AS [A0DB71C1-2E2B-4559-95E4-9CEBF2F01BA5] ON ([A0DB71C1-2E2B-4559-95E4-9CEBF2F01BA5].ID = root_hobt.ClientAddressCountyId) 
 JOIN SCrm.AccountAddresses AS [8D6A7C6A-9D55-4C03-82F1-75B6BB5BB3CC] ON ([8D6A7C6A-9D55-4C03-82F1-75B6BB5BB3CC].ID = root_hobt.ClientAddressId) 
 JOIN SCore.Identities AS [2B074135-3D54-49A9-ACDE-C82FDB5F9067] ON ([2B074135-3D54-49A9-ACDE-C82FDB5F9067].ID = root_hobt.CreatedByUserId) 
 JOIN SJob.RibaStages AS [D020A007-8E39-450B-8575-69D76529659A] ON ([D020A007-8E39-450B-8575-69D76529659A].ID = root_hobt.CurrentProjectRibaStageID) 
 JOIN SCore.OrganisationalUnits AS [1C4B6562-A512-4FC9-85EE-F6A2193EBECE] ON ([1C4B6562-A512-4FC9-85EE-F6A2193EBECE].ID = root_hobt.OrganisationalUnitID) 
 JOIN SCrm.Countries AS [C1B43942-F1B0-42DD-8AB7-E1D2C02DFA1B] ON ([C1B43942-F1B0-42DD-8AB7-E1D2C02DFA1B].ID = root_hobt.PropertyCountryId) 
 JOIN SCrm.Counties AS [EF3E7956-4ECB-49B0-B930-8DB68D545FFB] ON ([EF3E7956-4ECB-49B0-B930-8DB68D545FFB].ID = root_hobt.PropertyCountyId) 
 JOIN SJob.Assets AS [FE002E4D-3B56-499F-93DA-5D43259CBC76] ON ([FE002E4D-3B56-499F-93DA-5D43259CBC76].ID = root_hobt.PropertyId) 
 JOIN SSop.QuoteSources AS [DE5A2964-7F7D-4194-962C-11F3FA18DB55] ON ([DE5A2964-7F7D-4194-962C-11F3FA18DB55].ID = root_hobt.EnquirySourceId) 
 JOIN SCrm.AccountContacts AS [62A7CA41-57FE-4541-9B7B-64C2BECBD403] ON ([62A7CA41-57FE-4541-9B7B-64C2BECBD403].ID = root_hobt.AgentAccountContactId) 
 JOIN SCrm.AccountContacts AS [CCDDA156-B2D7-4F37-AA9E-1CB98F3C11FD] ON ([CCDDA156-B2D7-4F37-AA9E-1CB98F3C11FD].ID = root_hobt.ClientAccountContactId) 
 JOIN SSop.Projects AS [9066A2DA-692E-4EFD-A2F0-FF124E2F366E] ON ([9066A2DA-692E-4EFD-A2F0-FF124E2F366E].ID = root_hobt.ProjectId) 
 JOIN SCrm.Accounts AS [B7C58113-E763-4B52-82D5-21501514AF8C] ON ([B7C58113-E763-4B52-82D5-21501514AF8C].ID = root_hobt.FinanceAccountId) 
 JOIN SCrm.AccountAddresses AS [BC7CF205-B05B-41AC-B0CC-E23AEDC459D8] ON ([BC7CF205-B05B-41AC-B0CC-E23AEDC459D8].ID = root_hobt.FinanceAddressId) 
 JOIN SCrm.AccountContacts AS [02B19759-9D35-447C-9AE2-3C7B9027FEB1] ON ([02B19759-9D35-447C-9AE2-3C7B9027FEB1].ID = root_hobt.FinanceContactId) 
 JOIN SCrm.Counties AS [70FEA0EA-C279-484C-931D-2D23F42D01C3] ON ([70FEA0EA-C279-484C-931D-2D23F42D01C3].ID = root_hobt.FinanceCountyId) 
 JOIN SCore.Identities AS [9264744B-5F58-461B-953B-0C16D80B8FC7] ON ([9264744B-5F58-461B-953B-0C16D80B8FC7].ID = root_hobt.SignatoryIdentityId) 
 JOIN SCrm.ContactDetailTypes AS [C70D2DDB-45EB-4292-B1E9-2F7F97171CA8] ON ([C70D2DDB-45EB-4292-B1E9-2F7F97171CA8].ID = root_hobt.ClientContactDetailType) 
 JOIN SCrm.ContactDetailTypes AS [609B9A6E-F1BE-4A80-BFA8-A66F28E3F29A] ON ([609B9A6E-F1BE-4A80-BFA8-A66F28E3F29A].ID = root_hobt.AgentContactDetailType) 
 JOIN SCrm.ContactDetailTypes AS [302CDB8A-058A-4BEB-9B64-2FC2EACF10D9] ON ([302CDB8A-058A-4BEB-9B64-2FC2EACF10D9].ID = root_hobt.FinanceContactDetailType) 
 JOIN SSop.Contracts AS ClientContract ON (ClientContract.ID = root_hobt.ContractID)
 JOIN SSop.Contracts AS AgentContract ON  (AgentContract.ID = root_hobt.AgentContractID)
', 83, 75, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'Enquiries', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (160, 1, '64b03f27-756c-45aa-ac98-275662ffc669', N'[SSop].[EnquiriesUpsert]', N'EXEC [SSop].[EnquiriesUpsert]  
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@Date = @Date, 
	@CreatedByUserGuid = @CreatedByUserGuid, 
	@PropertyGuid = @PropertyGuid, 
	@PropertyNameNumber = @PropertyNameNumber, 
	@PropertyAddressLine1 = @PropertyAddressLine1, 
	@PropertyAddressLine2 = @PropertyAddressLine2, 
	@PropertyAddressLine3 = @PropertyAddressLine3, 
	@PropertyCountyGuid = @PropertyCountyGuid, 
	@PropertyPostCode = @PropertyPostCode, 
	@PropertyCountryGuid = @PropertyCountryGuid, 
	@ClientAccountGuid = @ClientAccountGuid, 
	@ClientAddressGuid = @ClientAddressGuid, 
	@ClientAccountContactGuid = @ClientAccountContactGuid, 
	@ClientName = @ClientName, 
	@ClientAddressNameNumber = @ClientAddressNameNumber, 
	@ClientAddressLine1 = @ClientAddressLine1, 
	@ClientAddressLine2 = @ClientAddressLine2, 
	@ClientAddressLine3 = @ClientAddressLine3, 
	@ClientAddressCountyGuid = @ClientAddressCountyGuid, 
	@ClientAddressPostCode = @ClientAddressPostCode, 
	@ClientAddressCountryGuid = @ClientAddressCountryGuid, 
	@AgentAccountGuid = @AgentAccountGuid, 
	@AgentAddressGuid = @AgentAddressGuid, 
	@AgentAccountContactGuid = @AgentAccountContactGuid, 
	@AgentName = @AgentName, 
	@AgentAddressNameNumber = @AgentAddressNameNumber, 
	@AgentAddressLine1 = @AgentAddressLine1, 
	@AgentAddressLine2 = @AgentAddressLine2, 
	@AgentAddressLine3 = @AgentAddressLine3, 
	@AgentAddressCountyGuid = @AgentAddressCountyGuid, 
	@AgentAddressPostCode = @AgentAddressPostCode, 
	@AgentAddressCountryGuid = @AgentAddressCountryGuid, 
	@DescriptionOfWorks = @DescriptionOfWorks, 
	@ValueOfWork = @ValueOfWork, 
	@CurrentProjectRobaStageGuid = @CurrentProjectRobaStageGuid, 
	@RibaStage0Months = @RibaStage0Months, 
	@RibaStage1Months = @RibaStage1Months, 
	@RibaStage2Months = @RibaStage2Months, 
	@RibaStage3Months = @RibaStage3Months, 
	@RibaStage4Months = @RibaStage4Months, 
	@RibaStage5Months = @RibaStage5Months, 
	@RibaStage6Months = @RibaStage6Months, 
	@RibaStage7Months = @RibaStage7Months, 
	@PreConstructionStageMonths = @PreConstructionStageMonths, 
	@ConstructionStageMonths = @ConstructionStageMonths, 
	@SendInfoToClient = @SendInfoToClient, 
	@SendInfoToAgent = @SendInfoToAgent, 
	@KeyDates = @KeyDates, 
	@ExpectedProcurementRoute = @ExpectedProcurementRoute, 
	@Notes = @Notes, 
	@EnquirySourceGuid = @EnquirySourceGuid, 
	@IsReadyForQuoteReview = @IsReadyForQuoteReview, 
	@QuotingDeadlineDate = @QuotingDeadlineDate, 
	@DeclinedToQuoteDate = @DeclinedToQuoteDate, 
	@DeclinedToQuoteReason = @DeclinedToQuoteReason, 
	@ExternalReference = @ExternalReference, 
	@ProjectGuid = @ProjectGuid, 
	@IsSubjectToNDA = @IsSubjectToNDA, 
	@DeadDate = @DeadDate, 
	@ChaseDate1 = @ChaseDate1, 
	@ChaseDate2 = @ChaseDate2, 
	@FinanceAccountGuid = @FinanceAccountGuid, 
	@FinanceAddressGuid = @FinanceAddressGuid, 
	@FinanceContactGuid = @FinanceContactGuid, 
	@FinanceAccountName = @FinanceAccountName, 
	@FinanceAddressNameNumber = @FinanceAddressNameNumber, 
	@FinanceAddressLine1 = @FinanceAddressLine1, 
	@FinanceAddressLine2 = @FinanceAddressLine2, 
	@FinanceAddressLine3 = @FinanceAddressLine3, 
	@FinanceCountyGuid = @FinanceCountyGuid, 
	@FinancePostCode = @FinancePostCode, 
	@EnterNewClientDetails = @EnterNewClientDetails, 
	@EnterNewAgentDetails = @EnterNewAgentDetails, 
	@EnterNewFinanceDetails = @EnterNewFinanceDetails, 
	@EnterNewStructureDetails = @EnterNewStructureDetails, 
	@IsClientFinanceAccount = @IsClientFinanceAccount, 
	@SignatoryIdentityGuid = @SignatoryIdentityGuid, 
	@ProposalLetter = @ProposalLetter, 
	@Guid = @Guid,
        @ClientContactDisplayName = @ClientContactDisplayName,
        @ClientContactDetailTypeGuid = @ClientContactDetailTypeGuid,
        @ClientContactDetailTypeName = @ClientContactDetailTypeName,
        @ClientContactDetailTypeValue = @ClientContactDetailTypeValue,
        @AgentContactDisplayName = @AgentContactDisplayName,
        @AgentContactDetailTypeGuid= @AgentContactDetailTypeGuid,
        @AgentContactDetailTypeName = @AgentContactDetailTypeName,
        @AgentContactDetailTypeValue = @AgentContactDetailTypeValue,
        @FinanceContactDisplayName = @FinanceContactDisplayName,
        @FinanceContactDetailTypeGuid = @FinanceContactDetailTypeGuid,
        @FinanceContactDetailTypeName = @FinanceContactDetailTypeName,
        @FinanceContactDetailTypeValue = @FinanceContactDetailTypeValue,
        @ContractGuid = @ContractGuid,
        @AgentContractGuid = @AgentContractGuid,
        @AssetJSONDetails = @AssetJSONDetails

', 83, 75, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiriesUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (161, 1, '96cc8f3c-5b38-447d-8940-f3224d71eaf2', N'Enquiries Validate', N'SELECT * FROM [SSop].[tvf_EnquiriesValidate] ( @Guid, @RowStatus, @PropertyGuid, @ClientAccountGuid, @ClientAddressGuid, @AgentAccountGuid, @AgentAddressGuid, @FinanceAccountGuid, @FinanceAddressGuid, @IsReadyForQuoteReview, @DescriptionOfWorks, @ValueOfWork, @CurrentProjectRibaStageGuid, @PropertyNumber, @PropertyPostCode, @ClientAddressNumber, @ClientAddressPostCode, @AgentAddressNumber, @AgentAddressPostCode, @AgentName, @ClientName, @DeclinedToQuoteDate, @DeclinedToQuoteReason, @KeyDates, @DeadDate, @EnterNewClientDetails, @EnterNewAgentDetails, @EnterNewFinanceDetails, @EnterNewStructureDetails, @IsClientFinanceAccount, @ProjectGuid, @ClientContactDisplayName, @AgentContactDisplayName, @FinanceContactDisplayName, @ClientContactDetailType, @ClientContactDetailTypeName, @ClientContactDetailTypeValue, @AgentContactDetailType, @AgentContactDetailTypeName, @AgentContactDetailTypeValue, @FinanceContactDetailType, @FinanceContactDetailTypeName, @FinanceContactDetailTypeValue, @ContractGuid, @AgentContractGuid) root_hobt', 83, 75, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SSop', N'tvf_EnquiriesValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (162, 1, 'e57cf9b0-9c57-424e-acec-a81f9258b1fc', N'Record History Read', N'SELECT	root_hobt.ID,
		root_hobt.SchemaName,
		root_hobt.TableName,
		root_hobt.ColumnName,
		root_hobt.RowID,
		root_hobt.Datetime,
		i.Guid AS UserID,
		root_hobt.SQLUser,
		root_hobt.PreviousValue,
		root_hobt.NewValue,
		ep.Guid AS EntityPropertyID,
		root_hobt.Guid,
		root_hobt.RowVersion,
		root_hobt.RowStatus,
		root_hobt.RowGuid
FROM	SCore.RecordHistory root_hobt
JOIN	SCore.Identities i ON (i.ID = root_hobt.UserID)
JOIN	SCore.EntityProperties ep ON (ep.ID = root_hobt.EntityPropertyID)', 85, 77, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (163, 1, '474ee71c-7b65-4281-b42c-9685d8c4dd90', N'Identities Read', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.FullName,
        root_hobt.EmailAddress,
        root_hobt.UserGuid,
        root_hobt.JobTitle,
        root_hobt.IsActive,
        root_hobt.BillableRate,
        root_hobt.Signature,
        ou.Guid AS OriganisationalUnitId,
        c.Guid  AS ContactId
FROM
        SCore.Identities root_hobt
JOIN
        SCore.OrganisationalUnits ou ON (ou.ID = root_hobt.OriganisationalUnitId)
JOIN
        SCrm.Contacts c ON root_hobt.ContactId = c.ID', 42, 40, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (164, 1, '013eb93c-4eee-4539-9e1f-2920dc863ef5', N'[SCore].[IdentityUpsert]', N'EXEC [SCore].[IdentityUpsert]  @FullName = @FullName, @EmailAddress = @EmailAddress, @JobTitle = @JobTitle, @OrganisationalUnitGuid = @OrganisationalUnitGuid, @IsActive = @IsActive, @ContactGuid = @ContactGuid, @BillableRate = @BillableRate, @Guid = @Guid', 42, 40, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'IdentityUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (165, 1, '4d7496d2-b3fc-4ff6-85e5-13dacb5d2cb1', N'Assets Delete', N'EXEC SJob.AssetsDelete @Guid = @Guid', 27, 22, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (166, 1, '6b7ad60d-e02d-434a-9a15-0468340f8bcc', N'Object Security Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.ObjectGuid,
		i.Guid AS UserId,
		g.Guid AS GroupId,
		root_hobt.CanRead,
		root_hobt.DenyRead,
		root_hobt.CanWrite,
		root_hobt.DenyWrite
FROM	SCore.ObjectSecurity root_hobt
JOIN	SCore.Identities i ON (i.ID = root_hobt.UserId)
JOIN	SCore.Groups g ON (g.ID = root_hobt.GroupId)', 86, 78, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (167, 1, '226e4956-b9a6-411b-8511-e727d70d646b', N'[SCore].[ObjectSecurityUpsert]', N'EXEC [SCore].[ObjectSecurityUpsert]  @ObjectGuid = @ObjectGuid, @UserGuid = @UserGuid, @GroupGuid = @GroupGuid, @CanRead = @CanRead, @DenyRead = @DenyRead, @CanWrite = @CanWrite, @DenyWrite = @DenyWrite, @Guid = @Guid', 86, 78, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (168, 1, 'a29228dd-75d9-4e97-8c62-93715f7bd31b', N'Job Milestones Validate', N'SELECT * FROM [SJob].[tvf_JobMilestonesValidate] ( @MilestoneTypeGuid, @Guid) root_hobt', 33, 30, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SJob', N'tvf_JobMilestonesValidate', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (169, 1, '97064c41-349b-49e7-ab8c-3221a7142ff2', N'Enquiry Create Quote', N'EXEC SSop.EnquiryCreateQuotes @Guid = @Guid	-- uniqueidentifier', 83, 75, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (170, 1, 'abf795bd-f950-4e91-bf24-8e704d855f38', N'Enquiry Services Read', N'SELECT 
	[8AA3EE8C-0AA8-4F1B-8C84-A3048A45936F].Guid AS EndRibaStageId
,	[1C74EDD6-BB3C-4C47-BCEF-EDE008AABD2F].Guid AS EnquiryId
,	root_hobt.Guid
,	root_hobt.ID
,	[75B5C70B-C121-4A6F-A632-2502321E9933].Guid AS JobTypeId
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	[036A7B03-4083-4695-A6AE-64D5F5C2C430].Guid AS StartRibaStageId

FROM SSop.EnquiryServices AS root_hobt 
JOIN SJob.RibaStages AS [8AA3EE8C-0AA8-4F1B-8C84-A3048A45936F] ON ([8AA3EE8C-0AA8-4F1B-8C84-A3048A45936F].ID = root_hobt.EndRibaStageId) 
 JOIN SSop.Enquiries AS [1C74EDD6-BB3C-4C47-BCEF-EDE008AABD2F] ON ([1C74EDD6-BB3C-4C47-BCEF-EDE008AABD2F].ID = root_hobt.EnquiryId) 
 JOIN SJob.JobTypes AS [75B5C70B-C121-4A6F-A632-2502321E9933] ON ([75B5C70B-C121-4A6F-A632-2502321E9933].ID = root_hobt.JobTypeId) 
 JOIN SJob.RibaStages AS [036A7B03-4083-4695-A6AE-64D5F5C2C430] ON ([036A7B03-4083-4695-A6AE-64D5F5C2C430].ID = root_hobt.StartRibaStageId) 
', 84, 76, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryServices', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (171, 1, 'e8719efb-d386-427f-b356-e12c5db10058', N'[SSop].[EnquiryServicesUpsert]', N'EXEC [SSop].[EnquiryServicesUpsert ]  @EnquiryGuid = @EnquiryGuid, @StartRibaStageGuid = @StartRibaStageGuid, @EndRibaStageGuid = @EndRibaStageGuid, @JobTypeGuid = @JobTypeGuid, @Guid = @Guid', 84, 76, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryServicesUpsert ', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (172, 1, 'a3ae9d2d-82f4-4ca6-9a68-790426c04a5a', N'Job Purpose Groups Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		j.Guid AS JobID,
		pg.Guid AS PurposeGroupID
FROM	SJob.JobPurposeGroups root_hobt
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
JOIN	SJob.PurposeGroups pg ON (pg.ID = root_hobt.PurposeGroupID)', 46, 44, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (173, 1, 'ea12c88b-0f5f-4c8b-bdd6-8ba29856b9b6', N'Job Purpose Groups Delete', N'[SJob].[JobPurposeGroupsDelete] @Guid = @Guid', 46, 44, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (174, 1, '189900b3-465b-4753-ab8d-750cbb27806e', N'Actions Delete', N'EXEC [SJob].[ActionsDelete] @Guid = @Guid', 43, 41, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (175, 1, 'c4b77179-e023-4679-9c81-bf31be0aba44', N'Activities Delete', N'EXEC [SJob].[ActivityDelete] @Guid = @Guid', 30, 25, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (176, 1, '975ff0cd-e10d-43ef-b460-4fa33942a7cd', N'Milestones Delete', N'EXEC [SJob].[MilestonesDelete]  @Guid = @Guid', 33, 30, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SJob', N'MilestonesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (177, 1, 'c335201d-da6f-4a19-9c3d-f01e98de17cf', N'Accounts Delete', N'EXEC SCrm.AccountsDelete @Guid = @Guid	', 15, 15, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (178, 1, '7fea2fc9-f7c2-4918-8699-416cac391526', N'Account Addresses Delete', N'EXEC SCrm.AccountAddressesDelete @Guid = @Guid	', 16, 35, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (179, 1, '85deb325-bca3-4e2c-96b5-2c4fc74f435b', N'Account Contacts Delete', N'EXEC SCrm.AccountContactsDelete @Guid = @Guid	', 17, 36, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (180, 1, '9ce8bf23-7321-4338-9cea-dadb455f830d', N'Contacts Delete', N'EXEC SCrm.ContactsDelete @Guid = @Guid	', 25, 20, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (181, 1, '12a66d31-4482-4faf-9d32-19fcbce42939', N'Contact Details Delete', N'EXEC SCrm.ContactDetailsDelete @Guid = @Guid	', 22, 17, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (182, 1, '2bf6f64f-e953-43ad-94bd-4a8af8cd016d', N'Enquiry Services Delete', N'EXEC SSop.EnquiryServicesDelete @Guid = @Guid	-- uniqueidentifier
', 84, 76, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (183, 1, '0910d848-6f46-46cf-a62b-e3752887e664', N'Account Memos Delete', N'EXECUTE SCrm.AccountMemosDelete @Guid = @Guid', 82, 74, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (184, 1, '4f223a38-e62f-4456-b0c4-9fdced9e8e08', N'Addresses Delete', N'EXECUTE SCrm.AddressesDelete @Guid = @Guid	-- uniqueidentifier
', 18, 16, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (185, 1, '2c903be2-2ae0-4de6-8186-a855ac727bf3', N'Contracts Delete', N'EXECUTE SSop.ContractsDelete @Guid = @Guid', 50, 47, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (186, 1, '0924ed39-3516-465b-8f77-4e1367f35854', N'Entity Properties Delete', N'EXECUTE SCore.EntityPropertiesDelete  @Guid = @Guid	', 6, 6, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (187, 1, '3f0a27db-187e-463b-ace6-3604ec40aba6', N'Entity Query Parameters Delete', N'EXECUTE SCore.EntityQueryParametersDelete  @Guid = @Guid	-- uniqueidentifier
', 8, 8, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (188, 1, '7dfa1460-e968-44c8-b258-fb460a6be329', N'Transaction Details Read', N'SELECT
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		t.Guid AS TransactionID,
		m.Guid AS MilestoneID,
		a.Guid AS ActivityID,
		jps.Guid AS JobPaymentStageId,
		root_hobt.Net,
		root_hobt.Vat,
		root_hobt.Gross,
		root_hobt.VatRate,
		root_hobt.Description,
		root_hobt.LegacyId
FROM
		SFin.TransactionDetails root_hobt
JOIN
		SFin.Transactions t ON (t.ID = root_hobt.TransactionID)
JOIN
		SJob.Milestones m ON (m.ID = root_hobt.MilestoneID)
JOIN
		SJob.Activities a ON (a.ID = root_hobt.ActivityID)
JOIN	
		SJob.JobPaymentStages jps ON jps.ID = root_hobt.JobPaymentStageId', 38, 34, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (189, 1, '9974091a-e67f-4cc3-9c3d-105da09cd773', N'Transaction Details Upsert', N'EXEC [SFin].[TransactionDetailsUpsert]  @TransactionGuid = @TransactionGuid, @MilestoneGuid = @MilestoneGuid, @ActivityGuid = @ActivityGuid, @Net = @Net, @Vat = @Vat, @Gross = @Gross, @VatRate = @VatRate, @Description = @Description, @JobPaymentStageGuid = @JobPaymentStageGuid, @Guid = @Guid', 38, 34, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'TransactionDetailsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (190, 1, 'f9e20c7c-33d5-4f7e-860e-a9a5cf96dadb', N'CDM Merge Info Read', N'SELECT 
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.AgreedFee,
	root_hobt.AppointedJobType,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.ConstructionStageFee,
	root_hobt.CPPReviewed,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.JobDescription,
	root_hobt.JobIDString,
	root_hobt.JobNumber,
	root_hobt.JobType,
	root_hobt.LocalAuthority,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.ParentGuid,
	root_hobt.PCII,
	root_hobt.PreConstructionStageFee,
	root_hobt.PrincipalContractorAddress,
	root_hobt.PrincipalContractorEmail,
	root_hobt.PrincipalContractorMobile,
	root_hobt.PrincipalContractorName,
	root_hobt.PrincipalContractorPhone,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.RibaStage1Fee,
	root_hobt.RibaStage2Fee,
	root_hobt.RibaStage3Fee,
	root_hobt.RibaStage4Fee,
	root_hobt.RibaStage5Fee,
	root_hobt.RibaStage6Fee,
	root_hobt.RibaStage7Fee,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SiteCompletionDate,
	root_hobt.SiteStartDate,
	root_hobt.StrategyLastUpdated,
	root_hobt.SurveyorEmail,
	root_hobt.SurveyorInitials,
	root_hobt.SurveyorJobTitle,
	root_hobt.SurveyorName,
	root_hobt.SurveyorPostNominals,
	root_hobt.TotalNetFee,
	root_hobt.UPRN,
	root_hobt.WrittenAppointmentDate
FROM SJob.Job_CDMMergeInfo AS root_hobt 
', 72, 67, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'Job_CDMMergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (191, 1, 'bb5307d0-ad65-4d7d-ae4f-37e7034a26ad', N'Quote Merge Info', N'SELECT 
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.Construction,
	root_hobt.FeeCap,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.PreConstruction,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.QuoteDate,
	root_hobt.QuoteNumber,
	root_hobt.QuoteOverview,
	root_hobt.QuotingConsultantEmail,
	root_hobt.QuotingConsultantInitials,
	root_hobt.QuotingConsultantJobTitle,
	root_hobt.QuotingConsultantName,
	root_hobt.QuotingConsultantPostNominals,
	root_hobt.QuotingUserEmail,
	root_hobt.QuotingUserInitials,
	root_hobt.QuotingUserJobTitle,
	root_hobt.QuotingUserName,
	root_hobt.QuotingUserPostNominals,
	root_hobt.RecipientAddress,
	root_hobt.RecipientAddressBlock,
	root_hobt.RecipientAddressLine1,
	root_hobt.RecipientAddressLine2,
	root_hobt.RecipientAddressLine3,
	root_hobt.RecipientCompanyRegNo,
	root_hobt.RecipientContactName,
	root_hobt.RecipientCounty,
	root_hobt.RecipientEmail,
	root_hobt.RecipientFirstName,
	root_hobt.RecipientMobile,
	root_hobt.RecipientName,
	root_hobt.RecipientPhone,
	root_hobt.RecipientPostcode,
	root_hobt.RecipientSurname,
	root_hobt.RecipientTown,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Stage1Net,
	root_hobt.Stage2Net,
	root_hobt.Stage3Net,
	root_hobt.Stage4Net,
	root_hobt.Stage5Net,
	root_hobt.Stage6Net,
	root_hobt.Stage7Net,
	root_hobt.TotalNetFees,
	root_hobt.UPRN,
	root_hobt.AgentAccountName,
	root_hobt.AgentContact,
	root_hobt.AgentAddressLineOne,
	root_hobt.AgentAddressLineTwo,
	root_hobt.AgentAddressLineThree,
	root_hobt.AgentPostcode,
	root_hobt.ClientAccountName,
	root_hobt.ClientContact,
	root_hobt.ClientAddressLineOne,
	root_hobt.ClientAddressLineTwo,
	root_hobt.ClientAddressLineThree

FROM SSop.Quote_MergeInfo AS root_hobt 
', 88, 80, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'Quote_MergeInfo', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (192, 1, '0f6184d4-37bf-4319-a1aa-2cd14fab5c5c', N'Fee Amendments Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		j.Guid AS JobID,
		i.Guid AS CreatedByUserID,
		root_hobt.CreatedDateTime,
		root_hobt.RibaStage0Change,
		root_hobt.RibaStage1Change,
		root_hobt.RibaStage2Change,
		root_hobt.RibaStage3Change,
		root_hobt.RibaStage4Change,
		root_hobt.RibaStage5Change,
		root_hobt.RibaStage6Change,
		root_hobt.RibaStage7Change,

		-- VISIT CHANGES
        root_hobt.RibaStage0VisitChange,
        root_hobt.RibaStage1VisitChange,
		root_hobt.RibaStage2VisitChange,
		root_hobt.RibaStage3VisitChange,
		root_hobt.RibaStage4VisitChange,
		root_hobt.RibaStage5VisitChange,
		root_hobt.RibaStage6VisitChange,
		root_hobt.RibaStage7VisitChange,

		--MEETING CHANGES
        root_hobt.RibaStage0MeetingChange,
        root_hobt.RibaStage1MeetingChange,
		root_hobt.RibaStage2MeetingChange,
		root_hobt.RibaStage3MeetingChange,
		root_hobt.RibaStage4MeetingChange,
		root_hobt.RibaStage5MeetingChange,
		root_hobt.RibaStage6MeetingChange,
		root_hobt.RibaStage7MeetingChange,

		
		root_hobt.PreConstructionStageChange,
		root_hobt.ConstructionStageChange,
		-- PRE + CONSTRUCTION CHANGES
		root_hobt.PreConstructionStageMeetingChange,
		root_hobt.PreConstructionStageVisitChange,
		root_hobt.ConstructionStageMeetingChange,
		root_hobt.ConstructionStageVisitChange,

		root_hobt.FeeCapChange
FROM	SJob.FeeAmendment root_hobt
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
JOIN	SCore.Identities i ON (i.ID = root_hobt.CreatedByUserID)', 89, 81, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (193, 1, '680b7bcf-45ad-4f55-b3a5-7161ca89c879', N'Fee Amendments Upsert', N'EXEC SJob.FeeAmendmentsUpsert @JobGuid = @JobGuid,			-- uniqueidentifier
							  @RibaStage0Change = @RibaStage0Change, -- decimal(9, 2)
							  @RibaStage1Change = @RibaStage1Change, -- decimal(9, 2)
							  @RibaStage2Change = @RibaStage2Change, -- decimal(9, 2)
							  @RibaStage3Change = @RibaStage3Change, -- decimal(9, 2)
							  @RibaStage4Change = @RibaStage4Change, -- decimal(9, 2)
							  @RibaStage5Change = @RibaStage5Change, -- decimal(9, 2)
							  @RibaStage6Change = @RibaStage6Change, -- decimal(9, 2)
							  @RibaStage7Change = @RibaStage7Change, -- decimal(9, 2)
                                                          
                                                           -- Visits
                                                          @RibaStage0VisitChange = @RibaStage0VisitChange, -- decimal(9, 2)
							  @RibaStage1VisitChange = @RibaStage1VisitChange, -- decimal(9, 2)
							  @RibaStage2VisitChange = @RibaStage2VisitChange, -- decimal(9, 2)
							  @RibaStage3VisitChange = @RibaStage3VisitChange, -- decimal(9, 2)
							  @RibaStage4VisitChange = @RibaStage4VisitChange, -- decimal(9, 2)
							  @RibaStage5VisitChange = @RibaStage5VisitChange, -- decimal(9, 2)
							  @RibaStage6VisitChange = @RibaStage6VisitChange, -- decimal(9, 2)
							  @RibaStage7VisitChange = @RibaStage7VisitChange, -- decimal(9, 2)

                                                           -- Meetings
                                                          @RibaStage0MeetingChange = @RibaStage0MeetingChange, -- decimal(9, 2)
							  @RibaStage1MeetingChange = @RibaStage1MeetingChange, -- decimal(9, 2)
							  @RibaStage2MeetingChange = @RibaStage2MeetingChange, -- decimal(9, 2)
							  @RibaStage3MeetingChange = @RibaStage3MeetingChange, -- decimal(9, 2)
							  @RibaStage4MeetingChange = @RibaStage4MeetingChange, -- decimal(9, 2)
							  @RibaStage5MeetingChange = @RibaStage5MeetingChange, -- decimal(9, 2)
							  @RibaStage6MeetingChange = @RibaStage6MeetingChange, -- decimal(9, 2)
							  @RibaStage7MeetingChange = @RibaStage7MeetingChange, -- decimal(9, 2)

							  @PreConstructionStageChange = @PreConstructionStageChange,
							  @ConstructionStageChange = @ConstructionStageChange,

                                                           -- construction + preconstruction
                                                            @PreConstructionStageMeetingChange = @PreConstructionStageMeetingChange,
			                                    @PreConstructionStageVisitChange = @PreConstructionStageVisitChange,
			                                   @ConstructionStageMeetingChange = @ConstructionStageMeetingChange,
			                                   @ConstructionStageVisitChange =  @ConstructionStageVisitChange,
							  @FeeCapChange = @FeeCapChange,		-- decimal(9, 2)
							  @Guid = @Guid				-- uniqueidentifier
', 89, 81, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (194, 1, '3e527fed-fda4-41c3-aac4-0bbb4fb6328b', N'Quote Sections Delete', N'EXEC SSop.QuoteSectionsDelete @Guid = @Guid ', 56, 53, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (195, 1, '0c289977-c603-44fe-ad6a-3d80de49f03a', N'Quote Items Delete', N'EXEC SSop.QuoteItemsDelete @Guid = @Guid', 58, 55, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (196, 1, '50764f6c-c7e4-4804-9b62-fb13c6189a3c', N'Contact Details Delete', N'EXEC SCrm.ContactDetailsDelete @Guid = @Guid', 23, 17, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (197, 1, '4fdb2db0-8511-4a62-a6b5-7b7cdfd8a877', N'Enquiry Services Ext Validate', N'SELECT * FROM [SSop].[tvf_EnquiryServicesValidate] ( @QuoteGuid, @Guid, @DeclinedToQuoteDate) root_hobt', 84, 123, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SSop', N'tvf_EnquiryServicesValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (198, 1, '4e863e70-f4fd-41b9-b514-3b2a1a87be94', N'Sage Exports Read', N'SELECT 
	root_hobt.ExportData,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.InclusiveToDate,
	[B8FDEE6F-A71B-41E6-B098-8544D714FC7E].Guid AS OrganisationalUnitId,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SFin.SageExports AS root_hobt 
JOIN SCore.OrganisationalUnits AS [B8FDEE6F-A71B-41E6-B098-8544D714FC7E] ON ([B8FDEE6F-A71B-41E6-B098-8544D714FC7E].ID = root_hobt.OrganisationalUnitId) 
', 90, 82, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'SageExports', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (199, 1, 'c65989c5-a515-4c9b-9c1d-a65a0393669c', N'Sage Exports Upsert', N'EXEC [SFin].[TransactionExportsToSageUpsert]  
	@InclusiveToDate = @InclusiveToDate, 
	@OrganisationalUnitGuid = @OrganisationalUnitGuid, 
	@Guid = @Guid', 90, 82, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'TransactionExportsToSageUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (200, 1, 'e328c6ea-120f-4582-9177-b1ee810b9013', N'Sage Exports Validate', N'SELECT * FROM [SFin].[SageExportsValidate] ( @Guid) root_hobt', 90, 82, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (201, 1, '3a0afae8-d2a3-4aa7-89e5-048239399c46', N'Transactions Validate', N'SELECT * FROM [SFin].[TransactionsValidate] ( @Guid, @AccountGuid, @TransactionTypeGuid) root_hobt', 37, 33, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (202, 1, '73298d5e-8c4f-421a-b3a2-6bb8ce3137bd', N'Job Extended Info Read', N'SELECT	root_hobt.Id,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.QuoteGuid
FROM	[SJob].[Job_ExtendedInfo] root_hobt', 9, 83, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (203, 1, '441469ab-14c9-4722-a8d0-4e70114f67e1', N'Finance Memo Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.LegacyId,
		t.Guid	 AS TransactionID,
		a.Guid	 AS AccountID,
		j.Guid	 AS JobID,
		root_hobt.Memo,
		root_hobt.CreatedDateTimeUTC,
		i.guid  AS CreatedByUserId
FROM	SFin.FinanceMemo  AS root_hobt
JOIN	SFin.Transactions AS t ON (t.ID = root_hobt.TransactionID)
JOIN	SCrm.Accounts	  AS a ON (a.ID = root_hobt.AccountID)
JOIN	SJob.Jobs		  AS j ON (j.ID = root_hobt.JobID)
JOIN	SCore.Identities  AS i ON (i.ID = root_hobt.CreatedByUserID)', 91, 84, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (204, 1, 'e96756d7-4540-491b-8ef3-ec0de554535d', N'Finance Memo Upsert', N'EXEC SFin.FinanceMemoUpsert @AccountGuid = @AccountGuid,		-- uniqueidentifier
							@JobGuid = @JobGuid,			-- uniqueidentifier
							@TransactionGuid = @TransactionGuid,	-- uniqueidentifier
							@Memo = @Memo,				-- nvarchar(max)
							@UserGuid = @UserGuid,			-- uniqueidentifier
							@Guid = @Guid				-- uniqueidentifier

', 91, 84, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (205, 1, '24b781db-0dad-417a-82d1-8d2620580a23', N'Account Merge Batch Read ', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		sa.Guid AS SourceAccountId,
		ta.Guid AS TargetAccountId,
		cu.Guid AS CreatedByUserId,
		ch.Guid AS CheckedByUserId,
		root_hobt.IsComplete
FROM	SCrm.AccountMergeBatch root_hobt
JOIN	SCrm.Accounts sa ON (sa.ID = root_hobt.SourceAccountId)
JOIN	SCrm.Accounts ta ON (ta.ID = root_hobt.TargetAccountId)
JOIN	SCore.Identities cu ON (cu.ID = root_hobt.CreatedByUserId)
JOIN	SCore.Identities ch ON (ch.ID = root_hobt.CheckedByUserId)', 93, 85, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (206, 1, 'b4dfa285-2c01-4d2a-8eb3-9dddf7eb7ecd', N'Account Merge Batch Upsert', N'EXEC SCrm.AccountMergeBatchUpsert @SourceAccountGuid = @SourceAccountGuid,	-- uniqueidentifier
								  @TargetAccountGuid = @TargetAccountGuid,	-- uniqueidentifier
								  @CreatedByUserGuid = @CreatedByUserGuid,	-- uniqueidentifier
								  @CheckedByUserGuid = @CheckedByUserGuid,	-- uniqueidentifier
								  @Guid = @Guid					-- uniqueidentifier', 93, 85, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (207, 1, 'a8abc4f6-0f46-4177-8fbb-84d24320869d', N'Account Merge Batch Validate', N'SELECT *
FROM	SCrm.tvf_AccountMergeBatchValidate(@SourceAccountGuid, @TargetAccountGuid, @CreatedByUserGuid, @CheckedByUserGuid, @IsComplete, @Guid) root_hobt', 93, 85, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (208, 1, '3b9d8bc0-e651-4c02-a59b-3f4433a08e06', N'Account Merge Batch Data Pills', N'SELECT * FROM [SCrm].[AccountMergeBatch_DataPills] (@Guid, @CheckedByUserGuid, @IsComplete) root_hobt ', 93, 85, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (209, 1, '90c33e0f-3cd6-4c7a-8e90-734a884fce04', N'Account Calculated Fields Read', N'SELECT ID AS Account_ID,
	   Guid,
	   RowStatus,
	   RowVersion,
	   MainAddress,
	   MainPhone,
	   MainEmail
FROM	SCrm.Accounts_CalculatedFields root_hobt', 15, 86, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCrm', N'Accounts_CalculatedFields', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (210, 1, '7318755e-7a08-4fb6-a2d5-813079fe7182', N'Jobs Validate', N'SELECT * FROM [SJob].[tvf_JobsValidate] ( @Guid, @JobCompleted, @JobCancelled, @DeadDate, @JobTypeGuid, @CannotBeInvoiced, @CannotBeInvoicedReason, @ContractGuid, @AgentContractGuid) root_hobt', 9, 9, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SJob', N'tvf_JobsValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (211, 1, '94d0e43f-d96a-4c2a-867b-c09f21845416', N'Fee Amendment Validate', N'SELECT * FROM [SJob].[FeeAmendmentsValidate]
	(
		@Guid ,
		@JobGuid 
	) root_hobt', 89, 81, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (212, 1, '54b5f855-d00a-4b9e-abd1-049e8be7615f', N'Quote Extended Info Read', N'SELECT
	[3D00EDE9-26D4-47DA-95BE-7374C084BADD].Guid AS AgentAccountId,
	[D8D47C34-0EA4-41F0-950D-DB45011865AA].Guid AS ClientAccountId,
	root_hobt.DescriptionOfWorks,
	[9B2655E2-4696-4B1E-9013-DA6AFE6CB728].Guid AS EnquiryId,
	root_hobt.JobType,
    root_hobt.JobTypeGuid,
	[0E518042-9A71-44B7-8549-305DB3E09225].Guid AS PropertyId,
	root_hobt.QuotingDeadlineDate,
    root_hobt.ClientContactId,
    AgentContact.Guid AS AgentContactId,
	ClientAddress.Guid AS ClientAddressId,
	AgentAddress.Guid AS AgentAddressId
FROM SSop.Quote_ExtendedInfo AS root_hobt 
JOIN SCrm.Accounts AS [D8D47C34-0EA4-41F0-950D-DB45011865AA] ON ([D8D47C34-0EA4-41F0-950D-DB45011865AA].ID = root_hobt.ClientAccountId) 
JOIN SCrm.Accounts AS [3D00EDE9-26D4-47DA-95BE-7374C084BADD] ON ([3D00EDE9-26D4-47DA-95BE-7374C084BADD].ID = root_hobt.AgentAccountId) 
JOIN SJob.Assets AS [0E518042-9A71-44B7-8549-305DB3E09225] ON ([0E518042-9A71-44B7-8549-305DB3E09225].ID = root_hobt.PropertyId) 
JOIN SSop.Enquiries AS [9B2655E2-4696-4B1E-9013-DA6AFE6CB728] ON ([9B2655E2-4696-4B1E-9013-DA6AFE6CB728].ID = root_hobt.EnquiryId)
JOIN SCrm.AccountAddresses AS ClientAddress ON (ClientAddress.ID = root_hobt.ClientAddressId)
JOIN SCrm.AccountAddresses AS AgentAddress ON (AgentAddress.ID = root_hobt.AgentAddressId)
JOIN SCrm.AccountContacts AS AgentContact ON (AgentContact.ID = root_hobt.AgentAccountContactId)', 55, 87, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'Quote_ExtendedInfo', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (213, 1, '82f0d634-c1c7-4567-8940-4dc83adc99bc', N'Project Extended Info Read', N'SELECT 
	root_hobt.AcceptedQuotesCount,
	root_hobt.AcceptedQuotesTotalValue,
	root_hobt.EnquiriesCount,
	root_hobt.Guid,
	root_hobt.Id,
	root_hobt.JobsActiveAgreedFeesTotal,
	root_hobt.JobsActiveCount,
	root_hobt.JobsActiveInvoicedFeesTotal,
	root_hobt.JobsActiveRemainingFeesTotal,
	root_hobt.JobsCancelledAgreedFeesTotal,
	root_hobt.JobsCancelledCount,
	root_hobt.JobsCancelledInvoicedFeesTotal,
	root_hobt.JobsCancelledUninvoicedFeesTotal,
	root_hobt.JobsCompletedAgreedFeesTotal,
	root_hobt.JobsCompletedCount,
	root_hobt.JobsCompletedInvoicedFeesTotal,
	root_hobt.JobsCompletedUninvoicesFeesTotal,
	root_hobt.JobsCount,
	root_hobt.JobsTotalAgreedFeesTotal,
	root_hobt.JobsTotalInvoicedFeesTotal,
	root_hobt.JobsTotalRemainingFeesTotal,
	root_hobt.ListLabel,
	root_hobt.PendingQuotesCount,
	root_hobt.PendingQuotesTotelValue,
	root_hobt.PercentageAchievableRevenueAchieved,
	root_hobt.PercentageCompleted,
	root_hobt.QuotesCount,
	root_hobt.QuotesTotalValue,
	root_hobt.RejectedQuotesCount,
	root_hobt.RejectedQuotesTotalValue,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.Project_ExtendedInfo AS root_hobt 
', 94, 89, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'Project_ExtendedInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (214, 1, '9c73a246-294e-4873-bdc6-644fd7d8d1aa', N'Projects Read', N'SELECT 
	root_hobt.ExternalReference
,	root_hobt.Guid
,	root_hobt.ID
,	root_hobt.Number
,	root_hobt.ProjectCompleted
,	root_hobt.ProjectDescription
,	root_hobt.ProjectProjectedEndDate
,	root_hobt.ProjectProjectsStartDate
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.IsSubjectToNDA

FROM SSop.Projects AS root_hobt 
', 94, 88, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'Projects', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (215, 1, '851eeb13-ddc8-49b2-9e8a-8e9d08449053', N'Projects Upsert', N'EXEC [SSop].[ProjectsUpsert]  @ExternalReference = @ExternalReference, @ProjectDescription = @ProjectDescription, @ProjectProjectedStartDate = @ProjectProjectedStartDate, @ProjectProjectedEndDate = @ProjectProjectedEndDate, @ProjectCompleted = @ProjectCompleted, @IsSubjectToNDA = @IsSubjectToNDA, @Guid = @Guid', 94, 88, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (216, 1, 'fa8aff4e-8783-4c95-88ff-b490aa6b3be5', N'Quote Memos Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        q.Guid AS QuoteID,
        root_hobt.Memo,
        root_hobt.CreatedDateTimeUTC,
        i.Guid AS CreatedByUserId,
        root_hobt.LegacyId
FROM    SSop.QuoteMemos root_hobt
JOIN    SSop.Quotes q ON (root_hobt.QuoteID = q.ID)
JOIN    SCore.Identities i ON (root_hobt.CreatedByUserId = i.ID)', 104, 96, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteMemos', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (217, 1, '572022bb-439f-4740-a591-72110cd3dda3', N'Quote Memo''s Upsert', N'EXEC SSop.QuoteMemosUpsert
  @QuoteGuid          = @QuoteGuid,
  @Memo               = @Memo,
  @CreatedDateTimeUTC = @CreatedDateTimeUTC,
  @CreatedByUserGuid  = @CreatedByUserGuid,
  @Guid               = @Guid', 104, 96, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (218, 1, 'bdafdf2e-c7d6-4922-bcd8-91dac2289394', N'User Groups Read', N'SELECT
        root_hobt.ID,
        root_hobt.Guid,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        i.Guid AS IdentityID,
        g.Guid AS GroupID
FROM
        SCore.UserGroups root_hobt
JOIN    SCore.Identities i ON (root_hobt.IdentityID = i.ID)
JOIN    SCore.Groups g ON (root_hobt.GroupID = g.ID)', 97, 92, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (220, 1, '000b42db-3963-46e5-a8c1-5846041a3b71', N'User Groups Upsert', N'EXEC [SCore].[UserGroupsUpsert]  @UserGuid = @UserGuid, @GroupGuid = @GroupGuid, @Guid = @Guid', 97, 92, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'UserGroupsUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (221, 1, 'be5ecc12-f826-4a4a-b6a3-e364113486e4', N'User Groups Delete', N'EXEC [SCore].[UserGroupsDelete]  @Guid = @Guid', 97, 92, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'UserGroupsDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (222, 1, '6eadb6af-7990-4a25-afe0-380e42290d03', N'User Preferences Read', N'SELECT
        root_hobt.ID,
        root_hobt.Guid,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        l.Guid AS SystemLanguageID
FROM
        SCore.UserPreferences root_hobt
JOIN    SCore.Languages l ON (root_hobt.SystemLanguageID = l.ID)', 42, 98, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (223, 1, '35890ae0-da06-4417-beed-87d9bbc36605', N'UserPreferencesUpsert', N'EXEC [SCore].[UserPreferencesUpsert]  @SystemLanguageGuid = @SystemLanguageGuid, @Guid = @Guid', 42, 98, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'UserPreferencesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (224, 1, '29cba2eb-6422-4649-88d4-ab79528d96e5', N'tvf_ContactsValidate', N'SELECT * FROM [SCrm].[tvf_ContactsValidate] ( @Guid) root_hobt', 25, 20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SCrm', N'tvf_ContactsValidate', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (225, 1, '4c2adafd-316d-472f-9803-c1f1738a5d4a', N'Groups Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.DirectoryId,
        root_hobt.Code,
        root_hobt.Name,
        root_hobt.Source
FROM    SCore.Groups root_hobt', 87, 79, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (226, 1, 'c395c13d-333f-4abc-a94d-7f73db417da2', N'GroupUpsert', N'EXEC [SCore].[GroupUpsert]  @Name = @Name, @Code = @Code, @DirectoryId = @DirectoryId, @Guid = @Guid, @Source = @Source', 87, 79, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'GroupUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (227, 1, 'e13d6987-ee08-4fef-8be4-5ef599511c11', N'ProjectDirectoryDelete', N'EXEC [SSop].[ProjectDirectoryDelete]  @Guid = @Guid', 35, 31, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectDirectoryDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (228, 1, 'f4d8a32d-5dea-4a23-8aa3-b827c3562645', N'Action Menu Items Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        ll.Guid AS LanguageLabelId,
        root_hobt.IconCss,
        root_hobt.Type,
        et.Guid AS EntityTypeId,
        eq.Guid AS EntityQueryId,
        root_hobt.SortOrder,
        root_hobt.RedirectToTargetGuid
FROM    SUserInterface.ActionMenuItems root_hobt
JOIN    SCore.LanguageLabels ll ON (root_hobt.LanguageLabelId = ll.ID)
JOIN    SCore.EntityTypes et ON (root_hobt.EntityTypeId = et.ID)
JOIN    SCore.EntityQueries eq ON (root_hobt.EntityQueryId = eq.ID)', 59, 56, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (229, 1, '0b285efd-5677-4796-875b-80a9cfcc09f8', N'Action Menu Items Upsert', N'EXEC [SUserInterface].[ActionMenuItemsUpsert]  @LanguageLabelGuid = @LanguageLabelGuid, @IconCss = @IconCss, @Type = @Type, @EntityTypeGuid = @EntityTypeGuid, @EntityQueryGuid = @EntityQueryGuid, @RedirectToTargetGuid = @RedirectToTargetGuid, @SortOrder = @SortOrder, @Guid = @Guid', 59, 56, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'ActionMenuItemsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (230, 1, '6faa607d-9498-41bb-8e74-37613d6d6c0e', N'Revise Quote', N'EXEC [SSop].[QuotesRevise]  @SourceGuid = @Guid, @TargetGuid = ''[[TargetGuid]]''', 55, 52, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, N'SSop', N'QuotesRevise', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (231, 1, '0e4fb65a-62dc-49ad-9b65-6c295916765b', N'JobTypeMilestoneTemplatesDelete', N'EXEC [SJob].[JobTypeMilestoneTemplatesDelete]  @Guid = @Guid', 79, 71, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SJob', N'JobTypeMilestoneTemplatesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (232, 1, '61127116-a676-43a9-b8c7-a0230765b5b1', N'Enquiry Key Date Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Details,
        root_hobt.DateTime,
        e.Guid AS EnquiryId
FROM    SSop.EnquiryKeyDates root_hobt
JOIN    SSop.Enquiries e ON (root_hobt.EnquiryId = e.ID)', 106, 99, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (233, 1, '19544843-06c6-44ee-9d4e-15c62c4f1201', N'EnquiryKeyDatesUpsert', N'EXEC [SSop].[EnquiryKeyDatesUpsert]  @EnquiryGuid = @EnquiryGuid, @Details = @Details, @DateTime = @DateTime, @Guid = @Guid', 106, 99, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryKeyDatesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (234, 1, '7ebd03f4-ba2a-4ab7-bb9b-a2f98651fd9a', N'EnquiryKeyDatesDelete', N'EXEC [SSop].[EnquiryKeyDatesDelete]  @Guid = @Guid', 106, 99, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryKeyDatesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (235, 1, '340b13fb-0af6-450f-baf8-edc4b3df55ab', N'Quote Key Dates Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        q.Guid AS QuoteId,
        root_hobt.Detail,
        root_hobt.DateTime
FROM    SSop.QuoteKeyDates root_hobt
JOIN    SSop.Quotes q ON (root_hobt.QuoteId = q.ID)', 107, 100, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (236, 1, '76ae5f3a-37f9-4a0b-a609-adc3dc61cd9a', N'Quote Key Date Upsert', N'EXEC [SSop].[QuoteKeyDatesUpsert]  @QuoteGuid = @QuoteGuid, @Detail = @Detail, @DateTime = @DateTime, @Guid = @Guid', 107, 100, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteKeyDatesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (237, 1, '7853f962-727f-4b0c-8d0a-3cb4f6574ea5', N'Job Key Dates Read', N'SELECT  root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        j.Guid AS JobId,
        root_hobt.Detail,
        root_hobt.DateTime
FROM    SJob.JobKeyDates root_hobt
JOIN    SJob.Jobs j ON (root_hobt.JobId = j.ID)', 108, 101, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (238, 1, '6911f536-00a6-4eb2-b1c0-84c39e4e3175', N'Job Key Dates Upsert', N'EXEC [SJob].[JobKeyDatesUpsert]  @JobGuid = @JobGuid, @Detail = @Detail, @DateTime = @DateTime, @Guid = @Guid', 108, 101, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobKeyDatesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (239, 1, '09c24ce0-0418-4703-b885-6f85a80b543b', N'Job Key Dates Delete', N'EXEC [SJob].[JobKeyDatesDelete]  @Guid = @Guid', 108, 101, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SJob', N'JobKeyDatesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (240, 1, '2f1531a3-c14f-4c06-99b6-c09dd1b765a9', N'Quote Key Dates Delete', N'EXEC [SSop].[QuoteKeyDatesDelete]  @Guid = @Guid', 107, 100, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteKeyDatesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (241, 1, 'f50a8dbe-93eb-4f6d-b6af-bc58c1b91270', N'Action Status Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.IsActive,
		root_hobt.SortOrder,
		root_hobt.Colour,
		root_hobt.IsCompleteStatus
FROM	SJob.ActionStatus root_hobt', 114, 106, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (242, 1, '1d6e69cf-bb09-4bb1-a416-df7c69c0eab1', N'Action Status Upsert', N'EXEC [SJob].[ActionStatusUpsert]  @Name = @Name, @IsActive = @IsActive, @Colour = @Colour, @SortOrder = @SortOrder, @IsCompleteStatus = @IsCompleteStatus, @Guid = @Guid', 114, 106, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActionStatusUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (243, 1, '596f8894-1aaf-405d-9ae2-84ef5f108932', N'Action Types Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.IsActive,
		root_hobt.SortOrder,
		root_hobt.Colour
FROM	SJob.ActionTypes root_hobt', 112, 104, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (244, 1, 'f72250ef-3157-42c8-b21c-daa49e1c89d7', N'Action Types Upsert', N'EXEC [SJob].[ActionTypesUpsert]  @Name = @Name, @IsActive = @IsActive, @Colour = @Colour, @SortOrder = @SortOrder, @Guid = @Guid', 112, 104, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActionTypesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (245, 1, '878d68df-46b2-47a6-a7e3-f407e87dda77', N'Action Priorities Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.IsActive,
		root_hobt.SortOrder,
		root_hobt.Colour
FROM	SJob.ActionPriorities  root_hobt', 113, 105, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (246, 1, 'baf2b0ed-31b1-40e4-8c8b-8d5df0f65c1c', N'Action Priorities Upsert', N'EXEC [SJob].[ActionPrioritiesUpsert]  @Name = @Name, @IsActive = @IsActive, @Colour = @Colour, @SortOrder = @SortOrder, @Guid = @Guid', 113, 105, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActionPrioritiesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (247, 1, '12e25118-9588-4717-82ff-eaa22dc76c54', N'Merge Document Tables Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		md.guid AS MergeDocumentId,
		root_hobt.TableName,
		et.Guid AS LinkedEntityTypeId
FROM	SCore.MergeDocumentTables root_hobt
JOIN	SCore.MergeDocuments md ON md.Id = root_hobt.MergeDocumentId
JOIN	SCore.EntityTypes et ON root_hobt.LinkedEntityTypeId = et.ID', 115, 107, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (248, 1, 'e96bf02e-8fe1-4e7a-9894-da7093a50e7a', N'Merge Document Tables Upsert', N'EXEC [SCore].[MergeDocumentTablesUpsert]  @MergeDocumentGuid = @MergeDocumentGuid, @TableName = @TableName, @LinkedEntityTypeGuid = @LinkedEntityTypeGuid, @Guid = @Guid', 115, 107, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentTablesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (249, 1, '7614ae34-a7f4-45f7-bd10-5efce70bfd1c', N'Merge Document Tables Delete', N'EXEC [SCore].[MergeDocumentTablesDelete]  @Guid = @Guid', 115, 107, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentTablesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (250, 1, '111ec18d-97be-4a3e-903a-b09baf0e7f04', N'Job Payment Stages Read', N'SELECT
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		j.Guid AS JobId,
		root_hobt.StagedDate,
		rs.Guid as AfterStageId,
		root_hobt.Value
FROM
		SJob.JobPaymentStages root_hobt
JOIN	
		SJob.RibaStages rs ON (root_hobt.AfterStageId = rs.id)
JOIN
		SJob.Jobs j ON (root_hobt.JobId = j.Id)', 119, 111, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (251, 1, 'c79ae75d-70cb-4992-8138-ec63a01c53e6', N'Job Payment Stages Upsert', N'EXEC [SJob].[JobPaymentStagesUpsert]  @JobGuid = @JobGuid, @StagedDate = @StagedDate, @AfterStageGuid = @AfterStageGuid, @Value = @Value, @Guid = @Guid', 119, 111, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobPaymentStagesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (252, 1, '5dc468a2-d674-4b8c-b5a4-b88838e9c224', N'Job Payment Stages Delete', N'EXEC [SJob].[JobPaymentStagesDelete]  @Guid = @Guid', 119, 111, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SJob', N'JobPaymentStagesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (253, 1, 'f2fa1ee1-7237-43c8-b4d6-70f7bf074be2', N'Quote Payment Stages Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		q.Guid AS QuoteId,
		pft.Guid AS PaymentFrequencyTypeId,
		root_hobt.PaymentFrequency,
		root_hobt.Value,
		root_hobt.PercentageOfTotal,
		rs.Guid  AS PayAfterStageId
FROM	SSop.QuotePaymentStages root_hobt
JOIN	SSop.Quotes q ON root_hobt.QuoteId = q.ID
JOIN	SFin.PaymentFrequencyTypes pft ON root_hobt.PaymentFrequencyTypeId = pft.ID
JOIN	SJob.RibaStages rs ON root_hobt.PayAfterStageId = rs.ID', 120, 112, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (254, 1, 'bf7df4da-d675-4f29-8c4c-b5b362eb948c', N'Quote Payment Stages Upsert', N'EXEC [SSop].[QuotePaymentStagesUpsert]  @QuoteGuid = @QuoteGuid, @PaymentFrequencyTypeGuid = @PaymentFrequencyTypeGuid, @PaymentFrequency = @PaymentFrequency, @Value = @Value, @PercentageOfTotal = @PercentageOfTotal, @PayAfterStageGuid = @PayAfterStageGuid, @Guid = @Guid', 120, 112, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuotePaymentStagesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (255, 1, '8ee8cbc5-5c35-46a3-bd12-17a497e4dfe2', N'Quote Payment Stages Delete', N'EXEC [SSop].[QuotePaymentStagesDelete]  @Guid = @Guid', 120, 112, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'QuotePaymentStagesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (256, 1, '9c824743-62f6-43cd-80e7-76f69f9130fc', N'ActivityCreateInvoiceRequest', N'EXEC SJob.ActivityCreateInvoiceRequest @Guid = @Guid', 30, 25, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, N'[SJob]', N'[ActivityCreateInvoiceRequest]', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (257, 1, '474c774a-2550-4fb9-a946-cff45fcfbf2a', N'Activity Pills', N'SELECT	root_hobt.ID,
		root_hobt.Label,
		root_hobt.Class,
		root_hobt.SortOrder 
FROM	[SJob].[Activities_DataPills](@SurveyorGuid, @BillableHours, @JobGuid, @RibaStageGuid, @IsAdditionalWork, @Guid) root_hobt', 30, 25, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (258, 1, '413ebcdc-b0a3-4fd7-bef1-1054f8c7274f', N'Invoice Request Read', N'SELECT
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Notes,
                root_hobt.InvoicingType,
                root_hobt.ExpectedDate,
                root_hobt.ManualStatus,
		i.Guid as RequesterUserId,
		root_hobt.CreatedDateTimeUTC,
                ips.Guid AS InvoicePaymentStatusID,
		j.Guid as JobId,
        j.Number as Number,
        i.FullName as SurveyorName,
        Ac.Guid as FinanceAccountID, -- new
        j.BillingInstruction AS JobBillingInstruction, -- [CBLD-521]
	Ac.BillingInstruction AS AccountBillingInstruction -- [CBLD-521]
FROM
		SFin.InvoiceRequests root_hobt
JOIN
		SJob.Jobs j ON (j.ID = root_hobt.JobId)
JOIN
		SCrm.Accounts Ac ON (j.FinanceAccountID = Ac.ID) -- new
JOIN
		SCore.Identities i ON (i.ID = root_hobt.RequesterUserId)
JOIN
		SFin.InvoicePaymentStatus ips ON (root_hobt.InvoicePaymentStatusID = ips.ID)', 126, 115, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'InvoiceRequests', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (259, 1, '8fe6417d-52ce-484c-baac-2c4a72763320', N'Invoice Requests Upsert', N'EXEC [SFin].[InvoiceRequestUpsert]  @JobGuid = @JobGuid, @RequesterUserGuid = @RequesterUserGuid, @Notes = @Notes, @Guid = @Guid, @InvoicingType = @InvoicingType, @ExpectedDate = @ExpectedDate, @ManualStatus = @ManualStatus, @PaymentStatusGuid = @PaymentStatusGuid', 126, 115, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'InvoiceRequestUpsert', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (260, 1, 'df7a9a4e-7572-43e9-bb17-1c73a0be772e', N'Invoice Request Items Read', N'SELECT 
 [DF573724-6B25-4B0E-BCDA-061280F64A77].Guid AS ActivityId,
 root_hobt.Guid,
 root_hobt.ID,
 [395D9343-C3C2-4DD1-A20C-A254BA403724].Guid AS InvoiceRequestId,
 [96FB0CCD-A7BF-45F8-A3A6-23D70E4620F4].Guid AS MilestoneId,
 root_hobt.Net,
 root_hobt.RowStatus,
 root_hobt.RowVersion,
 root_hobt.ShortDescription 
FROM SFin.InvoiceRequestItems AS root_hobt 
JOIN SFin.InvoiceRequests AS [395D9343-C3C2-4DD1-A20C-A254BA403724] ON ([395D9343-C3C2-4DD1-A20C-A254BA403724].ID = root_hobt.InvoiceRequestId) 
 JOIN SJob.Milestones AS [96FB0CCD-A7BF-45F8-A3A6-23D70E4620F4] ON ([96FB0CCD-A7BF-45F8-A3A6-23D70E4620F4].ID = root_hobt.MilestoneId) 
 JOIN SJob.Activities AS [DF573724-6B25-4B0E-BCDA-061280F64A77] ON ([DF573724-6B25-4B0E-BCDA-061280F64A77].ID = root_hobt.ActivityId) ', 127, 116, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'InvoiceRequestItems', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (261, 1, '2730f895-8332-45db-99f1-f0835ceffbcc', N'Invoice Requests Items Upsert', N'EXEC [SFin].[InvoiceRequestItemsUpsert]  
	@InvoiceRequestGuid = @InvoiceRequestGuid, 
	@MilestoneGuid = @MilestoneGuid, 
	@ActivityGuid = @ActivityGuid, 
	@Net = @Net, 
	@Guid = @Guid, 
	@ShortDescription = @ShortDescription', 127, 116, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'InvoiceRequestItemsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (262, 1, 'f999c9d0-8410-4baf-b306-0eea1bb37e89', N'Grid View Actions Read', N'SELECT	root_hobt.ID,
		root_hobt.Guid,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		ll.Guid  as LanguageLabelId,
		eq.Guid as EntityQueryId,
		gvd.Guid as GridViewDefinitionId
FROM	SUserInterface.GridViewActions root_hobt
JOIN	SCore.LanguageLabels ll on (ll.Id = root_hobt.LanguageLabelId)
JOIN	score.EntityQueries eq on (eq.Id = root_hobt.EntityQueryId)
JOIN	SUserInterface.GridViewDefinitions gvd on (gvd.Id = root_hobt.GridViewDefinitionId)', 128, 117, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (263, 1, 'd067a9a0-a702-455e-a337-8bc2b8ceb9ef', N'Grid View Actions Upsert', N'EXEC [SUserInterface].[GridViewActionUpsert]  @GridViewDefinitionGuid = @GridViewDefinitionGuid, @LanguageLabelGuid = @LanguageLabelGuid, @EntityQueryGuid = @EntityQueryGuid, @Guid = @Guid', 128, 117, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'GridViewActionUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (264, 1, '6a0e5c4b-acbf-4f79-8066-ff0796dca0ac', N'Payment Stage Create Invoice', N'EXEC [SFin].[StagePaymentCreateInvoice]  @Guid = @Guid', 119, 111, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, N'SFin', N'StagePaymentCreateInvoice', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (265, 1, '99645c87-76da-4e38-974f-dbc7e873eb95', N'Product Job Activities Read', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		p.Guid AS ProductId,
		jtat.Guid AS JobTypeActivityTypeId,
		root_hobt.ActivityTitle,
		root_hobt.OffsetDays,
		root_hobt.OffsetWeeks,
		root_hobt.OffsetMonths,
		jtmt.Guid AS JobTypeMilestoneTemplateId,
		root_hobt.PercentageOfProductValue
FROM	SJob.ProductJobActivities AS root_hobt
JOIN	SProd.Products AS p ON (p.Id = root_hobt.ProductId)
JOIN	SJob.JobTypeActivityTypes AS jtat ON (jtat.ID = root_hobt.JobTypeActivityTypeId)
JOIN	SJob.JobTypeMilestoneTemplates AS jtmt ON (jtmt.ID = root_hobt.JobTypeMilestoneTemplateId)', 122, 114, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ProductJobActivities', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (266, 1, '02e22ac1-dadf-442a-b5bb-f2fa6da3e890', N'Product Job Activities Upsert', N'EXEC [SJob].[ProductJobActivitiesUpsert]  @ProductGuid = @ProductGuid, @JobTypeActivityTypeGuid = @JobTypeActivityTypeGuid, @ActivityTitle = @ActivityTitle, @OffsetDays = @OffsetDays, @OffsetWeeks = @OffsetWeeks, @OffsetMonths = @OffsetMonths, @JobTypeMilestoneTemplateGuid = @JobTypeMilestoneTemplateGuid, @PercentageOfProductValue = @PercentageOfProductValue, @Guid = @Guid', 122, 114, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ProductJobActivitiesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (267, 1, '69f736c9-d60d-4206-8be7-0636cd2b23e0', N'Object Security Delete', N'EXEC [SCore].[ObjectSecurityDelete]  @Guid = @Guid', 86, 78, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'ObjectSecurityDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (268, 1, '012c7833-2ccf-494b-8858-a14acca5cef7', N'Invoice Requests Create Invoice', N'EXEC [SFin].[InvoiceRequestCreateInvoice]  @Guid = @Guid', 126, 115, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SFin', N'InvoiceRequestCreateInvoice', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (269, 1, '15a416e8-39fe-49ff-b054-d2d3c250359a', N'QuotePaymentStagesValidate', N'SELECT * FROM [SSop].[tvf_QuotePaymentStagesValidate] ( @PaymentFrequencyTypeGuid, @PaymentFrequency, @Value, @PercentageOfTotal, @Guid) root_hobt', 120, 112, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SSop', N'tvf_QuotePaymentStagesValidate', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (270, 1, '5ee95a21-4d3f-464c-8ce8-e8e01ace75dd', N'Merge Document Item Include Upsert', N'EXEC [SCore].[MergeDocumentItemIncludesUpsert]  @MergeDocumentItemGuid = @MergeDocumentItemGuid, @SortOrder = @SortOrder, @SourceDocumentEntityPropertyGuid = @SourceDocumentEntityPropertyGuid, @SourceSharePointItemEntityPropertyGuid = @SourceSharePointItemEntityPropertyGuid, @IncludedMergeDocumentGuid = @IncludedMergeDocumentGuid, @Guid = @Guid', 153, 120, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemIncludesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (271, 1, '1c8a3dcf-1181-443e-af6f-ecad59235c4b', N'Merge Document Item Includes Delete', N'EXEC [SCore].[MergeDocumentItemIncludesDelete]  @Guid = @Guid', 153, 120, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemIncludesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (272, 1, '7526aaa9-0379-4e9b-83ef-30278af7f838', N'Merge Document Item Includes Read', N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	[E779FDBF-3727-4C37-B19D-4BCC6F71314F].Guid AS IncludedMergeDocumentId,
	[0BEC90D5-4330-467B-B271-2D2A4364D00F].Guid AS MergeDocumentItemId,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SortOrder,
	[A7575B42-582C-4E04-A3C4-59ADA04EF33A].Guid AS SourceDocumentEntityPropertyId,
	[1A289995-4638-4F67-B706-CD3E3E3C80E0].Guid AS SourceSharePointItemEntityPropertyId
FROM SCore.MergeDocumentItemIncludes AS root_hobt 
JOIN SCore.MergeDocumentItems AS [0BEC90D5-4330-467B-B271-2D2A4364D00F] ON ([0BEC90D5-4330-467B-B271-2D2A4364D00F].ID = root_hobt.MergeDocumentItemId) 
 JOIN SCore.EntityProperties AS [A7575B42-582C-4E04-A3C4-59ADA04EF33A] ON ([A7575B42-582C-4E04-A3C4-59ADA04EF33A].ID = root_hobt.SourceDocumentEntityPropertyId) 
 JOIN SCore.EntityProperties AS [1A289995-4638-4F67-B706-CD3E3E3C80E0] ON ([1A289995-4638-4F67-B706-CD3E3E3C80E0].ID = root_hobt.SourceSharePointItemEntityPropertyId) 
 JOIN SCore.MergeDocuments AS [E779FDBF-3727-4C37-B19D-4BCC6F71314F] ON ([E779FDBF-3727-4C37-B19D-4BCC6F71314F].ID = root_hobt.IncludedMergeDocumentId) 
', 153, 120, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemIncludes', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (273, 1, '99a892c4-6fec-4aed-9119-aa80d5b1ad49', N'MergeDocumentItems Read', N'SELECT 
	root_hobt.BookmarkName,
	[02A636D3-60AA-4516-8303-3B12D2497685].Guid AS EntityTypeId,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.ImageColumns,
	[B86CAFA7-C6E8-4AC5-A606-7A2289ACDDC9].Guid AS MergeDocumentId,
	[9BFBE9EC-9DDB-4FCC-8513-9EB5F2C1593C].Guid AS MergeDocumentItemTypeId,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SubFolderPath
FROM SCore.MergeDocumentItems AS root_hobt 
JOIN SCore.MergeDocuments AS [B86CAFA7-C6E8-4AC5-A606-7A2289ACDDC9] ON ([B86CAFA7-C6E8-4AC5-A606-7A2289ACDDC9].ID = root_hobt.MergeDocumentId) 
 JOIN SCore.MergeDocumentItemTypes AS [9BFBE9EC-9DDB-4FCC-8513-9EB5F2C1593C] ON ([9BFBE9EC-9DDB-4FCC-8513-9EB5F2C1593C].ID = root_hobt.MergeDocumentItemTypeId) 
 JOIN SCore.EntityTypes AS [02A636D3-60AA-4516-8303-3B12D2497685] ON ([02A636D3-60AA-4516-8303-3B12D2497685].ID = root_hobt.EntityTypeId) 
', 152, 119, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItems', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (274, 1, '4ae3bc43-306b-47d7-9bd1-08c759e08ca2', N'MergeDocumentItems Upsert', N'EXEC [SCore].[MergeDocumentItemsUpsert]  @MergeDocumentGuid = @MergeDocumentGuid, @MergeDocumentItemTypeGuid = @MergeDocumentItemTypeGuid, @BookmarkName = @BookmarkName, @EntityTypeGuid = @EntityTypeGuid, @SubFolderPath = @SubFolderPath, @ImageColumns = @ImageColumns, @Guid = @Guid', 152, 119, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemsUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (275, 1, 'f50dc1d1-8cd8-4266-8686-cf23a3a07abd', N'MergeDocumentItems Delete', N'EXEC [SCore].[MergeDocumentItemsDelete]  @Guid = @Guid', 152, 119, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemsDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (276, 1, '22aab7de-d51f-453d-bee6-b296d011bff6', N'MergeDocumentItemTypes Read', N'SELECT 
	root_hobt.ID
,	root_hobt.Guid
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	root_hobt.Name
,	root_hobt.IsImageType

FROM SCore.MergeDocumentItemTypes AS root_hobt 
', 154, 121, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemTypes', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (277, 1, '5fd7b359-e65c-4a9e-bb6e-aaa3c73542bb', N'MergeDocumentItemTypes Upsert', N'EXEC [SCore].[MergeDocumentItemTypesUpsert]  @Name = @Name, @IsImageType = @IsImageType, @Guid = @Guid', 154, 121, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemTypesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (278, 1, 'f6b67f35-35e3-4b43-86fb-5700c76369ed', N'MergeDocumentItemTypes Delete', N'EXEC [SCore].[MergeDocumentItemTypesDelete]  @Guid = @Guid', 154, 121, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentItemTypesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (279, 1, '83b50644-ce3b-4909-837e-10281e17edec', N'EntityTypes Delete', N'EXEC [SCore].[EntityTypesDelete]  @Guid = @Guid', 4, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityTypesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (280, 1, 'abe704fd-2120-42b0-87e6-b8922b8195eb', N'ProjectsDelete', N'EXEC [SSop].[ProjectsDelete]  @Guid = @Guid', 94, 88, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectsDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (281, 1, '0557dd56-48fc-40e9-9a31-7a0548b57d97', N'ProjectKeyDates Read', N'SELECT 
	root_hobt.ID
,	root_hobt.Guid
,	root_hobt.RowStatus
,	root_hobt.RowVersion
,	[E9D4ABB8-AACF-4ECF-8EAC-1DFA642106F7].Guid AS ProjectID
,	root_hobt.Detail
,	root_hobt.DateTime

FROM SSop.ProjectKeyDates AS root_hobt 
JOIN SSop.Projects AS [E9D4ABB8-AACF-4ECF-8EAC-1DFA642106F7] ON ([E9D4ABB8-AACF-4ECF-8EAC-1DFA642106F7].ID = root_hobt.ProjectID) 
', 155, 122, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectKeyDates', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (282, 1, '7c5c71f2-5620-4157-80e3-9de75cad5b87', N'ProjectKeyDates Upsert', N'EXEC [SSop].[ProjectKeyDatesUpsert]  @ProjectGuid = @ProjectGuid, @Detail = @Detail, @DateTime = @DateTime, @Guid = @Guid', 155, 122, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectKeyDatesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (283, 1, '33b36e66-145c-41c5-9e28-d13975f16568', N'ProjectKeyDates Delete', N'EXEC [SSop].[ProjectKeyDatesDelete]  @Guid = @Guid', 155, 122, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'ProjectKeyDatesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (284, 254, '06f150dd-158b-41b4-a878-83f9da87cdf6', N'Project Data Pills', N'SELECT * FROM [SSop].[tvf_Project_DataPills] ( @Guid, @IsSubjectToNDA) root_hobt', 35, 88, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SSop', N'tvf_Project_DataPills', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (285, 1, '83ad3edc-abf3-42f6-8fea-46c6228d1662', N'Entity Queries Delete', N'EXEC [SCore].[EntityQueriesDelete]  @Guid = @Guid', 7, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'EntityQueriesDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (286, 1, '30146d9e-7a16-4dad-b179-15a48f04d9fe', N'Project Data Pills', N'SELECT * FROM [SSop].[tvf_Project_DataPills] ( @Guid, @IsSubjectToNDA) root_hobt', 94, 88, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SSop', N'tvf_Project_DataPills', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (287, 1, 'f2414138-3b23-4e94-8271-bc6fb3cc64c2', N'Enquiry Service Extended Info Read', N'SELECT 
	[CF303924-00E4-4D84-8E04-16B74316BD33].Guid AS QuoteId
,	root_hobt.DateAccepted
,	root_hobt.DateSent
,	root_hobt.DateRejected
,	root_hobt.Number
,	root_hobt.RevisionNumber
,       root_hobt.DeclinedToQuoteDate
,       root_hobt.DeclinedToQuoteReason
FROM SSop.EnquiryService_ExtendedInfo AS root_hobt 
JOIN SSop.Quotes AS [CF303924-00E4-4D84-8E04-16B74316BD33] ON ([CF303924-00E4-4D84-8E04-16B74316BD33].ID = root_hobt.QuoteId) 
', 84, 123, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryService_ExtendedInfo', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (288, 1, '47eb1261-b067-4454-bb45-1c664200437f', N'Enquiry Services Ext Upsert', N'EXEC [SSop].[EnquiryServicesExtUpsert]  
	@DateSent = @DateSent, 
	@DateAccepted = @DateAccepted, 
	@DateRejected = @DateRejected, 
	@DateDeclinedToQuote = @DateDeclinedToQuote, 
	@DateDeclinedToQuoteReason = @DateDeclinedToQuoteReason, 
	@QuoteGuid = @QuoteGuid, 
	@Guid = @Guid', 84, 123, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryServicesExtUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (289, 1, '9f13a3c0-f5fc-497f-95d2-06b3531d11d0', N'Enquiry Create Jobs', N'EXEC [SSop].[EnquiryCreateJobs]  
	@Guid = @Guid', 83, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryCreateJobs', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (290, 1, '533712a9-61fa-4192-a9dd-4d9076d24212', N'Quotes Delete', N'EXEC [SSop].[QuoteDelete]  
	@Guid = @Guid', 55, 52, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (291, 1, '946f41e3-b4a5-4449-8e6b-e9eb9cc71b07', N'Enquiry Merge Info Read', N'SELECT 
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.DescriptionOfWorks,
	root_hobt.EnquiryDate,
	root_hobt.EnquiryNumber,
	root_hobt.FinanceAddress,
	root_hobt.FinanceAddressBlock,
	root_hobt.FinanceAddressLine1,
	root_hobt.FinanceAddressLine2,
	root_hobt.FinanceAddressLine3,
	root_hobt.FinanceCompanyRegNo,
	root_hobt.FinanceContactName,
	root_hobt.FinanceCounty,
	root_hobt.FinanceEmail,
	root_hobt.FinanceFirstName,
	root_hobt.FinanceMobile,
	root_hobt.FinanceName,
	root_hobt.FinancePhone,
	root_hobt.FinancePostcode,
	root_hobt.FinanceSurname,
	root_hobt.FinanceTown,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.ParentGuid,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.ProposalLetter,
	root_hobt.RecipientAddress,
	root_hobt.RecipientAddressBlock,
	root_hobt.RecipientAddressLine1,
	root_hobt.RecipientAddressLine2,
	root_hobt.RecipientAddressLine3,
	root_hobt.RecipientCompanyRegNo,
	root_hobt.RecipientContactName,
	root_hobt.RecipientCounty,
	root_hobt.RecipientEmail,
	root_hobt.RecipientFirstName,
	root_hobt.RecipientMobile,
	root_hobt.RecipientName,
	root_hobt.RecipientPhone,
	root_hobt.RecipientPostcode,
	root_hobt.RecipientSurname,
	root_hobt.RecipientTown,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SignatoryInitials,
	root_hobt.SignatoryJobTitle,
	root_hobt.SignatoryName,
	root_hobt.SignatoryPostNominals,
	root_hobt.SignatorytEmail,
	root_hobt.TotalFee,
	root_hobt.UPRN,
	root_hobt.AgentAccountName,
	root_hobt.AgentContact,
	root_hobt.AgentAddressLineOne,
	root_hobt.AgentAddressLineTwo,
	root_hobt.AgentAddressLineThree,
	root_hobt.ClientAccountName,
	root_hobt.ClientContact,
	root_hobt.ClientAddressLineOne,
	root_hobt.ClientAddressLineTwo,
	root_hobt.ClientAddressLineThree
FROM SSop.Enquiry_MergeInfo AS root_hobt 
', 156, 124, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SSop', N'Enquiry_MergeInfo', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (292, 1, '666f7a0e-9da1-44bb-b8f6-f1584080fce3', N'Schedule Of Client Information Read', N'SELECT 
	[56C69394-5430-42BA-A4E2-4D12A3D0777C].Guid AS EnquiryId,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Item,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.ScheduleOfClientInformation AS root_hobt 
JOIN SSop.Enquiries AS [56C69394-5430-42BA-A4E2-4D12A3D0777C] ON ([56C69394-5430-42BA-A4E2-4D12A3D0777C].ID = root_hobt.EnquiryId) 
', 159, 127, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ScheduleOfClientInformation', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (293, 1, '07343c7b-5f9c-4938-8ffa-37beae0fabcd', N'ScheduleOfClientInformation Upsert', N'EXEC [SSop].[ScheduleOfClientInformationUpsert]  
	@EnquiryGuid = @EnquiryGuid, 
	@Item = @Item, 
	@Guid = @Guid', 159, 127, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ScheduleOfClientInformationUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (295, 1, '5ae93c3c-b861-4543-a7fa-9e71d462ff22', N'SSop.EnquiryService_MergeInfo Read', N'SELECT 
	root_hobt.EnquiryGuid,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.ParentGuid,
	root_hobt.QuoteGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.EnquiryService_MergeInfo AS root_hobt 
', 157, 125, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SSop', N'EnquiryService_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (296, 1, '960c86ac-ce23-412f-862b-5628b7a7f569', N'SSop.ScheduleOfClientInfo_MergeInfo Read', N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Item,
	root_hobt.ParentGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.ScheduleOfClientInfo_MergeInfo AS root_hobt 
', 163, 129, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SSop', N'ScheduleOfClientInfo_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (297, 1, 'a9d67cdb-c1ab-4873-b48e-2611e1fb8042', N'EnquiryAcceptanceServices_MergeInfo Read', N'SELECT 
	root_hobt.Accept,
	root_hobt.EnquiryGuid,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Name,
	root_hobt.ParentGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.EnquiryAcceptanceServices_MergeInfo AS root_hobt 
', 164, 130, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SSop', N'EnquiryAcceptanceServices_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (298, 1, '07a80181-876d-4bf6-b78d-5a0b062b92c3', N'MergeDocumentsDelete', N'EXEC [SCore].[MergeDocumentsDelete]  
	@Guid = @Guid', 60, 57, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'MergeDocumentsDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (299, 1, 'dd133a82-0f0c-4f69-87dc-85a6edd7ef4e', N'GridViewDefinitionsDelete', N'EXEC [SUserInterface].[GridViewDefinitionsDelete]  
	@Guid = @Guid', 12, 12, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'GridViewDefinitionsDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (300, 1, '9b0654c0-0706-40fd-a059-fdb5a6a97b23', N'GridViewColumnDefinitionsDelete', N'EXEC [SUserInterface].[GridViewColumnDefinitionsDelete]  
	@Guid = @Guid', 13, 13, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'GridViewColumnDefinitionsDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (301, 1, 'e183a37c-6f33-4602-a7fa-e1a209e08cfa', N'QuoteItems_MergeInfo', N'SELECT 
	root_hobt.Description,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.LineNet,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SSop.QuoteItems_MergeInfo AS root_hobt 
', 158, 126, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SSop', N'QuoteItems_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (302, 1, '31849617-140d-471f-bd27-7c7cce2250c1', N'Invoice Request Pills', N'SELECT * FROM [SFin].[tvf_InvoiceRequests_DataPills] ( @Guid, @FinanceAccountGuid) root_hobt', 126, 115, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SFin', N'tvf_InvoiceRequests_DataPills', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (303, 1, '0faac96b-9e90-4cb4-8e73-121a143105d0', N'Activity_ Merge Info_Read', N'SELECT 
	root_hobt.ActivityDate,
	root_hobt.ActivityNotes,
	root_hobt.ActivityTitle,
	root_hobt.ActivityType,
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.JobDescription,
	root_hobt.JobNumber,
	root_hobt.JobType,
	root_hobt.LocalAuthority,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.ParentGuid,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SurveyorEmail,
	root_hobt.SurveyorInitials,
	root_hobt.SurveyorJobTitle,
	root_hobt.SurveyorName,
	root_hobt.SurveyorPostNominals,
	root_hobt.UPRN
FROM SJob.Activity_MergeInfo AS root_hobt 
', 148, 118, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SJob', N'Activity_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (304, 1, '8e4d688e-0111-4bac-af40-b65b773d0685', N'SCrm.Contact_MergeInfo Read', N'SELECT 
	root_hobt.DisplayName,
	root_hobt.Email,
	root_hobt.FirstName,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Mobile,
	root_hobt.ParentGuid,
	root_hobt.Phone,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Surname
FROM SCrm.Contact_MergeInfo AS root_hobt 
', 109, 102, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SCrm', N'Contact_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (305, 1, '350ac761-a66b-4c52-888d-2036a3bdc0ff', N'SJob.Job_MergeInfo_Read', N'SELECT 
	root_hobt.AgentAddress,
	root_hobt.AgentAddressBlock,
	root_hobt.AgentAddressLine1,
	root_hobt.AgentAddressLine2,
	root_hobt.AgentAddressLine3,
	root_hobt.AgentCompanyRegNo,
	root_hobt.AgentContactName,
	root_hobt.AgentCounty,
	root_hobt.AgentEmail,
	root_hobt.AgentFirstName,
	root_hobt.AgentMobile,
	root_hobt.AgentName,
	root_hobt.AgentPhone,
	root_hobt.AgentPostcode,
	root_hobt.AgentSurname,
	root_hobt.AgentTown,
	root_hobt.AgreedFee,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientAppointmentReceived,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.ConstructionStageFee,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.JobDescription,
	root_hobt.JobIDString,
	root_hobt.JobNumber,
	root_hobt.JobType,
	root_hobt.LocalAuthority,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.PreConstructionStageFee,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.RibaStage1Fee,
	root_hobt.RibaStage2Fee,
	root_hobt.RibaStage3Fee,
	root_hobt.RibaStage4Fee,
	root_hobt.RibaStage5Fee,
	root_hobt.RibaStage6Fee,
	root_hobt.RibaStage7Fee,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SurveyorEmail,
	root_hobt.SurveyorInitials,
	root_hobt.SurveyorJobTitle,
	root_hobt.SurveyorName,
	root_hobt.SurveyorPostNominals,
	root_hobt.TotalNetFee,
	root_hobt.UPRN,
    root_hobt.LeadConsultant,
	root_hobt.AgentAccountName,
	root_hobt.AgentAddressLineOne,
	root_hobt.AgentAddressLineTwo,
	root_hobt.AgentAddressLineThree,
	root_hobt.AgentContact,
	root_hobt.ClientAddressLineOne,	
	root_hobt.ClientAddressLineTwo,	
	root_hobt.ClientAddressLineThree,
	root_hobt.ClientContact
        
FROM SJob.Job_MergeInfo AS root_hobt 
', 110, 103, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SJob', N'Job_MergeInfo', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (306, 1, '61317f52-407f-49d5-8ab5-e00d24657803', N'SJob.Activity_Table_MergeInfo.Read', N'SELECT 
	root_hobt.ActivityEndDate,
	root_hobt.ActivityNotes,
	root_hobt.ActivityStartDate,
	root_hobt.ActivityTitle,
	root_hobt.ActivityType,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.ParentGuid,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SurveyorName
FROM SJob.Activity_Table_MergeInfo AS root_hobt 
', 166, 131, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SJob', N'Activity_Table_MergeInfo', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (307, 1, 'd62757a5-c68a-46a7-a2cf-de0cf7d49fa1', N'Enquiry Duplicate', N'EXEC [SSop].[EnquiriesDuplicate]  @SourceGuid = @Guid, @TargetGuid = ''[[TargetGuid]]''', 83, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiriesDuplicate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (308, 1, '73859642-0a64-446b-bb07-6d12fdd6339e', N'Enquiries Revise', N'EXEC [SSop].[EnquiriesRevise]  @SourceGuid = @Guid, @TargetGuid = ''[[TargetGuid]]''', 83, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiriesRevise', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (309, 1, '24c79690-3d54-41e2-a170-9596cbee967b', N'Merge Document Items Validate ', N'SELECT * FROM [SCore].[tvf_MergeDocumentItemsValidate] (@MergeDocumentItemTypeId, @EntityTypeId, @SubFolderPath, @ImageColumns )', 152, 119, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SCore', N'MergeDocumentItems', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (310, 1, '8ff2c099-c5a2-401d-8a20-cc41e72e01cc', N'Schedule of Client Information Delete', N'EXEC [SSop].[ScheduleOfClientInformationDelete] @Guid = @Guid', 159, 127, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (311, 1, '26320003-6b68-40f2-93b7-528c8dd0bd08', N'Invoice Requests Delete', N'EXEC [SFin].[InvoiceRequestsDelete] @Guid = @Guid', 126, 115, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (312, 1, 'd7caa1b7-607f-4b9d-98ec-8a8edea7f9ab', N'Activity Types Delete', N'EXEC [SJob].[ActivityTypesDelete] @Guid = @Guid', 28, 23, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (313, 1, '7a81ed52-c6ab-469c-9d99-1254ee0062a1', N'Non-Activity Events Upsert', N'EXEC [SCore].[NonActivityEventsUpsert] @Guid = @Guid, @EndTime = @EndTime, @AbsenceTypeGuid= @AbsenceTypeGuid, @MemberId = @MemberId, @StartTime = @StartTime, @TeamId = @TeamId', 177, 134, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'NonActivityEvents', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (314, 1, 'a26d80ff-cb52-4036-a235-39b2bb497213', N'Non-Activity Events Delete', N'EXEC [SCore].[NonActivityEventsDelete] @Guid = @Guid', 177, 134, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'NonActivityEvents', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (315, 1, 'b1dea162-ce89-453f-a932-3a66fc4629fc', N'Non-Activity Events Read', N'SELECT 
	root_hobt.ID,
	root_hobt.Guid,
	root_hobt.RowVersion,
	root_hobt.RowStatus,
	NAT.Guid AS AbsenceTypeID,
	root_hobt.StartTime,
	root_hobt.EndTime,
	root_hobt.TeamGroupId,
	root_hobt.MemberIdentityId
FROM SCore.NonActivityEvents root_hobt
LEFT JOIN SCore.NonActivityTypes AS NAT ON (root_hobt.AbsenceTypeID = NAT.ID)', 177, 134, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'NonActivityEvents', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (316, 1, '26eb3a28-775d-44b3-aafc-a4dc19e89973', N'Non-Activity Types Upsert', N'EXEC [SCore].[NonActivityTypesUpsert]
	@Name = @Name,
        @Guid  = @Guid', 178, 135, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'NonActivityTypes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (317, 1, '156a72c5-77cf-48e9-9d7e-ff8ebdc8f33f', N'Non-Activity Types Delete', N'EXEC [SCore].[NonActivityTypesDelete]
@Guid = @Guid
	', 178, 135, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCore', N'NonActivityTypes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (318, 1, '217b1a03-1048-4a4c-b48c-d6261366a251', N'Non-Activity Types Read', N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.Name,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM SCore.NonActivityTypes AS root_hobt 
', 178, 135, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'NonActivityTypes', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (319, 1, 'e4502ba6-df55-4969-ad60-4f4536ea357a', N'Re-open Job', N'EXEC [SJob].[JobReopen]  
	@Guid = @Guid', 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobReopen', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (320, 1, '4398f7f6-a933-456a-8cb1-3b6cedbcdfc8', N'Re-open Quote', N'EXEC [SSop].[QuoteReopen]  
	@Guid = @Guid', 55, 52, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteReopen', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (321, 1, '4052dd79-aa82-40a8-bcef-65cf177b9cc7', N'Re-open Enquiry', N'EXEC [SSop].[EnquiryReopen]  
	@Guid = @Guid', 83, 75, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'EnquiryReopen', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (322, 1, '2971e2ee-675b-48e4-af31-62d43513cb09', N'Re-open Activities', N'EXEC [SJob].[ActivityReopen]  
	@Guid = @Guid', 30, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'ActivityReopen', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (323, 1, 'e2b27587-7312-4b67-989d-84bd777c0829', N'Asset Merge Batch Read', N'SELECT 
	[EEFD9BF2-DB99-46E3-BCE3-0C9DE3730E3B].Guid AS CheckedByUserId,
	[ADBF1D60-2576-48DB-9CE2-EFB7E88C741B].Guid AS CreatedByUserId,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsComplete,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	[A50022E1-4E2B-43F5-8DF4-EF8DB7159D43].Guid AS SourceAssetId,
	[F5BA2203-DC33-408F-8A19-15A147D62AD7].Guid AS TargetAssetId
FROM SJob.AssetMergeBatch AS root_hobt 
JOIN SJob.Assets AS [A50022E1-4E2B-43F5-8DF4-EF8DB7159D43] ON ([A50022E1-4E2B-43F5-8DF4-EF8DB7159D43].ID = root_hobt.SourceAssetId) 
 JOIN SJob.Assets AS [F5BA2203-DC33-408F-8A19-15A147D62AD7] ON ([F5BA2203-DC33-408F-8A19-15A147D62AD7].ID = root_hobt.TargetAssetId) 
 JOIN SCore.Identities AS [ADBF1D60-2576-48DB-9CE2-EFB7E88C741B] ON ([ADBF1D60-2576-48DB-9CE2-EFB7E88C741B].ID = root_hobt.CreatedByUserId) 
 JOIN SCore.Identities AS [EEFD9BF2-DB99-46E3-BCE3-0C9DE3730E3B] ON ([EEFD9BF2-DB99-46E3-BCE3-0C9DE3730E3B].ID = root_hobt.CheckedByUserId) 
', 179, 136, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'AssetMergeBatch', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (324, 1, 'ee5539c1-1394-416b-b5cd-ed8dda0adcab', N'Asset Merge Batch Upsert', N'EXEC [SJob].[AssetMergeBatchUpsert]  
	@SourceAssetGuid = @SourceAssetGuid, 
	@TargetAssetGuid = @TargetAssetGuid, 
	@CreatedByUserGuid = @CreatedByUserGuid, 
	@CheckedByUserGuid = @CheckedByUserGuid, 
	@Guid = @Guid', 179, 136, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'AssetMergeBatchUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (325, 1, 'd48e0100-89f2-4026-81df-1e2239f9f3f4', N'Asset Merge Batch Validate', N'SELECT * FROM [SJob].[tvf_AssetMergeBatchValidate] ( @SourceAssetGuid, @TargetAssetGuid, @CreatedByUserGuid, @CheckedByUserGuid, @IsComplete, @Guid) root_hobt', 179, 136, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SJob', N'tvf_AssetMergeBatchValidate', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (326, 1, 'da902a09-5e3f-4034-b567-f8cc9141e1b1', N'Asset Merge Batch Data Pills', N'SELECT * FROM [SJob].[tvf_AssetMergeBatch_DataPills] ( @Guid, @CheckedByUserGuid, @IsComplete) root_hobt', 179, 136, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, N'SJob', N'tvf_AssetMergeBatch_DataPills', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (327, 1, 'e028af94-5204-4971-b26c-712237fe84db', N'Asset Possible Duplicates Read', N'SELECT 
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsDifferent,
	root_hobt.IsDuplicate,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	[D6006AD9-9072-4C2B-A9F8-AB141E1A7A5A].Guid AS SourceAssetID,
	[4AFC3515-BC32-4017-A2EA-73AC7A02236C].Guid AS TargetAssetID
FROM SJob.AssetPossibleDuplicates AS root_hobt 
JOIN SJob.Assets AS [D6006AD9-9072-4C2B-A9F8-AB141E1A7A5A] ON ([D6006AD9-9072-4C2B-A9F8-AB141E1A7A5A].ID = root_hobt.SourceAssetID) 
 JOIN SJob.Assets AS [4AFC3515-BC32-4017-A2EA-73AC7A02236C] ON ([4AFC3515-BC32-4017-A2EA-73AC7A02236C].ID = root_hobt.TargetAssetID) 
', 184, 140, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'AssetPossibleDuplicates', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (328, 1, 'ba120c51-c290-40e7-b01b-970444fc7d92', N'AssetPossibleDuplicatesUpsert', N'EXEC [SJob].[AssetPossibleDuplicatesUpsert]  
	@IsDifferent = @IsDifferent, 
	@IsDuplicate = @IsDuplicate, 
	@Guid = @Guid', 184, 140, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'AssetPossibleDuplicatesUpsert', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (329, 1, '1585409e-4e10-4546-9275-99a45afbdc59', N'Contract Type Read', N'SELECT 
            root_hobt.ID,
            root_hobt.RowStatus,
            root_hobt.RowVersion,
            root_hobt.Guid,
            root_hobt.Code,
            root_hobt.Name,
            root_hobt.IsActive
FROM 
           SSop.ContractTypes root_hobt
          ', 185, 141, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SSop', N'ContractTypes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (330, 1, '7d186fcc-ad61-4727-9d3f-244b39133028', N'Contract Type Upsert', N'EXEC [SSop].[ContractTypeUpsert] @Guid = @Guid, @Code = @Code, @Name = @Name, @IsActive = @IsActive', 185, 141, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (331, 1, '156f220d-8533-4a2c-a4d2-215fa2a77296', N'Quote Memos Delete', N'EXEC SSop.QuoteMemosDelete @Guid = @Guid', 104, 96, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SSop', N'QuoteMemos', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (332, 1, '3138ca92-58f4-4f6f-aeb5-22e20499668a', N'Account Merge Batch Delete', N'EXEC [SCrm].[AccountMergeBatchDelete]  
	@Guid = @Guid', 93, 85, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SCrm', N'AccountMergeBatchDelete', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (333, 1, 'f5e0de7a-494b-4cb2-ad74-2347fab52f34', N'Job Type Activity Types Delete', N'EXEC [SJob].[JobTypeActivityTypesDelete] @Guid = @Guid', 81, 73, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SJob', N'JobTypeActivityTypes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (334, 1, 'e3ca5f9f-2934-4c9c-a7c3-1f95d5faf5f3', N'[SJob].[JobTypesDelete]', N'EXEC [SJob].[JobTypesDelete] @Guid = @Guid', 41, 39, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'SJob', N'JobTypes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (335, 1, '96a138f6-6d20-41bb-848b-e7875f69f56e', N'Re-open Cancelled Job', N'EXEC [SJob].[JobReopenClosedJob] @Guid = @Guid', 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobReopenClosedJob', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (336, 1, 'c73bbf05-c4b5-43db-ac42-4c292da20b4e', N'Re-open Dead Job', N'EXEC [SJob].[JobReopenDeadJob] @Guid = @Guid', 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'SJob', N'JobReopenDeadJob', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (337, 1, '87f9669f-4a18-4215-a735-a8cd8a5e55a6', N'Entity Properties Validate', N'SELECT * FROM [SCore].[tvf_EntityPropertiesValidate](@Guid) root_hobt', 6, 6, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'SCore', N'tvf_EntityPropertiesValidate', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (338, 1, '1cbef092-a000-4739-990a-e5932c7a6cc7', N'Workflow Read', N'SELECT 
	root_hobt.ID,
	root_hobt.Name,
	root_hobt.Description,
	root_hobt.Enabled,
	root_hobt.EntityHoBTID,
	Et.Guid AS EntityTypeID,
	root_hobt.Guid,
	og.Guid  AS OrganisationalUnitId,
	root_hobt.RowStatus,
	root_hobt.RowVersion
FROM 
	SCore.Workflow AS root_hobt 
JOIN 
	SCore.EntityTypes AS Et ON (Et.ID = root_hobt.EntityTypeID)
JOIN 
	SCore.OrganisationalUnits AS og ON (og.ID = root_hobt.OrganisationalUnitId)
', 188, 144, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'Workflow', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (339, 1, 'b18d8a04-a6cd-4acc-82fb-0f98fc37d948', N'Workflow Status Read', N' SELECT 
        root_hobt.Colour,
        root_hobt.Description,
        root_hobt.Enabled,
        root_hobt.Guid,
        root_hobt.Icon,
        root_hobt.ID,
        root_hobt.IsActiveStatus,
        root_hobt.IsCompleteStatus,
        root_hobt.IsCustomerWaitingStatus,
        root_hobt.IsPredefined,
        root_hobt.Name,
        Org.Guid AS OrganisationalUnitId,
        root_hobt.RequiresUsersAction,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.SendNotification,
        root_hobt.AuthorisationNeeded,
        root_hobt.ShowInEnquiries,
        root_hobt.ShowInJobs,
        root_hobt.ShowInQuotes,
        root_hobt.SortOrder
    FROM SCore.WorkflowStatus AS root_hobt 
    JOIN SCore.OrganisationalUnits AS Org 
        ON Org.ID = root_hobt.OrganisationalUnitId', 187, 143, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'WorkflowStatus', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (340, 1, '0b797b27-d56a-4494-b3e7-ee80ff9ca89b', N'Workflow Transition Read', N'SELECT 
	root_hobt.Description,
	root_hobt.Enabled,
	WfSF.Guid AS FromStatusID,
	WfST.Guid AS ToStatusID,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsFinal,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.SortOrder,
	Wf.Guid AS WorkflowID
FROM 
	SCore.WorkflowTransition AS root_hobt 
JOIN
	SCore.WorkflowStatus AS WfSF ON (WfSF.ID = root_hobt.FromStatusID)
JOIN
	SCore.WorkflowStatus AS WfST ON (WfST.ID = root_hobt.ToStatusID)
JOIN
	SCore.Workflow AS Wf ON (Wf.ID = root_hobt.WorkflowID)

', 194, 149, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'WorkflowTransition', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (341, 1, '653972d0-8861-4b90-b05f-8e58338c693d', N'Workflow Upsert', N'EXEC [SCore].[WorkflowUpsert] 
        @Guid = @Guid, 
        @RowStatus = @RowStatus, 
        @EntityTypeGuid = @EntityTypeGuid, 
        @Name = @Name, 
        @Description = @Description, 
        @Enabled = @Enabled,
        @OrganisationalUnitGuid = @OrganisationalUnitGuid', 188, 144, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'Workflow', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (342, 1, '32619c73-bd04-4943-a570-6b69292dbd17', N'Icons Upsert', N'EXEC [SUserInterface].[IconsUpsert] @Guid = @Guid,  @Name = @Name', 105, 97, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'Icons', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (343, 1, 'bf256512-c90f-4344-9ba7-814c977aa39d', N'Icons Read', N'SELECT 
	root_hobt.Guid,
	root_hobt.Name,
	root_hobt.RowVersion,
	root_hobt.RowStatus
FROM 
	[SUserInterface].[Icons] AS root_hobt', 105, 97, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'Icons', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (344, 1, '0f87c60d-408a-4e73-9781-5609e930070b', N'Workflow Transition Upsert', N'EXEC [SCore].[WorkflowTransitionUpsert] 
         @Guid = @Guid,
         @WorkflowGuid = @WorkflowGuid,
         @FromStatusGuid = @FromStatusGuid,
         @ToStatusGuid = @ToStatusGuid,
         @IsFinal = @IsFinal,
         @Enabled = @Enabled,
         @SortOrder = @SortOrder,
         @Description = @Description', 194, 149, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'WorkflowTransition', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (345, 1, '2601f186-9054-47d1-a000-ab9419157921', N'Workflow Status Delete', N'EXEC [SCore].[WorkflowStatusDelete] @Guid = @Guid', 187, 143, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (346, 1, 'c7ab723f-3355-4af5-8ca1-4e5ad0aae6d5', N'Workflow Status Upsert', N'EXEC [SCore].[WorkflowStatusUpsert]
	@Guid					= @Guid,								
	@Enabled				= @Enabled,				
	@Name					= @Name,					
	@Description			        = @Description,			
	@OrganisationUnitGuid		= @OrganisationUnitGuid,		
	@SortOrder				= @SortOrder,				
	@RequiresUserAction		= @RequiresUserAction,		
	@IsPredefined			        = @IsPredefined,			
	@ShowInEnquiries		        = @ShowInEnquiries,		
	@ShowInQuotes			= @ShowInQuotes,			
	@ShowInJobs				= @ShowInJobs,				
	@IsActiveStatus			= @IsActiveStatus,			
	@IsCustomerWaitingStatus    = @IsCustomerWaitingStatus,
	@IsCompleteStatus		        = @IsCompleteStatus,		
	@Colour					= @Colour,					
	@Icon					= @Icon,					
	@SendNotification		        = @SendNotification,
	@AuthorisationNeeded            = @AuthorisationNeeded	
   ', 187, 143, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (347, 1, '52dfd40e-aa37-4fb1-a5df-14b63c1a55cf', N'Workflow Transition Delete', N'EXEC [SCore].[WorkflowTransitionDelete] @Guid = @Guid', 194, 149, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (348, 1, '0d7be618-4109-47ea-b0c5-fe7ec4bbd2eb', N'Workflow Delete', N'EXEC [SCore].[WorkflowDelete] @Guid = @Guid', 188, 144, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (349, 1, 'a2450459-dde8-41ac-8e96-b66cca259c67', N'DataObjectTransition Read', N'SELECT 
	  root_hobt.ID,
      root_hobt.RowStatus,
      root_hobt.RowVersion,
      root_hobt.Guid,
      WfSNew.Guid AS StatusID,
      WfSOld.Guid AS OldStatusID,
      root_hobt.Comment,
      root_hobt.DateTimeUTC,
      CreatedBy.Guid AS CreatedByUserId,
      Surveyor.Guid AS SurveyorUserId,
      root_hobt.DataObjectGuid,
      root_hobt.IsImported
  FROM SCore.DataObjectTransition AS root_hobt
  LEFT JOIN SCore.WorkflowStatus AS WfSOld ON (WfSOld.ID = OldStatusID)
  LEFT JOIN SCore.WorkflowStatus AS WfSNew ON (WfSNew.ID = StatusID)
  JOIN SCore.Identities AS CreatedBy ON (CreatedBy.ID = root_hobt.CreatedByUserId)
  JOIN SCore.Identities AS Surveyor ON (Surveyor.ID = root_hobt.SurveyorUserId)', 190, 145, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'SCore', N'DataObjectTransition', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (350, 1, 'd6bbc88a-26f1-47bc-979f-1cb7fda24224', N'DataObjectTransition Upsert', N'EXEC [SCore].[DataObjectTransitionUpsert] 
          @Guid = @Guid,
          @OldStatusGuid = @OldStatusGuid,
          @StatusGuid = @StatusGuid,
          @Comment = @Comment,
          @CreatedByUserGuid = @CreatedByUserGuid,
          @SurveyorUserGuid= @SurveyorUserGuid,
          @DataObjectGuid= @DataObjectGuid,
          @IsImported= @IsImported', 190, 145, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (351, 1, '7e060530-bd9f-4520-9409-56e68f1f4f2e', N'DataObjectTransition Validate', N'SELECT * FROM [SCore].[tvf_DataObjectTransitionValidate]  (@Guid, @DataObjectGuid, @NewStatusGuid, @Comment) root_hobt', 190, 145, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (352, 1, '59257abc-0e87-4386-ab7d-e7301fb938f2', N'Workflow Validate', N'SELECT * FROM [SCore].[tvf_WorkflowValidate] (@Guid, @Name, @Description, @EntityTypeGuid, @IsEnabled, @OrgUnitGuid)', 188, 144, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (353, 1, 'c63ccb94-840b-4cb2-8c5d-97a0cd573c91', N'DataObjectTransition Delete', N'EXEC [SCore].[DataObjectTransitionDelete] @Guid = @Guid', 190, 145, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (354, 1, '8ae740f2-0bac-47da-bc84-90579d47d404', N'Workflow Transition Validate', N'SELECT * FROM [SCore].[tvf_WorkflowTransitionValidate]
(
   @Guid,			
   @Description,   
   @FromStatusGuid,
   @ToStatusGuid, 
   @IsFinal,       
   @Enabled,
   @WorkflowGuid       
)', 194, 149, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (355, 1, 'd644fe11-2525-40f5-bb27-9a244b906d1d', N'Workflow Status Validate', N'SELECT * FROM [SCore].[tvf_WorkflowStatusValidate]
(
    @Guid,
    @OrganisationalUnitGuid
)', 187, 143, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (356, 1, '4bc8458a-a8b3-4bc0-a086-bcd08f045b54', N'GridViewTypesUpsert', N'EXEC [SUserInterface].[GridViewTypesUpsert] @Name = @Name, @Guid = @Guid', 121, 113, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'SUserInterface', N'GridViewTypes', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (357, 1, '7c1b2fa3-1c14-4a5c-87f1-5df51af80090', N'[SFin].[InvoicePaymentStatus] Read', N'SELECT 
	root_hobt.ID,
	root_hobt.Guid,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Name
FROM [SFin].[InvoicePaymentStatus] AS root_hobt', 196, 151, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (358, 1, '8d22bbd8-1862-4413-80cf-8b3cded80868', N'[SFin].[InvoicePaymentStatus] Upsert', N'EXEC [SFin].[InvoicePaymentStatusUpsert] @Name = @Name, @Guid = @Guid', 196, 151, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);

INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (359, 1, '97d1f8c1-b986-45ad-999f-13663df4c5bd', N'SFin.InvoiceSchedules Read', N'SELECT 
	root_hobt.ID,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Guid,
	root_hobt.Name,
	root_hobt.DescriptionOfWork,
	root_hobt.Amount,
	ist.Guid AS TriggerId,
	root_hobt.ExpectedDate,
	q.Guid AS QuoteId,
    actmilconf.OnMilestoneCompletion,
	actmilconf.OnActivityCompletion,
	actmilconf.OnActivityAndMilestonCompletion,
	ribaconf.RibaOnCompletion,
	ribaconf.RibaOnPartCompletion
FROM  [SFin].[InvoiceSchedules] AS root_hobt
JOIN SFin.InvoiceScheduleTrigger AS ist ON (ist.ID = root_hobt.TriggerId)
JOIN SSop.Quotes AS q ON (q.ID = root_hobt.QuoteId)
JOIN SFin.InvoiceScheduleActivityMilestoneConfiguration AS actmilconf ON (root_hobt.ActivityMilestoneConfigurationId = actmilconf.ID)
JOIN SFin.InvoiceScheduleRibaConfiguration AS ribaconf ON (root_hobt.RibaConfigurationId = ribaconf.ID)', 200, 155, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (360, 1, '5b098bed-79d3-4a90-a1c7-208a9d3f4e44', N'SFin.InvoiceScheduleTrigger Read', N'SELECT 
	root_hobt.ID,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Guid,
	root_hobt.Name
FROM  [SFin].[InvoiceScheduleTrigger] AS root_hobt', 198, 153, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (361, 1, '44241425-2558-43e3-a750-acd737340f8d', N'SFin.InvoiceScheduleTrigger Upsert', N'EXEC [SFin].[InvoiceScheduleTriggerUpsert] @Guid = @Guid, @Name = @Name', 198, 153, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (362, 1, 'e1ec5876-e6c0-42ef-b4ba-4a2537bd3936', N'SFin.InvoiceSchedules Upsert', N'EXEC [SFin].[InvoiceSchedulesUpsert] 
	@Guid = @Guid, 
	@Name = @Name, 
	@TriggerGuid = @TriggerGuid, 
	@ExpectedDate = @ExpectedDate, 
	@DescriptionOfWork = @DescriptionOfWork, 
	@Amount = @Amount, 
	@QuoteGuid = @QuoteGuid,
	@RibaOnCompletion = @RibaOnCompletion,
	@RibaOnPartCompletion = @RibaOnPartCompletion,
	@OnMilestoneCompletion = @OnMilestoneCompletion,
	@OnActivityCompletion = @OnActivityCompletion,
	@OnActivityAndMilestonCompletion = @OnActivityAndMilestonCompletion', 200, 155, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (363, 1, '2c7c303b-7322-4cb1-9700-b2767f078c93', N'[SFin].[InvoiceScheduleTriggerDelete]', N'EXEC [SFin].[InvoiceScheduleTriggerDelete] @Guid = @Guid', 198, 153, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (364, 1, '6a405104-6441-4372-932c-cc759006a103', N'Riba Config Read', N'SELECT 
	ribaconf.RibaOnCompletion,
	ribaconf.RibaOnPartCompletion
FROM  [SFin].[InvoiceSchedules] AS root_hobt
JOIN SSop.Quotes AS q ON (q.ID = root_hobt.QuoteId)
JOIN SFin.InvoiceScheduleRibaConfiguration AS ribaconf ON (root_hobt.RibaConfigurationId = ribaconf.ID)', 200, 156, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (365, 1, 'e6dd3f41-b88e-4687-b6fb-ee1b96c5e01b', N'Activity Milestone Config Read', N'SELECT 
    monthconf.OnMilestoneCompletion,
	monthconf.OnActivityCompletion,
	monthconf.OnActivityAndMilestonCompletion
FROM  [SFin].[InvoiceSchedules] AS root_hobt
JOIN SSop.Quotes AS q ON (q.ID = root_hobt.QuoteId)
JOIN SFin.InvoiceScheduleActivityMilestoneConfiguration AS monthconf ON (root_hobt.ActivityMilestoneConfigurationId = monthconf.ID)
', 200, 157, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (366, 1, 'edee1b73-4bfc-4e68-a204-75e80b5648b1', N'[SFin].[InvoiceSchedules] Validate', N'SELECT * FROM [SFin].[tvf_InvoiceSchedulesValidate]
				(
					@Guid,							
					@TriggerGuid,					
					@OnActivityCompletion,			
					@OnMilestoneCompletion,			
					@OnActivityAndMilestonCompletion,
					@RibaOnCompletion,				
					@RibaOnPartCompletion
				)', 200, 155, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (367, 1, 'e036ba95-4d93-470d-9fbf-5b789d952542', N'[SFin].[InvoiceSchedules] Delete', N'EXEC [SFin].[InvoiceScheduleDelete]  @Guid = @Guid', 200, 155, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (368, 1, 'e8b72a9c-c81e-4942-9fb2-dce7420b5aad', N'Invoice Schedule Month Config Read', N'SELECT 
		root_hobt.ID,
		root_hobt.Guid,
		root_hobt.PeriodNumber,
		root_hobt.Amount,
		root_hobt.OnDayOfMonth,
		root_hobt.Description,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		invsc.Guid AS InvoiceScheduleId
FROM   [SFin].[InvoiceScheduleMonthConfiguration] AS root_hobt
JOIN   [SFin].[InvoiceSchedules] AS invsc ON (invsc.ID = root_hobt.InvoiceScheduleId)', 201, 158, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (369, 1, '2dd2d127-d6c0-4de4-81a3-d428ee6ae018', N'Invoice Schedule Month Config Upsert', N'EXEC [SFin].[InvoiceScheduleMonthConfigurationUpsert]
          @Guid = @Guid,
          @InvoiceScheduleGuid = @InvoiceScheduleGuid,
          @OnDayOfMonth = @OnDayOfMonth,
          @PeriodNumber = @PeriodNumber,
          @Amount = @Amount,
          @Description = @Description', 201, 158, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (370, 1, '71549b96-2cd0-4d92-b5d4-1e8700223b70', N'SFin.InvoiceScheduleMonthConfiguration Validation', N'SELECT * FROM [SFin].[tvf_InvoiceScheduleMonthConfigurationValidate] (@Guid, @OnDayOfMonth, @PeriodNumber, @Amount, @InvoiceScheduleGuid)', 201, 158, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (371, 1, 'e3ae34f8-64d2-442c-91af-a9fbdca7d11a', N'SFin.InvoiceSchedulePercentageConfiguration Read', N'SELECT 
		root_hobt.ID,
		root_hobt.Guid,
		root_hobt.PeriodNumber,
		root_hobt.Percentage,
		root_hobt.OnDayOfMonth,
		root_hobt.Description,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		invsc.Guid AS InvoiceScheduleId
FROM   [SFin].[InvoiceSchedulePercentageConfiguration] AS root_hobt
JOIN   [SFin].[InvoiceSchedules] AS invsc ON (invsc.ID = root_hobt.InvoiceScheduleId)', 203, 160, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (372, 1, '2f5bdd3c-30be-4261-b7e7-2c6f4a53daef', N'SFin.InvoiceSchedulePercentageConfiguration Upsert', N'EXEC [SFin].[InvoiceSchedulePercentageConfigurationUpsert]
          @Guid = @Guid,
          @InvoiceScheduleGuid = @InvoiceScheduleGuid,
          @OnDayOfMonth = @OnDayOfMonth,
          @PeriodNumber = @PeriodNumber,
          @Percentage= @Percentage,
          @Description = @Description', 203, 160, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);

GO
SET IDENTITY_INSERT SCore.EntityQueries OFF
GO
SET IDENTITY_INSERT SCore.EntityQueries ON
GO
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (373, 1, 'fda2e5b5-35fb-4dbf-ac79-6f2224018843', N'[SJob].[SubContractorInvoices] Read', N'SELECT 
    root_hobt.ID,
    root_hobt.RowStatus,
    root_hobt.RowVersion,
    root_hobt.Guid,
    root_hobt.SubContractorName,
    root_hobt.InvoiceDate,
    root_hobt.InvoiceNumber,
    root_hobt.DescriptionOfWork,
    root_hobt.ValueWithVAT,
    root_hobt.ValueWithoutVAT,
	j.Guid AS JobId,
    act.Guid AS ActivityId,
    mil.Guid AS MilestoneId,
    root_hobt.SupportingComments
FROM SJob.SubContractorInvoices AS root_hobt
JOIN SJob.Activities AS act ON (act.ID = root_hobt.ActivityId)
JOIN SJob.Milestones AS mil ON (mil.ID = root_hobt.MilestoneId)
JOIN SJob.Jobs AS j ON (j.ID = root_hobt.JobId)', 205, 162, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (374, 1, '4a8827a0-5ed9-4c63-8327-7628c52e2c7e', N'[SJob].[SubContractorInvoices] Upsert', N'EXEC [SJob].[SubContractorInvoicesUpsert] 
                     @Guid = @Guid,
                     @InvoiceNumber = @InvoiceNumber ,
                     @InvoiceDate = @InvoiceDate ,
                     @DescriptionOfWork = @DescriptionOfWork ,
                     @SupportingComments = @SupportingComments ,
                     @ActivityGuid = @ActivityGuid ,
                     @MilestoneGuid = @MilestoneGuid,
                     @ValueWithVAT = @ValueWithVAT,
                     @ValueWithoutVAT = @ValueWithoutVAT,
                     @SubContractorName = @SubContractorName ,
                     @JobGuid = @JobGuid
', 205, 162, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);

GO
SET IDENTITY_INSERT SCore.EntityQueries OFF
GO
SET IDENTITY_INSERT SCore.EntityQueries ON
GO
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (375, 1, 'e97c4c8f-ade4-497c-8732-c655989e13ea', N'Purchase Orders Read', N'SELECT
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Number,
		root_hobt.Description,
		root_hobt.Value,
		root_hobt.DateReceived,
		root_hobt.ValidUntilDate,
		act.Guid AS ActivityId,
		riba.Guid AS StageId,
		asset.Guid AS SiteId,
		j.Guid AS JobId
FROM SJob.PurchaseOrders AS root_hobt
JOIN SJob.RibaStages as riba ON (riba.ID = root_hobt.StageId)
JOIN SJob.Activities as act ON (act.ID = root_hobt.ActivityId)
JOIN SJob.Assets as asset ON (asset.ID = root_hobt.SiteId)
JOIN SJob.Jobs AS j ON (j.ID = root_hobt.JobId)', 209, 165, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (376, 1, 'fea51d25-43b6-4ada-b9c3-04f07e116668', N'Purchase Orders Upsert', N'EXEC [SJob].[PurchaseOrdersUpsert] 
                @Guid = @Guid,
                @Number = @Number,
                @Description = @Description,
                @Value = @Value,
                @DateReceived = @DateReceived,
                @ValidUntilDate = @ValidUntilDate,
                @ActivityGuid = @ActivityGuid,
                @JobGuid = @JobGuid', 209, 165, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);

GO
SET IDENTITY_INSERT SCore.EntityQueries OFF
GO
SET IDENTITY_INSERT SCore.EntityQueries ON
GO
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (377, 0, '06f39456-6297-48c5-bca6-7cb825005031', N'SCore.WorkflowStatusNotificationGroups Read', N'', 207, 163, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 0);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (378, 1, '23bcc6fa-14e4-47ff-a4e0-c10d68fd54ec', N'SCore.WorkflowStatusNotificationGroups Read', N'SELECT 
		root_hobt.ID,
                root_hobt.Guid,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		wf.Guid AS WorkflowID,
		root_hobt.WorkflowStatusGuid,
		ug.Guid AS GroupID,
                root_hobt.CanAction
FROM 
		SCore.WorkflowStatusNotificationGroups AS root_hobt
JOIN
		SCore.Groups as ug ON (ug.ID = root_hobt.GroupID)
JOIN
		SCore.Workflow AS wf ON (wf.ID = root_hobt.WorkflowID)
', 207, 163, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (379, 1, 'a9d25f42-cdfc-4e33-9713-bf1d39cb2540', N'[SCore].[WorkflowStatusNotificationGroupsUpsert] Upsert', N'EXEC [SCore].[WorkflowStatusNotificationGroupsUpsert] @WorkflowGuid = @WorkflowGuid, @UserGroupGuid = @UserGroupGuid, @CanAction = @CanAction, @Guid = @Guid', 207, 163, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
GO
SET IDENTITY_INSERT SCore.EntityQueries OFF
GO
SET IDENTITY_INSERT SCore.EntityQueries ON
GO
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (380, 1, '315b03a7-e328-4325-a6f0-f1786c905d7a', N'[SCore].[Markets] Read', N'SELECT 
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM SCore.Markets AS root_hobt', 211, 167, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (381, 1, '65f8ea7a-5f7b-4641-95e0-10dadf9e384e', N'[SCore].[Markets] Upsert', N'EXEC [SCore].[MarketsUpsert] @Guid = @Guid, @Name = @Name', 211, 167, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, N'', N'', 1);
INSERT SCore.EntityQueries(ID, RowStatus, Guid, Name, Statement, EntityTypeID, EntityHoBTID, IsDefaultCreate, IsDefaultRead, IsDefaultUpdate, IsDefaultDelete, IsScalarExecute, IsDefaultValidation, UsesProcessGuid, IsDefaultDataPills, IsProgressData, IsMergeDocumentQuery, SchemaName, ObjectName, IsManualStatement) VALUES (382, 1, '068a963f-40a0-4372-a45c-e86e613adc0b', N'FeeProposal Merge Read', N'SELECT 
	root_hobt.AgentAccountName,
	root_hobt.AgentAddressLineOne,
	root_hobt.AgentAddressLineThree,
	root_hobt.AgentAddressLineTwo,
	root_hobt.AgentContact,
	root_hobt.AgentPostcode,
	root_hobt.ClientAccountName,
	root_hobt.ClientAddress,
	root_hobt.ClientAddressBlock,
	root_hobt.ClientAddressLine1,
	root_hobt.ClientAddressLine2,
	root_hobt.ClientAddressLine3,
	root_hobt.ClientAddressLineOne,
	root_hobt.ClientAddressLineThree,
	root_hobt.ClientAddressLineTwo,
	root_hobt.ClientCompanyRegNo,
	root_hobt.ClientContact,
	root_hobt.ClientContactName,
	root_hobt.ClientCounty,
	root_hobt.ClientEmail,
	root_hobt.ClientFirstName,
	root_hobt.ClientMobile,
	root_hobt.ClientName,
	root_hobt.ClientPhone,
	root_hobt.ClientPostcode,
	root_hobt.ClientSurname,
	root_hobt.ClientTown,
	root_hobt.Construction,
	root_hobt.DateQuoteSent,
	root_hobt.FeeCap,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.OfficialAddressLine1,
	root_hobt.OfficialAddressLine2,
	root_hobt.OfficialAddressLine3,
	root_hobt.OfficialCounty,
	root_hobt.OfficialEmail,
	root_hobt.OfficialMobile,
	root_hobt.OfficialName,
	root_hobt.OfficialPhone,
	root_hobt.OfficialPostcode,
	root_hobt.OfficialTown,
	root_hobt.PreConstruction,
	root_hobt.ProjectName,
	root_hobt.PropertyAddress,
	root_hobt.PropertyAddressBlock,
	root_hobt.PropertyAddressLine1,
	root_hobt.PropertyAddressLine2,
	root_hobt.PropertyAddressLine3,
	root_hobt.PropertyCounty,
	root_hobt.PropertyPostcode,
	root_hobt.PropertyShortAddress,
	root_hobt.PropertyTown,
	root_hobt.QuoteDate,
	root_hobt.QuoteNumber,
	root_hobt.QuoteOverview,
	root_hobt.QuotingConsultantEmail,
	root_hobt.QuotingConsultantInitials,
	root_hobt.QuotingConsultantJobTitle,
	root_hobt.QuotingConsultantName,
	root_hobt.QuotingConsultantPostNominals,
	root_hobt.QuotingUserEmail,
	root_hobt.QuotingUserInitials,
	root_hobt.QuotingUserJobTitle,
	root_hobt.QuotingUserName,
	root_hobt.QuotingUserPostNominals,
	root_hobt.RecipientAddress,
	root_hobt.RecipientAddressBlock,
	root_hobt.RecipientAddressLine1,
	root_hobt.RecipientAddressLine2,
	root_hobt.RecipientAddressLine3,
	root_hobt.RecipientCompanyRegNo,
	root_hobt.RecipientContactName,
	root_hobt.RecipientCounty,
	root_hobt.RecipientEmail,
	root_hobt.RecipientFirstName,
	root_hobt.RecipientMobile,
	root_hobt.RecipientName,
	root_hobt.RecipientPhone,
	root_hobt.RecipientPostcode,
	root_hobt.RecipientSurname,
	root_hobt.RecipientTown,
	root_hobt.RevisionNumber,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Stage1Net,
	root_hobt.Stage2Net,
	root_hobt.Stage3Net,
	root_hobt.Stage4Net,
	root_hobt.Stage5Net,
	root_hobt.Stage6Net,
	root_hobt.Stage7Net,
	root_hobt.TotalNetFees,
	root_hobt.UPRN
FROM SSop.FireEngineering_Fee_Proposal_MergeInfo AS root_hobt 
', 204, 161, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, N'SSop', N'FireEngineering_Fee_Proposal_MergeInfo', 0);
GO
SET IDENTITY_INSERT SCore.EntityQueries OFF
GO