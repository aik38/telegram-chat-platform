# WBS_PROGRESS - 2025-12-20（lock/queue + postprocess + audit refresh）

目的: 直近のマージ（リクエストID付きログ、per-user ロック/キュー、LLM postprocess、/admin revoke 監査、payment_states.md、launch_checklist.md など）を main に反映した状態を棚卸しし、canonical WBS（docs/WBS.md）を同期したスナップショット。

## 追加進捗
- request_id 付きのロギングとシークレットマスクを全ハンドラに適用。(core/logging.py; bot/main.py RequestIdMiddleware)
- 同一ユーザーの併走セッションをロック＋待機案内で順次処理に統一。(bot/main.py `_acquire_inflight`)
- LLM 出力の改行整形と長文ソフトカットを postprocess で共通化し、OpenAI 呼び出しに組み込み。(bot/utils/postprocess.py; bot/main.py call_openai_with_retry)
- レート制限しきい値を環境変数化し、連打時の案内文面を更新。(core/config.py; bot/texts/ja.py)
- /admin revoke を含む管理者付与/剥奪の監査を追加し、返金・失敗・二重決済の状態遷移を docs/payment_states.md に整理。
- docs/launch_checklist.md を公開前手順として追加。

## 今回完了扱いにした主な項目
- T3-08（併走セッションロック/キュー）、T4-06（LLM postprocess）、T5-06（返金/失敗/二重決済ドキュメント）、T5-07（管理者付与/剥奪＋監査）、T7-01（request_id ログ + マスク）、T7-05（レート制限しきい値環境変数化）、T7-06（シークレット管理）が Done に移行。
- T3-07（相談モード仕様）と T4-07（料金最適化）は現行方針を維持する前提で凍結し、再設計しないことを明記。

## まだ未着手/要補完の主要ポイント
- プロンプトテンプレの安定化テスト（T4-02）と Bot/FastAPI 分離検討（T4-08）。
- DB 永続化強化（sessions/messages/app_events：T6-03/04/07）と監視導線（T7-04）。
- 相談モード価値定義・購入導線の文面整理（T8A-04/05）とメッセージ文体ガイド（T8A-06）。
- コスト監視と不正対策（T5-09/10）の運用ルール策定。

## 次に着手すべき10タスク
- docs/WBS.md の「Next 10 tasks」を参照（T4-02, T4-08, T5-09, T5-10, T6-03/04/07, T7-04, T8A-04/05）。
