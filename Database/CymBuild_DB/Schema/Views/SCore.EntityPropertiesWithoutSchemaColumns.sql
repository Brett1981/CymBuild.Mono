SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[EntityPropertiesWithoutSchemaColumns]
AS
SELECT	ep.ID,
		eh.SchemaName,
		eh.ObjectName,
		ep.Name
FROM	SCore.EntityProperties ep 
JOIN	[SCore].[EntityHobts] eh ON (eh.ID = ep.EntityHoBTID)
WHERE	(NOT EXISTS
			(
				SELECT	1
				FROM	sys.objects o 
				JOIN	sys.columns c ON (c.object_id = o.object_id)
				WHERE	(SCHEMA_NAME(o.schema_id) = eh.SchemaName)
					AND	(o.name = eh.ObjectName)
					AND	(c.name = ep.Name)
			)
		)
GO