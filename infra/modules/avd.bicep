targetScope = 'resourceGroup'

@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@minLength(36)
@maxLength(36)
param connectionUserObjectId string

param tokenExpirationTime string = dateTimeAdd(utcNow(), 'PT2H')

var settings = loadJsonContent('../settings.json')
var vmName = '${settings.avd.vmNamePrefix}-0'
var desktopUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
var vmUserLoginRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3ad86be52')

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: settings.network.vnetName
}

resource sessionHostSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: settings.network.subnets[2].name
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' = {
  name: settings.avd.hostpoolName
  location: settings.location
  properties: {
    hostPoolType: 'Pooled'
    managementType: 'Standard'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: settings.avd.maxSessionLimit
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
  location: settings.location
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-10-10' = {
  name: settings.avd.workspaceName
  location: settings.location
  properties: {
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

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: settings.location
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
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: settings.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: settings.avd.vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: settings.avd.imagePublisher
        offer: settings.avd.imageOffer
        sku: settings.avd.imageSku
        version: settings.avd.imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: settings.avd.vmDiskSizeGB
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: settings.avd.vmDiskType
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: settings.avd.vmAdminUsername
      adminPassword: vmAdministratorAccountPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
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
}

resource vmLoginAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualMachine.id, connectionUserObjectId, vmUserLoginRoleId)
  scope: virtualMachine
  properties: {
    principalId: connectionUserObjectId
    principalType: 'User'
    roleDefinitionId: vmUserLoginRoleId
  }
}

resource entraIdJoin 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: settings.location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
  }
}

resource avdRegistration 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: virtualMachine
  name: 'MicrosoftPowershellDSC'
  location: settings.location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: settings.avd.configurationPackageUrl
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        aadJoin: true
        UseAgentDownloadEndpoint: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPool.listRegistrationTokens().value[0].token
      }
    }
  }
  dependsOn: [
    entraIdJoin
  ]
}

resource customConfiguration 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: virtualMachine
  name: 'Microsoft.Compute.CustomScriptExtension'
  location: settings.location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        settings.avd.customConfigurationScriptUrl
      ]
      commandToExecute: 'powershell -ExecutionPolicy Bypass -File JPNOFLNG.ps1'
    }
  }
  dependsOn: [
    avdRegistration
  ]
}

output hostpoolName string = hostPool.name
output workspaceName string = workspace.name
output sessionHostName string = virtualMachine.name
