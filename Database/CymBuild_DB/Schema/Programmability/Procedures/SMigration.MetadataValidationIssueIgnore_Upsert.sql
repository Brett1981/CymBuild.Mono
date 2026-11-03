SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[MetadataValidationIssueIgnore_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataValidationIssueIgnore_Upsert]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ValidationIssueGuid UNIQUEIDENTIFIER,
    @Reason NVARCHAR(500) = N'',
    @IsIgnored BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @IgnoreGuid UNIQUEIDENTIFIER,
        @RegistryGuid UNIQUEIDENTIFIER,
        @SourceRowGuid UNIQUEIDENTIFIER,
        @IssueCode NVARCHAR(100),
        @SchemaName NVARCHAR(128),
        @TableName NVARCHAR(128),
        @TargetDatabaseName SYSNAME,
        @TargetServerName NVARCHAR(255),
        @TargetEnvironment NVARCHAR(20),
        @StableIssueKey NVARCHAR(800),
        @CurrentUserId INT = ISNULL(SCore.GetCurrentUserId(), -1),
        @DetailsJson NVARCHAR(MAX),
        @StepStatus NVARCHAR(30),
        @LogMessage NVARCHAR(2000);

    SELECT
        @TargetDatabaseName = run.TargetDatabaseName,
        @TargetServerName = run.TargetServerName,
        @TargetEnvironment = run.TargetEnvironment
    FROM SMigration.Metadata_Run AS run
    WHERE run.Guid = @RunGuid
      AND run.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52930, 'Metadata validation issue ignore could not find the selected run.', 1;

    SELECT TOP (1)
        @RegistryGuid = issue.RegistryGuid,
        @SourceRowGuid = issue.SourceRowGuid,
        @IssueCode = issue.IssueCode,
        @SchemaName = registry.SchemaName,
        @TableName = registry.TableName
    FROM SMigration.Metadata_ValidationIssues AS issue
    INNER JOIN SMigration.Metadata_TableRegistry AS registry
        ON registry.Guid = issue.RegistryGuid
       AND registry.RowStatus NOT IN (0,254)
    WHERE issue.RunGuid = @RunGuid
      AND issue.Guid = @ValidationIssueGuid
      AND issue.RowStatus NOT IN (0,254);

    IF @RegistryGuid IS NULL OR @SourceRowGuid IS NULL OR @IssueCode IS NULL
        THROW 52931, 'The selected metadata validation issue is not an active record-scoped issue.', 1;

    IF @IssueCode NOT IN (N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
        THROW 52932, 'Only DuplicateSourceGuid/DuplicateTargetGuid/DuplicateTargetKey/UnresolvedReference record issues can be ignored. Structural migration failures must be corrected.', 1;

    IF ISNULL(@IsIgnored, 0) = 1 AND NULLIF(LTRIM(RTRIM(ISNULL(@Reason, N''))), N'') IS NULL
        THROW 52933, 'An ignore reason is required for audit.', 1;

    SET @StableIssueKey = CONCAT
    (
        @TargetDatabaseName,
        N':',
        @SchemaName,
        N'.',
        @TableName,
        N':',
        CONVERT(NVARCHAR(36), @SourceRowGuid),
        N':',
        @IssueCode
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        IF ISNULL(@IsIgnored, 0) = 1
        BEGIN
            SELECT TOP (1)
                @IgnoreGuid = ignored.Guid
            FROM SMigration.Metadata_ValidationIssueIgnores AS ignored WITH (UPDLOCK, HOLDLOCK)
            WHERE ignored.DatabaseName = @TargetDatabaseName
              AND ignored.RegistryGuid = @RegistryGuid
              AND ignored.SourceRowGuid = @SourceRowGuid
              AND ignored.IssueCode = @IssueCode
            ORDER BY
                CASE WHEN ignored.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END,
                ignored.ID DESC;

            SET @IgnoreGuid = ISNULL(@IgnoreGuid, NEWID());

            EXEC SMigration.MetadataDataObject_Ensure
                @Guid = @IgnoreGuid,
                @SchemeName = N'SMigration',
                @ObjectName = N'Metadata_ValidationIssueIgnores';

            IF EXISTS
            (
                SELECT 1
                FROM SMigration.Metadata_ValidationIssueIgnores AS ignored
                WHERE ignored.Guid = @IgnoreGuid
            )
            BEGIN
                UPDATE SMigration.Metadata_ValidationIssueIgnores
                SET
                    RowStatus = 1,
                    DatabaseName = @TargetDatabaseName,
                    ServerName = ISNULL(@TargetServerName, N''),
                    EnvironmentName = ISNULL(@TargetEnvironment, N''),
                    RegistryGuid = @RegistryGuid,
                    SchemaName = @SchemaName,
                    TableName = @TableName,
                    SourceRowGuid = @SourceRowGuid,
                    IssueCode = @IssueCode,
                    StableIssueKey = @StableIssueKey,
                    Reason = LTRIM(RTRIM(@Reason)),
                    IgnoredByUserId = @CurrentUserId,
                    IgnoredOnUtc = SYSUTCDATETIME(),
                    UnignoredByUserId = NULL,
                    UnignoredOnUtc = NULL,
                    LastSeenRunGuid = @RunGuid,
                    LastSeenOnUtc = SYSUTCDATETIME()
                WHERE Guid = @IgnoreGuid;
            END
            ELSE
            BEGIN
                INSERT INTO SMigration.Metadata_ValidationIssueIgnores
                (
                    Guid,
                    RowStatus,
                    DatabaseName,
                    ServerName,
                    EnvironmentName,
                    RegistryGuid,
                    SchemaName,
                    TableName,
                    SourceRowGuid,
                    IssueCode,
                    StableIssueKey,
                    Reason,
                    IgnoredByUserId,
                    IgnoredOnUtc,
                    UnignoredByUserId,
                    UnignoredOnUtc,
                    LastSeenRunGuid,
                    LastSeenOnUtc
                )
                SELECT
                    @IgnoreGuid,
                    1,
                    @TargetDatabaseName,
                    ISNULL(@TargetServerName, N''),
                    ISNULL(@TargetEnvironment, N''),
                    @RegistryGuid,
                    @SchemaName,
                    @TableName,
                    @SourceRowGuid,
                    @IssueCode,
                    @StableIssueKey,
                    LTRIM(RTRIM(@Reason)),
                    @CurrentUserId,
                    SYSUTCDATETIME(),
                    NULL,
                    NULL,
                    @RunGuid,
                    SYSUTCDATETIME();
            END;
        END
        ELSE
        BEGIN
            DECLARE @IssuesToRestore TABLE
            (
                IgnoreGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
            );

            INSERT INTO @IssuesToRestore
            (
                IgnoreGuid
            )
            SELECT
                ignored.Guid
            FROM SMigration.Metadata_ValidationIssueIgnores AS ignored WITH (UPDLOCK, HOLDLOCK)
            WHERE ignored.DatabaseName = @TargetDatabaseName
              AND ignored.RegistryGuid = @RegistryGuid
              AND ignored.SourceRowGuid = @SourceRowGuid
              AND ignored.IssueCode = @IssueCode
              AND ignored.RowStatus NOT IN (0,254);

            DECLARE @GuidToRestore UNIQUEIDENTIFIER;
            DECLARE RestoreCursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT restoreRows.IgnoreGuid
                FROM @IssuesToRestore AS restoreRows
                ORDER BY restoreRows.IgnoreGuid;

            OPEN RestoreCursor;
            FETCH NEXT FROM RestoreCursor INTO @GuidToRestore;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC SCore.DeleteDataObject
                    @Guid = @GuidToRestore;

                FETCH NEXT FROM RestoreCursor INTO @GuidToRestore;
            END;

            CLOSE RestoreCursor;
            DEALLOCATE RestoreCursor;

            UPDATE ignored
            SET
                ignored.RowStatus = 254,
                ignored.UnignoredByUserId = @CurrentUserId,
                ignored.UnignoredOnUtc = SYSUTCDATETIME(),
                ignored.LastSeenRunGuid = @RunGuid,
                ignored.LastSeenOnUtc = SYSUTCDATETIME()
            FROM SMigration.Metadata_ValidationIssueIgnores AS ignored
            INNER JOIN @IssuesToRestore AS restoreRows
                ON restoreRows.IgnoreGuid = ignored.Guid
            WHERE ignored.RowStatus NOT IN (0,254);
        END;

        UPDATE SMigration.Metadata_Run
        SET
            RunStatus = N'Staged',
            ValidatedOnUtc = NULL
        WHERE Guid = @RunGuid
          AND RowStatus NOT IN (0,254);

        SET @DetailsJson =
        (
            SELECT
                CONVERT(NVARCHAR(36), @ValidationIssueGuid) AS validationIssueGuid,
                @IssueCode AS issueCode,
                CONVERT(NVARCHAR(36), @SourceRowGuid) AS sourceRowGuid,
                CONVERT(INT, ISNULL(@IsIgnored, 0)) AS isIgnored,
                CASE WHEN ISNULL(@IsIgnored, 0) = 1 THEN LTRIM(RTRIM(@Reason)) ELSE N'' END AS reason
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @StepStatus = CASE WHEN ISNULL(@IsIgnored, 0) = 1 THEN N'Ignored' ELSE N'Restored' END;
        SET @LogMessage = CASE
            WHEN ISNULL(@IsIgnored, 0) = 1 THEN N'Metadata validation issue ignored.'
            ELSE N'Metadata validation issue restored.'
        END;

        EXEC SMigration.MetadataExecutionLog_Add
            @RunGuid = @RunGuid,
            @StepName = N'ValidationIssueIgnore',
            @StepStatus = @StepStatus,
            @Message = @LogMessage,
            @DetailsJson = @DetailsJson;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
