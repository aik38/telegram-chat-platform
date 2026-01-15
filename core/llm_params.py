from __future__ import annotations

from collections.abc import Mapping
from typing import Any

_OPENAI_CHAT_ALLOWLIST = {
    "model",
    "messages",
    "temperature",
    "top_p",
    "max_tokens",
    "presence_penalty",
    "frequency_penalty",
    "stop",
    "stream",
    "n",
}

_GEMINI_CHAT_ALLOWLIST = {
    "model",
    "messages",
    "temperature",
    "top_p",
    "max_tokens",
}


def build_chat_kwargs(provider: str | None, kwargs: Mapping[str, Any]) -> dict[str, Any]:
    """Return provider-safe kwargs for chat.completions.create."""
    if provider == "gemini":
        return {key: value for key, value in kwargs.items() if key in _GEMINI_CHAT_ALLOWLIST}
    if provider == "openai":
        return {key: value for key, value in kwargs.items() if key in _OPENAI_CHAT_ALLOWLIST}
    return dict(kwargs)
