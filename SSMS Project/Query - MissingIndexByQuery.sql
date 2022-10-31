--http://sqlstudies.com/2013/11/11/a-better-way-to-find-missing-indexes/

WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan'
AS sp)
 
SELECT DB_NAME(CAST(pa.value AS INT)) QueryDatabase
    ,s.sql_handle
    ,OBJECT_SCHEMA_NAME(st.objectid, CAST(pa.value AS INT)) AS ObjectSchemaName
    ,OBJECT_NAME(st.objectid, CAST(pa.value AS INT)) AS ObjectName
    ,SUBSTRING(st.text,s.statement_start_offset/2+1,
            ((CASE WHEN s.statement_end_offset = -1 THEN DATALENGTH(st.text)
                ELSE s.statement_end_offset END) - s.statement_start_offset)/2 + 1)  AS SqlText
    ,s.total_elapsed_time
    ,s.last_execution_time
    ,s.execution_count
    ,s.total_logical_writes
    ,s.total_logical_reads
    ,s.min_elapsed_time
    ,s.max_elapsed_time
    -- query_hash is useful for grouping similar queries with different parameters
    --,s.query_hash
    --,cast (p.query_plan as varchar(max)) query_plan
    ,p.query_plan
    ,mi.MissingIndex.value(N'(./@Database)[1]', 'NVARCHAR(256)') AS TableDatabase
    ,mi.MissingIndex.value(N'(./@Table)[1]', 'NVARCHAR(256)') AS TableName
    ,mi.MissingIndex.value(N'(./@Schema)[1]', 'NVARCHAR(256)') AS TableSchema
    ,mi.MissingIndex.value(N'(../@Impact)[1]', 'DECIMAL(6,4)') AS ProjectedImpact
    ,ic.IndexColumns
    ,inc.IncludedColumns
FROM (  -- Uncomment the TOP & ORDER BY clauses to restrict the data and
        -- reduce the query run time.
        SELECT --TOP 200
        s.sql_handle
        ,s.plan_handle
        ,s.total_elapsed_time
        ,s.last_execution_time
        ,s.execution_count
        ,s.total_logical_writes
        ,s.total_logical_reads
        ,s.min_elapsed_time
        ,s.max_elapsed_time
        ,s.statement_start_offset
        ,s.statement_end_offset
        --,s.query_hash
    FROM sys.dm_exec_query_stats s
    -- ORDER BY s.total_elapsed_time DESC
    ) AS s
CROSS APPLY sys.dm_exec_text_query_plan(s.plan_handle,statement_start_offset,statement_end_offset) AS pp
CROSS APPLY (SELECT CAST(pp.query_plan AS XML) AS query_plan ) AS p
CROSS APPLY p.query_plan.nodes('/sp:ShowPlanXML/sp:BatchSequence/sp:Batch/sp:Statements/sp:StmtSimple/sp:QueryPlan/sp:MissingIndexes/sp:MissingIndexGroup/sp:MissingIndex')
                AS mi (MissingIndex) 
CROSS APPLY (SELECT STUFF((SELECT ', ' + ColumnGroupColumn.value('./@Name', 'NVARCHAR(256)')
            FROM mi.MissingIndex.nodes('./sp:ColumnGroup')
                AS t1 (ColumnGroup)
            CROSS APPLY t1.ColumnGroup.nodes('./sp:Column') AS t2 (ColumnGroupColumn)
            WHERE t1.ColumnGroup.value('./@Usage', 'NVARCHAR(256)') <> 'INCLUDE'
            FOR XML PATH(''),TYPE).value('.','VARCHAR(MAX)'), 1, 2, '') AS IndexColumns ) AS ic 
CROSS APPLY (SELECT STUFF((SELECT ', ' + ColumnGroupColumn.value('./@Name', 'NVARCHAR(256)')
            FROM mi.MissingIndex.nodes('./sp:ColumnGroup')
                AS t1 (ColumnGroup)
            CROSS APPLY t1.ColumnGroup.nodes('./sp:Column') AS t2 (ColumnGroupColumn)
            WHERE t1.ColumnGroup.value('./@Usage', 'NVARCHAR(256)') = 'INCLUDE'
            FOR XML PATH(''),TYPE).value('.','VARCHAR(MAX)'), 1, 2, '') AS IncludedColumns ) AS inc 
CROSS APPLY sys.dm_exec_plan_attributes(s.plan_handle) pa
CROSS APPLY sys.dm_exec_sql_text (s.sql_handle) st
WHERE pp.query_plan LIKE '%MissingIndexes%'
  AND pa.attribute = 'dbid'