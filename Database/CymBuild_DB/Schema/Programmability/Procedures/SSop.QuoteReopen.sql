SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuoteReopen]
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
					AND	(g.Code = N'QUOTESU')
			)
		)
	BEGIN 
		;THROW 60000, N'Only members of the Quote Superusers group can run this action.', 1
	END
	ELSE
	BEGIN 
		UPDATE	q
		SET		q.DeadDate = NULL,
				q.DateRejected = NULL
		FROM	SSop.Quotes AS q
		WHERE	(q.Guid = @Guid)
			AND	(
					(q.DeadDate IS NOT NULL)
				OR	(q.DateRejected IS NOT NULL)
				)
		
		DECLARE @UserGuid UNIQUEIDENTIFIER;
		DECLARE @ReopenedStatus UNIQUEIDENTIFIER;
		DECLARE @DataObjectTransitionGuid UNIQUEIDENTIFIER = NEWID();
		DECLARE @PreviousStatusGuid UNIQUEIDENTIFIER;

		--Get the user guid
		SELECT @UserGuid = Guid
		FROM SCore.Identities
		WHERE (ID = @UserID)

		--Get the reopened status
		SELECT @ReopenedStatus = Guid
		FROM SCore.WorkflowStatus
		WHERE Name LIKE N'%Reopened%'


		--Get the most recent status applied to the record.
		SELECT TOP(1) @PreviousStatusGuid = wfs.Guid
		FROM SCore.DataObjectTransition as dot
		JOIN SCore.WorkflowStatus as wfs ON (wfs.ID = dot.StatusID)
		WHERE (DataObjectGuid = @Guid)
		ORDER BY dot.ID DESC;

		DECLARE @CompleteStatusGuid UNIQUEIDENTIFIER = '6042639D-EF8A-4B6F-9182-A69A7119C117';
		DECLARE @DeclinedStatusGuid UNIQUEIDENTIFIER = 'B9BA4510-6358-4C0A-BBA1-5FEB33C54F84';
		


		IF(@PreviousStatusGuid NOT IN (@CompleteStatusGuid, @DeclinedStatusGuid ))
		BEGIN 
			;THROW 60000, N'Last applied status must be "Completed" or "Declined"', 1
		END

		EXEC SCore.DataObjectTransitionUpsert 
				@DataObjectTransitionGuid, 
				@PreviousStatusGuid, 
				@ReopenedStatus, 
				N'System Imported', 
				@UserGuid, 
				'00000000-0000-0000-0000-000000000000', 
				@Guid, 
				1


	END
  END;

GO