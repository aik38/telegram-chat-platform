from __future__ import annotations

from collections.abc import Mapping
from typing import Any

_GEMINI_CHAT_ALLOWLIST = {
    "model",
    "messages",
    "temperature",
    "top_p",
    "max_tokens",
    "stop",
    "stream",
    "n",
}


def build_chat_kwargs(provider: str | None, kwargs: Mapping[str, Any]) -> dict[str, Any]:
    """Return provider-safe kwargs for chat.completions.create."""
    if provider == "gemini":
        return {key: value for key, value in kwargs.items() if key in _GEMINI_CHAT_ALLOWLIST}
    return dict(kwargs)
