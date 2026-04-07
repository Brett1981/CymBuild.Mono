SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[EntityHobtsV]
              --WITH SCHEMABINDING
AS
SELECT	eh.ID,
		eh.RowStatus,
		eh.RowVersion,
		eh.Guid,
		eh.SchemaName,
		eh.ObjectName,
		eh.EntityTypeID,
		eh.ObjectType,
		eh.IsMainHoBT,
		eh.IsReadOnlyOffline
FROM	Score.[EntityHobts] eh
WHERE	(eh.[RowStatus] NOT IN (0, 254))
GO