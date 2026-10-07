targetScope = 'resourceGroup'

var settings = loadJsonContent('./settings.json')

resource outboundPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: settings.network.publicIpName
  location: settings.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: settings.network.natGatewayName
  location: settings.location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: settings.network.idleTimeoutInMinutes
    publicIpAddresses: [
      {
        id: outboundPublicIp.id
      }
    ]
  }
}

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
        defaultOutboundAccess: false
        natGateway: {
          id: natGateway.id
        }
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
