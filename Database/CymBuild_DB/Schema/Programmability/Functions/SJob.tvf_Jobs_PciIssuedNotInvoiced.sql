SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_PciIssuedNotInvoiced]
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
        j.ExternalReference,
        asset.FormattedAddressComma AS Asset,
        j.CreatedOn
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobFinance AS jf ON (jf.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets AS asset ON (asset.ID = j.UprnID)

    -- Latest workflow status for this job (if any). If none, this returns NULLs.
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid,
            wfs.IsActiveStatus AS LatestIsActiveStatus
        FROM SCore.DataObjectTransition dot
        JOIN SCore.WorkflowStatus wfs ON (wfs.ID = dot.StatusID)
        WHERE dot.DataObjectGuid = j.Guid
        ORDER BY dot.ID DESC
    ) AS wf

    CROSS APPLY
    (
        SELECT m.CompletedDateTimeUTC
        FROM SJob.Milestones AS m
        JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
        WHERE (m.JobID = j.ID)
          AND (m.RowStatus NOT IN (0, 254))
          AND (mt.Code = N'PCI')
          AND (m.IsComplete = 1)
          AND (NOT EXISTS
              (
                  SELECT 1
                  FROM SJob.Milestones AS m1
                  WHERE (m1.JobID = j.ID)
                    AND (m1.MilestoneTypeID = m.MilestoneTypeID)
                    AND (m1.RowStatus NOT IN (0, 254))
                    AND (m1.CompletedDateTimeUTC < m.CompletedDateTimeUTC)
              )
          )
    ) AS PCI

    WHERE (j.RowStatus NOT IN (0, 254))

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         ACTIVE: legacy OR workflow (latest only)
         Rule: if workflow exists => use wf.LatestIsActiveStatus
               else => use j.IsActive
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
         Completed workflow status GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN
                      CASE WHEN ISNULL(j.IsComplete, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '20D22623-283B-4088-9CEB-D944AC3E6516'
                          THEN 0   -- completed (exclude)
                      ELSE 1       -- not completed (include)
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT COMPLETE FOR REVIEW: legacy OR workflow (latest only)
         CompleteForReview workflow status GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN
                      CASE WHEN ISNULL(j.IsCompleteForReview, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '4BFDB215-3E27-4829-BB44-0468C92DAC82'
                          THEN 0   -- complete for review (exclude)
                      ELSE 1       -- not complete for review (include)
                  END
          END
      ) = 1

      AND (j.SurveyorID = @UserId)
      AND (j.ReviewedByUserID < 0)

      /* --------------------------------------------------------------------
         Not invoiced: no finance transaction linked to PCI milestone
         (unchanged)
      -------------------------------------------------------------------- */
      AND NOT EXISTS
      (
          SELECT 1
          FROM SFin.Transactions AS trn
          JOIN SFin.TransactionDetails AS trd ON (trn.ID = trd.TransactionID)
          JOIN SJob.Milestones AS m ON (m.ID = trd.MilestoneID)
          JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
          WHERE (trn.RowStatus NOT IN (0, 254))
            AND (trn.JobID = j.ID)
            AND (mt.Code = N'PCI')
      )
);
GO