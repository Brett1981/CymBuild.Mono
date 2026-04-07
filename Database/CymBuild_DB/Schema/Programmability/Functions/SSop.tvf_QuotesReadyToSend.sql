SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuotesReadyToSend]
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
        CASE
            WHEN q.DescriptionOfWorks <> N'' THEN LEFT(q.DescriptionOfWorks, 200)
            ELSE LEFT(q.Overview, 200)
        END AS Details,
        acc.Name + N' / ' + aacc.Name AS Account,
        uprn.FormattedAddressComma,
        i.FullName AS QuotingConsultant,
        qcf.QuoteStatus AS QuoteStatus
    FROM SSop.Quotes AS q
    JOIN SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
    JOIN SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
    JOIN SCrm.Accounts AS acc ON (acc.ID = e.ClientAccountID)
    JOIN SCrm.Accounts AS aacc ON (aacc.ID = e.AgentAccountID)
    JOIN SCore.Identities AS i ON (i.ID = q.QuotingConsultantId)
    JOIN SJob.Assets AS uprn ON (uprn.ID = q.UprnId)
    JOIN SSop.Quote_CalculatedFields AS qcf ON (qcf.ID = q.ID)

    OUTER APPLY
    (
        SELECT
            CONVERT(UNIQUEIDENTIFIER, '02A2237F-2AE7-4E05-926F-38E8B7D050A0') AS ReadyToSendStatus,
            CONVERT(UNIQUEIDENTIFIER, '25D5491C-42A8-4B04-B3AC-D648AF0F8032') AS SentStatus,
            CONVERT(UNIQUEIDENTIFIER, '21A29AEE-2D99-4DA3-8182-F31813B0C498') AS AcceptedStatus,
            CONVERT(UNIQUEIDENTIFIER, '0A6A71F7-B39F-4213-997E-2B3A13B6144C') AS RejectedStatus,
            CONVERT(UNIQUEIDENTIFIER, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D') AS DeadStatus
    ) AS Statuses

    -- Latest workflow status for this quote (if any) - rowstatus safe
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0, 254))
          AND (dot.DataObjectGuid = q.Guid)
        ORDER BY dot.ID DESC
    ) AS wf

    WHERE (q.RowStatus NOT IN (0, 254))
      AND (q.ID > 0)

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         READY TO SEND: legacy OR workflow (latest only)
         ReadyToSend workflow GUID: 02A2237F-2AE7-4E05-926F-38E8B7D050A0
         Legacy flag: q.IsFinal = 1
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(q.IsFinal, 0) = 1 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = Statuses.ReadyToSendStatus THEN 1
                      ELSE 0
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT SENT: legacy OR workflow (latest only)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN q.DateSent IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE WHEN wf.LatestWorkflowStatusGuid = Statuses.SentStatus THEN 0 ELSE 1 END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT ACCEPTED: legacy OR workflow (latest only)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN q.DateAccepted IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE WHEN wf.LatestWorkflowStatusGuid = Statuses.AcceptedStatus THEN 0 ELSE 1 END
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
                  CASE WHEN wf.LatestWorkflowStatusGuid = Statuses.RejectedStatus THEN 0 ELSE 1 END
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
                  CASE WHEN wf.LatestWorkflowStatusGuid = Statuses.DeadStatus THEN 0 ELSE 1 END
          END
      ) = 1

      AND (q.ExpiryDate > GETDATE())
);
GO