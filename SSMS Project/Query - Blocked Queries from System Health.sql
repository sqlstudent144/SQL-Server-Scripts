-- Don't think this is mine but I can't remember where I got it from.
SELECT 
	xed.event_data.value('(@timestamp)[1]', 'datetime2') AS [timestamp],
	xed.event_data.value('(data[@name="wait_type"]/text)[1]', 'varchar(25)') AS wait_type, 
	xed.event_data.value('(data[@name="duration"]/value)[1]', 'int')/1000/60.0 AS wait_time_in_min, 
	xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'varchar(max)') AS sql_text, 
	xed.event_data.value('(action[@name="session_id"]/value)[1]', 'varchar(25)') AS session_id, 
	xData.Event_Data,
	fx.object_name
FROM sys.fn_xe_file_target_read_file ('system_health*.xel','system_health*.xem',null,null) fx
CROSS APPLY (SELECT CAST(fx.event_data AS XML) AS Event_Data) AS xData
CROSS APPLY xData.Event_Data.nodes('//event') AS xed (event_data)
WHERE fx.object_name = 'wait_info';
