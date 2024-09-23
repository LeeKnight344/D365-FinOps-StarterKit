CREATE PROC [dvtosql].[target_dedupAndMerge] @tablename [nvarchar](100),@schema [nvarchar](10),@newdatetimemarker [datetime2],@debug_mode [bit] AS 
        declare @insertCount bigint,
                @updateCount bigint,
                @deleteCount bigint,
                @versionnumber bigint;

        declare @incremental int;
        declare @dedupData nvarchar(max);

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
                        RENAME OBJECT::{schema}.{tablename} TO _old_{tablename};

                    RENAME OBJECT::{schema}._new_{tablename} TO {tablename};
            
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

        -- dedup and merge

        set @dedupData = replace(replace('print(''--De-duplicate the data in {schema}._new_{tablename}--'');
        IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
        BEGIN
        WITH CTE AS
        ( SELECT ROW_NUMBER() OVER (PARTITION BY Id ORDER BY versionnumber DESC) AS rn, Id, versionnumber,SinkCreatedOn FROM {schema}._new_{tablename}
        )

        SELECT *
        INTO #TempDuplicates{tablename}
        FROM CTE
        WHERE rn > 1;

        DELETE t
        FROM {schema}._new_{tablename} t
        INNER JOIN #TempDuplicates{tablename} tmp ON t.Id = tmp.Id and t.versionnumber = tmp.versionnumber and t.SinkCreatedOn = tmp.SinkCreatedOn;

        DELETE t
        FROM {schema}._new_{tablename} t
		where t.IsDelete = 1;

        drop table  #TempDuplicates{tablename};

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
        RENAME OBJECT::{schema}._new_{tablename}  TO {tablename};

        select @versionnumber = max(versionnumber), @insertCount = count(1) from  {schema}.{tablename};
        END'
        ,'{schema}', @schema)
        ,'{tablename}', @tablename);

        IF  @debug_mode = 0 
            Execute sp_executesql @renameTableAndCreateIndex,@ParmDefinition, @insertCount=@insertCount OUTPUT, @updateCount=@updateCount OUTPUT,@deleteCount=@deleteCount OUTPUT, @versionnumber = @versionnumber OUTPUT;
        ELSE
            print (@renameTableAndCreateIndex)

        DECLARE @insertcolumns NVARCHAR(MAX);
        DECLARE @valuescolumns NVARCHAR(MAX);

        -- For the insert columns and values
        SELECT @insertColumns = STRING_AGG(convert(nvarchar(max), '[' + column_name) +']', ', ') FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME =@tablename and TABLE_SCHEMA = @schema  AND column_name <> '$FileName';

        SELECT @valuesColumns = STRING_AGG(convert(nvarchar(max),'source.[' + column_name + ']'), ', ') FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME =@tablename and TABLE_SCHEMA = @schema AND column_name <> '$FileName';


        DECLARE @mergedata nvarchar(max) = replace(replace(replace(replace(
        convert(nvarchar(max),'IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[{schema}].[_new_{tablename}]'') AND type in (N''U'')) 
        BEGIN;
        print(''-- Merge data from _new_{tablename} to {tablename}----'')

        DELETE target
        FROM {schema}.{tablename} AS target
        INNER JOIN {schema}._new_{tablename} AS source
        ON target.Id = source.Id;

        INSERT INTO {schema}.{tablename} ({insertcolumns})
        SELECT {valuescolumns} 
        FROM {schema}._new_{tablename} AS source
        where source.IsDelete is Null;

        select @versionnumber = max(versionnumber) from  {schema}.{tablename};

        set @versionnumber = isNull(@versionnumber, 0)
            
        drop table {schema}._new_{tablename};

        END;')
        ,'{schema}', @schema),
        '{tablename}', @tablename),
        '{insertcolumns}', @insertcolumns),
        '{valuescolumns}', @valuescolumns)

        IF  @debug_mode = 0 
            Execute sp_executesql @mergedata, @ParmDefinition, @insertCount=@insertCount OUTPUT, @updateCount=@updateCount OUTPUT,@deleteCount=@deleteCount OUTPUT, @versionnumber = @versionnumber OUTPUT;
        ELSE 
            select (@mergedata);

        update [dvtosql].[_controltableforcopy]
        set lastcopystatus = 0, lastdatetimemarker = @newdatetimemarker,  [lastcopyenddatetime] = getutcdate(), lastbigintmarker = @versionnumber
        where tablename = @tablename AND  tableschema = @schema

