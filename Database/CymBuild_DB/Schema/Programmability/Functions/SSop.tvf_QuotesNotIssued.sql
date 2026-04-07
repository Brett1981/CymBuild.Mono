SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuotesNotIssued]
(
    @UserId INT
)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
        q.FullNumber AS Number,
        LEFT(q.Overview, 200) AS Details,
        acc.Name + N' / ' + aacc.Name AS Account,
        uprn.FormattedAddressComma,
        qc.FullName AS QuotingConsultant,
        qcf.QuoteStatus,
        q.ExternalReference,
        jt.Name AS JobType,
        q.Date AS CreatedOn,
        q.ExpiryDate
    FROM SSop.Quotes AS q

    OUTER APPLY
    (
        SELECT
            CONVERT(UNIQUEIDENTIFIER, '25D5491C-42A8-4B04-B3AC-D648AF0F8032') AS SentStatus,
            CONVERT(UNIQUEIDENTIFIER, '0A6A71F7-B39F-4213-997E-2B3A13B6144C') AS RejectedStatus,
            CONVERT(UNIQUEIDENTIFIER, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D') AS DeadStatus
    ) AS WorkflowStatuses

    JOIN SSop.Quote_CalculatedFields AS qcf ON (qcf.ID = q.ID)
    JOIN SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
    JOIN SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
    JOIN SCrm.Accounts AS acc ON (acc.ID = e.ClientAccountID)
    JOIN SCrm.Accounts AS aacc ON (aacc.ID = e.AgentAccountId)
    JOIN SJob.Assets AS uprn ON (uprn.ID = q.UprnId)
    JOIN SCore.Identities AS qc ON (qc.ID = q.QuotingConsultantId)
    JOIN SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)

    -- Latest workflow status for this quote (if any) - rowstatus safe
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid
        FROM SCore.DataObjectTransition AS dob
        JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
        WHERE (dob.RowStatus NOT IN (0, 254))
          AND (dob.DataObjectGuid = q.Guid)
        ORDER BY dob.ID DESC
    ) AS wf

    WHERE (q.RowStatus NOT IN (0, 254))
      AND (q.ID > 0)

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         NOT SENT: legacy OR workflow (latest only)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN q.DateSent IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = WorkflowStatuses.SentStatus THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT REJECTED: legacy OR workflow (latest only)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN q.DateRejected IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = WorkflowStatuses.RejectedStatus THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT DEAD: legacy OR workflow (latest only)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN q.DeadDate IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = WorkflowStatuses.DeadStatus THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      AND (q.ExpiryDate > GETDATE())
      AND (q.ExpiryDate <= DATEADD(DAY, 14, GETDATE()))

      -- No job created from any quote item (unchanged)
      AND NOT EXISTS
      (
          SELECT 1
          FROM SSop.QuoteItems AS qi
          WHERE (qi.CreatedJobId > 0)
            AND (qi.QuoteId = q.ID)
      )
);
GO