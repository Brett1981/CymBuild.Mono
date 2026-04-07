SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   Task 1 — Refactor SJob.tvf_Jobs_ClosureRequestedForAuthoriserQueue(@UserId)

   New behaviour:
   - Uses generic authorisation queue model:
       * latest workflow transition
       * WorkflowStatus.AuthorisationNeeded = 1
       * user is a member of at least one mapped group for that workflow+status
   - Then joins to SJob.Jobs for job-specific display fields.

   IMPORTANT:
   - We KEEP job-domain rules here (Active/Complete/Cancelled), because those rules
     are not universal across Quotes/Enquiries.
============================================================================= */
CREATE FUNCTION [SJob].[tvf_Jobs_ClosureRequestedForAuthoriserQueue]
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
        agent.Name  AS Agent,
        jt.Name     AS JobTypeName,
        i.Guid      AS SurveyorGuid,
        i.FullName  AS SurveyorName,
        js.IsSubjectToNDA,
        j.ExternalReference,
        j.CreatedOn,
        j.JobCompleted,
        asset.FormattedAddressComma AS Asset,

        /* Generic queue columns (used by UI/actions) */
        aq.WorkflowId,
        aq.LatestWorkflowStatusGuid,
        aq.LatestWorkflowStatusName,
        aq.LatestTransitionGuid,
        aq.LatestTransitionUtc,
        aq.OrganisationalUnitId,
        aq.CanActionForUser
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus       AS js    ON js.ID = j.ID
    JOIN SJob.JobTypes        AS jt    ON jt.ID = j.JobTypeID
    JOIN SCore.Identities     AS i     ON i.ID  = j.SurveyorID
    JOIN SCrm.Accounts        AS client ON client.ID = j.ClientAccountID
    JOIN SCrm.Accounts        AS agent  ON agent.ID  = j.AgentAccountID
    JOIN SJob.Assets          AS asset  ON asset.ID  = j.UprnID

    /* -------------------------------------------------------------------------
       Generic authorisation queue:
       EntityTypes shows Jobs = 9 in your dataset.
    ------------------------------------------------------------------------- */
    JOIN SCore.tvf_WF_AuthorisationQueue(@UserId, 9) AS aq
        ON aq.DataObjectGuid = j.Guid

    WHERE j.RowStatus NOT IN (0,254)

      /* Keep existing read-security rule for Jobs */
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId)
      )

      /* --------------------------------------------------------------------
         Job legacy “Active” rule (latest workflow wins)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN aq.LatestWorkflowStatusGuid IS NULL THEN ISNULL(j.IsActive, 0)
              ELSE ISNULL(aq.LatestIsActiveStatus, 0)
          END
      ) = 1

      /* --------------------------------------------------------------------
         Job legacy “Not Complete” rule
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN aq.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsComplete, 0) = 0 AND j.JobCompleted IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE WHEN ISNULL(aq.LatestIsCompleteStatus, 0) = 1 THEN 0 ELSE 1 END
          END
      ) = 1

      /* --------------------------------------------------------------------
         Job legacy “Not Cancelled” rule
         - If workflow exists, we already filtered IsActiveStatus=1 above.
         - If no workflow exists, fall back to legacy j.IsCancelled.
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN aq.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE 1
          END
      ) = 1
);
GO