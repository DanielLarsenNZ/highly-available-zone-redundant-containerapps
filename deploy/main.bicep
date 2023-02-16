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
]

var acrPasswordSecretName = 'AcrPasswordSecret'

var roleDefinitionIds = {
  keyvault: '4633458b-17de-408a-b874-0445c86b69e6'                  // Key Vault Secrets User
}

var privateLinkContainerRegistyDnsNames = {
  AzureCloud: 'privatelink.azurecr.io'
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
