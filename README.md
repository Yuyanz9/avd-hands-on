# Day 1 本番用ハンズオン：Network → Windows 365 → AVD

**手動の前提確認・RG 設定 → Network（運用または検証）ボタン → Windows 365 担当パート → AVD ボタン**の順で使う一式です。Network は NAT Gateway あり／なしの2方式を用意し、3サブネットの既定値を保ったままネットワーク設定を変更できます。AVD は接続用 RBAC とホストプールの SSO 設定まで IaC に含めています。既存プールへのホスト追加ボタンと Day 2 セキュアジャンプ演習も用意していますが、ジャンプ先 VNet の作成方式（IaC／手動）は未決定です。

**Network は運用版と検証版を選べます。** 運用版は Standard NAT Gateway と静的 Standard Public IP を作成するため継続費用が発生します。検証版は NAT Gateway／Public IP を作らず、Azure の既定の送信アクセスを使います。Network の Azure 実デプロイ、動的デバイスグループの評価、Windows 365 との通しリハーサル、SSO のシームレスな資格情報フローは未確認です。2026-10-07 の旧版 Network／AVD ボタンでは Windows App 接続成功と日本語化に問題がなさそうとの利用者報告がありますが、[修正一覧](revision-list.md) R10 の確認を講師が済ませてから受講者へ配布してください。

> **新版公開済み（2026-10-18）：** Deploy ボタンから Office 入り既定イメージ、SKU 選択、スクリプト省略、複数台、ホストプール方式の入力を利用できます。**英語での新規展開を早める場合は `Custom Configuration Script Url` の既定 URL をすべて消して空欄にします。** 日本語化用 Custom Script Extension を作成せず、Entra ID 参加・AVD 登録・RBAC・22時停止は引き続き設定します。初回構築・ホスト追加の両方で利用でき、Azure 実機での所要時間・接続は別途確認が必要です。

**元の資料を残して Azure portal を開くには、ボタンを Ctrl＋クリック、マウスの中ボタンクリック、または右クリック →［新しいタブでリンクを開く］で開きます（macOS は Command＋クリック）。** GitHub の README ではリンクの `target="_blank"` が除去されるため、資料側から別タブを強制できません。通常クリックは同じタブで遷移します。

![Network・AVD・追加セッションホストの IaC リソースとデプロイ時の選択肢](resources/images/iac-resource-map.svg)

## 1. 受講者が前提確認と RG を手動設定

[Day 1 の統合手順](day1-handson.md)のパート1に従い、指定テナント・サブスクリプションを確認し、講師が指定する任意の名前で演習用 RG を Japan East に手動作成します。両ボタンで同じ既存 RG を選びます。テンプレートは RG を作成しません。

**RG 名は任意です。既定では選択した Network 方式と AVD を同じ RG にデプロイします。** Network の2方式は同じ既定 VNet 名を使うため、1つの VNet にはどちらか一方だけを選びます。既存 VNet が別 RG にある場合は、同じサブスクリプション内の VNet RG を AVD の `Network Resource Group Name` に指定できます。VNet 名とネットワーク CIDR は変更可能です。参加者ごとの環境を分ける場合は、受講者ごとに専用 RG と重複しない VNet 名・CIDR を用意してください。共有・業務用 RG への実行は禁止です。

講師は事前に、利用資格、VM サイズ・イメージ・クォータ、Azure Policy、必要な外向き通信とロール割り当て権限を確認します。**Contributor だけでは AVD の RBAC 作成はできません。**

SSO のテナント側準備は講師が実施します。Microsoft Entra 管理センターの［デバイス］→［リモート接続構成］で **Windows Cloud Login の RDP 認証**を有効化し、Conditional Access／MFA を確認します。これは Azure RG の権限だけでは実施できず、本 ARM には含めません。

## 2. Network を Deploy to Azure

Network のどちらか一方を選んでください。2つのボタンはどちらも既存の RG にデプロイし、同じ既定値で実行すると同じ VNet とサブネットを対象にします。

### 2.1 運用（NAT Gateway あり）

<!-- deploy-button-network:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F050547368fda298c904d7bcf037caebd26046801%2Ftemplates%2Fnetwork.json)
<!-- deploy-button-network:end -->

使用するテンプレート：[templates/network.json](templates/network.json)。Azure portal でサブスクリプションと手順1で作成した既存の演習用 RG を選び、必要に応じて以下の既定値を変更します。

### 2.2 検証（NAT なし）

<!-- deploy-button-network-validation:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F050547368fda298c904d7bcf037caebd26046801%2Ftemplates%2Fnetwork-validation.json)
<!-- deploy-button-network-validation:end -->

使用するテンプレート：[templates/network-validation.json](templates/network-validation.json)。既定の送信アクセスで検証する場合はこちらを選びます。NAT Gateway と送信用 Public IP は作成しません。

| 対象 | 既定値・自動処理 |
| --- | --- |
| Location／VNet | `japaneast`／`vnet-vdi`／`10.10.0.0/16`。両方式で変更可能 |
| Cloud PC 用 | `snet-cloudpc`／`10.10.1.0/24`。CIDR は変更可能 |
| Server 用 | `snet-server`／`10.10.2.0/24`（今回は VM を作らない）。CIDR は変更可能 |
| AVD 用 | `snet-avd`／`10.10.3.0/24`。CIDR は変更可能 |
| 運用方式 | `nat-vdi`／`pip-vdi`（名前は変更可能）、Standard NAT Gateway と静的 Standard IPv4 Public IP |
| 検証方式 | NAT Gateway／送信用 Public IP なし。Azure の既定の送信アクセスを使用 |
| サブネット | 運用方式は `defaultOutboundAccess: false` で NAT Gateway を関連付け。検証方式は `true`（プライベート サブネットではない） |

CIDR は VNet の範囲内に収め、サブネット同士が重複しない値を指定してください。記事に合わせ **NSG は未追加**です。受信・東西通信の制御は配布前の検討事項です。既定の送信アクセスは固定・予測可能な送信元 IP を提供しません。VM に Public IP は付けません。Cloud PC 用サブネットだけでは ANC や Cloud PC は作成されません。

**運用版には NAT Gateway と Public IP の継続費用が発生します。** 既存 VNet を NAT ありから検証版へ切り替えると、サブネットの NAT 関連付けは外れますが、増分デプロイでは NAT Gateway／Public IP リソース自体は自動削除されず、料金が続く場合があります。1つの VNet には一方の方式を選び、切り替え時は残存リソースと依存関係を講師が確認してください。

## 3. Windows 365 担当パート

Network の成功と3サブネットを確認後、Windows 365 担当者の資料へ切り替えます。構築手順・ANC・ライセンス・ポリシーの準備は担当側に任せます。ネットワーク情報の受け渡しと AVD へ戻る条件は [統合手順](day1-handson.md#3-windows-365-を構築する担当パート)に記載しています。

## 4. AVD を Deploy to Azure

<!-- deploy-button-avd:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F050547368fda298c904d7bcf037caebd26046801%2Ftemplates%2Favd.json)
<!-- deploy-button-avd:end -->

使用するテンプレート：[templates/avd.json](templates/avd.json)。パスワード以外は既定値が初期入力され、必要に応じて変更できます。パスワードと既存リソースの名前・配置、イメージ、Workspace 表示名、VM サイズ／ディスク種別、最大セッション数、VM 名プレフィックスに加え、スクリプト URL、台数、ホストプール方式、負荷分散方式を確認してください。

> **入力前に確認：12～123文字が必須です。** 11文字以下だと Azure portal で `InvalidTemplate`（パラメーターの長さ不足）になり、デプロイを開始できません。入力ミスを避けるため14文字以上を推奨します。Windows のパスワード要件として英大文字・英小文字・数字・記号のうち3種類以上を含めてください。これは VM のローカル管理者パスワードで、Entra ID のサインイン用パスワードとは別です。

| 対象 | 既定値・動作 |
| --- | --- |
| ホストプール／DAG | `DefaultHostPool`／`DefaultHostPool-DAG` |
| Workspace | `AVD Session Host` |
| セッションホスト | 既定1台、`Vm Number Of Instances` で1～10台。JST の日時（`AVDMMddHHmm`）＋ `-0`～ `-9`、`Standard_D4as_v6` |
| 管理者／OS ディスク | `vmadmin`／128 GiB、`StandardSSD_LRS` |
| イメージ | 既定 `microsoftwindowsdesktop`／`office-365`／`win11-25h2-avd-m365`／`latest`（Microsoft 365 Apps 入り）。SKU は選択式、Offer は自動連動 |
| ホストプール方式 | `Hostpool Type` は Pooled／Personal（既定 Pooled）。管理方式は Standard |
| 負荷分散 | `Load Balancer Type` は BreadthFirst／DepthFirst（既定 BreadthFirst）。Pooled は最大5セッション／ホストが既定。Personal は Persistent・自動割り当て・1ユーザー／ホスト |
| 参加・保護 | Microsoft Entra ID 参加、Intune なし、Trusted Launch／Secure Boot／vTPM |
| SSO | `enablerdsaadauth:i:1` を常に設定 |
| 接続用 RBAC | 実行ユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login |
| 日本語設定等 | `Custom Configuration Script Url` の既定は記事の `JPNOFLNG.ps1`。空欄なら Custom Script Extension を作らずイメージの言語（通常は英語）のまま高速展開。既定スクリプトは Windows Update と自動再起動を含む |
| 自動停止 | 毎日22:00（`Tokyo Standard Time`）。実行中のセッションも中断される場合があります |

Azure portal へサインインして**デプロイしたメンバーユーザー本人で接続**します。`deployer().objectId` で実行者を取得するため Object ID の入力は不要です。サービスプリンシパル・グループ・別ユーザー向けの配布入口ではありません。講師が別アカウントで再実行すると、その講師にも接続権限が追加されます。

AVD は、入力した VNet の RG／名前／サブネットを参照するだけで、Network は再適用しません。**Network Resource Group Name（`networkResourceGroupName`、旧案内の Virtual Network Resource Group Name）は VNet が存在する RG です。** 既定の `[resourceGroup().name]` は portal 上部で選択したデプロイ先 RG を指します。

| 配置 | RG 選択・入力 |
| --- | --- |
| VNet と VM を同じ RG に置く | 上部で VNet がある既存 RG を選択。Network Resource Group Name は既定のまま |
| VM を VNet と別の RG に置く | VM 用 RG を先に手動作成して上部で選択し、**Network Resource Group Name を VNet 側 RG の名前に書き換える**。例：VM は `rg-avd`、VNet は `rg-network` なら上部で `rg-avd` を選び、入力欄には `rg-network` |

別 RG も同じサブスクリプション内に限定し、既存 VNet／サブネットの名前とリージョン、参照・サブネット参加権限を確認します。VM 用 RG の名前を VNet RG として入力したままだと、既存 VNet が見つからず失敗します。

SKU は Windows 11 **23H2／24H2／25H2／26H2 の `-avd` と `-avd-m365`** から選べます。`-m365` は Office 入りの `office-365` Offer、Office なしは `windows-11` Offer を自動指定します。**Microsoft 365 Apps が入っていても Office 利用ライセンスは付与されません。** Office の利用・認証や日本語化の成功を保証せず、研修では Office 操作を必須にしません。Office 日本語化はライセンス・Intune の前提を確認したデモ／説明として別途準備します。各 SKU の提供地域、サポート期限、利用資格は講師が確認してください。

`Custom Configuration Script Url` を空欄にしても、Entra ID 参加、AVD 登録、接続権限、22時停止は実行されます。変更する場合は講師が承認した HTTPS の PowerShell `.ps1` URL だけを使います。ダウンロード・実行エラーはデプロイ失敗として扱い、成功と見なしません。既存 VM に空欄で再適用しても日本語設定を取り消したり、既存の拡張機能を増分デプロイで削除したりするものではありません。

**Personal を選ぶと、Pooled 向けの負荷分散選択と最大セッション数は使わず、Persistent・Automatic・1セッションで作成します。** ユーザーとホストは1対1です。既存プールの方式は変更できないため、別方式を試す場合は講師と既存リソースの保持・削除を確認して新規に作成します。

VM 名の既定プレフィックスはデプロイ時刻から作られ、1回の展開では `-0` から連番を付けます。**ホスト追加や再実行ではプレフィックスを新しくし、既存 VM と重複させません。** 台数増加に応じて VM・ディスク等の費用、vCPU クォータ、サブネット IP 消費も増えます。各 VM は毎日22:00（日本時間）に自動停止します。実行中のセッションが中断されることがあり、停止後もディスク・ネットワーク等の料金は残ります。

## 5. 既存プールへセッションホストを追加

<!-- deploy-button-session-host:start -->
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FYuyanz9%2Favd-hands-on%2F050547368fda298c904d7bcf037caebd26046801%2Ftemplates%2Fsession-host.json)
<!-- deploy-button-session-host:end -->

使用するテンプレート：[templates/session-host.json](templates/session-host.json)。このテンプレートは既存の Standard 管理ホストプールへ VM を既定1台、1回につき1～10台追加します。**台数は追加分であり、プール全体の目標台数ではありません。** 既存のホストプール、アプリケーショングループ、Workspace は作成・更新しません。Azure portal で新しい VM の配置先 RG を選びます。VNet が別 RG の場合は、上の配置表と同様に **Network Resource Group Name を VNet 側 RG に変更**してください。プールの RG は登録キーを発行する場所で、VM の配置先 RG と区別します。

デプロイ前に対象ホストプールで有効な登録キーを発行し、Secure registration token 欄へ貼り付けます。トークンと VM ローカル管理者パスワードは秘密情報として扱い、ファイル・チャット・スクリーンショットへ保存しません。イメージ、VM サイズ、リージョン、サブネットは既存プールと互換性があることを講師が確認してください。既定名は日時プレフィックス＋ `-0` からの連番です。既存ホストとの名前衝突を避け、再実行時はプレフィックスを変更します。作成した各 VM も毎日22:00（日本時間）に自動停止します。

| 入力項目 | 既定値 | 用途・注意 |
| --- | --- | --- |
| Existing Host Pool Name | `DefaultHostPool` | 登録キーを作成した対象の Standard 管理プール |
| Network Resource Group Name | 選択したデプロイ先 RG | 同じ RG なら既定のまま。別 RG なら **VNet 側 RG の名前**に変更 |
| Existing Vnet Name／Existing Subnet Name | `vnet-vdi`／`snet-avd` | 対象プールで利用する既存ネットワーク |
| Location | `japaneast` | VNet と既存プールに合わせる |
| Vm Gallery Image SKU | `win11-25h2-avd-m365` | Office 入り。既存ホストと互換の SKU をリストから選択。Offer は連動 |
| Vm Size／Vm Disk Type | `Standard_D4as_v6`／`StandardSSD_LRS` | 既存プールに合わせる |
| Vm Name Prefix | JST の日時 `AVDMMddHHmm` | 実行時刻が近い場合は一意になる値へ変更 |
| Custom Configuration Script Url | `https://nogujapanese.blob.core.windows.net/avd-deploy/JPNOFLNG.ps1` | 空欄なら日本語設定を省略 |
| Vm Number Of Instances | `1` | 追加する台数。1～10台。費用・クォータを確認 |
| Registration Token／Vm Administrator Account Password | 既定なし | 必須の secure parameter。秘密を保存しない |

## 6. 動的デバイスグループ（任意・手動）

動的デバイスグループは、作成済みの AVD セッションホストや Windows 365 Cloud PC に Intune などのデバイス ポリシーを割り当てるためのものです。**AVD ホストの作成・プールへの登録にも、Windows 365 の Cloud PC プロビジョニングにも必須ではありません。** Entra 管理センターで［グループ］→［新しいグループ］を開き、グループの種類を［セキュリティ］、メンバーシップの種類を［動的デバイス］にして作成します。

| 対象 | グループ名の例 | 動的メンバーシップ ルール |
| --- | --- | --- |
| AVD セッションホスト | `AVD-SessionHosts` | `(device.displayName -startsWith "AVD")` |
| Windows 365 Cloud PC | `Windows365-CloudPCs` | `(device.deviceModel -startsWith "Cloud PC") -or (device.deviceModel -startsWith "Windows 365")` |

AVD のルールは VM 名プレフィックス `AVD` を前提にします。既定プレフィックスから変更した場合はルールも合わせてください。ポリシーを割り当てる前に、ルール検証と実際のデバイス オブジェクトで対象・除外を確認します。動的グループの評価には時間がかかることがあります。動的メンバーシップ機能の利用条件・ライセンスは講師がテナントで確認してください。

Windows 365 のプロビジョニング ポリシーを割り当てる対象は **ユーザー グループ**です。Cloud PC の動的デバイスグループとは別の用途なので、混同しないでください。これらの Entra グループは本テンプレートでは作成しません。

## 記事からの意図的な変更と未確認事項

- VM 名プレフィックス、VM サイズ、ディスク種別、イメージ SKU、最大セッション数、VNet／サブネット名、配置 RG、ロケーション、Workspace 表示名は既定値を確認・変更できます。名前の重複や VNet とリージョンの不整合を避けます。
- AVD と追加ホストの VM は毎日22:00（日本時間）に自動停止します。Day 2 のセキュアジャンプ VM は IaC 対象外で、手動で同じ停止時刻を設定します。
- Network は運用版（NAT Gateway／静的 Public IP、`defaultOutboundAccess: false`）と検証版（NAT なし、`defaultOutboundAccess: true`）から選びます。運用版には継続費用がかかり、検証版の既定送信元 IP は固定されません。
- 接続権限2種類とホストプール SSO を自動設定します。Windows Cloud Login のテナント側準備は講師担当です。

イメージの `latest`、DSC パッケージ、記事の日本語設定スクリプトは外部依存です。**スクリプトは可変で、自動再起動による拡張機能の失敗・待機時間を含め未実証**です。配布前に通しリハーサルし、版固定・再起動方式の調整要否を判断します。デプロイ成功と SSO 接続成功は別の確認です。

### セキュリティ上の注意：外部スクリプト

AVD テンプレートは公開 Blob Storage の `JPNOFLNG.ps1` を取得し、Custom Script Extension で `ExecutionPolicy Bypass` を指定して VM 上で実行します。スクリプト内では `PSWindowsUpdate` もバージョン指定なしでインストール・実行します。ARM JSON の固定コミットはテンプレートだけを固定し、外部スクリプトや PowerShell Gallery のモジュールを固定・検証するものではありません。外部配信元の変更により実行内容が変わり得るサプライチェーンリスクがあります。

**この教材・スクリプトに悪意あるコードを加えること、実行先を不審なスクリプトに差し替えること、未承認の変更を配布・実行することを禁止します。** デプロイ前に講師が配信元とその時点の内容を確認し、承認できない場合は［作成］を進めないでください。この注意書きは技術的な改変防止策ではありません。ハッシュ／署名検証や不変なスクリプト配信は未実装のため、本番利用前に R09 の確認と対策が必要です。

流用スクリーンショットは旧テンプレートの参考で、新版の入力画面ではありません。新しい画面の撮影は実機リハーサル時に行います。費用・保持・削除の注意は [統合手順](day1-handson.md)を参照してください。

## 講師・作成者向け：生成と配信リンクの準備

Network の編集可能な既定値と AVD の変更しない基礎設定は [infra/settings.json](infra/settings.json)および対応する Bicep のパラメーターに記載しています。Network の portal 既定値は settings と一致するよう契約テストで検証します。このフォルダーを作業ディレクトリにして PowerShell 7 と Azure CLI の Bicep コンパイラーで実行します。ローカル生成は Bicep 0.42.1 で確認しています。以下は Azure ログインやデプロイを行いません。

```powershell
.\scripts\Build-Templates.ps1
.\tests\Test-ProductionTemplates.ps1
```

AVD のモジュールは生成 JSON に埋め込まれ、リモート Bicep や別の ARM テンプレートの配信は不要です。生成後はソースと JSON をセットで管理してください。

現在のボタンは、[配信管理データ](resources/deploy-links.json)に記録した公開コミット `050547368fda298c904d7bcf037caebd26046801` の ARM JSON に固定しています。4つの URL は匿名取得・JSON 解析・同梱 JSON との SHA-256 一致を確認済みです。これはテンプレート配信の確認であり、Azure 実機でのデプロイ・接続成功の確認ではありません。今後テンプレートを更新する場合も、その**テンプレートが含まれる40桁のコミット SHA**でボタンを設定し、匿名取得とハッシュ照合をやり直します。

```powershell
.\scripts\Set-DeployButtons.ps1 `
    -Repository '<公開先owner>/<公開先repo>' `
    -TemplateCommit '<テンプレートを含む40桁のコミットSHA>'
```

公開 repo 内のサブフォルダーに置く場合は `-TemplatePathPrefix 'avd-hands-on/production'` 等を指定します。スクリプトはローカル README と [配信管理データ](resources/deploy-links.json)のみを更新し、repo 作成・公開・push はしません。再実行後は4つの raw URL を匿名取得し、ローカルファイルとの SHA-256 一致を確認するまで管理データの `rawUrlsVerified` を `false` のままにします。

ボタンは [Microsoft 公式の README パターン](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-to-azure-button)に沿い、公開 raw ARM JSON の URL をエンコードして Azure portal へ渡します。**非公開 GitHub repo の raw URL はそのままでは ARM が取得できません。** 配信時は固定コミットのファイルが匿名取得でき、同梱 JSON のハッシュと一致することを確認してから、ボタンを配布します。

この公開 repo は `avd-hands-on\production\` の一式だけをルートに配置しています。元の非公開 `M-Training` repo はそのままです。親の内部資料・PowerPoint・顧客固有情報は含めていません。

## 関連資料

| 資料 | 用途 |
| --- | --- |
| [Day 1 統合手順](day1-handson.md) | 受講者・講師の進行と完了条件 |
| [Day 2 セキュアジャンプ手順](day2-secure-jump.md) | VNet 作成方式（IaC／手動）の決定待ち。現行手順は手動作成案 |
| [修正一覧](revision-list.md) | 実装済みと配布前の残作業 |
| [流用一覧](reuse-inventory.md) | 比較用素材と新規 IaC の区別 |
| [画像の出典](resources/images/README.md) | 加工・利用許可・旧画面の制約 |
| [コピー記録](resources/reuse-manifest.json) | 取り込み時点の出典とハッシュ |
