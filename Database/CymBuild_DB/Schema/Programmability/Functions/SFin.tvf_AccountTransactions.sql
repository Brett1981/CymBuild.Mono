SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_AccountTransactions] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN 
SELECT  t.ID,
        t.RowStatus,
        t.RowVersion,
        t.Guid,
        t.Number,
		t.Date,
		a.Name AS Account,
		tt.Name AS TransactionType,
		tc.RealNet AS Net,
		tc.RealVat AS Vat,
		tc.RealGross AS Gross,
		tc.RealOutstanding AS Outstanding
FROM    SFin.Transactions t
JOIN	SFin.TransactionCalculations tc ON (tc.ID = t.ID)
JOIN    SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
JOIN	SCrm.Accounts a ON (a.ID = t.AccountID)
WHERE   (t.RowStatus  NOT IN (0, 254))
	AND	(t.Id > 0)
	AND	(a.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserId) oscr
			)
		)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
GO