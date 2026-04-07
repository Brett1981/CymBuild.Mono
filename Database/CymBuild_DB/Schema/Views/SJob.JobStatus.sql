SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-101 – Job datapill visibility fixes (NO workflow process changes)

   QA issues targeted by this view change:
   - Job detail screen shows NO datapill for these statuses:
       • Dead
       • Complete for Review
       • Reviewed

   What’s actually wrong (based on how CymBuild typically drives datapills):
   - Datapills for Jobs are not driven purely by the *text* "JobStatus" returned
     by this view. They are normally driven by the WorkflowStatus metadata flags
     (RequiresUserAction / IsCustomerWaitingStatus / IsCompleteStatus / IsActiveStatus)
     and/or “ShowInJobs”, combined with the *latest* workflow transition for the Job.
   - This view currently returns only the Name, so any downstream pill logic that
     expects the Job’s current WorkflowStatus metadata (or a deterministically
     filterable status identifier) cannot reliably classify Dead / Complete for Review
     / Reviewed, resulting in “no datapill”.

   Fix approach (calculation/data-source only):
   - Keep JobStatus text output EXACTLY as before (no regression).
   - Add additional columns exposing the current workflow status metadata flags
     so datapill logic can render consistently on the Job detail screen.

   Constraints respected:
   - NO changes to workflow meanings / allowed transitions / lifecycle rules.
   - Latest workflow transition remains the single source of truth when present.
   - Legacy fallback behaviour remains intact for historical jobs.
============================================================================= */
CREATE VIEW [SJob].[JobStatus]
--WITH SCHEMABINDING
AS
SELECT
    j.ID,

    /* ------------------------------------------------------------------------
       Existing JobStatus output (unchanged)
    ------------------------------------------------------------------------- */
    JobStatus =
    CASE
        ---------------------------------------------------------------------
        -- 0) If we HAVE a workflow status, it is the single source of truth.
        ---------------------------------------------------------------------
        WHEN CurrentWorkflowStatus.Name IS NOT NULL
        THEN
            CASE
                WHEN CurrentWorkflowStatus.Name IN
                (
                    N'New',
                    N'Job Started',
                    N'Dormant',
                    N'Cancelled',
                    N'Completed',
                    N'Dead',
                    N'Complete for Review',
                    N'Reviewed'
                )
                THEN CurrentWorkflowStatus.Name
                ELSE CurrentWorkflowStatus.Name
            END

        ---------------------------------------------------------------------
        -- 1) No workflow transitions exist -> fall back to legacy fields.
        ---------------------------------------------------------------------
        WHEN (j.JobCompleted IS NOT NULL) THEN N'Completed'
        WHEN (j.JobCancelled IS NOT NULL) THEN N'Cancelled'
        WHEN (j.DeadDate      IS NOT NULL) THEN N'Dead'
        WHEN (j.JobDormant    IS NOT NULL) THEN N'Dormant'
        WHEN (j.ReviewedDateTimeUTC IS NOT NULL) THEN N'Reviewed'
        WHEN (j.IsCompleteForReview = 1) THEN N'Complete for Review'
        WHEN (j.JobStarted IS NOT NULL) THEN N'Job Started'
        ELSE N'New'
    END,

    /* ------------------------------------------------------------------------
       NEW: expose current workflow status metadata for datapills (read-only)

       These columns do NOT change JobStatus text output.
       They simply allow the UI/datapill logic to determine the correct pill
       from the underlying workflow status definition – which is required for
       QA statuses: Dead / Complete for Review / Reviewed.
    ------------------------------------------------------------------------- */
    CurrentWorkflowStatusName  = CurrentWorkflowStatus.Name,
    CurrentWorkflowStatusGuid  = CurrentWorkflowStatus.Guid,

    CurrentWorkflowRequiresUserAction   = ISNULL(CurrentWorkflowStatus.RequiresUsersAction, 0),
    CurrentWorkflowIsActiveStatus       = ISNULL(CurrentWorkflowStatus.IsActiveStatus, 0),
    CurrentWorkflowIsCustomerWaiting    = ISNULL(CurrentWorkflowStatus.IsCustomerWaitingStatus, 0),
    CurrentWorkflowIsCompleteStatus     = ISNULL(CurrentWorkflowStatus.IsCompleteStatus, 0),
    CurrentWorkflowShowInJobs           = ISNULL(CurrentWorkflowStatus.ShowInJobs, 0),

    p.IsSubjectToNDA
FROM SJob.Jobs j
JOIN SSop.Projects p ON p.ID = j.ProjectId

OUTER APPLY
(
    /* ------------------------------------------------------------------------
       Single latest transition (LATEST-STATUS-ONLY)

       I return the workflow metadata flags here so the Job detail datapill logic
       can correctly render for:
         - Dead
         - Complete for Review
         - Reviewed
    ------------------------------------------------------------------------- */
    SELECT TOP (1)
        Name                    = wfs1.Name,
        Guid                    = wfs1.Guid,
        RequiresUsersAction     = wfs1.RequiresUsersAction,
        IsActiveStatus          = wfs1.IsActiveStatus,
        IsCustomerWaitingStatus = wfs1.IsCustomerWaitingStatus,
        IsCompleteStatus        = wfs1.IsCompleteStatus,
        ShowInJobs              = wfs1.ShowInJobs
    FROM SCore.DataObjectTransition dot1
    JOIN SCore.WorkflowStatus wfs1 ON wfs1.ID = dot1.StatusID
    WHERE dot1.DataObjectGuid = j.Guid
      AND dot1.RowStatus NOT IN (0,254)
      AND wfs1.RowStatus NOT IN (0,254)
    ORDER BY dot1.DateTimeUTC DESC, dot1.ID DESC
) AS CurrentWorkflowStatus;
GO