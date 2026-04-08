CREATE OR ALTER PROCEDURE [SFin].[SageInboundDocumentAttempt_Insert]
(
    @InboundStatusID      BIGINT,
    @CymBuildDocumentGuid UNIQUEIDENTIFIER,
    @CymBuildDocumentID   BIGINT,
    @OperationName        NVARCHAR(100),
    @AttemptedOnUtc       DATETIME2(7),
    @CompletedOnUtc       DATETIME2(7) = NULL,
    @IsSuccess            BIT,
    @IsRetryableFailure   BIT,
    @ResponseStatus       NVARCHAR(50),
    @ResponseDetail       NVARCHAR(MAX) = NULL,
    @ErrorMessage         NVARCHAR(MAX) = NULL,
    @RequestPayloadJson   NVARCHAR(MAX) = NULL,
    @ResponsePayloadJson  NVARCHAR(MAX) = NULL,
    @Guid                 UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF (@Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000')
    BEGIN
        SET @Guid = NEWID();
    END;

    DECLARE @IsInsert BIT;

    EXEC SCore.UpsertDataObject
         @Guid       = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'SageInboundDocumentAttempts',
         @IsInsert   = @IsInsert OUTPUT;

    INSERT INTO SFin.SageInboundDocumentAttempts
    (
        RowStatus,
        Guid,
        InboundStatusID,
        CymBuildDocumentGuid,
        CymBuildDocumentID,
        OperationName,
        AttemptedOnUtc,
        CompletedOnUtc,
        IsSuccess,
        IsRetryableFailure,
        ResponseStatus,
        ResponseDetail,
        ErrorMessage,
        RequestPayloadJson,
        ResponsePayloadJson,
        CreatedByUserID,
        CreatedDateTimeUTC
    )
    VALUES
    (
        1,
        @Guid,
        @InboundStatusID,
        @CymBuildDocumentGuid,
        @CymBuildDocumentID,
        @OperationName,
        @AttemptedOnUtc,
        @CompletedOnUtc,
        @IsSuccess,
        @IsRetryableFailure,
        @ResponseStatus,
        @ResponseDetail,
        @ErrorMessage,
        @RequestPayloadJson,
        @ResponsePayloadJson,
        SCore.GetCurrentUserId(),
        GETUTCDATE()
    );
END;
GO