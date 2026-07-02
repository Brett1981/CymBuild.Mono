SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequestAutomationCreate]')
GO
PRINT (N'Create procedure [SFin].[InvoiceRequestAutomationCreate]')
GO

CREATE PROCEDURE [SFin].[InvoiceRequestAutomationCreate]
(
    @JobGuid                    UNIQUEIDENTIFIER,
    @Guid                       UNIQUEIDENTIFIER = NULL,
    @RequesterUserGuid          UNIQUEIDENTIFIER = NULL,
    @Notes                      NVARCHAR(MAX) = N'',

    @InvoicingType              NVARCHAR(10),
    @ExpectedDate               DATE = NULL,
    @PaymentStatusGuid          UNIQUEIDENTIFIER,

    @IsZeroValuePlaceholder     BIT = 0,
    @ReconciliationRequired     BIT = 0,
    @ReconciliationReason       NVARCHAR(200) = N'',

    @SourceType                 NVARCHAR(50),                 -- 'MonthConfig' | 'TriggerInstance' | 'PercentageConfig'
    @SourceGuid                 UNIQUEIDENTIFIER = NULL,
    @SourceIntId                INT = NULL,

    @AutomationRunGuid          UNIQUEIDENTIFIER = NULL,
    @InvoiceBatchGuid           UNIQUEIDENTIFIER = NULL,

    @BlockedReason              NVARCHAR(200) = N'',

    @CreatedGuid                UNIQUEIDENTIFIER OUTPUT,
    @WasInserted                BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @WasInserted = 0;

    IF (@Guid IS NULL)
        SET @Guid = NEWID();

    SET @CreatedGuid = @Guid;

    -------------------------------------------------------------------------
    -- Resolve IDs
    -------------------------------------------------------------------------
    DECLARE @JobId INT,
            @RequesterUserId INT,
            @PaymentStatusId BIGINT,
            @IsInsert BIT;

    SELECT @JobId = j.ID
    FROM SJob.Jobs j
    WHERE j.Guid = @JobGuid;

    IF (@JobId IS NULL)
        THROW 50000, N'InvoiceRequestAutomationCreate: Job not found for @JobGuid.', 1;

    -- Requester: if provided, use it; else session_context('user_id'); else -1
    IF (@RequesterUserGuid IS NOT NULL)
    BEGIN
        SELECT @RequesterUserId = i.ID
        FROM SCore.Identities i
        WHERE i.Guid = @RequesterUserGuid;
    END
    ELSE
    BEGIN
        SELECT @RequesterUserId = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);
    END


    -------------------------------------------------------------------------
    -- CYB-419: activity-triggered automated requests should be owned by the
    -- activity assignee (SJob.Activities.SurveyorID), not the service/session user.
    -- This keeps legacy/helper-based trigger-instance creation aligned with the
    -- activity grid, while preserving the existing fallback for non-activity flows.
    -------------------------------------------------------------------------
    IF (ISNULL(@SourceType, N'') = N'TriggerInstance' AND @SourceGuid IS NOT NULL)
    BEGIN
        DECLARE @ActivityRequesterUserId INT;

        SELECT TOP (1)
            @ActivityRequesterUserId = assignee.ID
        FROM SFin.InvoiceScheduleTriggerInstances AS ti
        JOIN SJob.Activities AS a
            ON a.RowStatus NOT IN (0,254)
           AND a.ID =
               CASE
                   WHEN ti.InstanceKey LIKE N'ACT:%'
                       THEN TRY_CONVERT(BIGINT, SUBSTRING(ti.InstanceKey, 5, 200))
                   WHEN CHARINDEX(N'|A', ti.InstanceKey) > 0
                       THEN TRY_CONVERT(BIGINT, SUBSTRING(ti.InstanceKey, CHARINDEX(N'|A', ti.InstanceKey) + 2, 50))
                   ELSE NULL
               END
        JOIN SCore.Identities AS assignee
            ON assignee.ID = a.SurveyorID
           AND assignee.RowStatus NOT IN (0,254)
        WHERE ti.Guid = @SourceGuid
          AND ti.RowStatus NOT IN (0,254)
          AND ti.InstanceType IN (N'Activity', N'ACT');

        IF (@ActivityRequesterUserId IS NOT NULL)
            SET @RequesterUserId = @ActivityRequesterUserId;
    END;

    SELECT @PaymentStatusId = ips.ID
    FROM SFin.InvoicePaymentStatus ips
    WHERE ips.Guid = @PaymentStatusGuid;

    IF (@PaymentStatusId IS NULL)
        THROW 50001, N'InvoiceRequestAutomationCreate: Payment status not found for @PaymentStatusGuid.', 1;

    -------------------------------------------------------------------------
    -- Idempotency fast-path: if ACTIVE row exists for (JobId + SourceType + SourceGuid) return it
    -------------------------------------------------------------------------
    IF (@SourceGuid IS NOT NULL)
    BEGIN
        DECLARE @ExistingGuid UNIQUEIDENTIFIER;

        SELECT TOP(1) @ExistingGuid = ir.Guid
        FROM SFin.InvoiceRequests ir
        WHERE ir.RowStatus NOT IN (0, 254)
          AND ir.JobId = @JobId
          AND ir.SourceType = @SourceType
          AND ir.SourceGuid = @SourceGuid;

        IF (@ExistingGuid IS NOT NULL)
        BEGIN
            SET @CreatedGuid = @ExistingGuid;
            RETURN;
        END
    END

    -------------------------------------------------------------------------
    -- Create DataObject row (EntityTypeId=126 inferred via HoBT mapping)
    -------------------------------------------------------------------------
    EXEC SCore.UpsertDataObject
         @Guid = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'InvoiceRequests',
         @IncludeDefaultSecurity = 0,
         @IsInsert = @IsInsert OUTPUT;

    -------------------------------------------------------------------------
    -- Insert/Update business row
    -------------------------------------------------------------------------
    BEGIN TRY
        IF (@IsInsert = 1)
        BEGIN
            INSERT SFin.InvoiceRequests
            (
                RowStatus,
                Guid,
                Notes,
                RequesterUserId,
                CreatedDateTimeUTC,
                JobId,
                LegacyId,
                LegacySystemID,
                InvoicingType,
                ExpectedDate,
                ManualStatus,
                InvoicePaymentStatusID,

                IsAutomated,
                IsZeroValuePlaceholder,
                ReconciliationRequired,
                ReconciliationReason,
                SourceType,
                SourceGuid,
                InvoiceBatchGuid,
                SourceIntId,
                BlockedReason,
                AutomationRunGuid
            )
            VALUES
            (
                1,
                @Guid,
                ISNULL(@Notes, N''),
                ISNULL(@RequesterUserId, -1),
                SYSUTCDATETIME(),
                @JobId,
                NULL,
                -1,
                ISNULL(@InvoicingType, N''),
                @ExpectedDate,
                0,
                @PaymentStatusId,

                1,
                ISNULL(@IsZeroValuePlaceholder, 0),
                ISNULL(@ReconciliationRequired, 0),
                ISNULL(@ReconciliationReason, N''),
                ISNULL(@SourceType, N''),
                @SourceGuid,
                @InvoiceBatchGuid,
                @SourceIntId,
                ISNULL(@BlockedReason, N''),
                @AutomationRunGuid
            );

            SET @WasInserted = 1;
        END
        ELSE
        BEGIN
            UPDATE ir
            SET
                ir.Notes                   = ISNULL(@Notes, N''),
                ir.JobId                   = @JobId,
                ir.InvoicingType           = ISNULL(@InvoicingType, N''),
                ir.ExpectedDate            = @ExpectedDate,
                ir.ManualStatus            = 0,
                ir.InvoicePaymentStatusID  = @PaymentStatusId,

                ir.IsAutomated             = 1,
                ir.IsZeroValuePlaceholder  = ISNULL(@IsZeroValuePlaceholder, 0),
                ir.ReconciliationRequired  = ISNULL(@ReconciliationRequired, 0),
                ir.ReconciliationReason    = ISNULL(@ReconciliationReason, N''),
                ir.SourceType              = ISNULL(@SourceType, N''),
                ir.SourceGuid              = @SourceGuid,
                ir.InvoiceBatchGuid        = @InvoiceBatchGuid,
                ir.SourceIntId             = @SourceIntId,
                ir.BlockedReason           = ISNULL(@BlockedReason, N''),
                ir.AutomationRunGuid       = @AutomationRunGuid
            FROM SFin.InvoiceRequests ir
            WHERE ir.Guid = @Guid;
        END
    END TRY
    BEGIN CATCH
        IF (ERROR_NUMBER() IN (2601, 2627) AND @SourceGuid IS NOT NULL)
        BEGIN
            SELECT TOP(1) @CreatedGuid = ir.Guid
            FROM SFin.InvoiceRequests ir
            WHERE ir.RowStatus NOT IN (0, 254)
              AND ir.JobId = @JobId
              AND ir.SourceType = @SourceType
              AND ir.SourceGuid = @SourceGuid;

            RETURN;
        END

        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50002, @Err, 1;
    END CATCH
END
GO