SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuoteCreateJobs_WithInvoiceScheduleStageValidation]')
GO

CREATE PROCEDURE [SSop].[QuoteCreateJobs_WithInvoiceScheduleStageValidation]
(
    @Guid UNIQUEIDENTIFIER,
    @AllowQuoteItemStageFallback BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @QuoteID INT = -1;

    SELECT
        @QuoteID = q.ID
    FROM SSop.Quotes AS q
    WHERE q.Guid = @Guid
      AND q.RowStatus NOT IN (0, 254);

    IF @QuoteID <= 0
    BEGIN
        ;THROW 60000, N'Cannot create jobs because the supplied Quote Guid was not found or is inactive.', 1;
    END;

    EXEC SSop.QuoteCreateJobsStageScheduleAssert
         @Guid = @Guid,
         @AllowQuoteItemStageFallback = @AllowQuoteItemStageFallback;

    -------------------------------------------------------------------------
    -- Existing quote-to-job creation uses SSop.Quote_JobsSummary, which treats
    -- CreatedJobId < 0 as "not yet created". Some UI paths save the empty
    -- Created Job field as 0. Job IDs are positive, so 0 is normalised to -1
    -- for the current quote only before calling the existing creation proc.
    -------------------------------------------------------------------------
    UPDATE qi
    SET
        qi.CreatedJobId = -1
    FROM SSop.QuoteItems AS qi
    WHERE qi.QuoteId = @QuoteID
      AND qi.RowStatus NOT IN (0, 254)
      AND qi.Quantity > 0
      AND ISNULL(qi.CreatedJobId, 0) = 0;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SSop.Quote_JobsSummary AS js
        WHERE js.QuoteGuid = @Guid
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM SSop.QuoteItems AS qi
            WHERE qi.QuoteId = @QuoteID
              AND qi.RowStatus NOT IN (0, 254)
              AND qi.Quantity > 0
              AND qi.CreatedJobId > 0
        )
        BEGIN
            ;THROW 60000, N'There were no new jobs to create because all eligible quote items already have a created job.', 1;
        END;

        ;THROW 60000, N'There were no new jobs to create. Check that the quote item Product creates a Job Type, Quantity is greater than zero, and Do Not Consolidate Job is set correctly.', 1;
    END;

    EXEC SSop.QuoteCreateJobs
         @Guid = @Guid;

    -------------------------------------------------------------------------
    -- Recalculate the dynamic Job Fee/RIBA Stage rows for every active job
    -- linked back to the quote items after conversion.
    -------------------------------------------------------------------------
    DECLARE @JobsToRefresh TABLE
    (
        JobID INT NOT NULL PRIMARY KEY
    );

    INSERT INTO @JobsToRefresh
    (
        JobID
    )
    SELECT DISTINCT
        qi.CreatedJobId AS JobID
    FROM SSop.QuoteItems AS qi
    JOIN SJob.Jobs AS j
        ON j.ID = qi.CreatedJobId
    WHERE qi.QuoteId = @QuoteID
      AND qi.RowStatus NOT IN (0, 254)
      AND qi.CreatedJobId > 0
      AND j.RowStatus NOT IN (0, 254);

    DECLARE @CurrentJobID INT;

    WHILE EXISTS
    (
        SELECT 1
        FROM @JobsToRefresh
    )
    BEGIN
        SELECT TOP (1)
            @CurrentJobID = jtr.JobID
        FROM @JobsToRefresh AS jtr
        ORDER BY
            jtr.JobID;

        EXEC SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems
             @JobID = @CurrentJobID;

        DELETE FROM @JobsToRefresh
        WHERE JobID = @CurrentJobID;
    END;
END;
GO