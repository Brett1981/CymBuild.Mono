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

		EXEC SCore.DataObjectTransitionUpsert @DataObjectTransitionGuid, @PreviousStatusGuid, @ReopenedStatus, N'System Imported', @UserGuid, '00000000-0000-0000-0000-000000000000', @Guid, 1


	END
  END;

GO