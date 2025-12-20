"""Simple internationalization helpers.

This module prepares language dictionaries and exposes helper functions for
normalizing language codes and fetching translated strings. Existing Japanese
texts remain the default and are not modified.
"""

from __future__ import annotations

from typing import Dict

from . import en, ja, pt


def normalize_lang(code: str | None) -> str:
    """Normalize language code to ``ja``, ``en``, or ``pt``.

    ``None`` or unknown codes fall back to ``ja``. Variants such as ``pt-br``
    and ``pt_BR`` are treated as Portuguese (``pt``).
    """

    if not code:
        return "ja"

    lowered = code.strip().lower().replace("_", "-")
    if lowered.startswith("pt"):
        return "pt"
    if lowered.startswith("en"):
        return "en"
    return "ja"


def _collect_ja_texts() -> Dict[str, str]:
    return {name: getattr(ja, name) for name in dir(ja) if name.isupper()}


LANG_MAP: Dict[str, Dict[str, str]] = {
    "ja": _collect_ja_texts(),
    "en": getattr(en, "TEXTS", {}),
    "pt": getattr(pt, "TEXTS", {}),
}


def t(lang: str | None, key: str, **kwargs) -> str:
    """Return translated text for ``key``.

    The lookup order is the requested language, then Japanese (``ja``). If the
    key does not exist in any dictionary, the key itself is returned.
    """

    lang_code = normalize_lang(lang)
    lang_dict = LANG_MAP.get(lang_code, {})

    text = lang_dict.get(key)
    if text is None:
        text = LANG_MAP.get("ja", {}).get(key)

    if text is None:
        return key

    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, IndexError, ValueError):
            return text
    return text

