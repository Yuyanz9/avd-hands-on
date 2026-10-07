# 本番化前の修正・確定事項

記事の3サブネットと固定値、手動 `rg-vdi`、AVD の自動 RBAC・SSO を採用しました。**ローカル実装済みと Azure 実機確認済みを区別**します。公開・push・実デプロイは未実施です。

## 実装状況と配布前の残項目

| ID | 状態 | 対象 | 実施済み／残作業・完了条件 |
| --- | --- | --- | --- |
| R01 | ローカル実装済み | 共通ネットワークの統一 | `vnet-vdi`／`10.10.0.0/16`、Cloud PC・Server・AVD の3サブネットに統一。実作成・NAT 関連付け確認は R10 |
| R02 | 担当確認待ち | Windows 365 の受け渡し | `snet-cloudpc` を用意。担当者と ANC／Microsoft ホスト型の方式、VNet 利用、通信・権限、待機・復帰条件を照合。Windows 365 実装は担当側 |
| R03 | ローカル実装済み | 2つの ARM JSON | `templates/network.json` と `templates/avd.json` を生成。AVD モジュールは埋め込み済み。公開取得と portal 実行は未確認 |
| R04 | 未公開 | 配信・版固定 | README バッジはリンクなし。将来公開先を指定して `Set-DeployButtons.ps1` で固定コミット URL を設定し、匿名取得と同梱 JSON のハッシュを確認。repo 作成・公開・push は別途依頼時のみ |
| R05 | 方針反映済み・画像待ち | 手動 RG と権限 | 記事同様 `rg-vdi`／Japan East、必須タグなし、既存 RG を両ボタンで選択。作成・IAM 画面の撮影と権限リハーサルは未実施。固定名のため個別演習の環境分離も要確認 |
| R06 | 一部実装・設計確認待ち | 送信・受信制御 | 3サブネットに NAT と `defaultOutboundAccess: false` を明示。記事同様 NSG は未追加。Windows 365／AVD の通信と受信・東西制御を配布前に確認 |
| R07 | ローカル実装済み | Windows 365 後の Network 保護 | AVD は既存ネットワーク参照のみ。VNet・サブネット・NAT の作成／再適用は含まない。実際の ANC 等への影響は担当者と R10 で確認 |
| R08 | ローカル実装済み | 固定パラメーター | Network は入力なし、AVD は secure password 1つだけ。Object ID は `deployer()`、VM 名は固定 `avd-0`。選択サブスクリプション・RG は portal で手動確認が必要 |
| R09 | 設定済み・実機確認待ち | VM・イメージ・外部スクリプト | 記事の D4as_v6／Office 入り Windows 11 25H2／日本語設定を採用。提供可否・クォータ・利用資格、`latest` の版固定、日本語設定スクリプトの更新・自動再起動による失敗と時間を確認 |
| R10 | 未実施 | 通しリハーサル | 受講者相当の権限で手動 RG → Network ボタン → Windows 365 → AVD ボタン → SSO 接続を確認。待機・失敗・再実行・Windows 365 への影響を記録 |
| R11 | 未整備 | 保持・削除 | Day 2 保持、停止後の課金、Windows 365 担当者への確認、RG 削除可否、ANC／Entra デバイス等の残存処理を具体化。旧タグ依存の削除スクリプトは使わない |
| R12 | ローカル実装済み | 接続用 RBAC | 実行メンバーユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login を付与。ロール作成権限、反映、別アカウントによる代行時の挙動を実機確認 |
| R13 | IaC 実装済み・講師準備／接続待ち | SSO | ホストプールの `enablerdsaadauth:i:1` は常時設定。Windows Cloud Login のテナント準備は講師担当。Windows App、クライアント要件、Conditional Access／MFA と実接続を確認 |
| R14 | 撮り直し待ち | スクリーンショット | 旧画像は出典付き参考として保持。新版の既存 RG 選択、Network 入力なし、AVD パスワードだけ、権限・ホスト登録・SSO・接続成功を機密マスクして撮影 |

## 確定した設計上の差

記事と異なり、日時ベースの VM 名を `avd-0` に固定し、暗黙の送信を無効にしています。RBAC とホストプール SSO も IaC へ追加しました。登録トークン・パスワードは保護設定／secure parameter に限定し、秘密を出力しません。

Windows Cloud Login のテナント設定、Windows 365、NSG の追加設計、実機確認、配信先の公開、保持・削除はローカル IaC の完成とは別です。**実機成功・完成版とはまだ表示しません。**
