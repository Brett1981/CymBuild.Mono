SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuoteTemplatesCreateQuote]
	(
		@TemplateGuid UNIQUEIDENTIFIER,
		@QuoteGuid UNIQUEIDENTIFIER,
		@UserGuid UNIQUEIDENTIFIER
	)
AS
BEGIN

	DECLARE @Overview NVARCHAR(MAX),
			@FeeCap DECIMAL(19, 2),
			@QuoteDate DATE = GETDATE()

	SELECT	@Overview = qt.Overview,
			@FeeCap = qt.FeeCap
	FROM	SSop.QuoteTemplates qt
	WHERE	(guid = @TemplateGuid)

	EXEC SSop.QuotesUpsert @OrganisationalUnitGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
						   @QuotingUserGuid = @UserGuid,			-- uniqueidentifier
						   @Number = 0,						-- int
						   @ClientAccountGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
						   @ClientAddressGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
						   @ClientContactGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
						   @AgentAccountGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
						   @AgentAddressGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
						   @AgentContactGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
						   @ContractGuid = '00000000-0000-0000-0000-000000000000',			-- uniqueidentifier
						   @Date = @QuoteDate,			-- date
						   @Overview = @Overview,					-- nvarchar(max)
						   @ExpiryDate = NULL,		-- date
						   @DateSent = NULL,		-- date
						   @DateAccepted = NULL,	-- date
						   @DateRejected = NULL,	-- date
						   @RejectionReason = N'',			-- nvarchar(max)
						   @QuoteSourceGuid = '00000000-0000-0000-0000-000000000000',			-- uniqueidentifier
						   @UprnGuid = '00000000-0000-0000-0000-000000000000',				-- uniqueidentifier
						   @ChaseDate1 = NULL,		-- date
						   @ChaseDate2 = NULL,		-- date
						   @FeeCap = @FeeCap,					-- decimal(19, 2)
						   @Guid = @QuoteGuid,						-- uniqueidentifier
						   @JobType = '00000000-0000-0000-0000-000000000000' --[CBLD-590: Defaulting to empty guid since this will be populated]



	DECLARE @MaxQuoteSection INT,
			@CurrentQuoteSection INT,
			@RibaStageGuid UNIQUEIDENTIFIER,
			@Name NVARCHAR(200),
			@SectionOverview NVARCHAR(MAX),
			@ShowProducts BIT,
			@ConsolidateJobs BIT,
			@SortOrder INT,
			@NumberOfMeetings INT,
			@NumberOfSiteVisits INT,
			@SectionGuid UNIQUEIDENTIFIER,
			@ProductGuid UNIQUEIDENTIFIER,
			@ItemDetails NVARCHAR(2000),
			@Net DECIMAL(19,2),
			@VatRate DECIMAL (19,2),
			@DoNotConsolidateJob BIT,
			@ItemSortOrder INT,
			@ItemQuantity DECIMAL(19,2),
			@ItemGuid UNIQUEIDENTIFIER,
			@MaxQuoteItem INT,
			@CurrentQuoteItem INT 


	SELECT	@MaxQuoteSection = MAX(qts.ID),
			@CurrentQuoteSection = -1
	FROM	SSop.QuoteTemplateSections qts
	JOIN	SSop.QuoteTemplates qt ON (qt.ID = qts.QuoteTemplateId)
	WHERE	(qt.Guid = @TemplateGuid)

	WHILE	(@CurrentQuoteSection < @MaxQuoteSection)
	BEGIN 
		SELECT	TOP(1) @CurrentQuoteSection = qts.ID,
			@CurrentQuoteSection = -1,
			@RibaStageGuid = rs.Guid,
			@Name = qts.Name,
			@SectionOverview = qts.Overview,
			@ShowProducts = qts.ShowProducts,
			@ConsolidateJobs = qts.ConsolidateJobs,
			@SortOrder = qts.SortOrder,
			@NumberOfMeetings = qts.NumberOfMeetings,
			@NumberOfSiteVisits = qts.NumberOfSiteVisits,
			@SectionGuid = NEWID()
		FROM	SSop.QuoteTemplateSections qts
		JOIN	SSop.QuoteTemplates qt ON (qt.ID = qts.QuoteTemplateId)
		JOIN	SJob.RibaStages rs ON (rs.ID = qts.RibaStageId)
		WHERE	(qt.Guid = @TemplateGuid)
			AND	(qts.ID > @CurrentQuoteSection)
		ORDER BY qts.ID
		
		EXECUTE SSop.QuoteSectionsUpsert @QuoteGuid = @QuoteGuid,					-- uniqueidentifier
										 @RibaStageGuid = @RibaStageGuid,				-- uniqueidentifier
										 @Name = @Name,						-- nvarchar(200)
										 @Overview = @SectionOverview,					-- nvarchar(max)
										 @ShowProducts = @ShowProducts,				-- bit
										 @ConsolidateJobs = @ConsolidateJobs,			-- bit
										 @SortOrder = @SortOrder,					-- int
										 @NumberOfMeetings = @NumberOfMeetings,				-- int
										 @NumberOfSiteVisits = @NumberOfSiteVisits,			-- int
										 @CombineWithSectionGuid = @SectionGuid,	-- uniqueidentifier
										 @Guid = @SectionGuid						-- uniqueidentifier

		SELECT	@MaxQuoteItem = MAX(qti.ID),
				@CurrentQuoteItem = -1
		FROM	SSop.QuoteTemplateItems qti
		WHERE	(qti.QuoteTemplateSectionId = @CurrentQuoteSection)

		WHILE	(@CurrentQuoteItem > @MaxQuoteItem)
		BEGIN 
			SELECT	TOP (1) @CurrentQuoteItem = qti.ID,
					@ProductGuid = p.Guid,
					@ItemDetails = qti.ID,
					@Net = qti.Net,
					@VatRate = qti.VatRate,
					@DoNotConsolidateJob = qti.DoNotConsolidateJob,
					@SortOrder = qti.SortOrder,
					@ItemQuantity = qti.Quantity
			FROM	SSop.QuoteTemplateItems qti
			JOIN	SProd.Products p ON (p.ID = qti.ProductId)
			WHERE	(qti.QuoteTemplateSectionId = @CurrentQuoteSection)
			ORDER BY qti.ID

			EXECUTE SSop.QuoteItemsUpsert @QuoteSectionGuid = @SectionGuid,		-- uniqueidentifier
										  @ProductGuid = @ProductGuid,			-- uniqueidentifier
										  @Details = @ItemDetails,				-- nvarchar(2000)
										  @Net = @Net,					-- decimal(9, 2)
										  @VatRate = @VatRate,				-- decimal(9, 2)
										  @DoNotConsolidateJob = @DoNotConsolidateJob,	-- bit
										  @SortOrder = @ItemSortOrder,				-- int
										  @Quantity = @ItemQuantity,				-- decimal(9, 2)
										  @Guid = @ItemGuid					-- uniqueidentifier
		END
		
		
	END
	
END;
GO