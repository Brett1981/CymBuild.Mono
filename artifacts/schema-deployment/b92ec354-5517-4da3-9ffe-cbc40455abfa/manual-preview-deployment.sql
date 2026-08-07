/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLDEVBRE01\GENERAL
    Target database : CymBuild_QA
    Run Guid        : b92ec354-5517-4da3-9ffe-cbc40455abfa
    Generated UTC   : 2026-08-04T08:17:50.3010619Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_QA];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 1, @read_only = 0;
GO

/* Prepare shared migration support for Table SCore.ObjectSecurity from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\_Shared\SMigration.AlterColumnNullabilityWithDependencies.sql */
/*
    CymBuild schema deployment shared helper.

    Creates a connection-local temporary procedure used by dedicated, source-controlled table
    migrations. The helper changes only column nullability and dynamically preserves supported
    target indexes and standalone user-created statistics that depend on the altered columns.
    Read-only preflight may recognise schema-bound functions/views that the controlled
    SCore.PreDeploymentScript can remove through SCore.SCHEMABINDING. Apply mode remains strict:
    those dependencies must be absent before any column is altered. Unsupported table, column,
    index, statistics, full-text, computed-column, and unmanaged schema-bound dependency shapes
    are rejected before target maintenance begins.

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
    @SchemaName                                      SYSNAME,
    @TableName                                       SYSNAME,
    @ColumnChangesJson                               NVARCHAR(MAX),
    @ValidateOnly                                    BIT = 0,
    @AllowPreDeploymentManagedSchemaBoundDependencies BIT = 0
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

    IF @AllowPreDeploymentManagedSchemaBoundDependencies = 1 AND @ValidateOnly = 0
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper permits pre-deployment-managed schema-bound dependencies only during read-only validation.', 1;
    END;

    IF @AllowPreDeploymentManagedSchemaBoundDependencies = 1
       AND
       (
           OBJECT_ID(N'[SCore].[PreDeploymentScript]', N'P') IS NULL
           OR OBJECT_ID(N'[SCore].[SCHEMABINDING]', N'P') IS NULL
       )
    BEGIN
        THROW 60362, N'CymBuild shared column-alter helper cannot approve managed schema-bound dependencies because SCore.PreDeploymentScript or SCore.SCHEMABINDING is unavailable.', 1;
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

    /*
        SQL Server records filtered-index and filtered-statistics predicates as table-owned,
        schema-bound expressions in sys.sql_expression_dependencies. Those dependencies are
        handled later by the reusable index/statistics suspension logic and must not be treated
        as external schema-bound modules.

        True external schema-bound dependencies have a different referencing object_id. They
        remain blocked because removing or rewriting modules must be an explicit source-controlled
        migration decision. Computed-column dependencies are table-owned too, so they are checked
        separately and remain unsupported by this nullability-only helper.
    */
    DECLARE @ComputedColumnDependencies NVARCHAR(MAX);

    SELECT
        @ComputedColumnDependencies = STRING_AGG
        (
            CONVERT(NVARCHAR(MAX), QUOTENAME(computedColumns.name)),
            N', '
        )
    FROM sys.sql_expression_dependencies AS dependencies
    JOIN #CymBuildColumnChanges AS changes
      ON changes.ColumnId = dependencies.referenced_minor_id
     AND changes.NeedsAlter = 1
    JOIN sys.computed_columns AS computedColumns
      ON computedColumns.object_id = @ObjectId
     AND computedColumns.column_id = dependencies.referencing_minor_id
    WHERE dependencies.referenced_id = @ObjectId
      AND dependencies.referencing_id = @ObjectId
      AND dependencies.is_schema_bound_reference = 1;

    IF NULLIF(@ComputedColumnDependencies, N'') IS NOT NULL
    BEGIN
        DECLARE @ComputedDependencyMessage NVARCHAR(2048) =
            N'CymBuild shared column-alter helper found computed-column dependencies on requested columns: '
            + LEFT(@ComputedColumnDependencies, 1700)
            + N'. Use a dedicated guarded migration.';
        THROW 60362, @ComputedDependencyMessage, 1;
    END;

    CREATE TABLE #CymBuildExternalSchemaBoundDependencies
    (
        ReferencingObjectId      INT            NOT NULL,
        TwoPartName              NVARCHAR(517)  NOT NULL,
        ObjectType               CHAR(2)        NULL,
        IsManagedByPreDeployment BIT            NOT NULL,
        PRIMARY KEY CLUSTERED (ReferencingObjectId)
    );

    INSERT INTO #CymBuildExternalSchemaBoundDependencies
    (
        ReferencingObjectId,
        TwoPartName,
        ObjectType,
        IsManagedByPreDeployment
    )
    SELECT
        externalDependencies.referencing_id,
        COALESCE
        (
            QUOTENAME(referencingSchema.name) + N'.' + QUOTENAME(referencingObject.name),
            N'object_id=' + CONVERT(NVARCHAR(20), externalDependencies.referencing_id)
        ),
        referencingObject.type,
        CONVERT
        (
            BIT,
            CASE
                WHEN @AllowPreDeploymentManagedSchemaBoundDependencies = 1
                 AND referencingObject.type IN (N'V', N'IF', N'TF', N'FN')
                 AND referencingModule.is_schema_bound = 1
                 AND referencingModule.definition IS NOT NULL
                 AND UPPER(referencingModule.definition) LIKE N'%WITH SCHEMABINDING%'
                THEN 1
                ELSE 0
            END
        )
    FROM
    (
        SELECT DISTINCT
            dependencies.referencing_id
        FROM sys.sql_expression_dependencies AS dependencies
        JOIN #CymBuildColumnChanges AS changes
          ON changes.ColumnId = dependencies.referenced_minor_id
         AND changes.NeedsAlter = 1
        WHERE dependencies.referenced_id = @ObjectId
          AND dependencies.referencing_id <> @ObjectId
          AND dependencies.is_schema_bound_reference = 1
    ) AS externalDependencies
    LEFT JOIN sys.objects AS referencingObject
      ON referencingObject.object_id = externalDependencies.referencing_id
    LEFT JOIN sys.schemas AS referencingSchema
      ON referencingSchema.schema_id = referencingObject.schema_id
    LEFT JOIN sys.sql_modules AS referencingModule
      ON referencingModule.object_id = referencingObject.object_id;

    DECLARE @ExternalSchemaBoundDependencies NVARCHAR(MAX);

    SELECT
        @ExternalSchemaBoundDependencies = STRING_AGG
        (
            CONVERT(NVARCHAR(MAX), dependencies.TwoPartName),
            N', '
        )
    FROM #CymBuildExternalSchemaBoundDependencies AS dependencies
    WHERE dependencies.IsManagedByPreDeployment = 0;

    IF NULLIF(@ExternalSchemaBoundDependencies, N'') IS NOT NULL
    BEGIN
        DECLARE @ExternalDependencyMessage NVARCHAR(2048) =
            N'CymBuild shared column-alter helper found unmanaged or still-active external schema-bound dependencies on requested columns: '
            + LEFT(@ExternalSchemaBoundDependencies, 1570)
            + N'. Use a dedicated guarded migration or ensure SCore.PreDeploymentScript removes approved schema binding before apply.';
        THROW 60362, @ExternalDependencyMessage, 1;
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

GO

/* Preflight Table SCore.ObjectSecurity from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\CYB361\SCore.ObjectSecurity.preflight.sql */
/*
    CYB-361 / CYB-362 guarded preflight for SCore.ObjectSecurity.

    Source-controlled expected shape:
      - Guid       UNIQUEIDENTIFIER NULL ROWGUIDCOL
      - ObjectGuid UNIQUEIDENTIFIER NOT NULL
      - UserId     INT NOT NULL

    This preflight is read-only. It deliberately refuses to infer ObjectGuid or UserId values.
    Before SCore.PreDeploymentScript, the controlled runner may recognise only schema-bound
    functions/views that are provably managed by SCore.SCHEMABINDING. The runner repeats this
    preflight in strict mode after pre-deployment maintenance.
*/
SET NOCOUNT ON;

DECLARE @ObjectId INT = OBJECT_ID(N'[SCore].[ObjectSecurity]', N'U');

IF @ObjectId IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration requires existing table [SCore].[ObjectSecurity].', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'Guid'
      AND t.name = N'uniqueidentifier'
      AND c.is_rowguidcol = 1
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [Guid] is not UNIQUEIDENTIFIER ROWGUIDCOL.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'ObjectGuid'
      AND t.name = N'uniqueidentifier'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [ObjectGuid] is missing or has an unexpected data type.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'UserId'
      AND t.name = N'int'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [UserId] is missing or has an unexpected data type.', 1;
END;

DECLARE @NullObjectGuidCount BIGINT;
DECLARE @NullUserIdCount BIGINT;
DECLARE @OrphanUserIdCount BIGINT;
DECLARE @Message NVARCHAR(2048);

SELECT
    @NullObjectGuidCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[ObjectGuid] IS NULL;

IF @NullObjectGuidCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullObjectGuidCount)
        + N' row(s) have NULL ObjectGuid. No value can be inferred safely.';
    THROW 60361, @Message, 1;
END;

SELECT
    @NullUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[UserId] IS NULL;

IF @NullUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullUserIdCount)
        + N' row(s) have NULL UserId. No identity value will be guessed.';
    THROW 60361, @Message, 1;
END;

SELECT
    @OrphanUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE NOT EXISTS
(
    SELECT 1
    FROM [SCore].[Identities] AS i
    WHERE i.[ID] = os.[UserId]
);

IF @OrphanUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @OrphanUserIdCount)
        + N' row(s) reference a UserId not present in SCore.Identities.';
    THROW 60361, @Message, 1;
END;

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration preflight requires the shared column-dependency helper on the current deployment connection.', 1;
END;

DECLARE @AllowPreDeploymentManagedSchemaBoundDependencies BIT =
    CONVERT
    (
        BIT,
        CASE
            WHEN TRY_CONVERT(INT, SESSION_CONTEXT(N'CymBuild_schema_predeployment_will_run')) = 1 THEN 1
            ELSE 0
        END
    );

EXEC #CymBuild_AlterColumnNullabilityWithDependencies
    @SchemaName = N'SCore',
    @TableName = N'ObjectSecurity',
    @ColumnChangesJson = N'[
        {"ColumnName":"Guid","IsNullable":true},
        {"ColumnName":"ObjectGuid","IsNullable":false},
        {"ColumnName":"UserId","IsNullable":false}
    ]',
    @ValidateOnly = 1,
    @AllowPreDeploymentManagedSchemaBoundDependencies = @AllowPreDeploymentManagedSchemaBoundDependencies;

GO
EXEC [SCore].[PreDeploymentScript];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;
GO

/* Strict post-pre-deployment preflight Table SCore.ObjectSecurity */
/*
    CYB-361 / CYB-362 guarded preflight for SCore.ObjectSecurity.

    Source-controlled expected shape:
      - Guid       UNIQUEIDENTIFIER NULL ROWGUIDCOL
      - ObjectGuid UNIQUEIDENTIFIER NOT NULL
      - UserId     INT NOT NULL

    This preflight is read-only. It deliberately refuses to infer ObjectGuid or UserId values.
    Before SCore.PreDeploymentScript, the controlled runner may recognise only schema-bound
    functions/views that are provably managed by SCore.SCHEMABINDING. The runner repeats this
    preflight in strict mode after pre-deployment maintenance.
*/
SET NOCOUNT ON;

DECLARE @ObjectId INT = OBJECT_ID(N'[SCore].[ObjectSecurity]', N'U');

IF @ObjectId IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration requires existing table [SCore].[ObjectSecurity].', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'Guid'
      AND t.name = N'uniqueidentifier'
      AND c.is_rowguidcol = 1
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [Guid] is not UNIQUEIDENTIFIER ROWGUIDCOL.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'ObjectGuid'
      AND t.name = N'uniqueidentifier'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [ObjectGuid] is missing or has an unexpected data type.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'UserId'
      AND t.name = N'int'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [UserId] is missing or has an unexpected data type.', 1;
END;

DECLARE @NullObjectGuidCount BIGINT;
DECLARE @NullUserIdCount BIGINT;
DECLARE @OrphanUserIdCount BIGINT;
DECLARE @Message NVARCHAR(2048);

SELECT
    @NullObjectGuidCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[ObjectGuid] IS NULL;

IF @NullObjectGuidCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullObjectGuidCount)
        + N' row(s) have NULL ObjectGuid. No value can be inferred safely.';
    THROW 60361, @Message, 1;
END;

SELECT
    @NullUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[UserId] IS NULL;

IF @NullUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullUserIdCount)
        + N' row(s) have NULL UserId. No identity value will be guessed.';
    THROW 60361, @Message, 1;
END;

SELECT
    @OrphanUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE NOT EXISTS
(
    SELECT 1
    FROM [SCore].[Identities] AS i
    WHERE i.[ID] = os.[UserId]
);

IF @OrphanUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @OrphanUserIdCount)
        + N' row(s) reference a UserId not present in SCore.Identities.';
    THROW 60361, @Message, 1;
END;

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration preflight requires the shared column-dependency helper on the current deployment connection.', 1;
END;

DECLARE @AllowPreDeploymentManagedSchemaBoundDependencies BIT =
    CONVERT
    (
        BIT,
        CASE
            WHEN TRY_CONVERT(INT, SESSION_CONTEXT(N'CymBuild_schema_predeployment_will_run')) = 1 THEN 1
            ELSE 0
        END
    );

EXEC #CymBuild_AlterColumnNullabilityWithDependencies
    @SchemaName = N'SCore',
    @TableName = N'ObjectSecurity',
    @ColumnChangesJson = N'[
        {"ColumnName":"Guid","IsNullable":true},
        {"ColumnName":"ObjectGuid","IsNullable":false},
        {"ColumnName":"UserId","IsNullable":false}
    ]',
    @ValidateOnly = 1,
    @AllowPreDeploymentManagedSchemaBoundDependencies = @AllowPreDeploymentManagedSchemaBoundDependencies;

GO

/* Deploy Table SCore.ObjectSecurity using DedicatedMigration from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\CYB361\SCore.ObjectSecurity.alter.sql */
/*
    CYB-361 / CYB-362 dedicated, data-preserving migration for SCore.ObjectSecurity.

    This script aligns the demonstrated QA shape with the source-controlled DEV shape without
    recreating the table or deleting/updating business rows. It is idempotent and repeats all
    preconditions inside the deployment transaction.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ObjectId INT = OBJECT_ID(N'[SCore].[ObjectSecurity]', N'U');

    IF @ObjectId IS NULL
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration requires existing table [SCore].[ObjectSecurity].', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        JOIN sys.types AS t
          ON t.user_type_id = c.user_type_id
        WHERE c.object_id = @ObjectId
          AND c.name = N'Guid'
          AND t.name = N'uniqueidentifier'
          AND c.is_rowguidcol = 1
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [Guid] is not UNIQUEIDENTIFIER ROWGUIDCOL.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        JOIN sys.types AS t
          ON t.user_type_id = c.user_type_id
        WHERE c.object_id = @ObjectId
          AND c.name = N'ObjectGuid'
          AND t.name = N'uniqueidentifier'
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [ObjectGuid] is missing or has an unexpected data type.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        JOIN sys.types AS t
          ON t.user_type_id = c.user_type_id
        WHERE c.object_id = @ObjectId
          AND c.name = N'UserId'
          AND t.name = N'int'
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [UserId] is missing or has an unexpected data type.', 1;
    END;

    DECLARE @NullObjectGuidCount BIGINT;
    DECLARE @NullUserIdCount BIGINT;
    DECLARE @OrphanUserIdCount BIGINT;
    DECLARE @Message NVARCHAR(2048);

    SELECT
        @NullObjectGuidCount = COUNT_BIG(1)
    FROM [SCore].[ObjectSecurity] AS os WITH (UPDLOCK, HOLDLOCK)
    WHERE os.[ObjectGuid] IS NULL;

    IF @NullObjectGuidCount > 0
    BEGIN
        SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
            + CONVERT(NVARCHAR(30), @NullObjectGuidCount)
            + N' row(s) have NULL ObjectGuid. No value can be inferred safely.';
        THROW 60361, @Message, 1;
    END;

    SELECT
        @NullUserIdCount = COUNT_BIG(1)
    FROM [SCore].[ObjectSecurity] AS os WITH (UPDLOCK, HOLDLOCK)
    WHERE os.[UserId] IS NULL;

    IF @NullUserIdCount > 0
    BEGIN
        SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
            + CONVERT(NVARCHAR(30), @NullUserIdCount)
            + N' row(s) have NULL UserId. No identity value will be guessed.';
        THROW 60361, @Message, 1;
    END;

    SELECT
        @OrphanUserIdCount = COUNT_BIG(1)
    FROM [SCore].[ObjectSecurity] AS os WITH (UPDLOCK, HOLDLOCK)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[Identities] AS i
        WHERE i.[ID] = os.[UserId]
    );

    IF @OrphanUserIdCount > 0
    BEGIN
        SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
            + CONVERT(NVARCHAR(30), @OrphanUserIdCount)
            + N' row(s) reference a UserId not present in SCore.Identities.';
        THROW 60361, @Message, 1;
    END;

    /*
        Shared source-controlled migration infrastructure handles the mechanical SQL Server
        requirements for nullability changes: dependent rowstore indexes, standalone user-created
        statistics, and temporary ROWGUIDCOL removal/restoration. Table-specific intent remains
        explicit in this migration.
    */
    EXEC #CymBuild_AlterColumnNullabilityWithDependencies
        @SchemaName = N'SCore',
        @TableName = N'ObjectSecurity',
        @ColumnChangesJson = N'[
            {"ColumnName":"Guid","IsNullable":true},
            {"ColumnName":"ObjectGuid","IsNullable":false},
            {"ColumnName":"UserId","IsNullable":false}
        ]';

    DECLARE @ObjectGuidDefaultObjectId INT;
    DECLARE @ObjectGuidDefaultDefinition NVARCHAR(MAX);

    SELECT
        @ObjectGuidDefaultObjectId = dc.[object_id],
        @ObjectGuidDefaultDefinition = dc.[definition]
    FROM sys.default_constraints AS dc
    JOIN sys.columns AS c
      ON c.[object_id] = dc.[parent_object_id]
     AND c.[column_id] = dc.[parent_column_id]
    WHERE dc.[parent_object_id] = @ObjectId
      AND c.[name] = N'ObjectGuid';

    IF @ObjectGuidDefaultObjectId IS NULL
    BEGIN
        IF OBJECT_ID(N'[SCore].[DF_ObjectSecurity_RecordGuid]', N'D') IS NOT NULL
        BEGIN
            THROW 60361, N'CYB-361 ObjectSecurity migration blocked: constraint name DF_ObjectSecurity_RecordGuid is already used by another object.', 1;
        END;

        ALTER TABLE [SCore].[ObjectSecurity]
            ADD CONSTRAINT [DF_ObjectSecurity_RecordGuid]
            DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [ObjectGuid];
    END;
    ELSE IF LOWER(@ObjectGuidDefaultDefinition)
            NOT LIKE N'%00000000-0000-0000-0000-000000000000%'
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: ObjectGuid has an unexpected default constraint.', 1;
    END;

    DECLARE @UserForeignKeyObjectId INT;

    SELECT TOP (1)
        @UserForeignKeyObjectId = fk.[object_id]
    FROM sys.foreign_keys AS fk
    JOIN sys.foreign_key_columns AS fkc
      ON fkc.[constraint_object_id] = fk.[object_id]
    JOIN sys.columns AS pc
      ON pc.[object_id] = fkc.[parent_object_id]
     AND pc.[column_id] = fkc.[parent_column_id]
    JOIN sys.columns AS rc
      ON rc.[object_id] = fkc.[referenced_object_id]
     AND rc.[column_id] = fkc.[referenced_column_id]
    WHERE fk.[parent_object_id] = @ObjectId
      AND fk.[referenced_object_id] = OBJECT_ID(N'[SCore].[Identities]', N'U')
      AND pc.[name] = N'UserId'
      AND rc.[name] = N'ID';

    IF @UserForeignKeyObjectId IS NULL
    BEGIN
        IF OBJECT_ID(N'[SCore].[FK_ObjectSecurity_Users]', N'F') IS NOT NULL
        BEGIN
            THROW 60361, N'CYB-361 ObjectSecurity migration blocked: FK_ObjectSecurity_Users exists with an unexpected definition.', 1;
        END;

        ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
            ADD CONSTRAINT [FK_ObjectSecurity_Users]
            FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID]);

        ALTER TABLE [SCore].[ObjectSecurity]
            CHECK CONSTRAINT [FK_ObjectSecurity_Users];
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = @ObjectId
          AND
          (
              (c.name = N'Guid' AND (c.is_nullable <> 1 OR c.is_rowguidcol <> 1))
              OR (c.name = N'ObjectGuid' AND c.is_nullable <> 0)
              OR (c.name = N'UserId' AND c.is_nullable <> 0)
          )
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration verification failed: target column shape does not match the source-controlled definition.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

GO

/* Deploy Function SSop.tvf_Quotes using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SSop.tvf_Quotes.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_Quotes]')
GO
PRINT (N'Create function [SSop].[tvf_Quotes]')
GO
PRINT (N'Create function [SSop].[tvf_Quotes]')
GO

--exec score.PostDeploymentScript


CREATE OR ALTER FUNCTION [SSop].[tvf_Quotes]
(
    @UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN
SELECT
    q.ID,
    q.RowStatus,
    q.RowVersion,
    q.Guid,
    q.FullNumber AS Number,
    CASE
        WHEN q.DescriptionOfWorks <> N''
            THEN LEFT(q.DescriptionOfWorks, 200)
        ELSE LEFT(q.Overview, 200)
    END AS Details,
    LatestTransitionComment.Comment,
    CONCAT
    (
        COALESCE(NULLIF(LTRIM(RTRIM(acc.Name)), N''), N'Client Not set'),
        N' / ',
        COALESCE(NULLIF(LTRIM(RTRIM(agent.Name)), N''), N'Agent Not set')
    ) AS Account,
    uprn.FormattedAddressComma,
    qcf.QuoteStatus AS QuoteStatus,
    i.FullName AS QuotingConsultant,
    ou.Name AS OrganisationalUnitName,
    COALESCE(NULLIF(LTRIM(RTRIM(businessUnit.Name)), N''), N'') AS BusinessUnit,
    COALESCE(NULLIF(LTRIM(RTRIM(department.Name)), N''), N'') AS Department,
        COALESCE(NULLIF(LTRIM(RTRIM(businessUnit.Name)), N''), N'') AS BusinessUnitName,
    COALESCE(NULLIF(LTRIM(RTRIM(department.Name)), N''), N'') AS DepartmentName,
    jt.Name AS JobType,
    q.Date,
    q.ExternalReference,
    acc.Name AS Client,
    ISNULL(qn.TotalNet, 0) AS TotalNet,

    CONVERT(date, ISNULL(qw.SentStatusDate, q.DateSent)) AS QuoteSentDate,

    CONVERT
    (
        date,
        CASE
            WHEN ISNULL(q.RevisionNumber, 0) > 0
                 OR q.OriginalQuoteId <> -1
                THEN ISNULL(qw.ChaseOneDate, q.ChaseDate1)
            ELSE ISNULL(qw.ChaseOneDate, ISNULL(ew.ChaseOneDate, ISNULL(q.ChaseDate1, e.ChaseDate1)))
        END
    ) AS QuoteChaseDateOne,

    CONVERT
    (
        date,
        CASE
            WHEN ISNULL(q.RevisionNumber, 0) > 0
                 OR q.OriginalQuoteId <> -1
                THEN ISNULL(qw.ChaseTwoDate, q.ChaseDate2)
            ELSE ISNULL(qw.ChaseTwoDate, ISNULL(ew.ChaseTwoDate, ISNULL(q.ChaseDate2, e.ChaseDate2)))
        END
    ) AS QuoteChaseDateTwo,
    LastStatusComment.Comment AS LastComment

FROM SSop.Quotes AS q
JOIN SSop.Quote_CalculatedFields AS qcf
    ON qcf.ID = q.ID
JOIN SSop.EnquiryServices AS es
    ON es.ID = q.EnquiryServiceID
JOIN SSop.Enquiries AS e
    ON e.ID = es.EnquiryId
JOIN SCrm.Accounts AS acc
    ON acc.ID = e.ClientAccountID
JOIN SCrm.Accounts AS agent
    ON agent.ID = e.AgentAccountId
JOIN SJob.Assets AS uprn
    ON uprn.ID = e.PropertyId
JOIN SCore.Identities AS i
    ON i.ID = q.QuotingConsultantId
JOIN SCore.OrganisationalUnits AS ou ON ou.ID = q.OrganisationalUnitID
JOIN SJob.JobTypes AS jt
    ON jt.ID = q.JobTypeId
OUTER APPLY
(
    SELECT TOP (1)
        ancestor.Name
    FROM SCore.OrganisationalUnits AS ancestor
    WHERE ancestor.RowStatus NOT IN (0,254)
      AND ISNULL(ancestor.IsBusinessUnit, 0) = 1
      AND ou.OrgNode IS NOT NULL
      AND ancestor.OrgNode IS NOT NULL
      AND ou.OrgNode.IsDescendantOf(ancestor.OrgNode) = 1
    ORDER BY ancestor.OrgNode.GetLevel() DESC,
             ancestor.ID DESC
) AS businessUnit
OUTER APPLY
(
    SELECT TOP (1)
        ancestor.Name
    FROM SCore.OrganisationalUnits AS ancestor
    WHERE ancestor.RowStatus NOT IN (0,254)
      AND ISNULL(ancestor.IsDepartment, 0) = 1
      AND ou.OrgNode IS NOT NULL
      AND ancestor.OrgNode IS NOT NULL
      AND ou.OrgNode.IsDescendantOf(ancestor.OrgNode) = 1
    ORDER BY ancestor.OrgNode.GetLevel() DESC,
             ancestor.ID DESC
) AS department
OUTER APPLY
(
    SELECT TOP (1)
        dob1.Comment
    FROM SCore.DataObjectTransition AS dob1
    WHERE dob1.RowStatus NOT IN (0,254)
      AND dob1.DataObjectGuid = q.Guid
    ORDER BY dob1.ID DESC
) AS LatestTransitionComment
OUTER APPLY
(
    SELECT SUM(qi.Net) AS TotalNet
    FROM SSop.QuoteItems AS qi
    WHERE qi.QuoteId = q.ID
      AND qi.RowStatus NOT IN (0,254)
) AS qn
OUTER APPLY
(
    SELECT
        MAX(CASE WHEN ws.Guid = '25D5491C-42A8-4B04-B3AC-D648AF0F8032' THEN dot.DateTimeUTC END) AS SentStatusDate,
        MAX(CASE WHEN ws.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913' THEN dot.DateTimeUTC END) AS ChaseOneDate,
        MAX(CASE WHEN ws.Guid = '1F01C16B-1A73-4844-A938-FE357405FD93' THEN dot.DateTimeUTC END) AS ChaseTwoDate
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
) AS qw
OUTER APPLY
(
    SELECT
        MAX(CASE WHEN ws.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913' THEN dot.DateTimeUTC END) AS ChaseOneDate,
        MAX(CASE WHEN ws.Guid = '1F01C16B-1A73-4844-A938-FE357405FD93' THEN dot.DateTimeUTC END) AS ChaseTwoDate
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = e.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
) AS ew
OUTER APPLY
(
    SELECT TOP (1)
        CONCAT(CONVERT(date, dot.DateTimeUTC), N' - ', dot.Comment) AS Comment
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus <> 0
      AND dot.RowStatus <> 254
      AND ws.RowStatus <> 0
      AND ws.RowStatus <> 254
    ORDER BY
        dot.ID DESC
) AS LastStatusComment
WHERE q.ID > 0
  AND q.RowStatus NOT IN (0,254)
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
  );
GO
GO

/* Deploy StoredProcedure SFin.TransactionSageSubmission_Requeue using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.TransactionSageSubmission_Requeue.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageSubmission_Requeue]')
GO
PRINT (N'Create procedure [SFin].[TransactionSageSubmission_Requeue]')
GO
PRINT (N'Create procedure [SFin].[TransactionSageSubmission_Requeue]')
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionSageSubmission_Requeue]
(
    @TransactionGuid              UNIQUEIDENTIFIER = NULL,
    @TransactionGuidsJson         NVARCHAR(MAX) = NULL,
    @IncludeNonRetryableFailures  BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserID INT = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    IF (@TransactionGuid IS NULL)
       AND (NULLIF(LTRIM(RTRIM(@TransactionGuidsJson)), N'') IS NULL)
        THROW 50001, 'Either @TransactionGuid or @TransactionGuidsJson must be supplied.', 1;

    IF (@TransactionGuid IS NOT NULL)
       AND (NULLIF(LTRIM(RTRIM(@TransactionGuidsJson)), N'') IS NOT NULL)
        THROW 50002, 'Provide either @TransactionGuid or @TransactionGuidsJson, not both.', 1;

    IF (@TransactionGuidsJson IS NOT NULL AND ISJSON(@TransactionGuidsJson) <> 1)
        THROW 50003, '@TransactionGuidsJson must be a valid JSON array.', 1;

    DECLARE @RequestedGuids TABLE
    (
        TransactionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );

    IF (@TransactionGuid IS NOT NULL)
    BEGIN
        INSERT INTO @RequestedGuids (TransactionGuid)
        VALUES (@TransactionGuid);
    END
    ELSE
    BEGIN
        INSERT INTO @RequestedGuids (TransactionGuid)
        SELECT DISTINCT TRY_CONVERT(UNIQUEIDENTIFIER, j.[value])
        FROM OPENJSON(@TransactionGuidsJson) AS j
        WHERE TRY_CONVERT(UNIQUEIDENTIFIER, j.[value]) IS NOT NULL;
    END;

    IF NOT EXISTS (SELECT 1 FROM @RequestedGuids)
        THROW 50004, 'No valid transaction guids were supplied.', 1;

    DECLARE @Targets TABLE
    (
        TransactionID BIGINT NOT NULL,
        TransactionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        StatusID BIGINT NULL,
        CurrentStatusCode NVARCHAR(30) NULL,
        LastErrorIsRetryable BIT NULL
    );

    INSERT INTO @Targets
    (
        TransactionID,
        TransactionGuid,
        StatusID,
        CurrentStatusCode,
        LastErrorIsRetryable
    )
    SELECT
        t.ID,
        t.Guid,
        s.ID,
        s.StatusCode,
        s.LastErrorIsRetryable
    FROM SFin.Transactions AS t
    INNER JOIN @RequestedGuids AS rg
        ON rg.TransactionGuid = t.Guid
    LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
        ON s.TransactionGuid = t.Guid
       AND s.RowStatus NOT IN (0, 254)
    WHERE t.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserID) AS oscr
      );

    IF NOT EXISTS (SELECT 1 FROM @Targets)
    BEGIN
        SELECT
            CAST(0 AS INT) AS RequeuedTransactionCount,
            CAST(0 AS INT) AS ResetOutboxRowCount,
            CAST(0 AS INT) AS ResetStatusRowCount,
            N'No accessible transactions were found for the supplied guid(s).' AS [Message];

        RETURN;
    END;

    DECLARE @ResetCandidates TABLE
    (
        TransactionID BIGINT NOT NULL,
        TransactionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        StatusID BIGINT NULL
    );

    INSERT INTO @ResetCandidates
    (
        TransactionID,
        TransactionGuid,
        StatusID
    )
    SELECT
        x.TransactionID,
        x.TransactionGuid,
        x.StatusID
    FROM @Targets AS x
    WHERE ISNULL(x.CurrentStatusCode, N'') <> N'Succeeded'
      AND
      (
            x.StatusID IS NULL
         OR x.CurrentStatusCode IS NULL
         OR x.CurrentStatusCode IN (N'Pending', N'InProgress', N'FailedRetryable')
         OR (ISNULL(x.LastErrorIsRetryable, 0) = 1)
         OR (@IncludeNonRetryableFailures = 1 AND x.CurrentStatusCode = N'FailedNonRetryable')
      );

    IF NOT EXISTS (SELECT 1 FROM @ResetCandidates)
    BEGIN
        SELECT
            CAST(0 AS INT) AS RequeuedTransactionCount,
            CAST(0 AS INT) AS ResetOutboxRowCount,
            CAST(0 AS INT) AS ResetStatusRowCount,
            CASE
                WHEN @IncludeNonRetryableFailures = 1
                    THEN N'No eligible transaction submissions were found to reset.'
                ELSE N'No eligible retryable transaction submissions were found to reset.'
            END AS [Message];

        SELECT
            t.TransactionID,
            t.TransactionGuid,
            t.StatusID,
            t.CurrentStatusCode,
            t.LastErrorIsRetryable
        FROM @Targets AS t
        ORDER BY t.TransactionID;

        RETURN;
    END;

    DECLARE @ResetOutbox TABLE (ID BIGINT NOT NULL PRIMARY KEY);
    DECLARE @ResetStatuses TABLE (ID BIGINT NOT NULL PRIMARY KEY);

    BEGIN TRAN;

    UPDATE io
    SET
        io.PublishAttempts = 0,
        io.PublishingStartedOnUtc = NULL,
        io.PublishingToken = NULL,
        io.PublishedOnUtc = NULL,
        io.LastError = NULL
    OUTPUT inserted.ID INTO @ResetOutbox(ID)
    FROM SCore.IntegrationOutbox AS io
    INNER JOIN @ResetCandidates AS rc
        ON TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(CASE WHEN ISJSON(io.PayloadJson) = 1 THEN io.PayloadJson ELSE N'{}' END, '$.transactionGuid')) = rc.TransactionGuid
    WHERE io.RowStatus NOT IN (0, 254)
      AND io.EventType = N'TransactionApprovedForSageSubmission';

    UPDATE s
    SET
        s.StatusCode = N'Pending',
        s.IsInProgress = 0,
        s.InProgressClaimedOnUtc = NULL,
        s.LastFailedOnUtc = NULL,
        s.LastError = NULL,
        s.LastErrorIsRetryable = NULL,
        s.UpdatedDateTimeUTC = SYSUTCDATETIME(),
        s.UpdatedByUserID = @UserID
    OUTPUT inserted.ID INTO @ResetStatuses(ID)
    FROM SFin.TransactionSageSubmissionStatus AS s
    INNER JOIN @ResetCandidates AS rc
        ON rc.StatusID = s.ID
    WHERE s.RowStatus NOT IN (0, 254)
      AND ISNULL(s.StatusCode, N'') <> N'Succeeded';

    COMMIT TRAN;

    DECLARE
        @EnsureTransactionID BIGINT,
        @EnsureTransactionGuid UNIQUEIDENTIFIER;

    DECLARE ensure_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            rc.TransactionID,
            rc.TransactionGuid
        FROM @ResetCandidates AS rc
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SCore.IntegrationOutbox AS io
            WHERE io.RowStatus <> 0
              AND io.RowStatus <> 254
              AND io.EventType = N'TransactionApprovedForSageSubmission'
              AND io.PublishedOnUtc IS NULL
              AND ISJSON(io.PayloadJson) = 1
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(CASE WHEN ISJSON(io.PayloadJson) = 1 THEN io.PayloadJson ELSE N'{}' END, '$.transactionGuid')) = rc.TransactionGuid
        );

    OPEN ensure_cur;

    FETCH NEXT FROM ensure_cur INTO @EnsureTransactionID, @EnsureTransactionGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.TransactionSageSubmission_EnsureQueued
             @TransactionID = @EnsureTransactionID,
             @TransactionGuid = @EnsureTransactionGuid,
             @CreatedByUserId = @UserID,
             @SurveyorUserId = -1,
             @Comment = N'Sage submission requeue ensured missing outbox event.',
             @SuppressResult = 1;

        FETCH NEXT FROM ensure_cur INTO @EnsureTransactionID, @EnsureTransactionGuid;
    END;

    CLOSE ensure_cur;
    DEALLOCATE ensure_cur;

    SELECT
        COUNT(*) AS RequeuedTransactionCount,
        (SELECT COUNT(*) FROM @ResetOutbox) AS ResetOutboxRowCount,
        (SELECT COUNT(*) FROM @ResetStatuses) AS ResetStatusRowCount,
        CASE
            WHEN @IncludeNonRetryableFailures = 1
                THEN N'Transaction Sage submission reset for retry successfully.'
            ELSE N'Transaction Sage submission retry state reset successfully.'
        END AS [Message]
    FROM @ResetCandidates;

    SELECT
        rc.TransactionID,
        rc.TransactionGuid,
        ResetStatusRow = CASE WHEN rs.ID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,
        ResetOutboxRows =
        (
            SELECT COUNT(*)
            FROM SCore.IntegrationOutbox AS io
            WHERE io.RowStatus NOT IN (0, 254)
              AND io.EventType = N'TransactionApprovedForSageSubmission'
              AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(CASE WHEN ISJSON(io.PayloadJson) = 1 THEN io.PayloadJson ELSE N'{}' END, '$.transactionGuid')) = rc.TransactionGuid
              AND io.PublishAttempts = 0
              AND io.PublishingStartedOnUtc IS NULL
              AND io.PublishingToken IS NULL
              AND io.LastError IS NULL
        )
    FROM @ResetCandidates AS rc
    LEFT JOIN @ResetStatuses AS rs
        ON rs.ID = rc.StatusID
    ORDER BY rc.TransactionID;
END;
GO
GO

/* Deploy StoredProcedure SFin.TransactionsUpsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.TransactionsUpsert.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionsUpsert]')
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionsUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
    @JobGuid UNIQUEIDENTIFIER,
    @TransactionTypeGuid UNIQUEIDENTIFIER,
    @Date DATE,
    @PurchaseOrderNumber NVARCHAR(28),
    @SageTransactionReference NVARCHAR(50),
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @CreatedByUserGuid UNIQUEIDENTIFIER,
    @SurveyorGuid UNIQUEIDENTIFIER,
    @CreditTermsGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
    @Batched BIT,
	@ExpectedDate DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountID INT,
            @JobID INT,
            @TransactionTypeId SMALLINT,
            @IsInsert BIT = 0,
            @TranNo INT,
            @OrganisationalUnitId INT,
            @DepartmentPrefix NVARCHAR(10),
            @CreatedByUserId INT,
            @SurveyorUserId INT,
            @CreditTermsId INT,
            @ExistingBatched BIT,
            @ExistingAccountID INT,
            @ExistingJobID INT,
            @TransactionID BIGINT,
            @EnsureQueuedComment NVARCHAR(MAX);

    SELECT  @AccountID = ID
    FROM    SCrm.Accounts
    WHERE   [Guid] = @AccountGuid;

    SELECT  @JobID = ID
    FROM    SJob.Jobs
    WHERE   [Guid] = @JobGuid;

    SELECT  @TransactionTypeId = ID
    FROM    SFin.TransactionTypes
    WHERE   [Guid] = @TransactionTypeGuid;

    SELECT  @CreatedByUserId = ID
    FROM    SCore.Identities
    WHERE   [Guid] = @CreatedByUserGuid;

    SELECT  @SurveyorUserId = ID
    FROM    SCore.Identities
    WHERE   [Guid] = @SurveyorGuid;

    SELECT  @CreditTermsId = ID
    FROM    SFin.CreditTerms
    WHERE   [Guid] = @CreditTermsGuid;

    SELECT  @OrganisationalUnitId = ID,
            @DepartmentPrefix = DepartmentPrefix
    FROM    SCore.OrganisationalUnits ou
    WHERE   ou.Guid = @OrganisationalUnitGuid;

    EXEC SCore.UpsertDataObject
         @Guid = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'Transactions',
         @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT SFin.Transactions
        (
            RowStatus,
            Guid,
            TransactionTypeID,
            AccountID,
            JobID,
            Number,
            Date,
            PurchaseOrderNumber,
            SageTransactionReference,
            OrganisationalUnitId,
            CreatedByUserId,
            SurveyorUserId,
            CreditTermsId,
            Batched,
			ExpectedDate
        )
        VALUES
        (
            0,
            @Guid,
            @TransactionTypeId,
            @AccountID,
            @JobID,
            0,
            @Date,
            @PurchaseOrderNumber,
            @SageTransactionReference,
            @OrganisationalUnitId,
            @CreatedByUserId,
            @SurveyorUserId,
            @CreditTermsId,
            1,
			@ExpectedDate
        );
    END
    ELSE
    BEGIN
        SELECT  @TransactionID = t.ID,
                @ExistingBatched = t.Batched,
                @ExistingAccountID = t.AccountID,
                @ExistingJobID = t.JobID
        FROM    SFin.Transactions t
        WHERE   t.Guid = @Guid;

        UPDATE  SFin.Transactions
        SET     Date = @Date,
                JobID = @JobID,
                PurchaseOrderNumber = @PurchaseOrderNumber,
                SageTransactionReference = @SageTransactionReference,
                SurveyorUserId = @SurveyorUserId,
                CreditTermsId = @CreditTermsId,
                Batched = @Batched,
				ExpectedDate = @ExpectedDate,
                AccountID = CASE
                                WHEN @ExistingBatched = 1 THEN @AccountID
                                ELSE AccountID
                            END
        WHERE   [Guid] = @Guid;

        IF (@ExistingBatched = 1 AND ISNULL(@ExistingAccountID, -1) <> ISNULL(@AccountID, -1))
        BEGIN
            UPDATE  SJob.Jobs
            SET     FinanceAccountID = @AccountID
            WHERE   ID = @ExistingJobID;
        END

        IF (ISNULL(@Batched, 1) = 0)
        BEGIN
            SET @EnsureQueuedComment =
                CASE
                    WHEN ISNULL(@ExistingBatched, 0) = 1
                        THEN N'Finance approval detected from TransactionsUpsert Batched 1 to 0.'
                    ELSE N'Finance approval repair detected from TransactionsUpsert for already unbatched transaction.'
                END;

            EXEC SFin.TransactionSageSubmission_EnsureQueued
                 @TransactionID = @TransactionID,
                 @TransactionGuid = @Guid,
                 @CreatedByUserId = @CreatedByUserId,
                 @SurveyorUserId = @SurveyorUserId,
                 @Comment = @EnsureQueuedComment,
                 @SuppressResult = 1;
        END
    END

    IF (@IsInsert = 1)
    BEGIN
        SELECT @TranNo = NEXT VALUE FOR SFin.TransactionNumber;

        UPDATE  SFin.Transactions
        SET     Number = @DepartmentPrefix + CONVERT(NVARCHAR(30), @TranNo),
                RowStatus = 1
        WHERE   [Guid] = @Guid;
    END
END
GO
GO

/* Deploy StoredProcedure SFin.TransactionUnbatch using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.TransactionUnbatch.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionUnbatch]')
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionUnbatch]
    @Guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @IsBatched BIT = 0,
        @TransactionID BIGINT,
        @TransactionNumber NVARCHAR(30),
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE @EnsureOutcome TABLE
    (
        TransactionID BIGINT NULL,
        TransactionGuid UNIQUEIDENTIFIER NULL,
        TransitionID BIGINT NULL,
        TransitionGuid UNIQUEIDENTIFIER NULL,
        OutboxID BIGINT NULL,
        Outcome NVARCHAR(50) NULL,
        [Message] NVARCHAR(MAX) NULL
    );

    SELECT
        @TransactionID = ID,
        @IsBatched = Batched,
        @TransactionNumber = Number,
        @SurveyorUserId = SurveyorUserId,
        @CreatedByUserId = CreatedByUserId
    FROM SFin.Transactions
    WHERE Guid = @Guid
      AND RowStatus <> 0
      AND RowStatus <> 254;

    IF @TransactionID IS NULL
    BEGIN
        ;THROW 51002, 'Cannot unbatch transaction because it was not found or is inactive.', 1;
    END;

    IF (@IsBatched = 1)
    BEGIN
        UPDATE SFin.Transactions
        SET Batched = 0
        WHERE Guid = @Guid
          AND RowStatus <> 0
          AND RowStatus <> 254;
    END;

    /*
        CYB-414 / Sage posting reliability
        -------------------------------
        Always ensure the Sage submission event is queued after this procedure is
        called, even if the transaction is already Batched = 0. This makes the
        Post to Sage action idempotent and repairs the partial Live state where
        the transaction had been unbatched but no TransactionBatchTransition /
        TransactionApprovedForSageSubmission outbox row existed.
    */
    INSERT INTO @EnsureOutcome
    EXEC SFin.TransactionSageSubmission_EnsureQueued
         @TransactionID = @TransactionID,
         @TransactionGuid = @Guid,
         @CreatedByUserId = @CreatedByUserId,
         @SurveyorUserId = @SurveyorUserId,
         @Comment = N'Finance approval detected from TransactionUnbatch.',
         @SuppressResult = 0;

    SELECT
        TransactionID,
        TransactionGuid,
        TransitionID,
        TransitionGuid,
        OutboxID,
        Outcome,
        [Message]
    FROM @EnsureOutcome;
END;
GO

GO

/* Deploy Trigger SFin.tr_Transactions_RecordBatchApprovalTransition using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Triggers\SFin.tr_Transactions_RecordBatchApprovalTransition.sql */
PRINT (N'Create trigger [SFin].[tr_Transactions_RecordBatchApprovalTransition] on table [SFin].[Transactions]')
GO
CREATE OR ALTER TRIGGER [SFin].[tr_Transactions_RecordBatchApprovalTransition]
ON [SFin].[Transactions]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    IF NOT UPDATE(Batched)
        RETURN;

    DECLARE
        @TransactionID BIGINT,
        @TransactionGuid UNIQUEIDENTIFIER,
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            i.ID,
            i.Guid,
            i.SurveyorUserId,
            COALESCE(CONVERT(INT, SESSION_CONTEXT(N'user_id')), i.CreatedByUserId, -1) AS CreatedByUserId
        FROM inserted AS i
        INNER JOIN deleted AS d
            ON d.ID = i.ID
        WHERE i.RowStatus <> 0
          AND i.RowStatus <> 254
          AND d.RowStatus <> 0
          AND d.RowStatus <> 254
          AND ISNULL(d.Batched, 0) = 1
          AND ISNULL(i.Batched, 0) = 0;

    OPEN cur;

    FETCH NEXT FROM cur INTO
        @TransactionID,
        @TransactionGuid,
        @SurveyorUserId,
        @CreatedByUserId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.TransactionSageSubmission_EnsureQueued
             @TransactionID = @TransactionID,
             @TransactionGuid = @TransactionGuid,
             @CreatedByUserId = @CreatedByUserId,
             @SurveyorUserId = @SurveyorUserId,
             @Comment = N'Finance approval detected from Batched 1 to 0.',
             @SuppressResult = 1;

        FETCH NEXT FROM cur INTO
            @TransactionID,
            @TransactionGuid,
            @SurveyorUserId,
            @CreatedByUserId;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

GO
EXEC [SCore].[PostDeploymentScript];
GO

