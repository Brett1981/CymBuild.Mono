SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRun_Create]')
GO

CREATE PROCEDURE [SMigration].[MetadataRun_Create]
(
    @SourceEnvironment NVARCHAR(20),
    @TargetEnvironment NVARCHAR(20),
    @SourceServerName NVARCHAR(255),
    @SourceDatabaseName NVARCHAR(255),
    @TargetServerName NVARCHAR(255),
    @TargetDatabaseName NVARCHAR(255),
    @IsValidateOnly BIT = 1,
    @RunGuid UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @RunGuid = ISNULL(NULLIF(@RunGuid, '00000000-0000-0000-0000-000000000000'), NEWID());

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @RunGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Metadata_Run';

    INSERT INTO SMigration.Metadata_Run
    (
        Guid,
        RowStatus,
        SourceEnvironment,
        TargetEnvironment,
        SourceServerName,
        SourceDatabaseName,
        TargetServerName,
        TargetDatabaseName,
        RunStatus,
        IsValidateOnly,
        CreatedOnUtc,
        CreatedByUserId,
        SummaryJson
    )
    SELECT
        @RunGuid,
        1,
        @SourceEnvironment,
        @TargetEnvironment,
        @SourceServerName,
        @SourceDatabaseName,
        @TargetServerName,
        @TargetDatabaseName,
        N'Created',
        ISNULL(@IsValidateOnly, 1),
        SYSUTCDATETIME(),
        ISNULL(SCore.GetCurrentUserId(), -1),
        N'{}'
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
    );

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'CreateRun',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata migration run created.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;
END;
GO