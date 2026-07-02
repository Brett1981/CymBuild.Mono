SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_AccountQuotes]')
GO
CREATE FUNCTION [SJob].[tvf_AccountQuotes] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
         --WITH SCHEMABINDING
AS
RETURN
SELECT
		q.ID,
		q.RowStatus,
		q.RowVersion,
		q.Guid,
		q.Number,
		q.Date,
		LEFT(q.Overview, 200) AS Overview,
		i.Guid				  QuotingUserGuid,
		i.FullName			  AS QuotingUserName,
		qc.FullName			  AS QuotingConsultant,
		org1.Name AS Department,
		org2.Name AS BusinessUnit
FROM
		SSop.Quotes q
JOIN	SSop.EnquiryServices es on (es.Id = q.EnquiryServiceID)
JOIN	SSop.Enquiries e on (e.Id = es.EnquiryId)
JOIN
		SCrm.Accounts a ON ((a.ID = e.ClientAccountId)
					OR (a.ID = e.AgentAccountId)
					OR (a.ID = e.FinanceAccountId))
JOIN
		SCore.Identities i ON (q.QuotingUserId = i.ID)
JOIN
		SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
LEFT JOIN
		SCore.OrganisationalUnits AS org1 ON (q.OrganisationalUnitID = org1.ID)
LEFT JOIN 
		SCore.OrganisationalUnits AS org2 ON (org1.ParentID = org2.ID)
WHERE
		(q.RowStatus NOT IN (0, 254))
		AND (q.ID > 0)
		AND (a.Guid = @ParentGuid)
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
		)
		)
GO