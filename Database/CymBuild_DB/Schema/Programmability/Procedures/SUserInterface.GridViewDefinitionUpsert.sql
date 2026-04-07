SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SUserInterface].[GridViewDefinitionUpsert]
  (
    @Code													NVARCHAR(20),
    @RowStatus												TINYINT,
    @GridDefinitionGuid										UNIQUEIDENTIFIER,
    @DetailPageUri											NVARCHAR(250),
    @SqlQuery												NVARCHAR(MAX),
    @DefaultSortColumnName									NVARCHAR(250),
    @SecurableCode											NVARCHAR(20),
    @DisplayOrder											INT,
    @DisplayGroupName										NVARCHAR(50),
    @MetricSqlQuery											NVARCHAR(MAX),
    @ShowMetric												BIT,
    @IsDetailWindowed										BIT,
    @EntityTypeGuid											UNIQUEIDENTIFIER,
    @MetricTypeGuid											UNIQUEIDENTIFIER,
    @MetricMin												INT,
    @MetricMax												INT,
    @MetricMinorUnit										INT,
    @MetricMajorUnit										INT,
    @MetricStartAngle										INT,
    @MetricEndAngle											INT,
    @MetricReversed											BIT,
    @MetricRange1Min										DECIMAL(18, 0),
    @MetricRange1Max										DECIMAL(18, 0),
    @MetricRange1ColourHex									NVARCHAR(10),
    @MetricRange2Min										DECIMAL(18, 0),
    @MetricRange2Max										DECIMAL(18, 0),
    @MetricRange2ColourHex									NVARCHAR(10),
    @IsDefaultSortDescending								BIT,
    @AllowNew												BIT,
    @AllowExcelExport										BIT,
    @AllowPdfExport											BIT,
    @AllowCsvExport											BIT,
    @LanguageLabelGuid										UNIQUEIDENTIFIER,
    @DrawerIconGuid											UNIQUEIDENTIFIER,
	@GridViewTypeGuid										UNIQUEIDENTIFIER,
	@AllowBulkChange										BIT,
    @Guid													UNIQUEIDENTIFIER OUT,
	@ShowOnMobile											BIT,
	@TreeListFirstOrderBy									NVARCHAR(100),
	@TreeListSecondOrderBy									NVARCHAR(100),
	@TreeListThirdOrderBy									NVARCHAR(100),
	@TreeListOrderBy										NVARCHAR(100),
	@TreeListGroupBy										NVARCHAR(100),
	@ShowOnDashboard										BIT,
	@FilteredListCreatedOnColumn							NVARCHAR(100),
	@FilteredListRedStatusIndicatorTxt						NVARCHAR(100),
	@FilteredListOrangeStatusIndicatorTxt					NVARCHAR(100),
	@FilteredListGreenStatusIndicatorTxt					NVARCHAR(100),
	@FilteredListGroupBy									NVARCHAR(100)

  )
AS
  BEGIN
    DECLARE @LanguageLabelID  INT = -1,
            @GridDefinitionID INT,
            @EntityTypeID     INT,
            @MetricTypeID     INT = -1,
			@GridViewTypeID		INT = -1,
            @DrawerIconId     INT = -1;



    SELECT
            @GridDefinitionID = ID
    FROM
            SUserInterface.GridDefinitions
    WHERE
            ([Guid] = @GridDefinitionGuid)

    SELECT
            @EntityTypeID = ID
    FROM
            SCore.EntityTypes
    WHERE
            ([Guid] = @EntityTypeGuid)

    SELECT
            @MetricTypeID = ID
    FROM
            SUserInterface.MetricTypes
    WHERE
            ([Guid] = @MetricTypeGuid)

    SELECT
            @LanguageLabelID = ID
    FROM
            SCore.LanguageLabels ll
    WHERE
            (Guid = @LanguageLabelGuid)

    SELECT
            @DrawerIconId = ID
    FROM
            SUserInterface.Icons i
    WHERE
            (Guid = @DrawerIconGuid)

	SELECT	
			@GridViewTypeID = ID
	FROM	
			SUserInterface.GridViewTypes gvt
	WHERE	
			(gvt.Guid = @GridViewTypeGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'GridViewDefinitions',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        DECLARE @ID INT

        INSERT SUserInterface.GridViewDefinitions
              (
                [Guid],
                LanguageLabelId,
                [RowStatus],
                [Code],
                [GridDefinitionId],
                [DetailPageUri],
                [SqlQuery],
                [DefaultSortColumnName],
                [SecurableCode],
                [DisplayOrder],
                [DisplayGroupName],
                [MetricSqlQuery],
                [ShowMetric],
                [IsDetailWindowed],
                [EntityTypeID],
                [MetricTypeID],
                [MetricMin],
                [MetricMax],
                [MetricMinorUnit],
                [MetricMajorUnit],
                [MetricStartAngle],
                [MetricEndAngle],
                [MetricReversed],
                [MetricRange1Min],
                [MetricRange1Max],
                MetricRange1ColourHex,
                MetricRange2Min,
                MetricRange2Max,
                MetricRange2ColourHex,
                DrawerIconId,
                IsDefaultSortDescending,
                AllowNew,
                AllowExcelExport,
                AllowPdfExport,
                AllowCsvExport,
				GridViewTypeId,
				AllowBulkChange,
				ShowOnMobile,
				TreeListFirstOrderBy,
				TreeListSecondOrderBy,
				TreeListThirdOrderBy,
				TreeListOrderBy,
				TreeListGroupBy,
				ShowOnDashboard,
				FilteredListCreatedOnColumn,
				FilteredListRedStatusIndicatorTxt,	
				FilteredListOrangeStatusIndicatorTxt,	
				FilteredListGreenStatusIndicatorTxt,	
				FilteredListGroupBy					
              )
        VALUES
                (
                  @Guid,
                  @LanguageLabelID,
                  1,
                  @Code,
                  @GridDefinitionID,
                  @DetailPageUri,
                  @SqlQuery,
                  @DefaultSortColumnName,
                  @SecurableCode,
                  @DisplayOrder,
                  @DisplayGroupName,
                  @MetricSqlQuery,
                  @ShowMetric,
                  @IsDetailWindowed,
                  @EntityTypeID,
                  @MetricTypeID,
                  @MetricMin,
                  @MetricMax,
                  @MetricMinorUnit,
                  @MetricMajorUnit,
                  @MetricStartAngle,
                  @MetricEndAngle,
                  @MetricReversed,
                  @MetricRange1Min,
                  @MetricRange1Max,
                  @MetricRange1ColourHex,
                  @MetricRange2Min,
                  @MetricRange2Max,
                  @MetricRange2ColourHex,
                  @DrawerIconId,
                  @IsDefaultSortDescending,
                  @AllowNew,
                  @AllowExcelExport,
                  @AllowPdfExport,
                  @AllowCsvExport,
				  @GridViewTypeID,
				  @AllowBulkChange,
				  @ShowOnMobile,
				  @TreeListFirstOrderBy,
				  @TreeListSecondOrderBy,
				  @TreeListThirdOrderBy,
				  @TreeListOrderBy,
				  @TreeListGroupBy,
				  @ShowOnDashboard,
				  @FilteredListCreatedOnColumn,	
				  @FilteredListRedStatusIndicatorTxt,
				  @FilteredListOrangeStatusIndicatorTxt,	
				  @FilteredListGreenStatusIndicatorTxt,
				  @FilteredListGroupBy
                )

        SELECT
                @ID = SCOPE_IDENTITY()


        DECLARE @NewID1    UNIQUEIDENTIFIER = NEWID(),
                @NewID2    UNIQUEIDENTIFIER = NEWID(),
				@IdLanguageLabel INT, 
				@GuidLanguageLabel INT,
                @IsInsert2 BIT;

		SELECT	@IdLanguageLabel = ll.ID
		FROM	SCore.LanguageLabels AS ll 
		WHERE	ll.Name = N'#_grid_column'

		SELECT	@GuidLanguageLabel = ll.ID
		FROM	SCore.LanguageLabels AS ll 
		WHERE	ll.Name = N'Guid_grid_column'

        EXEC SCore.UpsertDataObject
          @Guid       = @NewID1,
          @SchemeName = N'SUserInterface',
          @ObjectName = N'GridViewColumnDefinitions',
          @IsInsert   = @IsInsert2

        EXEC SCore.UpsertDataObject
          @Guid       = @NewID2,
          @SchemeName = N'SUserInterface',
          @ObjectName = N'GridViewColumnDefinitions',
          @IsInsert   = @IsInsert2

        INSERT SUserInterface.GridViewColumnDefinitions
              (
                RowStatus,
                Guid,
                Name,
                ColumnOrder,
                GridViewDefinitionId,
                IsPrimaryKey,
                IsHidden,
                IsFiltered,
                IsCombo,
                IsLongitude,
                IsLatitude,
				LanguageLabelId
              )
        VALUES
            (
              1,	-- RowStatus - tinyint
              @NewID1,	-- Guid - uniqueidentifier
              N'ID',	-- Name - nvarchar(100)
              999,	-- ColumnOrder - int
              @ID,	-- GridViewDefinitionId - int
              1,	-- IsPrimaryKey - bit
              1,	-- IsHidden - bit
              1,	-- IsFiltered - bit
              0,	-- IsCombo - bit
              0,	-- IsLongitude - bit
              0,	-- IsLatitude - bit
			  @IdLanguageLabel
            ),
            (
              1,	-- RowStatus - tinyint
              @NewID2,	-- Guid - uniqueidentifier
              N'Guid',	-- Name - nvarchar(100)
              0,	-- ColumnOrder - int
              @ID,	-- GridViewDefinitionId - int
              0,	-- IsPrimaryKey - bit
              1,	-- IsHidden - bit
              0,	-- IsFiltered - bit
              0,	-- IsCombo - bit
              0,	-- IsLongitude - bit
              0,	-- IsLatitude - bit
			  @GuidLanguageLabel
            )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.GridViewDefinitions
        SET     [LanguageLabelId] = @LanguageLabelID,
				[Code] = @Code,
                [RowStatus] = @RowStatus,
                [GridDefinitionId] = @GridDefinitionID,
                [DetailPageUri] = @DetailPageUri,
                [SqlQuery] = @SqlQuery,
                [DefaultSortColumnName] = @DefaultSortColumnName,
                [SecurableCode] = @SecurableCode,
                [DisplayOrder] = @DisplayOrder,
                [DisplayGroupName] = @DisplayGroupName,
                [MetricSqlQuery] = @MetricSqlQuery,
                [ShowMetric] = @ShowMetric,
                [IsDetailWindowed] = @IsDetailWindowed,
                [EntityTypeID] = @EntityTypeID,
                MetricTypeID = @MetricTypeID,
                MetricMin = @MetricMin,
                MetricMax = @MetricMax,
                MetricMinorUnit = @MetricMinorUnit,
                MetricMajorUnit = @MetricMajorUnit,
                MetricStartAngle = @MetricStartAngle,
                MetricEndAngle = @MetricEndAngle,
                MetricReversed = @MetricReversed,
                MetricRange1Min = @MetricRange1Min,
                MetricRange1Max = @MetricRange1Max,
                MetricRange1ColourHex = @MetricRange1ColourHex,
                MetricRange2Min = @MetricRange2Min,
                MetricRange2Max = @MetricRange2Max,
                MetricRange2ColourHex = @MetricRange2ColourHex,
                DrawerIconId = @DrawerIconId,
                IsDefaultSortDescending = @IsDefaultSortDescending,
                AllowNew = @AllowNew,
                AllowExcelExport = @AllowExcelExport,
                AllowPdfExport = @AllowPdfExport,
                AllowCsvExport = @AllowCsvExport,
				GridViewTypeId = @GridViewTypeID,
				AllowBulkChange = @AllowBulkChange,
				ShowOnMobile = @ShowOnMobile,
				TreeListFirstOrderBy = @TreeListFirstOrderBy,
				TreeListSecondOrderBy = @TreeListSecondOrderBy,
				TreeListThirdOrderBy = @TreeListThirdOrderBy,
				TreeListOrderBy = @TreeListOrderBy,
				TreeListGroupBy = @TreeListGroupBy,
				ShowOnDashboard = @ShowOnDashboard,
				FilteredListCreatedOnColumn = @FilteredListCreatedOnColumn,
				FilteredListRedStatusIndicatorTxt = @FilteredListRedStatusIndicatorTxt,
				FilteredListOrangeStatusIndicatorTxt = @FilteredListOrangeStatusIndicatorTxt,
				FilteredListGreenStatusIndicatorTxt = @FilteredListGreenStatusIndicatorTxt,
				FilteredListGroupBy = @FilteredListGroupBy		
        WHERE
          ([Guid] = @Guid)
      END
  END




GO