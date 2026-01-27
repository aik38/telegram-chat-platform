from __future__ import annotations

import re
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


def _parse_sectioned_prompt(text: str) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current_key: str | None = None
    for line in text.splitlines():
        match = re.match(r"^##\s+(\S+)", line.strip())
        if match:
            current_key = match.group(1).strip()
            sections.setdefault(current_key, [])
            continue
        if current_key is not None:
            sections[current_key].append(line)
    return {key: "\n".join(lines).strip() for key, lines in sections.items()}


def normalize_love_style(value: str | None) -> str | None:
    if not value:
        return None
    normalized = value.strip().upper()
    if normalized in {"A", "B", "C"}:
        return f"LOVE_{normalized}"
    if normalized in {"LOVE_A", "LOVE_B", "LOVE_C"}:
        return normalized
    return None


def select_romance_prompt(love_style: str | None, *, lang: str | None = None) -> tuple[str, str | None]:
    romance_prompt = load_prompt("romance", lang=lang)
    if not romance_prompt:
        return "", None
    sections = _parse_sectioned_prompt(romance_prompt)
    normalized = normalize_love_style(love_style)
    if normalized and normalized in sections:
        return sections[normalized], normalized
    if "LOVE_A" in sections:
        return sections["LOVE_A"], "LOVE_A"
    if sections:
        key = sorted(sections.keys())[0]
        return sections[key], key
    return romance_prompt, None


def build_system_prompt(mode: str | None, lang: str | None = None, *, love_style: str | None = None) -> str:
    lang_code = (lang or "").strip().lower()
    base = load_prompt("base", lang=lang_code)
    parts: list[str] = [base] if base else []
    normalized = (mode or "none").strip().lower()
    if normalized in {"romance", "sexy"}:
        if normalized == "romance":
            mode_prompt, _ = select_romance_prompt(love_style, lang=lang_code)
        else:
            mode_prompt = load_prompt(normalized, lang=lang_code)
        if mode_prompt:
            parts.append(mode_prompt)
    else:
        if _should_use_soft_addon(lang_code):
            parts.append(_SOFT_STYLE_ADDON)
    return "\n\n".join(part for part in parts if part)


__all__ = ["build_system_prompt", "load_prompt", "normalize_love_style", "select_romance_prompt"]
