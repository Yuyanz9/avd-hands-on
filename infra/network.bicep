targetScope = 'resourceGroup'

var settings = loadJsonContent('./settings.json')

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: settings.network.vnetName
  location: settings.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        settings.network.addressPrefix
      ]
    }
    subnets: [for subnet in settings.network.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        defaultOutboundAccess: true
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
  }
}

output resourceGroupName string = resourceGroup().name
output vnetId string = virtualNetwork.id
output cloudPcSubnetId string = '${virtualNetwork.id}/subnets/${settings.network.subnets[0].name}'
output serverSubnetId string = '${virtualNetwork.id}/subnets/${settings.network.subnets[1].name}'
output avdSubnetId string = '${virtualNetwork.id}/subnets/${settings.network.subnets[2].name}'
