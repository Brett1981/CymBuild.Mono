SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SUserInterface].[GridViewColumnDefinitionUpsert]
  (
    @Name                   NVARCHAR(250),
    @RowStatus              TINYINT,
    @GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @ColumnOrder            INT,
    @IsPrimaryKey           BIT,
    @IsHidden               BIT,
    @IsFiltered             BIT,
    @IsCombo                BIT,
    @DisplayFormat          NVARCHAR(50),
    @Width                  NVARCHAR(10),
    @LanguageLabelGuid      UNIQUEIDENTIFIER,
    @Guid                   UNIQUEIDENTIFIER OUT,
	@TopHeaderCategory		NVARCHAR(50),
	@TopHeaderCategoryOrder INT
  )
AS
  BEGIN
    DECLARE @GridViewDefinitionID INT,
            @LanguageLabelId      INT


    SELECT
            @GridViewDefinitionID = ID
    FROM
            SUserInterface.GridViewDefinitions
    WHERE
            ([Guid] = @GridViewDefinitionGuid)

    SELECT
            @LanguageLabelId = ID
    FROM
            SCore.LanguageLabels ll
    WHERE
            ([Guid] = @LanguageLabelGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'GridViewColumnDefinitions',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SUserInterface.GridViewColumnDefinitions
              (
                [Guid],
                [Name],
                [RowStatus],
                [ColumnOrder],
                [GridViewDefinitionId],
                [IsPrimaryKey],
                [IsHidden],
                [IsFiltered],
                [IsCombo],
                [DisplayFormat],
                [LanguageLabelId],
                Width,
				TopHeaderCategory,
				TopHeaderCategoryOrder
              )
        VALUES
                (
                  @Guid,
                  @Name,
                  1,
                  @ColumnOrder,
                  @GridViewDefinitionID,
                  @IsPrimaryKey,
                  @IsHidden,
                  @IsFiltered,
                  @IsCombo,
                  @DisplayFormat,
                  @LanguageLabelId,
                  @Width,
				  --[NEW] -> [CBLD-383]
				  @TopHeaderCategory,
				  @TopHeaderCategoryOrder
                )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.GridViewColumnDefinitions
        SET     [Name] = @Name,
                [RowStatus] = @RowStatus,
                [ColumnOrder] = @ColumnOrder,
                [GridViewDefinitionId] = @GridViewDefinitionID,
                [IsPrimaryKey] = @IsPrimaryKey,
                [IsHidden] = @IsHidden,
                [IsFiltered] = @IsFiltered,
                [IsCombo] = @IsCombo,
                [DisplayFormat] = @DisplayFormat,
                [LanguageLabelId] = @LanguageLabelId,
                Width = @Width,
				 --[NEW] -> [CBLD-383]
				TopHeaderCategory = @TopHeaderCategory,
				TopHeaderCategoryOrder = @TopHeaderCategoryOrder
        WHERE
          ([Guid] = @Guid)
      END
  END

GO