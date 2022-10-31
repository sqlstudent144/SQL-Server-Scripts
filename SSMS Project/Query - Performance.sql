/*
--- Procedure stats
-- View the statistics at the SP level
SELECT db_name(database_id), object_name(object_id,database_id), * 
FROM sys.dm_exec_procedure_stats ps
OUTER APPLY sys.dm_exec_query_plan (ps.plan_handle)
WHERE object_name(object_id,database_id) LIKE '%spName1%'
ORDER BY total_elapsed_time/execution_count DESC
*/
--- Query stats
-- View the stats for all queries. 
-- WHERE clause to pick out a specific SP or DB.
SELECT TOP 1000
	DB_NAME(st.dbid) AS DB_Name, 
	ISNULL(object_name(qp.objectid, qp.dbid),'*** Ad-Hoc ***') AS SPName, qs.*,
	CAST(qp.query_plan AS XML) AS XML_Plan,
    SUBSTRING(st.text,qs.statement_start_offset/2+1,
            ((CASE WHEN qs.statement_end_offset = -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset END) - qs.statement_start_offset)/2 + 1)  AS SqlText,
	st.text AS FullQuery
FROM sys.dm_exec_query_stats qs
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) st
OUTER APPLY sys.dm_exec_text_query_plan(qs.plan_handle, 
        qs.statement_start_offset, qs.statement_end_offset) qp
--WHERE st.dbid = DB_ID('TRSIOS')
WHERE object_name(st.objectid, st.dbid) LIKE '%spName1%'
--	OR object_name(st.objectid, st.dbid) LIKE '%spName2%'
--ORDER BY total_elapsed_time/execution_count DESC
 ORDER BY total_elapsed_time DESC
--ORDER BY max_grant_kb DESC
