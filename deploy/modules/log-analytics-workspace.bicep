@description('The name of the log analytics workspace that will be deployed')
param logAnalyticsWorkspaceName string

@description('The location to deploy our resources to. Must be a region that supports availability zones')
param location string

@description('The tags to apply to this Log Analytics workspace')
param tags object = {}

@description('The Key Vault that will be used to store secrets from this SQL Server')
param keyVaultName string

var logAnalyticsSharedKeySecretName = 'LogAnalyticsSharedKey'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
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

resource sharedKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: logAnalyticsSharedKeySecretName
  parent: keyVault
  properties: {
    value: logAnalytics.listKeys().primarySharedKey
  }
}

output id string = logAnalytics.id
output customerId string = logAnalytics.properties.customerId
