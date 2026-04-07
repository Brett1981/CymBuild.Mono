SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuoteItemsUpsert]
  (
    @QuoteGuid				UNIQUEIDENTIFIER,
    @ProductGuid			UNIQUEIDENTIFIER,
    @Details				NVARCHAR(2000),
    @Net					DECIMAL(19, 2),
    @VatRate				DECIMAL(9, 2),
    @DoNotConsolidateJob	BIT,
    @SortOrder				INT,
    @Quantity				DECIMAL(9, 2),
	@ProvidedAtStageGuid	UNIQUEIDENTIFIER,
    @Guid					UNIQUEIDENTIFIER,
	@NumberOfSiteVisits		INT,
	@NumberOfMeetings		INT,
	@InvoicingScheduleGuid	UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @QuoteId				INT,
            @ProductId				INT,
			@ProvidedAtStageId		INT,
			@InvoicingScheduleId	INT,
            @IsInsert				BIT;

    SELECT
            @QuoteId = ID
    FROM
            SSop.Quotes
    WHERE
            ([Guid] = @QuoteGuid)

    SELECT
            @ProvidedAtStageId = ID
    FROM
            SJob.RibaStages AS rs
    WHERE
            ([Guid] = @ProvidedAtStageGuid)

	SELECT
            @ProductId = ID
    FROM
            SProd.Products
    WHERE
            ([Guid] = @ProductGuid)

	SELECT 
			@InvoicingScheduleId = ID
	FROM 
			SFin.InvoiceSchedules
	WHERE 
			([Guid] = @InvoicingScheduleGuid)



    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'QuoteItems',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.QuoteItems
              (
                RowStatus,
                Guid,
                QuoteId,
                ProductId,
                Details,
                Net,
                VatRate,
                DoNotConsolidateJob,
                SortOrder,
                Quantity,
				ProvideAtStageID,
				NumberOfMeetings,
				NumberOfSiteVisits,
				InvoicingSchedule
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @QuoteId,	-- QuoteSectionId - int
                  @ProductId,	-- ProductId - int
                  @Details,	-- Details - nvarchar(2000)
                  @Net,	-- Net - decimal(9, 2)
                  @VatRate,	-- VatRate - decimal(9, 2)
                  @DoNotConsolidateJob,	-- DoNotConsolidateJob - bit
                  @SortOrder,	-- SortOrder - int
                  @Quantity,
				  @ProvidedAtStageId,
				  @NumberOfMeetings,
				  @NumberOfSiteVisits,
				  @InvoicingScheduleId
                )
      END
    ELSE
      BEGIN
        UPDATE  SSop.QuoteItems
        SET     QuoteId = @QuoteId,
                ProductId = @ProductId,
                Details = @Details,
                Net = @Net,
                VatRate = @VatRate,
                DoNotConsolidateJob = @DoNotConsolidateJob,
                SortOrder = @SortOrder,
                Quantity = @Quantity,
				ProvideAtStageID = @ProvidedAtStageId,
				NumberOfMeetings = @NumberOfMeetings,
				NumberOfSiteVisits = @NumberOfSiteVisits,
				InvoicingSchedule = @InvoicingScheduleId
        WHERE
          ([Guid] = @Guid)
      END
  END
GO