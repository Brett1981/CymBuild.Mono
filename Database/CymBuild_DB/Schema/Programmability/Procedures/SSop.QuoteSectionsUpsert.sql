SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SSop].[QuoteSectionsUpsert]
  (
    @QuoteGuid              UNIQUEIDENTIFIER,
    @RibaStageGuid          UNIQUEIDENTIFIER,
    @Name                   NVARCHAR(200),
    @Overview               NVARCHAR(MAX),
    @ShowProducts           BIT,
    @ConsolidateJobs        BIT,
    @SortOrder              INT,
    @NumberOfMeetings       INT,
    @NumberOfSiteVisits     INT,
    @CombineWithSectionGuid UNIQUEIDENTIFIER,
    @ValueOfWorkGuid        UNIQUEIDENTIFIER,
    @Guid                   UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @QuoteId              INT,
            @RibaStageId          INT,
            @CombineWithSectionId INT,
            @ValueOfWorkId        INT,
            @IsInsert             BIT;

    SELECT
            @QuoteId = ID
    FROM
            SSop.Quotes
    WHERE
            ([Guid] = @QuoteGuid)

    SELECT
            @RibaStageId = ID
    FROM
            SJob.RibaStages
    WHERE
            ([Guid] = @RibaStageGuid)

    SELECT
            @CombineWithSectionId = ID
    FROM
            SSop.QuoteSections
    WHERE
            ([Guid] = @CombineWithSectionGuid)

    SELECT
            @ValueOfWorkId = ID
    FROM
            SJob.ValuesOfWork
    WHERE
            (Guid = @ValueOfWorkGuid)

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'QuoteSections',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.QuoteSections
              (
                RowStatus,
                Guid,
                QuoteId,
                RibaStageId,
                Name,
                Overview,
                ShowProducts,
                ConsolidateJobs,
                SortOrder,
                NumberOfMeetings,
                NumberOfSiteVisits,
                CombineWithSectionId,
                ValueOfWorkId
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @QuoteId,	-- QuoteId - int
                  @RibaStageId,	-- UprnId - int
                  @Name,	-- Name - nvarchar(200)
                  @Overview,	-- Overview - nvarchar(max)
                  @ShowProducts,	-- ShowProducts - bit
                  @ConsolidateJobs,	-- ConsolidateJobs - bit
                  @SortOrder,	-- SortOrder - int
                  @NumberOfMeetings,
                  @NumberOfSiteVisits,
                  @CombineWithSectionId,
                  @ValueOfWorkId
                )
      END
    ELSE
      BEGIN
        UPDATE  SSop.QuoteSections
        SET     QuoteId = @QuoteId,
                RibaStageId = @RibaStageId,
                Name = @Name,
                Overview = @Overview,
                ShowProducts = @ShowProducts,
                ConsolidateJobs = @ConsolidateJobs,
                SortOrder = @SortOrder,
                NumberOfMeetings = @NumberOfMeetings,
                NumberOfSiteVisits = @NumberOfSiteVisits,
                CombineWithSectionId = @CombineWithSectionId,
                ValueOfWorkId = @ValueOfWorkId
        WHERE
          ([Guid] = @Guid)
      END
  END
GO