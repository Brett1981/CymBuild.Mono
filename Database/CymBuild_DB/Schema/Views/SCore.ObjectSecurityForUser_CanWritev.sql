SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[ObjectSecurityForUser_CanWritev]
        --WITH SCHEMABINDING
AS
	SELECT	do.Guid,
			i.ID
	FROM	SCore.DataObjects do
	CROSS JOIN	SCore.Identities i
	WHERE	(NOT EXISTS
				(
					SELECT	1
					FROM	SCore.ObjectSecurity os1
					WHERE	(os1.UserId = i.ID)
						AND	(os1.ObjectGuid = do.Guid)
						AND	(os1.DenyWrite > 0)
						AND	(os1.RowStatus NOT IN (0, 254))
				)
			)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SCore.ObjectSecurity os1
					JOIN	SCore.UserGroups ug ON (os1.GroupId = ug.GroupID)
					WHERE	(ug.IdentityID = i.ID)
						AND	(os1.ObjectGuid = do.Guid)
						AND	(os1.DenyWrite > 0)
						AND	(os1.RowStatus NOT IN (0, 254))
				)
			)
		AND	(
				( EXISTS
					(
						SELECT	1
						FROM	SCore.ObjectSecurity os1
						WHERE	(os1.UserId = i.ID)
							AND	(os1.ObjectGuid = do.Guid)
							AND	(os1.CanWrite > 0)
							AND	(os1.RowStatus NOT IN (0, 254))
					)
				)
			OR	( EXISTS
					(
						SELECT	1
						FROM	SCore.ObjectSecurity os1
						JOIN	SCore.UserGroups ug ON (os1.GroupId = ug.GroupID)
						WHERE	(ug.IdentityID = i.ID)
							AND	(os1.ObjectGuid = do.Guid)
							AND	(os1.CanWrite > 0)
							AND	(os1.RowStatus NOT IN (0, 254))
					)
				)
			OR	(NOT EXISTS
					(
						SELECT	1
						FROM	SCore.ObjectSecurity hos3
						WHERE	(hos3.ObjectGuid = do.Guid)
							AND (hos3.RowStatus NOT IN (0, 254))
					)
				)
			)
	 
GO