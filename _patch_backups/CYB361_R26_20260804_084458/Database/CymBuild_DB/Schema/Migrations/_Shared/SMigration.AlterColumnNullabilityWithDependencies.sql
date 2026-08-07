/*
    CymBuild schema deployment shared helper.

    Creates a connection-local temporary procedure used by dedicated, source-controlled table
    migrations. The helper changes only column nullability and dynamically preserves supported
    target indexes and standalone user-created statistics that depend on the altered columns.
    Unsupported table, column, index, statistics, full-text, and schema-bound dependency shapes
    are rejected during validation before target maintenance begins.

    The calling migration must own an active transaction. Unsupported dependency shapes are
    rejected before any dependency is dropped.
*/
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NOT NULL
BEGIN
    DROP PROCEDURE #CymBuild_AlterColumnNullabilityWithDependencies;
END;
GO

CREATE PROCEDURE #CymBuild_AlterColumnNullabilityWithDependencies
    @SchemaName        SYSNAME,
    @TableName         SYSNAME,
    @ColumnChangesJson NVARCHAR(MAX),
    @ValidateOnly      BIT = 0
AS
BEGIN
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ValidateOnly = 0 AND @@TRANCOUNT = 0
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper requires an active caller transaction for apply mode.', 1;
    END;

    IF NULLIF(LTRIM(RTRIM(@SchemaName)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@TableName)), N'') IS NULL
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper requires a schema and table name.', 1;
    END;

    IF ISJSON(@ColumnChangesJson) <> 1
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper requires valid JSON column changes.', 1;
    END;

    DECLARE @QualifiedTableName NVARCHAR(517) = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName);
    DECLARE @ObjectId INT = OBJECT_ID(@QualifiedTableName, N'U');

    IF @ObjectId IS NULL
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper could not find the requested table.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.tables AS tables
        WHERE tables.object_id = @ObjectId
          AND
          (
              tables.is_memory_optimized = 1
              OR tables.temporal_type <> 0
              OR tables.is_node = 1
              OR tables.is_edge = 1
          )
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper does not support memory-optimized, temporal, ledger, node, or edge tables. Use a dedicated guarded migration.', 1;
    END;

    CREATE TABLE #CymBuildColumnChanges
    (
        ColumnName        SYSNAME       NOT NULL,
        TargetIsNullable  BIT           NOT NULL,
        ColumnId          INT           NULL,
        CurrentIsNullable BIT           NULL,
        WasRowGuidCol     BIT           NULL,
        TypeDeclaration   NVARCHAR(600) NULL,
        NeedsAlter        BIT           NOT NULL DEFAULT (0),
        PRIMARY KEY CLUSTERED (ColumnName)
    );

    INSERT INTO #CymBuildColumnChanges
    (
        ColumnName,
        TargetIsNullable
    )
    SELECT
        parsed.ColumnName,
        parsed.TargetIsNullable
    FROM OPENJSON(@ColumnChangesJson)
    WITH
    (
        ColumnName       SYSNAME '$.ColumnName',
        TargetIsNullable BIT     '$.IsNullable'
    ) AS parsed
    WHERE parsed.ColumnName IS NOT NULL
      AND parsed.TargetIsNullable IS NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM #CymBuildColumnChanges AS changes
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper received no valid column changes.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM #CymBuildColumnChanges AS changes
        LEFT JOIN sys.columns AS columns
          ON columns.object_id = @ObjectId
         AND columns.name = changes.ColumnName
        WHERE columns.column_id IS NULL
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper found a requested column that does not exist.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM #CymBuildColumnChanges AS changes
        JOIN sys.columns AS columns
          ON columns.object_id = @ObjectId
         AND columns.name = changes.ColumnName
        JOIN sys.types AS types
          ON types.user_type_id = columns.user_type_id
        WHERE columns.is_identity = 1
           OR columns.is_computed = 1
           OR columns.is_sparse = 1
           OR columns.is_column_set = 1
           OR columns.is_filestream = 1
           OR columns.is_masked = 1
           OR columns.is_hidden = 1
           OR columns.generated_always_type <> 0
           OR columns.encryption_type IS NOT NULL
           OR types.is_user_defined = 1
           OR types.is_assembly_type = 1
           OR types.name IN (N'timestamp', N'rowversion', N'text', N'ntext', N'image', N'xml', N'sql_variant', N'geography', N'geometry', N'hierarchyid')
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper does not support one or more requested column shapes. Use a dedicated guarded migration.', 1;
    END;

    UPDATE changes
    SET
        ColumnId = columns.column_id,
        CurrentIsNullable = columns.is_nullable,
        WasRowGuidCol = columns.is_rowguidcol,
        NeedsAlter = CONVERT(BIT, CASE WHEN columns.is_nullable = changes.TargetIsNullable THEN 0 ELSE 1 END),
        TypeDeclaration =
            CASE
                WHEN types.name IN (N'varchar', N'char', N'varbinary', N'binary') THEN
                    QUOTENAME(types.name) + N'(' + CASE WHEN columns.max_length = -1 THEN N'MAX' ELSE CONVERT(NVARCHAR(20), columns.max_length) END + N')'
                WHEN types.name IN (N'nvarchar', N'nchar') THEN
                    QUOTENAME(types.name) + N'(' + CASE WHEN columns.max_length = -1 THEN N'MAX' ELSE CONVERT(NVARCHAR(20), columns.max_length / 2) END + N')'
                WHEN types.name IN (N'decimal', N'numeric') THEN
                    QUOTENAME(types.name) + N'(' + CONVERT(NVARCHAR(20), columns.precision) + N',' + CONVERT(NVARCHAR(20), columns.scale) + N')'
                WHEN types.name IN (N'datetime2', N'datetimeoffset', N'time') THEN
                    QUOTENAME(types.name) + N'(' + CONVERT(NVARCHAR(20), columns.scale) + N')'
                WHEN types.name = N'float' THEN
                    QUOTENAME(types.name) + N'(' + CONVERT(NVARCHAR(20), columns.precision) + N')'
                ELSE
                    QUOTENAME(types.name)
            END
            + CASE
                  WHEN columns.collation_name IS NULL THEN N''
                  ELSE N' COLLATE ' + QUOTENAME(columns.collation_name)
              END
    FROM #CymBuildColumnChanges AS changes
    JOIN sys.columns AS columns
      ON columns.object_id = @ObjectId
     AND columns.name = changes.ColumnName
    JOIN sys.types AS types
      ON types.user_type_id = columns.user_type_id;

    IF NOT EXISTS
    (
        SELECT 1
        FROM #CymBuildColumnChanges AS changes
        WHERE changes.NeedsAlter = 1
    )
    BEGIN
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.sql_expression_dependencies AS dependencies
        JOIN #CymBuildColumnChanges AS changes
          ON changes.ColumnId = dependencies.referenced_minor_id
         AND changes.NeedsAlter = 1
        WHERE dependencies.referenced_id = @ObjectId
          AND dependencies.is_schema_bound_reference = 1
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper found a schema-bound expression dependency on a requested column. Use a dedicated guarded migration.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.fulltext_index_columns AS fullTextColumns
        JOIN #CymBuildColumnChanges AS changes
          ON changes.ColumnId = fullTextColumns.column_id
         AND changes.NeedsAlter = 1
        WHERE fullTextColumns.object_id = @ObjectId
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper found a full-text indexed requested column. Use a dedicated guarded migration.', 1;
    END;

    DECLARE @ColumnName SYSNAME;
    DECLARE @TargetIsNullable BIT;
    DECLARE @NullCount BIGINT;
    DECLARE @NullCheckSql NVARCHAR(MAX);

    DECLARE nullability_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            changes.ColumnName,
            changes.TargetIsNullable
        FROM #CymBuildColumnChanges AS changes
        WHERE changes.NeedsAlter = 1
          AND changes.TargetIsNullable = 0
        ORDER BY changes.ColumnId;

    OPEN nullability_cursor;
    FETCH NEXT FROM nullability_cursor INTO @ColumnName, @TargetIsNullable;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NullCount = 0;
        SET @NullCheckSql = N'SELECT @NullCountOutput = COUNT_BIG(1) FROM '
            + @QualifiedTableName
            + CASE WHEN @ValidateOnly = 1 THEN N'' ELSE N' WITH (UPDLOCK, HOLDLOCK)' END
            + N' WHERE ' + QUOTENAME(@ColumnName)
            + N' IS NULL;';

        EXEC sys.sp_executesql
            @NullCheckSql,
            N'@NullCountOutput BIGINT OUTPUT',
            @NullCountOutput = @NullCount OUTPUT;

        IF @NullCount > 0
        BEGIN
            DECLARE @NullMessage NVARCHAR(2048) = N'CymBuild shared column-alter helper blocked '
                + @QualifiedTableName + N'.' + QUOTENAME(@ColumnName)
                + N': ' + CONVERT(NVARCHAR(30), @NullCount)
                + N' existing row(s) contain NULL.';
            THROW 60362, @NullMessage, 1;
        END;

        FETCH NEXT FROM nullability_cursor INTO @ColumnName, @TargetIsNullable;
    END;

    CLOSE nullability_cursor;
    DEALLOCATE nullability_cursor;

    CREATE TABLE #CymBuildDependentIndexes
    (
        IndexId INT NOT NULL,
        PRIMARY KEY CLUSTERED (IndexId)
    );

    INSERT INTO #CymBuildDependentIndexes
    (
        IndexId
    )
    SELECT DISTINCT
        indexes.index_id
    FROM sys.indexes AS indexes
    JOIN #CymBuildColumnChanges AS changes
      ON changes.NeedsAlter = 1
    WHERE indexes.object_id = @ObjectId
      AND indexes.index_id > 0
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM sys.index_columns AS indexColumns
              WHERE indexColumns.object_id = indexes.object_id
                AND indexColumns.index_id = indexes.index_id
                AND indexColumns.column_id = changes.ColumnId
          )
          OR
          (
              indexes.has_filter = 1
              AND indexes.filter_definition IS NOT NULL
              AND CHARINDEX(QUOTENAME(changes.ColumnName), indexes.filter_definition) > 0
          )
      );

    IF EXISTS
    (
        SELECT 1
        FROM #CymBuildDependentIndexes AS dependent
        JOIN sys.indexes AS indexes
          ON indexes.object_id = @ObjectId
         AND indexes.index_id = dependent.IndexId
        LEFT JOIN sys.data_spaces AS dataSpaces
          ON dataSpaces.data_space_id = indexes.data_space_id
        WHERE indexes.name IS NULL
           OR indexes.is_primary_key = 1
           OR indexes.is_unique_constraint = 1
           OR indexes.is_hypothetical = 1
           OR indexes.auto_created = 1
           OR indexes.suppress_dup_key_messages = 1
           OR indexes.type <> 2
           OR dataSpaces.data_space_id IS NULL
           OR dataSpaces.type <> N'FG'
           OR (indexes.has_filter = 1 AND indexes.filter_definition IS NULL)
           OR EXISTS
              (
                  SELECT 1
                  FROM sys.partitions AS partitions
                  WHERE partitions.object_id = indexes.object_id
                    AND partitions.index_id = indexes.index_id
                    AND partitions.partition_number > 1
              )
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper found a dependent constraint, clustered/partitioned/hypothetical index, or unsupported index type. Use a dedicated guarded migration.', 1;
    END;

    CREATE TABLE #CymBuildDependencyScripts
    (
        DependencyType NVARCHAR(20)  NOT NULL,
        DependencyName SYSNAME       NOT NULL,
        DropOrder      INT           NOT NULL,
        CreateOrder    INT           NOT NULL,
        DropSql        NVARCHAR(MAX) NOT NULL,
        CreateSql      NVARCHAR(MAX) NOT NULL,
        PRIMARY KEY CLUSTERED (DependencyType, DependencyName)
    );

    DECLARE @IndexId INT;
    DECLARE @IndexName SYSNAME;
    DECLARE @IsUnique BIT;
    DECLARE @HasFilter BIT;
    DECLARE @FilterDefinition NVARCHAR(MAX);
    DECLARE @FillFactor TINYINT;
    DECLARE @IsPadded BIT;
    DECLARE @IgnoreDupKey BIT;
    DECLARE @AllowRowLocks BIT;
    DECLARE @AllowPageLocks BIT;
    DECLARE @OptimizeSequentialKey BIT;
    DECLARE @IsDisabled BIT;
    DECLARE @NoRecompute BIT;
    DECLARE @DataSpaceName SYSNAME;
    DECLARE @CompressionDescription NVARCHAR(60);
    DECLARE @CompressionCount INT;
    DECLARE @KeyColumns NVARCHAR(MAX);
    DECLARE @IncludedColumns NVARCHAR(MAX);
    DECLARE @CreateIndexSql NVARCHAR(MAX);
    DECLARE @DropIndexSql NVARCHAR(MAX);

    DECLARE index_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT dependent.IndexId
        FROM #CymBuildDependentIndexes AS dependent
        ORDER BY dependent.IndexId;

    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @IndexId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @IndexName = indexes.name,
            @IsUnique = indexes.is_unique,
            @HasFilter = indexes.has_filter,
            @FilterDefinition = indexes.filter_definition,
            @FillFactor = indexes.fill_factor,
            @IsPadded = indexes.is_padded,
            @IgnoreDupKey = indexes.ignore_dup_key,
            @AllowRowLocks = indexes.allow_row_locks,
            @AllowPageLocks = indexes.allow_page_locks,
            @OptimizeSequentialKey = indexes.optimize_for_sequential_key,
            @IsDisabled = indexes.is_disabled,
            @DataSpaceName = dataSpaces.name,
            @NoRecompute = stats.no_recompute
        FROM sys.indexes AS indexes
        JOIN sys.data_spaces AS dataSpaces
          ON dataSpaces.data_space_id = indexes.data_space_id
        JOIN sys.stats AS stats
          ON stats.object_id = indexes.object_id
         AND stats.stats_id = indexes.index_id
        WHERE indexes.object_id = @ObjectId
          AND indexes.index_id = @IndexId;

        SELECT
            @CompressionDescription = MIN(partitions.data_compression_desc),
            @CompressionCount = COUNT(DISTINCT partitions.data_compression_desc)
        FROM sys.partitions AS partitions
        WHERE partitions.object_id = @ObjectId
          AND partitions.index_id = @IndexId;

        IF @CompressionCount > 1
        BEGIN
            THROW 60362, N'CymBuild shared column-alter helper found mixed index compression settings. Use a dedicated guarded migration.', 1;
        END;

        SELECT
            @KeyColumns = STRING_AGG
            (
                CONVERT
                (
                    NVARCHAR(MAX),
                    QUOTENAME(columns.name)
                    + CASE WHEN indexColumns.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END
                ),
                N', '
            ) WITHIN GROUP (ORDER BY indexColumns.key_ordinal)
        FROM sys.index_columns AS indexColumns
        JOIN sys.columns AS columns
          ON columns.object_id = indexColumns.object_id
         AND columns.column_id = indexColumns.column_id
        WHERE indexColumns.object_id = @ObjectId
          AND indexColumns.index_id = @IndexId
          AND indexColumns.key_ordinal > 0;

        SELECT
            @IncludedColumns = STRING_AGG
            (
                CONVERT(NVARCHAR(MAX), QUOTENAME(columns.name)),
                N', '
            ) WITHIN GROUP (ORDER BY indexColumns.index_column_id)
        FROM sys.index_columns AS indexColumns
        JOIN sys.columns AS columns
          ON columns.object_id = indexColumns.object_id
         AND columns.column_id = indexColumns.column_id
        WHERE indexColumns.object_id = @ObjectId
          AND indexColumns.index_id = @IndexId
          AND indexColumns.is_included_column = 1;

        IF @KeyColumns IS NULL
        BEGIN
            THROW 60362, N'CymBuild shared column-alter helper could not script a dependent index key.', 1;
        END;

        SET @DropIndexSql = N'DROP INDEX ' + QUOTENAME(@IndexName) + N' ON ' + @QualifiedTableName + N';';
        SET @CreateIndexSql = N'CREATE '
            + CASE WHEN @IsUnique = 1 THEN N'UNIQUE ' ELSE N'' END
            + N'NONCLUSTERED '
            + N'INDEX ' + QUOTENAME(@IndexName)
            + N' ON ' + @QualifiedTableName
            + N' (' + @KeyColumns + N')'
            + CASE WHEN NULLIF(@IncludedColumns, N'') IS NULL THEN N'' ELSE N' INCLUDE (' + @IncludedColumns + N')' END
            + CASE WHEN @HasFilter = 1 THEN N' WHERE ' + @FilterDefinition ELSE N'' END
            + N' WITH ('
            + N'PAD_INDEX = ' + CASE WHEN @IsPadded = 1 THEN N'ON' ELSE N'OFF' END
            + N', FILLFACTOR = ' + CONVERT(NVARCHAR(3), @FillFactor)
            + N', IGNORE_DUP_KEY = ' + CASE WHEN @IgnoreDupKey = 1 THEN N'ON' ELSE N'OFF' END
            + N', STATISTICS_NORECOMPUTE = ' + CASE WHEN @NoRecompute = 1 THEN N'ON' ELSE N'OFF' END
            + N', ALLOW_ROW_LOCKS = ' + CASE WHEN @AllowRowLocks = 1 THEN N'ON' ELSE N'OFF' END
            + N', ALLOW_PAGE_LOCKS = ' + CASE WHEN @AllowPageLocks = 1 THEN N'ON' ELSE N'OFF' END
            + N', OPTIMIZE_FOR_SEQUENTIAL_KEY = ' + CASE WHEN @OptimizeSequentialKey = 1 THEN N'ON' ELSE N'OFF' END
            + CASE WHEN @CompressionDescription IS NULL OR @CompressionDescription = N'NONE' THEN N'' ELSE N', DATA_COMPRESSION = ' + @CompressionDescription END
            + N') ON ' + QUOTENAME(@DataSpaceName) + N';'
            + CASE WHEN @IsDisabled = 1 THEN N' ALTER INDEX ' + QUOTENAME(@IndexName) + N' ON ' + @QualifiedTableName + N' DISABLE;' ELSE N'' END;

        INSERT INTO #CymBuildDependencyScripts
        (
            DependencyType,
            DependencyName,
            DropOrder,
            CreateOrder,
            DropSql,
            CreateSql
        )
        VALUES
        (
            N'INDEX',
            @IndexName,
            20,
            100,
            @DropIndexSql,
            @CreateIndexSql
        );

        FETCH NEXT FROM index_cursor INTO @IndexId;
    END;

    CLOSE index_cursor;
    DEALLOCATE index_cursor;

    CREATE TABLE #CymBuildDependentStatistics
    (
        StatsId INT NOT NULL,
        PRIMARY KEY CLUSTERED (StatsId)
    );

    IF EXISTS
    (
        SELECT 1
        FROM sys.stats AS stats
        JOIN #CymBuildColumnChanges AS changes
          ON changes.NeedsAlter = 1
        WHERE stats.object_id = @ObjectId
          AND stats.auto_created = 1
          AND stats.auto_drop = 0
          AND
          (
              EXISTS
              (
                  SELECT 1
                  FROM sys.stats_columns AS statsColumns
                  WHERE statsColumns.object_id = stats.object_id
                    AND statsColumns.stats_id = stats.stats_id
                    AND statsColumns.column_id = changes.ColumnId
              )
              OR
              (
                  stats.has_filter = 1
                  AND stats.filter_definition IS NOT NULL
                  AND CHARINDEX(QUOTENAME(changes.ColumnName), stats.filter_definition) > 0
              )
          )
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper found an auto-created statistic without AUTO_DROP on a requested column. Refresh statistics metadata or use a dedicated guarded migration.', 1;
    END;

    INSERT INTO #CymBuildDependentStatistics
    (
        StatsId
    )
    SELECT DISTINCT
        stats.stats_id
    FROM sys.stats AS stats
    JOIN #CymBuildColumnChanges AS changes
      ON changes.NeedsAlter = 1
    LEFT JOIN sys.indexes AS indexes
      ON indexes.object_id = stats.object_id
     AND indexes.index_id = stats.stats_id
    WHERE stats.object_id = @ObjectId
      AND stats.user_created = 1
      AND indexes.index_id IS NULL
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM sys.stats_columns AS statsColumns
              WHERE statsColumns.object_id = stats.object_id
                AND statsColumns.stats_id = stats.stats_id
                AND statsColumns.column_id = changes.ColumnId
          )
          OR
          (
              stats.has_filter = 1
              AND stats.filter_definition IS NOT NULL
              AND CHARINDEX(QUOTENAME(changes.ColumnName), stats.filter_definition) > 0
          )
      );

    IF EXISTS
    (
        SELECT 1
        FROM #CymBuildDependentStatistics AS dependent
        JOIN sys.stats AS stats
          ON stats.object_id = @ObjectId
         AND stats.stats_id = dependent.StatsId
        WHERE stats.is_temporary = 1
           OR stats.has_persisted_sample = 1
           OR (stats.has_filter = 1 AND stats.filter_definition IS NULL)
    )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper found temporary, persisted-sample, or unreadable filtered statistics. Use a dedicated guarded migration.', 1;
    END;

    DECLARE @StatsId INT;
    DECLARE @StatsName SYSNAME;
    DECLARE @StatsColumns NVARCHAR(MAX);
    DECLARE @StatsFilter NVARCHAR(MAX);
    DECLARE @StatsHasFilter BIT;
    DECLARE @StatsNoRecompute BIT;
    DECLARE @StatsIncremental BIT;
    DECLARE @StatsAutoDrop BIT;
    DECLARE @DropStatsSql NVARCHAR(MAX);
    DECLARE @CreateStatsSql NVARCHAR(MAX);
    DECLARE @StatsOptions NVARCHAR(MAX);

    DECLARE stats_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT dependent.StatsId
        FROM #CymBuildDependentStatistics AS dependent
        ORDER BY dependent.StatsId;

    OPEN stats_cursor;
    FETCH NEXT FROM stats_cursor INTO @StatsId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @StatsName = stats.name,
            @StatsFilter = stats.filter_definition,
            @StatsHasFilter = stats.has_filter,
            @StatsNoRecompute = stats.no_recompute,
            @StatsIncremental = stats.is_incremental,
            @StatsAutoDrop = stats.auto_drop
        FROM sys.stats AS stats
        WHERE stats.object_id = @ObjectId
          AND stats.stats_id = @StatsId;

        SELECT
            @StatsColumns = STRING_AGG
            (
                CONVERT(NVARCHAR(MAX), QUOTENAME(columns.name)),
                N', '
            ) WITHIN GROUP (ORDER BY statsColumns.stats_column_id)
        FROM sys.stats_columns AS statsColumns
        JOIN sys.columns AS columns
          ON columns.object_id = statsColumns.object_id
         AND columns.column_id = statsColumns.column_id
        WHERE statsColumns.object_id = @ObjectId
          AND statsColumns.stats_id = @StatsId;

        IF @StatsColumns IS NULL
        BEGIN
            THROW 60362, N'CymBuild shared column-alter helper could not script dependent statistics.', 1;
        END;

        SET @StatsOptions = N'';
        IF @StatsNoRecompute = 1
        BEGIN
            SET @StatsOptions = N'NORECOMPUTE';
        END;
        IF @StatsIncremental = 1
        BEGIN
            SET @StatsOptions = @StatsOptions + CASE WHEN @StatsOptions = N'' THEN N'' ELSE N', ' END + N'INCREMENTAL = ON';
        END;
        IF @StatsAutoDrop = 1
        BEGIN
            SET @StatsOptions = @StatsOptions + CASE WHEN @StatsOptions = N'' THEN N'' ELSE N', ' END + N'AUTO_DROP = ON';
        END;

        SET @DropStatsSql = N'DROP STATISTICS ' + @QualifiedTableName + N'.' + QUOTENAME(@StatsName) + N';';
        SET @CreateStatsSql = N'CREATE STATISTICS ' + QUOTENAME(@StatsName)
            + N' ON ' + @QualifiedTableName + N' (' + @StatsColumns + N')'
            + CASE WHEN @StatsHasFilter = 1 THEN N' WHERE ' + @StatsFilter ELSE N'' END
            + CASE WHEN @StatsOptions = N'' THEN N'' ELSE N' WITH ' + @StatsOptions END
            + N';';

        INSERT INTO #CymBuildDependencyScripts
        (
            DependencyType,
            DependencyName,
            DropOrder,
            CreateOrder,
            DropSql,
            CreateSql
        )
        VALUES
        (
            N'STATISTICS',
            @StatsName,
            10,
            200,
            @DropStatsSql,
            @CreateStatsSql
        );

        FETCH NEXT FROM stats_cursor INTO @StatsId;
    END;

    CLOSE stats_cursor;
    DEALLOCATE stats_cursor;

    IF @ValidateOnly = 1
    BEGIN
        RETURN;
    END;

    DECLARE @DependencySql NVARCHAR(MAX);

    DECLARE drop_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT scripts.DropSql
        FROM #CymBuildDependencyScripts AS scripts
        ORDER BY scripts.DropOrder, scripts.DependencyType, scripts.DependencyName;

    OPEN drop_cursor;
    FETCH NEXT FROM drop_cursor INTO @DependencySql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @DependencySql;
        FETCH NEXT FROM drop_cursor INTO @DependencySql;
    END;

    CLOSE drop_cursor;
    DEALLOCATE drop_cursor;

    DECLARE @TypeDeclaration NVARCHAR(600);
    DECLARE @WasRowGuidCol BIT;
    DECLARE @AlterSql NVARCHAR(MAX);

    DECLARE alter_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            changes.ColumnName,
            changes.TargetIsNullable,
            changes.TypeDeclaration,
            changes.WasRowGuidCol
        FROM #CymBuildColumnChanges AS changes
        WHERE changes.NeedsAlter = 1
        ORDER BY changes.ColumnId;

    OPEN alter_cursor;
    FETCH NEXT FROM alter_cursor INTO @ColumnName, @TargetIsNullable, @TypeDeclaration, @WasRowGuidCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @WasRowGuidCol = 1
        BEGIN
            SET @AlterSql = N'ALTER TABLE ' + @QualifiedTableName
                + N' ALTER COLUMN ' + QUOTENAME(@ColumnName) + N' DROP ROWGUIDCOL;';
            EXEC sys.sp_executesql @AlterSql;
        END;

        SET @AlterSql = N'ALTER TABLE ' + @QualifiedTableName
            + N' ALTER COLUMN ' + QUOTENAME(@ColumnName) + N' '
            + @TypeDeclaration + CASE WHEN @TargetIsNullable = 1 THEN N' NULL;' ELSE N' NOT NULL;' END;
        EXEC sys.sp_executesql @AlterSql;

        IF @WasRowGuidCol = 1
        BEGIN
            SET @AlterSql = N'ALTER TABLE ' + @QualifiedTableName
                + N' ALTER COLUMN ' + QUOTENAME(@ColumnName) + N' ADD ROWGUIDCOL;';
            EXEC sys.sp_executesql @AlterSql;
        END;

        FETCH NEXT FROM alter_cursor INTO @ColumnName, @TargetIsNullable, @TypeDeclaration, @WasRowGuidCol;
    END;

    CLOSE alter_cursor;
    DEALLOCATE alter_cursor;

    DECLARE create_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT scripts.CreateSql
        FROM #CymBuildDependencyScripts AS scripts
        ORDER BY scripts.CreateOrder, scripts.DependencyType, scripts.DependencyName;

    OPEN create_cursor;
    FETCH NEXT FROM create_cursor INTO @DependencySql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @DependencySql;
        FETCH NEXT FROM create_cursor INTO @DependencySql;
    END;

    CLOSE create_cursor;
    DEALLOCATE create_cursor;
END;
GO
