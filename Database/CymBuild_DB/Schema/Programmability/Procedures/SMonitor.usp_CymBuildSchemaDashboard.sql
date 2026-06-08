SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMonitor].[usp_CymBuildSchemaDashboard]')
GO

CREATE PROCEDURE [SMonitor].[usp_CymBuildSchemaDashboard]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SnapshotUtc DATETIME2(3) = SYSUTCDATETIME();

    /* =========================================================================
       A) Summary KPIs
    ========================================================================= */
    ;WITH MonitoredSchemas AS
    (
        SELECT s.schema_id, s.name
        FROM sys.schemas s
        WHERE s.name IN (N'SCore', N'SJob', N'SFin', N'SSop')
    ),
    MonitoredObjects AS
    (
        SELECT
            sc.name AS SchemaName,
            o.object_id,
            o.name AS ObjectName,
            o.type,
            o.type_desc
        FROM sys.objects o
        INNER JOIN MonitoredSchemas sc
            ON sc.schema_id = o.schema_id
        WHERE o.is_ms_shipped = 0
    ),
    SchemaBoundObjects AS
    (
        SELECT
            mo.SchemaName,
            mo.ObjectName,
            mo.type,
            mo.type_desc,
            ISNULL(sm.is_schema_bound, 0) AS is_schema_bound
        FROM MonitoredObjects mo
        LEFT JOIN sys.sql_modules sm
            ON sm.object_id = mo.object_id
        WHERE mo.type IN (N'V', N'IF', N'TF', N'FN')
    ),
    LargestTable AS
    (
        SELECT TOP (1)
            sch.name AS SchemaName,
            t.name AS TableName,
            SUM(ps.row_count) AS [ROWCOUNT],
            CAST(SUM(a.total_pages) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS ReservedMB
        FROM sys.tables t
        INNER JOIN sys.schemas sch
            ON sch.schema_id = t.schema_id
        INNER JOIN sys.indexes i
            ON i.object_id = t.object_id
        INNER JOIN sys.partitions p
            ON p.object_id = i.object_id
           AND p.index_id = i.index_id
        INNER JOIN sys.allocation_units a
            ON a.container_id = p.partition_id
        INNER JOIN sys.dm_db_partition_stats ps
            ON ps.object_id = t.object_id
           AND ps.index_id IN (0,1)
        WHERE sch.name IN (N'SCore', N'SJob', N'SFin', N'SSop')
        GROUP BY sch.name, t.name
        ORDER BY ReservedMB DESC, [ROWCOUNT] DESC, sch.name, t.name
    )
    SELECT
        @SnapshotUtc AS SnapshotUtc,
        4 AS SchemasMonitored,
        (SELECT COUNT(*) FROM MonitoredObjects) AS TotalObjectsMonitored,
        (SELECT COUNT(*) FROM MonitoredObjects WHERE type = N'U') AS TableCount,
        (SELECT COUNT(*) FROM MonitoredObjects WHERE type = N'V') AS ViewCount,
        (SELECT COUNT(*) FROM MonitoredObjects WHERE type IN (N'P', N'PC')) AS ProcedureCount,
        (SELECT COUNT(*) FROM MonitoredObjects WHERE type IN (N'IF', N'TF', N'FN')) AS FunctionCount,
        (SELECT COUNT(*) FROM SchemaBoundObjects WHERE is_schema_bound = 0) AS NonSchemaBoundObjectCount,
        (SELECT TOP 1 CONCAT(SchemaName, N'.', TableName) FROM LargestTable) AS LargestTableName,
        (SELECT TOP 1 [ROWCOUNT] FROM LargestTable) AS LargestTableRowCount,
        (SELECT TOP 1 ReservedMB FROM LargestTable) AS LargestTableReservedMB;

    /* =========================================================================
       B) Object counts by schema and type
    ========================================================================= */
    SELECT
        s.name AS SchemaName,
        SUM(CASE WHEN o.type = N'U' THEN 1 ELSE 0 END) AS TableCount,
        SUM(CASE WHEN o.type = N'V' THEN 1 ELSE 0 END) AS ViewCount,
        SUM(CASE WHEN o.type IN (N'P', N'PC') THEN 1 ELSE 0 END) AS ProcedureCount,
        SUM(CASE WHEN o.type IN (N'IF', N'TF', N'FN') THEN 1 ELSE 0 END) AS FunctionCount,
        COUNT(*) AS TotalObjectCount
    FROM sys.schemas s
    LEFT JOIN sys.objects o
        ON o.schema_id = s.schema_id
       AND o.is_ms_shipped = 0
       AND o.type IN (N'U', N'V', N'P', N'PC', N'IF', N'TF', N'FN')
    WHERE s.name IN (N'SCore', N'SJob', N'SFin', N'SSop')
    GROUP BY s.name
    ORDER BY s.name;

    /* =========================================================================
       C) Core integrity checks
    ========================================================================= */
    ;WITH Checks AS
    (
        SELECT N'SCore.DataObjects exists' AS CheckName, CASE WHEN OBJECT_ID(N'SCore.DataObjects', N'U') IS NOT NULL THEN 1 ELSE 0 END AS IsOk, N'Core identity layer table' AS Detail
        UNION ALL
        SELECT N'SCore.Workflow exists', CASE WHEN OBJECT_ID(N'SCore.Workflow', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Workflow definition table'
        UNION ALL
        SELECT N'SCore.WorkflowStatus exists', CASE WHEN OBJECT_ID(N'SCore.WorkflowStatus', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Workflow status table'
        UNION ALL
        SELECT N'SCore.DataObjectTransition exists', CASE WHEN OBJECT_ID(N'SCore.DataObjectTransition', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Status transition history table'
        UNION ALL
        SELECT N'SCore.IntegrationOutbox exists', CASE WHEN OBJECT_ID(N'SCore.IntegrationOutbox', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Integration outbox table'
        UNION ALL
        SELECT N'SCore.WorkflowStatusNotificationGroups exists', CASE WHEN OBJECT_ID(N'SCore.WorkflowStatusNotificationGroups', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Workflow notification routing table'
        UNION ALL
        SELECT N'SFin.InvoiceScheduleTriggerInstances exists', CASE WHEN OBJECT_ID(N'SFin.InvoiceScheduleTriggerInstances', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Invoice automation trigger ledger'
        UNION ALL
        SELECT N'SSop.Quotes exists', CASE WHEN OBJECT_ID(N'SSop.Quotes', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Quote master table'
        UNION ALL
        SELECT N'SJob.Jobs exists', CASE WHEN OBJECT_ID(N'SJob.Jobs', N'U') IS NOT NULL THEN 1 ELSE 0 END, N'Jobs master table'
    )
    SELECT
        CheckName,
        CAST(IsOk AS bit) AS IsOk,
        CASE WHEN IsOk = 1 THEN N'OK' ELSE N'Missing' END AS StatusText,
        Detail
    FROM Checks
    ORDER BY CheckName;

    /* =========================================================================
       D) Largest tables by size / rows
    ========================================================================= */
    ;WITH TableStats AS
    (
        SELECT
            sch.name AS SchemaName,
            t.name AS TableName,
            SUM(CASE WHEN ps.index_id IN (0,1) THEN ps.row_count ELSE 0 END) AS [ROWCOUNT],
            CAST(SUM(a.total_pages) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS ReservedMB,
            CAST(SUM(a.used_pages) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS UsedMB,
            CAST(SUM(CASE WHEN i.index_id IN (0,1) THEN a.data_pages ELSE 0 END) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS DataMB,
            CAST((SUM(a.used_pages) - SUM(CASE WHEN i.index_id IN (0,1) THEN a.data_pages ELSE 0 END)) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS IndexMB
        FROM sys.tables t
        INNER JOIN sys.schemas sch
            ON sch.schema_id = t.schema_id
        INNER JOIN sys.indexes i
            ON i.object_id = t.object_id
        INNER JOIN sys.partitions p
            ON p.object_id = i.object_id
           AND p.index_id = i.index_id
        INNER JOIN sys.allocation_units a
            ON a.container_id = p.partition_id
        INNER JOIN sys.dm_db_partition_stats ps
            ON ps.object_id = t.object_id
           AND ps.index_id = i.index_id
        WHERE sch.name IN (N'SCore', N'SJob', N'SFin', N'SSop')
        GROUP BY sch.name, t.name
    )
    SELECT TOP (25)
        SchemaName,
        TableName,
        [ROWCOUNT],
        ReservedMB,
        UsedMB,
        DataMB,
        IndexMB
    FROM TableStats
    ORDER BY ReservedMB DESC, [ROWCOUNT] DESC, SchemaName, TableName;

    /* =========================================================================
       E) Schema-bound status for views/functions
    ========================================================================= */
    SELECT
        sch.name AS SchemaName,
        o.name AS ObjectName,
        o.type AS ObjectType,
        o.type_desc AS ObjectTypeDesc,
        CAST(ISNULL(sm.is_schema_bound, 0) AS bit) AS IsSchemaBound,
        CASE
            WHEN ISNULL(sm.is_schema_bound, 0) = 1 THEN N'Schema bound'
            ELSE N'Not schema bound'
        END AS StatusText
    FROM sys.objects o
    INNER JOIN sys.schemas sch
        ON sch.schema_id = o.schema_id
    LEFT JOIN sys.sql_modules sm
        ON sm.object_id = o.object_id
    WHERE sch.name IN (N'SCore', N'SJob', N'SFin', N'SSop')
      AND o.is_ms_shipped = 0
      AND o.type IN (N'V', N'IF', N'TF', N'FN')
    ORDER BY
        CASE WHEN ISNULL(sm.is_schema_bound, 0) = 0 THEN 0 ELSE 1 END,
        sch.name,
        o.type_desc,
        o.name;
END
GO