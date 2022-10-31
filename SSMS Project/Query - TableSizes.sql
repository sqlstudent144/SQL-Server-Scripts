-- SET NOEXEC ON
-- SET NOEXEC OFF

IF object_id('tempdb.dbo.#TableSizes') <> 0
	DROP TABLE #TableSizes
GO
CREATE TABLE #TableSizes (
	DBName varchar(255),
	SchemaName varchar(255),
	TableName varchar(255),
	Rows int,
	TotalSpaceKB int,
	UsedSpaceKB int,
	UnusedSpaceKB int
)

EXEC sp_msforeachdb
'USE [?] ;
INSERT INTO #TableSizes
SELECT 
	db_name() AS DBName,
    s.Name AS SchemaName,
    t.NAME AS TableName,
    p.rows AS RowCounts,
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY t.Name, s.Name, p.Rows
ORDER BY t.Name;'

SELECT * FROM #TableSizes
WHERE DBName NOT IN ('tempdb','master','model','msdb');
