/****** Object:  StoredProcedure [SSop].[QuotesUpsert]    Script Date: 07/03/2025 14:38:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







ALTER PROCEDURE [SSop].[QuotesUpsert]
	(	@OrganisationalUnitGuid UNIQUEIDENTIFIER,
		@QuotingUserGuid UNIQUEIDENTIFIER,
		@ContractGuid UNIQUEIDENTIFIER,
		@Date DATE,
		@Overview NVARCHAR(MAX),
		@ExpiryDate DATE,
		@DateSent DATE,
		@DateAccepted DATE,
		@DateRejected DATE,
		@RejectionReason NVARCHAR(MAX),
		@FeeCap DECIMAL(19, 2),
		@IsFinal BIT,
		@ExternalReference NVARCHAR(50),
		@QuotingConsultantGuid UNIQUEIDENTIFIER,
		@AppointmentFromRibaStageGuid UNIQUEIDENTIFIER,
		@CurrentStageGuid UNIQUEIDENTIFIER,
		@DeadDate DATE,
		@EnquiryServiceGuid UNIQUEIDENTIFIER,
		@ProjectGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @OrganisationalUnitId		INT = -1,
			@QuotingUserId				INT,
			@ContractId					INT = -1,
			@IsInsert					BIT = 0,
			@QuoteId					INT,
			@QuoteNumber				INT,
			@QuotingConsultantId		INT,
			@AppointmentFromRibaStageId INT,
			@CurrentStageId				INT,
			@EnquiryServiceID			INT,
			@ProjectID					INT;

	SELECT	@OrganisationalUnitId = ID
	FROM	SCore.OrganisationalUnits
	WHERE	(Guid = @OrganisationalUnitGuid);

	SELECT	@QuotingUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @QuotingUserGuid);

	SELECT	@QuotingConsultantId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @QuotingConsultantGuid);

	SELECT	@ContractId = ID
	FROM	SSop.Contracts
	WHERE	(Guid = @ContractGuid);

	SELECT	@AppointmentFromRibaStageId = ID
	FROM	SJob.RibaStages
	WHERE	(Guid = @AppointmentFromRibaStageGuid);

	SELECT	@EnquiryServiceID = es.ID
	FROM	SSop.EnquiryServices AS es
	WHERE	(es.Guid = @EnquiryServiceGuid);

	SELECT	@CurrentStageId = ID
	FROM	SJob.RibaStages
	WHERE	(Guid = @CurrentStageGuid);


	SELECT	@ProjectID = p.ID
	FROM	SSop.Projects AS p
	WHERE	(p.Guid = @ProjectGuid);

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SSop',			-- nvarchar(255)
								@ObjectName = N'Quotes',		-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SSop.Quotes
			 (RowStatus,
			  Guid,
			  OrganisationalUnitID,
			  QuotingUserId,
			  ContractID,
			  Date,
			  Overview,
			  ExpiryDate,
			  DateSent,
			  DateAccepted,
			  DateRejected,
			  RejectionReason,
			  FeeCap,
			  IsFinal,
			  ExternalReference,
			  QuotingConsultantId,
			  AppointmentFromRibaStageId,
			  CurrentRibaStageId,
			  DeadDate,
			  EnquiryServiceID,
			  ProjectId)
		VALUES
			 (
				 0,						-- RowStatus - tinyint
				 @Guid,					-- Guid - uniqueidentifier
				 @OrganisationalUnitId, -- OrganisationalUnitID - int
				 @QuotingUserId,		-- QuotingUserId - int
				 @ContractId,			-- ContractID - int
				 @Date,					-- Date - date
				 @Overview,				-- Overview - nvarchar(max)
				 @ExpiryDate,
				 @DateSent,
				 @DateAccepted,
				 @DateRejected,
				 @RejectionReason,
				 @FeeCap,
				 @IsFinal,
				 @ExternalReference,
				 @QuotingConsultantId,
				 @AppointmentFromRibaStageId,
				 @CurrentStageId,
				 @DeadDate,
				 @EnquiryServiceID,
				 @ProjectID
			 );

		SELECT	@QuoteId = SCOPE_IDENTITY ();

	END;
	ELSE
	BEGIN
		DECLARE @_quotingConsultant INT,
				@_isFinal			BIT,
				@_emailRecipient	NVARCHAR(MAX),
				@_emailBody			NVARCHAR(MAX),
				@_emailSubject		NVARCHAR(MAX),
				@_quoteNumber		NVARCHAR(MAX);

		SELECT	@_quotingConsultant = QuotingConsultantId,
				@_isFinal			= IsFinal,
				@_quoteNumber		= Number
		FROM	SSop.Quotes
		WHERE	(Guid = @Guid);

		UPDATE	SSop.Quotes
		SET		OrganisationalUnitID = @OrganisationalUnitId,
				QuotingUserId = @QuotingUserId,
				ContractID = @ContractId,
				Date = @Date,
				Overview = @Overview,
				ExpiryDate = @ExpiryDate,
				DateSent = @DateSent,
				DateAccepted = @DateAccepted,
				DateRejected = @DateRejected,
				RejectionReason = @RejectionReason,
				FeeCap = @FeeCap,
				IsFinal = @IsFinal,
				ExternalReference = @ExternalReference,
				QuotingConsultantId = @QuotingConsultantId,
				AppointmentFromRibaStageId = @AppointmentFromRibaStageId,
				CurrentRibaStageId = @CurrentStageId,
				DeadDate = @DeadDate,
				EnquiryServiceID = @EnquiryServiceID,
				ProjectId = @ProjectID
		WHERE	(Guid = @Guid);

		IF (@QuotingConsultantId <> @_quotingConsultant)
		BEGIN
			SELECT	@_emailRecipient = i.EmailAddress
			FROM	SCore.Identities AS i
			WHERE	(i.ID = @QuotingConsultantId);

			SET @_emailBody = N'You have been assigned as the consultant for quote <a href="'
							  + +SCore.GetCurrentApplicationUrl () + N'/QuoteDetail/' + CONVERT (	NVARCHAR(MAX),
																									@Guid
																								)
							  + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT (	NVARCHAR(MAX),
																				@Guid
																			)
							  + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
							  + @_quoteNumber + N'</a>. Please take a moment to review this record.';
			SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' assigned to your user.';

			EXEC SAlert.CreateNotification @Recipients = @_emailRecipient,	-- nvarchar(max)
										   @Subject = @_emailSubject,		-- nvarchar(255)
										   @Body = @_emailBody,				-- nvarchar(max)
										   @BodyFormat = N'TEXT',			-- nvarchar(20)
										   @Importance = N'NORMAL';			-- nvarchar(6)
		END;

		IF (@IsFinal <> @_isFinal)
	   AND	(@IsFinal = 1)
	   AND	(@DateSent IS NULL)
		BEGIN
			SELECT	@_emailRecipient = STRING_AGG (	  i.EmailAddress,
													  N';'
												  )
			FROM	SCore.Identities AS i
			JOIN	SCore.UserGroups AS ug ON (ug.IdentityID = i.ID)
			JOIN	SCore.Groups	 AS g ON (g.ID			 = ug.GroupID)
			WHERE	(g.Code = N'CDMSA');

			SET @_emailBody = N'Quote <a href="' + SCore.GetCurrentApplicationUrl () + N'/QuoteDetail/'
							  + CONVERT (	NVARCHAR(MAX),
											@Guid
										) + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT (	NVARCHAR(MAX),
																							@Guid
																						)
							  + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
							  + @_quoteNumber
							  + N'</a> has been marked as final. Please review this record and send out the quote.';
			SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' ready to send.';

			EXEC SAlert.CreateNotification @Recipients = @_emailRecipient,	-- nvarchar(max)
										   @Subject = @_emailSubject,		-- nvarchar(255)
										   @Body = @_emailBody,				-- nvarchar(max)
										   @BodyFormat = N'TEXT',			-- nvarchar(20)
										   @Importance = N'NORMAL';			-- nvarchar(6)
		END;
	END;

	IF (@IsInsert = 1)
	BEGIN
		SELECT	@QuoteNumber = NEXT VALUE FOR SSop.QuoteNumber;

		UPDATE	SSop.Quotes
		SET		Number = @QuoteNumber,
				RowStatus = 1
		WHERE	(ID = @QuoteId);
	END;

	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250),
			@FilingLocation	  NVARCHAR(MAX);

	SELECT	@FilingLocation =
		 (
			 SELECT ss.SiteIdentifier,
					spf.FolderPath
			 FROM	SCore.ObjectSharePointFolder AS spf
			 JOIN	SCore.SharepointSites		 AS ss ON (ss.ID = spf.SharepointSiteId)
			 WHERE	(spf.ObjectGuid = @Guid)
			 FOR JSON PATH
		 );

	DECLARE @QuoteNumberString NVARCHAR(30);

	SELECT	@FilingObjectName  = q.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / ' + agent.Name
								 + N' - ' + q.Overview,
			@QuoteNumberString = q.Number
	FROM	SSop.Quotes		AS q
	JOIN	SJob.Properties AS p ON (p.ID			= q.UprnId)
	JOIN	SCrm.Accounts	AS client ON (client.ID = q.ClientAccountId)
	JOIN	SCrm.Accounts	AS agent ON (agent.ID	= q.AgentAccountId)
	WHERE	(q.Guid = @Guid);

	EXEC SOffice.TargetObjectUpsert @EntityTypeGuid = N'1c4794c1-f956-4c32-b886-5500ac778a56',	-- uniqueidentifier
									@RecordGuid = @Guid,										-- uniqueidentifier
									@Number = @QuoteNumberString,								-- bigint
									@Name = @FilingObjectName,									-- nvarchar(250)	
									@FilingLocation = @FilingLocation;
END;
GO


