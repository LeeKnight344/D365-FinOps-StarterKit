CREATE   FUNCTION dvtosql.source_GetSQLMetadataFromSQLV2
(
	@SourceSchema nvarchar(100),
	@TablesToIncluce nvarchar(max) = '*',
	@TablesToExcluce nvarchar(max) = ''
)
RETURNS TABLE 
AS
RETURN 
select
	(select 
		TABLE_NAME as tablename,
		string_agg(convert(varchar(max), QUOTENAME(COLUMN_NAME)), ',') as selectcolumns,
		string_agg(convert(varchar(max), QUOTENAME(COLUMN_NAME) + SPACE(1) +  
		DATA_TYPE +
		CASE 
			WHEN DATA_TYPE LIKE '%char%' AND CHARACTER_MAXIMUM_LENGTH = -1 THEN '(max)'
			WHEN CHARACTER_MAXIMUM_LENGTH IS NOT NULL THEN '(' + CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR) + ')'
			WHEN DATA_TYPE IN ('decimal', 'numeric') THEN '(' + CAST(NUMERIC_PRECISION AS VARCHAR) + ', ' + CAST(NUMERIC_SCALE AS VARCHAR) + ')'
		ELSE '' END), ',') as datatypes,
		string_agg(convert(varchar(max), QUOTENAME(COLUMN_NAME)), ',') as columnnames
	from INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_SCHEMA = @SourceSchema
	and TABLE_NAME not in ('_controltableforcopy,TargetMetadata,OptionsetMetadata,StateMetadata,StatusMetadata,GlobalOptionsetMetadata')
	and TABLE_NAME not like '%_partitioned'
	and (@TablesToIncluce = '*' OR TABLE_NAME in (select value from string_split(@TablesToIncluce, ',')))
	and TABLE_NAME not in (select value from string_split(@TablesToExcluce, ','))
	group by TABLE_NAME
	FOR JSON PATH
	) sqlmetadata

