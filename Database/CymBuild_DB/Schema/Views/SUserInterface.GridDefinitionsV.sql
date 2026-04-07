SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SUserInterface].[GridDefinitionsV]
              --WITH SCHEMABINDING
AS
SELECT	gd.ID,
		gd.RowStatus,
		gd.RowVersion,
		gd.Guid,
		gd.Code,
		gd.PageUri,
		gd.TabName,
		gd.ShowAsTiles
FROM	SUserInterface.GridDefinitions gd
WHERE	(gd.RowStatus NOT IN (0, 254))
GO