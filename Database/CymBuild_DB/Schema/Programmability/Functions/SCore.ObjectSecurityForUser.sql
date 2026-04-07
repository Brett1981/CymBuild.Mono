SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[ObjectSecurityForUser]
	(
		@ObjectGuid UNIQUEIDENTIFIER,
		@UserId		INT
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
	RETURN
	SELECT
			@ObjectGuid AS ObjectGuid,
			CAST(CASE
					WHEN EXISTS
						(
							SELECT
									1
							FROM
									SCore.ExpandedObjectSecurityForUser(@ObjectGuid, @UserId) os1
							WHERE
									os1.DenyRead > 0
						) THEN
						0
					WHEN EXISTS
						(
							SELECT
									1
							FROM
									SCore.ExpandedObjectSecurityForUser(@ObjectGuid, @UserId) os1
							WHERE
									os1.CanRead > 0
						) THEN
						1
					ELSE
					(CASE
							WHEN ISNULL(os2.HasSecurity, 0) = 0 THEN
								1
							ELSE
							0
					END
					)
			END AS BIT) AS CanRead,
			CAST(CASE
					WHEN EXISTS
						(
							SELECT
									1
							FROM
									SCore.ExpandedObjectSecurityForUser(@ObjectGuid, @UserId) os1
							WHERE
									os1.DenyWrite > 0
						) THEN
						0
					WHEN EXISTS
						(
							SELECT
									1
							FROM
									SCore.ExpandedObjectSecurityForUser(@ObjectGuid, @UserId) os1
							WHERE
									os1.CanWrite > 0
						) THEN
						1
					ELSE
					(CASE
							WHEN ISNULL(os2.HasSecurity, 0) = 0 THEN
								1
							ELSE
							0
					END
					)
			END AS BIT) AS CanWrite
	FROM
			[SCore].[Identities] i
	OUTER APPLY
			(
				SELECT
						1 HasSecurity
				WHERE
						(EXISTS
						(
							SELECT
									1
							FROM
									SCore.ObjectSecurity os3
							WHERE
									(os3.ObjectGuid = @ObjectGuid)
									AND (os3.RowStatus NOT IN (0, 254))
						)
						)
			) AS os2
	WHERE
			(i.ID = @UserId)
GO