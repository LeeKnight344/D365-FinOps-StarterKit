//Global Parameters
param AZ_Subscription_id string
param AZ_ResourceGroup_Name string
param AZ_Resource_Location string

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

// Azure SQL Server Host Parameters
param AZ_SQLHost_Name string
param AZ_SQLHost_Local_Admin_Username string
param AZ_SQLHost_Local_Admin_Password string
param AZ_SQLHost_EntraID_Admin string
param AZ_SQLHost_EntraID_Admin_SID string
param AZ_SQLHost_Version string
param AZ_SQLHost_TLSMin_Version string
param AZ_SQLHost_PublicAccess string
param AZ_SQLHost_TenantId string
param AZ_SQLHost_EntraIDAuth_Enforced bool
param AZ_SQLHost_OutboundAccess_Restricted string
param AZ_SQLHost_AdminType string
param AZ_SQLHost_PrincipalType string
param AZ_SQLHost_Kind string
param AZ_SQLHost_FirewallRule_01 string
param AZ_SQLHost_FirewallRule_01_StartIP string
param AZ_SQLHost_FirewallRule_01_EndIP string

// Azure SQL DB Parameters
param AZ_SQLDB_Name string
param AZ_SQLDB_sku_name string
param AZ_SQLDB_tier string
param AZ_SQLDB_family string
param AZ_SQLDB_capacity int
param AZ_SQLDB_Kind string
param AZ_SQLDB_Collation string
param AZ_SQLDB_MaxSize int
param AZ_SQLDB_Catalog_Collation string
param AZ_SQLDB_Zone_Redundant bool
param AZ_SQLDB_Read_Scale string
param AZ_SQLDB_AutoPause_Delay int
param AZ_SQLDB_Backup_Storage_Redundancy string
param AZ_SQLDB_Min_Capacity string
param AZ_SQLDB_Ledger_Enabled bool
param AZ_SQLDB_Availibility_Zone string

// Datalake Storage Account Parameters
param AZ_StorageAccount_Name string


// Key Vault Parameters
param AZ_KeyVault_Name string
param AZ_KeyVault_Sku string
param AZ_KeyVault_Family string
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


// Reference to retrieve the Synapse workspace system-assigned identity principal ID (object ID)
var AZ_SynapseWorkspace_ObjectId = reference(AZ_SynapseWorkspace_Name_resource.id, '2021-06-01', 'full').identity.principalId

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


resource AZ_SQLHost_Name_resource 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: AZ_SQLHost_Name
  location: AZ_Resource_Location
  kind: AZ_SQLHost_Kind
  properties: {
    administratorLogin: AZ_SQLHost_Local_Admin_Username
    administratorLoginPassword: AZ_SQLHost_Local_Admin_Password
    version: AZ_SQLHost_Version
    minimalTlsVersion: AZ_SQLHost_TLSMin_Version
    publicNetworkAccess: AZ_SQLHost_PublicAccess
    administrators: {
      administratorType: AZ_SQLHost_AdminType
      principalType: AZ_SQLHost_PrincipalType
      login: AZ_SQLHost_EntraID_Admin
      sid: AZ_SQLHost_EntraID_Admin_SID
      tenantId: AZ_SQLHost_TenantId
      azureADOnlyAuthentication: AZ_SQLHost_EntraIDAuth_Enforced
    }
    restrictOutboundNetworkAccess: AZ_SQLHost_OutboundAccess_Restricted
  }
}

resource AZ_SQLHost_Name_ActiveDirectory 'Microsoft.Sql/servers/administrators@2023-08-01-preview' = {
  parent: AZ_SQLHost_Name_resource
  name: AZ_SQLHost_AdminType
  properties: {
    administratorType: AZ_SQLHost_AdminType
    login: AZ_SQLHost_EntraID_Admin
    sid: AZ_SQLHost_EntraID_Admin_SID
    tenantId: AZ_SQLHost_TenantId
  }
}

resource AZ_SQLHost_FirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: AZ_SQLHost_Name_resource
  name: AZ_SQLHost_FirewallRule_01
  properties: {
    startIpAddress: AZ_SQLHost_FirewallRule_01_StartIP
    endIpAddress: AZ_SQLHost_FirewallRule_01_EndIP
  }
}


resource AZ_SQLHost_Name_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: AZ_SQLHost_Name_resource
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource Microsoft_Sql_servers_azureADOnlyAuthentications_AZ_SQLHost_Name_Default 'Microsoft.Sql/servers/azureADOnlyAuthentications@2023-08-01-preview' = {
  parent: AZ_SQLHost_Name_resource
  name: 'Default'
  properties: {
    azureADOnlyAuthentication: false
  }
}


resource AZ_SQLHost_Name_DB 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: AZ_SQLHost_Name_resource
  name: AZ_SQLDB_Name
  location: AZ_Resource_Location
  sku: {
    name: AZ_SQLDB_sku_name 
    tier: AZ_SQLDB_tier
    family: AZ_SQLDB_family
    capacity: AZ_SQLDB_capacity
  }
  kind: AZ_SQLDB_Kind
  properties: {
    collation: AZ_SQLDB_Collation
    maxSizeBytes:  AZ_SQLDB_MaxSize
    catalogCollation:  AZ_SQLDB_Catalog_Collation
    zoneRedundant: AZ_SQLDB_Zone_Redundant
    readScale: AZ_SQLDB_Read_Scale
    autoPauseDelay:  AZ_SQLDB_AutoPause_Delay
    requestedBackupStorageRedundancy:  AZ_SQLDB_Backup_Storage_Redundancy
    minCapacity: json(AZ_SQLDB_Min_Capacity)
    maintenanceConfigurationId: '/subscriptions/${AZ_Subscription_id}/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_Default'
    isLedgerOn:  AZ_SQLDB_Ledger_Enabled
    availabilityZone:  AZ_SQLDB_Availibility_Zone
  }
}



resource Microsoft_Sql_servers_devOpsAuditingSettings_AZ_SQLHost_Name_Default 'Microsoft.Sql/servers/devOpsAuditingSettings@2023-08-01-preview' = {
  parent: AZ_SQLHost_Name_resource
  name: 'Default'
  properties: {
    isAzureMonitorTargetEnabled: false
    isManagedIdentityInUse: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
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

}


resource keyVaultSecret_Serverless_pwd 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'ServerlessDatabasePassword'  
  properties: {
    value: AZ_SynapseWorkspace_SQL_Local_Password  
  }

}


resource keyVaultSecret_Hosted_Username 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'HostedDatabaseUsername' 
  properties: {
    value: AZ_SQLHost_Local_Admin_Username  
  }

}

resource keyVaultSecret_Hosted_pwd 'Microsoft.KeyVault/vaults/secrets@2023-08-01-preview' = {
  parent: AZ_KeyVault_Name_resource
  name: 'HostedDatabasePassword'  
  properties: {
    value: AZ_SQLHost_Local_Admin_Password 
  }

}
