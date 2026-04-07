SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SJob].[ActivityCreateInvoiceRequest]')
GO
CREATE PROCEDURE [SJob].[ActivityCreateInvoiceRequest]
	(
		@Guid UNIQUEIDENTIFIER
	)
AS
	BEGIN
		SET NOCOUNT ON 

		DECLARE	@MilestoneGuid UNIQUEIDENTIFIER, 
				@JobGuid UNIQUEIDENTIFIER,
				@CreatedByUserGuid UNIQUEIDENTIFIER,
				@InvoiceRequestGuid UNIQUEIDENTIFIER = NEWID(),
				@InvoiceRequestItemGuid UNIQUEIDENTIFIER = NEWID(),
				@Net DECIMAL(19,2)

		IF (
			(EXISTS
				(
					SELECT	1
					FROM	SFin.InvoiceRequestItems iri
					JOIN	SJob.Activities a ON (a.ID = iri.ActivityId)
					WHERE	(a.Guid = @Guid)
						AND	(iri.RowStatus NOT IN (0, 254))
				)
			)
			OR (EXISTS
				(
					SELECT	1
					FROM	SFin.TransactionDetails td
					JOIN	SJob.Activities a ON (a.ID = td.ActivityId)
					WHERE	(a.Guid = @Guid)
						AND	(td.RowStatus NOT IN (0, 254))
				)
			)
		)
		BEGIN 
			;THROW 60000, N'This Activity has previously been invoiced or an invoice request has already been made.', 1
		END

		IF (
				(NOT EXISTS
					(
						SELECT	1
						FROM	SJob.Activities a 
						JOIN	SJob.ActivityStatus ast ON (ast.ID = a.ActivityStatusID)
						WHERE	(ast.IsCompleteStatus = 1)
							AND	(a.Guid = @Guid)
					)
				)
			)
		BEGIN 
			;THROW 60000, N'The Activity must be complete before it can be invoiced.', 1
		END

		-- Get the current user.
		SELECT	@CreatedByUserGuid = SCore.GetCurrentUserGuid()

		-- Get the details to create the invoice.
		SELECT	@JobGuid = j.Guid,
				@MilestoneGuid = m.Guid,
				@Net = CASE WHEN a.InvoicingValue > 0 THEN a.InvoicingValue ELSE (i.BillableRate * a.InvoicingQuantity) END
		FROM	SJob.Activities a
		JOIN	SJob.Jobs j ON (j.ID = a.JobId)
		JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
		JOIN	SCrm.Accounts fa ON (fa.ID = j.FinanceAccountID)
		JOIN	SJob.Milestones m ON (m.id = a.MilestoneID)
		WHERE	(a.Guid = @Guid)

		EXEC SFin.InvoiceRequestUpsert @JobGuid = @JobGuid,				-- uniqueidentifier
									   @RequesterUserGuid = @CreatedByUserGuid,	-- uniqueidentifier
									   @Notes = N'',				-- nvarchar(max)
									   @Guid = @InvoiceRequestGuid,					-- uniqueidentifier
									   @InvoicingType = N'',
									   @ExpectedDate = NULL,
									   @ManualStatus = 0,
									   @PaymentStatusGuid = '00000000-0000-0000-0000-000000000000'
				
		EXEC sFin.InvoiceRequestItemsUpsert @InvoiceRequestGuid = @InvoiceRequestGuid, -- uniqueidentifier
											@MilestoneGuid = @MilestoneGuid,		-- uniqueidentifier
											@ActivityGuid = @Guid,		-- uniqueidentifier
											@Net = @Net,				-- decimal(19, 2)
											@Guid = @InvoiceRequestItemGuid,				-- uniqueidentifier
											@ShortDescription = N'',
											@RIBAStageGuid = '00000000-0000-0000-0000-000000000000'
		
	END;
GO