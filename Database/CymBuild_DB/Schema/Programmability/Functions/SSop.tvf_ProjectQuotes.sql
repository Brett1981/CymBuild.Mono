SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_ProjectQuotes]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.Number,
		q.Overview,
		qc.FullName AS Consultant,
		qcf.QuoteStatus,
		uprn.FormattedAddressComma,
		client.Name + N' / ' + agent.Name AS ClientAgent
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SSop.Projects p ON (p.ID = q.ProjectId)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountID)
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(p.Guid = @ParentGuid)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (q.guid, @UserId) oscr
			)
		)
GO