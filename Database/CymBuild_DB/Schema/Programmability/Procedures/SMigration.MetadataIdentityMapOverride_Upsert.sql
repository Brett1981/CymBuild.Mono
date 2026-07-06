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
