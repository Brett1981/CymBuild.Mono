SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuotesRevise] @SourceGuid UNIQUEIDENTIFIER,
								  @TargetGuid UNIQUEIDENTIFIER
AS
BEGIN

	DECLARE @SourceID INT,
			@ID		  INT,
			@IsInsert BIT;

	SELECT	@SourceID = ID
	FROM	SSop.Quotes
	WHERE	(Guid = @SourceGuid);

	IF (@@ROWCOUNT > 1)
	BEGIN
		;
		THROW 60000, N'Invalid source Quote', 1;
	END;

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Quotes AS q
		 WHERE	(q.Guid = @SourceGuid)
			AND (q.DateAccepted IS NOT NULL)
	 )
	   )
	BEGIN
		; THROW 60000, N'You cannot revise an accepted quote', 1;
	END;

	EXEC SCore.UpsertDataObject @Guid = @TargetGuid,
								@SchemeName = N'SSop',
								@ObjectName = N'Quotes',
								@IncludeDefaultSecurity = 1,
								@IsInsert = @IsInsert;

	INSERT	SSop.Quotes
		 (RowStatus,
		  Guid,
		  OrganisationalUnitID,
		  QuotingUserId,
		  Number,
		  UprnId,
		  ClientAccountId,
		  ClientAddressId,
		  ClientContactId,
		  ContractID,
		  Date,
		  Overview,
		  ExpiryDate,
		  QuoteSourceId,
		  IsSubjectToNDA,
		  AgentAccountId,
		  AgentAddressId,
		  AgentContactId,
		  ExternalReference,
		  FeeCap,
		  RevisionNumber,
		  OriginalQuoteId,
		  EnquiryServiceID,
		  DescriptionOfWorks,
		  QuotingConsultantId,
		  ExclusionsAndLimitations,
		  ProjectId,
		  AgentContractID,
		  MarketId,
		  SectorId)
	SELECT	0,
			@TargetGuid,
			q.OrganisationalUnitID,
			q.QuotingUserId,
			q.Number,
			q.UprnId,
			q.ClientAccountId,
			q.ClientAddressId,
			q.ClientContactId,
			q.ContractID,
			GETDATE (),
			q.Overview,
			DATEADD (	MONTH,
						6,
						GETDATE ()
					),
			q.QuoteSourceId,
			q.IsSubjectToNDA,
			q.AgentAccountId,
			q.AgentAddressId,
			q.AgentContactId,
			q.ExternalReference,
			q.FeeCap,
			ISNULL (   latest_revision.rev,
					   0
				   ) + 1,
			CASE
				WHEN q.OriginalQuoteId = (-1) THEN q.ID
				ELSE q.OriginalQuoteId
			END,
			q.EnquiryServiceID,
			q.DescriptionOfWorks,
			q.QuotingConsultantId,
			q.ExclusionsAndLimitations,
			q.ProjectId,
			q.AgentContractID,
			q.MarketId,
			q.SectorId
	FROM	SSop.Quotes AS q
	OUTER APPLY
			(
				SELECT	MAX (q1.RevisionNumber) AS rev
				FROM	SSop.Quotes AS q1
				WHERE	(q1.OriginalQuoteId = CASE
												  WHEN q.OriginalQuoteId = (-1) THEN q.ID
												  ELSE q.OriginalQuoteId
											  END
						)
			)			AS latest_revision
	WHERE	(q.ID = @SourceID);

	SELECT	@ID = SCOPE_IDENTITY ();


	-- Build the collection of items to duplicate. 
	DECLARE @QuoteItems SCore.TwoGuidUniqueList;

	INSERT	@QuoteItems
		 (GuidValue, GuidValueTwo)
	SELECT	qi.Guid,
			NEWID ()
	FROM	SSop.QuoteItems AS qi
	WHERE	(qi.QuoteId = @SourceID)
		AND (qi.RowStatus NOT IN (0, 254));

	-- Build the collection of payment stages to duplicate
	DECLARE @QuotePaymentStages SCore.TwoGuidUniqueList;

	INSERT	@QuotePaymentStages
		 (GuidValue, GuidValueTwo)
	SELECT	qps.Guid,
			NEWID ()
	FROM	SSop.QuotePaymentStages AS qps
	WHERE	(qps.QuoteId = @SourceID)
		AND (qps.RowStatus NOT IN (0, 254));

	-- Build the collection of quote memos
	DECLARE @QuoteMemos SCore.TwoGuidUniqueList;

	INSERT	@QuoteMemos --RETURNS NOTHING
		 (GuidValue, GuidValueTwo)
	SELECT	qm.Guid,
			NEWID ()
	FROM	SSop.QuoteMemos AS qm
	WHERE	(qm.QuoteID = @SourceID)
		AND (qm.RowStatus NOT IN (0, 254));

	-- Create the data objects. 
	DECLARE @NewGuidList SCore.GuidUniqueList;

	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	GuidValueTwo
	FROM	@QuoteItems;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,		-- GuidUniqueList
									@SchemeName = N'SSop',			-- nvarchar(255)
									@ObjectName = N'QuoteItems',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;	-- bit	

	DELETE	FROM @NewGuidList;
	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	GuidValueTwo
	FROM	@QuotePaymentStages;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,				-- GuidUniqueList
									@SchemeName = N'SSop',					-- nvarchar(255)
									@ObjectName = N'QuotePaymentStages',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;			-- bit	

	DELETE	FROM @NewGuidList;
	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	qm.GuidValueTwo
	FROM	@QuoteMemos AS qm;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,		-- GuidUniqueList
									@SchemeName = N'SSop',			-- nvarchar(255)
									@ObjectName = N'QuoteMemos',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;	-- bit	

	-- Duplicate the Quote Items. 
	INSERT	SSop.QuoteItems
		 (RowStatus, Guid, QuoteId, ProductId, Details, Net, VatRate, DoNotConsolidateJob, SortOrder, Quantity)
	SELECT	1,
			qil.GuidValueTwo,
			@ID,
			qi.ProductId,
			qi.Details,
			qi.Net,
			qi.VatRate,
			qi.DoNotConsolidateJob,
			qi.SortOrder,
			qi.Quantity
	FROM	SSop.QuoteItems	   AS qi
	JOIN	@QuoteItems		   AS qil ON (qil.GuidValue = qi.Guid)
	JOIN	SSop.QuoteSections AS oqs ON (oqs.ID		= qi.QuoteSectionId);


	-- Duplicate the Quote Payment Stages 
	INSERT INTO SSop.QuotePaymentStages
		 (RowStatus, Guid, QuoteId, PaymentFrequencyTypeId, PaymentFrequency, Value, PercentageOfTotal, PayAfterStageId)
	SELECT	1,
			qpsl.GuidValueTwo,
			@ID,
			qps.PaymentFrequencyTypeId,
			qps.PaymentFrequency,
			qps.Value,
			qps.PercentageOfTotal,
			qps.PayAfterStageId
	FROM	SSop.QuotePaymentStages AS qps
	JOIN	@QuotePaymentStages		AS qpsl ON (qps.Guid = qpsl.GuidValue);

	-- Duplicate the Quote Memos
	INSERT INTO SSop.QuoteMemos
		 (RowStatus, Guid, QuoteID, Memo, CreatedDateTimeUTC, CreatedByUserId)
	SELECT	1,
			qms.GuidValueTwo,
			@ID,
			qm.Memo,
			qm.CreatedDateTimeUTC,
			qm.CreatedByUserId
	FROM	SSop.QuoteMemos AS qm
	JOIN	@QuoteMemos		AS qms ON (qm.Guid = qms.GuidValue);

	UPDATE	SSop.Quotes
	SET		RowStatus = 1
	WHERE	(ID = @ID);
END;
GO