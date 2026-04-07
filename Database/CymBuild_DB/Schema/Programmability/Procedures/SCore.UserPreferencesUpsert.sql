SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SCore].[UserPreferencesUpsert]
  (
    @SystemLanguageGuid UNIQUEIDENTIFIER,
    @Guid               UNIQUEIDENTIFIER
  )
AS
  BEGIN
    SET NOCOUNT ON

    DECLARE @SystemLanguageId INT

    SELECT
            @SystemLanguageId = ID
    FROM
            SCore.Languages l
    WHERE
            Guid = @SystemLanguageGuid


    UPDATE  SCore.UserPreferences
    SET     SystemLanguageID = @SystemLanguageId
    WHERE
      Guid = @Guid;

  END;
GO