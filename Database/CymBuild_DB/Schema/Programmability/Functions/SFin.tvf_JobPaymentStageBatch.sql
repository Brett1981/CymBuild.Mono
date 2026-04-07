SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SFin].[tvf_JobPaymentStageBatch]
(
	@UserId int
)
RETURNS TABLE
AS 
Return 
SELECT	jps.ID,
		jps.RowStatus,
		jps.RowVersion,
		jps.Guid,
		jps.StagedDate,
		jps.Value,
		j.Number as JobNumber, 
		fa.Name as FinanceAccount
FROM	SJob.JobPaymentStages jps
JOIN	SJob.Jobs j on (j.Id = jps.JobId)
JOIN	SCrm.Accounts fa on (fa.Id = j.FinanceAccountID)
WHERE	(jps.RowStatus not in (0, 254))
	AND	(
			(jps.AfterStageId < 0)
			OR (jps.AfterStageId >= j.CurrentRibaStageId)
		)
	AND	(jps.StagedDate <= GETUTCDATE())
	AND	(NOT EXISTS
			(
				SELECT	1
				FROM	SFin.TransactionDetails td
				WHERE	(td.JobPaymentStageId = jps.ID)
					AND	(td.RowStatus NOT IN (0, 254))
			)
		)
	AND	(NOT EXISTS	
			(
				SELECT	1
				FROM	SJob.JobPaymentStages jps1
				WHERE	(jps1.ID <> jps.ID)
					AND	(jps1.RowStatus NOT IN (0, 254))
					AND	(jps1.AfterStageId < jps.AfterStageId)
					AND	(jps1.StagedDate < jps.StagedDate)
					AND	(NOT EXISTS
								(
									SELECT
											1
									FROM
											SFin.TransactionDetails td1
									WHERE
											(td1.JobPaymentStageId = jps1.ID)
											AND (td1.RowStatus NOT IN (0, 254))
								)
							)
			)
		)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
GO