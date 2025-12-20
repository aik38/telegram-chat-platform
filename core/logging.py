import logging
import os
from contextvars import ContextVar
from logging.handlers import RotatingFileHandler
from typing import Iterable

request_id_var: ContextVar[str] = ContextVar("request_id", default="-")
_SENSITIVE_ENV_VARS = ("TELEGRAM_BOT_TOKEN", "OPENAI_API_KEY")


def _gather_env_values(keys: Iterable[str]) -> list[str]:
    secrets: list[str] = []
    for key in keys:
        value = os.getenv(key, "")
        if value:
            secrets.append(value)
    return secrets


def collect_sensitive_values(additional: Iterable[str] | None = None) -> list[str]:
    """Return a list of sensitive strings that should be masked in logs."""
    secrets = _gather_env_values(_SENSITIVE_ENV_VARS)
    if additional:
        secrets.extend([value for value in additional if value])
    return secrets


def mask_secrets(message: str, secrets: Iterable[str]) -> str:
    """Replace sensitive substrings in the given message with asterisks."""
    masked = message
    for secret in secrets:
        masked = masked.replace(secret, "***")
    return masked


class SafeLogFilter(logging.Filter):
    def __init__(self, secrets: list[str]) -> None:
        super().__init__()
        self.secrets = [value for value in secrets if value]

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = request_id_var.get("-")
        record.msg = mask_secrets(record.getMessage(), self.secrets)
        record.args = ()
        return True


def setup_logging() -> None:
    """Configure console and rotating file logging for the bot."""
    log_level = logging.INFO
    log_format = "%(asctime)s [%(levelname)s] %(name)s [rid=%(request_id)s]: %(message)s"

    handlers = [logging.StreamHandler()]

    logs_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logs")
    os.makedirs(logs_dir, exist_ok=True)
    file_path = os.path.join(logs_dir, "bot.log")

    file_handler = RotatingFileHandler(
        file_path, maxBytes=1_000_000, backupCount=5, encoding="utf-8"
    )
    handlers.append(file_handler)

    filter_instance = SafeLogFilter(collect_sensitive_values())
    for handler in handlers:
        handler.addFilter(filter_instance)

    logging.basicConfig(level=log_level, format=log_format, handlers=handlers)


__all__ = ["collect_sensitive_values", "mask_secrets", "request_id_var", "setup_logging"]
