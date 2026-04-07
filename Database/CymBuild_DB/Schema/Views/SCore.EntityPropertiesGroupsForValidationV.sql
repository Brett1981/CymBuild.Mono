SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO









CREATE VIEW	[SCore].[EntityPropertiesGroupsForValidationV]
              --WITH SCHEMABINDING
AS
SELECT	epg.Guid,
		epg.Name,
		et.Name AS EntityType,
		N'G' AS TargetType
FROM	Score.[EntityPropertyGroups] epg
JOIN	SCore.EntityTypes et ON epg.EntityTypeID = et.ID
WHERE	(epg.[RowStatus] NOT IN (0, 254))
	AND	(et.RowStatus NOT IN (0, 254))
GO