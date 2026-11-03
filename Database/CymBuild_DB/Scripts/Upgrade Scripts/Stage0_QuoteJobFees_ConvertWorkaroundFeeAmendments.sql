/*
    Convert workaround fee amendments into the Job's original agreed fee.

    Background: before release 26.2 reached LIVE (2026-07-07), a Job created
    from a quote with a Stage 0 (or custom stage) item got no agreed fee, because
    the fixed fee columns have no slot for those stages and nothing wrote
    SJob.JobRibaStageFees. Users worked around it by raising a fee amendment for
    the full quoted fee (e.g. Job 9615: "Did not pull through the remaining fee
    amount, therefore adjusted manually via fee amendment"). The Job total is
    right, but the original quoted fee shows as 0 and the amendment as a change,
    so the under/overquoting report counts the whole fee as an underquote.

    For each qualifying Job this script, in one transaction per Job:
      1. writes SJob.JobRibaStageFees from the quote items, using
         SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems - the procedure job
         creation now uses;
      2. checks the new stage fees equal the amendments, stage by stage;
      3. retires the fee-carrying workaround amendments (SCore.DeleteDataObject
         + RowStatus 254, the standard soft delete) and appends a note to their
         Reason. The SJob.FeeAmendment RecordHistory trigger audits the change
         under @ActingUserID. Amendments that change no fee are left alone.
    The Job's total agreed fee is unchanged; it moves from "amendment" to
    "original fee".

    A Job qualifies (the AMENDED group of SJob.Jobs_BackfillMissingQuoteStageFees)
    only when ALL of these hold at run time:
      - active Job, every fixed fee column zero, no active JobRibaStageFees rows;
      - its created-from quote items come from exactly one quote and total <> 0;
      - its active fee amendments' fee changes add up to exactly that total;
      - no FeeAmendmentRibaStages / CustomFeeAmendment rows on the Job;
      - the fee-carrying amendments change nothing but fees (no fee cap,
        meeting or visit changes), so retiring them loses nothing else.
    @StageSource picks which stages the restored fee goes on:
      - N'QUOTE' (default): the quote items' stages, via the upsert procedure
        (-1 "no stage" items go to RIBA Stage 1, as job creation does). Jobs
        where these differ from the amendments' stages are skipped
        (STAGE MISMATCH) unless @AllowStageMove = 1; moving fee between stages
        can change per-stage "remaining" on invoiced Jobs.
      - N'AMENDMENT': the stages the workaround amendments put the fee on, so
        every per-stage figure stays exactly as users see it today. Profiling
        on QA2 (2026-10-02) found the quote side is usually Stage 0 or -1 left
        at its default, with the amendment recording where the work really is.
        CreatedFromQuoteItemID is the Job's first quote item (as the upsert
        procedure does for stages with no quote item). Jobs whose amendments
        net negative on any stage are skipped (NEGATIVE STAGE).

    Business sign-off is required before running with @DryRun = 0.

    @DryRun = 1 (default) runs every step and rolls each Job back, so the report
    shows exactly what would happen. It takes short per-Job locks and consumes
    identity values, so run it out of hours on LIVE.

    Safe to re-run: a converted Job has JobRibaStageFees rows and no longer
    qualifies.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;          -- sqlcmd defaults QUOTED_IDENTIFIER OFF; the filtered
SET QUOTED_IDENTIFIER ON;   -- indexes on the updated tables need both ON (Msg 1934)

DECLARE @DryRun BIT = 1;
DECLARE @ActingUserID INT = NULL;   -- SCore.Identities.ID of the person running this (audit trail)
DECLARE @JobID INT = NULL;          -- NULL = every qualifying Job; set to try one Job first
DECLARE @StageSource NVARCHAR(10) = N'QUOTE';  -- N'QUOTE' or N'AMENDMENT' (see header)
DECLARE @AllowStageMove BIT = 0;                -- @StageSource = N'QUOTE' only

DECLARE @RetireNote NVARCHAR(400) =
    N' [Retired ' + CONVERT(NVARCHAR(10), SYSUTCDATETIME(), 23)
  + N': fee restored to the Job''s original agreed fee from the quote. This amendment had been raised because the quoted fee did not reach the Job.]';

-------------------------------------------------------------------------------
-- Preconditions
-------------------------------------------------------------------------------
IF @@TRANCOUNT > 0
BEGIN
    ;THROW 60000, N'Run this script outside a transaction.', 1;
END;

IF @StageSource IS NULL OR @StageSource NOT IN (N'QUOTE', N'AMENDMENT')
BEGIN
    ;THROW 60000, N'Set @StageSource to N''QUOTE'' or N''AMENDMENT''.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM SCore.Identities AS i
    WHERE i.ID = @ActingUserID
      AND i.ID > 0
      AND i.RowStatus NOT IN (0, 254)
)
BEGIN
    ;THROW 60000, N'Set @ActingUserID to the active SCore.Identities.ID of the person running this script.', 1;
END;

IF OBJECT_ID(N'SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems', N'P') IS NULL
BEGIN
    ;THROW 60000, N'SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems is missing. Deploy release 26.2 schema first.', 1;
END;

-- The amendment columns map to stages by RibaStages.Number (as SJob.Job_FeeDrawdown does).
IF EXISTS
(
    SELECT rs.Number
    FROM SJob.RibaStages AS rs
    WHERE rs.RowStatus NOT IN (0, 254)
      AND rs.IsCustomStage = 0
      AND rs.Number IN (0, 1, 2, 3, 4, 5, 6, 7, 99, 999)
    GROUP BY rs.Number
    HAVING COUNT(1) > 1
)
BEGIN
    ;THROW 60000, N'More than one active standard RIBA stage shares a Number; the amendment-to-stage mapping is ambiguous.', 1;
END;

DECLARE @PreviousUserID SQL_VARIANT = SESSION_CONTEXT(N'user_id');
EXEC sys.sp_set_session_context @key = N'user_id', @value = @ActingUserID, @read_only = 0;

-------------------------------------------------------------------------------
-- Candidates
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Candidates;
DROP TABLE IF EXISTS #AmendmentStages;
DROP TABLE IF EXISTS #QuoteStages;
DROP TABLE IF EXISTS #Results;

CREATE TABLE #Candidates
(
    JobID INT NOT NULL PRIMARY KEY,
    AnchorQuoteItemID BIGINT NOT NULL,
    QuoteItemTotal DECIMAL(19, 2) NOT NULL,
    AmendmentTotal DECIMAL(19, 2) NOT NULL,
    FeeAmendmentCount INT NOT NULL,
    BlockReason NVARCHAR(200) NULL
);

CREATE TABLE #AmendmentStages
(
    JobID INT NOT NULL,
    RibaStageID INT NOT NULL,
    FeeChange DECIMAL(19, 2) NOT NULL,
    PRIMARY KEY (JobID, RibaStageID)
);

CREATE TABLE #QuoteStages
(
    JobID INT NOT NULL,
    RibaStageID INT NOT NULL,
    LineNet DECIMAL(19, 2) NOT NULL,
    PRIMARY KEY (JobID, RibaStageID)
);

CREATE TABLE #Results
(
    JobID INT NOT NULL PRIMARY KEY,
    NewStageFeeTotal DECIMAL(19, 2) NULL,
    AmendmentsRetired INT NULL,
    Outcome NVARCHAR(30) NOT NULL,
    Detail NVARCHAR(4000) NULL
);

;WITH FeeCarrying AS
(
    SELECT
        fa.ID,
        fa.JobID,
        CAST
        (
              fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change
            + fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change
            + fa.PreConstructionStageChange + fa.ConstructionStageChange
            AS DECIMAL(19, 2)
        ) AS FeeChange,
        CASE
            WHEN fa.FeeCapChange <> 0
              OR fa.RibaStage0MeetingChange <> 0 OR fa.RibaStage0VisitChange <> 0
              OR fa.RibaStage1MeetingChange <> 0 OR fa.RibaStage1VisitChange <> 0
              OR fa.RibaStage2MeetingChange <> 0 OR fa.RibaStage2VisitChange <> 0
              OR fa.RibaStage3MeetingChange <> 0 OR fa.RibaStage3VisitChange <> 0
              OR fa.RibaStage4MeetingChange <> 0 OR fa.RibaStage4VisitChange <> 0
              OR fa.RibaStage5MeetingChange <> 0 OR fa.RibaStage5VisitChange <> 0
              OR fa.RibaStage6MeetingChange <> 0 OR fa.RibaStage6VisitChange <> 0
              OR fa.RibaStage7MeetingChange <> 0 OR fa.RibaStage7VisitChange <> 0
              OR fa.PreConstructionStageMeetingChange <> 0 OR fa.PreConstructionStageVisitChange <> 0
              OR fa.ConstructionStageMeetingChange <> 0 OR fa.ConstructionStageVisitChange <> 0
            THEN 1 ELSE 0
        END AS HasOtherChanges
    FROM SJob.FeeAmendment AS fa
    WHERE fa.RowStatus NOT IN (0, 254)
)
INSERT INTO #Candidates
(
    JobID,
    AnchorQuoteItemID,
    QuoteItemTotal,
    AmendmentTotal,
    FeeAmendmentCount,
    BlockReason
)
SELECT
    j.ID,
    anchor.QuoteItemID,
    quoted.QuoteItemTotal,
    amended.AmendmentTotal,
    amended.FeeAmendmentCount,
    CASE
        WHEN amended.WithOtherChanges > 0
            THEN N'A fee-carrying amendment also changes the fee cap, meetings or visits.'
        WHEN EXISTS (SELECT 1 FROM SJob.FeeAmendmentRibaStages AS fars
                     WHERE fars.JobID = j.ID AND fars.RowStatus NOT IN (0, 254))
          OR EXISTS (SELECT 1 FROM SJob.CustomFeeAmendment AS cfa
                     WHERE cfa.JobID = j.ID AND cfa.RowStatus NOT IN (0, 254))
            THEN N'The Job has stage-level or custom-stage amendment rows.'
        ELSE NULL
    END AS BlockReason
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
    -- First quote item, ordered as SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems
    -- picks its anchor.
    SELECT TOP (1)
        qi.ID AS QuoteItemID
    FROM SSop.QuoteItems AS qi
    WHERE qi.CreatedJobId = j.ID
      AND qi.RowStatus NOT IN (0, 254)
      AND qi.Quantity > 0
    ORDER BY
        qi.SortOrder,
        qi.ID
) AS anchor
CROSS APPLY
(
    SELECT
        CAST(SUM(fc.FeeChange) AS DECIMAL(19, 2)) AS AmendmentTotal,
        SUM(CASE WHEN fc.FeeChange <> 0 THEN 1 ELSE 0 END) AS FeeAmendmentCount,
        SUM(CASE WHEN fc.FeeChange <> 0 AND fc.HasOtherChanges = 1 THEN 1 ELSE 0 END) AS WithOtherChanges
    FROM FeeCarrying AS fc
    WHERE fc.JobID = j.ID
) AS amended
WHERE j.ID > 0
  AND j.RowStatus NOT IN (0, 254)
  AND (@JobID IS NULL OR j.ID = @JobID)
  AND ISNULL(j.AgreedFee, 0) + ISNULL(j.RibaStage1Fee, 0) + ISNULL(j.RibaStage2Fee, 0)
    + ISNULL(j.RibaStage3Fee, 0) + ISNULL(j.RibaStage4Fee, 0) + ISNULL(j.RibaStage5Fee, 0)
    + ISNULL(j.RibaStage6Fee, 0) + ISNULL(j.RibaStage7Fee, 0)
    + ISNULL(j.PreConstructionStageFee, 0) + ISNULL(j.ConstructionStageFee, 0) = 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM SJob.JobRibaStageFees AS jrsf
      WHERE jrsf.JobID = j.ID
        AND jrsf.RowStatus NOT IN (0, 254)
  )
  AND quoted.QuoteCount = 1
  AND ISNULL(quoted.QuoteItemTotal, 0) <> 0
  AND amended.AmendmentTotal = quoted.QuoteItemTotal;

-- What the workaround amendments put on each stage.
INSERT INTO #AmendmentStages
(
    JobID,
    RibaStageID,
    FeeChange
)
SELECT
    c.JobID,
    rs.ID,
    SUM(stage.FeeChange)
FROM #Candidates AS c
JOIN SJob.FeeAmendment AS fa
    ON fa.JobID = c.JobID
   AND fa.RowStatus NOT IN (0, 254)
CROSS APPLY
(
    VALUES
        (0, fa.RibaStage0Change), (1, fa.RibaStage1Change), (2, fa.RibaStage2Change),
        (3, fa.RibaStage3Change), (4, fa.RibaStage4Change), (5, fa.RibaStage5Change),
        (6, fa.RibaStage6Change), (7, fa.RibaStage7Change),
        (99, fa.PreConstructionStageChange), (999, fa.ConstructionStageChange)
) AS stage (StageNumber, FeeChange)
JOIN SJob.RibaStages AS rs
    ON rs.Number = stage.StageNumber
   AND rs.IsCustomStage = 0
   AND rs.RowStatus NOT IN (0, 254)
WHERE c.BlockReason IS NULL
GROUP BY
    c.JobID,
    rs.ID
HAVING SUM(stage.FeeChange) <> 0;

-- What the quote items put on each stage (-1 -> Stage 1, as job creation does).
-- Used for the report only; QUOTE mode writes through the upsert procedure.
INSERT INTO #QuoteStages
(
    JobID,
    RibaStageID,
    LineNet
)
SELECT
    c.JobID,
    CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END,
    SUM(CAST(qit.LineNet AS DECIMAL(19, 2)))
FROM #Candidates AS c
JOIN SSop.QuoteItems AS qi
    ON qi.CreatedJobId = c.JobID
   AND qi.RowStatus NOT IN (0, 254)
   AND qi.Quantity > 0
JOIN SSop.QuoteItemTotals AS qit
    ON qit.ID = qi.ID
WHERE c.BlockReason IS NULL
GROUP BY
    c.JobID,
    CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END;

INSERT INTO #Results (JobID, Outcome, Detail)
SELECT c.JobID, N'SKIPPED - BLOCKED', c.BlockReason
FROM #Candidates AS c
WHERE c.BlockReason IS NOT NULL;

-------------------------------------------------------------------------------
-- Convert, one transaction per Job
-------------------------------------------------------------------------------
DECLARE @CurrentJobID INT;
DECLARE @NewStageFeeTotal DECIMAL(19, 2);
DECLARE @StageDifferences INT;
DECLARE @Retired INT;
DECLARE @RetireGuids TABLE (Guid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY);
DECLARE @RetireGuid UNIQUEIDENTIFIER;
DECLARE @QuoteStageDifferences INT;
DECLARE @NewStageRows TABLE
(
    Guid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    RibaStageID INT NOT NULL,
    AgreedFee DECIMAL(19, 2) NOT NULL
);
DECLARE @NewStageGuids SCore.GuidUniqueList;
DECLARE @IsInsert BIT;

DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT c.JobID
    FROM #Candidates AS c
    WHERE c.BlockReason IS NULL
    ORDER BY c.JobID;

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @CurrentJobID;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Does the quote put the fee on different stages from the amendments?
    SELECT @QuoteStageDifferences = COUNT(1)
    FROM
    (
        SELECT qs.RibaStageID, qs.LineNet
        FROM #QuoteStages AS qs
        WHERE qs.JobID = @CurrentJobID
    ) AS quoted
    FULL OUTER JOIN
    (
        SELECT ams.RibaStageID, ams.FeeChange
        FROM #AmendmentStages AS ams
        WHERE ams.JobID = @CurrentJobID
    ) AS amended
        ON amended.RibaStageID = quoted.RibaStageID
    WHERE ISNULL(quoted.LineNet, 0) <> ISNULL(amended.FeeChange, 0);

    IF @StageSource = N'AMENDMENT'
       AND EXISTS
       (
           SELECT 1
           FROM #AmendmentStages AS ams
           WHERE ams.JobID = @CurrentJobID
             AND ams.FeeChange < 0
       )
    BEGIN
        INSERT INTO #Results (JobID, Outcome, Detail)
        VALUES (@CurrentJobID, N'SKIPPED - NEGATIVE STAGE',
                N'The amendments take fee off at least one stage, so they cannot be used as the original stage fees.');
    END
    ELSE
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @StageSource = N'AMENDMENT'
        BEGIN
            -- Write one stage fee row per stage the amendments put the fee on.
            DELETE FROM @NewStageRows;
            DELETE FROM @NewStageGuids;

            INSERT INTO @NewStageRows (Guid, RibaStageID, AgreedFee)
            SELECT NEWID(), ams.RibaStageID, ams.FeeChange
            FROM #AmendmentStages AS ams
            WHERE ams.JobID = @CurrentJobID;

            INSERT INTO @NewStageGuids (GuidValue)
            SELECT nsr.Guid
            FROM @NewStageRows AS nsr;

            IF EXISTS (SELECT 1 FROM @NewStageGuids)
            BEGIN
                EXEC SCore.DataObjectBulkUpsert
                     @GuidList   = @NewStageGuids,
                     @SchemeName = N'SJob',
                     @ObjectName = N'JobRibaStageFees',
                     @IsInsert   = @IsInsert OUTPUT;
            END;

            INSERT INTO SJob.JobRibaStageFees
            (
                RowStatus,
                Guid,
                JobID,
                RibaStageID,
                CreatedFromQuoteItemID,
                AgreedFee,
                CreatedDateTimeUTC,
                CreatedByUserID
            )
            SELECT
                1,
                nsr.Guid,
                c.JobID,
                nsr.RibaStageID,
                c.AnchorQuoteItemID,
                nsr.AgreedFee,
                SYSUTCDATETIME(),
                @ActingUserID
            FROM @NewStageRows AS nsr
            JOIN #Candidates AS c
                ON c.JobID = @CurrentJobID;
        END
        ELSE
        BEGIN
            EXEC SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems @JobID = @CurrentJobID;
        END;

        SELECT @NewStageFeeTotal = CAST(SUM(jrsf.AgreedFee) AS DECIMAL(19, 2))
        FROM SJob.JobRibaStageFees AS jrsf
        WHERE jrsf.JobID = @CurrentJobID
          AND jrsf.RowStatus NOT IN (0, 254);

        SELECT @StageDifferences = COUNT(1)
        FROM
        (
            SELECT jrsf.RibaStageID, SUM(jrsf.AgreedFee) AS AgreedFee
            FROM SJob.JobRibaStageFees AS jrsf
            WHERE jrsf.JobID = @CurrentJobID
              AND jrsf.RowStatus NOT IN (0, 254)
            GROUP BY jrsf.RibaStageID
        ) AS restored
        FULL OUTER JOIN
        (
            SELECT ams.RibaStageID, ams.FeeChange
            FROM #AmendmentStages AS ams
            WHERE ams.JobID = @CurrentJobID
        ) AS amended
            ON amended.RibaStageID = restored.RibaStageID
        WHERE ISNULL(restored.AgreedFee, 0) <> ISNULL(amended.FeeChange, 0);

        IF @NewStageFeeTotal IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            INSERT INTO #Results (JobID, NewStageFeeTotal, Outcome, Detail)
            VALUES (@CurrentJobID, NULL, N'SKIPPED - NO ROWS', N'No quote item resolved to a RIBA stage.');
        END
        ELSE IF @NewStageFeeTotal <> (SELECT c.AmendmentTotal FROM #Candidates AS c WHERE c.JobID = @CurrentJobID)
        BEGIN
            ROLLBACK TRANSACTION;
            INSERT INTO #Results (JobID, NewStageFeeTotal, Outcome, Detail)
            VALUES (@CurrentJobID, @NewStageFeeTotal, N'SKIPPED - TOTAL MISMATCH',
                    N'Restored stage fees (invoice schedule values) do not equal the amendment total.');
        END
        ELSE IF @StageDifferences > 0 AND @AllowStageMove = 0
        BEGIN
            ROLLBACK TRANSACTION;
            INSERT INTO #Results (JobID, NewStageFeeTotal, Outcome, Detail)
            VALUES (@CurrentJobID, @NewStageFeeTotal, N'SKIPPED - STAGE MISMATCH',
                    N'Same total, but the quote puts the fee on different stages from the amendment. Re-run with @StageSource = N''AMENDMENT'' or @AllowStageMove = 1 if accepted.');
        END
        ELSE
        BEGIN
            DELETE FROM @RetireGuids;

            INSERT INTO @RetireGuids (Guid)
            SELECT fa.Guid
            FROM SJob.FeeAmendment AS fa
            WHERE fa.JobID = @CurrentJobID
              AND fa.RowStatus NOT IN (0, 254)
              AND fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change
                + fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change
                + fa.PreConstructionStageChange + fa.ConstructionStageChange <> 0;

            DECLARE retire_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT rg.Guid FROM @RetireGuids AS rg;

            OPEN retire_cursor;
            FETCH NEXT FROM retire_cursor INTO @RetireGuid;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC SCore.DeleteDataObject @Guid = @RetireGuid;
                FETCH NEXT FROM retire_cursor INTO @RetireGuid;
            END;

            CLOSE retire_cursor;
            DEALLOCATE retire_cursor;

            UPDATE fa
            SET
                fa.RowStatus = 254,
                fa.Reason = fa.Reason + @RetireNote
            FROM SJob.FeeAmendment AS fa
            JOIN @RetireGuids AS rg
                ON rg.Guid = fa.Guid;

            SET @Retired = @@ROWCOUNT;

            IF @DryRun = 1
            BEGIN
                ROLLBACK TRANSACTION;
            END
            ELSE
            BEGIN
                COMMIT TRANSACTION;
            END;

            INSERT INTO #Results (JobID, NewStageFeeTotal, AmendmentsRetired, Outcome, Detail)
            VALUES
            (
                @CurrentJobID,
                @NewStageFeeTotal,
                @Retired,
                CASE WHEN @DryRun = 1 THEN N'WOULD CONVERT' ELSE N'CONVERTED' END,
                CASE
                    WHEN @StageSource = N'AMENDMENT' AND @QuoteStageDifferences > 0
                        THEN N'Stages taken from the amendments; the quote had the fee on different stages.'
                    WHEN @StageDifferences > 0
                        THEN N'Fee moved between stages (@AllowStageMove = 1).'
                    ELSE NULL
                END
            );
        END;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        IF CURSOR_STATUS(N'local', N'retire_cursor') >= -1
        BEGIN
            DEALLOCATE retire_cursor;
        END;

        INSERT INTO #Results (JobID, Outcome, Detail)
        VALUES (@CurrentJobID, N'FAILED', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM job_cursor INTO @CurrentJobID;
END;

CLOSE job_cursor;
DEALLOCATE job_cursor;

EXEC sys.sp_set_session_context @key = N'user_id', @value = @PreviousUserID, @read_only = 0;

-------------------------------------------------------------------------------
-- Report
-------------------------------------------------------------------------------
SELECT
    r.Outcome,
    COUNT(1) AS Jobs,
    SUM(c.AmendmentTotal) AS FeeValue
FROM #Results AS r
JOIN #Candidates AS c
    ON c.JobID = r.JobID
GROUP BY r.Outcome
ORDER BY r.Outcome;

SELECT
    r.JobID,
    j.Number AS JobNumber,
    c.QuoteItemTotal,
    c.AmendmentTotal,
    r.NewStageFeeTotal,
    c.FeeAmendmentCount,
    r.AmendmentsRetired,
    r.Outcome,
    r.Detail
FROM #Results AS r
JOIN #Candidates AS c
    ON c.JobID = r.JobID
JOIN SJob.Jobs AS j
    ON j.ID = r.JobID
ORDER BY
    r.Outcome,
    r.JobID;
