SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;
	
	DBCC CHECKIDENT ('SCore.WorkflowStatus', RESEED);

    PRINT '=================================================';
    PRINT 'WorkflowStatus canonicalisation (merged script)';
    PRINT '=================================================';

    -------------------------------------------------------------------------
    -- QUOTES: normalise casing variants
    -------------------------------------------------------------------------
    UPDATE ws
    SET ws.Name = N'Ready to Send'
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name IN (N'Ready To Send', N'Ready to send');

    -------------------------------------------------------------------------
    -- QUOTES: Merge "Is Final (Ready To Send)" -> "Ready to Send"
    -------------------------------------------------------------------------
    DECLARE @QuoteReadyToSend_CanonicalId INT = NULL;
    DECLARE @QuoteReadyToSend_LegacyId    INT = NULL;

    SELECT TOP (1) @QuoteReadyToSend_CanonicalId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Ready to Send'
    ORDER BY ws.ID;

    SELECT TOP (1) @QuoteReadyToSend_LegacyId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Is Final (Ready To Send)'
    ORDER BY ws.ID;

    IF @QuoteReadyToSend_LegacyId IS NOT NULL
    BEGIN
        IF @QuoteReadyToSend_CanonicalId IS NULL
        BEGIN
            UPDATE SCore.WorkflowStatus
            SET Name = N'Ready to Send'
            WHERE ID = @QuoteReadyToSend_LegacyId;

            PRINT 'Renamed Quote: "Is Final (Ready To Send)" -> "Ready to Send" (no canonical existed)';
        END
        ELSE
        BEGIN
            UPDATE dot
            SET dot.StatusID = @QuoteReadyToSend_CanonicalId
            FROM SCore.DataObjectTransition dot
            WHERE dot.RowStatus NOT IN (0,254)
              AND dot.StatusID = @QuoteReadyToSend_LegacyId;

            UPDATE SCore.WorkflowStatus
            SET RowStatus = 254
            WHERE ID = @QuoteReadyToSend_LegacyId;

            PRINT 'Merged Quote: migrated transitions from "Is Final (Ready To Send)" -> "Ready to Send" and archived legacy';
        END
    END

    -------------------------------------------------------------------------
    -- QUOTES: Merge "Declined To Quote" -> "Declined"
    -------------------------------------------------------------------------
    DECLARE @QuoteDeclined_CanonicalId INT = NULL;
    DECLARE @QuoteDeclined_LegacyId    INT = NULL;

    SELECT TOP (1) @QuoteDeclined_CanonicalId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Declined'
    ORDER BY ws.ID;

    SELECT TOP (1) @QuoteDeclined_LegacyId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Declined To Quote'
    ORDER BY ws.ID;

    IF @QuoteDeclined_LegacyId IS NOT NULL
    BEGIN
        IF @QuoteDeclined_CanonicalId IS NULL
        BEGIN
            UPDATE SCore.WorkflowStatus
            SET Name = N'Declined'
            WHERE ID = @QuoteDeclined_LegacyId;

            PRINT 'Renamed Quote: "Declined To Quote" -> "Declined" (no canonical existed)';
        END
        ELSE
        BEGIN
            UPDATE dot
            SET dot.StatusID = @QuoteDeclined_CanonicalId
            FROM SCore.DataObjectTransition dot
            WHERE dot.RowStatus NOT IN (0,254)
              AND dot.StatusID = @QuoteDeclined_LegacyId;

            UPDATE SCore.WorkflowStatus
            SET RowStatus = 254
            WHERE ID = @QuoteDeclined_LegacyId;

            PRINT 'Merged Quote: migrated transitions from "Declined To Quote" -> "Declined" and archived legacy';
        END
    END

    -------------------------------------------------------------------------
    -- QUOTES: De-dupe "Ready to Send" (keep lowest ID, migrate transitions)
    -------------------------------------------------------------------------
    DECLARE @QuoteReadyToSend_DupeId INT = NULL;

    SELECT TOP (1) @QuoteReadyToSend_CanonicalId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Ready to Send'
    ORDER BY ws.ID;

    SELECT TOP (1) @QuoteReadyToSend_DupeId = x.ID
    FROM
    (
        SELECT ws.ID,
               rn = ROW_NUMBER() OVER (ORDER BY ws.ID)
        FROM SCore.WorkflowStatus ws
        WHERE ws.RowStatus NOT IN (0,254)
          AND ws.ShowInQuotes = 1
          AND ws.Name = N'Ready to Send'
    ) x
    WHERE x.rn >= 2
    ORDER BY x.ID;

    WHILE @QuoteReadyToSend_CanonicalId IS NOT NULL AND @QuoteReadyToSend_DupeId IS NOT NULL
    BEGIN
        UPDATE dot
        SET dot.StatusID = @QuoteReadyToSend_CanonicalId
        FROM SCore.DataObjectTransition dot
        WHERE dot.RowStatus NOT IN (0,254)
          AND dot.StatusID = @QuoteReadyToSend_DupeId;

        UPDATE SCore.WorkflowStatus
        SET RowStatus = 254
        WHERE ID = @QuoteReadyToSend_DupeId;

        PRINT 'Archived duplicate Quote "Ready to Send" (migrated transitions to canonical).';

        SELECT TOP (1) @QuoteReadyToSend_DupeId = x.ID
        FROM
        (
            SELECT ws.ID,
                   rn = ROW_NUMBER() OVER (ORDER BY ws.ID)
            FROM SCore.WorkflowStatus ws
            WHERE ws.RowStatus NOT IN (0,254)
              AND ws.ShowInQuotes = 1
              AND ws.Name = N'Ready to Send'
        ) x
        WHERE x.rn >= 2
        ORDER BY x.ID;
    END

    -------------------------------------------------------------------------
    -- QUOTES: Ensure "Quoting" exists (auto-generated)
    -------------------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.WorkflowStatus
        WHERE RowStatus NOT IN (0,254)
          AND ShowInQuotes = 1
          AND Name = N'Quoting'
    )
    BEGIN
        DECLARE @QuotingStatusGuidForQuotes UNIQUEIDENTIFIER = NEWID();

        EXEC [SCore].[WorkflowStatusUpsert]
            @QuotingStatusGuidForQuotes,
            1,
            N'Quoting',
            N'Automatically generated status',
            '00000000-0000-0000-0000-000000000000',
            -1,
            0,
            1,
            0,   -- ShowInEnq  (IMPORTANT)
            1,   -- ShowInQuotes
            0,   -- ShowInJobs
            1,
            0,
            0,
            N'#000000',
            N'bi-gear',
            0;

        PRINT 'Created Quote status: "Quoting".';
    END
    ELSE
        PRINT 'Quote status "Quoting" already exists.';

    -------------------------------------------------------------------------
    -- JOBS: restore the "script 1" mistake case + ensure New + Job Started
    -------------------------------------------------------------------------
    UPDATE ws
    SET ws.Name = N'Job Started'
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'New'
      AND ws.Description = N'The job has been started.';

    IF @@ROWCOUNT > 0
        PRINT 'Restored Job status: "New" [The job has been started.] -> "Job Started"';

    ;WITH JobNew AS
    (
        SELECT
            ws.ID,
            ws.Description,
            rn = ROW_NUMBER() OVER
                 (ORDER BY CASE WHEN ws.Description = N'Automatically generated status' THEN 0 ELSE 1 END, ws.ID)
        FROM SCore.WorkflowStatus ws
        WHERE ws.RowStatus NOT IN (0,254)
          AND ws.ShowInJobs = 1
          AND ws.Name = N'New'
    )
    UPDATE ws
    SET ws.Name = N'Job Started'
    FROM SCore.WorkflowStatus ws
    JOIN JobNew jn ON jn.ID = ws.ID
    WHERE jn.rn >= 2;

    DECLARE @JobNew_AutoId  INT = NULL;
    DECLARE @JobStartedId   INT = NULL;

    SELECT TOP (1) @JobNew_AutoId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'New'
      AND ws.Description = N'Automatically generated status'
    ORDER BY ws.ID;

    IF (@JobNew_AutoId IS NULL)
    BEGIN
        DECLARE @NewStatusGuidForJobs UNIQUEIDENTIFIER = NEWID();

        EXEC [SCore].[WorkflowStatusUpsert]
            @NewStatusGuidForJobs,
            1,
            N'New',
            N'Automatically generated status',
            '00000000-0000-0000-0000-000000000000',
            -1,
            0,
            1,
            0,  -- ShowInEnq (IMPORTANT)
            0,
            1,
            1,
            0,
            0,
            N'#000000',
            N'bi-gear',
            0;

        PRINT 'Created Job status: "New" (auto-generated).';
    END

    SELECT TOP (1) @JobStartedId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'Job Started'
    ORDER BY ws.ID;

    IF (@JobStartedId IS NULL)
    BEGIN
        DECLARE @JobStartedGuid UNIQUEIDENTIFIER = NEWID();

        EXEC [SCore].[WorkflowStatusUpsert]
            @JobStartedGuid,
            1,
            N'Job Started',
            N'The job has been started.',
            '00000000-0000-0000-0000-000000000000',
            -1,
            0,
            1,
            0,  -- ShowInEnq (IMPORTANT)
            0,
            1,
            1,
            0,
            0,
            N'#000000',
            N'bi-play',
            0;

        PRINT 'Created Job status: "Job Started".';
    END

    -------------------------------------------------------------------------
    -- CRITICAL: Scope flag corrections (THIS fixes your Enquiry duplicates)
    -------------------------------------------------------------------------

    -- Jobs must NOT appear in Enquiries/Quotes lists
    UPDATE ws
    SET ws.ShowInEnquiries = 0,
        ws.ShowInQuotes    = 0,
        ws.ShowInJobs      = 1
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name IN (N'New', N'Job Started');

    -- Quotes-only "Quoting" must NOT appear in Enquiries/Jobs lists
    UPDATE ws
    SET ws.ShowInEnquiries = 0,
        ws.ShowInJobs      = 0,
        ws.ShowInQuotes    = 1
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Quoting';

    -- Quotes-only "Ready to Send" and "Declined" must NOT appear in Enquiries/Jobs lists
    UPDATE ws
    SET ws.ShowInEnquiries = 0,
        ws.ShowInJobs      = 0,
        ws.ShowInQuotes    = 1
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name IN (N'Ready to Send', N'Declined');

    -------------------------------------------------------------------------
    -- Final de-dupe: archive extra Job "New" rows (keep lowest ID)
    -------------------------------------------------------------------------
    DECLARE @JobNewCanonicalId INT = NULL;
    DECLARE @JobNewDupeId INT = NULL;

    SELECT TOP (1) @JobNewCanonicalId = ws.ID
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'New'
    ORDER BY ws.ID;

    SELECT TOP (1) @JobNewDupeId = x.ID
    FROM
    (
        SELECT ws.ID,
               rn = ROW_NUMBER() OVER (ORDER BY ws.ID)
        FROM SCore.WorkflowStatus ws
        WHERE ws.RowStatus NOT IN (0,254)
          AND ws.ShowInJobs = 1
          AND ws.Name = N'New'
    ) x
    WHERE x.rn >= 2
    ORDER BY x.ID;

    WHILE @JobNewCanonicalId IS NOT NULL AND @JobNewDupeId IS NOT NULL
    BEGIN
        UPDATE dot
        SET dot.StatusID = @JobNewCanonicalId
        FROM SCore.DataObjectTransition dot
        WHERE dot.RowStatus NOT IN (0,254)
          AND dot.StatusID = @JobNewDupeId;

        UPDATE SCore.WorkflowStatus
        SET RowStatus = 254
        WHERE ID = @JobNewDupeId;

        PRINT 'Archived duplicate Job "New" (migrated transitions to canonical).';

        SELECT TOP (1) @JobNewDupeId = x.ID
        FROM
        (
            SELECT ws.ID,
                   rn = ROW_NUMBER() OVER (ORDER BY ws.ID)
            FROM SCore.WorkflowStatus ws
            WHERE ws.RowStatus NOT IN (0,254)
              AND ws.ShowInJobs = 1
              AND ws.Name = N'New'
        ) x
        WHERE x.rn >= 2
        ORDER BY x.ID;
    END
	
	DBCC CHECKIDENT ('SCore.WorkflowStatus', RESEED);

    COMMIT TRANSACTION;
    PRINT 'Completed successfully.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

    DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
    PRINT 'Failed. Rolling back.';
    THROW 60000, @Err, 1;
END CATCH;
GO

