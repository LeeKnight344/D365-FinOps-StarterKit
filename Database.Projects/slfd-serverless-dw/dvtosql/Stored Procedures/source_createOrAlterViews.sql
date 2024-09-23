

CREATE   PROC dvtosql.source_createOrAlterViews
(
	@externalds_name nvarchar(1000), 
	@modeljson nvarchar(max),
	@enumtranslation nvarchar(max),
	@incrementalCSV int,  
	@add_EDL_AuditColumns int, 
	@tableschema nvarchar(10)='dbo', 
	@rowsetoptions nvarchar(2000) ='',
	@translate_enums int = 0,
	@remove_mserp_prefix  int = 0,
	@translateBYOD_enums int = 1 -- Added to support BYOD (simple entities) label translation
)
AS

	-- set createviewddl template and columns variables 
	declare @CreateViewDDL nvarchar(max); 
	declare @addcolumns nvarchar(max) = '';
	declare @GlobalOptionSetMetadataTemplate nvarchar(max)='' 
	declare @filter_deleted_rows nvarchar(200) =  ' '
	declare @srsanalysisenumsTemplate nvarchar(max)='' -- Added to support BYOD (simple entities) label translation

	-- setup the ddl template 
	if @incrementalCSV  = 0
	begin	
		if @add_EDL_AuditColumns = 1
			begin
				set @addcolumns = '{tablename}.PartitionId,{tablename}.SinkModifiedOn as DataLakeModified_DateTime, cast(null as varchar(100)) as [$FileName], {tablename}.recid as _SysRowId,cast({tablename}.versionnumber as varchar(100)) as LSN,convert(datetime2,null) as LastProcessedChange_DateTime,'
			end 
		else 
			set @addcolumns = '{tablename}.PartitionId,';

		set @CreateViewDDL =
		'CREATE OR ALTER VIEW  {tableschema}.{tablename}  AS 
		 SELECT 
		 {selectcolumns}
		 FROM  OPENROWSET
		 ( BULK ''deltalake/{tablename}_partitioned/'',  
		  FORMAT = ''delta'', 
		  DATA_SOURCE = ''{externaldsname}''
		 ) 
		 WITH
		 (
			{datatypes}, [PartitionId] int
		 ) as {tablename}';

		set @filter_deleted_rows =  ' where isnull({tablename}.IsDelete,0) = 0 '
		
		set @GlobalOptionSetMetadataTemplate = 'create or alter view dvtosql.GlobalOptionsetMetadata 
		AS
		SELECT *
		FROM  OPENROWSET
				( BULK ''deltalake/GlobalOptionsetMetadata_partitioned/'',  
					FORMAT = ''delta'', 
					DATA_SOURCE = ''{externaldsname}''
				) as GlobalOptionsetMetadata'

		-- Added to support BYOD (simple entities) label translation
		set @srsanalysisenumsTemplate = 'create or alter view dvtosql.srsanalysisenums 
		AS
		SELECT *
		FROM  OPENROWSET
				( BULK ''deltalake/srsanalysisenums_partitioned/'',  
					FORMAT = ''delta'', 
					DATA_SOURCE = ''{externaldsname}''
				) as srsanalysisenums'
	
	end
	else 
	begin
		
		if @add_EDL_AuditColumns = 1
			begin
				set @addcolumns = 'cast(replace({tablename}.filepath(1),''.'', '':'') as datetime2) as DataLakeModified_DateTime, cast({tablename}.filepath(1) +''{tablename}'' + {tablename}.filepath(2) as varchar(100)) as [$FileName], {tablename}.recid as _SysRowId, cast({tablename}.versionnumber as varchar(100)) as LSN, convert(datetime2,null) as LastProcessedChange_DateTime,'
			end
		else
			begin
				-- for incremental folder(CSV) filepath(1) is the timestamp folder - we still want to add DataLakeModified_DateTime to enable folder ellimination when fetching increemntal data
				set @addcolumns = 'cast(replace({tablename}.filepath(1),''.'', '':'') as datetime2) as DataLakeModified_DateTime,'
			end
		
		set @CreateViewDDL =
		'CREATE OR ALTER VIEW  {tableschema}.{tablename}  AS 
		SELECT 
			{selectcolumns}
		FROM  OPENROWSET
		( BULK ''*/{tablename}/*.csv'',  
		  FORMAT = ''CSV'', 
		  DATA_SOURCE = ''{externaldsname}''
		  {options}
		) 
		WITH
		(
			{datatypes}
		) as {tablename} ';

set @GlobalOptionSetMetadataTemplate = 'create or alter view dvtosql.GlobalOptionsetMetadata 
AS
SELECT *
FROM  OPENROWSET
		( BULK ''*/OptionsetMetadata/GlobalOptionsetMetadata.csv'',  
		  FORMAT = ''CSV'', 
		  DATA_SOURCE = ''{externaldsname}''
		) 
		WITH
		(
			[OptionSetName] [varchar](max),
			[Option] [bigint],
			[IsUserLocalizedLabel] [bit],
			[LocalizedLabelLanguageCode] [bigint],
			[LocalizedLabel] [varchar](max),
			[GlobalOptionSetName] [varchar](max),
			[EntityName] [varchar](max),
			[ExternalValue] [varchar](max)

		) as GlobalOptionsetMetadata
		where GlobalOptionsetMetadata.filepath(1) = 
		(select top 1 lastfolder
		 FROM  OPENROWSET
		( BULK ''Changelog/changelog.info'',  
		  FORMAT = ''CSV'', 
		  DATA_SOURCE = ''{externaldsname}''
		) 
		WITH
		(
			lastfolder nvarchar(100)
		) as changelog
		)' 
	end;

-- Generate globaloptionset view 
set @GlobalOptionSetMetadataTemplate = replace(@GlobalOptionSetMetadataTemplate,'{externaldsname}', @externalds_name)
execute sp_executesql @GlobalOptionSetMetadataTemplate;

-- Added to support BYOD (simple entities) label translation
if (@translateBYOD_enums = 1)
begin
	set @srsanalysisenumsTemplate = replace(@srsanalysisenumsTemplate,'{externaldsname}', @externalds_name)
	execute sp_executesql @srsanalysisenumsTemplate;
end

drop table if exists #cdmmetadata;
	create table #cdmmetadata
	(
		tablename nvarchar(200) COLLATE Database_Default,	
		selectcolumns nvarchar(max) COLLATE Database_Default,
		datatypes nvarchar(max) COLLATE Database_Default,	
		columnnames nvarchar(max) COLLATE Database_Default
	);

	-- Moved two lines to later to support BYOD (simple entities) label translation
	-- insert into #cdmmetadata (tablename, selectcolumns, datatypes, columnnames)
	-- select tablename, selectcolumns, datatypes, columnnames from dvtosql.source_GetSQLMetadataFromCDM(@modeljson, @enumtranslation) as cdm

drop table if exists #enumtranslation;
	create table #enumtranslation
	(
		tablename nvarchar(200) COLLATE Database_Default,	
		enumtranslation nvarchar(max) default('')
	);

	-- Added to support BYOD (simple entities) label translation
	IF ((@translate_enums = 1) and (@translateBYOD_enums = 1))
	BEGIN
		RAISERROR ('You must translate enither enums or BYOD enums, or neither, but not both.', 16, 1)
	END

	IF ((@translate_enums = 1) and (@translateBYOD_enums = 0))
	BEGIN
		declare @enumtranslation_optionset nvarchar(max);
		select @enumtranslation_optionset = enumtranslation  from [dvtosql].[source_GetEnumTranslation]()

		insert into #enumtranslation
		select 
			tablename, 
			enumtranslation 
		from string_split(@enumtranslation_optionset, ';')
		cross apply openjson(value) 
		with (tablename nvarchar(100), enumtranslation nvarchar(max))
	END

	-- Added to support BYOD (simple entities) label translation
	IF ((@translate_enums = 0) and (@translateBYOD_enums = 1)) -- Added for BYOD to support simple entities
	BEGIN
		declare @enumtranslationBYOD_optionset nvarchar(max);
		select @enumtranslationBYOD_optionset = enumtranslation  from [dvtosql].[source_GetEnumTranslationBYOD]()
		
		set @enumtranslation = @enumtranslationBYOD_optionset;
		
		insert into #enumtranslation
		select 
			tablename, 
			enumtranslation 
		from string_split(@enumtranslationBYOD_optionset, ';')
		cross apply openjson(value) 
		with (tablename nvarchar(100), enumtranslation nvarchar(max))
	END


	--select * from #cdmmetadata
	
	-- Moved two lines here to support BYOD (simple entities) label translation
	insert into #cdmmetadata (tablename, selectcolumns, datatypes, columnnames)
	select tablename, selectcolumns, datatypes, columnnames from dvtosql.source_GetSQLMetadataFromCDM(@modeljson, @enumtranslation) as cdm

-- generate ddl for view definitions for each tables in cdmmetadata table in the bellow format. 
-- Begin try  
	-- execute sp_executesql N'create or alter view schema.tablename as select columns from openrowset(...) tablename '  
-- End Try 
--Begin catch 
	-- print ERROR_PROCEDURE() + ':' print ERROR_MESSAGE() 
--end catch
declare @ddl_tables nvarchar(max);

select 
	@ddl_tables = string_agg(convert(nvarchar(max), viewDDL ), ';')
	FROM (
			select 
			'begin try  execute sp_executesql N''' +
			replace(replace(replace(replace(replace(replace(replace(@CreateViewDDL + @filter_deleted_rows, 			
			'{tableschema}',@tableschema),
			'{selectcolumns}', 
				case when c.tablename  COLLATE Database_Default like 'mserp_%' then '' else  @addcolumns end + 
				c.selectcolumns  COLLATE Database_Default +  
				isnull(enumtranslation COLLATE Database_Default, '')), 
			'{tablename}', c.tablename), 
			'{externaldsname}', @externalds_name), 
			'{datatypes}', c.datatypes),
			'{options}', @rowsetoptions),
			'''','''''')  
			+ '''' + ' End Try Begin catch print ERROR_PROCEDURE() + '':'' print ERROR_MESSAGE() end catch' as viewDDL
			from #cdmmetadata as c
			left outer join #enumtranslation as e on c.tablename = e.tablename
		)x		

-- execute @ddl_tables 

If @remove_mserp_prefix = 1
BEGIN
	declare @mserp_columnname_prefix nvarchar(100) = 'AS [mserp_', @mserp_entityname_prefix nvarchar(100) = replace('VIEW  {tableschema}.mserp_', '{tableschema}',@tableschema) ;
	set @ddl_tables = replace(replace(@ddl_tables, 'mserp_createdon', 'fno_createdon'),'mserp_Id', 'fno_Id');
	set @ddl_tables = replace(replace(@ddl_tables, @mserp_columnname_prefix, 'AS ['),@mserp_entityname_prefix, replace('VIEW  {tableschema}.', '{tableschema}',@tableschema)) 
	--print @mserp_prefix;
END 
--select @ddl_tables
execute sp_executesql @ddl_tables;

-- There is  difference in Synapse link and Export to data lake when exporting derived base tables like dirpartytable
-- For base table (Dirpartytable), Export to data lake includes all columns from the derived tables. However Synapse link only exports columns that in the AOT. 
-- This step overide the Dirpartytable view and columns from other derived tables , making table dirpartytable backward compatible
-- Table Inheritance data is available in AXBD
declare @ddl_fno_derived_tables nvarchar(max);
declare @tableinheritance nvarchar(max) = '[{"parenttable":"AgreementHeader","childtables":[{"childtable":"PurchAgreementHeader"},{"childtable":"SalesAgreementHeader"}]},{"parenttable":"AgreementHeaderExt_RU","childtables":[{"childtable":"PurchAgreementHeaderExt_RU"},{"childtable":"SalesAgreementHeaderExt_RU"}]},{"parenttable":"AgreementHeaderHistoryExt_RU","childtables":[{"childtable":"PurchAgreementHeaderHistoryExt_RU"},{"childtable":"SalesAgreementHeaderHistoryExt_RU"}]},{"parenttable":"AifEndpointActionValueMap","childtables":[{"childtable":"AifPortValueMap"},{"childtable":"InterCompanyTradingValueMap"}]},{"parenttable":"BankLCLine","childtables":[{"childtable":"BankLCExportLine"},{"childtable":"BankLCImportLine"}]},{"parenttable":"CAMDataAllocationBase","childtables":[{"childtable":"CAMDataFormulaAllocationBase"},{"childtable":"CAMDataHierarchyAllocationBase"},{"childtable":"CAMDataPredefinedDimensionMemberAllocationBase"}]},{"parenttable":"CAMDataCostAccountingLedgerSourceEntryProvider","childtables":[{"childtable":"CAMDataCostAccountingLedgerCostElementEntryProvider"},{"childtable":"CAMDataCostAccountingLedgerStatisticalMeasureProvider"}]},{"parenttable":"CAMDataDataConnectorDimension","childtables":[{"childtable":"CAMDataDataConnectorChartOfAccounts"},{"childtable":"CAMDataDataConnectorCostObjectDimension"}]},{"parenttable":"CAMDataDataConnectorSystemInstance","childtables":[{"childtable":"CAMDataDataConnectorSystemInstanceAX"}]},{"parenttable":"CAMDataDataOrigin","childtables":[{"childtable":"CAMDataDataOriginDocument"}]},{"parenttable":"CAMDataDimension","childtables":[{"childtable":"CAMDataCostElementDimension"},{"childtable":"CAMDataCostObjectDimension"},{"childtable":"CAMDataStatisticalDimension"}]},{"parenttable":"CAMDataDimensionHierarchy","childtables":[{"childtable":"CAMDataDimensionCategorizationHierarchy"},{"childtable":"CAMDataDimensionClassificationHierarchy"}]},{"parenttable":"CAMDataDimensionHierarchyNode","childtables":[{"childtable":"CAMDataDimensionHierarchyNodeComposite"},{"childtable":"CAMDataDimensionHierarchyNodeLeaf"}]},{"parenttable":"CAMDataImportedDimensionMember","childtables":[{"childtable":"CAMDataImportedCostElementDimensionMember"},{"childtable":"CAMDataImportedCostObjectDimensionMember"},{"childtable":"CAMDataImportedStatisticalDimensionMember"}]},{"parenttable":"CAMDataImportedTransactionEntry","childtables":[{"childtable":"CAMDataImportedBudgetEntry"},{"childtable":"CAMDataImportedGeneralLedgerEntry"}]},{"parenttable":"CAMDataJournalCostControlUnitBase","childtables":[{"childtable":"CAMDataJournalCostControlUnit"}]},{"parenttable":"CAMDataSourceDocumentLine","childtables":[{"childtable":"CAMDataSourceDocumentLineDetail"}]},{"parenttable":"CAMDataTransactionVersion","childtables":[{"childtable":"CAMDataActualVersion"},{"childtable":"CAMDataBudgetVersion"},{"childtable":"CAMDataCalculation"},{"childtable":"CAMDataOverheadCalculation"},{"childtable":"CAMDataSourceTransactionVersion"}]},{"parenttable":"CaseDetailBase","childtables":[{"childtable":"CaseDetail"},{"childtable":"CustCollectionsCaseDetail"},{"childtable":"HcmFMLACaseDetail"}]},{"parenttable":"CatProductReference","childtables":[{"childtable":"CatCategoryProductReference"},{"childtable":"CatClassifiedProductReference"},{"childtable":"CatDistinctProductReference"},{"childtable":"CatExternalQuoteProductReference"}]},{"parenttable":"CustCollectionsLinkTable","childtables":[{"childtable":"CustCollectionsLinkActivitiesCustTrans"},{"childtable":"CustCollectionsLinkCasesActivities"}]},{"parenttable":"CustInterestTransLineIdRef","childtables":[{"childtable":"CustInterestTransLineIdRef_MarkupTrans"},{"childtable":"CustnterestTransLineIdRef_Invoice"}]},{"parenttable":"CustInvoiceLineTemplate","childtables":[{"childtable":"CustInvoiceMarkupTransTemplate"},{"childtable":"CustInvoiceStandardLineTemplate"}]},{"parenttable":"CustVendDirective_PSN","childtables":[{"childtable":"CustDirective_PSN"},{"childtable":"VendDirective_PSN"}]},{"parenttable":"CustVendRoutingSlip_PSN","childtables":[{"childtable":"CustRoutingSlip_PSN"},{"childtable":"VendRoutingSlip_PSN"}]},{"parenttable":"DMFRules","childtables":[{"childtable":"DMFRulesNumberSequence"}]},{"parenttable":"EcoResApplicationControl","childtables":[{"childtable":"EcoResCatalogControl"},{"childtable":"EcoResComponentControl"}]},{"parenttable":"EcoResNomenclature","childtables":[{"childtable":"EcoResDimBasedConfigurationNomenclature"},{"childtable":"EcoResProductVariantNomenclature"},{"childtable":"EngChgProductCategoryNomenclature"},{"childtable":"PCConfigurationNomenclature"}]},{"parenttable":"EcoResNomenclatureSegment","childtables":[{"childtable":"EcoResNomenclatureSegmentAttributeValue"},{"childtable":"EcoResNomenclatureSegmentColorDimensionValue"},{"childtable":"EcoResNomenclatureSegmentColorDimensionValueName"},{"childtable":"EcoResNomenclatureSegmentConfigDimensionValue"},{"childtable":"EcoResNomenclatureSegmentConfigDimensionValueName"},{"childtable":"EcoResNomenclatureSegmentConfigGroupItemId"},{"childtable":"EcoResNomenclatureSegmentConfigGroupItemName"},{"childtable":"EcoResNomenclatureSegmentNumberSequence"},{"childtable":"EcoResNomenclatureSegmentProductMasterName"},{"childtable":"EcoResNomenclatureSegmentProductMasterNumber"},{"childtable":"EcoResNomenclatureSegmentSizeDimensionValue"},{"childtable":"EcoResNomenclatureSegmentSizeDimensionValueName"},{"childtable":"EcoResNomenclatureSegmentStyleDimensionValue"},{"childtable":"EcoResNomenclatureSegmentStyleDimensionValueName"},{"childtable":"EcoResNomenclatureSegmentTextConstant"},{"childtable":"EcoResNomenclatureSegmentVersionDimensionValue"},{"childtable":"EcoResNomenclatureSegmentVersionDimensionValueName"}]},{"parenttable":"EcoResProduct","childtables":[{"childtable":"EcoResDistinctProduct"},{"childtable":"EcoResDistinctProductVariant"},{"childtable":"EcoResProductMaster"}]},{"parenttable":"EcoResProductMasterDimensionValue","childtables":[{"childtable":"EcoResProductMasterColor"},{"childtable":"EcoResProductMasterConfiguration"},{"childtable":"EcoResProductMasterSize"},{"childtable":"EcoResProductMasterStyle"},{"childtable":"EcoResProductMasterVersion"}]},{"parenttable":"EcoResProductWorkspaceConfiguration","childtables":[{"childtable":"EcoResProductDiscreteManufacturingWorkspaceConfiguration"},{"childtable":"EcoResProductMaintainWorkspaceConfiguration"},{"childtable":"EcoResProductProcessManufacturingWorkspaceConfiguration"},{"childtable":"EcoResProductVariantMaintainWorkspaceConfiguration"}]},{"parenttable":"EngChgEcmOriginals","childtables":[{"childtable":"EngChgEcmOriginalEcmAttribute"},{"childtable":"EngChgEcmOriginalEcmBom"},{"childtable":"EngChgEcmOriginalEcmBomTable"},{"childtable":"EngChgEcmOriginalEcmFormulaCoBy"},{"childtable":"EngChgEcmOriginalEcmFormulaStep"},{"childtable":"EngChgEcmOriginalEcmProduct"},{"childtable":"EngChgEcmOriginalEcmRoute"},{"childtable":"EngChgEcmOriginalEcmRouteOpr"},{"childtable":"EngChgEcmOriginalEcmRouteTable"}]},{"parenttable":"FBGeneralAdjustmentCode_BR","childtables":[{"childtable":"FBGeneralAdjustmentCodeICMS_BR"},{"childtable":"FBGeneralAdjustmentCodeINSSCPRB_BR"},{"childtable":"FBGeneralAdjustmentCodeIPI_BR"},{"childtable":"FBGeneralAdjustmentCodePISCOFINS_BR"}]},{"parenttable":"HRPLimitAgreementException","childtables":[{"childtable":"HRPLimitAgreementCompException"},{"childtable":"HRPLimitAgreementJobException"}]},{"parenttable":"IntercompanyActionPolicy","childtables":[{"childtable":"IntercompanyAgreementActionPolicy"}]},{"parenttable":"PaymCalendarRule","childtables":[{"childtable":"PaymCalendarCriteriaRule"},{"childtable":"PaymCalendarLocationRule"}]},{"parenttable":"PCConstraint","childtables":[{"childtable":"PCExpressionConstraint"},{"childtable":"PCTableConstraint"}]},{"parenttable":"PCProductConfiguration","childtables":[{"childtable":"PCTemplateConfiguration"},{"childtable":"PCVariantConfiguration"}]},{"parenttable":"PCTableConstraintColumnDefinition","childtables":[{"childtable":"PCTableConstraintDatabaseColumnDef"},{"childtable":"PCTableConstraintGlobalColumnDef"}]},{"parenttable":"PCTableConstraintDefinition","childtables":[{"childtable":"PCDatabaseRelationConstraintDefinition"},{"childtable":"PCGlobalTableConstraintDefinition"}]},{"parenttable":"RetailMediaResource","childtables":[{"childtable":"RetailImageResource"}]},{"parenttable":"RetailPeriodicDiscount","childtables":[{"childtable":"GUPFreeItemDiscount"},{"childtable":"RetailDiscountMixAndMatch"},{"childtable":"RetailDiscountMultibuy"},{"childtable":"RetailDiscountOffer"},{"childtable":"RetailDiscountThreshold"},{"childtable":"RetailShippingThresholdDiscounts"}]},{"parenttable":"RetailProductAttributesLookup","childtables":[{"childtable":"RetailAttributesGlobalLookup"},{"childtable":"RetailAttributesLegalEntityLookup"}]},{"parenttable":"RetailPubRetailChannelTable","childtables":[{"childtable":"RetailPubRetailMCRChannelTable"},{"childtable":"RetailPubRetailOnlineChannelTable"},{"childtable":"RetailPubRetailStoreTable"}]},{"parenttable":"RetailTillLayoutZoneReferenceLegacy","childtables":[{"childtable":"RetailTillLayoutButtonGridZoneLegacy"},{"childtable":"RetailTillLayoutImageZoneLegacy"},{"childtable":"RetailTillLayoutReportZoneLegacy"}]},{"parenttable":"SCTTracingActivity","childtables":[{"childtable":"SCTTracingActivity_Purch"}]},{"parenttable":"SysMessageTarget","childtables":[{"childtable":"SysMessageCompanyTarget"},{"childtable":"SysWorkloadMessageCompanyTarget"},{"childtable":"SysWorkloadMessageHubCompanyTarget"}]},{"parenttable":"SysPolicyRuleType","childtables":[{"childtable":"SysPolicySourceDocumentRuleType"}]},{"parenttable":"TradeNonStockedConversionLog","childtables":[{"childtable":"TradeNonStockedConversionChangeLog"},{"childtable":"TradeNonStockedConversionCheckLog"}]},{"parenttable":"UserRequest","childtables":[{"childtable":"VendRequestUserRequest"},{"childtable":"VendUserRequest"}]},{"parenttable":"VendRequest","childtables":[{"childtable":"VendRequestCategoryExtension"},{"childtable":"VendRequestCompany"},{"childtable":"VendRequestStatusChange"}]},{"parenttable":"VendVendorRequest","childtables":[{"childtable":"VendVendorRequestNewCategory"},{"childtable":"VendVendorRequestNewVendor"}]},{"parenttable":"WarrantyGroupConfigurationItem","childtables":[{"childtable":"RetailWarrantyApplicableChannel"},{"childtable":"WarrantyApplicableProduct"},{"childtable":"WarrantyGroupData"}]},{"parenttable":"AgreementHeaderHistory","childtables":[{"childtable":"PurchAgreementHeaderHistory"},{"childtable":"SalesAgreementHeaderHistory"}]},{"parenttable":"AgreementLine","childtables":[{"childtable":"AgreementLineQuantityCommitment"},{"childtable":"AgreementLineVolumeCommitment"}]},{"parenttable":"AgreementLineHistory","childtables":[{"childtable":"AgreementLineQuantityCommitmentHistory"},{"childtable":"AgreementLineVolumeCommitmentHistory"}]},{"parenttable":"BankLC","childtables":[{"childtable":"BankLCExport"},{"childtable":"BankLCImport"}]},{"parenttable":"BenefitESSTileSetupBase","childtables":[{"childtable":"BenefitESSTileSetupBenefit"},{"childtable":"BenefitESSTileSetupBenefitCredit"}]},{"parenttable":"BudgetPlanElementDefinition","childtables":[{"childtable":"BudgetPlanColumn"},{"childtable":"BudgetPlanRow"}]},{"parenttable":"BusinessEventsEndpoint","childtables":[{"childtable":"BusinessEventsAzureBlobStorageEndpoint"},{"childtable":"BusinessEventsAzureEndpoint"},{"childtable":"BusinessEventsEventGridEndpoint"},{"childtable":"BusinessEventsEventHubEndpoint"},{"childtable":"BusinessEventsFlowEndpoint"},{"childtable":"BusinessEventsServiceBusQueueEndpoint"},{"childtable":"BusinessEventsServiceBusTopicEndpoint"}]},{"parenttable":"CAMDataCostAccountingPolicy","childtables":[{"childtable":"CAMDataAccountingUnitOfMeasurePolicy"},{"childtable":"CAMDataCostAccountingAccountPolicy"},{"childtable":"CAMDataCostAccountingLedgerPolicy"},{"childtable":"CAMDataCostAllocationPolicy"},{"childtable":"CAMDataCostBehaviorPolicy"},{"childtable":"CAMDataCostControlUnitPolicy"},{"childtable":"CAMDataCostDistributionPolicy"},{"childtable":"CAMDataCostFlowAssumptionPolicy"},{"childtable":"CAMDataCostRollupPolicy"},{"childtable":"CAMDataInputMeasurementBasisPolicy"},{"childtable":"CAMDataInventoryValuationMethodPolicy"},{"childtable":"CAMDataLedgerDocumentAccountingPolicy"},{"childtable":"CAMDataOverheadRatePolicy"},{"childtable":"CAMDataRecordingIntervalPolicy"}]},{"parenttable":"CAMDataJournal","childtables":[{"childtable":"CAMDataBudgetEntryTransferJournal"},{"childtable":"CAMDataCalculationJournal"},{"childtable":"CAMDataCostAllocationJournal"},{"childtable":"CAMDataCostBehaviorCalculationJournal"},{"childtable":"CAMDataCostDistributionJournal"},{"childtable":"CAMDataGeneralLedgerEntryTransferJournal"},{"childtable":"CAMDataOverheadRateCalculationJournal"},{"childtable":"CAMDataSourceEntryTransferJournal"},{"childtable":"CAMDataStatisticalEntryTransferJournal"}]},{"parenttable":"CAMDataSourceDocumentAttributeValue","childtables":[{"childtable":"CAMDataSourceDocumentAttributeValueAmount"},{"childtable":"CAMDataSourceDocumentAttributeValueDate"},{"childtable":"CAMDataSourceDocumentAttributeValueQuantity"},{"childtable":"CAMDataSourceDocumentAttributeValueString"}]},{"parenttable":"CatPunchoutRequest","childtables":[{"childtable":"CatCXMLPunchoutRequest"}]},{"parenttable":"CatUserReview","childtables":[{"childtable":"CatUserReviewProduct"},{"childtable":"CatUserReviewVendor"}]},{"parenttable":"CatVendProdCandidateAttributeValue","childtables":[{"childtable":"CatVendorBooleanValue"},{"childtable":"CatVendorCurrencyValue"},{"childtable":"CatVendorDateTimeValue"},{"childtable":"CatVendorFloatValue"},{"childtable":"CatVendorIntValue"},{"childtable":"CatVendorTextValue"}]},{"parenttable":"CustInvLineBillCodeCustomFieldBase","childtables":[{"childtable":"CustInvLineBillCodeCustomFieldBool"},{"childtable":"CustInvLineBillCodeCustomFieldDateTime"},{"childtable":"CustInvLineBillCodeCustomFieldInt"},{"childtable":"CustInvLineBillCodeCustomFieldReal"},{"childtable":"CustInvLineBillCodeCustomFieldText"}]},{"parenttable":"DIOTAdditionalInfoForNoVendor_MX","childtables":[{"childtable":"DIOTAddlInfoForNoVendorLedger_MX"},{"childtable":"DIOTAddlInfoForNoVendorProj_MX"}]},{"parenttable":"DirPartyTable","childtables":[{"childtable":"CompanyInfo"},{"childtable":"DirOrganization"},{"childtable":"DirOrganizationBase"},{"childtable":"DirPerson"},{"childtable":"OMInternalOrganization"},{"childtable":"OMOperatingUnit"},{"childtable":"OMTeam"}]},{"parenttable":"DOMRules","childtables":[{"childtable":"DOMCatalogAmountFulfillmentTypeRules"},{"childtable":"DOMCatalogMinimumInventoryRules"},{"childtable":"DOMCatalogRules"},{"childtable":"DOMCatalogShipPriorityRules"},{"childtable":"DOMOrgFulfillmentTypeRules"},{"childtable":"DOMOrgLocationOfflineRules"},{"childtable":"DOMOrgMaximumDistanceRules"},{"childtable":"DOMOrgMaximumOrdersRules"},{"childtable":"DOMOrgMaximumRejectsRules"}]},{"parenttable":"DOMRulesLine","childtables":[{"childtable":"DOMRulesLineCatalogAmountFulfillmentTypeRules"},{"childtable":"DOMRulesLineCatalogMinimumInventoryRules"},{"childtable":"DOMRulesLineCatalogRules"},{"childtable":"DOMRulesLineCatalogShipPriorityRules"},{"childtable":"DOMRulesLineOrgFulfillmentTypeRules"},{"childtable":"DOMRulesLineOrgLocationOfflineRules"},{"childtable":"DOMRulesLineOrgMaximumDistanceRules"},{"childtable":"DOMRulesLineOrgMaximumOrdersRules"},{"childtable":"DOMRulesLineOrgMaximumRejectsRules"}]},{"parenttable":"EcoResCategory","childtables":[{"childtable":"PCClass"}]},{"parenttable":"EcoResInstanceValue","childtables":[{"childtable":"CatalogProductInstanceValue"},{"childtable":"CustomerInstanceValue"},{"childtable":"EcoResCategoryInstanceValue"},{"childtable":"EcoResEngineeringProductCategoryAttributeInstanceValue"},{"childtable":"EcoResProductInstanceValue"},{"childtable":"EcoResReleasedEngineeringProductVersionAttributeInstanceValue"},{"childtable":"GUPPriceTreeInstanceValue"},{"childtable":"GUPRebateDateInstanceValue"},{"childtable":"GUPRetailChannelInstanceValue"},{"childtable":"GUPSalesQuotationInstanceValue"},{"childtable":"GUPSalesTableInstanceValue"},{"childtable":"PCComponentInstanceValue"},{"childtable":"RetailCatalogProdInternalOrgInstanceVal"},{"childtable":"RetailChannelInstanceValue"},{"childtable":"RetailInternalOrgProductInstanceValue"},{"childtable":"RetailSalesTableInstanceValue"},{"childtable":"TMSLoadBuildStrategyAttribValueSet"}]},{"parenttable":"EcoResProductVariantDimensionValue","childtables":[{"childtable":"EcoResProductVariantColor"},{"childtable":"EcoResProductVariantConfiguration"},{"childtable":"EcoResProductVariantSize"},{"childtable":"EcoResProductVariantStyle"},{"childtable":"EcoResProductVariantVersion"}]},{"parenttable":"EcoResValue","childtables":[{"childtable":"EcoResBooleanValue"},{"childtable":"EcoResCurrencyValue"},{"childtable":"EcoResDateTimeValue"},{"childtable":"EcoResFloatValue"},{"childtable":"EcoResIntValue"},{"childtable":"EcoResReferenceValue"},{"childtable":"EcoResTextValue"}]},{"parenttable":"EntAssetMaintenancePlanLine","childtables":[{"childtable":"EntAssetMaintenancePlanLineCounter"},{"childtable":"EntAssetMaintenancePlanLineTime"}]},{"parenttable":"HRPDefaultLimit","childtables":[{"childtable":"HRPDefaultLimitCompensationRule"},{"childtable":"HRPDefaultLimitJobRule"}]},{"parenttable":"KanbanQuantityPolicyDemandPeriod","childtables":[{"childtable":"KanbanQuantityDemandPeriodFence"},{"childtable":"KanbanQuantityDemandPeriodSeason"}]},{"parenttable":"MarkupMatchingTrans","childtables":[{"childtable":"VendInvoiceInfoLineMarkupMatchingTrans"},{"childtable":"VendInvoiceInfoSubMarkupMatchingTrans"}]},{"parenttable":"MarkupPeriodChargeInvoiceLineBase","childtables":[{"childtable":"MarkupPeriodChargeInvoiceLineBaseMonetary"},{"childtable":"MarkupPeriodChargeInvoiceLineBaseQuantity"},{"childtable":"MarkupPeriodChargeInvoiceLineBaseQuantityMinAmount"}]},{"parenttable":"PayrollPayStatementLine","childtables":[{"childtable":"PayrollPayStatementBenefitLine"},{"childtable":"PayrollPayStatementEarningLine"},{"childtable":"PayrollPayStatementTaxLine"}]},{"parenttable":"PayrollProviderTaxRegion","childtables":[{"childtable":"PayrollTaxRegionForSymmetry"}]},{"parenttable":"PayrollTaxEngineTaxCode","childtables":[{"childtable":"PayrollTaxEngineTaxCodeForSymmetry"}]},{"parenttable":"PayrollTaxEngineWorkerTaxRegion","childtables":[{"childtable":"PayrollWorkerTaxRegionForSymmetry"}]},{"parenttable":"PCPriceElement","childtables":[{"childtable":"PCPriceBasePrice"},{"childtable":"PCPriceExpressionRule"}]},{"parenttable":"PCRuntimeCache","childtables":[{"childtable":"PCRuntimeCacheXml"}]},{"parenttable":"PCTemplateAttributeBinding","childtables":[{"childtable":"PCTemplateCategoryAttribute"},{"childtable":"PCTemplateConstant"}]},{"parenttable":"RetailChannelTable","childtables":[{"childtable":"RetailDirectSalesChannel"},{"childtable":"RetailMCRChannelTable"},{"childtable":"RetailOnlineChannelTable"},{"childtable":"RetailStoreTable"}]},{"parenttable":"RetailPeriodicDiscountLine","childtables":[{"childtable":"GUPFreeItemDiscountLine"},{"childtable":"RetailDiscountLineMixAndMatch"},{"childtable":"RetailDiscountLineMultibuy"},{"childtable":"RetailDiscountLineOffer"},{"childtable":"RetailDiscountLineThresholdApplying"}]},{"parenttable":"RetailReturnPolicyLine","childtables":[{"childtable":"RetailReturnInfocodePolicyLine"},{"childtable":"RetailReturnReasonCodePolicyLine"}]},{"parenttable":"RetailTillLayoutZoneReference","childtables":[{"childtable":"RetailTillLayoutButtonGridZone"},{"childtable":"RetailTillLayoutImageZone"},{"childtable":"RetailTillLayoutReportZone"}]},{"parenttable":"ServicesParty","childtables":[{"childtable":"ServicesCustomer"},{"childtable":"ServicesEmployee"}]},{"parenttable":"SysPolicyRule","childtables":[{"childtable":"CatCatalogPolicyRule"},{"childtable":"HcmBenefitEligibilityRule"},{"childtable":"HRPDefaultLimitRule"},{"childtable":"HRPLimitAgreementRule"},{"childtable":"HRPLimitRequestCurrencyRule"},{"childtable":"PayrollPremiumEarningGenerationRule"},{"childtable":"PurchReApprovalPolicyRuleTable"},{"childtable":"PurchReqControlRFQRule"},{"childtable":"PurchReqControlRule"},{"childtable":"PurchReqSourcingPolicyRule"},{"childtable":"RequisitionPurposeRule"},{"childtable":"RequisitionReplenishCatAccessPolicyRule"},{"childtable":"RequisitionReplenishControlRule"},{"childtable":"SysPolicySourceDocumentRule"},{"childtable":"TrvPolicyRule"},{"childtable":"TSPolicyRule"}]},{"parenttable":"SysTaskRecorderNode","childtables":[{"childtable":"SysTaskRecorderNodeAnnotationUserAction"},{"childtable":"SysTaskRecorderNodeCommandUserAction"},{"childtable":"SysTaskRecorderNodeFormUserAction"},{"childtable":"SysTaskRecorderNodeFormUserActionInputOutput"},{"childtable":"SysTaskRecorderNodeInfoUserAction"},{"childtable":"SysTaskRecorderNodeMenuItemUserAction"},{"childtable":"SysTaskRecorderNodePropertyUserAction"},{"childtable":"SysTaskRecorderNodeScope"},{"childtable":"SysTaskRecorderNodeTaskUserAction"},{"childtable":"SysTaskRecorderNodeUserAction"},{"childtable":"SysTaskRecorderNodeValidationUserAction"}]},{"parenttable":"SysUserRequest","childtables":[{"childtable":"HcmWorkerUserRequest"},{"childtable":"VendVendorPortalUserRequest"}]},{"parenttable":"TrvEnhancedData","childtables":[{"childtable":"TrvEnhancedCarRentalData"},{"childtable":"TrvEnhancedHotelData"},{"childtable":"TrvEnhancedItineraryData"}]}]'
declare @backwardcompatiblecolumns nvarchar(max) = '_SysRowId,DataLakeModified_DateTime,$FileName,LSN,LastProcessedChange_DateTime';
declare @exlcudecolumns nvarchar(max) = 'Id,SinkCreatedOn,SinkModifiedOn,modifieddatetime,modifiedby,modifiedtransactionid,dataareaid,recversion,partition,sysrowversion,recid,tableid,versionnumber,createdon,modifiedon,isDelete,PartitionId,createddatetime,createdby,createdtransactionid,PartitionId,sysdatastatecode';

with table_hierarchy as
(
	select 
	parenttable,
	string_agg(convert(nvarchar(max),childtable), ',') as childtables,
	string_agg(convert(nvarchar(max),joinclause), ' ') as joins,
	string_agg(convert(nvarchar(max),columnnamelist), ',') as columnnamelists
	from (
		select 
		parenttable, 
		childtable,
		'LEFT OUTER JOIN ' + childtable + ' AS ' + childtable + ' ON ' + parenttable +'.recid = ' + childtable + '.recid' AS joinclause,
		(select 
			STRING_AGG(convert(varchar(max),  '[' + TABLE_NAME + '].'+ '[' + COLUMN_NAME + ']'   + ' AS [' + COLUMN_NAME + ']'), ',') 
			from INFORMATION_SCHEMA.COLUMNS C
			where TABLE_SCHEMA = @tableschema
			and TABLE_NAME  = childtable
			and COLUMN_NAME not in (select value from string_split(@backwardcompatiblecolumns + ',' + @exlcudecolumns, ','))
		) as columnnamelist
		from openjson(@tableinheritance) 
		with (parenttable nvarchar(200), childtables nvarchar(max) as JSON) 
		cross apply openjson(childtables) with (childtable nvarchar(200))
		where childtable in (select TABLE_NAME from INFORMATION_SCHEMA.COLUMNS C where TABLE_SCHEMA = @tableschema and C.TABLE_NAME  = childtable)
		) x
		group by parenttable
)

select 
	@ddl_fno_derived_tables = string_agg(convert(nvarchar(max), viewDDL ), ';')
	FROM (
			select 
			'begin try  execute sp_executesql N''' +
			replace(replace(replace(replace(replace(replace(replace(@CreateViewDDL  + ' ' + h.joins + @filter_deleted_rows, 			
			'{tableschema}',@tableschema),
			'{selectcolumns}', @addcolumns + selectcolumns  COLLATE Database_Default +  isnull(enumtranslation COLLATE Database_Default, '') + ',' + h.columnnamelists COLLATE Database_Default), 
			'{tablename}', c.tablename), 
			'{externaldsname}', @externalds_name), 
			'{datatypes}', c.datatypes),
			'{options}', @rowsetoptions),
			'''','''''')  
			+ '''' + ' End Try Begin catch print ERROR_PROCEDURE() + '':'' print ERROR_MESSAGE() end catch' as viewDDL
			from #cdmmetadata c
			left outer join #enumtranslation as e on c.tablename = e.tablename
			inner join table_hierarchy h on c.tablename = h.parenttable
  	) X;

--print(@ddl_fno_derived_tables)
execute sp_executesql @ddl_fno_derived_tables;

