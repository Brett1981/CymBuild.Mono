SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[Assistant_EnsureGridViewDefinition]')
GO

CREATE PROCEDURE [SAi].[Assistant_EnsureGridViewDefinition] (
	@Code NVARCHAR(20)
	,@GridDefinitionGuid UNIQUEIDENTIFIER
	,@DetailPageUri NVARCHAR(250)
	,@SqlQuery NVARCHAR(MAX)
	,@DefaultSortColumnName NVARCHAR(250)
	,@DisplayOrder INT
	,@DisplayGroupName NVARCHAR(50)
	,@EntityTypeGuid UNIQUEIDENTIFIER
	,@LanguageLabelGuid UNIQUEIDENTIFIER
	,@Guid UNIQUEIDENTIFIER OUTPUT
	,@ShowOnMobile BIT = 1
	,@SecurableCode NVARCHAR(20) = N''
	,@MetricSqlQuery NVARCHAR(MAX) = N''
	,@ShowMetric BIT = 0
	,@IsDetailWindowed BIT = 0
	,@MetricTypeGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000'
	,@MetricMin INT = 0
	,@MetricMax INT = 0
	,@MetricMinorUnit INT = 0
	,@MetricMajorUnit INT = 0
	,@MetricStartAngle INT = 0
	,@MetricEndAngle INT = 0
	,@MetricReversed BIT = 0
	,@MetricRange1Min DECIMAL(18, 0) = 0
	,@MetricRange1Max DECIMAL(18, 0) = 0
	,@MetricRange1ColourHex NVARCHAR(10) = N''
	,@MetricRange2Min DECIMAL(18, 0) = 0
	,@MetricRange2Max DECIMAL(18, 0) = 0
	,@MetricRange2ColourHex NVARCHAR(10) = N''
	,@IsDefaultSortDescending BIT = 1
	,@AllowNew BIT = 0
	,@AllowExcelExport BIT = 1
	,@AllowPdfExport BIT = 0
	,@AllowCsvExport BIT = 1
	,@AllowBulkChange BIT = 0
	,@ShowOnDashboard BIT = 0
	,@TreeListFirstOrderBy NVARCHAR(100) = N''
	,@TreeListSecondOrderBy NVARCHAR(100) = N''
	,@TreeListThirdOrderBy NVARCHAR(100) = N''
	,@TreeListOrderBy NVARCHAR(100) = N''
	,@TreeListGroupBy NVARCHAR(100) = N''
	,@FilteredListCreatedOnColumn NVARCHAR(100) = N''
	,@FilteredListRedStatusIndicatorTxt NVARCHAR(100) = N''
	,@FilteredListOrangeStatusIndicatorTxt NVARCHAR(100) = N''
	,@FilteredListGreenStatusIndicatorTxt NVARCHAR(100) = N''
	,@FilteredListGroupBy NVARCHAR(100) = N''
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @GridViewTypeGuid UNIQUEIDENTIFIER = SAi.Assistant_ResolveGridViewTypeGuid(N'Grid');
	DECLARE @DrawerIconGuid UNIQUEIDENTIFIER = SAi.Assistant_ResolveAnyIconGuid();

	IF @GridViewTypeGuid IS NULL
	BEGIN
		SELECT TOP (1) @GridViewTypeGuid = gvt.Guid
		FROM SUserInterface.GridViewTypes AS gvt
		WHERE gvt.RowStatus NOT IN (
				0
				,254
				)
		ORDER BY gvt.ID;
	END;

	IF @GridViewTypeGuid IS NULL
	BEGIN
			;

		THROW 60200
			,N'Unable to resolve a GridViewType Guid for metadata seeding.'
			,1;
	END;

	IF @DrawerIconGuid IS NULL
	BEGIN
			;

		THROW 60201
			,N'Unable to resolve an Icon Guid for metadata seeding.'
			,1;
	END;

	EXEC SUserInterface.GridViewDefinitionUpsert @Code = @Code
		,@RowStatus = 1
		,@GridDefinitionGuid = @GridDefinitionGuid
		,@DetailPageUri = @DetailPageUri
		,@SqlQuery = @SqlQuery
		,@DefaultSortColumnName = @DefaultSortColumnName
		,@SecurableCode = @SecurableCode
		,@DisplayOrder = @DisplayOrder
		,@DisplayGroupName = @DisplayGroupName
		,@MetricSqlQuery = @MetricSqlQuery
		,@ShowMetric = @ShowMetric
		,@IsDetailWindowed = @IsDetailWindowed
		,@EntityTypeGuid = @EntityTypeGuid
		,@MetricTypeGuid = @MetricTypeGuid
		,@MetricMin = @MetricMin
		,@MetricMax = @MetricMax
		,@MetricMinorUnit = @MetricMinorUnit
		,@MetricMajorUnit = @MetricMajorUnit
		,@MetricStartAngle = @MetricStartAngle
		,@MetricEndAngle = @MetricEndAngle
		,@MetricReversed = @MetricReversed
		,@MetricRange1Min = @MetricRange1Min
		,@MetricRange1Max = @MetricRange1Max
		,@MetricRange1ColourHex = @MetricRange1ColourHex
		,@MetricRange2Min = @MetricRange2Min
		,@MetricRange2Max = @MetricRange2Max
		,@MetricRange2ColourHex = @MetricRange2ColourHex
		,@IsDefaultSortDescending = @IsDefaultSortDescending
		,@AllowNew = @AllowNew
		,@AllowExcelExport = @AllowExcelExport
		,@AllowPdfExport = @AllowPdfExport
		,@AllowCsvExport = @AllowCsvExport
		,@LanguageLabelGuid = @LanguageLabelGuid
		,@DrawerIconGuid = @DrawerIconGuid
		,@GridViewTypeGuid = @GridViewTypeGuid
		,@AllowBulkChange = @AllowBulkChange
		,@Guid = @Guid OUTPUT
		,@ShowOnMobile = @ShowOnMobile
		,@TreeListFirstOrderBy = @TreeListFirstOrderBy
		,@TreeListSecondOrderBy = @TreeListSecondOrderBy
		,@TreeListThirdOrderBy = @TreeListThirdOrderBy
		,@TreeListOrderBy = @TreeListOrderBy
		,@TreeListGroupBy = @TreeListGroupBy
		,@ShowOnDashboard = @ShowOnDashboard
		,@FilteredListCreatedOnColumn = @FilteredListCreatedOnColumn
		,@FilteredListRedStatusIndicatorTxt = @FilteredListRedStatusIndicatorTxt
		,@FilteredListOrangeStatusIndicatorTxt = @FilteredListOrangeStatusIndicatorTxt
		,@FilteredListGreenStatusIndicatorTxt = @FilteredListGreenStatusIndicatorTxt
		,@FilteredListGroupBy = @FilteredListGroupBy;
END;
GO