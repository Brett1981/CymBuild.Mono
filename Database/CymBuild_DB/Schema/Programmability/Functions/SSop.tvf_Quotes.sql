SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_Quotes]')
GO


CREATE FUNCTION [SSop].[tvf_Quotes]
(
    @UserId INT
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
    q.FullNumber AS Number,
    CASE
        WHEN q.DescriptionOfWorks <> N''
            THEN LEFT(q.DescriptionOfWorks, 200)
        ELSE LEFT(q.Overview, 200)
    END AS Details,
	LatestTransitionComment.Comment,
	CONCAT(COALESCE(NULLIF(LTRIM(RTRIM(acc.Name)), ''), 'Client Not set'), ' / ', COALESCE(NULLIF(LTRIM(RTRIM(agent.Name)), ''), 'Agent Not set')) AS Account,
    uprn.FormattedAddressComma,
    qcf.QuoteStatus AS QuoteStatus,
    i.FullName AS QuotingConsultant,
    ou.Name AS OrganisationalUnitName,
    jt.Name AS JobType,
    q.Date,
    q.ExternalReference,
    acc.Name AS Client,
    ISNULL(qn.TotalNet, 0) AS TotalNet,

    CONVERT(date, ISNULL(qw.SentStatusDate, q.DateSent)) AS QuoteSentDate,

    CONVERT
    (
        date,
        CASE
            WHEN ISNULL(q.RevisionNumber, 0) > 0
                 OR q.OriginalQuoteId <> -1
                THEN ISNULL(qw.ChaseOneDate, q.ChaseDate1)
            ELSE ISNULL(qw.ChaseOneDate, ISNULL(ew.ChaseOneDate, ISNULL(q.ChaseDate1, e.ChaseDate1)))
        END
    ) AS QuoteChaseDateOne,

    CONVERT
    (
        date,
        CASE
            WHEN ISNULL(q.RevisionNumber, 0) > 0
                 OR q.OriginalQuoteId <> -1
                THEN ISNULL(qw.ChaseTwoDate, q.ChaseDate2)
            ELSE ISNULL(qw.ChaseTwoDate, ISNULL(ew.ChaseTwoDate, ISNULL(q.ChaseDate2, e.ChaseDate2)))
        END
    ) AS QuoteChaseDateTwo,
	LastStatusComment.Comment AS LastComment

FROM SSop.Quotes q
JOIN SSop.Quote_CalculatedFields qcf
    ON qcf.ID = q.ID
JOIN SSop.EnquiryServices AS es
    ON es.ID = q.EnquiryServiceID
JOIN SSop.Enquiries AS e
    ON e.ID = es.EnquiryId
JOIN SCrm.Accounts acc
    ON acc.ID = e.ClientAccountID
JOIN SCrm.Accounts agent
    ON agent.ID = e.AgentAccountId
JOIN SJob.Assets uprn
    ON uprn.ID = e.PropertyId
JOIN SCore.Identities i
    ON i.ID = q.QuotingConsultantId
JOIN SCore.OrganisationalUnits ou
    ON q.OrganisationalUnitID = ou.ID
JOIN SJob.JobTypes AS jt
    ON jt.ID = q.JobTypeId
OUTER APPLY 
(
	SELECT TOP (1)
		dob1.Comment
	FROM SCore.DataObjectTransition AS dob1
	WHERE dob1.RowStatus NOT IN (0,254)
	  AND dob1.DataObjectGuid = q.Guid
	ORDER BY dob1.ID DESC
) AS LatestTransitionComment
OUTER APPLY
(
    SELECT SUM(qi.Net) AS TotalNet
    FROM SSop.QuoteItems qi
    WHERE qi.QuoteId = q.ID
      AND qi.RowStatus NOT IN (0,254)
) AS qn
OUTER APPLY
(
    SELECT
        MAX(CASE WHEN ws.Guid = '25D5491C-42A8-4B04-B3AC-D648AF0F8032' THEN dot.DateTimeUTC END) AS SentStatusDate,
        MAX(CASE WHEN ws.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913' THEN dot.DateTimeUTC END) AS ChaseOneDate,
        MAX(CASE WHEN ws.Guid = '1F01C16B-1A73-4844-A938-FE357405FD93' THEN dot.DateTimeUTC END) AS ChaseTwoDate
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
) AS qw

OUTER APPLY
(
    SELECT
        MAX(CASE WHEN ws.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913' THEN dot.DateTimeUTC END) AS ChaseOneDate,
        MAX(CASE WHEN ws.Guid = '1F01C16B-1A73-4844-A938-FE357405FD93' THEN dot.DateTimeUTC END) AS ChaseTwoDate
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = e.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
) AS ew

OUTER APPLY
(
    SELECT
		CONCAT(CONVERT(DATE, dot.DateTimeUTC), N' - ', dot.Comment) AS Comment
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
	  AND NOT EXISTS
			(
				SELECT 1
				FROM SCore.DataObjectTransition AS dot2
				JOIN SCore.WorkflowStatus ws2
					ON ws2.ID = dot2.StatusID
				WHERE dot2.DataObjectGuid = q.Guid
				  AND dot2.RowStatus NOT IN (0,254)
				  AND ws2.RowStatus NOT IN (0,254)
				  AND dot2.ID > dot.ID
			)
) AS LastStatusComment

WHERE q.ID > 0
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
  );
GO