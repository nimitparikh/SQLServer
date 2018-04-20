USE master
GO
IF	OBJECT_ID ('DBATasks..tblPerfMonData')  IS  NULL
CREATE TABLE DBATasks..tblPerfMonData(
	[object_name] [nchar](128) NOT NULL,
	[counter_name] [nchar](128) NOT NULL,
	[instance_name] [nchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[RunTime] [datetime] NOT NULL
) ON [PRIMARY]
GO

USE [DBATasks];
GO
IF EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[spPerfMonData]')
          AND type IN(N'P', N'PC')
)
    DROP PROCEDURE [dbo].[spPerfMonData];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[spPerfMonData]')
          AND type IN(N'P', N'PC')
)
    BEGIN
        EXEC dbo.sp_executesql
             @statement = N'CREATE PROCEDURE [dbo].[spPerfMonData] AS';
END;
GO
ALTER PROCEDURE [dbo].[spPerfMonData](@retaindays INT = 1)
AS
     SET NOCOUNT ON;
     DECLARE @lastruntime DATETIME;
     SET @lastruntime = ISNULL(
                              (
                                  SELECT MAX(RunTime)
                                  FROM DBATasks..tblPerfMonData
                              ), GETDATE());
     INSERT INTO DBATasks..tblPerfMonData
            SELECT *,
                   GETDATE() RunTime
            FROM sys.dm_os_performance_counters
            WHERE cntr_value <> 0;
     WITH Duplicates
          AS (
          SELECT object_name,
                 counter_name,
                 instance_name,
                 cntr_value,
                 runtime,
                 ROW_NUMBER() OVER(PARTITION BY object_name,
                                                counter_name,
                                                instance_name,
                                                cntr_value ORDER BY RunTime DESC) rownumber
          FROM DBATasks..tblPerfMonData
          WHERE RunTime >= @lastruntime)
          DELETE FROM Duplicates
          WHERE rownumber <> 1;
     DELETE DBATasks..tblPerfMonData
     WHERE RunTime < DATEADD(DD, -@retaindays, GETDATE());
GO

USE [msdb]
GO
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA - Collect Perfmon Data')
BEGIN
EXEC msdb.dbo.sp_delete_job @job_name = N'DBA - Collect Perfmon Data',  @delete_unused_schedule=1
END
EXEC  msdb.dbo.sp_add_job @job_name=N'DBA - Collect Perfmon Data', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa'
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA - Collect Perfmon Data', @server_name = @@SERVERNAME
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA - Collect Perfmon Data', @step_name=N'Collect Perfmon Data', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBATasks..spPerfMonData', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DBA - Collect Perfmon Data', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA - Collect Perfmon Data', @name=N'Every 15 min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20171101, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
GO

----Rollback
--IF	OBJECT_ID ('DBATasks..tblPerfMonData')  IS  NULL
--DROP TABLE DBATasks..tblPerfMonData
--IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA - Collect Perfmon Data')
--BEGIN
--EXEC msdb.dbo.sp_delete_job @job_name = N'DBA - Collect Perfmon Data',  @delete_unused_schedule=1
--END
