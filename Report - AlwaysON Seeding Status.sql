SELECT remote_machine_name,
       local_database_name,
       internal_state_desc,
       transfer_rate_bytes_per_second*60/(1024*1024) TransferRateMBPerMin,
       transferred_size_bytes /(1024*1024) TransferredMB,
       database_size_bytes/(1024*1024) DBSizeMB,
       DATEADD(HH, DATEDIFF(HH, GETUTCDATE(), GETDATE()), start_time_utc) StartTime,
       DATEADD(HH, DATEDIFF(HH, GETUTCDATE(), GETDATE()), end_time_utc) EndTime,
       DATEADD(HH, DATEDIFF(HH, GETUTCDATE(), GETDATE()), estimate_time_complete_utc) EstimatedFinishTime
FROM sys.dm_hadr_physical_seeding_stats;

--No need of password to add database to AG;
--ALTER AVAILABILITY GROUP AGName REMOVE DATABASE DBName;
--GO
--ALTER AVAILABILITY GROUP AGName ADD DATABASE DBName;
--GO
