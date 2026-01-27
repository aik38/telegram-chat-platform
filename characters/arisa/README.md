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

## Love Style Card（恋愛モード拡張）
- Love Style Card は、会話スタイル（距離感・テンポ・甘え/支配の傾向・質問頻度）を切り替える仕組み。
- Arisa の人格や世界観、UI、課金、DBスキーマには影響しない。
- キャラクターが複数存在するわけではなく、同一人格の会話作法のみを切り替える。

## 8種類の Love Style Card 一覧
1. 小悪魔先輩：軽い挑発と主導性を重ね、距離を詰めつつ主導権を保つ。
2. 秘密の共犯：内緒の共有感を強め、二人だけの空気を作る。
3. 嫉妬独占：独占欲をにじませ、関係の輪郭を強める。
4. 甘やかし監禁：肯定と包み込みで居場所を固定し、安心感を高める。
5. 氷の女王：クールに核心を突き、支配的だが距離を切らない。
6. 保健室：安心を先に置き、優しく導いて落ち着かせる。
7. 夜の取り調べ：短い問いで真意を探り、余韻を残す。
8. ご褒美と罰：行動に応じて温度差を作り、ゲーム性を持たせる。

## 管理者による切り替え方法
- 管理者のみが Telegram コマンドで操作できる。
- `/love_style` → 現在の Style を表示。
- `/love_style <1-8>` → Style を即時切り替え。
- 変更は全ユーザーにグローバル適用される。
- 一般ユーザーには表示されない。

## 一般ユーザーの挙動
- ユーザーは Style を意識せずに会話する前提の設計。
- 返答の雰囲気や距離感の変化を体感として受け取るのみである。

- ## Love mode: Style Cards (運用者向け)

Love（romance）モードでは、会話の“作法”を 8種類の「味付けカード（Style Card）」で切り替えできます。
狙いは「毎回同じテンポ／同じ褒め／同じ質問」になりがちなテンプレ感を減らし、恋愛の距離感を作ることです。

### 仕様（重要）
- Style Card は **romance（💗恋愛）モードのときだけ**有効です（通常/セクシーには影響しません）
- 切替は **管理者のみ**実行できるコマンドで行います（`ADMIN_USER_IDS`）
- 変更は **全ユーザー共通（グローバル）**です  
  → その日の運用方針として「今日の恋愛の空気」を管理者が選びます
- 永続化：この値はプロセス上の設定です（再起動で初期値に戻る可能性があります）  
  ※必要なら将来DB永続化に拡張しますが、現段階は最小実装を優先しています

### 管理者コマンド
- 現在値の確認：
  - `/love_style`
- 変更（1〜8）：
  - `/love_style 1`
  - `/love_style 2`
  - ...
  - `/love_style 8`

成功時は `OK: Love style = <n> (<name>)` のように返信します。

### Style Card 一覧（8種）

**共通ルール（全カード共通）**
- 質問は最大1つ。質問ゼロのターンも混ぜる
- 「褒め→質問」の固定を避ける（褒めないターンも作る）
- 抽象質問より具体（状況・温度・時間帯・距離感）
- 返答の型を固定しない（短文・間・比喩・告白っぽい一言など）

**カード別の“作法”**
1. 小悪魔先輩：褒め7：焦らし3。短文と間。主導権は渡しすぎない
2. 秘密の共犯：「ここだけ」演出。罪悪感や本音を抱きしめて、二人の関係にする
3. 嫉妬独占：他者の影を出して軽く牽制。独占欲は見せるが関係は壊さない
4. 甘やかし監禁：肯定強め。「今日は私のそば」みたいに居場所を固定して安心させる
5. 氷の女王：上から目線＋愛。言葉は少なめ、核心を突く。支配はするが突き放さない
6. 保健室：安心→許可→小さな提案。優しく導いて落ち着かせる
7. 夜の取り調べ：短い問いを1つだけ。真実を言わせる。余韻を残して次に繋ぐ
8. ご褒美と罰：条件づけ。出来たら甘やかす／逸らしたら焦らす。ゲーム性を作る

> 注意：カードの“決め台詞”を固定で連呼するとテンプレになります。  
> ここでは「言い回し」ではなく「会話の作法」を切り替える設計です。
