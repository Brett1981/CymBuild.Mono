SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_CDM_MyProjects]
(
    @UserID INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
WITH MilestoneData AS
(
    SELECT
        JobID,
        MAX(CASE WHEN MilestoneTypeID = 8 THEN 1 ELSE 0 END) AS HasHSFile,
        MAX(CASE WHEN MilestoneTypeID = 2 AND IsComplete = 1 THEN 1 ELSE 0 END) AS ClientDutiesIssued,
        MAX(CASE WHEN MilestoneTypeID = 1 AND IsComplete = 1 THEN 1 ELSE 0 END) AS CDMStrategyIssued,
        MAX(CONVERT(INT, IsNotApplicable)) AS IsPCI_NA,
        MAX(CASE WHEN MilestoneTypeID = 11 AND IsComplete = 1 THEN 1 ELSE 0 END) AS PCICompleted,
        MAX(CASE WHEN MilestoneTypeID = 7 THEN 1 ELSE 0 END) AS F10Applicable,
        MAX(CASE WHEN MilestoneTypeID = 19 THEN CompletedDateTimeUTC END) AS CPPDateReceived,
        MAX(CASE WHEN MilestoneTypeID = 17 THEN CompletedDateTimeUTC END) AS CPPReviewed,
        MAX(CASE WHEN MilestoneTypeID = 8 THEN ReviewedDateTimeUTC END) AS HSFReviewedDate,
        MAX(CASE WHEN MilestoneTypeID = 8 THEN CompletedDateTimeUTC END) AS HSFCompletedDate,
        MAX(CASE WHEN MilestoneTypeID = 7 THEN CompletedDateTimeUTC END) AS F10IssuedDate,
        MAX(CASE WHEN MilestoneTypeID = 7 THEN StartDateTimeUTC END) AS F10StartDate,
        MAX(CASE WHEN MilestoneTypeID = 7 THEN DueDateTimeUTC END) AS F10DueDate,
        MAX(CASE WHEN MilestoneTypeID = 7 THEN SubmissionExpiryDate END) AS F10ExpiryDate,
        MAX(CASE WHEN MilestoneTypeID = 11 THEN CompletedDateTimeUTC END) AS PCIDate
    FROM SJob.Milestones
    GROUP BY JobID
),
FeeData AS
(
    SELECT
        JobId,
        MAX(CASE WHEN StageId = -2 THEN Agreed END) AS TotalAgreed,
        MAX(CASE WHEN StageId = -2 THEN Remaining END) AS TotalRemaining,
        MAX(CASE WHEN StageId = 10 THEN QuotedMeetings END) AS PreConMeetings,
        MAX(CASE WHEN StageId = 11 THEN QuotedMeetings END) AS ConMeetings,
        MAX(CASE WHEN StageId = 10 THEN QuotedMeetings - CompletedMeetings END) AS PreConRemaining,
        MAX(CASE WHEN StageId = 11 THEN QuotedMeetings - CompletedMeetings END) AS ConRemaining
    FROM SJob.Job_FeeDrawdown
    GROUP BY JobId
),
ActivityData AS
(
    SELECT
        JobID,
        COUNT(CASE WHEN ActivityTypeID = 23 THEN ID END) AS TotalComplianceVisits,
        COUNT(CASE WHEN ActivityTypeID = 23 AND ActivityStatusID = 3 THEN ID END) AS CompletedComplianceVisits,
        MAX(CASE WHEN ActivityTypeID = 26 THEN 1 ELSE 0 END) AS HasDRR,
        MAX(CASE WHEN ActivityTypeID = 26 AND ActivityStatusID = 3 THEN 1 ELSE 0 END) AS DRRCompleted,
        MAX(CASE WHEN ActivityTypeID = 26 AND ActivityStatusID = 3 THEN EndDate END) AS DRRLastIssued
    FROM SJob.Activities
    GROUP BY JobID
)
SELECT
    j.ID,
    j.Guid,
    j.RowStatus,

    j.Number AS projectRef,
    client.Name + N' / ' + agent.Name AS clientAgent,
    p.Name + N' / ' + p.FormattedAddressComma AS propertyName,
    jt.Name AS CDMRole,
    js.JobStatus,

    -- [FINANCE]
    fd.TotalAgreed AS totalAgreed,
    fd.TotalRemaining AS totalRemaining,

    -- [AGREED DELIVERABLES]
    fd.PreConMeetings AS preconMeetings,
    fd.ConMeetings AS conMeetings,
    ad.TotalComplianceVisits AS complianceVisit,
    CASE WHEN md.HasHSFile = 1 THEN N'Yes' ELSE N'No' END AS hsFile,

    -- [REMAINING DELIVERABLES]
    fd.PreConRemaining AS preconMeetingsRemaining,
    fd.ConRemaining AS conMeetingsRemaining,
    (ad.TotalComplianceVisits - ad.CompletedComplianceVisits) AS compVisitsRemaining,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM SJob.Milestones m
            WHERE m.JobID = j.ID
              AND m.MilestoneTypeID = 8
              AND m.IsComplete = 1
        ) THEN N'Yes'
        ELSE N'No'
    END AS HSIssued,

    -- [CLIENT DUTIES]
    CASE WHEN md.ClientDutiesIssued = 1 THEN N'Yes' ELSE N'No' END AS clientDutiesIssued,
    CASE WHEN md.CDMStrategyIssued = 1 THEN N'Yes' ELSE N'No' END AS CDMStrategyIssued,

    -- [PCI]
    CASE
        WHEN md.IsPCI_NA = 1 THEN N'N/A'
        WHEN md.PCICompleted = 1 THEN N'Yes'
        ELSE N'No'
    END AS PCIInspectionCompleted,
    CASE
        WHEN md.IsPCI_NA = 1 THEN N'N/A'
        WHEN md.PCIDate IS NOT NULL THEN CONVERT(NVARCHAR(10), md.PCIDate, 120)
        ELSE NULL
    END AS PCIDate,

    -- [RISK]
    CASE
        WHEN ad.HasDRR = 1 AND ad.DRRLastIssued IS NOT NULL THEN CONVERT(NVARCHAR(10), ad.DRRLastIssued, 120)
        ELSE N'N/A'
    END AS DRRLastIssued,

    -- [F10]
    CASE WHEN md.F10Applicable = 1 THEN N'Yes' ELSE N'No' END AS F10Applicable,
    CAST(md.F10IssuedDate AS DATE) AS F10IssuedDate,
    CAST(md.F10StartDate AS DATE) AS F10Start,
    DATEDIFF(WEEK, md.F10StartDate, md.F10DueDate) AS F10WeekDuration,
    CAST(md.F10ExpiryDate AS DATE) AS F10ExpiryDate,

    -- [CPP]
    CAST(md.CPPDateReceived AS DATE) AS CPPDateReceived,
    CAST(md.CPPReviewed AS DATE) AS CPPReviewed,

    -- [H&S FILE]
    CAST(md.HSFReviewedDate AS DATE) AS HSFReviewed,
    CAST(md.HSFCompletedDate AS DATE) AS HSFCompleted
FROM SJob.Jobs AS j
JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
JOIN SJob.Assets AS p ON (p.ID = j.UprnID)
JOIN SJob.JobTypes AS jt ON (jt.ID = j.JobTypeID)
JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
LEFT JOIN MilestoneData AS md ON (md.JobID = j.ID)
LEFT JOIN FeeData AS fd ON (fd.JobId = j.ID)
LEFT JOIN ActivityData AS ad ON (ad.JobID = j.ID)

-- Latest workflow status for this job (if any) - rowstatus safe
OUTER APPLY
(
    SELECT TOP (1)
        wfs.Guid AS LatestWorkflowStatusGuid,
        wfs.IsActiveStatus AS LatestIsActiveStatus
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
    WHERE (dot.RowStatus NOT IN (0, 254))
      AND (dot.DataObjectGuid = j.Guid)
    ORDER BY dot.ID DESC
) AS wf

WHERE (j.RowStatus NOT IN (0, 254))
  AND (j.SurveyorID = @UserID)
  AND (j.ID > 0)

  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserID)
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
;
GO