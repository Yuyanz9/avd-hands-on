targetScope = 'resourceGroup'

@description('Local VM administrator password. Do not use or store the tenant account password.')
@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

module avd './modules/avd.bicep' = {
  name: 'avd-fixed-configuration'
  params: {
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
    connectionUserObjectId: deployer().objectId
  }
}

output hostpoolName string = avd.outputs.hostpoolName
output workspaceName string = avd.outputs.workspaceName
output sessionHostName string = avd.outputs.sessionHostName
