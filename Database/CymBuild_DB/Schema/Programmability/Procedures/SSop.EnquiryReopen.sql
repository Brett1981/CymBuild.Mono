SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[EnquiryReopen]
  @Guid                    UNIQUEIDENTIFIER OUT
AS
  BEGIN
    DECLARE @UserID             INT = -1;

    SELECT
            @UserID = ISNULL(CONVERT(INT,
            SESSION_CONTEXT(N'user_id')
            ),
            -1
            );

    IF (NOT EXISTS
			(
				SELECT	1
				FROM	SCore.UserGroups AS ug
				JOIN	SCore.Groups AS g ON (g.ID = ug.GroupID)
				WHERE	(ug.IdentityID = @UserID)
					AND	(g.Code = N'ENQUIRYSU')
					AND (ug.RowStatus NOT IN (0,254))
					
			)
		)
	BEGIN 
		;THROW 60000, N'Only members of the Enquiries Superusers group can run this action.', 1
	END
	ELSE
	BEGIN 
		UPDATE	e
		SET		e.DeclinedToQuoteDate = NULL
		FROM	SSop.Enquiries AS e
		WHERE	(e.Guid = @Guid)
			AND	(e.DeclinedToQuoteDate IS NOT NULL)


		--Parameters for upserting the data object transition.
		DECLARE @TransitionGuid UNIQUEIDENTIFIER = NEWID();
		DECLARE @ReopenStatus UNIQUEIDENTIFIER = '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD';
		DECLARE @PreviousStatusGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';
		DECLARE @Comment NVARCHAR(200) = N'The job has been reopened.';
		DECLARE @UserGuid UNIQUEIDENTIFIER;
		DECLARE @IsImported BIT = 0;
		DECLARE @LastAppliedStatusGuid UNIQUEIDENTIFIER;


		--Get the user GUID
		SELECT @UserGuid = Guid
		FROM SCore.Identities
		WHERE (ID = @UserID);


		--Get the current status applied to the record.
		SELECT 
			@PreviousStatusGuid = dob.Guid,
			@LastAppliedStatusGuid =  wfs.Guid
		FROM SCore.DataObjectTransition AS dob
		JOIN SCore.WorkflowStatus AS wfs ON (wfs.Id = dob.StatusID)
		WHERE
				(dob.DataObjectGuid = @Guid)
			AND (dob.RowStatus NOT IN (0,254))
			AND (NOT EXISTS
					(
						SELECT 1 
						FROM SCore.DataObjectTransition AS dob1
						WHERE
								(dob1.DataObjectGuid = @Guid)
							AND (dob1.RowStatus NOT IN (0,254))
							AND (dob1.ID > dob.ID)
					)
				);

		DECLARE @CompleteStatusGuid UNIQUEIDENTIFIER = '6042639D-EF8A-4B6F-9182-A69A7119C117';
		DECLARE @DeclinedStatusGuid UNIQUEIDENTIFIER = '708C00E6-F45F-4CB2-8E91-A80B8B8E802E';
		DECLARE @EngineeringDeclinedStatusGuid UNIQUEIDENTIFIER = '60B8D960-8F6C-495D-B2E7-F19EBD5506EE';


		IF(@LastAppliedStatusGuid NOT IN (@CompleteStatusGuid, @DeclinedStatusGuid, @EngineeringDeclinedStatusGuid ))
		BEGIN 
			;THROW 60000, N'Last applied status must be "Completed" or "Declined"', 1
		END
				

		--Add reopened status.
		EXEC SCore.DataObjectTransitionUpsert  
				@TransitionGuid, 
				@PreviousStatusGuid, 
				@ReopenStatus, 
				@Comment, 
				@UserGuid, 
				@UserGuid, 
				@Guid, 
				@IsImported;

	END
  END;

GO