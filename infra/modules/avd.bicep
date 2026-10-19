targetScope = 'resourceGroup'

@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@minLength(36)
@maxLength(36)
param avdUsersGroupObjectId string

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
param customConfigurationScriptUrl string
@minValue(1)
@maxValue(10)
param vmNumberOfInstances int
@allowed([
  'Pooled'
  'Personal'
])
param hostpoolType string
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancerType string
param intune bool
param autoShutdownTime string

@metadata({ displayName: 'RDP - Alternate Shell' })
@description('空欄は未構成です。指定する場合はリモート セッションで起動する実行ファイルのパスを入力します。')
param rdpAlternateShell string = ''

@metadata({ displayName: 'RDP - CredSSP' })
@description('現在の既定は有効 (1) です。')
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpEnableCredSspSupport string = '有効 (1)'

@metadata({ displayName: 'RDP - Microsoft Entra SSO' })
@description('現在の既定は有効 (1) です。')
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpEnableEntraIdAuth string = '有効 (1)'

@metadata({ displayName: 'RDP - KDC Proxy Name' })
@description('空欄は未構成です。Kerberos KDC プロキシの完全修飾ドメイン名を入力します。')
param rdpKdcProxyName string = ''

@metadata({ displayName: 'RDP - Target Is AAD Joined' })
@description('旧式の認証プロパティです。enablerdsaadauth を優先して使用してください。')
@allowed([
  '未構成'
  'ユーザー名とパスワード (1)'
  'Windows クライアントで Entra 認証 (0)'
])
param rdpTargetIsAadJoined string = '未構成'

@metadata({ displayName: 'RDP - Automatic Reconnection' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpAutoReconnectionEnabled string = '未構成'

@metadata({ displayName: 'RDP - Bandwidth Auto Detect' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpBandwidthAutoDetect string = '未構成'

@metadata({ displayName: 'RDP - Compression' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpCompression string = '未構成'

@metadata({ displayName: 'RDP - Network Auto Detect' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpNetworkAutoDetect string = '未構成'

@metadata({ displayName: 'RDP - Video Playback Mode' })
@description('現在の既定は有効 (1) です。')
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpVideoPlaybackMode string = '有効 (1)'

@metadata({ displayName: 'RDP - Audio Capture Mode' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpAudioCaptureMode string = '未構成'

@metadata({ displayName: 'RDP - Audio Mode' })
@description('現在の既定はローカル端末で再生 (0) です。')
@allowed([
  '未構成'
  'ローカル端末で再生 (0)'
  'リモート セッションで再生 (1)'
  '再生しない (2)'
])
param rdpAudioMode string = 'ローカル端末で再生 (0)'

@metadata({ displayName: 'RDP - Camera Redirection' })
@description('空欄は未構成です。* または対象カメラのデバイス パスを入力します。')
param rdpCameraStoreDirect string = ''

@metadata({ displayName: 'RDP - MTP/PTP Device Redirection' })
@description('特定のデバイスを指定する場合は、下の Custom Device Value を入力します。')
@allowed([
  '未構成'
  'すべての対応デバイス (*)'
  '新しく接続する対応デバイス (DynamicDevices)'
])
param rdpDeviceStoreDirect string = '未構成'

@metadata({ displayName: 'RDP - MTP/PTP Custom Device Value' })
@description('空欄は上の選択を使用します。デバイス パスを指定すると選択より優先されます。')
param rdpDeviceStoreDirectCustom string = ''

@metadata({ displayName: 'RDP - Drive Redirection' })
@description('ドライブ文字を指定する場合は、下の Custom Drive Value を入力します。')
@allowed([
  '未構成'
  'リダイレクトしない (空)'
  'すべてのドライブ (*)'
  '新しく接続するドライブ (DynamicDrives)'
])
param rdpDriveStoreDirect string = '未構成'

@metadata({ displayName: 'RDP - Custom Drive Value' })
@description('空欄は上の選択を使用します。例: C:\\;E:\\;。値を指定すると選択より優先されます。')
param rdpDriveStoreDirectCustom string = ''

@metadata({ displayName: 'RDP - Encode Redirected Video Capture' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpEncodeRedirectedVideoCapture string = '未構成'

@metadata({ displayName: 'RDP - Keyboard Hook' })
@description('値 3 は RemoteApp 専用です。このテンプレートの Desktop セッションでは選択しないでください。')
@allowed([
  '未構成'
  'ローカル端末で処理 (0)'
  'フォーカス中はリモートで処理 (1)'
  '全画面時のみリモートで処理 (2)'
  'RemoteApp で処理 (3)'
])
param rdpKeyboardHook string = '未構成'

@metadata({ displayName: 'RDP - Clipboard Redirection' })
@description('現在の既定は無効 (0) です。')
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpRedirectClipboard string = '無効 (0)'

@metadata({ displayName: 'RDP - COM Port Redirection' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpRedirectComPorts string = '未構成'

@metadata({ displayName: 'RDP - Redirected Video Capture Quality' })
@allowed([
  '未構成'
  '高圧縮 (0)'
  '中圧縮 (1)'
  '高画質 (2)'
])
param rdpRedirectedVideoCaptureEncodingQuality string = '未構成'

@metadata({ displayName: 'RDP - Location Redirection' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpRedirectLocation string = '未構成'

@metadata({ displayName: 'RDP - Printer Redirection' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpRedirectPrinters string = '未構成'

@metadata({ displayName: 'RDP - Smart Card Redirection' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpRedirectSmartCards string = '未構成'

@metadata({ displayName: 'RDP - WebAuthn Redirection' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpRedirectWebAuthn string = '未構成'

@metadata({ displayName: 'RDP - Smart Raw Printers' })
@description('空欄は未構成です。* または対象プリンターのドライバー名プレフィックスを入力します。')
param rdpSmartRawPrinters string = ''

@metadata({ displayName: 'RDP - USB Device Redirection' })
@description('特定のデバイスを指定する場合は、下の Custom USB Device Value を入力します。')
@allowed([
  '未構成'
  'リダイレクトしない (空)'
  'すべての対応 USB デバイス (*)'
])
param rdpUsbDeviceStoreDirect string = '未構成'

@metadata({ displayName: 'RDP - Custom USB Device Value' })
@description('空欄は上の選択を使用します。デバイス クラス GUID またはデバイス インスタンス ID を指定すると選択より優先されます。')
param rdpUsbDeviceStoreDirectCustom string = ''

@metadata({ displayName: 'RDP - Desktop Size ID' })
@allowed([
  '未構成'
  '640x480'
  '800x600'
  '1024x768'
  '1280x1024'
  '1600x1200'
])
param rdpDesktopSizeId string = '未構成'

@metadata({ displayName: 'RDP - Desktop Height' })
@description('0 は未構成です。指定する場合は 200～8192 のピクセル数を入力します。指定時は Desktop Size ID より優先されます。')
@minValue(0)
@maxValue(8192)
param rdpDesktopHeight int = 0

@metadata({ displayName: 'RDP - Desktop Scale Factor' })
@description('0 は未構成です。このプロパティは非推奨です。')
@allowed([
  '未構成'
  '100%'
  '125%'
  '150%'
  '175%'
  '200%'
  '250%'
  '300%'
  '400%'
  '500%'
])
param rdpDesktopScaleFactor string = '未構成'

@metadata({ displayName: 'RDP - Desktop Width' })
@description('0 は未構成です。指定する場合は 200～8192 のピクセル数を入力します。指定時は Desktop Size ID より優先されます。')
@minValue(0)
@maxValue(8192)
param rdpDesktopWidth int = 0

@metadata({ displayName: 'RDP - Dynamic Resolution' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpDynamicResolution string = '未構成'

@metadata({ displayName: 'RDP - Maximize to Current Displays' })
@description('use multimon が有効な場合に利用できます。Windows App for Windows と Windows 用 Remote Desktop アプリのみ対応します。')
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpMaximizeToCurrentDisplays string = '未構成'

@metadata({ displayName: 'RDP - Screen Mode ID' })
@description('use multimon が有効な場合は、この設定より複数ディスプレイ設定が優先されます。')
@allowed([
  '未構成'
  'ウィンドウ (1)'
  '全画面 (2)'
])
param rdpScreenModeId string = '未構成'

@metadata({ displayName: 'RDP - Selected Monitors' })
@description('空欄は未構成です。use multimon が有効な場合に、mstsc.exe /l で取得した連続するディスプレイ ID をカンマ区切りで入力します。Windows クライアント専用です。')
param rdpSelectedMonitors string = ''

@metadata({ displayName: 'RDP - Single Monitor in Windowed Mode' })
@description('use multimon が有効な場合に利用できます。Windows クライアント専用です。')
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpSingleMonInWindowedMode string = '未構成'

@metadata({ displayName: 'RDP - Smart Sizing' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpSmartSizing string = '未構成'

@metadata({ displayName: 'RDP - Use Multiple Monitors' })
@allowed([
  '未構成'
  '有効 (1)'
  '無効 (0)'
])
param rdpUseMultimon string = '未構成'

param tokenExpirationTime string = dateTimeAdd(utcNow(), 'PT2H')

var settings = loadJsonContent('../settings.json')
var desktopUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
var rdpDeviceStoreDirectValue = !empty(rdpDeviceStoreDirectCustom) ? rdpDeviceStoreDirectCustom : (rdpDeviceStoreDirect == 'すべての対応デバイス (*)' ? '*' : (rdpDeviceStoreDirect == '新しく接続する対応デバイス (DynamicDevices)' ? 'DynamicDevices' : ''))
var rdpDeviceStoreDirectProperty = empty(rdpDeviceStoreDirectValue) ? '' : 'devicestoredirect:s:${rdpDeviceStoreDirectValue};'
var rdpDriveStoreDirectProperty = !empty(rdpDriveStoreDirectCustom) ? 'drivestoredirect:s:${rdpDriveStoreDirectCustom};' : (rdpDriveStoreDirect == '未構成' ? '' : (rdpDriveStoreDirect == 'リダイレクトしない (空)' ? 'drivestoredirect:s:;' : (rdpDriveStoreDirect == 'すべてのドライブ (*)' ? 'drivestoredirect:s:*;' : 'drivestoredirect:s:DynamicDrives;')))
var rdpUsbDeviceStoreDirectProperty = !empty(rdpUsbDeviceStoreDirectCustom) ? 'usbdevicestoredirect:s:${rdpUsbDeviceStoreDirectCustom};' : (rdpUsbDeviceStoreDirect == '未構成' ? '' : (rdpUsbDeviceStoreDirect == 'リダイレクトしない (空)' ? 'usbdevicestoredirect:s:;' : 'usbdevicestoredirect:s:*;'))
var rdpProperties = concat(
  rdpEnableEntraIdAuth == '未構成' ? '' : 'enablerdsaadauth:i:${rdpEnableEntraIdAuth == '有効 (1)' ? '1' : '0'};',
  rdpEnableCredSspSupport == '未構成' ? '' : 'enablecredsspsupport:i:${rdpEnableCredSspSupport == '有効 (1)' ? '1' : '0'};',
  rdpVideoPlaybackMode == '未構成' ? '' : 'videoplaybackmode:i:${rdpVideoPlaybackMode == '有効 (1)' ? '1' : '0'};',
  rdpRedirectClipboard == '未構成' ? '' : 'redirectclipboard:i:${rdpRedirectClipboard == '有効 (1)' ? '1' : '0'};',
  rdpAudioMode == '未構成' ? '' : 'audiomode:i:${rdpAudioMode == 'ローカル端末で再生 (0)' ? '0' : (rdpAudioMode == 'リモート セッションで再生 (1)' ? '1' : '2')};',
  rdpAlternateShell == '' ? '' : 'alternate shell:s:${rdpAlternateShell};',
  rdpKdcProxyName == '' ? '' : 'kdcproxyname:s:${rdpKdcProxyName};',
  rdpTargetIsAadJoined == '未構成' ? '' : 'targetisaadjoined:i:${rdpTargetIsAadJoined == 'ユーザー名とパスワード (1)' ? '1' : '0'};',
  rdpAutoReconnectionEnabled == '未構成' ? '' : 'autoreconnection enabled:i:${rdpAutoReconnectionEnabled == '有効 (1)' ? '1' : '0'};',
  rdpBandwidthAutoDetect == '未構成' ? '' : 'bandwidthautodetect:i:${rdpBandwidthAutoDetect == '有効 (1)' ? '1' : '0'};',
  rdpCompression == '未構成' ? '' : 'compression:i:${rdpCompression == '有効 (1)' ? '1' : '0'};',
  rdpNetworkAutoDetect == '未構成' ? '' : 'networkautodetect:i:${rdpNetworkAutoDetect == '有効 (1)' ? '1' : '0'};',
  rdpAudioCaptureMode == '未構成' ? '' : 'audiocapturemode:i:${rdpAudioCaptureMode == '有効 (1)' ? '1' : '0'};',
  rdpCameraStoreDirect == '' ? '' : 'camerastoredirect:s:${rdpCameraStoreDirect};',
  rdpDeviceStoreDirectProperty,
  rdpDriveStoreDirectProperty,
  rdpEncodeRedirectedVideoCapture == '未構成' ? '' : 'encode redirected video capture:i:${rdpEncodeRedirectedVideoCapture == '有効 (1)' ? '1' : '0'};',
  rdpKeyboardHook == '未構成' ? '' : 'keyboardhook:i:${rdpKeyboardHook == 'ローカル端末で処理 (0)' ? '0' : (rdpKeyboardHook == 'フォーカス中はリモートで処理 (1)' ? '1' : (rdpKeyboardHook == '全画面時のみリモートで処理 (2)' ? '2' : '3'))};',
  rdpRedirectComPorts == '未構成' ? '' : 'redirectcomports:i:${rdpRedirectComPorts == '有効 (1)' ? '1' : '0'};',
  rdpRedirectedVideoCaptureEncodingQuality == '未構成' ? '' : 'redirected video capture encoding quality:i:${rdpRedirectedVideoCaptureEncodingQuality == '高圧縮 (0)' ? '0' : (rdpRedirectedVideoCaptureEncodingQuality == '中圧縮 (1)' ? '1' : '2')};',
  rdpRedirectLocation == '未構成' ? '' : 'redirectlocation:i:${rdpRedirectLocation == '有効 (1)' ? '1' : '0'};',
  rdpRedirectPrinters == '未構成' ? '' : 'redirectprinters:i:${rdpRedirectPrinters == '有効 (1)' ? '1' : '0'};',
  rdpRedirectSmartCards == '未構成' ? '' : 'redirectsmartcards:i:${rdpRedirectSmartCards == '有効 (1)' ? '1' : '0'};',
  rdpRedirectWebAuthn == '未構成' ? '' : 'redirectwebauthn:i:${rdpRedirectWebAuthn == '有効 (1)' ? '1' : '0'};',
  rdpSmartRawPrinters == '' ? '' : 'SmartRawPrinters:s:${rdpSmartRawPrinters};',
  rdpUsbDeviceStoreDirectProperty,
  rdpDesktopSizeId == '未構成' ? '' : 'desktop size id:i:${rdpDesktopSizeId == '640x480' ? '0' : (rdpDesktopSizeId == '800x600' ? '1' : (rdpDesktopSizeId == '1024x768' ? '2' : (rdpDesktopSizeId == '1280x1024' ? '3' : '4')))};',
  rdpDesktopHeight == 0 ? '' : 'desktopheight:i:${rdpDesktopHeight};',
  rdpDesktopScaleFactor == '未構成' ? '' : 'desktopscalefactor:i:${replace(rdpDesktopScaleFactor, '%', '')};',
  rdpDesktopWidth == 0 ? '' : 'desktopwidth:i:${rdpDesktopWidth};',
  rdpDynamicResolution == '未構成' ? '' : 'dynamic resolution:i:${rdpDynamicResolution == '有効 (1)' ? '1' : '0'};',
  rdpMaximizeToCurrentDisplays == '未構成' ? '' : 'maximizetocurrentdisplays:i:${rdpMaximizeToCurrentDisplays == '有効 (1)' ? '1' : '0'};',
  rdpScreenModeId == '未構成' ? '' : 'screen mode id:i:${rdpScreenModeId == 'ウィンドウ (1)' ? '1' : '2'};',
  rdpSelectedMonitors == '' ? '' : 'selectedmonitors:s:${rdpSelectedMonitors};',
  rdpSingleMonInWindowedMode == '未構成' ? '' : 'singlemoninwindowedmode:i:${rdpSingleMonInWindowedMode == '有効 (1)' ? '1' : '0'};',
  rdpSmartSizing == '未構成' ? '' : 'smart sizing:i:${rdpSmartSizing == '有効 (1)' ? '1' : '0'};',
  rdpUseMultimon == '未構成' ? '' : 'use multimon:i:${rdpUseMultimon == '有効 (1)' ? '1' : '0'};'
)

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
    hostPoolType: hostpoolType
    managementType: 'Standard'
    loadBalancerType: hostpoolType == 'Personal' ? 'Persistent' : loadBalancerType
    maxSessionLimit: hostpoolType == 'Personal' ? 1 : maxSessionLimit
    personalDesktopAssignmentType: hostpoolType == 'Personal' ? 'Automatic' : null
    preferredAppGroupType: 'Desktop'
    validationEnvironment: false
    startVMOnConnect: false
    publicNetworkAccess: 'Enabled'
    customRdpProperty: rdpProperties
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
  name: guid(desktopApplicationGroup.id, avdUsersGroupObjectId, desktopUserRoleId)
  scope: desktopApplicationGroup
  properties: {
    principalId: avdUsersGroupObjectId
    principalType: 'Group'
    roleDefinitionId: desktopUserRoleId
  }
}

module sessionHost './session-host.bicep' = [for index in range(0, vmNumberOfInstances): {
  name: 'avd-session-host-${index}'
  params: {
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
    registrationToken: hostPool.listRegistrationTokens().value[0].token
    avdUsersGroupObjectId: avdUsersGroupObjectId
    hostPoolName: hostPool.name
    networkResourceGroupName: networkResourceGroupName
    virtualNetworkName: virtualNetwork.name
    subnetName: sessionHostSubnet.name
    location: location
    imageSku: imageSku
    vmSize: vmSize
    vmDiskType: vmDiskType
    vmNamePrefix: vmNamePrefix
    vmIndex: index
    customConfigurationScriptUrl: customConfigurationScriptUrl
    intune: intune
    autoShutdownTime: autoShutdownTime
  }
}]

output hostpoolName string = hostPool.name
output workspaceName string = workspace.name
output sessionHostName string = sessionHost[0].outputs.sessionHostName
output sessionHostNames array = [for index in range(0, vmNumberOfInstances): sessionHost[index].outputs.sessionHostName]
