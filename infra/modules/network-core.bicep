targetScope = 'resourceGroup'

param location string
param vnetName string
param vnetAddressPrefix string
param cloudPcSubnetPrefix string
param serverSubnetPrefix string
param avdSubnetPrefix string
param natGatewayName string
param publicIpName string
param useNatGateway bool

var subnets = [
  {
    name: 'snet-cloudpc'
    addressPrefix: cloudPcSubnetPrefix
  }
  {
    name: 'snet-server'
    addressPrefix: serverSubnetPrefix
  }
  {
    name: 'snet-avd'
    addressPrefix: avdSubnetPrefix
  }
]

resource outboundPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (useNatGateway) {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = if (useNatGateway) {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: outboundPublicIp.id
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: union({
        addressPrefix: subnet.addressPrefix
        defaultOutboundAccess: !useNatGateway
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }, useNatGateway ? {
        natGateway: {
          id: natGateway.id
        }
      } : {})
    }]
  }
}

output resourceGroupName string = resourceGroup().name
output vnetId string = virtualNetwork.id
output cloudPcSubnetId string = '${virtualNetwork.id}/subnets/snet-cloudpc'
output serverSubnetId string = '${virtualNetwork.id}/subnets/snet-server'
output avdSubnetId string = '${virtualNetwork.id}/subnets/snet-avd'
