SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

PRINT (N'Create or alter procedure [SMigration].[MetadataRegistry_SyncFromEntityTypes]')
GO

PRINT (N'Create procedure [SMigration].[MetadataRegistry_SyncFromEntityTypes]')
GO
PRINT (N'Create procedure [SMigration].[MetadataRegistry_SyncFromEntityTypes]')
GO
PRINT (N'Create procedure [SMigration].[MetadataRegistry_SyncFromEntityTypes]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRegistry_SyncFromEntityTypes]')
GO

CREATE PROCEDURE [SMigration].[MetadataRegistry_SyncFromEntityTypes]
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