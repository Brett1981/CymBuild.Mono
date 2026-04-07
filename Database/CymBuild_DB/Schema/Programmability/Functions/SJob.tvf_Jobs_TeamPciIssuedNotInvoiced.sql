SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamPciIssuedNotInvoiced]
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        client.Name AS Client,
        jt.Name AS JobTypeName,
        i.Guid AS SurveyorGuid,
        i.FullName AS SurveyorName,
        PCI.CompletedDateTimeUTC,
        jf.OutstandingFee,
        js.IsSubjectToNDA,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        asset.FormattedAddressComma AS Asset,
        j.ExternalReference,
        j.CreatedOn
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus   AS js ON (js.ID = j.ID)
    JOIN SJob.JobFinance  AS jf ON (jf.ID = j.ID)
    JOIN SJob.JobTypes    AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i  ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts    AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts    AS agent  ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets      AS asset  ON (asset.ID = j.UprnID)

    -- Latest workflow status for this job (if any) - rowstatus safe (dot + wfs)
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid           AS LatestWorkflowStatusGuid,
            wfs.IsActiveStatus AS LatestIsActiveStatus
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus       AS wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0, 254))
          AND (wfs.RowStatus NOT IN (0, 254))
          AND (dot.DataObjectGuid = j.Guid)
        ORDER BY dot.ID DESC
    ) AS wf

    -- Latest PCI completed milestone (avoid duplicate rows per job)
    CROSS APPLY
    (
        SELECT m.CompletedDateTimeUTC
        FROM SJob.Milestones AS m
        JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
        WHERE (m.JobID = j.ID)
          AND (m.RowStatus NOT IN (0, 254))
          AND (mt.Code = N'PCI')
          AND (m.CompletedDateTimeUTC IS NOT NULL)
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.Milestones AS m1
              WHERE (m1.JobID = j.ID)
                AND (m1.MilestoneTypeID = m.MilestoneTypeID)
                AND (m1.RowStatus NOT IN (0, 254))
                AND (m1.CompletedDateTimeUTC > m.CompletedDateTimeUTC)
          )
    ) AS PCI

    CROSS APPLY
    (
        SELECT ou1.OrgNode
        FROM SCore.OrganisationalUnits AS ou1
        JOIN SCore.Identities AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
        WHERE (i1.ID = @UserId)
    ) AS CurrentUser

    WHERE (j.RowStatus NOT IN (0, 254))

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         GLOBAL ACTIVE RULE (latest workflow wins):
         - If workflow exists => must have LatestIsActiveStatus = 1
         - Else => must have legacy IsActive = 1
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN ISNULL(j.IsActive, 0)
              ELSE ISNULL(wf.LatestIsActiveStatus, 0)
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT COMPLETE: legacy OR workflow (latest only)
         Completed workflow GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '20D22623-283B-4088-9CEB-D944AC3E6516') THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT CANCELLED: legacy OR workflow (latest only)
         Cancelled workflow GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64') THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      -- Pending completion stays legacy (no workflow column provided for it)
      AND (ISNULL(j.IsPendingCompletion, 0) = 0)

      -- Team scope (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS ou2
          WHERE (ou2.ID = i.OriganisationalUnitId)
            AND (ou2.OrgNode.IsDescendantOf(CurrentUser.OrgNode) = 1)
      )

      -- No PCI transaction (unchanged)
      AND NOT EXISTS
      (
          SELECT 1
          FROM SFin.Transactions AS trn
          JOIN SFin.TransactionDetails AS td ON (td.TransactionID = trn.ID)
          JOIN SJob.Milestones AS m ON (m.ID = td.MilestoneID)
          JOIN SJob.MilestoneTypes AS mtt ON (mtt.ID = m.MilestoneTypeID)
          WHERE (trn.RowStatus NOT IN (0, 254))
            AND (trn.JobID = j.ID)
            AND (mtt.Code = N'PCI')
      )
);
GO