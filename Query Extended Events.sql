DECLARE @ExtendedEventPath VARCHAR(MAX);
SELECT TOP 1 @ExtendedEventPath = SUBSTRING(st.target_data, CHARINDEX(':\', st.target_data) - 1, CHARINDEX('.xel', st.target_data) - CHARINDEX(':\', st.target_data) + 5)
FROM sys.dm_xe_sessions s
     INNER JOIN sys.dm_xe_session_targets st ON s.address = st.event_session_address
WHERE st.target_data LIKE '%:\%.xel%' --and s.name like 'Performance_Monitor' --Name of Exetended Event Session
--PRINT @ExtendedEventPath;
SELECT n.value('(@name)[1]', 'varchar(50)') AS event_name, 
       n.value('(@package)[1]', 'varchar(50)') AS package_name, 
       n.value('(@timestamp)[1]', 'datetime2') AS [utc_timestamp], 
       n.value('(data[@name="object_id"]/value)[1]', 'bigint') AS object_id, 
       n.value('(data[@name="object_name"]/value)[1]', 'nvarchar(max)') AS object_name, 
       n.value('(data[@name="object_type"]/value)[1]', 'nvarchar(max)') AS object_type, 
       n.value('(data[@name="duration"]/value)[1]', 'bigint') AS duration, 
       n.value('(data[@name="cpu_time"]/value)[1]', 'bigint') AS cpu, 
       n.value('(data[@name="physical_reads"]/value)[1]', 'bigint') AS physical_reads, 
       n.value('(data[@name="logical_reads"]/value)[1]', 'bigint') AS logical_reads, 
       n.value('(data[@name="writes"]/value)[1]', 'bigint') AS writes, 
       n.value('(data[@name="row_count"]/value)[1]', 'bigint') AS row_count, 
       n.value('(data[@name="last_row_count"]/value)[1]', 'bigint') AS last_row_count, 
       n.value('(data[@name="line_number"]/value)[1]', 'bigint') AS line_number, 
       n.value('(data[@name="offset"]/value)[1]', 'bigint') AS OFFSET, 
       n.value('(data[@name="offset_end"]/value)[1]', 'bigint') AS offset_end, 
       n.value('(data[@name="statement"]/value)[1]', 'nvarchar(max)') AS statement, 
       n.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
       n.value('(action[@name="database_name"]/value)[1]', 'nvarchar(128)') AS database_name,
       n.value('(action[@name="nt_username"]/value)[1]', 'nvarchar(128)') AS nt_username,
	  n.value('(action[@name="client_hostname"]/value)[1]', 'nvarchar(256)') AS client_hostname,
	  EVENT_DATA
FROM
(
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file(@ExtendedEventPath, NULL, NULL, NULL)
) ed
CROSS APPLY ed.event_data.nodes('event') AS q(n)
WHERE  1= 1
and n.value('(@timestamp)[1]', 'datetime2') > DATEADD(MINUTE,-5,GETUTCDATE())
--and n.value('(data[@name="statement"]/value)[1]', 'nvarchar(max)') like '%usp_name%'
--and n.value('(data[@name="duration"]/value)[1]', 'bigint') > 100000 * 1 --5 second
ORDER BY utc_timestamp DESC
