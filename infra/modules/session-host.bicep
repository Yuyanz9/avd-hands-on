targetScope = 'resourceGroup'

@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@secure()
@minLength(1)
param registrationToken string

@minLength(36)
@maxLength(36)
param connectionUserObjectId string

param hostPoolName string
param networkResourceGroupName string
param virtualNetworkName string
param subnetName string
param location string
param imageSku string
param vmSize string
param vmDiskType string
@minLength(1)
@maxLength(13)
param vmNamePrefix string

var settings = loadJsonContent('../settings.json')
var vmName = '${vmNamePrefix}-0'
var vmUserLoginRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3ad86be52')

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(networkResourceGroupName)
}

resource sessionHostSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: subnetName
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
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
  location: location
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
        publisher: settings.avd.imagePublisher
        offer: settings.avd.imageOffer
        sku: imageSku
        version: settings.avd.imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: settings.avd.vmDiskSizeGB
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: vmDiskType
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
  location: location
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
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: settings.avd.configurationPackageUrl
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        aadJoin: true
        UseAgentDownloadEndpoint: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: registrationToken
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
  location: location
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

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    dailyRecurrence: {
      time: '2200'
    }
    notificationSettings: {
      emailRecipient: ''
      status: 'Disabled'
      timeInMinutes: 30
      webhookUrl: ''
    }
    status: 'Enabled'
    targetResourceId: virtualMachine.id
    taskType: 'ComputeVmShutdownTask'
    timeZoneId: 'Tokyo Standard Time'
  }
}

output sessionHostName string = virtualMachine.name
