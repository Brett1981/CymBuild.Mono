SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SUserInterface].[GridViewDefinitionDuplicate]
	(	@SourceGuid UNIQUEIDENTIFIER,
		@TargetGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @SourceId INT,
			@TargetId INT;

	SELECT	@SourceId = ID
	FROM	SUserInterface.GridViewDefinitions
	WHERE	(Guid = @SourceGuid);

	INSERT	SUserInterface.GridViewDefinitions
		 (RowStatus,
		  Guid,
		  Code,
		  LanguageLabelId,
		  GridDefinitionId,
		  DetailPageUri,
		  SqlQuery,
		  DefaultSortColumnName,
		  SecurableCode,
		  DisplayOrder,
		  DisplayGroupName,
		  MetricSqlQuery,
		  ShowMetric,
		  IsDetailWindowed,
		  EntityTypeID,
		  MetricTypeID,
		  MetricMin,
		  MetricMax,
		  MetricMinorUnit,
		  MetricMajorUnit,
		  MetricStartAngle,
		  MetricEndAngle,
		  MetricReversed,
		  MetricRange1Min,
		  MetricRange1Max,
		  MetricRange1ColourHex,
		  MetricRange2Min,
		  MetricRange2Max,
		  MetricRange2ColourHex,
		  DrawerIconId,
		  IsDefaultSortDescending,
		  AllowNew,
		  AllowExcelExport,
		  AllowPdfExport,
		  AllowCsvExport)
	SELECT	1,
			@TargetGuid,
			LEFT(Code, 18) + N'_C',
			LanguageLabelId,
			GridDefinitionId,
			DetailPageUri,
			SqlQuery,
			DefaultSortColumnName,
			SecurableCode,
			0,
			DisplayGroupName,
			MetricSqlQuery,
			ShowMetric,
			IsDetailWindowed,
			EntityTypeID,
			MetricTypeID,
			MetricMin,
			MetricMax,
			MetricMinorUnit,
			MetricMajorUnit,
			MetricStartAngle,
			MetricEndAngle,
			MetricReversed,
			MetricRange1Min,
			MetricRange1Max,
			MetricRange1ColourHex,
			MetricRange2Min,
			MetricRange2Max,
			MetricRange2ColourHex,
			DrawerIconId,
			IsDefaultSortDescending,
			AllowNew,
			AllowExcelExport,
			AllowPdfExport,
			AllowCsvExport
	FROM	SUserInterface.GridViewDefinitions
	WHERE	(ID = @SourceId);

	SELECT	@TargetId = SCOPE_IDENTITY ();

	INSERT	SUserInterface.GridViewColumnDefinitions
		 (RowStatus,
		  Guid,
		  Name,
		  ColumnOrder,
		  LanguageLabelId,
		  GridViewDefinitionId,
		  IsPrimaryKey,
		  IsHidden,
		  IsFiltered,
		  IsCombo,
		  IsLongitude,
		  IsLatitude,
		  DisplayFormat,
		  Width)
	SELECT	1,
			NEWID (),
			Name,
			ColumnOrder,
			LanguageLabelId,
			@TargetId,
			IsPrimaryKey,
			IsHidden,
			IsFiltered,
			IsCombo,
			IsLongitude,
			IsLatitude,
			DisplayFormat,
			Width
	FROM	SUserInterface.GridViewColumnDefinitions
	WHERE	(GridViewDefinitionId = @SourceId)
		AND (RowStatus NOT IN (0, 254));


END;
GO