SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_SystemSecurityObjects]
(
	@UserId INT
)
RETURNS TABLE
AS
RETURN 
SELECT	et.ID,
		et.RowStatus,
		et.Guid,
		N'Entity' ObjectType,
		olfu.Label MainObject,
		N'' SubObject,
		CASE WHEN EXISTS (SELECT 1 FROM SCore.ObjectSecurity AS os WHERE os.ObjectGuid = et.Guid AND os.RowStatus NOT IN (0, 254)) THEN 1 ELSE 0 END AS HasRestrictions
FROM	SCore.EntityTypes et
OUTER APPLY SCore.ObjectLabelForUser(et.LanguageLabelID, @UserId) AS olfu
WHERE	(et.RowStatus NOT IN (0, 254))
	AND	(et.IsMetaData = 0)
	AND	(et.ID > 0)
UNION ALL 
SELECT	et.ID,
		et.RowStatus,
		et.Guid,
		N'Entity Property' ObjectType,
		et_olfu.Label MainObject,
		ep_olfu.Label SubObject,
		CASE WHEN EXISTS (SELECT 1 FROM SCore.ObjectSecurity AS os WHERE os.ObjectGuid = ep.Guid AND os.RowStatus NOT IN (0, 254)) THEN 1 ELSE 0 END AS HasRestrictions
FROM	SCore.EntityProperties AS ep
JOIN	SCore.EntityHobts AS eh ON (eh.ID = ep.EntityHoBTID)
JOIN	SCore.EntityTypes et ON (et.ID = eh.EntityTypeID)
OUTER APPLY SCore.ObjectLabelForUser(et.LanguageLabelID, @UserId) AS et_olfu
OUTER APPLY SCore.ObjectLabelForUser(ep.LanguageLabelID, @UserId) AS ep_olfu
WHERE	(ep.RowStatus NOT IN (0, 254))
	AND	(et.IsMetaData = 0)
	AND	(et.ID > 0)
UNION ALL 
SELECT	gvd.ID,
		gvd.RowStatus,
		gvd.Guid,
		N'Grid View',
		gv_olfu.Label MainObject,
		N'' SubObject,
		CASE WHEN EXISTS (SELECT 1 FROM SCore.ObjectSecurity AS os WHERE os.ObjectGuid = gvd.Guid AND os.RowStatus NOT IN (0, 254)) THEN 1 ELSE 0 END AS HasRestrictions
FROM	SUserInterface.GridViewDefinitions AS gvd
OUTER APPLY SCore.ObjectLabelForUser(gvd.LanguageLabelId, @UserId) AS gv_olfu
WHERE	(gvd.RowStatus NOT IN (0, 254))
	AND	(NOT EXISTS
			(
				SELECT	1
				FROM	SCore.EntityTypes AS et
				WHERE	(et.IsMetaData = 0)
					AND	(et.ID = gvd.EntityTypeID)
			)
		)
UNION ALL 
SELECT	gvcd.ID,
		gvcd.RowStatus,
		gvcd.Guid,
		N'Grid View Column',
		gv_olfu.Label MainObject,
		gvcd_olfu.Label SubObject,
		CASE WHEN EXISTS (SELECT 1 FROM SCore.ObjectSecurity AS os WHERE os.ObjectGuid = gvcd.Guid AND os.RowStatus NOT IN (0, 254)) THEN 1 ELSE 0 END AS HasRestrictions
FROM	SUserInterface.GridViewColumnDefinitions AS gvcd 
JOIN	SUserInterface.GridViewDefinitions AS gvd ON (gvd.ID = gvcd.GridViewDefinitionId)
OUTER APPLY SCore.ObjectLabelForUser(gvd.LanguageLabelId, @UserId) AS gv_olfu
OUTER APPLY SCore.ObjectLabelForUser(gvcd.LanguageLabelId, @UserId) AS gvcd_olfu
WHERE	(gvd.RowStatus NOT IN (0, 254))
	AND	(NOT EXISTS
			(
				SELECT	1
				FROM	SCore.EntityTypes AS et
				WHERE	(et.IsMetaData = 0)
					AND	(et.ID = gvd.EntityTypeID)
			)
		)
GO