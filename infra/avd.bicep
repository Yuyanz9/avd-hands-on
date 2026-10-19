targetScope = 'resourceGroup'

@description('Local VM administrator password. Do not use or store the tenant account password.')
@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@metadata({ displayName: 'Network Resource Group Name' })
@description('Existing VNet resource group, not the new VM resource group. Leave the default only when both are the same; otherwise enter the VNet resource group name.')
param networkResourceGroupName string = resourceGroup().name

@description('Name of the existing virtual network.')
@minLength(2)
@maxLength(64)
param virtualNetworkName string = 'vnet-vdi'

@description('Name of the existing subnet used for AVD session hosts.')
@minLength(1)
@maxLength(80)
param subnetName string = 'snet-avd'

@description('Location for the AVD resources. It must match the existing VNet location.')
param location string = 'japaneast'

@metadata({ displayName: 'Vm Gallery Image SKU' })
@description('Windows 11 multi-session image. M365 SKUs include Microsoft 365 Apps but do not grant an Apps license. The offer is selected automatically.')
@allowed([
  'win11-23h2-avd'
  'win11-23h2-avd-m365'
  'win11-24h2-avd'
  'win11-24h2-avd-m365'
  'win11-25h2-avd'
  'win11-25h2-avd-m365'
  'win11-26h2-avd'
  'win11-26h2-avd-m365'
])
param imageSku string = 'win11-25h2-avd-m365'

@description('Workspace display name shown in Windows App.')
@minLength(1)
@maxLength(64)
param workspaceFriendlyName string = 'AVD Session Host'

@description('Size of the session host VM.')
param vmSize string = 'Standard_D4as_v6'

@description('OS disk storage account type supported by the selected VM size and region.')
param vmDiskType string = 'StandardSSD_LRS'

@description('Maximum number of user sessions allowed on each session host.')
@minValue(1)
param maxSessionLimit int = 5

@description('Prefix for the Windows computer and Azure VM names. Appends -0 through -9; maximum prefix length is 13. Use a new prefix for subsequent host additions.')
@minLength(1)
@maxLength(13)
param vmNamePrefix string = dateTimeAdd(utcNow(), 'PT9H', 'AVDMMddHHmm')

@metadata({ displayName: 'Custom Configuration Script Url' })
@description('Approved PowerShell script URL. Default runs Japanese configuration; clear this field to skip custom configuration and keep the image language.')
param customConfigurationScriptUrl string = 'https://raw.githubusercontent.com/Yuyanz9/avd-hands-on/7b0923fcc78335ac25bafc418d9d3ab4538292d8/scripts/JPNOFLNG.ps1'

@metadata({ displayName: 'Vm Number Of Instances' })
@description('Number of session hosts to create (1-10). More VMs increase cost and require sufficient quota and subnet capacity.')
@minValue(1)
@maxValue(10)
param vmNumberOfInstances int = 1

@metadata({ displayName: 'Hostpool Type' })
@description('New host pool type. Cannot be changed for an existing pool. Personal uses automatic assignment and Persistent balancing.')
@allowed([
  'Pooled'
  'Personal'
])
param hostpoolType string = 'Pooled'

@metadata({ displayName: 'Load Balancer Type' })
@description('Pooled load balancing algorithm. Personal pools always use Persistent instead of this pooled setting.')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancerType string = 'BreadthFirst'

@metadata({ displayName: 'Intune Enrollment' })
@description('Request Microsoft Intune enrollment for new Microsoft Entra joined session hosts. Requires tenant MDM auto-enrollment and appropriate licensing; use false for Personal host pools.')
param intune bool = true

@metadata({ displayName: 'Enable Automatic Shutdown' })
@description('Enable the daily VM shutdown schedule. Setting this to false disables an existing schedule when redeploying.')
param autoShutdownEnabled bool = true

@metadata({ displayName: 'Shutdown Hour (Japan Time)' })
@description('Hour of the daily VM shutdown in Japan time (0-23).')
@minValue(0)
@maxValue(23)
param autoShutdownHour int = 19

@metadata({ displayName: 'Shutdown Minute' })
@description('Minute of the daily VM shutdown (0-59).')
@minValue(0)
@maxValue(59)
param autoShutdownMinute int = 0

module avd './modules/avd.bicep' = {
  name: 'avd-editable-configuration'
  params: {
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
    connectionUserObjectId: deployer().objectId
    networkResourceGroupName: networkResourceGroupName
    virtualNetworkName: virtualNetworkName
    subnetName: subnetName
    location: location
    imageSku: imageSku
    workspaceFriendlyName: workspaceFriendlyName
    vmSize: vmSize
    vmDiskType: vmDiskType
    maxSessionLimit: maxSessionLimit
    vmNamePrefix: vmNamePrefix
    customConfigurationScriptUrl: customConfigurationScriptUrl
    vmNumberOfInstances: vmNumberOfInstances
    hostpoolType: hostpoolType
    loadBalancerType: loadBalancerType
    intune: intune
    autoShutdownEnabled: autoShutdownEnabled
    autoShutdownHour: autoShutdownHour
    autoShutdownMinute: autoShutdownMinute
  }
}

output hostpoolName string = avd.outputs.hostpoolName
output workspaceName string = avd.outputs.workspaceName
output sessionHostName string = avd.outputs.sessionHostName
output sessionHostNames array = avd.outputs.sessionHostNames
