-- Get-Volume
-- Found here: https://sqlsanctum.wordpress.com/2016/02/05/get-drive-sizes-using-sql-or-powershell/
SELECT
   [Drive] = volume_mount_point
  ,[FreeSpaceGB] = available_bytes/1024/1024/1024.0
  ,[SizeGB] = total_bytes/1024/1024/1024.0
  ,[PercentFree] = CONVERT(INT,CONVERT(DECIMAL(15,2),available_bytes) / total_bytes * 100)
FROM sys.master_files mf
  CROSS APPLY sys.dm_os_volume_stats(mf.database_id,mf.file_id)
--Optional where clause filters drives with more than 20% free space
-- WHERE CONVERT(INT,CONVERT(DECIMAL(15,2),available_bytes) / total_bytes * 100) < 20
GROUP BY
   volume_mount_point
  ,total_bytes/1024/1024 --/1024
  ,available_bytes/1024/1024 --/1024
  ,CONVERT(INT,CONVERT(DECIMAL(15,2),available_bytes) / total_bytes * 100)
ORDER BY [Drive]


exec xp_fixeddrives
