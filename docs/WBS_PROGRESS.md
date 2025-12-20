# WBS_PROGRESS - 2025-12-21（launch docs hardening + UX copy pass）

目的: ローンチ前の運用ドキュメント強化（launch checklist/runbook/ux copy/marketing）を反映し、canonical WBS（docs/WBS.md）を最新化したスナップショット。タロット結果フォーマット・料金最適化（T4-07）・相談モード仕様（T3-07）は触らない方針を維持。

## 追加進捗
- docs/launch_checklist.md を手順粒度に揃え、決済スモーク・バックアップ・SNS案内の実施順を具体化。
- docs/runbook.md に「ローンチ当日の初動」「不正・コスト監視（暫定）」を追加し、PAYWALL 切替や返金・手動付与の一次対応を明文化。
- docs/ux_copy.md を新設し、相談モードの価値定義・購入導線テンプレ・丁寧語スタイルガイドを整理（ロジック変更なし）。
- docs/marketing.md / docs/kpi.md を追加し、価値提案 1 文・投稿テンプレ・手動 KPI 集計手順をテンプレ化。

## 今回完了扱いにした主な項目
- 追加の完了タスクはなし。T3-07（相談モード）/T4-07（料金最適化）は現行凍結方針を再確認のみ。

## まだ未着手/要補完の主要ポイント
- プロンプトテンプレの安定化テスト（T4-02）と Bot/FastAPI 分離検討（T4-08）。
- DB 永続化強化（sessions/app_events：T6-03/07）と監視導線（T7-04）。
- 相談モード価値定義・購入導線の文面整理（T8A-04/05）とメッセージ文体ガイド（T8A-06）を docs/ux_copy.md ベースで運用に落とし込む。
- コスト監視と不正対策（T5-09/10）の運用ルール策定（docs/runbook.md / docs/kpi.md を叩き台に拡充）。

## 次に着手すべき10タスク
- docs/WBS.md の「Next 10 tasks」を参照（T8A-04/05/06, T4-02, T4-08, T5-09, T5-10, T6-03, T6-07, T7-04）。
