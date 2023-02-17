@description('The name of the App Insights workspace that will be deployed')
param applicationInsightsName string

@description('The location to deploy this App Insights to')
param location string

@description('The workspace resource ID that this App Insights workspace will connect to')
param logAnalyticsId string

@description('The tags to apply to this App Insights resource')
param tags object = {}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsId
  }
}

output name string = appInsights.name
output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
