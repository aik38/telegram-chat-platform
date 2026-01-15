from datetime import datetime, timezone
import importlib
import sys


def import_bot_main(monkeypatch, tmp_path):
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123456:TESTTOKEN")
    monkeypatch.setenv("OPENAI_API_KEY", "dummy")
    monkeypatch.setenv("ADMIN_USER_IDS", "8385379400")
    monkeypatch.setenv("SQLITE_DB_PATH", str(tmp_path / "test.db"))
    if "core.config" in sys.modules:
        del sys.modules["core.config"]
    if "core.monetization" in sys.modules:
        del sys.modules["core.monetization"]
    if "core.db" in sys.modules:
        del sys.modules["core.db"]
    if "bot.main" in sys.modules:
        del sys.modules["bot.main"]
    return importlib.import_module("bot.main")


def test_admin_bypass_marks_paid(monkeypatch, tmp_path):
    bot_main = import_bot_main(monkeypatch, tmp_path)
    now = datetime(2024, 1, 1, tzinfo=timezone.utc)

    is_paid, pass_active, paid_subscription = bot_main.resolve_arisa_paid_state(
        8385379400, user=None, now=now
    )

    assert bot_main.is_admin_user(8385379400)
    assert is_paid is True
    assert pass_active is False
    assert paid_subscription is False
