@description('The name of the application')
param applicationName string = uniqueString(resourceGroup().id)

@description('The location to deploy our resources to. Must be a region that supports availability zones')
param location string = resourceGroup().location

@description('The name of our Container App environment')
param containerAppEnvName string = 'env-${applicationName}'

@description('The name of the log analytics workspace that will be deployed')
param logAnalyticsWorkspaceName string = 'law-${applicationName}'

@description('The name of the App Insights workspace that will be deployed')
param applicationInsightsName string = 'appins-${applicationName}'

@description('The name of the container registry that will be deployed')
param containerRegistryName string = 'acr${applicationName}'

@description('The name of the virtual network that will be deployed')
param virtualNetworkName string = 'vnet-${applicationName}'

@description('The name of the key vault that will be deployed')
param keyVaultName string = 'kv-${applicationName}'

@description('The name of the Service Bus namespace that will be deployed')
param serviceBusName string = 'sb-${applicationName}'

@description('The name of the Azure Cache for Redis instance to deploy')
param redisCacheName string = 'cache-${applicationName}'

@description('The name of the SQL Server that will be deployed')
param sqlServerName string = 'sql-${applicationName}'

@description('The name of the SQL database to create')
param ordersDatabaseName string = '${applicationName}-orders'

@description('The name of the Catalog Database to create in SQL Server')
param catalogDatabaseName string = '${applicationName}-catalog'

@description('Optional. SQL admin username. Defaults to \'\${applicationName}-admin\'')
param sqlAdmin string = '${applicationName}-admin'

@description('Optional. A password for the Azure SQL server admin user. Defaults to a new GUID.')
@secure()
param sqlAdminPassword string = newGuid()

@description('The docker container image to deploy')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Optional. An Azure tags object for tagging parent resources that support tags.')
param tags object = {
  Project: 'Azure highly-available zone-redundant container apps application'
}

@description('Number of CPU cores the container can use. Can be with a maximum of two decimals.')
@allowed([
  '0.25'
  '0.5'
  '0.75'
  '1'
  '1.25'
  '1.5'
  '1.75'
  '2'
])
param cpuCore string = '0.5'

@description('Amount of memory (in gibibytes, GiB) allocated to the container up to 4GiB. Can be with a maximum of two decimals. Ratio with CPU cores must be equal to 2.')
@allowed([
  '0.5'
  '1'
  '1.5'
  '2'
  '3'
  '3.5'
  '4'
])
param memorySize string = '1'

@description('The minimum number of replicas that will be deployed. Must be at least 3 for ZR')
@minValue(3)
@maxValue(30)
param minReplica int = 3

@description('The maximum number of replicas that will be deployed')
@minValue(1)
@maxValue(30)
param maxReplica int = 30

// Container App Variables
var containerAppSubnetName = 'infrastructure-subnet'
var storeFrontend = 'frontend'
var orderingAppName = 'ordering'
var basketAppName = 'basket'
var catalogAppName = 'catalog'
var shared_config = [
  {
    name: 'APPINSIGHTS_CONNECTION_STRING'
    value: appInsights.outputs.connectionString
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.outputs.instrumentationKey
  }
  {
    name: 'AZURE_SERVICE_BUS_FQ_NAMESPACE'
    value: replace(replace(serviceBus.outputs.endpoint, 'https://', ''), ':433/', '')
  }
  {
    name: 'AZURE_SERVICE_BUS_QUEUE_NAME'
    value: queueName
  }
]

// Service Bus Variables
var queueName = 'orders'

// Environment specific private link suffixes
// reference: https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns
var privateLinkContainerRegistyDnsNames = {
  AzureCloud: 'privatelink.azurecr.io'
}

var privateLinkServiceBusDnsNames = {
  AzureCloud: 'privatelink.servicebus.windows.net'
  AzureUSGovernment: 'privatelink.servicebus.usgovcloudapi.net'
  AzureChinaCloud: 'privatelink.servicebus.chinacloudapi.cn'
}

var privateLinkRedisDnsNames = {
  AzureCloud: 'privatelink.redis.cache.windows.net'
  AzureUSGovernment: 'privatelink.redis.cache.usgovcloudapi.net'
  AzureChinaCloud: 'privatelink.redis.cache.chinacloudapi.cn'
}

// VNET
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      // [0] Container App Environment VNet Integration Subnet
      {
        name: containerAppSubnetName
        properties: {
          addressPrefix: '10.0.0.0/23'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [1] Container Registry integration subnet
      {
        name: 'containerregistry-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [2] Service Bus private endpoint subnet
      {
        name: 'servicebus-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [3] Azure Cache for Redis private endpoint subnet
      {
        name: 'redis-subnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // [4] Azure SQL private endpoint subnet
      {
        name: 'sql-server-subnet'
        properties: {
          addressPrefix: '10.0.5.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// AZURE MONITOR - Log Analytics
module logAnalytics 'modules/log-analytics-workspace.bicep' = {
  name: 'loganalytics'
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: tags 
  }
}

// Application Insights
module appInsights 'modules/app-insights.bicep' = {
  name: 'appins'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsId: logAnalytics.outputs.id
  }
}

// Key Vault
module keyVault 'modules/key-vault.bicep' = {
  name: 'kv'
  params: {
    keyVaultName: keyVaultName 
    location: location
    tags: tags
  }
}

// Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'acr'
  params: {
    containerRegistryName: containerRegistryName
    location: location
    tags: tags
  }
}

// Service Bus
module serviceBus 'modules/service-bus.bicep' = {
  name: 'service-bus'
  params: {
    location: location
    queueName: queueName
    serviceBusName: serviceBusName
    tags: tags
  }
}

// Azure Cache for Redis
resource redisCache 'Microsoft.Cache/redis@2022-06-01' = {
  name: redisCacheName
  location: location
  tags: tags
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      capacity: 1
      family: 'P'
      name: 'Premium'
    }
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    replicasPerMaster: 2
    replicasPerPrimary: 2
  }
}

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdmin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled'
  }

  resource orderDatabase 'databases' = {
    name: ordersDatabaseName
    location: location
    tags: tags
    sku: {
      name: 'P1'
      tier: 'Premium'
    }
    properties: {
      zoneRedundant: true
    }
  }

  resource catalogDatabase 'databases' = {
    name: catalogDatabaseName
    location: location
    tags: tags
    sku: {
      name: 'P1'
      tier: 'Premium'
    }
    properties: {
      zoneRedundant: true
    }
  }
}

// Private DNS Zones
resource privateAcrDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkContainerRegistyDnsNames[environment().name]
  location: 'global'
  tags: tags

  resource privateAcrDnsZoneVnetLink 'virtualNetworkLinks' = {
    name: '${last(split(virtualNetwork.id, '/'))}-vnetlink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateServiceBusDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkServiceBusDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(virtualNetwork.id, '/'))}-vnetlink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateRedisDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateLinkRedisDnsNames[environment().name]
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(virtualNetwork.id, '/'))}-vnetlink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateSqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
  resource privateSitesDnsZoneVNetLink 'virtualNetworkLinks' = {
    name: '${last(split(virtualNetwork.id, '/'))}-vnetlink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

// PRIVATE ENDPOINTS

//  Each Private endpoint (PEP) is comprised of: 
//    1. Private endpoint resource, 
//    2. Private link service connection to the target resource, 
//    3. Private DNS zone group, linked to a VNet-linked private DNS Zone
resource containerRegistryPep 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${containerRegistry.name}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: containerRegistry.outputs.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateAcrDnsZone.id
          }
        }
      ]
    }
  }
}

resource serviceBusPepResource 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${serviceBus.name}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[2].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: serviceBus.outputs.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateServiceBusDnsZone.id
          }
        }
      ]
    }
  }
}

resource redisPep 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${redisCache.name}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[3].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateRedisDnsZone.id
          }
        }
      ]
    }
  }
}

resource sqlPepResource 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${sqlServer.name}-pep'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[4].id
    }
    privateLinkServiceConnections: [
      {
        name: 'peplink'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'dnszonegroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateSqlDnsZone.id
          }
        }
      ]
    }
  }
}

// Container Apps Environment
module env 'modules/container-app-env.bicep' = {
  name: 'env'
  params: {
    containerAppEnvName: containerAppEnvName
    infraSubnetId: virtualNetwork.properties.subnets[0].id
    lawCustomerId: logAnalytics.outputs.customerId
    lawSharedKey: logAnalytics.outputs.sharedKey
    location: location
    tags: tags
  }
}

// Container Apps
module frontendApp 'modules/container-app.bicep' = {
  name: 'front-end'
  params: {
    containerAppEnvId: env.outputs.id
    containerAppName: storeFrontend 
    containerImage: containerImage
    containerRegistryName: containerRegistry.outputs.containerRegistryName
    location: location
    tags: tags
    environmentVariables: shared_config
    isExternal: true
    cpuCore: cpuCore
    memorySize: memorySize
    minReplica: minReplica
    maxReplica: maxReplica
  }
}

module orderingApi 'modules/container-app.bicep' = {
  name: 'ordering'
  params: {
    containerAppEnvId: env.outputs.id
    containerAppName: orderingAppName
    containerImage: containerImage
    containerRegistryName: containerRegistry.outputs.containerRegistryName
    location: location
    tags: tags
    cpuCore: cpuCore
    memorySize: memorySize
    minReplica: minReplica
    maxReplica: maxReplica
  }
}

module catalogApi 'modules/container-app.bicep' = {
  name: 'catalog'
  params: {
    containerAppEnvId: env.outputs.id
    containerAppName: catalogAppName
    containerImage: containerImage
    containerRegistryName: containerRegistry.outputs.containerRegistryName
    location: location
    tags: tags
    cpuCore: cpuCore
    memorySize: memorySize
    minReplica: minReplica
    maxReplica: maxReplica
  }
}

module basketApi 'modules/container-app.bicep' = {
  name: 'basket'
  params: {
    containerAppEnvId: env.outputs.id
    containerAppName: basketAppName
    containerImage: containerImage
    containerRegistryName: containerRegistry.outputs.containerRegistryName
    location: location
    tags: tags
    cpuCore: cpuCore
    memorySize: memorySize
    minReplica: minReplica
    maxReplica: maxReplica
  }
}
