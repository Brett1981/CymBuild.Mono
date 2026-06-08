SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataExecutionLog_Add]')
GO

CREATE PROCEDURE [SMigration].[MetadataExecutionLog_Add]
(
    @RunGuid     UNIQUEIDENTIFIER,
    @StepName    NVARCHAR(100),
    @StepStatus  NVARCHAR(30),
    @Message     NVARCHAR(2000) = N'',
    @DetailsJson NVARCHAR(MAX) = N'{}'
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogGuid UNIQUEIDENTIFIER = NEWID();

    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @LogGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Metadata_ExecutionLog';

    INSERT INTO SMigration.Metadata_ExecutionLog
    (
        Guid,
        RowStatus,
        RunGuid,
        StepName,
        StepStatus,
        Message,
        DetailsJson,
        CreatedOnUtc
    )
    SELECT
        @LogGuid,
        1,
        @RunGuid,
        @StepName,
        @StepStatus,
        ISNULL(@Message, N''),
        ISNULL(@DetailsJson, N'{}'),
        SYSUTCDATETIME();
END;
GO