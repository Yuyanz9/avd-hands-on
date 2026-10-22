# AVD Hands-on package

このリポジトリは、別管理の当日用 PowerPoint を補完する技術資材です。講座の説明・演習手順・実行条件は PowerPoint と講師の指示に従ってください。PowerPoint はこのリポジトリに含めず、このパッケージ単独では使えません。

## Deploy entry points

Deploy ボタンは `main` ブランチの ARM テンプレートを参照します。技術的な入口のみなので、PowerPoint と講師の指示なしに実行しないでください。

### 1. Network (NAT Gateway)

<!-- deploy-button-network:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fmain%2Ftemplates%2Fnetwork.json)
<!-- deploy-button-network:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**

### 2. Network（検証用）

<!-- deploy-button-network-validation:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fmain%2Ftemplates%2Fnetwork-validation.json)
<!-- deploy-button-network-validation:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**

### 3. AVD

<!-- deploy-button-avd:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fmain%2Ftemplates%2Favd.json)
<!-- deploy-button-avd:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**

### 4. Add session hosts

<!-- deploy-button-session-host:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fmain%2Ftemplates%2Fsession-host.json)
<!-- deploy-button-session-host:end -->

**Ctrl＋クリックで Azure portal を別タブで開けます（macOS は Command＋クリック）。**
