SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SMonitor].[vw_ActiveWaits]')
GO

/* =============================================================================
   5) Optional lightweight wrapper view for current active waits only
============================================================================= */
CREATE VIEW [SMonitor].[vw_ActiveWaits]
AS
SELECT
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
    st.text AS batch_text
FROM sys.dm_exec_requests er
INNER JOIN sys.dm_exec_sessions s
    ON s.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE er.session_id <> @@SPID;
GO