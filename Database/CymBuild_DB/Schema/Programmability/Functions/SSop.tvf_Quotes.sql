SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_Quotes]
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
        q.FullNumber AS Number,
        CASE 
            WHEN q.DescriptionOfWorks <> N'' 
                THEN LEFT(q.DescriptionOfWorks, 200) 
                ELSE LEFT(q.Overview, 200) 
        END AS Details,
        acc.Name + N' / ' + agent.Name AS Account,
        uprn.FormattedAddressComma,
        qcf.QuoteStatus AS QuoteStatus,
        i.FullName AS QuotingConsultant,
        ou.Name AS OrganisationalUnitName,
        jt.Name AS JobType,
        q.Date,
        q.ExternalReference,
        acc.Name AS Client,
        ISNULL(qn.TotalNet, 0) AS TotalNet,
        -- [Sent Date]
        CONVERT(date, ISNULL(qa.SentStatusDate, q.DateSent)) AS QuoteSentDate,
        -- [Chase Date 1]
        CONVERT(date, ISNULL(ea.ChaseOneDate, e.ChaseDate1)) AS QuoteChaseDateOne,
        -- [Chase Date 2]
        CONVERT(date, ISNULL(ea.ChaseTwoDate, e.ChaseDate2)) AS QuoteChaseDateTwo
FROM    SSop.Quotes q
JOIN    SSop.Quote_CalculatedFields qcf 
        ON qcf.ID = q.ID
JOIN    SSop.EnquiryServices AS es 
        ON es.ID = q.EnquiryServiceID
JOIN    SSop.Enquiries AS e 
        ON e.ID = es.EnquiryId
JOIN    SCrm.Accounts acc 
        ON acc.ID = e.ClientAccountID
JOIN    SCrm.Accounts agent 
        ON agent.ID = e.AgentAccountId
JOIN    SJob.Assets uprn 
        ON uprn.ID = e.PropertyId
JOIN    SCore.Identities i 
        ON i.ID = q.QuotingConsultantId
JOIN    SCore.OrganisationalUnits ou 
        ON q.OrganisationalUnitID = ou.ID
JOIN    SJob.JobTypes AS jt 
        ON jt.ID = es.JobTypeId
-- Pre-aggregated quote total so workflow rows can't multiply it
OUTER APPLY (
    SELECT 
        SUM(qi.Net) AS TotalNet
    FROM SSop.QuoteItems qi
    WHERE qi.QuoteId = q.ID
) AS qn
-- Quote workflow: Sent date (by status GUID)
OUTER APPLY (
    SELECT 
        MAX(dot.DateTimeUTC) AS SentStatusDate
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus ws ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND ws.Guid = '25D5491C-42A8-4B04-B3AC-D648AF0F8032'-- SentStatus
) AS qa
-- Enquiry workflow: Chase 1 and Chase 2 (by status GUIDs)
OUTER APPLY (
    SELECT  
        MAX(CASE 
                WHEN ws.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913' -- ChaseOneStatus
                    THEN dot.DateTimeUTC 
                ELSE NULL
            END) AS ChaseOneDate,
        MAX(CASE 
                WHEN ws.Guid = '1F01C16B-1A73-4844-A938-FE357405FD93'  -- ChaseTwoStatus
                    THEN dot.DateTimeUTC 
                ELSE NULL
            END) AS ChaseTwoDate
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus ws ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = e.Guid
) AS ea
WHERE  q.ID > 0
    AND EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
        );
GO