SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_AuthorisationQuotes]
(
	@UserId INT
)
RETURNS TABLE
              --WITH SCHEMABINDING
AS RETURN	

SELECT
    q.ID,
    q.RowStatus,
    q.RowVersion,
    q.Guid,
    q.Number,
    q.ExpiryDate,
    q.DescriptionOfWorks AS DescriptionOfWork,
    client.Name + N' / ' + agent.Name AS ClientAgent,
    asset.FormattedAddressComma AS Asset,
    q.ExternalReference,
    CONVERT(date, q.[Date]) AS QuoteDate,
	I.FullName AS QuotingUser
FROM SSop.Quotes AS q
JOIN SJob.Assets AS asset
    ON asset.ID = q.UprnId
JOIN SSop.EnquiryServices AS es
    ON es.ID = q.EnquiryServiceID
JOIN SSop.Enquiries AS e
    ON e.ID = es.EnquiryId
JOIN SCrm.Accounts AS client
    ON q.ClientAccountId = client.ID
JOIN SCrm.Accounts AS agent
    ON q.AgentAccountId = agent.ID
JOIN SCore.OrganisationalUnits AS org
    ON org.ID = q.OrganisationalUnitID
JOIN SCore.Identities AS I
	ON (I.ID = q.QuotingUserId)
OUTER APPLY
(
    SELECT TOP (1)
        Name = wfs.Name,
        Guid = wfs.Guid,
        StatusId = wfs.ID,
        dot.DateTimeUTC,
        dot.ID
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS LatestWorkflowStatus
WHERE
    q.RowStatus NOT IN (0,254)
    AND q.OrganisationalUnitID IN (15,16,17,18)
    AND LatestWorkflowStatus.Guid = '9A60F983-24BA-4733-907E-C5CCE0B691CB'
    AND EXISTS
    (
        SELECT 1
        FROM SSop.EnquiryService_ExtendedInfo ese
        WHERE ese.QuoteID = q.ID
          AND ese.RowStatus NOT IN (0,254)
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
    );
GO