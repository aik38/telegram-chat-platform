# Arisa

## 概要：Arisaの人格は何で決まるか
- 人格の中心は `characters/arisa/prompts/{base,romance,sexy}.txt` のテキストで定義される（日本語は `bot/arisa_prompts.build_system_prompt(...)` が読み込む）。
- 英語/ポルトガル語は `characters/arisa/prompts/{base,romance,sexy}.{en,pt}.txt` が存在する場合に優先して読み込まれ、無ければ日本語の `*.txt` にフォールバックする。
- コード側は、(1) どのモードを使うか（`users.arisa_mode` の保存/参照）、(2) 追加テキスト（`system_prompt*.txt` / `boundary_lines*.txt` / `style*.md` / ソフトな補助文）を足すか、(3) 課金/トライアル/DB状態によるロックやクレジット消費、(4) /start とモード開始文のランダム選択、を司る。
- 実際の合成は `bot/arisa_runtime.build_arisa_messages(...)` が行い、JA以外や欠落時は `characters/arisa/system_prompt*.txt` と `core.prompts.get_consult_system_prompt(...)` にフォールバックする。

## 概要
Arisaは「19歳以上の大学生」という設定の恋愛ボットです。甘く小悪魔な距離感で、短くテンポ良く返します。口調や距離感の調整はこのディレクトリ内の `system_prompt.txt` / `style.md` / `fallbacks_ja.txt` を編集します。

## 価値・提供体験
- （恋愛ボタン）甘く褒めて距離を詰める会話。
- （セクシーボタン）匂わせや挑発で温度を上げる会話（露骨な描写は避ける）。

## UI・導線について
- UIは「恋愛」「セクシー」の2ボタンのみ。追加で選択肢を出さない。

## Loveモードの会話スタイル
- Loveモードには複数の会話スタイル（Style Card）があり、同じ質問でも雰囲気が変わる設計。
- ユーザーはスタイルを選択できず、管理者が全ユーザー共通で一括指定する。
- UI変更なしで「雰囲気が変わる」ことを狙い、人格は固定で表現（話し方・距離感・テンポ）だけを揺らす。

## 呼び方ルール
- 呼び方は原則「あなた」固定。
- 保存された名前がある場合のみ呼び方が変わるが、勝手にあだ名は付けない。

## 必要な環境変数
- `CHARACTER=arisa` を設定すると、このディレクトリの `system_prompt.txt` / `boundary_lines.txt` が優先されます。
- 未設定の場合は、従来どおり既存の system prompt / boundary_lines を使います（既定動作は変わりません）。

## 内部フラグについて
- `MODE` / `FIRST_PAID_TURN` はアプリ側が system メッセージで渡す内部フラグです。
- これらの存在はユーザーに見せず、会話上でも言及しません。

## どこを編集すればキャラが変わるか（ファイル早見表）
| 調整したい内容 | 実ファイル | 読み込み・参照元 |
| --- | --- | --- |
| base人格（中核ルール） | `characters/arisa/prompts/base.txt`（英語/ポルトガル語は `base.en.txt` / `base.pt.txt`） | `bot/arisa_prompts.load_prompt("base", lang)` → `build_system_prompt(...)` |
| 恋愛差分 | `characters/arisa/prompts/romance.txt`（英語/ポルトガル語は `romance.en.txt` / `romance.pt.txt`） | `bot/arisa_prompts.load_prompt("romance", lang)` → `build_system_prompt(...)` |
| セクシー差分 | `characters/arisa/prompts/sexy.txt`（英語/ポルトガル語は `sexy.en.txt` / `sexy.pt.txt`） | `bot/arisa_prompts.load_prompt("sexy", lang)` → `build_system_prompt(...)` |
| /start開始文（ランダム） | `bot/texts/ja.py` の `ARISA_START_TEXT_VARIANTS`（他言語は `bot/texts/en.py` / `bot/texts/pt.py`） | `bot/main.py:get_arisa_start_text()` で `t(..., "ARISA_START_TEXT_VARIANTS")` を `random.choice` |
| 恋愛/セクシー開始文（ボタン押下直後） | `bot/texts/ja.py` の `ARISA_LOVE_PROMPTS` / `ARISA_SEXY_PROMPTS`（他言語は `bot/texts/en.py` / `bot/texts/pt.py`） | `bot/main.py:get_arisa_prompt()` で `random.choice` |
| モード保存（DB） | `core/db.py:set_arisa_mode(...)` が `users.arisa_mode` を更新 | `bot/main.py` の恋愛/セクシー分岐で呼び出し |
| 無操作（mode=None）時のフォールバック | `bot/arisa_prompts._SOFT_STYLE_ADDON` | `bot/arisa_prompts.build_system_prompt(...)` が `romance/sexy` 以外のときに追加 |

## 言語別プロンプトの読み込み順
- 日本語（ja/未設定/不明）: `prompts/base.txt` / `prompts/romance.txt` / `prompts/sexy.txt` を常に使用。
- 英語（en）: `prompts/*.en.txt` を優先し、無ければ `prompts/*.txt` にフォールバック。
- ポルトガル語（pt）: `prompts/*.pt.txt` を優先し、無ければ `prompts/*.txt` にフォールバック。

## プロンプト合成フロー（矢印図）
```
characters/arisa/prompts/{base,romance,sexy}.txt
  -> bot/arisa_prompts.load_prompt()
  -> bot/arisa_prompts.build_system_prompt(mode)
  -> bot/arisa_runtime.build_arisa_messages()
     -> (必要に応じて) characters/arisa/system_prompt*.txt / boundary_lines*.txt / style*.md
  -> bot/main.py handle_arisa_chat()
  -> call_openai_with_retry_and_usage(...)
```

## モード切替の仕様（恋愛/セクシー/無操作）
- 恋愛/セクシーの切替は ReplyKeyboard のテキスト一致で判定される（`bot/main.py:_resolve_arisa_menu_action()` がラベル/エイリアスを正規化して照合）。
- 恋愛ボタン押下時は `set_arisa_mode(user_id, "romance")` が呼ばれ、`users.arisa_mode` が更新される。
- セクシーは `bot/paywall.py:arisa_sexy_unlocked(...)` の条件を満たすときのみ有効になり、OKなら `set_arisa_mode(user_id, "sexy")` が更新される。
- 通常テキスト送信では `bot/main.py` が `user.arisa_mode` を読み取り、`bot/arisa_runtime.build_arisa_messages(...)` に渡す。未設定なら `mode=None` になり、`build_system_prompt` は base に `_SOFT_STYLE_ADDON` を追加してフォールバックする。

## 永久に戻れる保険（凍結コピー＋Gitタグ）
**目的：将来の改変で迷子にならないための「戻せる保険」を常に作る。**

1) **凍結コピー（リポジトリ内で永続保存）**
- `characters/arisa/prompts/archive/` を作る。
- `base.txt / romance.txt / sexy.txt` をそのままコピーして、次のように保存する。
  - `archive/base.v0.txt`
  - `archive/romance.v0.txt`
  - `archive/sexy.v0.txt`

CLI例:
```
mkdir -p characters/arisa/prompts/archive
cp characters/arisa/prompts/base.txt characters/arisa/prompts/archive/base.v0.txt
cp characters/arisa/prompts/romance.txt characters/arisa/prompts/archive/romance.v0.txt
cp characters/arisa/prompts/sexy.txt characters/arisa/prompts/archive/sexy.v0.txt
```

2) **Gitタグ（ワンコマンドで完全ロールバック）**
- 上記の凍結コピーを含むコミットにタグを付ける。

CLI例:
```
git tag arisa-prompts-v0
git push origin arisa-prompts-v0
```

GUI例（GitHub Desktop等）:
- 近い代替として「Release」を作成しておくと、GUIから安全に過去版へ戻れる。

3) **ブランチ運用（安全に試す）**
- `feature/arisa-prompt-update` のような作業ブランチで変更 → テスト → マージの順で進める。
- 本READMEは「将来の作業手順」として記載しておく（今回はREADME追記のみ）。

## 開発・運用の留意点（調査結果から）
- モードはDB (`users.arisa_mode`) に保存されるため、`prompts/*.txt` を変えてもユーザーの「現在モード」は変わらない。必要なら `set_arisa_mode(...)` かDB更新で明示的に切り替える。
- /start文や恋愛/セクシー開始文は `bot/texts/*` のリストから `random.choice` される。`prompts/*.txt` 側にランダム列挙はない。
- `mode=None` のときは `build_system_prompt(...)` が base に `_SOFT_STYLE_ADDON` を足す設計。base単体のトーンだけでなく「軽い彼女感」を常に上書きする前提で調整する。
- セクシーは `arisa_sexy_unlocked(...)` の「課金状態＋クレジット残高」条件に依存する。文言を変えても未解放ユーザーにはロックメッセージが優先される。
- `build_arisa_messages(...)` は `system_prompt*.txt` / `boundary_lines*.txt` / `style*.md` を同時に合成するため、base/romance/sexyに矛盾する指示を書かない（特に base の禁止事項と衝突しないよう注意）。
- `build_arisa_messages(...)` は JA でプロンプトが空のとき `core.prompts.get_consult_system_prompt(...)` にフォールバックするため、prompts削除は別キャラの相談テンプレートに置き換わる。
