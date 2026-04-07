USE [CymBuild_Dev]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [SFin].[TransactionSageSubmissionStatus_Ensure]
(
    @TransactionID       BIGINT,
    @TransactionGuid     UNIQUEIDENTIFIER,
    @TransitionGuid      UNIQUEIDENTIFIER = NULL,
    @CreatedByUserID     INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StatusGuid UNIQUEIDENTIFIER;
    DECLARE @IsInsert BIT;
    DECLARE @ExistingStatusId BIGINT;

    BEGIN TRAN;

    SELECT
        @ExistingStatusId = s.ID
    FROM SFin.TransactionSageSubmissionStatus AS s WITH (UPDLOCK, HOLDLOCK)
    WHERE s.TransactionGuid = @TransactionGuid
      AND s.RowStatus NOT IN (0, 254);

    IF (@ExistingStatusId IS NULL)
    BEGIN
        SET @StatusGuid = NEWID();

        EXEC SCore.UpsertDataObject
             @Guid       = @StatusGuid,
             @SchemeName = N'SFin',
             @ObjectName = N'TransactionSageSubmissionStatus',
             @IsInsert   = @IsInsert OUTPUT;

        INSERT INTO SFin.TransactionSageSubmissionStatus
        (
            RowStatus,
            Guid,
            TransactionID,
            TransactionGuid,
            LastTransitionGuid,
            LastOperationName,
            StatusCode,
            IsInProgress,
            CreatedDateTimeUTC,
            CreatedByUserID,
            UpdatedDateTimeUTC,
            UpdatedByUserID
        )
        VALUES
        (
            1,
            @StatusGuid,
            @TransactionID,
            @TransactionGuid,
            @TransitionGuid,
            N'CreateSalesOrder',
            N'Pending',
            0,
            SYSUTCDATETIME(),
            ISNULL(@CreatedByUserID, -1),
            SYSUTCDATETIME(),
            ISNULL(@CreatedByUserID, -1)
        );
    END

    COMMIT TRAN;
END;
GO