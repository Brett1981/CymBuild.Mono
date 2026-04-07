SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[EnquiryServicesExtUpsert]
	(	@DateSent DATE,
		@DateAccepted DATE,
		@DateRejected DATE,
		@DateDeclinedToQuote DATE, --[CBLD-592]
		@DateDeclinedToQuoteReason NVARCHAR(MAX),
		@QuoteGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN

	

	IF (@QuoteGuid = '00000000-0000-0000-0000-000000000000')
	BEGIN
		RETURN;
	END;

	--[CBLD-592] -Declined to quote handling.
	IF(@DateDeclinedToQuote IS NOT NULL)
		BEGIN
			UPDATE	SSop.Quotes
			SET		DateDeclinedToQuote = @DateDeclinedToQuote
			WHERE	(Guid = @QuoteGuid);
		END;

	IF(@DateDeclinedToQuoteReason <> N'')
		BEGIN
			UPDATE	SSop.Quotes
			SET		DeclinedToQuoteReason = @DateDeclinedToQuoteReason
			WHERE	(Guid = @QuoteGuid);
		END;

	IF (
		   @DateSent IS NOT NULL
		OR	@DateAccepted IS NOT NULL
		OR	@DateRejected IS NOT NULL
	   )
	BEGIN
		DECLARE @DeadDate DATE, 
				@IsFinal BIT, 
				@RevisionNumber INT, 
				@OrganisationalUnitGuid UNIQUEIDENTIFIER,
				@DateDeclined DATE,
				@DateDeclinedReason NVARCHAR(MAX),
				@ContractGuid UNIQUEIDENTIFIER,
				@AgentContractGuid UNIQUEIDENTIFIER


		
		SELECT	@DeadDate = q.DeadDate, 
				@IsFinal = q.IsFinal,
				@RevisionNumber = q.RevisionNumber,
				@OrganisationalUnitGuid = ou.Guid,
				@DateDeclined = q.DateDeclinedToQuote,
				@DateDeclinedReason = q.DeclinedToQuoteReason,
				@ContractGuid = cct.Guid,
				@AgentContractGuid = act.Guid
		FROM	SSop.Quotes AS q
		JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = q.OrganisationalUnitID)
		JOIN    SSop.Contracts AS cct ON (cct.ID = q.ContractID)
		JOIN    SSop.Contracts AS act ON (act.ID = q.AgentContractID)
		WHERE	(q.Guid = @QuoteGuid)


		DECLARE @DeadStatus				UNIQUEIDENTIFIER	= '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';
		DECLARE @FinalStatus			UNIQUEIDENTIFIER	= '02A2237F-2AE7-4E05-926F-38E8B7D050A0';
		DECLARE @DateDeclinedStatus		UNIQUEIDENTIFIER	= '708C00E6-F45F-4CB2-8E91-A80B8B8E802E';

		DECLARE @IsDeadStatus			BIT = 0;
		DECLARE @IsFinalStatus			BIT = 0;
		DECLARE @IsDateDeclinedStatus	BIT = 0;

		/*
			Set the actual values here based on what we have/don't have in the 
			[SCore].[DataObjectTransition] table.

			The functions parameters above will be left in for now.
		
		*/

		--[DEAD DATE]
		IF(EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition AS dob
			LEFT JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
			WHERE dob.DataObjectGuid = @QuoteGuid AND wfs.Guid = @DeadStatus ))
		BEGIN
			SELECT @DeadDate = dob.DateTimeUTC
			FROM SCore.DataObjectTransition AS dob
			LEFT JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
			WHERE dob.DataObjectGuid = @QuoteGuid AND wfs.Guid = @DeadStatus
		END;
		--[FINAL STATUS]
		ELSE IF(EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition AS dob
			LEFT JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
			WHERE dob.DataObjectGuid = @QuoteGuid AND wfs.Guid = @FinalStatus ))
		BEGIN
			SET @IsFinal = 1;
		END;
		--[DECLINED STATUS]
		ELSE IF(EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition AS dob
			LEFT JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
			WHERE dob.DataObjectGuid = @QuoteGuid AND wfs.Guid = @DateDeclinedStatus))
		BEGIN
			SELECT @DeadDate = dob.DateTimeUTC
			FROM SCore.DataObjectTransition AS dob
			LEFT JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
			WHERE dob.DataObjectGuid = @QuoteGuid AND wfs.Guid = @DeadStatus
		END;
	

		DECLARE	@ValidationResults SCore.ValidationResult

		INSERT @ValidationResults
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
		SELECT	qv.TargetGuid, qv.TargetType, qv.IsReadOnly, qv.IsHidden, qv.IsInvalid, qv.IsInformationOnly, qv.Message
		FROM	SSop.tvf_QuotesValidate(@QuoteGuid, @DateSent, @DeadDate, @DateRejected,@IsFinal, @RevisionNumber, @OrganisationalUnitGuid, @DateDeclined, @DateDeclinedReason, @ContractGuid, @AgentContractGuid) AS qv
		
		DECLARE	@ValidationMessage NVARCHAR(MAX) = SCore.GetValidationString(@ValidationResults)

		IF (@ValidationMessage <> N'')
		BEGIN			
			;THROW 60000, @ValidationMessage, 1
		END

		IF (EXISTS
				(
					SELECT	 1
					FROM	 @ValidationResults AS vr
					JOIN	SCore.EntityProperties AS ep ON (ep.Guid = vr.TargetGuid)
					WHERE	((vr.IsReadOnly = 1) OR (vr.IsHidden = 1))
						AND	(
								(ep.Name = N'DateSent' AND @DateSent IS NOT NULL)
							OR	(ep.Name = N'DateRejected' AND @DateRejected IS NOT NULL)
							OR	(ep.Name = N'DateAccepted' AND @DateAccepted IS NOT NULL)
							)
				)
			)
		BEGIN 
			;THROW 60000, N'You cannot change the Sent, Rejected or Accepted Date at the time, please check the state current of the quote.', 1
		END

		UPDATE	SSop.Quotes
		SET		DateSent = @DateSent,
				DateRejected = @DateRejected,
				DateAccepted = @DateAccepted
		WHERE	(Guid = @QuoteGuid);

	END;
END;



GO