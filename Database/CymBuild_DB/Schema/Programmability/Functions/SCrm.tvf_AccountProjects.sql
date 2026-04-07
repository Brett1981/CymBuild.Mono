SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SCrm].[tvf_AccountProjects]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN
SELECT
		p.ID,
		p.RowStatus,
		p.RowVersion,
		p.Guid,
		p.Number,
		p.ProjectDescription
FROM
		SSop.Projects AS p
JOIN
		SJob.Jobs AS j ON (p.ID = j.ProjectId)

JOIN
		SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN
		SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)

JOIN
		SCrm.Accounts financeAccount ON (financeAccount.ID = j.FinanceAccountID)
WHERE
		(p.RowStatus NOT IN (0, 254))
		AND (j.RowStatus NOT IN (0,254))
		AND (   (client.Guid = @ParentGuid)
				OR (agent.Guid = @ParentGuid)
				OR (financeAccount.Guid = @ParentGuid))
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
		)
		)
GO