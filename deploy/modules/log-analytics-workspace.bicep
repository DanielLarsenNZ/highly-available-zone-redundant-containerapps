@description('The name of the log analytics workspace that will be deployed')
param logAnalyticsWorkspaceName string

@description('The location to deploy our resources to. Must be a region that supports availability zones')
param location string

@description('The tags to apply to this Log Analytics workspace')
param tags object = {}

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

output id string = logAnalytics.id
output customerId string = logAnalytics.properties.customerId
output sharedKey string = logAnalytics.listKeys().primarySharedKey
