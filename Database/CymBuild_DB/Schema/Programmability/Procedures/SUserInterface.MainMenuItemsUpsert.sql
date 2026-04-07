SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SUserInterface].[MainMenuItemsUpsert]
  (
    @RowStatus         TINYINT,
    @LanguageLabelGuid UNIQUEIDENTIFIER,
	@IconGuid		   UNIQUEIDENTIFIER,
	@SortOrder		   INT,
	@NavigationUrl	   NVARCHAR(500),
    @Guid              UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    DECLARE @LanguageLabelId INT,
			@IconId INT

    SELECT
            @LanguageLabelId = ID
    FROM
            SCore.LanguageLabels ll
    WHERE
            (Guid = @LanguageLabelGuid)

	SELECT	
			@IconId = ID
	FROM	
			SUserInterface.Icons AS i
	WHERE	
			(Guid = @IconGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'MainMenuItems',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SUserInterface.MainMenuItems
              (
                [Guid],
                [LanguageLabelId],
                [RowStatus],
                [IconId],
				[SortOrder],
				[NavigationUrl]
              )
        VALUES
                (
                  @Guid,
                  @LanguageLabelId,
                  1,
                  @IconId,
				  @SortOrder,
				  @NavigationUrl
                )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.MainMenuItems
        SET     LanguageLabelId = @LanguageLabelId,
                [RowStatus] = @RowStatus,
                [IconId] = @IconId,
				[SortOrder] = @SortOrder,
				[NavigationUrl] = @NavigationUrl
        WHERE
          ([Guid] = @Guid)
      END
  END

GO