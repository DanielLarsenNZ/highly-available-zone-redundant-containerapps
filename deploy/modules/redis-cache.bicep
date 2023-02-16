@description('The name of the Redis Cache to deploy')
param redisCacheName string

@description('The location to deploy the cache to')
param location string

@description('The tags to apply to this Redis Cache')
param tags object = {}

@description('The Key Vault that will be used to store secrets from this Redis Cache')
param keyVaultName string

var redisConnectionStringSecretName = 'RedisConnectionString'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
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

output id string = redisCache.id
