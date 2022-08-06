/*
https://technet.microsoft.com/en-us/library/dd822788%28v=sql.100%29.aspx?f=255&MSPPError=-2147217396
*/
---- Events
SELECT p.name AS package, c.event, k.keyword, c.channel, c.description
FROM
(
SELECT event_package=o.package_guid, o.description,
       event=c.object_name, channel=v.map_value
FROM sys.dm_xe_objects o
       LEFT JOIN sys.dm_xe_object_columns c ON o.name = c.object_name
       INNER JOIN sys.dm_xe_map_values v ON c.type_name = v.name
              AND c.column_value = cast(v.map_key AS nvarchar)
WHERE object_type='event' AND (c.name = 'channel' OR c.name IS NULL)
) c left join
(
       SELECT event_package=c.object_package_guid, event=c.object_name,
              keyword=v.map_value
       FROM sys.dm_xe_object_columns c INNER JOIN sys.dm_xe_map_values v
       ON c.type_name = v.name AND c.column_value = v.map_key
              AND c.type_package_guid = v.object_package_guid
       INNER JOIN sys.dm_xe_objects o ON o.name = c.object_name
              AND o.package_guid=c.object_package_guid
       WHERE object_type='event' AND c.name = 'keyword'
) k
ON
k.event_package = c.event_package AND (k.event = c.event OR k.event IS NULL)
INNER JOIN sys.dm_xe_packages p ON p.guid=c.event_package
WHERE (p.capabilities IS NULL OR p.capabilities & 1 = 0)
--and c.event like '%database%'
ORDER BY channel, keyword, event
---- Actions
SELECT p.name AS PackageName,
       o.name AS ActionName,
       o.description AS ActionDescription
FROM sys.dm_xe_objects o
       INNER JOIN sys.dm_xe_packages p
              ON o.package_guid = p.guid
WHERE o.object_type = 'action'
  AND (p.capabilities IS NULL OR p.capabilities & 1 = 0)
ORDER BY PackageName, ActionName;
---- Targets

---- Drop an event session
DROP EVENT SESSION [HIPAA TPA EE] ON SERVER
---- Create an event session
CREATE EVENT SESSION [HIPAA TPA EE] ON SERVER 
ADD EVENT sqlserver.error_reported(
    ACTION(sqlserver.database_id,sqlserver.nt_username,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[database_id]=14)),
ADD EVENT sqlserver.database_stopped(
    ACTION(sqlserver.nt_username)
    WHERE ([sqlserver].[database_id]=14)),
ADD EVENT sqlserver.database_started(
    ACTION(sqlserver.nt_username)
    WHERE ([sqlserver].[database_id]=14))
ADD TARGET package0.asynchronous_file_target(
     SET filename='H:\MSSQL10_50.WEBTEST\MSSQL\Audit Files\HIPAA TPA EE.etl', metadatafile='H:\MSSQL10_50.WEBTEST\MSSQL\Audit Files\HIPAA TPA EE.mta')

GO

ALTER EVENT SESSION [HIPAA TPA EE] ON SERVER 
DROP EVENT sqlserver.database_stopped,
DROP EVENT sqlserver.database_started

---- Start an event session
ALTER EVENT SESSION [HIPAA TPA EE]
ON SERVER
STATE=START

---- Information about existing session
select * from sys.server_event_sessions
select * from sys.server_event_session_events where event_session_id = 65540
SELECT * FROM sys.server_event_session_actions where event_session_id = 65540


---- Read an EE file
SELECT top 100 *, cast(event_data as xml) as targetdata
FROM sys.fn_xe_file_target_read_file('H:\MSSQL10_50.WEBTEST\MSSQL\Audit Files\HIPAA TPA EE*etl', 'H:\MSSQL10_50.WEBTEST\MSSQL\Audit Files\HIPAA TPA EE*mta', null, null)

---- Read from the ring buffer
SELECT CAST(target_data as xml) AS targetdata
INTO #capture_waits_data
FROM sys.dm_xe_session_targets xet
JOIN sys.dm_xe_sessions xes
    ON xes.address = xet.event_session_address
WHERE xes.name = 'Ring Buffer - Track Waits'
  AND xet.target_name = 'ring_buffer';

---- Interpret data
---- http://www.brentozar.com/archive/2015/01/query-extended-events-target-xml/
SELECT xed.event_data.value('(@timestamp)[1]', 'datetime2') AS [timestamp],
  xed.event_data.value('(data[@name="error"]/value)[1]', 'int') AS error, 
  xed.event_data.value('(data[@name="severity"]/value)[1]', 'int') AS severity, 
  xed.event_data.value('(data[@name="state"]/value)[1]', 'int') AS state, 
  xed.event_data.value('(data[@name="message"]/value)[1]', 'varchar(200)') AS message, 
  xed.event_data.value('(action[@name="nt_username"]/value)[1]', 'varchar(200)') AS nt_username, 
  xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(200)') AS username, 
  xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)') AS sql_text
FROM sys.fn_xe_file_target_read_file('H:\MSSQL10_50.WEBTEST\MSSQL\Audit Files\HIPAA TPA EE*etl', 'H:\MSSQL10_50.WEBTEST\MSSQL\Audit Files\HIPAA TPA EE*mta', null, null)
--file
  CROSS APPLY (VALUES (CAST(event_data AS XML))) vals(targetdata)
  CROSS APPLY targetdata.nodes('//event') AS xed (event_data);
--ring buffer
--  CROSS APPLY targetdata.nodes('//RingBufferTarget/event') AS xed (event_data);



----- Parse xel file
SELECT 
	[XML Data],
	[XML Data].value('(/event/@timestamp)[1]', 'datetime2') AS [timestamp],
	[XML Data].value('(/event/action[@name=''database_name'']/value)[1]','varchar(max)')    AS [Database],
	[XML Data].value('(/event/data[@name=''duration'']/value)[1]','int')					AS [Duration],
	[XML Data].value('(/event/action[@name=''session_id'']/value)[1]','int')                AS [session_id],
	[XML Data].value('(/event/data[@name=''object_name'']/value)[1]','varchar(max)')        AS [object_name],
	[XML Data].value('(/event/action[@name=''sql_text'']/value)[1]','varchar(max)')         AS [sql_text]
	INTO #temp
FROM
(SELECT
	OBJECT_NAME              AS [Event],
	CONVERT(XML, event_data) AS [XML Data]
	FROM sys.fn_xe_file_target_read_file
		('C:\temp\WhatsGoingOn*.xel',NULL,NULL,NULL)
	where event_data like '%sql_text%') as x;
