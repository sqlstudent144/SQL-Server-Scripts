DECLARE @AuFiPa nvarchar(256), @today nvarchar(15), @last24hrs datetime, @offset int

SELECT @offset = DateDiff(hour, getutcdate(), getdate())
SELECT @last24hrs = dateadd(day,-21,getdate()) -- dateadd(hour,-24,getdate())
SELECT @today = convert(nvarchar(10),getdate(),102)
SELECT @AuFiPa = audit_file_path FROM sys.dm_server_audit_status WHERE name='SysAudit' AND status=1

SELECT convert(nvarchar(30),dateadd(hour,@offset,event_time),120) AS [Event_time], 
	action_id, succeeded, session_server_principal_name, target_server_principal_name, 
	server_instance_name, database_name, statement
  FROM sys.fn_get_audit_file(@AuFiPa, default, default)
-- where action_id in ('LGIF')
WHERE 1=1
   AND action_id NOT IN ('VSST', 'BA', 'BAL') --,'ALSS','BA')
--   and dateadd(hour,@offset,event_time) > @today
   AND event_time > @last24hrs
--   and event_time > @today
--   and convert(nvarchar(10),event_time,102) = @today
ORDER BY event_time DESC



