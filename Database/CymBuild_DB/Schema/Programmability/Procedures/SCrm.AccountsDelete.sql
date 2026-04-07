SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SCrm].[AccountsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	a
	SET		RowStatus = 254
	FROM	SCrm.Accounts a 
	WHERE	(a.Guid = @Guid)
		AND (NOT EXISTS 
				(
					SELECT	1
					FROM	SSop.Enquiries e 
					WHERE	(e.RowStatus NOT IN (0,254))
						AND	(
								(a.Id = e.AgentAccountId)
							OR	(a.Id = e.ClientAccountId)
							)
				)
			)
		AND (NOT EXISTS 
				(
					SELECT	1
					FROM	SSop.Quotes q
					WHERE	(q.RowStatus NOT IN (0,254))
						AND	(
								(a.Id = q.AgentAccountId)
							OR	(a.Id = q.ClientAccountId)
							)
				)
			)
		AND (NOT EXISTS 
				(
					SELECT	1
					FROM	SJob.Jobs j
					WHERE	(j.RowStatus NOT IN (0,254))
						AND	(
								(a.Id = j.AgentAccountId)
							OR	(a.Id = j.ClientAccountId)
							)
				)
			)

END;

GO