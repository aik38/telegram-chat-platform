# 運用切り戻し手順（Phase8/9/10 MVP向け）

既存の占い/相談の文体や出力フォーマットを変えずに、運用で最低限対応するための手順だけをまとめています。すべての操作は国内βのSQLite構成を前提にしています。

## ローンチ当日の初動テンプレ
- **障害検知時の連絡**: まず #ops チャンネルに「検知時刻・事象・ユーザーID/リクエストID（ある場合）・暫定対応」を 3 行で共有する。
- **影響切り分け**: `/admin stats 1` でエラー件数を確認 → 決済なら「決済トラブル」、レスポンス遅延なら「負荷/外部API」、Bot 無応答なら「接続/トークン」。
- **ユーザー返信テンプレ**（チャットに貼る）:
  - 「ただいま調整中です。ご不便をおかけしてごめんなさい。少し時間をおいて再度お試しください。」
  - 決済後の未反映は「/status で付与状況を確認いただき、反映していない場合はこのままお知らせください」と追記。
- **課金を止める/戻す**: 下の「即時リリース/切り戻しトグル」を実行。PAYWALL を閉じたままでも占いは無料で継続できる。

## 即時リリース/切り戻しトグル
- **課金を止める**: `.env` または環境変数で `PAYWALL_ENABLED=false` にして bot を再起動。占い文面はそのまま、チケット消費/パス判定のみ無効化されます。
- **負荷を落とす**: `THROTTLE_MESSAGE_INTERVAL_SEC` / `THROTTLE_CALLBACK_INTERVAL_SEC` を一時的に上げて再起動し、連打を吸収します（例: 2.0 / 1.2）。
- **画像オプションを隠す**: `IMAGE_ADDON_ENABLED=false` でボタンが「準備中」表示に戻ります。

## Bot/API の再起動
1. `.env` を見直し（TOKEN/API_KEY/ADMIN_USER_IDS/PAYWALL_ENABLED）。
2. プロセスを停止してから `python -m bot.main` を再起動（または supervisor/systemd を再起動）。
3. 起動ログで `DB health check: ok` と `polling=True` を確認。

## DB バックアップ/復元（SQLite）
- バックアップ: `cp db/telegram_tarot.db db/telegram_tarot.db.bak_$(date +%Y%m%d%H%M)` を取得（実行前に bot 停止推奨）。
- 復元: bot を止め、`cp db/telegram_tarot.db.bak_YYYYMMDDHHMM db/telegram_tarot.db` で戻す。起動後に `pytest -q` か `/admin stats` で最低限の整合を確認。

## 決済トラブル時の運用
- **重複/未反映**: `/admin grant <user_id> <SKU>` で手動付与し、`/status` 案内を送る。ログは audits/payment_events に残る。
- **返金**: Telegram 決済 ID を確認し `/refund <telegram_payment_charge_id>` を実行。成功メッセージをユーザーへ転送。
- **一時停止**: `PAYWALL_ENABLED=false` にして再起動。相談/占いは無料のまま継続。

## 不正・異常利用の観察ポイント（暫定）
- **疑わしいパターン**: 同一時間帯に同じ相談文を送る別ユーザー、短時間の連続決済→即返金、無料枠だけを日跨ぎ消化する端末。
- **最初の対応**: `/admin stats 1` で急増イベントがないか確認 → 当該 user_id に `/admin revoke <user_id> <SKU>` で一時剥奪し、問い合わせが来たら手動で戻す。
- **記録**: 事象と user_id を #ops にメモし、再発したら IP/端末情報の取得可否を検討（実装前提ではなく運用フラグ）。

## コスト監視（暫定）
- OpenAI Usage の日次をダッシュボードから CSV でエクスポートし、日次トークン合計と上限（暫定: βでは 10 USD/日）を目視。上限を超えそうなら `PAYWALL_ENABLED=true` でも無料枠を縮小する方針を合意。
- bot 停止を避けるため、しきい値超過時はまず管理者に共有 → `THROTTLE_*` を上げる or メニュー案内で無料枠を控えめにする。

## フィードバックとインシデントメモ
- ユーザーからの声: `/feedback <text>` で受け付け。管理者は `/admin feedback_recent 10` で確認。
- 簡易ヘルス/件数: `/admin stats 7` で日次の占い/相談/決済/エラー件数を取得（直近14日まで指定可能）。
- 障害・改善メモ: 発生日・user_id・request_id（rid=）・対処内容をワンライナーで残し、docs/ux_copy.md に相談モードの改善ヒントを追記する。

## 参考ドキュメント
- `docs/sqlite_backup.md`: SQLite バックアップ詳細。
- `docs/launch_checklist.md`: 本番反映前の確認リスト。
- `docs/payment_states.md`: 決済ステートとエラー時の扱い。
