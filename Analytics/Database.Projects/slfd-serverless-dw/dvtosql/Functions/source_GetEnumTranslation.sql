
	
CREATE       FUNCTION [dvtosql].[source_GetEnumTranslation]
(
)
RETURNS TABLE 
AS

Return
select  string_agg(convert(nvarchar(max),'{"tablename":"'+ tablename + '","enumtranslation":",' + enumstringcolumns + '"}'), ';' ) as enumtranslation
from 

(
	select 
		tablename,
		string_agg(convert(nvarchar(max),enumtranslation), ',') as enumstringcolumns
		from (
		select 
		tablename,
		columnname ,
		'CASE [' + tablename + '].[' + columnname + ']' +  string_agg( convert(nvarchar(max),  ' WHEN '+convert(nvarchar(10),enumid)) + ' THEN ''' + enumvalue , ''' ' ) + ''' END AS ' + columnname + '_$label'  
		as enumtranslation
		FROM (SELECT 
			EntityName as tablename,
			OptionSetName as columnname,
			GlobalOptionSetName as enum,
			[Option] as enumid ,
			ExternalValue as enumvalue
			from dvtosql.GlobalOptionsetMetadata
			where LocalizedLabelLanguageCode = 1033 -- this is english
			and OptionSetName not in ('sysdatastatecode') 
			) x
		group by tablename,columnname, enum
		)y
		group by tablename
	) optionsetmetadata

