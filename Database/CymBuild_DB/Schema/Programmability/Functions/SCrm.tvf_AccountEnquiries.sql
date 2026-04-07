SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountEnquiries]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN
SELECT
		e.ID,
		e.RowStatus,
		e.RowVersion,
		e.Guid,
		e.Number,
		e.DescriptionOfWorks,
		UPRN.FormattedAddressComma,
		e.ExternalReference,
		CASE
				WHEN e.ClientAccountId < 0 THEN
					e.ClientName
				ELSE
				client.Name
		END + N' / ' +
					  CASE
							  WHEN e.AgentAccountId < 0 THEN
								  e.AgentName
							  ELSE
							  agent.Name
					  END AS ClientAgent
FROM
		SSop.Enquiries e
JOIN
		SJob.Assets uprn ON (UPRN.ID = e.PropertyId)
JOIN
		SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN
		SCrm.Accounts agent ON (agent.ID = e.AgentAccountID)
WHERE
		(e.RowStatus NOT IN (0, 254))
		AND (   (client.Guid = @ParentGuid)
				OR (agent.Guid = @ParentGuid))
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
		)
		)
GO