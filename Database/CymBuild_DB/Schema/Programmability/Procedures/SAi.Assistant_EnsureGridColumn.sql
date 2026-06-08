SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[Assistant_EnsureGridColumn]')
GO
CREATE PROCEDURE [SAi].[Assistant_EnsureGridColumn]
(
    @GridViewGuid UNIQUEIDENTIFIER,
    @ColumnGuid UNIQUEIDENTIFIER,
    @Name NVARCHAR(100),
    @ColumnOrder INT,
    @LanguageLabelName NVARCHAR(250),
    @IsPrimaryKey BIT = 0,
    @IsHidden BIT = 0,
    @IsFiltered BIT = 1,
    @IsCombo BIT = 0,
    @IsLongitude BIT = 0,
    @IsLatitude BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @GridViewDefinitionId INT;
    DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = NEWID();
    DECLARE @LanguageLabelId INT;
    DECLARE @IsInsert BIT;

    SELECT @GridViewDefinitionId = gvd.ID
    FROM SUserInterface.GridViewDefinitions AS gvd
    WHERE gvd.Guid = @GridViewGuid
      AND gvd.RowStatus NOT IN (0,254);

    IF @GridViewDefinitionId IS NULL
    BEGIN
        ;THROW 60210, N'Grid view definition not found for column seed.', 1;
    END;

    EXEC SCore.LanguageLabelUpsert
         @Name = @LanguageLabelName,
         @Guid = @LanguageLabelGuid OUTPUT;

    SELECT @LanguageLabelId = ll.ID
    FROM SCore.LanguageLabels AS ll
    WHERE ll.Guid = @LanguageLabelGuid;

    EXEC SCore.UpsertDataObject
         @Guid = @ColumnGuid,
         @SchemeName = N'SUserInterface',
         @ObjectName = N'GridViewColumnDefinitions',
         @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT INTO SUserInterface.GridViewColumnDefinitions
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
            1,
            @ColumnGuid,
            @Name,
            @ColumnOrder,
            @GridViewDefinitionId,
            @IsPrimaryKey,
            @IsHidden,
            @IsFiltered,
            @IsCombo,
            @IsLongitude,
            @IsLatitude,
            @LanguageLabelId
        );
    END
    ELSE
    BEGIN
        UPDATE SUserInterface.GridViewColumnDefinitions
        SET RowStatus = 1,
            Name = @Name,
            ColumnOrder = @ColumnOrder,
            GridViewDefinitionId = @GridViewDefinitionId,
            IsPrimaryKey = @IsPrimaryKey,
            IsHidden = @IsHidden,
            IsFiltered = @IsFiltered,
            IsCombo = @IsCombo,
            IsLongitude = @IsLongitude,
            IsLatitude = @IsLatitude,
            LanguageLabelId = @LanguageLabelId
        WHERE Guid = @ColumnGuid;
    END;
END;
GO