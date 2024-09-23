
CREATE   PROC dvtosql.source_GetNewDataToCopy
(
	@controltable nvarchar(max), 
	@sourcetableschema nvarchar(10),
	@environment nvarchar(1000), 
	@incrementalCSV int =1, 
	@externaldatasource nvarchar(1000) = '', 
	@lastdatetimemarker datetime2 = '1900-01-01' 
)
AS

drop table if exists #controltable;
CREATE TABLE #controltable
	(
		[tableschema] [varchar](20) null,
		[tablename] [varchar](255) null,
		[datetime_markercolumn] varchar(100),
		[bigint_markercolumn] varchar(100),
		[environment] varchar(1000),
		[lastdatetimemarker] nvarchar(100) ,
		lastcopystatus int,
		lastbigintmarker bigint,
		[active] int,
		[incremental] int,
		[selectcolumns] nvarchar(max) null,
		[datatypes] nvarchar(max) null,
		[columnnames] nvarchar(max) null
	);

insert into #controltable (tableschema, tablename,datetime_markercolumn,bigint_markercolumn, environment, lastdatetimemarker, lastcopystatus, lastbigintmarker, active, incremental, selectcolumns, datatypes, columnnames)
select tableschema, tablename, datetime_markercolumn,bigint_markercolumn, environment, lastdatetimemarker, lastcopystatus, lastbigintmarker, active, incremental, selectcolumns, datatypes, columnnames  from openjson(@controltable)
	with (tableschema nvarchar(100), tablename nvarchar(200), datetime_markercolumn varchar(100),bigint_markercolumn varchar(100), lastdatetimemarker nvarchar(100), active int, incremental int, environment nvarchar(100) ,lastcopystatus int,lastbigintmarker bigint, 
	columnnames nvarchar(max), selectcolumns nvarchar(max), datatypes nvarchar(max) )

select 
	@lastdatetimemarker= max(lastdatetimemarker) 
from #controltable 
where 
	[active] = 1 and
	lastcopystatus != 1	and 
	lastdatetimemarker != '1900-01-01T00:00:00';

set  @lastdatetimemarker = isnull(@lastdatetimemarker, '1900-01-01T00:00:00')
print(@lastdatetimemarker);

declare @newtables nvarchar(max);
select 
	@newtables= isnull(string_agg(convert(nvarchar(max), tablename), ','),'')
from #controltable 
where 
	[active] = 1 and
	lastcopystatus != 1
	and (lastdatetimemarker = '1900-01-01T00:00:00' or incremental =0);

declare @tablelist_inNewFolders nvarchar(max);
declare @minfoldername nvarchar(100) = '';
declare @maxfoldername nvarchar(100) = '';
declare @SelectTableData nvarchar(max);
declare @newdatetimemarker datetime2 = getdate();
declare @whereClause nvarchar(200) = ' where {datetime_markercolumn} between ''{lastdatetimemarker}'' and ''{newdatetimemarker}''';

set @SelectTableData  = 'SELECT * from {tableschema}.{tablename}';

IF (@incrementalCSV = 1)
	BEGIN;
		
		declare @ParmDefinition NVARCHAR(500);
		declare @newfolders nvarchar(max); 

		-- get newFolders and max modeljson by listing out model.json files in each timestamp folders */model.json
		-- @lastFolderMarker helps  elliminate folders and find new folders created after this folder
		SET @ParmDefinition = N'@minfoldername nvarchar(max) OUTPUT, @maxfoldername nvarchar(100) OUTPUT, @tablelist_inNewFolders nvarchar(max) OUTPUT';

		declare @getNewFolders nvarchar(max) = 
		'SELECT     
		@minfoldername = isNull(min(minfolder),format(GETUTCDATE(),''yyyy-MM-ddTHH.mm.ssZ'')),
		@maxfoldername = isNull(max(maxfolderPath),format(GETUTCDATE(),''yyyy-MM-ddTHH.mm.ssZ'')),  
		@tablelist_inNewFolders = isnull(string_agg(convert(nvarchar(max), x.tablename),'',''),'''')
		from 
		(
			select 
			tablename,
			min(r.filepath(1)) as minfolder,
			max(r.filepath(1)) as maxfolderPath
			FROM
				OPENROWSET(
					BULK ''*/model.json'',
					DATA_SOURCE = ''{externaldatasource}'',
					FORMAT = ''CSV'',
					FIELDQUOTE = ''0x0b'',
					FIELDTERMINATOR =''0x0b'',
					ROWTERMINATOR = ''0x0b''
				)
				WITH 
				(
					jsonContent varchar(MAX)
				) AS r
				cross apply openjson(jsonContent) with (entities nvarchar(max) as JSON)
				cross apply openjson (entities) with([tablename] NVARCHAR(200) ''$.name'', [partitions] NVARCHAR(MAX) ''$.partitions'' as JSON ) t
				where r.filepath(1) >''{lastFolderMarker}'' and [partitions] != ''[]''
				group by tablename
			) x';

		set @getNewFolders = replace(replace (@getNewFolders, '{externaldatasource}',@externaldatasource), '{lastFolderMarker}', FORMAT(@lastdatetimemarker, 'yyyy-MM-ddTHH.mm.ssZ'));

		print(@getNewFolders)

		execute sp_executesql @getNewFolders, @ParmDefinition, @tablelist_inNewFolders=@tablelist_inNewFolders OUTPUT, @maxfoldername=@maxfoldername OUTPUT, @minfoldername=@minfoldername OUTPUT;

		set @tablelist_inNewFolders = @tablelist_inNewFolders + ',' +  @newtables
		
		print ('Folder to process:' + @minfoldername + '...' + @maxfoldername)
		print('Tables in new folders:' + @tablelist_inNewFolders)
		print ('New marker value:' + @maxfoldername);

		set @newdatetimemarker =  convert(datetime2, replace(@maxfoldername, '.', ':'));
		
		select 
		tableschema,
		tablename,
		lastdatetimemarker,
		@newdatetimemarker as newdatetimemarker ,
		replace(replace(replace(replace(replace(replace(replace(convert(nvarchar(max),@SelectTableData  + (case when incremental =1 then @whereClause else '' end)), 
		'{tableschema}', @sourcetableschema),
		'{tablename}', tablename),
		'{lastdatetimemarker}', lastdatetimemarker),
		'{newdatetimemarker}', @newdatetimemarker),
		'{lastbigintmarker}', lastbigintmarker),
		'{datetime_markercolumn}', datetime_markercolumn),
		'{bigint_markercolumn}', bigint_markercolumn)
		 as selectquery,
		 datatypes
	from #controltable
	where 
		tablename in (select value from string_split(@tablelist_inNewFolders, ',')) and 
		[active] = 1 and 
		lastcopystatus != 1
	END;
	ELSE
	BEGIN;
		print('--delta tables - get newdatetimemarker---')
		declare @tablenewdatetimemarker nvarchar(max);

                  -- if the database is synapse link created lakehouse db - get the location from the first datasource
                  declare @deltastoragelocation varchar(4000);
                  select top 1 @deltastoragelocation = [location]  from sys.external_data_sources
                        where name like 'datasource_%'

                  -- if the database is created by the pipeline then take the location from external ds created by script
                  if (@deltastoragelocation is null)
                  begin
					select top 1 @deltastoragelocation = [location] 
					from sys.external_data_sources
                        where name = @externaldatasource
					
					-- added to support when the storage location does not end in '/'
					if (RIGHT(@deltastoragelocation, 1) != '/')
						set @deltastoragelocation = @deltastoragelocation + '/deltalake/'  
					else
					set @deltastoragelocation = @deltastoragelocation + 'deltalake/'
			    end


                  declare @tableschema varchar(20)= (select top 1 tableschema from #controltable where incremental = 1 and [active] = 1);

                  declare @newtableconversion nvarchar(max) = 'SELECT distinct ''{tableschema}'' as tableschema, replace(TableName, ''_partitioned'', '''') as TableName, ''{newdatetimemarker}'' as newdatetimemarker
                  FROM  OPENROWSET
                        ( BULK ''{deltastoragelocation}conversionresults/*.info'',
                        FORMAT = ''CSV'',
                        FIELDQUOTE = ''0x0b'',
                        FIELDTERMINATOR =''0x0b'',
                        ROWTERMINATOR = ''0x0b''
                  )
                  WITH
                  (
                        jsonContent varchar(MAX)
                  ) AS r
                  cross apply openjson (jsonContent) with (JobType int, QueueTime datetime2,  TableNames nvarchar(max) ''$.TableNames'' as json)
                  cross apply openjson(TableNames) with (TableName nvarchar(200) ''$'' )
                  where queuetime > ''{lastdatetimemarker}''';

                  set @tablenewdatetimemarker = replace(replace(replace(REPLACE(@newtableconversion, '{tableschema}', @tableschema), '{newdatetimemarker}', @newdatetimemarker), '{lastdatetimemarker}', @lastdatetimemarker), '{deltastoragelocation}', @deltastoragelocation);

                  print(@tablenewdatetimemarker)
            
            --          select @tablenewdatetimemarker= string_agg(convert(nvarchar(max),tablenewdatetimemarker), ' union ')
            --          from (
            --          select
            --                'select ''' + tableschema +  ''' as tableschema, ''' + tablename +  ''' as tablename, max(' + datetime_markercolumn + ') as newdatetimemarker from ' + @sourcetableschema + '.' + tablename as tablenewdatetimemarker
            --          from #controltable
            --          where incremental = 1 and
            --          [active] = 1 and
            --          lastcopystatus != 1
            --          )x
            --    end

            drop table if exists #newcontroltable;
            CREATE TABLE #newcontroltable
                  (
                        [tableschema] [varchar](20) null,
                        [tablename] [varchar](255) null,
                        [newdatetimemarker] datetime2
                  )
            insert into #newcontroltable
            execute sp_executesql @tablenewdatetimemarker

            insert into #newcontroltable ([tableschema], [tablename], [newdatetimemarker] )
            select @tableschema,   value, @newdatetimemarker  from string_split(@newtables, ',')  

            select
            distinct
            c.tableschema,
            c.tablename,
            lastdatetimemarker,
            n.newdatetimemarker as newdatetimemarker ,
            replace(replace(replace(replace(replace(replace(replace(convert(nvarchar(max),@SelectTableData  + (case when incremental =1 then @whereClause else '' end)),
            '{tableschema}', @sourcetableschema),
            '{tablename}', c.tablename),
            '{lastdatetimemarker}', lastdatetimemarker),
            '{newdatetimemarker}', newdatetimemarker),
            '{lastbigintmarker}', lastbigintmarker),
            '{datetime_markercolumn}', datetime_markercolumn),
            '{bigint_markercolumn}', bigint_markercolumn)
             as selectquery,
             datatypes
      from #controltable c
      join #newcontroltable n on c.tableschema = n.tableschema and c.tablename = n.tablename
      where
            c.lastdatetimemarker < newdatetimemarker and
            [active] = 1 and
            lastcopystatus != 1

      END


