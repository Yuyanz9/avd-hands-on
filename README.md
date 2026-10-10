# Day 1 本番用ハンズオン：Network → Windows 365 → AVD

**手動の前提確認・RG 設定 → Network ボタン → Windows 365 担当パート → AVD ボタン**の順で使う一式です。記事の3サブネットと固定値を採用し、AVD は接続用 RBAC とホストプールの SSO 設定まで IaC に含めています。

**公開済みの準備版です。** 2026-10-07 に旧版の Network／AVD ボタンを試行し、Windows App からの接続成功と日本語化に問題がなさそうとの利用者報告がありました。今回の更新では portal で選んだ任意名の RG を AVD のネットワーク参照先にも使いますが、この更新版の Azure 実デプロイは未確認です。Windows 365 との通しリハーサルと SSO のシームレスな資格情報フローも未確認のため、[修正一覧](revision-list.md) R10 の確認を講師が済ませてから受講者へ配布してください。

## 1. 受講者が前提確認と RG を手動設定

[Day 1 の統合手順](day1-handson.md)のパート1に従い、指定テナント・サブスクリプションを確認し、講師が指定する任意の名前で演習用 RG を Japan East に手動作成します。両ボタンで同じ既存 RG を選びます。テンプレートは RG を作成しません。

**RG 名は任意ですが、Network と AVD は同じ RG にデプロイしてください。** 参加者ごとの環境を分ける場合は、同じサブスクリプション内でも受講者ごとに専用 RG を用意します。固定の VNet／VM 名を使うため、同一 RG を複数参加者で共有しないでください。共有・業務用 RG への実行は禁止です。

講師は事前に、利用資格、VM サイズ・イメージ・クォータ、Azure Policy、必要な外向き通信とロール割り当て権限を確認します。**Contributor だけでは AVD の RBAC 作成はできません。**

SSO のテナント側準備は講師が実施します。Microsoft Entra 管理センターの［デバイス］→［リモート接続構成］で **Windows Cloud Login の RDP 認証**を有効化し、Conditional Access／MFA を確認します。これは Azure RG の権限だけでは実施できず、本 ARM には含めません。

## 2. Network を Deploy to Azure

<!-- deploy-button-network:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fc42336345433c34a8c878df7795d5dcd20dadc95%2Ftemplates%2Fnetwork.json)
<!-- deploy-button-network:end -->

使用するテンプレート：[templates/network.json](templates/network.json)。**テンプレート固有の入力パラメーターはありません。** Azure portal でサブスクリプションと手順1で作成した既存の演習用 RG を選択します。RG 名は固定されていません。

| 対象 | 固定設定 |
| --- | --- |
| リージョン／VNet | `japaneast`／`vnet-vdi`、`10.10.0.0/16` |
| Cloud PC 用 | `snet-cloudpc`、`10.10.1.0/24` |
| Server 用 | `snet-server`、`10.10.2.0/24`（今回は VM を作らない） |
| AVD 用 | `snet-avd`、`10.10.3.0/24` |
| 送信経路 | `nat-vdi`＋`pip-vdi`、Standard／静的 IPv4、3サブネットに関連付け |
| 明示的な送信 | 各サブネットで `defaultOutboundAccess: false` |

記事に合わせ **NSG は未追加**です。受信・東西通信の制御は配布前の検討事項です。NAT の Public IP は送信専用で、VM に Public IP は付けません。Cloud PC 用サブネットだけでは ANC や Cloud PC は作成されません。

## 3. Windows 365 担当パート

Network の成功と3サブネットを確認後、Windows 365 担当者の資料へ切り替えます。構築手順・ANC・ライセンス・ポリシーの準備は担当側に任せます。ネットワーク情報の受け渡しと AVD へ戻る条件は [統合手順](day1-handson.md#3-windows-365-を構築する担当パート)に記載しています。

## 4. AVD を Deploy to Azure

<!-- deploy-button-avd:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fc42336345433c34a8c878df7795d5dcd20dadc95%2Ftemplates%2Favd.json)
<!-- deploy-button-avd:end -->

使用するテンプレート：[templates/avd.json](templates/avd.json)。**入力するテンプレートパラメーターは VM ローカル管理者のパスワード1つだけ**です。秘密を固定値・ファイル・スクリーンショットに保存しません。

> **入力前に確認：12～123文字が必須です。** 11文字以下だと Azure portal で `InvalidTemplate`（パラメーターの長さ不足）になり、デプロイを開始できません。入力ミスを避けるため14文字以上を推奨します。Windows のパスワード要件として英大文字・英小文字・数字・記号のうち3種類以上を含めてください。これは VM のローカル管理者パスワードで、Entra ID のサインイン用パスワードとは別です。

| 対象 | 固定設定 |
| --- | --- |
| ホストプール／DAG | `DefaultHostPool`／`DefaultHostPool-DAG` |
| Workspace | `AVD Session Host` |
| セッションホスト | `avd-0`、1台、`Standard_D4as_v6` |
| 管理者／OS ディスク | `vmadmin`／128 GiB、`StandardSSD_LRS` |
| イメージ | `microsoftwindowsdesktop`／`windows-11`／`win11-25h2-avd`／`latest`（Microsoft 365 Apps なし） |
| ホストプール方式 | Pooled／Standard／BreadthFirst、最大5セッション |
| 参加・保護 | Microsoft Entra ID 参加、Intune なし、Trusted Launch／Secure Boot／vTPM |
| SSO | `enablerdsaadauth:i:1` を常に設定 |
| 接続用 RBAC | 実行ユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login |
| 日本語設定等 | 記事の `JPNOFLNG.ps1`。Windows Update と自動再起動を含む |

Azure portal へサインインして**デプロイしたメンバーユーザー本人で接続**します。`deployer().objectId` で実行者を取得するため Object ID の入力は不要です。サービスプリンシパル・グループ・別ユーザー向けの配布入口ではありません。講師が別アカウントで再実行すると、その講師にも接続権限が追加されます。

AVD は、portal で選択したデプロイ先 RG にある既存の `vnet-vdi`／`snet-avd` を参照するだけで、Network は再適用しません。Network のデプロイ先と同じ RG を選んでください。登録トークンの有効期間はデプロイから2時間で、VM 拡張機能の `protectedSettings` のみに渡します。登録済みホストの利用期限ではありません。

## 記事からの意図的な変更と未確認事項

- 日時ベースの VM 名ではなく **`avd-0`** を使用し、再実行による別 VM の作成を避けます。既存 VM を変更する可能性はあるため、無断で再実行しません。
- NAT に加え `defaultOutboundAccess: false` を明示し、暗黙の送信経路に依存しません。
- 接続権限2種類とホストプール SSO を自動設定します。Windows Cloud Login のテナント側準備は講師担当です。

イメージの `latest`、DSC パッケージ、記事の日本語設定スクリプトは外部依存です。**スクリプトは可変で、自動再起動による拡張機能の失敗・待機時間を含め未実証**です。配布前に通しリハーサルし、版固定・再起動方式の調整要否を判断します。デプロイ成功と SSO 接続成功は別の確認です。

### セキュリティ上の注意：外部スクリプト

AVD テンプレートは公開 Blob Storage の `JPNOFLNG.ps1` を取得し、Custom Script Extension で `ExecutionPolicy Bypass` を指定して VM 上で実行します。スクリプト内では `PSWindowsUpdate` もバージョン指定なしでインストール・実行します。ARM JSON の固定コミットはテンプレートだけを固定し、外部スクリプトや PowerShell Gallery のモジュールを固定・検証するものではありません。外部配信元の変更により実行内容が変わり得るサプライチェーンリスクがあります。

**この教材・スクリプトに悪意あるコードを加えること、実行先を不審なスクリプトに差し替えること、未承認の変更を配布・実行することを禁止します。** デプロイ前に講師が配信元とその時点の内容を確認し、承認できない場合は［作成］を進めないでください。この注意書きは技術的な改変防止策ではありません。ハッシュ／署名検証や不変なスクリプト配信は未実装のため、本番利用前に R09 の確認と対策が必要です。

流用スクリーンショットは旧テンプレートの参考で、新版の入力画面ではありません。新しい画面の撮影は実機リハーサル時に行います。費用・保持・削除の注意は [統合手順](day1-handson.md)を参照してください。

## 講師・作成者向け：生成と配信リンクの準備

固定値の正本は [infra/settings.json](infra/settings.json)です。このフォルダーを作業ディレクトリにして PowerShell 7 と Azure CLI の Bicep コンパイラーで実行します。ローカル生成は Bicep 0.42.1 で確認しています。以下は Azure ログインやデプロイを行いません。

```powershell
.\scripts\Build-Templates.ps1
.\tests\Test-ProductionTemplates.ps1
```

AVD のモジュールは生成 JSON に埋め込まれ、リモート Bicep や別の ARM テンプレートの配信は不要です。生成後はソースと JSON をセットで管理してください。

現在のボタンは、[配信管理データ](resources/deploy-links.json)に記録した公開コミットの ARM JSON に固定しています。匿名取得した両テンプレートの SHA-256 を同ファイルに記録します。別の版を公開する場合は、その**テンプレートが含まれる40桁のコミット SHA**でボタンを設定します。

```powershell
.\scripts\Set-DeployButtons.ps1 `
    -Repository '<公開先owner>/<公開先repo>' `
    -TemplateCommit '<テンプレートを含む40桁のコミットSHA>'
```

公開 repo 内のサブフォルダーに置く場合は `-TemplatePathPrefix 'avd-hands-on/production'` 等を指定します。スクリプトはローカル README と [配信管理データ](resources/deploy-links.json)のみを更新し、repo 作成・公開・push はしません。再実行後は両 raw URL を匿名取得し、ローカルファイルとの SHA-256 一致を確認するまで管理データの `rawUrlsVerified` を `false` のままにします。

ボタンは [Microsoft 公式の README パターン](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-to-azure-button)に沿い、公開 raw ARM JSON の URL をエンコードして Azure portal へ渡します。**非公開 GitHub repo の raw URL はそのままでは ARM が取得できません。** 配信時は固定コミットのファイルが匿名取得でき、同梱 JSON のハッシュと一致することを確認してから、ボタンを配布します。

この公開 repo は `avd-hands-on\production\` の一式だけをルートに配置しています。元の非公開 `M-Training` repo はそのままです。親の内部資料・PowerPoint・顧客固有情報は含めていません。

## 関連資料

| 資料 | 用途 |
| --- | --- |
| [Day 1 統合手順](day1-handson.md) | 受講者・講師の進行と完了条件 |
| [修正一覧](revision-list.md) | 実装済みと配布前の残作業 |
| [流用一覧](reuse-inventory.md) | 比較用素材と新規 IaC の区別 |
| [画像の出典](resources/images/README.md) | 加工・利用許可・旧画面の制約 |
| [コピー記録](resources/reuse-manifest.json) | 取り込み時点の出典とハッシュ |
