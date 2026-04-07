SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[Jobs_DWETL]

AS
 
SELECT  j.ID,

        j.OrganisationalUnitID,

        ou.Name AS OUName,

        j.ClientAccountID,

        j.AgentAccountID,

        j.SurveyorID,

        ISNULL(jf.InvoicedValue, 0) AS InvoicedValue,

        jt.Name AS JobType,
 
        -- Effective dates: legacy first, else workflow transition timestamps

        CONVERT(DATE, COALESCE(j.JobStarted,   j.CreatedOn))   AS RegisteredDate,

        CONVERT(DATE, COALESCE(j.JobCompleted, wfd_completed.JobCompletedDateTimeUtc)) AS CompletedDate,
 
        j.AgreedFee + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.ConstructionStageFee + j.PreConstructionStageFee AS OriginalQuotedValue,

        j.AgreedFee + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.ConstructionStageFee + j.PreConstructionStageFee + ISNULL(FeeAmendment.Total, 0) AS ActualQuotedValue,
 
        PhysicalInspections.Cnt AS PhysicalInspections,

        TotalInspections.Cnt AS TotalInspections,

        j.Number,

        c.Name AS County,

        p.Postcode

FROM    SJob.Jobs j

JOIN    SJob.JobStatus js ON (js.ID = j.ID)

JOIN    SJob.JobFinance jf ON (jf.ID = j.ID)

JOIN    SCore.Identities i ON (i.ID = j.SurveyorID)

JOIN    SJob.JobTypes jt ON (jt.ID = j.JobTypeID)

JOIN    SJob.Assets AS p ON (p.ID = j.UprnID)

JOIN    SCrm.Counties AS c ON (c.ID = p.CountyId)

JOIN    SCore.OrganisationalUnits AS ou ON (ou.ID = j.OrganisationalUnitID)
 
-- Latest workflow status for this job (if any) - rowstatus safe

OUTER APPLY

(

    SELECT TOP (1)

        wfs.Guid AS LatestWorkflowStatusGuid,

        wfs.IsActiveStatus AS LatestIsActiveStatus

    FROM SCore.DataObjectTransition dot

    JOIN SCore.WorkflowStatus wfs ON (wfs.ID = dot.StatusID)

    WHERE (dot.RowStatus NOT IN (0, 254))

      AND (wfs.RowStatus NOT IN (0, 254))

      AND (dot.DataObjectGuid = j.Guid)

    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC

) AS wf
 
 
-- Workflow date for Job Completed (by GUID)

OUTER APPLY

(

    SELECT TOP (1)

        dot.DateTimeUTC AS JobCompletedDateTimeUtc

    FROM SCore.DataObjectTransition dot

    JOIN SCore.WorkflowStatus wfs ON (wfs.ID = dot.StatusID)

    WHERE dot.RowStatus NOT IN (0,254)

      AND wfs.RowStatus NOT IN (0,254)

      AND dot.DataObjectGuid = j.Guid

      AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516'  -- Completed

    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC

) AS wfd_completed
 
-- keep our legacy fallback status mapping if desired (GUIDs pulled once)

OUTER APPLY

(

    SELECT

        (SELECT TOP (1) wfs.Guid

         FROM SCore.WorkflowStatus wfs

         WHERE wfs.RowStatus NOT IN (0,254)

           AND wfs.Guid = '1504E82F-35CA-4D6E-8C3E-E4701A68C90D' -- Not Started (if we want this)

         ORDER BY wfs.ID) AS NotStartedGuid,
 
        (SELECT TOP (1) wfs.Guid

         FROM SCore.WorkflowStatus wfs

         WHERE wfs.RowStatus NOT IN (0,254)

           AND wfs.Guid IN ('9E0A10C7-94A0-4E25-AFB1-14240D906C12', '3DAB4339-A1C0-4ABE-860A-4915A6CF94B6') -- Job Started (New Transition)

         ORDER BY wfs.ID) AS StartedGuid,
 
        (SELECT TOP (1) wfs.Guid

         FROM SCore.WorkflowStatus wfs

         WHERE wfs.RowStatus NOT IN (0,254)

           AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516' -- Completed

         ORDER BY wfs.ID) AS CompletedGuid,
 
        (SELECT TOP (1) wfs.IsActiveStatus

         FROM SCore.WorkflowStatus wfs

         WHERE wfs.RowStatus NOT IN (0,254)

           AND wfs.Guid = '1504E82F-35CA-4D6E-8C3E-E4701A68C90D'

         ORDER BY wfs.ID) AS NotStartedIsActive,
 
        (SELECT TOP (1) wfs.IsActiveStatus

         FROM SCore.WorkflowStatus wfs

         WHERE wfs.RowStatus NOT IN (0,254)

           AND wfs.Guid = 'FC9AA6A3-79DB-4533-A6A9-B831610F2BDC'

         ORDER BY wfs.ID) AS StartedIsActive,
 
        (SELECT TOP (1) wfs.IsActiveStatus

         FROM SCore.WorkflowStatus wfs

         WHERE wfs.RowStatus NOT IN (0,254)

           AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516'

         ORDER BY wfs.ID) AS CompletedIsActive

) AS LegacyWf
 
OUTER APPLY

(

    SELECT

        CASE

            WHEN wf.LatestWorkflowStatusGuid IS NOT NULL THEN wf.LatestWorkflowStatusGuid

            WHEN j.JobCompleted IS NOT NULL THEN LegacyWf.CompletedGuid

            WHEN j.JobStarted   IS NOT NULL THEN LegacyWf.StartedGuid

            ELSE LegacyWf.NotStartedGuid

        END AS EffectiveWorkflowStatusGuid,
 
        CASE

            WHEN wf.LatestWorkflowStatusGuid IS NOT NULL THEN wf.LatestIsActiveStatus

            WHEN j.JobCompleted IS NOT NULL THEN LegacyWf.CompletedIsActive

            WHEN j.JobStarted   IS NOT NULL THEN LegacyWf.StartedIsActive

            ELSE LegacyWf.NotStartedIsActive

        END AS EffectiveIsActiveStatus

) AS EffectiveWf
 
OUTER APPLY

(

    SELECT COUNT(1) AS Cnt

    FROM SJob.Activities a

    JOIN SJob.ActivityStatus stat ON (stat.ID = a.ActivityStatusID)

    JOIN SJob.ActivityTypes atype ON (atype.ID = a.ActivityTypeID)

    WHERE (j.ID = a.JobID)

      AND (stat.Name = N'Complete')

      AND (atype.IsSiteVisit = 1)

      AND (a.RowStatus NOT IN (0, 254))

) AS PhysicalInspections
 
OUTER APPLY

(

    SELECT COUNT(1) AS Cnt

    FROM SJob.Activities a

    JOIN SJob.ActivityStatus stat ON (stat.ID = a.ActivityStatusID)

    JOIN SJob.ActivityTypes atype ON (atype.ID = a.ActivityTypeID)

    WHERE (j.ID = a.JobID)

      AND (stat.Name = N'Complete')

      AND (a.RowStatus NOT IN (0, 254))

) AS TotalInspections
 
OUTER APPLY

(

    SELECT SUM(

            fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change +

            fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change +

            fa.ConstructionStageChange + fa.PreConstructionStageChange

        ) AS Total

    FROM SJob.FeeAmendment fa

    WHERE (fa.JobID = j.ID)

      AND (fa.RowStatus NOT IN (0, 254))

) AS FeeAmendment
 
WHERE

    -- preserve original "not cancelled" intent, but respect workflow inactive status when it exists

    (

        (wf.LatestWorkflowStatusGuid IS NULL AND j.JobCancelled IS NULL)

        OR

        (wf.LatestWorkflowStatusGuid IS NOT NULL AND ISNULL(wf.LatestIsActiveStatus, 0) = 1)

    )

    AND

    (

        EXISTS

        (

            SELECT 1

            FROM SCore.RecordHistory rh

            WHERE (rh.RowGuid = j.Guid)

              AND (rh.Datetime > DATEADD(MONTH, -6, GETDATE()))

              AND (rh.RowStatus NOT IN (0, 254))

        )

        OR

        EXISTS

        (

            SELECT 1

            FROM SCore.RecordHistory rh

            WHERE (rh.Datetime > DATEADD(MONTH, -6, GETDATE()))

              AND (rh.RowStatus NOT IN (0, 254))

              AND EXISTS

                  (

                      SELECT 1

                      FROM SJob.Activities a

                      WHERE (a.JobID = j.ID)

                        AND (a.Guid = rh.RowGuid)

                        AND (a.RowStatus NOT IN (0, 254))

                  )

        )

        OR

        EXISTS

        (

            SELECT 1

            FROM SCore.RecordHistory rh

            WHERE (rh.Datetime > DATEADD(MONTH, -6, GETDATE()))

              AND (rh.RowStatus NOT IN (0, 254))

              AND EXISTS

                  (

                      SELECT 1

                      FROM SFin.Transactions t

                      WHERE (t.JobID = j.ID)

                        AND (t.Guid = rh.RowGuid)

                        AND (t.RowStatus NOT IN (0, 254))

                  )

        )

    );

GO