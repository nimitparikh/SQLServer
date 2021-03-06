USE [DBATasks]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblFileStats]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[tblFileStats](
	[DBName] [nvarchar](128) NULL,
	[FileID] [smallint] NOT NULL,
	[NumOfReads] [bigint] NULL,
	[NumOfWrites] [bigint] NULL,
	[IOStallReadMS] [bigint] NULL,
	[IOStallWriteMS] [bigint] NULL,
	[NumOfBytesRead] [bigint] NULL,
	[NumOfBytesWritten] [bigint] NULL,
	[IOStall] [bigint] NULL,
	[SizeOnDiskBytes] [bigint] NULL,
	[ReadLatency] [bigint] NULL,
	[WriteLatency] [bigint] NULL,
	[FileType] [nvarchar](60) NULL,
	[FileLocation] [nvarchar](1080) NOT NULL,
	[RunTime] [datetime] NOT NULL
) ON [PRIMARY]
END
GO

USE [DBATasks];
GO

IF EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[spFileStats]')
          AND type IN(N'P', N'PC')
)
    DROP PROCEDURE [dbo].[spFileStats];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[spFileStats]')
          AND type IN(N'P', N'PC')
)
    BEGIN
        EXEC dbo.sp_executesql
             @statement = N'CREATE PROCEDURE [dbo].[spFileStats] AS';
END;
GO
ALTER PROCEDURE [dbo].[spFileStats](@retentiondays INT = 4, @waitfordelaysec int = 30)
AS
     SET NOCOUNT ON;
	DECLARE @lastruntime DATETIME;
     SET @lastruntime = ISNULL(
                              (
                                  SELECT MAX(RunTime)
                                  FROM DBATasks..tblFileStats
                              ), GETDATE());
     IF OBJECT_ID('tempdb..#io') IS NOT NULL
         DROP TABLE #io;
     SELECT *
     INTO #io
     FROM sys.dm_io_virtual_file_stats(NULL, NULL);
     DECLARE @delaytime CHAR(8);
     SET @delaytime = CONVERT(CHAR(8), DATEADD(SECOND, @waitfordelaysec, 0), 108);
     WAITFOR DELAY @delaytime;
     INSERT INTO DBATasks..tblFileStats
            SELECT DB_NAME(a.database_id) DBName,
                   a.file_id FileID,
                   a.num_of_reads - b.num_of_reads AS NumOfReads,
                   a.num_of_writes - b.num_of_writes AS NumOfWrites,
                   a.io_stall_read_ms - b.io_stall_read_ms IOStallReadMS,
                   a.io_stall_write_ms - b.io_stall_write_ms IOStallWriteMS,
                   a.num_of_bytes_read - b.num_of_bytes_read NumOfBytesRead,
                   a.num_of_bytes_written - b.num_of_bytes_written NumOfBytesWritten,
                   a.io_stall - b.io_stall IOStall,
                   a.size_on_disk_bytes - b.size_on_disk_bytes SizeOnDiskBytes,
                   CASE
                       WHEN a.num_of_reads - b.num_of_reads > 0
                       THEN(a.io_stall_read_ms - b.io_stall_read_ms) / (a.num_of_reads - b.num_of_reads)
                       ELSE 0
                   END AS ReadLatency,
                   CASE
                       WHEN a.num_of_writes - b.num_of_writes > 0
                       THEN(a.io_stall_write_ms - b.io_stall_write_ms) / (a.num_of_writes - b.num_of_writes)
                       ELSE 0
                   END AS WriteLatency,
                   c.type_desc FileType,
                   c.physical_name FileLocation,
                   GETDATE() RunTime
            FROM #io b
                 INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) a ON a.database_id = b.database_id
                                                                          AND a.file_id = b.file_id
                 INNER JOIN sys.master_files c ON a.database_id = c.database_id
                                                  AND a.file_id = c.file_id
            ORDER BY DB_NAME(a.database_id);
     DELETE FROM DBATasks..tblFileStats
     WHERE NumOfBytesRead = 0
           AND NumOfBytesWritten = 0
           AND RunTime > @lastruntime;
     DELETE FROM DBATasks..tblFileStats
     WHERE RunTime < DATEADD(DD, -@retentiondays, GETDATE());
GO

USE [msdb]
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DBA - Collect FileStats Data')
EXEC msdb.dbo.sp_delete_job @job_name=N'DBA - Collect FileStats Data', @delete_unused_schedule=1
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'DBA - Collect FileStats Data')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - Collect FileStats Data', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'FileStats Data', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBATasks..[spFileStats]', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 10 Min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20010820, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
