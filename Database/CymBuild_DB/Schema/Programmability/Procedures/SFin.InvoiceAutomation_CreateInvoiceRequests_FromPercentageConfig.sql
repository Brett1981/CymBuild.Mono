SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]')
GO

CREATE PROCEDURE [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]
(
      @AutomationRunGuid         UNIQUEIDENTIFIER
    , @RequesterUserGuid         UNIQUEIDENTIFIER
    , @DefaultPaymentStatusGuid  UNIQUEIDENTIFIER = NULL
    , @NowUtc                    DATETIME2(7) = NULL
    , @MaxAttempts               INT = 5

    , @CreatedInvoiceRequests    INT = 0 OUTPUT
    , @Attempt                   INT = NULL OUTPUT
    , @CreatedAtUtc              DATETIME2(7) = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    /* IMPORTANT: avoid dooming outer execution context */
    SET XACT_ABORT OFF;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());
    SET @CreatedAtUtc = @NowUtcEff;
    SET @CreatedInvoiceRequests = 0;

    /* Resolve RequesterUserId */
    DECLARE @RequesterUserId INT;
    SELECT @RequesterUserId = i.ID
    FROM SCore.Identities i
    WHERE i.Guid = @RequesterUserGuid;

    IF (@RequesterUserId IS NULL)
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END

    /* Resolve default payment status ID */
    DECLARE @DefaultPaymentStatusId BIGINT;

    IF (@DefaultPaymentStatusGuid IS NOT NULL)
    BEGIN
        SELECT @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus ps
        WHERE ps.Guid = @DefaultPaymentStatusGuid
          AND ps.RowStatus NOT IN (0,254);
    END
    ELSE
    BEGIN
        SELECT TOP (1) @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus ps
        WHERE ps.RowStatus NOT IN (0,254)
        ORDER BY ps.ID ASC;
    END

    IF (@DefaultPaymentStatusId IS NULL)
    BEGIN
        RAISERROR(N'No active InvoicePaymentStatus row found (and/or DefaultPaymentStatusGuid invalid).', 16, 1);
        RETURN;
    END

    DECLARE @LocalAttempt INT = 0;

    WHILE (1=1)
    BEGIN
        SET @LocalAttempt += 1;
        SET @Attempt = @LocalAttempt;

        BEGIN TRY
            IF OBJECT_ID('tempdb..#Candidates') IS NOT NULL DROP TABLE #Candidates;
            IF OBJECT_ID('tempdb..#ToCreate') IS NOT NULL DROP TABLE #ToCreate;
            IF OBJECT_ID('tempdb..#InsertedRequests') IS NOT NULL DROP TABLE #InsertedRequests;
            IF OBJECT_ID('tempdb..#ItemsToCreate') IS NOT NULL DROP TABLE #ItemsToCreate;

            CREATE TABLE #Candidates
            (
                  InvoiceScheduleId        INT              NOT NULL
                , JobId                   INT              NOT NULL
                , PercentageConfigId      INT              NOT NULL
                , PercentageConfigGuid    UNIQUEIDENTIFIER  NOT NULL
                , PeriodNumber            INT              NOT NULL
                , Percentage              DECIMAL(19,2)     NOT NULL
                , OnDayOfMonth            DATE             NULL
                , Description             NVARCHAR(MAX)     NOT NULL
            );

            ;WITH ScheduleJobScope AS
            (
                SELECT DISTINCT
                      qi.InvoicingSchedule AS InvoiceScheduleId
                    , qi.CreatedJobId      AS JobId
                FROM SSop.QuoteItems qi
                JOIN SFin.InvoiceSchedules sch
                    ON sch.ID = qi.InvoicingSchedule
                WHERE
                    qi.RowStatus NOT IN (0,254)
                    AND sch.RowStatus NOT IN (0,254)
                    AND qi.CreatedJobId NOT IN (-1,0)
                    AND qi.InvoicingSchedule NOT IN (-1,0)
            )
            INSERT #Candidates
            (
                  InvoiceScheduleId
                , JobId
                , PercentageConfigId
                , PercentageConfigGuid
                , PeriodNumber
                , Percentage
                , OnDayOfMonth
                , Description
            )
            SELECT
                  sjs.InvoiceScheduleId
                , sjs.JobId
                , pc.ID
                , pc.Guid
                , pc.PeriodNumber
                , pc.Percentage
                , pc.OnDayOfMonth
                , pc.Description
            FROM ScheduleJobScope sjs
            JOIN SFin.InvoiceSchedulePercentageConfiguration pc
                ON pc.InvoiceScheduleId = sjs.InvoiceScheduleId
               AND pc.RowStatus NOT IN (0,254)
            JOIN SFin.vw_InvoiceAutomation_BlockingDiagnostics bd
                ON bd.InvoiceScheduleId = sjs.InvoiceScheduleId
               AND bd.JobId = sjs.JobId
            WHERE
                bd.IsBlocked = 0
                AND pc.OnDayOfMonth IS NOT NULL
                AND pc.OnDayOfMonth <= CAST(@NowUtcEff AS DATE);

            /* Nothing due */
            IF NOT EXISTS (SELECT 1 FROM #Candidates)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END

            CREATE TABLE #ToCreate
            (
                  InvoiceScheduleId        INT              NOT NULL
                , JobId                   INT              NOT NULL
                , PercentageConfigId      INT              NOT NULL
                , PercentageConfigGuid    UNIQUEIDENTIFIER  NOT NULL
                , PeriodNumber            INT              NOT NULL
                , Percentage              DECIMAL(19,2)     NOT NULL
                , OnDayOfMonth            DATE             NOT NULL
                , Description             NVARCHAR(MAX)     NOT NULL
                , BaseAmount              DECIMAL(19,2)     NULL
                , CalculatedNet           DECIMAL(19,2)     NOT NULL
                , NeedsReconciliation     BIT              NOT NULL
                , NewInvoiceRequestGuid   UNIQUEIDENTIFIER  NOT NULL
            );

            INSERT #ToCreate
            (
                  InvoiceScheduleId, JobId,
                  PercentageConfigId, PercentageConfigGuid,
                  PeriodNumber, Percentage, OnDayOfMonth, Description,
                  BaseAmount, CalculatedNet, NeedsReconciliation,
                  NewInvoiceRequestGuid
            )
            SELECT
                  c.InvoiceScheduleId
                , c.JobId
                , c.PercentageConfigId
                , c.PercentageConfigGuid
                , c.PeriodNumber
                , c.Percentage
                , c.OnDayOfMonth
                , c.Description
                , BaseAmount =
                    CASE
                        WHEN NULLIF(j.AgreedFee, 0) IS NOT NULL THEN CAST(j.AgreedFee AS DECIMAL(19,2))
                        WHEN NULLIF(j.ValueOfWork, 0) IS NOT NULL THEN CAST(j.ValueOfWork AS DECIMAL(19,2))
                        ELSE NULL
                    END
                , CalculatedNet =
                    CAST(
                        CASE
                            WHEN (CASE
                                    WHEN NULLIF(j.AgreedFee, 0) IS NOT NULL THEN j.AgreedFee
                                    WHEN NULLIF(j.ValueOfWork, 0) IS NOT NULL THEN j.ValueOfWork
                                    ELSE NULL
                                  END) IS NULL
                                 OR (CASE
                                        WHEN NULLIF(j.AgreedFee, 0) IS NOT NULL THEN j.AgreedFee
                                        WHEN NULLIF(j.ValueOfWork, 0) IS NOT NULL THEN j.ValueOfWork
                                        ELSE NULL
                                      END) <= 0
                                 OR c.Percentage <= 0
                                THEN 0
                            ELSE ROUND(
                                    (CASE
                                        WHEN NULLIF(j.AgreedFee, 0) IS NOT NULL THEN j.AgreedFee
                                        WHEN NULLIF(j.ValueOfWork, 0) IS NOT NULL THEN j.ValueOfWork
                                        ELSE 0
                                     END) * (c.Percentage / 100.0), 2
                                 )
                        END
                        AS DECIMAL(19,2)
                    )
                , NeedsReconciliation =
                    CASE
                        WHEN (CASE
                                WHEN NULLIF(j.AgreedFee, 0) IS NOT NULL THEN j.AgreedFee
                                WHEN NULLIF(j.ValueOfWork, 0) IS NOT NULL THEN j.ValueOfWork
                                ELSE NULL
                              END) IS NULL
                             OR (CASE
                                    WHEN NULLIF(j.AgreedFee, 0) IS NOT NULL THEN j.AgreedFee
                                    WHEN NULLIF(j.ValueOfWork, 0) IS NOT NULL THEN j.ValueOfWork
                                    ELSE NULL
                                 END) <= 0
                             OR c.Percentage <= 0
                            THEN CONVERT(bit, 1)
                        ELSE CONVERT(bit, 0)
                    END
                , NEWID()
            FROM #Candidates c
            JOIN SJob.Jobs j
              ON j.ID = c.JobId
             AND j.RowStatus NOT IN (0,254)
            WHERE
                /* active-row idempotency */
                NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'PercentageConfig'
                      AND r.JobId = c.JobId
                      AND r.SourceGuid = c.PercentageConfigGuid
                )
                /* do not regenerate if ever flagged for reconciliation (any RowStatus) */
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests r
                    WHERE r.SourceType = N'PercentageConfig'
                      AND r.JobId = c.JobId
                      AND r.SourceGuid = c.PercentageConfigGuid
                      AND r.ReconciliationRequired = 1
                );

            IF NOT EXISTS (SELECT 1 FROM #ToCreate)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END

            CREATE TABLE #InsertedRequests
            (
                  InvoiceRequestId        INT              NOT NULL
                , InvoiceRequestGuid      UNIQUEIDENTIFIER  NOT NULL
                , JobId                   INT              NOT NULL
                , PercentageConfigGuid    UNIQUEIDENTIFIER  NOT NULL
                , PercentageConfigId      INT              NOT NULL
                , PeriodNumber            INT              NOT NULL
                , Percentage              DECIMAL(19,2)     NOT NULL
                , OnDayOfMonth            DATE             NOT NULL
                , Description             NVARCHAR(MAX)     NOT NULL
                , ReconciliationRequired  BIT              NOT NULL
                , CalculatedNet           DECIMAL(19,2)     NOT NULL
            );

            /* Insert requests row-by-row so we can UpsertDataObject first */
            DECLARE
                  @JobId INT
                , @PcGuid UNIQUEIDENTIFIER
                , @PcId INT
                , @Period INT
                , @Pct DECIMAL(19,2)
                , @OnDay DATE
                , @Desc NVARCHAR(MAX)
                , @CalcNet DECIMAL(19,2)
                , @NeedsRecon bit
                , @ReqGuid UNIQUEIDENTIFIER;

            DECLARE cur_req CURSOR LOCAL FAST_FORWARD FOR
            SELECT JobId, PercentageConfigGuid, PercentageConfigId, PeriodNumber, Percentage, OnDayOfMonth, Description, CalculatedNet, NeedsReconciliation, NewInvoiceRequestGuid
            FROM #ToCreate;

            OPEN cur_req;
            FETCH NEXT FROM cur_req INTO @JobId, @PcGuid, @PcId, @Period, @Pct, @OnDay, @Desc, @CalcNet, @NeedsRecon, @ReqGuid;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                /* Re-check under concurrency */
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'PercentageConfig'
                      AND r.JobId = @JobId
                      AND r.SourceGuid = @PcGuid
                )
                BEGIN
                    DECLARE @WasInsert bit;

                    EXEC SCore.UpsertDataObject
                        @Guid = @ReqGuid,
                        @SchemeName = N'SFin',
                        @ObjectName = N'InvoiceRequests',
                        @IncludeDefaultSecurity = 0,
                        @IsInsert = @WasInsert OUTPUT;

                    INSERT SFin.InvoiceRequests
                    (
                          RowStatus, Guid, Notes, RequesterUserId, CreatedDateTimeUTC,
                          JobId, LegacyId, LegacySystemID,
                          InvoicingType, ExpectedDate, ManualStatus, InvoicePaymentStatusID,
                          IsAutomated, IsZeroValuePlaceholder,
                          ReconciliationRequired, ReconciliationReason,
                          SourceType, SourceGuid, SourceIntId,
                          AutomationRunGuid, InvoiceBatchGuid, BlockedReason
                    )
                    SELECT
                          1, @ReqGuid, N'', @RequesterUserId, @NowUtcEff,
                          @JobId, NULL, -1,
                          N'PCT', @OnDay, 0, @DefaultPaymentStatusId,
                          1, CASE WHEN @CalcNet = 0 THEN 1 ELSE 0 END,
                          @NeedsRecon,
                          CASE
                              WHEN @NeedsRecon = 1
                                  THEN LEFT(
                                           CONCAT(
                                               N'Percentage config requires valuation/reconciliation. Period=',
                                               CONVERT(NVARCHAR(20), @Period),
                                               N', Pct=',
                                               CONVERT(NVARCHAR(50), @Pct),
                                               N'%'
                                           ),
                                           200
                                       )
                              ELSE N''
                          END,
                          N'PercentageConfig', @PcGuid, @PcId,
                          @AutomationRunGuid, NULL, N''
                    WHERE NOT EXISTS (SELECT 1 FROM SFin.InvoiceRequests WITH (UPDLOCK, HOLDLOCK) WHERE Guid = @ReqGuid);

                    INSERT #InsertedRequests
                    (
                        InvoiceRequestId, InvoiceRequestGuid, JobId,
                        PercentageConfigGuid, PercentageConfigId,
                        PeriodNumber, Percentage, OnDayOfMonth, Description,
                        ReconciliationRequired, CalculatedNet
                    )
                    SELECT
                          r.ID, r.Guid, r.JobId,
                          r.SourceGuid, @PcId,
                          @Period, @Pct, @OnDay, @Desc,
                          r.ReconciliationRequired, @CalcNet
                    FROM SFin.InvoiceRequests r
                    WHERE r.Guid = @ReqGuid
                      AND r.RowStatus NOT IN (0,254);
                END

                FETCH NEXT FROM cur_req INTO @JobId, @PcGuid, @PcId, @Period, @Pct, @OnDay, @Desc, @CalcNet, @NeedsRecon, @ReqGuid;
            END

            CLOSE cur_req;
            DEALLOCATE cur_req;

            IF NOT EXISTS (SELECT 1 FROM #InsertedRequests)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END

            /* Stage items (one per request) */
            CREATE TABLE #ItemsToCreate
            (
                  NewItemGuid       UNIQUEIDENTIFIER NOT NULL
                , InvoiceRequestId  INT              NOT NULL
                , Net               DECIMAL(19,2)     NOT NULL
                , ShortDescription  NVARCHAR(200)     NOT NULL
            );

            INSERT #ItemsToCreate (NewItemGuid, InvoiceRequestId, Net, ShortDescription)
            SELECT
                  NEWID(),
                  ir.InvoiceRequestId,
                  CAST(CASE WHEN ir.ReconciliationRequired = 1 THEN 0 ELSE ir.CalculatedNet END AS DECIMAL(19,2)),
                  LEFT(
                      ISNULL(
                          NULLIF(CONVERT(NVARCHAR(4000), ir.Description), N''),
                          CONCAT(N'Percentage drawdown (', CONVERT(NVARCHAR(50), ir.Percentage), N'%)')
                      ),
                      200
                  )
            FROM #InsertedRequests ir;

            /* Insert items row-by-row so we can UpsertDataObject first */
            DECLARE
                  @ItemGuid UNIQUEIDENTIFIER
                , @ReqId INT
                , @Net DECIMAL(19,2)
                , @Short NVARCHAR(200);

            DECLARE cur_item CURSOR LOCAL FAST_FORWARD FOR
            SELECT NewItemGuid, InvoiceRequestId, Net, ShortDescription
            FROM #ItemsToCreate;

            OPEN cur_item;
            FETCH NEXT FROM cur_item INTO @ItemGuid, @ReqId, @Net, @Short;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @ItemWasInsert bit;

                EXEC SCore.UpsertDataObject
                    @Guid = @ItemGuid,
                    @SchemeName = N'SFin',
                    @ObjectName = N'InvoiceRequestItems',
                    @IncludeDefaultSecurity = 0,
                    @IsInsert = @ItemWasInsert OUTPUT;

                INSERT SFin.InvoiceRequestItems
                (
                      RowStatus, Guid, InvoiceRequestId,
                      MilestoneId, ActivityId, Net,
                      LegacyId, LegacySystemID, ShortDescription
                )
                SELECT
                      1, @ItemGuid, @ReqId,
                      -1, -1, @Net,
                      NULL, -1, LEFT(ISNULL(@Short, N''), 200)
                WHERE NOT EXISTS (SELECT 1 FROM SFin.InvoiceRequestItems WITH (UPDLOCK, HOLDLOCK) WHERE Guid = @ItemGuid);

                FETCH NEXT FROM cur_item INTO @ItemGuid, @ReqId, @Net, @Short;
            END

            CLOSE cur_item;
            DEALLOCATE cur_item;

            SET @CreatedInvoiceRequests = (SELECT COUNT(1) FROM #InsertedRequests);
            RETURN;
        END TRY
        BEGIN CATCH
            DECLARE @ErrNum INT = ERROR_NUMBER();
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

            /* Safety: never leak an open tran */
            IF (@@TRANCOUNT > 0)
                ROLLBACK;

            /* Retry deadlock / unique-race */
            IF (@ErrNum = 1205 AND @LocalAttempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.250';
                CONTINUE;
            END

            IF ((@ErrNum IN (2601,2627)) AND @LocalAttempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.050';
                CONTINUE;
            END

            RAISERROR(N'CreateInvoiceRequests_FromPercentageConfig failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
            RETURN;
        END CATCH
    END
END
GO