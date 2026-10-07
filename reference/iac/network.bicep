targetScope = 'resourceGroup'

@description('Participant-specific prefix. Use 3-8 lowercase letters or digits, starting with a letter.')
@minLength(3)
@maxLength(8)
param namePrefix string

@description('Azure region for the training resources.')
param location string = resourceGroup().location

param vnetAddressPrefix string = '10.42.0.0/16'
param sessionHostSubnetAddressPrefix string = '10.42.1.0/24'
param targetSubnetAddressPrefix string = '10.42.2.0/24'

var tags = {
  training: 'avd-hands-on'
  participant: namePrefix
}

resource outboundPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${namePrefix}-egress-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: '${namePrefix}-nat'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: outboundPublicIp.id
      }
    ]
  }
}

resource sessionHostNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${namePrefix}-sessionhosts-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource targetNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${namePrefix}-targets-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromSessionHosts'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: sessionHostSubnetAddressPrefix
          destinationAddressPrefix: targetSubnetAddressPrefix
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${namePrefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-sessionhosts'
        properties: {
          addressPrefix: sessionHostSubnetAddressPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: sessionHostNsg.id
          }
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: 'snet-targets'
        properties: {
          addressPrefix: targetSubnetAddressPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: targetNsg.id
          }
          natGateway: {
            id: natGateway.id
          }
        }
      }
    ]
  }
}

output vnetName string = virtualNetwork.name
output vnetId string = virtualNetwork.id
output sessionHostSubnetId string = '${virtualNetwork.id}/subnets/snet-sessionhosts'
output targetSubnetId string = '${virtualNetwork.id}/subnets/snet-targets'
output natGatewayId string = natGateway.id
