from __future__ import annotations

from functools import lru_cache
from pathlib import Path

_PROMPTS_DIR = Path(__file__).resolve().parents[1] / "characters" / "arisa" / "prompts"

_SOFT_STYLE_ADDON = (
    "ライトな彼女感のトーンで、距離は近め。"
    "恋愛を押し付けず、ユーザーの温度感に合わせる。"
)


@lru_cache(maxsize=8)
def load_prompt(name: str) -> str:
    path = _PROMPTS_DIR / f"{name}.txt"
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8").strip()


def build_system_prompt(mode: str | None) -> str:
    base = load_prompt("base")
    parts: list[str] = [base] if base else []
    normalized = (mode or "none").strip().lower()
    if normalized in {"romance", "sexy"}:
        mode_prompt = load_prompt(normalized)
        if mode_prompt:
            parts.append(mode_prompt)
    else:
        parts.append(_SOFT_STYLE_ADDON)
    return "\n\n".join(part for part in parts if part)


__all__ = ["build_system_prompt", "load_prompt"]
