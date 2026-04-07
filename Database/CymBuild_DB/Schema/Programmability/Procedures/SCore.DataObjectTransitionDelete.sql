SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[DataObjectTransitionDelete]
  @Guid      UNIQUEIDENTIFIER
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
					AND	(g.Code = N'SU')
			)
		)
	BEGIN
		THROW 60000, 'You must be a member of the "Super User" group to delete a transition.', 1;
	END;


    EXEC SCore.DeleteDataObject
      @Guid = @Guid;

    UPDATE  SCore.DataObjectTransition
    SET     RowStatus = 254
    WHERE   Guid = @Guid
  END;

GO