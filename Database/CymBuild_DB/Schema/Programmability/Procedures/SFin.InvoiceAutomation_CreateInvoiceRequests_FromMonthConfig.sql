SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromMonthConfig]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromMonthConfig]')
GO

CREATE PROCEDURE [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromMonthConfig]
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
    SET XACT_ABORT OFF;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());

    SET @CreatedAtUtc = @NowUtcEff;
    SET @CreatedInvoiceRequests = 0;

    DECLARE @RequesterUserId INT;

    SELECT @RequesterUserId = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @RequesterUserGuid
      AND i.RowStatus NOT IN (0,254);

    IF @RequesterUserId IS NULL
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END;

    DECLARE @DefaultPaymentStatusId BIGINT;

    IF @DefaultPaymentStatusGuid IS NOT NULL
    BEGIN
        SELECT @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus AS ps
        WHERE ps.Guid = @DefaultPaymentStatusGuid
          AND ps.RowStatus NOT IN (0,254);
    END
    ELSE
    BEGIN
        SELECT TOP (1) @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus AS ps
        WHERE ps.RowStatus NOT IN (0,254)
        ORDER BY ps.ID ASC;
    END;

    IF @DefaultPaymentStatusId IS NULL
    BEGIN
        RAISERROR(N'No active InvoicePaymentStatus row found (and/or DefaultPaymentStatusGuid invalid).', 16, 1);
        RETURN;
    END;

    DECLARE @LocalAttempt INT = 0;

    WHILE (1 = 1)
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
                  InvoiceScheduleId INT NOT NULL
                , JobId INT NOT NULL
                , MonthConfigId INT NOT NULL
                , MonthConfigGuid UNIQUEIDENTIFIER NOT NULL
                , PeriodNumber INT NOT NULL
                , Amount DECIMAL(19,2) NOT NULL
                , OnDayOfMonth DATE NULL
                , Description NVARCHAR(MAX) NOT NULL
                , RIBAStageId INT NULL
            );

            ;WITH ScheduleJobScope AS
            (
                SELECT DISTINCT
                      qi.InvoicingSchedule AS InvoiceScheduleId
                    , qi.CreatedJobId AS JobId
                FROM SSop.QuoteItems AS qi
                JOIN SFin.InvoiceSchedules AS sch
                    ON sch.ID = qi.InvoicingSchedule
                   AND sch.RowStatus NOT IN (0,254)
                WHERE qi.RowStatus NOT IN (0,254)
                  AND qi.CreatedJobId NOT IN (-1,0)
                  AND qi.InvoicingSchedule NOT IN (-1,0)
            )
            INSERT INTO #Candidates
            (
                  InvoiceScheduleId
                , JobId
                , MonthConfigId
                , MonthConfigGuid
                , PeriodNumber
                , Amount
                , OnDayOfMonth
                , Description
                , RIBAStageId
            )
            SELECT
                  sjs.InvoiceScheduleId
                , sjs.JobId
                , mc.ID
                , mc.Guid
                , mc.PeriodNumber
                , mc.Amount
                , mc.OnDayOfMonth
                , ISNULL(mc.Description, N'')
                , mc.RIBAStageId
            FROM ScheduleJobScope AS sjs
            JOIN SFin.InvoiceScheduleMonthConfiguration AS mc
                ON mc.InvoiceScheduleId = sjs.InvoiceScheduleId
               AND mc.RowStatus NOT IN (0,254)
            JOIN SFin.vw_InvoiceAutomation_BlockingDiagnostics AS bd
                ON bd.InvoiceScheduleId = sjs.InvoiceScheduleId
               AND bd.JobId = sjs.JobId
            WHERE bd.IsBlocked = 0
              AND mc.OnDayOfMonth IS NOT NULL
              AND mc.OnDayOfMonth <= CAST(@NowUtcEff AS DATE);

            IF NOT EXISTS (SELECT 1 FROM #Candidates)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END;

            CREATE TABLE #ToCreate
            (
                  InvoiceScheduleId INT NOT NULL
                , JobId INT NOT NULL
                , MonthConfigId INT NOT NULL
                , MonthConfigGuid UNIQUEIDENTIFIER NOT NULL
                , PeriodNumber INT NOT NULL
                , Amount DECIMAL(19,2) NOT NULL
                , OnDayOfMonth DATE NOT NULL
                , Description NVARCHAR(MAX) NOT NULL
                , RIBAStageId INT NULL
                , NewInvoiceRequestGuid UNIQUEIDENTIFIER NOT NULL
            );

            INSERT INTO #ToCreate
            (
                  InvoiceScheduleId
                , JobId
                , MonthConfigId
                , MonthConfigGuid
                , PeriodNumber
                , Amount
                , OnDayOfMonth
                , Description
                , RIBAStageId
                , NewInvoiceRequestGuid
            )
            SELECT
                  c.InvoiceScheduleId
                , c.JobId
                , c.MonthConfigId
                , c.MonthConfigGuid
                , c.PeriodNumber
                , c.Amount
                , c.OnDayOfMonth
                , c.Description
                , c.RIBAStageId
                , NEWID()
            FROM #Candidates AS c
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM SFin.InvoiceRequests AS r
                WHERE r.SourceType = N'MonthConfig'
                  AND r.JobId = c.JobId
                  AND r.SourceGuid = c.MonthConfigGuid
                  AND
                  (
                      r.RowStatus NOT IN (0,254)
                      OR r.IsMerged = 1
                  )
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM SFin.InvoiceRequests AS r
                WHERE r.SourceType = N'MonthConfig'
                  AND r.JobId = c.JobId
                  AND r.SourceGuid = c.MonthConfigGuid
                  AND r.ReconciliationRequired = 1
            );

            IF NOT EXISTS (SELECT 1 FROM #ToCreate)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END;

            CREATE TABLE #InsertedRequests
            (
                  InvoiceRequestId INT NOT NULL
                , InvoiceRequestGuid UNIQUEIDENTIFIER NOT NULL
                , JobId INT NOT NULL
                , MonthConfigGuid UNIQUEIDENTIFIER NOT NULL
                , MonthConfigId INT NOT NULL
                , PeriodNumber INT NOT NULL
                , Amount DECIMAL(19,2) NOT NULL
                , OnDayOfMonth DATE NOT NULL
                , Description NVARCHAR(MAX) NOT NULL
                , ReconciliationRequired BIT NOT NULL
                , RIBAStageId INT NULL
            );

            DECLARE
                  @JobId INT
                , @MonthGuid UNIQUEIDENTIFIER
                , @MonthId INT
                , @Period INT
                , @Amt DECIMAL(19,2)
                , @OnDay DATE
                , @Desc NVARCHAR(MAX)
                , @ReqGuid UNIQUEIDENTIFIER
                , @RIBAStageId INT;

            DECLARE cur_req CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                  JobId
                , MonthConfigGuid
                , MonthConfigId
                , PeriodNumber
                , Amount
                , OnDayOfMonth
                , Description
                , NewInvoiceRequestGuid
                , RIBAStageId
            FROM #ToCreate;

            OPEN cur_req;

            FETCH NEXT FROM cur_req
            INTO @JobId, @MonthGuid, @MonthId, @Period, @Amt, @OnDay, @Desc, @ReqGuid, @RIBAStageId;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests AS r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'MonthConfig'
                      AND r.JobId = @JobId
                      AND r.SourceGuid = @MonthGuid
                )
                BEGIN
                    DECLARE @WasInsert BIT;

                    EXEC SCore.UpsertDataObject
                          @Guid = @ReqGuid
                        , @SchemeName = N'SFin'
                        , @ObjectName = N'InvoiceRequests'
                        , @IncludeDefaultSecurity = 0
                        , @IsInsert = @WasInsert OUTPUT;

                    DECLARE @NeedsReconciliation BIT =
                        CASE WHEN ISNULL(@Amt, 0) <= 0 THEN 1 ELSE 0 END;

				
				


                    INSERT INTO SFin.InvoiceRequests
                    (
                          RowStatus
                        , Guid
                        , Notes
                        , RequesterUserId
                        , CreatedDateTimeUTC
                        , JobId
                        , LegacyId
                        , LegacySystemID
                        , InvoicingType
                        , ExpectedDate
                        , ManualStatus
                        , InvoicePaymentStatusID
                        , IsAutomated
                        , IsZeroValuePlaceholder
                        , ReconciliationRequired
                        , ReconciliationReason
                        , SourceType
                        , SourceGuid
                        , SourceIntId
                        , AutomationRunGuid
                        , InvoiceBatchGuid
                        , BlockedReason
                    )
                    SELECT
                          1
                        , @ReqGuid
                        , N''
                        , @RequesterUserId
                        , @NowUtcEff
                        , @JobId
                        , NULL
                        , -1
                        , N'MON'
                        , @OnDay
                        , 0
                        , @DefaultPaymentStatusId
                        , 1
                        , CASE WHEN @NeedsReconciliation = 1 THEN 1 ELSE 0 END
                        , @NeedsReconciliation
                        , CASE
                              WHEN @NeedsReconciliation = 1
                                  THEN N'Month config amount is zero/invalid; reconciliation required.'
                              ELSE N''
                          END
                        , N'MonthConfig'
                        , @MonthGuid
                        , @MonthId
                        , @AutomationRunGuid
                        , NULL
                        , N''
                    WHERE NOT EXISTS
                    (
                        SELECT 1
                        FROM SFin.InvoiceRequests WITH (UPDLOCK, HOLDLOCK)
                        WHERE Guid = @ReqGuid
                    );

                    INSERT INTO #InsertedRequests
                    (
                          InvoiceRequestId
                        , InvoiceRequestGuid
                        , JobId
                        , MonthConfigGuid
                        , MonthConfigId
                        , PeriodNumber
                        , Amount
                        , OnDayOfMonth
                        , Description
                        , ReconciliationRequired
                        , RIBAStageId
                    )
                    SELECT
                          r.ID
                        , r.Guid
                        , r.JobId
                        , r.SourceGuid
                        , @MonthId
                        , @Period
                        , @Amt
                        , @OnDay
                        , @Desc
                        , r.ReconciliationRequired
                        , @RIBAStageId
                    FROM SFin.InvoiceRequests AS r
                    WHERE r.Guid = @ReqGuid
                      AND r.RowStatus NOT IN (0,254);
                END;

                FETCH NEXT FROM cur_req
                INTO @JobId, @MonthGuid, @MonthId, @Period, @Amt, @OnDay, @Desc, @ReqGuid, @RIBAStageId;
            END;

            CLOSE cur_req;
            DEALLOCATE cur_req;

            IF NOT EXISTS (SELECT 1 FROM #InsertedRequests)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END;

            CREATE TABLE #ItemsToCreate
            (
                  NewItemGuid UNIQUEIDENTIFIER NOT NULL
                , InvoiceRequestId INT NOT NULL
                , Net DECIMAL(19,2) NOT NULL
                , ShortDescription NVARCHAR(200) NOT NULL
                , RIBAStageId INT NULL
            );

            INSERT INTO #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , Net
                , ShortDescription
                , RIBAStageId
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , CAST(CASE WHEN ir.ReconciliationRequired = 1 THEN 0 ELSE ir.Amount END AS DECIMAL(19,2))
                , LEFT(
                      ISNULL(
                          NULLIF(CONVERT(NVARCHAR(4000), ir.Description), N''),
                          CONCAT(N'Monthly drawdown (Period ', CONVERT(NVARCHAR(20), ir.PeriodNumber), N')')
                      ),
                      200
                  )
                , ir.RIBAStageId
            FROM #InsertedRequests AS ir;

            DECLARE
                  @ItemGuid UNIQUEIDENTIFIER
                , @ReqId INT
                , @Net DECIMAL(19,2)
                , @Short NVARCHAR(200)
                , @ItemRIBAStageId INT;

            DECLARE cur_item CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                  NewItemGuid
                , InvoiceRequestId
                , Net
                , ShortDescription
                , RIBAStageId
            FROM #ItemsToCreate;

            OPEN cur_item;

            FETCH NEXT FROM cur_item
            INTO @ItemGuid, @ReqId, @Net, @Short, @ItemRIBAStageId;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @ItemWasInsert BIT;

                EXEC SCore.UpsertDataObject
                      @Guid = @ItemGuid
                    , @SchemeName = N'SFin'
                    , @ObjectName = N'InvoiceRequestItems'
                    , @IncludeDefaultSecurity = 0
                    , @IsInsert = @ItemWasInsert OUTPUT;

                INSERT INTO SFin.InvoiceRequestItems
                (
                      RowStatus
                    , Guid
                    , InvoiceRequestId
                    , MilestoneId
                    , ActivityId
                    , Net
                    , LegacyId
                    , LegacySystemID
                    , ShortDescription
                    , RIBAStageId
                )
                SELECT
                      1
                    , @ItemGuid
                    , @ReqId
                    , -1
                    , -1
                    , @Net
                    , NULL
                    , -1
                    , LEFT(ISNULL(@Short, N''), 200)
                    , @ItemRIBAStageId
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequestItems WITH (UPDLOCK, HOLDLOCK)
                    WHERE Guid = @ItemGuid
                );

                FETCH NEXT FROM cur_item
                INTO @ItemGuid, @ReqId, @Net, @Short, @ItemRIBAStageId;
            END;

            CLOSE cur_item;
            DEALLOCATE cur_item;

            SET @CreatedInvoiceRequests =
            (
                SELECT COUNT(1)
                FROM #InsertedRequests
            );

            RETURN;
        END TRY
        BEGIN CATCH
            DECLARE @ErrNum INT = ERROR_NUMBER();
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

            IF @@TRANCOUNT > 0
                ROLLBACK;

            IF @ErrNum = 1205 AND @LocalAttempt < @MaxAttempts
            BEGIN
                WAITFOR DELAY '00:00:00.250';
                CONTINUE;
            END;

            IF @ErrNum IN (2601,2627) AND @LocalAttempt < @MaxAttempts
            BEGIN
                WAITFOR DELAY '00:00:00.050';
                CONTINUE;
            END;

            RAISERROR(N'CreateInvoiceRequests_FromMonthConfig failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
            RETURN;
        END CATCH;
    END;
END;
GO