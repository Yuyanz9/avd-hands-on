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
    location = 'japaneast'
    'network.vnetName' = 'vnet-vdi'
    'network.addressPrefix' = '10.10.0.0/16'
    'avd.hostpoolName' = 'DefaultHostPool'
    'avd.workspaceName' = 'AVD Session Host'
    'avd.vmAdminUsername' = 'vmadmin'
    'avd.vmDiskSizeGB' = 128
    'avd.imagePublisher' = 'microsoftwindowsdesktop'
    'avd.imageOffer' = 'windows-11'
    'avd.imageVersion' = 'latest'
    'avd.customConfigurationScriptUrl' = 'https://raw.githubusercontent.com/Yuyanz9/avd-hands-on/7b0923fcc78335ac25bafc418d9d3ab4538292d8/scripts/JPNOFLNG.ps1'
    'avd.configurationPackageUrl' = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.03537.1471.zip'
}
foreach ($path in $expected.Keys) {
    $value = $settings
    foreach ($segment in ($path -split '\.')) { $value = $value[$segment] }
    Assert-Template ($value -ceq $expected[$path]) "Unexpected fixed setting: $path."
}
Assert-Template (-not $settings.ContainsKey('resourceGroupName')) 'Resource group must come from the portal deployment scope, not fixed settings.'
Assert-Template ($settings.avd.customConfigurationScriptUrl -cmatch '^https://raw\.githubusercontent\.com/Yuyanz9/avd-hands-on/[0-9a-f]{40}/scripts/JPNOFLNG\.ps1$') 'The default Japanese script must use an immutable public package URL, not Blob or a mutable branch.'
$localizationPath = Join-Path $root 'scripts\JPNOFLNG.ps1'
$localizationText = Get-Content -LiteralPath $localizationPath -Raw
$localizationTokens = $null
$localizationErrors = $null
$localizationAst = [System.Management.Automation.Language.Parser]::ParseFile($localizationPath, [ref]$localizationTokens, [ref]$localizationErrors)
Assert-Template ($localizationErrors.Count -eq 0) 'The hosted Japanese script must parse without executing any system configuration.'
$localizationCommands = @($localizationAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst]
}, $true) | ForEach-Object { $_.GetCommandName() })
foreach ($name in @('Set-TimeZone', 'Install-Language', 'Set-WinSystemLocale', 'Set-Culture', 'Set-SystemPreferredUILanguage', 'Set-WinHomeLocation', 'New-WinUserLanguageList', 'Set-WinUserLanguageList', 'Install-PackageProvider', 'Install-Module', 'Get-WindowsUpdate')) {
    Assert-Template ($name -in $localizationCommands) "Preserve the article's OS localization/Windows Update operation: $name."
}
Assert-Template ($localizationText.Contains('Install-Language ja-jp -CopyTosettings') -and $localizationText.Contains('Get-WindowsUpdate -AcceptAll -Install -AutoReboot')) 'Preserve welcome-screen language copying and the documented automatic restart behavior.'
Assert-Template ($localizationText.Contains('carol0226') -and $localizationText.Contains('https://qiita.com/carol0226/items/f7770369947aaf4962f7')) 'Keep attribution to the author and a public reference, not the limited-share article URL.'
$localizationHasher = [System.Security.Cryptography.SHA256]::Create()
try {
    $canonicalBytes = [System.Text.Encoding]::UTF8.GetBytes($localizationText.Replace("`r`n", "`n"))
    $localizationHash = [System.BitConverter]::ToString($localizationHasher.ComputeHash($canonicalBytes)).Replace('-', '')
} finally {
    $localizationHasher.Dispose()
}
Assert-Template ($localizationHash -ceq '5C55DB8A3C2394F1AFBE2125F950753ED2DFFE602578C963504F617EAE46FAE4') 'The bundled script must match the verified immutable URL after Git LF normalization; publish a new script commit before changing it.'
Assert-Template ($settings.network.subnets.Count -eq 3) 'Expected exactly three article subnets.'
$subnetNames = @('snet-cloudpc', 'snet-avd', 'snet-server')
$subnetPrefixes = @('10.10.1.0/24', '10.10.2.0/24', '10.10.3.0/24')
for ($index = 0; $index -lt 3; $index++) {
    Assert-Template ($settings.network.subnets[$index].name -ceq $subnetNames[$index]) 'Unexpected subnet name or order.'
    Assert-Template ($settings.network.subnets[$index].addressPrefix -ceq $subnetPrefixes[$index]) 'Unexpected subnet address prefix.'
}

$templates = @{}
foreach ($phase in @('network', 'network-validation', 'avd', 'session-host')) {
    $stored = Read-Json (Join-Path $root "templates\$phase.json")
    $freshPath = Join-Path ([System.IO.Path]::GetTempPath()) "avd-hands-on-test-$PID-$phase.json"
    try {
        Invoke-TrainingAzureCli -Arguments @(
            'bicep', 'build', '--file', (Join-Path $root "infra\$phase.bicep"),
            '--outfile', $freshPath, '--only-show-errors'
        ) | Out-Null
        $fresh = Read-Json $freshPath
    } finally {
        Remove-Item -LiteralPath $freshPath -Force -ErrorAction SilentlyContinue
    }
    Assert-Template ((Convert-CompactJson $stored) -ceq (Convert-CompactJson $fresh)) "Stale generated $phase.json. Run Build-Templates.ps1 with the current compiler."
    Assert-Template ($stored['$schema'] -match '/deploymentTemplate.json#$') "$phase must use resource-group deployment scope."
    Assert-Template ((Find-Resources $stored 'Microsoft.Resources/resourceGroups').Count -eq 0) 'Resource groups must be created manually.'
    Assert-Template (($stored.outputs | ConvertTo-Json -Depth 100) -notmatch 'password|registrationInfoToken|listRegistrationTokens') 'Outputs must not expose secrets.'
    $templates[$phase] = $stored
}

$network = $templates.network
$networkDefaults = @{
    location = 'japaneast'
    vnetName = 'vnet-vdi'
    vnetAddressPrefix = '10.10.0.0/16'
    cloudPcSubnetPrefix = '10.10.1.0/24'
    avdSubnetPrefix = '10.10.2.0/24'
    serverSubnetPrefix = '10.10.3.0/24'
}
foreach ($phase in @('network', 'network-validation')) {
    $template = $templates[$phase]
    $operational = $phase -eq 'network'
    Assert-Template ($template.parameters.Count -eq $(if ($operational) { 8 } else { 6 })) "$phase must expose only the agreed editable parameters."
    $networkParameterOrder = @('location', 'vnetName', 'vnetAddressPrefix', 'cloudPcSubnetPrefix', 'avdSubnetPrefix', 'serverSubnetPrefix')
    if ($operational) { $networkParameterOrder += @('natGatewayName', 'publicIpName') }
    Assert-Template (($template.parameters.Keys -join ',') -ceq ($networkParameterOrder -join ',')) "$phase must show Cloud PC, AVD, Server inputs in slide order."
    foreach ($name in $networkDefaults.Keys) {
        Assert-Template ($template.parameters[$name].defaultValue -ceq $networkDefaults[$name]) "$phase must preserve the editable network default: $name."
        Assert-Template (-not [string]::IsNullOrWhiteSpace($template.parameters[$name].metadata.displayName)) "$phase must show a friendly portal label for $name."
    }
    if ($operational) {
        Assert-Template ($template.parameters.natGatewayName.defaultValue -ceq 'nat-vdi') 'Operational NAT Gateway name must keep its current default.'
        Assert-Template ($template.parameters.publicIpName.defaultValue -ceq 'pip-vdi') 'Operational public IP name must keep its current default.'
        Assert-Template ($template.parameters.natGatewayName.metadata.displayName -eq 'NAT Gateway Name' -and $template.parameters.publicIpName.metadata.displayName -eq 'Public IP Name') 'NAT and public IP names must be editable with clear labels.'
    } else {
        Assert-Template (-not $template.parameters.ContainsKey('natGatewayName') -and -not $template.parameters.ContainsKey('publicIpName')) 'Validation mode must not expose NAT or public IP names.'
    }

    Assert-Template ($template.resources.Count -eq 1) "$phase must invoke one shared network module."
    $deployment = $template.resources[0]
    Assert-Template ($deployment.type -eq 'Microsoft.Resources/deployments' -and $deployment.properties.mode -eq 'Incremental') "$phase must use an embedded incremental deployment."
    Assert-Template ($deployment.properties.parameters.useNatGateway.value -eq $operational) "$phase must select the intended NAT mode."
    foreach ($name in $networkDefaults.Keys) {
        Assert-Template ($deployment.properties.parameters[$name].value -ceq "[parameters('$name')]") "$phase must forward the editable $name input."
    }
    $networkCore = $deployment.properties.template
    $vnets = Find-Resources $networkCore 'Microsoft.Network/virtualNetworks'
    $nats = Find-Resources $networkCore 'Microsoft.Network/natGateways'
    $publicIps = Find-Resources $networkCore 'Microsoft.Network/publicIPAddresses'
    Assert-Template ($vnets.Count -eq 1 -and $nats.Count -eq 1 -and $publicIps.Count -eq 1) "$phase must use the shared VNet/NAT implementation."
    Assert-Template ($nats[0].condition -ceq "[parameters('useNatGateway')]" -and $publicIps[0].condition -ceq "[parameters('useNatGateway')]") "$phase must conditionally create NAT resources."
    Assert-Template ($nats[0].sku.name -eq 'Standard' -and $nats[0].properties.idleTimeoutInMinutes -eq 4) 'Operational NAT Gateway must use Standard SKU and a four-minute idle timeout.'
    Assert-Template ($publicIps[0].sku.name -eq 'Standard' -and $publicIps[0].properties.publicIPAllocationMethod -eq 'Static' -and $publicIps[0].properties.publicIPAddressVersion -eq 'IPv4') 'Operational NAT must use a static Standard IPv4 public IP.'
    $expectedSubnetNames = @('snet-cloudpc', 'snet-avd', 'snet-server')
    $expectedSubnetParameters = @('cloudPcSubnetPrefix', 'avdSubnetPrefix', 'serverSubnetPrefix')
    $subnetDefinitions = @($networkCore.variables.subnets)
    Assert-Template ($subnetDefinitions.Count -eq 3) "$phase must preserve all three subnet definitions."
    for ($index = 0; $index -lt 3; $index++) {
        Assert-Template ($subnetDefinitions[$index].name -ceq $expectedSubnetNames[$index]) "$phase subnet names must stay fixed and ordered."
        $prefixParameter = $expectedSubnetParameters[$index]
        Assert-Template ($subnetDefinitions[$index].addressPrefix -ceq "[parameters('$prefixParameter')]") "$phase subnet CIDRs must use editable parameters."
    }
    foreach ($output in @('cloudPcSubnetId', 'avdSubnetId', 'serverSubnetId')) {
        $index = [array]::IndexOf(@('cloudPcSubnetId', 'avdSubnetId', 'serverSubnetId'), $output)
        Assert-Template ($networkCore.outputs[$output].value.Contains("/subnets/$($expectedSubnetNames[$index])")) "$phase must keep each output ID bound to its named subnet."
    }
    Assert-Template ($vnets[0].name -ceq "[parameters('vnetName')]") "$phase VNet name must use its editable input."
    Assert-Template ($vnets[0].properties.addressSpace.addressPrefixes[0] -ceq "[parameters('vnetAddressPrefix')]") "$phase VNet address space must use its editable input."
    $subnetCopy = @($vnets[0].properties.copy | Where-Object { $_.name -eq 'subnets' })
    Assert-Template ($subnetCopy.Count -eq 1 -and $subnetCopy[0].count -ceq "[length(variables('subnets'))]") "$phase must deploy all three subnets."
    $subnet = $subnetCopy[0].input
    Assert-Template ($subnet.name -ceq "[variables('subnets')[copyIndex('subnets')].name]") 'Subnet names must remain fixed.'
    Assert-Template ($subnet.properties -match "defaultOutboundAccess', not\(parameters\('useNatGateway'\)\)") 'Outbound access must be enabled only in NAT-free validation mode.'
    Assert-Template ($subnet.properties -match "if\(parameters\('useNatGateway'\), createObject\('natGateway'") 'Only operational subnets may receive a NAT Gateway association.'
    Assert-Template ($subnet.properties -match "'privateEndpointNetworkPolicies', 'Disabled'.*'privateLinkServiceNetworkPolicies', 'Enabled'") 'Subnet policies must remain unchanged.'
}

$entry = $templates.avd
Assert-Template ($entry.parameters.Count -eq 58 -and $entry.parameters.ContainsKey('vmAdministratorAccountPassword')) 'AVD must expose the existing inputs, required AVD Users group ID, Intune enrollment, shutdown-time and all supported AVD RDP properties.'
$password = $entry.parameters.vmAdministratorAccountPassword
Assert-Template ($password.type -eq 'securestring' -and -not $password.ContainsKey('defaultValue')) 'The password must be secure and have no default.'
Assert-Template ($password.minLength -eq 12 -and $password.maxLength -eq 123) 'The password length must be bounded.'
$groupObjectId = $entry.parameters.avdUsersGroupObjectId
Assert-Template ($groupObjectId.type -eq 'string' -and $groupObjectId.minLength -eq 36 -and $groupObjectId.maxLength -eq 36 -and -not $groupObjectId.ContainsKey('defaultValue')) 'AVD deployment must require the existing AVD Users group Object ID.'
Assert-Template ($groupObjectId.metadata.displayName -ceq 'AVD Users Group Object Id') 'Show a clear label for the AVD Users group Object ID.'
$expectedDefaults = @{
    networkResourceGroupName = '[resourceGroup().name]'
    virtualNetworkName = 'vnet-vdi'
    subnetName = 'snet-avd'
    location = 'japaneast'
    imageSku = 'win11-25h2-avd-m365'
    workspaceFriendlyName = 'AVD Session Host'
    vmSize = 'Standard_D4as_v6'
    vmDiskType = 'StandardSSD_LRS'
    maxSessionLimit = 5
    vmNamePrefix = "[dateTimeAdd(utcNow(), 'PT9H', 'AVDMMddHHmm')]"
    customConfigurationScriptUrl = $settings.avd.customConfigurationScriptUrl
    vmNumberOfInstances = 1
    hostpoolType = 'Pooled'
    loadBalancerType = 'BreadthFirst'
    intune = $true
    autoShutdownTime = '19:00'
}
foreach ($name in $expectedDefaults.Keys) {
    Assert-Template ($entry.parameters[$name].defaultValue -ceq $expectedDefaults[$name]) "AVD default must be editable and preserve the expected value: $name."
}
Assert-Template ($entry.parameters.vmNamePrefix.maxLength -eq 13) 'VM name prefix must leave room for the -0 suffix in a Windows computer name.'
$expectedOrder = @('vmAdministratorAccountPassword', 'avdUsersGroupObjectId', 'networkResourceGroupName', 'virtualNetworkName', 'subnetName', 'location', 'imageSku', 'workspaceFriendlyName', 'vmSize', 'vmDiskType', 'maxSessionLimit', 'vmNamePrefix', 'customConfigurationScriptUrl', 'vmNumberOfInstances', 'hostpoolType', 'loadBalancerType', 'intune', 'autoShutdownTime')
$rdpParameterOrder = @('rdpAlternateShell', 'rdpEnableCredSspSupport', 'rdpEnableEntraIdAuth', 'rdpKdcProxyName', 'rdpTargetIsAadJoined', 'rdpAutoReconnectionEnabled', 'rdpBandwidthAutoDetect', 'rdpCompression', 'rdpNetworkAutoDetect', 'rdpVideoPlaybackMode', 'rdpAudioCaptureMode', 'rdpAudioMode', 'rdpCameraStoreDirect', 'rdpDeviceStoreDirect', 'rdpDeviceStoreDirectCustom', 'rdpDriveStoreDirect', 'rdpDriveStoreDirectCustom', 'rdpEncodeRedirectedVideoCapture', 'rdpKeyboardHook', 'rdpRedirectClipboard', 'rdpRedirectComPorts', 'rdpRedirectedVideoCaptureEncodingQuality', 'rdpRedirectLocation', 'rdpRedirectPrinters', 'rdpRedirectSmartCards', 'rdpRedirectWebAuthn', 'rdpSmartRawPrinters', 'rdpUsbDeviceStoreDirect', 'rdpUsbDeviceStoreDirectCustom', 'rdpDesktopSizeId', 'rdpDesktopHeight', 'rdpDesktopScaleFactor', 'rdpDesktopWidth', 'rdpDynamicResolution', 'rdpMaximizeToCurrentDisplays', 'rdpScreenModeId', 'rdpSelectedMonitors', 'rdpSingleMonInWindowedMode', 'rdpSmartSizing', 'rdpUseMultimon')
$expectedOrder += $rdpParameterOrder
Assert-Template (($entry.parameters.Keys -join ',') -ceq ($expectedOrder -join ',')) 'Keep the existing portal input order, require the AVD Users group ID, and show every RDP property after the deployment options.'
$expectedRdpDefaults = @{
    rdpAlternateShell = ''
    rdpEnableCredSspSupport = '有効 (1)'
    rdpEnableEntraIdAuth = '有効 (1)'
    rdpKdcProxyName = ''
    rdpTargetIsAadJoined = '未構成'
    rdpAutoReconnectionEnabled = '未構成'
    rdpBandwidthAutoDetect = '未構成'
    rdpCompression = '未構成'
    rdpNetworkAutoDetect = '未構成'
    rdpVideoPlaybackMode = '有効 (1)'
    rdpAudioCaptureMode = '未構成'
    rdpAudioMode = 'ローカル端末で再生 (0)'
    rdpCameraStoreDirect = ''
    rdpDeviceStoreDirect = 'すべての対応デバイス (*)'
    rdpDeviceStoreDirectCustom = ''
    rdpDriveStoreDirect = 'リダイレクトしない (空)'
    rdpDriveStoreDirectCustom = ''
    rdpEncodeRedirectedVideoCapture = '未構成'
    rdpKeyboardHook = '未構成'
    rdpRedirectClipboard = '無効 (0)'
    rdpRedirectComPorts = '有効 (1)'
    rdpRedirectedVideoCaptureEncodingQuality = '未構成'
    rdpRedirectLocation = '未構成'
    rdpRedirectPrinters = '無効 (0)'
    rdpRedirectSmartCards = '有効 (1)'
    rdpRedirectWebAuthn = '有効 (1)'
    rdpSmartRawPrinters = ''
    rdpUsbDeviceStoreDirect = 'リダイレクトしない (空)'
    rdpUsbDeviceStoreDirectCustom = ''
    rdpDesktopSizeId = '未構成'
    rdpDesktopHeight = 0
    rdpDesktopScaleFactor = '未構成'
    rdpDesktopWidth = 0
    rdpDynamicResolution = '未構成'
    rdpMaximizeToCurrentDisplays = '未構成'
    rdpScreenModeId = '未構成'
    rdpSelectedMonitors = ''
    rdpSingleMonInWindowedMode = '未構成'
    rdpSmartSizing = '未構成'
    rdpUseMultimon = '有効 (1)'
}
Assert-Template ($expectedRdpDefaults.Count -eq 40) 'Expose all AVD-supported RDP properties, including their custom-value input fields.'
foreach ($name in $rdpParameterOrder) {
    $parameter = $entry.parameters[$name]
    Assert-Template ($parameter.defaultValue -ceq $expectedRdpDefaults[$name]) "RDP default must preserve the current behavior or remain unconfigured: $name."
    Assert-Template (-not [string]::IsNullOrWhiteSpace($parameter.metadata.displayName)) "Show every RDP input in the deployment form: $name."
}
$rdpEnumParameters = @('rdpEnableCredSspSupport', 'rdpEnableEntraIdAuth', 'rdpTargetIsAadJoined', 'rdpAutoReconnectionEnabled', 'rdpBandwidthAutoDetect', 'rdpCompression', 'rdpNetworkAutoDetect', 'rdpVideoPlaybackMode', 'rdpAudioCaptureMode', 'rdpAudioMode', 'rdpDeviceStoreDirect', 'rdpDriveStoreDirect', 'rdpEncodeRedirectedVideoCapture', 'rdpKeyboardHook', 'rdpRedirectClipboard', 'rdpRedirectComPorts', 'rdpRedirectedVideoCaptureEncodingQuality', 'rdpRedirectLocation', 'rdpRedirectPrinters', 'rdpRedirectSmartCards', 'rdpRedirectWebAuthn', 'rdpUsbDeviceStoreDirect', 'rdpDesktopSizeId', 'rdpDesktopScaleFactor', 'rdpDynamicResolution', 'rdpMaximizeToCurrentDisplays', 'rdpScreenModeId', 'rdpSingleMonInWindowedMode', 'rdpSmartSizing', 'rdpUseMultimon')
foreach ($name in $rdpEnumParameters) {
    Assert-Template ($entry.parameters[$name].allowedValues -contains '未構成') "RDP dropdown must offer an explicit unconfigured choice: $name."
}
$imageSkus = @('win11-23h2-avd', 'win11-23h2-avd-m365', 'win11-24h2-avd', 'win11-24h2-avd-m365', 'win11-25h2-avd', 'win11-25h2-avd-m365', 'win11-26h2-avd', 'win11-26h2-avd-m365')
$labels = @{
    avdUsersGroupObjectId = 'AVD Users Group Object Id'
    networkResourceGroupName = 'Network Resource Group Name'
    imageSku = 'Vm Gallery Image SKU'
    customConfigurationScriptUrl = 'Custom Configuration Script Url'
    vmNumberOfInstances = 'Vm Number Of Instances'
    hostpoolType = 'Hostpool Type'
    loadBalancerType = 'Load Balancer Type'
    intune = 'Intune Enrollment'
    autoShutdownTime = 'Auto Shutdown Time (JST)'
}
foreach ($name in $labels.Keys) {
    Assert-Template ($entry.parameters[$name].metadata.displayName -ceq $labels[$name]) "Show the requested portal label: $name."
}
Assert-Template (($entry.parameters.hostpoolType.allowedValues -join ',') -ceq 'Pooled,Personal') 'Host pool type must be a Pooled/Personal selection.'
Assert-Template (($entry.parameters.loadBalancerType.allowedValues -join ',') -ceq 'BreadthFirst,DepthFirst') 'Expose only the supported pooled load balancing algorithms.'
Assert-Template ($entry.parameters.autoShutdownTime.minLength -eq 5 -and $entry.parameters.autoShutdownTime.maxLength -eq 5 -and $entry.parameters.autoShutdownTime.metadata.description -match 'HH:mm.*Japan Standard Time') 'Shutdown time must use a five-character HH:mm value in Japan Standard Time.'
$readmeText = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw
$day1Text = Get-Content -LiteralPath (Join-Path $root 'day1-handson.md') -Raw
$day2Text = Get-Content -LiteralPath (Join-Path $root 'day2-secure-jump.md') -Raw
[xml]$resourceMap = Get-Content -LiteralPath (Join-Path $root 'resources\images\iac-resource-map.svg') -Raw
$diagramSubnetNames = @($resourceMap.SelectNodes('//*[local-name()="text" and @y="493"]'))
$diagramSubnetPrefixes = @($resourceMap.SelectNodes('//*[local-name()="text" and @y="526"]'))
Assert-Template ($diagramSubnetNames.Count -eq 3 -and $diagramSubnetPrefixes.Count -eq 3) 'The diagram must show the three subnet names and CIDRs.'
for ($index = 0; $index -lt 3; $index++) {
    Assert-Template ($diagramSubnetNames[$index].InnerText -ceq $subnetNames[$index] -and $diagramSubnetPrefixes[$index].InnerText -ceq $subnetPrefixes[$index] -and $diagramSubnetNames[$index].GetAttribute('x') -eq $diagramSubnetPrefixes[$index].GetAttribute('x')) 'Diagram cards must match Cloud PC=.1, AVD=.2, Server=.3 in order.'
}
Assert-Template ($readmeText -match '12～123文字が必須' -and $readmeText -match 'InvalidTemplate') 'README must explain the minimum password length error.'
Assert-Template ($day1Text -match '12～123文字が必須' -and $day1Text -match 'InvalidTemplate') 'Day 1 guide must explain the minimum password length error.'
Assert-Template ($day1Text.Contains('Virtual Network Resource Group Name') -and $day1Text.Contains('Work Space Name') -and $day1Text.Contains('Max Session Limit')) 'Day 1 guide must describe the editable fields.'
Assert-Template ($readmeText.Contains('Auto Shutdown Time (JST)') -and $readmeText.Contains('19:00') -and $day1Text.Contains('Auto Shutdown Time (JST)') -and $day1Text.Contains('19:00')) 'Both guides must document the editable Japan-time shutdown setting and its 19:00 default.'
Assert-Template ($day1Text.Contains('(device.displayName -startsWith "AVD")') -and $day1Text.Contains('(device.deviceModel -startsWith "Cloud PC") -or (device.deviceModel -startsWith "Windows 365")')) 'Day 1 guide must document AVD and Cloud PC dynamic device rules.'
Assert-Template ($day1Text.Contains('プロビジョニング ポリシー') -and $day1Text.Contains('ユーザー グループ')) 'Day 1 guide must distinguish Windows 365 provisioning policy assignments from device groups.'
Assert-Template ($readmeText.Contains('AVD Users') -and $readmeText.Contains('Object ID') -and $readmeText.Contains('増分デプロイ') -and $day1Text.Contains('AVD Users') -and $day1Text.Contains('Object ID') -and $day1Text.Contains('増分デプロイ')) 'Both guides must explain the manually created AVD Users group, its required Object ID, and incremental cleanup of old user assignments.'
Assert-Template ($readmeText.Contains('既定で `true`') -and $readmeText.Contains('intune=false') -and $day1Text.Contains('Intune Enrollment') -and $day1Text.Contains('Pooled host pool')) 'Document the default Intune enrollment request, opt-out and host-pool prerequisite.'
Assert-Template ($readmeText.Contains('運用（NAT Gateway あり）') -and $readmeText.Contains('検証（NAT なし）')) 'README must label both Network deployment modes.'
Assert-Template ($day1Text.Contains('defaultOutboundAccess: false') -and $day1Text.Contains('defaultOutboundAccess: true') -and $day1Text.Contains('NAT Gateway')) 'Day 1 guide must explain both Network outbound modes.'
Assert-Template ($day2Text.Contains('VNet 作成方式') -and $day2Text.Contains('IaC') -and $day2Text.Contains('未決定') -and $day2Text.Contains('Public IP') -and $day2Text.Contains('NAT Gateway') -and $day2Text.Contains('Peering') -and $day2Text.Contains('22:00')) 'Day 2 guide must mark VNet creation mode as undecided and retain the secure-jump constraints.'
foreach ($text in @($readmeText, $day1Text)) {
    Assert-Template ($text.Contains('Network Resource Group Name') -and $text.Contains('rg-avd') -and $text.Contains('rg-network')) 'Explain the VM deployment RG and existing VNet RG with distinct examples.'
    Assert-Template ($text.Contains('Ctrl＋クリック') -and $text.Contains('新しいタブでリンクを開く') -and $text.Contains('Command＋クリック')) 'Document a reliable new-tab operation instead of promising target=_blank on GitHub.'
    Assert-Template ($text.Contains('空欄') -and $text.Contains('日本語') -and $text.Contains('英語')) 'Explain how an empty script URL skips Japanese configuration for English deployments.'
    Assert-Template ($text.Contains('enablecredsspsupport:i:1') -and $text.Contains('videoplaybackmode:i:1')) 'Document the two explicitly restored RDP defaults.'
    Assert-Template ($text.Contains('37項目') -and $text.Contains('未構成') -and $text.Contains('自由入力')) 'Document all deployment-time RDP choices, their unconfigured defaults and custom-value inputs.'
    Assert-Template ($text.Contains($settings.avd.customConfigurationScriptUrl) -and $text.Contains('scripts/JPNOFLNG.ps1')) 'Both guides must show the immutable default and link to the bundled Japanese script.'
    Assert-Template ($text.Contains('OS 日本語化') -and $text.Contains('別途 Intune')) 'Do not imply the OS script also localizes Microsoft 365 Apps.'
    Assert-Template ($text -match '(?s)`snet-cloudpc`／`10\.10\.1\.0/24`.*?`snet-avd`／`10\.10\.2\.0/24`.*?`snet-server`／`10\.10\.3\.0/24`') 'Guides must use the slide-aligned subnet mappings and order.'
    Assert-Template ($text.Contains('使用中の旧 VNet') -and $text.Contains('NIC') -and $text.Contains('ANC')) 'Warn against blindly reapplying new CIDRs to an occupied old VNet.'
    Assert-Template ($text.Contains('redirectclipboard:i:0') -and $text.Contains('再接続') -and $text.Contains('グループ ポリシー')) 'Explain the disabled clipboard default, later changes, reconnect and policy precedence.'
    Assert-Template ($text.Contains('Office 利用ライセンスは付与されません') -and $text.Contains('Custom Configuration Script Url') -and $text.Contains('Vm Number Of Instances')) 'Explain licensing and optional script/count inputs.'
}
Assert-Template ($entry.resources.Count -eq 1) 'AVD entry must contain one embedded module.'
$deployment = $entry.resources[0]
Assert-Template ($deployment.type -eq 'Microsoft.Resources/deployments' -and -not $deployment.properties.ContainsKey('templateLink')) 'AVD must use an embedded template, not a remote dependency.'
Assert-Template ($deployment.properties.mode -eq 'Incremental') 'AVD module must not delete unrelated resources.'
Assert-Template ($deployment.properties.parameters.avdUsersGroupObjectId.value -ceq "[parameters('avdUsersGroupObjectId')]") 'Forward the required AVD Users group Object ID.'
Assert-Template ($deployment.properties.parameters.vmAdministratorAccountPassword.value -ceq "[parameters('vmAdministratorAccountPassword')]") 'Forward the secure password directly.'
foreach ($name in $expectedDefaults.Keys) {
    Assert-Template ($deployment.properties.parameters[$name].value -ceq "[parameters('$name')]") "Forward the editable parameter to the AVD module: $name."
}
foreach ($name in $rdpParameterOrder) {
    Assert-Template ($deployment.properties.parameters[$name].value -ceq "[parameters('$name')]") "Forward the editable RDP parameter to the AVD module: $name."
}

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
Assert-Template ($hosts[0].properties.hostPoolType -ceq "[parameters('hostpoolType')]" -and $hosts[0].properties.managementType -eq 'Standard') 'Pool type must be editable while management stays Standard.'
Assert-Template ($hosts[0].properties.loadBalancerType -ceq "[if(equals(parameters('hostpoolType'), 'Personal'), 'Persistent', parameters('loadBalancerType'))]") 'Pooled must use the selected algorithm; Personal must use Persistent.'
Assert-Template ($hosts[0].properties.personalDesktopAssignmentType -ceq "[if(equals(parameters('hostpoolType'), 'Personal'), 'Automatic', null())]") 'Personal must use automatic desktop assignment; Pooled must not configure it.'
Assert-Template ($hosts[0].properties.maxSessionLimit -ceq "[if(equals(parameters('hostpoolType'), 'Personal'), 1, parameters('maxSessionLimit'))]") 'Use the editable Pooled session limit and one session for Personal.'
Assert-Template ($hosts[0].properties.customRdpProperty -ceq "[variables('rdpProperties')]") 'The host pool must receive the composed RDP properties.'
$rdpExpression = ConvertTo-Json -InputObject $avd.variables -Depth 100 -Compress
$supportedRdpProperties = @('alternate shell', 'enablecredsspsupport', 'enablerdsaadauth', 'kdcproxyname', 'targetisaadjoined', 'autoreconnection enabled', 'bandwidthautodetect', 'compression', 'networkautodetect', 'videoplaybackmode', 'audiocapturemode', 'audiomode', 'camerastoredirect', 'devicestoredirect', 'drivestoredirect', 'encode redirected video capture', 'keyboardhook', 'redirectclipboard', 'redirectcomports', 'redirected video capture encoding quality', 'redirectlocation', 'redirectprinters', 'redirectsmartcards', 'redirectwebauthn', 'SmartRawPrinters', 'usbdevicestoredirect', 'desktop size id', 'desktopheight', 'desktopscalefactor', 'desktopwidth', 'dynamic resolution', 'maximizetocurrentdisplays', 'screen mode id', 'selectedmonitors', 'singlemoninwindowedmode', 'smart sizing', 'use multimon')
foreach ($property in $supportedRdpProperties) {
    Assert-Template ($rdpExpression.Contains($property)) "Compose the selected value for every AVD-supported RDP property: $property."
}
Assert-Template ($supportedRdpProperties.Count -eq 37) 'Cover the complete supported AVD RDP property list, excluding RemoteApp-only properties.'
Assert-Template ($rdpExpression.Contains('enablecredsspsupport') -and $rdpExpression.Contains('videoplaybackmode') -and $rdpExpression.Contains('redirectclipboard') -and $rdpExpression.Contains('audiomode')) 'Preserve the current CredSSP, video playback, clipboard and audio properties in the composed settings.'
Assert-Template ($hosts[0].properties.registrationInfo.expirationTime -ceq "[parameters('tokenExpirationTime')]") 'Host pool must use the relative expiry.'
Assert-Template ($dags[0].properties.applicationGroupType -eq 'Desktop' -and $dags[0].properties.hostPoolArmPath -match 'hostPools') 'DAG must belong to the host pool.'
Assert-Template ($workspaces[0].properties.applicationGroupReferences.Count -eq 1 -and $workspaces[0].properties.applicationGroupReferences[0] -match 'applicationGroups') 'DAG must be registered in the workspace.'
Assert-Template ($workspaces[0].properties.friendlyName -ceq "[parameters('workspaceFriendlyName')]") 'Workspace display name must use the editable parameter.'

$sessionModule = @($avd.resources | Where-Object { $_.type -eq 'Microsoft.Resources/deployments' })
Assert-Template ($sessionModule.Count -eq 1 -and -not $sessionModule[0].properties.ContainsKey('templateLink')) 'AVD must embed its shared session-host module.'
Assert-Template ($sessionModule[0].properties.parameters.registrationToken.value -match 'listRegistrationTokens') 'AVD must mint its registration token for the new host.'
Assert-Template ($sessionModule[0].properties.parameters.autoShutdownTime.value -ceq "[parameters('autoShutdownTime')]") 'Forward the editable shutdown time into each AVD session host.'
$sessionHost = $sessionModule[0].properties.template
Assert-Template ($sessionHost.parameters.registrationToken.type -eq 'securestring' -and $sessionHost.parameters.vmAdministratorAccountPassword.type -eq 'securestring') 'Nested session-host secrets must remain secure parameters.'
$vms = Find-Resources $sessionHost 'Microsoft.Compute/virtualMachines'
$nics = Find-Resources $sessionHost 'Microsoft.Network/networkInterfaces'
Assert-Template ($vms.Count -eq 1 -and $nics.Count -eq 1 -and -not $vms[0].ContainsKey('copy')) 'Deploy exactly one session host and NIC.'
Assert-Template ($sessionHost.variables.vmName -ceq "[format('{0}-{1}', parameters('vmNamePrefix'), parameters('vmIndex'))]") 'Append the per-instance index to the editable VM name prefix.'
$vm = $vms[0]
Assert-Template ($vm.identity.type -eq 'SystemAssigned' -and $vm.properties.licenseType -eq 'Windows_Client') 'Expected system identity and Windows client licensing.'
Assert-Template ($vm.properties.hardwareProfile.vmSize -ceq "[parameters('vmSize')]") 'VM size must use the editable parameter.'
Assert-Template ($vm.properties.storageProfile.imageReference.publisher -ceq "[variables('settings').avd.imagePublisher]" -and $vm.properties.storageProfile.imageReference.offer -ceq "[variables('imageOffer')]") 'Image publisher stays fixed and offer must use the SKU mapping.'
Assert-Template ($sessionHost.variables.imageOffer -ceq "[if(endsWith(parameters('imageSku'), '-m365'), 'office-365', variables('settings').avd.imageOffer)]") 'M365 images must use office-365, not windows-11.'
Assert-Template ($vm.properties.storageProfile.imageReference.sku -ceq "[parameters('imageSku')]" -and $vm.properties.storageProfile.imageReference.version -ceq "[variables('settings').avd.imageVersion]") 'Image SKU must be editable while version stays fixed.'
Assert-Template ($vm.properties.storageProfile.osDisk.diskSizeGB -ceq "[variables('settings').avd.vmDiskSizeGB]" -and $vm.properties.storageProfile.osDisk.managedDisk.storageAccountType -ceq "[parameters('vmDiskType')]") 'Disk size must remain fixed and type must be editable.'
Assert-Template ($vm.properties.osProfile.adminUsername -ceq "[variables('settings').avd.vmAdminUsername]" -and $vm.properties.osProfile.adminPassword -ceq "[parameters('vmAdministratorAccountPassword')]") 'Use the fixed username and secure password.'
Assert-Template ($vm.properties.securityProfile.securityType -eq 'TrustedLaunch' -and $vm.properties.securityProfile.uefiSettings.secureBootEnabled -eq $true -and $vm.properties.securityProfile.uefiSettings.vTpmEnabled -eq $true) 'Trusted Launch, Secure Boot and vTPM must be enabled.'
$ip = $nics[0].properties.ipConfigurations[0].properties
Assert-Template (-not $ip.ContainsKey('publicIPAddress') -and $ip.privateIPAllocationMethod -eq 'Dynamic') 'No VM public IP is allowed.'
Assert-Template ($ip.subnet.id -match "parameters\('networkResourceGroupName'\)" -and $ip.subnet.id -match "parameters\('virtualNetworkName'\)" -and $ip.subnet.id -match "parameters\('subnetName'\)" -and $ip.subnet.id -match 'extensionResourceId') 'NIC must resolve the editable VNet RG, VNet and subnet.'

$desktopRoles = Find-Resources $avd 'Microsoft.Authorization/roleAssignments'
$loginRoles = Find-Resources $sessionHost 'Microsoft.Authorization/roleAssignments'
Assert-Template ($desktopRoles.Count -eq 1 -and $loginRoles.Count -eq 1) 'Expected one desktop access and one VM login assignment.'
Assert-Template ($avd.variables.desktopUserRoleId -match '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63' -and $sessionHost.variables.vmUserLoginRoleId -match 'fb879df8-f326-4884-b1cf-06f3ad86be52') 'Use the correct built-in roles.'
foreach ($role in @($desktopRoles) + @($loginRoles)) {
    Assert-Template ($role.properties.principalId -ceq "[parameters('avdUsersGroupObjectId')]" -and $role.properties.principalType -eq 'Group') 'Both roles must target the existing AVD Users security group.'
    Assert-Template ($role.name -match "guid\(.*parameters\('avdUsersGroupObjectId'\)") 'Role names must be deterministic for each group and scope.'
}
Assert-Template ($desktopRoles[0].scope -match 'applicationGroups' -and $loginRoles[0].scope -match 'virtualMachines') 'Assign desktop and VM login roles at their respective resource scopes.'

$extensions = Find-Resources $sessionHost 'Microsoft.Compute/virtualMachines/extensions'
$join = @($extensions | Where-Object { $_.properties.type -eq 'AADLoginForWindows' })
$dsc = @($extensions | Where-Object { $_.properties.type -eq 'DSC' })
$custom = @($extensions | Where-Object { $_.properties.type -eq 'CustomScriptExtension' })
Assert-Template ($extensions.Count -eq 3 -and $join.Count -eq 1 -and $dsc.Count -eq 1 -and $custom.Count -eq 1) 'Expected Entra join, registration and article custom configuration.'
Assert-Template ($join[0].properties.typeHandlerVersion -eq '2.0') 'Use the SSO-capable Entra join extension.'
$joinSettings = ConvertTo-Json -InputObject $join[0].properties.settings -Depth 100 -Compress
Assert-Template ($joinSettings -match "parameters\('intune'\)" -and $joinSettings.Contains('0000000a-0000-0000-c000-000000000000') -and $joinSettings -match 'null\(\)') 'Request Intune MDM enrollment through the Entra join extension only when enabled.'
Assert-Template ($dsc[0].properties.settings.properties.aadJoin -eq $true -and $dsc[0].properties.settings.properties.UseAgentDownloadEndpoint -eq $true) 'Registration must use Entra join and the agent download endpoint.'
Assert-Template ($dsc[0].properties.settings.modulesUrl -ceq "[variables('settings').avd.configurationPackageUrl]") 'Use the configured DSC package.'
Assert-Template ($dsc[0].properties.settings.configurationFunction -ceq 'Configuration.ps1\AddSessionHost') 'Use the supported DSC registration function.'
Assert-Template (($dsc[0].properties.settings | ConvertTo-Json -Depth 100) -notmatch 'registrationInfoToken') 'Registration tokens must not be in public settings.'
Assert-Template ($dsc[0].properties.protectedSettings.properties.registrationInfoToken -ceq "[parameters('registrationToken')]") 'Only pass the registration token through protected settings.'
Assert-Template (($dsc[0].dependsOn -join ' ') -match 'AADLoginForWindows' -and ($custom[0].dependsOn -join ' ') -match 'MicrosoftPowershellDSC') 'Enforce Entra join, then registration, then custom configuration.'
Assert-Template ($custom[0].condition -ceq "[not(empty(parameters('customConfigurationScriptUrl')))]") 'An empty URL must skip Custom Script Extension, not identity or registration.'
Assert-Template ($custom[0].properties.protectedSettings.fileUris.Count -eq 1 -and $custom[0].properties.protectedSettings.fileUris[0] -ceq "[parameters('customConfigurationScriptUrl')]") 'Use the selected script URL only in protected settings.'
foreach ($resource in $sessionHost.resources) {
    if ($resource -ne $custom[0]) {
        Assert-Template (-not $resource.ContainsKey('condition')) 'Script omission must not skip VM, NIC, login, registration, RBAC, or shutdown.'
    }
}

$sessionEntry = $templates['session-host']
Assert-Template ($sessionEntry.parameters.Count -eq 16 -and $sessionEntry.parameters.registrationToken.type -eq 'securestring' -and -not $sessionEntry.parameters.registrationToken.ContainsKey('defaultValue')) 'The add-host template must require a secure registration token and AVD Users group ID and expose script/count/Intune/shutdown-time options.'
Assert-Template ($sessionEntry.parameters.avdUsersGroupObjectId.type -eq 'string' -and $sessionEntry.parameters.avdUsersGroupObjectId.minLength -eq 36 -and $sessionEntry.parameters.avdUsersGroupObjectId.maxLength -eq 36 -and -not $sessionEntry.parameters.avdUsersGroupObjectId.ContainsKey('defaultValue')) 'The add-host template must require the existing AVD Users group Object ID.'
Assert-Template ($sessionEntry.parameters.avdUsersGroupObjectId.metadata.displayName -ceq 'AVD Users Group Object Id') 'The add-host template must clearly label the AVD Users group Object ID.'
Assert-Template ($sessionEntry.parameters.intune.type -eq 'bool' -and $sessionEntry.parameters.intune.defaultValue -eq $true) 'The add-host template must request Intune enrollment by default.'
Assert-Template ($sessionEntry.parameters.autoShutdownTime.defaultValue -ceq '19:00' -and $sessionEntry.parameters.autoShutdownTime.metadata.displayName -ceq 'Auto Shutdown Time (JST)') 'The add-host template must expose a 19:00 Japan-time shutdown default.'
Assert-Template (-not $sessionEntry.parameters.ContainsKey('hostpoolType') -and -not $sessionEntry.parameters.ContainsKey('loadBalancerType')) 'Adding hosts must not offer to change existing pool properties.'
Assert-Template ($sessionEntry.parameters.vmAdministratorAccountPassword.type -eq 'securestring' -and -not $sessionEntry.parameters.vmAdministratorAccountPassword.ContainsKey('defaultValue')) 'The add-host template must require a secure VM password.'
Assert-Template ($sessionEntry.resources.Count -eq 1 -and $sessionEntry.resources[0].type -eq 'Microsoft.Resources/deployments') 'The add-host entry must use one embedded module.'
$addHostDeployment = $sessionEntry.resources[0]
Assert-Template (-not $addHostDeployment.properties.ContainsKey('templateLink') -and $addHostDeployment.properties.mode -eq 'Incremental') 'The add-host template must be embedded and incremental.'
Assert-Template ($addHostDeployment.properties.parameters.autoShutdownTime.value -ceq "[parameters('autoShutdownTime')]") 'Forward the editable shutdown time into the add-host module.'
Assert-Template ($addHostDeployment.properties.parameters.avdUsersGroupObjectId.value -ceq "[parameters('avdUsersGroupObjectId')]") 'The add-host VM login role must target the supplied AVD Users group.'
Assert-Template ($addHostDeployment.properties.parameters.registrationToken.value -ceq "[parameters('registrationToken')]") 'Forward the secure registration token directly.'
$addHostLeaf = $addHostDeployment.properties.template
Assert-Template ($addHostLeaf.parameters.registrationToken.type -eq 'securestring' -and $addHostLeaf.parameters.vmAdministratorAccountPassword.type -eq 'securestring') 'Add-host nested secrets must remain secure parameters.'
Assert-Template (@($addHostLeaf.resources | Where-Object { $_.type -match 'Microsoft.DesktopVirtualization/(hostPools|applicationGroups|workspaces)' }).Count -eq 0) 'Adding a host must not create or update the host pool, DAG or workspace.'
$addHostDsc = @($addHostLeaf.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/extensions' -and $_.properties.type -eq 'DSC' })
Assert-Template ($addHostLeaf.parameters.hostPoolName.type -eq 'string' -and $addHostDsc.Count -eq 1 -and $addHostDsc[0].properties.settings.properties.hostPoolName -ceq "[parameters('hostPoolName')]") 'The add-host template must register with the selected existing pool.'
Assert-Template ((Convert-CompactJson $sessionHost) -ceq (Convert-CompactJson $addHostLeaf)) 'Initial and added hosts must embed the identical shared leaf implementation.'

foreach ($template in @($entry, $sessionEntry)) {
    Assert-Template (($template.parameters.imageSku.allowedValues -join ',') -ceq ($imageSkus -join ',')) 'Both entry points must expose the same eight SKU selections.'
    Assert-Template ($template.parameters.imageSku.defaultValue -ceq 'win11-25h2-avd-m365') 'Both entry points must default to the Office-equipped 25H2 image.'
    Assert-Template ($template.parameters.customConfigurationScriptUrl.defaultValue -ceq $settings.avd.customConfigurationScriptUrl -and -not $template.parameters.customConfigurationScriptUrl.ContainsKey('minLength')) 'Preserve Japanese script by default and allow an empty URL.'
    Assert-Template ($template.parameters.vmNumberOfInstances.defaultValue -eq 1 -and $template.parameters.vmNumberOfInstances.minValue -eq 1 -and $template.parameters.vmNumberOfInstances.maxValue -eq 10) 'Allow 1-10 instances with default 1.'
    Assert-Template ($template.parameters.networkResourceGroupName.defaultValue -ceq '[resourceGroup().name]' -and $template.parameters.networkResourceGroupName.metadata.displayName -ceq 'Network Resource Group Name') 'Preserve the same-RG default while labeling the VNet RG field clearly.'
}
foreach ($parent in @($avd, $sessionEntry)) {
    $loop = @(Find-Resources $parent 'Microsoft.Resources/deployments')[0]
    Assert-Template ($loop.copy.count -ceq "[length(range(0, parameters('vmNumberOfInstances')))]") 'Instantiate the shared VM/NIC/extensions/RBAC/shutdown module exactly once per requested VM.'
    Assert-Template ($loop.properties.parameters.vmIndex.value -ceq "[range(0, parameters('vmNumberOfInstances'))[copyIndex()]]") 'Pass a unique zero-based index to every leaf.'
    Assert-Template ($loop.name -match "range\(0, parameters\('vmNumberOfInstances'\)\)\[copyIndex\(\)\]") 'Nested deployment names must be distinct per VM.'
    Assert-Template ($loop.properties.parameters.customConfigurationScriptUrl.value -ceq "[parameters('customConfigurationScriptUrl')]") 'Forward the script choice to every VM.'
    Assert-Template ($loop.properties.parameters.intune.value -ceq "[parameters('intune')]") 'Forward the Intune enrollment choice to every VM.'
    Assert-Template ($parent.outputs.sessionHostName.type -eq 'string' -and $parent.outputs.sessionHostName.value -match "\[0\]") 'Retain the first-host string output for compatibility.'
    Assert-Template ($parent.outputs.sessionHostNames.type -eq 'array' -and $parent.outputs.sessionHostNames.copy.count -ceq $loop.copy.count) 'Return every created name in the array output.'
}
Assert-Template ($entry.outputs.sessionHostNames.type -eq 'array' -and $entry.outputs.sessionHostNames.value -match '\.outputs\.sessionHostNames\.value') 'Expose the complete name array from the initial AVD entry.'
Assert-Template ($sessionHost.parameters.vmIndex.minValue -eq 0 -and $sessionHost.parameters.vmIndex.maxValue -eq 9) 'Limit leaf indexes so a 13-character prefix fits a Windows computer name.'
foreach ($count in @(1, 2, 10)) {
    Assert-Template ($sessionHost.variables.vmName -match "^\[format\('([^']+)', parameters\('vmNamePrefix'\), parameters\('vmIndex'\)\)\]$") 'The compiled VM naming expression must use exactly the prefix and loop index.'
    $nameFormat = $Matches[1]
    $names = @(0..($count - 1) | ForEach-Object { $nameFormat -f 'AVD1015214700', $_ })
    Assert-Template ($names.Count -eq $count -and @($names | Select-Object -Unique).Count -eq $count -and @($names | Where-Object Length -gt 15).Count -eq 0) "The compiled prefix/index contract must produce $count unique names within 15 characters."
}
Assert-Template ($vm.name -ceq "[variables('vmName')]" -and $nics[0].name -ceq "[format('{0}-nic', variables('vmName'))]") 'Every loop iteration must name its VM and NIC from the indexed VM name.'
Assert-Template ($loginRoles[0].scope -ceq "[resourceId('Microsoft.Compute/virtualMachines', variables('vmName'))]") 'Per-host login access must target the indexed VM, not the first host.'
foreach ($extension in $extensions) {
    Assert-Template ($extension.name -match "^\[format\('\{0\}/\{1\}', variables\('vmName'\), '") 'Each extension must be parented to its indexed VM.'
}

$scriptCommand = $custom[0].properties.protectedSettings.commandToExecute
Assert-Template ($scriptCommand -match '^powershell -NoProfile -ExecutionPolicy Bypass -Command "(.+)"$') 'Execute the downloaded script using a single explicit PowerShell command.'
$scriptBody = $Matches[1]
Assert-Template ($scriptBody -notmatch 'JPNOFLNG|Invoke-Expression|DownloadString') 'Do not hard-code a filename or evaluate a URL as code.'
$scriptFixture = Join-Path ([System.IO.Path]::GetTempPath()) ('avd-custom-script-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scriptFixture | Out-Null
Push-Location $scriptFixture
try {
    $file = Join-Path $scriptFixture 'Different Configuration.ps1'
    $marker = Join-Path $scriptFixture 'script-ran.txt'
    Set-Content -LiteralPath $file -Value "Set-Content -LiteralPath '.\script-ran.txt' -Value 'ran alternate script'"
    $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptBody 2>&1
    Assert-Template ($LASTEXITCODE -eq 0 -and (Get-Content -LiteralPath $marker -Raw).Trim() -ceq 'ran alternate script') 'An alternate .ps1 filename with spaces must actually run.'
    Set-Content -LiteralPath $file -Value "throw 'intentional fixture failure'"
    $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptBody 2>&1
    Assert-Template ($LASTEXITCODE -ne 0 -and ($result -join ' ') -match 'intentional fixture failure') 'A script failure must return a failing process exit code.'
    Set-Content -LiteralPath $file -Value 'exit 7'
    $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptBody 2>&1
    Assert-Template ($LASTEXITCODE -eq 7) 'An explicit script exit code must propagate to Custom Script Extension.'
    Remove-Item -LiteralPath $file
    $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptBody 2>&1
    Assert-Template ($LASTEXITCODE -ne 0 -and ($result -join ' ') -match 'Expected exactly one') 'A missing downloaded script must fail explicitly.'
    Set-Content -LiteralPath $file -Value "'unused'"
    Set-Content -LiteralPath (Join-Path $scriptFixture 'Unexpected.ps1') -Value "'unused'"
    $result = & powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptBody 2>&1
    Assert-Template ($LASTEXITCODE -ne 0 -and ($result -join ' ') -match 'Expected exactly one') 'Ambiguous downloaded scripts must fail rather than run an arbitrary file.'
} finally {
    Pop-Location
    Remove-Item -LiteralPath $scriptFixture -Recurse -Force
}

foreach ($template in @($sessionHost, $addHostLeaf)) {
    $schedules = Find-Resources $template 'Microsoft.DevTestLab/schedules'
    Assert-Template ($schedules.Count -eq 1) 'Each session-host workflow must configure one VM shutdown schedule.'
    Assert-Template ($schedules[0].properties.dailyRecurrence.time -ceq "[replace(parameters('autoShutdownTime'), ':', '')]" -and $schedules[0].properties.timeZoneId -eq 'Tokyo Standard Time') 'Convert the editable HH:mm input to the schedule API format in Japan Standard Time.'
    Assert-Template ($schedules[0].properties.taskType -eq 'ComputeVmShutdownTask' -and $schedules[0].properties.status -eq 'Enabled') 'Enable the VM shutdown task.'
    Assert-Template ($schedules[0].properties.targetResourceId -match 'virtualMachines') 'Target the created VM with the shutdown schedule.'
    Assert-Template ($schedules[0].name -ceq "[format('shutdown-computevm-{0}', variables('vmName'))]" -and $schedules[0].properties.targetResourceId -ceq "[resourceId('Microsoft.Compute/virtualMachines', variables('vmName'))]") 'Shutdown must be distinct for every indexed VM and target that same VM.'
}

foreach ($phase in @('network', 'network-validation')) {
    $networkCore = $templates[$phase].resources[0].properties.template
    foreach ($resource in @($networkCore.resources | Where-Object { $_.ContainsKey('location') })) {
        Assert-Template ($resource.location -ceq "[parameters('location')]") "$phase resources must use the editable location."
    }
}

$liveReadme = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw
$liveManifest = Read-Json (Join-Path $root 'resources\deploy-links.json')
Assert-Template (($liveManifest.orderedDay1Phases -join ',') -ceq 'manual-prerequisites-and-resource-group,network-deploy-to-azure,windows365-owner-part,avd-deploy-to-azure') 'Preserve the Day 1 phase order.'
Assert-Template ($liveManifest.publication.rawUrlsVerified -eq $false -or $liveManifest.publication.repository) 'Verified publication must identify its repository.'
if ($liveManifest.publication.repository) {
    Assert-Template ($liveManifest.publication.templateCommit -cmatch '^[0-9a-f]{40}$') 'Published buttons must pin an immutable template commit.'
}
if ($liveManifest.publication.rawUrlsVerified) {
    Assert-Template ($liveManifest.status -ceq 'published-templates-urls-verified-not-azure-validated') 'Distinguish verified template publication from Azure runtime validation.'
    foreach ($text in @($readmeText, $day1Text)) {
        Assert-Template ($text.Contains('新版公開済み') -and -not $text.Contains('ローカル更新版・未公開')) 'Published guides must describe the available updated inputs.'
    }
}
foreach ($phase in @('network', 'network-validation', 'avd', 'session-host')) {
    $link = @($liveManifest.links | Where-Object { $_.phase -eq $phase })
    Assert-Template ($liveReadme.Contains("<!-- deploy-button-${phase}:end -->`n`n**Ctrl＋クリック") -or $liveReadme.Contains("<!-- deploy-button-${phase}:end -->`r`n`r`n**Ctrl＋クリック")) 'Keep the new-tab instruction immediately below every deployment button.'
    Assert-Template ($link.Count -eq 1 -and $link[0].localTemplate -eq "templates/$phase.json") 'Metadata must identify each local production template.'
    Assert-Template ($link[0].localTemplateSha256 -eq (Get-FileHash -LiteralPath (Join-Path $root "templates\$phase.json") -Algorithm SHA256).Hash) 'Metadata must record the hash of the current local JSON.'
    if ($liveManifest.publication.repository) {
        $prefix = $liveManifest.publication.templatePathPrefix.Trim('/')
        if ($prefix) { $prefix += '/' }
        $uri = "https://raw.githubusercontent.com/$($liveManifest.publication.repository)/$($liveManifest.publication.templateCommit)/${prefix}templates/$phase.json"
        Assert-Template ($link[0].templateUri -ceq $uri) 'Each template URL must match the publication repository, commit, and path.'
        Assert-Template ($link[0].deployToAzureUrl -ceq ('https://portal.azure.com/#create/Microsoft.Template/uri/' + [uri]::EscapeDataString($uri))) 'Each button must encode its immutable template URL.'
        Assert-Template ($liveReadme.Contains("[![Deploy to Azure](https://aka.ms/deploytoazurebutton)]($($link[0].deployToAzureUrl))")) 'README buttons must match the publication metadata.'
    }
    if (-not $liveManifest.publication.repository) {
        Assert-Template ($null -eq $link[0].templateUri -and $null -eq $link[0].deployToAzureUrl) 'Unpublished templates must not have active deployment URLs.'
        $pattern = "<!-- deploy-button-${phase}:start -->(.*?)<!-- deploy-button-${phase}:end -->"
        $regions = [regex]::Matches($liveReadme, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        Assert-Template ($regions.Count -eq 1) 'Each phase must have one managed README button region.'
        $region = $regions[0].Groups[1].Value
        Assert-Template ($region.Contains('![Deploy to Azure](https://aka.ms/deploytoazurebutton)') -and $region -notmatch '\[!\[Deploy to Azure\]') 'Unpublished badges must be official images without deployment links.'
    }
    if ($liveManifest.status -eq 'local-updates-not-published-buttons-reference-previous-release') {
        Assert-Template ($liveManifest.publication.rawUrlsVerified -eq $false -and $liveReadme.Contains('ローカル更新版・未公開')) 'Do not claim the published URLs match unpublished local templates.'
    }
}

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('avd-production-buttons-' + [guid]::NewGuid().ToString('N'))
$originalReadmeHash = (Get-FileHash -LiteralPath (Join-Path $root 'README.md')).Hash
$originalManifestHash = (Get-FileHash -LiteralPath (Join-Path $root 'resources\deploy-links.json')).Hash
function Reset-ButtonFixture {
    foreach ($directory in @('scripts', 'resources', 'templates')) {
        New-Item -ItemType Directory -Path (Join-Path $fixture $directory) -Force | Out-Null
    }
    foreach ($relative in @('README.md', 'resources\deploy-links.json', 'scripts\Set-DeployButtons.ps1', 'templates\network.json', 'templates\network-validation.json', 'templates\avd.json', 'templates\session-host.json')) {
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
    foreach ($phase in @('network', 'network-validation', 'avd', 'session-host')) {
        $link = @($configured.links | Where-Object { $_.phase -eq $phase })[0]
        $uri = "https://raw.githubusercontent.com/example-org/example-avd/$($arguments.TemplateCommit.ToLowerInvariant())/avd-hands-on/production/templates/$phase.json"
        Assert-Template ($link.templateUri -ceq $uri) 'Button template URI must use a fixed commit and prefix.'
        Assert-Template ($link.deployToAzureUrl -ceq ('https://portal.azure.com/#create/Microsoft.Template/uri/' + [uri]::EscapeDataString($uri))) 'Use the official encoded portal URL.'
        Assert-Template ($configuredReadme.Contains("[![Deploy to Azure](https://aka.ms/deploytoazurebutton)]($($link.deployToAzureUrl))")) 'README must contain the matching official button.'
        Assert-Template ($configuredReadme.Contains("<!-- deploy-button-${phase}:end -->`n`n**Ctrl＋クリック") -or $configuredReadme.Contains("<!-- deploy-button-${phase}:end -->`r`n`r`n**Ctrl＋クリック")) 'Regenerating links must preserve each per-button Ctrl-click instruction.'
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
    $fixtureManifest.links += @($fixtureManifest.links | Where-Object { $_.phase -eq 'avd' })[0]
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
