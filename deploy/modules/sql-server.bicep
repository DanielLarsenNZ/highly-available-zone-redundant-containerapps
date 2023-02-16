@description('The name of the SQL Server that will be deployed')
param sqlServerName string

@description('The location to deploy our resources to. Must be a region that supports availability zones')
param location string

@description('Optional. An Azure tags object for tagging parent resources that support tags.')
param tags object

@description('Optional. SQL admin username. Defaults to \'\${applicationName}-admin\'')
param sqlAdmin string

@description('Optional. A password for the Azure SQL server admin user. Defaults to a new GUID.')
@secure()
param sqlAdminPassword string

@description('The name of the SQL database to create')
param ordersDatabaseName string

@description('The name of the Catalog Database to create in SQL Server')
param catalogDatabaseName string

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdmin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled'
  }

  resource orderDatabase 'databases' = {
    name: ordersDatabaseName
    location: location
    tags: tags
    sku: {
      name: 'P1'
      tier: 'Premium'
    }
    properties: {
      zoneRedundant: true
    }
  }

  resource catalogDatabase 'databases' = {
    name: catalogDatabaseName
    location: location
    tags: tags
    sku: {
      name: 'P1'
      tier: 'Premium'
    }
    properties: {
      zoneRedundant: true
    }
  }
}

output id string = sqlServer.id
