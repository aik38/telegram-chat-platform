from __future__ import annotations

import os
from typing import Set

from dotenv import load_dotenv

load_dotenv()


def _get_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _parse_premium_ids(value: str | None) -> Set[int]:
    if not value:
        return set()

    ids: set[int] = set()
    for raw in value.split(","):
        candidate = raw.strip()
        if not candidate:
            continue
        try:
            ids.add(int(candidate))
        except ValueError:
            continue
    return ids


PAYWALL_ENABLED: bool = _get_bool("PAYWALL_ENABLED", default=False)
PREMIUM_USER_IDS: set[int] = _parse_premium_ids(os.getenv("PREMIUM_USER_IDS"))


def is_premium_user(user_id: int | None) -> bool:
    if user_id is None:
        return False
    return user_id in PREMIUM_USER_IDS


__all__ = ["PAYWALL_ENABLED", "PREMIUM_USER_IDS", "is_premium_user"]
