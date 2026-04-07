SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamCommencedNotInvoiced]
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
        client.Name + N' / ' + agent.Name AS ClientAgent,
        jt.Name AS JobTypeName,
        i.Guid AS SurveyorGuid,
        i.FullName AS SurveyorName,
        js.IsSubjectToNDA,
        asset.FormattedAddressComma AS Asset,
        j.ExternalReference,
        CONVERT(VARCHAR(11), j.CreatedOn, 106) AS CreatedOn
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobFinance AS jf ON (jf.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets AS asset ON (asset.ID = j.UprnID)

    -- Latest workflow status for this job (if any)
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid,
            wfs.IsActiveStatus AS LatestIsActiveStatus
        FROM SCore.DataObjectTransition dot
        JOIN SCore.WorkflowStatus wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0, 254))
          AND (dot.DataObjectGuid = j.Guid)
        ORDER BY dot.ID DESC
    ) AS wf

    CROSS APPLY
    (
        SELECT ou1.OrgNode
        FROM SCore.OrganisationalUnits AS ou1
        JOIN SCore.Identities AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
        WHERE (i1.ID = @UserId)
    ) AS CurrentUser

    WHERE (j.RowStatus NOT IN (0, 254))

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

      AND
      (
          -- Commenced: activity changed after job created
          EXISTS
          (
              SELECT 1
              FROM SCore.RecordHistory AS rh1
              JOIN SJob.Activities AS a1 ON rh1.RowGuid = a1.Guid
              WHERE a1.JobID = j.ID
                AND a1.RowStatus NOT IN (0, 254)
                AND rh1.RowStatus NOT IN (0, 254)
                AND rh1.Datetime > j.CreatedOn
          )
          OR
          -- Commenced: milestone changed after job created
          EXISTS
          (
              SELECT 1
              FROM SCore.RecordHistory AS rh1
              JOIN SJob.Milestones AS m1 ON rh1.RowGuid = m1.Guid
              WHERE m1.JobID = j.ID
                AND m1.RowStatus NOT IN (0, 254)
                AND rh1.RowStatus NOT IN (0, 254)
                AND rh1.Datetime > j.CreatedOn
          )
      )

      /* --------------------------------------------------------------------
         NOT CANCELLED: legacy OR workflow (latest only)
         Cancelled workflow status GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64'
                          THEN 0  -- cancelled (exclude)
                      ELSE 1      -- not cancelled (include)
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT COMPLETE FOR REVIEW: legacy OR workflow (latest only)
         Legacy check here is your original: CompletedForReviewDate IS NULL
         Workflow CFR GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN j.CompletedForReviewDate IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '4BFDB215-3E27-4829-BB44-0468C92DAC82'
                          THEN 0  -- complete for review (exclude)
                      ELSE 1      -- not complete for review (include)
                  END
          END
      ) = 1

      -- No financial transactions against the job (unchanged)
      AND NOT EXISTS
      (
          SELECT 1
          FROM SFin.Transactions AS t
          JOIN SFin.TransactionDetails AS td ON (t.ID = td.TransactionID)
          WHERE t.JobID = j.ID
      )

      -- Team scope (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS ou2
          WHERE (ou2.ID = i.OriganisationalUnitId)
            AND (ou2.OrgNode.IsDescendantOf(CurrentUser.OrgNode) = 1)
      )

      -- Security (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )
);
GO