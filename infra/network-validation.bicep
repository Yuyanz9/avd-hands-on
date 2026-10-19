targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
@metadata({ displayName: 'Location' })
param location string = 'japaneast'

@description('Name of the virtual network.')
@metadata({ displayName: 'Virtual Network Name' })
@minLength(2)
@maxLength(64)
param vnetName string = 'vnet-vdi'

@description('Virtual network CIDR. Keep all subnet prefixes inside this address space.')
@metadata({ displayName: 'Virtual Network Address Prefix' })
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Cloud PC subnet CIDR. Subnet prefixes must not overlap.')
@metadata({ displayName: 'Cloud PC Subnet Address Prefix' })
param cloudPcSubnetPrefix string = '10.10.1.0/24'

@description('AVD subnet CIDR. Subnet prefixes must not overlap.')
@metadata({ displayName: 'AVD Subnet Address Prefix' })
param avdSubnetPrefix string = '10.10.2.0/24'

module network './modules/network-core.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    cloudPcSubnetPrefix: cloudPcSubnetPrefix
    avdSubnetPrefix: avdSubnetPrefix
    natGatewayName: 'nat-vdi'
    publicIpName: 'pip-vdi'
    useNatGateway: false
  }
}

output resourceGroupName string = network.outputs.resourceGroupName
output vnetId string = network.outputs.vnetId
output cloudPcSubnetId string = network.outputs.cloudPcSubnetId
output avdSubnetId string = network.outputs.avdSubnetId
