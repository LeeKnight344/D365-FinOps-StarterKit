//Global Parameters
param AZ_Resource_Location string
param AZ_Subscription_id string
param AZ_Resource_Group string
param AZ_Tenant_ID string

//Log Analytics Workspace Parameters
param AZ_LogAnalytics_Workspace_Name string

//App Insights Parameters
param AZ_App_Insights_Name string

//Storage Account Parameters
param AZ_StorageAccount_Name string
param AZ_StorageAccount_FileShare_Name string

//Logic App & App Service Plan Parameters
param AZ_32B_Worker_Process bool
param AZ_FTPS_State string
param AZ_DOTNET_Framework string
param AZ_Logic_App_Service_SKU string
param AZ_Logic_App_Service_SKU_Code string
param AZ_Logic_App_Service_WorkerSize string
param AZ_Logic_App_Service_WorkerSize_ID string
param AZ_Logic_App_Service_Number_Of_Workers string
param AZ_Logic_App_Service_Name string
param AZ_LogicApp_Name string
//param AZ_Always_On bool = false

//API Connection Parameters

  //Commondataservice
  param AZ_APIS_Dataverse_Name string
  param AZ_APIS_Dataverse_Client_ID string
  param AZ_APIS_Dataverse_Object_ID string
  @secure()
  param AZ_APIS_Dataverse_Client_Secret string
  param AZ_APIS_Dataverse_URL string

  //LogAnalytics
  param AZ_APIS_LogAnalytics_Name string

  //BlobStorage
  param AZ_APIS_BlobStorage_Name string

  //FinAndOps
  param AZ_APIS_FinandOps_URL string

//Service Bus Parameters
param AZ_service_bus_Namespace_Name string 
param AZ_service_bus_Namespace_sku string
param AZ_service_bus_Namespace_skuname string

//Key Vault Parameters
param AZ_KeyVaultName string
param AZ_KeyVault_Admin_User string

var contentShare = AZ_StorageAccount_FileShare_Name



resource keyvaultname_resource 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: AZ_KeyVaultName
   location: AZ_Resource_Location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: AZ_Tenant_ID
    accessPolicies: [
      {
        tenantId: AZ_Tenant_ID
        objectId: AZ_APIS_Dataverse_Object_ID
        permissions: {
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
          ]
          certificates: [
            'Get'
            'List'
            'Update'
            'Create'
            'Import'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'ManageContacts'
            'ManageIssuers'
            'GetIssuers'
            'ListIssuers'
            'SetIssuers'
            'DeleteIssuers'
          ]
          keys: [
            'Get'
            'List'
            'Update'
            'Create'
            'Import'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'Decrypt'
            'Encrypt'
            'UnwrapKey'
            'WrapKey'
            'Verify'
            'Sign'
            'Release'
            'Rotate'
            'GetRotationPolicy'
            'SetRotationPolicy'
          ]
        }
      }
      {
        tenantId: AZ_Tenant_ID
        objectId: AZ_KeyVault_Admin_User
        permissions: {
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
          ]
          certificates: [
            'Get'
            'List'
            'Update'
            'Create'
            'Import'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'ManageContacts'
            'ManageIssuers'
            'GetIssuers'
            'ListIssuers'
            'SetIssuers'
            'DeleteIssuers'
          ]
          keys: [
            'Get'
            'List'
            'Update'
            'Create'
            'Import'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'Decrypt'
            'Encrypt'
            'UnwrapKey'
            'WrapKey'
            'Verify'
            'Sign'
            'Release'
            'Rotate'
            'GetRotationPolicy'
            'SetRotationPolicy'
          ]
        }
      }
    ]
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: false
    vaultUri: 'https://${AZ_KeyVaultName}.vault.azure.net/'
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyvaultname_resource
  name: 'AzureServiceBusSASKey' // The name of the secret
  properties: {
    value: listKeys(AZ_service_bus_Namespace_Name_LogicAppSharedAccessKey.id, AZ_service_bus_Namespace_Name_LogicAppSharedAccessKey.apiVersion).primaryConnectionString
  }
}

resource AZ_service_bus_Namespace_Name_resource 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = {
  name: AZ_service_bus_Namespace_Name
  location: AZ_Resource_Location
  sku: {
    name: AZ_service_bus_Namespace_skuname
    tier: AZ_service_bus_Namespace_sku
  }
  properties: {
    geoDataReplication: {
      maxReplicationLagDurationInSeconds: 0
      locations: [
        {
          locationName: AZ_Resource_Location
          roleType: 'Primary'
        }
      ]
    }
    premiumMessagingPartitions: 0
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    zoneRedundant: false
  }
}

resource AZ_service_bus_Namespace_Name_RootManageSharedAccessKey 'Microsoft.ServiceBus/namespaces/authorizationrules@2023-01-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}


resource AZ_service_bus_Namespace_Name_LogicAppSharedAccessKey 'Microsoft.ServiceBus/namespaces/authorizationrules@2023-01-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'LogicAppKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

resource AZ_service_bus_Namespace_Name_default 'Microsoft.ServiceBus/namespaces/networkrulesets@2023-01-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'default'

  properties: {
    publicNetworkAccess: 'Enabled'
    defaultAction: 'Allow'
    virtualNetworkRules: []
    ipRules: []
    trustedServiceAccessEnabled: false
  }
}


resource AZ_service_bus_Namespace_Name_D365_BE_queue_Resource 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbq-d365businessevents'
  properties: {
    maxMessageSizeInKilobytes: 256
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: false
    enableBatchedOperations: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    status: 'Active'
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}

resource AZ_service_bus_Namespace_Name_D365_DE_queue_Resource 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbq-d365dataevents'
  properties: {
    maxMessageSizeInKilobytes: 256
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: false
    enableBatchedOperations: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    status: 'Active'
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}


resource AZ_service_bus_Namespace_Name_D365_tpc_Resource 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbt-integration-d365-outbound'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_All_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_Resource
  name: 'sbs-all'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_All_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_All_Resource
  name: '$Default'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '1=1'
      compatibilityLevel: 20
    }
  }

}

resource AZ_service_bus_Namespace_Name_D365_SBS_Device_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_Resource
  name: 'sbs-devices'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_Device_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_Device_Resource
  name: 'DeviceFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '''
        "http://schemas.microsoft.com/xrm/2011/Claims/EntityLogicalName" IN (
          'mserp_a365deviceentity'
        ) 
		AND "http://schemas.microsoft.com/xrm/2011/Claims/InitiatingUserAgent" LIKE '%FINOPS%'
      '''
      compatibilityLevel: 20
    }
  }

}

resource AZ_service_bus_Namespace_Name_D365_SBS_systemusers_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_Resource
  name: 'sbs-systemusers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_systemusers_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_systemusers_Resource
  name: 'systemusersFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '''
      "http://schemas.microsoft.com/xrm/2011/Claims/EntityLogicalName" IN (
        'mserp_systemuserentity'
      ) 
  AND "http://schemas.microsoft.com/xrm/2011/Claims/InitiatingUserAgent" LIKE '%FINOPS%'
    '''
      compatibilityLevel: 20
    }
  }

}

resource AZ_service_bus_Namespace_Name_D365_SBS_customers_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_Resource
  name: 'sbs-customers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_customers_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_customers_Resource
  name: 'CustomersFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '''
        "http://schemas.microsoft.com/xrm/2011/Claims/EntityLogicalName" IN (
          'mserp_custcustomerv3entity'
        ) 
		AND "http://schemas.microsoft.com/xrm/2011/Claims/InitiatingUserAgent" LIKE '%FINOPS%'
      '''
      compatibilityLevel: 20
    }
  }
}


resource AZ_service_bus_Namespace_Name_D365_tpc_outbound_Resource 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbt-integration-d365-outbound-completed'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_customers_completed_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_outbound_Resource
  name: 'sbs-customers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_customers_completed_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_customers_completed_Resource
  name: 'CustomersFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'CustomerBroadcast'
        ) 
        AND SourceSystem = 'D365'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_Device_completed_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_outbound_Resource
  name: 'sbs-devices'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_Device_completed_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_Device_completed_Resource
  name: 'DeviceFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '''
        BroadcastIdentifier IN (
          'DeviceBroadcast'
        ) 
        AND SourceSystem = 'D365'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_SystemUser_completed_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_outbound_Resource
  name: 'sbs-systemusers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_SystemUser_completed_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_SystemUser_completed_Resource
  name: 'SystemUserFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '''
        BroadcastIdentifier IN (
          'SystemUserBroadcast'
        ) 
        AND SourceSystem = 'D365'
      '''
      compatibilityLevel: 20
    }
  }
}


resource AZ_service_bus_Namespace_Name_D365_tpc_inbound_Resource 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbt-integration-d365-inbound'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_customers_inbound_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_inbound_Resource
  name: 'sbs-customers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_customers_inbound_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_customers_inbound_Resource
  name: 'CustomersFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'CustomerBroadcast'
        ) 
        AND SourceSystem != 'D365'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_device_inbound_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_inbound_Resource
  name: 'sbs-devices'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_device_inbound_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_device_inbound_Resource
  name: 'DeviceFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'DeviceBroadcast'
        ) 
        AND SourceSystem != 'D365'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_systemuser_inbound_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_inbound_Resource
  name: 'sbs-systemusers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_systemuser_inbound_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_systemuser_inbound_Resource
  name: 'SystemUserFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'SystemUserBroadcast'
        ) 
        AND SourceSystem != 'D365'
      '''
      compatibilityLevel: 20
    }
  }
}



resource AZ_service_bus_Namespace_Name_D365_tpc_query_Resource 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbt-integration-d365-query'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_customers_query_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_query_Resource
  name: 'sbs-customers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_customers_query_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_customers_query_Resource
  name: 'CustomersFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'CustomerQueryRequest'
        ) 
        AND BroadcastType = 'QueryRequest'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_device_query_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_query_Resource
  name: 'sbs-devices'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_device_query_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_device_query_Resource
  name: 'DeviceFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'DeviceQueryRequest'
        ) 
        AND BroadcastType = 'QueryRequest'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_systemuser_query_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_query_Resource
  name: 'sbs-systemusers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_systemuser_query_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_systemuser_query_Resource
  name: 'SystemUserFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'SystemUserQueryRequest'
        ) 
        AND BroadcastType = 'QueryRequest'
      '''
      compatibilityLevel: 20
    }
  }
}


resource AZ_service_bus_Namespace_Name_D365_tpc_query_response_Resource 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_resource
  name: 'sbt-integration-d365-query-response'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_customers_query_response_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_query_response_Resource
  name: 'sbs-customers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_customers_query_response_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_customers_query_response_Resource
  name: 'CustomersFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'CustomerQueryResponse'
        ) 
        AND BroadcastType = 'QueryResponse'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_device_query_response_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_query_response_Resource
  name: 'sbs-devices'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_device_query_response_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_device_query_response_Resource
  name: 'DeviceFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'DeviceQueryResponse'
        ) 
        AND BroadcastType = 'QueryResponse'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_service_bus_Namespace_Name_D365_SBS_systemuser_query_response_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_tpc_query_response_Resource
  name: 'sbs-systemusers'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 3
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'PT1H'
  }
}


resource AZ_service_bus_Namespace_Name_D365_SBS_systemuser_query_response_Filters_Resource 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-10-01-preview' = {
  parent: AZ_service_bus_Namespace_Name_D365_SBS_systemuser_query_response_Resource
  name: 'SystemUserFilter'
  properties: {
    action: {}
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression:'''
        BroadcastIdentifier IN (
          'SystemUserQueryResponse'
        ) 
        AND BroadcastType = 'QueryResponse'
      '''
      compatibilityLevel: 20
    }
  }
}

resource AZ_LogAnalytics_Workspace_Name_resource 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: AZ_LogAnalytics_Workspace_Name
  location: AZ_Resource_Location
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
    features: {
      legacy: 0
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource AZ_LogAnalytics_Workspace_Name_genericintegrationslog_CL 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: AZ_LogAnalytics_Workspace_Name_resource
  name: 'genericintegrationslog_CL'
  properties: {
    totalRetentionInDays: 30
    plan: 'Analytics'
    schema: {
      name: 'genericintegrationslog_CL'
      columns: [
        {
          name: 'logicAppName'
          type: 'string'
        }
        {
          name: 'logicAppRegion'
          type: 'string'
        }
        {
          name: 'messageContent'
          type: 'string'
        }
        {
          name: 'messageId'
          type: 'string'
        }
        {
          name: 'messageType'
          type: 'string'
        }
        {
          name: 'triggeringUser'
          type: 'string'
        }
        {
          name: 'integrationType'
          type: 'string'
        }
        {
          name: 'integrationTimestamp'
          type: 'datetime'
        }
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
      ]
    }
    retentionInDays: 30
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
    AZ_StorageAccount_Name_resource
  ]
}


resource AZ_APIS_LogAnalytics_Name_resource 'Microsoft.Web/connections@2016-06-01' = {
  name: AZ_APIS_LogAnalytics_Name
  location: AZ_Resource_Location
  kind: 'V2'
  properties: {
    displayName: AZ_APIS_LogAnalytics_Name
    parameterValues:{
      username: AZ_LogAnalytics_Workspace_Name_resource.properties.customerId 
      password: AZ_LogAnalytics_Workspace_Name_resource.listKeys().primarySharedKey
    }
    statuses: [
      {
        status: 'Connected'
      }
    ]
    customParameterValues: {}
    nonSecretParameterValues: {}
    api: {
      name: 'azureloganalyticsdatacollector'
      displayName: 'Azure Log Analytics Data Collector'
      description: 'Azure Log Analytics Data Collector will send data to any Azure Log Analytics workspace.'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1683/1.0.1683.3680/azureloganalyticsdatacollector/icon.png'
      brandColor: '#637080'
      id: 'subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${AZ_Resource_Location}/managedApis/azureloganalyticsdatacollector'
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
    AZ_App_Insights_Name_resource
    hostingPlan
  ]
}

resource AZ_APIS_BlobStorage_Name_resource 'Microsoft.Web/connections@2016-06-01' = {
  name: AZ_APIS_BlobStorage_Name
  location: AZ_Resource_Location
  kind: 'V2'
  properties: {
    displayName: AZ_APIS_BlobStorage_Name
    parameterValues:{
      accountname: AZ_StorageAccount_Name_resource.name
      accesskey: AZ_StorageAccount_Name_resource.listKeys().keys[0].value
    }
    customParameterValues: {}
    api: {
      name: 'azureblob'
      displayName: 'Azure Blob Storage'
      description: 'Microsoft Azure Storage provides a massively scalable, durable, and highly available storage for data on the cloud, and serves as the data storage solution for modern applications. Connect to Blob Storage to perform various operations such as create, update, get and delete on blobs in your Azure Storage account.'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1714/1.0.1714.3897/azureblob/icon.png'
      brandColor: '#804998'
      id: '/subscriptions/${AZ_Subscription_id}/providers/Microsoft.Web/locations/${AZ_Resource_Location}/managedApis/azureblob'
      type: 'Microsoft.Web/locations/managedApis'
    }
    testLinks: [
      {
        requestUri: 'https://management.azure.com:443/subscriptions/${AZ_Subscription_id}/resourceGroups/${AZ_Resource_Group}/providers/Microsoft.Web/connections/${AZ_APIS_BlobStorage_Name}/extensions/proxy/testconnection?api-version=2016-06-01'
        method: 'get'
      }
    ]
  }
}





resource AZ_APIS_LogAnalytics_AccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: AZ_LogicApp_resource.name 
  parent: AZ_APIS_LogAnalytics_Name_resource
  location: AZ_Resource_Location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: AZ_LogicApp_resource.identity.principalId 
    }
  }
}
}




resource AZ_App_Insights_Name_resource 'microsoft.insights/components@2020-02-02' = {
  name: AZ_App_Insights_Name
 location : AZ_Resource_Location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'IbizaWebAppExtensionCreate'
    RetentionInDays: 90
    WorkspaceResourceId: '/subscriptions/${AZ_Subscription_id}/resourceGroups/${AZ_Resource_Group}/providers/Microsoft.OperationalInsights/workspaces/${AZ_LogAnalytics_Workspace_Name}'
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
    AZ_StorageAccount_Name_resource
  ]
}

resource AZ_App_Insights_Name_degradationindependencyduration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'degradationindependencyduration'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'degradationindependencyduration'
      DisplayName: 'Degradation in dependency duration'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_degradationinserverresponsetime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'degradationinserverresponsetime'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'degradationinserverresponsetime'
      DisplayName: 'Degradation in server response time'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_digestMailConfiguration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'digestMailConfiguration'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'digestMailConfiguration'
      DisplayName: 'Digest Mail Configuration'
      Description: 'This rule describes the digest mail preferences'
      HelpUrl: 'www.homail.com'
      IsHidden: true
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_extension_billingdatavolumedailyspikeextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'extension_billingdatavolumedailyspikeextension'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'extension_billingdatavolumedailyspikeextension'
      DisplayName: 'Abnormal rise in daily data volume (preview)'
      Description: 'This detection rule automatically analyzes the billing data generated by your application, and can warn you about an unusual increase in your application\'s billing costs'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/tree/master/SmartDetection/billing-data-volume-daily-spike.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_extension_canaryextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'extension_canaryextension'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'extension_canaryextension'
      DisplayName: 'Canary extension'
      Description: 'Canary extension'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/'
      IsHidden: true
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_extension_exceptionchangeextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'extension_exceptionchangeextension'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'extension_exceptionchangeextension'
      DisplayName: 'Abnormal rise in exception volume (preview)'
      Description: 'This detection rule automatically analyzes the exceptions thrown in your application, and can warn you about unusual patterns in your exception telemetry.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/abnormal-rise-in-exception-volume.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_extension_memoryleakextension 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'extension_memoryleakextension'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'extension_memoryleakextension'
      DisplayName: 'Potential memory leak detected (preview)'
      Description: 'This detection rule automatically analyzes the memory consumption of each process in your application, and can warn you about potential memory leaks or increased memory consumption.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/tree/master/SmartDetection/memory-leak.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_extension_securityextensionspackage 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'extension_securityextensionspackage'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'extension_securityextensionspackage'
      DisplayName: 'Potential security issue detected (preview)'
      Description: 'This detection rule automatically analyzes the telemetry generated by your application and detects potential security issues.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/application-security-detection-pack.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_extension_traceseveritydetector 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'extension_traceseveritydetector'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'extension_traceseveritydetector'
      DisplayName: 'Degradation in trace severity ratio (preview)'
      Description: 'This detection rule automatically analyzes the trace logs emitted from your application, and can warn you about unusual patterns in the severity of your trace telemetry.'
      HelpUrl: 'https://github.com/Microsoft/ApplicationInsights-Home/blob/master/SmartDetection/degradation-in-trace-severity-ratio.md'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_longdependencyduration 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'longdependencyduration'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'longdependencyduration'
      DisplayName: 'Long dependency duration'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_migrationToAlertRulesCompleted 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'migrationToAlertRulesCompleted'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'migrationToAlertRulesCompleted'
      DisplayName: 'Migration To Alert Rules Completed'
      Description: 'A configuration that controls the migration state of Smart Detection to Smart Alerts'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: true
      IsEnabledByDefault: false
      IsInPreview: true
      SupportsEmailNotifications: false
    }
    Enabled: false
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_slowpageloadtime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'slowpageloadtime'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'slowpageloadtime'
      DisplayName: 'Slow page load time'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}

resource AZ_App_Insights_Name_slowserverresponsetime 'microsoft.insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  parent: AZ_App_Insights_Name_resource
  name: 'slowserverresponsetime'
 location : AZ_Resource_Location
  properties: {
    RuleDefinitions: {
      Name: 'slowserverresponsetime'
      DisplayName: 'Slow server response time'
      Description: 'Smart Detection rules notify you of performance anomaly issues.'
      HelpUrl: 'https://docs.microsoft.com/en-us/azure/application-insights/app-insights-proactive-performance-diagnostics'
      IsHidden: false
      IsEnabledByDefault: true
      IsInPreview: false
      SupportsEmailNotifications: true
    }
    Enabled: true
    SendEmailsToSubscriptionOwners: true
    CustomEmails: []
  }
}


resource AZ_APIS_Dataverse_Name_resource 'Microsoft.Web/connections@2016-06-01' = {
  name: AZ_APIS_Dataverse_Name
  location: AZ_Resource_Location
  kind: 'V2'
  properties: {
    displayName: AZ_APIS_Dataverse_Name
    parameterValues: {
      'token:clientId': AZ_APIS_Dataverse_Client_ID
      'token:clientSecret': AZ_APIS_Dataverse_Client_Secret
      'token:TenantId': subscription().tenantId
      'token:grantType': 'client_credentials'
    }
    statuses: [
      {
        status: 'Connected'
      }
    ]
    customParameterValues: {}
    api: {
      name: 'commondataservice'
      displayName: 'Microsoft Dataverse (legacy)'
      description: 'Provides access to the environment database in Microsoft Dataverse.'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1681/1.0.1681.3668/commondataservice/icon-la.png'
      brandColor: '#637080'
      id: 'subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${AZ_Resource_Location}/managedApis/commondataservice'
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}

resource AZ_APIS_Dataverse_AccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: '${AZ_APIS_Dataverse_Name_resource.name}/${AZ_LogicApp_resource.name}'
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: AZ_LogicApp_resource.identity.principalId
      }
    }
  }
}

resource AZ_LogicApp_resource 'Microsoft.Web/sites@2022-03-01' = {
  name: AZ_LogicApp_Name
  kind: 'functionapp,workflowapp'
  location: AZ_Resource_Location
  tags: {
    'hidden-link: /app-insights-resource-id': '/subscriptions/${AZ_Subscription_id}/resourceGroups/${AZ_Resource_Group}/providers/Microsoft.Insights/components/${AZ_App_Insights_Name}'
  }
  properties: {
    name: AZ_LogicApp_Name
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: reference('microsoft.insights/components/${AZ_App_Insights_Name}', '2015-05-01').ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${AZ_StorageAccount_Name};AccountKey=${listKeys(AZ_StorageAccount_Name_resource.id,'2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${AZ_StorageAccount_Name};AccountKey=${listKeys(AZ_StorageAccount_Name_resource.id,'2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: contentShare
        }
        {
          name: 'serviceBus_connectionString'
          value: listKeys(AZ_service_bus_Namespace_Name_LogicAppSharedAccessKey.id, AZ_service_bus_Namespace_Name_LogicAppSharedAccessKey.apiVersion).primaryConnectionString
        }
        {
          name: 'subsriptionid'
          value: AZ_Subscription_id
        }
        {
          name: 'dataverseconnectionruntimeurl'
          value: reference(resourceId('Microsoft.Web/connections', AZ_APIS_Dataverse_Name)).connectionRuntimeUrl
        }
        {
          name: 'blobstorageconnectionruntimeurl'
          value: reference(resourceId('Microsoft.Web/connections', AZ_APIS_BlobStorage_Name)).connectionRuntimeUrl
        }
        {
          name: 'loganalyticsconnectionruntimeurl'
          value: reference(resourceId('Microsoft.Web/connections', AZ_APIS_LogAnalytics_Name)).connectionRuntimeUrl
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'azureregion'
          value: AZ_Resource_Location
        }
        {
          name: 'Dataverse_Client_Id'
          value: AZ_APIS_Dataverse_Client_ID
        }
        {
          name: 'Dataverse_Client_Secret'
          value: AZ_APIS_Dataverse_Client_Secret
        }
        {
          name: 'Dataverse URL'
          value: AZ_APIS_Dataverse_URL
        }
        {
          name: 'Finance and Operations URL'
          value: AZ_APIS_FinandOps_URL
        }
        {
          name: 'Azure Tenant ID'
          value: AZ_Tenant_ID
        }
      ]
      cors: {}
      use32BitWorkerProcess: AZ_32B_Worker_Process
      ftpsState: AZ_FTPS_State
      netFrameworkVersion: AZ_DOTNET_Framework
    }
    clientAffinityEnabled: false
    virtualNetworkSubnetId: null
    functionsRuntimeAdminIsolationEnabled: false
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
    serverFarmId: '/subscriptions/${AZ_Subscription_id}/resourcegroups/${AZ_Resource_Group}/providers/Microsoft.Web/serverfarms/${AZ_Logic_App_Service_Name}'
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
    AZ_App_Insights_Name_resource
    hostingPlan
  ]
}


resource name_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  parent: AZ_LogicApp_resource
  name: 'scm'
  properties: {
    allow: false
  }
}

resource name_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  parent: AZ_LogicApp_resource
  name: 'ftp'
  properties: {
    allow: false
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2018-11-01' = {
  name: AZ_Logic_App_Service_Name
  location: AZ_Resource_Location
  kind: ''
  tags: {}
  properties: {
    name: AZ_Logic_App_Service_Name
    workerSize: AZ_Logic_App_Service_WorkerSize
    workerSizeId: AZ_Logic_App_Service_WorkerSize_ID
    numberOfWorkers: AZ_Logic_App_Service_Number_Of_Workers
    maximumElasticWorkerCount: '20'
    zoneRedundant: false
  }
  sku: {
    tier: AZ_Logic_App_Service_SKU
    name: AZ_Logic_App_Service_SKU_Code
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
  ]
}


resource AZ_StorageAccount_Name_resource 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: AZ_StorageAccount_Name
  location: AZ_Resource_Location
  tags: {}
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    defaultToOAuthAuthentication: true
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
  ]
}

resource AZ_StorageAccount_Name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: AZ_StorageAccount_Name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

resource AZ_StorageAccount_Name_sa_blob_logs 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  scope: AZ_StorageAccount_Name_resource
  name: '${AZ_StorageAccount_Name}-sa-blob-logs'
  properties: {
    workspaceId: '/subscriptions/${AZ_Subscription_id}/resourceGroups/${AZ_Resource_Group}/providers/Microsoft.OperationalInsights/workspaces/${AZ_LogAnalytics_Workspace_Name}'
    // logs: [
    //   {
    //     category: 'StorageWrite'
    //     enabled: true
    //   }
    // ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
  dependsOn: [
    AZ_LogAnalytics_Workspace_Name_resource
    AZ_StorageAccount_Name_resource
  ]
}
