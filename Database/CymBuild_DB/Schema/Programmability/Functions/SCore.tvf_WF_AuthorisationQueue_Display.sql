SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION  [SCore].[tvf_WF_AuthorisationQueue_Display]
(
    @UserId INT = NULL
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN

SELECT
    COALESCE(e.ID, q.ID, j.ID) AS ID,
    COALESCE(e.GUID, q.GUID, j.GUID) AS [Guid],
    1 AS RowStatus,

    aq.UserId,
    aq.DataObjectGuid,
    aq.EntityTypeId,
    et.Name AS EntityTypeName,
    COALESCE(
        CONVERT(NVARCHAR(50), j.Number),
        CONVERT(NVARCHAR(50), q.Number),
        CONVERT(NVARCHAR(50), e.Number)
    ) AS [Number],

    aq.OrganisationalUnitId,
    ou.Name AS DisciplineName,

    aq.WorkflowId,

    aq.LatestWorkflowStatusGuid,
    aq.LatestWorkflowStatusName,
    aq.LatestTransitionGuid,
    aq.LatestTransitionUtc,

    aq.TargetGroupIdsCsv,
    aq.CanActionForUser,

    /* Jobs */
    j.Number AS JobNumber,
    j.JobDescription AS JobDescription,
    jt.Name AS JobTypeName,
    client.Name AS JobClientName,
    agent.Name AS JobAgentName,
    asset.FormattedAddressComma AS JobAddress,

    /* Quotes */
    q.Number AS QuoteNumber,

    /* Enquiries */
    e.Number AS EnquiryNumber,

    /* =========================
       Review / Financial Summary
       ========================= */

    -- A single “best effort” display title for grids/cards
    COALESCE(
        CONCAT(N'Job ', j.Number),
        CONCAT(N'Quote ', q.Number),
        CONCAT(N'Enquiry ', e.Number)
    ) AS DisplayRef,

    -- Common “party / address” (prefers Job, then Enquiry, then Quote if you later add)
    COALESCE(client.Name, EnqInfo.ClientName) AS DisplayClientName,
    COALESCE(agent.Name, EnqInfo.AgentName) AS DisplayAgentName,
    COALESCE(asset.FormattedAddressComma, EnqInfo.PropertyAddress) AS DisplayAddress,

    -- Enquiry: fee expectation (from Enquiry_MergeInfo)
    EnqInfo.TotalFee AS EnquiryTotalFee,

    -- Quote: agreed/net/accepted date
    QuoteSum.AgreedFee AS QuoteAgreedFee,
    QuoteSum.Net       AS QuoteNet,
    QuoteSum.DateAccepted AS QuoteDateAccepted,

    -- Job: totals (ex fee cap + inc fee cap)
    JobFeeEx.JobTotalFee_ExFeeCap       AS JobTotalFee,
    JobFeeEx.JobTotalInvoiced_ExFeeCap  AS JobTotalInvoiced,
    JobFeeEx.JobOutstanding_ExFeeCap    AS JobOutstanding,

    JobFeeInc.JobTotalFee_IncFeeCap       AS JobTotalFeeIncFeeCap,
    JobFeeInc.JobTotalInvoiced_IncFeeCap  AS JobTotalInvoicedIncFeeCap,
    JobFeeInc.JobOutstanding_IncFeeCap    AS JobOutstandingIncFeeCap

FROM SCore.tvf_WF_AuthorisationQueue(@UserId, -1) aq
JOIN SCore.EntityTypes et ON et.ID = aq.EntityTypeId
LEFT JOIN SCore.OrganisationalUnits ou ON ou.ID = aq.OrganisationalUnitId

LEFT JOIN SJob.Jobs j
    ON j.Guid = aq.DataObjectGuid AND j.RowStatus NOT IN (0,254)
LEFT JOIN SJob.JobTypes jt ON jt.ID = j.JobTypeID
LEFT JOIN SCrm.Accounts client ON client.ID = j.ClientAccountID
LEFT JOIN SCrm.Accounts agent ON agent.ID = j.AgentAccountID
LEFT JOIN SJob.Assets asset ON asset.ID = j.UprnID

LEFT JOIN SSop.Quotes q
    ON q.Guid = aq.DataObjectGuid AND q.RowStatus NOT IN (0,254)
LEFT JOIN SSop.Enquiries e
    ON e.Guid = aq.DataObjectGuid AND e.RowStatus NOT IN (0,254)

-- Enquiry summary (review friendly)
OUTER APPLY
(
    SELECT TOP (1)
        emi.ClientName,
        emi.AgentName,
        emi.PropertyAddress,
        emi.EnquiryDate,
        emi.TotalFee
    FROM SSop.Enquiry_MergeInfo emi
    WHERE emi.Guid = aq.DataObjectGuid
) EnqInfo

-- Quote summary (use aggregated row)
OUTER APPLY
(
    SELECT TOP (1)
        qjs.AgreedFee,
        qjs.Net,
        qjs.DateAccepted,
        qjs.JobType
    FROM SSop.Quote_JobsSummary qjs
    WHERE qjs.QuoteGuid = aq.DataObjectGuid
      AND qjs.QuoteItemId = -1
) QuoteSum

-- Job fee totals (ex fee cap)
OUTER APPLY
(
    SELECT TOP (1)
        jfd.Agreed   AS JobTotalFee_ExFeeCap,
        jfd.Invoiced AS JobTotalInvoiced_ExFeeCap,
        jfd.Remaining AS JobOutstanding_ExFeeCap
    FROM SJob.Job_FeeDrawdown jfd
    WHERE jfd.Guid = aq.DataObjectGuid
      AND jfd.IsTotalHighlightRow = 1
      AND jfd.StageId = -2
) JobFeeEx

-- Job fee totals (inc fee cap)
OUTER APPLY
(
    SELECT TOP (1)
        jfd.Agreed   AS JobTotalFee_IncFeeCap,
        jfd.Invoiced AS JobTotalInvoiced_IncFeeCap,
        jfd.Remaining AS JobOutstanding_IncFeeCap
    FROM SJob.Job_FeeDrawdown jfd
    WHERE jfd.Guid = aq.DataObjectGuid
      AND jfd.IsTotalHighlightRow = 1
      AND jfd.StageId = -3
) JobFeeInc
;
GO