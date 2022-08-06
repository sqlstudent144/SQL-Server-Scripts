-- Gotten from here: https://www.sqlservercentral.com/articles/find-permission-changes-in-the-default-trace

DECLARE @tracefile VARCHAR(500)
-- Get path of default trace file
SELECT @tracefile = CAST(value AS VARCHAR(500))
FROM ::fn_trace_getinfo(DEFAULT)
WHERE traceid = 1
AND property = 2

-- Get security changes from the default trace
SELECT *
 FROM ::fn_trace_gettable(@tracefile, DEFAULT) trcdata -- DEFAULT means all trace files will be read
 INNER JOIN sys.trace_events evt ON trcdata.EventClass = evt.trace_event_id
 WHERE trcdata.EventClass IN (102, 103, 104, 105, 106, 108, 109, 110, 111)
 ORDER BY trcdata.StartTime
                 --trcdata.DatabaseID
                 --trcdata.TargetLoginName
