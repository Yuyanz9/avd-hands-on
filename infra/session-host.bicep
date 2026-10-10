targetScope = 'resourceGroup'

@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@secure()
@description('Active registration token created for the existing host pool.')
@minLength(1)
param registrationToken string

@description('Existing Standard-management AVD host pool name. The token must belong to this pool.')
@minLength(3)
@maxLength(64)
param hostPoolName string = 'DefaultHostPool'

@description('Resource group containing the existing VNet. Defaults to the selected deployment resource group.')
param networkResourceGroupName string = resourceGroup().name

@description('Name of the existing virtual network.')
@minLength(2)
@maxLength(64)
param virtualNetworkName string = 'vnet-vdi'

@description('Name of the existing subnet used for AVD session hosts.')
@minLength(1)
@maxLength(80)
param subnetName string = 'snet-avd'

@description('Location for the session host. It must match the existing VNet location.')
param location string = 'japaneast'

@description('Windows image SKU. The publisher, offer, and version remain the current training defaults.')
param imageSku string = 'win11-25h2-avd'

@description('Size of the session host VM. Keep it compatible with the existing host pool.')
param vmSize string = 'Standard_D4as_v6'

@description('OS disk storage account type supported by the selected VM size and region.')
param vmDiskType string = 'StandardSSD_LRS'

@description('Prefix for the Windows computer and Azure VM name. The template appends -0; maximum prefix length is 13.')
@minLength(1)
@maxLength(13)
param vmNamePrefix string = dateTimeAdd(utcNow(), 'PT9H', 'AVDMMddHHmm')

module sessionHost './modules/session-host.bicep' = {
  name: 'add-avd-session-host'
  params: {
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
    registrationToken: registrationToken
    connectionUserObjectId: deployer().objectId
    hostPoolName: hostPoolName
    networkResourceGroupName: networkResourceGroupName
    virtualNetworkName: virtualNetworkName
    subnetName: subnetName
    location: location
    imageSku: imageSku
    vmSize: vmSize
    vmDiskType: vmDiskType
    vmNamePrefix: vmNamePrefix
  }
}

output sessionHostName string = sessionHost.outputs.sessionHostName
