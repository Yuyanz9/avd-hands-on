targetScope = 'resourceGroup'

@description('Participant-specific prefix. Must match the network deployment.')
@minLength(3)
@maxLength(8)
param namePrefix string

@description('Azure region supporting AVD metadata and the chosen VM SKU.')
param location string = resourceGroup().location

param vnetName string = '${namePrefix}-vnet'
param sessionHostSubnetName string = 'snet-sessionhosts'

@description('Object ID, not application ID or UPN, of the user or group receiving desktop access.')
@minLength(36)
@maxLength(36)
param avdUserObjectId string

@allowed([
  'User'
  'Group'
])
param accessPrincipalType string = 'User'

@description('Local recovery administrator. Not the account used to sign in to the AVD desktop.')
@minLength(1)
@maxLength(20)
param vmAdminUsername string = 'avdlocaladmin'

@secure()
@minLength(12)
@maxLength(123)
param vmAdminPassword string

@minValue(1)
@maxValue(10)
param vmCount int = 1

param vmSize string = 'Standard_D2s_v5'
param imageSku string = 'win11-24h2-avd'

@description('Pin a tested image version before the training. Latest is only the initial preparation default.')
param imageVersion string = 'latest'

@description('Enable only after the tenant-side Windows Cloud Login configuration is complete.')
param enableSso bool = false

@description('Short-lived host registration token expiration, refreshed when this template is deployed.')
param registrationExpiration string = dateTimeAdd(utcNow(), 'PT8H')

@description('Versioned Microsoft AVD configuration package. Verify availability before the training.')
param configurationPackageUrl string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02774.414.zip'

var tags = {
  training: 'avd-hands-on'
  participant: namePrefix
}
var sessionHostNames = [for index in range(0, vmCount): '${namePrefix}-sh${padLeft(string(index + 1), 2, '0')}']
var desktopUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
var vmUserLoginRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3ad86be52')
var authenticationProperties = enableSso ? 'enablerdsaadauth:i:1;' : 'targetisaadjoined:i:1;enablecredsspsupport:i:1;'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource sessionHostSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: sessionHostSubnetName
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' = {
  name: '${namePrefix}-hp'
  location: location
  tags: tags
  properties: {
    friendlyName: '${namePrefix} training desktop'
    description: 'Microsoft Entra joined AVD training host pool'
    hostPoolType: 'Pooled'
    managementType: 'Standard'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: 1
    preferredAppGroupType: 'Desktop'
    validationEnvironment: false
    startVMOnConnect: false
    publicNetworkAccess: 'Enabled'
    customRdpProperty: '${authenticationProperties}redirectclipboard:i:1;audiomode:i:0;'
    registrationInfo: {
      expirationTime: registrationExpiration
      registrationTokenOperation: 'Update'
    }
  }
}

resource desktopApplicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2025-10-10' = {
  name: '${namePrefix}-dag'
  location: location
  tags: tags
  properties: {
    applicationGroupType: 'Desktop'
    friendlyName: '${namePrefix} desktop'
    hostPoolArmPath: hostPool.id
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-10-10' = {
  name: '${namePrefix}-ws'
  location: location
  tags: tags
  properties: {
    friendlyName: '${namePrefix} training workspace'
    publicNetworkAccess: 'Enabled'
    applicationGroupReferences: [
      desktopApplicationGroup.id
    ]
  }
}

resource desktopAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(desktopApplicationGroup.id, avdUserObjectId, desktopUserRoleId)
  scope: desktopApplicationGroup
  properties: {
    principalId: avdUserObjectId
    principalType: accessPrincipalType
    roleDefinitionId: desktopUserRoleId
  }
}

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2024-05-01' = [for vmName in sessionHostNames: {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: sessionHostSubnet.id
          }
        }
      }
    ]
  }
}]

resource virtualMachines 'Microsoft.Compute/virtualMachines@2024-11-01' = [for (vmName, index) in sessionHostNames: {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows-11'
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces[index].id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource vmLoginAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (vmName, index) in sessionHostNames: {
  name: guid(virtualMachines[index].id, avdUserObjectId, vmUserLoginRoleId)
  scope: virtualMachines[index]
  properties: {
    principalId: avdUserObjectId
    principalType: accessPrincipalType
    roleDefinitionId: vmUserLoginRoleId
  }
}]

resource entraIdJoin 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = [for (vmName, index) in sessionHostNames: {
  parent: virtualMachines[index]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}]

resource avdRegistration 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = [for (vmName, index) in sessionHostNames: {
  parent: virtualMachines[index]
  name: 'MicrosoftPowershellDSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: configurationPackageUrl
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        aadJoin: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPool.listRegistrationTokens().value[0].token
      }
    }
  }
  dependsOn: [
    entraIdJoin[index]
  ]
}]

output hostPoolName string = hostPool.name
output desktopApplicationGroupName string = desktopApplicationGroup.name
output workspaceName string = workspace.name
output sessionHostNames array = sessionHostNames
