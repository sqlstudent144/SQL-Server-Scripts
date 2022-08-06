-- I think I got this from sqlskills but not certain.
SELECT DB_NAME(fs.database_id) DBName, 
	-- DB Values
	SUM(vals.num_of_mb_read) AS DB_Reads, 
	CASE WHEN SUM(fs.num_of_reads) > 0 THEN
		SUM(fs.io_stall_read_ms) / SUM(fs.num_of_reads) ELSE 0 END
			AS DB_Read_Wait,
	SUM(vals.num_of_mb_written) AS DB_Writes, 
	CASE WHEN SUM(fs.num_of_writes) > 0 THEN
		SUM(fs.io_stall_write_ms) / SUM(fs.num_of_writes) ELSE 0 END
			AS DB_Write_Wait,
	SUM(vals.size_on_disk_mb) AS DB_Size,
	-- Data file only values
	SUM(CASE WHEN mf.type = 0 THEN vals.num_of_mb_read ELSE 0 END) AS Data_Reads, 
	CASE WHEN SUM(vals.num_of_reads_data) > 0 THEN
		SUM(vals.io_stall_read_ms_data) / SUM(vals.num_of_reads_data) ELSE 0 END
			AS Data_Read_Wait, 
	SUM(CASE WHEN mf.type = 0 THEN vals.num_of_mb_written ELSE 0 END) AS Data_Writes, 
	CASE WHEN SUM(vals.num_of_writes_data) > 0 THEN
		SUM(vals.io_stall_writes_ms_data) / SUM(vals.num_of_writes_data) ELSE 0 END
			AS Data_Write_Wait, 
	SUM(CASE WHEN mf.type = 0 THEN vals.size_on_disk_mb ELSE 0 END) AS Data_Size,
	-- Log file only values
	SUM(CASE WHEN mf.type = 1 THEN vals.num_of_mb_read ELSE 0 END) AS Log_Reads, 
	CASE WHEN SUM(vals.num_of_reads_log) > 0 THEN
		SUM(vals.io_stall_read_ms_log) / SUM(vals.num_of_reads_log) ELSE 0 END
			AS Log_Read_Wait, 
	SUM(CASE WHEN mf.type = 1 THEN vals.num_of_mb_written ELSE 0 END) AS Log_Writes, 
	CASE WHEN SUM(vals.num_of_writes_log) > 0 THEN
		SUM(vals.io_stall_writes_ms_log) / SUM(vals.num_of_writes_log) ELSE 0 END
			AS Log_Write_Wait, 
	SUM(CASE WHEN mf.type = 1 THEN vals.size_on_disk_mb ELSE 0 END) AS Log_Size
FROM sys.dm_io_virtual_file_stats(null,null) fs
JOIN sys.master_files mf
	ON fs.database_id = mf.database_id
	AND fs.file_id = mf.file_id
CROSS APPLY (SELECT CAST(fs.num_of_bytes_read/1024/1024.0 AS Decimal(18,2)), 
					CAST(fs.num_of_bytes_written/1024/1024.0 AS Decimal(18,2)),
					CAST(fs.size_on_disk_bytes/1024/1024.0 AS Decimal(18,2)),
					CASE WHEN mf.type = 0 THEN fs.num_of_reads ELSE 0 END,
					CASE WHEN mf.type = 0 THEN fs.io_stall_read_ms ELSE 0 END,
					CASE WHEN mf.type = 0 THEN fs.num_of_writes ELSE 0 END,
					CASE WHEN mf.type = 0 THEN fs.io_stall_write_ms ELSE 0 END,
					CASE WHEN mf.type = 1 THEN fs.num_of_reads ELSE 0 END,
					CASE WHEN mf.type = 1 THEN fs.io_stall_read_ms ELSE 0 END,
					CASE WHEN mf.type = 1 THEN fs.num_of_writes ELSE 0 END,
					CASE WHEN mf.type = 1 THEN fs.io_stall_write_ms ELSE 0 END
					) AS vals(num_of_mb_read, num_of_mb_written, size_on_disk_mb,
							num_of_reads_data, io_stall_read_ms_data,
							num_of_writes_data, io_stall_writes_ms_data,
							num_of_reads_log, io_stall_read_ms_log,
							num_of_writes_log, io_stall_writes_ms_log	)
GROUP BY fs.database_id
ORDER BY 1
