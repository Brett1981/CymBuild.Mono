SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'SMigration.Metadata_IdentityMapOverrides', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Metadata_IdentityMapOverrides] (
      [ID] [bigint] IDENTITY,
      [Guid] [uniqueidentifier] NOT NULL,
      [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_RowStatus] DEFAULT (1),
      [DatabaseName] [sysname] NOT NULL,
      [ServerName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_ServerName] DEFAULT (N''),
      [EnvironmentName] [nvarchar](20) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_EnvironmentName] DEFAULT (N''),
      [RegistryGuid] [uniqueidentifier] NOT NULL,
      [SchemaName] [nvarchar](128) NOT NULL,
      [TableName] [nvarchar](128) NOT NULL,
      [SourceRowGuid] [uniqueidentifier] NOT NULL,
      [TargetRowGuid] [uniqueidentifier] NOT NULL,
      [TargetRowId] [bigint] NULL,
      [TargetDisplayName] [nvarchar](500) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_TargetDisplayName] DEFAULT (N''),
      [StableOverrideKey] [nvarchar](800) NOT NULL,
      [Reason] [nvarchar](500) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_Reason] DEFAULT (N''),
      [MappedByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_MappedByUserId] DEFAULT (-1),
      [MappedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_MappedOnUtc] DEFAULT (sysutcdatetime()),
      [UnmappedByUserId] [int] NULL,
      [UnmappedOnUtc] [datetime2] NULL,
      [LastSeenRunGuid] [uniqueidentifier] NULL,
      [LastSeenOnUtc] [datetime2] NULL,
      CONSTRAINT [PK_Metadata_IdentityMapOverrides] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
      CONSTRAINT [UQ_Metadata_IdentityMapOverrides_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'SMigration.Metadata_IdentityMapOverrides') AND name = N'UX_Metadata_IdentityMapOverrides_ActiveScope')
BEGIN
    CREATE UNIQUE INDEX [UX_Metadata_IdentityMapOverrides_ActiveScope]
      ON [SMigration].[Metadata_IdentityMapOverrides] ([DatabaseName], [RegistryGuid], [SourceRowGuid])
      WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
      WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'SMigration.Metadata_IdentityMapOverrides') AND name = N'IX_Metadata_IdentityMapOverrides_DatabaseTable')
BEGIN
    CREATE INDEX [IX_Metadata_IdentityMapOverrides_DatabaseTable]
      ON [SMigration].[Metadata_IdentityMapOverrides] ([DatabaseName], [SchemaName], [TableName], [RowStatus])
      WITH (FILLFACTOR = 80);
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIdentityMapDetails_List]')
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
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'ManualOverride'
            WHEN maprow.TargetRowId IS NULL THEN N'TargetMissing'
            ELSE N'Resolved'
        END AS IssueCode,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'Mapped'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Resolved'
            WHEN ign.ID IS NOT NULL THEN N'Ignored'
            ELSE N'Needs review'
        END AS IssueStatus,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'Target row was resolved using a persistent manual mapping override.'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Target row was matched by stable Guid.'
            ELSE N'Source metadata row has no matching target row by stable Guid.'
        END AS Reason,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'Review override if needed. Future identity-map builds will use this mapping for the selected target database.'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'No action required.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN N'Expected for new metadata: preview/apply will insert this row if it is included and not ignored. If this target already exists under a different Guid, select the row and map it to the existing target record.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Update' THEN N'Review target Guid alignment. Use manual mapping only when the source and target rows represent the same logical metadata record.'
            ELSE N'Review the staged metadata row and decide whether it should be included, ignored, manually mapped, or corrected before apply.'
        END AS SuggestedAction,
        CONVERT(BIT, CASE WHEN maprow.TargetRowId IS NOT NULL THEN 1 ELSE 0 END) AS IsResolved,
        CONVERT(BIT, CASE WHEN ign.ID IS NULL THEN 0 ELSE 1 END) AS IsIgnoredIssue,
        ISNULL(ign.Reason, N'') AS IgnoreReason,
        CASE WHEN ign.IgnoredOnUtc IS NULL THEN N'' ELSE CONVERT(NVARCHAR(30), ign.IgnoredOnUtc, 126) END AS IgnoredOnUtc,
        ISNULL(sr.SourcePayloadJson, N'{}') AS SourcePayloadJson,
        CONVERT(BIT, CASE WHEN ov.ID IS NULL THEN 0 ELSE 1 END) AS HasOverride,
        CASE WHEN ov.TargetRowGuid IS NULL THEN N'' ELSE CONVERT(NVARCHAR(36), ov.TargetRowGuid) END AS OverrideTargetRowGuid,
        ISNULL(ov.TargetDisplayName, N'') AS OverrideTargetDisplayName,
        ISNULL(ov.Reason, N'') AS OverrideReason
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
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = maprow.RegistryGuid
       AND ov.SourceRowGuid = maprow.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
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
END
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIdentityMapOverride_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIdentityMapOverride_Upsert]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128),
    @SourceRowGuid UNIQUEIDENTIFIER,
    @TargetRowGuid UNIQUEIDENTIFIER = NULL,
    @Reason NVARCHAR(500) = N'',
    @IsActive BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @OverrideGuid UNIQUEIDENTIFIER,
        @RegistryGuid UNIQUEIDENTIFIER,
        @TargetDatabaseName SYSNAME,
        @TargetServerName NVARCHAR(255),
        @TargetEnvironment NVARCHAR(20),
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @StableOverrideKey NVARCHAR(800),
        @CurrentUserId INT = ISNULL(SCore.GetCurrentUserId(), -1),
        @TargetRowId BIGINT,
        @TargetDisplayName NVARCHAR(500),
        @DisplayExpression NVARCHAR(MAX),
        @HasRowStatus BIT,
        @Sql NVARCHAR(MAX);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName,
        @TargetServerName = r.TargetServerName,
        @TargetEnvironment = r.TargetEnvironment
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52400, 'Metadata identity map override could not find the selected run.', 1;

    SELECT TOP (1)
        @RegistryGuid = tr.Guid,
        @GuidColumnName = tr.GuidColumnName,
        @PrimaryKeyColumnName = tr.PrimaryKeyColumnName
    FROM SMigration.Metadata_TableRegistry AS tr
    WHERE tr.RowStatus NOT IN (0,254)
      AND tr.SchemaName = @SchemaName
      AND tr.TableName = @TableName;

    IF @RegistryGuid IS NULL
        THROW 52401, 'Metadata identity map override could not find the selected registry row.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ApplyIdentityMap AS maprow
        WHERE maprow.RunGuid = @RunGuid
          AND maprow.RegistryGuid = @RegistryGuid
          AND maprow.SourceRowGuid = @SourceRowGuid
          AND maprow.RowStatus NOT IN (0,254)
    )
        THROW 52402, 'Metadata identity map override could not find the selected identity map row.', 1;

    SET @StableOverrideKey = CONCAT(@TargetDatabaseName, N':', @SchemaName, N'.', @TableName, N':', CONVERT(NVARCHAR(36), @SourceRowGuid));

    IF ISNULL(@IsActive, 0) = 1
    BEGIN
        IF @TargetRowGuid IS NULL
            THROW 52403, 'A target row Guid is required when saving an identity map override.', 1;

        SET @DisplayExpression = N'CONVERT(NVARCHAR(36), targetrow.' + QUOTENAME(@GuidColumnName) + N')';

        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)) AND name = N'Title')
            SET @DisplayExpression = N'COALESCE(NULLIF(TRY_CONVERT(NVARCHAR(500), targetrow.[Title]), N''''), ' + @DisplayExpression + N')';
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)) AND name = N'Description')
            SET @DisplayExpression = N'COALESCE(NULLIF(TRY_CONVERT(NVARCHAR(500), targetrow.[Description]), N''''), ' + @DisplayExpression + N')';
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)) AND name = N'Code')
            SET @DisplayExpression = N'COALESCE(NULLIF(TRY_CONVERT(NVARCHAR(500), targetrow.[Code]), N''''), ' + @DisplayExpression + N')';
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)) AND name = N'FullName')
            SET @DisplayExpression = N'COALESCE(NULLIF(TRY_CONVERT(NVARCHAR(500), targetrow.[FullName]), N''''), ' + @DisplayExpression + N')';
        IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)) AND name = N'Name')
            SET @DisplayExpression = N'COALESCE(NULLIF(TRY_CONVERT(NVARCHAR(500), targetrow.[Name]), N''''), ' + @DisplayExpression + N')';

        SET @HasRowStatus = CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)) AND name = N'RowStatus') THEN 1 ELSE 0 END;

        SET @Sql = N'
SELECT TOP (1)
    @TargetRowIdOut = TRY_CONVERT(BIGINT, targetrow.' + QUOTENAME(@PrimaryKeyColumnName) + N'),
    @TargetDisplayNameOut = ' + @DisplayExpression + N'
FROM ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS targetrow
WHERE targetrow.' + QUOTENAME(@GuidColumnName) + N' = @TargetRowGuid'
            + CASE WHEN @HasRowStatus = 1 THEN N'
  AND targetrow.[RowStatus] NOT IN (0,254)' ELSE N'' END + N';';

        EXEC sys.sp_executesql
            @Sql,
            N'@TargetRowGuid UNIQUEIDENTIFIER, @TargetRowIdOut BIGINT OUTPUT, @TargetDisplayNameOut NVARCHAR(500) OUTPUT',
            @TargetRowGuid = @TargetRowGuid,
            @TargetRowIdOut = @TargetRowId OUTPUT,
            @TargetDisplayNameOut = @TargetDisplayName OUTPUT;

        IF @TargetRowId IS NULL
            THROW 52404, 'The selected target row could not be found or is inactive.', 1;

        SELECT TOP (1)
            @OverrideGuid = ov.Guid
        FROM SMigration.Metadata_IdentityMapOverrides AS ov
        WHERE ov.DatabaseName = @TargetDatabaseName
          AND ov.RegistryGuid = @RegistryGuid
          AND ov.SourceRowGuid = @SourceRowGuid
        ORDER BY CASE WHEN ov.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END, ov.ID DESC;

        SET @OverrideGuid = ISNULL(@OverrideGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @OverrideGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_IdentityMapOverrides';

        IF EXISTS (SELECT 1 FROM SMigration.Metadata_IdentityMapOverrides WHERE Guid = @OverrideGuid)
        BEGIN
            UPDATE SMigration.Metadata_IdentityMapOverrides
            SET
                RowStatus = 1,
                DatabaseName = @TargetDatabaseName,
                ServerName = ISNULL(@TargetServerName, N''),
                EnvironmentName = ISNULL(@TargetEnvironment, N''),
                RegistryGuid = @RegistryGuid,
                SchemaName = @SchemaName,
                TableName = @TableName,
                SourceRowGuid = @SourceRowGuid,
                TargetRowGuid = @TargetRowGuid,
                TargetRowId = @TargetRowId,
                TargetDisplayName = ISNULL(@TargetDisplayName, CONVERT(NVARCHAR(36), @TargetRowGuid)),
                StableOverrideKey = @StableOverrideKey,
                Reason = ISNULL(@Reason, N''),
                MappedByUserId = @CurrentUserId,
                MappedOnUtc = SYSUTCDATETIME(),
                UnmappedByUserId = NULL,
                UnmappedOnUtc = NULL,
                LastSeenRunGuid = @RunGuid,
                LastSeenOnUtc = SYSUTCDATETIME()
            WHERE Guid = @OverrideGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Metadata_IdentityMapOverrides
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
                TargetRowGuid,
                TargetRowId,
                TargetDisplayName,
                StableOverrideKey,
                Reason,
                MappedByUserId,
                MappedOnUtc,
                UnmappedByUserId,
                UnmappedOnUtc,
                LastSeenRunGuid,
                LastSeenOnUtc
            )
            SELECT
                @OverrideGuid,
                1,
                @TargetDatabaseName,
                ISNULL(@TargetServerName, N''),
                ISNULL(@TargetEnvironment, N''),
                @RegistryGuid,
                @SchemaName,
                @TableName,
                @SourceRowGuid,
                @TargetRowGuid,
                @TargetRowId,
                ISNULL(@TargetDisplayName, CONVERT(NVARCHAR(36), @TargetRowGuid)),
                @StableOverrideKey,
                ISNULL(@Reason, N''),
                @CurrentUserId,
                SYSUTCDATETIME(),
                NULL,
                NULL,
                @RunGuid,
                SYSUTCDATETIME();
        END;

        UPDATE maprow
        SET maprow.TargetRowId = @TargetRowId
        FROM SMigration.Metadata_ApplyIdentityMap AS maprow
        WHERE maprow.RunGuid = @RunGuid
          AND maprow.RegistryGuid = @RegistryGuid
          AND maprow.SourceRowGuid = @SourceRowGuid
          AND maprow.RowStatus NOT IN (0,254);
    END
    ELSE
    BEGIN
        DECLARE @OverridesToClear TABLE
        (
            OverrideGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
        );

        INSERT INTO @OverridesToClear (OverrideGuid)
        SELECT ov.Guid
        FROM SMigration.Metadata_IdentityMapOverrides AS ov
        WHERE ov.DatabaseName = @TargetDatabaseName
          AND ov.RegistryGuid = @RegistryGuid
          AND ov.SourceRowGuid = @SourceRowGuid
          AND ov.RowStatus NOT IN (0,254);

        DECLARE @GuidToClear UNIQUEIDENTIFIER;
        DECLARE OverrideCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT clearRows.OverrideGuid
            FROM @OverridesToClear AS clearRows
            ORDER BY clearRows.OverrideGuid;

        OPEN OverrideCursor;
        FETCH NEXT FROM OverrideCursor INTO @GuidToClear;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC SCore.DeleteDataObject
                @Guid = @GuidToClear;
            FETCH NEXT FROM OverrideCursor INTO @GuidToClear;
        END;
        CLOSE OverrideCursor;
        DEALLOCATE OverrideCursor;

        UPDATE ov
        SET
            ov.RowStatus = 254,
            ov.UnmappedByUserId = @CurrentUserId,
            ov.UnmappedOnUtc = SYSUTCDATETIME(),
            ov.LastSeenRunGuid = @RunGuid,
            ov.LastSeenOnUtc = SYSUTCDATETIME()
        FROM SMigration.Metadata_IdentityMapOverrides AS ov
        INNER JOIN @OverridesToClear AS clearRows
            ON clearRows.OverrideGuid = ov.Guid
        WHERE ov.RowStatus NOT IN (0,254);

        UPDATE maprow
        SET maprow.TargetRowId = NULL
        FROM SMigration.Metadata_ApplyIdentityMap AS maprow
        WHERE maprow.RunGuid = @RunGuid
          AND maprow.RegistryGuid = @RegistryGuid
          AND maprow.SourceRowGuid = @SourceRowGuid
          AND maprow.RowStatus NOT IN (0,254);
    END;
END
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyIdentityMap_Build]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyIdentityMap_Build]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @Sql NVARCHAR(MAX);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_ApplyIdentityMap
    WHERE RunGuid = @RunGuid;

    INSERT INTO SMigration.Metadata_ApplyIdentityMap
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SchemaName,
        TableName,
        SourceRowGuid,
        SourceRowId,
        TargetRowId,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        sr.RunGuid,
        sr.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        sr.SourceRowId,
        NULL,
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update');

    DECLARE registry_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            tr.Guid,
            tr.SchemaName,
            tr.TableName,
            tr.GuidColumnName,
            tr.PrimaryKeyColumnName
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
        ORDER BY
            tr.ApplyOrder,
            tr.SchemaName,
            tr.TableName;

    OPEN registry_cursor;

    FETCH NEXT FROM registry_cursor
    INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
UPDATE maprow
SET
    maprow.TargetRowId = TRY_CONVERT(BIGINT, targetrow.' + QUOTENAME(@PrimaryKeyColumnName) + N')
FROM SMigration.Metadata_ApplyIdentityMap AS maprow
INNER JOIN ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS targetrow
    ON targetrow.' + QUOTENAME(@GuidColumnName) + N' = maprow.SourceRowGuid
WHERE maprow.RunGuid = @RunGuid
  AND maprow.RegistryGuid = @RegistryGuid
  AND maprow.RowStatus NOT IN (0,254);';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid;

        SET @Sql = N'
UPDATE maprow
SET
    maprow.TargetRowId = TRY_CONVERT(BIGINT, targetrow.' + QUOTENAME(@PrimaryKeyColumnName) + N')
FROM SMigration.Metadata_ApplyIdentityMap AS maprow
INNER JOIN SMigration.Metadata_IdentityMapOverrides AS ov
    ON ov.DatabaseName = @TargetDatabaseName
   AND ov.RegistryGuid = maprow.RegistryGuid
   AND ov.SourceRowGuid = maprow.SourceRowGuid
   AND ov.RowStatus NOT IN (0,254)
INNER JOIN ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS targetrow
    ON targetrow.' + QUOTENAME(@GuidColumnName) + N' = ov.TargetRowGuid
WHERE maprow.RunGuid = @RunGuid
  AND maprow.RegistryGuid = @RegistryGuid
  AND maprow.RowStatus NOT IN (0,254);';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER, @TargetDatabaseName SYSNAME',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid,
            @TargetDatabaseName = @TargetDatabaseName;

        FETCH NEXT FROM registry_cursor
        INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;
    END;

    CLOSE registry_cursor;
    DEALLOCATE registry_cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'BuildIdentityMap',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata apply identity map built.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;

    SELECT
        SchemaName,
        TableName,
        COUNT_BIG(1) AS MapRows,
        SUM(CASE WHEN TargetRowId IS NULL THEN 1 ELSE 0 END) AS MissingTargetRows
    FROM SMigration.Metadata_ApplyIdentityMap
    WHERE RunGuid = @RunGuid
      AND RowStatus NOT IN (0,254)
    GROUP BY
        SchemaName,
        TableName
    ORDER BY
        SchemaName,
        TableName;
END;
GO

