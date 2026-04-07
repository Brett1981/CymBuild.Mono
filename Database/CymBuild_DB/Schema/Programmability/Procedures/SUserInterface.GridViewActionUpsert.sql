SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SUserInterface].[GridViewActionUpsert]
  (
    @GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @LanguageLabelGuid      UNIQUEIDENTIFIER,
	@EntityQueryGuid		UNIQUEIDENTIFIER,
    @Guid                   UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    DECLARE @GridViewDefinitionID INT,
            @LanguageLabelId      INT,
			@EntityQueryId			INT


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

	SELECT
			@EntityQueryId = ID
	FROM
			SCore.EntityQueries eq
	WHERE
			([Guid] = @EntityQueryGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'GridViewActions',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SUserInterface.GridViewActions
              (
                [Guid],
                [RowStatus],
                [GridViewDefinitionId],
				[EntityQueryId],
                [LanguageLabelId]
              )
        VALUES
                (
                  @Guid,
                  1,
                  @GridViewDefinitionID,
				  @EntityQueryId,
                  @LanguageLabelId
                )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.GridViewActions
        SET     [GridViewDefinitionId] = @GridViewDefinitionID,
				[EntityQueryId] = @EntityQueryId,
                [LanguageLabelId] = @LanguageLabelId
        WHERE
          ([Guid] = @Guid)
      END
  END

GO