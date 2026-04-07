SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_EnquiriesValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@RowStatus TINYINT,
		@PropertyGuid UNIQUEIDENTIFIER,
		@ClientAccountGuid UNIQUEIDENTIFIER,
		@ClientAddressGuid UNIQUEIDENTIFIER,
		@AgentAccountGuid UNIQUEIDENTIFIER,
		@AgentAddressGuid UNIQUEIDENTIFIER,
		@FinanceAccountGuid UNIQUEIDENTIFIER,
		@FinanceAddressGuid UNIQUEIDENTIFIER,
		@IsReadyForQuoteReview BIT,
		@DescriptionOfWorks NVARCHAR(MAX),
		@ValueOfWork DECIMAL(19, 2),
		@CurrentProjectRibaStageGuid UNIQUEIDENTIFIER,
		@PropertyNumber NVARCHAR(100),
		@PropertyPostCode NVARCHAR(30),
		@ClientAddressNumber NVARCHAR(100),
		@ClientAddressPostCode NVARCHAR(30),
		@AgentAddressNumber NVARCHAR(100),
		@AgentAddressPostCode NVARCHAR(30),
		@AgentName NVARCHAR(250),
		@ClientName NVARCHAR(250),
		@DeclinedToQuoteDate DATE,
		@DeclinedToQuoteReason NVARCHAR(4000),
		@KeyDates NVARCHAR(2000),
		@DeadDate DATE,
		@EnterNewClientDetails BIT,
		@EnterNewAgentDetails BIT,
		@EnterNewFinanceDetails BIT,
		@EnterNewStructureDetails BIT,
		@IsClientFinanceAccount BIT,
		@ProjectGuid UNIQUEIDENTIFIER,
		@ClientContactDisplayName NVARCHAR(250),
		@AgentContactDisplayName NVARCHAR(250),
		@FinanceContactDisplayName NVARCHAR(250),
		@ClientContactDetailType UNIQUEIDENTIFIER,
		@ClientContactDetailTypeName NVARCHAR(100),
		@ClientContactDetailTypeValue NVARCHAR(250),
		@AgentContactDetailType UNIQUEIDENTIFIER,
		@AgentContactDetailTypeName NVARCHAR(100),
		@AgentContactDetailTypeValue NVARCHAR(250),
		@FinanceContactDetailType UNIQUEIDENTIFIER,
		@FinanceContactDetailTypeName NVARCHAR(100),
		@FinanceContactDetailTypeValue NVARCHAR(250),
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
		IsInformationOnly BIT NOT NULL DEFAULT ((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN

	DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER;

	DECLARE @ReadyForQuoteStatus	UNIQUEIDENTIFIER = 'EB867FA0-9608-4CC7-93BE-CC8E8140E8F0';
	DECLARE @DeadStatus				UNIQUEIDENTIFIER = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';
	DECLARE @DeclinedStatus			UNIQUEIDENTIFIER = N'708C00E6-F45F-4CB2-8E91-A80B8B8E802E';
	DECLARE @ReOpened				UNIQUEIDENTIFIER = '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD';

	

	DECLARE @DeclinedToQuote	 DATE;
	DECLARE @IsDeadDate			 DATE;
	DECLARE @ReadyForQuoteReview BIT = 0;


	DECLARE @IsEnquiryReopened  BIT = 0;


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
		SET @IsEnquiryReopened = 1;
	
	

	--Declined
	IF(EXISTS
		(
			SELECT 1 
			FROM SCore.DataObjectTransition AS dot
			JOIN SCore.WorkflowStatus AS ws ON (ws.ID = StatusID)
			WHERE 
				(dot.DataObjectGuid = @Guid) 
				AND (dot.RowStatus NOT IN (0,254))
				AND (ws.Guid = @DeclinedStatus)
		)
	)
	BEGIN
			SELECT @DeclinedToQuote = dot.DateTimeUTC
			FROM SCore.DataObjectTransition AS dot
			JOIN SCore.WorkflowStatus AS ws ON (ws.ID = StatusID)
			WHERE 
				(dot.DataObjectGuid = @Guid) 
				AND (dot.RowStatus NOT IN (0,254))
				AND (ws.Guid = @DeclinedStatus)
	END;

	--Dead
	ELSE IF(EXISTS
			(
				SELECT 1 
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowStatus AS ws ON (ws.ID = StatusID)
				WHERE 
					(dot.DataObjectGuid = @Guid) 
					AND (dot.RowStatus NOT IN (0,254))
					AND (ws.Guid = @DeadStatus)
			)
	)
	BEGIN
			SELECT @IsDeadDate = dot.DateTimeUTC
			FROM SCore.DataObjectTransition AS dot
			JOIN SCore.WorkflowStatus AS ws ON (ws.ID = StatusID)
			WHERE 
				(dot.DataObjectGuid = @Guid) 
				AND (dot.RowStatus NOT IN (0,254))
				AND (ws.Guid = @DeadStatus)
	END;


	--Ready for quote review
	ELSE IF(EXISTS
			(
				SELECT 1 
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowStatus AS ws ON (ws.ID = StatusID)
				WHERE 
					(dot.DataObjectGuid = @Guid) 
					AND (dot.RowStatus NOT IN (0,254))
					AND (ws.Guid = @ReadyForQuoteStatus)
			)
	)
	BEGIN
			SET @ReadyForQuoteReview = 1;
	END;



	/*
		Hide the old key dates field if it wasn't populated. 
	*/
	IF (@KeyDates = N'')
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name	   = N'KeyDates';
	END;

	
	/*
		If there's both a declined to quote date and reason, lock these fields down. 
	*/
	IF (@DeclinedToQuote IS NOT NULL OR @DeclinedToQuoteDate IS NOT NULL)
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
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name NOT IN (N'DeclinedToQuoteDate', N'DeclinedToQuoteReason');
	END;

	/* 
		If there's a dead date. Lock everything down except that field. 
	*/
	IF ((@IsDeadDate IS NOT NULL OR @DeadDate IS NOT NULL) AND @IsEnquiryReopened = 0)
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
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name	   <> N'DeadDate';
	END;

	/* Hide show manual property entry.  */
	IF (
		   @PropertyGuid <> '00000000-0000-0000-0000-000000000000'
		OR	@EnterNewStructureDetails = 0
	   )
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'PropertyNameNumber', N'PropertyAddressLine1', N'PropertyAddressLine2',
							   N'PropertyAddressLine3', N'PropertyTown', N'PropertyCountyId', N'PropertyPostCode',
							   N'PropertyCountryId'
							  
							  );
	END;
	ELSE
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'PropertyID');
	END;

	/*
		Ensure that if the user is manually entering the client/agent/finance details - along with contact details -
		that any field pertaining to the contact details are made compulsory once the "...ContactDisplayName" has been filled.
	*/

	--Client
	IF (
			@EnterNewClientDetails = 1 AND 
			@ClientContactDisplayName <> N'' AND 
			(
				@ClientContactDetailType = '00000000-0000-0000-0000-000000000000' OR
				@ClientContactDetailTypeName = N'' OR
				@ClientContactDetailTypeValue = N''
			)
		)
	BEGIN
	INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					0,
					1,
					N'Please enter contact details for client.'
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name IN (N'ClientContactDetailType', N'ClientContactDetailTypeName',N'ClientContactDetailTypeValue', N'');

	END;


	--Agent
	IF (
			@EnterNewAgentDetails = 1 AND 
			@AgentContactDisplayName <> N'' AND
			(
				@AgentContactDetailType = '00000000-0000-0000-0000-000000000000' OR
				@AgentContactDetailTypeName = N'' OR
				@AgentContactDetailTypeValue = N''
			)
		)
	BEGIN
	INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					0,
					1,
					N'Please enter contact details for agent account.'
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name IN (N'AgentContactDetailType', N'AgentContactDetailTypeName',N'AgentContactDetailTypeValue', N'');

	END;

	--Finance
	IF (
			@EnterNewFinanceDetails = 1 AND 
			@FinanceContactDisplayName <> N'' AND
			(
				@FinanceContactDetailType = '00000000-0000-0000-0000-000000000000' OR
				@FinanceContactDetailTypeName = N'' OR
				@FinanceContactDetailTypeValue = N''
			)
		)
	BEGIN
	INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					0,
					1,
					N'Please enter contact details for finance account.'
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name IN (N'FinanceContactDetailType', N'FinanceContactDetailTypeName',N'FinanceContactDetailTypeValue', N'');

	END;

	/* Hide / Show Manual Client Entry */
	IF (
		   @ClientAccountGuid <> '00000000-0000-0000-0000-000000000000'
		OR	@EnterNewClientDetails = 0
	   )
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name	   = N'ClientName';
	END;
	ELSE
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'ClientAccountID');
	END;

	/* Hide show manual client Address Entry */
	IF (
		   @ClientAddressGuid <> '00000000-0000-0000-0000-000000000000'
		OR	@EnterNewClientDetails = 0
	   )
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'ClientAddressNameNumber', N'ClientAddressLine1', N'ClientAddressLine2',
							   N'ClientAddressLine3', N'ClientAddressTown', N'ClientAddressCountyId',
							   N'ClientAddressPostCode', N'ClientAddressCountryId',
							    N'ClientContactDisplayName',N'ClientContactDetailType',N'ClientContactDetailTypeName',N'ClientContactDetailTypeValue' --CBLD-653
							  );
	END;
	ELSE
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'ClientAddressID', N'ClientAccountContactID');  
	END;

	/* Hide Show Manual Agent Entry */
	IF (
		   @AgentAccountGuid <> '00000000-0000-0000-0000-000000000000'
		OR	@EnterNewAgentDetails = 0
	   )
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name	   = N'AgentName';
	END;
	ELSE
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'AgentAccountID');
	END;

	/* Hide show manual agent address entry */
	IF (
		   @AgentAddressGuid <> '00000000-0000-0000-0000-000000000000'
		OR	@EnterNewAgentDetails = 0
	   )
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'AgentAddressNameNumber', N'AgentAddressLine1', N'AgentAddressLine2',
							   N'AgentAddressLine3', N'AgentTown', N'AgentCountyId', N'AgentAddressPostCode',
							   N'AgentCountryId', N'AgentContactDisplayName', N'AgentContactDetailType', N'AgentContactDetailTypeName', N'AgentContactDetailTypeValue'
							  );
	END;
	ELSE
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'AgentAddressID', N'AgentAccountContactID');
	END;

	/* Hide show manual finance account entry */
	IF (@IsClientFinanceAccount = 1)
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epg.Guid,
				N'G',
				0,
				1,
				0,
				N''
		FROM	SCore.EntityPropertyGroups AS epg
		JOIN	SCore.EntityTypes		   AS et ON (et.ID = epg.EntityTypeID)
		WHERE	(epg.Name = N'Finance Account Details')
			AND (et.Name  = N'Enquiries');
	END;
	ELSE
	BEGIN
		IF (
			   @FinanceAccountGuid <> '00000000-0000-0000-0000-000000000000'
			OR	@EnterNewFinanceDetails = 0
		   )
		BEGIN
			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name	   = N'FinanceAccountName';
		END;
		ELSE
		BEGIN
			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name IN (N'FinanceAccountID');
		END;

		IF (
			   @FinanceAddressGuid <> '00000000-0000-0000-0000-000000000000'
			OR	@EnterNewFinanceDetails = 0
		   )
		BEGIN
			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name IN (N'FinanceAddressNameNumber', N'FinanceAddressLine1', N'FinanceAddressLine2',
								   N'FinanceAddressLine3', N'FinanceTown', N'FinanceCountyId', N'FinancePostCode',
								   N'FinanceContactDisplayName', N'FinanceContactDetailType', N'FinanceContactDetailTypeName', N'FinanceContactDetailTypeValue'
								  );
		END;
		ELSE
		BEGIN
			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	epfvv.[Schema] = N'SSop'
				AND epfvv.Hobt	   = N'Enquiries'
				AND epfvv.Name IN (N'FinanceAddressID', N'FinanceContactID');
		END;
	END;

	

	IF (@ReadyForQuoteReview = 1)
		BEGIN
			IF (@DescriptionOfWorks = N'')
			BEGIN
				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'DescriptionOfWorks'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until there is a description of the works.'
					 );
			END;

			IF (@ValueOfWork = 0)
			BEGIN
				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'ValueOfWork'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until there is a value of work.'
					 );
			END;

			IF (@CurrentProjectRibaStageGuid = '00000000-0000-0000-0000-000000000000')
			BEGIN
				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'CurrentProjectRibaStageId'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until there is a current RIBA stage.'
					 );
			END;


			IF (@PropertyGuid = '00000000-0000-0000-0000-000000000000')
		   AND	(@PropertyNumber = N'')
		   AND	(@PropertyPostCode = N'')
			BEGIN
				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'PropertyId'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until property details have been entered.'
					 );
			END;

			/*
				Don't allow the enquiry to be submitted for quoting until their is a client or agent. 
			*/
			IF (@ClientAccountGuid = '00000000-0000-0000-0000-000000000000')
		   AND	(@ClientName = N'')
		   AND	(@AgentAccountGuid = '00000000-0000-0000-0000-000000000000')
		   AND	(@AgentName = N'')
			BEGIN
				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'ClientAccountId'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until client or agent account has been entered.'
					 );

				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'AgentAccountId'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until client or agent account has been entered.'
					 );
			END;

			/*
				Don't allow the enquiry to be submitted for quoting until their is a client or agent. 
			*/
			IF (@ClientAddressGuid = '00000000-0000-0000-0000-000000000000')
		   AND	(@ClientAddressNumber = N'')
		   AND	(@ClientAddressPostCode = N'')
		   AND	(@AgentAddressGuid = '00000000-0000-0000-0000-000000000000')
		   AND	(@AgentAddressNumber = N'')
		   AND	(@AgentAddressPostCode = N'')
			BEGIN
				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'ClientAddressId'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until client or agent address details have been entered.'
					 );

				SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid (	  N'SSop',
																			  N'Enquiries',
																			  N'AgentAddressId'
																		  );

				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				VALUES
					 (
						 @EntityPropertyGuid,
						 N'P',
						 0,
						 0,
						 1,
						 N'An enquiry cannot be reviewed until client or agent address details have been entered.'
					 );
			END;
		END;


	/*
		Check if there are quotes in existence. 
	*/
	DECLARE	@IsReadyForQuoteReviewGuid UNIQUEIDENTIFIER = SCore.GetEntityPropertyGuid(N'SSop', N'Enquiries', N'IsReadyForQuoteReview')
	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.EnquiryServices AS es
		 JOIN	SSop.Enquiries		 AS e ON (e.ID = es.EnquiryId)
		 WHERE	(e.Guid = @Guid)
			AND (es.RowStatus NOT IN (0, 254))
			AND (EXISTS
			 (
				 SELECT 1
				 FROM	SSop.Quotes AS q
				 WHERE	(q.EnquiryServiceID = es.ID)
					AND (q.RowStatus NOT IN (0, 254))
			 )
				)
			AND (EXISTS
						(
							SELECT	1
							FROM	SCore.RecordHistory AS rh
							JOIN	SCore.EntityProperties ep ON (ep.ID = rh.EntityPropertyID)
							WHERE	(ep.Guid = @IsReadyForQuoteReviewGuid)
								AND	(rh.RowGuid = @Guid)
						)
					)
	 )
	   )
	BEGIN
		/*
			Prevent changes to 
				- Ready for Quote, ead Date and Declined to Quote date, 
				- Enquiry and Status Groups
				- Entering adhoc account or structure details. 
			after quotes have been created. 
		*/
		

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SSop.EnquiryServices AS es
			 JOIN	SSop.Enquiries		 AS e ON (e.ID = es.EnquiryId)
			 WHERE	(e.Guid = @Guid)
				AND (es.RowStatus NOT IN (0, 254))
		 )
		   )
		BEGIN
			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
			SELECT	epgfvv.Guid,		-- TargetGuid - uniqueidentifier
					epgfvv.TargetType,	-- TargetType - char(1)
					1,					-- IsReadOnly - bit
					0,					-- IsHidden - bit
					0,					-- IsInvalid - bit
					0,					-- IsInformationOnly - bit
					N''					-- Message - nvarchar(2000)
			FROM	SCore.EntityPropertiesGroupsForValidationV AS epgfvv
			WHERE	(epgfvv.EntityType = N'Enquiries')
				AND (epgfvv.Name NOT IN (N'Enquiry', N'Status'));

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
			SELECT	epfvv.Guid,			-- TargetGuid - uniqueidentifier
					epfvv.TargetType,	-- TargetType - char(1)
					1,					-- IsReadOnly - bit
					1,					-- IsHidden - bit
					0,					-- IsInvalid - bit
					0,					-- IsInformationOnly - bit
					N''					-- Message - nvarchar(2000)
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	(epfvv.[Schema] = N'SSop')
				AND (epfvv.Hobt		= N'Enquiries')
				AND (epfvv.Name IN (N'EnterNewClientDetails', N'EnterNewStructureDetails', N'EnterNewAgentDetails',
									N'EnterNewFinanceDetails'
								   )
					);
		END;

		/* If any of the quotes have reached ceertain states, don't allow the enquiry to be changed. */
		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SSop.EnquiryServices			 AS es
			 JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.Id	 = es.ID)
			 JOIN	SSop.Enquiries					 AS e ON (e.ID			 = es.EnquiryId)
			 JOIN	SSop.Quote_CalculatedFields		 AS qcf ON (esei.QuoteID = qcf.ID)
			 WHERE	(qcf.QuoteStatus IN (N'Sent', N'Accepted', N'Rejected', N'Complete'))
				AND (e.Guid = @Guid)
				AND	(es.RowStatus NOT IN (0, 254))
		 )
		   )
		BEGIN
			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
			SELECT	epgfvv.Guid,		-- TargetGuid - uniqueidentifier
					epgfvv.TargetType,	-- TargetType - char(1)
					1,					-- IsReadOnly - bit
					0,					-- IsHidden - bit
					0,					-- IsInvalid - bit
					0,					-- IsInformationOnly - bit
					N''					-- Message - nvarchar(2000)
			FROM	SCore.EntityPropertiesGroupsForValidationV AS epgfvv
			WHERE	(epgfvv.EntityType = N'Enquiries')
			AND (epgfvv.Name NOT IN (N'Status')) --Do not disable the "Status" group just yet.
		END;

		--Disable everything but the two chase date fields in the "Status" group
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				epfvv.TargetType,
				1,
				0,
				0,
				N''
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
			AND epfvv.Name IN (N'IsReadyForQuoteReview', N'DeclinedToQuoteDate', N'DeadDate')
		END;


		--Hide AgentContractID if ContractID is set, and vice-versa.
		IF (@ContractGuid <> '00000000-0000-0000-0000-000000000000')
		BEGIN

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	(epfvv.[Schema] = N'SSop')
				AND (epfvv.Hobt		= N'Enquiries')
				AND (epfvv.Name		= (N'AgentContractID'));
		END
		ELSE IF (@AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
		BEGIN

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	(epfvv.[Schema] = N'SSop')
				AND (epfvv.Hobt		= N'Enquiries')
				AND (epfvv.Name		= (N'ContractID'));
		END;


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
			AND (@IsEnquiryReopened <> 1)
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
		WHERE	epfvv.[Schema] = N'SSop'
			AND epfvv.Hobt	   = N'Enquiries'
	END;


	RETURN;
END;

GO