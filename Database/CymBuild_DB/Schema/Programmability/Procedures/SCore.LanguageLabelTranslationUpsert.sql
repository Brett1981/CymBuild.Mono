SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[LanguageLabelTranslationUpsert]
  (
    @Text              NVARCHAR(250),
    @TextPlural        NVARCHAR(250),
    @HelpText          NVARCHAR(MAX),
    @LanguageLabelGuid UNIQUEIDENTIFIER,
    @LanguageGuid      UNIQUEIDENTIFIER,
    @Guid              UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    SET NOCOUNT ON;

    DECLARE @LanguageLabelID INT,
            @LanguageID      INT;

    SELECT
            @LanguageID = ID
    FROM
            SCore.Languages
    WHERE
            (Guid = @LanguageGuid);

    SELECT
            @LanguageLabelID = ID
    FROM
            SCore.LanguageLabels
    WHERE
            (Guid = @LanguageLabelGuid);

    DECLARE @IsInsert BIT = 0;
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCore',			-- nvarchar(255)
      @ObjectName = N'LanguageLabelTranslations',		-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT;	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SCore.LanguageLabelTranslations
              (
                Guid,
                Text,
                TextPlural,
                HelpText,
                RowStatus,
                LanguageID,
                LanguageLabelID
              )
        VALUES
                (
                  @Guid,
                  @Text,
                  @TextPlural,
                  @HelpText,
                  1,
                  @LanguageID,
                  @LanguageLabelID
                );
      END;
    ELSE
      BEGIN
        UPDATE  SCore.LanguageLabelTranslations
        SET     Text = @Text,
                TextPlural = @TextPlural,
                HelpText = @HelpText,
                LanguageLabelID = @LanguageLabelID,
                LanguageID = @LanguageID
        WHERE
          (Guid = @Guid);
      END;
  END;
GO