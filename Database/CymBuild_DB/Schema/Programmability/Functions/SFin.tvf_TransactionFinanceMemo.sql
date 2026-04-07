SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_TransactionFinanceMemo]
	(
		@UserId INT,
		@TransactionGuid UNIQUEIDENTIFIER
	)

RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN SELECT
		fm.ID,
		fm.RowStatus,
		fm.RowVersion,
		fm.Guid,
		t.Number AS TransactionNumber,
		a.Name	 AS AccountName,
		j.Number AS JobNumber,
		fm.Memo,
		CONVERT(DATE, fm.CreatedDateTimeUTC) AS CreatedDate, -- CBLD-502
		fm.CreatedByUserId, --CBLD-502
		id.FullName
FROM
		SFin.FinanceMemo AS fm
JOIN
		SFin.Transactions AS t ON (t.ID = fm.TransactionID)
JOIN
		SCrm.Accounts AS a ON (a.ID = fm.AccountID)
JOIN
		SJob.Jobs AS j ON (j.ID = fm.JobId)
JOIN
		SCore.Identities id ON (id.ID = fm.CreatedByUserId) -- CBLD-502
WHERE
		(t.Guid = @TransactionGuid)
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(fm.Guid, @UserId) oscr
		)
		)
GO