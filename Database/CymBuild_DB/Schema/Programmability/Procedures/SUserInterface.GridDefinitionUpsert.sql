SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SUserInterface].[GridDefinitionUpsert]
  (
    @Code              NVARCHAR(30),
    @RowStatus         TINYINT,
    @TabName           NVARCHAR(250),
    @ShowAsTiles       BIT,
    @PageUri           NVARCHAR(250),
    @LanguageLabelGuid UNIQUEIDENTIFIER,
    @Guid              UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    DECLARE @LanguageLabelId INT

    SELECT
            @LanguageLabelId = ID
    FROM
            SCore.LanguageLabels ll
    WHERE
            (Guid = @LanguageLabelGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'GridDefinitions',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SUserInterface.GridDefinitions
              (
                [Guid],
                [LanguageLabelId],
                [RowStatus],
                [Code],
                [TabName],
                [ShowAsTiles],
                [PageUri]
              )
        VALUES
                (
                  @Guid,
                  @LanguageLabelId,
                  1,
                  @Code,
                  @TabName,
                  @ShowAsTiles,
                  @PageUri
                )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.GridDefinitions
        SET     LanguageLabelId = @LanguageLabelId,
                [RowStatus] = @RowStatus,
                [Code] = @Code,
                [TabName] = @TabName,
                [ShowAsTiles] = @ShowAsTiles,
                [PageUri] = @PageUri
        WHERE
          ([Guid] = @Guid)
      END
  END

GO