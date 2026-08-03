SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SJob].[Jobs_DWETL]')
GO
PRINT (N'Create view [SJob].[Jobs_DWETL]')
GO

CREATE VIEW [SJob].[Jobs_DWETL]
AS

SELECT
    j.ID,
    j.OrganisationalUnitID,
    ou.Name AS OUName,
    j.ClientAccountID,
    j.AgentAccountID,
    j.SurveyorID,
    ISNULL(jf.InvoicedValue, 0) AS InvoicedValue,
    jt.Name AS JobType,

    -- Effective dates: legacy first, else workflow transition timestamps
    CONVERT(DATE, COALESCE(j.JobStarted, j.CreatedOn)) AS RegisteredDate,
    CONVERT(DATE, COALESCE(j.JobCompleted, wfd_completed.JobCompletedDateTimeUtc)) AS CompletedDate,

    QuotedValue.OriginalQuotedValue AS OriginalQuotedValue,
    QuotedValue.OriginalQuotedValue + ISNULL(FeeAmendment.Total, 0) AS ActualQuotedValue,

    PhysicalInspections.Cnt AS PhysicalInspections,
    TotalInspections.Cnt AS TotalInspections,
    j.Number,
    c.Name AS County,
    p.Postcode

FROM SJob.Jobs AS j

JOIN SJob.JobStatus AS js
    ON js.ID = j.ID

JOIN SJob.JobFinance AS jf
    ON jf.ID = j.ID

JOIN SCore.Identities AS i
    ON i.ID = j.SurveyorID

JOIN SJob.JobTypes AS jt
    ON jt.ID = j.JobTypeID

JOIN SJob.Assets AS p
    ON p.ID = j.UprnID

JOIN SCrm.Counties AS c
    ON c.ID = p.CountyId

JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = j.OrganisationalUnitID

-- Latest workflow status for this job, if any.
OUTER APPLY
(
    SELECT TOP (1)
        wfs.Guid AS LatestWorkflowStatusGuid,
        wfs.IsActiveStatus AS LatestIsActiveStatus
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS wfs
        ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0, 254)
      AND wfs.RowStatus NOT IN (0, 254)
      AND dot.DataObjectGuid = j.Guid
    ORDER BY
        dot.DateTimeUTC DESC,
        dot.ID DESC
) AS wf

-- Workflow date for Job Completed.
OUTER APPLY
(
    SELECT TOP (1)
        dot.DateTimeUTC AS JobCompletedDateTimeUtc
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS wfs
        ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0, 254)
      AND wfs.RowStatus NOT IN (0, 254)
      AND dot.DataObjectGuid = j.Guid
      AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516' -- Completed
    ORDER BY
        dot.DateTimeUTC DESC,
        dot.ID DESC
) AS wfd_completed

-- Legacy fallback workflow status mapping.
OUTER APPLY
(
    SELECT
        (
            SELECT TOP (1)
                wfs.Guid
            FROM SCore.WorkflowStatus AS wfs
            WHERE wfs.RowStatus NOT IN (0, 254)
              AND wfs.Guid = '1504E82F-35CA-4D6E-8C3E-E4701A68C90D' -- Not Started
            ORDER BY
                wfs.ID
        ) AS NotStartedGuid,

        (
            SELECT TOP (1)
                wfs.Guid
            FROM SCore.WorkflowStatus AS wfs
            WHERE wfs.RowStatus NOT IN (0, 254)
              AND wfs.Guid IN
              (
                  '9E0A10C7-94A0-4E25-AFB1-14240D906C12',
                  '3DAB4339-A1C0-4ABE-860A-4915A6CF94B6'
              ) -- Job Started
            ORDER BY
                wfs.ID
        ) AS StartedGuid,

        (
            SELECT TOP (1)
                wfs.Guid
            FROM SCore.WorkflowStatus AS wfs
            WHERE wfs.RowStatus NOT IN (0, 254)
              AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516' -- Completed
            ORDER BY
                wfs.ID
        ) AS CompletedGuid,

        (
            SELECT TOP (1)
                wfs.IsActiveStatus
            FROM SCore.WorkflowStatus AS wfs
            WHERE wfs.RowStatus NOT IN (0, 254)
              AND wfs.Guid = '1504E82F-35CA-4D6E-8C3E-E4701A68C90D'
            ORDER BY
                wfs.ID
        ) AS NotStartedIsActive,

        (
            SELECT TOP (1)
                wfs.IsActiveStatus
            FROM SCore.WorkflowStatus AS wfs
            WHERE wfs.RowStatus NOT IN (0, 254)
              AND wfs.Guid = 'FC9AA6A3-79DB-4533-A6A9-B831610F2BDC'
            ORDER BY
                wfs.ID
        ) AS StartedIsActive,

        (
            SELECT TOP (1)
                wfs.IsActiveStatus
            FROM SCore.WorkflowStatus AS wfs
            WHERE wfs.RowStatus NOT IN (0, 254)
              AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516'
            ORDER BY
                wfs.ID
        ) AS CompletedIsActive
) AS LegacyWf

OUTER APPLY
(
    SELECT
        CASE
            WHEN wf.LatestWorkflowStatusGuid IS NOT NULL THEN wf.LatestWorkflowStatusGuid
            WHEN j.JobCompleted IS NOT NULL THEN LegacyWf.CompletedGuid
            WHEN j.JobStarted IS NOT NULL THEN LegacyWf.StartedGuid
            ELSE LegacyWf.NotStartedGuid
        END AS EffectiveWorkflowStatusGuid,

        CASE
            WHEN wf.LatestWorkflowStatusGuid IS NOT NULL THEN wf.LatestIsActiveStatus
            WHEN j.JobCompleted IS NOT NULL THEN LegacyWf.CompletedIsActive
            WHEN j.JobStarted IS NOT NULL THEN LegacyWf.StartedIsActive
            ELSE LegacyWf.NotStartedIsActive
        END AS EffectiveIsActiveStatus
) AS EffectiveWf

OUTER APPLY
(
    SELECT
        COUNT(1) AS Cnt
    FROM SJob.Activities AS a
    JOIN SJob.ActivityStatus AS stat
        ON stat.ID = a.ActivityStatusID
    JOIN SJob.ActivityTypes AS atype
        ON atype.ID = a.ActivityTypeID
    WHERE j.ID = a.JobID
      AND stat.Name = N'Complete'
      AND atype.IsSiteVisit = 1
      AND a.RowStatus NOT IN (0, 254)
) AS PhysicalInspections

OUTER APPLY
(
    SELECT
        COUNT(1) AS Cnt
    FROM SJob.Activities AS a
    JOIN SJob.ActivityStatus AS stat
        ON stat.ID = a.ActivityStatusID
    JOIN SJob.ActivityTypes AS atype
        ON atype.ID = a.ActivityTypeID
    WHERE j.ID = a.JobID
      AND stat.Name = N'Complete'
      AND a.RowStatus NOT IN (0, 254)
) AS TotalInspections

-- Legacy fixed-column job quoted value.
-- AgreedFee is retained as the legacy Stage 0/base fee value.
-- RibaStage7Fee is now included.
OUTER APPLY
(
    SELECT
        CAST
        (
              ISNULL(j.AgreedFee, 0)
            + ISNULL(j.RibaStage1Fee, 0)
            + ISNULL(j.RibaStage2Fee, 0)
            + ISNULL(j.RibaStage3Fee, 0)
            + ISNULL(j.RibaStage4Fee, 0)
            + ISNULL(j.RibaStage5Fee, 0)
            + ISNULL(j.RibaStage6Fee, 0)
            + ISNULL(j.RibaStage7Fee, 0)
            + ISNULL(j.PreConstructionStageFee, 0)
            + ISNULL(j.ConstructionStageFee, 0)
            AS DECIMAL(19, 2)
        ) AS Total
) AS LegacyQuotedValue

-- Quote-created job total.
-- This supports the newer Fee Stage/custom RIBA stage model, because Fee Stages above 7
-- are not represented by fixed columns on SJob.Jobs.
OUTER APPLY
(
    SELECT
        CAST(SUM(ISNULL(qit.LineNet, 0)) AS DECIMAL(19, 2)) AS Total
    FROM SSop.QuoteItems AS qi
    JOIN SSop.QuoteItemTotals AS qit
        ON qit.ID = qi.ID
    WHERE qi.CreatedJobId = j.ID
      AND qi.RowStatus NOT IN (0, 254)
) AS CreatedFromQuoteItems

OUTER APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN CreatedFromQuoteItems.Total IS NOT NULL
                 AND CreatedFromQuoteItems.Total <> 0
                    THEN CreatedFromQuoteItems.Total
                ELSE LegacyQuotedValue.Total
            END
            AS DECIMAL(19, 2)
        ) AS OriginalQuotedValue
) AS QuotedValue

OUTER APPLY
(
    SELECT
        CAST
        (
            SUM
            (
                  ISNULL(fa.RibaStage0Change, 0)
                + ISNULL(fa.RibaStage1Change, 0)
                + ISNULL(fa.RibaStage2Change, 0)
                + ISNULL(fa.RibaStage3Change, 0)
                + ISNULL(fa.RibaStage4Change, 0)
                + ISNULL(fa.RibaStage5Change, 0)
                + ISNULL(fa.RibaStage6Change, 0)
                + ISNULL(fa.RibaStage7Change, 0)
                + ISNULL(fa.PreConstructionStageChange, 0)
                + ISNULL(fa.ConstructionStageChange, 0)
            )
            AS DECIMAL(19, 2)
        ) AS Total
    FROM SJob.FeeAmendment AS fa
    WHERE fa.JobID = j.ID
      AND fa.RowStatus NOT IN (0, 254)
) AS FeeAmendment

WHERE
    (
        (
            wf.LatestWorkflowStatusGuid IS NULL
            AND j.JobCancelled IS NULL
        )
        OR
        (
            wf.LatestWorkflowStatusGuid IS NOT NULL
            AND ISNULL(wf.LatestIsActiveStatus, 0) = 1
        )
    )
    AND
    (
        EXISTS
        (
            SELECT
                1
            FROM SCore.RecordHistory AS rh
            WHERE rh.RowGuid = j.Guid
              AND rh.Datetime > DATEADD(MONTH, -6, GETDATE())
              AND rh.RowStatus NOT IN (0, 254)
        )
        OR
        EXISTS
        (
            SELECT
                1
            FROM SCore.RecordHistory AS rh
            WHERE rh.Datetime > DATEADD(MONTH, -6, GETDATE())
              AND rh.RowStatus NOT IN (0, 254)
              AND EXISTS
                  (
                      SELECT
                          1
                      FROM SJob.Activities AS a
                      WHERE a.JobID = j.ID
                        AND a.Guid = rh.RowGuid
                        AND a.RowStatus NOT IN (0, 254)
                  )
        )
        OR
        EXISTS
        (
            SELECT
                1
            FROM SCore.RecordHistory AS rh
            WHERE rh.Datetime > DATEADD(MONTH, -6, GETDATE())
              AND rh.RowStatus NOT IN (0, 254)
              AND EXISTS
                  (
                      SELECT
                          1
                      FROM SFin.Transactions AS t
                      WHERE t.JobID = j.ID
                        AND t.Guid = rh.RowGuid
                        AND t.RowStatus NOT IN (0, 254)
                  )
        )
    );
GO