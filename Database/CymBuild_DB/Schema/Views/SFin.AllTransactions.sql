SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SFin].[AllTransactions]')
GO
CREATE VIEW [SFin].[AllTransactions]
	        --WITH SCHEMABINDING
AS
SELECT	t.ID,
		t.RowStatus,
		t.RowVersion,
		t.Guid,
		(CONVERT(NVARCHAR(200), t.Number) + N' ' + tt.Name + N' ' + CONVERT(NVARCHAR(200), t.Date)) AS Name
FROM	SFin.Transactions t
JOIN	SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
WHERE	(t.ID > 0)
GO