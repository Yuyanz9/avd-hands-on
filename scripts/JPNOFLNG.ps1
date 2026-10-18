# OS Japanese localization example by carol0226.
# Public reference: https://qiita.com/carol0226/items/f7770369947aaf4962f7
# Windows only; Microsoft 365 Apps language configuration is a separate Intune task.
# Runs Windows Update with automatic restart. For session hosts, not the authoring PC.

# ログのパス設定
mkdir c:\DeployLog
$FILENAME = $env:Computername
$log = "c:\DeployLog\" + $FILENAME + ".log"

# 開始
echo "Delpoy Start" >> $log

# タイムゾーン
echo "#1 Time Zone" >> $log
Set-TimeZone -Id "Tokyo Standard Time" >> $log
date >> $log
Get-TimeZone >> $log

# 言語パックインストール
echo "#2 OS LanguagePack Install" >> $log
date >> $log
Install-Language ja-jp >> $log

# システムロケール
echo "#3 System Locale" >> $log
date >> $log
Set-WinSystemLocale -SystemLocale ja-JP >> $log
Get-WinSystemLocale  >> $log

# 地域設定
echo "#4 Locale Setting" >> $log
date >> $log
Set-Culture -CultureInfo ja-JP >> $log
Get-Culture >> $log

# システム優先言語
echo "#5 System Preferred UI Language" >> $log
date >> $log
Set-SystemPreferredUILanguage ja-JP >> $log
Get-SystemPreferredUILanguage >> $log

# ロケーション
echo "#6 Location" >> $log
date >> $log
Set-WinHomeLocation -GeoId 0x7a >> $log
Get-WinHomeLocation >> $log

# 言語リスト
echo "#7 Language List" >> $log
date >> $log
$mylang = New-WinUserLanguageList -Language "ja-JP"
Set-WinUserLanguageList $mylang -Force >> $log
Get-WinUserLanguageList >> $log

# ようこそ画面をコピー
echo "#8 Welcome Display Copy" >> $log
date >> $log
Install-Language ja-jp -CopyTosettings >> $log

# Windows Update ※AutoRebootが掛かると 後続バッチが動作しないので注意
echo "#10 Windows Update" >> $log
date >> $log
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force >> $log
Install-Module PSWindowsUpdate -Force >> $log
Get-WindowsUpdate -AcceptAll -Install -AutoReboot >> $log

# 終了時刻の記録
echo "Deploy Finished" >> $log
date >> $log
