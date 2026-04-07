SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SFin].[InvoiceRequestUpsert]')
GO
PRINT (N'Create procedure [SFin].[InvoiceRequestUpsert]')
GO
CREATE PROCEDURE [SFin].[InvoiceRequestUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
    @RequesterUserGuid UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX),
    @Guid UNIQUEIDENTIFIER,
    @InvoicingType NVARCHAR(10),
    @ExpectedDate DATE,
    @ManualStatus BIT,
    @PaymentStatusGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobID INT,
            @RequesterUserId INT,
            @PaymentStatusID BIGINT,
            @DataObjectWasInserted BIT;

    -- Null-safety for NOT NULL column
    SET @Notes = ISNULL(@Notes, N'');

    -- Resolve Job
    SELECT @JobID = ID
    FROM SJob.Jobs
    WHERE [Guid] = @JobGuid;

    IF (@JobID IS NULL)
        THROW 60000, N'InvoiceRequestUpsert: JobGuid not found.', 1;

    -- Resolve Requester
    SELECT @RequesterUserId = ID
    FROM SCore.Identities
    WHERE [Guid] = @RequesterUserGuid;

    IF (@RequesterUserId IS NULL)
        THROW 60000, N'InvoiceRequestUpsert: RequesterUserGuid not found.', 1;

    -- Resolve Payment Status
    SELECT @PaymentStatusID = ID
    FROM SFin.InvoicePaymentStatus
    WHERE [Guid] = @PaymentStatusGuid;

    IF (@PaymentStatusID IS NULL)
        THROW 60000, N'InvoiceRequestUpsert: PaymentStatusGuid not found.', 1;

    -- Ensure DataObject exists (always do this)
    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SFin',
        @ObjectName = N'InvoiceRequests',
        @IncludeDefaultSecurity = 0,
        @IsInsert = @DataObjectWasInserted OUTPUT;

    -- IMPORTANT: Decide insert/update based on SFin.InvoiceRequests, NOT DataObjects
    IF NOT EXISTS (SELECT 1 FROM SFin.InvoiceRequests WITH (UPDLOCK, HOLDLOCK) WHERE [Guid] = @Guid)
    BEGIN
        INSERT SFin.InvoiceRequests
        (
            RowStatus,
            Guid,
            Notes,
            RequesterUserId,
            CreatedDateTimeUTC,
            JobId,
            InvoicingType,
            ExpectedDate,
            ManualStatus,
            InvoicePaymentStatusID
        )
        VALUES
        (
            1,
            @Guid,
            @Notes,
            @RequesterUserId,
            GETUTCDATE(),
            @JobID,
            ISNULL(@InvoicingType, N''),
            @ExpectedDate,
            ISNULL(@ManualStatus, 0),
            @PaymentStatusID
        );
    END
    ELSE
    BEGIN
        UPDATE ir
        SET
            ir.Notes = @Notes,
            ir.JobId = @JobID,
            ir.InvoicingType = ISNULL(@InvoicingType, N''),
            ir.ExpectedDate = @ExpectedDate,
            ir.ManualStatus = ISNULL(@ManualStatus, 0),
            ir.InvoicePaymentStatusID = @PaymentStatusID,
			ir.RequesterUserId = @RequesterUserId
        FROM SFin.InvoiceRequests ir
        WHERE ir.[Guid] = @Guid;
    END
END
GO