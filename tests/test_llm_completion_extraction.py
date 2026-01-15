import importlib
import sys

from bot.texts.i18n import t


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


def test_completion_extraction_fallback(monkeypatch):
    bot_main = import_bot_main(monkeypatch)

    class DummyChoice:
        def __init__(self):
            self.message = None

    class DummyCompletion:
        def __init__(self):
            self.choices = [DummyChoice()]

    completion = DummyCompletion()
    result = bot_main.extract_completion_content_or_fallback(completion, lang="ja")

    assert result == t("ja", "OPENAI_CONTENT_FALLBACK")
