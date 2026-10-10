# 本番化前の修正・確定事項

記事の3サブネットと固定値、手動作成する任意名の演習用 RG、AVD の自動 RBAC・SSO を採用しました。Network と AVD は同じ RG を使います。**テンプレートの公開・ローカル検査と Azure 実機確認済みを区別**します。2026-10-07 に旧版を試行し、Windows App 接続成功・日本語化も問題なさそうとの利用者報告がありますが、今回の任意 RG 対応版を Azure で実行した確認はありません。

## 実装状況と配布前の残項目

| ID | 状態 | 対象 | 実施済み／残作業・完了条件 |
| --- | --- | --- | --- |
| R01 | ローカル実装済み | 共通ネットワークの統一 | `vnet-vdi`／`10.10.0.0/16`、Cloud PC・Server・AVD の3サブネットに統一。実作成・NAT 関連付け確認は R10 |
| R02 | 担当確認待ち | Windows 365 の受け渡し | `snet-cloudpc` を用意。担当者と ANC／Microsoft ホスト型の方式、VNet 利用、通信・権限、待機・復帰条件を照合。Windows 365 実装は担当側 |
| R03 | 公開・raw取得確認済み | 2つの ARM JSON | `templates/network.json` と `templates/avd.json` を固定コミットに公開。AVD モジュールは埋め込み済み。匿名 HTTP 取得・JSON 解析・ローカル SHA-256 一致を確認。任意 RG 対応版の Azure 実行は R10 |
| R04 | 対応済み・公開 URL 確認済み | 配信・版固定 | `Yuyanz9/avd-hands-on` の Deploy ボタンは `resources/deploy-links.json` に記録した固定コミットの ARM JSON を参照。コミット SHA とテンプレートの SHA-256 を管理し、匿名 URL の取得一致を確認 |
| R05 | 任意 RG 対応テンプレート公開・ボタン切替待ち | 手動 RG と権限 | 更新 ARM は任意名の RG に対応。ボタン切替までは旧テンプレートのため `rg-vdi` を選択。切替後は Japan East、必須タグなし、Network／AVD で同一の既存 RG を使う。別々の RG へのデプロイは非対応。作成・IAM 画面の撮影と権限リハーサルは未実施 |
| R06 | 一部実装・設計確認待ち | 送信・受信制御 | 3サブネットに NAT と `defaultOutboundAccess: false` を明示。記事同様 NSG は未追加。Windows 365／AVD の通信と受信・東西制御を配布前に確認 |
| R07 | ローカル実装済み | Windows 365 後の Network 保護 | AVD は既存ネットワーク参照のみ。VNet・サブネット・NAT の作成／再適用は含まない。実際の ANC 等への影響は担当者と R10 で確認 |
| R08 | ローカル実装済み | 固定パラメーター | Network は入力なし、AVD は secure password 1つだけ。Object ID は `deployer()`、VM 名は固定 `avd-0`。サブスクリプションと同じ演習用 RG は portal で選択し、両デプロイで一致させる |
| R09 | 設定済み・実機確認待ち | VM・イメージ・外部スクリプト | 記事の D4as_v6／Office 入り Windows 11 25H2／日本語設定を採用。提供可否・クォータ・利用資格、`latest` の版固定、日本語設定スクリプトの更新・自動再起動による失敗と時間を確認 |
| R10 | 一部確認済み・更新版の実機確認待ち | 通しリハーサル | 旧版は利用者報告で Network／AVD を試行し、Windows App 接続と日本語化を確認。任意 RG 対応版を講師権限で同一 RG にデプロイし、Network → Windows 365 → AVD → SSO 接続を通し確認する。SSO のシームレスな資格情報フロー、待機・失敗・再実行・Windows 365 への影響も記録 |
| R11 | 未整備 | 保持・削除 | Day 2 保持、停止後の課金、Windows 365 担当者への確認、RG 削除可否、ANC／Entra デバイス等の残存処理を具体化。旧タグ依存の削除スクリプトは使わない |
| R12 | ローカル実装済み | 接続用 RBAC | 実行メンバーユーザーへ DAG の Desktop Virtualization User と VM の Virtual Machine User Login を付与。ロール作成権限、反映、別アカウントによる代行時の挙動を実機確認 |
| R13 | IaC 実装済み・講師準備／接続待ち | SSO | ホストプールの `enablerdsaadauth:i:1` は常時設定。Windows Cloud Login のテナント準備は講師担当。Windows App、クライアント要件、Conditional Access／MFA と実接続を確認 |
| R14 | 撮り直し待ち | スクリーンショット | 旧画像は出典付き参考として保持。新版の既存 RG 選択、Network 入力なし、AVD パスワードだけ、権限・ホスト登録・SSO・接続成功を機密マスクして撮影 |

## 確定した設計上の差

記事と異なり、日時ベースの VM 名を `avd-0` に固定し、暗黙の送信を無効にしています。RBAC とホストプール SSO も IaC へ追加しました。登録トークン・パスワードは保護設定／secure parameter に限定し、秘密を出力しません。

Windows Cloud Login のテナント設定、Windows 365、NSG の追加設計、実機確認、保持・削除は公開とローカル IaC の完成とは別です。**Azure 実機成功・完成版とはまだ表示しません。**
