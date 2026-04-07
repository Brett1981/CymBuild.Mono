SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobsValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@JobCompleted DATETIME2,
		@JobCancelled DATETIME2,
		@DeadDate DATE, 
		@JobTypeGuid UNIQUEIDENTIFIER,
		@CannotBeInvoiced BIT,
		@CannotBeInvoicedReason NVARCHAR(MAX),
		@ContractGuid UNIQUEIDENTIFIER,
		@AgentContractGuid UNIQUEIDENTIFIER
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN
	DECLARE @JobTypeName NVARCHAR(250)

	DECLARE @IsJobDead		BIT = 0;
	DECLARE @IsJobCancelled BIT = 0
	DECLARE @IsJobCompleted BIT = 0;
	DECLARE @IsJobReopened  BIT = 0;

	DECLARE @CancelledStatus	UNIQUEIDENTIFIER = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64';
	DECLARE @CompletededStatus	UNIQUEIDENTIFIER = '20D22623-283B-4088-9CEB-D944AC3E6516';
	DECLARE @DeadStatus			UNIQUEIDENTIFIER = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';
	DECLARE @ReOpened			UNIQUEIDENTIFIER = '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD';


	--Dead
	IF(EXISTS(SELECT 1 FROM SCore.DataObjectTransition AS dot JOIN SCore.WorkflowStatus AS ws ON (ws.ID = dot.StatusID) WHERE dot.DataObjectGuid = @Guid AND ws.Guid = @DeadStatus AND dot.RowStatus NOT IN (0,254) ))
		SET @IsJobDead = 1;

	--Cancelled
	IF(EXISTS(SELECT 1 FROM SCore.DataObjectTransition AS dot JOIN SCore.WorkflowStatus AS ws ON (ws.ID = dot.StatusID) WHERE dot.DataObjectGuid = @Guid AND ws.Guid = @CancelledStatus AND dot.RowStatus NOT IN (0,254)))
		SET @IsJobCancelled = 1;

	--Completed
	IF(EXISTS(SELECT 1 FROM SCore.DataObjectTransition AS dot JOIN SCore.WorkflowStatus AS ws ON (ws.ID = dot.StatusID) WHERE dot.DataObjectGuid = @Guid AND ws.Guid = @CompletededStatus AND dot.RowStatus NOT IN (0,254)))
		SET @IsJobCompleted = 1;

	IF(EXISTS
				(
					SELECT 1 
					FROM SCore.DataObjectTransition AS dot 
					JOIN SCore.WorkflowStatus AS ws ON (ws.ID = dot.StatusID) 
					WHERE 
							(dot.DataObjectGuid = @Guid) 
						AND (ws.Guid = @ReOpened)
						AND dot.RowStatus NOT IN (0,254)
						--No other transition after "Reopened"
						AND NOT EXISTS
								(
									SELECT 1 
									FROM SCore.DataObjectTransition AS dot1 
									JOIN SCore.WorkflowStatus AS ws ON (ws.ID = dot1.StatusID) 
									WHERE 
											(dot1.DataObjectGuid = @Guid)
										AND (dot1.RowStatus NOT IN (0,254))
										AND (ws.RowStatus NOT IN (0,254))
										AND (dot1.ID > dot.ID)
								)
				)
			)
		SET @IsJobReopened = 1;


	SELECT	@JobTypeName = jt.Name 
	FROM	SJob.JobTypes jt
	WHERE	(jt.Guid = @JobTypeGuid)





	IF (@JobTypeName NOT IN (N'CDM PD', N'CDM PD (Construction Phase Only)', N'CDM PD (Pre-Construction Phase Only)')) 
	BEGIN 

		INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        SELECT epfv.Guid, N'P', 0, 1, 0, N''
		FROM	SCore.EntityPropertiesForValidationV epfv
		WHERE	(epfv.Name = N'ClientAppointmentReceived')
			AND	(epfv.Hobt = N'Jobs')
			AND	(epfv.[Schema] = N'SJob')
	END 

	/* Make the Job read only when complete */
	IF (((@IsJobCompleted = 1 OR @JobCompleted IS NOT NULL) OR (@IsJobCancelled  = 1 OR @JobCancelled IS NOT NULL) OR (@IsJobDead = 1 OR @DeadDate IS NOT NULL)) AND @IsJobReopened = 0)
	BEGIN 
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT
			 	 epfv.Guid,
				 N'P',
				 1,
				 0,
				 0,
				 N''
		FROM	SCore.EntityPropertiesForValidationV AS epfv
		WHERE	(epfv.[Schema] = N'SJob')
			AND (epfv.Hobt = N'Jobs')

    END

	IF (NOT EXISTS 
			(
				SELECT	1
				FROM	SJob.Jobs
				WHERE	(Guid = @Guid)
			)
		)
	BEGIN 
		INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        SELECT epfv.Guid, N'P', 1, 0, 0, N''
		FROM	SCore.EntityPropertiesForValidationV epfv
		WHERE	(epfv.Name IN (N'JobCancelled', N'JobDormant', N'JobCompleted', N'CurrentRibaStageId', N'IsCompleteForReview', N'ReviewedByUserId', N'ReviewedDateTimeUTC'))
			AND	(epfv.Hobt = N'Jobs')
			AND	(epfv.[Schema] = N'SJob')

	END

	IF(@CannotBeInvoiced = 0)
		BEGIN
		INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        SELECT epfv.Guid, N'P', 1, 0, 0, N''
		FROM	SCore.EntityPropertiesForValidationV epfv
		WHERE	(epfv.Name IN (N'CannotBeInvoicedReason'))
			AND	(epfv.Hobt = N'Jobs')
			AND	(epfv.[Schema] = N'SJob')
		END

	IF(@CannotBeInvoiced = 1 AND @CannotBeInvoicedReason = '')
		BEGIN 
		INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        SELECT epfv.Guid, N'P', 0, 0, 1, N'Please, provide a reason why the job cannot be invoiced.'
		FROM	SCore.EntityPropertiesForValidationV epfv
		WHERE	(epfv.Name IN (N'CannotBeInvoicedReason'))
			AND	(epfv.Hobt = N'Jobs')
			AND	(epfv.[Schema] = N'SJob')
		END

	IF(@ContractGuid <> '00000000-0000-0000-0000-000000000000')
	BEGIN 
		INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        SELECT epfv.Guid, N'P', 0, 1, 0, N''
		FROM	SCore.EntityPropertiesForValidationV epfv
		WHERE	(epfv.Name IN (N'AgentContractID'))
			AND	(epfv.Hobt = N'Jobs')
			AND	(epfv.[Schema] = N'SJob')

	END
	ELSE IF(@AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
	BEGIN 
		INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        SELECT epfv.Guid, N'P', 0, 1, 0, N''
		FROM	SCore.EntityPropertiesForValidationV epfv
		WHERE	(epfv.Name IN (N'ContractID'))
			AND	(epfv.Hobt = N'Jobs')
			AND	(epfv.[Schema] = N'SJob')

	END

	--Lock the record if we have a status that's marked as "Final"
	IF(EXISTS
		(
			SELECT 1 
			FROM SCore.DataObjectTransition AS dot1
			JOIN SCore.WorkflowStatus AS ws ON (ws.ID = StatusID)
			WHERE 
				(dot1.DataObjectGuid = @Guid) 
				AND (dot1.RowStatus NOT IN (0,254))
				AND (ws.IsCompleteStatus = 1)	
				AND (NOT EXISTS
							(
								SELECT 1 
								FROM SCore.DataObjectTransition AS dot2
								WHERE 
									(dot2.DataObjectGuid = @Guid)
									AND (dot2.RowStatus NOT IN (0,254))
									AND (dot2.ID > dot1.ID)
							)
					)
				AND (@IsJobReopened <> 1)
		)
	)
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				1,
				0,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SJob'
			AND epfvv.Hobt	   = N'SJobs'
	END;

	RETURN;
END;

GO