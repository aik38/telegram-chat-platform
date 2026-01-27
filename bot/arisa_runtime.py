from __future__ import annotations

import hashlib
import random
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from bot.arisa_prompts import build_system_prompt
from bot.texts.i18n import normalize_lang
from core.prompts import get_consult_system_prompt

ARISA_DEFAULT_TEMPERATURE = 0.72
ARISA_DEFAULT_TOP_P = 0.9
ARISA_DEFAULT_PRESENCE = 0.2
ARISA_DEFAULT_FREQUENCY = 0.15
CURRENT_LOVE_STYLE_CARD = 1

_ARISA_DIR = Path(__file__).resolve().parents[1] / "characters" / "arisa"


@lru_cache(maxsize=4)
def _read_arisa_file(filename: str) -> str | None:
    path = _ARISA_DIR / filename
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8")


def _arisa_tone_prompt(lang: str) -> str:
    if lang == "en":
        return "Keep replies short, affectionate, close in distance, and refined."
    if lang == "pt":
        return "Responda de forma curta, carinhosa, próxima e elegante."
    return "短く、甘えた距離感で、上品に返すこと。"


def get_user_calling(*, paid: bool, known_name: str | None) -> str:
    if paid and known_name:
        cleaned = known_name.strip()
        if cleaned:
            return f"{cleaned}さん"
    return "あなた"


def get_current_love_style_card() -> int:
    return CURRENT_LOVE_STYLE_CARD


def set_current_love_style_card(value: int) -> int:
    global CURRENT_LOVE_STYLE_CARD
    CURRENT_LOVE_STYLE_CARD = value
    return CURRENT_LOVE_STYLE_CARD


def sanitize_arisa_reply(text: str) -> str:
    if not text:
        return ""
    sanitized = re.sub(r"[`*_~]", "", text)
    sanitized = sanitized.replace("【", "").replace("】", "")
    sanitized = sanitized.replace("[", "").replace("]", "")
    sanitized = sanitized.strip()
    return sanitized or text.strip()


def arisa_generation_params(
    *,
    provider: str | None = None,
) -> tuple[float, dict[str, Any]]:
    temperature = ARISA_DEFAULT_TEMPERATURE
    overrides: dict[str, Any] = {}
    if provider in {"openai", "gemini"}:
        overrides["top_p"] = ARISA_DEFAULT_TOP_P
    if provider == "openai":
        overrides["presence_penalty"] = ARISA_DEFAULT_PRESENCE
        overrides["frequency_penalty"] = ARISA_DEFAULT_FREQUENCY
    return temperature, overrides


def _load_arisa_fallbacks_ja() -> tuple[str, ...]:
    contents = _read_arisa_file("fallbacks_ja.txt")
    if not contents:
        return ()
    lines = [line.strip() for line in contents.splitlines()]
    return tuple(line for line in lines if line and not line.startswith("#"))


def _arisa_fallback_variants(lang: str) -> tuple[str, ...]:
    if lang == "en":
        return (
            "…Sorry, my words tangled for a second. Are you okay right now?",
            "…Hold on. I want to be gentle with you. What’s the one thing you want me to say first?",
            "…I stumbled a bit. Tell me what you want most from me right now.",
        )
    if lang == "pt":
        return (
            "…Desculpa, minhas palavras se embolaram. Você tá bem agora?",
            "…Espera. Quero cuidar de você direitinho. O que você quer ouvir primeiro?",
            "…Eu tropecei um pouco. Me diz o que você quer mais de mim agora.",
        )
    fallbacks_ja = _load_arisa_fallbacks_ja()
    if fallbacks_ja:
        return fallbacks_ja
    return (
        "…ごめん、言葉がうまく出ない。あなた、いまいちばん欲しいのは何？",
        "…今はちゃんと寄り添いたい。あなた、今の気分を一言で教えて？",
        "…言い直すね。あなた、今いちばん気になってることって何？",
    )


def _select_fallback_variant(
    variants: tuple[str, ...],
    *,
    user_id: int | None,
    message_id: int | None,
    update_id: int | None,
) -> str:
    if not variants:
        return ""
    if user_id is None:
        return random.choice(variants)
    seed_parts = [str(user_id)]
    if message_id is not None:
        seed_parts.append(str(message_id))
    elif update_id is not None:
        seed_parts.append(str(update_id))
    if len(seed_parts) == 1:
        return random.choice(variants)
    seed = ":".join(seed_parts)
    hashed = int(hashlib.sha256(seed.encode("utf-8")).hexdigest(), 16)
    return variants[hashed % len(variants)]


def get_arisa_fallback_message(
    *,
    lang: str | None,
    calling: str,
    user_id: int | None,
    message_id: int | None,
    update_id: int | None = None,
) -> str:
    lang_code = normalize_lang(lang)
    variants = _arisa_fallback_variants(lang_code)
    message = _select_fallback_variant(
        variants,
        user_id=user_id,
        message_id=message_id,
        update_id=update_id,
    )
    if not message:
        return ""
    if calling and calling != "あなた":
        return message.replace("あなた", calling, 1)
    return message


def build_arisa_messages(
    user_query: str,
    *,
    lang: str | None = "ja",
    paid: bool = False,
    first_paid_turn: bool = False,
    mode: str | None = None,
    calling: str = "あなた",
) -> list[dict[str, str]]:
    """Arisaモードの system prompt を組み立てる。"""
    lang_code = normalize_lang(lang)
    if calling == "あなた":
        if lang_code == "en":
            calling = "you"
        elif lang_code == "pt":
            calling = "você"
    mode_prompt = build_system_prompt(mode, lang=lang_code)
    system_prompt = (
        mode_prompt
        or _read_arisa_file(f"system_prompt.{lang_code}.txt")
        or _read_arisa_file("system_prompt.txt")
    )
    if not system_prompt:
        system_prompt = get_consult_system_prompt(lang_code)
    boundary_lines = _read_arisa_file(f"boundary_lines.{lang_code}.txt") or _read_arisa_file(
        "boundary_lines.txt"
    )
    style = _read_arisa_file(f"style.{lang_code}.md") or _read_arisa_file("style.md")
    internal_flags = (
        f'MODE: "{ "PAID" if paid else "FREE" }"\n'
        f'FIRST_PAID_TURN: "{ "true" if first_paid_turn else "false" }"\n'
        f'LANG: "{lang_code}"\n'
        f'ARISA_MODE: "{mode or "none"}"\n'
        f'CALLING: "{calling}"'
    )
    if mode == "romance":
        internal_flags = f"{internal_flags}\nLOVE_STYLE_CARD={CURRENT_LOVE_STYLE_CARD}"
    parts = [system_prompt]
    if boundary_lines:
        parts.append(boundary_lines.strip())
    if style:
        parts.append(style.strip())
    parts.append(_arisa_tone_prompt(lang_code))
    parts.append(internal_flags)
    return [
        {"role": "system", "content": "\n\n".join(parts)},
        {"role": "user", "content": user_query},
    ]
