

CREATE   PROC dvtosql.target_GetSetSQLMetadata
(
	@tableschema nvarchar(10), 
	@StorageDS nvarchar(2000) = '', 
	@sqlMetadata nvarchar(max) = '{}', 
	@datetime_markercolumn nvarchar(100)= 'SinkModifiedOn',
	@bigint_markercolumn nvarchar(100) = 'versionnumber',
	@lastdatetimemarker nvarchar(max) = '1900-01-01',
	@controltable nvarchar(max) OUTPUT
)
AS

declare  @storageaccount nvarchar(1000);
declare  @container nvarchar(1000);
declare  @externalds_name nvarchar(1000);
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
		[active] [int] default 1,
		[incremental] [int] default 1,
		[selectcolumns] nvarchar(max) null,
		[datatypes] nvarchar(max) null,
		[columnnames] nvarchar(max) null
	);

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
		);


With sqlmetadata as 
(
	select * 
	from openjson(@sqlmetadata) with([tablename] NVARCHAR(200), [selectcolumns] NVARCHAR(MAX), datatypes NVARCHAR(MAX), columnnames NVARCHAR(MAX)) t
)

MERGE INTO [dvtosql].[_controltableforcopy] AS target
	USING sqlmetadata AS source
	ON target.tableschema = @tableschema and  target.tablename = source.tablename
	WHEN MATCHED AND (target.datatypes != source.datatypes) THEN 
		UPDATE SET  target.datatypes = source.datatypes, target.selectcolumns = source.selectcolumns, target.columnnames = source.columnnames 
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT (tableschema, tablename, datetime_markercolumn, bigint_markercolumn, storageaccount, container, environment, datapath, selectcolumns, datatypes, columnnames)
		VALUES (@tableschema, tablename, @datetime_markercolumn,@bigint_markercolumn, @storageaccount, @container, @container, '*' + tablename + '*.csv', selectcolumns, datatypes, columnnames);

	-- update full export tables
	update [dvtosql].[_controltableforcopy] 
		set incremental = 0
	where tablename in (select value from string_split(@fullexportList, ','));


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
		environment,  
		incremental,
		datatypes, 
		columnnames,
		replace(selectcolumns, '''','''''') as selectcolumns
	from [dvtosql].[_controltableforcopy]
	where  [active] = 1 and tableschema = @tableschema


