@description('The name of the Container App Environment that will be deployed')
param containerAppEnvName string

@description('The location to deploy the Container App environment to')
param location string

@description('The Log Analytics Customer Id that this Environment will use')
param lawCustomerId string

@description('The Log Analytics Shared Key that this Environment will use')
@secure()
param lawSharedKey string

@description('The Subnet Id that this Container Environment will integrate with')
param infraSubnetId string

@description('The tags to apply to this resource')
param tags object = {}

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
        customerId: lawCustomerId
        sharedKey: lawSharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: infraSubnetId
    }
    zoneRedundant: true
  }
}

output id string = env.id
