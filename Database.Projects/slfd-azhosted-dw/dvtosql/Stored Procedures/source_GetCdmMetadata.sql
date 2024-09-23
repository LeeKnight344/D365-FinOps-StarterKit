
CREATE   PROC dvtosql.source_GetCdmMetadata(@externaldatasource nvarchar(1000),  @modeljson nvarchar(max) Output, @enumtranslation nvarchar(max) Output)
AS 
declare @parmdefinition nvarchar(1000);
-- read model.json from the root folder
set @parmdefinition = N'@modeljson nvarchar(max) OUTPUT';
declare @getmodelJson nvarchar(max) = 
'SELECT     
	@modeljson= replace(jsonContent, ''cdm:'', '''')
FROM
	OPENROWSET(
		BULK ''model.json'',
		DATA_SOURCE = ''{externaldatasource}'',
		FORMAT = ''CSV'',
		FIELDQUOTE = ''0x0b'',
		FIELDTERMINATOR =''0x0b'',
		ROWTERMINATOR = ''0x0b''
	)
	WITH 
	(
		jsonContent varchar(MAX)
	) AS r'

set @getmodelJson = replace(@getmodelJson, '{externaldatasource}',@externaldatasource);

execute sp_executesql @getmodelJson, @ParmDefinition, @modeljson=@modeljson OUTPUT;

--print(@getmodelJson);
--declare @enumtranslation nvarchar(max) 
set @parmdefinition = N'@enumtranslation nvarchar(max) OUTPUT';

declare @getenumtranslation nvarchar(max) = 
replace('select 
	@enumtranslation = string_agg(convert(nvarchar(max),enumtranslation), '';'')
from (
select ''{"tablename":"''+ tablename + ''","columnname":"'' + columnname + ''","enum":"'' +
''CASE ['' + columnname + '']'' +  string_agg( convert(nvarchar(max),  '' WHEN ~''+enumvalue+''~ THEN '' + convert(nvarchar(10),enumid)) , '' '' ) + '' END"}'' as enumtranslation
FROM (SELECT 
		tablename,
		columnname,
		enum,
		enumid,
		enumvalue
	FROM OPENROWSET(
		BULK ''enumtranslation/*.cdm.json'',
		DATA_SOURCE = ''{externaldatasource}'',
		FORMAT = ''CSV'',
		fieldterminator =''0x0b'',
		fieldquote = ''0x0b'',
		rowterminator = ''0x0b''
		)
		with (doc nvarchar(max)) as r
		cross apply openjson (doc) with (tablename nvarchar(max) ''$.definitions[0].entityName'', definitions nvarchar(max) as JSON )
		cross apply OPENJSON(definitions, ''$[0].hasAttributes'')  
						WITH (columnname  nvarchar(200) ''$.name'',  datatype NVARCHAR(50) ''$.dataFormat'' , maxLength int ''$.maximumLength'' 
						,scale int ''$.traits[0].arguments[1].value'', 
						enum nvarchar(max) ''$.appliedTraits[3].arguments[0].value'', 
						constantvalues nvarchar(max) ''$.appliedTraits[3].arguments[1].value.entityReference.constantValues'' as JSON)
		cross apply OPENJSON(constantvalues) with (enumid nvarchar(100) ''$[3]'', enumvalue nvarchar(100) ''$[2]'' )
		where  1=1
		and enum is not null
		and JSON_QUERY(doc, ''$.definitions[0]'') is not null
	) x
	group by tablename,columnname, enum
)y;', '{externaldatasource}', @externaldatasource) ;

--print(@getenumtranslation);
begin try
execute sp_executesql @getenumtranslation, @ParmDefinition, @enumtranslation=@enumtranslation OUTPUT; 
end try 
begin catch

END CATCH;


set @modeljson = isnull(@modeljson, '{}') ;
set @enumtranslation = isnull(@enumtranslation, '{}') ;

