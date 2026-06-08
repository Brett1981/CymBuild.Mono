SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceScheduleTriggerInstances_Materialise]')
GO
PRINT (N'Create procedure [SFin].[InvoiceScheduleTriggerInstances_Materialise]')
GO

CREATE PROCEDURE [SFin].[InvoiceScheduleTriggerInstances_Materialise]
(
      @DetectedDateTimeUTC DATETIME2(7) = NULL
    , @MaxAttempts         INT          = 5
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = COALESCE(@DetectedDateTimeUTC, SYSUTCDATETIME());
    DECLARE @Attempt INT = 0;

    /* Confirmed from SCore.EntityTypes */
    DECLARE @InvoiceScheduleTriggerEntityTypeId INT = 198;

    WHILE (1 = 1)
    BEGIN
        SET @Attempt += 1;

        BEGIN TRY
            BEGIN TRAN;

            DECLARE @ToInsert TABLE
            (
                  InvoiceScheduleId     INT               NOT NULL
                , InstanceType          NVARCHAR(100)     NOT NULL
                , InstanceKey           NVARCHAR(200)     NOT NULL
                , CompletedDateTimeUTC  DATETIME2(7)      NULL
                , TriggerInstanceGuid   UNIQUEIDENTIFIER  NOT NULL
            );

            ;WITH Detections AS
            (
                SELECT
                      d.InvoiceScheduleId
                    , d.InstanceType
                    , d.InstanceKey
                    , d.CompletedDateTimeUTC
                FROM [SFin].[tvf_InvoiceAutomation_Phase3Detections]() d
                WHERE d.InstanceType <> N'Percentage'
            )
            INSERT INTO @ToInsert
            (
                  InvoiceScheduleId
                , InstanceType
                , InstanceKey
                , CompletedDateTimeUTC
                , TriggerInstanceGuid
            )
            SELECT
                  d.InvoiceScheduleId
                , d.InstanceType
                , d.InstanceKey
                , d.CompletedDateTimeUTC
                , NEWID()
            FROM Detections d
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [SFin].[InvoiceScheduleTriggerInstances] t WITH (UPDLOCK, HOLDLOCK)
                WHERE t.InvoiceScheduleId = d.InvoiceScheduleId
                  AND t.InstanceType      = d.InstanceType
                  AND t.InstanceKey       = d.InstanceKey
                  AND t.RowStatus NOT IN (0,254)
            );

            /* Core identity layer must exist first */
            INSERT INTO [SCore].[DataObjects]
            (
                  [Guid]
                , [EntityTypeId]
                , [RowStatus]
            )
            SELECT
                  i.TriggerInstanceGuid
                , @InvoiceScheduleTriggerEntityTypeId
                , 1
            FROM @ToInsert i;

            INSERT INTO [SFin].[InvoiceScheduleTriggerInstances]
            (
                  [Guid]
                , [RowStatus]
                , [InvoiceScheduleId]
                , [InstanceType]
                , [InstanceKey]
                , [DetectedDateTimeUTC]
                , [CompletedDateTimeUTC]
                , [LegacySystemID]
            )
            SELECT
                  i.TriggerInstanceGuid
                , 1
                , i.InvoiceScheduleId
                , i.InstanceType
                , i.InstanceKey
                , @NowUtc
                , i.CompletedDateTimeUTC
                , -1
            FROM @ToInsert i;

            DECLARE @InsertedCount INT = @@ROWCOUNT;

            ;WITH Detections AS
            (
                SELECT
                      d.InvoiceScheduleId
                    , d.InstanceType
                    , d.InstanceKey
                    , d.CompletedDateTimeUTC
                FROM [SFin].[tvf_InvoiceAutomation_Phase3Detections]() d
                WHERE d.InstanceType <> N'Percentage'
            )
            UPDATE t
               SET t.CompletedDateTimeUTC = d.CompletedDateTimeUTC
            FROM [SFin].[InvoiceScheduleTriggerInstances] t
            JOIN Detections d
              ON d.InvoiceScheduleId = t.InvoiceScheduleId
             AND d.InstanceType      = t.InstanceType
             AND d.InstanceKey       = t.InstanceKey
            WHERE t.RowStatus NOT IN (0,254)
              AND t.CompletedDateTimeUTC IS NULL
              AND d.CompletedDateTimeUTC IS NOT NULL;

            DECLARE @UpdatedCount INT = @@ROWCOUNT;

            COMMIT;

            SELECT
                  InsertedCount = @InsertedCount
                , UpdatedCount  = @UpdatedCount
                , Attempt       = @Attempt;

            RETURN;
        END TRY
        BEGIN CATCH
            IF (XACT_STATE() <> 0)
                ROLLBACK;

            DECLARE
                  @ErrNum INT = ERROR_NUMBER()
                , @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

            IF (@ErrNum = 1205 AND @Attempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.250';
                CONTINUE;
            END;

            IF (@ErrNum IN (2601, 2627) AND @Attempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.050';
                CONTINUE;
            END;

            RAISERROR(N'Phase 4 materialisation failed. Error %d: %s', 16, 1, @ErrNum, @ErrMsg);
            RETURN;
        END CATCH
    END
END
GO