SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'SMigration.Metadata_IdentityMapIgnoredIssues', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Metadata_IdentityMapIgnoredIssues
    (
        ID BIGINT IDENTITY NOT NULL,
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_RowStatus DEFAULT (1),
        DatabaseName SYSNAME NOT NULL,
        ServerName NVARCHAR(255) NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_ServerName DEFAULT (N''),
        EnvironmentName NVARCHAR(20) NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_EnvironmentName DEFAULT (N''),
        RegistryGuid UNIQUEIDENTIFIER NOT NULL,
        SchemaName NVARCHAR(128) NOT NULL,
        TableName NVARCHAR(128) NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        IssueCode NVARCHAR(50) NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_IssueCode DEFAULT (N'TargetMissing'),
        StableIssueKey NVARCHAR(800) NOT NULL,
        Reason NVARCHAR(500) NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_Reason DEFAULT (N''),
        IgnoredByUserId INT NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_IgnoredByUserId DEFAULT (-1),
        IgnoredOnUtc DATETIME2 NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_IgnoredOnUtc DEFAULT (SYSUTCDATETIME()),
        UnignoredByUserId INT NULL,
        UnignoredOnUtc DATETIME2 NULL,
        LastSeenRunGuid UNIQUEIDENTIFIER NULL,
        LastSeenOnUtc DATETIME2 NULL,
        CONSTRAINT PK_Metadata_IdentityMapIgnoredIssues PRIMARY KEY CLUSTERED (ID) WITH (FILLFACTOR = 80),
        CONSTRAINT UQ_Metadata_IdentityMapIgnoredIssues_Guid UNIQUE (Guid) WITH (FILLFACTOR = 80)
    );
END;
GO

IF COL_LENGTH(N'SMigration.Metadata_IdentityMapIgnoredIssues', N'StableIssueKey') IS NULL
BEGIN
    ALTER TABLE SMigration.Metadata_IdentityMapIgnoredIssues ADD StableIssueKey NVARCHAR(800) NOT NULL CONSTRAINT DF_Metadata_IdentityMapIgnoredIssues_StableIssueKey DEFAULT (N'');
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'SMigration.Metadata_IdentityMapIgnoredIssues', N'U')
      AND name = N'UX_Metadata_IdentityMapIgnoredIssues_ActiveScope'
)
BEGIN
    CREATE UNIQUE INDEX UX_Metadata_IdentityMapIgnoredIssues_ActiveScope
        ON SMigration.Metadata_IdentityMapIgnoredIssues (DatabaseName, RegistryGuid, SourceRowGuid, IssueCode)
        WHERE RowStatus NOT IN (0,254)
        WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'SMigration.Metadata_IdentityMapIgnoredIssues', N'U')
      AND name = N'IX_Metadata_IdentityMapIgnoredIssues_DatabaseTable'
)
BEGIN
    CREATE INDEX IX_Metadata_IdentityMapIgnoredIssues_DatabaseTable
        ON SMigration.Metadata_IdentityMapIgnoredIssues (DatabaseName, SchemaName, TableName, RowStatus)
        WITH (FILLFACTOR = 80);
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIdentityMapDetails_List]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128) = N'',
    @TableName NVARCHAR(128) = N'',
    @IncludeIgnored BIT = 1
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
        THROW 52300, 'Metadata identity map detail could not find the selected run.', 1;

    SELECT
        maprow.SchemaName,
        maprow.TableName,
        maprow.SourceRowGuid,
        ISNULL(maprow.SourceRowId, 0) AS SourceRowId,
        maprow.TargetRowId,
        ISNULL(sr.DifferenceType, N'') AS DifferenceType,
        COALESCE
        (
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Name'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.FullName'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Code'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Description'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Title'), N''),
            CONVERT(NVARCHAR(36), maprow.SourceRowGuid)
        ) AS SourceDisplayName,
        CASE WHEN maprow.TargetRowId IS NULL THEN N'TargetMissing' ELSE N'Resolved' END AS IssueCode,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Resolved'
            WHEN ign.ID IS NOT NULL THEN N'Ignored'
            ELSE N'Needs review'
        END AS IssueStatus,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Target row was matched by stable Guid.'
            ELSE N'Source metadata row has no matching target row by stable Guid.'
        END AS Reason,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL THEN N'No action required.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN N'Expected for new metadata: preview/apply will insert this row if it is included and not ignored. If this is historic or acceptable, keep this identity issue ignored or ignore the staged metadata record.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Update' THEN N'Review target Guid alignment. Restage after correcting the target record, or ignore this identity issue only when the mismatch is known and acceptable.'
            ELSE N'Review the staged metadata row and decide whether it should be included, ignored, or corrected in the target database before apply.'
        END AS SuggestedAction,
        CONVERT(BIT, CASE WHEN maprow.TargetRowId IS NOT NULL THEN 1 ELSE 0 END) AS IsResolved,
        CONVERT(BIT, CASE WHEN ign.ID IS NULL THEN 0 ELSE 1 END) AS IsIgnoredIssue,
        ISNULL(ign.Reason, N'') AS IgnoreReason,
        CASE WHEN ign.IgnoredOnUtc IS NULL THEN N'' ELSE CONVERT(NVARCHAR(30), ign.IgnoredOnUtc, 126) END AS IgnoredOnUtc,
        ISNULL(sr.SourcePayloadJson, N'{}') AS SourcePayloadJson
    FROM SMigration.Metadata_ApplyIdentityMap AS maprow
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = maprow.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS sr
        ON sr.RunGuid = maprow.RunGuid
       AND sr.RegistryGuid = maprow.RegistryGuid
       AND sr.SourceRowGuid = maprow.SourceRowGuid
       AND sr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapIgnoredIssues AS ign
        ON ign.DatabaseName = @TargetDatabaseName
       AND ign.RegistryGuid = maprow.RegistryGuid
       AND ign.SourceRowGuid = maprow.SourceRowGuid
       AND ign.IssueCode = N'TargetMissing'
       AND ign.RowStatus NOT IN (0,254)
    WHERE maprow.RunGuid = @RunGuid
      AND maprow.RowStatus NOT IN (0,254)
      AND (@SchemaName = N'' OR maprow.SchemaName = @SchemaName)
      AND (@TableName = N'' OR maprow.TableName = @TableName)
      AND (@IncludeIgnored = 1 OR ign.ID IS NULL)
    ORDER BY
        CASE WHEN maprow.TargetRowId IS NOT NULL THEN 2 WHEN ign.ID IS NOT NULL THEN 1 ELSE 0 END,
        maprow.SchemaName,
        maprow.TableName,
        ISNULL(maprow.SourceRowId, 0),
        maprow.SourceRowGuid;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIdentityMapIssue_Upsert]
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
