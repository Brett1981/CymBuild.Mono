SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_ObjectSecurityForObject]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN SELECT		os.ID,
					os.RowStatus,
					os.RowVersion,
					os.Guid,
					os.ObjectGuid,
					i.Guid AS UserGuid,
					i.FullName AS UserFullName,
					i.EmailAddress AS UserIdentity,
					g.Guid AS GroupGuid,
					g.Name AS GroupName,
					g.DirectoryId AS GroupIdentity,
					os.CanRead,
					os.DenyRead,
					os.CanWrite,
					os.DenyWrite
	   FROM			SCore.ObjectSecurity		  AS os
	   JOIN			SCore.Identities			  AS i ON (i.ID = os.UserId)
	   JOIN			SCore.Groups				AS g ON (g.ID = os.GroupId)  
	   WHERE		(os.ObjectGuid = @Guid)
				AND	(os.RowStatus NOT IN (0, 254))
	   UNION ALL 
	   SELECT	-1,
				1,
				g.RowVersion,
				'00000000-0000-0000-0000-000000000000',
				@Guid,
				'00000000-0000-0000-0000-000000000000' AS UserGuid,
				N'Everyone' AS UserFullName,
				N'Everyone' AS UserIdentity,
				g.Guid AS GroupGuid,
				g.Name AS GroupName,
				g.DirectoryId AS GroupIdentity,
				CONVERT(BIT, 1) AS CanRead,
				CONVERT(BIT, 0) AS DenyRead,
				CONVERT(BIT, 1) AS CanWrite,
				CONVERT(BIT, 0) AS DenyWrite
		FROM	SCore.Groups AS g
		WHERE	(g.ID = ((-1)))
			AND	(NOT EXISTS	
					(
						SELECT	1
						FROM	SCore.ObjectSecurity AS os 
						WHERE	(os.ObjectGuid = @Guid)
							AND	(os.RowStatus NOT IN (0, 254))
					)
				)
GO