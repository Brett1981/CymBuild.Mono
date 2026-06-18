SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SCore].[EntityDataTypesV]')
GO
CREATE VIEW [SCore].[EntityDataTypesV]
                   --WITH SCHEMABINDING
AS
SELECT	edt.ID,
		edt.RowStatus,
		edt.RowVersion,
		edt.Guid,
		edt.Name,
		edt.QuoteValue
FROM	[SCore].[EntityDataTypes] edt
WHERE	([edt].[RowStatus] NOT IN (0, 254))
GO