SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_AccountTurnover] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN
SELECT	TransactionYear, 
		trn_pvt.Guid,
		trn_pvt.RowStatus,
		trn_pvt.ID,
		ISNULL([1], 0) AS Jan,
		ISNULL([2], 0) AS Feb,
		ISNULL([3], 0) AS Mar,
		ISNULL([4], 0) AS Apr,
		ISNULL([5], 0) AS May,
		ISNULL([6], 0) AS Jun,
		ISNULL([7], 0) AS Jul,
		ISNULL([8], 0) AS Aug,
		ISNULL([9], 0) AS Sep,
		ISNULL([10], 0) AS Oct,
		ISNULL([11], 0) AS Nov,
		ISNULL([12], 0) AS Dec
FROM	
(
	SELECT  DATEPART(YEAR, t.Date) AS TransactionYear,
			DATEPART(MONTH, t.Date) AS TransactionMonth,
			a.Guid,
			a.RowStatus,
			a.ID,
			tc.RealGross AS Gross
	FROM    SFin.Transactions t
	JOIN	SFin.TransactionCalculations tc ON (tc.ID = t.ID)
	JOIN    SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
	JOIN	SCrm.Accounts a ON (a.ID = t.AccountID)
	WHERE   (t.RowStatus  NOT IN (0, 254))
		AND	(t.Id > 0)
		AND	(tt.IsBank = 0)
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
) AS trn
PIVOT
(
	SUM(Gross)

FOR  TransactionMonth
IN ([1], [2], [3],[4], [5], [6], [7], [8], [9], [10], [11], [12])) AS trn_pvt
GO