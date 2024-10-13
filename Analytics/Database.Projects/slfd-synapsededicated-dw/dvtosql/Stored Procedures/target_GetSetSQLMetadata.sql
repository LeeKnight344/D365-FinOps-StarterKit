CREATE PROC [dvtosql].[target_GetSetSQLMetadata] @tableschema [nvarchar](10),@StorageDS [nvarchar](2000),@sqlMetadata [nvarchar](max),@datetime_markercolumn [nvarchar](100),@controltable [nvarchar](max) OUT AS

	declare  @storageaccount nvarchar(1000);
	declare  @container nvarchar(1000);
	declare  @externalds_name nvarchar(1000);

	--declare	@datetime_markercolumn nvarchar(100)= 'SinkModifiedOn';
	declare	@bigint_markercolumn nvarchar(100) = 'versionnumber';
	declare	@lastdatetimemarker nvarchar(max) = '1900-01-01';
	declare  @fullexportList nvarchar(max)= 'GlobalOptionsetMetadata,OptionsetMetadata,StateMetadata,StatusMetadata,TargetMetadata';

	if @StorageDS != ''
	begin
		set @storageaccount = (select value from string_split(@StorageDS, '/', 1) where ordinal = 3)
		set @container = (select value from string_split(@StorageDS, '/', 1) where ordinal = 4)
	end

	IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dvtosql].[_controltableforcopy]') AND type in (N'U'))
		CREATE TABLE [dvtosql].[_controltableforcopy]
		(
			[tableschema] [varchar](20) null,
			[tablename] [varchar](255) null,
			[datetime_markercolumn] varchar(100),
			[bigint_markercolumn] varchar(100),
			[storageaccount] varchar(1000) null,
			[container] varchar(1000) null,
			[environment] varchar(1000) null,
			[datapath] varchar(1000) null,
			[lastcopystartdatetime] [datetime2](7) null,
			[lastcopyenddatetime] [datetime2](7) null,
			[lastdatetimemarker] [datetime2](7) default '1/1/1900',
			[lastbigintmarker] bigint default -1,
			[lastcopystatus] [int] default 0,
			[refreshinterval] [int] default 60,
			[active] int default 1,
			[incremental] [int] default 1,
			[selectcolumns] nvarchar(max) null,
			[datatypes] nvarchar(max) null,
			[columnnames] nvarchar(max) null
		)	WITH(HEAP);

	IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dvtosql].[_datalaketosqlcopy_log]') AND type in (N'U'))
		CREATE TABLE [dvtosql].[_datalaketosqlcopy_log]
		(
			[pipelinerunid] [varchar](200) NOT NULL,
			[tablename] [varchar](200) NOT NULL,
			[minfolder] [varchar](100) NULL,
			[maxfolder] [varchar](100) NULL,
			[copystatus] [int] NULL default(0),
			[rowsinserted] [bigint] NULL default(0),
			[rowsupdated] [bigint] NULL default(0),
			[rowsdeleted] [bigint] NULL default(0),
			[startdatetime] [datetime2](7),
			[enddatetime] [datetime2](7) NULL
		) WITH(HEAP);

	Insert into [dvtosql].[_controltableforcopy] (tableschema, tablename, datetime_markercolumn, bigint_markercolumn, storageaccount, container, environment, datapath, selectcolumns, datatypes, columnnames)
	select 
		@tableschema, tablename, @datetime_markercolumn,@bigint_markercolumn, @storageaccount, @container, @container, '*' + tablename + '*.csv', selectcolumns, datatypes, columnnames
	from  openjson(@sqlmetadata) with([tablename] NVARCHAR(200), [selectcolumns] NVARCHAR(MAX), datatypes NVARCHAR(MAX), columnnames NVARCHAR(MAX)) t 
	where tablename not in  (select tablename COLLATE Latin1_General_BIN2 from [dvtosql].[_controltableforcopy]  where tableschema COLLATE Latin1_General_BIN2  = @tableschema COLLATE Latin1_General_BIN2)

	-- update full export tables
	update [dvtosql].[_controltableforcopy] 
		set incremental = 0
	where tablename in (select value from string_split(@fullexportList, ','));

	update target 
		SET  target.datatypes = source.datatypes, target.selectcolumns = source.selectcolumns, target.columnnames = source.columnnames 
	FROM [dvtosql].[_controltableforcopy] as target
	INNER JOIN (select 
			tablename, selectcolumns, datatypes, columnnames
		from  openjson(@sqlmetadata) with([tablename] NVARCHAR(200), [selectcolumns] NVARCHAR(MAX), datatypes NVARCHAR(MAX), columnnames NVARCHAR(MAX)) 
		)source 
	on   target.tableschema COLLATE Latin1_General_BIN2 = @tableschema COLLATE Latin1_General_BIN2 and target.tablename COLLATE Latin1_General_BIN2 = source.tablename COLLATE Latin1_General_BIN2
	where  target.datatypes COLLATE Latin1_General_BIN2 != source.datatypes COLLATE Latin1_General_BIN2;


	select 
		[tableschema], 
		[tablename], 
		[datetime_markercolumn],
		[bigint_markercolumn],
		case 
			when @lastdatetimemarker  = '1900-01-01' Then isnull([lastdatetimemarker], '')  
			else @lastdatetimemarker 
		end as lastdatetimemarker,
		lastbigintmarker,
		lastcopystatus,
		[active],
		incremental,
		environment,  
		datatypes, 
		columnnames,
		replace(selectcolumns, '''','''''') as selectcolumns
	from [dvtosql].[_controltableforcopy]
	where  [active] = 1 AND  tableschema = @tableschema

