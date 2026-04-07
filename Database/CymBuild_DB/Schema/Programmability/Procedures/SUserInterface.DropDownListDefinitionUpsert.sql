SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SUserInterface].[DropDownListDefinitionUpsert]
  (
    @Code                  NVARCHAR(20),
    @NameColumn            NVARCHAR(254),
    @ValueColumn           NVARCHAR(254),
    @SqlQuery              NVARCHAR(MAX),
    @DefaultSortColumnName NVARCHAR(254),
    @IsDefaultColumn       BIT,
    @IsDetailWindowed      BIT,
    @DetailPageURI         NVARCHAR(250),
    @EntityTypeGuid        UNIQUEIDENTIFIER,
    @InformationPageURI    NVARCHAR(250),
    @GroupColumn           NVARCHAR(254),
    @Guid                  UNIQUEIDENTIFIER OUT,
	@ColourHexColumn       NVARCHAR(7),
	@ExternalSearchPageUrl NVARCHAR(250)
  )
AS
  BEGIN
    DECLARE @EntityTypeId INT

    SELECT
            @EntityTypeId = et.ID
    FROM
            SCore.EntityTypes et
    WHERE
            (et.Guid = @EntityTypeGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'DropDownListDefinitions',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SUserInterface.DropDownListDefinitions
              (
                [Guid],
                [Code],
                [NameColumn],
                [ValueColumn],
                [SqlQuery],
                [DefaultSortColumnName],
                [IsDefaultColumn],
                [RowStatus],
                DetailPageUrl,
                IsDetailWindowed,
                EntityTypeId,
                InformationPageUrl,
                GroupColumn,
				ColourHexColumn,
				ExternalSearchPageUrl
              )
        VALUES
                (
                  @Guid,
                  @Code,
                  @NameColumn,
                  @ValueColumn,
                  @SqlQuery,
                  @DefaultSortColumnName,
                  @IsDefaultColumn,
                  1,
                  @DetailPageURI,
                  @IsDetailWindowed,
                  @EntityTypeId,
                  @InformationPageURI,
                  @GroupColumn,
				  @ColourHexColumn,
				  @ExternalSearchPageUrl
                )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.DropDownListDefinitions
        SET     [Guid] = @Guid,
                [Code] = @Code,
                [NameColumn] = @NameColumn,
                [ValueColumn] = @ValueColumn,
                [SqlQuery] = @SqlQuery,
                [DefaultSortColumnName] = @DefaultSortColumnName,
                [IsDefaultColumn] = @IsDefaultColumn,
                DetailPageUrl = @DetailPageURI,
                IsDetailWindowed = @IsDetailWindowed,
                EntityTypeId = @EntityTypeId,
                InformationPageUrl = @InformationPageURI,
                GroupColumn = @GroupColumn,
				ColourHexColumn = @ColourHexColumn,
				ExternalSearchPageUrl = @ExternalSearchPageUrl
        WHERE
          ([Guid] = @Guid)
      END
  END

GO