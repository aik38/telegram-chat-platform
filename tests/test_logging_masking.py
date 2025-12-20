import logging
import os
from io import StringIO

from core.logging import SafeLogFilter, collect_sensitive_values


def test_safe_log_filter_masks_env_secrets(monkeypatch) -> None:
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "telegram-secret-token")
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test-secret")

    stream = StringIO()
    handler = logging.StreamHandler(stream)
    handler.addFilter(SafeLogFilter(collect_sensitive_values()))

    logger = logging.getLogger("masking-test")
    logger.setLevel(logging.INFO)
    logger.addHandler(handler)
    logger.propagate = False

    try:
        logger.info("Tokens: %s / %s", os.getenv("TELEGRAM_BOT_TOKEN"), os.getenv("OPENAI_API_KEY"))
    finally:
        logger.removeHandler(handler)

    output = stream.getvalue()
    assert "telegram-secret-token" not in output
    assert "sk-test-secret" not in output
    assert "***" in output
