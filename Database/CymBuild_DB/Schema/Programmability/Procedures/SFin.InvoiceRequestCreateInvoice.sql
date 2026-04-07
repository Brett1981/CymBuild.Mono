SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SFin].[InvoiceRequestCreateInvoice]
	(
		@Guid UNIQUEIDENTIFIER
	)
AS
	BEGIN
		SET NOCOUNT ON 

		DECLARE	@AccountGuid UNIQUEIDENTIFIER, 
				@JobGuid UNIQUEIDENTIFIER,
				@TransactionTypeGuid UNIQUEIDENTIFIER,
				@Date DATE = GETUTCDATE(), 
				@PurchaseOrderNumber NVARCHAR(28),
				@OrganisationalUnitGuid UNIQUEIDENTIFIER,
				@CreatedByUserGuid UNIQUEIDENTIFIER,
				@SurveyorGuid UNIQUEIDENTIFIER,
				@CreditTermsGuid UNIQUEIDENTIFIER,
				@TransactionGuid UNIQUEIDENTIFIER = NEWID(),
				@InvoiceRequestId INT,
				@TransactionId INT,
				@Description NVARCHAR(MAX) = N'',
				@JobDescription NVARCHAR(MAX),
				@JobNumber NVARCHAR(30),
				@UprnFormattedAddressComma NVARCHAR(MAX),
				@JobType NVARCHAR(MAX)

		SELECT	@AccountGuid = fa.Guid,
				@InvoiceRequestId = ir.ID, 
				@JobGuid = j.Guid,
				@SurveyorGuid = r.Guid,
				@JobDescription = j.JobDescription,
				@JobNumber = j.Number,
				@JobType = jt.Name,
				@PurchaseOrderNumber = j.PurchaseOrderNumber,
				@OrganisationalUnitGuid = ou.Guid,
				@CreditTermsGuid = ct.Guid,
				@UprnFormattedAddressComma = uprn.FormattedAddressComma
		FROM	SFin.InvoiceRequests ir
		JOIN	SJob.Jobs j ON (j.ID = ir.JobId)
		JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
		JOIN	SJob.Assets uprn ON (uprn.ID = j.UprnID)
		JOIN	SCrm.Accounts fa ON (fa.ID = j.FinanceAccountID)
		JOIN	SCore.Identities r ON (r.ID = ir.RequesterUserId)
		JOIN	SCore.OrganisationalUnits ou ON (ou.Id = j.OrganisationalUnitID)
		JOIN	SFin.CreditTerms ct on (ct.ID = fa.DefaultCreditTermsId)
		WHERE ir.Guid = @Guid

		IF (NOT EXISTS
		(
			SELECT	1
			FROM	SCrm.Accounts AS a 
			WHERE	(a.Guid = @AccountGuid)
				AND	(a.Code <> N'')
		)
			)
		BEGIN 
			;THROW 60000, N'The finance account on the job is invalid.', 1
		END

		SELECT	@CreatedByUserGuid = SCore.GetCurrentUserGuid()

		SELECT	@TransactionTypeGuid = tt.Guid 
		FROM	SFin.TransactionTypes tt
		WHERE	(tt.Name = N'Invoice')

		-- Create the invoice header
		EXEC SFin.TransactionsUpsert @AccountGuid = @AccountGuid,				-- uniqueidentifier
									 @JobGuid = @JobGuid,					-- uniqueidentifier
									 @TransactionTypeGuid = @TransactionTypeGuid,		-- uniqueidentifier
									 @Date = @Date,				-- date
									 @PurchaseOrderNumber = @PurchaseOrderNumber,		-- nvarchar(28)
									 @SageTransactionReference = N'',	-- nvarchar(50)
									 @OrganisationalUnitGuid = @OrganisationalUnitGuid,	-- uniqueidentifier
									 @CreatedByUserGuid = @CreatedByUserGuid,			-- uniqueidentifier
									 @SurveyorGuid = @SurveyorGuid,				-- uniqueidentifier
									 @CreditTermsGuid = @CreditTermsGuid,			-- uniqueidentifier
									 @Guid = @TransactionGuid,						-- uniqueidentifier
									 @Batched = 1									-- Set it to 1

		SELECT	@TransactionId = ID
		FROM	SFin.Transactions t
		WHERE	(Guid = @TransactionGuid)

		SET @Description = @Description + N'	
Our project ref.: ' + @JobNumber + N'
Project description: ' + @JobDescription + N'
Property: ' + @UprnFormattedAddressComma + N'
Appointed role: ' + @JobType

		DECLARE	@DetailList SCore.TwoGuidUniqueList,
				@NewDetailRecords SCore.GuidUniqueList

		INSERT	@DetailList
			 (GuidValue, GuidValueTwo)
		SELECT	iri.Guid,
				NEWID()
		FROM	SFin.InvoiceRequestItems iri
		WHERE	(iri.InvoiceRequestId = @InvoiceRequestId)
			AND	(iri.RowStatus NOT IN (0, 254))


		INSERT	@NewDetailRecords (GuidValue)
		SELECT	GuidValueTwo
		FROM	@DetailList

		DECLARE	@IsInsert BIT 

		EXEC SCore.DataObjectBulkUpsert 
			@GuidList = @NewDetailRecords,
			@SchemeName = N'SFin',
			@ObjectName = N'TransactionDetails',
			@IncludeDefaultSecurity = 0,
			@IsInsert = @IsInsert OUT 

		INSERT	SFin.TransactionDetails
			 (RowStatus,
			  Guid,
			  TransactionID,
			  MilestoneID,
			  ActivityID,
			  Net,
			  Vat,
			  Gross,
			  VatRate,
			  Description,
			  LegacyId,
			  JobPaymentStageId,
			  InvoiceRequestItemId,
			  RIBAStageId)
		SELECT	1,
				dl.GuidValueTwo,
				@TransactionId,
				iri.MilestoneId,
				iri.ActivityId,
				iri.Net,
				iri.Net * 0.2,
				iri.Net * 1.2,
				20,
				@Description, 
				NULL,
				-1,
				iri.Id,
				iri.RIBAStageId
		FROM	@DetailList dl
		JOIN	SFin.InvoiceRequestItems iri ON (iri.Guid = dl.GuidValue)
		

	END;
GO