SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[Jobs_BackfillMissingQuoteStageFees]')
GO

/*
    Backfills SJob.JobRibaStageFees for Jobs created from a Quote whose agreed fee
    never reached the Job.

    SSop.QuoteCreateJobs writes the fixed fee columns from SSop.Quote_JobsSummary,
    which has no slot for Stage 0 (RibaStages.Number = 0) or custom stages, and
    before release 26.2 nothing wrote SJob.JobRibaStageFees. A Job created from
    such a quote has a zero agreed fee even though its quote items carry a real
    value (e.g. Job 9615: one Stage 0 item of 13,960.00, every fee column 0).

    Candidates: active Jobs with no active SJob.JobRibaStageFees rows and at least
    one active, non-zero created-from QuoteItem.

        FIX     - every fixed fee column is zero, the items come from one quote and
                  no fee amendment changes the fee. Safe: the dynamic rows become
                  the Job's only agreed fee.
        AMENDED - as FIX, but the fee amendments add up to exactly the quote item
                  total: a user raised an amendment to work around the missing
                  fee. Backfilling would count the fee twice, so these are only
                  reported; correcting them needs a business decision on the
                  amendment.
        REVIEW  - anything else: fixed fee columns that differ from the quote
                  items (they may hold manual edits, and dynamic rows would hide
                  them), items from more than one quote (likely duplicated by a
                  quote revision), or amendments that only partly change the fee.

    Jobs whose fixed fee columns already equal the quote item total are fine and
    are not reported.

    The amendment total covers the fixed columns, SJob.FeeAmendmentRibaStages and
    SJob.CustomFeeAmendment, whatever the amendment's status.

    Corrections call SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems, the same
    procedure SSop.QuoteCreateJobs now calls when it creates a Job.

    Run with @PreviewOnly = 1 (default) first. @JobID limits the run to one Job.
*/
CREATE OR ALTER PROCEDURE [SJob].[Jobs_BackfillMissingQuoteStageFees]
(
    @PreviewOnly BIT = 1,
    @JobID INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Each Job is corrected in its own transaction so one failure cannot undo
    -- the others; an outer transaction would defeat that.
    IF @@TRANCOUNT > 0
    BEGIN
        ;THROW 60000, N'SJob.Jobs_BackfillMissingQuoteStageFees must be run outside a transaction.', 1;
    END;

    DECLARE @Candidates TABLE
    (
        JobID INT NOT NULL PRIMARY KEY,
        FixedFeeTotal DECIMAL(19, 2) NOT NULL,
        QuoteItemTotal DECIMAL(19, 2) NOT NULL,
        QuoteCount INT NOT NULL,
        FeeAmendmentCount INT NOT NULL,
        FeeAmendmentTotal DECIMAL(19, 2) NOT NULL,
        ProposedAction NVARCHAR(10) NOT NULL
    );

    DECLARE @Results TABLE
    (
        JobID INT NOT NULL PRIMARY KEY,
        Outcome NVARCHAR(20) NOT NULL,
        ErrorMessage NVARCHAR(4000) NULL
    );

    ;WITH CandidateTotals AS
    (
        SELECT
            j.ID AS JobID,
            CAST
            (
                  ISNULL(j.AgreedFee, 0) + ISNULL(j.RibaStage1Fee, 0) + ISNULL(j.RibaStage2Fee, 0)
                + ISNULL(j.RibaStage3Fee, 0) + ISNULL(j.RibaStage4Fee, 0) + ISNULL(j.RibaStage5Fee, 0)
                + ISNULL(j.RibaStage6Fee, 0) + ISNULL(j.RibaStage7Fee, 0)
                + ISNULL(j.PreConstructionStageFee, 0) + ISNULL(j.ConstructionStageFee, 0)
                AS DECIMAL(19, 2)
            ) AS FixedFeeTotal,
            quoted.QuoteItemTotal,
            quoted.QuoteCount,
            amended.FeeAmendmentCount,
            CAST
            (
                  ISNULL(amended.FixedColumnChange, 0)
                + ISNULL(stageAmended.StageChange, 0)
                + ISNULL(customAmended.CustomChange, 0)
                AS DECIMAL(19, 2)
            ) AS FeeAmendmentTotal
        FROM SJob.Jobs AS j
        CROSS APPLY
        (
            SELECT
                CAST(SUM(qit.LineNet) AS DECIMAL(19, 2)) AS QuoteItemTotal,
                COUNT(DISTINCT qi.QuoteId) AS QuoteCount
            FROM SSop.QuoteItems AS qi
            JOIN SSop.QuoteItemTotals AS qit
                ON qit.ID = qi.ID
            WHERE qi.CreatedJobId = j.ID
              AND qi.RowStatus NOT IN (0, 254)
              AND qi.Quantity > 0
        ) AS quoted
        CROSS APPLY
        (
            SELECT
                COUNT(1) AS FeeAmendmentCount,
                SUM
                (
                      fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change
                    + fa.RibaStage3Change + fa.RibaStage4Change + fa.RibaStage5Change
                    + fa.RibaStage6Change + fa.RibaStage7Change
                    + fa.PreConstructionStageChange + fa.ConstructionStageChange
                ) AS FixedColumnChange
            FROM SJob.FeeAmendment AS fa
            WHERE fa.JobID = j.ID
              AND fa.RowStatus NOT IN (0, 254)
        ) AS amended
        OUTER APPLY
        (
            SELECT
                SUM(fars.FeeChange) AS StageChange
            FROM SJob.FeeAmendmentRibaStages AS fars
            WHERE fars.JobID = j.ID
              AND fars.RowStatus NOT IN (0, 254)
        ) AS stageAmended
        OUTER APPLY
        (
            SELECT
                SUM(cfa.StageChange) AS CustomChange
            FROM SJob.CustomFeeAmendment AS cfa
            WHERE cfa.JobID = j.ID
              AND cfa.RowStatus NOT IN (0, 254)
        ) AS customAmended
        WHERE j.ID > 0
          AND j.RowStatus NOT IN (0, 254)
          AND (@JobID IS NULL OR j.ID = @JobID)
          AND ISNULL(quoted.QuoteItemTotal, 0) <> 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.JobRibaStageFees AS jrsf
              WHERE jrsf.JobID = j.ID
                AND jrsf.RowStatus NOT IN (0, 254)
          )
    )
    INSERT INTO @Candidates
    (
        JobID,
        FixedFeeTotal,
        QuoteItemTotal,
        QuoteCount,
        FeeAmendmentCount,
        FeeAmendmentTotal,
        ProposedAction
    )
    SELECT
        ct.JobID,
        ct.FixedFeeTotal,
        ct.QuoteItemTotal,
        ct.QuoteCount,
        ct.FeeAmendmentCount,
        ct.FeeAmendmentTotal,
        CASE
            WHEN ct.FixedFeeTotal <> 0 OR ct.QuoteCount > 1 THEN N'REVIEW'
            WHEN ct.FeeAmendmentTotal = 0 THEN N'FIX'
            WHEN ct.FeeAmendmentTotal = ct.QuoteItemTotal THEN N'AMENDED'
            ELSE N'REVIEW'
        END AS ProposedAction
    FROM CandidateTotals AS ct
    WHERE ct.FixedFeeTotal <> ct.QuoteItemTotal;

    IF @PreviewOnly = 1
    BEGIN
        SELECT
            c.JobID,
            j.Number AS JobNumber,
            j.CreatedOn,
            c.FixedFeeTotal,
            c.QuoteItemTotal,
            c.QuoteCount,
            c.FeeAmendmentCount,
            c.FeeAmendmentTotal,
            c.ProposedAction
        FROM @Candidates AS c
        JOIN SJob.Jobs AS j
            ON j.ID = c.JobID
        ORDER BY
            c.ProposedAction,
            c.JobID;

        RETURN;
    END;

    DECLARE @CurrentJobID INT;

    DECLARE candidate_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT c.JobID
        FROM @Candidates AS c
        WHERE c.ProposedAction = N'FIX'
        ORDER BY c.JobID;

    OPEN candidate_cursor;
    FETCH NEXT FROM candidate_cursor INTO @CurrentJobID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems @JobID = @CurrentJobID;

            -- The upsert returns silently when no quote item maps to a stage.
            INSERT INTO @Results (JobID, Outcome, ErrorMessage)
            SELECT
                @CurrentJobID,
                CASE WHEN written.HasRows = 1 THEN N'FIXED' ELSE N'NO ROWS' END,
                CASE WHEN written.HasRows = 1 THEN NULL
                     ELSE N'No quote item resolved to a RIBA stage; nothing was written.' END
            FROM
            (
                SELECT
                    CASE WHEN EXISTS
                    (
                        SELECT 1
                        FROM SJob.JobRibaStageFees AS jrsf
                        WHERE jrsf.JobID = @CurrentJobID
                          AND jrsf.RowStatus NOT IN (0, 254)
                    ) THEN 1 ELSE 0 END AS HasRows
            ) AS written;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
            BEGIN
                ROLLBACK TRANSACTION;
            END;

            INSERT INTO @Results (JobID, Outcome, ErrorMessage)
            VALUES (@CurrentJobID, N'FAILED', ERROR_MESSAGE());
        END CATCH;

        FETCH NEXT FROM candidate_cursor INTO @CurrentJobID;
    END;

    CLOSE candidate_cursor;
    DEALLOCATE candidate_cursor;

    SELECT
        c.JobID,
        j.Number AS JobNumber,
        c.QuoteItemTotal,
        stageFees.AgreedFeeTotal AS JobRibaStageFeesTotal,
        c.FeeAmendmentTotal,
        ISNULL(r.Outcome, N'SKIPPED - ' + c.ProposedAction) AS Outcome,
        CASE
            WHEN r.JobID IS NOT NULL THEN r.ErrorMessage
            WHEN c.ProposedAction = N'AMENDED' THEN N'Fee amendment equals the quote total - decide on the amendment before restoring the fee.'
            ELSE N'Needs manual review - see the preview columns.'
        END AS Detail
    FROM @Candidates AS c
    JOIN SJob.Jobs AS j
        ON j.ID = c.JobID
    LEFT JOIN @Results AS r
        ON r.JobID = c.JobID
    OUTER APPLY
    (
        SELECT
            CAST(SUM(jrsf.AgreedFee) AS DECIMAL(19, 2)) AS AgreedFeeTotal
        FROM SJob.JobRibaStageFees AS jrsf
        WHERE jrsf.JobID = c.JobID
          AND jrsf.RowStatus NOT IN (0, 254)
    ) AS stageFees
    ORDER BY
        ISNULL(r.Outcome, N'SKIPPED'),
        c.JobID;
END;
GO
