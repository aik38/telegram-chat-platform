from __future__ import annotations

from core.admin import is_admin_user


def arisa_chat_allowed(
    user_id: int | None,
    available_credits: int,
    *,
    admin_override: bool | None = None,
) -> bool:
    if user_id is None:
        return False
    is_admin = admin_override if admin_override is not None else is_admin_user(user_id)
    return is_admin or available_credits > 0


def arisa_should_consume_credits(
    user_id: int | None,
    *,
    admin_override: bool | None = None,
) -> bool:
    if user_id is None:
        return False
    is_admin = admin_override if admin_override is not None else is_admin_user(user_id)
    return not is_admin


def arisa_sexy_unlocked(
    *,
    paid_user: bool,
    available_credits: int,
    user_id: int | None,
    admin_override: bool | None = None,
) -> bool:
    if user_id is None:
        return False
    is_admin = admin_override if admin_override is not None else is_admin_user(user_id)
    if is_admin:
        return True
    return paid_user and available_credits > 0
