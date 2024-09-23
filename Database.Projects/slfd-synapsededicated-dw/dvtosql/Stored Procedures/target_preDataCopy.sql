CREATE PROC [dvtosql].[target_preDataCopy] @pipelinerunId [nvarchar](100),@tableschema [nvarchar](10),@tablename [nvarchar](200),@columnnames [nvarchar](max),@lastdatetimemarker [nvarchar](100),@newdatetimemarker [nvarchar](100) AS

declare @debug_mode int = 0
declare @precopydata nvarchar(max) = replace(replace(replace(replace(replace(replace(convert(nvarchar(max),'print(''--creating table {schema}._new_{tablename}--'');
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
BEGIN
	DROP TABLE [{schema}].[_new_{tablename}] 
END

CREATE TABLE [{schema}].[_new_{tablename}] ({columnnames}) WITH(HEAP)

INSERT INTO  [dvtosql].[_datalaketosqlcopy_log](pipelinerunid, tablename, minfolder,maxfolder) 
values(''{pipelinerunId}'', ''{tablename}'', ''{lastdatetimemarker}'',''{newdatetimemarker}'' )

update [dvtosql].[_controltableforcopy]
set lastcopystatus = 1, [lastcopystartdatetime] = getutcdate()
where tablename = ''{tablename}'' AND  tableschema = ''{schema}''
')
,'{columnnames}', @columnnames)
,'{schema}', @tableschema)
,'{tablename}', @tablename)

,'{pipelinerunId}', @pipelinerunId)
,'{lastdatetimemarker}', @lastdatetimemarker)
,'{newdatetimemarker}', @newdatetimemarker)
;

IF  @debug_mode = 0 
	Execute sp_executesql @precopydata;
ELSE 
	print (@precopydata);

