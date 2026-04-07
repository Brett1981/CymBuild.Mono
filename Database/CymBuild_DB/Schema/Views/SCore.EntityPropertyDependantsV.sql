SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[EntityPropertyDependantsV]
             --WITH SCHEMABINDING
AS
SELECT	epd.ID,
		epd.RowStatus,
		epd.RowVersion,
		epd.Guid,
		ep.Guid AS ParentPropertyGuid,
		dep.Name AS PropertyName
FROM	SCore.[EntityPropertyDependants] epd
JOIN	SCore.EntityProperties ep ON (ep.ID = epd.ParentEntityPropertyID)
JOIN	SCore.EntityProperties dep ON (dep.ID = epd.DependantPropertyID)
WHERE	(epd.[RowStatus] NOT IN (0, 254))
GO