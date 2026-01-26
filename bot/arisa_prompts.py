from __future__ import annotations

from functools import lru_cache
from pathlib import Path

_PROMPTS_DIR = Path(__file__).resolve().parents[1] / "characters" / "arisa" / "prompts"

_SOFT_STYLE_ADDON = (
    "ライトな彼女感のトーンで、距離は近め。"
    "恋愛を押し付けず、ユーザーの温度感に合わせる。"
)


@lru_cache(maxsize=16)
def load_prompt(name: str, lang: str | None = None) -> str:
    lang_code = (lang or "").strip().lower()
    candidates: list[Path] = []
    if lang_code in {"en", "pt"}:
        candidates.append(_PROMPTS_DIR / f"{name}.{lang_code}.txt")
    candidates.append(_PROMPTS_DIR / f"{name}.txt")
    for path in candidates:
        if path.is_file():
            return path.read_text(encoding="utf-8").strip()
    return ""


def _should_use_soft_addon(lang_code: str) -> bool:
    if lang_code in {"en", "pt"}:
        return not (_PROMPTS_DIR / f"base.{lang_code}.txt").is_file()
    return True


def build_system_prompt(mode: str | None, lang: str | None = None) -> str:
    lang_code = (lang or "").strip().lower()
    base = load_prompt("base", lang=lang_code)
    parts: list[str] = [base] if base else []
    normalized = (mode or "none").strip().lower()
    if normalized in {"romance", "sexy"}:
        mode_prompt = load_prompt(normalized, lang=lang_code)
        if mode_prompt:
            parts.append(mode_prompt)
    else:
        if _should_use_soft_addon(lang_code):
            parts.append(_SOFT_STYLE_ADDON)
    return "\n\n".join(part for part in parts if part)


__all__ = ["build_system_prompt", "load_prompt"]
