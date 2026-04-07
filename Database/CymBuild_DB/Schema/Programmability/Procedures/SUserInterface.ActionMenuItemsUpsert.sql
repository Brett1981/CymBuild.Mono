SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SUserInterface].[ActionMenuItemsUpsert]
  (
    @LanguageLabelGuid UNIQUEIDENTIFIER,
    @IconCss           NVARCHAR(100),
    @Type              NVARCHAR(1),
    @EntityTypeGuid    UNIQUEIDENTIFIER,
    @EntityQueryGuid   UNIQUEIDENTIFIER,
    @RedirectToTargetGuid BIT,
    @SortOrder        INT,
    @Guid              UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @LanguageLabelId INT,
            @EntityTypeId    INT,
            @EntityQueryId   INT

    SELECT
            @LanguageLabelId = ID
    FROM
            SCore.LanguageLabels
    WHERE
            ([Guid] = @LanguageLabelGuid)

    SELECT
            @EntityTypeId = ID
    FROM
            SCore.EntityTypes
    WHERE
            ([Guid] = @EntityTypeGuid)

    SELECT
            @EntityQueryId = ID
    FROM
            SCore.EntityQueries
    WHERE
            ([Guid] = @EntityQueryGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SUserInterface',				-- nvarchar(255)
      @ObjectName = N'ActionMenuItems',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SUserInterface.ActionMenuItems
              (
                RowStatus,
                Guid,
                LanguageLabelId,
                IconCss,
                Type,
                EntityTypeId,
                EntityQueryId,
                RedirectToTargetGuid, 
                SortOrder
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @LanguageLabelId,	-- LanguageLabelId - int
                  @IconCss,	-- IconCss - nvarchar(100)
                  @Type,	-- Type - nvarchar(1)
                  @EntityTypeId,	-- EntityTypeId - int
                  @EntityQueryId,	-- EntityQueryId - int
                  @RedirectToTargetGuid,
                  @SortOrder
                )
      END
    ELSE
      BEGIN
        UPDATE  SUserInterface.ActionMenuItems
        SET     LanguageLabelId = @LanguageLabelId,
                IconCss = @IconCss,
                Type = @Type,
                EntityTypeId = @EntityTypeId,
                EntityQueryId = @EntityQueryId,
                RedirectToTargetGuid = @RedirectToTargetGuid,
                SortOrder = @SortOrder
        WHERE
          ([Guid] = @Guid)
      END
  END

GO