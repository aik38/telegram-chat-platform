from __future__ import annotations

import os
from typing import Set

_ADMIN_USER_IDS: Set[int] | None = None


def parse_admin_ids(raw: str | None) -> Set[int]:
    values: set[int] = set()
    if not raw:
        return values
    for value in raw.split(","):
        candidate = value.strip()
        if not candidate:
            continue
        try:
            values.add(int(candidate))
        except ValueError:
            continue
    return values


def configure_admin_user_ids(admin_ids: Set[int] | None) -> None:
    global _ADMIN_USER_IDS
    _ADMIN_USER_IDS = set(admin_ids) if admin_ids is not None else None


def get_admin_user_ids(raw: str | None = None) -> Set[int]:
    if raw is not None:
        return parse_admin_ids(raw)
    if _ADMIN_USER_IDS is not None:
        return set(_ADMIN_USER_IDS)
    return parse_admin_ids(os.getenv("ADMIN_USER_IDS", ""))


def get_admin_user_ids_raw() -> str:
    return os.getenv("ADMIN_USER_IDS", "")


def is_admin_user(user_id: int | None, *, admin_ids: Set[int] | None = None) -> bool:
    if user_id is None:
        return False
    ids = admin_ids if admin_ids is not None else get_admin_user_ids()
    return user_id in ids


__all__ = [
    "configure_admin_user_ids",
    "get_admin_user_ids",
    "get_admin_user_ids_raw",
    "is_admin_user",
    "parse_admin_ids",
]
