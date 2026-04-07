SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_NoFormalAppointment]
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
        j.JobStarted AS DueDateTimeUTC,
        js.IsSubjectToNDA,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        prop.FormattedAddressComma AS Asset,
        j.ExternalReference,
        jobTypes.Name AS JobType,
        CONVERT(NVARCHAR(19), j.CreatedOn) AS CreatedOn,
        i.FullName AS Consultant
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus     AS js       ON (js.ID = j.ID)
    JOIN SJob.JobTypes      AS jt       ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities   AS i        ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts      AS client   ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts      AS agent    ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets        AS prop     ON (prop.ID = j.UprnID)
    JOIN SJob.JobTypes      AS jobTypes ON (jobTypes.ID = j.JobTypeID)

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

    WHERE (j.RowStatus NOT IN (0, 254))

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      AND (jt.Name IN (N'CDM PD', N'CDM PD (Construction Phase Only)', N'CDM PD (Pre-Construction Phase Only)'))

      AND (j.ReviewedByUserID < 0)
      AND (j.SurveyorID = @UserId)
      AND (j.ClientAppointmentReceived = 0)

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

      /* --------------------------------------------------------------------
         NOT COMPLETE FOR REVIEW: legacy OR workflow (latest only)
         CFR workflow GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82
         (original intent was "NOT CFR", so we keep that)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCompleteForReview, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '4BFDB215-3E27-4829-BB44-0468C92DAC82') THEN 0
                      ELSE 1
                  END
          END
      ) = 1
);
GO