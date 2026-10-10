targetScope = 'resourceGroup'

@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@minLength(36)
@maxLength(36)
param connectionUserObjectId string

param networkResourceGroupName string
param virtualNetworkName string
param subnetName string
param location string
param imageSku string
param workspaceFriendlyName string
param vmSize string
param vmDiskType string
param maxSessionLimit int
param vmNamePrefix string

param tokenExpirationTime string = dateTimeAdd(utcNow(), 'PT2H')

var settings = loadJsonContent('../settings.json')
var desktopUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(networkResourceGroupName)
}

resource sessionHostSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: subnetName
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' = {
  name: settings.avd.hostpoolName
  location: location
  properties: {
    hostPoolType: 'Pooled'
    managementType: 'Standard'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: maxSessionLimit
    preferredAppGroupType: 'Desktop'
    validationEnvironment: false
    startVMOnConnect: false
    publicNetworkAccess: 'Enabled'
    customRdpProperty: 'enablerdsaadauth:i:1;redirectclipboard:i:1;audiomode:i:0;'
    registrationInfo: {
      expirationTime: tokenExpirationTime
      registrationTokenOperation: 'Update'
    }
  }
}

resource desktopApplicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2025-10-10' = {
  name: '${settings.avd.hostpoolName}-DAG'
  location: location
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-10-10' = {
  name: settings.avd.workspaceName
  location: location
  properties: {
    friendlyName: workspaceFriendlyName
    publicNetworkAccess: 'Enabled'
    applicationGroupReferences: [
      desktopApplicationGroup.id
    ]
  }
}

resource desktopAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(desktopApplicationGroup.id, connectionUserObjectId, desktopUserRoleId)
  scope: desktopApplicationGroup
  properties: {
    principalId: connectionUserObjectId
    principalType: 'User'
    roleDefinitionId: desktopUserRoleId
  }
}

module sessionHost './session-host.bicep' = {
  name: 'avd-session-host'
  params: {
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
    registrationToken: hostPool.listRegistrationTokens().value[0].token
    connectionUserObjectId: connectionUserObjectId
    hostPoolName: hostPool.name
    networkResourceGroupName: networkResourceGroupName
    virtualNetworkName: virtualNetwork.name
    subnetName: sessionHostSubnet.name
    location: location
    imageSku: imageSku
    vmSize: vmSize
    vmDiskType: vmDiskType
    vmNamePrefix: vmNamePrefix
  }
}

output hostpoolName string = hostPool.name
output workspaceName string = workspace.name
output sessionHostName string = sessionHost.outputs.sessionHostName
