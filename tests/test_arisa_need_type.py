import importlib
import sys

import pytest


def import_bot_main(monkeypatch):
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123456:TESTTOKEN")
    monkeypatch.setenv("OPENAI_API_KEY", "dummy")
    if "core.config" in sys.modules:
        del sys.modules["core.config"]
    if "core.monetization" in sys.modules:
        del sys.modules["core.monetization"]
    if "core.db" in sys.modules:
        del sys.modules["core.db"]
    if "bot.main" in sys.modules:
        del sys.modules["bot.main"]
    return importlib.import_module("bot.main")


def test_classify_need_by_keywords(monkeypatch):
    bot_main = import_bot_main(monkeypatch)

    assert bot_main.classify_need("安心したい") == "calm"
    assert bot_main.classify_need("刺激がほしい") == "tease"
    assert bot_main.classify_need("整理したい") == "clarify"
    assert bot_main.classify_need("安心と刺激、どっちも") == "calm"
    assert bot_main.classify_need("今日は疲れた") is None


def test_get_user_calling(monkeypatch):
    bot_main = import_bot_main(monkeypatch)

    assert bot_main.get_user_calling(paid=True, name="Arisa") == "Arisaさん"
    assert bot_main.get_user_calling(paid=True, name=None) == "あなた"
    assert bot_main.get_user_calling(paid=False, name="Arisa") == "あなた"
    assert bot_main.get_user_calling(paid=False, name=None) == "あなた"
