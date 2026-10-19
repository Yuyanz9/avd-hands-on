# AVD Hands-on package

このリポジトリは、別管理の当日用 PowerPoint を補完する技術資材です。講座の説明・演習手順・実行条件は PowerPoint と講師の指示に従ってください。PowerPoint はこのリポジトリに含めず、このパッケージ単独では使えません。

## Maintainer commands

PowerShell 7 と Azure CLI（Bicep 拡張機能）が必要です。

```powershell
pwsh -File .\scripts\Build-Templates.ps1
pwsh -File .\tests\Test-ProductionTemplates.ps1
```

テンプレートのビルドはローカルで ARM JSON を生成するだけで、Azure リソースは作成しません。Azure への実行は、必ず当日用 PowerPoint と講師の指示を確認してください。

## Deploy entry points

Deploy ボタンは技術的な入口のみです。PowerPoint と講師の指示なしに実行しないでください。

### Network (NAT Gateway)

<!-- deploy-button-network:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F9ef84dc969b7ef730306bc451959e6afee907b17%2Ftemplates%2Fnetwork.json)
<!-- deploy-button-network:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**

### Network (NAT-free validation)

<!-- deploy-button-network-validation:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F9ef84dc969b7ef730306bc451959e6afee907b17%2Ftemplates%2Fnetwork-validation.json)
<!-- deploy-button-network-validation:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**

### AVD

<!-- deploy-button-avd:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F9ef84dc969b7ef730306bc451959e6afee907b17%2Ftemplates%2Favd.json)
<!-- deploy-button-avd:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**

### Add session hosts

<!-- deploy-button-session-host:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F9ef84dc969b7ef730306bc451959e6afee907b17%2Ftemplates%2Fsession-host.json)
<!-- deploy-button-session-host:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**
