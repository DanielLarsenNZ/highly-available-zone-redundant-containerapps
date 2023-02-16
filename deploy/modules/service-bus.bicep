@description('The name of the Service Bus namespace that will be deployed')
param serviceBusName string

@description('The location to deploy our resources to. Must be a region that supports availability zones')
param location string

@description('The tags to apply to this Service Bus Namespace')
param tags object = {}

@description('The name of the queue to deploy to this Service Bus Namespace')
param queueName string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
    capacity: 1
    tier: 'Premium'
  }
  properties: {
    zoneRedundant: true
  }

  resource ordersQueue 'queues' = {
    name: queueName
  }
}

output id string = serviceBus.id
output endpoint string = serviceBus.properties.serviceBusEndpoint
