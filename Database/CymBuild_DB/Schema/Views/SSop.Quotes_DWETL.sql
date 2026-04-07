SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[Quotes_DWETL]
    --WITH SCHEMABINDING
AS
SELECT
    q.ID,
    q.QuotingConsultantId,
    e.ClientAccountId,
    e.AgentAccountId,
    uprn.CountyId,
    c.Name AS County,
    ISNULL(sn.Net, 0) AS Net,

    -- Effective dates: legacy first, else workflow transition timestamps
    eff.EffectiveDateSent     AS [Date],
    eff.EffectiveDateAccepted AS DateAccepted,
    eff.EffectiveDateRejected AS DateRejected,

    ou.Name AS OrgUnit,
    q.Number,
    MAX(CASE WHEN ISNULL(jtDerived.JobTypeName, N'') <> N'' THEN jtDerived.JobTypeName ELSE ISNULL(qjs.JobType, N'') END) AS JobType,
    q.QuotingUserId
FROM SSop.Quotes q
join    ssop.Quote_ExtendedInfo qei on q.id = qei.Id
join    ssop.Enquiries e on (e.id = qei.EnquiryID)
JOIN SJob.Assets uprn
    ON uprn.ID = e.PropertyId
JOIN SCore.OrganisationalUnits ou
    ON ou.ID = q.OrganisationalUnitID
JOIN SCrm.Counties c
    ON c.ID = uprn.CountyId

-- Net: aggregate section totals WITHOUT joining to items
OUTER APPLY
(
    SELECT
        SUM(qst.Net) AS Net
    FROM SSop.QuoteSections qs
    JOIN SSop.QuoteSectionTotals qst
        ON qst.ID = qs.ID
    WHERE qs.QuoteId = q.ID
      AND qs.RowStatus NOT IN (0,254)
) sn

-- JobType: look for any created job types on items for this quote
OUTER APPLY
(
    SELECT
        MAX(jt.Name) AS JobTypeName
    FROM SSop.QuoteSections qs2
    JOIN SSop.QuoteItems qi
        ON qi.QuoteSectionId = qs2.ID
    JOIN SJob.Jobs j
        ON j.ID = qi.CreatedJobId
    JOIN SJob.JobTypes jt
        ON jt.ID = j.JobTypeID
    WHERE qs2.QuoteId = q.ID
      AND qs2.RowStatus NOT IN (0,254)
      AND qi.RowStatus  NOT IN (0,254)
      AND j.RowStatus   NOT IN (0,254)
      AND jt.RowStatus  NOT IN (0,254)
) jtDerived

LEFT JOIN SSop.Quote_JobsSummary qjs
    ON qjs.QuoteGuid = q.Guid

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
    AND uprn.RowStatus NOT IN (0,254)
   AND ou.RowStatus   NOT IN (0,254)
   AND c.RowStatus    NOT IN (0,254)

    -- Use effective sent date for inclusion
    AND eff.EffectiveDateSent IS NOT NULL

GROUP BY
    q.ID,
    q.Number,
    q.QuotingUserId,
    q.QuotingConsultantId,
    e.ClientAccountId,
    e.AgentAccountId,
    uprn.CountyId,
    c.Name,
    ou.Name,
    sn.Net,
    eff.EffectiveDateSent,
    eff.EffectiveDateAccepted,
    eff.EffectiveDateRejected
GO