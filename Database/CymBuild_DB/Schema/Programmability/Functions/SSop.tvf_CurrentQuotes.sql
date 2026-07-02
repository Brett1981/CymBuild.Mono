SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_CurrentQuotes]')
GO
CREATE FUNCTION [SSop].[tvf_CurrentQuotes]
(
	@UserId INT
)
RETURNS TABLE
           --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		CASE WHEN q.DescriptionOfWorks <> N'' THEN LEFT(q.DescriptionOfWorks, 200) ELSE LEFT(q.Overview, 200) END AS Details, --[CBLD-640]
		--LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + agent.Name AS Account,
		uprn.FormattedAddressComma,
		qcf.QuoteStatus,
		i.FullName AS QuotingConsultant,
		q.RevisionNumber,
		ou.Name AS Department,
		ou2.Name As BusinessUnit,
		q.ExternalReference
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SCrm.Accounts acc ON (acc.ID = q.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = q.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = q.UprnId)
JOIN	SCore.Identities i ON (i.ID = q.QuotingConsultantId)
JOIN    SCore.OrganisationalUnits ou ON q.OrganisationalUnitID = ou.ID
JOIN	SCore.OrganisationalUnits ou2 ON ou.ParentID = ou2.ID
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(
			(q.DateAccepted IS NULL)
			OR 
			(
				(q.DateAccepted IS NOT NULL)
				AND (EXISTS 
						(
							SELECT	1
							FROM	SSop.QuoteItems qi
							JOIN	SSop.QuoteSections qs ON (qs.ID = qi.QuoteSectionId)
							WHERE	(qs.QuoteID = q.ID)
								AND	(qi.RowStatus NOT IN (0, 254))
								AND	(qi.CreatedJobId < 0)
						)
					)
			)
		)
	AND	(q.DateRejected IS NULL)
	AND	(q.ExpiryDate > GETDATE())
GO