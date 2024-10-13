
CREATE   PROC dvtosql.source_SetupExternalDataSource(@StorageDS nvarchar(2000), @SaaSToken nvarchar(1000) ='',
@storageDSUriScheme nvarchar(100) = 'adls:', @externalds_name nvarchar(1000) OUTPUT)
AS 
	declare @identity nvarchar(1000);
	declare @secret nvarchar(1000)

	if @SaaSToken = ''
		begin
			set @identity= 'MANAGED IDENTITY';
			set @secret = '';
		end
	else
		begin
			set @identity = 'SHARED ACCESS SIGNATURE';
			set @secret   = replace(', SECRET = ''{SaaSToken}''', '{SaaSToken}',@SaaSToken);
		end
	
	set @externalds_name = (select value from string_split(@StorageDS, '/', 1) where ordinal = 4)
	declare @externalDS_Location nvarchar(1000) = replace(@StorageDS, 'https:', @storageDSUriScheme)

	-- Create 'Managed Identity' 'Database Scoped Credentials' if not exist
	-- database scope credentials is used to access storage account 
	Declare @CreateCredentials nvarchar(max) =  replace(replace(replace(replace(
		'
		IF NOT EXISTS(select * from sys.database_credentials where name = ''{externalds_name}'')
			CREATE DATABASE SCOPED CREDENTIAL [{externalds_name}] WITH IDENTITY=''{identity}'' {Secret}

		IF NOT EXISTS(select * from sys.external_data_sources where name = ''{externalds_name}'')
			CREATE EXTERNAL DATA SOURCE [{externalds_name}] WITH (
				LOCATION = ''{extenralDS_Location}'',
				CREDENTIAL = [{externalds_name}])
		',
		'{externalds_name}', @externalds_name),
		'{extenralDS_Location}', @externalDS_Location),
		'{identity}', @identity),
		'{secret}', @Secret)
		;

	execute sp_executesql  @CreateCredentials;

