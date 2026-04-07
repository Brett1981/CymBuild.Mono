SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[EntityQueryParametersV]
              --WITH SCHEMABINDING
AS
SELECT	eqp.ID,
		eqp.RowStatus,
		eqp.RowVersion,
		eqp.Guid,
		eqp.Name,
		eqp.EntityQueryID,
		eqp.EntityDataTypeID,
		eqp.MappedEntityPropertyID,
		eqp.DefaultValue,
		eqp.IsInput,
		eqp.IsOutput,
		eqp.IsReturnColumn
FROM	[SCore].[EntityQueryParameters] eqp
WHERE	([eqp].[RowStatus] NOT IN (0, 254))
GO