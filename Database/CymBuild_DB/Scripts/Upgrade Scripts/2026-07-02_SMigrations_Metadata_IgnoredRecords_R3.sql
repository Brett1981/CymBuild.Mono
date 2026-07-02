/* CI/CD-safe idempotent SMigration persistent ignored records deployment.
   R3: database-scoped ignore rules for metadata migration.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    EXEC(N'CREATE SCHEMA [SMigration] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'SMigration.Metadata_IgnoredRecords', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Metadata_IgnoredRecords]
    (
        [ID] [bigint] IDENTITY(1,1) NOT NULL,
        [Guid] [uniqueidentifier] NOT NULL,
        [RowStatus] [tinyint] NOT NULL,
        [DatabaseName] [sysname] NOT NULL,
        [ServerName] [nvarchar](255) NOT NULL,
        [EnvironmentName] [nvarchar](20) NOT NULL,
        [RegistryGuid] [uniqueidentifier] NOT NULL,
        [SchemaName] [nvarchar](128) NOT NULL,
        [TableName] [nvarchar](128) NOT NULL,
        [SourceRowGuid] [uniqueidentifier] NOT NULL,
        [StableRecordKey] [nvarchar](600) NOT NULL,
        [DifferenceType] [nvarchar](30) NOT NULL,
        [IgnoreScope] [nvarchar](30) NOT NULL,
        [Reason] [nvarchar](500) NOT NULL,
        [IgnoredByUserId] [int] NOT NULL,
        [IgnoredOnUtc] [datetime2](7) NOT NULL,
        [UnignoredByUserId] [int] NULL,
        [UnignoredOnUtc] [datetime2](7) NULL,
        [LastSeenRunGuid] [uniqueidentifier] NULL,
        [LastSeenOnUtc] [datetime2](7) NULL,
        CONSTRAINT [PK_Metadata_IgnoredRecords] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Metadata_IgnoredRecords_Guid] UNIQUE NONCLUSTERED ([Guid] ASC) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_RowStatus] DEFAULT (1) FOR [RowStatus];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_ServerName' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_ServerName] DEFAULT (N'') FOR [ServerName];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_EnvironmentName' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_EnvironmentName] DEFAULT (N'') FOR [EnvironmentName];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_DifferenceType' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_DifferenceType] DEFAULT (N'') FOR [DifferenceType];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_IgnoreScope' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_IgnoreScope] DEFAULT (N'TargetDatabase') FOR [IgnoreScope];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_Reason' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_Reason] DEFAULT (N'') FOR [Reason];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_IgnoredByUserId' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_IgnoredByUserId] DEFAULT (-1) FOR [IgnoredByUserId];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_IgnoredRecords_IgnoredOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
    ALTER TABLE [SMigration].[Metadata_IgnoredRecords] ADD CONSTRAINT [DF_Metadata_IgnoredRecords_IgnoredOnUtc] DEFAULT (SYSUTCDATETIME()) FOR [IgnoredOnUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Metadata_IgnoredRecords_ActiveScope' AND object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
BEGIN
    CREATE UNIQUE INDEX [UX_Metadata_IgnoredRecords_ActiveScope]
        ON [SMigration].[Metadata_IgnoredRecords] ([DatabaseName], [RegistryGuid], [SourceRowGuid])
        WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
        WITH (FILLFACTOR = 80)
        ON [PRIMARY];
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Metadata_IgnoredRecords_DatabaseTable' AND object_id = OBJECT_ID(N'SMigration.Metadata_IgnoredRecords'))
BEGIN
    CREATE INDEX [IX_Metadata_IgnoredRecords_DatabaseTable]
        ON [SMigration].[Metadata_IgnoredRecords] ([DatabaseName], [SchemaName], [TableName], [RowStatus])
        WITH (FILLFACTOR = 80)
        ON [PRIMARY];
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecord_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIgnoredRecord_Upsert]
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecords_List]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIgnoredRecords_List]
(
    @RunGuid UNIQUEIDENTIFIER,
    @IncludeInactive BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetDatabaseName SYSNAME;

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52210, 'Metadata ignored records list could not find the selected run.', 1;

    SELECT
        ign.Guid,
        ign.DatabaseName,
        ign.SchemaName,
        ign.TableName,
        ign.SourceRowGuid,
        ign.StableRecordKey,
        ign.Reason,
        ign.IgnoredByUserId,
        CONVERT(NVARCHAR(30), ign.IgnoredOnUtc, 126) AS IgnoredOnUtc,
        CONVERT(NVARCHAR(30), ign.UnignoredOnUtc, 126) AS UnignoredOnUtc,
        ign.RowStatus
    FROM SMigration.Metadata_IgnoredRecords AS ign
    WHERE ign.DatabaseName = @TargetDatabaseName
      AND (ISNULL(@IncludeInactive, 0) = 1 OR ign.RowStatus NOT IN (0,254))
    ORDER BY ign.SchemaName, ign.TableName, ign.IgnoredOnUtc DESC, ign.ID DESC;
END
GO

PRINT N'R3 persistent ignored records objects deployed. Ensure SMigration.MetadataApply_Run source is deployed from this patch so apply and automation skip ignored rows.';
GO
