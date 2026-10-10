# 流用素材と新規本番用 IaC

元資料は削除・移動せずに保持しています。出典パスは `avd-hands-on\` 起点の記録です。この一式の実行・閲覧は親フォルダーへ依存しません。

## 今回の実行入口

| ファイル | 用途 |
| --- | --- |
| [固定設定](infra/settings.json) | 記事の値、3サブネット、AVD の固定設定部分 |
| [Network ソース](infra/network.bicep) | VNet・3サブネット・NAT・Public IP |
| [AVD 入口](infra/avd.bicep)／[モジュール](infra/modules/avd.bicep) | 既定値付き編集可能パラメーター、secure password、実行者 ID、VM・AVD・RBAC・SSO・22:00停止 |
| [セッションホスト共通モジュール](infra/modules/session-host.bicep) | Entra 参加、既存プール登録、日本語設定拡張機能、VM Login RBAC、自動停止 |
| [追加ホスト入口](infra/session-host.bicep) | 既存 Standard 管理プールへ1台を追加。登録キーは secure parameter |
| [Network／AVD／追加ホスト JSON](templates/network.json)／[AVD JSON](templates/avd.json)／[追加ホスト JSON](templates/session-host.json) | Deploy to Azure 用に生成。モジュールは JSON に埋め込み |
| [生成スクリプト](scripts/Build-Templates.ps1) | Azure リソースを作らないローカルコンパイル |
| [ボタン設定スクリプト](scripts/Set-DeployButtons.ps1) | 公開リポジトリとテンプレートを含む固定コミットを指定し、ローカル README／メタデータを更新 |
| [契約テスト](tests/Test-ProductionTemplates.ps1) | 固定値、生成物、接続設定、ボタン生成・失敗時の非更新を確認 |

記事の ARM をコピーしたものではなく、記事の固定設定と既存 Bicep の実装パターンを使って新規に作成しています。外部 ARM の旧ボタンは本番の実行入口から外しました。Day 2 のセキュアジャンプ環境と Peering は、[手動手順](day2-secure-jump.md)だけで行います。

## 取り込んだ参考素材

| 素材 | 元ファイル | 格納先・制約 |
| --- | --- | --- |
| 手動準備・完了条件・安全上の材料 | `docs\portal-deploy-handson.md`、既存参加者・講師ガイド | [統合手順](day1-handson.md)へ再構成。旧 CLI 版の実測・確認済み表示は引き継がない |
| RG タグのマスク済み画像 | `docs\images\day1\resource-group-tags.png` | [参考画像](resources/images/manual/resource-group-tags.png)。今回はタグ必須なし、主手順では使用しない |
| Network の記事画像 | `docs\images\portal-deploy\01-network-deploy.png` | [旧画面](resources/images/portal-deploy/01-network-deploy.png)。新版は入力欄なし |
| AVD の記事画像 | `docs\images\portal-deploy\02-avd-deploy.png` | [旧画面](resources/images/portal-deploy/02-avd-deploy.png)。新版は既存 RG・パスワードのみ |
| 既存ネットワーク欄の拡大 | `docs\images\portal-deploy\03-existing-network-detail.png` | [参考画像](resources/images/portal-deploy/03-existing-network-detail.png)。新版の参照先は固定のため主手順では使用しない |
| 管理者欄の拡大 | `docs\images\portal-deploy\04-admin-password-detail.png` | [参考画像](resources/images/portal-deploy/04-admin-password-detail.png)。実パスワードはない。新版のユーザー名は固定 |
| Network／AVD Bicep | `infra\network.bicep`、`infra\avd.bicep` | [Network コピー](reference/iac/network.bicep)／[AVD コピー](reference/iac/avd.bicep)。比較用であり、ボタンからは実行しない |
| Bicep 設定 | `bicepconfig.json` | [比較用コピー](reference/iac/bicepconfig.json)と [本パッケージの設定](bicepconfig.json) |
| Azure CLI 共通ヘルパー | `scripts\AzureCli.ps1` | [ローカルコピー](scripts/AzureCli.ps1)。生成時のコマンド失敗を例外として扱う。旧タグ検査・削除の機能は本手順では呼び出さない |

画像の出典・加工・許可は [画像一覧](resources/images/README.md)、当初の取り込み元とハッシュは [コピー記録](resources/reuse-manifest.json)を参照します。コピー記録は取り込み時点の資料記録であり、新規に書いた IaC が比較用ファイルと同一であることを示すものではありません。

記事の日本語設定スクリプトと Microsoft の DSC パッケージはローカルへ同梱せず、固定設定の URL から取得します。外部スクリプトの可変性・更新・再起動の課題は [R09](revision-list.md)に残しています。

## 混在させない構成

| 項目 | 今回の本番用一式 | 比較用の既存 Bicep |
| --- | --- | --- |
| ネットワーク | `10.10.0.0/16`、Cloud PC・Server・AVD の3サブネット | `10.42.0.0/16`、Session Hosts・Targets の2サブネット |
| NSG | 記事に合わせ未追加 | 用途別 NSG あり |
| 送信 | 3サブネットに NAT、暗黙送信なし | 2サブネットに NAT、暗黙送信なし |
| 入力 | Network なし、AVD は既定値付き編集可能欄と secure password | 名前・台数・Object ID 等を指定 |
| VM／OS | D4as_v6、Microsoft 365 Apps なしの Windows 11 25H2 AVD | D2s_v5、Windows 11 24H2 |
| 接続・SSO | 実行ユーザーへ RBAC、SSO 常時設定、テナント準備は講師 | Object ID の RBAC、SSO オプトイン |
| 実機確認 | 未実施 | 別ルートの限定確認記録で、本番用一式の実証ではない |

Network＋AVD の一括ルート、旧デプロイ・タグ依存の削除スクリプト、Day 2 の VM／Peering の IaC、Windows 365 の実装は同梱しません。Day 2 の VM と Peering は手動手順に従います。親の資料・内部メモ・PowerPoint・顧客固有情報も対象外です。比較用コピーは自動同期しないため、更新時は差分・ハッシュと本番への影響を確認します。
