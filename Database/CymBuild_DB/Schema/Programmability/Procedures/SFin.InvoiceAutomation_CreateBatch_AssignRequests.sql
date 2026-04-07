SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateBatch_AssignRequests]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateBatch_AssignRequests]')
GO

CREATE PROCEDURE [SFin].[InvoiceAutomation_CreateBatch_AssignRequests]
(
      @AutomationRunGuid   UNIQUEIDENTIFIER
    , @RequesterUserGuid   UNIQUEIDENTIFIER
    , @Notes               NVARCHAR(MAX) = NULL
    , @NowUtc              DATETIME2(7) = NULL
    , @MaxAttempts         INT = 5

    , @InvoiceBatchGuid    UNIQUEIDENTIFIER = NULL OUTPUT
    , @AssignedCount       INT = 0 OUTPUT
    , @Attempt             INT = NULL OUTPUT
    , @CreatedAtUtc        DATETIME2(7) = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());
    SET @CreatedAtUtc = @NowUtcEff;

    DECLARE @RequesterUserId INT;
    SELECT @RequesterUserId = i.ID
    FROM SCore.Identities i
    WHERE i.Guid = @RequesterUserGuid;

    IF (@RequesterUserId IS NULL)
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END

    DECLARE @LocalAttempt INT = 0;

    WHILE (1=1)
    BEGIN
        SET @LocalAttempt += 1;
        SET @Attempt = @LocalAttempt;

        BEGIN TRY
            BEGIN TRAN;

            DECLARE @EligibleCount INT;

            SELECT @EligibleCount = COUNT(1)
            FROM SFin.InvoiceRequests r
            WHERE r.RowStatus NOT IN (0,254)
              AND r.AutomationRunGuid = @AutomationRunGuid
              AND ISNULL(r.IsAutomated, 0) = 1
              AND r.InvoiceBatchGuid IS NULL;

            IF (ISNULL(@EligibleCount, 0) = 0)
            BEGIN
                SET @InvoiceBatchGuid = NULL;
                SET @AssignedCount = 0;
                COMMIT;
                RETURN;
            END

            DECLARE @BatchGuid UNIQUEIDENTIFIER = NULL;

            SELECT TOP (1) @BatchGuid = b.Guid
            FROM SFin.InvoiceBatches b
            WHERE b.RowStatus NOT IN (0,254)
              AND b.AutomationRunGuid = @AutomationRunGuid
            ORDER BY b.ID DESC;

            IF (@BatchGuid IS NULL)
            BEGIN
                SET @BatchGuid = NEWID();

                INSERT SFin.InvoiceBatches
                (
                      RowStatus, Guid, CreatedDateTimeUTC, CreatedByUserId,
                      AutomationRunGuid, CreatedCount, Notes, LegacyId, LegacySystemID
                )
                VALUES
                (
                      1, @BatchGuid, @NowUtcEff, @RequesterUserId,
                      @AutomationRunGuid, 0, ISNULL(@Notes, N''), NULL, -1
                );
            END

            ;WITH ToBatch AS
            (
                SELECT r.ID
                FROM SFin.InvoiceRequests r
                WHERE r.RowStatus NOT IN (0,254)
                  AND r.AutomationRunGuid = @AutomationRunGuid
                  AND ISNULL(r.IsAutomated, 0) = 1
                  AND r.InvoiceBatchGuid IS NULL
            )
            UPDATE r
                SET r.InvoiceBatchGuid = @BatchGuid
            FROM SFin.InvoiceRequests r
            JOIN ToBatch b ON b.ID = r.ID;

            SET @AssignedCount = @@ROWCOUNT;
            SET @InvoiceBatchGuid = @BatchGuid;

            UPDATE b
                SET b.CreatedCount =
                (
                    SELECT COUNT(1)
                    FROM SFin.InvoiceRequests r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.InvoiceBatchGuid = @BatchGuid
                )
            FROM SFin.InvoiceBatches b
            WHERE b.Guid = @BatchGuid;

            COMMIT;
            RETURN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;

            DECLARE @ErrNum INT = ERROR_NUMBER();
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

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

            RAISERROR(N'CreateBatch_AssignRequests failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
            RETURN;
        END CATCH
    END
END
GO