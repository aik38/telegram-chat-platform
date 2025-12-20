import asyncio

from bot.middlewares.throttle import ThrottleMiddleware
from bot.texts.ja import THROTTLE_TEXT


class _DummyMessage:
    def __init__(self, user_id: int = 1) -> None:
        self.from_user = type("User", (), {"id": user_id})
        self.answers: list[str] = []
        self.handled = 0

    async def answer(self, text: str, show_alert: bool | None = None) -> None:  # noqa: ARG002
        self.answers.append(text)


def test_throttle_shows_notice_without_raising() -> None:
    async def _run() -> None:
        middleware = ThrottleMiddleware(min_interval_sec=2.0, apply_to_callbacks=True)

        async def handler(event, data):  # type: ignore[override]
            event.handled += 1
            return "ok"

        first_event = _DummyMessage()
        result = await middleware(handler, first_event, {})
        assert result == "ok"
        assert first_event.handled == 1
        assert first_event.answers == []

        second_event = _DummyMessage()
        await middleware(handler, second_event, {})
        assert second_event.handled == 0
        assert second_event.answers == [THROTTLE_TEXT]

    asyncio.run(_run())
