SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[EntityPropertyGroupsV]
             --WITH SCHEMABINDING
AS
SELECT	epg.ID,
		epg.RowStatus,
		epg.RowVersion,
		epg.Guid,
		epg.Name,
		epg.IsHidden,
		epg.SortOrder,
		epg.LanguageLabelID,
		epg.EntityTypeID,
		epg.PropertyGroupLayoutID,
		epg.IsCollapsable,
		epg.IsDefaultCollapsed,
		epg.IsDefaultCollapsed_Mobile,
		epg.ShowOnMobile
FROM	Score.[EntityPropertyGroups] epg
WHERE	(epg.[RowStatus] NOT IN (0, 254))
GO