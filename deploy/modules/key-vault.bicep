@description('The name of the application')
param applicationName string = uniqueString(resourceGroup().id)

@description('The name of the key vault that will be deployed')
param keyVaultName string = 'kv-${applicationName}'

@description('The location to deploy the Key Vault to')
param location string

@description('The tags to apply to this Key Vault resource')
param tags object = {}

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
    accessPolicies: []
  }
}

output id string = keyVault.id
output name string = keyVault.name
