SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[QuoteProducts_ETL]
    --WITH SCHEMABINDING
AS
 
SELECT
    q.ID,
    q.QuotingUserId,
    q.QuotingConsultantId,
    e.ClientAccountId,
    e.AgentAccountId,
    uprn.CountyId,
    c.Name AS County,
    SUM(qi.Net * qi.Quantity) AS Net,
    prod.Code AS ProductCode,
 
    -- Effective dates: legacy first, else workflow transition timestamps
    eff.EffectiveDateSent       AS [Date],
    eff.EffectiveDateAccepted   AS DateAccepted,
    eff.EffectiveDateRejected   AS DateRejected,
 
    ou.Name AS OrgUnit
FROM SSop.Quotes q
join    ssop.Quote_ExtendedInfo qei on q.id = qei.Id
join    ssop.Enquiries e on (e.id = qei.EnquiryID)
JOIN SSop.QuoteItems qi             ON qi.QuoteId = q.ID
JOIN SProd.Products prod            ON prod.ID = qi.ProductId
JOIN SJob.Assets uprn               ON uprn.ID = e.PropertyId
JOIN SCore.OrganisationalUnits ou   ON ou.ID = q.OrganisationalUnitID
JOIN SCrm.Counties c                ON c.ID = uprn.CountyId
 
-- Workflow date for Sent (by GUID)
OUTER APPLY
(
    SELECT TOP (1)
        dot.DateTimeUTC AS DateSentUtc
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
      AND dot.DataObjectGuid = q.Guid
      AND wfs.Guid = '25D5491C-42A8-4B04-B3AC-D648AF0F8032' -- Sent
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS wfd_sent
 
-- Workflow date for Accepted (by GUID)
OUTER APPLY
(
    SELECT TOP (1)
        dot.DateTimeUTC AS DateAcceptedUtc
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
      AND dot.DataObjectGuid = q.Guid
      AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498' -- Accepted
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS wfd_accepted
 
-- Workflow date for Rejected (by GUID(s))
OUTER APPLY
(
    SELECT TOP (1)
        dot.DateTimeUTC AS DateRejectedUtc
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
      AND dot.DataObjectGuid = q.Guid
      AND wfs.Guid IN
      (
          '0A6A71F7-B39F-4213-997E-2B3A13B6144C', -- Rejected
          '85B522AA-134C-4E6C-884A-FF7264D7DD2E'  -- Rejected (alt)
      )
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS wfd_rejected
 
OUTER APPLY
(
    SELECT
        COALESCE(q.DateSent,     wfd_sent.DateSentUtc)         AS EffectiveDateSent,
        COALESCE(q.DateAccepted, wfd_accepted.DateAcceptedUtc) AS EffectiveDateAccepted,
        COALESCE(q.DateRejected, wfd_rejected.DateRejectedUtc) AS EffectiveDateRejected
) AS eff
 
WHERE
        q.RowStatus      NOT IN (0,254)
    AND qi.RowStatus     NOT IN (0,254)
    AND prod.RowStatus   NOT IN (0,254)
    AND uprn.RowStatus   NOT IN (0,254)
    AND ou.RowStatus     NOT IN (0,254)
    AND c.RowStatus      NOT IN (0,254)
 
    -- Use effective sent date for inclusion and date window
    AND eff.EffectiveDateSent IS NOT NULL
    AND eff.EffectiveDateSent >= CONVERT(datetime, '2025-04-01', 120)
 
GROUP BY
    q.ID,
    q.QuotingUserId,
    q.QuotingConsultantId,
    e.ClientAccountId,
    e.AgentAccountId,
    uprn.CountyId,
    c.Name,
    prod.Code,
    ou.Name,
    eff.EffectiveDateSent,
    eff.EffectiveDateAccepted,
    eff.EffectiveDateRejected;

GO