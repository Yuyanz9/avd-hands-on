#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'scripts\AzureCli.ps1')
$assertions = 0

function Assert-Template {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:assertions++
}

function Find-Resources {
    param([hashtable]$Template, [string]$Type)
    return ,@($Template.resources | Where-Object { $_.type -eq $Type })
}

function Read-Json {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
}

function Convert-CompactJson {
    param($Value)
    ConvertTo-Json -InputObject $Value -Depth 100 -Compress
}

function Get-FixedSettings {
    param([hashtable]$Template)
    $value = $Template.variables.settings
    $visited = @{}
    while ($value -is [string]) {
        Assert-Template ($value -match "^\[variables\('([^']+)'\)\]$") 'Fixed settings must be literal or a constant variable reference.'
        $name = $Matches[1]
        Assert-Template ($Template.variables.ContainsKey($name) -and -not $visited.ContainsKey($name)) 'Fixed settings must not contain a missing or cyclic reference.'
        $visited[$name] = $true
        $value = $Template.variables[$name]
    }
    Assert-Template ($value -is [hashtable]) 'Fixed settings must resolve to an object.'
    return $value
}

$settings = Read-Json (Join-Path $root 'infra\settings.json')
$expected = @{
    resourceGroupName = 'rg-vdi'
    location = 'japaneast'
    'network.vnetName' = 'vnet-vdi'
    'network.addressPrefix' = '10.10.0.0/16'
    'network.natGatewayName' = 'nat-vdi'
    'network.publicIpName' = 'pip-vdi'
    'network.idleTimeoutInMinutes' = 4
    'avd.hostpoolName' = 'DefaultHostPool'
    'avd.workspaceName' = 'AVD Session Host'
    'avd.vmNamePrefix' = 'avd'
    'avd.vmAdminUsername' = 'vmadmin'
    'avd.vmSize' = 'Standard_D4as_v6'
    'avd.vmDiskType' = 'StandardSSD_LRS'
    'avd.vmDiskSizeGB' = 128
    'avd.imagePublisher' = 'microsoftwindowsdesktop'
    'avd.imageOffer' = 'office-365'
    'avd.imageSku' = 'win11-25h2-avd-m365'
    'avd.imageVersion' = 'latest'
    'avd.maxSessionLimit' = 5
    'avd.customConfigurationScriptUrl' = 'https://nogujapanese.blob.core.windows.net/avd-deploy/JPNOFLNG.ps1'
    'avd.configurationPackageUrl' = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.03537.1471.zip'
}
foreach ($path in $expected.Keys) {
    $value = $settings
    foreach ($segment in ($path -split '\.')) { $value = $value[$segment] }
    Assert-Template ($value -ceq $expected[$path]) "Unexpected fixed setting: $path."
}
Assert-Template ($settings.network.subnets.Count -eq 3) 'Expected exactly three article subnets.'
$subnetNames = @('snet-cloudpc', 'snet-server', 'snet-avd')
$subnetPrefixes = @('10.10.1.0/24', '10.10.2.0/24', '10.10.3.0/24')
for ($index = 0; $index -lt 3; $index++) {
    Assert-Template ($settings.network.subnets[$index].name -ceq $subnetNames[$index]) 'Unexpected subnet name or order.'
    Assert-Template ($settings.network.subnets[$index].addressPrefix -ceq $subnetPrefixes[$index]) 'Unexpected subnet address prefix.'
}

$templates = @{}
foreach ($phase in @('network', 'avd')) {
    $stored = Read-Json (Join-Path $root "templates\$phase.json")
    $compiled = Invoke-TrainingAzureCli -Arguments @(
        'bicep', 'build', '--file', (Join-Path $root "infra\$phase.bicep"),
        '--stdout', '--only-show-errors'
    )
    $fresh = ($compiled -join [Environment]::NewLine) | ConvertFrom-Json -AsHashtable -Depth 100
    Assert-Template ((Convert-CompactJson $stored) -ceq (Convert-CompactJson $fresh)) "Stale generated $phase.json. Run Build-Templates.ps1 with the current compiler."
    Assert-Template ($stored['$schema'] -match '/deploymentTemplate.json#$') "$phase must use resource-group deployment scope."
    Assert-Template ((Find-Resources $stored 'Microsoft.Resources/resourceGroups').Count -eq 0) 'Resource groups must be created manually.'
    Assert-Template (($stored.outputs | ConvertTo-Json -Depth 100) -notmatch 'password|registrationInfoToken|listRegistrationTokens') 'Outputs must not expose secrets.'
    $templates[$phase] = $stored
}

$network = $templates.network
Assert-Template (-not $network.ContainsKey('parameters') -or $network.parameters.Count -eq 0) 'Network must have no attendee parameters.'
Assert-Template ((Convert-CompactJson (Get-FixedSettings $network)) -ceq (Convert-CompactJson $settings)) 'Network fixed settings must match the source.'
Assert-Template ($network.resources.Count -eq 3) 'Network must create only VNet, NAT and public IP.'
$vnets = Find-Resources $network 'Microsoft.Network/virtualNetworks'
$nats = Find-Resources $network 'Microsoft.Network/natGateways'
$publicIps = Find-Resources $network 'Microsoft.Network/publicIPAddresses'
Assert-Template ($vnets.Count -eq 1 -and $nats.Count -eq 1 -and $publicIps.Count -eq 1) 'Expected one VNet, NAT Gateway and outbound public IP.'
Assert-Template ($vnets[0].name -ceq "[variables('settings').network.vnetName]") 'VNet name must use fixed settings.'
Assert-Template ($vnets[0].properties.addressSpace.addressPrefixes[0] -ceq "[variables('settings').network.addressPrefix]") 'VNet address space must use fixed settings.'
$subnetCopy = @($vnets[0].properties.copy | Where-Object { $_.name -eq 'subnets' })
Assert-Template ($subnetCopy.Count -eq 1 -and $subnetCopy[0].count -ceq "[length(variables('settings').network.subnets)]") 'All three fixed subnets must be deployed.'
$subnet = $subnetCopy[0].input
Assert-Template ($subnet.name -ceq "[variables('settings').network.subnets[copyIndex('subnets')].name]") 'Subnet names must use the fixed array.'
Assert-Template ($subnet.properties.addressPrefix -ceq "[variables('settings').network.subnets[copyIndex('subnets')].addressPrefix]") 'Subnet prefixes must use the fixed array.'
Assert-Template ($subnet.properties.defaultOutboundAccess -eq $false) 'Implicit outbound access must be disabled.'
Assert-Template ($subnet.properties.natGateway.id -ceq "[resourceId('Microsoft.Network/natGateways', variables('settings').network.natGatewayName)]") 'Each subnet must use the fixed NAT Gateway.'
Assert-Template ($subnet.properties.privateEndpointNetworkPolicies -eq 'Disabled' -and $subnet.properties.privateLinkServiceNetworkPolicies -eq 'Enabled') 'Subnet policies must match the article.'
Assert-Template ($nats[0].sku.name -eq 'Standard' -and $nats[0].properties.idleTimeoutInMinutes -ceq "[variables('settings').network.idleTimeoutInMinutes]") 'Expected Standard NAT with fixed timeout.'
Assert-Template ($nats[0].properties.publicIpAddresses[0].id -match 'publicIPAddresses.*publicIpName') 'NAT must use the fixed public IP.'
Assert-Template ($publicIps[0].sku.name -eq 'Standard' -and $publicIps[0].properties.publicIPAllocationMethod -eq 'Static' -and $publicIps[0].properties.publicIPAddressVersion -eq 'IPv4') 'Expected Standard static IPv4.'

$entry = $templates.avd
Assert-Template ($entry.parameters.Count -eq 1 -and $entry.parameters.ContainsKey('vmAdministratorAccountPassword')) 'AVD must expose only the password parameter.'
$password = $entry.parameters.vmAdministratorAccountPassword
Assert-Template ($password.type -eq 'securestring' -and -not $password.ContainsKey('defaultValue')) 'The password must be secure and have no default.'
Assert-Template ($password.minLength -eq 12 -and $password.maxLength -eq 123) 'The password length must be bounded.'
Assert-Template ($entry.resources.Count -eq 1) 'AVD entry must contain one embedded module.'
$deployment = $entry.resources[0]
Assert-Template ($deployment.type -eq 'Microsoft.Resources/deployments' -and -not $deployment.properties.ContainsKey('templateLink')) 'AVD must use an embedded template, not a remote dependency.'
Assert-Template ($deployment.properties.mode -eq 'Incremental') 'AVD module must not delete unrelated resources.'
Assert-Template ($deployment.properties.parameters.connectionUserObjectId.value -ceq '[deployer().objectId]') 'Assign access to the deploying user without attendee Object ID input.'
Assert-Template ($deployment.properties.parameters.vmAdministratorAccountPassword.value -ceq "[parameters('vmAdministratorAccountPassword')]") 'Forward the secure password directly.'
$avd = $deployment.properties.template
Assert-Template ((Convert-CompactJson (Get-FixedSettings $avd)) -ceq (Convert-CompactJson $settings)) 'AVD fixed settings must match the source.'
Assert-Template ($avd.parameters.vmAdministratorAccountPassword.type -eq 'securestring' -and -not $avd.parameters.vmAdministratorAccountPassword.ContainsKey('defaultValue')) 'Nested password must remain secure.'
Assert-Template ($avd.parameters.tokenExpirationTime.defaultValue -ceq "[dateTimeAdd(utcNow(), 'PT2H')]") 'Registration token expiry must be two hours from deployment.'
Assert-Template (($avd.outputs | ConvertTo-Json -Depth 100) -notmatch 'password|registrationInfoToken|listRegistrationTokens') 'Module outputs must not expose secrets.'
Assert-Template (@($avd.resources | Where-Object { $_.type -match 'virtualNetworks|natGateways|publicIPAddresses|resourceGroups|Microsoft.Intune' }).Count -eq 0) 'AVD must not recreate Network, RG or Intune resources.'

$hosts = Find-Resources $avd 'Microsoft.DesktopVirtualization/hostPools'
$dags = Find-Resources $avd 'Microsoft.DesktopVirtualization/applicationGroups'
$workspaces = Find-Resources $avd 'Microsoft.DesktopVirtualization/workspaces'
Assert-Template ($hosts.Count -eq 1 -and $dags.Count -eq 1 -and $workspaces.Count -eq 1) 'Expected one host pool, DAG and workspace.'
Assert-Template ($hosts[0].properties.hostPoolType -eq 'Pooled' -and $hosts[0].properties.managementType -eq 'Standard' -and $hosts[0].properties.loadBalancerType -eq 'BreadthFirst') 'Expected article host pool configuration.'
Assert-Template ($hosts[0].properties.maxSessionLimit -ceq "[variables('settings').avd.maxSessionLimit]") 'Expected fixed session limit.'
Assert-Template ($hosts[0].properties.customRdpProperty -ceq 'enablerdsaadauth:i:1;redirectclipboard:i:1;audiomode:i:0;') 'SSO must always be enabled, not opt-in.'
Assert-Template ($hosts[0].properties.registrationInfo.expirationTime -ceq "[parameters('tokenExpirationTime')]") 'Host pool must use the relative expiry.'
Assert-Template ($dags[0].properties.applicationGroupType -eq 'Desktop' -and $dags[0].properties.hostPoolArmPath -match 'hostPools') 'DAG must belong to the host pool.'
Assert-Template ($workspaces[0].properties.applicationGroupReferences.Count -eq 1 -and $workspaces[0].properties.applicationGroupReferences[0] -match 'applicationGroups') 'DAG must be registered in the workspace.'

$vms = Find-Resources $avd 'Microsoft.Compute/virtualMachines'
$nics = Find-Resources $avd 'Microsoft.Network/networkInterfaces'
Assert-Template ($vms.Count -eq 1 -and $nics.Count -eq 1 -and -not $vms[0].ContainsKey('copy')) 'Deploy exactly one fixed session host.'
Assert-Template ($avd.variables.vmName -ceq "[format('{0}-0', variables('settings').avd.vmNamePrefix)]") 'Use stable avd-0 naming, not a timestamp.'
$vm = $vms[0]
Assert-Template ($vm.identity.type -eq 'SystemAssigned' -and $vm.properties.licenseType -eq 'Windows_Client') 'Expected system identity and Windows client licensing.'
Assert-Template ($vm.properties.hardwareProfile.vmSize -ceq "[variables('settings').avd.vmSize]") 'VM size must use the fixed article setting.'
foreach ($field in @('publisher', 'offer', 'sku', 'version')) {
    $setting = @{ publisher = 'imagePublisher'; offer = 'imageOffer'; sku = 'imageSku'; version = 'imageVersion' }[$field]
    Assert-Template ($vm.properties.storageProfile.imageReference[$field] -ceq "[variables('settings').avd.$setting]") "Fixed image $field must be wired to the VM."
}
Assert-Template ($vm.properties.storageProfile.osDisk.diskSizeGB -ceq "[variables('settings').avd.vmDiskSizeGB]" -and $vm.properties.storageProfile.osDisk.managedDisk.storageAccountType -ceq "[variables('settings').avd.vmDiskType]") 'Use the fixed OS disk size and type.'
Assert-Template ($vm.properties.osProfile.adminUsername -ceq "[variables('settings').avd.vmAdminUsername]" -and $vm.properties.osProfile.adminPassword -ceq "[parameters('vmAdministratorAccountPassword')]") 'Use the fixed username and secure password.'
Assert-Template ($vm.properties.securityProfile.securityType -eq 'TrustedLaunch' -and $vm.properties.securityProfile.uefiSettings.secureBootEnabled -eq $true -and $vm.properties.securityProfile.uefiSettings.vTpmEnabled -eq $true) 'Trusted Launch, Secure Boot and vTPM must be enabled.'
$ip = $nics[0].properties.ipConfigurations[0].properties
Assert-Template (-not $ip.ContainsKey('publicIPAddress') -and $ip.privateIPAllocationMethod -eq 'Dynamic') 'No VM public IP is allowed.'
Assert-Template ($ip.subnet.id -match "settings'\)\.resourceGroupName" -and $ip.subnet.id -match "settings'\)\.network\.vnetName" -and $ip.subnet.id -match "settings'\)\.network\.subnets\[2\]\.name") 'NIC must reference rg-vdi/vnet-vdi/snet-avd.'

$roles = Find-Resources $avd 'Microsoft.Authorization/roleAssignments'
Assert-Template ($roles.Count -eq 2) 'Expected desktop access and VM login assignments.'
Assert-Template ($avd.variables.desktopUserRoleId -match '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63' -and $avd.variables.vmUserLoginRoleId -match 'fb879df8-f326-4884-b1cf-06f3ad86be52') 'Use the correct built-in roles.'
foreach ($role in $roles) {
    Assert-Template ($role.properties.principalId -ceq "[parameters('connectionUserObjectId')]" -and $role.properties.principalType -eq 'User') 'Both roles must target the deploying member user.'
    Assert-Template ($role.name -match "guid\(.*parameters\('connectionUserObjectId'\)") 'Role names must be deterministic for each principal and scope.'
}
$desktopRole = @($roles | Where-Object { $_.properties.roleDefinitionId -eq "[variables('desktopUserRoleId')]" })
$loginRole = @($roles | Where-Object { $_.properties.roleDefinitionId -eq "[variables('vmUserLoginRoleId')]" })
Assert-Template ($desktopRole.Count -eq 1 -and $desktopRole[0].scope -match 'applicationGroups') 'Desktop access must be scoped to the DAG.'
Assert-Template ($loginRole.Count -eq 1 -and $loginRole[0].scope -match 'virtualMachines') 'VM login must be scoped to the VM.'

$extensions = Find-Resources $avd 'Microsoft.Compute/virtualMachines/extensions'
$join = @($extensions | Where-Object { $_.properties.type -eq 'AADLoginForWindows' })
$dsc = @($extensions | Where-Object { $_.properties.type -eq 'DSC' })
$custom = @($extensions | Where-Object { $_.properties.type -eq 'CustomScriptExtension' })
Assert-Template ($extensions.Count -eq 3 -and $join.Count -eq 1 -and $dsc.Count -eq 1 -and $custom.Count -eq 1) 'Expected Entra join, registration and article custom configuration.'
Assert-Template ($join[0].properties.typeHandlerVersion -eq '2.0') 'Use the SSO-capable Entra join extension.'
Assert-Template ($dsc[0].properties.settings.properties.aadJoin -eq $true -and $dsc[0].properties.settings.properties.UseAgentDownloadEndpoint -eq $true) 'Registration must use Entra join and the agent download endpoint.'
Assert-Template ($dsc[0].properties.settings.modulesUrl -ceq "[variables('settings').avd.configurationPackageUrl]") 'Use the configured DSC package.'
Assert-Template ($dsc[0].properties.settings.configurationFunction -ceq 'Configuration.ps1\AddSessionHost') 'Use the supported DSC registration function.'
Assert-Template (($dsc[0].properties.settings | ConvertTo-Json -Depth 100) -notmatch 'registrationInfoToken') 'Registration tokens must not be in public settings.'
Assert-Template ($dsc[0].properties.protectedSettings.properties.registrationInfoToken -match 'listRegistrationTokens') 'Only pass the registration token through protected settings.'
Assert-Template (($dsc[0].dependsOn -join ' ') -match 'AADLoginForWindows' -and ($custom[0].dependsOn -join ' ') -match 'MicrosoftPowershellDSC') 'Enforce Entra join, then registration, then custom configuration.'
Assert-Template ($custom[0].properties.protectedSettings.fileUris[0] -ceq "[variables('settings').avd.customConfigurationScriptUrl]" -and $custom[0].properties.protectedSettings.commandToExecute -ceq 'powershell -ExecutionPolicy Bypass -File JPNOFLNG.ps1') 'Wire the article script without storing credentials.'

foreach ($resource in @($network.resources) + @($avd.resources | Where-Object { $_.ContainsKey('location') })) {
    Assert-Template ($resource.location -ceq "[variables('settings').location]") 'All deployed resources must use Japan East.'
}

$liveReadme = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw
$liveManifest = Read-Json (Join-Path $root 'resources\deploy-links.json')
Assert-Template (($liveManifest.orderedDay1Phases -join ',') -ceq 'manual-prerequisites-and-resource-group,network-deploy-to-azure,windows365-owner-part,avd-deploy-to-azure') 'Preserve the Day 1 phase order.'
Assert-Template ($liveManifest.publication.rawUrlsVerified -eq $false -or $liveManifest.publication.repository) 'Verified publication must identify its repository.'
foreach ($phase in @('network', 'avd')) {
    $link = @($liveManifest.links | Where-Object { $_.phase -eq $phase })
    Assert-Template ($link.Count -eq 1 -and $link[0].localTemplate -eq "templates/$phase.json") 'Metadata must identify each local production template.'
    if (-not $liveManifest.publication.repository) {
        Assert-Template ($null -eq $link[0].templateUri -and $null -eq $link[0].deployToAzureUrl) 'Unpublished templates must not have active deployment URLs.'
        $pattern = "<!-- deploy-button-${phase}:start -->(.*?)<!-- deploy-button-${phase}:end -->"
        $regions = [regex]::Matches($liveReadme, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        Assert-Template ($regions.Count -eq 1) 'Each phase must have one managed README button region.'
        $region = $regions[0].Groups[1].Value
        Assert-Template ($region.Contains('![Deploy to Azure](https://aka.ms/deploytoazurebutton)') -and $region -notmatch '\[!\[Deploy to Azure\]') 'Unpublished badges must be official images without deployment links.'
    }
}

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('avd-production-buttons-' + [guid]::NewGuid().ToString('N'))
$originalReadmeHash = (Get-FileHash -LiteralPath (Join-Path $root 'README.md')).Hash
$originalManifestHash = (Get-FileHash -LiteralPath (Join-Path $root 'resources\deploy-links.json')).Hash
function Reset-ButtonFixture {
    foreach ($directory in @('scripts', 'resources', 'templates')) {
        New-Item -ItemType Directory -Path (Join-Path $fixture $directory) -Force | Out-Null
    }
    foreach ($relative in @('README.md', 'resources\deploy-links.json', 'scripts\Set-DeployButtons.ps1', 'templates\network.json', 'templates\avd.json')) {
        Copy-Item -LiteralPath (Join-Path $root $relative) -Destination (Join-Path $fixture $relative) -Force
    }
}
function Assert-ButtonFailure {
    param([hashtable]$Arguments, [string]$ExpectedError)
    $readmeHash = (Get-FileHash -LiteralPath (Join-Path $fixture 'README.md')).Hash
    $manifestHash = (Get-FileHash -LiteralPath (Join-Path $fixture 'resources\deploy-links.json')).Hash
    $message = ''
    try {
        & (Join-Path $fixture 'scripts\Set-DeployButtons.ps1') @Arguments 6>$null
    } catch {
        $message = $_.Exception.Message
    }
    Assert-Template ($message -match $ExpectedError) "Expected explicit button failure: $ExpectedError. Actual: $message"
    Assert-Template ((Get-FileHash -LiteralPath (Join-Path $fixture 'README.md')).Hash -eq $readmeHash) 'A rejected configuration must not partially rewrite README.'
    Assert-Template ((Get-FileHash -LiteralPath (Join-Path $fixture 'resources\deploy-links.json')).Hash -eq $manifestHash) 'A rejected configuration must not rewrite metadata.'
}

try {
    Reset-ButtonFixture
    $arguments = @{
        Repository = 'example-org/example-avd'
        TemplateCommit = ('ABCDEF01' * 5)
        TemplatePathPrefix = 'avd-hands-on/production'
    }
    & (Join-Path $fixture 'scripts\Set-DeployButtons.ps1') @arguments 6>$null
    $configured = Read-Json (Join-Path $fixture 'resources\deploy-links.json')
    $configuredReadme = Get-Content -LiteralPath (Join-Path $fixture 'README.md') -Raw
    Assert-Template ($configured.publication.templateCommit -ceq $arguments.TemplateCommit.ToLowerInvariant() -and $configured.publication.rawUrlsVerified -eq $false) 'Normalize the commit without claiming URL verification.'
    foreach ($phase in @('network', 'avd')) {
        $link = @($configured.links | Where-Object { $_.phase -eq $phase })[0]
        $uri = "https://raw.githubusercontent.com/example-org/example-avd/$($arguments.TemplateCommit.ToLowerInvariant())/avd-hands-on/production/templates/$phase.json"
        Assert-Template ($link.templateUri -ceq $uri) 'Button template URI must use a fixed commit and prefix.'
        Assert-Template ($link.deployToAzureUrl -ceq ('https://portal.azure.com/#create/Microsoft.Template/uri/' + [uri]::EscapeDataString($uri))) 'Use the official encoded portal URL.'
        Assert-Template ($configuredReadme.Contains("[![Deploy to Azure](https://aka.ms/deploytoazurebutton)]($($link.deployToAzureUrl))")) 'README must contain the matching official button.'
        Assert-Template ($link.localTemplateSha256 -eq (Get-FileHash -LiteralPath (Join-Path $fixture "templates\$phase.json")).Hash) 'Record the actual local template hash.'
    }
    $once = $configuredReadme
    & (Join-Path $fixture 'scripts\Set-DeployButtons.ps1') @arguments 6>$null
    Assert-Template ((Get-Content -LiteralPath (Join-Path $fixture 'README.md') -Raw) -ceq $once) 'Repeated button configuration must be idempotent.'
    Reset-ButtonFixture
    $rootArguments = @{ Repository = $arguments.Repository; TemplateCommit = $arguments.TemplateCommit }
    & (Join-Path $fixture 'scripts\Set-DeployButtons.ps1') @rootArguments 6>$null
    $atRoot = Read-Json (Join-Path $fixture 'resources\deploy-links.json')
    Assert-Template ($atRoot.links[0].templateUri -match '/[0-9a-f]{40}/templates/network.json$') 'Standalone package URLs must support an empty prefix.'

    Reset-ButtonFixture
    Assert-ButtonFailure (@{ Repository = $arguments.Repository; TemplateCommit = $arguments.TemplateCommit; TemplatePathPrefix = '../production' }) 'dot path segments'
    Assert-ButtonFailure (@{ Repository = $arguments.Repository; TemplateCommit = 'main' }) 'TemplateCommit'
    Assert-ButtonFailure (@{ Repository = $arguments.Repository; TemplateCommit = $arguments.TemplateCommit; TemplatePathPrefix = '/production' }) 'TemplatePathPrefix'
    $fixtureReadme = Join-Path $fixture 'README.md'
    (Get-Content -LiteralPath $fixtureReadme -Raw).Replace('<!-- deploy-button-avd:end -->', '') | Set-Content -LiteralPath $fixtureReadme -Encoding utf8
    Assert-ButtonFailure $arguments 'exactly one start and end marker for avd'
    Reset-ButtonFixture
    Add-Content -LiteralPath $fixtureReadme -Value '<!-- deploy-button-avd:start -->' -Encoding utf8
    Assert-ButtonFailure $arguments 'exactly one start and end marker for avd'
    Reset-ButtonFixture
    $fixtureManifest = Read-Json (Join-Path $fixture 'resources\deploy-links.json')
    $fixtureManifest.links += $fixtureManifest.links[1]
    $fixtureManifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $fixture 'resources\deploy-links.json') -Encoding utf8
    Assert-ButtonFailure $arguments 'one link entry for avd'
    Reset-ButtonFixture
    Remove-Item -LiteralPath (Join-Path $fixture 'templates\avd.json')
    Assert-ButtonFailure $arguments 'Missing compiled template'
} finally {
    if (Test-Path -LiteralPath $fixture) {
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
Assert-Template ((Get-FileHash -LiteralPath (Join-Path $root 'README.md')).Hash -eq $originalReadmeHash -and (Get-FileHash -LiteralPath (Join-Path $root 'resources\deploy-links.json')).Hash -eq $originalManifestHash) 'Button tests must leave the live package untouched.'
Write-Host "Passed $assertions production template and deployment-button assertions. No Azure resources were deployed."
