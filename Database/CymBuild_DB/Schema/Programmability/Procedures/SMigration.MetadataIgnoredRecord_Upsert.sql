SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecord_Upsert]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecord_Upsert]')
GO

CREATE PROCEDURE [SMigration].[MetadataIgnoredRecord_Upsert]
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
        @IgnoreGuid UNIQUEIDENTIFIER,
        @RegistryGuid UNIQUEIDENTIFIER,
        @DifferenceType NVARCHAR(30),
        @TargetDatabaseName SYSNAME,
        @TargetServerName NVARCHAR(255),
        @TargetEnvironment NVARCHAR(20),
        @StableRecordKey NVARCHAR(600),
        @CurrentUserId INT = ISNULL(SCore.GetCurrentUserId(), -1);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName,
        @TargetServerName = r.TargetServerName,
        @TargetEnvironment = r.TargetEnvironment
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52200, 'Metadata ignore could not find the selected run.', 1;

    SELECT TOP (1)
        @RegistryGuid = tr.Guid,
        @DifferenceType = sr.DifferenceType
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND tr.SchemaName = @SchemaName
      AND tr.TableName = @TableName
      AND sr.SourceRowGuid = @SourceRowGuid;

    IF @RegistryGuid IS NULL
        THROW 52201, 'Metadata ignore could not find the staged record for the selected run.', 1;

    SET @StableRecordKey = CONCAT(@TargetDatabaseName, N':', @SchemaName, N'.', @TableName, N':', CONVERT(NVARCHAR(36), @SourceRowGuid));

    IF ISNULL(@IsIgnored, 0) = 1
    BEGIN
        SELECT TOP (1)
            @IgnoreGuid = ign.Guid
        FROM SMigration.Metadata_IgnoredRecords AS ign
        WHERE ign.DatabaseName = @TargetDatabaseName
          AND ign.RegistryGuid = @RegistryGuid
          AND ign.SourceRowGuid = @SourceRowGuid
        ORDER BY CASE WHEN ign.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END, ign.ID DESC;

        SET @IgnoreGuid = ISNULL(@IgnoreGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @IgnoreGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_IgnoredRecords';

        IF EXISTS (SELECT 1 FROM SMigration.Metadata_IgnoredRecords AS ign WHERE ign.Guid = @IgnoreGuid)
        BEGIN
            UPDATE SMigration.Metadata_IgnoredRecords
            SET
                RowStatus = 1,
                DatabaseName = @TargetDatabaseName,
                ServerName = ISNULL(@TargetServerName, N''),
                EnvironmentName = ISNULL(@TargetEnvironment, N''),
                RegistryGuid = @RegistryGuid,
                SchemaName = @SchemaName,
                TableName = @TableName,
                SourceRowGuid = @SourceRowGuid,
                StableRecordKey = @StableRecordKey,
                DifferenceType = ISNULL(@DifferenceType, N''),
                IgnoreScope = N'TargetDatabase',
                Reason = ISNULL(@Reason, N''),
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
            INSERT INTO SMigration.Metadata_IgnoredRecords
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
                StableRecordKey,
                DifferenceType,
                IgnoreScope,
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
                @StableRecordKey,
                ISNULL(@DifferenceType, N''),
                N'TargetDatabase',
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
        DECLARE @RecordsToClear TABLE
        (
            IgnoreGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
        );

        INSERT INTO @RecordsToClear
        (
            IgnoreGuid
        )
        SELECT
            ign.Guid
        FROM SMigration.Metadata_IgnoredRecords AS ign
        WHERE ign.DatabaseName = @TargetDatabaseName
          AND ign.RegistryGuid = @RegistryGuid
          AND ign.SourceRowGuid = @SourceRowGuid
          AND ign.RowStatus NOT IN (0,254);

        DECLARE @GuidToClear UNIQUEIDENTIFIER;
        DECLARE IgnoreCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT clearRows.IgnoreGuid
            FROM @RecordsToClear AS clearRows
            ORDER BY clearRows.IgnoreGuid;

        OPEN IgnoreCursor;
        FETCH NEXT FROM IgnoreCursor INTO @GuidToClear;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.DeleteDataObject
                @Guid = @GuidToClear;
            FETCH NEXT FROM IgnoreCursor INTO @GuidToClear;
        END;
        CLOSE IgnoreCursor;
        DEALLOCATE IgnoreCursor;

        UPDATE ign
        SET
            ign.RowStatus = 254,
            ign.UnignoredByUserId = @CurrentUserId,
            ign.UnignoredOnUtc = SYSUTCDATETIME(),
            ign.LastSeenRunGuid = @RunGuid,
            ign.LastSeenOnUtc = SYSUTCDATETIME()
        FROM SMigration.Metadata_IgnoredRecords AS ign
        INNER JOIN @RecordsToClear AS clearRows
            ON clearRows.IgnoreGuid = ign.Guid
        WHERE ign.RowStatus NOT IN (0,254);
    END;
END
GO