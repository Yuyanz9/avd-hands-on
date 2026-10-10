# Day 1 本番用ハンズオン：Network → Windows 365 → AVD

**手動の前提確認・RG 設定 → Network ボタン → Windows 365 担当パート → AVD ボタン**の順で使う一式です。記事の3サブネットと固定値を採用し、AVD は接続用 RBAC とホストプールの SSO 設定まで IaC に含めています。既存プールへのホスト追加ボタンと、手動で行う Day 2 セキュアジャンプ演習も用意しています。

**更新版を公開済みです。** Network／AVD／session-host の3つの ARM JSON は、公開コミットに固定した raw URL から匿名取得し、同梱ファイルとの SHA-256 一致を確認済みです。2026-10-07 に旧版の Network／AVD ボタンを試行し、Windows App からの接続成功と日本語化に問題がなさそうとの利用者報告がありましたが、今回の更新版の Azure 実デプロイは未確認です。Windows 365 との通しリハーサルと SSO のシームレスな資格情報フローも未確認のため、[修正一覧](revision-list.md) R10 の確認を講師が済ませてから受講者へ配布してください。

## 1. 受講者が前提確認と RG を手動設定

[Day 1 の統合手順](day1-handson.md)のパート1に従い、指定テナント・サブスクリプションを確認し、講師が指定する任意の名前で演習用 RG を Japan East に手動作成します。両ボタンで同じ既存 RG を選びます。テンプレートは RG を作成しません。

**RG 名は任意です。既定では Network と AVD を同じ RG にデプロイします。** VNet が別 RG にある場合は、同じサブスクリプション内の既存 VNet RG を AVD の `Virtual Network Resource Group Name` に指定できます。VNet 名は既定値のままでも変更可能、VM 名には分単位の日時プレフィックスを使います。参加者ごとの環境を分ける場合は、受講者ごとに専用 RG を用意してください。共有・業務用 RG への実行は禁止です。

講師は事前に、利用資格、VM サイズ・イメージ・クォータ、Azure Policy、必要な外向き通信とロール割り当て権限を確認します。**Contributor だけでは AVD の RBAC 作成はできません。**

SSO のテナント側準備は講師が実施します。Microsoft Entra 管理センターの［デバイス］→［リモート接続構成］で **Windows Cloud Login の RDP 認証**を有効化し、Conditional Access／MFA を確認します。これは Azure RG の権限だけでは実施できず、本 ARM には含めません。

## 2. Network を Deploy to Azure

<!-- deploy-button-network:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fb18d7d073fcf11f83f3ba6f5decef5b4c999bede%2Ftemplates%2Fnetwork.json)
<!-- deploy-button-network:end -->

使用するテンプレート：[templates/network.json](templates/network.json)。**テンプレート固有の入力パラメーターはありません。** Azure portal でサブスクリプションと手順1で作成した既存の演習用 RG を選択します。RG 名は固定されていません。

| 対象 | 既定値・自動処理 |
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
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fb18d7d073fcf11f83f3ba6f5decef5b4c999bede%2Ftemplates%2Favd.json)
<!-- deploy-button-avd:end -->

使用するテンプレート：[templates/avd.json](templates/avd.json)。パスワード以外は現在の標準値が初期入力され、必要に応じて変更できます。パスワードと既存リソースの名前・配置、イメージ、Workspace 表示名、VM サイズ／ディスク種別、最大セッション数、VM 名プレフィックスを確認してください。

> **入力前に確認：12～123文字が必須です。** 11文字以下だと Azure portal で `InvalidTemplate`（パラメーターの長さ不足）になり、デプロイを開始できません。入力ミスを避けるため14文字以上を推奨します。Windows のパスワード要件として英大文字・英小文字・数字・記号のうち3種類以上を含めてください。これは VM のローカル管理者パスワードで、Entra ID のサインイン用パスワードとは別です。

| 対象 | 固定設定 |
| --- | --- |
| ホストプール／DAG | `DefaultHostPool`／`DefaultHostPool-DAG` |
| Workspace | `AVD Session Host` |
| セッションホスト | 1台、既定プレフィックスは JST の日時（`AVDMMddHHmm`）＋ `-0`、`Standard_D4as_v6` |
| 管理者／OS ディスク | `vmadmin`／128 GiB、`StandardSSD_LRS` |
| イメージ | `microsoftwindowsdesktop`／`windows-11`／`win11-25h2-avd`／`latest`（Microsoft 365 Apps なし） |
| ホストプール方式 | Pooled／Standard／BreadthFirst、最大5セッション |
| 参加・保護 | Microsoft Entra ID 参加、Intune なし、Trusted Launch／Secure Boot／vTPM |
| SSO | `enablerdsaadauth:i:1` を常に設定 |
| 接続用 RBAC | 実行ユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login |
| 日本語設定等 | 記事の `JPNOFLNG.ps1`。Windows Update と自動再起動を含む |
| 自動停止 | 毎日22:00（`Tokyo Standard Time`）。実行中のセッションも中断される場合があります |

Azure portal へサインインして**デプロイしたメンバーユーザー本人で接続**します。`deployer().objectId` で実行者を取得するため Object ID の入力は不要です。サービスプリンシパル・グループ・別ユーザー向けの配布入口ではありません。講師が別アカウントで再実行すると、その講師にも接続権限が追加されます。

AVD は、入力した VNet の RG／名前／サブネットを参照するだけで、Network は再適用しません。既定の VNet RG は portal で選択した AVD のデプロイ先 RG です。Network と別の RG を使う場合は、同じサブスクリプション内の正しい VNet／サブネットとリージョンを指定してください。VM 名の既定プレフィックスはデプロイ時刻から作られます。複数ホストを同じ時間帯に作る場合は、名前が重複しないようプレフィックスを変更してください。各 VM は毎日22:00（日本時間）に自動停止します。実行中のセッションが中断されることがあり、停止後もディスク・ネットワーク等の料金は残ります。

## 5. 既存プールへセッションホストを追加

<!-- deploy-button-session-host:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2Fb18d7d073fcf11f83f3ba6f5decef5b4c999bede%2Ftemplates%2Fsession-host.json)
<!-- deploy-button-session-host:end -->

使用するテンプレート：[templates/session-host.json](templates/session-host.json)。このテンプレートは既存の Standard 管理ホストプールへ VM を1台だけ追加します。既存のホストプール、アプリケーショングループ、Workspace は作成・更新しません。Azure portal で対象プールと既存 VNet があるリソースグループをデプロイ先に選びます（VNet は別 RG も指定可能です）。

デプロイ前に対象ホストプールで有効な登録キーを発行し、Secure registration token 欄へ貼り付けます。トークンと VM ローカル管理者パスワードは秘密情報として扱い、ファイル・チャット・スクリーンショットへ保存しません。イメージ、VM サイズ、リージョン、サブネットは既存プールと互換性があることを講師が確認してください。既定名は日時プレフィックス＋ `-0` です。既存ホストとの名前衝突を避け、同時刻に複数回実行する場合はプレフィックスを変更します。作成した VM も毎日22:00（日本時間）に自動停止します。

| 入力項目 | 既定値 | 用途・注意 |
| --- | --- | --- |
| Existing Host Pool Name | `DefaultHostPool` | 登録キーを作成した対象の Standard 管理プール |
| Virtual Network Resource Group Name | 選択したデプロイ先 RG | 既存 VNet が別 RG なら同じサブスクリプション内で指定 |
| Existing Vnet Name／Existing Subnet Name | `vnet-vdi`／`snet-avd` | 対象プールで利用する既存ネットワーク |
| Location | `japaneast` | VNet と既存プールに合わせる |
| Vm Gallery Image SKU | `win11-25h2-avd` | 既存ホストと互換の SKU |
| Vm Size／Vm Disk Type | `Standard_D4as_v6`／`StandardSSD_LRS` | 既存プールに合わせる |
| Vm Name Prefix | JST の日時 `AVDMMddHHmm` | 実行時刻が近い場合は一意になる値へ変更 |
| Registration Token／Vm Administrator Account Password | 既定なし | 必須の secure parameter。秘密を保存しない |

## 記事からの意図的な変更と未確認事項

- VM 名プレフィックス、VM サイズ、ディスク種別、イメージ SKU、最大セッション数、VNet／サブネット名、配置 RG、ロケーション、Workspace 表示名は既定値を確認・変更できます。名前の重複や VNet とリージョンの不整合を避けます。
- AVD と追加ホストの VM は毎日22:00（日本時間）に自動停止します。Day 2 のセキュアジャンプ VM は IaC 対象外で、手動で同じ停止時刻を設定します。
- NAT に加え `defaultOutboundAccess: false` を明示し、暗黙の送信経路に依存しません。
- 接続権限2種類とホストプール SSO を自動設定します。Windows Cloud Login のテナント側準備は講師担当です。

イメージの `latest`、DSC パッケージ、記事の日本語設定スクリプトは外部依存です。**スクリプトは可変で、自動再起動による拡張機能の失敗・待機時間を含め未実証**です。配布前に通しリハーサルし、版固定・再起動方式の調整要否を判断します。デプロイ成功と SSO 接続成功は別の確認です。

### セキュリティ上の注意：外部スクリプト

AVD テンプレートは公開 Blob Storage の `JPNOFLNG.ps1` を取得し、Custom Script Extension で `ExecutionPolicy Bypass` を指定して VM 上で実行します。スクリプト内では `PSWindowsUpdate` もバージョン指定なしでインストール・実行します。ARM JSON の固定コミットはテンプレートだけを固定し、外部スクリプトや PowerShell Gallery のモジュールを固定・検証するものではありません。外部配信元の変更により実行内容が変わり得るサプライチェーンリスクがあります。

**この教材・スクリプトに悪意あるコードを加えること、実行先を不審なスクリプトに差し替えること、未承認の変更を配布・実行することを禁止します。** デプロイ前に講師が配信元とその時点の内容を確認し、承認できない場合は［作成］を進めないでください。この注意書きは技術的な改変防止策ではありません。ハッシュ／署名検証や不変なスクリプト配信は未実装のため、本番利用前に R09 の確認と対策が必要です。

流用スクリーンショットは旧テンプレートの参考で、新版の入力画面ではありません。新しい画面の撮影は実機リハーサル時に行います。費用・保持・削除の注意は [統合手順](day1-handson.md)を参照してください。

## 講師・作成者向け：生成と配信リンクの準備

Network の固定値と AVD の変更しない基礎設定は [infra/settings.json](infra/settings.json)です。利用者が変更する AVD 値の既定値は Bicep のパラメーターに記載しています。このフォルダーを作業ディレクトリにして PowerShell 7 と Azure CLI の Bicep コンパイラーで実行します。ローカル生成は Bicep 0.42.1 で確認しています。以下は Azure ログインやデプロイを行いません。

```powershell
.\scripts\Build-Templates.ps1
.\tests\Test-ProductionTemplates.ps1
```

AVD のモジュールは生成 JSON に埋め込まれ、リモート Bicep や別の ARM テンプレートの配信は不要です。生成後はソースと JSON をセットで管理してください。

現在のボタンは、[配信管理データ](resources/deploy-links.json)に記録した公開コミットの ARM JSON に固定しています。3テンプレートの SHA-256 を同ファイルに記録し、公開 raw URL からの匿名取得結果と一致することを確認済みです。別の版を公開する場合は、その**テンプレートが含まれる40桁のコミット SHA**でボタンを設定します。

```powershell
.\scripts\Set-DeployButtons.ps1 `
    -Repository '<公開先owner>/<公開先repo>' `
    -TemplateCommit '<テンプレートを含む40桁のコミットSHA>'
```

公開 repo 内のサブフォルダーに置く場合は `-TemplatePathPrefix 'avd-hands-on/production'` 等を指定します。スクリプトはローカル README と [配信管理データ](resources/deploy-links.json)のみを更新し、repo 作成・公開・push はしません。再実行後は3つの raw URL を匿名取得し、ローカルファイルとの SHA-256 一致を確認するまで管理データの `rawUrlsVerified` を `false` のままにします。

ボタンは [Microsoft 公式の README パターン](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-to-azure-button)に沿い、公開 raw ARM JSON の URL をエンコードして Azure portal へ渡します。**非公開 GitHub repo の raw URL はそのままでは ARM が取得できません。** 配信時は固定コミットのファイルが匿名取得でき、同梱 JSON のハッシュと一致することを確認してから、ボタンを配布します。

この公開 repo は `avd-hands-on\production\` の一式だけをルートに配置しています。元の非公開 `M-Training` repo はそのままです。親の内部資料・PowerPoint・顧客固有情報は含めていません。

## 関連資料

| 資料 | 用途 |
| --- | --- |
| [Day 1 統合手順](day1-handson.md) | 受講者・講師の進行と完了条件 |
| [Day 2 セキュアジャンプ手順](day2-secure-jump.md) | IaC を使わずに手動で構築する演習 |
| [修正一覧](revision-list.md) | 実装済みと配布前の残作業 |
| [流用一覧](reuse-inventory.md) | 比較用素材と新規 IaC の区別 |
| [画像の出典](resources/images/README.md) | 加工・利用許可・旧画面の制約 |
| [コピー記録](resources/reuse-manifest.json) | 取り込み時点の出典とハッシュ |
