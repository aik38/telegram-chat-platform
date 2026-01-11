import os
from dataclasses import dataclass
from pathlib import Path
from typing import Set

from core.env_utils import load_environment


def _parse_admin_ids(raw: str) -> Set[int]:
    values: set[int] = set()
    for value in (raw or "").split(","):
        candidate = value.strip()
        if not candidate:
            continue
        try:
            values.add(int(candidate))
        except ValueError:
            continue
    return values


def _parse_float_env(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


@dataclass(frozen=True)
class AppConfig:
    telegram_bot_token: str
    openai_api_key: str
    support_email: str
    admin_user_ids: Set[int]
    throttle_message_interval_sec: float
    throttle_callback_interval_sec: float
    one_message_tokens: int
    trial_free_credits: int
    pass_7d_daily_limit: int
    pass_30d_daily_limit: int
    dotenv_path: Path


def load_config() -> AppConfig:
    dotenv_path = load_environment()
    telegram_bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
    openai_api_key = os.getenv("OPENAI_API_KEY")
    support_email = os.getenv("SUPPORT_EMAIL", "hasegawaarisa1@gmail.com")
    admin_user_ids = _parse_admin_ids(os.getenv("ADMIN_USER_IDS", ""))
    throttle_message_interval_sec = _parse_float_env(
        "THROTTLE_MESSAGE_INTERVAL_SEC", 1.2
    )
    throttle_callback_interval_sec = _parse_float_env(
        "THROTTLE_CALLBACK_INTERVAL_SEC", 0.8
    )
    one_message_tokens = int(os.getenv("ONE_MESSAGE_TOKENS", "600"))
    trial_free_credits = int(os.getenv("TRIAL_FREE_CREDITS", "10"))
    pass_7d_daily_limit = int(os.getenv("PASS_7D_DAILY_LIMIT", "30"))
    pass_30d_daily_limit = int(os.getenv("PASS_30D_DAILY_LIMIT", "50"))

    if not telegram_bot_token:
        raise RuntimeError("TELEGRAM_BOT_TOKEN is not set in environment or .env")
    if not openai_api_key:
        raise RuntimeError("OPENAI_API_KEY is not set in environment or .env")

    return AppConfig(
        telegram_bot_token=telegram_bot_token,
        openai_api_key=openai_api_key,
        support_email=support_email,
        admin_user_ids=admin_user_ids,
        throttle_message_interval_sec=throttle_message_interval_sec,
        throttle_callback_interval_sec=throttle_callback_interval_sec,
        one_message_tokens=one_message_tokens,
        trial_free_credits=trial_free_credits,
        pass_7d_daily_limit=pass_7d_daily_limit,
        pass_30d_daily_limit=pass_30d_daily_limit,
        dotenv_path=dotenv_path,
    )
