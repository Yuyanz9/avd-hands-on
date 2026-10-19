targetScope = 'resourceGroup'

@description('Local VM administrator password. Do not use or store the tenant account password.')
@secure()
@minLength(12)
@maxLength(123)
param vmAdministratorAccountPassword string

@metadata({ displayName: 'AVD Users Group Object Id' })
@description('Object ID of the existing Entra security group named AVD Users. Create the group manually before deployment.')
@minLength(36)
@maxLength(36)
param avdUsersGroupObjectId string

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

@metadata({ displayName: 'Auto Shutdown Time (JST)' })
@description('Daily VM shutdown time in 24-hour HH:mm format, Japan Standard Time. Default is 19:00.')
@minLength(5)
@maxLength(5)
param autoShutdownTime string = '19:00'

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

module avd './modules/avd.bicep' = {
  name: 'avd-editable-configuration'
  params: {
    vmAdministratorAccountPassword: vmAdministratorAccountPassword
    avdUsersGroupObjectId: avdUsersGroupObjectId
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
    autoShutdownTime: autoShutdownTime
    rdpAlternateShell: rdpAlternateShell
    rdpEnableCredSspSupport: rdpEnableCredSspSupport
    rdpEnableEntraIdAuth: rdpEnableEntraIdAuth
    rdpKdcProxyName: rdpKdcProxyName
    rdpTargetIsAadJoined: rdpTargetIsAadJoined
    rdpAutoReconnectionEnabled: rdpAutoReconnectionEnabled
    rdpBandwidthAutoDetect: rdpBandwidthAutoDetect
    rdpCompression: rdpCompression
    rdpNetworkAutoDetect: rdpNetworkAutoDetect
    rdpVideoPlaybackMode: rdpVideoPlaybackMode
    rdpAudioCaptureMode: rdpAudioCaptureMode
    rdpAudioMode: rdpAudioMode
    rdpCameraStoreDirect: rdpCameraStoreDirect
    rdpDeviceStoreDirect: rdpDeviceStoreDirect
    rdpDeviceStoreDirectCustom: rdpDeviceStoreDirectCustom
    rdpDriveStoreDirect: rdpDriveStoreDirect
    rdpDriveStoreDirectCustom: rdpDriveStoreDirectCustom
    rdpEncodeRedirectedVideoCapture: rdpEncodeRedirectedVideoCapture
    rdpKeyboardHook: rdpKeyboardHook
    rdpRedirectClipboard: rdpRedirectClipboard
    rdpRedirectComPorts: rdpRedirectComPorts
    rdpRedirectedVideoCaptureEncodingQuality: rdpRedirectedVideoCaptureEncodingQuality
    rdpRedirectLocation: rdpRedirectLocation
    rdpRedirectPrinters: rdpRedirectPrinters
    rdpRedirectSmartCards: rdpRedirectSmartCards
    rdpRedirectWebAuthn: rdpRedirectWebAuthn
    rdpSmartRawPrinters: rdpSmartRawPrinters
    rdpUsbDeviceStoreDirect: rdpUsbDeviceStoreDirect
    rdpUsbDeviceStoreDirectCustom: rdpUsbDeviceStoreDirectCustom
    rdpDesktopSizeId: rdpDesktopSizeId
    rdpDesktopHeight: rdpDesktopHeight
    rdpDesktopScaleFactor: rdpDesktopScaleFactor
    rdpDesktopWidth: rdpDesktopWidth
    rdpDynamicResolution: rdpDynamicResolution
    rdpMaximizeToCurrentDisplays: rdpMaximizeToCurrentDisplays
    rdpScreenModeId: rdpScreenModeId
    rdpSelectedMonitors: rdpSelectedMonitors
    rdpSingleMonInWindowedMode: rdpSingleMonInWindowedMode
    rdpSmartSizing: rdpSmartSizing
    rdpUseMultimon: rdpUseMultimon
  }
}

output hostpoolName string = avd.outputs.hostpoolName
output workspaceName string = avd.outputs.workspaceName
output sessionHostName string = avd.outputs.sessionHostName
output sessionHostNames array = avd.outputs.sessionHostNames
