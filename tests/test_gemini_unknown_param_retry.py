import asyncio
import importlib
import sys

import httpx
from openai import BadRequestError


def import_bot_main(monkeypatch):
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123456:TESTTOKEN")
    monkeypatch.setenv("OPENAI_API_KEY", "dummy")
    monkeypatch.setenv(
        "OPENAI_BASE_URL",
        "https://generativelanguage.googleapis.com/v1beta/openai/",
    )
    if "core.config" in sys.modules:
        del sys.modules["core.config"]
    if "core.monetization" in sys.modules:
        del sys.modules["core.monetization"]
    if "core.db" in sys.modules:
        del sys.modules["core.db"]
    if "bot.main" in sys.modules:
        del sys.modules["bot.main"]
    return importlib.import_module("bot.main")


def test_gemini_unknown_param_retry(monkeypatch):
    bot_main = import_bot_main(monkeypatch)
    calls: list[dict[str, object]] = []

    class DummyCompletion:
        def __init__(self):
            class DummyUsage:
                total_tokens = 42

            class DummyMessage:
                content = "ok"

            class DummyChoice:
                message = DummyMessage()

            self.choices = [DummyChoice()]
            self.usage = DummyUsage()

    def create(**kwargs):
        calls.append(kwargs)
        if len(calls) == 1:
            response = httpx.Response(
                400,
                request=httpx.Request("POST", "https://generativelanguage.googleapis.com"),
            )
            raise BadRequestError(
                'Invalid JSON payload received. Unknown name "frequency_penalty"',
                response=response,
                body=None,
            )
        return DummyCompletion()

    class DummyCompletions:
        def create(self, **kwargs):
            return create(**kwargs)

    class DummyChat:
        completions = DummyCompletions()

    class DummyClient:
        chat = DummyChat()

    bot_main.client = DummyClient()

    answer, fatal, tokens = asyncio.run(
        bot_main.call_openai_with_retry_and_usage(
            [{"role": "user", "content": "hi"}],
            request_overrides={"frequency_penalty": 0.2},
        )
    )

    assert answer == "ok"
    assert fatal is False
    assert tokens == 42
    assert len(calls) == 2
    assert all("frequency_penalty" not in call for call in calls)
