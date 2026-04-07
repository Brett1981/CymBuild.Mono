SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobReopen]
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
					AND	(g.Code = N'JOBSU')
					AND (ug.RowStatus NOT IN (0,254))
					AND (g.RowStatus NOT IN (0,254))
			)
		)
	BEGIN 
		;THROW 60000, N'Only members of the Job Superusers group can run this action.', 1
	END
	ELSE
	BEGIN 
		UPDATE	j
		SET		j.JobCompleted = NULL
		FROM	SJob.Jobs AS j
		WHERE	(j.Guid = @Guid)


		--Parameters for upserting the data object transition.
		DECLARE @TransitionGuid UNIQUEIDENTIFIER = NEWID();
		DECLARE @ReopenStatus UNIQUEIDENTIFIER = '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD';
		DECLARE @PreviousStatusGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';
		DECLARE @Comment NVARCHAR(200) = N'The job has been reopened.';
		DECLARE @UserGuid UNIQUEIDENTIFIER;
		DECLARE @IsImported BIT = 0;


		--Get the user GUID
		SELECT @UserGuid = Guid
		FROM SCore.Identities
		WHERE (ID = @UserID);


		--Get the current status applied to the record.
		SELECT @PreviousStatusGuid = Guid
		FROM SCore.DataObjectTransition AS dob
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