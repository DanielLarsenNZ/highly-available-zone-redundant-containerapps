@description('The name for this container registry')
param containerRegistryName string

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

output loginServer string = containerRegistry.properties.loginServer
output username string = containerRegistry.listCredentials().username
output id string = containerRegistry.id
output containerRegistryName string = containerRegistry.name
