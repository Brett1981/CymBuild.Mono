SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[EntityQueriesV]
              --WITH SCHEMABINDING
AS
SELECT	eq.ID,
		eq.RowStatus,
		eq.RowVersion,
		eq.Guid,
		eq.Name,
		eq.Statement,
		eq.EntityTypeID,
		eq.EntityHoBTID,
		eq.IsDefaultCreate,
		eq.IsDefaultRead,
		eq.IsDefaultUpdate,
		eq.IsDefaultDelete,
		eq.IsScalarExecute,
		eq.IsDefaultValidation,
		eq.UsesProcessGuid,
		eq.IsDefaultDataPills,
		eq.IsProgressData,
		eq.IsMergeDocumentQuery,
		eq.SchemaName,
		eq.ObjectName,
		eq.IsManualStatement
FROM	Score.[EntityQueries] eq
WHERE	(eq.[RowStatus] NOT IN (0, 254))
GO