SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[ActivityReopen]
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
		UPDATE	a
		SET		a.ActivityStatusID = ast2.ID
		FROM	SJob.Activities AS a
		CROSS APPLY 
		(
			SELECT	ast.ID
			FROM	SJob.ActivityStatus AS ast
			WHERE	Name = 'Reopened'
		) ast2
		WHERE	(a.Guid = @Guid)
	END
  END;

GO