SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIdentityMapIssue_Upsert]')
GO

PRINT (N'Create procedure [SMigration].[MetadataIdentityMapIssue_Upsert]')
GO

CREATE PROCEDURE [SMigration].[MetadataIdentityMapIssue_Upsert]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128),
    @SourceRowGuid UNIQUEIDENTIFIER,
    @Reason NVARCHAR(500) = N'',
    @IsIgnored BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @IssueGuid UNIQUEIDENTIFIER,
        @RegistryGuid UNIQUEIDENTIFIER,
        @TargetDatabaseName SYSNAME,
        @TargetServerName NVARCHAR(255),
        @TargetEnvironment NVARCHAR(20),
        @StableIssueKey NVARCHAR(800),
        @CurrentUserId INT = ISNULL(SCore.GetCurrentUserId(), -1);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName,
        @TargetServerName = r.TargetServerName,
        @TargetEnvironment = r.TargetEnvironment
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52310, 'Metadata identity map issue could not find the selected run.', 1;

    SELECT TOP (1)
        @RegistryGuid = maprow.RegistryGuid
    FROM SMigration.Metadata_ApplyIdentityMap AS maprow
    WHERE maprow.RunGuid = @RunGuid
      AND maprow.RowStatus NOT IN (0,254)
      AND maprow.SchemaName = @SchemaName
      AND maprow.TableName = @TableName
      AND maprow.SourceRowGuid = @SourceRowGuid;

    IF @RegistryGuid IS NULL
        THROW 52311, 'Metadata identity map issue could not find the selected identity map row.', 1;

    SET @StableIssueKey = CONCAT(@TargetDatabaseName, N':', @SchemaName, N'.', @TableName, N':', CONVERT(NVARCHAR(36), @SourceRowGuid), N':TargetMissing');

    IF ISNULL(@IsIgnored, 0) = 1
    BEGIN
        SELECT TOP (1)
            @IssueGuid = ign.Guid
        FROM SMigration.Metadata_IdentityMapIgnoredIssues AS ign
        WHERE ign.DatabaseName = @TargetDatabaseName
          AND ign.RegistryGuid = @RegistryGuid
          AND ign.SourceRowGuid = @SourceRowGuid
          AND ign.IssueCode = N'TargetMissing'
        ORDER BY CASE WHEN ign.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END, ign.ID DESC;

        SET @IssueGuid = ISNULL(@IssueGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @IssueGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_IdentityMapIgnoredIssues';

        IF EXISTS (SELECT 1 FROM SMigration.Metadata_IdentityMapIgnoredIssues AS ign WHERE ign.Guid = @IssueGuid)
        BEGIN
            UPDATE SMigration.Metadata_IdentityMapIgnoredIssues
            SET
                RowStatus = 1,
                DatabaseName = @TargetDatabaseName,
                ServerName = ISNULL(@TargetServerName, N''),
                EnvironmentName = ISNULL(@TargetEnvironment, N''),
                RegistryGuid = @RegistryGuid,
                SchemaName = @SchemaName,
                TableName = @TableName,
                SourceRowGuid = @SourceRowGuid,
                IssueCode = N'TargetMissing',
                StableIssueKey = @StableIssueKey,
                Reason = ISNULL(@Reason, N''),
                IgnoredByUserId = @CurrentUserId,
                IgnoredOnUtc = SYSUTCDATETIME(),
                UnignoredByUserId = NULL,
                UnignoredOnUtc = NULL,
                LastSeenRunGuid = @RunGuid,
                LastSeenOnUtc = SYSUTCDATETIME()
            WHERE Guid = @IssueGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Metadata_IdentityMapIgnoredIssues
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
                @IssueGuid,
                1,
                @TargetDatabaseName,
                ISNULL(@TargetServerName, N''),
                ISNULL(@TargetEnvironment, N''),
                @RegistryGuid,
                @SchemaName,
                @TableName,
                @SourceRowGuid,
                N'TargetMissing',
                @StableIssueKey,
                ISNULL(@Reason, N''),
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
        DECLARE @IssuesToClear TABLE
        (
            IssueGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
        );

        INSERT INTO @IssuesToClear (IssueGuid)
        SELECT ign.Guid
        FROM SMigration.Metadata_IdentityMapIgnoredIssues AS ign
        WHERE ign.DatabaseName = @TargetDatabaseName
          AND ign.RegistryGuid = @RegistryGuid
          AND ign.SourceRowGuid = @SourceRowGuid
          AND ign.IssueCode = N'TargetMissing'
          AND ign.RowStatus NOT IN (0,254);

        DECLARE @GuidToClear UNIQUEIDENTIFIER;
        DECLARE IssueCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT clearRows.IssueGuid
            FROM @IssuesToClear AS clearRows
            ORDER BY clearRows.IssueGuid;

        OPEN IssueCursor;
        FETCH NEXT FROM IssueCursor INTO @GuidToClear;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.DeleteDataObject
                @Guid = @GuidToClear;
            FETCH NEXT FROM IssueCursor INTO @GuidToClear;
        END;
        CLOSE IssueCursor;
        DEALLOCATE IssueCursor;

        UPDATE ign
        SET
            ign.RowStatus = 254,
            ign.UnignoredByUserId = @CurrentUserId,
            ign.UnignoredOnUtc = SYSUTCDATETIME(),
            ign.LastSeenRunGuid = @RunGuid,
            ign.LastSeenOnUtc = SYSUTCDATETIME()
        FROM SMigration.Metadata_IdentityMapIgnoredIssues AS ign
        INNER JOIN @IssuesToClear AS clearRows
            ON clearRows.IssueGuid = ign.Guid
        WHERE ign.RowStatus NOT IN (0,254);
    END;
END;
GO