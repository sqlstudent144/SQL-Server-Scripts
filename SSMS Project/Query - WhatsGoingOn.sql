USE master
GO 
--kill 88
--select * from sys.dm_exec_connections where session_id IN (608)
--select * from sys.dm_exec_sessions where session_id IN    (608)
--select * from sys.dm_exec_requests where session_id IN    (608)

-- DBCC Inputbuffer()
--SELECT session_id, sum(granted_memory_kb)/1024.0 AS Memory_mb
--FROM sys.dm_exec_query_memory_grants
--GROUP BY session_id
--select * from sys.dm_exec_query_memory_grants
--- What's happening with Active requests
SELECT DB_NAME(er.database_id) AS DB_Name 
	,er.command
	,es.host_name
	,es.login_name 
    ,datediff(minute,start_time,getdate()) AS RunTimeInMinutes
	,blocking_session_id
	,ISNULL(object_name(qp.objectid, qp.dbid),'*** Ad-Hoc ***') AS RunningCode
	,er.*
	,qp.objectid
	,qp.dbid
	,CAST(qp.query_plan AS XML) AS XML_Plan
    ,CAST('<?query --'+SUBSTRING(st.text,er.statement_start_offset/2+1,
            ((CASE WHEN er.statement_end_offset = -1 THEN DATALENGTH(st.text)
                ELSE er.statement_end_offset END) - er.statement_start_offset)/2 + 1)+'--?>'  AS XML) AS SqlText
FROM sys.dm_exec_requests er
LEFT OUTER JOIN sys.dm_exec_sessions es
	ON er.session_id = es.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
OUTER APPLY sys.dm_exec_text_query_plan(er.plan_handle, 
        statement_start_offset, statement_end_offset) qp
WHERE es.is_user_process = 1
ORDER BY er.session_id desc

-- Find idle sessions that have open transactions
SELECT db_name(st.dbid), DATEDIFF(minute,s.last_request_end_time,getdate()) AS minutes_since_last_Request,
		s.*, st.*
FROM sys.dm_exec_sessions AS s  
JOIN sys.dm_exec_connections AS c
	ON s.session_id = c.session_id
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) st
WHERE EXISTS   
    (  
    SELECT *   
    FROM sys.dm_tran_session_transactions AS t  
    WHERE t.session_id = s.session_id  
    )  
    AND NOT EXISTS   
    (  
    SELECT *   
    FROM sys.dm_exec_requests AS r  
    WHERE r.session_id = s.session_id  
    );  

DBCC SQLPERF(LOGSPACE);

--kill 174
--kill 140
-- select * from sys.dm_os_sys_info
-- select * from sys.dm_os_performance_counters
/*
--- What's happening with waiting tasks
SELECT * FROM sys.dm_os_waiting_tasks
ORDER BY session_id DESC
*/
--select * from sys.dm_Exec_connections 
--OUTER APPLY sys.dm_exec_sql_text(most_recent_sql_handle) st
--where session_id IN (72,81)
--select * from sys.dm_exec_sessions 
--where session_id = 233
--select * from sys.dm_tran_locks where request_session_id = 150
--select db_name(17)
/*
SELECT * 
FROM sys.dm_tran_session_transactions stran
JOIN sys.dm_exec_sessions sess
	ON stran.session_id = sess.session_id
JOIN sys.dm_exec_connections conn
	ON stran.session_id = conn.session_id
OUTER APPLY sys.dm_exec_sql_text(most_recent_sql_handle) st
WHERE stran.session_id NOT IN (SELECT session_id FROM sys.dm_exec_requests)
*/
/*
--- What's happening with locks
---- No DB locks
SELECT db_name(resource_database_id) AS DB_Name, * FROM sys.dm_tran_locks
WHERE resource_type <> 'DATABASE'
ORDER BY db_name(resource_database_id)
---- DB lock counts
SELECT db_name(resource_database_id) AS DB_Name, count(1) FROM sys.dm_tran_locks
WHERE resource_type = 'DATABASE'
GROUP BY resource_database_id
WITH ROLLUP
-- List of database locks
SELECT db_name(resource_database_id) AS DB_Name, request_session_id, *
FROM sys.dm_tran_locks
WHERE resource_type = 'DATABASE'
  and resource_database_id = db_id('Products')
*/
/*
-- SQL Server memory & CPU usage 
declare @ts_now bigint
--select @ts_now = cpu_ticks / convert(float, cpu_ticks_in_ms) from sys.dm_os_sys_info
-- 2008
 select @ts_now = cpu_ticks / (cpu_ticks/ms_ticks) from sys.dm_os_sys_info;
	 
select record_id,
      dateadd(ms, -1 * (@ts_now - [timestamp]), GetDate()) as EventTime,
      SQLProcessUtilization,
      SystemIdle,
      100 - SystemIdle - SQLProcessUtilization as OtherProcessUtilization
from (
      select
            record.value('(./Record/@id)[1]', 'int') as record_id,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') as SystemIdle,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') as SQLProcessUtilization,
            timestamp
      from (
            select timestamp, convert(xml, record) as record
            from sys.dm_os_ring_buffers
            where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
            and record like '%<SystemHealth>%') as x
      ) as y
order by record_id desc

*/
/*
--- What's happening with database locks
SELECT db_name(resource_database_id) AS DB_Name, count(1)
FROM sys.dm_tran_locks
WHERE resource_type = 'DATABASE'
GROUP BY db_name(resource_database_id)

--- Who has locks on a given database
SELECT sys.dm_exec_sessions.* 
FROM sys.dm_tran_locks
JOIN sys.dm_exec_sessions
	ON sys.dm_tran_locks.request_session_id = sys.dm_exec_sessions.session_id
WHERE resource_type = 'DATABASE'
  AND resource_database_id = db_id('Medpoint')

*/
/*
--- Look at connections & sessions
SELECT * FROM sys.dm_exec_sessions
SELECT * FROM sys.dm_exec_connections
*/
/*
--- Stats for a stored procedure
SELECT CAST(qp.query_plan AS XML) AS XML_Plan,
    SUBSTRING(st.text,qs.statement_start_offset/2+1,
            ((CASE WHEN qs.statement_end_offset = -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset END) - qs.statement_start_offset)/2 + 1)  AS SqlText,
	qs.total_elapsed_time/qs.execution_count as avg_elapsed_time,
    qs.*
FROM sys.dm_exec_query_stats qs
JOIN sys.dm_exec_procedure_stats ps
    ON qs.sql_handle = ps.sql_handle
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 
        statement_start_offset, statement_end_offset) qp
WHERE PS.object_id = object_id('Brass.dbo.RecalculateReconFileDetails');
*/

/*
---- Check latch stats
-- Baseline
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##TempLatchStats1')
    DROP TABLE [##TemplatchStats1];
GO
SELECT * INTO [##TemplatchStats1]
FROM sys.dm_os_latch_stats
ORDER BY [latch_class];
GO

-- Capture updated stats
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##TemplatchStats2')
    DROP TABLE [##TemplatchStats2];
GO
SELECT * INTO [##TemplatchStats2]
FROM sys.dm_os_latch_stats
ORDER BY [latch_class];
GO

-- Diff them
SELECT
    '***' AS [New],
    [ts2].[latch_class] AS [latch],
    [ts2].[waiting_requests_count] AS [Diff_waiting_requests_count],
    [ts2].[wait_time_ms] AS [Diff_wait_time_ms],
    [ts2].[max_wait_time_ms] AS [max_wait_time_ms]
FROM [##TemplatchStats2] [ts2]
LEFT OUTER JOIN [##TemplatchStats1] [ts1]
    ON [ts2].[latch_class] = [ts1].[latch_class]
WHERE [ts1].[latch_class] IS NULL
UNION
SELECT
    '' AS [New],
    [ts2].[latch_class] AS [latch],
    [ts2].[waiting_requests_count] - [ts1].[waiting_requests_count] AS [Diff_waiting_requests_count],
    [ts2].[wait_time_ms] - [ts1].[wait_time_ms] AS [Diff_wait_time_ms],
    [ts2].[max_wait_time_ms] AS [max_wait_time_ms]
	
FROM [##TemplatchStats2] [ts2]
LEFT OUTER JOIN [##TemplatchStats1] [ts1]
    ON [ts2].[latch_class] = [ts1].[latch_class]
WHERE [ts1].[latch_class] IS NOT NULL
ORDER BY [Diff_wait_time_ms] desc
GO
*/

/*
----- Check spinlock waits
-- Baseline
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##TempSpinlockStats1')
    DROP TABLE [##TempSpinlockStats1];
GO
SELECT * INTO [##TempSpinlockStats1]
FROM sys.dm_os_spinlock_stats
WHERE [collisions] > 0
ORDER BY [name];
GO

-- Capture updated stats
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##TempSpinlockStats2')
    DROP TABLE [##TempSpinlockStats2];
GO
SELECT * INTO [##TempSpinlockStats2]
FROM sys.dm_os_spinlock_stats
WHERE [collisions] > 0
ORDER BY [name];
GO

-- Diff them
SELECT
    '***' AS [New],
    [ts2].[name] AS [Spinlock],
    [ts2].[collisions] AS [DiffCollisions],
    [ts2].[spins] AS [DiffSpins],
    [ts2].[spins_per_collision] AS [SpinsPerCollision],
    [ts2].[sleep_time] AS [DiffSleepTime],
    [ts2].[backoffs] AS [DiffBackoffs]
FROM [##TempSpinlockStats2] [ts2]
LEFT OUTER JOIN [##TempSpinlockStats1] [ts1]
    ON [ts2].[name] = [ts1].[name]
WHERE [ts1].[name] IS NULL
UNION
SELECT
    '' AS [New],
    [ts2].[name] AS [Spinlock],
    [ts2].[collisions] - [ts1].[collisions] AS [DiffCollisions],
    [ts2].[spins] - [ts1].[spins] AS [DiffSpins],
    CASE ([ts2].[spins] - [ts1].[spins]) WHEN 0 THEN 0
        ELSE ([ts2].[spins] - [ts1].[spins]) /
            ([ts2].[collisions] - [ts1].[collisions]) END
            AS [SpinsPerCollision],
    [ts2].[sleep_time] - [ts1].[sleep_time] AS [DiffSleepTime],
    [ts2].[backoffs] - [ts1].[backoffs] AS [DiffBackoffs]
FROM [##TempSpinlockStats2] [ts2]
LEFT OUTER JOIN [##TempSpinlockStats1] [ts1]
    ON [ts2].[name] = [ts1].[name]
WHERE [ts1].[name] IS NOT NULL
    AND [ts2].[collisions] - [ts1].[collisions] > 0
ORDER BY diffcollisions desc
GO
*/
/*
----- Wait stats
WITH [Waits] AS
    (SELECT
        [wait_type],
        [wait_time_ms] / 1000.0 AS [WaitS],
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
        [signal_wait_time_ms] / 1000.0 AS [SignalS],
        [waiting_tasks_count] AS [WaitCount],
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        N'BROKER_EVENTHANDLER',             N'BROKER_RECEIVE_WAITFOR',
        N'BROKER_TASK_STOP',                N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER',              N'CHECKPOINT_QUEUE',
        N'CHKPT',                           N'CLR_AUTO_EVENT',
        N'CLR_MANUAL_EVENT',                N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT',              N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE',           N'DBMIRRORING_CMD',
        N'DIRTY_PAGE_POLL',                 N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC',                        N'FSAGENT',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT',     N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL',               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT',            N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK',                 N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP',                  N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE',                    N'ONDEMAND_TASK_QUEUE',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'REQUEST_FOR_DEADLOCK_SEARCH',     N'RESOURCE_QUEUE',
        N'SERVER_IDLE_CHECK',               N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP',                 N'SLEEP_DCOMSTARTUP',
        N'SLEEP_MASTERDBREADY',             N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED',            N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK',                N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP',             N'SNI_HTTP_ACCEPT',
        N'SP_SERVER_DIAGNOSTICS_SLEEP',     N'SQLTRACE_BUFFER_FLUSH',
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES',           N'WAIT_FOR_RESULTS',
        N'WAITFOR',                         N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_HOST_WAIT',              N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_CKPT_CLOSE',             N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT')
    AND [waiting_tasks_count] > 0
 )
SELECT
    MAX ([W1].[wait_type]) AS [WaitType],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95; -- percentage threshold
GO
*/
/*
-- Kill negative session
SELECT DISTINCT request_owner_guid, request_session_id
FROM sys.dm_tran_locks 
WHERE request_session_id < 0
KILL '1B9772FD-3022-4833-AEF6-2A26DCC406A5'
KILL 'FC0C7B2D-C788-4763-9D48-1DFC02576B23'
*/

