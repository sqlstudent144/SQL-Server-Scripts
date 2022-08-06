-- Source: https://www.sqlservercentral.com/blogs/identifying-failed-queries-with-extended-events
-- See also: https://straightforwardsql.com/posts/investigating-errors-with-extended-events/
--- Create Xevent
------ Be sure to change the filename and metadatafile
CREATE EVENT SESSION [FailedQueries] ON SERVER 
ADD EVENT sqlserver.error_reported 
	(ACTION(sqlserver.client_app_name, sqlserver.client_hostname,  
		sqlserver.database_name, sqlserver.sql_text, sqlserver.username) 
	WHERE ([package0].[greater_than_int64]([severity], (10)))) 
ADD TARGET package0.event_file (SET 
	filename = N'E:\Sql_EE_Output\FailedQueries.xel'
	,metadatafile = N'E:\Sql_EE_Output\FailedQueries.xem'
	,max_file_size = (5)
	,max_rollover_files = (10))
WITH (STARTUP_STATE = OFF) -- Change to ON if you want this to start when SQL starts.
GO
--- Start Xevent
ALTER EVENT SESSION [FailedQueries] ON SERVER 
STATE = START;
GO
--- Stop Xevent
ALTER EVENT SESSION [FailedQueries] ON SERVER 
STATE = STOP;
GO
-----------------------------------------
-- Read data
------ Be sure to change the filename
SELECT
	[XML Data],
	[XML Data].value('(/event[@name=''error_reported'']/@timestamp)[1]','DATETIME')AS [Timestamp],
	[XML Data].value('(/event/action[@name=''database_name'']/value)[1]','varchar(max)')AS [Database],
	[XML Data].value('(/event/data[@name=''message'']/value)[1]','varchar(max)')AS [Message],
	[XML Data].value('(/event/action[@name=''sql_text'']/value)[1]','varchar(max)')AS [Statement]
FROM
	(SELECT 
		OBJECT_NAME AS [Event], 
		CONVERT(XML, event_data) AS [XML Data]
		FROM sys.fn_xe_file_target_read_file
					('C:\SQLServer\XEvents\FailedQueries*.xel',NULL,NULL,NULL)
	) as FailedQueries;
GO