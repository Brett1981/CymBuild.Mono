SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_ProjectEnquiries]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT	e.ID,
				e.RowStatus,
				e.RowVersion,
				e.Guid,
				e.Number,
				e.DescriptionOfWorks,
				uprn.FormattedAddressComma,
				e.ExternalReference,
				CASE
					WHEN e.ClientAccountId < 0 THEN e.ClientName
					ELSE client.Name
				END + N' / ' + CASE
								   WHEN e.AgentAccountId < 0 THEN e.AgentName
								   ELSE agent.Name
							   END AS ClientAgent
	   FROM		SSop.Enquiries						 AS e
	   JOIN		SJob.Assets						 AS uprn ON (uprn.ID	 = e.PropertyId)
	   JOIN		SSop.Projects						 AS p ON (p.ID			 = e.ProjectId)
	   JOIN		SCrm.Accounts						 AS client ON (client.ID = e.ClientAccountId)
	   JOIN		SCrm.Accounts						 AS agent ON (agent.ID	 = e.AgentAccountId)
	   WHERE	(e.RowStatus NOT IN (0, 254))
			AND (p.Guid = @ParentGuid)
			AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (e.guid, @UserId) oscr
			)
		)
GO