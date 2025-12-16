import importlib
import sys


def import_bot_main(monkeypatch):
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123456:TESTTOKEN")
    monkeypatch.setenv("OPENAI_API_KEY", "dummy")
    if "bot.main" in sys.modules:
        del sys.modules["bot.main"]
    return importlib.import_module("bot.main")


def test_is_tarot_mode(monkeypatch):
    bot_main = import_bot_main(monkeypatch)
    assert bot_main.is_tarot_mode("今の恋愛について占って")
    assert bot_main.is_tarot_mode("/tarot 恋愛運")
    assert not bot_main.is_tarot_mode("今日は忙しかったです")


def test_choose_spread(monkeypatch):
    bot_main = import_bot_main(monkeypatch)
    assert bot_main.choose_spread("恋愛について占って") == bot_main.ONE_CARD
    assert bot_main.choose_spread("3枚で恋愛について占って") == bot_main.THREE_CARD_SITUATION
