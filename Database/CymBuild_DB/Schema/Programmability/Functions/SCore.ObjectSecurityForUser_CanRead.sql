SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[ObjectSecurityForUser_CanRead]
	(
		@ObjectGuid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN
	SELECT	1 AS CanRead
	FROM	SCore.Identities i
	WHERE	(i.ID = @UserId)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SCore.ObjectSecurity os1
					WHERE	(os1.ObjectGuid = @ObjectGuid)
						AND	(os1.DenyRead > 0)
						AND	(os1.RowStatus NOT IN (0, 254))
						AND (
								(os1.UserId = i.ID)
								OR 
								(EXISTS	
									(	
										SELECT 1
										FROM	SCore.UserGroups ug
										WHERE	(ug.IdentityID = i.ID)
											AND	(os1.GroupId = ug.GroupID)
											AND	(ug.RowStatus NOT IN (0, 254))
									)
								)
							)
				)
			)
		AND	(
				( EXISTS
					(
						SELECT	1
						FROM	SCore.ObjectSecurity os1
						WHERE	(os1.ObjectGuid = @ObjectGuid)
							AND	(os1.CanRead > 0)
							AND	(os1.RowStatus NOT IN (0, 254))
							AND (
								(os1.UserId = i.ID)
								OR 
								(EXISTS	
									(
										SELECT
												1
										FROM
												SCore.UserGroups ug
										WHERE
												(ug.IdentityID = i.ID)
												AND (os1.GroupId = ug.GroupId)
												AND (ug.RowStatus NOT IN (0, 254))
											)
								)
							)
					)
				)
			OR	(NOT EXISTS
					(
						SELECT	1
						FROM	SCore.ObjectSecurity hos3
						WHERE	(hos3.ObjectGuid = @ObjectGuid)
							AND (hos3.RowStatus NOT IN (0, 254))
					)
				)
			)
GO