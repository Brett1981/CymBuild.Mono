SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMonitor].[usp_WaitStatsDashboard]')
GO

/* =============================================================================
   4) Main dashboard procedure
============================================================================= */
CREATE PROCEDURE [SMonitor].[usp_WaitStatsDashboard]
    @TopCount INT = 15,
    @CpuPressureSignalThresholdPct DECIMAL(9,2) = 25.00
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SqlStartTime DATETIME2(3);
    DECLARE @SnapshotUtc DATETIME2(3) = SYSUTCDATETIME();

    SELECT @SqlStartTime = sqlserver_start_time
    FROM sys.dm_os_sys_info;

    /* -------------------------------------------------------------------------
       A) Cumulative waits since SQL restart
    ------------------------------------------------------------------------- */
    ;WITH RawWaits AS
    (
        SELECT
            ws.wait_type,
            ws.waiting_tasks_count,
            ws.wait_time_ms,
            ws.max_wait_time_ms,
            ws.signal_wait_time_ms,
            CAST(ws.wait_time_ms - ws.signal_wait_time_ms AS BIGINT) AS resource_wait_time_ms
        FROM sys.dm_os_wait_stats ws
        WHERE ws.waiting_tasks_count > 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMonitor.WaitStatsExclusions ex
              WHERE ex.WaitType = ws.wait_type
          )
    ),
    Categorised AS
    (
        SELECT
            rw.wait_type,
            rw.waiting_tasks_count,
            rw.wait_time_ms,
            rw.max_wait_time_ms,
            rw.signal_wait_time_ms,
            rw.resource_wait_time_ms,
            CAST(rw.wait_time_ms * 1.0 / NULLIF(rw.waiting_tasks_count, 0) AS DECIMAL(18,2)) AS avg_wait_ms_per_task,
            CASE
                WHEN rw.wait_type LIKE N'SOS_SCHEDULER_%'
                  OR rw.wait_type IN (N'THREADPOOL', N'CXPACKET', N'CXCONSUMER')
                    THEN N'CPU'
                WHEN rw.wait_type LIKE N'PAGEIOLATCH_%'
                  OR rw.wait_type LIKE N'ASYNC_IO_COMPLETION'
                  OR rw.wait_type LIKE N'IO_COMPLETION'
                  OR rw.wait_type LIKE N'WRITELOG'
                  OR rw.wait_type LIKE N'LOGBUFFER'
                  OR rw.wait_type LIKE N'LOGBUFFER'
                  OR rw.wait_type LIKE N'BACKUPIO'
                  OR rw.wait_type LIKE N'READ_COMPLETION'
                    THEN N'I/O'
                WHEN rw.wait_type LIKE N'RESOURCE_SEMAPHORE%'
                  OR rw.wait_type LIKE N'MEMORY_%'
                  OR rw.wait_type IN (N'CMEMTHREAD', N'CMEMPARTITIONED', N'EE_PMOLOCK', N'RESERVED_MEMORY_ALLOCATION_EXT')
                    THEN N'Memory'
                ELSE N'Other'
            END AS WaitCategory
        FROM RawWaits rw
    ),
    Totals AS
    (
        SELECT
            SUM(wait_time_ms) AS total_wait_time_ms,
            SUM(signal_wait_time_ms) AS total_signal_wait_time_ms,
            SUM(resource_wait_time_ms) AS total_resource_wait_time_ms
        FROM Categorised
    ),
    Ranked AS
    (
        SELECT
            c.wait_type,
            c.WaitCategory,
            c.waiting_tasks_count,
            c.wait_time_ms,
            c.max_wait_time_ms,
            c.signal_wait_time_ms,
            c.resource_wait_time_ms,
            c.avg_wait_ms_per_task,
            CAST(c.wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS pct_of_total_wait_time,
            CAST(c.signal_wait_time_ms * 100.0 / NULLIF(c.wait_time_ms, 0) AS DECIMAL(9,2)) AS pct_signal_within_wait,
            ROW_NUMBER() OVER (ORDER BY c.wait_time_ms DESC, c.wait_type ASC) AS rn
        FROM Categorised c
        CROSS JOIN Totals t
    )
    SELECT
        @SnapshotUtc AS SnapshotUtc,
        DB_NAME() AS DatabaseName,
        @@SERVERNAME AS ServerName,
        @SqlStartTime AS SqlServerStartTime,
        DATEDIFF(SECOND, @SqlStartTime, @SnapshotUtc) AS SecondsSinceRestart,
        t.total_wait_time_ms AS TotalWaitTimeMs,
        CAST(t.total_wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS TotalWaitTimeSeconds,
        t.total_signal_wait_time_ms AS TotalSignalWaitTimeMs,
        CAST(t.total_signal_wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS TotalSignalWaitTimeSeconds,
        t.total_resource_wait_time_ms AS TotalResourceWaitTimeMs,
        CAST(t.total_resource_wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS TotalResourceWaitTimeSeconds,
        CAST(t.total_signal_wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS SignalWaitPct,
        CAST(t.total_resource_wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS ResourceWaitPct,
        CASE
            WHEN CAST(t.total_signal_wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) > @CpuPressureSignalThresholdPct
                THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS IsCpuPressureHighlighted,
        CASE
            WHEN CAST(t.total_signal_wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) > @CpuPressureSignalThresholdPct
                THEN N'CPU pressure highlighted: signal waits exceed configured threshold.'
            ELSE N'CPU pressure not highlighted.'
        END AS CpuPressureMessage
    FROM Totals t;

    /* -------------------------------------------------------------------------
       B) Wait category distribution (for donut / bar charts)
    ------------------------------------------------------------------------- */
    ;WITH RawWaits AS
    (
        SELECT
            ws.wait_type,
            ws.waiting_tasks_count,
            ws.wait_time_ms,
            ws.signal_wait_time_ms,
            CAST(ws.wait_time_ms - ws.signal_wait_time_ms AS BIGINT) AS resource_wait_time_ms
        FROM sys.dm_os_wait_stats ws
        WHERE ws.waiting_tasks_count > 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMonitor.WaitStatsExclusions ex
              WHERE ex.WaitType = ws.wait_type
          )
    ),
    Categorised AS
    (
        SELECT
            CASE
                WHEN rw.wait_type LIKE N'SOS_SCHEDULER_%'
                  OR rw.wait_type IN (N'THREADPOOL', N'CXPACKET', N'CXCONSUMER')
                    THEN N'CPU'
                WHEN rw.wait_type LIKE N'PAGEIOLATCH_%'
                  OR rw.wait_type LIKE N'ASYNC_IO_COMPLETION'
                  OR rw.wait_type LIKE N'IO_COMPLETION'
                  OR rw.wait_type LIKE N'WRITELOG'
                  OR rw.wait_type LIKE N'LOGBUFFER'
                  OR rw.wait_type LIKE N'LOGBUFFER'
                  OR rw.wait_type LIKE N'BACKUPIO'
                  OR rw.wait_type LIKE N'READ_COMPLETION'
                    THEN N'I/O'
                WHEN rw.wait_type LIKE N'RESOURCE_SEMAPHORE%'
                  OR rw.wait_type LIKE N'MEMORY_%'
                  OR rw.wait_type IN (N'CMEMTHREAD', N'CMEMPARTITIONED', N'EE_PMOLOCK', N'RESERVED_MEMORY_ALLOCATION_EXT')
                    THEN N'Memory'
                ELSE N'Other'
            END AS WaitCategory,
            rw.wait_time_ms,
            rw.signal_wait_time_ms,
            rw.resource_wait_time_ms,
            rw.waiting_tasks_count
        FROM RawWaits rw
    ),
    Totals AS
    (
        SELECT SUM(wait_time_ms) AS total_wait_time_ms
        FROM Categorised
    )
    SELECT
        c.WaitCategory,
        SUM(c.wait_time_ms) AS WaitTimeMs,
        CAST(SUM(c.wait_time_ms) / 1000.0 AS DECIMAL(18,2)) AS WaitTimeSeconds,
        SUM(c.signal_wait_time_ms) AS SignalWaitTimeMs,
        SUM(c.resource_wait_time_ms) AS ResourceWaitTimeMs,
        SUM(c.waiting_tasks_count) AS WaitingTasksCount,
        CAST(SUM(c.wait_time_ms) * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS PctOfTotalWaitTime
    FROM Categorised c
    CROSS JOIN Totals t
    GROUP BY c.WaitCategory, t.total_wait_time_ms
    ORDER BY WaitTimeMs DESC, WaitCategory ASC;

    /* -------------------------------------------------------------------------
       C) Top wait types
    ------------------------------------------------------------------------- */
    ;WITH RawWaits AS
    (
        SELECT
            ws.wait_type,
            ws.waiting_tasks_count,
            ws.wait_time_ms,
            ws.max_wait_time_ms,
            ws.signal_wait_time_ms,
            CAST(ws.wait_time_ms - ws.signal_wait_time_ms AS BIGINT) AS resource_wait_time_ms
        FROM sys.dm_os_wait_stats ws
        WHERE ws.waiting_tasks_count > 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMonitor.WaitStatsExclusions ex
              WHERE ex.WaitType = ws.wait_type
          )
    ),
    Categorised AS
    (
        SELECT
            rw.wait_type,
            rw.waiting_tasks_count,
            rw.wait_time_ms,
            rw.max_wait_time_ms,
            rw.signal_wait_time_ms,
            rw.resource_wait_time_ms,
            CAST(rw.wait_time_ms * 1.0 / NULLIF(rw.waiting_tasks_count, 0) AS DECIMAL(18,2)) AS avg_wait_ms_per_task,
            CASE
                WHEN rw.wait_type LIKE N'SOS_SCHEDULER_%'
                  OR rw.wait_type IN (N'THREADPOOL', N'CXPACKET', N'CXCONSUMER')
                    THEN N'CPU'
                WHEN rw.wait_type LIKE N'PAGEIOLATCH_%'
                  OR rw.wait_type LIKE N'ASYNC_IO_COMPLETION'
                  OR rw.wait_type LIKE N'IO_COMPLETION'
                  OR rw.wait_type LIKE N'WRITELOG'
                  OR rw.wait_type LIKE N'LOGBUFFER'
                  OR rw.wait_type LIKE N'LOGBUFFER'
                  OR rw.wait_type LIKE N'BACKUPIO'
                  OR rw.wait_type LIKE N'READ_COMPLETION'
                    THEN N'I/O'
                WHEN rw.wait_type LIKE N'RESOURCE_SEMAPHORE%'
                  OR rw.wait_type LIKE N'MEMORY_%'
                  OR rw.wait_type IN (N'CMEMTHREAD', N'CMEMPARTITIONED', N'EE_PMOLOCK', N'RESERVED_MEMORY_ALLOCATION_EXT')
                    THEN N'Memory'
                ELSE N'Other'
            END AS WaitCategory
        FROM RawWaits rw
    ),
    Totals AS
    (
        SELECT SUM(wait_time_ms) AS total_wait_time_ms FROM Categorised
    )
    SELECT TOP (@TopCount)
        c.wait_type,
        c.WaitCategory,
        c.waiting_tasks_count,
        c.wait_time_ms,
        CAST(c.wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS wait_time_seconds,
        c.signal_wait_time_ms,
        CAST(c.signal_wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS signal_wait_seconds,
        c.resource_wait_time_ms,
        CAST(c.resource_wait_time_ms / 1000.0 AS DECIMAL(18,2)) AS resource_wait_seconds,
        c.max_wait_time_ms,
        c.avg_wait_ms_per_task,
        CAST(c.wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS pct_of_total_wait_time,
        CAST(c.signal_wait_time_ms * 100.0 / NULLIF(c.wait_time_ms, 0) AS DECIMAL(9,2)) AS pct_signal_within_wait
    FROM Categorised c
    CROSS JOIN Totals t
    ORDER BY c.wait_time_ms DESC, c.wait_type ASC;

    /* -------------------------------------------------------------------------
       D) Active waits / active requests
    ------------------------------------------------------------------------- */
    SELECT
        @SnapshotUtc AS SnapshotUtc,
        er.session_id,
        er.request_id,
        er.status,
        er.command,
        er.wait_type,
        er.wait_time AS current_wait_ms,
        er.last_wait_type,
        er.wait_resource,
        er.blocking_session_id,
        er.cpu_time AS cpu_time_ms,
        er.total_elapsed_time AS total_elapsed_time_ms,
        er.reads,
        er.writes,
        er.logical_reads,
        er.granted_query_memory,
        er.dop,
        er.parallel_worker_count,
        DB_NAME(er.database_id) AS database_name,
        s.host_name,
        s.program_name,
        s.login_name,
        SUBSTRING(st.text,
                  (er.statement_start_offset / 2) + 1,
                  ((CASE er.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE er.statement_end_offset
                    END - er.statement_start_offset) / 2) + 1) AS running_statement,
        st.text AS batch_text
    FROM sys.dm_exec_requests er
    INNER JOIN sys.dm_exec_sessions s
        ON s.session_id = er.session_id
    OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
    WHERE er.session_id <> @@SPID
      AND er.database_id = DB_ID()
    ORDER BY er.wait_time DESC, er.cpu_time DESC, er.total_elapsed_time DESC;

    /* -------------------------------------------------------------------------
       E) Signal vs resource waits summary (for stacked chart / KPI card)
    ------------------------------------------------------------------------- */
    ;WITH RawWaits AS
    (
        SELECT
            ws.wait_time_ms,
            ws.signal_wait_time_ms,
            CAST(ws.wait_time_ms - ws.signal_wait_time_ms AS BIGINT) AS resource_wait_time_ms
        FROM sys.dm_os_wait_stats ws
        WHERE ws.waiting_tasks_count > 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMonitor.WaitStatsExclusions ex
              WHERE ex.WaitType = ws.wait_type
          )
    )
    SELECT
        SUM(wait_time_ms) AS TotalWaitTimeMs,
        SUM(signal_wait_time_ms) AS SignalWaitTimeMs,
        SUM(resource_wait_time_ms) AS ResourceWaitTimeMs,
        CAST(SUM(signal_wait_time_ms) * 100.0 / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(9,2)) AS SignalWaitPct,
        CAST(SUM(resource_wait_time_ms) * 100.0 / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(9,2)) AS ResourceWaitPct,
        CASE
            WHEN CAST(SUM(signal_wait_time_ms) * 100.0 / NULLIF(SUM(wait_time_ms), 0) AS DECIMAL(9,2)) > @CpuPressureSignalThresholdPct
                THEN N'High signal wait percentage detected - likely scheduler or CPU pressure.'
            ELSE N'Signal wait percentage is within threshold.'
        END AS SignalWaitAssessment
    FROM RawWaits;

    /* -------------------------------------------------------------------------
       F) Recommendations derived from the pattern of waits
    ------------------------------------------------------------------------- */
    ;WITH RawWaits AS
    (
        SELECT
            ws.wait_type,
            ws.waiting_tasks_count,
            ws.wait_time_ms,
            ws.signal_wait_time_ms,
            CAST(ws.wait_time_ms - ws.signal_wait_time_ms AS BIGINT) AS resource_wait_time_ms
        FROM sys.dm_os_wait_stats ws
        WHERE ws.waiting_tasks_count > 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMonitor.WaitStatsExclusions ex
              WHERE ex.WaitType = ws.wait_type
          )
    ),
    Totals AS
    (
        SELECT
            SUM(wait_time_ms) AS total_wait_time_ms,
            SUM(signal_wait_time_ms) AS total_signal_wait_time_ms
        FROM RawWaits
    ),
    TopWait AS
    (
        SELECT TOP (1)
            rw.wait_type,
            rw.wait_time_ms,
            CAST(rw.wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS pct_of_total_wait_time
        FROM RawWaits rw
        CROSS JOIN Totals t
        ORDER BY rw.wait_time_ms DESC, rw.wait_type ASC
    ),
    Markers AS
    (
        SELECT
            MAX(CASE WHEN rw.wait_type IN (N'SOS_SCHEDULER_YIELD', N'THREADPOOL', N'CXPACKET', N'CXCONSUMER') THEN 1 ELSE 0 END) AS HasCpuPressureWaits,
            MAX(CASE WHEN rw.wait_type IN (N'PAGEIOLATCH_SH', N'PAGEIOLATCH_EX', N'PAGEIOLATCH_UP', N'WRITELOG', N'IO_COMPLETION', N'ASYNC_IO_COMPLETION') THEN 1 ELSE 0 END) AS HasIoPressureWaits,
            MAX(CASE WHEN rw.wait_type LIKE N'RESOURCE_SEMAPHORE%' OR rw.wait_type LIKE N'MEMORY_%' THEN 1 ELSE 0 END) AS HasMemoryPressureWaits,
            MAX(CASE WHEN rw.wait_type IN (N'LCK_M_S', N'LCK_M_U', N'LCK_M_X', N'LCK_M_IX', N'LCK_M_IS') THEN 1 ELSE 0 END) AS HasLockWaits,
            MAX(CASE WHEN rw.wait_type IN (N'CXPACKET', N'CXCONSUMER') THEN 1 ELSE 0 END) AS HasParallelismWaits
        FROM RawWaits rw
    )
    SELECT
        rec.Priority,
        rec.Pattern,
        rec.Recommendation,
        rec.SupportingMetric
    FROM
    (
        SELECT
            1 AS Priority,
            N'CPU pressure' AS Pattern,
            N'High signal waits suggest workers are waiting for CPU. Check scheduler pressure, expensive queries, high DOP plans, missing indexes, and concurrent workload spikes.' AS Recommendation,
            CONCAT(N'Signal wait % = ', CAST(CAST(t.total_signal_wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) AS NVARCHAR(50)), N'%') AS SupportingMetric
        FROM Totals t
        CROSS JOIN Markers m
        WHERE CAST(t.total_signal_wait_time_ms * 100.0 / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(9,2)) > @CpuPressureSignalThresholdPct
           OR m.HasCpuPressureWaits = 1

        UNION ALL

        SELECT
            2 AS Priority,
            N'I/O pressure' AS Pattern,
            N'Dominant PAGEIOLATCH / WRITELOG / IO_COMPLETION waits suggest storage latency. Check data/log disk latency, TempDB layout, autogrowth settings, and large scan patterns.' AS Recommendation,
            CONCAT(N'Top wait = ', tw.wait_type, N' (', CAST(tw.pct_of_total_wait_time AS NVARCHAR(50)), N'% of total)') AS SupportingMetric
        FROM TopWait tw
        CROSS JOIN Markers m
        WHERE m.HasIoPressureWaits = 1

        UNION ALL

        SELECT
            3 AS Priority,
            N'Memory pressure' AS Pattern,
            N'RESOURCE_SEMAPHORE or MEMORY_* waits suggest query memory pressure. Review grants, sort/hash spills, cardinality estimates, and concurrent reporting workloads.' AS Recommendation,
            N'Memory-related waits detected' AS SupportingMetric
        FROM Markers m
        WHERE m.HasMemoryPressureWaits = 1

        UNION ALL

        SELECT
            4 AS Priority,
            N'Blocking / locking' AS Pattern,
            N'LCK_* waits indicate blocking. Identify long transactions, missing indexes causing large lock footprints, and review transaction scope in CymBuild save workflows.' AS Recommendation,
            N'Lock waits detected' AS SupportingMetric
        FROM Markers m
        WHERE m.HasLockWaits = 1

        UNION ALL

        SELECT
            5 AS Priority,
            N'Parallelism' AS Pattern,
            N'CXPACKET / CXCONSUMER waits may indicate parallelism inefficiency. Check cost threshold for parallelism, MAXDOP, skewed plans, and expensive reporting queries.' AS Recommendation,
            N'Parallelism waits detected' AS SupportingMetric
        FROM Markers m
        WHERE m.HasParallelismWaits = 1

        UNION ALL

        SELECT
            99 AS Priority,
            N'General' AS Pattern,
            N'Review the top waits together with active requests. A single dominant wait often reflects the current primary bottleneck, but mixed waits may indicate several concurrent issues.' AS Recommendation,
            CONCAT(N'Current top wait = ', tw.wait_type, N' (', CAST(tw.pct_of_total_wait_time AS NVARCHAR(50)), N'% of total)') AS SupportingMetric
        FROM TopWait tw
    ) rec
    ORDER BY rec.Priority ASC, rec.Pattern ASC;
END
GO