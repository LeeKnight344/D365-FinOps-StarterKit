

CREATE   PROC [dvtosql].target_dedupAndMerge
(
@tablename nvarchar(100),
@schema nvarchar(10),
@newdatetimemarker datetime2,
@debug_mode bit = 0,
@pipelinerunid nvarchar(100) = ''
)
AS 

declare @insertCount bigint,
        @updateCount bigint,
        @deleteCount bigint,
        @versionnumber bigint;

declare @incremental int;

select top 1
	@incremental = incremental 
from [dvtosql].[_controltableforcopy]
where 
	tableschema = @schema AND
	tablename = @tablename;  

update [dvtosql].[_controltableforcopy]
set 
	lastcopystatus = 1, 
	[lastcopystartdatetime] = getutcdate()
where 
	tableschema = @schema AND
	tablename = @tablename;  


if (@incremental = 0)
BEGIN
	declare @fullcopy nvarchar(max) = replace(replace('IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
		BEGIN
			print(''--full export - swap table --'')
		
			IF OBJECT_ID(''{schema}.{tablename}'', ''U'') IS NOT NULL 
			exec sp_rename ''{schema}.{tablename}'', ''_old_{tablename}'';

			exec sp_rename ''{schema}._new_{tablename}'', ''{tablename}'';
	
			IF OBJECT_ID(''{schema}._old_{tablename}'', ''U'') IS NOT NULL 
				DROP TABLE {schema}._old_{tablename};
		END'
	,'{schema}', @schema)
	,'{tablename}', @tablename);

	IF  @debug_mode = 0 
		Execute sp_executesql @fullcopy;
	ELSE 
		print (@fullcopy);
END
ELSE
BEGIN;
	-- dedup and merge
	declare @dedupData nvarchar(max) = replace(replace('print(''--De-duplicate the data in {schema}._new_{tablename}--'');
	IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
	BEGIN
		WITH CTE AS
		( SELECT ROW_NUMBER() OVER (PARTITION BY Id ORDER BY versionnumber DESC) AS rn FROM {schema}._new_{tablename}
		)
		DELETE FROM CTE WHERE rn > 1;
	END'
	,'{schema}', @schema)
	,'{tablename}', @tablename);

	IF  @debug_mode = 0 
		Execute sp_executesql @dedupData;
	ELSE 
		print (@dedupData);

	DECLARE @ParmDefinition NVARCHAR(500);
	SET @ParmDefinition = N'@insertCount bigint OUTPUT, @updateCount bigint  OUTPUT, @deleteCount bigint  OUTPUT, @versionnumber bigint  OUTPUT';


	declare @renameTableAndCreateIndex nvarchar(max) = replace(replace('IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
	AND NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[{tablename}]'') AND type in (N''U'')) 
	BEGIN

	print(''--_new_{tablename} exists and {tablename} does not exists ...rename the table --'')
	exec sp_rename ''{schema}._new_{tablename}'', ''{tablename}''
 
	print(''-- -- create index on table----'')
	IF EXISTS ( SELECT 1 FROM information_schema.columns WHERE table_schema = ''{schema}'' and table_name = ''{tablename}'' AND column_name = ''Id'') 
		AND NOT EXISTS ( SELECT 1 FROM sys.indexes WHERE name = ''{schema}_{tablename}_id_idx'' AND object_id = OBJECT_ID(''[{schema}].[{tablename}]''))
	BEGIN
		CREATE UNIQUE INDEX {schema}_{tablename}_id_idx ON [{schema}].[{tablename}](Id) with (ONLINE = ON);
	END;

	IF EXISTS ( SELECT 1 FROM information_schema.columns WHERE  table_schema = ''{schema}'' and  table_name = ''{tablename}'' AND column_name = ''recid'') 
		AND NOT EXISTS ( SELECT 1 FROM sys.indexes WHERE name = ''{schema}_{tablename}_recid_idx'' AND object_id = OBJECT_ID(''[{schema}].[{tablename}]''))
	BEGIN
		CREATE UNIQUE INDEX {schema}_{tablename}_RecId_Idx ON [{schema}].[{tablename}](recid) with (ONLINE = ON);
	END;

	IF EXISTS ( SELECT 1 FROM information_schema.columns WHERE  table_schema = ''{schema}'' and  table_name = ''{tablename}'' AND column_name = ''versionnumber'') 
		AND NOT EXISTS ( SELECT 1 FROM sys.indexes WHERE name = ''{schema}_{tablename}_versionnumber_idx'' AND object_id = OBJECT_ID(''[{schema}].[{tablename}]''))
	BEGIN
		CREATE  INDEX {schema}_{tablename}_versionnumber_Idx ON [{schema}].[{tablename}](versionnumber) with (ONLINE = ON);
	END;

	select @versionnumber = max(versionnumber), @insertCount = count(1) from  {schema}.{tablename};


	END'
	,'{schema}', @schema)
	,'{tablename}', @tablename);

	IF  @debug_mode = 0 
		Execute sp_executesql @renameTableAndCreateIndex,@ParmDefinition, @insertCount=@insertCount OUTPUT, @updateCount=@updateCount OUTPUT,@deleteCount=@deleteCount OUTPUT, @versionnumber = @versionnumber OUTPUT;
	ELSE
		print (@renameTableAndCreateIndex)

	DECLARE @updatestatements NVARCHAR(MAX);
	DECLARE @insertcolumns NVARCHAR(MAX);
	DECLARE @valuescolumns NVARCHAR(MAX);

	-- Generate update statements
	SELECT @updateStatements = STRING_AGG(convert(nvarchar(max),'target.[' + column_name + '] = source.[' + column_name + ']'), ', ') 
	FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME =@tablename and TABLE_SCHEMA = @schema AND column_name <> 'Id' AND column_name <> '$FileName'; 

	-- For the insert columns and values
	SELECT @insertColumns = STRING_AGG(convert(nvarchar(max), '[' + column_name) +']', ', ') FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME =@tablename and TABLE_SCHEMA = @schema  AND column_name <> '$FileName';

	SELECT @valuesColumns = STRING_AGG(convert(nvarchar(max),'source.[' + column_name + ']'), ', ') FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME =@tablename and TABLE_SCHEMA = @schema AND column_name <> '$FileName';


	DECLARE @mergedata nvarchar(max) = replace(replace(replace(replace(replace(
	convert(nvarchar(max),'IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
	BEGIN;
	print(''-- Merge data from _new_{tablename} to {tablename}----'')

	DECLARE @MergeOutput TABLE (
		MergeAction NVARCHAR(10)
	);

	SET NOCOUNT OFF;

	-- Delete data in the target table based on source.
	DELETE target FROM {schema}.{tablename} AS target
	INNER JOIN {schema}._new_{tablename} AS source ON target.id = source.id and source.isdelete = 1;
	
	SELECT @deleteCount = @@ROWCOUNT;


	--Now remove data from the source to avoid update during the merge function
	DELETE FROM {schema}._new_{tablename} Where IsDelete = 1;

	MERGE INTO {schema}.{tablename} AS target
	USING {schema}._new_{tablename} AS source
	ON target.Id = source.Id
	WHEN MATCHED AND (target.versionnumber < source.versionnumber) THEN 
		UPDATE SET {updatestatements}
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT ({insertcolumns}) 
		VALUES ({valuescolumns})
	OUTPUT $action INTO @MergeOutput(MergeAction );

	 select @insertCount = [INSERT],
			@updateCount = [UPDATE]
		 from (select MergeAction from @MergeOutput) mergeResultsPlusEmptyRow     
		 pivot (count(MergeAction) 
			for MergeAction in ([INSERT],[UPDATE])) 
			as mergeResultsPivot;

	select @versionnumber = max(versionnumber) from  {schema}.{tablename};
	
	drop table {schema}._new_{tablename};


	END;')
	,'{schema}', @schema),
	'{tablename}', @tablename),
	'{updatestatements}', @updatestatements),
	'{insertcolumns}', @insertcolumns),
	'{valuescolumns}', @valuescolumns)

	IF  @debug_mode = 0 
		Execute sp_executesql @mergedata, @ParmDefinition, @insertCount=@insertCount OUTPUT, @updateCount=@updateCount OUTPUT,@deleteCount=@deleteCount OUTPUT, @versionnumber = @versionnumber OUTPUT;
	ELSE 
		print(@mergedata);

	update [dvtosql].[_controltableforcopy]
	set lastcopystatus = 0, lastdatetimemarker = @newdatetimemarker,  [lastcopyenddatetime] = getutcdate(), lastbigintmarker = @versionnumber
	where tablename = @tablename AND  tableschema = @schema

	update [dvtosql].[_datalaketosqlcopy_log]
	set copystatus = 0, [rowsinserted] = @insertCount, [rowsupdated] = @updateCount, [rowsdeleted]=@deleteCount,  [enddatetime] = getutcdate()
	where tablename =  concat(@schema, '.', @tablename)  and pipelinerunid= @pipelinerunid 
END 

