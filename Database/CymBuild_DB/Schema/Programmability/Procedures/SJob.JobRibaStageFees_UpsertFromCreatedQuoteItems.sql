SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[JobRibaStageFees_UpsertFromCreatedQuoteItems]')
GO
PRINT (N'Create procedure [SJob].[JobRibaStageFees_UpsertFromCreatedQuoteItems]')
GO

CREATE PROCEDURE [SJob].[JobRibaStageFees_UpsertFromCreatedQuoteItems]
(
    @JobID INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SJob.Jobs AS j
        WHERE j.ID = @JobID
          AND j.RowStatus NOT IN (0, 254)
    )
    BEGIN
        ;THROW 60000, N'Cannot upsert dynamic job RIBA stage fees because the supplied JobID is not active.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.EntityHobts AS eh
        JOIN SCore.EntityTypes AS et
            ON et.ID = eh.EntityTypeID
        WHERE eh.SchemaName = N'SJob'
          AND eh.ObjectName = N'JobRibaStageFees'
          AND eh.RowStatus NOT IN (0, 254)
          AND et.RowStatus NOT IN (0, 254)
    )
    BEGIN
        ;THROW 60000, N'SJob.JobRibaStageFees metadata is missing. Deploy the source-controlled HoBT/EntityType metadata before recalculating Job RIBA stage fees.', 1;
    END;

    IF COL_LENGTH(N'SFin.InvoiceScheduleMonthConfiguration', N'RIBAStageId') IS NULL
    BEGIN
        ;THROW 60000, N'SFin.InvoiceScheduleMonthConfiguration.RIBAStageId is missing. Deploy the source-controlled schema before recalculating Job RIBA stage fees.', 1;
    END;

    IF COL_LENGTH(N'SFin.InvoiceSchedulePercentageConfiguration', N'RIBAStageId') IS NULL
    BEGIN
        ;THROW 60000, N'SFin.InvoiceSchedulePercentageConfiguration.RIBAStageId is missing. Deploy the source-controlled schema before recalculating Job RIBA stage fees.', 1;
    END;

    IF COL_LENGTH(N'SFin.InvoiceSchedulePercentageConfiguration', N'Percentage') IS NULL
    BEGIN
        ;THROW 60000, N'SFin.InvoiceSchedulePercentageConfiguration.Percentage is missing. Deploy the source-controlled schema before recalculating Job RIBA stage fees.', 1;
    END;

    DECLARE @CurrentUserID INT = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);
    DECLARE @GuidList SCore.GuidUniqueList;
    DECLARE @IsInsert BIT = 0;
    DECLARE @StartedTransaction BIT = 0;
    DECLARE @AnchorQuoteItemID INT;

    DECLARE @SelectedQuoteItems TABLE
    (
        QuoteItemID INT NOT NULL PRIMARY KEY,
        QuoteId INT NOT NULL,
        InvoiceScheduleID INT NOT NULL,
        RibaStageID INT NOT NULL,
        LineNet DECIMAL(19, 2) NOT NULL,
        SortOrder INT NOT NULL
    );

    DECLARE @InvoiceScheduleStages TABLE
    (
        RibaStageID INT NOT NULL PRIMARY KEY,
        StageScheduleTotal DECIMAL(19, 2) NOT NULL
    );

    DECLARE @QuoteItemStageTotals TABLE
    (
        RibaStageID INT NOT NULL PRIMARY KEY,
        CreatedFromQuoteItemID INT NOT NULL,
        QuoteItemStageTotal DECIMAL(19, 2) NOT NULL
    );

    DECLARE @StageFees TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        JobID INT NOT NULL,
        RibaStageID INT NOT NULL PRIMARY KEY,
        CreatedFromQuoteItemID INT NOT NULL,
        AgreedFee DECIMAL(19, 2) NOT NULL
    );

    INSERT INTO @SelectedQuoteItems
    (
        QuoteItemID,
        QuoteId,
        InvoiceScheduleID,
        RibaStageID,
        LineNet,
        SortOrder
    )
    SELECT
        CONVERT(INT, qi.ID) AS QuoteItemID,
        qi.QuoteId,
        qi.InvoicingSchedule AS InvoiceScheduleID,
        CASE
            WHEN qi.ProvideAtStageID = -1 THEN 2
            ELSE qi.ProvideAtStageID
        END AS RibaStageID,
        CONVERT(DECIMAL(19, 2), qit.LineNet) AS LineNet,
        qi.SortOrder
    FROM SSop.QuoteItems AS qi
    JOIN SSop.QuoteItemTotals AS qit
        ON qit.ID = qi.ID
    WHERE qi.CreatedJobId = @JobID
      AND qi.RowStatus NOT IN (0, 254)
      AND qi.Quantity > 0
      AND CASE
              WHEN qi.ProvideAtStageID = -1 THEN 2
              ELSE qi.ProvideAtStageID
          END > 0;

    IF NOT EXISTS
    (
        SELECT 1
        FROM @SelectedQuoteItems
    )
    BEGIN
        RETURN;
    END;

    SELECT TOP (1)
        @AnchorQuoteItemID = sqi.QuoteItemID
    FROM @SelectedQuoteItems AS sqi
    ORDER BY
        sqi.SortOrder,
        sqi.QuoteItemID;

    ;WITH SelectedSchedules AS
    (
        SELECT DISTINCT
            sqi.QuoteId,
            sqi.InvoiceScheduleID
        FROM @SelectedQuoteItems AS sqi
        WHERE sqi.InvoiceScheduleID > 0
    ),
    ScheduleStageTotals AS
    (
        SELECT
            monthconf.RIBAStageId AS RibaStageID,
            SUM(CONVERT(DECIMAL(19, 2), monthconf.Amount)) AS StageScheduleTotal
        FROM SelectedSchedules AS ss
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = ss.InvoiceScheduleID
           AND sch.QuoteId = ss.QuoteId
        JOIN SFin.InvoiceScheduleMonthConfiguration AS monthconf
            ON monthconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0, 254)
          AND monthconf.RowStatus NOT IN (0, 254)
          AND monthconf.RIBAStageId > 0
        GROUP BY
            monthconf.RIBAStageId

        UNION ALL

        SELECT
            percentconf.RIBAStageId AS RibaStageID,
            SUM
            (
                CONVERT
                (
                    DECIMAL(19, 2),
                    ROUND
                    (
                        sch.Amount * (percentconf.Percentage / CONVERT(DECIMAL(19, 2), 100.00)),
                        2
                    )
                )
            ) AS StageScheduleTotal
        FROM SelectedSchedules AS ss
        JOIN SFin.InvoiceSchedules AS sch
            ON sch.ID = ss.InvoiceScheduleID
           AND sch.QuoteId = ss.QuoteId
        JOIN SFin.InvoiceSchedulePercentageConfiguration AS percentconf
            ON percentconf.InvoiceScheduleId = sch.ID
        WHERE sch.RowStatus NOT IN (0, 254)
          AND percentconf.RowStatus NOT IN (0, 254)
          AND percentconf.RIBAStageId > 0
        GROUP BY
            percentconf.RIBAStageId
    )
    INSERT INTO @InvoiceScheduleStages
    (
        RibaStageID,
        StageScheduleTotal
    )
    SELECT
        sst.RibaStageID,
        SUM(sst.StageScheduleTotal) AS StageScheduleTotal
    FROM ScheduleStageTotals AS sst
    GROUP BY
        sst.RibaStageID;

    ;WITH StageAnchors AS
    (
        SELECT
            sqi.RibaStageID,
            sqi.QuoteItemID,
            ROW_NUMBER() OVER
            (
                PARTITION BY sqi.RibaStageID
                ORDER BY sqi.SortOrder, sqi.QuoteItemID
            ) AS RowNumber
        FROM @SelectedQuoteItems AS sqi
    )
    INSERT INTO @QuoteItemStageTotals
    (
        RibaStageID,
        CreatedFromQuoteItemID,
        QuoteItemStageTotal
    )
    SELECT
        sqi.RibaStageID,
        sa.QuoteItemID AS CreatedFromQuoteItemID,
        SUM(sqi.LineNet) AS QuoteItemStageTotal
    FROM @SelectedQuoteItems AS sqi
    JOIN StageAnchors AS sa
        ON sa.RibaStageID = sqi.RibaStageID
       AND sa.RowNumber = 1
    GROUP BY
        sqi.RibaStageID,
        sa.QuoteItemID;

    ;WITH RequiredStages AS
    (
        SELECT
            qist.RibaStageID,
            qist.CreatedFromQuoteItemID,
            CASE
                WHEN iss.StageScheduleTotal IS NOT NULL THEN iss.StageScheduleTotal
                ELSE qist.QuoteItemStageTotal
            END AS AgreedFee
        FROM @QuoteItemStageTotals AS qist
        LEFT JOIN @InvoiceScheduleStages AS iss
            ON iss.RibaStageID = qist.RibaStageID

        UNION ALL

        SELECT
            iss.RibaStageID,
            @AnchorQuoteItemID AS CreatedFromQuoteItemID,
            iss.StageScheduleTotal AS AgreedFee
        FROM @InvoiceScheduleStages AS iss
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM @QuoteItemStageTotals AS qist
            WHERE qist.RibaStageID = iss.RibaStageID
        )
    )
    INSERT INTO @StageFees
    (
        Guid,
        JobID,
        RibaStageID,
        CreatedFromQuoteItemID,
        AgreedFee
    )
    SELECT
        ISNULL(existing.Guid, NEWID()) AS Guid,
        @JobID AS JobID,
        rs.RibaStageID,
        rs.CreatedFromQuoteItemID,
        CONVERT(DECIMAL(19, 2), rs.AgreedFee) AS AgreedFee
    FROM RequiredStages AS rs
    OUTER APPLY
    (
        SELECT TOP (1)
            jrsf.Guid
        FROM SJob.JobRibaStageFees AS jrsf
        WHERE jrsf.JobID = @JobID
          AND jrsf.RibaStageID = rs.RibaStageID
          AND jrsf.RowStatus NOT IN (0, 254)
        ORDER BY
            jrsf.ID
    ) AS existing;

    IF NOT EXISTS
    (
        SELECT 1
        FROM @StageFees
    )
    BEGIN
        RETURN;
    END;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END;

        INSERT INTO @GuidList
        (
            GuidValue
        )
        SELECT
            sf.Guid
        FROM @StageFees AS sf
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.DataObjects AS d
            WHERE d.Guid = sf.Guid
        );

        IF EXISTS
        (
            SELECT 1
            FROM @GuidList
        )
        BEGIN
            EXEC SCore.DataObjectBulkUpsert
                 @GuidList   = @GuidList,
                 @SchemeName = N'SJob',
                 @ObjectName = N'JobRibaStageFees',
                 @IsInsert   = @IsInsert OUTPUT;
        END;

        ---------------------------------------------------------------------
        -- Previous versions could create more than one active row for the same
        -- Job/RIBA stage when multiple QuoteItems shared a stage. The new
        -- business rule produces one Job fee row per stage, so keep the first
        -- active row and retire any additional active rows before applying the
        -- recalculated value.
        ---------------------------------------------------------------------
        ;WITH ActiveRowsForRecalculatedStages AS
        (
            SELECT
                target.ID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        target.JobID,
                        target.RibaStageID
                    ORDER BY
                        CASE
                            WHEN target.Guid = sf.Guid THEN 0
                            ELSE 1
                        END,
                        target.ID
                ) AS RowNumber
            FROM SJob.JobRibaStageFees AS target
            JOIN @StageFees AS sf
                ON sf.JobID = target.JobID
               AND sf.RibaStageID = target.RibaStageID
            WHERE target.RowStatus NOT IN (0, 254)
        )
        UPDATE target
        SET
            target.RowStatus = 254,
            target.LastUpdatedDateTimeUTC = SYSUTCDATETIME(),
            target.LastUpdatedByUserID = @CurrentUserID
        FROM SJob.JobRibaStageFees AS target
        JOIN ActiveRowsForRecalculatedStages AS activeRows
            ON activeRows.ID = target.ID
        WHERE activeRows.RowNumber > 1;

        UPDATE target
        SET
            target.RowStatus = 1,
            target.JobID = sf.JobID,
            target.RibaStageID = sf.RibaStageID,
            target.CreatedFromQuoteItemID = sf.CreatedFromQuoteItemID,
            target.AgreedFee = sf.AgreedFee,
            target.LastUpdatedDateTimeUTC = SYSUTCDATETIME(),
            target.LastUpdatedByUserID = @CurrentUserID
        FROM SJob.JobRibaStageFees AS target
        JOIN @StageFees AS sf
            ON sf.JobID = target.JobID
           AND sf.RibaStageID = target.RibaStageID
        WHERE target.RowStatus NOT IN (0, 254)
          AND
          (
                 target.CreatedFromQuoteItemID <> sf.CreatedFromQuoteItemID
              OR target.AgreedFee <> sf.AgreedFee
              OR target.RowStatus <> 1
          );

        INSERT INTO SJob.JobRibaStageFees
        (
            RowStatus,
            Guid,
            JobID,
            RibaStageID,
            CreatedFromQuoteItemID,
            AgreedFee,
            CreatedDateTimeUTC,
            CreatedByUserID,
            LastUpdatedDateTimeUTC,
            LastUpdatedByUserID
        )
        SELECT
            1 AS RowStatus,
            sf.Guid,
            sf.JobID,
            sf.RibaStageID,
            sf.CreatedFromQuoteItemID,
            sf.AgreedFee,
            SYSUTCDATETIME() AS CreatedDateTimeUTC,
            @CurrentUserID AS CreatedByUserID,
            NULL AS LastUpdatedDateTimeUTC,
            NULL AS LastUpdatedByUserID
        FROM @StageFees AS sf
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SJob.JobRibaStageFees AS existing
            WHERE existing.JobID = sf.JobID
              AND existing.RibaStageID = sf.RibaStageID
              AND existing.RowStatus NOT IN (0, 254)
        );

        IF @StartedTransaction = 1
        BEGIN
            COMMIT TRANSACTION;
        END;
    END TRY
    BEGIN CATCH
        IF @StartedTransaction = 1
           AND XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;
GO