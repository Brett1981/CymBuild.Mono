SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_JobFinanceMemo]
	(
		@UserId INT,
		@JobGuid UNIQUEIDENTIFIER
	)

RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN SELECT		fm.ID,
					fm.RowStatus,
					fm.RowVersion,
					fm.Guid,
					t.Number AS TransactionNumber,
					a.Name AS AccountName,
					j.Number AS JobNumber,
					fm.Memo,
					fm.CreatedDateTimeUTC,
					fm.CreatedByUserId
	   FROM			SFin.FinanceMemo			  AS fm
	   JOIN			SFin.Transactions			  AS t ON (t.ID = fm.TransactionID)
	   JOIN			SCrm.Accounts				  AS a ON (a.ID = fm.AccountID)
	   JOIN			SJob.Jobs					  AS j ON (j.ID = fm.JobID)
	   WHERE		(fm.RowStatus NOT IN (0, 254))
				AND	(j.RowStatus NOT IN (0, 254))
				AND	(a.RowStatus NOT IN (0, 254))
				AND	(t.RowStatus NOT IN (0, 254))
				AND	(
						(
							(j.Guid = @JobGuid) 
						AND	(fm.JobID > 0)
						AND (j.RowStatus NOT IN (0, 254))
						)
					OR	(EXISTS	
							(
								SELECT	1
								FROM	SJob.Jobs tj
								WHERE	(tj.Id = t.JobID)
									AND (tj.Guid = @JobGuid) 
									AND (tj.RowStatus NOT IN (0, 254))
									AND	(fm.JobID > 0)
							)
						)
					OR	(EXISTS	
							(
								SELECT	1
								FROM	SJob.Jobs jfa
								WHERE	(jfa.FinanceAccountID = a.ID)
									AND (jfa.Guid = @JobGuid) 
									AND (jfa.RowStatus NOT IN (0, 254))
									AND	(jfa.FinanceAccountID > 0)
							)
						)
					)
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(fm.Guid, @UserId) oscr
			)
		)

GO