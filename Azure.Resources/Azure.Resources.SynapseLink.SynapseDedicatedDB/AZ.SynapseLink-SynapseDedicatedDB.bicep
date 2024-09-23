//Global Parameters
param AZ_Subscription_id string
param AZ_ResourceGroup_Name string
param AZ_Resource_Location string
param AZ_Resource_Location_Formatted string = 'UK West'

// Synapse Analytics Workspace Parameters
param AZ_SynapseWorkspace_Name string
param AZ_SynapseWorkspace_Linked_StorageAccount_defaultfilesystem string
param AZ_SynapseWorkspace_SQL_Local_Username string
param AZ_SynapseWorkspace_Managed_ResourceGroupName string
param AZ_SynapseWorkspace_EntraID_Admin_ObjectID string

// Apache Spark Pool Parameters
param AZ_SparkPool_SynapseWorkspace_Name string
param AZ_SparkPool_AutoScale bool
param AZ_SparkPool_IsolatedCompute bool
param AZ_SparkPool_MinNodeCount int
param AZ_SparkPool_MaxNodeCount int
param AZ_SparkPool_NodeCount int
param AZ_SparkPool_NodeSizeFamily string
param AZ_SparkPool_NodeSize string
param AZ_SparkPool_AutoPause bool
param AZ_SparkPool_AutoPauseDelay int
param AZ_SparkPool_Version string
param AZ_SparkPool_ConfigFile_Name string
param AZ_SparkPool_ConfigFile_PropertiesContent string
param AZ_SparkPool_SessionLevelPackages bool
param AZ_SparkPool_DynamicExecutorAllocation bool
param AZ_SparkPool_MinExecutorCount int
param AZ_SparkPool_MaxExecutorCount int
param AZ_SparkPool_CacheSize int

// Synapse Analytics Dedicated DB Parameters
param AZ_SynapseWorkspace_DecicatedSQL_Pool_SKU string = 'DW100c'
param AZ_SynapseWorkspace_DecicatedSQL_Pool_Capacity int = 0
param AZ_SynapseWorkspace_DecicatedSQL_MaxSize int = 263882790666240
param AZ_SynapseWorkspace_DedicatedSQL_Name string = 'slfddedicateddb'

// Datalake Storage Account Parameters
param AZ_StorageAccount_Name string

// Key Vault Parameters
param AZ_KeyVault_Name string
param AZ_KeyVault_Sku string
param AZ_KeyVault_Family string = 'A'
param AZ_KeyVault_TenantId string
param AZ_KeyVault_EnabledForDeployment bool
param AZ_KeyVault_EnabledForTemplateDeployment bool
param AZ_KeyVault_EnabledForDiskEncryption bool
param AZ_KeyVault_EnabledForRBACAuthorization bool
param AZ_KeyVault_Public_Network_Access string
param AZ_KeyVault_SoftDelete_Enabled bool
param AZ_KeyVault_SoftDelete_RetentionDays int


// Secure Tag to hide SQL password during deployment
@secure()
param AZ_SynapseWorkspace_SQL_Local_Password string



resource workspaceName_sparkPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01-preview' = {
  name: '${AZ_SynapseWorkspace_Name}/${AZ_SparkPool_SynapseWorkspace_Name}'
  location: AZ_Resource_Location
  properties: {
    nodeCount: AZ_SparkPool_NodeCount
    nodeSizeFamily: AZ_SparkPool_NodeSizeFamily
    nodeSize: AZ_SparkPool_NodeSize
    autoScale: {
      enabled: AZ_SparkPool_AutoScale
      minNodeCount: AZ_SparkPool_MinNodeCount
      maxNodeCount: AZ_SparkPool_MaxNodeCount
    }
    autoPause: {
      enabled: AZ_SparkPool_AutoPause
      delayInMinutes: AZ_SparkPool_AutoPauseDelay
    }
    sparkVersion: AZ_SparkPool_Version
    sparkConfigProperties: {
      filename: AZ_SparkPool_ConfigFile_Name
      content: AZ_SparkPool_ConfigFile_PropertiesContent
    }
    isComputeIsolationEnabled: AZ_SparkPool_IsolatedCompute
    sessionLevelPackagesEnabled: AZ_SparkPool_SessionLevelPackages
    dynamicExecutorAllocation: {
      enabled: AZ_SparkPool_DynamicExecutorAllocation
      minExecutors: AZ_SparkPool_MinExecutorCount
      maxExecutors: AZ_SparkPool_MaxExecutorCount
    }
    cacheSize: AZ_SparkPool_CacheSize
  }
  
  dependsOn: [
    AZ_SynapseWorkspace_Name_resource
  ]
}



resource AZ_StorageAccount_Name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: AZ_StorageAccount_Name
  location: 'ukwest'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
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

resource Microsoft_Storage_storageAccounts_fileServices_AZ_StorageAccount_Name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: AZ_StorageAccount_Name_resource
  name: 'default'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Reference to retrieve the Synapse workspace system-assigned identity principal ID (object ID)
var AZ_SynapseWorkspace_ObjectId = reference(AZ_SynapseWorkspace_Name_resource.id, '2021-06-01', 'full').identity.principalId

resource Microsoft_Storage_storageAccounts_queueServices_AZ_StorageAccount_Name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: AZ_StorageAccount_Name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_AZ_StorageAccount_Name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: AZ_StorageAccount_Name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource AZ_StorageAccount_Name_default_slfdsaplaceholder 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: AZ_StorageAccount_Name_default
  name: 'slfdsaplaceholder'
  properties: {
//    immutableStorageWithVersioning: {
//     enabled: true
//  }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
    
  }
}

resource AZ_SynapseWorkspace_Name_resource 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: AZ_SynapseWorkspace_Name
  location: AZ_Resource_Location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      resourceId: '/subscriptions/${AZ_Subscription_id}/resourceGroups/${AZ_ResourceGroup_Name}/providers/Microsoft.Storage/storageAccounts/${AZ_StorageAccount_Name}'
      createManagedPrivateEndpoint: false
      accountUrl: 'https://${AZ_StorageAccount_Name}.dfs.core.windows.net'
      filesystem: AZ_SynapseWorkspace_Linked_StorageAccount_defaultfilesystem
    }
    encryption: {}
    managedResourceGroupName: AZ_SynapseWorkspace_Managed_ResourceGroupName
    sqlAdministratorLogin: AZ_SynapseWorkspace_SQL_Local_Username
    sqlAdministratorLoginPassword: AZ_SynapseWorkspace_SQL_Local_Password
    privateEndpointConnections: []
    publicNetworkAccess: 'Enabled'
    cspWorkspaceAdminProperties: {
      initialWorkspaceAdminObjectId: AZ_SynapseWorkspace_EntraID_Admin_ObjectID
    }
    azureADOnlyAuthentication: false
    trustedServiceBypassEnabled: false
  }
}

resource AZ_SynapseWorkspace_Name_Default 'Microsoft.Synapse/workspaces/auditingSettings@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'Default'
  properties: {
    retentionDays: 0
    auditActionsAndGroups: []
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
}

resource Microsoft_Synapse_workspaces_azureADOnlyAuthentications_AZ_SynapseWorkspace_Name_default 'Microsoft.Synapse/workspaces/azureADOnlyAuthentications@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'default'
  properties: {
    azureADOnlyAuthentication: false
  }
}

resource Microsoft_Synapse_workspaces_dedicatedSQLminimalTlsSettings_AZ_SynapseWorkspace_Name_default 'Microsoft.Synapse/workspaces/dedicatedSQLminimalTlsSettings@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'default'
  //location: AZ_Resource_Location
  properties: {
    minimalTlsVersion: '1.2'
  }
}

resource Microsoft_Synapse_workspaces_extendedAuditingSettings_AZ_SynapseWorkspace_Name_Default 'Microsoft.Synapse/workspaces/extendedAuditingSettings@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'Default'
  properties: {
    retentionDays: 0
    auditActionsAndGroups: []
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
}

resource AZ_SynapseWorkspace_Name_allowAllAzureResources 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}


resource AZ_SynapseWorkspace_Name_User_01 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'allow_user_01'
  properties: {
    startIpAddress: '109.146.142.85'
    endIpAddress: '109.146.142.85'
  }
}

resource AZ_SynapseWorkspace_Name_AutoResolveIntegrationRuntime 'Microsoft.Synapse/workspaces/integrationruntimes@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'AutoResolveIntegrationRuntime'
  properties: {
    type: 'Managed'
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

resource Microsoft_Synapse_workspaces_securityAlertPolicies_AZ_SynapseWorkspace_Name_Default 'Microsoft.Synapse/workspaces/securityAlertPolicies@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_resource
  name: 'Default'
  properties: {
    state: 'Disabled'
    disabledAlerts: [
      ''
    ]
    emailAddresses: [
      ''
    ]
    emailAccountAdmins: false
    retentionDays: 0
  }
}


resource AZ_SynapseWorkspace_Name_slfddedicateddb 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: '${AZ_SynapseWorkspace_Name}/${AZ_SynapseWorkspace_DedicatedSQL_Name}'
  location: AZ_Resource_Location
  sku: {
    name: AZ_SynapseWorkspace_DecicatedSQL_Pool_SKU
    capacity: AZ_SynapseWorkspace_DecicatedSQL_Pool_Capacity
  }
  properties: {
    maxSizeBytes: AZ_SynapseWorkspace_DecicatedSQL_MaxSize
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    storageAccountType: 'GRS'
    provisioningState: 'Succeeded'
  }

  dependsOn: [
    AZ_SynapseWorkspace_Name_resource
  ]
}

resource AZ_SynapseWorkspace_Name_slfddedicateddb_Default 'Microsoft.Synapse/workspaces/sqlPools/auditingSettings@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_slfddedicateddb
  name: 'default'
  properties: {
    retentionDays: 0
    auditActionsAndGroups: []
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
    dependsOn: [
    AZ_SynapseWorkspace_Name_resource
  ]
}

resource Microsoft_Synapse_workspaces_sqlPools_extendedAuditingSettings_AZ_SynapseWorkspace_Name_slfddedicateddb_Default 'Microsoft.Synapse/workspaces/sqlPools/extendedAuditingSettings@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_slfddedicateddb
  name: 'default'
  properties: {
    retentionDays: 0
    auditActionsAndGroups: []
    isStorageSecondaryKeyInUse: false
    isAzureMonitorTargetEnabled: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
  dependsOn: [
    AZ_SynapseWorkspace_Name_resource
  ]
}

resource Microsoft_Synapse_workspaces_sqlPools_geoBackupPolicies_AZ_SynapseWorkspace_Name_slfddedicateddb_Default 'Microsoft.Synapse/workspaces/sqlPools/geoBackupPolicies@2021-06-01' = {
  parent: AZ_SynapseWorkspace_Name_slfddedicateddb
  name: 'Default'
  location: AZ_Resource_Location_Formatted
  properties: {
    state: 'Enabled'
  }
  dependsOn: [
    AZ_SynapseWorkspace_Name_resource
  ]
}

resource AZ_KeyVault_Name_resource 'Microsoft.KeyVault/vaults@2023-08-01-preview' = {
  name: AZ_KeyVault_Name
  location: AZ_Resource_Location
  properties: {
    enabledForDeployment: AZ_KeyVault_EnabledForDeployment
    enabledForTemplateDeployment: AZ_KeyVault_EnabledForTemplateDeployment
    enabledForDiskEncryption: AZ_KeyVault_EnabledForDiskEncryption
    enableRbacAuthorization: AZ_KeyVault_EnabledForRBACAuthorization
    accessPolicies: [
      {
        tenantId: AZ_KeyVault_TenantId
        objectId: AZ_SynapseWorkspace_EntraID_Admin_ObjectID
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
        tenantId: AZ_KeyVault_TenantId
        objectId: AZ_SynapseWorkspace_ObjectId
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
    tenantId: AZ_KeyVault_TenantId
    sku: {
      name: AZ_KeyVault_Sku
      family: AZ_KeyVault_Family
    }
    publicNetworkAccess: AZ_KeyVault_Public_Network_Access
    enableSoftDelete: AZ_KeyVault_SoftDelete_Enabled
    softDeleteRetentionInDays: AZ_KeyVault_SoftDelete_RetentionDays
  }
  tags: {}
  dependsOn: []
}

resource keyVaultSecret_Serverless_Username 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'ServerlessDatabaseUsername'
  properties: {
    value: AZ_SynapseWorkspace_SQL_Local_Username 
  }
  dependsOn: [
    AZ_KeyVault_Name_resource  
  ]
}


resource keyVaultSecret_Serverless_pwd 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'ServerlessDatabasePassword'  
  properties: {
    value: AZ_SynapseWorkspace_SQL_Local_Password  
  }
  dependsOn: [
    AZ_KeyVault_Name_resource  
  ]
}


resource keyVaultSecret_Hosted_Username 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'HostedDatabaseUsername' 
  properties: {
    value: AZ_SynapseWorkspace_SQL_Local_Username   
  }
  dependsOn: [
    AZ_KeyVault_Name_resource  
  ]
}

resource keyVaultSecret_Hosted_pwd 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'HostedDatabasePassword'  
  properties: {
    value: AZ_SynapseWorkspace_SQL_Local_Password  
  }
  dependsOn: [
    AZ_KeyVault_Name_resource
  ]
}
