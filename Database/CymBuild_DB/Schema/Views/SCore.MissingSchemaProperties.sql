SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE VIEW	[SCore].[MissingSchemaProperties]
AS
SELECT	p.guid, h.SchemaName, h.ObjectName, p.Name 
FROM	SCore.EntityPropertiesV p	
JOIN	SCore.EntityHobtsV h ON (h.id = p.EntityHoBTID)
WHERE	(NOT EXISTS
			(
				SELECT	1
				FROM	sys.columns c
				JOIN	sys.tables t ON (t.object_id = c.object_id)
				WHERE	(SCHEMA_NAME(t.schema_id) = h.SchemaName)
					AND	(t.name = h.ObjectName)
					AND	(c.name = p.Name)
			)				
		)

GO