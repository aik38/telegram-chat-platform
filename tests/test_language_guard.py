import asyncio
import importlib
import sys

from core.prompts import language_guard


def import_bot_main(monkeypatch, tmp_path):
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123456:TESTTOKEN")
    monkeypatch.setenv("OPENAI_API_KEY", "dummy")
    monkeypatch.setenv("SQLITE_DB_PATH", str(tmp_path / "test.db"))
    for module in ["core.config", "core.monetization", "core.db", "bot.main"]:
        if module in sys.modules:
            del sys.modules[module]
    return importlib.import_module("bot.main")


class DummyFromUser:
    def __init__(self, user_id: int, language_code: str | None = None):
        self.id = user_id
        self.language_code = language_code


class DummyMessage:
    def __init__(self, text: str, *, user_id: int, language_code: str | None = None):
        self.text = text
        self.from_user = DummyFromUser(user_id, language_code)
        self.answers: list[str] = []

    async def answer(self, text: str, **kwargs):
        self.answers.append(text)


class DummyCallback:
    def __init__(self, data: str, *, user_id: int, message: DummyMessage | None = None):
        self.data = data
        self.from_user = DummyFromUser(user_id)
        self.message = message
        self.answers: list[str] = []

    async def answer(self, text: str, **kwargs):
        self.answers.append(text)


def test_language_guard_in_messages(monkeypatch, tmp_path):
    bot_main = import_bot_main(monkeypatch, tmp_path)
    guard = language_guard("en")

    general_messages = bot_main.build_general_chat_messages("hello", lang="en")
    assert general_messages[1]["role"] == "system"
    assert general_messages[1]["content"] == guard

    tarot_messages = bot_main.build_tarot_messages(
        spread=bot_main.ONE_CARD,
        user_query="hello",
        drawn_cards=[
            {
                "card": {"name_en": "The Fool", "orientation": "upright"},
                "label_ja": "メインメッセージ",
            }
        ],
        lang="en",
    )
    system_messages = [message for message in tarot_messages if message["role"] == "system"]
    assert system_messages
    assert system_messages[-1]["content"] == guard

    arisa_messages = bot_main.build_arisa_messages("hello", lang="en", mode="sexy")
    assert arisa_messages[1]["role"] == "system"
    assert arisa_messages[1]["content"] == guard


def test_lang_button_persists_for_next_message(monkeypatch, tmp_path):
    bot_main = import_bot_main(monkeypatch, tmp_path)
    from core import db as core_db

    message = DummyMessage("/lang", user_id=123, language_code="ja")
    callback = DummyCallback("lang:set:en", user_id=123, message=message)
    asyncio.run(bot_main.handle_lang_set(callback))

    assert core_db.get_user_lang(123) == "en"

    next_message = DummyMessage("hello", user_id=123, language_code="ja")
    assert bot_main.resolve_lang_from_message(next_message) == "en"
