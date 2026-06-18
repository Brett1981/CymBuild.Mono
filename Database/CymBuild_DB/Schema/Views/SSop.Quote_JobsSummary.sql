SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SSop].[Quote_JobsSummary]')
GO

CREATE VIEW [SSop].[Quote_JobsSummary]
AS
SELECT
    MIN(qi.ID) AS ID,
    q.RowStatus,
    q.Guid AS QuoteGuid,
    q.Overview,
    q.IsSubjectToNDA,
    SUM(qit.LineNet) AS Net,

    SUM(CASE WHEN rs.Number = 0 THEN qit.LineNet ELSE 0 END) AS RibaStage0Fee,
    SUM(CASE WHEN rs.Number = 1 THEN qit.LineNet ELSE 0 END) AS RibaStage1Fee,
    SUM(CASE WHEN rs.Number = 2 THEN qit.LineNet ELSE 0 END) AS RibaStage2Fee,
    SUM(CASE WHEN rs.Number = 3 THEN qit.LineNet ELSE 0 END) AS RibaStage3Fee,
    SUM(CASE WHEN rs.Number = 4 THEN qit.LineNet ELSE 0 END) AS RibaStage4Fee,
    SUM(CASE WHEN rs.Number = 5 THEN qit.LineNet ELSE 0 END) AS RibaStage5Fee,
    SUM(CASE WHEN rs.Number = 6 THEN qit.LineNet ELSE 0 END) AS RibaStage6Fee,
    SUM(CASE WHEN rs.Number = 7 THEN qit.LineNet ELSE 0 END) AS RibaStage7Fee,
    SUM(CASE WHEN rs.Number = 99 THEN qit.LineNet ELSE 0 END) AS PreConstructionStageFee,
    SUM(CASE WHEN rs.Number = 999 THEN qit.LineNet ELSE 0 END) AS ConstructionStageFee,

    ou.Guid AS OrganisationalUnitGuid,
    quoteJobType.Guid AS JobTypeGuid,
    cr.Guid AS ContractGuid,
    '00000000-0000-0000-0000-000000000000' AS IdentityGuid,
    -1 AS QuoteItemId,
    q.ExternalReference,
    SUM(qit.LineNet) AS AgreedFee,
    quoteJobType.Name AS JobType,

    (
        SELECT MAX(dot.DateTimeUTC)
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus AS wfs
            ON wfs.ID = dot.StatusID
        WHERE dot.DataObjectGuid = q.Guid
          AND dot.RowStatus NOT IN (0,254)
          AND wfs.RowStatus NOT IN (0,254)
          AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498'
    ) AS DateAccepted,

    q.FeeCap,
    ISNULL(crs.Guid, '00000000-0000-0000-0000-000000000000') AS CurrentRibaStageGuid,
    ISNULL(ars.Guid, '00000000-0000-0000-0000-000000000000') AS AppointedRibaStageGuid,
    q.ValueOfWork,
    acr.Guid AS AgentContractGuid
FROM SSop.QuoteItems AS qi
JOIN SSop.QuoteItemTotals AS qit
    ON qit.ID = qi.ID
JOIN SJob.RibaStages AS rs
    ON rs.ID = qi.ProvideAtStageID
JOIN SProd.Products AS p2
    ON p2.ID = qi.ProductId
JOIN SJob.JobTypes AS productJobType
    ON productJobType.ID = p2.CreatedJobType
JOIN SSop.Quotes AS q
    ON q.ID = qi.QuoteId
JOIN SJob.JobTypes AS quoteJobType
    ON quoteJobType.ID = q.JobTypeId
   AND quoteJobType.RowStatus NOT IN (0,254)
JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = q.OrganisationalUnitID
JOIN SSop.Contracts AS cr
    ON cr.ID = q.ContractID
JOIN SSop.Contracts AS acr
    ON acr.ID = q.AgentContractID
JOIN SSop.EnquiryServices AS es
    ON es.ID = q.EnquiryServiceID
JOIN SSop.Enquiries AS e
    ON e.ID = es.EnquiryId
JOIN SJob.RibaStages AS crs
    ON crs.ID = e.CurrentProjectRibaStageID
JOIN SJob.RibaStages AS ars
    ON ars.ID = q.AppointmentFromRibaStageId
WHERE qi.RowStatus NOT IN (0,254)
  AND qi.Quantity > 0
  AND qi.CreatedJobId < 0
  AND qi.DoNotConsolidateJob = 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM SProd.Products AS prod2
      WHERE prod2.NeverConsolidate = 1
        AND prod2.ID = qi.ProductId
  )
GROUP BY
    q.RowStatus,
    q.Guid,
    q.Overview,
    q.IsSubjectToNDA,
    ou.Guid,
    quoteJobType.Guid,
    quoteJobType.Name,
    cr.Guid,
    q.ExternalReference,
    q.FeeCap,
    crs.Guid,
    ars.Guid,
    q.ValueOfWork,
    acr.Guid

UNION ALL

SELECT
    qi.ID AS ID,
    q.RowStatus,
    q.Guid AS QuoteGuid,
    q.Overview,
    q.IsSubjectToNDA,
    qit.LineNet AS Net,

    CASE WHEN rs.Number = 0 THEN qit.LineNet ELSE 0 END AS RibaStage0Fee,
    CASE WHEN rs.Number = 1 THEN qit.LineNet ELSE 0 END AS RibaStage1Fee,
    CASE WHEN rs.Number = 2 THEN qit.LineNet ELSE 0 END AS RibaStage2Fee,
    CASE WHEN rs.Number = 3 THEN qit.LineNet ELSE 0 END AS RibaStage3Fee,
    CASE WHEN rs.Number = 4 THEN qit.LineNet ELSE 0 END AS RibaStage4Fee,
    CASE WHEN rs.Number = 5 THEN qit.LineNet ELSE 0 END AS RibaStage5Fee,
    CASE WHEN rs.Number = 6 THEN qit.LineNet ELSE 0 END AS RibaStage6Fee,
    CASE WHEN rs.Number = 7 THEN qit.LineNet ELSE 0 END AS RibaStage7Fee,
    CASE WHEN rs.Number = 99 THEN qit.LineNet ELSE 0 END AS PreConstructionStageFee,
    CASE WHEN rs.Number = 999 THEN qit.LineNet ELSE 0 END AS ConstructionStageFee,

    ou.Guid AS OrganisationalUnitGuid,
    quoteJobType.Guid AS JobTypeGuid,
    cr.Guid AS ContractGuid,
    '00000000-0000-0000-0000-000000000000' AS IdentityGuid,
    qi.ID AS QuoteItemId,
    q.ExternalReference,
    qi.Net AS AgreedFee,
    quoteJobType.Name AS JobType,

    (
        SELECT MAX(dot.DateTimeUTC)
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus AS wfs
            ON wfs.ID = dot.StatusID
        WHERE dot.DataObjectGuid = q.Guid
          AND dot.RowStatus NOT IN (0,254)
          AND wfs.RowStatus NOT IN (0,254)
          AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498'
    ) AS DateAccepted,

    q.FeeCap,
    ISNULL(crs.Guid, '00000000-0000-0000-0000-000000000000') AS CurrentRibaStageGuid,
    ISNULL(ars.Guid, '00000000-0000-0000-0000-000000000000') AS AppointedRibaStageGuid,
    q.ValueOfWork,
    acr.Guid AS AgentContractGuid
FROM SSop.QuoteItems AS qi
JOIN SSop.QuoteItemTotals AS qit
    ON qit.ID = qi.ID
JOIN SJob.RibaStages AS rs
    ON rs.ID = qi.ProvideAtStageID
JOIN SSop.Quotes AS q
    ON q.ID = qi.QuoteId
JOIN SJob.JobTypes AS quoteJobType
    ON quoteJobType.ID = q.JobTypeId
   AND quoteJobType.RowStatus NOT IN (0,254)
JOIN SProd.Products AS prod
    ON prod.ID = qi.ProductId
JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = q.OrganisationalUnitID
JOIN SSop.Contracts AS cr
    ON cr.ID = q.ContractID
JOIN SSop.Contracts AS acr
    ON acr.ID = q.AgentContractID
JOIN SSop.EnquiryServices AS es
    ON es.ID = q.EnquiryServiceID
JOIN SSop.Enquiries AS e
    ON e.ID = es.EnquiryId
JOIN SJob.RibaStages AS crs
    ON crs.ID = e.CurrentProjectRibaStageID
JOIN SJob.RibaStages AS ars
    ON ars.ID = q.AppointmentFromRibaStageId
WHERE qi.RowStatus NOT IN (0,254)
  AND qi.Quantity > 0
  AND qi.CreatedJobId < 0
  AND
  (
      prod.NeverConsolidate = 1
      OR qi.DoNotConsolidateJob = 1
  );
GO