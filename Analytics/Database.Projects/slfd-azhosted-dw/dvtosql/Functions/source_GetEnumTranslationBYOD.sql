
-- Added to support BYOD (simple entities) label translation
CREATE       FUNCTION [dvtosql].[source_GetEnumTranslationBYOD]
(
)
RETURNS TABLE 
AS

Return
select  
string_agg(convert(nvarchar(max),'{"tablename":"'+ tablename + '","columnname":"'+ columnname + '","enum":"' + enumstringcolumns + '"}'), ';' ) as enumtranslation
from
(
	select 
		tablename,
		string_agg(convert(nvarchar(max),enumtranslation), ',') as enumstringcolumns,
		columnname
		from (
		select 
		tablename,
		columnname ,
		'CASE [' + tablename + '].[' + columnname + ']' +  string_agg( convert(nvarchar(max),  ' WHEN '+convert(nvarchar(10),enumid)) + ' THEN ' + convert(nvarchar(10),enumvalue) , ' ' ) + ' END'
		as enumtranslation
		FROM (SELECT 
			EntityName as tablename,
			OptionSetName as columnname,
			GlobalOptionSetName as enum,
			[Option] as enumid ,
			b.enumitemvalue as enumvalue
			from dvtosql.GlobalOptionsetMetadata as a
			left outer join srsanalysisenums as b ON a.GlobalOptionSetName = 'mserp_' + lower(b.enumname)
			and a.ExternalValue = b.enumitemname
			where LocalizedLabelLanguageCode = 1033 -- this is english
			and OptionSetName not in ('sysdatastatecode')
			) x
		group by tablename,columnname, enum
		)y
		group by tablename, columnname
	) optionsetmetadata

