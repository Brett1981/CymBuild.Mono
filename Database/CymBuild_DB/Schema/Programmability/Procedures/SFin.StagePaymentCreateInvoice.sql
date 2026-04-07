SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SFin].[StagePaymentCreateInvoice]
	(
		@Guid UNIQUEIDENTIFIER
	)
AS
	BEGIN
		SET NOCOUNT ON 

		DECLARE	@AccountGuid UNIQUEIDENTIFIER, 
				@JobGuid UNIQUEIDENTIFIER,
				@TransactionTypeGuid UNIQUEIDENTIFIER,
				@Date DATE, 
				@PurchaseOrderNumber NVARCHAR(28),
				@OrganisationalUnitGuid UNIQUEIDENTIFIER,
				@CreatedByUserGuid UNIQUEIDENTIFIER,
				@SurveyorGuid UNIQUEIDENTIFIER,
				@CreditTermsGuid UNIQUEIDENTIFIER,
				@TransactionGuid UNIQUEIDENTIFIER = NEWID(),
				@TransactionDetailGuid UNIQUEIDENTIFIER = NEWID(),
				@Value DECIMAL(9,2)

		-- Get the current user.
		SELECT	@CreatedByUserGuid = SCore.GetCurrentUserGuid()

		-- Get the details to create the invoice.
		SELECT	@AccountGuid = fa.Guid,
				@JobGuid = j.Guid,
				@Date = jps.StagedDate,
				@PurchaseOrderNumber = j.PurchaseOrderNumber,
				@OrganisationalUnitGuid = ou.Guid,
				@CreditTermsGuid = ct.Guid,
				@SurveyorGuid = i.Guid,
				@Value = jps.Value
		FROM	SJob.JobPaymentStages jps
		JOIN	SJob.Jobs j ON (j.ID = jps.JobId)
		JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
		JOIN	SCrm.Accounts fa ON (fa.ID = j.FinanceAccountID)
		JOIN	SFin.CreditTerms ct ON (ct.Id = fa.DefaultCreditTermsId)
		JOIN	SCore.OrganisationalUnits ou ON (ou.Id = j.OrganisationalUnitID)
		WHERE	(jps.Guid = @Guid)

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
									 @Guid = @TransactionGuid						-- uniqueidentifier
		
		-- Create the invoice detail
		EXEC SFin.TransactionDetailsUpsert @TransactionGuid = @TransactionGuid, -- uniqueidentifier
										   @MilestoneGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
										   @ActivityGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
										   @Net = @Value,				-- decimal(9, 2)
										   @Vat = 0,				-- decimal(9, 2)
										   @Gross = 0,			-- decimal(9, 2)
										   @VatRate = 20.0,			-- decimal(9, 2)
										   @Description = N'',		-- nvarchar(2000)
										   @JobPaymentStageGuid = @Guid,
										   @Guid = @TransactionDetailGuid				-- uniqueidentifier
		

	END;
GO