--https://stackoverflow.com/questions/7070053/convert-a-sql-query-result-table-to-an-html-table-for-email
USE [DBATasks]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spQueryToHtmlTable]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spQueryToHtmlTable]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spQueryToHtmlTable]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[spQueryToHtmlTable] AS' 
END
GO

ALTER PROCEDURE [dbo].[spQueryToHtmlTable]
(@query   NVARCHAR(MAX), --A query to turn into HTML format. It should not include an ORDER BY clause.
 @orderBy NVARCHAR(MAX) = NULL, --An optional ORDER BY clause. It should contain the words 'ORDER BY'.
 @OperatorName nvarchar(128) = 'SQLDBATeam',
 @Subject nvarchar(128) = 'HTML Report',
 @html    NVARCHAR(MAX) = NULL OUTPUT --The HTML output of the procedure.
)
AS
         BEGIN
             SET NOCOUNT ON;
             IF @orderBy IS NULL
                 BEGIN
                     SET @orderBy = '';
                 END;
             SET @orderBy = REPLACE(@orderBy, '''', '''''');
             DECLARE @realQuery NVARCHAR(MAX)= '
				DECLARE @headerRow nvarchar(MAX);
				DECLARE @cols nvarchar(MAX);    

				SELECT * INTO #dynSql FROM ('+@query+') sub;

				SELECT @cols = COALESCE(@cols + '', '''''''', '', '''') + ''['' + name + ''] AS ''''td''''''
				FROM tempdb.sys.columns 
				WHERE object_id = object_id(''tempdb..#dynSql'')
				ORDER BY column_id;

				SET @cols = ''SET @html = CAST(( SELECT '' + @cols + '' FROM #dynSql '+@orderBy+' FOR XML PATH(''''tr''''), ELEMENTS XSINIL) AS nvarchar(max))''    

				EXEC sys.sp_executesql @cols, N''@html nvarchar(MAX) OUTPUT'', @html=@html OUTPUT

				SELECT @headerRow = COALESCE(@headerRow + '''', '''') + ''<th>'' + name + ''</th>'' 
				FROM tempdb.sys.columns 
				WHERE object_id = object_id(''tempdb..#dynSql'')
				ORDER BY column_id;

				SET @headerRow = ''<tr>'' + @headerRow + ''</tr>'';

				SET @html = ''<table border="1">'' + @headerRow + @html + ''</table>'';    
				';
             EXEC sys.sp_executesql
                  @realQuery,
                  N'@html nvarchar(MAX) OUTPUT',
                  @html = @html OUTPUT;
         END;
    
declare @email_to nvarchar(max)
 SELECT @email_to = email_address
     FROM msdb..sysoperators
     WHERE NAME = @OperatorName;
SET @Subject = @Subject + ' - ' + CONVERT(nvarchar(128),@@SERVERNAME)
EXEC msdb.dbo.sp_send_dbmail
    @recipients = @email_to,
    @subject = @Subject,
    @body = @html,
    @body_format = 'HTML',
    @query_no_truncate = 1,
    @attach_query_result_as_file = 0;
GO
