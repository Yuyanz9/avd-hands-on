# 本番化前の修正・確定事項

記事の3サブネットと固定値、手動作成する任意名の演習用 RG、AVD の自動 RBAC・SSO を採用しました。Network と AVD は同じ RG を使います。**テンプレートの公開・検査と Azure 実機確認済みを区別**します。2026-10-07 に旧版を試行し、Windows App 接続成功・日本語化も問題なさそうとの利用者報告がありますが、今回の任意 RG 対応版を Azure で実行した確認はありません。

## 実装状況と配布前の残項目

| ID | 状態 | 対象 | 実施済み／残作業・完了条件 |
| --- | --- | --- | --- |
| R01 | ローカル実装済み | 共通ネットワークの統一 | `vnet-vdi`／`10.10.0.0/16`、Cloud PC・Server・AVD の3サブネットに統一。実作成・NAT 関連付け確認は R10 |
| R02 | 担当確認待ち | Windows 365 の受け渡し | `snet-cloudpc` を用意。担当者と ANC／Microsoft ホスト型の方式、VNet 利用、通信・権限、待機・復帰条件を照合。Windows 365 実装は担当側 |
| R03 | 公開済み・raw URL／SHA-256 検証済み | 3つの ARM JSON | Network、AVD、既存プールへの session-host 追加テンプレートを生成・公開。3つとも公開 raw URL から匿名取得し、同梱 JSON と SHA-256 が一致することを確認。Azure 実行は R10 |
| R04 | 対応済み・固定版配信確認済み | 配信・版固定 | Deploy ボタンはコミット `b18d7d073fcf11f83f3ba6f5decef5b4c999bede` に含まれる固定 JSON を参照。URL と SHA-256 は `resources/deploy-links.json` に記録し、匿名取得一致を確認 |
| R05 | 任意名に対応・画像待ち | 手動 RG と権限 | Japan East、必須タグなし。Network と AVD は同一 RG が既定。AVD の VNet RG 入力で同じサブスクリプション内の別 VNet RG も指定可能。作成・IAM 画面の撮影と権限リハーサルは未実施 |
| R06 | 一部実装・設計確認待ち | 送信・受信制御 | 3サブネットに NAT と `defaultOutboundAccess: false` を明示。記事同様 NSG は未追加。Windows 365／AVD の通信と受信・東西制御を配布前に確認 |
| R07 | ローカル実装済み | Windows 365 後の Network 保護 | AVD は既存ネットワーク参照のみ。VNet・サブネット・NAT の作成／再適用は含まない。実際の ANC 等への影響は担当者と R10 で確認 |
| R08 | 実装・公開済み／実機確認待ち | 編集可能な AVD パラメーター | VNet RG／名前／サブネット、Location、image SKU、Workspace 表示名、VM サイズ／ディスク種別、最大セッション数、VM 名プレフィックスを既定値付きで編集可能。パスワードは secure。VM 名は日時プレフィックス＋ `-0`。Object ID は `deployer()` |
| R09 | 設定済み・実機確認待ち | VM・イメージ・外部スクリプト | D4as_v6／Microsoft 365 Apps なしの Windows 11 25H2 AVD イメージ（`windows-11`／`win11-25h2-avd`）／日本語設定を採用。提供可否・クォータ・利用資格、`latest` の版固定、日本語設定スクリプトの更新・自動再起動による失敗と時間を確認 |
| R10 | 一部確認済み・更新版の実機確認待ち | 通しリハーサル | 旧版は利用者報告で Network／AVD を試行し、Windows App 接続と日本語化を確認。今回の編集可能な AVD 版と追加ホスト版を検証し、Network → Windows 365 → AVD → SSO 接続を通し確認する。SSO、登録キー、22:00 停止、待機・失敗・再実行・Windows 365 への影響も記録 |
| R11 | 未整備 | 保持・削除 | Day 2 保持、停止後の課金、Windows 365 担当者への確認、RG 削除可否、ANC／Entra デバイス等の残存処理を具体化。旧タグ依存の削除スクリプトは使わない |
| R12 | ローカル実装済み | 接続用 RBAC | 実行メンバーユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login を付与。ロール作成権限、反映、別アカウントによる代行時の挙動を実機確認 |
| R13 | IaC 実装済み・講師準備／接続待ち | SSO | ホストプールの `enablerdsaadauth:i:1` は常時設定。Windows Cloud Login のテナント準備は講師担当。Windows App、クライアント要件、Conditional Access／MFA と実接続を確認 |
| R14 | 撮り直し待ち | スクリーンショット | 旧画像は出典付き参考として保持。新版の入力値と既定値、権限・ホスト登録・SSO・停止設定・接続成功を機密マスクして撮影 |
| R15 | IaC 実装・公開済み／登録キー手順・実機確認待ち | 既存プールへのホスト追加 | `session-host.json` は VM／NIC／拡張機能／VM Login RBAC／22:00停止のみを作成。既存 Standard プール用の有効な登録キーを事前に生成し、安全に入力する。ホストプール・DAG・Workspace は変更しない。イメージ・サイズ・ID 方式の互換性と実接続を確認 |
| R16 | IaC 実装・公開済み／実機確認待ち | AVD VM の22:00停止 | AVD 作成・追加ホストの各 VM に毎日22:00 `Tokyo Standard Time` の自動停止を追加。進行中セッションの中断と、ディスク等の課金継続を案内 |
| R17 | 手動手順公開済み・講師設計確認待ち | Day 2 セキュアジャンプ | 別 CIDR の VNet／VM を手動作成し、Public IP・NAT Gateway なし、日本語化なし、手動 Peering、ダブルホップ、22:00停止を手順化。受信元・ルート・外向き通信は講師承認が必要 |

## 確定した設計上の差

記事の日時式を既定の VM 名プレフィックスとして使い、portal で編集可能にしました。暗黙の送信を無効にし、RBAC とホストプール SSO も IaC へ追加しています。登録トークン・パスワードは保護設定／secure parameter に限定し、秘密を出力しません。

Windows Cloud Login のテナント設定、Windows 365、NSG の追加設計、実機確認、保持・削除は公開とローカル IaC の完成とは別です。**Azure 実機成功・完成版とはまだ表示しません。**
