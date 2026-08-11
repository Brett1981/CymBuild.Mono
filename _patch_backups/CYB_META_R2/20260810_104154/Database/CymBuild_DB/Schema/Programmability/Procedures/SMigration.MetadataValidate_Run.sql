SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataValidate_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataValidate_Run]')
GO

CREATE PROCEDURE [SMigration].[MetadataValidate_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FailCount INT = 0;
    DECLARE @WarnCount INT = 0;
    DECLARE @InfoCount INT = 0;

    BEGIN TRANSACTION;

    -- Only clear validation issues owned by this validation proc.
    -- Do NOT delete staging-discovered blockers such as DuplicateSourceGuid.
    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'RunNotFound',
          N'DuplicateStagedRow'
      );

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
    BEGIN
        INSERT INTO SMigration.Metadata_ValidationIssues
        (
            Guid,
            RowStatus,
            RunGuid,
            RegistryGuid,
            SourceRowGuid,
            Severity,
            IssueCode,
            IssueMessage,
            DetailsJson,
            CreatedOnUtc
        )
        SELECT
            NEWID(),
            1,
            @RunGuid,
            NULL,
            NULL,
            N'Fail',
            N'RunNotFound',
            N'Metadata migration run does not exist or is inactive.',
            N'{}',
            SYSUTCDATETIME();
    END;

    INSERT INTO SMigration.Metadata_ValidationIssues
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SourceRowGuid,
        Severity,
        IssueCode,
        IssueMessage,
        DetailsJson,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        @RunGuid,
        sr.RegistryGuid,
        sr.SourceRowGuid,
        N'Fail',
        N'DuplicateStagedRow',
        N'The staged run contains duplicate rows for the same table and source row Guid.',
        CONCAT(N'{"SourceRowGuid":"', CONVERT(NVARCHAR(36), sr.SourceRowGuid), N'"}'),
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
    GROUP BY
        sr.RegistryGuid,
        sr.SourceRowGuid
    HAVING COUNT_BIG(1) > 1;

    SELECT
        @FailCount = SUM(CASE WHEN vi.Severity = N'Fail' THEN 1 ELSE 0 END),
        @WarnCount = SUM(CASE WHEN vi.Severity = N'Warn' THEN 1 ELSE 0 END),
        @InfoCount = SUM(CASE WHEN vi.Severity = N'Info' THEN 1 ELSE 0 END)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254);

    SET @FailCount = ISNULL(@FailCount, 0);
    SET @WarnCount = ISNULL(@WarnCount, 0);
    SET @InfoCount = ISNULL(@InfoCount, 0);

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = CASE WHEN @FailCount > 0 THEN N'ValidationFailed' ELSE N'Validated' END,
        ValidatedOnUtc = SYSUTCDATETIME(),
        SummaryJson = CONCAT
        (
            N'{"failCount":',
            CONVERT(NVARCHAR(30), @FailCount),
            N',"warnCount":',
            CONVERT(NVARCHAR(30), @WarnCount),
            N',"infoCount":',
            CONVERT(NVARCHAR(30), @InfoCount),
            N'}'
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
    DECLARE @_StepStatus AS NVARCHAR(15) = (CASE WHEN @FailCount > 0 THEN N'Failed' ELSE N'Succeeded' END)
    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ValidateRun',
        @StepStatus = @_StepStatus,
        @Message = N'Metadata migration validation completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;

    SELECT
        @FailCount AS FailCount,
        @WarnCount AS WarnCount,
        @InfoCount AS InfoCount;
END;
GO