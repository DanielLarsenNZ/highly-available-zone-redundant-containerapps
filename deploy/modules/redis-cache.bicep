@description('The name of the Redis Cache to deploy')
param redisCacheName string

@description('The location to deploy the cache to')
param location string

@description('The tags to apply to this Redis Cache')
param tags object = {}

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

output id string = redisCache.id
