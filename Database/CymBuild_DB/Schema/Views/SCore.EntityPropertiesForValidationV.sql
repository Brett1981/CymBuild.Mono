SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[EntityPropertiesForValidationV]
              --WITH SCHEMABINDING
AS
SELECT	ep.Guid,
		ep.Name,
		eh.ObjectName AS Hobt,
		eh.SchemaName AS [Schema],
		N'P' AS TargetType
FROM	Score.[EntityProperties] ep
JOIN	SCore.EntityHobts eh ON ep.EntityHoBTID = eh.ID
WHERE	(ep.[RowStatus] NOT IN (0, 254))
	AND	(eh.RowStatus NOT IN (0, 254))
GO