@description('The name for this container registry')
param containerRegistryName string = 'acr${applicationName}'

@description('The name of the application')
param applicationName string = uniqueString(resourceGroup().id)

@description('The location to deploy this container registry to')
param location string

@description('The tags to apply to this containe registry')
param tags object = {}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
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

output containerRegistryName string = containerRegistry.name
