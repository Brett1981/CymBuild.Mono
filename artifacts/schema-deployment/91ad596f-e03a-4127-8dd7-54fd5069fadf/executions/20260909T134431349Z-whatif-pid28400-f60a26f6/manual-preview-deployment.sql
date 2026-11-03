/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLBRE01\SQL2022
    Target database : CymBuild_UAT
    Run Guid        : 91ad596f-e03a-4127-8dd7-54fd5069fadf
    Generated UTC   : 2026-09-09T13:45:41.6662723Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_UAT];
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

/* Preflight Table SFin.InvoiceRequests from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\Generated\Tables\SFin.InvoiceRequests.preflight.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Table SFin.InvoiceRequests
    Difference         : Different
    Comparison hash    : 91F7D44A641BA6D2FF712AE2D88618554D556D865B93B106E0660FBB8011B009
    Definition SHA-256 : DA4F59042E1F0B096D2608EAAB040935D3FDC2F84315F756A86F7E93B745D781
    Purpose            : Read-only preflight for declarative existing-table convergence.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SFin].[InvoiceRequests]', N'U') IS NULL THROW 51420, 'Table convergence parent table does not exist.', 1;
IF OBJECT_ID(N'[SFin].[DF_InvoiceRequests_IsRejected]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SFin].[DF_InvoiceRequests_IsRejected]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SFin].[InvoiceRequests]', N'U') AND c.name = N'IsRejected') THROW 51422, 'Default constraint name SFin.DF_InvoiceRequests_IsRejected is already used by another column.', 1;
GO

GO

/* Preflight Table SFin.InvoiceSchedules from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\Generated\Tables\SFin.InvoiceSchedules.preflight.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Table SFin.InvoiceSchedules
    Difference         : Different
    Comparison hash    : 96E3D436266C4602E9A71773F67130C21097C64767DBE8C4F0B91D6F888B5FB6
    Definition SHA-256 : 04579C1DA2D52A5830F9F4A07C67442632C346C52EC5499D20138AE34833182B
    Purpose            : Read-only preflight for declarative existing-table convergence.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SFin].[InvoiceSchedules]', N'U') IS NULL THROW 51420, 'Table convergence parent table does not exist.', 1;
IF OBJECT_ID(N'[SFin].[DF_InvoiceSchedules_Frequency]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SFin].[DF_InvoiceSchedules_Frequency]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SFin].[InvoiceSchedules]', N'U') AND c.name = N'Frequency') THROW 51422, 'Default constraint name SFin.DF_InvoiceSchedules_Frequency is already used by another column.', 1;
GO

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

/* Strict post-pre-deployment preflight Table SFin.InvoiceRequests */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Table SFin.InvoiceRequests
    Difference         : Different
    Comparison hash    : 91F7D44A641BA6D2FF712AE2D88618554D556D865B93B106E0660FBB8011B009
    Definition SHA-256 : DA4F59042E1F0B096D2608EAAB040935D3FDC2F84315F756A86F7E93B745D781
    Purpose            : Read-only preflight for declarative existing-table convergence.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SFin].[InvoiceRequests]', N'U') IS NULL THROW 51420, 'Table convergence parent table does not exist.', 1;
IF OBJECT_ID(N'[SFin].[DF_InvoiceRequests_IsRejected]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SFin].[DF_InvoiceRequests_IsRejected]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SFin].[InvoiceRequests]', N'U') AND c.name = N'IsRejected') THROW 51422, 'Default constraint name SFin.DF_InvoiceRequests_IsRejected is already used by another column.', 1;
GO

GO

/* Strict post-pre-deployment preflight Table SFin.InvoiceSchedules */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Table SFin.InvoiceSchedules
    Difference         : Different
    Comparison hash    : 96E3D436266C4602E9A71773F67130C21097C64767DBE8C4F0B91D6F888B5FB6
    Definition SHA-256 : 04579C1DA2D52A5830F9F4A07C67442632C346C52EC5499D20138AE34833182B
    Purpose            : Read-only preflight for declarative existing-table convergence.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SFin].[InvoiceSchedules]', N'U') IS NULL THROW 51420, 'Table convergence parent table does not exist.', 1;
IF OBJECT_ID(N'[SFin].[DF_InvoiceSchedules_Frequency]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SFin].[DF_InvoiceSchedules_Frequency]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SFin].[InvoiceSchedules]', N'U') AND c.name = N'Frequency') THROW 51422, 'Default constraint name SFin.DF_InvoiceSchedules_Frequency is already used by another column.', 1;
GO

GO

/* Prepare Index SJob.ActivityTypes.ActivityTypes.IX_UQ_ActivityTypes_Guid from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid
    Difference         : Different
    Comparison hash    : 745FC68E5AD42D12964C4C8974BF55DB3BE82F1107EBB71034BF97C468ACF301
    Definition SHA-256 : E9DF89D60524F3EDC6DE8A9702FC7BEF8A0D23D3C2A33902CE84A495A1630DB1
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Index SJob.ProjectDirectoryRoles.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name
    Difference         : Different
    Comparison hash    : 139B79A0347C711B3C48857D26DE0DDD4A47CCA6567B3DB0D2DDD0AB58D0A9F2
    Definition SHA-256 : 8BBD997E88B0C32849B9F4B34C6B3E7A5B2AD7E5A4C0F5743E3A247D8E9F651E
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Index SUserInterface.ActionMenuItems.ActionMenuItems.IX_UQ_ActionMenuItems_Gud from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud
    Difference         : Different
    Comparison hash    : 16A5B8FE77DD931A5CDD64476A8B43FF66A013C0C8BD16C6862F9478673CC298
    Definition SHA-256 : 931CDE0A02A471EB31E8CDE9B4E086A814E34190A71753BDC72FF17A856D1446
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Index SUserInterface.Icons.Icons.IX_UQ_MetricTypes_Name from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.Icons.IX_UQ_MetricTypes_Name.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.Icons.IX_UQ_MetricTypes_Name
    Difference         : Different
    Comparison hash    : EE1D76B1676B7D5D6C205542935303315E4946377C4019DB2C4BA578A771ACEA
    Definition SHA-256 : 625F8DA516CC6D4D08F6426554BB46B51CE1FAEC9EEE2E0D63CEFB2FF2E3ADCB
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Index SUserInterface.WidgetDashboards.WidgetDashboards.IX_UQ_WidgetDashboards_Guid from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid
    Difference         : Different
    Comparison hash    : 1D0FBF60FB88C403E54CB6EC4EA006C2146AC380F8E8377B5B488DBA6CCABC80
    Definition SHA-256 : 11E0AC9C6412EC3C4AEF1B33EF20DF95CA7CE44BADCFDDBAB4EF853FCB1D181F
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Index SUserInterface.WidgetDashboardWidgetTypes.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid
    Difference         : Different
    Comparison hash    : 23579467C0A0D4D896205D753D51DA2654D4047A14A238E74FD1C2287DA26CC4
    Definition SHA-256 : 0E075C72CB73E04CBBE8809D773F8225B13F500BE17D4C266A63F53DA4378364
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Index SUserInterface.WidgetTypes.WidgetTypes.IX_UQ_WidgetTypes_Guid from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid
    Difference         : Different
    Comparison hash    : 05FEC715E4BB8ABC6DDDA359EDF123320514D611C36C226A5C0E8DF0621D3377
    Definition SHA-256 : 1CD55E549F011B8ABD85C6458E90111CCB61C52F3D73C4E29977F38C3FEC0D09
    Purpose            : Prepare phase: preserve the target index for atomic replacement during finalize.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
-- Differing rowstore indexes are replaced atomically by the finalize script with
-- DROP_EXISTING = ON. The existing target index remains available if replacement fails.
GO

GO

/* Prepare Constraint SUserInterface.Icons.UK_Icons_Guid from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SUserInterface.Icons.UK_Icons_Guid.prepare.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SUserInterface.Icons.UK_Icons_Guid
    Difference         : Different
    Comparison hash    : E97635C3A93E5D52E26734F7FCF26D1287A4C629737297E4703E137680267A8D
    Definition SHA-256 : 5299AD4CF96CDD0E94E41CCF0709BD703FF41FA5742902F360856D3DEDC26A11
    Purpose            : Prepare phase: remove the target constraint before structural deployment.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SUserInterface].[Icons]', N'U')
      AND constraintObject.name = N'UK_Icons_Guid'
)
    BEGIN
        ALTER TABLE [SUserInterface].[Icons] DROP CONSTRAINT [UK_Icons_Guid];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

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

/* Deploy Table SFin.InvoiceRequests using DeclarativeTableAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\Generated\Tables\SFin.InvoiceRequests.alter.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Table SFin.InvoiceRequests
    Difference         : Different
    Comparison hash    : 91F7D44A641BA6D2FF712AE2D88618554D556D865B93B106E0660FBB8011B009
    Definition SHA-256 : DA4F59042E1F0B096D2608EAAB040935D3FDC2F84315F756A86F7E93B745D781
    Purpose            : Apply guarded, idempotent column and table-option convergence.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @CymBuildDefaultConstraintName SYSNAME;
    DECLARE @CymBuildDropDefaultSql NVARCHAR(MAX);
    IF COL_LENGTH(N'[SFin].[InvoiceRequests]', N'IsRejected') IS NULL
        ALTER TABLE [SFin].[InvoiceRequests] ADD [IsRejected] bit NOT NULL CONSTRAINT [DF_InvoiceRequests_IsRejected] DEFAULT ((0)) WITH VALUES;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Table SFin.InvoiceSchedules using DeclarativeTableAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\Generated\Tables\SFin.InvoiceSchedules.alter.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Table SFin.InvoiceSchedules
    Difference         : Different
    Comparison hash    : 96E3D436266C4602E9A71773F67130C21097C64767DBE8C4F0B91D6F888B5FB6
    Definition SHA-256 : 04579C1DA2D52A5830F9F4A07C67442632C346C52EC5499D20138AE34833182B
    Purpose            : Apply guarded, idempotent column and table-option convergence.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @CymBuildDefaultConstraintName SYSNAME;
    DECLARE @CymBuildDropDefaultSql NVARCHAR(MAX);
    IF COL_LENGTH(N'[SFin].[InvoiceSchedules]', N'Frequency') IS NULL
        ALTER TABLE [SFin].[InvoiceSchedules] ADD [Frequency] nvarchar(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_InvoiceSchedules_Frequency] DEFAULT (NULL);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Function SCrm.tvf_AccountsCheckForDuplicate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SCrm.tvf_AccountsCheckForDuplicate.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SCrm.tvf_AccountsCheckForDuplicate
    Source schema hash : 4CD32AAD9EC4FE94DF76200F7794221C25647128A42A115D2545E2329829BE3B
    Definition SHA-256 : 33EDCF54DEBB056E9480E5A4F4789DD6DF39BC79EC1BD79F3BFD5E8C9AE2204A

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SCrm].[tvf_AccountsCheckForDuplicate] 
(
   @DisplayName    NVARCHAR(100)   = NULL
)
RETURNS @Results TABLE
(
	Guid UNIQUEIDENTIFIER,
	DisplayName NVARCHAR(MAX),
	MatchScore INT
)
AS
BEGIN
	--Normalise value
	DECLARE @NormName       NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@DisplayName, ''))));

INSERT INTO @Results
(
	Guid,
	DisplayName,
	MatchScore
)
SELECT
	scored.Guid,
	-- FORMAT => (Account Status) (Name + Code) | Main Contact: ... | Main Address: ...
	CONCAT(
		CASE
			WHEN scored.MatchScore >= 50 THEN N'[HIGH MATCH] '
			WHEN scored.MatchScore >= 25 THEN N'[MEDIUM MATCH] '
			ELSE N'[LOW MATCH] '
		END,
		N'(', ISNULL(NULLIF(TRIM(scored.AccountStatusName), N''), N'Unknown'), N') ',
		scored.ConcatenatedNameCode,
		N' | Main Contact: ', ISNULL(NULLIF(TRIM(scored.ContactDisplayName), N''), N'N/A'),
		N' | Main Address: ', ISNULL(NULLIF(TRIM(scored.FormattedAddressComma), N''), N'N/A')
	) AS DisplayName,
	scored.MatchScore
FROM
(
	SELECT
		root_hobt.Guid,
		root_hobt.ConcatenatedNameCode,
		acs.Name AS AccountStatusName,
		contact.DisplayName AS ContactDisplayName,
		contactAddress.FormattedAddressComma,
		(
			-- Exact Name match
			CASE WHEN @NormName <> ''
				 AND UPPER(LTRIM(RTRIM(root_hobt.Name))) = @NormName
				 THEN 40 ELSE 0 END

			-- Prefix match: one name starts with the other, independent of SOUNDEX. Catches "AB"
			-- matching "ABX Company", and "Acme" matching "Acme (1)"/"Acme (2)" regardless of
			-- suffix length. This must NOT be folded into the SOUNDEX branch below - SOUNDEX
			-- encodes phonetics from the *whole* remaining string, so SOUNDEX('AB') never equals
			-- SOUNDEX('ABX Company Ltd') even though the name plainly starts with "AB". Requiring
			-- SOUNDEX equality before ever checking the prefix (the previous approach) meant short
			-- prefix searches almost never matched longer real names (CYB-312 QA feedback).
			+ CASE WHEN @NormName <> ''
				   AND root_hobt.Name <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Name))) <> @NormName
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.Name))) LIKE @NormName + N'%'
						OR @NormName LIKE UPPER(LTRIM(RTRIM(root_hobt.Name))) + N'%'
					   )
				   THEN 20 ELSE 0 END

			-- SOUNDEX Name match (fuzzy, for near-miss spellings of similar length - e.g.
			-- "Cymbild" vs "Cymbuild"). Gated on similar overall length so unrelated names that
			-- happen to share a SOUNDEX code (which ignores length) aren't flagged - without this,
			-- a broad SOUNDEX-only match surfaces dozens of unrelated accounts for common name
			-- codes (CYB-312 QA feedback).
			+ CASE WHEN @NormName <> ''
				   AND root_hobt.Name <> ''
				   AND SOUNDEX(root_hobt.Name) = SOUNDEX(@DisplayName)
				   AND UPPER(LTRIM(RTRIM(root_hobt.Name))) <> @NormName
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.Name))) - LEN(@NormName)) <= 3
				   THEN 15 ELSE 0 END
		) AS MatchScore
	FROM SCrm.Accounts AS root_hobt
	LEFT JOIN SCrm.AccountStatus acs ON (acs.ID = root_hobt.AccountStatusID)
	LEFT JOIN SCrm.Contacts contact ON (root_hobt.MainAccountContactId = contact.ID)
	LEFT JOIN SCrm.Addresses contactAddress ON (root_hobt.MainAccountAddressId = contactAddress.ID)
	WHERE
			root_hobt.RowStatus NOT IN (0,254)
		AND (
				(@NormName <> '' AND root_hobt.Name <> '' AND UPPER(LTRIM(RTRIM(root_hobt.Name))) = @NormName)
			 OR (@NormName <> '' AND root_hobt.Name <> '' AND (
						UPPER(LTRIM(RTRIM(root_hobt.Name))) LIKE @NormName + N'%'
					 OR @NormName LIKE UPPER(LTRIM(RTRIM(root_hobt.Name))) + N'%'
				 ))
			 OR (@NormName <> '' AND root_hobt.Name <> '' AND SOUNDEX(root_hobt.Name) = SOUNDEX(@DisplayName)
					AND ABS(LEN(LTRIM(RTRIM(root_hobt.Name))) - LEN(@NormName)) <= 3)
			)
) AS scored


	DELETE FROM @Results WHERE MatchScore <= 0;

	RETURN;
END;
GO

/* Deploy Function SCrm.tvf_ContactsCheckForDuplicate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SCrm.tvf_ContactsCheckForDuplicate.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SCrm.tvf_ContactsCheckForDuplicate
    Source schema hash : 99AE65F405935383399D2998488A743C78E39E98F9F9617E1A8A788B90AD98E7
    Definition SHA-256 : 38CA16981413E4EFA7A43547E7074C9B1AB4FB5FA7EE43CF939B30242CA0B59A

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SCrm].[tvf_ContactsCheckForDuplicate] 
(
   @DisplayName    NVARCHAR(100)   = N'',
   @FirstName	   NVARCHAR(100)   = N'',
   @Surname		   NVARCHAR(100)   = N'',
   @Initials	   NVARCHAR(10)    = N''
)
RETURNS @Results TABLE
(
	Guid UNIQUEIDENTIFIER,
	DisplayName NVARCHAR(MAX),
	MatchScore INT
)
AS
BEGIN

	--Normalise value
	DECLARE 
			@NormName		NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@DisplayName, '')))),
			@NormFirstName	NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@FirstName, '')))),
			@NormSurname	NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@Surname, '')))),
			@NormInitials	NVARCHAR(10) = UPPER(LTRIM(RTRIM(ISNULL(@Initials, ''))));



INSERT INTO @Results
(
	Guid,
	DisplayName,
	MatchScore
)
SELECT
	scored.Guid,
	CONCAT(
		CASE
			WHEN scored.MatchScore >= 50 THEN N'[HIGH MATCH] '
			WHEN scored.MatchScore >= 25 THEN N'[MEDIUM MATCH] '
			ELSE N'[LOW MATCH] '
		END,
		N' | ',
		scored.DisplayName,
		N' | ',
		scored.Surname,
		N' ',
		scored.FirstName,
		N' | Primary Account: ',
		ISNULL(NULLIF(TRIM(scored.AccountName), N''), N'N/A')
	) AS DisplayName,
	scored.MatchScore
FROM
(
	SELECT
		root_hobt.Guid,
		root_hobt.DisplayName,
		root_hobt.Surname,
		root_hobt.FirstName,
		ac.Name AS AccountName,
		(
			-- Exact => Initials
			CASE WHEN @NormInitials <> ''
				 AND UPPER(LTRIM(RTRIM(root_hobt.Initials))) = @NormInitials
				 THEN 5 ELSE 0 END

			-- Exact => Last name
			+ CASE WHEN @NormSurname <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Surname))) = @NormSurname
				   THEN 25 ELSE 0 END

			-- Prefix => Last name
			+ CASE WHEN @NormSurname <> ''
				   AND root_hobt.Surname <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Surname))) <> @NormSurname
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.Surname))) LIKE @NormSurname + N'%'
						OR @NormSurname LIKE UPPER(LTRIM(RTRIM(root_hobt.Surname))) + N'%'
					   )
				   THEN 15 ELSE 0 END

			-- SOUNDEX => Last Name
			+ CASE WHEN @NormSurname <> ''
				   AND LEN(@NormSurname) >= 3
				   AND root_hobt.Surname <> ''
				   AND SOUNDEX(root_hobt.Surname) = SOUNDEX(@NormSurname)
				   AND UPPER(LTRIM(RTRIM(root_hobt.Surname))) <> @NormSurname
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.Surname))) - LEN(@NormSurname)) <= 3
				   THEN 10 ELSE 0 END

			-- Exact => First name
			+ CASE WHEN @NormFirstName <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.FirstName))) = @NormFirstName
				   THEN 20 ELSE 0 END

			-- Prefix => First name
			+ CASE WHEN @NormFirstName <> ''
				   AND root_hobt.FirstName <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.FirstName))) <> @NormFirstName
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.FirstName))) LIKE @NormFirstName + N'%'
						OR @NormFirstName LIKE UPPER(LTRIM(RTRIM(root_hobt.FirstName))) + N'%'
					   )
				   THEN 15 ELSE 0 END

			-- SOUNDEX => First Name
			+ CASE WHEN @NormFirstName <> ''
				   AND LEN(@NormFirstName) >= 3
				   AND root_hobt.FirstName <> ''
				   AND SOUNDEX(root_hobt.FirstName) = SOUNDEX(@NormFirstName)
				   AND UPPER(LTRIM(RTRIM(root_hobt.FirstName))) <> @NormFirstName
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.FirstName))) - LEN(@NormFirstName)) <= 3
				   THEN 10 ELSE 0 END

			-- Exact => Display name
			+ CASE WHEN @NormName <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) = @NormName
				   THEN 50 ELSE 0 END

			-- Prefix => Display name
			+ CASE WHEN @NormName <> ''
				   AND root_hobt.DisplayName <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) <> @NormName
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) LIKE @NormName + N'%'
						OR @NormName LIKE UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) + N'%'
					   )
				   THEN 25 ELSE 0 END

			-- SOUNDEX => DisplayName
			+ CASE WHEN @NormName <> ''
				   AND LEN(@NormName) >= 3
				   AND root_hobt.DisplayName <> ''
				   AND SOUNDEX(root_hobt.DisplayName) = SOUNDEX(@NormName)
				   AND UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) <> @NormName
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.DisplayName))) - LEN(@NormName)) <= 3
				   THEN 20 ELSE 0 END
		) AS MatchScore
	FROM SCrm.Contacts AS root_hobt
	JOIN SCrm.Accounts ac ON (ac.ID = root_hobt.PrimaryAccountID)
	WHERE
			root_hobt.RowStatus NOT IN (0,254)
		AND (
			   (@NormName <> '' AND root_hobt.DisplayName <> '' AND (
			   		UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) = @NormName
			   	 OR UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) LIKE @NormName + N'%'
			   	 OR @NormName LIKE UPPER(LTRIM(RTRIM(root_hobt.DisplayName))) + N'%'
			   	 OR (LEN(@NormName) >= 3 AND SOUNDEX(root_hobt.DisplayName) = SOUNDEX(@DisplayName))
			   ))
			OR (@NormFirstName <> N'' AND root_hobt.FirstName <> N'' AND (
					root_hobt.FirstName LIKE N'%' + @FirstName + N'%'
				 OR (LEN(@NormFirstName) >= 3 AND SOUNDEX(root_hobt.FirstName) = SOUNDEX(@NormFirstName))
			))
			OR (@NormSurname <> N'' AND root_hobt.Surname <> N'' AND (
					root_hobt.Surname LIKE N'%' + @Surname + N'%'
				 OR (LEN(@NormSurname) >= 3 AND SOUNDEX(root_hobt.Surname) = SOUNDEX(@NormSurname))
			))
			OR (@NormInitials <> N'' AND (root_hobt.Initials LIKE N'%' + @Initials + N'%' OR root_hobt.Initials = @Initials))
			)
) AS scored


	DELETE FROM @Results WHERE MatchScore <= 10;

	RETURN;

END;
GO

GO

/* Deploy Function SFin.TransactionDetailsValidate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.TransactionDetailsValidate.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.TransactionDetailsValidate
    Source schema hash : B10D034A0EB6193D80F3CECD618D34C04A517DE6723E2AF60EAE33D0B26601A6
    Definition SHA-256 : 92DCF1832AF7983BB4B4520B5F9A53814DB5778BC9C23F63D25BB79848D9C26D

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SFin].[TransactionDetailsValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @TransactionGuid UNIQUEIDENTIFIER
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    IsInformationOnly BIT NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE
        @CurrentUserId INT = SCore.GetCurrentUserId(),
        @CurrentUserIsFinance BIT = 0,
        @TransactionDetailsHoBTGuid UNIQUEIDENTIFIER,
        @ExistingTransactionDetail BIT = 0,
        @ParentIsBatched BIT = NULL,
        @IsReadOnly BIT = 0,
        @IsInvalid BIT = 0,
        @ValidationMessage NVARCHAR(2000) = N'';

    SELECT
        @TransactionDetailsHoBTGuid = eh.Guid
    FROM SCore.EntityHobts AS eh
    WHERE eh.SchemaName = N'SFin'
      AND eh.ObjectName = N'TransactionDetails'
      AND eh.RowStatus NOT IN (0, 254);

    SELECT
        @CurrentUserIsFinance = CONVERT(BIT, 1)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups AS ug
        JOIN SCore.Groups AS g
          ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @CurrentUserId
          AND ug.RowStatus NOT IN (0, 254)
          AND g.RowStatus NOT IN (0, 254)
          AND
          (
              g.Code = N'FINANCE'
              OR g.Name IN (N'Finance', N'Finance Group')
          )
    );

    /*
        Existing detail row:
        Resolve the parent transaction from the persisted TransactionID.
    */
    SELECT
        @ExistingTransactionDetail = CONVERT(BIT, 1),
        @ParentIsBatched = CONVERT(BIT, t.Batched)
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
      ON t.ID = td.TransactionID
    WHERE td.Guid = @Guid
      AND td.RowStatus NOT IN (0, 254)
      AND t.RowStatus NOT IN (0, 254);

    /*
        New detail row:
        Resolve the parent transaction from the incoming TransactionGuid.
    */
    IF @ExistingTransactionDetail = 0
       AND @TransactionGuid IS NOT NULL
       AND @TransactionGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @ParentIsBatched = CONVERT(BIT, t.Batched)
        FROM SFin.Transactions AS t
        WHERE t.Guid = @TransactionGuid
          AND t.RowStatus NOT IN (0, 254);
    END;

    /*
        Non-Finance:
          - Existing detail rows are read-only.
          - New detail rows are blocked.

        Finance:
          - Existing detail rows remain editable, even when parent transaction is approved / Batched = 0.
          - New detail rows are blocked once parent transaction is approved / Batched = 0.
    */
    IF @CurrentUserIsFinance = 0
    BEGIN
        SET @IsReadOnly = 1;

        IF @ExistingTransactionDetail = 0
        BEGIN
            SET @IsInvalid = 1;
            SET @ValidationMessage = N'Only Finance users can create transaction details.';
        END;
    END;

    IF @CurrentUserIsFinance = 1
       AND @ExistingTransactionDetail = 0
       AND @ParentIsBatched = 0
    BEGIN
        SET @IsInvalid = 1;
        SET @ValidationMessage = N'Transaction details cannot be added once the transaction has been approved from batched status.';
    END;

    IF @TransactionDetailsHoBTGuid IS NOT NULL
       AND
       (
           @IsReadOnly = 1
           OR @IsInvalid = 1
       )
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            IsInformationOnly,
            Message
        )
        VALUES
        (
            @TransactionDetailsHoBTGuid,
            N'H',
            @IsReadOnly,
            0,
            @IsInvalid,
            0,
            @ValidationMessage
        );
    END;

	--Archived transaction: read-only
	IF(EXISTS
		(
			SELECT 1 
			FROM SFin.Transactions
			WHERE 
					RowStatus IN (200)
				AND Guid = @TransactionGuid
		)
	 )
	BEGIN
         INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        VALUES
        (
            @TransactionDetailsHoBTGuid,
            N'H',
            1,
            0,
            0,
            N''
        );
    END;

    RETURN;
END;
GO

GO

/* Deploy Function SFin.TransactionsValidate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.TransactionsValidate.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.TransactionsValidate
    Source schema hash : 59449E31517492B8B5D31144758372DDBDCA38DA539553BBCD613AA0B4B25222
    Definition SHA-256 : BD691AE4C8B812690EA0DE379B82856621716A81E9AAB6AE7CBE6365A4DE2CB0

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SFin].[TransactionsValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @AccountGuid UNIQUEIDENTIFIER,
    @TransactionTypeGuid UNIQUEIDENTIFIER,
    @Batched BIT
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL
        DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    IsInformationOnly BIT NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE
        @EntityPropertyGuid UNIQUEIDENTIFIER,
        @TransactionsHoBTGuid UNIQUEIDENTIFIER,
        @CurrentUserId INT = SCore.GetCurrentUserId(),
        @CurrentUserIsFinance BIT = 0,
        @ExistingTransaction BIT = 0;

    SELECT
        @TransactionsHoBTGuid = eh.Guid
    FROM SCore.EntityHobts AS eh
    WHERE eh.SchemaName = N'SFin'
      AND eh.ObjectName = N'Transactions'
      AND eh.RowStatus NOT IN (0, 254);

    SELECT
        @ExistingTransaction = CONVERT(BIT, 1)
    FROM SFin.Transactions AS t
    WHERE t.Guid = @Guid
      AND t.RowStatus NOT IN (0, 254);

    SELECT
        @CurrentUserIsFinance = CONVERT(BIT, 1)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups AS ug
        INNER JOIN SCore.Groups AS g
            ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @CurrentUserId
          AND ug.RowStatus NOT IN (0, 254)
          AND g.RowStatus NOT IN (0, 254)
          AND
          (
              g.Code = N'FINANCE'
              OR g.Name IN
              (
                  N'Finance',
                  N'Finance Group'
              )
          )
    );

    /*
        Existing transaction headers are read-only for non-Finance users.

        Finance users remain responsible for validating amendments.
        Property-level read-only metadata still controls permanently shaded
        fields such as Number and Organisational Unit.
    */
    IF @TransactionsHoBTGuid IS NOT NULL
       AND @ExistingTransaction = 1
       AND @CurrentUserIsFinance = 0
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        VALUES
        (
            @TransactionsHoBTGuid,
            N'H',
            1,
            0,
            0,
            N''
        );
    END;

    -- Hide Credit Terms for bank transactions.
    IF EXISTS
    (
        SELECT 1
        FROM SFin.TransactionTypes AS tt
        WHERE tt.Guid = @TransactionTypeGuid
          AND tt.IsBank = 1
          AND tt.RowStatus NOT IN (0, 254)
    )
    BEGIN
        SELECT
            @EntityPropertyGuid =
                SCore.GetEntityPropertyGuid
                (
                    N'SFin',
                    N'Transactions',
                    N'CreditTermsId'
                );

        IF @EntityPropertyGuid IS NOT NULL
        BEGIN
            INSERT @ValidationResult
            (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                Message
            )
            VALUES
            (
                @EntityPropertyGuid,
                N'P',
                0,
                1,
                0,
                N''
            );
        END;
    END;

    -- Account must have a Sage account code before use on transactions.
    IF EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts AS a
        WHERE a.Guid = @AccountGuid
          AND a.Code = N''
          AND a.RowStatus NOT IN (0, 254)
    )
    BEGIN
        SELECT
            @EntityPropertyGuid = ep.Guid
        FROM SCore.EntityPropertiesV AS ep
        INNER JOIN SCore.EntityHobtsV AS eh
            ON eh.ID = ep.EntityHoBTID
        WHERE eh.SchemaName = N'SFin'
          AND eh.ObjectName = N'Transactions'
          AND ep.Name = N'AccountID';

        IF @EntityPropertyGuid IS NOT NULL
        BEGIN
            INSERT @ValidationResult
            (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                Message
            )
            VALUES
            (
                @EntityPropertyGuid,
                N'P',
                0,
                0,
                1,
                N'An account must have a Sage Account Code before it can be used on transactions.'
            );
        END;
    END;

	--Archived transaction: read-only
	IF(EXISTS
		(
			SELECT 1 
			FROM SFin.Transactions
			WHERE 
					RowStatus IN (200)
				AND Guid = @Guid
		)
	 )
	BEGIN
         INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        VALUES
        (
            @TransactionsHoBTGuid,
            N'H',
            1,
            0,
            0,
            N''
        );
    END;

    RETURN;
END;
GO

GO

/* Deploy Function SFin.tvf_AllTransactions using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_AllTransactions.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.tvf_AllTransactions
    Source schema hash : 368DD75ECDCCD4D2FE24788DF72EE544259C67995C6A871816B4F8391B452846
    Definition SHA-256 : 45AC038645B4A87BD4DD1643A84AC49F6E230F82819F979208D609B3020D1E45

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    CYB-445 / CYB-495 / CYB-530 - Sage and payment status corrections for All Transactions.

    Authoritative evidence used:
      1. A receipt materialised by the Sage inbound process.
      2. Successful automated Sage submission.
      3. Active membership of a legacy Sage Export.
      4. A non-empty SageTransactionReference entered for a transaction
         created manually in Sage.

    Behaviour preserved:
      - Inbound receipts display as Received from Sage, never Legacy.
      - Automated Succeeded remains Succeeded.
      - Active historical Sage Export membership remains Legacy.
      - A Sage reference on a transaction that is not an inbound receipt,
        automated success or legacy export displays as Manual.
      - Existing automated non-success statuses remain unchanged where there
        is no manual-export evidence and no Sage reference.
      - Transactions with no automated status and no Sage evidence remain
        Not Sent.
      - JobNumber, JobDescription and Products remain part of the function contract.
      - Paid invoices are not overdue when Outstanding is zero.

    This deliberately does not infer Sage status from allocation alone.
*/

CREATE OR ALTER FUNCTION [SFin].[tvf_AllTransactions]
(
    @UserId INT
)
RETURNS TABLE
AS
RETURN
(
SELECT
      t.ID
    , t.RowStatus
    , t.RowVersion
    , t.Guid
    , t.Number
    , t.Date
    , a.Name AS Account
    , tt.Name AS TransactionType
    , tc.Net
    , tc.Vat
    , tc.Gross
    , tc.Outstanding
    , t.SageTransactionReference
    , t.SageInvoiceNumber
    , t.PurchaseOrderNumber
    , i.FullName AS Surveyor
    , t.Batched
    , CASE
          WHEN t.TransactionTypeID = 1
           AND tc.Outstanding > 0
           AND DueDetails.DueDate <= GETUTCDATE()
              THEN N'Overdue'
          ELSE N''
      END AS IsOverdue
    , CASE
          WHEN SageInbound.IsSageInbound = 1
              THEN N'Received from Sage'
          WHEN s.StatusCode = N'Succeeded'
              THEN N'Succeeded'
          WHEN legacy.HasActiveManualSageExport = 1
              THEN N'Legacy'
          WHEN NULLIF
               (
                   LTRIM
                   (
                       RTRIM
                       (
                           ISNULL(t.SageTransactionReference, N'')
                       )
                   ),
                   N''
               ) IS NOT NULL
              THEN N'Manual'
          WHEN s.StatusCode IS NULL
              THEN N'Not Sent'
          ELSE s.StatusCode
      END AS SageStatusCode
    , CASE
          WHEN NULLIF
               (
                   LTRIM
                   (
                       RTRIM
                       (
                           ISNULL(t.SageTransactionReference, N'')
                       )
                   ),
                   N''
               ) IS NOT NULL
              THEN 1
          ELSE 0
      END AS HasSageReference
    , OrgUnit.Name AS Department
    , OrgUnit2.Name AS OrgUnit
	,j.Number AS JobNumber,
	j.JobDescription,
	Prods.Products
FROM SFin.Transactions AS t
INNER JOIN SFin.TransactionCalculations AS tc
    ON tc.ID = t.ID
INNER JOIN SFin.TransactionTypes AS tt
    ON tt.ID = t.TransactionTypeID
   AND tt.RowStatus NOT IN (0, 254)
INNER JOIN SCrm.Accounts AS a
    ON a.ID = t.AccountID
   AND a.RowStatus NOT IN (0, 254)
INNER JOIN SCore.Identities AS i
    ON i.ID = t.SurveyorUserId
   AND i.RowStatus NOT IN (0, 254)
INNER JOIN SJob.Jobs AS j
    ON j.ID = t.JobID
   AND j.RowStatus NOT IN (0, 254)
INNER JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
   AND OrgUnit.RowStatus NOT IN (0, 254)
INNER JOIN SCore.OrganisationalUnits AS OrgUnit2
    ON OrgUnit.ParentID = OrgUnit2.ID
   AND OrgUnit2.RowStatus NOT IN (0, 254)
LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
    ON s.TransactionGuid = t.Guid
   AND s.RowStatus <> 0
   AND s.RowStatus <> 254
OUTER APPLY
(
    SELECT TOP (1)
        CONVERT(BIT, 1) AS IsSageInbound
    FROM SFin.SageExternalTransactions AS sageInbound
    WHERE sageInbound.MaterialisedReceiptTransactionGuid = t.Guid
      AND sageInbound.RowStatus NOT IN (0, 254)
    ORDER BY sageInbound.ID DESC
) AS SageInbound
OUTER APPLY
(
    SELECT TOP (1)
        CONVERT(BIT, 1) AS HasActiveManualSageExport
    FROM SFin.SageExportTransactions AS setr
    INNER JOIN SFin.SageExports AS se
        ON se.ID = setr.SageExportID
       AND se.RowStatus <> 0
       AND se.RowStatus <> 254
    WHERE setr.TransactionID = t.ID
      AND setr.RowStatus <> 0
      AND setr.RowStatus <> 254
    ORDER BY setr.ID DESC
) AS legacy
OUTER APPLY
	(
		SELECT STRING_AGG(d.Code, ',') AS Products
		FROM
		(
			SELECT DISTINCT p.Code
			FROM SSop.QuoteItems qi
			JOIN SJob.Jobs jobs
				ON jobs.ID = qi.CreatedJobId
				AND jobs.RowStatus NOT IN (0, 254)
			LEFT JOIN SProd.Products p
				ON p.ID = qi.ProductId
				AND p.RowStatus NOT IN (0, 254)
			WHERE qi.RowStatus NOT IN (0,254)
			  AND jobs.Guid = j.Guid
		) AS d
	) AS Prods
LEFT JOIN SFin.CreditTerms AS ct
    ON ct.ID = t.CreditTermsId AND ct.RowStatus NOT IN (0, 254)
OUTER APPLY (
    SELECT
        CASE WHEN CAST(SUM(ISNULL(td.Gross, 0)) AS DECIMAL(19,2)) <> 0
            THEN CAST(
                COALESCE(
                    CAST(t.ExpectedDate AS DATE),
                    DATEADD(DAY, ISNULL(ct.DueDays, 0), DATEADD(DAY, 30, CAST(t.Date AS DATETIME)))
                ) AS DATE)
            ELSE NULL
        END AS DueDate
    FROM SFin.TransactionDetails AS td
    WHERE td.TransactionID = t.ID
      AND td.RowStatus NOT IN (0, 254)
) AS DueDetails
WHERE t.RowStatus <> 0
  AND t.RowStatus NOT IN (200,254) --include archived
  AND t.ID > 0
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead
      (
          t.Guid,
          @UserId
      ) AS oscr
  )
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead
      (
          a.Guid,
          @UserId
      ) AS oscr
  )


UNION ALL


SELECT 
		root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.InvoiceNumber,
		root_hobt.InvoiceDate,
		a.Name AS Account,
		N'Subcontractor Invoice' AS TransactionType,
		root_hobt.ValueWithoutVAT AS Net,
		root_hobt.ValueWithVAT AS Vat,
		root_hobt.ValueWithVAT AS Gross,
		0 AS Outstanding,
		N'' AS SageTransactionReference,
		N'' AS SageInvoiceNumber,
		N'' AS PurchaseOrderNumber,
		Surveyor.FullName AS Surveyor,
		0 AS Batched,
		N'' AS IsOverdue,
		N'' AS SageStatusCode,
		N'' AS HasSageReference,
		OrgUnit.Name AS Department,
		OrgUnit2.Name AS OrgUnit,
		j.Number AS JobNumber,
		j.JobDescription AS JobDescription,
		Prods.Products
FROM SJob.SubContractorInvoices root_hobt
JOIN SJob.Jobs j
	ON root_hobt.JobId = j.ID
	AND j.RowStatus NOT IN (0, 254)
JOIN SCore.Identities Surveyor
	ON j.SurveyorID = Surveyor.ID
	AND Surveyor.RowStatus NOT IN (0, 254)
JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
	AND OrgUnit.RowStatus NOT IN (0, 254)
JOIN SCore.OrganisationalUnits AS OrgUnit2
		ON OrgUnit.ParentID = OrgUnit2.ID
		AND OrgUnit2.RowStatus NOT IN (0, 254)
JOIN SCrm.Accounts AS a
	ON a.ID = root_hobt.SubContractorId
	AND a.RowStatus NOT IN (0, 254)
OUTER APPLY
	(
		SELECT STRING_AGG(d.Code, ',') AS Products
		FROM
		(
			SELECT DISTINCT p.Code
			FROM SSop.QuoteItems qi
			JOIN SJob.Jobs jobs ON jobs.ID = qi.CreatedJobId AND jobs.RowStatus NOT IN (0, 254)
			LEFT JOIN SProd.Products p ON p.ID = qi.ProductId AND p.RowStatus NOT IN (0, 254)
			WHERE qi.RowStatus NOT IN (0,254) AND jobs.Guid = j.Guid
		) AS d
	) AS Prods
WHERE 
		(root_hobt.RowStatus NOT IN (0,254))
		AND (root_hobt.ID > 0)
		AND (root_hobt.InvoiceDate IS NOT NULL)
)
GO

GO

/* Deploy Function SFin.tvf_InvoiceRequests using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_InvoiceRequests.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.tvf_InvoiceRequests
    Source schema hash : 66FA613270C686D4F599E4F48ADE7B9BD184BCBCD6F4499FB2E6276E56543EA2
    Definition SHA-256 : 944D7CC6AB8FF1A7BCADE5E097E8AAF75618F2EE69E48614B7BD99B39B35E225

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SFin].[tvf_InvoiceRequests]
(
    @UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN
SELECT
    ir.ID,
    ir.RowStatus,
    ir.RowVersion,
    ir.Guid,
    ir.Notes,
    ir.CreatedDateTimeUTC,
    ir.InvoicingType,
    ir.ExpectedDate,
    ir.ManualStatus,
    i.Guid AS RequesterUserId,
    i.FullName AS SurveyorName,
    j.Guid AS JobId,
    j.Number,
    j.FinanceAccountID,
    FinAcc.Name AS FinanceAccountName,
    FinAcc.Code AS FinanceAccountCode,
    STRING_AGG(ActT.Name, ', ') AS ActivityID,
    Acc.Name AS ClientName,
    SUM(IRI.Net) AS Net,
    MAX(Act.EndDate) AS EndDate,
    j.BillingInstruction AS JobBillingInstruction,
    FinAcc.BillingInstruction AS CRMBillingInstruction,
    CASE
        WHEN MAX
        (
            CASE
                WHEN ActT.IsBillable = 0 THEN 'No'
                ELSE 'Yes'
            END
        ) = 'Yes' THEN 'Yes'
        ELSE 'No'
    END AS IsBillable,
    OrgUnit.Name AS OrgUnit,
    CAST
    (
        CASE
            WHEN j.FinanceAccountID IS NULL OR j.FinanceAccountID <= 0 THEN 1
            WHEN NULLIF(LTRIM(RTRIM(FinAcc.Code)), N'') IS NULL THEN 1
            ELSE 0
        END
        AS bit
    ) AS HasFinanceAccountIssue,
    CASE
        WHEN j.FinanceAccountID IS NULL OR j.FinanceAccountID <= 0
            THEN N'No finance account selected.'
        WHEN NULLIF(LTRIM(RTRIM(FinAcc.Code)), N'') IS NULL
            THEN N'Finance account does not have a valid Sage Code.'
        ELSE N''
    END AS FinanceAccountIssueMessage,
    CAST
    (
        CASE
            WHEN SUM(IRI.Net) <= 0 THEN 1
            ELSE 0
        END
        AS bit
    ) AS HasBatchingIssue,
    CASE
        WHEN SUM(IRI.Net) <= 0
            THEN N'Invoice request value is zero or negative and cannot be converted into a transaction.'
        ELSE N''
    END AS BatchingIssueMessage,
	OrgUnit.Name AS Department,
	OrgUnit2.Name AS BusinessUnit
FROM SFin.InvoiceRequests AS ir
JOIN SJob.Jobs AS j
    ON j.ID = ir.JobId
JOIN SCore.Identities AS i
    ON i.ID = ir.RequesterUserId
JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
JOIN SCore.OrganisationalUnits AS OrgUnit2
	ON OrgUnit.ParentID = OrgUnit2.ID
INNER JOIN SFin.InvoiceRequestItems AS IRI
    ON IRI.InvoiceRequestId = ir.ID
INNER JOIN SJob.Activities AS Act
    ON IRI.ActivityId = Act.ID
INNER JOIN SJob.ActivityTypes AS ActT
    ON Act.ActivityTypeID = ActT.ID
INNER JOIN SCrm.Accounts AS Acc
    ON Acc.ID = j.ClientAccountID
LEFT JOIN SCrm.Accounts AS FinAcc
    ON FinAcc.ID = j.FinanceAccountID
WHERE
    ir.RowStatus NOT IN (0, 254)
    AND ir.ID > 0
    AND j.CannotBeInvoiced <> 1
    AND ir.IsMerged = 0
    AND EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequestItems AS iri
        WHERE iri.RowStatus NOT IN (0, 254)
          AND iri.InvoiceRequestId = ir.ID
    )
    AND
    (
        EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            INNER JOIN SJob.Activities AS act
                ON iri.ActivityId = act.ID
            WHERE (act.ActivityStatusID = 3 OR act.ID < 0)
              AND iri.InvoiceRequestId = ir.ID
              AND iri.RowStatus NOT IN (0, 254)
              AND act.RowStatus NOT IN (0, 254)
        )
        OR IRI.ActivityId < 0
    )
    AND
    (
        EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            INNER JOIN SJob.Activities AS Act
                ON iri.ActivityId = Act.ID
            WHERE iri.RowStatus NOT IN (0, 254)
              AND Act.RowStatus NOT IN (0, 254)
              AND CAST(Act.EndDate AS date) <= CAST(GETDATE() AS date)
              AND iri.InvoiceRequestId = ir.ID
        )
        OR IRI.ActivityId < 0
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) AS oscr
    )
   AND NOT EXISTS
    (
        SELECT 1
        FROM SFin.TransactionDetails AS td
        INNER JOIN SFin.InvoiceRequestItems AS iri
            ON iri.ID = td.InvoiceRequestItemId
        INNER JOIN SFin.Transactions AS tr
            ON tr.ID = td.TransactionID
        WHERE iri.InvoiceRequestId = ir.ID
          AND td.RowStatus NOT IN (0, 254)
          AND iri.RowStatus NOT IN (0, 254)
          AND tr.RowStatus NOT IN (0, 254, 200)
    )
GROUP BY
    ir.ID,
    ir.RowStatus,
    ir.RowVersion,
    ir.Guid,
    ir.Notes,
    ir.CreatedDateTimeUTC,
    ir.InvoicingType,
    ir.ExpectedDate,
    ir.ManualStatus,
    i.Guid,
    i.FullName,
    j.Guid,
    j.Number,
    j.FinanceAccountID,
    FinAcc.Name,
    FinAcc.Code,
    Acc.Name,
    j.BillingInstruction,
    FinAcc.BillingInstruction,
    OrgUnit.Name,
	OrgUnit2.Name
GO

GO

/* Deploy Function SFin.tvf_InvoiceRequests_DataPills using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_InvoiceRequests_DataPills.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.tvf_InvoiceRequests_DataPills
    Source schema hash : D83592ECED10B0308ABDDF05A99210B388A021B72CA64A2D6BE7DFD693FF9045
    Definition SHA-256 : 9E427FBE9A10C6AE70BBB82FC19BFBCB4F556251823B5EA9DC225734F6BFD523

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SFin].[tvf_InvoiceRequests_DataPills]
(
    @Guid               UNIQUEIDENTIFIER, -- InvoiceRequest Guid
    @FinanceAccountGuid UNIQUEIDENTIFIER
)
RETURNS @DataPills TABLE
(
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(50) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
)
AS
BEGIN
    -------------------------------------------------------------------------
    -- 1) Finance Account On Credit Hold
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts Ac
        WHERE Ac.Guid = @FinanceAccountGuid
          AND Ac.AccountStatusID = 4
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Credit Hold', N'bg-danger', 1);
    END

    -------------------------------------------------------------------------
    -- 2) InvoiceRequest-level pills (based on the current InvoiceRequest row)
    -------------------------------------------------------------------------

    -- Blocked when BlockedReason <> ''
    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests ir
        WHERE ir.Guid = @Guid
          AND ir.RowStatus NOT IN (0, 254)
          AND NULLIF(LTRIM(RTRIM(ir.BlockedReason)), N'') IS NOT NULL
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Blocked', N'bg-warning', 2);
    END

    -- Reconciliation when ReconciliationRequired = 1
    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests ir
        WHERE ir.Guid = @Guid
          AND ir.RowStatus NOT IN (0, 254)
          AND ir.ReconciliationRequired = 1
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Reconciliation', N'bg-info', 3);
    END

    -- Automated when IsAutomated = 1
    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests ir
        WHERE ir.Guid = @Guid
          AND ir.RowStatus NOT IN (0, 254)
          AND ir.IsAutomated = 1
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Automated', N'bg-primary', 4);
    END

	--Rejected Datapill
	IF(EXISTS(
		SELECT 1 
		FROM SFin.InvoiceRequests 
		WHERE 
				(Guid = @Guid) 
			AND (IsRejected = 1)
			)
		)
	BEGIN
		 INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Rejected', N'bg-danger', 5);
	END;

    RETURN;
END;
GO

GO

/* Deploy Function SFin.tvf_QuoteInvoiceSchedules using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_QuoteInvoiceSchedules.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_QuoteInvoiceSchedules]')
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_QuoteInvoiceSchedules]
(
      @UserId INT
    , @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
SELECT
      invs.ID
    , invs.RowStatus
    , invs.RowVersion
    , invs.Guid
    , invs.Name
    , invs.DescriptionOfWork
    , CAST
      (
          CASE
              WHEN monthly_totals.MonthlyRowCount > 0
                  THEN monthly_totals.MonthlyTotalAmount

              WHEN percentage_totals.PercentageRowCount > 0
                  THEN
                      (
                          COALESCE
                          (
                              NULLIF(quote_item_totals.QuoteItemTotalAmount, 0.00),
                              invs.Amount,
                              0.00
                          )
                          * percentage_totals.PercentageTotalPercentage
                      ) / 100.00

              ELSE ISNULL(invs.Amount, 0.00)
          END
          AS DECIMAL(19, 2)
      ) AS Amount
    , CASE
		WHEN  ist.Name = N'Monthly Drawdowns' AND invs.Frequency IS NOT NULL
			THEN CONCAT(N'Monthly Drawdowns (', invs.Frequency, N')')
		ELSE ist.Name END AS TriggerId
    , invs.ExpectedDate
FROM SFin.InvoiceSchedules AS invs
JOIN SSop.Quotes AS q
    ON q.ID = invs.QuoteId
   AND q.RowStatus NOT IN (0, 254)
JOIN SFin.InvoiceScheduleTrigger AS ist
    ON ist.ID = invs.TriggerId
   AND ist.RowStatus NOT IN (0, 254)
OUTER APPLY
(
    SELECT
          COUNT_BIG(1) AS MonthlyRowCount
        , CAST(ISNULL(SUM(month_config.Amount), 0.00) AS DECIMAL(19, 2)) AS MonthlyTotalAmount
    FROM SFin.InvoiceScheduleMonthConfiguration AS month_config
    WHERE month_config.RowStatus NOT IN (0, 254)
      AND month_config.InvoiceScheduleId = invs.ID
) AS monthly_totals
OUTER APPLY
(
    SELECT
          COUNT_BIG(1) AS PercentageRowCount
        , CAST(ISNULL(SUM(percentage_config.Percentage), 0.00) AS DECIMAL(19, 2)) AS PercentageTotalPercentage
    FROM SFin.InvoiceSchedulePercentageConfiguration AS percentage_config
    WHERE percentage_config.RowStatus NOT IN (0, 254)
      AND percentage_config.InvoiceScheduleId = invs.ID
) AS percentage_totals
OUTER APPLY
(
    SELECT
        CAST(ISNULL(SUM(qit.LineNet), 0.00) AS DECIMAL(19, 2)) AS QuoteItemTotalAmount
    FROM SSop.QuoteItems AS qi
    JOIN SSop.QuoteItemTotals AS qit
        ON qit.ID = qi.ID
    WHERE qi.RowStatus NOT IN (0, 254)
      AND qi.InvoicingSchedule = invs.ID
) AS quote_item_totals
WHERE q.Guid = @ParentGuid
  AND invs.RowStatus NOT IN (0, 254)
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead(invs.Guid, @UserId) AS oscr
  );
GO
GO

/* Deploy Function SFin.tvf_SageInboundDiagnostics using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_SageInboundDiagnostics.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.tvf_SageInboundDiagnostics
    Source schema hash : BF95D6161C0B5966A2F0374B3C7CAE2D936E83EFCF3C15226901E4A93FA68A6C
    Definition SHA-256 : 9DAAB2AB6A44AC50EC2874BCC3CAC84506A94CAD863BEE023752FD60497EEFBF

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SFin].[tvf_SageInboundDiagnostics]
(
    @StatusCode NVARCHAR(30) = NULL,
    @SageAccountReference NVARCHAR(100) = NULL,
    @SageDocumentNo NVARCHAR(100) = NULL,
    @OnlyRetryableFailures BIT = NULL,
    @InvoiceRequestID INT = NULL,
    @TransactionID BIGINT = NULL,
    @JobID INT = NULL,
    @TransactionNumber NVARCHAR(50) = NULL
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    WITH LatestAttempt AS
    (
        SELECT
            a.InboundStatusID,
            a.AttemptedOnUtc,
            a.CompletedOnUtc,
            a.IsSuccess,
            a.ErrorMessage,
            a.IsRetryableFailure,
            a.ResponseStatus,
            a.ResponseDetail,
            ROW_NUMBER() OVER
            (
                PARTITION BY a.InboundStatusID
                ORDER BY a.AttemptedOnUtc DESC, a.ID DESC
            ) AS RN
        FROM SFin.SageInboundDocumentAttempts AS a
        WHERE a.RowStatus NOT IN (0, 254)
    )
    SELECT
        s.ID,
        s.Guid,
        s.CymBuildEntityTypeID,
        s.CymBuildDocumentGuid,
        s.CymBuildDocumentID,
        s.InvoiceRequestID,
        s.TransactionID,
        --s.JobID,
        ISNULL(j.Number, N'') AS JobID,
        ISNULL(j.Number, N'') AS JobNumber,
        s.SageDataset,
        s.SageAccountReference,
        s.SageDocumentNo,
        s.LastOperationName,
        s.StatusCode,
        s.IsInProgress,
        s.InProgressClaimedOnUtc,
        s.LastSucceededOnUtc,
        s.LastFailedOnUtc,
        s.LastError,
        s.LastErrorIsRetryable,
        s.LastSourceWatermarkUtc,
        s.LastGrossAmount,
        s.LastAllocatedValue,
        s.LastOutstandingAmount,
        s.LastDocumentDiscountedValue,
        s.LastIsPaid,
        s.LastIsFullyPaid,
        s.LastPaymentStateCode,
        s.LastTransactionDate,
        s.LastSageTransactionReference,
        s.LastSecondReference,
        s.LastSageTransactionTypeCode,
        s.NextPollDueOnUtc,
        s.PollAttemptCount,
        s.IsTerminalState,
        s.CreatedByUserID,
        s.CreatedDateTimeUTC,
        s.UpdatedByUserID,
        s.UpdatedDateTimeUTC,

        la.AttemptedOnUtc AS LastAttemptedOnUtc,
        la.CompletedOnUtc AS LastCompletedOnUtc,
        la.IsSuccess AS LastAttemptIsSuccess,
        la.ErrorMessage AS LastAttemptErrorMessage,
        la.IsRetryableFailure AS LastAttemptIsRetryableFailure,
        la.ResponseStatus AS LastAttemptResponseStatus,
        la.ResponseDetail AS LastAttemptResponseDetail,

        CAST
        (
            CASE
                WHEN s.IsTerminalState = 1 THEN 0
                WHEN s.StatusCode = N'Failed' THEN 0
                WHEN s.StatusCode = N'RetryPending' THEN 1
                WHEN s.StatusCode = N'Pending' THEN 1
                WHEN s.StatusCode = N'PartiallyPaid' THEN 1
                WHEN s.StatusCode = N'InProgress' THEN 0
                WHEN s.StatusCode = N'Succeeded' THEN 0
                ELSE 0
            END
            AS BIT
        ) AS CanRequeue,

        CAST(1 AS BIT) AS CanForceRequeue,

        srcTran.Guid AS TransactionGuid,
        ISNULL(srcTran.Number, N'') AS TransactionNumber,
        srcTran.SageTransactionReference AS TransactionSageTransactionReference,
        CAST(ISNULL(srcTran.Batched, 0) AS BIT) AS TransactionIsBatched,

        matchedTran.Guid AS MatchedTransactionGuid,
        ISNULL(matchedTran.Number, N'') AS MatchedTransactionNumber,
        matchedTran.SageTransactionReference AS MatchedTransactionSageTransactionReference,

        receiptTran.Guid AS MaterialisedReceiptTransactionGuid,
        ISNULL(receiptTran.Number, N'') AS MaterialisedReceiptTransactionNumber,

        alloc.Guid AS MaterialisedAllocationGuid,
        alloc.ID AS MaterialisedAllocationID,

        ext.ID AS LastMatchedExternalTransactionID,
        ext.SageTransactionTypeCode AS LastMatchedExternalTransactionTypeCode,
        ext.AllocatedValue AS LastMatchedExternalTransactionAllocatedValue
    FROM SFin.SageInboundDocumentStatus AS s
    LEFT JOIN LatestAttempt AS la
        ON la.InboundStatusID = s.ID
       AND la.RN = 1
    LEFT JOIN SJob.Jobs AS j
        ON j.ID = s.JobID
       AND j.RowStatus NOT IN (0, 254)
    OUTER APPLY
    (
        SELECT TOP (1)
            ext.ID,
            ext.Guid,
            ext.SageTransactionTypeCode,
            ext.AllocatedValue,
            ext.MatchedTransactionID,
            ext.MatchedInvoiceRequestID,
            ext.MatchedJobID,
            ext.MaterialisedReceiptTransactionID,
            ext.MaterialisedReceiptTransactionGuid,
            ext.MaterialisedAllocationID,
            ext.MaterialisedAllocationGuid
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.RowStatus NOT IN (0, 254)
          AND
          (
                (
                    ext.SageDataset = s.SageDataset
                AND ext.SageAccountReference = s.SageAccountReference
                AND ext.SageDocumentNo = s.SageDocumentNo
                )
             OR
                (
                    ext.MatchedTransactionID = s.TransactionID
                AND s.TransactionID > 0
                )
             OR
                (
                    ext.MatchedInvoiceRequestID = s.InvoiceRequestID
                AND s.InvoiceRequestID > 0
                )
          )
        ORDER BY
            CASE
                WHEN ext.MatchedTransactionID = s.TransactionID
                     AND s.TransactionID > 0 THEN 0
                WHEN ext.MatchedInvoiceRequestID = s.InvoiceRequestID
                     AND s.InvoiceRequestID > 0 THEN 1
                WHEN ext.SageDataset = s.SageDataset
                 AND ext.SageAccountReference = s.SageAccountReference
                 AND ext.SageDocumentNo = s.SageDocumentNo THEN 2
                ELSE 9
            END,
            -- An Invoice (4) row and its Credit Note/Receipt (5/6) row can both match
            -- the same tier above. Prefer the 5/6 row when one exists so
            -- MaterialisedReceipt* reflects the receipt's own state rather than the
            -- invoice's; the invoice row remains the fallback "Fix Receipt" candidate
            -- when Sage never sent a separate Receipt/Credit Note transaction.
            CASE WHEN ext.SageTransactionTypeCode IN (5, 6) THEN 0 ELSE 1 END,
            ext.LastSeenOnUtc DESC,
            ext.ID DESC
    ) AS ext
    LEFT JOIN SFin.Transactions AS srcTran
        ON srcTran.ID = s.TransactionID
       AND srcTran.RowStatus NOT IN (0, 254)
    LEFT JOIN SFin.Transactions AS matchedTran
        ON matchedTran.ID = ext.MatchedTransactionID
       AND matchedTran.RowStatus NOT IN (0, 254)
    LEFT JOIN SFin.Transactions AS receiptTran
        ON receiptTran.ID = ext.MaterialisedReceiptTransactionID
       AND receiptTran.RowStatus NOT IN (0, 254)
    LEFT JOIN SFin.TransactionAllocations AS alloc
        ON alloc.ID = ext.MaterialisedAllocationID
       AND alloc.RowStatus NOT IN (0, 254)
    WHERE s.RowStatus NOT IN (0, 254)
      AND (@StatusCode IS NULL OR @StatusCode = N'' OR s.StatusCode = @StatusCode)
      AND (@SageAccountReference IS NULL OR @SageAccountReference = N'' OR s.SageAccountReference LIKE N'%' + @SageAccountReference + N'%')
      AND (@SageDocumentNo IS NULL OR @SageDocumentNo = N'' OR s.SageDocumentNo LIKE N'%' + @SageDocumentNo + N'%')
      AND (@OnlyRetryableFailures IS NULL OR ISNULL(s.LastErrorIsRetryable, 0) = @OnlyRetryableFailures)
      AND (@InvoiceRequestID IS NULL OR s.InvoiceRequestID = @InvoiceRequestID)
      AND (@TransactionID IS NULL OR s.TransactionID = @TransactionID)
      AND (@JobID IS NULL OR s.JobID = @JobID)
      AND
      (
            @TransactionNumber IS NULL
         OR @TransactionNumber = N''
         OR ISNULL(srcTran.Number, N'') LIKE N'%' + @TransactionNumber + N'%'
         OR ISNULL(matchedTran.Number, N'') LIKE N'%' + @TransactionNumber + N'%'
         OR ISNULL(receiptTran.Number, N'') LIKE N'%' + @TransactionNumber + N'%'
      )
);
GO

GO

/* Deploy Function SFin.tvf_Transactions_DataPills using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_Transactions_DataPills.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SFin.tvf_Transactions_DataPills
    Source schema hash : 2164C583E792F53EA7E70CA014856ADC944726182649CB63E9398B1890F9CF83
    Definition SHA-256 : 8D7CD020FA9CA9C66A9E0D5E443041877BFFCEE9F5D84E0589DAA7A516B92808

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SFin].[tvf_Transactions_DataPills]
(
    @Guid           UNIQUEIDENTIFIER,
    @Batched		BIT			
)
RETURNS @DataPills TABLE
(
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(MAX) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
)
        --WITH SCHEMABINDING
AS
BEGIN

	IF(@Batched = 1)
		BEGIN
			INSERT @DataPills (Label, Class, SortOrder)
				VALUES (N'Batched', N'bg-danger', 1);
		END;

	IF(EXISTS
		(
			SELECT 1 
			FROM SFin.Transactions
			WHERE 
					(Guid = @Guid)
				AND (RowStatus IN (200))
		)
	)
	BEGIN 
		INSERT @DataPills (Label, Class, SortOrder)
				VALUES (N'Rejected - Read-only', N'bg-danger', 1);
	END;
    RETURN;
END;
GO

GO

/* Deploy Function SJob.tvf_AssetsCheckForDuplicate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SJob.tvf_AssetsCheckForDuplicate.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SJob.tvf_AssetsCheckForDuplicate
    Source schema hash : B3F2FBC06BADA0CFB63FCDEF4D418A95A8829B3AF9357CFB920EE37B20CC5880
    Definition SHA-256 : 070073C0231C3F68B212B7D34255E821A0945C4F45ACE14E1A751C32BE85DAD5

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SJob].[tvf_AssetsCheckForDuplicate] 
(
   @Name    NVARCHAR(100)   = NULL,
   @Number NVARCHAR(50) = NULL,
   @AddressLine1 NVARCHAR(100) = N'',
   @AddressLine2 NVARCHAR(100) = N'',
   @AddressLine3 NVARCHAR(100) = N'',
   @Town NVARCHAR(100) = N'',
   @CountyGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
   @Postcode NVARCHAR(100) = N''
)
RETURNS @Results TABLE
(
	Guid UNIQUEIDENTIFIER,
	FormattedAddress NVARCHAR(600),
	MatchScore INT
)
AS
BEGIN

	--Normalise values
	DECLARE @NormPostcode   NVARCHAR(50)  = REPLACE(UPPER(LTRIM(RTRIM(ISNULL(@Postcode, '')))), ' ', '');
    DECLARE @NormNumber     NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@Number, ''))));
    DECLARE @NormAddr1      NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@AddressLine1, ''))));
    DECLARE @NormAddr2      NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@AddressLine2, ''))));
    DECLARE @NormAddr3      NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@AddressLine3, ''))));
    DECLARE @NormTown       NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@Town, ''))));
	DECLARE @NormName       NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@Name, ''))));

INSERT INTO @Results
(
	Guid,
	FormattedAddress,
	MatchScore
)
SELECT
	scored.Guid,
	-- FORMAT => (Name) AssetNumber - FormattedAddressComma | Owner: ...
	CONCAT(
		CASE
			WHEN scored.MatchScore >= 50 THEN N'[HIGH MATCH] '
			WHEN scored.MatchScore >= 25 THEN N'[MEDIUM MATCH] '
			ELSE N'[LOW MATCH] '
		END,
		N'(', ISNULL(NULLIF(TRIM(scored.Name), N''), N'Unnamed'), N') ',
		scored.Number, N' ', scored.AddressLine1, N' ', scored.Town, scored.Postcode,
		N' | Owner: ', ISNULL(NULLIF(TRIM(scored.OwnerName), N''), N'N/A')
	) AS FormattedAddress,
	scored.MatchScore
FROM
(
	SELECT
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Number,
		root_hobt.AddressLine1,
		root_hobt.Town,
		root_hobt.Postcode,
		owner.Name AS OwnerName,
		(
			-- Exact Name match
			CASE WHEN @NormName <> ''
				 AND UPPER(LTRIM(RTRIM(root_hobt.Name))) = @NormName
				 THEN 40 ELSE 0 END

			-- Prefix Name match, independent of SOUNDEX. Catches "Uni" matching "University
			-- House" - SOUNDEX encodes phonetics from the *whole* remaining string, so a short
			-- prefix will rarely SOUNDEX-match a longer real name even when the name plainly
			-- starts with it (same root cause as the Accounts "AB"/"ABX" report, CYB-312 QA
			-- feedback). Kept as its own branch rather than nested inside the SOUNDEX condition.
			+ CASE WHEN @NormName <> ''
				   AND root_hobt.Name <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Name))) <> @NormName
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.Name))) LIKE @NormName + N'%'
						OR @NormName LIKE UPPER(LTRIM(RTRIM(root_hobt.Name))) + N'%'
					   )
				   THEN 25 ELSE 0 END

			-- SOUNDEX Name match (fuzzy, near-miss spellings of similar length only - e.g.
			-- "Cymbild" vs "Cymbuild"). Gated on similar length so unrelated names that happen to
			-- share a SOUNDEX code aren't flagged (CYB-312 QA feedback).
			+ CASE WHEN @NormName <> ''
				   AND root_hobt.Name <> ''
				   AND SOUNDEX(root_hobt.Name) = SOUNDEX(@Name)
				   AND UPPER(LTRIM(RTRIM(root_hobt.Name))) <> @NormName
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.Name))) - LEN(@NormName)) <= 3
				   THEN 15 ELSE 0 END

			+ CASE WHEN @NormPostcode <> ''
				   AND REPLACE(UPPER(LTRIM(RTRIM(root_hobt.Postcode))), ' ', '') = @NormPostcode
				   THEN 30 ELSE 0 END

			-- Exact Number (building number) match
			+ CASE WHEN @NormNumber <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Number))) = @NormNumber
				   THEN 20 ELSE 0 END

			-- Exact AddressLine1 match
			+ CASE WHEN @NormAddr1 <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) = @NormAddr1
				   THEN 25 ELSE 0 END

			-- Prefix AddressLine1 match, independent of SOUNDEX (same reasoning as Name above).
			+ CASE WHEN @NormAddr1 <> ''
				   AND root_hobt.AddressLine1 <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) <> @NormAddr1
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) LIKE @NormAddr1 + N'%'
						OR @NormAddr1 LIKE UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) + N'%'
					   )
				   THEN 20 ELSE 0 END

			-- SOUNDEX AddressLine1 match (fuzzy, only if not exact, similar length only)
			+ CASE WHEN @NormAddr1 <> ''
				   AND root_hobt.AddressLine1 <> ''
				   AND SOUNDEX(root_hobt.AddressLine1) = SOUNDEX(@AddressLine1)
				   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) <> @NormAddr1
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.AddressLine1))) - LEN(@NormAddr1)) <= 3
				   THEN 10 ELSE 0 END

			-- Exact AddressLine2 / AddressLine3 match. These were already used to widen the
			-- candidate set in WHERE but never actually scored, so a match on them alone was
			-- always silently discarded regardless of the WHERE clause - added here so they
			-- count for something (CYB-312 QA feedback: "the more fields, the more precise").
			+ CASE WHEN @NormAddr2 <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine2))) = @NormAddr2
				   THEN 10 ELSE 0 END

			+ CASE WHEN @NormAddr3 <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine3))) = @NormAddr3
				   THEN 10 ELSE 0 END

			-- Exact Town match
			+ CASE WHEN @NormTown <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Town))) = @NormTown
				   THEN 30 ELSE 0 END

			-- Prefix Town match, independent of SOUNDEX (same reasoning as Name above).
			+ CASE WHEN @NormTown <> ''
				   AND root_hobt.Town <> ''
				   AND UPPER(LTRIM(RTRIM(root_hobt.Town))) <> @NormTown
				   AND (
						   UPPER(LTRIM(RTRIM(root_hobt.Town))) LIKE @NormTown + N'%'
						OR @NormTown LIKE UPPER(LTRIM(RTRIM(root_hobt.Town))) + N'%'
					   )
				   THEN 20 ELSE 0 END

			-- SOUNDEX Town match (fuzzy, only if not exact, similar length only). Previously
			-- scored the same as an exact match (30) - reduced to be consistent with every other
			-- field's exact-beats-fuzzy weighting in this function.
			+ CASE WHEN @NormTown <> ''
				   AND root_hobt.Town <> ''
				   AND SOUNDEX(root_hobt.Town) = SOUNDEX(@Town)
				   AND UPPER(LTRIM(RTRIM(root_hobt.Town))) <> @NormTown
				   AND ABS(LEN(LTRIM(RTRIM(root_hobt.Town))) - LEN(@NormTown)) <= 3
				   THEN 15 ELSE 0 END

			-- County match: only ever a corroborating bonus alongside a genuine field match above
			-- (a row only reaches scoring at all because something else already matched in
			-- WHERE) - a shared county on its own is nowhere near specific enough to suggest a
			-- duplicate, which is why it's no longer a standalone WHERE condition (see below).
			+ CASE WHEN @CountyGuid <> '00000000-0000-0000-0000-000000000000'
				   AND county.Guid = @CountyGuid
				   THEN 10 ELSE 0 END

		) AS MatchScore

	FROM SJob.Assets AS root_hobt
	LEFT JOIN SCrm.Counties AS county ON root_hobt.CountyId = county.ID
	LEFT JOIN SCrm.Accounts AS owner ON owner.ID = root_hobt.OwnerAccountId
	WHERE
			root_hobt.RowStatus NOT IN (0,254)
		AND (
				-- Each clause only contributes when its own parameter was actually supplied AND
				-- the row is a plausible match for it. Previously most of these were
				-- "@Param = '' OR field LIKE ..." / "@Param <> '' OR field LIKE ..." (OR instead
				-- of AND), which is true for every row the moment that parameter is empty/non-
				-- empty respectively, regardless of whether the row matches at all - between that
				-- and the County clause below (which was unconditionally true whenever no county
				-- was supplied), this WHERE clause was not actually filtering anything in the
				-- common case (CYB-312 QA feedback). Name was previously not in this WHERE clause
				-- at all, even though it's scored below - only the surrounding bugs being
				-- "always true" let a Name-only search reach scoring at all; added properly here
				-- so fixing the bugs above doesn't silently break Name-based duplicate detection.
				(@NormNumber <> '' AND root_hobt.Number LIKE N'%' + @Number + N'%')
			 OR (@NormAddr1 <> '' AND root_hobt.AddressLine1 <> '' AND (
						UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) LIKE @NormAddr1 + N'%'
					 OR @NormAddr1 LIKE UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) + N'%'
					 OR SOUNDEX(root_hobt.AddressLine1) = SOUNDEX(@AddressLine1)
				 ))
			 OR (@NormAddr2 <> '' AND root_hobt.AddressLine2 LIKE N'%' + @AddressLine2 + N'%')
			 OR (@NormAddr3 <> '' AND root_hobt.AddressLine3 LIKE N'%' + @AddressLine3 + N'%')
			 OR (@NormTown <> '' AND root_hobt.Town <> '' AND (
						UPPER(LTRIM(RTRIM(root_hobt.Town))) LIKE @NormTown + N'%'
					 OR @NormTown LIKE UPPER(LTRIM(RTRIM(root_hobt.Town))) + N'%'
					 OR SOUNDEX(root_hobt.Town) = SOUNDEX(@Town)
				 ))
			 OR (@NormPostcode <> '' AND REPLACE(UPPER(LTRIM(RTRIM(root_hobt.Postcode))), ' ', '') = @NormPostcode)
			 OR (@NormName <> '' AND root_hobt.Name <> '' AND (
						UPPER(LTRIM(RTRIM(root_hobt.Name))) LIKE @NormName + N'%'
					 OR @NormName LIKE UPPER(LTRIM(RTRIM(root_hobt.Name))) + N'%'
					 OR SOUNDEX(root_hobt.Name) = SOUNDEX(@Name)
				 ))
			)
) AS scored
ORDER BY scored.MatchScore DESC;


-- ===================== Unlinked Enquiries =====================
INSERT INTO @Results
(
	Guid,
	FormattedAddress,
	MatchScore
)
SELECT
	'00000000-0000-0000-0000-000000000000',
	-- Labelled "(Unlinked Enquiry)" and includes the Client so the user can tell at a glance
	-- that this candidate is a not-yet-converted Enquiry, not an existing Asset record - the
	-- Guid returned is the sentinel zero-Guid (there is no Asset record yet), so "Use
	-- Selected" cannot navigate to it the way it does for the other, real, candidates.
	CONCAT(N'(Unlinked Enquiry) ', CONCAT_WS(', ',
		NULLIF(scored.PropertyNameNumber, ''),
		NULLIF(scored.PropertyAddressLine1, ''),
		NULLIF(scored.PropertyTown, ''),
		NULLIF(scored.PropertyPostCode, '')
	), N' | Client: ', ISNULL(NULLIF(TRIM(scored.ClientDisplayName), N''), N'N/A')) AS FormattedAddress,
	scored.MatchScore
FROM
(
	SELECT
		e.PropertyNameNumber,
		e.PropertyAddressLine1,
		e.PropertyTown,
		e.PropertyPostCode,
		COALESCE(NULLIF(client.Name, N''), e.ClientName) AS ClientDisplayName,
		(
			-- === Weighted scoring (no UPRN/Geo available on enquiries) ===
			-- Exact postcode match
			CASE WHEN @NormPostcode <> ''
				 AND REPLACE(UPPER(LTRIM(RTRIM(e.PropertyPostCode))), ' ', '') = @NormPostcode
				 THEN 30 ELSE 0 END

			-- Exact PropertyNameNumber match (equivalent to Asset.Name)
			+ CASE WHEN @NormName <> ''
				   AND UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) = @NormName
				   THEN 40 ELSE 0 END

			-- Prefix PropertyNameNumber match, independent of SOUNDEX (see Assets branch above).
			+ CASE WHEN @NormName <> ''
				   AND e.PropertyNameNumber <> ''
				   AND UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) <> @NormName
				   AND (
						   UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) LIKE @NormName + N'%'
						OR @NormName LIKE UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) + N'%'
					   )
				   THEN 25 ELSE 0 END

			-- SOUNDEX PropertyNameNumber match (fuzzy, similar length only)
			+ CASE WHEN @NormName <> ''
				   AND e.PropertyNameNumber <> ''
				   AND SOUNDEX(e.PropertyNameNumber) = SOUNDEX(@Name)
				   AND UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) <> @NormName
				   AND ABS(LEN(LTRIM(RTRIM(e.PropertyNameNumber))) - LEN(@NormName)) <= 3
				   THEN 15 ELSE 0 END

			-- Exact AddressLine1 match
			+ CASE WHEN @NormAddr1 <> ''
				   AND UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) = @NormAddr1
				   THEN 25 ELSE 0 END

			-- Prefix AddressLine1 match, independent of SOUNDEX (see Assets branch above).
			+ CASE WHEN @NormAddr1 <> ''
				   AND e.PropertyAddressLine1 <> ''
				   AND UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) <> @NormAddr1
				   AND (
						   UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) LIKE @NormAddr1 + N'%'
						OR @NormAddr1 LIKE UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) + N'%'
					   )
				   THEN 20 ELSE 0 END

			-- SOUNDEX AddressLine1 match (fuzzy, similar length only)
			+ CASE WHEN @NormAddr1 <> ''
				   AND e.PropertyAddressLine1 <> ''
				   AND SOUNDEX(e.PropertyAddressLine1) = SOUNDEX(@AddressLine1)
				   AND UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) <> @NormAddr1
				   AND ABS(LEN(LTRIM(RTRIM(e.PropertyAddressLine1))) - LEN(@NormAddr1)) <= 3
				   THEN 10 ELSE 0 END

			-- Exact Town match
			+ CASE WHEN @NormTown <> ''
				   AND UPPER(LTRIM(RTRIM(e.PropertyTown))) = @NormTown
				   THEN 10 ELSE 0 END

			-- SOUNDEX Town match (fuzzy, similar length only)
			+ CASE WHEN @NormTown <> ''
				   AND e.PropertyTown <> ''
				   AND SOUNDEX(e.PropertyTown) = SOUNDEX(@Town)
				   AND UPPER(LTRIM(RTRIM(e.PropertyTown))) <> @NormTown
				   AND ABS(LEN(LTRIM(RTRIM(e.PropertyTown))) - LEN(@NormTown)) <= 3
				   THEN 5 ELSE 0 END

		) AS MatchScore

	FROM SSop.Enquiries AS e
	LEFT JOIN SCrm.Accounts AS client ON client.ID = e.ClientAccountId
	WHERE e.RowStatus NOT IN (0, 254)
	  -- Only enquiries that entered NEW structure/property details
	  AND (e.EnterNewStructureDetails = 1 OR e.PropertyId = -1)
	  -- Only enquiries where NO active EnquiryService has been linked to a Quote
	  AND NOT EXISTS (
		  SELECT 1
		  FROM SSop.EnquiryServices AS es
		  WHERE es.EnquiryId = e.ID
			AND es.RowStatus NOT IN (0, 254)
			AND es.QuoteId <> -1
	  )
	  -- Pre-filter: at least one meaningful criterion must match. Prefix conditions added
	  -- alongside the existing SOUNDEX ones for the same reason as the main Assets query - a
	  -- short prefix like "Uni" needs its own check, since it will rarely SOUNDEX-match a longer
	  -- real value.
	  AND (
			(@NormPostcode <> '' AND REPLACE(UPPER(LTRIM(RTRIM(e.PropertyPostCode))), ' ', '') = @NormPostcode)
		 OR (@NormName <> '' AND e.PropertyNameNumber <> '' AND (
				 UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) LIKE @NormName + N'%'
			  OR @NormName LIKE UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) + N'%'
			  OR SOUNDEX(e.PropertyNameNumber) = SOUNDEX(@Name)
			 ))
		 OR (@NormAddr1 <> '' AND e.PropertyAddressLine1 <> '' AND (
				 UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) LIKE @NormAddr1 + N'%'
			  OR @NormAddr1 LIKE UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) + N'%'
			  OR SOUNDEX(e.PropertyAddressLine1) = SOUNDEX(@AddressLine1)
			 ))
	  )
) AS scored
ORDER BY scored.MatchScore DESC;

DELETE FROM @Results WHERE MatchScore <= 20;

RETURN;

END;
GO

GO

/* Deploy Function SJob.tvf_JobTransactions using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SJob.tvf_JobTransactions.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : Function SJob.tvf_JobTransactions
    Source schema hash : 5AFFE503CC4B976912008343E38853F56DC3995D5E22B9E6730F1D2E7DEB653D
    Definition SHA-256 : B783D6692FAA12EF580B52CBEBCBADE79EEE3F33AEBB2440B0BFC9DC08D3B135

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION [SJob].[tvf_JobTransactions] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS
RETURN 
SELECT	t.ID,
		t.Guid,
		t.RowStatus,
		t.Number,
		t.Date,
		tc.RealNet,
		tc.RealVat,
		tc.RealGross,
		tc.RealOutstanding,
		(tc.RealVat + tc.RealOutstanding) AS RealOutstandingWithVAT,
		tt.Name AS Type,
		i.FullName AS Surveyor,
		t.SageTransactionReference,
		ac.Name AS FinanceAccount,
		CASE
    WHEN tc.RealOutstanding = 0 
        THEN 'Paid'

    WHEN tc.RealOutstanding > 0 
         AND DATEDIFF(
                DAY,
                COALESCE(
                    CAST(t.ExpectedDate AS date),
                    DATEADD(DAY, ISNULL(ct.DueDays,0), CAST(t.[Date] AS date))
                ),
                CAST(GETDATE() AS date)
            ) > 0
        THEN 'Overdue'
    ELSE 'Outstanding'
END AS TransactionStatus
FROM	SFin.Transactions t
JOIN	SFin.TransactionCalculations tc ON (tc.Id = t.ID)
JOIN	SFin.TransactionTypes tt ON (tt.ID = t.TransactionTypeID)
JOIN	SJob.Jobs j ON (j.Id = t.JobID)
JOIN	SCore.Identities i ON (i.ID = t.SurveyorUserId)
JOIN    SCrm.Accounts AS ac ON (ac.ID = t.AccountID)
LEFT JOIN SFin.CreditTerms ct ON ct.ID = t.CreditTermsId AND ct.RowStatus <> 254
WHERE	
		(j.Guid = @ParentGuid)
	AND (t.Batched <> 1)
	AND (t.RowStatus NOT IN (0,200,254)) --Use archived when rejecting a batched transaction.
GO

GO

/* Deploy StoredProcedure SFin.InvoiceRequestCreateInvoice using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.InvoiceRequestCreateInvoice.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.InvoiceRequestCreateInvoice
    Source schema hash : 10ADECC18A1196C10D204EDA11FED3095FCA66C653131223831B09771283B235
    Definition SHA-256 : 26308145C9ECBBF8D32995466F45DA486D4DAAC78042CB2D156B25DFADF97B4C

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[InvoiceRequestCreateInvoice]
	(
		@Guid UNIQUEIDENTIFIER
	)
AS
	BEGIN
		SET NOCOUNT ON 

		DECLARE	@AccountGuid UNIQUEIDENTIFIER, 
				@JobGuid UNIQUEIDENTIFIER,
				@TransactionTypeGuid UNIQUEIDENTIFIER,
				@Date DATE = GETUTCDATE(), 
				@PurchaseOrderNumber NVARCHAR(28),
				@OrganisationalUnitGuid UNIQUEIDENTIFIER,
				@CreatedByUserGuid UNIQUEIDENTIFIER,
				@SurveyorGuid UNIQUEIDENTIFIER,
				@CreditTermsGuid UNIQUEIDENTIFIER,
				@TransactionGuid UNIQUEIDENTIFIER = NEWID(),
				@InvoiceRequestId INT,
				@TransactionId INT,
				@Description NVARCHAR(MAX) = N'',
				@JobDescription NVARCHAR(MAX),
				@JobNumber NVARCHAR(30),
				@UprnFormattedAddressComma NVARCHAR(MAX),
				@JobType NVARCHAR(MAX),
				@IsRejected BIT;

		SELECT	@AccountGuid = fa.Guid,
				@InvoiceRequestId = ir.ID, 
				@JobGuid = j.Guid,
				@SurveyorGuid = r.Guid,
				@JobDescription = j.JobDescription,
				@JobNumber = j.Number,
				@JobType = jt.Name,
				@PurchaseOrderNumber = j.PurchaseOrderNumber,
				@OrganisationalUnitGuid = ou.Guid,
				@CreditTermsGuid = ct.Guid,
				@UprnFormattedAddressComma = uprn.FormattedAddressComma,
				@IsRejected = ir.IsRejected
		FROM	SFin.InvoiceRequests ir
		JOIN	SJob.Jobs j ON (j.ID = ir.JobId)
		JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
		JOIN	SJob.Assets uprn ON (uprn.ID = j.UprnID)
		JOIN	SCrm.Accounts fa ON (fa.ID = j.FinanceAccountID)
		JOIN	SCore.Identities r ON (r.ID = ir.RequesterUserId)
		JOIN	SCore.OrganisationalUnits ou ON (ou.Id = j.OrganisationalUnitID)
		JOIN	SFin.CreditTerms ct on (ct.ID = fa.DefaultCreditTermsId)
		WHERE ir.Guid = @Guid


		IF(@IsRejected = 1)
		BEGIN
			UPDATE SFin.InvoiceRequests
			SET IsRejected = 0
			WHERE Guid = @Guid
		END;


		IF (NOT EXISTS
		(
			SELECT	1
			FROM	SCrm.Accounts AS a 
			WHERE	(a.Guid = @AccountGuid)
				AND	(a.Code <> N'')
		)
			)
		BEGIN 
			;THROW 60000, N'The finance account on the job is invalid.', 1
		END

		SELECT	@CreatedByUserGuid = SCore.GetCurrentUserGuid()

		SELECT	@TransactionTypeGuid = tt.Guid 
		FROM	SFin.TransactionTypes tt
		WHERE	(tt.Name = N'Invoice')

		DECLARE @ExpectedDateOnInvoiceRequest DATE;

		SELECT @ExpectedDateOnInvoiceRequest = ir.ExpectedDate
		FROM SFin.InvoiceRequests AS ir
		WHERE ir.Guid = @Guid;


		-- Create the invoice header
		EXEC SFin.TransactionsUpsert @AccountGuid = @AccountGuid,				-- uniqueidentifier
									 @JobGuid = @JobGuid,					-- uniqueidentifier
									 @TransactionTypeGuid = @TransactionTypeGuid,		-- uniqueidentifier
									 @Date = @Date,				-- date
									 @PurchaseOrderNumber = @PurchaseOrderNumber,		-- nvarchar(28)
									 @SageTransactionReference = N'',	-- nvarchar(50)
									 @OrganisationalUnitGuid = @OrganisationalUnitGuid,	-- uniqueidentifier
									 @CreatedByUserGuid = @CreatedByUserGuid,			-- uniqueidentifier
									 @SurveyorGuid = @SurveyorGuid,				-- uniqueidentifier
									 @CreditTermsGuid = @CreditTermsGuid,			-- uniqueidentifier
									 @Guid = @TransactionGuid,						-- uniqueidentifier
									 @Batched = 1,									-- Set it to 1
									 @ExpectedDate = @ExpectedDateOnInvoiceRequest

		SELECT	@TransactionId = ID
		FROM	SFin.Transactions t
		WHERE	(Guid = @TransactionGuid)

		SET @Description = @Description + N'	
Our project ref.: ' + @JobNumber + N'
Project description: ' + @JobDescription + N'
Property: ' + @UprnFormattedAddressComma + N'
Appointed role: ' + @JobType

		DECLARE	@DetailList SCore.TwoGuidUniqueList,
				@NewDetailRecords SCore.GuidUniqueList

		INSERT	@DetailList
			 (GuidValue, GuidValueTwo)
		SELECT	iri.Guid,
				NEWID()
		FROM	SFin.InvoiceRequestItems iri
		WHERE	(iri.InvoiceRequestId = @InvoiceRequestId)
			AND	(iri.RowStatus NOT IN (0, 254))


		INSERT	@NewDetailRecords (GuidValue)
		SELECT	GuidValueTwo
		FROM	@DetailList

		DECLARE	@IsInsert BIT 

		EXEC SCore.DataObjectBulkUpsert 
			@GuidList = @NewDetailRecords,
			@SchemeName = N'SFin',
			@ObjectName = N'TransactionDetails',
			@IncludeDefaultSecurity = 0,
			@IsInsert = @IsInsert OUT 

		INSERT	SFin.TransactionDetails
			 (RowStatus,
			  Guid,
			  TransactionID,
			  MilestoneID,
			  ActivityID,
			  Net,
			  Vat,
			  Gross,
			  VatRate,
			  Description,
			  LegacyId,
			  JobPaymentStageId,
			  InvoiceRequestItemId,
			  RIBAStageId)
		SELECT	1,
				dl.GuidValueTwo,
				@TransactionId,
				iri.MilestoneId,
				iri.ActivityId,
				iri.Net,
				iri.Net * 0.2,
				iri.Net * 1.2,
				20,
				@Description, 
				NULL,
				-1,
				iri.Id,
				iri.RIBAStageId
		FROM	@DetailList dl
		JOIN	SFin.InvoiceRequestItems iri ON (iri.Guid = dl.GuidValue)
		

	END;
GO

GO

/* Deploy StoredProcedure SFin.InvoiceScheduleConfigurationTotalsGet using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.InvoiceScheduleConfigurationTotalsGet.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.InvoiceScheduleConfigurationTotalsGet
    Source schema hash : 96BC9D48E5EC80DF9C46F33AFD862BC196AFADF8823347AAD746C482E069DDAA
    Definition SHA-256 : E03EB4FD330AC1312B9536B36C95888B27F03DEB63D0942258B9F1CF2B116D4C

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[InvoiceScheduleConfigurationTotalsGet]
(
      @UserId     INT
    , @ParentGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @InvoiceScheduleId INT = NULL
        , @ScheduleAmount DECIMAL(18, 2) = 0.00
		, @Frequency NVARCHAR(20) = NULL;

    SELECT TOP (1)
          @InvoiceScheduleId = invsch.ID
        , @ScheduleAmount = ISNULL(invsch.Amount, 0.00)
		 , @Frequency = invsch.Frequency
    FROM SFin.InvoiceSchedules AS invsch
    WHERE invsch.RowStatus NOT IN (0, 254)
      AND invsch.Guid = @ParentGuid
    ORDER BY invsch.ID;

    IF @InvoiceScheduleId IS NULL
    BEGIN
        SELECT
              CAST(0.00 AS DECIMAL(18, 2)) AS MonthlyTotalAmount
            , CAST(0.00 AS DECIMAL(18, 2)) AS PercentageTotalPercentage
            , CAST(0.00 AS DECIMAL(18, 2)) AS PercentageTotalAmount
            , CAST(0.00 AS DECIMAL(18, 2)) AS ScheduleAmount
			, CAST(NULL AS NVARCHAR(20)) AS Frequency;
        RETURN;
    END;

    ;WITH MonthlyTotals AS
    (
        SELECT
            CAST(ISNULL(SUM(root_hobt.Amount), 0.00) AS DECIMAL(18, 2)) AS TotalAmount
        FROM SFin.InvoiceScheduleMonthConfiguration AS root_hobt
        WHERE root_hobt.RowStatus NOT IN (0, 254)
          AND root_hobt.InvoiceScheduleId = @InvoiceScheduleId
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(root_hobt.Guid, @UserId) AS oscr
          )
    ),
    PercentageTotals AS
    (
        SELECT
            CAST(ISNULL(SUM(root_hobt.Percentage), 0.00) AS DECIMAL(18, 2)) AS TotalPercentage
        FROM SFin.InvoiceSchedulePercentageConfiguration AS root_hobt
        WHERE root_hobt.RowStatus NOT IN (0, 254)
          AND root_hobt.InvoiceScheduleId = @InvoiceScheduleId
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(root_hobt.Guid, @UserId) AS oscr
          )
    )
    SELECT
          mt.TotalAmount AS MonthlyTotalAmount
        , pt.TotalPercentage AS PercentageTotalPercentage
        , CAST((@ScheduleAmount * pt.TotalPercentage) / 100.00 AS DECIMAL(18, 2)) AS PercentageTotalAmount
        , @ScheduleAmount AS ScheduleAmount
		, @Frequency AS Frequency
    FROM MonthlyTotals AS mt
    CROSS JOIN PercentageTotals AS pt;
END
GO

GO

/* Deploy StoredProcedure SFin.InvoiceScheduleMonthConfiguration_GenerateMonthlySeries using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.InvoiceScheduleMonthConfiguration_GenerateMonthlySeries.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.InvoiceScheduleMonthConfiguration_GenerateMonthlySeries
    Source schema hash : 71FD54C1FA413E608A89564E4554E0F547BC2FA13DACF3E0F396804169B2CB02
    Definition SHA-256 : C72984BB9BA81B7BE2302EEA894698D09753C215959199F84B74E5C23359614B

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[InvoiceScheduleMonthConfiguration_GenerateMonthlySeries]
(
      @InvoiceScheduleGuid   UNIQUEIDENTIFIER
    , @StartDate             DATE
    , @EndDate               DATE
    , @TotalValueNet         DECIMAL(19,2)
    , @Frequency             VARCHAR(20) = 'Monthly'
    , @OverwriteExisting     BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF (@InvoiceScheduleGuid IS NULL OR @InvoiceScheduleGuid = '00000000-0000-0000-0000-000000000000')
        THROW 60001, 'InvoiceScheduleGuid is required.', 1;

    IF (@StartDate IS NULL OR @EndDate IS NULL)
        THROW 60002, 'StartDate and EndDate are required.', 1;

    IF (@StartDate > @EndDate)
        THROW 60003, 'StartDate must be <= EndDate.', 1;

    IF (ISNULL(@TotalValueNet, 0) <= 0)
        THROW 60004, 'TotalValueNet must be > 0.', 1;

    -- Map Frequency -> step in months
    DECLARE @StepMonths INT =
        CASE @Frequency
            WHEN 'Monthly'     THEN 1
            WHEN 'Bi-monthly'  THEN 2
            WHEN 'Quarterly'   THEN 3
            WHEN 'Bi-annual'   THEN 6
            ELSE NULL
        END;

    IF (@StepMonths IS NULL)
        THROW 60008, 'Frequency must be one of: Monthly, Bi-monthly, Quarterly, Bi-annual.', 1;

    DECLARE @InvoiceScheduleId INT =
    (
        SELECT TOP (1) s.ID
        FROM SFin.InvoiceSchedules s
        WHERE s.RowStatus NOT IN (0,254)
          AND s.Guid = @InvoiceScheduleGuid
        ORDER BY s.ID DESC
    );

    IF (@InvoiceScheduleId IS NULL)
        THROW 60005, 'InvoiceSchedule not found for provided Guid.', 1;

    IF (@OverwriteExisting = 0)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceScheduleMonthConfiguration mc
            WHERE mc.RowStatus NOT IN (0,254)
              AND mc.InvoiceScheduleId = @InvoiceScheduleId
        )
        BEGIN
            ;THROW 60006, 'Monthly schedule rows already exist. Use OverwriteExisting=1 to regenerate.', 1;
        END
    END

    BEGIN TRAN;

    UPDATE SFin.InvoiceSchedules
    SET Frequency = @Frequency
    WHERE ID = @InvoiceScheduleId;

    IF (@OverwriteExisting = 1)
    BEGIN
        UPDATE mc
        SET mc.RowStatus = 254
        FROM SFin.InvoiceScheduleMonthConfiguration mc
        WHERE mc.RowStatus NOT IN (0,254)
          AND mc.InvoiceScheduleId = @InvoiceScheduleId;
    END

    -- Total month span covered by the date range (used to derive how many
    -- periods fit at the chosen frequency)
    DECLARE @TotalMonthSpan INT = DATEDIFF(MONTH, @StartDate, @EndDate) + 1;
    IF (@TotalMonthSpan <= 0)
        THROW 60007, 'Invalid month span.', 1;

    -- Number of periods at the given frequency. The final period always
    -- lands exactly on @EndDate (same rule as before), so we count how many
    -- full @StepMonths hops fit in the span, plus the closing one.
    DECLARE @PeriodsCount INT = ((@TotalMonthSpan - 1) / @StepMonths) + 1;
    IF (@PeriodsCount <= 0)
        THROW 60007, 'Invalid month span.', 1;

    DECLARE @BaseDay INT = DAY(@StartDate);

    DECLARE @BaseAmount DECIMAL(19,2) = ROUND(@TotalValueNet / @PeriodsCount, 2);
    DECLARE @LastAmount DECIMAL(19,2) = ROUND(@TotalValueNet - (@BaseAmount * (@PeriodsCount - 1)), 2);

    DECLARE @i INT = 0;

    WHILE (@i < @PeriodsCount)
    BEGIN
        DECLARE @PeriodNumber INT = @i + 1;

        DECLARE @InvoiceDate DATE;

        IF (@i = @PeriodsCount - 1)
        BEGIN
            -- Requirement: final invoice is exactly the EndDate provided
            SET @InvoiceDate = @EndDate;
        END
        ELSE
        BEGIN
            -- Clamp to end-of-month if base day doesn't exist (31st -> Feb 28/29)
            DECLARE @MonthAnchor DATE = DATEADD(MONTH, @i * @StepMonths, @StartDate);
            DECLARE @EomDay INT = DAY(EOMONTH(@MonthAnchor));
            DECLARE @DayToUse INT = CASE WHEN @BaseDay > @EomDay THEN @EomDay ELSE @BaseDay END;

            SET @InvoiceDate = DATEFROMPARTS(YEAR(@MonthAnchor), MONTH(@MonthAnchor), @DayToUse);
        END

        DECLARE @Amount DECIMAL(19,2) = CASE WHEN @i = @PeriodsCount - 1 THEN @LastAmount ELSE @BaseAmount END;

        DECLARE @RowGuid UNIQUEIDENTIFIER = NEWID();

        -- DataObject row (EntityTypeId = 201)
        INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
        VALUES (@RowGuid, 1, 201);

        INSERT INTO SFin.InvoiceScheduleMonthConfiguration
        (
              RowStatus
            , Guid
            , InvoiceScheduleId
            , PeriodNumber
            , Amount
            , OnDayOfMonth
            , Description
        )
        VALUES
        (
              1
            , @RowGuid
            , @InvoiceScheduleId
            , @PeriodNumber
            , @Amount
            , @InvoiceDate
            , N''
        );

        SET @i += 1;
    END

    COMMIT;

    SELECT
          InsertedCount = @PeriodsCount
        , MonthsCount  = @PeriodsCount
        
END
GO
 
GO

/* Deploy StoredProcedure SFin.RejectBatchedTransaction using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.RejectBatchedTransaction.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.RejectBatchedTransaction
    Source schema hash : 2815F4453FBDFF7509B7CA0706DA0B1AC1EFAEBD037442700540C0A4CFB00607
    Definition SHA-256 : 132D4F863B48774B1DCDB520ACF8B1A1EC66D96BEE299AA1D90355D7B14150A4

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[RejectBatchedTransaction]
  @Guid      UNIQUEIDENTIFIER,
  @RejectionReason NVARCHAR(MAX)
AS
  BEGIN


	DECLARE @InvoiceRequestGuid UNIQUEIDENTIFIER;
	DECLARE @InvoiceRequestNumber NVARCHAR(10); --Use it for the note (user knows which invoice it pertains to)

	--Get the invoice request guid through the transaction.
	SELECT DISTINCT
		@InvoiceRequestGuid = ir.Guid,
		@InvoiceRequestNumber = CONVERT(NVARCHAR(10), ir.ID)
	FROM SFin.TransactionDetails root_hobt
	JOIN SFin.InvoiceRequestItems iri ON (iri.ID = root_hobt.InvoiceRequestItemId)
	JOIN SFin.InvoiceRequests ir ON (iri.InvoiceRequestId = ir.ID)
	JOIN SFin.Transactions tr ON (tr.ID = root_hobt.TransactionID)
	WHERE 
			(tr.Guid = @Guid)
		AND (root_hobt.RowStatus NOT IN (0,254))


	IF(@InvoiceRequestGuid IS NOT NULL)
		BEGIN
			
			--(1) Delete the batched transaction.
			EXEC SCore.DeleteDataObject
			  @Guid = @Guid;

			UPDATE  SFin.Transactions
			SET     RowStatus = 200  --Use archive. This way, the job finance memos will still show. 
			WHERE   Guid = @Guid


			--(2) Mark the invoice request as rejected.
			UPDATE SFin.InvoiceRequests
			SET IsRejected = 1
			WHERE Guid = @InvoiceRequestGuid;


			--(3) Upsert a finance memo note for the invoice request

			--[PARAMETERS]
			DECLARE 
			 @_AccountGuid UNIQUEIDENTIFIER,
			 @_JobGuid UNIQUEIDENTIFIER,
			 @_TransactionGuid UNIQUEIDENTIFIER,
			 @_Memo NVARCHAR(MAX),
			 @_UserGuid UNIQUEIDENTIFIER,
			 @_RejectionMemoGuid UNIQUEIDENTIFIER = NEWID(),
			 @_PrependedRejectionReason NVARCHAR(MAX);

			 


			 --(a) Get the job guid + finance account guid
			 SELECT 
				@_AccountGuid	 = finacc.Guid,
				@_JobGuid		 = j.Guid
			FROM SFin.Transactions root_hobt
			JOIN SJob.Jobs j ON (root_hobt.JobID = j.ID)
			JOIN SCrm.Accounts finacc ON (j.FinanceAccountID = finacc.ID)
			WHERE root_hobt.Guid = @Guid;
			
			--(b) Set the user
			SET @_UserGuid = SCore.GetCurrentUserGuid();

			--(c) Prepend the note with "Rejection Reason".
			SET @_PrependedRejectionReason = CONCAT(N'Rejection Reason for invoice request ', @InvoiceRequestNumber, N': ', @RejectionReason);

			--(d) Set the transaction guid (easier read)
			SET @_TransactionGuid = @Guid;

			--(e) No check for empty message: this should be handled by the front-end.
			
			--(f) Execute upsert.
			EXEC SFin.FinanceMemoUpsert
				@AccountGuid	 = @_AccountGuid, 
				@JobGuid		 = @_JobGuid, 
				@TransactionGuid = @_TransactionGuid, 
				@Memo			 = @_PrependedRejectionReason, 
				@UserGuid		 = @_UserGuid, 
				@Guid			 = @_RejectionMemoGuid;

		END;
  END;
GO

GO

/* Deploy StoredProcedure SFin.SageInbound_ReconcileInvoiceTransaction using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.SageInbound_ReconcileInvoiceTransaction.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SFin].[SageInbound_ReconcileInvoiceTransaction]')
GO
CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileInvoiceTransaction]
(
    @ExternalTransactionID BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @NowUtc DATETIME2(7) = SYSUTCDATETIME(),
        @SageDataset NVARCHAR(30),
        @SageAccountReference NVARCHAR(100),
        @SageDocumentNo NVARCHAR(100),
        @SageTransactionTypeCode INT,
        @SageTransactionReference NVARCHAR(100),
        @SecondReference NVARCHAR(100),
        @MatchedTransactionID BIGINT = -1,
        @MatchedTransactionGuid UNIQUEIDENTIFIER = NULL,
        @MatchedInvoiceRequestID INT = -1,
        @MatchedJobID INT = -1,
        @MatchRule NVARCHAR(100) = N'NoMatch',
        @IsMatched BIT = 0;

    SELECT
        @SageDataset = ext.SageDataset,
        @SageAccountReference = ext.SageAccountReference,
        @SageDocumentNo = ext.SageDocumentNo,
        @SageTransactionTypeCode = ext.SageTransactionTypeCode,
        @SageTransactionReference = ext.SageTransactionReference,
        @SecondReference = ext.SecondReference
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    IF @SageDocumentNo IS NULL
    BEGIN
        RAISERROR('Sage external transaction not found.', 16, 1);
        RETURN;
    END;

    /*
        Supported customer transaction types are Invoice (4), Credit Note (5)
        and Receipt (6). Credit Notes and Receipts are reconciled to the posted
        Invoice so their allocations can be materialised in CymBuild. Unknown
        transaction types must not be guessed or attached to an Invoice.
    */
    IF ISNULL(@SageTransactionTypeCode, -1) NOT IN (4, 5, 6)
    BEGIN
        UPDATE ext
        SET
            MatchedTransactionID = -1,
            MatchedInvoiceRequestID = -1,
            MatchedJobID = -1,
            UpdatedByUserID = SCore.GetCurrentUserId(),
            UpdatedDateTimeUTC = @NowUtc
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.ID = @ExternalTransactionID
          AND ext.RowStatus NOT IN (0,254);

        SELECT
            ExternalTransactionID = @ExternalTransactionID,
            IsMatched = CAST(0 AS BIT),
            MatchedTransactionID = CAST(-1 AS BIGINT),
            MatchedTransactionGuid = CAST(NULL AS UNIQUEIDENTIFIER),
            MatchedInvoiceRequestID = CAST(-1 AS INT),
            MatchedJobID = CAST(-1 AS INT),
            MatchRule = N'UnsupportedSageTransactionType';

        RETURN;
    END;

    /* 1. Preferred current match */
    SELECT TOP (1)
        @MatchedTransactionID = t.ID,
        @MatchedTransactionGuid = t.Guid,
        @MatchedJobID = ISNULL(t.JobID, -1),
        @MatchRule = N'ReservedInvoiceNumber=SageDocumentNo'
    FROM SFin.Transactions AS t
    WHERE t.RowStatus NOT IN (0,254)
      AND ISNULL(t.ReservedInvoiceNumber, N'') = ISNULL(@SageDocumentNo, N'')
    ORDER BY t.ID DESC;

    /* 2. Backward-compatible fallback for already-enqueued inbound rows */
    IF ISNULL(@MatchedTransactionID, -1) <= 0
    BEGIN
        SELECT TOP (1)
            @MatchedTransactionID = s.TransactionID,
            @MatchedInvoiceRequestID = s.InvoiceRequestID,
            @MatchedJobID = s.JobID,
            @MatchRule = N'InboundStatus.TransactionID'
        FROM SFin.SageInboundDocumentStatus AS s
        WHERE s.RowStatus NOT IN (0,254)
          AND s.TransactionID > 0
          AND s.SageDataset = @SageDataset
          AND s.SageAccountReference = @SageAccountReference
          AND s.SageDocumentNo = @SageDocumentNo
        ORDER BY s.ID DESC;
    END;

    /* 3. Secondary ReservedInvoiceNumber fallback */
    IF ISNULL(@MatchedTransactionID, -1) <= 0
       AND ISNULL(@SecondReference, N'') <> N''
    BEGIN
        SELECT TOP (1)
            @MatchedTransactionID = t.ID,
            @MatchedTransactionGuid = t.Guid,
            @MatchedJobID = ISNULL(t.JobID, -1),
            @MatchRule = N'ReservedInvoiceNumber=SecondReference'
        FROM SFin.Transactions AS t
        WHERE t.RowStatus NOT IN (0,254)
          AND ISNULL(t.ReservedInvoiceNumber, N'') = ISNULL(@SecondReference, N'')
        ORDER BY t.ID DESC;
    END;

    IF ISNULL(@MatchedTransactionID, -1) > 0
    BEGIN
        IF ISNULL(@MatchedInvoiceRequestID, -1) <= 0
        BEGIN
            SELECT TOP (1)
                @MatchedInvoiceRequestID = ISNULL(iri.InvoiceRequestID, -1)
            FROM SFin.TransactionDetails AS td
            JOIN SFin.InvoiceRequestItems AS iri
                ON iri.ID = td.InvoiceRequestItemId
               AND iri.RowStatus NOT IN (0,254)
            WHERE td.TransactionID = @MatchedTransactionID
              AND td.RowStatus NOT IN (0,254)
              AND td.InvoiceRequestItemId IS NOT NULL
            ORDER BY td.ID DESC;
        END;

        IF ISNULL(@MatchedJobID, -1) <= 0 OR @MatchedTransactionGuid IS NULL
        BEGIN
            SELECT TOP (1)
                @MatchedJobID = CASE WHEN ISNULL(@MatchedJobID, -1) <= 0 THEN ISNULL(t.JobID, -1) ELSE @MatchedJobID END,
                @MatchedTransactionGuid = ISNULL(@MatchedTransactionGuid, t.Guid)
            FROM SFin.Transactions AS t
            WHERE t.ID = @MatchedTransactionID
              AND t.RowStatus NOT IN (0,254);
        END;

        SET @IsMatched = 1;
    END;

    UPDATE ext
    SET
        MatchedTransactionID = CASE WHEN @IsMatched = 1 THEN @MatchedTransactionID ELSE -1 END,
        MatchedInvoiceRequestID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedInvoiceRequestID, -1) ELSE -1 END,
        MatchedJobID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedJobID, -1) ELSE -1 END,
        UpdatedByUserID = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC = @NowUtc
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    SELECT
        ExternalTransactionID = @ExternalTransactionID,
        IsMatched = @IsMatched,
        MatchedTransactionID = CASE WHEN @IsMatched = 1 THEN @MatchedTransactionID ELSE -1 END,
        MatchedTransactionGuid = CASE WHEN @IsMatched = 1 THEN @MatchedTransactionGuid ELSE NULL END,
        MatchedInvoiceRequestID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedInvoiceRequestID, -1) ELSE -1 END,
        MatchedJobID = CASE WHEN @IsMatched = 1 THEN ISNULL(@MatchedJobID, -1) ELSE -1 END,
        MatchRule = @MatchRule;
END;
GO

GO

/* Deploy StoredProcedure SFin.SageInboundDiagnostics_Get using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.SageInboundDiagnostics_Get.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.SageInboundDiagnostics_Get
    Source schema hash : 18FDB17F5C547D3331CA7E29099DB8069472BF89B97AB41C9A0C64A2C1DF81D2
    Definition SHA-256 : 4F59F90095F730799F7B7712B7249F64E64B2538B581676D7F9F9F62313635DD

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[SageInboundDiagnostics_Get]
(
    @StatusCode NVARCHAR(30) = NULL,
    @SageAccountReference NVARCHAR(100) = NULL,
    @SageDocumentNo NVARCHAR(100) = NULL,
    @TransactionNumber NVARCHAR(50) = NULL,
    @OnlyRetryableFailures BIT = NULL,
    @InvoiceRequestID INT = NULL,
    @TransactionID BIGINT = NULL,
    @JobID INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.ID,
        d.Guid,
        d.CymBuildEntityTypeID,
        d.CymBuildDocumentGuid,
        d.CymBuildDocumentID,
        d.InvoiceRequestID,
        d.TransactionID,
        d.JobID,
        d.JobNumber,
        d.SageDataset,
        d.SageAccountReference,
        d.SageDocumentNo,
        d.LastOperationName,
        d.StatusCode,
        d.IsInProgress,
        d.InProgressClaimedOnUtc,
        d.LastSucceededOnUtc,
        d.LastFailedOnUtc,
        d.LastError,
        d.LastErrorIsRetryable,
        d.LastSourceWatermarkUtc,
        d.LastGrossAmount,
        d.LastAllocatedValue,
        d.LastOutstandingAmount,
        d.LastDocumentDiscountedValue,
        d.LastIsPaid,
        d.LastIsFullyPaid,
        d.LastPaymentStateCode,
        d.LastTransactionDate,
        d.LastSageTransactionReference,
        d.LastSecondReference,
        d.LastSageTransactionTypeCode,
        d.NextPollDueOnUtc,
        d.PollAttemptCount,
        d.IsTerminalState,
        d.CreatedByUserID,
        d.CreatedDateTimeUTC,
        d.UpdatedByUserID,
        d.UpdatedDateTimeUTC,
        d.LastAttemptedOnUtc,
        d.LastCompletedOnUtc,
        d.LastAttemptIsSuccess,
        d.LastAttemptErrorMessage,
        d.LastAttemptIsRetryableFailure,
        d.LastAttemptResponseStatus,
        d.LastAttemptResponseDetail,
        d.CanRequeue,
        d.CanForceRequeue,

        d.TransactionGuid,
        d.TransactionNumber,
        d.TransactionIsBatched,
        d.MatchedTransactionGuid,
        d.MatchedTransactionNumber,
        d.MaterialisedReceiptTransactionGuid,
        d.MaterialisedReceiptTransactionNumber,
        d.MaterialisedAllocationGuid,
        d.MaterialisedAllocationID,
        d.TransactionSageTransactionReference,
        d.MatchedTransactionSageTransactionReference,
        d.LastMatchedExternalTransactionID,
        d.LastMatchedExternalTransactionTypeCode,
        d.LastMatchedExternalTransactionAllocatedValue
    FROM SFin.tvf_SageInboundDiagnostics
    (
        @StatusCode,
        @SageAccountReference,
        @SageDocumentNo,
        @OnlyRetryableFailures,
        @InvoiceRequestID,
        @TransactionID,
        @JobID,
        @TransactionNumber
    ) AS d
    ORDER BY d.UpdatedDateTimeUTC DESC, d.ID DESC;
END
GO

GO

/* Deploy StoredProcedure SFin.SageInboundReceiptMaterialisation_AutoCorrect using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.SageInboundReceiptMaterialisation_AutoCorrect.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.SageInboundReceiptMaterialisation_AutoCorrect
    Source schema hash : F067937F834259F89EF9140C67E2C0FF39970EF798237836E075FD2163E5CD39
    Definition SHA-256 : 6795DC6258611089A7EE4CC3B7860B476DDDF72F4D90A721BBFF6ED55533F36D

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[SageInboundReceiptMaterialisation_AutoCorrect]
(
    @ExternalTransactionID BIGINT = NULL,
    @BatchSize INT = 100,
    @DryRun BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @CurrentExternalTransactionID BIGINT,
        @ProcessedCount INT = 0,
        @CorrectedCount INT = 0,
        @SkippedCount INT = 0,
        @FailedCount INT = 0;

    DECLARE @Candidates TABLE
    (
        RowNumber INT IDENTITY(1,1) NOT NULL,
        ExternalTransactionID BIGINT NOT NULL
    );

    DECLARE @Results TABLE
    (
        ExternalTransactionID BIGINT NOT NULL,
        Outcome NVARCHAR(30) NOT NULL,
        Message NVARCHAR(2000) NOT NULL,
        MatchedTransactionID BIGINT NULL,
        MaterialisedReceiptTransactionID BIGINT NULL,
        MaterialisedAllocationID BIGINT NULL
    );

    INSERT INTO @Candidates
    (
        ExternalTransactionID
    )
    SELECT TOP (@BatchSize)
        ext.ID
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.RowStatus NOT IN (0,254)
      AND ext.SageTransactionTypeCode IN (5, 6)
      AND ABS(ISNULL(ext.AllocatedValue, 0)) > 0
      AND
      (
            @ExternalTransactionID IS NULL
         OR ext.ID = @ExternalTransactionID
      )
      AND ext.MaterialisedReceiptTransactionID IS NULL
    ORDER BY ext.ID;

    IF @DryRun = 1
    BEGIN
        SELECT
            ProcessedCount = COUNT(1),
            CorrectedCount = 0,
            SkippedCount = COUNT(1),
            FailedCount = 0
        FROM @Candidates;

        SELECT
            c.ExternalTransactionID,
            Outcome = N'DryRun',
            Message = N'Candidate would be reconciled and materialised.',
            MatchedTransactionID = ext.MatchedTransactionID,
            MaterialisedReceiptTransactionID = ext.MaterialisedReceiptTransactionID,
            MaterialisedAllocationID = ext.MaterialisedAllocationID
        FROM @Candidates AS c
        JOIN SFin.SageExternalTransactions AS ext
            ON ext.ID = c.ExternalTransactionID
           AND ext.RowStatus NOT IN (0,254)
        ORDER BY c.ExternalTransactionID;

        RETURN;
    END;

    DECLARE candidate_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        c.ExternalTransactionID
    FROM @Candidates AS c
    ORDER BY c.ExternalTransactionID;

    OPEN candidate_cursor;

    FETCH NEXT FROM candidate_cursor INTO @CurrentExternalTransactionID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            DECLARE @ReconcileResult TABLE
            (
                ExternalTransactionID BIGINT,
                IsMatched BIT,
                MatchedTransactionID BIGINT,
                MatchedTransactionGuid UNIQUEIDENTIFIER,
                MatchedInvoiceRequestID INT,
                MatchedJobID INT,
                MatchRule NVARCHAR(100)
            );

            DECLARE @PaymentStateResult TABLE
            (
                ExternalTransactionID BIGINT,
                PaymentStateCode NVARCHAR(30),
                AllocatedValue DECIMAL(18,2),
                OutstandingAmount DECIMAL(18,2),
                GrossAmount DECIMAL(18,2),
                DocumentDiscountedValue DECIMAL(18,2),
                IsPaid BIT,
                IsFullyPaid BIT
            );

            INSERT INTO @ReconcileResult
            (
                ExternalTransactionID,
                IsMatched,
                MatchedTransactionID,
                MatchedTransactionGuid,
                MatchedInvoiceRequestID,
                MatchedJobID,
                MatchRule
            )
            EXEC SFin.SageInbound_ReconcileInvoiceTransaction
                @ExternalTransactionID = @CurrentExternalTransactionID;

            INSERT INTO @PaymentStateResult
            (
                ExternalTransactionID,
                PaymentStateCode,
                AllocatedValue,
                OutstandingAmount,
                GrossAmount,
                DocumentDiscountedValue,
                IsPaid,
                IsFullyPaid
            )
            EXEC SFin.SageInbound_ApplyAggregatePaymentState
                @ExternalTransactionID = @CurrentExternalTransactionID;

            EXEC SFin.SageInboundReceiptAndAllocation_Materialise
                @ExternalTransactionID = @CurrentExternalTransactionID;

            INSERT INTO @Results
            (
                ExternalTransactionID,
                Outcome,
                Message,
                MatchedTransactionID,
                MaterialisedReceiptTransactionID,
                MaterialisedAllocationID
            )
            SELECT
                ext.ID,
                CASE
                    WHEN ext.MaterialisedReceiptTransactionID IS NOT NULL
                     AND ext.MaterialisedAllocationID IS NOT NULL
                        THEN N'Corrected'
                    WHEN ISNULL(ext.MatchedTransactionID, -1) <= 0
                        THEN N'Skipped'
                    ELSE N'Skipped'
                END,
                CASE
                    WHEN ext.MaterialisedReceiptTransactionID IS NOT NULL
                     AND ext.MaterialisedAllocationID IS NOT NULL
                        THEN N'Sage Credit Note/Receipt and allocation materialised.'
                    WHEN ISNULL(ext.MatchedTransactionID, -1) <= 0
                        THEN N'Could not reconcile external transaction to a CymBuild invoice transaction.'
                    ELSE N'Materialisation did not create an allocation-source transaction. Check ReceiptMaterialisationError.'
                END,
                ext.MatchedTransactionID,
                ext.MaterialisedReceiptTransactionID,
                ext.MaterialisedAllocationID
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @CurrentExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);
        END TRY
        BEGIN CATCH
            SET @FailedCount += 1;

            UPDATE ext
            SET
                ReceiptMaterialisationError = LEFT(ERROR_MESSAGE(), 2000),
                UpdatedByUserID = SCore.GetCurrentUserId(),
                UpdatedDateTimeUTC = GETUTCDATE()
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @CurrentExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);

            INSERT INTO @Results
            (
                ExternalTransactionID,
                Outcome,
                Message,
                MatchedTransactionID,
                MaterialisedReceiptTransactionID,
                MaterialisedAllocationID
            )
            SELECT
                ext.ID,
                N'Failed',
                LEFT(ERROR_MESSAGE(), 2000),
                ext.MatchedTransactionID,
                ext.MaterialisedReceiptTransactionID,
                ext.MaterialisedAllocationID
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @CurrentExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);
        END CATCH;

        FETCH NEXT FROM candidate_cursor INTO @CurrentExternalTransactionID;
    END;

    CLOSE candidate_cursor;
    DEALLOCATE candidate_cursor;

    SELECT
        @ProcessedCount = COUNT(1),
        @CorrectedCount = SUM(CASE WHEN Outcome = N'Corrected' THEN 1 ELSE 0 END),
        @SkippedCount = SUM(CASE WHEN Outcome = N'Skipped' THEN 1 ELSE 0 END),
        @FailedCount = SUM(CASE WHEN Outcome = N'Failed' THEN 1 ELSE 0 END)
    FROM @Results;

    SELECT
        ProcessedCount = ISNULL(@ProcessedCount, 0),
        CorrectedCount = ISNULL(@CorrectedCount, 0),
        SkippedCount = ISNULL(@SkippedCount, 0),
        FailedCount = ISNULL(@FailedCount, 0);

    SELECT
        ExternalTransactionID,
        Outcome,
        Message,
        MatchedTransactionID,
        MaterialisedReceiptTransactionID,
        MaterialisedAllocationID
    FROM @Results
    ORDER BY ExternalTransactionID;
END;
GO

GO

/* Deploy StoredProcedure SFin.TransactionDetailsUpsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.TransactionDetailsUpsert.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.TransactionDetailsUpsert
    Source schema hash : 6D88E82B53CE7BE5E03CDA609C5EEAE8FBB3E5E794841EAC333B65F8546E4A8B
    Definition SHA-256 : 9B8EC7305EBFD4E8DAACD92F6A0D16E9E00CAFA653E9693F2428CFA0D262A34F

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionDetailsUpsert]
(
      @TransactionGuid          UNIQUEIDENTIFIER
    , @MilestoneGuid            UNIQUEIDENTIFIER
    , @ActivityGuid             UNIQUEIDENTIFIER
    , @Net                      DECIMAL(9, 2)
    , @Vat                      DECIMAL(9, 2)
    , @Gross                    DECIMAL(9, 2)
    , @VatRate                  DECIMAL(9, 2)
    , @Description              NVARCHAR(2000)
    , @JobPaymentStageGuid      UNIQUEIDENTIFIER
    , @Guid                     UNIQUEIDENTIFIER
    , @RIBAStageGuid            UNIQUEIDENTIFIER
    , @InvoiceRequestItemGuid   UNIQUEIDENTIFIER = NULL
    , @Qty                      DECIMAL(18, 4) = 1
    , @VatCodeGuid              UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @TransactionID              BIGINT
        , @MilestoneID                BIGINT = -1
        , @ActivityID                 BIGINT = -1
        , @JobPaymentStageID          INT    = -1
        , @RIBAStageID                INT    = -1
        , @InvoiceRequestItemID       BIGINT = -1
        , @VatCodeID                  INT
        , @ResolvedVatRate            DECIMAL(9, 4)
        , @IsInsert                   BIT
        , @TransactionTypeName        NVARCHAR(50)
        , @TransactionTypeIsNegated   BIT = 0
        , @TransactionTypeIsBank      BIT = 0
        , @JobNumber                  NVARCHAR(2000)
        , @JobDescription             NVARCHAR(2000)
        , @JobType                    NVARCHAR(2000)
        , @UprnFormattedAddressComma  NVARCHAR(2000);

    IF @Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 60070, N'A valid Guid is required for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @TransactionGuid IS NULL OR @TransactionGuid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 60071, N'A valid TransactionGuid is required for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @VatCodeGuid IS NULL OR @VatCodeGuid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 60072, N'A valid VatCodeGuid is required for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @Qty IS NULL OR @Qty <= 0
    BEGIN
        SET @Qty = 1;
    END;

    SELECT
          @TransactionID = t.ID
        , @TransactionTypeName = tt.Name
        , @TransactionTypeIsNegated = ISNULL(tt.IsNegated, 0)
        , @TransactionTypeIsBank = ISNULL(tt.IsBank, 0)
    FROM SFin.Transactions AS t
    INNER JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0, 254)
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);

    IF @TransactionID IS NULL
    BEGIN
        ;THROW 60073, N'Transaction could not be resolved for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @MilestoneGuid IS NOT NULL
       AND @MilestoneGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @MilestoneID = m.ID
        FROM SJob.Milestones AS m
        WHERE m.Guid = @MilestoneGuid
          AND m.RowStatus NOT IN (0, 254);
    END;

    IF @ActivityGuid IS NOT NULL
       AND @ActivityGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @ActivityID = a.ID
        FROM SJob.Activities AS a
        WHERE a.Guid = @ActivityGuid
          AND a.RowStatus NOT IN (0, 254);
    END;

    IF @RIBAStageGuid IS NOT NULL
       AND @RIBAStageGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @RIBAStageID = rs.ID
        FROM SJob.RibaStages AS rs
        WHERE rs.Guid = @RIBAStageGuid
          AND rs.RowStatus NOT IN (0, 254);
    END;

    IF @JobPaymentStageGuid IS NOT NULL
       AND @JobPaymentStageGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @JobPaymentStageID = jps.ID
        FROM SJob.JobPaymentStages AS jps
        WHERE jps.Guid = @JobPaymentStageGuid
          AND jps.RowStatus NOT IN (0, 254);
    END;

    IF @InvoiceRequestItemGuid IS NOT NULL
       AND @InvoiceRequestItemGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @InvoiceRequestItemID = iri.ID
        FROM SFin.InvoiceRequestItems AS iri
        WHERE iri.Guid = @InvoiceRequestItemGuid
          AND iri.RowStatus NOT IN (0, 254);
    END;

    SELECT
          @VatCodeID = vc.ID
        , @ResolvedVatRate = vc.VatPercentage
    FROM SFin.VatCodes AS vc
    WHERE vc.Guid = @VatCodeGuid
      AND vc.RowStatus NOT IN (0, 254)
      AND vc.Active = 1;

    IF @VatCodeID IS NULL
    BEGIN
        ;THROW 60074, N'VatCode could not be resolved for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @ResolvedVatRate IS NULL
    BEGIN
        ;THROW 60075, N'VatCode selected does not contain a valid VAT percentage for SFin.TransactionDetailsUpsert.', 1;
    END;

    /*
        VAT rate is now owned by the selected VatCode.
        Ignore caller-supplied @VatRate / @Vat / @Gross and recalculate deterministically.
    */
    SET @VatRate = CONVERT(DECIMAL(9, 2), @ResolvedVatRate);
    SET @Vat = ROUND(@Net * (@ResolvedVatRate / 100.0), 2);
    SET @Gross = ROUND(@Net + @Vat, 2);

    /*
        Fee-cap validation must only apply to finance transactions that consume
        job fee drawdown. Inbound Sage receipt materialisation also uses this
        upsert to create bank-side receipt details, but receipts must not be
        blocked by invoice fee-cap remaining values.

        TransactionTypes.IsBank keeps the logic data-driven and preserves the
        existing accounting sign convention, where TransactionCalculations uses
        IsNegated rather than storing negative line values directly.

        The explicit Receipt/Payment exclusion protects the inbound path even
        if historic reference data has not marked a bank-side transaction type
        as IsBank = 1 yet.
    */
    IF ISNULL(@TransactionTypeIsBank, 0) = 0
       AND ISNULL(@TransactionTypeIsNegated, 0) = 0
       AND ISNULL(@TransactionTypeName, N'') NOT IN (N'Receipt', N'Payment')
       AND ISNULL(@Net, 0) > 0
    BEGIN
        DECLARE @JobGuid UNIQUEIDENTIFIER;
        DECLARE @RemainingAmount DECIMAL(19,2);
        DECLARE @ExistingDetailNetForGuard DECIMAL(19,2) = 0;
        DECLARE @FeeCapGuardAvailableAmount DECIMAL(19,2);

        SELECT
            @JobGuid = j.Guid
        FROM SFin.Transactions AS root_hobt
        LEFT JOIN SJob.Jobs AS j
            ON root_hobt.JobID = j.ID
           AND j.RowStatus NOT IN (0, 254)
        WHERE root_hobt.ID = @TransactionID
          AND root_hobt.RowStatus NOT IN (0, 254);

        SELECT
            @RemainingAmount = fd.Remaining
        FROM SJob.Job_FeeDrawdown AS fd
        INNER JOIN SJob.Jobs AS j
            ON j.ID = fd.JobId
           AND j.RowStatus NOT IN (0, 254)
        WHERE j.Guid = @JobGuid
          AND fd.StageLabel = N'Total (inc. Fee Cap)';

        SELECT
            @ExistingDetailNetForGuard = ISNULL(SUM(ISNULL(td.Net, 0)), 0)
        FROM SFin.TransactionDetails AS td
        WHERE td.Guid = @Guid
          AND td.TransactionID = @TransactionID
          AND td.RowStatus NOT IN (0, 254);

        SET @FeeCapGuardAvailableAmount = @RemainingAmount + ISNULL(@ExistingDetailNetForGuard, 0);

        IF @RemainingAmount IS NOT NULL
           AND @Net > @FeeCapGuardAvailableAmount
        BEGIN
            DECLARE @ErrorMessageDirect NVARCHAR(500);

            SET @ErrorMessageDirect =
                      N'Cannot save this transaction because only the total of £'
                    + CONVERT(NVARCHAR(50), @FeeCapGuardAvailableAmount)
                    + N' remains'
                    + N', but the transaction Net is £'
                    + CONVERT(NVARCHAR(50), @Net)
                    + N'.';

            THROW 51003, @ErrorMessageDirect, 1;
        END;
    END;

    EXEC SCore.UpsertDataObject
          @Guid       = @Guid
        , @SchemeName = N'SFin'
        , @ObjectName = N'TransactionDetails'
        , @IsInsert   = @IsInsert OUTPUT;

    IF @IsInsert = 1
    BEGIN
        SELECT
              @JobNumber = j.Number
            , @JobDescription = j.JobDescription
            , @JobType = jt.Name
            , @UprnFormattedAddressComma = p.FormattedAddressComma
        FROM SJob.Jobs AS j
        INNER JOIN SJob.JobTypes AS jt
            ON jt.ID = j.JobTypeID
        INNER JOIN SJob.Assets AS p
            ON p.ID = j.UprnID
        INNER JOIN SFin.Transactions AS t
            ON t.JobID = j.ID
        WHERE t.Guid = @TransactionGuid
          AND j.RowStatus NOT IN (0, 254)
          AND jt.RowStatus NOT IN (0, 254)
          AND p.RowStatus NOT IN (0, 254)
          AND t.RowStatus NOT IN (0, 254);

        IF @@ROWCOUNT > 0
        BEGIN
            SET @Description =
                ISNULL(@Description, N'')
                + N'
Our project ref.: ' + ISNULL(@JobNumber, N'')
                + N'
Project description: ' + ISNULL(@JobDescription, N'')
                + N'
Property: ' + ISNULL(@UprnFormattedAddressComma, N'')
                + N'
Appointed role: ' + ISNULL(@JobType, N'');
        END;

        SET @Description = REPLACE(@Description, CHAR(34), CHAR(39));

        INSERT INTO SFin.TransactionDetails
        (
              RowStatus
            , Guid
            , TransactionID
            , MilestoneID
            , ActivityID
            , Net
            , Vat
            , Gross
            , VatRate
            , Description
            , JobPaymentStageId
            , InvoiceRequestItemId
            , RIBAStageId
            , Qty
            , VatCodeID
        )
        VALUES
        (
              1
            , @Guid
            , @TransactionID
            , ISNULL(@MilestoneID, -1)
            , ISNULL(@ActivityID, -1)
            , @Net
            , @Vat
            , @Gross
            , @VatRate
            , ISNULL(@Description, N'')
            , ISNULL(@JobPaymentStageID, -1)
            , ISNULL(@InvoiceRequestItemID, -1)
            , ISNULL(@RIBAStageID, -1)
            , @Qty
            , @VatCodeID
        );
    END
    ELSE
    BEGIN
        UPDATE td
        SET
              td.MilestoneID = ISNULL(@MilestoneID, -1)
            , td.ActivityID = ISNULL(@ActivityID, -1)
            , td.Net = @Net
            , td.Vat = @Vat
            , td.Gross = @Gross
            , td.VatRate = @VatRate
            , td.Description = ISNULL(@Description, N'')
            , td.JobPaymentStageId = ISNULL(@JobPaymentStageID, -1)
            , td.InvoiceRequestItemId = ISNULL(@InvoiceRequestItemID, -1)
            , td.RIBAStageId = ISNULL(@RIBAStageID, -1)
            , td.Qty = @Qty
            , td.VatCodeID = @VatCodeID
        FROM SFin.TransactionDetails AS td
        WHERE td.Guid = @Guid
          AND td.RowStatus NOT IN (0, 254);
    END;
END;
GO

GO

/* Deploy StoredProcedure SFin.TransactionSageInvoiceDetails_Upsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.TransactionSageInvoiceDetails_Upsert.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.TransactionSageInvoiceDetails_Upsert
    Source schema hash : DBC20F7B420828E5404BCBAC5AF3AD5ACE8B72B7144E12637BB087C5EB35EF03
    Definition SHA-256 : D31F76FC1E618375B4FE62C1649663BBDF4151971B71B8AB02AE2DF8153E751A

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionSageInvoiceDetails_Upsert]
(
    @TransactionGuid UNIQUEIDENTIFIER,
    @SageInvoiceNumber NVARCHAR(50) = NULL,
    @SageSalesOrderNumber NVARCHAR(50) = NULL,
    @UpdatedByUserID INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE t
    SET
        t.SageInvoiceNumber = COALESCE(NULLIF(LTRIM(RTRIM(@SageInvoiceNumber)), N''), t.SageInvoiceNumber),
        t.SageSalesOrderNumber = COALESCE(NULLIF(LTRIM(RTRIM(@SageSalesOrderNumber)), N''), t.SageSalesOrderNumber),
        t.SageInvoiceGeneratedDateTimeUtc = SYSUTCDATETIME()
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);
END
GO

GO

/* Deploy StoredProcedure SFin.TransactionSageSubmissionStatus_MarkSentLegacy using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SFin.TransactionSageSubmissionStatus_MarkSentLegacy.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SFin.TransactionSageSubmissionStatus_MarkSentLegacy
    Source schema hash : 901241A5829CB97750FED59E064686726C77768F88D5B47722D1A07C8A050A5C
    Definition SHA-256 : DFEA9426EE72F391A36B11F71B90A7EF9A642CE1F6CEDBC95A4971D6FF2BE679

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[TransactionSageSubmissionStatus_MarkSentLegacy]
(
    @UpdatedByUserID INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        CYB-501
        Transactions that were approved and sent to Sage manually, before the
        automated Sage submission process existed, never had their submission
        status row transitioned away from the default 'Pending' StatusCode.
        This mirrors the "already succeeded" evidence check already used by
        SFin.TransactionSageSubmission_EnsureQueued: a non-empty
        SageTransactionReference / SageInvoiceNumber / SageSalesOrderNumber on
        the transaction proves it was already sent to Sage, regardless of
        what the tracking row's StatusCode still says.
    */
    DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    UPDATE s
    SET
        s.StatusCode = N'Sent Legacy',
        s.LastOperationName = N'MarkSentLegacy',
        s.UpdatedDateTimeUTC = @NowUtc,
        s.UpdatedByUserID = ISNULL(@UpdatedByUserID, -1)
    FROM SFin.TransactionSageSubmissionStatus AS s
    JOIN SFin.Transactions AS t
        ON t.ID = s.TransactionID
       AND t.RowStatus NOT IN (0, 254)
    WHERE s.RowStatus NOT IN (0, 254)
      AND s.StatusCode = N'Pending'
      AND
      (
            NULLIF(LTRIM(RTRIM(t.SageTransactionReference)), N'') IS NOT NULL
         OR NULLIF(LTRIM(RTRIM(t.SageInvoiceNumber)), N'') IS NOT NULL
         OR NULLIF(LTRIM(RTRIM(t.SageSalesOrderNumber)), N'') IS NOT NULL
      );

    SELECT UpdatedCount = @@ROWCOUNT;
END
GO

GO

/* Deploy StoredProcedure SMigration.MetadataApplyIdentityMap_Build using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataApplyIdentityMap_Build.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.MetadataApplyIdentityMap_Build
    Source schema hash : 613D6A4B756096145D6491A0024F89E539FDF55BE48AD18E7EFBBB3F64C5F13A
    Definition SHA-256 : 897C4A364739EC4BD8D07E542D0D27D45B610FCA292D76F8656141D12D5A4D32

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

    EXEC SMigration.MetadataRegistry_SyncFromEntityTypes
        @SourceDatabaseName = NULL,
        @TargetDatabaseName = @TargetDatabaseName;

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
        maprow.SchemaName,
        maprow.TableName,
        COUNT_BIG(1) AS MapRows,
        SUM(CASE
            WHEN maprow.TargetRowId IS NULL
             AND ISNULL(sr.DifferenceType, N'') <> N'Insert'
             AND ign.ID IS NULL
             AND ov.ID IS NULL THEN 1
            ELSE 0
        END) AS MissingTargetRows
    FROM SMigration.Metadata_ApplyIdentityMap AS maprow
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
    GROUP BY
        maprow.SchemaName,
        maprow.TableName
    ORDER BY
        maprow.SchemaName,
        maprow.TableName;
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataIdentityMapOverride_Upsert using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataIdentityMapOverride_Upsert.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.MetadataIdentityMapOverride_Upsert
    Source schema hash : 8AAA39548DD16F94268D9C577337E6F5CE36A02F9CC44608DB39EEC1F5C6D4A1
    Definition SHA-256 : ECDE69F267332680924E6D559F5B589BC5CA9A6D2929C6232B54ACB8A0B93238

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

GO

/* Deploy StoredProcedure SMigration.MetadataRegistry_SyncFromEntityTypes using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataRegistry_SyncFromEntityTypes.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.MetadataRegistry_SyncFromEntityTypes
    Source schema hash : C411DA496EAB338773BDA68A8D4C0B27E45F9FC3262D006C7B2ACDCA76EBBCCA
    Definition SHA-256 : 6838F66B23E59B7CC31D659F0F1B8ABEE53A82A88C0EE553D376C425370BD88F

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SMigration].[MetadataRegistry_SyncFromEntityTypes]
(
    @SourceDatabaseName SYSNAME = NULL,
    @TargetDatabaseName SYSNAME = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceDb SYSNAME = NULLIF(@SourceDatabaseName, N''),
        @TargetDb SYSNAME = ISNULL(NULLIF(@TargetDatabaseName, N''), DB_NAME()),
        @ControlDb SYSNAME,
        @ControlSourceName NVARCHAR(20),
        @Sql NVARCHAR(MAX);

    /*
        R16C behaviour:
        - When a source database is supplied, source EntityTypes are authoritative
          for what is metadata in the migration run.
        - When no source database is supplied, fall back to the target/current database
          so maintenance calls still have a deterministic control database.
        - Registry rows backed by an EntityType main HoBT in the control database are
          enabled only when that EntityType has IsMetaData = 1.
        - Existing curated registry rows that are not backed by a controllable EntityType
          are left untouched.
    */
    SET @ControlDb = CASE
        WHEN @SourceDb IS NOT NULL AND DB_ID(@SourceDb) IS NOT NULL THEN @SourceDb
        WHEN @TargetDb IS NOT NULL AND DB_ID(@TargetDb) IS NOT NULL THEN @TargetDb
        ELSE DB_NAME()
    END;

    SET @ControlSourceName = CASE
        WHEN @SourceDb IS NOT NULL AND DB_ID(@SourceDb) IS NOT NULL THEN N'Source'
        WHEN @TargetDb IS NOT NULL AND DB_ID(@TargetDb) IS NOT NULL THEN N'Target'
        ELSE N'Current'
    END;

    IF OBJECT_ID(N'tempdb..#MetadataRegistryEntityTypeControlledTables') IS NOT NULL
        DROP TABLE #MetadataRegistryEntityTypeControlledTables;

    IF OBJECT_ID(N'tempdb..#MetadataRegistryEntityTypeCandidates') IS NOT NULL
        DROP TABLE #MetadataRegistryEntityTypeCandidates;

    CREATE TABLE #MetadataRegistryEntityTypeControlledTables
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        IsMetaData BIT NOT NULL,
        SourceName NVARCHAR(20) NOT NULL
    );

    CREATE TABLE #MetadataRegistryEntityTypeCandidates
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        SourceName NVARCHAR(20) NOT NULL
    );

    IF @ControlDb IS NOT NULL AND DB_ID(@ControlDb) IS NOT NULL
    BEGIN
        SET @Sql = N'
INSERT INTO #MetadataRegistryEntityTypeControlledTables
(
    SchemaName,
    TableName,
    IsMetaData,
    SourceName
)
SELECT DISTINCT
    CONVERT(SYSNAME, eh.SchemaName) AS SchemaName,
    CONVERT(SYSNAME, eh.ObjectName) AS TableName,
    CONVERT(BIT, ISNULL(et.IsMetaData, 0)) AS IsMetaData,
    @ControlSourceName AS SourceName
FROM ' + QUOTENAME(@ControlDb) + N'.SCore.EntityTypes AS et
INNER JOIN ' + QUOTENAME(@ControlDb) + N'.SCore.EntityHobts AS eh
    ON eh.EntityTypeID = et.ID
   AND eh.RowStatus NOT IN (0,254)
WHERE et.RowStatus NOT IN (0,254)
  AND ISNULL(eh.IsMainHoBT, 0) = 1
  AND NULLIF(eh.SchemaName, N'''') IS NOT NULL
  AND NULLIF(eh.ObjectName, N'''') IS NOT NULL;

INSERT INTO #MetadataRegistryEntityTypeCandidates
(
    SchemaName,
    TableName,
    SourceName
)
SELECT DISTINCT
    controlled.SchemaName,
    controlled.TableName,
    controlled.SourceName
FROM #MetadataRegistryEntityTypeControlledTables AS controlled
WHERE controlled.IsMetaData = 1;';

        EXEC sys.sp_executesql
            @Sql,
            N'@ControlSourceName NVARCHAR(20)',
            @ControlSourceName = @ControlSourceName;
    END;

    ;WITH ControlledTables AS
    (
        SELECT
            controlled.SchemaName,
            controlled.TableName,
            MAX(CONVERT(INT, controlled.IsMetaData)) AS IsMetaData
        FROM #MetadataRegistryEntityTypeControlledTables AS controlled
        WHERE NULLIF(controlled.SchemaName, N'') IS NOT NULL
          AND NULLIF(controlled.TableName, N'') IS NOT NULL
        GROUP BY
            controlled.SchemaName,
            controlled.TableName
    )
    UPDATE target
    SET
        target.IsEnabled = 0
    FROM SMigration.Metadata_TableRegistry AS target
    INNER JOIN ControlledTables AS controlled
        ON controlled.SchemaName = target.SchemaName
       AND controlled.TableName = target.TableName
    WHERE controlled.IsMetaData = 0
      AND target.RowStatus NOT IN (0,254)
      AND target.IsEnabled = 1;

    ;WITH DistinctCandidates AS
    (
        SELECT
            c.SchemaName,
            c.TableName,
            MIN(c.SourceName) AS FirstSeenIn,
            ROW_NUMBER() OVER (ORDER BY c.SchemaName, c.TableName) AS CandidateOrder
        FROM #MetadataRegistryEntityTypeCandidates AS c
        WHERE NULLIF(c.SchemaName, N'') IS NOT NULL
          AND NULLIF(c.TableName, N'') IS NOT NULL
        GROUP BY
            c.SchemaName,
            c.TableName
    ),
    CandidateValues AS
    (
        SELECT
            CONVERT(UNIQUEIDENTIFIER, SUBSTRING(HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), UPPER(CONCAT(N'SMigration.Metadata_TableRegistry|', dc.SchemaName, N'.', dc.TableName)))), 1, 16)) AS RegistryGuid,
            dc.SchemaName,
            dc.TableName,
            CONVERT(INT, 10000 + dc.CandidateOrder) AS ApplyOrder
        FROM DistinctCandidates AS dc
    )
    UPDATE target
    SET
        target.RowStatus = 1,
        target.IsEnabled = 1,
        target.GuidColumnName = CASE WHEN NULLIF(target.GuidColumnName, N'') IS NULL THEN N'Guid' ELSE target.GuidColumnName END,
        target.PrimaryKeyColumnName = CASE WHEN NULLIF(target.PrimaryKeyColumnName, N'') IS NULL THEN N'ID' ELSE target.PrimaryKeyColumnName END
    FROM SMigration.Metadata_TableRegistry AS target
    INNER JOIN CandidateValues AS source
        ON source.SchemaName = target.SchemaName
       AND source.TableName = target.TableName;

    ;WITH DistinctCandidates AS
    (
        SELECT
            c.SchemaName,
            c.TableName,
            ROW_NUMBER() OVER (ORDER BY c.SchemaName, c.TableName) AS CandidateOrder
        FROM #MetadataRegistryEntityTypeCandidates AS c
        WHERE NULLIF(c.SchemaName, N'') IS NOT NULL
          AND NULLIF(c.TableName, N'') IS NOT NULL
        GROUP BY
            c.SchemaName,
            c.TableName
    ),
    CandidateValues AS
    (
        SELECT
            CONVERT(UNIQUEIDENTIFIER, SUBSTRING(HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), UPPER(CONCAT(N'SMigration.Metadata_TableRegistry|', dc.SchemaName, N'.', dc.TableName)))), 1, 16)) AS RegistryGuid,
            dc.SchemaName,
            dc.TableName,
            CONVERT(INT, 10000 + dc.CandidateOrder) AS ApplyOrder
        FROM DistinctCandidates AS dc
    )
    INSERT INTO SMigration.Metadata_TableRegistry
    (
        Guid,
        RowStatus,
        SchemaName,
        TableName,
        GuidColumnName,
        PrimaryKeyColumnName,
        ApplyOrder,
        IsEnabled,
        IsDataObjectBacked,
        IsRetirable,
        IsEnvironmentSpecific,
        NaturalKeyJson,
        ParentDependencyJson,
        CreatedOnUtc
    )
    SELECT
        source.RegistryGuid,
        1,
        source.SchemaName,
        source.TableName,
        N'Guid',
        N'ID',
        source.ApplyOrder,
        1,
        1,
        1,
        0,
        N'[]',
        N'[]',
        SYSUTCDATETIME()
    FROM CandidateValues AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS target
        WHERE target.SchemaName = source.SchemaName
          AND target.TableName = source.TableName
    )
      AND NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS targetGuid
        WHERE targetGuid.Guid = source.RegistryGuid
    );

    DECLARE
        @RegistryGuid UNIQUEIDENTIFIER,
        @SchemaName SYSNAME,
        @TableName SYSNAME;

    DECLARE registry_do_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            tr.Guid,
            tr.SchemaName,
            tr.TableName
        FROM SMigration.Metadata_TableRegistry AS tr
        INNER JOIN
        (
            SELECT
                c.SchemaName,
                c.TableName
            FROM #MetadataRegistryEntityTypeCandidates AS c
            GROUP BY
                c.SchemaName,
                c.TableName
        ) AS c
            ON c.SchemaName = tr.SchemaName
           AND c.TableName = tr.TableName
        WHERE tr.RowStatus NOT IN (0,254);

    OPEN registry_do_cursor;

    FETCH NEXT FROM registry_do_cursor INTO @RegistryGuid, @SchemaName, @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @RegistryGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_TableRegistry';

        FETCH NEXT FROM registry_do_cursor INTO @RegistryGuid, @SchemaName, @TableName;
    END;

    CLOSE registry_do_cursor;
    DEALLOCATE registry_do_cursor;

    SELECT
        COUNT_BIG(1) AS CandidateCount,
        @ControlDb AS ControlDatabaseName,
        @ControlSourceName AS ControlSourceName
    FROM
    (
        SELECT
            c.SchemaName,
            c.TableName
        FROM #MetadataRegistryEntityTypeCandidates AS c
        GROUP BY
            c.SchemaName,
            c.TableName
    ) AS groupedCandidates;
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataStage_NormaliseDifferences using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataStage_NormaliseDifferences.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.MetadataStage_NormaliseDifferences
    Source schema hash : 4896128E2C598EA02C7D90ECE4D85436CB0F96A33501C5A58FE8CA4A8AC6CF54
    Definition SHA-256 : 9E6EBCDC17BD1D7223F26B9F0FB85BE86AC0B30E7D7ADA4696B995BD76524ABE

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    CymBuild Metadata CI/CD
    Stage/Diff normalisation fix

    Purpose:
    - Keep raw SourcePayloadJson / TargetPayloadJson for audit.
    - Stop Stage/Diff reporting false inserts where Apply intentionally reuses
      an existing target row by natural key.
    - Stop Stage/Diff reporting false updates caused only by environment-specific
      numeric IDs/FKs.

    Required call point:
    - Execute SMigration.MetadataStage_NormaliseDifferences after all
      SMigration.Metadata_StagedRows have been inserted for a run and before
      SummaryJson is calculated/read by the UI.

    Works for:
    - same-server SQL proc staging
    - API two-connection staging, provided the API calls this proc after staging
*/

CREATE OR ALTER PROCEDURE [SMigration].[MetadataStage_NormaliseDifferences]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
    BEGIN
        THROW 53000, 'Metadata stage normalisation failed because the run was not found or is inactive.', 1;
    END;

    DECLARE
        @EntityPropertiesColumnList NVARCHAR(MAX),
        @GridViewColumnDefinitionsColumnList NVARCHAR(MAX),
        @IconsColumnList NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    /* =========================================================
       1. Convert false inserts to natural-key target matches.
          These remain Update/NoChange based on the real target payload.
       ========================================================= */

    SELECT
        @EntityPropertiesColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'epj.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SCore'
      AND t.name = N'EntityProperties'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @EntityPropertiesColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH EntityPropertiesToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetEp.ID AS TargetEntityPropertyID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            TRY_CONVERT(BIGINT, COALESCE
            (
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHoBTID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHoBTId''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHobtID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHobtId'')
            )) AS SourceEntityHoBTID,
            JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS PropertyName
    ) AS parsed
    LEFT JOIN SMigration.Metadata_TableRegistry AS hobtReg
        ON hobtReg.SchemaName = N''SCore''
       AND hobtReg.TableName = N''EntityHobts''
       AND hobtReg.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS srcHobt
        ON srcHobt.RunGuid = sr.RunGuid
       AND srcHobt.RegistryGuid = hobtReg.Guid
       AND srcHobt.SourceRowId = parsed.SourceEntityHoBTID
       AND srcHobt.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.EntityHobts AS targetHobt
        ON targetHobt.Guid = srcHobt.SourceRowGuid
       AND targetHobt.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.EntityProperties AS targetEp
        ON targetEp.EntityHoBTID = targetHobt.ID
       AND targetEp.Name = parsed.PropertyName
       AND targetEp.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SCore''
      AND tr.TableName = N''EntityProperties''
      AND targetEp.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN EntityPropertiesToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @EntityPropertiesColumnList + N'
            FROM SCore.EntityProperties AS epj
            WHERE epj.ID = n.TargetEntityPropertyID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    SELECT
        @GridViewColumnDefinitionsColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'gvcdj.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SUserInterface'
      AND t.name = N'GridViewColumnDefinitions'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @GridViewColumnDefinitionsColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH GridViewColumnsToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetCol.ID AS TargetGridViewColumnDefinitionID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            TRY_CONVERT(BIGINT, COALESCE
            (
                JSON_VALUE(sr.SourcePayloadJson, N''$.GridViewDefinitionID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.GridViewDefinitionId'')
            )) AS SourceGridViewDefinitionID,
            JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS ColumnName,
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N''$.IsPrimaryKey'')) AS IsPrimaryKey
    ) AS parsed
    LEFT JOIN SMigration.Metadata_TableRegistry AS gvdReg
        ON gvdReg.SchemaName = N''SUserInterface''
       AND gvdReg.TableName = N''GridViewDefinitions''
       AND gvdReg.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS srcGvd
        ON srcGvd.RunGuid = sr.RunGuid
       AND srcGvd.RegistryGuid = gvdReg.Guid
       AND srcGvd.SourceRowId = parsed.SourceGridViewDefinitionID
       AND srcGvd.RowStatus NOT IN (0,254)
    LEFT JOIN SUserInterface.GridViewDefinitions AS targetGvd
        ON targetGvd.Guid = srcGvd.SourceRowGuid
       AND targetGvd.RowStatus NOT IN (0,254)
    LEFT JOIN SUserInterface.GridViewColumnDefinitions AS targetCol
        ON targetCol.GridViewDefinitionID = targetGvd.ID
       AND targetCol.RowStatus NOT IN (0,254)
       AND
       (
            targetCol.Name = parsed.ColumnName
            OR
            (
                ISNULL(parsed.IsPrimaryKey, 0) = 1
                AND targetCol.IsPrimaryKey = 1
            )
       )
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SUserInterface''
      AND tr.TableName = N''GridViewColumnDefinitions''
      AND targetCol.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN GridViewColumnsToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @GridViewColumnDefinitionsColumnList + N'
            FROM SUserInterface.GridViewColumnDefinitions AS gvcdj
            WHERE gvcdj.ID = n.TargetGridViewColumnDefinitionID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    SELECT
        @IconsColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'ij.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SUserInterface'
      AND t.name = N'Icons'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @IconsColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH IconsToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetIcon.ID AS TargetIconID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS IconName
    ) AS parsed
    LEFT JOIN SUserInterface.Icons AS targetIcon
        ON targetIcon.Name = parsed.IconName
       AND targetIcon.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SUserInterface''
      AND tr.TableName = N''Icons''
      AND targetIcon.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN IconsToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @IconsColumnList + N'
            FROM SUserInterface.Icons AS ij
            WHERE ij.ID = n.TargetIconID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    /* =========================================================
       2. Normalise false updates caused by environment-specific IDs.
          This keeps relationship drift visible only where a stable, non-ID
          metadata value differs. Raw payloads remain available for audit.
       ========================================================= */

    IF OBJECT_ID(N'tempdb..#MetadataNormalisedDiff') IS NOT NULL
        DROP TABLE #MetadataNormalisedDiff;

    CREATE TABLE #MetadataNormalisedDiff
    (
        StagedRowID BIGINT NOT NULL PRIMARY KEY,
        SourceNormalisedHash VARBINARY(32) NULL,
        TargetNormalisedHash VARBINARY(32) NULL
    );

    ;WITH SourceNormalised AS
    (
        SELECT
            sr.ID AS StagedRowID,
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT(NVARCHAR(MAX), CONCAT(j.[key], N'=', ISNULL(j.[value], N'<NULL>'))),
                        N'|'
                    ) WITHIN GROUP (ORDER BY j.[key])
                )
            ) AS NormalisedHash
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.SourcePayloadJson) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType = N'Update'
          AND sr.TargetPayloadJson IS NOT NULL
          AND j.[key] NOT IN
          (
              N'ID',
              N'EntityTypeID', N'EntityTypeId',
              N'EntityHoBTID', N'EntityHoBTId', N'EntityHobtID', N'EntityHobtId',
              N'LanguageLabelID', N'LanguageLabelId',
              N'LanguageID', N'LanguageId',
              N'EntityDataTypeID', N'EntityDataTypeId',
              N'EntityPropertyGroupID', N'EntityPropertyGroupId',
              N'DropDownListDefinitionID', N'DropDownListDefinitionId',
              N'EntityQueryID', N'EntityQueryId',
              N'MappedEntityPropertyID', N'MappedEntityPropertyId',
              N'GridDefinitionID', N'GridDefinitionId',
              N'GridViewDefinitionID', N'GridViewDefinitionId',
              N'MetricTypeID', N'MetricTypeId',
              N'DrawerIconID', N'DrawerIconId',
              N'GridViewTypeID', N'GridViewTypeId',
              N'IconID', N'IconId',
              N'PropertyGroupLayoutID', N'PropertyGroupLayoutId'
          )
        GROUP BY sr.ID
    ),
    TargetNormalised AS
    (
        SELECT
            sr.ID AS StagedRowID,
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT(NVARCHAR(MAX), CONCAT(j.[key], N'=', ISNULL(j.[value], N'<NULL>'))),
                        N'|'
                    ) WITHIN GROUP (ORDER BY j.[key])
                )
            ) AS NormalisedHash
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.TargetPayloadJson) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType = N'Update'
          AND sr.TargetPayloadJson IS NOT NULL
          AND j.[key] NOT IN
          (
              N'ID',
              N'EntityTypeID', N'EntityTypeId',
              N'EntityHoBTID', N'EntityHoBTId', N'EntityHobtID', N'EntityHobtId',
              N'LanguageLabelID', N'LanguageLabelId',
              N'LanguageID', N'LanguageId',
              N'EntityDataTypeID', N'EntityDataTypeId',
              N'EntityPropertyGroupID', N'EntityPropertyGroupId',
              N'DropDownListDefinitionID', N'DropDownListDefinitionId',
              N'EntityQueryID', N'EntityQueryId',
              N'MappedEntityPropertyID', N'MappedEntityPropertyId',
              N'GridDefinitionID', N'GridDefinitionId',
              N'GridViewDefinitionID', N'GridViewDefinitionId',
              N'MetricTypeID', N'MetricTypeId',
              N'DrawerIconID', N'DrawerIconId',
              N'GridViewTypeID', N'GridViewTypeId',
              N'IconID', N'IconId',
              N'PropertyGroupLayoutID', N'PropertyGroupLayoutId'
          )
        GROUP BY sr.ID
    )
    INSERT INTO #MetadataNormalisedDiff
    (
        StagedRowID,
        SourceNormalisedHash,
        TargetNormalisedHash
    )
    SELECT
        sr.ID,
        sn.NormalisedHash,
        tn.NormalisedHash
    FROM SMigration.Metadata_StagedRows AS sr
    LEFT JOIN SourceNormalised AS sn
        ON sn.StagedRowID = sr.ID
    LEFT JOIN TargetNormalised AS tn
        ON tn.StagedRowID = sr.ID
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL;

    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN #MetadataNormalisedDiff AS nd
        ON nd.StagedRowID = sr.ID
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND nd.SourceNormalisedHash = nd.TargetNormalisedHash;

    /* =========================================================
       3. Refresh run summary after normalisation.
       ========================================================= */

    UPDATE SMigration.Metadata_Run
    SET SummaryJson =
    (
        SELECT
            CONCAT
            (
                N'{"insertCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                N',"updateCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                N',"noChangeCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                N',"totalCount":',
                CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                N'}'
            )
        FROM SMigration.Metadata_StagedRows AS sr
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
    )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
END;
GO

GO

/* Deploy StoredProcedure SMigration.MetadataStage_Run using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.MetadataStage_Run.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.MetadataStage_Run
    Source schema hash : 11DF451A2816EC5438C62837DA63B8AB110EB8202EC5171D77F078CFC4ACD29B
    Definition SHA-256 : 868DEA82E6C7958010E762302AA7D112F0E0ED58F7CB6E09B6C31EC21FB75213

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SMigration].[MetadataStage_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceDatabaseName SYSNAME,
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @ColumnList NVARCHAR(MAX),
        @HasRowStatus BIT,
        @SourceWhereClause NVARCHAR(MAX),
        @SourceAndClause NVARCHAR(MAX),
        @DuplicateWhereClause NVARCHAR(MAX),
        @SourceRowStatusExpression NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    SELECT
        @SourceDatabaseName = r.SourceDatabaseName,
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @SourceDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    EXEC SMigration.MetadataRegistry_SyncFromEntityTypes
        @SourceDatabaseName = @SourceDatabaseName,
        @TargetDatabaseName = @TargetDatabaseName;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
    )
    BEGIN
        ;THROW 51001, 'No enabled metadata registry rows exist. Run SMigration.MetadataRegistry_Seed first.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_StagedRows
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'DuplicateSourceGuid',
          N'RegisteredGuidColumnMissing',
          N'RegisteredTableMissing',
          N'RegisteredSourceTableMissing'
      );

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
        SET @ColumnList = NULL;
        SET @HasRowStatus = 0;
        SET @Sql = NULL;

        IF OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
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
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredTableMissing',
                CONCAT(N'Registered metadata table does not exist in target: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF OBJECT_ID(QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
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
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredSourceTableMissing',
                CONCAT(N'Registered metadata table does not exist in source: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.schemas AS s
            INNER JOIN sys.tables AS t
                ON t.schema_id = s.schema_id
            INNER JOIN sys.columns AS c
                ON c.object_id = t.object_id
            WHERE s.name = @SchemaName
              AND t.name = @TableName
              AND c.name = @GuidColumnName
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
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredGuidColumnMissing',
                CONCAT(N'Registered metadata table does not have Guid column: ', @SchemaName, N'.', @TableName, N'.', @GuidColumnName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'","GuidColumnName":"', @GuidColumnName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SELECT
            @HasRowStatus =
                CASE WHEN EXISTS
                (
                    SELECT 1
                    FROM sys.schemas AS s
                    INNER JOIN sys.tables AS t
                        ON t.schema_id = s.schema_id
                    INNER JOIN sys.columns AS c
                        ON c.object_id = t.object_id
                    WHERE s.name = @SchemaName
                      AND t.name = @TableName
                      AND c.name = N'RowStatus'
                )
                THEN 1 ELSE 0 END;

        SELECT
            @ColumnList =
                STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N',')
                WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.schemas AS s
        INNER JOIN sys.tables AS t
            ON t.schema_id = s.schema_id
        INNER JOIN sys.columns AS c
            ON c.object_id = t.object_id
        WHERE s.name = @SchemaName
          AND t.name = @TableName
          AND c.is_computed = 0
          AND c.system_type_id <> 189;

        IF @ColumnList IS NULL
        BEGIN
            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SET @SourceRowStatusExpression =
            CASE WHEN @HasRowStatus = 1
                THEN N'TRY_CONVERT(TINYINT, s.RowStatus)'
                ELSE N'NULL'
            END;

        SET @SourceWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE s.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @SourceAndClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'AND'
                ELSE N'WHERE'
            END;

        SET @DuplicateWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE sd.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @Sql = N'
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
    @RegistryGuid,
    d.SourceRowGuid,
    N''Fail'',
    N''DuplicateSourceGuid'',
    CONCAT(N''Source metadata table contains duplicate active Guid values: ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' / '', CONVERT(NVARCHAR(36), d.SourceRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","DuplicateCount":'',
        CONVERT(NVARCHAR(30), d.DuplicateCount),
        N''}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        COUNT_BIG(1) AS DuplicateCount
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    GROUP BY CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    HAVING COUNT_BIG(1) > 1
) AS d;

INSERT INTO SMigration.Metadata_StagedRows
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    SourceRowId,
    SourceRowStatus,
    SourcePayloadJson,
    SourcePayloadHash,
    TargetPayloadJson,
    TargetPayloadHash,
    DifferenceType,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    src.SourceRowGuid,
    src.SourceRowId,
    src.SourceRowStatus,
    src.SourcePayloadJson,
    HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson)),
    tgt.TargetPayloadJson,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN NULL
        ELSE HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson))
    END,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN N''Insert''
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson))
           <> HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''Update''
        ELSE N''NoChange''
    END,
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        TRY_CONVERT(BIGINT, s.' + QUOTENAME(@PrimaryKeyColumnName) + N') AS SourceRowId,
        ' + @SourceRowStatusExpression + N' AS SourceRowStatus,
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sj
            WHERE sj.' + QUOTENAME(@GuidColumnName) + N' = s.' + QUOTENAME(@GuidColumnName) + N'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS SourcePayloadJson
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    ' + @SourceAndClause + N' NOT EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT
                CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N') AS DuplicateGuid
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sd
            ' + @DuplicateWhereClause + N'
            GROUP BY CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N')
            HAVING COUNT_BIG(1) > 1
        ) AS dup
        WHERE dup.DuplicateGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    )
) AS src
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS tj
            WHERE tj.' + QUOTENAME(@GuidColumnName) + N' = src.SourceRowGuid
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid;

        FETCH NEXT FROM registry_cursor
        INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;
    END;

    CLOSE registry_cursor;
    DEALLOCATE registry_cursor;

    EXEC SMigration.MetadataStage_NormaliseDifferences
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates
    @RunGuid = @RunGuid;

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = N'Staged',
        SummaryJson =
        (
            SELECT
                CONCAT
                (
                    N'{"insertCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                    N',"updateCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                    N',"noChangeCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                    N',"totalCount":',
                    CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                    N'}'
                )
            FROM SMigration.Metadata_StagedRows AS sr
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254)
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'StageRun',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata staging completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;
END;
GO

GO

/* Deploy StoredProcedure SMigration.OnboardingLookup_BusinessUnitGroups using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.OnboardingLookup_BusinessUnitGroups.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.OnboardingLookup_BusinessUnitGroups
    Source schema hash : 27389066D1B07E19AB1B5F4B03DB9C61AB4F57A4FC16B01F592F3C44D4340216
    Definition SHA-256 : 250B1592D05DC712044372BFA3B7B6390A50B19E9EF4396A7C57305B516CC814

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SMigration].[OnboardingLookup_BusinessUnitGroups]
    @SourceDatabase SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT
            Guid = CAST(g.Guid AS NVARCHAR(36)),
            Name = ISNULL(g.Name, N''''),
            Code = ISNULL(g.Code, N''''),
            Description = CONCAT(ISNULL(g.Code, N''''), N'' - '', ISNULL(g.Name, N''''))
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        WHERE g.RowStatus NOT IN (0,254)
          AND g.ID > 0
          AND g.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND ISNULL(g.DirectoryId, N'''') <> N''''
          AND EXISTS
          (
              SELECT 1
              FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
              WHERE ou.ID > 0
                AND ou.RowStatus NOT IN (0,254)
                AND
                (
                    ou.DefaultSecurityGroupId = g.ID
                    OR ou.Name = g.Name
                )
          )
        ORDER BY g.Name;';

    EXEC sys.sp_executesql @sql;
END
GO

GO

/* Deploy StoredProcedure SMigration.OnboardingStage_LoadFromSource using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SMigration.OnboardingStage_LoadFromSource.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Object             : StoredProcedure SMigration.OnboardingStage_LoadFromSource
    Source schema hash : 5299ACDF40AF061BB941D9247BC6E2E7ABDD557E11610E3442A8539DC0F22D10
    Definition SHA-256 : 43435CB12ECACBA04F06D19658B3F4AFEEDAC1405604E80420BE92F8044C322A

    This deterministic file was synchronized from an explicitly selected, validated and accepted
    CymBuild_Dev source-definition snapshot. Review and commit the source-control diff before using
    it for promotion.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ================================================================================================
   Load onboarding migration stage from source DB.

   CymBuild rules preserved:
   - Source DB is read-only.
   - Target staging tables are deployment target only.
   - No manual DB promotion.
   - Explicit columns only.
   - Sentinel GUID rows are ignored.
   - RowStatus NOT IN (0,254) used for active migration scope where appropriate.
   - Workflow parent rows are staged before WorkflowStatusNotificationGroups.

   Critical workflow note:
   Active WorkflowStatusNotificationGroups may reference a Workflow parent whose RowStatus is not
   active in the source. Therefore Workflow parent staging intentionally does NOT filter wf.RowStatus.
   Filtering wf.RowStatus here was the cause of StagedWorkflows = 0 while WSNG rows were staged,
   which then caused MISSING_WORKFLOW validation errors.
   ================================================================================================ */
CREATE OR ALTER PROCEDURE [SMigration].[OnboardingStage_LoadFromSource]
    @SourceDatabase SYSNAME,
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER,
    @SourceServerName SYSNAME = N'',
    @TargetServerName SYSNAME = N'',
    @TargetDatabaseName SYSNAME = N'',
    @RunGuid UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(1000) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    EXEC SMigration.OnboardingStage_Reset @RunGuid = @RunGuid;

    DECLARE @SourceBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER = NULL;
    DECLARE @sql NVARCHAR(MAX);

    /* Resolve source BU OU by matching default security group first. */
    SET @sql = N'
    SELECT TOP (1)
        @OutGuid = ou.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = ou.DefaultSecurityGroupId
    WHERE g.Guid = @BusinessUnitGroupGuid
      AND ou.ID > 0
      AND g.ID > 0
    ORDER BY ou.ID;';

    EXEC sp_executesql
        @sql,
        N'@BusinessUnitGroupGuid UNIQUEIDENTIFIER, @OutGuid UNIQUEIDENTIFIER OUTPUT',
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @OutGuid = @SourceBusinessUnitOrganisationalUnitGuid OUTPUT;

    /* Fallback: match OU name to group name. */
    IF @SourceBusinessUnitOrganisationalUnitGuid IS NULL
    BEGIN
        SET @sql = N'
        SELECT TOP (1)
            @OutGuid = ou.Guid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.Guid = @BusinessUnitGroupGuid
        WHERE ou.Name = g.Name
          AND ou.ID > 0
          AND g.ID > 0
        ORDER BY ou.ID;';

        EXEC sp_executesql
            @sql,
            N'@BusinessUnitGroupGuid UNIQUEIDENTIFIER, @OutGuid UNIQUEIDENTIFIER OUTPUT',
            @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
            @OutGuid = @SourceBusinessUnitOrganisationalUnitGuid OUTPUT;
    END;

    EXEC SMigration.OnboardingRun_Reserve
        @RunGuid = @RunGuid,
        @SourceDatabase = @SourceDatabase,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @SourceServerName = @SourceServerName,
        @TargetServerName = @TargetServerName,
        @TargetDatabaseName = @TargetDatabaseName,
        @SourceBusinessUnitOrganisationalUnitGuid = @SourceBusinessUnitOrganisationalUnitGuid,
        @Notes = @Notes;

    IF @SourceBusinessUnitOrganisationalUnitGuid IS NULL
    BEGIN
        DECLARE @SourceBusinessUnitError NVARCHAR(2048) = CONCAT(
            N'Could not resolve selected source business unit group ',
            CONVERT(NVARCHAR(36), @BusinessUnitGroupGuid),
            N' to a source organisational unit in database ',
            QUOTENAME(@SourceDatabase),
            N'. The OnBoarding business unit must be a group used as SCore.OrganisationalUnits.DefaultSecurityGroupId, or have an organisational unit with the same name. Reload the OnBoarding business-unit lookup after deploying this patch; the lookup now only returns resolvable business-unit groups.'
        );

        EXEC SMigration.OnboardingLog_Add
            @RunGuid,
            N'Stage',
            N'All',
            N'Failed',
            0,
            @SourceBusinessUnitError;

        THROW 51000, @SourceBusinessUnitError, 1;
    END;

    /* ============================================================================================
       1. Groups
       ============================================================================================ */
    SET @sql = N'
    ;WITH StageIdentityIds AS
    (
        SELECT DISTINCT
            i.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
            ON ug.IdentityID = i.ID
           AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ug.GroupID
           AND g.RowStatus NOT IN (0,254)
        WHERE i.RowStatus NOT IN (0,254)
          AND i.ID > 0
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    StageOU AS
    (
        SELECT
            ou.ID,
            g.ID AS DefaultGroupID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ou.DefaultSecurityGroupId
        CROSS JOIN
        (
            SELECT OrgNode
            FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits
            WHERE Guid = @BusinessUnitOuGuid
        ) AS b
        WHERE ou.RowStatus NOT IN (0,254)
          AND ou.ID > 0
          AND
          (
              ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
              OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1
          )
    ),
    RelevantGroups AS
    (
        SELECT
            g.ID,
            g.Guid,
            g.RowStatus,
            g.DirectoryId,
            g.Code,
            g.Name,
            g.Source
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        WHERE g.Guid = @BusinessUnitGroupGuid
          AND g.ID > 0

        UNION

        SELECT DISTINCT
            g.ID,
            g.Guid,
            g.RowStatus,
            g.DirectoryId,
            g.Code,
            g.Name,
            g.Source
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
            ON ug.GroupID = g.ID
        INNER JOIN StageIdentityIds AS s
            ON s.ID = ug.IdentityID
        WHERE g.RowStatus NOT IN (0,254)
          AND ug.RowStatus NOT IN (0,254)
          AND g.ID > 0

        UNION

        SELECT DISTINCT
            g.ID,
            g.Guid,
            g.RowStatus,
            g.DirectoryId,
            g.Code,
            g.Name,
            g.Source
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        INNER JOIN StageOU AS sou
            ON sou.DefaultGroupID = g.ID
        WHERE g.RowStatus NOT IN (0,254)
          AND g.ID > 0
    )
    INSERT INTO SMigration.Onboarding_Groups
    (
        RunGuid,
        GroupGuid,
        RowStatus,
        DirectoryId,
        Code,
        Name,
        Source,
        IsBusinessUnitGroup
    )
    SELECT DISTINCT
        @RunGuid,
        rg.Guid,
        rg.RowStatus,
        rg.DirectoryId,
        rg.Code,
        rg.Name,
        rg.Source,
        CAST(CASE WHEN rg.Guid = @BusinessUnitGroupGuid THEN 1 ELSE 0 END AS BIT)
    FROM RelevantGroups AS rg
    WHERE rg.ID > 0
      AND rg.Guid <> ''00000000-0000-0000-0000-000000000000'';';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* ============================================================================================
       2. OrganisationalUnits
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_OrganisationalUnits
    (
        RunGuid,
        OrganisationalUnitGuid,
        RowStatus,
        Name,
        ParentOrganisationalUnitGuid,
        ParentOrganisationalUnitName,
        AddressGuid,
        ContactGuid,
        OfficialAddressGuid,
        OfficialContactGuid,
        DepartmentPrefix,
        CostCentreCode,
        DefaultSecurityGroupGuid,
        QuoteThreshold,
        OrgLevel
    )
    SELECT
        @RunGuid,
        ou.Guid,
        ou.RowStatus,
        ou.Name,
        parent.Guid,
        parent.Name,
        a.Guid,
        c.Guid,
        oa.Guid,
        oc.Guid,
        ou.DepartmentPrefix,
        ou.CostCentreCode,
        g.Guid,
        ou.QuoteThreshold,
        ou.OrgNode.GetLevel()
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS parent
        ON parent.ID = ou.ParentID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS a
        ON a.ID = ou.AddressId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
        ON c.ID = ou.ContactId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS oa
        ON oa.ID = ou.OfficialAddressId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS oc
        ON oc.ID = ou.OfficialContactId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = ou.DefaultSecurityGroupId
    CROSS JOIN
    (
        SELECT OrgNode
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits
        WHERE Guid = @BusinessUnitOuGuid
    ) AS b
    WHERE ou.RowStatus NOT IN (0,254)
      AND ou.ID > 0
      AND ou.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND
      (
          ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
          OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

        /* Workflows in scope:
           - notification-group parents
           - active workflows for staged source OUs
        */
        SET @sql = N'
        ;WITH SourceWorkflows AS
        (
            SELECT DISTINCT
                wf.Guid AS WorkflowGuid,
                wf.RowStatus,
                ou.Guid AS OrganisationalUnitGuid,
                et.Guid AS EntityTypeGuid,
                eh.Guid AS EntityHoBTGuid,
                wf.Name,
                wf.Description,
                wf.Enabled
            FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
                ON ou.ID = wf.OrganisationalUnitId
            LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityTypes AS et
                ON et.ID = wf.EntityTypeID
            LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityHoBTs AS eh
                ON eh.ID = wf.EntityHoBTID
            WHERE wf.ID > 0
              AND wf.Guid <> ''00000000-0000-0000-0000-000000000000''
              AND
              (
                  wf.RowStatus NOT IN (0,254)
                  OR EXISTS
                  (
                      SELECT 1
                      FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS wsng
                      WHERE wsng.WorkflowID = wf.ID
                        AND wsng.RowStatus NOT IN (0,254)
                        AND wsng.ID > 0
                  )
              )
              AND
              (
                  wf.OrganisationalUnitId = -1
                  OR EXISTS
                  (
                      SELECT 1
                      FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS businessUnit
                      WHERE businessUnit.Guid = @BusinessUnitOuGuid
                        AND businessUnit.ID > 0
                        AND ou.OrgNode.IsDescendantOf(businessUnit.OrgNode) = 1
                  )
              )
        )
        INSERT INTO SMigration.Onboarding_Workflows
        (
            RunGuid,
            WorkflowGuid,
            RowStatus,
            OrganisationalUnitGuid,
            EntityTypeGuid,
            EntityHoBTGuid,
            Name,
            Description,
            Enabled
        )
        SELECT
            @RunGuid,
            sw.WorkflowGuid,
            sw.RowStatus,
            sw.OrganisationalUnitGuid,
            sw.EntityTypeGuid,
            sw.EntityHoBTGuid,
            sw.Name,
            sw.Description,
            sw.Enabled
        FROM SourceWorkflows AS sw
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_Workflows AS existing
            WHERE existing.RunGuid = @RunGuid
              AND existing.WorkflowGuid = sw.WorkflowGuid
        );
        ';

        EXEC sp_executesql
            @sql,
            N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* ============================================================================================
       3. Addresses required by staged OUs
       ============================================================================================ */
    SET @sql = N'
    ;WITH RelevantAddressGuids AS
    (
        SELECT AddressGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid

        UNION

        SELECT OfficialAddressGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid
    )
    INSERT INTO SMigration.Onboarding_Addresses
    (
        RunGuid,
        AddressGuid,
        RowStatus,
        AddressNumber,
        Name,
        Number,
        AddressLine1,
        AddressLine2,
        AddressLine3,
        Town,
        CountyGuid,
        Postcode,
        CountryGuid,
        LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        a.Guid,
        a.RowStatus,
        a.AddressNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        county.Guid,
        a.Postcode,
        country.Guid,
        a.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS a
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Counties AS county
        ON county.ID = a.CountyID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Countries AS country
        ON country.ID = a.CountryID
    INNER JOIN RelevantAddressGuids AS r
        ON r.Guid = a.Guid
    WHERE a.ID > 0
      AND a.Guid <> ''00000000-0000-0000-0000-000000000000'';';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       4. Contacts required by OUs and identities
       ============================================================================================ */
    SET @sql = N'
    ;WITH IdentityContactGuids AS
    (
        SELECT DISTINCT
            c.Guid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
            ON ug.IdentityID = i.ID
           AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ug.GroupID
           AND g.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
            ON c.ID = i.ContactId
        WHERE i.RowStatus NOT IN (0,254)
          AND i.ID > 0
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    OUContactGuids AS
    (
        SELECT ContactGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid

        UNION

        SELECT OfficialContactGuid AS Guid
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid
    ),
    RelevantContactGuids AS
    (
        SELECT Guid FROM IdentityContactGuids
        UNION
        SELECT Guid FROM OUContactGuids
    )
    INSERT INTO SMigration.Onboarding_Contacts
    (
        RunGuid,
        ContactGuid,
        RowStatus,
        PrimaryAccountGuid,
        PrimaryAddressGuid,
        FirstName,
        Initials,
        Surname,
        PostNominals,
        TitleGuid,
        DisplayName,
        IsPerson,
        PositionGuid,
        LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        c.Guid,
        c.RowStatus,
        acct.Guid,
        addr.Guid,
        c.FirstName,
        c.Initials,
        c.Surname,
        c.PostNominals,
        title.Guid,
        c.DisplayName,
        c.IsPerson,
        pos.Guid,
        c.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Accounts AS acct
        ON acct.ID = c.PrimaryAccountID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS addr
        ON addr.ID = c.PrimaryAddressID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.ContactTitles AS title
        ON title.ID = c.TitleId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.ContactPositions AS pos
        ON pos.ID = c.PositionID
    INNER JOIN RelevantContactGuids AS r
        ON r.Guid = c.Guid
    WHERE c.ID > 0
      AND c.Guid <> ''00000000-0000-0000-0000-000000000000'';';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    /* ============================================================================================
       5. Addresses required by staged contacts
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Addresses
    (
        RunGuid,
        AddressGuid,
        RowStatus,
        AddressNumber,
        Name,
        Number,
        AddressLine1,
        AddressLine2,
        AddressLine3,
        Town,
        CountyGuid,
        Postcode,
        CountryGuid,
        LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        a.Guid,
        a.RowStatus,
        a.AddressNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        county.Guid,
        a.Postcode,
        country.Guid,
        a.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses AS a
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Counties AS county
        ON county.ID = a.CountyID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Countries AS country
        ON country.ID = a.CountryID
    INNER JOIN SMigration.Onboarding_Contacts AS c
        ON c.RunGuid = @RunGuid
       AND c.PrimaryAddressGuid = a.Guid
    WHERE a.ID > 0
      AND a.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Addresses AS x
          WHERE x.RunGuid = @RunGuid
            AND x.AddressGuid = a.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       6. Identities
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Identities
    (
        RunGuid,
        IdentityGuid,
        RowStatus,
        FullName,
        EmailAddress,
        UserGuid,
        JobTitle,
        OrganisationalUnitGuid,
        IsActive,
        ContactGuid,
        BillableRate,
        Signature
    )
    SELECT DISTINCT
        @RunGuid,
        i.Guid,
        i.RowStatus,
        i.FullName,
        i.EmailAddress,
        i.UserGuid,
        i.JobTitle,
        ou.Guid,
        i.IsActive,
        c.Guid,
        i.BillableRate,
        i.Signature
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
        ON ug.IdentityID = i.ID
       AND ug.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = ug.GroupID
       AND g.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = i.OriganisationalUnitId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts AS c
        ON c.ID = i.ContactId
    WHERE i.RowStatus NOT IN (0,254)
      AND i.ID > 0
      AND i.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND g.Guid = @BusinessUnitGroupGuid;';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    /* ============================================================================================
       7. UserGroups
       ============================================================================================ */
    SET @sql = N'
    ;WITH SourceUserGroups AS
    (
        SELECT
            @RunGuid AS RunGuid,
            ug.Guid AS UserGroupGuid,
            ug.RowStatus,
            i.Guid AS IdentityGuid,
            g.Guid AS GroupGuid,
            ROW_NUMBER() OVER
            (
                PARTITION BY ug.Guid
                ORDER BY ug.ID
            ) AS DuplicateRank
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups AS ug
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities AS i
            ON i.ID = ug.IdentityID
           AND i.ID > 0
           AND i.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
            ON g.ID = ug.GroupID
           AND g.ID > 0
           AND g.RowStatus NOT IN (0,254)
        WHERE ug.RowStatus NOT IN (0,254)
          AND ug.ID > 0
          AND ug.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_Identities AS oi
              WHERE oi.RunGuid = @RunGuid
                AND oi.IdentityGuid = i.Guid
          )
          AND EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_Groups AS og
              WHERE og.RunGuid = @RunGuid
                AND og.GroupGuid = g.Guid
          )
    )
    INSERT INTO SMigration.Onboarding_UserGroups
    (
        RunGuid,
        UserGroupGuid,
        RowStatus,
        IdentityGuid,
        GroupGuid
    )
    SELECT
        sug.RunGuid,
        sug.UserGroupGuid,
        sug.RowStatus,
        sug.IdentityGuid,
        sug.GroupGuid
    FROM SourceUserGroups AS sug
    WHERE sug.DuplicateRank = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_UserGroups AS existing
          WHERE existing.RunGuid = sug.RunGuid
            AND existing.UserGroupGuid = sug.UserGroupGuid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

        
    /* ============================================================================================
       8. Workflows required by staged workflow notification groups.
       Do not filter wf.RowStatus here. See header note.
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Workflows
    (
        RunGuid,
        WorkflowGuid,
        RowStatus,
        OrganisationalUnitGuid,
        EntityTypeGuid,
        EntityHoBTGuid,
        Name,
        Description,
        Enabled
    )
    SELECT DISTINCT
        @RunGuid,
        wf.Guid,
        wf.RowStatus,
        ou.Guid,
        et.Guid,
        eh.Guid,
        wf.Name,
        wf.Description,
        wf.Enabled
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS wsng
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
        ON wf.ID = wsng.WorkflowID
       AND wf.ID > 0
       AND wf.Guid <> ''00000000-0000-0000-0000-000000000000''
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = wsng.GroupID
       AND g.RowStatus NOT IN (0,254)
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = wf.OrganisationalUnitId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityTypes AS et
        ON et.ID = wf.EntityTypeID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.EntityHoBTs AS eh
        ON eh.ID = wf.EntityHoBTID
    WHERE wsng.RowStatus NOT IN (0,254)
      AND wsng.ID > 0
      AND wsng.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Groups AS sg
          WHERE sg.RunGuid = @RunGuid
            AND sg.GroupGuid = g.Guid
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Workflows AS existing
          WHERE existing.RunGuid = @RunGuid
            AND existing.WorkflowGuid = wf.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

/* WorkflowStatuses required by staged workflows, transitions and notification groups */
    SET @sql = N'
    ;WITH WorkflowStatusGuids AS
    (
        SELECT DISTINCT fromWs.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowTransition AS wt
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wt.WorkflowID
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS fromWs
            ON fromWs.ID = wt.FromStatusID
           AND wt.FromStatusID > 0
        WHERE wt.ID > 0
          AND wt.RowStatus NOT IN (0,254)
          AND fromWs.RowStatus NOT IN (0,254)
          AND fromWs.Guid <> ''00000000-0000-0000-0000-000000000000''

        UNION

        SELECT DISTINCT toWs.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowTransition AS wt
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wt.WorkflowID
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS toWs
            ON toWs.ID = wt.ToStatusID
           AND wt.ToStatusID > 0
        WHERE wt.ID > 0
          AND wt.RowStatus NOT IN (0,254)
          AND toWs.RowStatus NOT IN (0,254)
          AND toWs.Guid <> ''00000000-0000-0000-0000-000000000000''

        UNION

        SELECT DISTINCT ws.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS wsng
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wsng.WorkflowID
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS ws
            ON ws.Guid = wsng.WorkflowStatusGuid
        WHERE wsng.ID > 0
          AND wsng.RowStatus NOT IN (0,254)
          AND ws.RowStatus NOT IN (0,254)
          AND ws.Guid <> ''00000000-0000-0000-0000-000000000000''

        UNION

        SELECT DISTINCT ws.Guid AS WorkflowStatusGuid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS ws
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
            ON ou.ID = ws.OrganisationalUnitId
        CROSS JOIN
        (
            SELECT OrgNode
            FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits
            WHERE Guid = @BusinessUnitOuGuid
        ) AS b
        WHERE ws.ID > 0
          AND ws.RowStatus NOT IN (0,254)
          AND ws.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND
          (
              ws.OrganisationalUnitId = -1
              OR ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
          )
    )
    INSERT INTO SMigration.Onboarding_WorkflowStatuses
    (
        RunGuid,
        WorkflowStatusGuid,
        RowStatus,
        OrganisationalUnitGuid,
        Name,
        Description,
        ShowInEnquiries,
        ShowInQuotes,
        ShowInJobs,
        Enabled,
        IsPredefined,
        SortOrder,
        Colour,
        Icon,
        SendNotification,
        IsCompleteStatus,
        IsCustomerWaitingStatus,
        RequiresUsersAction,
        IsActiveStatus,
        AuthorisationNeeded,
        IsAuthStatus
    )
    SELECT DISTINCT
        @RunGuid,
        ws.Guid,
        ws.RowStatus,
        ou.Guid,
        ws.Name,
        ws.Description,
        ws.ShowInEnquiries,
        ws.ShowInQuotes,
        ws.ShowInJobs,
        ws.Enabled,
        ws.IsPredefined,
        ws.SortOrder,
        ws.Colour,
        ws.Icon,
        ws.SendNotification,
        ws.IsCompleteStatus,
        ws.IsCustomerWaitingStatus,
        ws.RequiresUsersAction,
        ws.IsActiveStatus,
        ws.AuthorisationNeeded,
        ws.IsAuthStatus
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS ws
    INNER JOIN WorkflowStatusGuids AS relevant
        ON relevant.WorkflowStatusGuid = ws.Guid
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = ws.OrganisationalUnitId
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_WorkflowStatuses AS existing
        WHERE existing.RunGuid = @RunGuid
          AND existing.WorkflowStatusGuid = ws.Guid
    );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

/* WorkflowTransitions for staged workflows */
        SET @sql = N'
        INSERT INTO SMigration.Onboarding_WorkflowTransitions
        (
            RunGuid,
            WorkflowTransitionGuid,
            RowStatus,
            WorkflowGuid,
            FromStatusGuid,
            ToStatusGuid,
            IsFinal,
            Enabled,
            SortOrder,
            Description
        )
        SELECT
            @RunGuid,
            wt.Guid,
            wt.RowStatus,
            wf.Guid,
            ISNULL(fromWs.Guid, ''00000000-0000-0000-0000-000000000000''),
            ISNULL(toWs.Guid, ''00000000-0000-0000-0000-000000000000''),
            wt.IsFinal,
            wt.Enabled,
            wt.SortOrder,
            ISNULL(wt.Description, N'''')
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowTransition AS wt
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
            ON wf.ID = wt.WorkflowID
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS fromWs
            ON fromWs.ID = wt.FromStatusID
           AND wt.FromStatusID > 0
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatus AS toWs
            ON toWs.ID = wt.ToStatusID
           AND wt.ToStatusID > 0
        INNER JOIN SMigration.Onboarding_Workflows AS sw
            ON sw.RunGuid = @RunGuid
           AND sw.WorkflowGuid = wf.Guid
        WHERE wt.ID > 0
          AND wt.RowStatus NOT IN (0,254)
          AND wt.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_WorkflowTransitions AS existing
              WHERE existing.RunGuid = @RunGuid
                AND existing.WorkflowTransitionGuid = wt.Guid
          );
        ';

        EXEC sp_executesql
            @sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;

    /* ============================================================================================
       9. WorkflowStatusNotificationGroups
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_WorkflowStatusNotificationGroups
    (
        RunGuid,
        WorkflowNotificationGroupGuid,
        RowStatus,
        WorkflowGuid,
        WorkflowStatusGuid,
        GroupGuid,
        CanAction
    )
    SELECT DISTINCT
        @RunGuid,
        x.Guid,
        x.RowStatus,
        wf.Guid,
        x.WorkflowStatusGuid,
        g.Guid,
        x.CanAction
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups AS x
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow AS wf
        ON wf.ID = x.WorkflowID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        ON g.ID = x.GroupID
    WHERE x.RowStatus NOT IN (0,254)
      AND x.ID > 0
      AND x.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Groups AS sg
          WHERE sg.RunGuid = @RunGuid
            AND sg.GroupGuid = g.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       10. JobTypes under staged OUs
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypes
    (
        RunGuid,
        JobTypeGuid,
        RowStatus,
        Name,
        IsActive,
        SequenceID,
        UseTimeSheets,
        UsePlanChecks,
        OrganisationalUnitGuid
    )
    SELECT DISTINCT
        @RunGuid,
        jt.Guid,
        jt.RowStatus,
        jt.Name,
        jt.IsActive,
        jt.SequenceID,
        jt.UseTimeSheets,
        jt.UsePlanChecks,
        ou.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
        ON ou.ID = jt.OrganisationalUnitID
    WHERE jt.RowStatus NOT IN (0,254)
      AND jt.ID > 0
      AND jt.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_OrganisationalUnits AS sou
          WHERE sou.RunGuid = @RunGuid
            AND sou.OrganisationalUnitGuid = ou.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS businessUnit
          WHERE businessUnit.Guid = @BusinessUnitOuGuid
            AND businessUnit.ID > 0
            AND ou.OrgNode.IsDescendantOf(businessUnit.OrgNode) = 1
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* ============================================================================================
       11. ActivityTypes only those used by staged jobtypes
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_ActivityTypes
    (
        RunGuid,
        ActivityTypeGuid,
        RowStatus,
        Name,
        IsActive,
        SortOrder,
        IsFeeTrigger,
        IsLiveTrigger,
        IsAdmin,
        IsScheduleItem,
        Colour,
        IsMeeting,
        IsSiteVisit,
        IsBillable,
        IsCommencementTrigger
    )
    SELECT DISTINCT
        @RunGuid,
        at.Guid,
        at.RowStatus,
        at.Name,
        at.IsActive,
        at.SortOrder,
        at.IsFeeTrigger,
        at.IsLiveTrigger,
        at.IsAdmin,
        at.IsScheduleItem,
        at.Colour,
        at.IsMeeting,
        at.IsSiteVisit,
        at.IsBillable,
        at.IsCommencementTrigger
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.ActivityTypes AS at
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes AS jtat
        ON jtat.ActivityTypeID = at.ID
       AND jtat.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtat.JobTypeID
    WHERE at.RowStatus NOT IN (0,254)
      AND at.ID > 0
      AND at.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       12. MilestoneTypes only those used by staged jobtypes
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_MilestoneTypes
    (
        RunGuid,
        MilestoneTypeGuid,
        RowStatus,
        Code,
        Name,
        IsActive,
        IsInvoiceTrigger,
        IsReviewRequired,
        HelpText,
        HasQuotedHours,
        HasDescription,
        HasReference,
        IsCompulsory,
        IncludeStart,
        IncludeSchedule,
        IncludeDueDate,
        HasExternalSubmission
    )
    SELECT DISTINCT
        @RunGuid,
        mt.Guid,
        mt.RowStatus,
        mt.Code,
        mt.Name,
        mt.IsActive,
        mt.IsInvoiceTrigger,
        mt.IsReviewRequired,
        mt.HelpText,
        mt.HasQuotedHours,
        mt.HasDescription,
        mt.HasReference,
        mt.IsCompulsory,
        mt.IncludeStart,
        mt.IncludeSchedule,
        mt.IncludeDueDate,
        mt.HasExternalSubmission
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.MilestoneTypes AS mt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates AS jtmt
        ON jtmt.MilestoneTypeID = mt.ID
       AND jtmt.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtmt.JobTypeID
    WHERE mt.RowStatus NOT IN (0,254)
      AND mt.ID > 0
      AND mt.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       13. JobTypeActivityTypes
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypeActivityTypes
    (
        RunGuid,
        JobTypeActivityTypeGuid,
        RowStatus,
        JobTypeGuid,
        ActivityTypeGuid
    )
    SELECT DISTINCT
        @RunGuid,
        jtat.Guid,
        jtat.RowStatus,
        jt.Guid,
        at.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes AS jtat
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtat.JobTypeID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.ActivityTypes AS at
        ON at.ID = jtat.ActivityTypeID
    WHERE jtat.RowStatus NOT IN (0,254)
      AND jtat.ID > 0
      AND jtat.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_ActivityTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.ActivityTypeGuid = at.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       14. JobTypeMilestoneTemplates
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypeMilestoneTemplates
    (
        RunGuid,
        JobTypeMilestoneTemplateGuid,
        RowStatus,
        JobTypeGuid,
        MilestoneTypeGuid,
        Description,
        SortOrder
    )
    SELECT DISTINCT
        @RunGuid,
        jtmt.Guid,
        jtmt.RowStatus,
        jt.Guid,
        mt.Guid,
        jtmt.Description,
        jtmt.SortOrder
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates AS jtmt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
        ON jt.ID = jtmt.JobTypeID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.MilestoneTypes AS mt
        ON mt.ID = jtmt.MilestoneTypeID
    WHERE jtmt.RowStatus NOT IN (0,254)
      AND jtmt.ID > 0
      AND jtmt.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeGuid = jt.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_MilestoneTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.MilestoneTypeGuid = mt.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       15. Products
       ============================================================================================ */
    /* Products for staged job types */
        SET @sql = N'
        INSERT INTO SMigration.Onboarding_Products
        (
            RunGuid,
            ProductGuid,
            RowStatus,
            Code,
            Description,
            CreatedJobTypeGuid,
            NeverConsolidate,
            RibaStageGuid
        )
        SELECT DISTINCT
            @RunGuid,
            p.Guid,
            p.RowStatus,
            p.Code,
            p.Description,
            jt.Guid,
            p.NeverConsolidate,
            ISNULL(rs.Guid, ''00000000-0000-0000-0000-000000000000'')
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SProd.Products AS p
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes AS jt
            ON jt.ID = p.CreatedJobType
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.RibaStages AS rs
            ON rs.ID = p.RibaStageId
        INNER JOIN SMigration.Onboarding_JobTypes AS sjt
            ON sjt.RunGuid = @RunGuid
           AND sjt.JobTypeGuid = jt.Guid
        WHERE p.ID > 0
          AND p.RowStatus NOT IN (0,254)
          AND p.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_Products AS existing
              WHERE existing.RunGuid = @RunGuid
                AND existing.ProductGuid = p.Guid
          );
        ';

        EXEC sp_executesql
            @sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;

    /* ============================================================================================
       16. ProductJobActivities
       ============================================================================================ */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_ProductJobActivities
    (
        RunGuid,
        ProductJobActivityGuid,
        RowStatus,
        ProductGuid,
        JobTypeActivityTypeGuid,
        ActivityTitle,
        OffsetDays,
        OffsetWeeks,
        OffsetMonths,
        JobTypeMilestoneTemplateGuid,
        PercentageOfProductValue
    )
    SELECT DISTINCT
        @RunGuid,
        pja.Guid,
        pja.RowStatus,
        p.Guid,
        jtat.Guid,
        pja.ActivityTitle,
        pja.OffsetDays,
        pja.OffsetWeeks,
        pja.OffsetMonths,
        jtmt.Guid,
        pja.PercentageOfProductValue
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.ProductJobActivities AS pja
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SProd.Products AS p
        ON p.ID = pja.ProductId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes AS jtat
        ON jtat.ID = pja.JobTypeActivityTypeId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates AS jtmt
        ON jtmt.ID = pja.JobTypeMilestoneTemplateId
    WHERE pja.RowStatus NOT IN (0,254)
      AND pja.ID > 0
      AND pja.Guid <> ''00000000-0000-0000-0000-000000000000''
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_Products AS s
          WHERE s.RunGuid = @RunGuid
            AND s.ProductGuid = p.Guid
      )
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_JobTypeActivityTypes AS s
          WHERE s.RunGuid = @RunGuid
            AND s.JobTypeActivityTypeGuid = jtat.Guid
      );';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid;

    /* ============================================================================================
       Apply persisted run entity scope before counts/validation/apply.
       This preserves the existing full scope when no run-specific selections exist.
       ============================================================================================ */
    EXEC SMigration.OnboardingRunEntitySelection_ApplyToStage @RunGuid = @RunGuid;

    /* ============================================================================================
       Stage execution log counts
       ============================================================================================ */
    DECLARE @c INT;

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Groups', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'OrganisationalUnits', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Addresses', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Contacts', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Identities', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'UserGroups', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Workflows', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatuses WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowStatuses', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowTransitions', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'WorkflowStatusNotificationGroups', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'ActivityTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'MilestoneTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypeActivityTypes', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'JobTypeMilestoneTemplates', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'Products', N'Stage', @c, N'';

    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
    EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'ProductJobActivities', N'Stage', @c, N'';

    /* ============================================================================================
       Stage summary output
       ============================================================================================ */
    SELECT
        RunGuid = @RunGuid,
        GroupCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid),
        IdentityCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid),
        UserGroupCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid),
        WorkflowCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Workflows WHERE RunGuid = @RunGuid),
        WorkflowTransitionCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowTransitions WHERE RunGuid = @RunGuid),
        WorkflowNotificationGroupCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid),
        JobTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid),
        ActivityTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid),
        MilestoneTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid),
        ProductCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid),
        JobTypeActivityTypeCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid),
        JobTypeMilestoneTemplateCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid),
        ProductJobActivityCount =
            (SELECT COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid);
END
GO

GO

/* Post-structure preflight Constraint SUserInterface.UK_Icons_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SUserInterface.Icons.UK_Icons_Guid
    Difference         : Different
    Comparison hash    : E97635C3A93E5D52E26734F7FCF26D1287A4C629737297E4703E137680267A8D
    Definition SHA-256 : 5299AD4CF96CDD0E94E41CCF0709BD703FF41FA5742902F360856D3DEDC26A11
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SUserInterface].[Icons]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SUserInterface.Icons does not exist.', 1;
IF COL_LENGTH(N'[SUserInterface].[Icons]', N'Guid') IS NULL
    THROW 51405, 'Key-constraint column SUserInterface.Icons.Guid does not exist.', 1;
IF EXISTS (SELECT [Guid] FROM [SUserInterface].[Icons] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1)
    THROW 51407, 'Key constraint UK_Icons_Guid cannot be created because duplicate key values exist.', 1;
GO

GO

/* Post-structure preflight Index SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid
    Difference         : Different
    Comparison hash    : 745FC68E5AD42D12964C4C8974BF55DB3BE82F1107EBB71034BF97C468ACF301
    Definition SHA-256 : E9DF89D60524F3EDC6DE8A9702FC7BEF8A0D23D3C2A33902CE84A495A1630DB1
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SJob].[ActivityTypes]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SJob].[ActivityTypes]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SJob].[ActivityTypes] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name
    Difference         : Different
    Comparison hash    : 139B79A0347C711B3C48857D26DE0DDD4A47CCA6567B3DB0D2DDD0AB58D0A9F2
    Definition SHA-256 : 8BBD997E88B0C32849B9F4B34C6B3E7A5B2AD7E5A4C0F5743E3A247D8E9F651E
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SJob].[ProjectDirectoryRoles]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SJob].[ProjectDirectoryRoles]', N'RowStatus') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF COL_LENGTH(N'[SJob].[ProjectDirectoryRoles]', N'Name') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [RowStatus], [Name] FROM [SJob].[ProjectDirectoryRoles] WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254)) GROUP BY [RowStatus], [Name] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud
    Difference         : Different
    Comparison hash    : 16A5B8FE77DD931A5CDD64476A8B43FF66A013C0C8BD16C6862F9478673CC298
    Definition SHA-256 : 931CDE0A02A471EB31E8CDE9B4E086A814E34190A71753BDC72FF17A856D1446
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SUserInterface].[ActionMenuItems]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SUserInterface].[ActionMenuItems]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SUserInterface].[ActionMenuItems] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SUserInterface.Icons.IX_UQ_MetricTypes_Name */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.Icons.IX_UQ_MetricTypes_Name
    Difference         : Different
    Comparison hash    : EE1D76B1676B7D5D6C205542935303315E4946377C4019DB2C4BA578A771ACEA
    Definition SHA-256 : 625F8DA516CC6D4D08F6426554BB46B51CE1FAEC9EEE2E0D63CEFB2FF2E3ADCB
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SUserInterface].[Icons]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SUserInterface].[Icons]', N'Name') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Name] FROM [SUserInterface].[Icons] GROUP BY [Name] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid
    Difference         : Different
    Comparison hash    : 1D0FBF60FB88C403E54CB6EC4EA006C2146AC380F8E8377B5B488DBA6CCABC80
    Definition SHA-256 : 11E0AC9C6412EC3C4AEF1B33EF20DF95CA7CE44BADCFDDBAB4EF853FCB1D181F
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SUserInterface].[WidgetDashboards]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SUserInterface].[WidgetDashboards]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'METADATA') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SUserInterface].[WidgetDashboards] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid
    Difference         : Different
    Comparison hash    : 23579467C0A0D4D896205D753D51DA2654D4047A14A238E74FD1C2287DA26CC4
    Definition SHA-256 : 0E075C72CB73E04CBBE8809D773F8225B13F500BE17D4C266A63F53DA4378364
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SUserInterface].[WidgetDashboardWidgetTypes]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SUserInterface].[WidgetDashboardWidgetTypes]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'METADATA') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SUserInterface].[WidgetDashboardWidgetTypes] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid
    Difference         : Different
    Comparison hash    : 05FEC715E4BB8ABC6DDDA359EDF123320514D611C36C226A5C0E8DF0621D3377
    Definition SHA-256 : 1CD55E549F011B8ABD85C6458E90111CCB61C52F3D73C4E29977F38C3FEC0D09
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SUserInterface].[WidgetTypes]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SUserInterface].[WidgetTypes]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'METADATA') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SUserInterface].[WidgetTypes] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Deploy Index SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SJob.ActivityTypes.IX_UQ_ActivityTypes_Guid
    Difference         : Different
    Comparison hash    : 745FC68E5AD42D12964C4C8974BF55DB3BE82F1107EBB71034BF97C468ACF301
    Definition SHA-256 : E9DF89D60524F3EDC6DE8A9702FC7BEF8A0D23D3C2A33902CE84A495A1630DB1
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ActivityTypes_Guid] ON [SJob].[ActivityTypes] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [PRIMARY];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SJob.ProjectDirectoryRoles.IX_UQ_ProjectDirectoryRoles_Name
    Difference         : Different
    Comparison hash    : 139B79A0347C711B3C48857D26DE0DDD4A47CCA6567B3DB0D2DDD0AB58D0A9F2
    Definition SHA-256 : 8BBD997E88B0C32849B9F4B34C6B3E7A5B2AD7E5A4C0F5743E3A247D8E9F651E
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ProjectDirectoryRoles_Name] ON [SJob].[ProjectDirectoryRoles] ([RowStatus] ASC, [Name] ASC) WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254)) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [PRIMARY];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.ActionMenuItems.IX_UQ_ActionMenuItems_Gud
    Difference         : Different
    Comparison hash    : 16A5B8FE77DD931A5CDD64476A8B43FF66A013C0C8BD16C6862F9478673CC298
    Definition SHA-256 : 931CDE0A02A471EB31E8CDE9B4E086A814E34190A71753BDC72FF17A856D1446
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ActionMenuItems_Gud] ON [SUserInterface].[ActionMenuItems] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [PRIMARY];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SUserInterface.Icons.IX_UQ_MetricTypes_Name using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.Icons.IX_UQ_MetricTypes_Name.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.Icons.IX_UQ_MetricTypes_Name
    Difference         : Different
    Comparison hash    : EE1D76B1676B7D5D6C205542935303315E4946377C4019DB2C4BA578A771ACEA
    Definition SHA-256 : 625F8DA516CC6D4D08F6426554BB46B51CE1FAEC9EEE2E0D63CEFB2FF2E3ADCB
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MetricTypes_Name] ON [SUserInterface].[Icons] ([Name] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [PRIMARY];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetDashboards.IX_UQ_WidgetDashboards_Guid
    Difference         : Different
    Comparison hash    : 1D0FBF60FB88C403E54CB6EC4EA006C2146AC380F8E8377B5B488DBA6CCABC80
    Definition SHA-256 : 11E0AC9C6412EC3C4AEF1B33EF20DF95CA7CE44BADCFDDBAB4EF853FCB1D181F
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetDashboards_Guid] ON [SUserInterface].[WidgetDashboards] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [METADATA];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetDashboardWidgetTypes.IX_UQ_WidgetDashboardWidgetTypes_Guid
    Difference         : Different
    Comparison hash    : 23579467C0A0D4D896205D753D51DA2654D4047A14A238E74FD1C2287DA26CC4
    Definition SHA-256 : 0E075C72CB73E04CBBE8809D773F8225B13F500BE17D4C266A63F53DA4378364
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetDashboardWidgetTypes_Guid] ON [SUserInterface].[WidgetDashboardWidgetTypes] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [METADATA];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid using IndexReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SUserInterface.WidgetTypes.IX_UQ_WidgetTypes_Guid
    Difference         : Different
    Comparison hash    : 05FEC715E4BB8ABC6DDDA359EDF123320514D611C36C226A5C0E8DF0621D3377
    Definition SHA-256 : 1CD55E549F011B8ABD85C6458E90111CCB61C52F3D73C4E29977F38C3FEC0D09
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetTypes_Guid] ON [SUserInterface].[WidgetTypes] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DROP_EXISTING = ON) ON [METADATA];
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Constraint SUserInterface.UK_Icons_Guid using ConstraintReplace from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SUserInterface.Icons.UK_Icons_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SUserInterface.Icons.UK_Icons_Guid
    Difference         : Different
    Comparison hash    : E97635C3A93E5D52E26734F7FCF26D1287A4C629737297E4703E137680267A8D
    Definition SHA-256 : 5299AD4CF96CDD0E94E41CCF0709BD703FF41FA5742902F360856D3DEDC26A11
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SUserInterface].[Icons]', N'U')
      AND constraintObject.name = N'UK_Icons_Guid'
)
    BEGIN
        ALTER TABLE [SUserInterface].[Icons] ADD CONSTRAINT [UK_Icons_Guid] UNIQUE NONCLUSTERED ([Guid] ASC) WITH (PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100) ON [METADATA];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO
DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();
EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;
GO
