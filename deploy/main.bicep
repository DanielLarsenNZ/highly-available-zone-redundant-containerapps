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

var containerAppSubnetName = 'infrastructure-subnet'
var containerAppName = 'frontend'
var shared_config = [
  {
    name: 'APPINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'AZURE_SERVICE_BUS_FQ_NAMESPACE'
    value: replace(replace(serviceBus.properties.serviceBusEndpoint, 'https://', ''), ':433/', '')
  }
  {
    name: 'AZURE_SERVICE_BUS_QUEUE_NAME'
    value: queueName
  }
]

var queueName = 'orders'

var acrPasswordSecretName = 'AcrPasswordSecret'
var redisConnectionStringSecretName = 'RedisConnectionString'

var roleDefinitionIds = {
  keyvault: '4633458b-17de-408a-b874-0445c86b69e6'                  // Key Vault Secrets User
  servicebus: '090c5cfd-751d-490a-894a-3ce6f1109419'                // Azure Service Bus Data Owner
}

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
      {
        name: containerAppSubnetName
        properties: {
          addressPrefix: '10.0.0.0/23'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'containerregistry-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'servicebus-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'redis-subnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enabledForTemplateDeployment: true
    accessPolicies: [
      {
        objectId: frontEndContainerApp.identity.principalId
        tenantId: frontEndContainerApp.identity.tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    zoneRedundancy: 'Enabled'
    adminUserEnabled: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

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
          privateLinkServiceId: containerRegistry.id
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

resource containerRegistryPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: acrPasswordSecretName
  parent: keyVault
  properties: {
    value: containerRegistry.listCredentials().passwords[0].value
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
    capacity: 1
    tier: 'Premium'
  }
  properties: {
    zoneRedundant: true
  }

  resource ordersQueue 'queues' = {
    name: queueName
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
          privateLinkServiceId: serviceBus.id
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

resource redisSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: redisConnectionStringSecretName
  parent: keyVault
  properties: {
    value: '${redisCache.properties.hostName}:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
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

resource env 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  sku: {
    name: 'Consumption'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: virtualNetwork.properties.subnets[0].id
    }
    zoneRedundant: true
  }
}

resource frontEndContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
   managedEnvironmentId: env.id
   configuration: {
    activeRevisionsMode: 'Multiple'
    ingress: {
      external: true
      transport: 'auto'
      targetPort: 80
      allowInsecure: false
      traffic: [
        {
          latestRevision: true
          weight: 100
        }
      ]
    }
    secrets: [
      {
        name: 'container-registry-password'
        value: containerRegistry.listCredentials().passwords[0].value
      }
    ]
    registries: [
      {
        server: containerRegistry.properties.loginServer
        username: containerRegistry.listCredentials().username
        passwordSecretRef: 'container-registry-password'
      }
    ]
   }
   template: {
    containers: [
      {
        name: containerAppName
        image: containerImage
        env: shared_config
        resources: {
          cpu: json(cpuCore)
          memory: '${memorySize}Gi'
        }
      }
    ]
    scale: {
      minReplicas: minReplica
      maxReplicas: maxReplica
      rules: [
        {
          name: 'http-rule'
          http: {
            metadata: {
              concurrentRequests: '100'
            }
          }
        }
      ]
    }
   } 
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource keyVaultReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, frontEndContainerApp.id, roleDefinitionIds.keyvault)
  properties: {
    principalId: frontEndContainerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.keyvault)
    principalType: 'ServicePrincipal'
  }
}

resource serviceBusDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.id, frontEndContainerApp.id, roleDefinitionIds.servicebus)
  properties: {
    principalId: frontEndContainerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.servicebus)
    principalType: 'ServicePrincipal'
  }
}
