# 本番化前の修正・確定事項

記事の3サブネットと既定値、手動作成する任意名の演習用 RG、AVD の自動 RBAC・SSO を採用しました。Network と AVD は同じ RG を使います。Network は運用（NAT Gateway あり）と検証（NAT なし）の2方式があり、VNet／サブネットの CIDR を変更できます。**テンプレートの公開・検査と Azure 実機確認済みを区別**します。2026-10-07 に旧版を試行し、Windows App 接続成功・日本語化も問題なさそうとの利用者報告がありますが、今回の Network 2方式と任意 RG 対応版を Azure で実行した確認はありません。

## 実装状況と配布前の残項目

**2026-10-18に新版を公開済みです。** Office 入り既定イメージと選択リスト、スクリプト URL、複数台、プール方式・負荷分散の入力を公開し、Deploy ボタンを新版の固定コミットへ切り替えました。4つの ARM JSON の匿名取得・ハッシュ一致を確認しています。Azure 実機でのデプロイと接続は未確認です。

**同日の RDP 2項目修正も公開済みです。** CredSSP／ビデオ再生の既定値を明示しました。残りのデバイス／画面設定の比較と実機確認は R19 に残しています。

| ID | 状態 | 対象 | 実施済み／残作業・完了条件 |
| --- | --- | --- | --- |
| R01 | ローカル実装済み | 共通ネットワークの統一 | `vnet-vdi`／`10.10.0.0/16`、Cloud PC・Server・AVD の3サブネットを既定値に設定し、VNet／サブネット CIDR は変更可能。実作成・送信設定確認は R10 |
| R02 | 担当確認待ち | Windows 365 の受け渡し | `snet-cloudpc` を用意。担当者と ANC／Microsoft ホスト型の方式、VNet 利用、通信・権限、待機・復帰条件を照合。Windows 365 実装は担当側 |
| R03 | RDP 修正版も公開・配信確認済み | 4つの ARM JSON | 運用 Network、検証 Network、AVD、session-host の公開 JSON は匿名取得・JSON 解析・同梱ファイルとの SHA-256 一致を確認。AVD JSON は RDP 2項目修正を含む。Azure 実行は R10 |
| R04 | 新版の固定リンクへ切替済み | 配信・版固定 | Deploy ボタンは公開コミット `e66d1a82f77faac3d432d05e64f8f4869a7b7f69` を参照。`resources/deploy-links.json` の URL・ハッシュを更新し、匿名取得照合済み。GitHub は別タブを強制できないため Ctrl＋クリック等を案内 |
| R05 | 任意名に対応・画像待ち | 手動 RG と権限 | Japan East、必須タグなし。Network と AVD は同一 RG が既定。AVD の VNet RG 入力で同じサブスクリプション内の別 VNet RG も指定可能。作成・IAM 画面の撮影と権限リハーサルは未実施 |
| R06 | IaC 更新済み・設計確認待ち | 送信・受信制御 | 運用版は Standard NAT Gateway／静的 Standard Public IP と `defaultOutboundAccess: false`、検証版は NAT なし・`defaultOutboundAccess: true`。NSG は未作成。運用版の継続費用と検証版の不定な送信元 IP を案内し、通信・受信・東西制御を配布前に確認 |
| R07 | ローカル実装済み | Windows 365 後の Network 保護 | AVD は既存ネットワーク参照のみ。VNet・サブネットを再作成しない。NAT ありから検証方式への増分切替で NAT／Public IP が残存し得る点と ANC 等への影響を担当者と R10 で確認 |
| R08 | 新版公開済み／実機確認待ち | 編集可能な AVD パラメーター | 従来の入力順を維持し、Custom Configuration Script Url、Vm Number Of Instances（既定1、1～10）、Hostpool Type（既定 Pooled）、Load Balancer Type（既定 BreadthFirst）を追加。Personal は Persistent／Automatic／1セッションに連動。パスワードは secure。Object ID は `deployer()` |
| R09 | GitHub 固定版を既定にして公開済み／実機確認待ち | VM・イメージ・外部スクリプト | D4as_v6／Office 入り25H2を既定にし、Windows 11 23H2～26H2 の Office あり／なしを選択可能。OS 日本語化 PS1 を出典付きで同梱し、GitHub 固定コミットの匿名取得・内容一致を確認。初回／追加ホストの既定 URL も切替済み。空欄で省略可能。Office 日本語化は別途 Intune。利用資格、地域・サポート期限、`latest` と依存モジュールの版固定、VM 内ハッシュ／署名検証、自動再起動と時間を確認 |
| R10 | 一部確認済み・更新版の実機確認待ち | 通しリハーサル | 旧版は利用者報告で Network／AVD を試行し、Windows App 接続と日本語化を確認。今回の Network 2方式、編集可能な AVD 版、追加ホスト版を検証し、Network → Windows 365 → AVD → SSO 接続を通し確認する。SSO、登録キー、22:00 停止、待機・失敗・再実行・Windows 365 への影響も記録 |
| R11 | 未整備 | 保持・削除 | Day 2 保持、停止後の課金、Windows 365 担当者への確認、RG 削除可否、ANC／Entra デバイス等の残存処理を具体化。旧タグ依存の削除スクリプトは使わない |
| R12 | ローカル実装済み | 接続用 RBAC | 実行メンバーユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login を付与。ロール作成権限、反映、別アカウントによる代行時の挙動を実機確認 |
| R13 | IaC 実装済み・講師準備／接続待ち | SSO | ホストプールの `enablerdsaadauth:i:1` は常時設定。Windows Cloud Login のテナント準備は講師担当。Windows App、クライアント要件、Conditional Access／MFA と実接続を確認 |
| R14 | 撮り直し待ち | スクリーンショット | 旧画像は出典付き参考として保持。新版の入力値と既定値、権限・ホスト登録・SSO・停止設定・接続成功を機密マスクして撮影 |
| R15 | 新版公開済み／実機確認待ち | 既存プールへのホスト追加 | `session-host.json` は指定した追加台数（既定1、1～10）の VM／NIC／拡張機能／VM Login RBAC／22:00停止を作成。SKU 選択・任意スクリプト URL は初回と共通。ホストプール・DAG・Workspace は変更しない。登録キーは secure。別 RG の VNet 指定、名前衝突、イメージ等の互換性と実接続を確認 |
| R16 | IaC 実装・公開済み／実機確認待ち | AVD VM の22:00停止 | AVD 作成・追加ホストの各 VM に毎日22:00 `Tokyo Standard Time` の自動停止を追加。進行中セッションの中断と、ディスク等の課金継続を案内 |
| R17 | **要決定**・手順案あり | Day 2 セキュアジャンプ VNet の作成方式 | ジャンプ先 VNet を Deploy to Azure（IaC）で作るか、受講者が portal で手動作成するかを決定する。現在の Day 2 手順は手動作成案で未確定。VNet Peering は手動の方針。決定後、手順と所要時間を更新する。別 CIDR、Public IP／NAT Gateway なし、日本語化なし、ダブルホップ、22:00停止を維持し、受信元・ルート・外向き通信は講師承認が必要 |
| R18 | 手動手順追加・テナント確認待ち | 動的デバイスグループ | AVD セッションホストと Windows 365 Cloud PC 用の動的デバイスグループのルールを追加。グループ作成・ライセンス・実デバイスへのルール適用・ポリシー割り当ては講師が確認。プロビジョニングの必須条件ではない |
| R19 | 2項目を修正・公開済み／全体照合待ち | 標準作成＋Entra SSO と RDP プロパティの整合 | `enablecredsspsupport:i:1`、`videoplaybackmode:i:1` を明示し、SSO・クリップボード転送・音声は維持。期待値側の［詳細］の実際の `customRdpProperty` と比較し、デバイス／ディスプレイ設定の意図しない差を特定する。テンプレートのダウンロードや GUI の未指定表示だけでは実効値を確定しない。一般の既定値一覧と新規プールの転送既定値には差があるため一括許可しない。実際のホストプール GUI／接続は未確認 |

## 確定した設計上の差

記事の日時式を既定の VM 名プレフィックスとして使い、portal で編集可能にしました。Network は NAT Gateway を使う運用方式（`defaultOutboundAccess: false`）と、NAT を使わず Azure の既定送信アクセスを使う検証方式（`defaultOutboundAccess: true`）を選べます。検証方式の送信元 IP は固定されず、運用方式には NAT Gateway／Public IP の継続費用が発生します。RBAC とホストプール SSO も IaC へ追加しています。登録トークン・パスワードは保護設定／secure parameter に限定し、秘密を出力しません。

Windows Cloud Login のテナント設定、Windows 365、NSG の追加設計、実機確認、保持・削除は公開とローカル IaC の完成とは別です。**Azure 実機成功・完成版とはまだ表示しません。**
