CREATE   FUNCTION dvtosql.source_GetSQLMetadataFromCDM
(	
	@modeljson nvarchar(max),
	@enumtranslation nvarchar(max) = '{}'
)
RETURNS TABLE 
AS
RETURN 
(
with table_field_enum_map as 
(
	select 
		tablename, 
		columnname, 
		enum as enumtranslation 
	from string_split(@enumtranslation, ';')
	cross apply openjson(value) 
	with (tablename nvarchar(100),columnname nvarchar(100), enum nvarchar(max))
)

	select 
		tablename as tablename,
		string_agg(convert(varchar(max), selectcolumn), ',') as selectcolumns,
		string_agg(convert(varchar(max), + '[' + columnname + '] ' +  sqldatatype) , ',') as datatypes,
		string_agg(convert(varchar(max), columnname), ',') as columnnames
	from 
	(select  
		t.[tablename] as tablename,
		name as columnname,
		case    
			when datatype = 'string'   then IsNull(replace('(' + em.enumtranslation + ')','~',''''),  + 'isNull(['+  t.tablename + '].['+  name + '], '''')') + ' AS [' + name  + ']' 
			when datatype = 'datetime' then 'isNull(['+  t.tablename + '].['  + name + '], ''1900-01-01'') AS [' + name  + ']' 
			when datatype = 'datetimeoffset' then 'isNull(['+  t.tablename + '].['  + name + '], ''1900-01-01'') AS [' + name  + ']' 
			else '['+  t.tablename + '].[' + name + ']' + ' AS [' + name  + ']' 
		end as selectcolumn,
		datatype as datatype,
		case      
			when datatype ='guid' then 'nvarchar(100)'    
			when datatype = 'string' and  (maxlength >= 8000 or  maxlength < 1 or maxlength is null)  then 'nvarchar(max)'    
			when datatype = 'string' and  maxlength < 8000 then 'nvarchar(' + try_convert(nvarchar(5),maxlength) + ')'
			when datatype = 'int64' then 'bigint'   
			when datatype = 'datetime' then 'datetime2' 
			when datatype = 'datetimeoffset' then 'datetime2' 
			when datatype = 'boolean' then 'bit'   
			when datatype = 'double' then 'real'    
			when datatype = 'decimal' then 'decimal(' + try_convert(varchar(10), [precision]) + ',' + try_convert(varchar(10), [scale])+ ')'  
			else datatype 
		end as sqldatatype
	from openjson(@modeljson) with(entities nvarchar(max) as JSON) 
	cross apply openjson (entities) with([tablename] NVARCHAR(200) '$.name', [attributes] NVARCHAR(MAX) '$.attributes' as JSON ) t
	cross apply openjson(attributes) with ( name varchar(200) '$.name',  datatype varchar(50) '$.dataType' , maxlength int '$.maxLength' ,precision int '$.traits[0].arguments[0].value' ,scale int '$.traits[0].arguments[1].value') c   
	left outer join table_field_enum_map em on t.[tablename] = em.tablename and c.name = em.columnname
	) metadata
	group by tablename

)
