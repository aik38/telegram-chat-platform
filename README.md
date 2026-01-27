# Telegram Generic Chat Bot

Telegram向けに再利用可能な汎用チャットボットプラットフォームです。キャラクターモジュールを差し替え可能な構成で、このREADMEは入口ガイドとして進行状況やタスクの最新情報は `docs/WBS.md`（唯一のWBS）を参照してください。スナップショットは `docs/WBS_PROGRESS.md` に残しています。
価格設計やローンチ前チェックリストは `docs/pricing_notes.md` と `docs/launch_checklist.md`（MVP向け48hチェックリスト、冒頭に30〜60分のショートラン手順あり）を参照してください。運用時の SQLite バックアップ/リストア手順は `docs/sqlite_backup.md` にまとめています。

## 最初にやること（30〜60分ショートラン）
`docs/launch_checklist.md` のショートラン手順を起点に、以下の3ステップで MVP ローンチを最短確認します。

1. `pytest -q`
2. `python -m bot.main`
3. Telegram で `/start` `/help` `/buy` `/status` を確認

マーケ素材、SNS整備、監視ダッシュボード等は「ローンチ後」に回して問題ありません。ショートラン後は同じ `docs/launch_checklist.md` の 48h チェックリストを STEP3 として実行してください。

## インストール / 開発ルーチン（telegram sync）

```bash
pip install -r requirements.txt
```

- 日常運用は PowerShell で `tools/sync.ps1` を実行する想定です。内部で `git pull --rebase` → `.venv\Scripts\python.exe -m pytest -q` → 変更があれば commit/push の順で回します。
  - Windows 由来の junk（Desktop.ini など）だけが差分の場合は commit をスキップします（PR #47 実装）。
- デスクトップショートカット（Update+Start など）運用は廃止し、起動は `StartBots.cmd` に一本化しています。

## Windows quick start

### 起動はこれだけ（recommended）

1. リポジトリ直下の `StartBots.cmd` をダブルクリックします。
2. メニューでアプリ（LINE / Tarot / Arisa）を選択します。
3. LLM（openai / gemini）を選択し、単独で起動します（同時起動はしません）。

- Provider 切替は `DOTENV_FILE` の切替だけで行います。
  - Tarot: `.env.gemini` / `.env.openai`
  - Arisa: `.env.arisa.gemini` / `.env.arisa.openai`
  - LINE: `.env.gemini` / `.env.openai`
- Tarot / Arisa は **Telegram Bot**、LINE は **API サーバー** です（Bot と API は別プロセス）。
- すべて **ポート 8000 単独起動** が前提です（同時起動しません）。

### 手動起動（PowerShell）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_tarot.ps1 -DotenvFile .env.openai
powershell -ExecutionPolicy Bypass -File scripts/run_arisa.ps1 -DotenvFile .env.arisa.gemini
powershell -ExecutionPolicy Bypass -File scripts/run_line.ps1 -DotenvFile .env.openai -Port 8000
```

### scripts/ と tools/ の役割

- `scripts/`: 起動エントリや運用スクリプト（PowerShell）。
- `tools/`: 補助ユーティリティ（Python/PowerShell）。

## Troubleshooting（Windows）

### WinError 10048（ポート衝突）

- `uvicorn` 起動時に `WinError 10048` が出る場合、`8000` が既に使用中です。
- 既に使用中であれば、該当プロセスを停止してから再起動してください。

### TelegramConflictError（同一トークンの多重 polling）

- 同じ `TELEGRAM_BOT_TOKEN` で複数プロセスが `getUpdates` を実行すると `TelegramConflictError` が発生します。
- 起動中の Bot を停止してから再起動してください（同時起動しません）。
- Bot 起動時に `.locks/` 配下へロックファイルを作成し、多重起動は自動で停止します。前回クラッシュでロックが残った場合は `.locks/` を削除してから再起動してください。

### git stash の引用符（PowerShell）

- `git stash drop stash@{0}` は PowerShell で誤解釈されることがあるため、**必ず引用符**で囲んでください。
  - 例: `git stash drop "stash@{0}"`


## Windows最短起動（Bot）

PowerShell で **1コマンド** で Bot（aiogram）を起動する手順です。API サーバー（Uvicorn）は別コマンドなので、Bot を動かしたい場合は以下のスクリプトを使ってください。

### ダブルクリック起動（StartBots.cmd）

- リポジトリ直下の `StartBots.cmd` が唯一の起動入口です。
- ダブルクリック後は **アプリ選択 → LLM 選択 → 単独起動** の順で進みます。

> `DOTENV_FILE` を指定しない場合は `.env` を読み込みます。環境切替後は **必ずプロセスを再起動** してください。

### Arisa を動かす

1. リポジトリ直下に `.env.arisa.openai` もしくは `.env.arisa.gemini` を作成し、`TELEGRAM_BOT_TOKEN`, `OPENAI_API_KEY`, `SQLITE_DB_PATH`, `CHARACTER=arisa`, `PAYWALL_ENABLED` など必要な環境変数を設定します。
   - QA用に管理者テストをする場合は `.env.arisa.*` に `ADMIN_USER_IDS=123456789,987654321` のようにカンマ区切りで Telegram のユーザーIDを指定します。
2. PowerShell で以下を実行します。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_arisa.ps1 -DotenvFile .env.arisa.gemini
```

### Tarot（通常モード）で起動する

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_tarot.ps1 -DotenvFile .env.gemini
```

### LINE API サーバーを起動する

**手動起動**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_line.ps1 -DotenvFile .env.gemini -Port 8000
```

**どこからでも起動（PowerShell 7 / 絶対パス）**

```powershell
$repo = "C:\Users\OWNER\OneDrive\デスクトップ\telegram-chat-platform"
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts\run_line.ps1") -DotenvFile (Join-Path $repo ".env.openai") -Port 8000
```

絶対パスで実行する場合（カレント不問）:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\telegram-chat-platform\scripts\run_line.ps1" -DotenvFile "C:\path\to\telegram-chat-platform\.env.openai" -Port 8000
```

### 補足

- 上記スクリプトは `DOTENV_FILE` を読み込み、Bot / API を起動します。
- `.venv` があればその Python を優先して使います。
- `.env` / `.env.*` は **コミット禁止** です（`.env.example` のみ追跡対象）。

### /start とボタンの簡易手動テスト（default / Arisa）

1. 通常モード（default）
   1. `scripts/run_tarot.ps1` で起動し、Telegram で `/start` を送信。
   2. 下段ボタンが「🎩占い」「💬相談」「🛒チャージ」「📊ステータス」「🌐 言語設定」になっていることを確認。
   3. 「🎩占い」「💬相談」をそれぞれタップし、各モードの案内が返ることを確認。
   4. 「🌐 言語設定」をタップし、3言語の選択肢が表示されることを確認。
2. Arisa モード（CHARACTER=arisa）
   - Arisa の「💖恋愛」「🔥セクシー」開始文はランダムに切り替わります。また Store/Status はモードに関係なく常に利用できます。
   1. `.env.arisa.gemini` を用意して `scripts/run_arisa.ps1` で起動し、Telegram で `/start` を送信。
   2. 上段ボタンが「💖恋愛」「🔥セクシー」に切り替わっていることを確認。
   3. 「💖恋愛」「🔥セクシー」をそれぞれタップし、Arisa 専用の促し文がランダムに返ることを確認。
   4. 「🛒チャージ」「📊ステータス」をタップし、どのモードでも Store/Status が開くことを確認。
   5. 「🌐 言語設定」をタップし、3言語の選択肢が表示されることを確認。

### Arisa コマンド制御の更新（概要）

- Arisa モードで未許可コマンド（例: `/read1` `/buy`）を安全にブロックし、ValueError を起こし得る `Command()`（引数なし）を排除。
- Arisa の `/start` `/help` `/lang` `/language` `/status` `/store` は専用ハンドラで処理し、既存の default / LINE の挙動は変更しない。

### Arisa Love Style Card（管理者切り替え）

- Arisa（admin-only）: `/love_style` で Love（romance）モードの Style Card を確認/変更できます（詳細は `characters/arisa/README.md`）。

### Arisa コマンド制御の手動確認

1. `.env.arisa.gemini` を用意して `scripts/run_arisa.ps1` を実行。
2. Telegram で `/start` を送信し、Arisa メニューが出ることを確認。
3. `/help` `/lang` `/language` がそれぞれ案内/言語選択を返すことを確認。
4. `/status` `/store` で Store/Status が表示されることを確認。
5. `/read1` `/buy` など未許可コマンドがブロック文言で返ることを確認。
6. `scripts/run_tarot.ps1` で起動し、default の `/start` `/read1` が従来通り動作することを確認。



### Arisa 収益化 v2（Stars + トークン課金）の簡易確認

1. `.env.arisa.gemini` に `CHARACTER=arisa`, `ONE_MESSAGE_TOKENS=600`, `TRIAL_FREE_CREDITS=10` を設定して起動。
2. 新規ユーザーで `/start` を送信し、初回10通の試用が付与されることを `/status` で確認。
3. `/status` にチケット残・試用残・パス状態・Sexy解放が表示されることを確認。
4. 「🔥セクシー」を押下し、未課金の場合はティーザー + `/store` 誘導になることを確認。
5. 100⭐️購入で+15通、初回のみ追加+15通（合計30通相当）が付与されることを確認。
6. 7日/30日パスを購入し、本日の残り回数が減ること・上限で止まることを確認。
7. 言語を EN/PT に切り替えて `/store` `/status` が自然訳で表示されることを確認。
8. `scripts/run_tarot.ps1` で起動し、占い/星の王子さまの文言や動作が変わらないことを確認。

### 主な環境変数

- `.env.example` を `.env` にコピーして値を埋めてください。
- `SUPPORT_EMAIL`: 利用規約やサポート案内に表示するメールアドレス。未設定時は `hasegawaarisa1@gmail.com` が使われますが、ダミー表記を避けるため環境変数で上書きする運用を推奨します。
- `OPENAI_BASE_URL`: OpenAI互換APIのエンドポイント。未設定/空の場合は従来通りOpenAIへ接続します。
  - 例: Gemini (OpenAI互換) `https://generativelanguage.googleapis.com/v1beta/openai/`
  - 例: DeepSeek (OpenAI互換) `https://api.deepseek.com/v1`
- `OPENAI_MODEL` / `LINE_OPENAI_MODEL`: 接続先に合わせてモデルIDの変更が必要です。
- `THROTTLE_MESSAGE_INTERVAL_SEC` / `THROTTLE_CALLBACK_INTERVAL_SEC`: テキスト送信・ボタン連打それぞれの最小間隔（秒）。未設定時は 1.2s / 0.8s のままです。負荷試験時に環境変数で調整してください。
- LINE Webhook 用（LINE Messaging APIを利用する場合）
  - `LINE_CHANNEL_SECRET`: チャネルシークレット。署名検証に使用します。
  - `LINE_CHANNEL_ACCESS_TOKEN`: チャネルアクセストークン。LINE返信APIを呼ぶ際に使用します。
  - `LINE_ADMIN_USER_IDS`: 管理者だけが「今日の星」「ミニ占い」を実行できます。カンマ区切りで指定。
  - `LINE_FREE_MESSAGES_PER_MONTH`: 一般ユーザーの月間無料メッセージ上限。未設定時は 30 回/月。
  - `LINE_VERIFY_SIGNATURE`: 署名検証の ON/OFF（デフォルトは `true`。開発でのみ OFF を想定）。
  - `PRINCE_SYSTEM_PROMPT`: 「星の王子さま」人格のシステムプロンプト上書き用。未設定時はデフォルトの短め日本語プロンプトを利用。
  - `LINE_OPENAI_MODEL`: LINE返信用の OpenAI モデル指定（デフォルト `gpt-4o-mini`）。

### シークレット運用ルール

- `.env` を含むシークレットファイルはコミットしないでください（`.env.example` のみを追跡対象にします）。
- ログや print で BOT_TOKEN / OPENAI_API_KEY などの値を直接出力しないでください。`core.logging.SafeLogFilter` がコンソールと `logs/bot.log` でトークンをマスクするので、開発時はこのロガーを経由する形を維持してください。
- 調査でシークレット値を扱う場合は、メモやスクリーンショットにも残さない運用を徹底してください。

### 管理者ID（ADMIN_USER_IDS）の設定

- 管理者にしたい Telegram アカウントの **個人チャットの Chat ID** を取得します。
  - 例: RawDataBot (`@raw_data_bot` など) で `/start` し、表示される `id` の値を控える。
- `ADMIN_USER_IDS` はカンマ区切りで複数指定できます。
  - 例: `1357890414,123456789`
- 管理者アカウントは検証用途（課金や上限の確認）で利用する想定です。
- PowerShell での起動例:

  ```powershell
  cd "...\telegram-chat-platform"
  .\.venv\Scripts\Activate.ps1
  $env:ADMIN_USER_IDS="1357890414"
  python -m bot.main
  ```

## 開発環境での起動方法

- Bot 起動: `python -m bot.main`
- API 起動: `uvicorn api.main:app --reload --port 8000`
- LINE Webhook（開発向け）:
  1. `.env` に `LINE_CHANNEL_SECRET` / `LINE_CHANNEL_ACCESS_TOKEN` / `LINE_ADMIN_USER_IDS` を設定。署名検証を暫定的に外す場合のみ `LINE_VERIFY_SIGNATURE=false` を追加。
  2. `scripts/run_line.ps1` を起動（API 起動 → `http://127.0.0.1:8000/health` を確認）。
  3. 公開 URL を用意している場合は `.../webhooks/line` を LINE Developers の Webhook URL に設定し、検証ボタンで 200 OK が返ることを確認します。
  4. Messaging API > チャネル基本設定で Webhook を有効化し、チャネルアクセストークンを発行。
  5. 友だち追加後にメッセージを送ると、会話モードで「星の王子さま」人格が応答し、月間無料枠（デフォルト 30 回）を超えると上限メッセージを返します。

### LINE開発の最短手順

1. 必要な環境変数をセット：`LINE_CHANNEL_SECRET` / `LINE_CHANNEL_ACCESS_TOKEN` / `OPENAI_API_KEY`（必要に応じて `PRINCE_SYSTEM_PROMPT` や `LINE_ADMIN_USER_IDS`）。
2. `scripts/run_line.ps1` を起動し、`http://127.0.0.1:8000/health` を確認。
3. 公開 URL を用意している場合は `.../webhooks/line` を LINE Developers の Webhook URL に設定。
4. LINE から `/whoami` を送信し、返ってきた `userId` を `LINE_ADMIN_USER_IDS` に追記して API を再起動（管理者限定メニュー用）。
5. 本番同等で署名検証を行う（デフォルト ON）。開発時のみ `LINE_VERIFY_SIGNATURE=false` を利用可能。
6. 実機で 10 往復ほどメッセージを送り、「話す」（星の王子さま人格）と管理者限定の「今日の星」「ミニ占い」が期待通り返ることを確認。

### ログ出力

- Bot 起動時に `logs/bot.log` に INFO 以上のログがローテーション付きで保存されます。
- コンソールにも同じログが出力されるため、開発中はどちらでも確認できます。

### Bot の使い方メモ

- メッセージに「占って」と入れると、タロット占いモードでカードを引いて返答します。
- それ以外のメッセージには、雑談や相談に答える通常の会話モードで返信します。
- 例）`今の恋愛運を占ってほしい` → タロットモード、`今日はしんどかった…ちょっと話を聞いて` → 通常会話モード。
- 利用規約と安全ガイドは `/terms` または `/help` から辿れます。

- コマンド：`/read1`（1枚引き）、`/read3`（3枚引き）、`/hexa`（ヘキサグラム）、`/celtic`（ケルト十字）
  - `/read3` はスリーカード（3枚固定）で、1枚目=過去、2枚目=現在、3枚目=未来の時間軸。時間スケール指定がない場合は前後3か月を想定し、流れ・傾向・気づきを示す。出力は見出しなしで `《カード》：` 行を3つ並べ、箇条書きは未来（3枚目）のみ最大3点、断定を避けた提案ベースでまとめる。
  - `/love1` `/love3` は旧コマンドとして互換対応しています。

スリーカード（/read3）の出力イメージ（概念例）:

《カード》：カップの3（正位置）
過去の場面で得た安心感がいまの選択にも響いていそうです。
《カード》：ソードの8（逆位置）
視点を少し変えるだけで、ほどける余地があります。
《カード》：ワンドのペイジ（正位置）
- 気になる誘いがあれば、まず話を聞いてみるときっかけになりそうです。
- 手軽に始められる準備を一つ決め、肩慣らしをしてみてください。
- 迷ったら「なぜ気になるか」を言葉にしてから次の手順を選ぶと動きやすそうです。

### 決済と権限

- `/buy` で Stars (XTR) の商品一覧を表示します。ボタンから決済フローに進みます。
- `/status` でパスの有効期限やチケット残数を確認できます。
- `PAYWALL_ENABLED=true` のとき `/read3` `/hexa` `/celtic` は有料メニュー扱いになります（`/love3` は旧コマンドとして互換対応）。
  - 有効なパス（premium_until が現在より未来）または対応するチケット残高があれば利用可能です。
  - パスが無効でチケットもない場合は実行せず `/buy` を案内します。

## 課金導線スモークテスト（連打含む）

- 前提: テスト用の決済設定を行い、PAYWALL_ENABLED を本番同等に設定する。
- `/buy` で購入メニューを開き、商品ボタンを連打しても Bot が落ちないこと（コンソールに `query is too old` が出ても動作継続する）。
- 同じ商品ボタンを短時間に連打した場合、「購入画面は既に表示しています」と案内され、Invoice が重複発行されないこと。
- 決済確認（pre_checkout_query）は即時に応答し、例外が起きてもプロセスが落ちないこと。
- 決済完了後に「購入ありがとう」「付与内容」「占いに戻る/ステータスを見る」ボタンが表示され、占い導線に戻れること。
- `/status` または「📊ステータスを見る」ボタンで、パス期限・チケット残数・無料枠の次回リセット時刻が1画面で確認できること。
- パスが有効なユーザーは「スリーカード(3枚)」購入ボタンを押しても追加課金に進まず、占いに戻るよう案内されること。

### BotFather 推奨コマンド

`/setcommands` で登録しておく推奨リストです。

```
start - ボットの案内
buy - 有料メニュー購入
status - 利用状況の確認
terms - 利用規約の表示と同意
support - お問い合わせ窓口
paysupport - 決済トラブル対応窓口
read1 - 1枚引き
read3 - 3枚引き
hexa - ヘキサグラム（7枚）
celtic - ケルト十字（10枚）
```

## よくあるエラー（Troubleshooting）

- `TelegramConflictError: terminated by other getUpdates request` が出る場合は、**同じ BOT トークンで polling が二重起動している**（または webhook と競合している）ことが多いです。
  - 対処: 旧プロセスを停止し、polling 運用では `deleteWebhook` を実行してから、同時に1インスタンスだけ起動するようにしてください。

## タロットロジックの内部構造

- `core/tarot/cards.py`
  - 大アルカナ22枚・小アルカナ56枚のカード定義（ID、和名・英名、正逆キーワードなど）
- `core/tarot/spreads.py`
  - 1枚引きと3枚引き（状況・障害・未来）のスプレッド定義
- `core/tarot/draws.py`
  - スプレッドに応じてカードをランダムに抽選する `draw_cards`、正逆表記ヘルパー

Bot からはスプレッドを選び `draw_cards` を呼ぶだけで、カードと正逆のセットが得られます。

## 二重モードの使い方例

- 通常チャット例（タロット用語は禁止）
  - 入力: `最近仕事で疲れています。`
  - 出力: カウンセリング寄りの励ましや提案。カード名やタロット用語は出さない。
- 占いモード例（カード名＋正逆を必ず提示）
  - 入力: `最近仕事がきついので、今後について占ってほしいです。`
  - 出力: `引いたカードは次の通りです…` とカード名・正位置/逆位置を列挙し、その後でリーディングを提供。

### 仕様メモ

- 通常チャットでは「占って」「タロット」「カードを引いて」などの明確な依頼がない限り、占い・カードの話題は出さない。
- 通常チャットの返答にタロット用語が紛れた場合は自動的にリライトし、再度含まれる場合は該当文を削除して安全に返す。
- タロット占いモードでは回答の先頭で必ず引いたカード名と正逆を明示する。
- 断定的な表現は避け、落ち着いた敬語で安心感のあるトーンを保つ。

### テスト

system python だと `pytest` が見つからない場合があるため、必ず venv を前提に実行してください。

1) `.venv` を有効化して実行する場合

```powershell
.\.venv\Scripts\Activate.ps1
python -m pytest -q
```

2) 有効化せずに venv の python を直指定する場合

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

### LINE Webhook ローカル検証

- ローカルで LINE Webhook を叩くテスト: `python tools/test_line_webhook.py`
  - `.env` から `LINE_CHANNEL_SECRET` を読み、署名付きで `http://localhost:8000/webhooks/line` に POST します（環境変数 `LINE_WEBHOOK_URL` でURL上書き可）。

## Dev routine (daily)
1) Run `tools/sync.ps1` (= telegram sync): `git pull --rebase` → `.venv\Scripts\python.exe -m pytest -q` → 変更があれば commit/push（junk だけなら commit しない）。
2) Pick next item from `docs/WBS.md` (Next 10 tasks)
3) Use Codex (web) to implement 1 task per PR
4) After merge: run sync again and smoke-test `/start` `/buy` `/status`

## Launch checklist (public + marketing start)
詳細は `docs/launch_checklist.md` に集約。進行状況とWBSは `docs/WBS.md` を参照してください。

## 次に見るドキュメント
- `docs/WBS.md`: 唯一のWBS（進行中タスクと優先度）
- `docs/WBS_PROGRESS.md`: 進捗スナップショット
- `docs/launch_checklist.md`: ショートラン＆48hチェックリスト
- `docs/runbook.md`: 運用・トラブルシュート
- `docs/pricing_notes.md`: 価格と課金まわりのメモ

## 運用：環境切替（Gemini / OpenAI）

このリポジトリは `DOTENV_FILE` を指定するだけで LLM 接続先を切り替えられます。  
（例: `.env.gemini` / `.env.openai` を用意しておき、起動時に `DOTENV_FILE` を指定します）

### Geminiで動かしたい日

PowerShell でリポジトリ直下にて実行します。

```powershell
$env:DOTENV_FILE = ".env.gemini"
powershell -ExecutionPolicy Bypass -File scripts/run_tarot.ps1
````

その後、Windows 側の `StartBots.cmd` から起動してください。

### OpenAIに戻す日

```powershell
$env:DOTENV_FILE = ".env.openai"
powershell -ExecutionPolicy Bypass -File scripts/run_tarot.ps1
```

その後、Windows 側の `StartBots.cmd` から起動してください。

注意:

* 切替は「起動前」に行ってください（起動中に `DOTENV_FILE` を切り替えても反映されません）
* `.env` 内で `OPENAI_BASE_URL` / `OPENAI_MODEL` / `OPENAI_API_KEY` を重複定義しないでください（意図しない値が読まれる原因になります）

## Gemini/OpenAIの切替手順（追記）

- Geminiで動かしたい日: `DOTENV_FILE=.env.gemini` を指定して起動
- OpenAIに戻す日: `DOTENV_FILE=.env.openai` を指定して起動
- その後ダブルクリック起動でOK（起動中なら停止してから切替）
- `.env` に同じキー（OPENAI_BASE_URL 等）を複数回書かないでください

## Windows起動の切替確認（.envを触らずに6パターン）

`.env` を上書きせずに `DOTENV_FILE` で切替できることを確認する手順です。`StartBots.cmd` を使い、各組み合わせを都度選択して起動します。起動中のプロセスは必ず停止してから次へ進めてください。

1. Tarot (OpenAI): StartBots.cmd → Bot=tarot / LLM=openai を選択 → 起動ログで `DOTENV_FILE=.env.openai` を確認。
2. Tarot (Gemini): StartBots.cmd → Bot=tarot / LLM=gemini を選択 → 起動ログで `DOTENV_FILE=.env.gemini` を確認。
3. Arisa (OpenAI): StartBots.cmd → Bot=arisa / LLM=openai を選択 → 起動ログで `DOTENV_FILE=.env.arisa.openai` を確認。
4. Arisa (Gemini): StartBots.cmd → Bot=arisa / LLM=gemini を選択 → 起動ログで `DOTENV_FILE=.env.arisa.gemini` を確認。
5. LINE (OpenAI): StartBots.cmd → Bot=line / LLM=openai を選択 → 起動ログで `DOTENV_FILE=.env.openai` を確認。
6. LINE (Gemini): StartBots.cmd → Bot=line / LLM=gemini を選択 → 起動ログで `DOTENV_FILE=.env.gemini` を確認。

## GitHubでmainにマージ後、ローカルへ反映する（Windows / PowerShell）

ローカルPCへ確実に反映するための PowerShell コマンド例です。PowerShell では行継続に `^` は使いません（cmd専用）。1行で書くか、必要ならバッククォート `` ` `` を使ってください。

### A) 更新だけ（安全・最短）

```powershell
cd "$env:USERPROFILE\OneDrive\デスクトップ\telegram-chat-platform"
git pull --rebase origin main
```

### B) 更新 + 簡易チェック（compileall）

> `compileall` は **リポジトリ全体 "." を対象にしない** でください（`.git` を踏んで壊れるため）。対象ディレクトリを限定します。

```powershell
cd "$env:USERPROFILE\OneDrive\デスクトップ\telegram-chat-platform"
git pull --rebase origin main
.\.venv\Scripts\Activate.ps1
python -m compileall -q api bot core characters tools
```

### 実行後の起動

- 起動は `StartBots.cmd` を使ってください（既存の `scripts/run_*.ps1` の案内がある場合はそちらに従ってください）。
- `scripts/` は PowerShell のみなので `compileall` の対象外です。
