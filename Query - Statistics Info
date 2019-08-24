-- Initial query taken from here: "https://blogs.msdn.microsoft.com/sql_server_team/persisting-statistics-sampling-rate/" then modified.

SELECT o.name AS object_name, ss.stats_id, ss.name as stat_name, 
	ss.filter_definition, shr.last_updated, 
	shr.persisted_sample_percent, 
	(shr.rows_sampled * 100)/shr.rows AS sample_percent,
	shr.rows, shr.rows_sampled, 
    shr.steps, shr.unfiltered_rows, shr.modification_counter 
FROM sys.stats ss
INNER JOIN sys.objects o 
    ON o.object_id = ss.object_id
CROSS APPLY sys.dm_db_stats_properties(ss.object_id, ss.stats_id) shr
WHERE o.is_ms_shipped = 0
ORDER BY o.name, ss.stats_id;
