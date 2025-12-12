# AGENTS - Telegram Tarot Bot

## 1. プロジェクト概要

- プロジェクト名: Telegram Bot（タロット占い） / Tarot（国内ベータ → 海外本番 / Telegram版）
- 目的:
  - 日本国内クローズドβ環境で、タロット占いTelegram Botの機能・負荷・UXを検証する。
  - 商用展開は海外のみを対象とし、最終的に外国語UI＋海外仕様に切り替える。
- 前提:
  - 「参照先サービス」と **ほぼ同一仕様** を目指す。
  - 国内βはクローズド（社内・限定ユーザ）、商用提供は行わない。
  - MAUが 10,000人 を超えるまでは **テキスト＋画像中心** のMVPとし、動画機能は将来バージョンで追加する。

## 2. 技術スタック（固定）

このプロジェクトでは、以下の技術スタックを前提とする。  
他言語・他フレームワークへの変更提案は不要。

- 言語: **Python 3.x**
- Botフレームワーク: **aiogram**
- APIサーバ: **FastAPI + Uvicorn**
- DB:
  - 国内ベータ: **SQLite**
  - 海外本番: **PostgreSQL**（最初からRDB前提でスキーマ設計）
- インフラ:
  - 国内ベータ: 日本国内VPS等
  - 海外本番: オランダなど海外VPS。Webhook先URLを切替える。

## 3. リポジトリ構成（想定）

Codexは原則としてこの構成を前提にコード生成・修正を行う。

```text
repo-root/
  bot/                   # aiogramベースのTelegram Bot層
    main.py              # Botエントリポイント
    handlers/            # 会話ハンドラ群
    keyboards/           # InlineKeyboard 等のUI
    middlewares/
    __init__.py

  api/                   # FastAPIアプリケーション層
    main.py              # APIエントリポイント (Uvicornから起動)
    routers/             # /api/v1/... などのルーター
    services/            # LLM呼び出し、Tarotサービス等
    __init__.py

  core/                  # 共通ドメインロジック・設定
    tarot/               # タロットカード定義・スプレッドロジック
      cards.py
      spreads.py
    config.py            # 環境変数・設定の読み込み
    models.py            # Pydanticモデルなど
    logging.py           # ログ設定
    __init__.py

  db/
    schema.sql           # 初期スキーマ（SQLite／PostgreSQL共通設計）
    models.py            # ORMモデル (SQLAlchemy想定)
    migrations/          # 余力があればマイグレーションスクリプト
    __init__.py

  scripts/
    dev_run_bot.sh       # Bot起動用（開発）
    dev_run_api.sh       # API起動用（開発）
    __init__.py

  tests/
    test_bot_basic.py
    test_api_reading.py

  docs/
    AGENTS.md            # このファイル
    SEQUENCE.md          # シーケンス図・フロー
    API_SPEC.md          # API仕様
    DB_SCHEMA.md         # DB仕様など

  .env.example
  requirements.txt or pyproject.toml
  README.md
