SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_AssetEnquiries]')
GO
CREATE FUNCTION [SJob].[tvf_AssetEnquiries]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		e.Number,
		e.DescriptionOfWorks,
		e.ExternalReference,
		CASE WHEN e.ClientAccountId < 0 THEN e.ClientName ELSE client.Name END  + N' / ' + CASE WHEN e.AgentAccountId < 0 THEN e.AgentName ELSE  agent.Name END AS ClientAgent,
		ou.Name AS Department,
		ou2.Name AS BusinessUnit
FROM    SSop.Enquiries e 
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountID)
LEFT JOIN SCore.OrganisationalUnits AS ou ON (e.OrganisationalUnitID = ou.ID)
LEFT JOIN SCore.OrganisationalUnits AS ou2 ON (ou.ParentID = ou2.ID)
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(uprn.Guid = @ParentGuid)
	AND	(EXISTS
			(					
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)
GO