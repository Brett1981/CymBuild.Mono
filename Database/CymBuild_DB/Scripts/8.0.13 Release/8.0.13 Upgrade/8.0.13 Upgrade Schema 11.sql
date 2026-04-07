/****** Object:  StoredProcedure [SSop].[QuotesDuplicate]    Script Date: 28/03/2025 16:44:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




ALTER PROCEDURE [SSop].[QuotesDuplicate]
	@SourceGuid UNIQUEIDENTIFIER,
	@TargetGuid UNIQUEIDENTIFIER
AS
	BEGIN

		DECLARE @SourceID INT,
				@ID		  INT,
				@IsInsert BIT;

		SELECT
				@SourceID = ID
		FROM
				SSop.Quotes
		WHERE
				(Guid = @SourceGuid);

		IF (@@ROWCOUNT > 1)
			BEGIN
				;
				THROW 60000, N'Invalid source Quote', 1;
			END;

		EXEC SCore.UpsertDataObject
			@Guid					= @TargetGuid,
			@SchemeName				= N'SSop',
			@ObjectName				= N'Quotes',
			@IncludeDefaultSecurity = 1,
			@IsInsert				= @IsInsert

		INSERT SSop.Quotes
				(
					RowStatus,
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
					EnquiryServiceID,
					ProjectId
				)
			SELECT
					0,
					@TargetGuid,
					q.OrganisationalUnitID,
					q.QuotingUserId,
					N'0',
					q.UprnId,
					q.ClientAccountId,
					q.ClientAddressId,
					q.ClientContactId,
					q.ContractID,
					GETDATE(),
					q.Overview,
					DATEADD(MONTH,
					6,
					GETDATE()
					),
					q.QuoteSourceId,
					q.IsSubjectToNDA,
					q.AgentAccountId,
					q.AgentAddressId,
					q.AgentContactId,
					q.ExternalReference,
					q.FeeCap,
					q.EnquiryServiceID,
					q.ProjectId
			FROM
					SSop.Quotes AS q
			WHERE
					(q.ID = @SourceID);

		SELECT
				@ID = SCOPE_IDENTITY();

	

		-- Build the collection of items to duplicate. 
		DECLARE @QuoteItems SCore.TwoGuidUniqueList

		INSERT @QuoteItems
				(
					GuidValue,
					GuidValueTwo
				)
			SELECT
					qi.Guid,
					NEWID()
			FROM
					SSop.QuoteItems qi
			
			WHERE
					
					(qi.QuoteId = @SourceID) --CBLD-613
					AND (qi.RowStatus NOT IN (0, 254))
					

		-- Build the collection of payment stages to duplicate
		DECLARE @QuotePaymentStages SCore.TwoGuidUniqueList

		INSERT @QuotePaymentStages --RETURNS NOTHING
				(
					GuidValue,
					GuidValueTwo
				)
			SELECT
					qps.Guid,
					NEWID()
			FROM
					SSop.QuotePaymentStages qps
			WHERE
					(qps.QuoteId = @SourceID)
					AND (qps.RowStatus NOT IN (0, 254))

		-- Create the data objects. 
		DECLARE @NewGuidList SCore.GuidUniqueList


		INSERT @NewGuidList
				(
					GuidValue
				)
			SELECT
					GuidValueTwo
			FROM
					@QuoteItems

		EXEC SCore.DataObjectBulkUpsert
			@GuidList   = @NewGuidList,				-- GuidUniqueList
			@SchemeName = N'SSop',				-- nvarchar(255)
			@ObjectName = N'QuoteItems',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit	

		DELETE FROM
		@NewGuidList		
		INSERT @NewGuidList
				(
					GuidValue
				)
			SELECT
					GuidValueTwo
			FROM
					@QuotePaymentStages

		EXEC SCore.DataObjectBulkUpsert
			@GuidList   = @NewGuidList,				-- GuidUniqueList
			@SchemeName = N'SSop',				-- nvarchar(255)
			@ObjectName = N'QuotePaymentStages',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit	

		

		-- Duplicate the Quote Items. 
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
					Quantity
				)
			SELECT
					1,
					qil.GuidValueTwo,
					@ID,
					qi.ProductId,
					qi.Details,
					qi.Net,
					qi.VatRate,
					qi.DoNotConsolidateJob,
					qi.SortOrder,
					qi.Quantity
			FROM
					SSop.QuoteItems qi
			JOIN
					@QuoteItems qil ON (qil.GuidValue = qi.Guid)
			
		

		-- Duplicate the Quote Payment Stages 
		INSERT INTO SSop.QuotePaymentStages
			(
				RowStatus,
				Guid, 
				QuoteId, 
				PaymentFrequencyTypeId, 
				PaymentFrequency,
				Value,
				PercentageOfTotal, 
				PayAfterStageId
			)
			SELECT	1, 
					qpsl.GuidValueTwo, 
					@Id,
					qps.PaymentFrequencyTypeId,
					qps.PaymentFrequency,
					qps.Value,
					qps.PercentageOfTotal,
					qps.PayAfterStageId
			FROM	
					SSop.QuotePaymentStages qps
			JOIN	
					@QuotePaymentStages qpsl on (qps.Guid = qpsl.GuidValue)

		-- Allocate a new Quote number. 

		DECLARE @QuoteNumber NVARCHAR(30);

		SELECT
				@QuoteNumber = NEXT VALUE FOR SSop.QuoteNumber;

		UPDATE  SSop.Quotes
		SET		Number = @QuoteNumber,
				RowStatus = 1
		WHERE
			(ID = @ID);
	END;
