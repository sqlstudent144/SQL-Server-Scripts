-- Gotten from here: https://dba.stackexchange.com/questions/154283/stats-date-is-null
-- Answer by Nic.

SELECT  t.name ,
        s.object_id ,
        s.stats_id ,
        c.name ,
        sc.stats_column_id ,
        s.name ,
        sp.last_updated ,
		p.rows as total_rows ,
        sp.rows_sampled ,
        sp.modification_counter ,
        sp.steps ,
        sp.rows
FROM    [sys].[stats] AS [s]
        INNER JOIN sys.stats_columns sc ON s.stats_id = sc.stats_id
                                            AND s.object_id = sc.object_id
        INNER JOIN sys.columns c ON c.object_id = sc.object_id
                                    AND c.column_id = sc.column_id
        INNER JOIN sys.tables t ON c.object_id = t.object_id
		INNER JOIN sys.partitions p ON c.object_id = p.object_id
					AND p.index_id IN (0,1)
        OUTER APPLY sys.dm_db_stats_properties([s].[object_id],
                                                [s].[stats_id]) AS [sp]
WHERE   t.name LIKE '%'
--WHERE p.rows > 0
ORDER BY sp.last_updated ASC

--update statistics agOnlineHierarchy1
