SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[ExpandedObjectSecurityForUser]
	(
		@ObjectGuid UNIQUEIDENTIFIER,
		@UserId		INT
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
	RETURN

	SELECT
			os.DenyRead,
			os.CanRead,
			os.CanWrite,
			os.DenyWrite
	FROM
			SCore.ObjectSecurity AS os
	WHERE
			(os.RowStatus NOT IN (0, 254))
			AND (os.ObjectGuid = @ObjectGuid)
			AND	(@UserId > 0)
			AND (
					(os.UserId = @UserId)
					OR (EXISTS
					(
						SELECT
								1
						FROM
								SCore.UserGroups AS ug
						JOIN
								SCore.Groups AS g ON (ug.GroupID = g.ID)
						WHERE
								(g.ID = os.GroupID)
								AND (g.ID > 0)
								AND (ug.IdentityID = @UserId)
								AND (ug.RowStatus NOT IN (0, 254))
								AND (g.RowStatus NOT IN (0, 254))
					)
					)
			)
GO