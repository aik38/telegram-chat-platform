from __future__ import annotations

import difflib
import hashlib
import random
import unicodedata
from functools import lru_cache
from pathlib import Path
from typing import Any

from bot.texts.i18n import normalize_lang
from core.prompts import get_consult_system_prompt

DEFAULT_ARISA_NEED_TYPE = "unknown"

ARISA_NEED_TYPE_TEMPERATURE = {
    "calm": 0.68,
    "clarify": 0.55,
    "tease": 0.95,
    "unknown": 0.68,
}

ARISA_NEED_TYPE_TOP_P = {
    "calm": 0.9,
    "clarify": 0.85,
    "tease": 0.95,
    "unknown": 0.9,
}

ARISA_NEED_TYPE_PRESENCE = {
    "calm": 0.2,
    "clarify": 0.1,
    "tease": 0.35,
    "unknown": 0.2,
}

ARISA_NEED_TYPE_FREQUENCY = {
    "calm": 0.15,
    "clarify": 0.1,
    "tease": 0.25,
    "unknown": 0.15,
}

_NEED_KEYWORDS: dict[str, tuple[str, ...]] = {
    "calm": ("安心", "あんしん", "安心感", "安らぎ"),
    "tease": ("刺激", "しげき", "スリル"),
    "clarify": ("整理", "せいり", "整頓"),
}

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


def _normalize_need_text(text: str) -> str:
    return unicodedata.normalize("NFKC", text).lower()


def _find_keyword_index(text: str, keyword: str) -> int | None:
    index = text.find(keyword)
    if index >= 0:
        return index
    keyword_len = len(keyword)
    if keyword_len == 0 or not text:
        return None
    lengths = {keyword_len}
    if keyword_len > 1:
        lengths.add(keyword_len - 1)
    lengths.add(keyword_len + 1)
    for size in sorted(lengths):
        if size <= 0 or size > len(text):
            continue
        for start in range(0, len(text) - size + 1):
            segment = text[start : start + size]
            ratio = difflib.SequenceMatcher(None, segment, keyword).ratio()
            if ratio >= 0.8:
                return start
    return None


def classify_need(text: str) -> str | None:
    if not text:
        return None
    normalized = _normalize_need_text(text)
    hits: list[tuple[int, str]] = []
    for need_type, keywords in _NEED_KEYWORDS.items():
        best_index: int | None = None
        for keyword in keywords:
            normalized_keyword = _normalize_need_text(keyword)
            index = _find_keyword_index(normalized, normalized_keyword)
            if index is not None and (best_index is None or index < best_index):
                best_index = index
        if best_index is not None:
            hits.append((best_index, need_type))
    if not hits:
        return None
    hits.sort(key=lambda item: item[0])
    return hits[0][1]


def resolve_arisa_need_type(base_need_type: str | None, user_text: str) -> str:
    override = classify_need(user_text)
    if override:
        return override
    if base_need_type in ARISA_NEED_TYPE_TEMPERATURE:
        return base_need_type
    return DEFAULT_ARISA_NEED_TYPE


def get_user_calling(*, paid: bool, known_name: str | None) -> str:
    if paid and known_name:
        cleaned = known_name.strip()
        if cleaned:
            return f"{cleaned}さん"
    return "あなた"


def arisa_temperature_for_need(need_type: str) -> float:
    return ARISA_NEED_TYPE_TEMPERATURE.get(
        need_type, ARISA_NEED_TYPE_TEMPERATURE[DEFAULT_ARISA_NEED_TYPE]
    )


def arisa_generation_params(
    need_type: str,
    *,
    provider: str | None = None,
) -> tuple[float, dict[str, Any]]:
    temperature = arisa_temperature_for_need(need_type)
    overrides: dict[str, Any] = {}
    if provider in {"openai", "gemini"}:
        overrides["top_p"] = ARISA_NEED_TYPE_TOP_P.get(need_type, 0.9)
        overrides["presence_penalty"] = ARISA_NEED_TYPE_PRESENCE.get(need_type, 0.2)
        overrides["frequency_penalty"] = ARISA_NEED_TYPE_FREQUENCY.get(need_type, 0.15)
    return temperature, overrides


def _load_arisa_fallbacks_ja() -> tuple[str, ...]:
    contents = _read_arisa_file("fallbacks_ja.txt")
    if not contents:
        return ()
    lines = [line.strip() for line in contents.splitlines()]
    return tuple(line for line in lines if line and not line.startswith("#"))


def _arisa_fallback_variants(lang: str) -> dict[str, tuple[str, ...]]:
    if lang == "en":
        return {
            "calm": (
                "…Sorry, my words tangled for a second. Are you okay right now?",
                "…Hold on. I want to be gentle with you. What’s the one thing you want me to say first?",
                "…I stumbled a bit. Tell me what you want most from me right now.",
            ),
            "clarify": (
                "…Let me reset. What’s the one point you want me to untangle first?",
                "…I got caught in my thoughts. What detail matters most to you right now?",
                "…Give me one line—what feels most confusing at the moment?",
            ),
            "tease": (
                "…Hehe, I got a little carried away. What mood should I lean into?",
                "…Oops, I teased too much. Tell me your vibe in one word.",
                "…I went quiet on purpose. Now, what do you want me to do with you—just for now?",
            ),
            "unknown": (
                "…Sorry, my words got twisted. What do you want to feel right now?",
                "…I want to stay close to you. What’s the one thing you want from me?",
                "…Let me try again. What’s on your mind most right now?",
            ),
        }
    if lang == "pt":
        return {
            "calm": (
                "…Desculpa, minhas palavras se embolaram. Você tá bem agora?",
                "…Espera. Quero cuidar de você direitinho. O que você quer ouvir primeiro?",
                "…Eu tropecei um pouco. Me diz o que você quer mais de mim agora.",
            ),
            "clarify": (
                "…Deixa eu reiniciar. Qual ponto você quer organizar primeiro?",
                "…Me perdi um pouco. Qual detalhe importa mais agora?",
                "…Me dá uma linha: o que tá mais confuso neste momento?",
            ),
            "tease": (
                "…Hehe, me empolguei. Em que clima você quer que eu entre?",
                "…Ops, provoquei demais. Diz tua vibe em uma palavra.",
                "…Fiquei quieta de propósito. Agora me diz: o que você quer de mim, só por agora?",
            ),
            "unknown": (
                "…Desculpa, minhas palavras travaram. O que você quer sentir agora?",
                "…Quero ficar bem pertinho. O que você quer de mim agora?",
                "…Vamos de novo. O que tá mais forte na sua cabeça agora?",
            ),
        }
    fallbacks_ja = _load_arisa_fallbacks_ja()
    if fallbacks_ja:
        return {
            "calm": fallbacks_ja,
            "clarify": fallbacks_ja,
            "tease": fallbacks_ja,
            "unknown": fallbacks_ja,
        }
    return {
        "calm": (
            "…ごめん、言葉が絡まった。あなた、今いちばん欲しいのは何？",
            "…うまく言えなかった。あなた、今いちばん欲しい言葉を教えて？",
            "…いまは落ち着いて受け止めたい。あなたがいちばん欲しい言葉、教えて？",
        ),
        "clarify": (
            "…ごめん、頭の中が渋滞した。いま一番ひっかかってる点はどこ？",
            "…いったん深呼吸。いま一番ひっかかってる点、ひと言で教えて？",
            "…私が整えるね。いちばん気になる部分はどこ？",
        ),
        "tease": (
            "…ふふ、ちょっと焦らしすぎた。あなた、いまの気分を一言で教えて？",
            "…ごめんね、空気に酔った。あなたは今、どんな温度がほしい？",
            "…黙ったの、わざと。あなた、今どんなムード？",
        ),
        "unknown": (
            "…ごめん、言葉がうまく出ない。あなた、いまいちばん欲しいのは何？",
            "…今はちゃんと寄り添いたい。あなた、今の気分を一言で教えて？",
            "…言い直すね。あなた、今いちばん気になってることって何？",
        ),
    }


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
    need_type: str,
    calling: str,
    user_id: int | None,
    message_id: int | None,
    update_id: int | None = None,
) -> str:
    lang_code = normalize_lang(lang)
    variants_by_need = _arisa_fallback_variants(lang_code)
    variants = variants_by_need.get(need_type) or variants_by_need.get("unknown", ())
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
    need_type: str = DEFAULT_ARISA_NEED_TYPE,
    calling: str = "あなた",
) -> list[dict[str, str]]:
    """Arisaモードの system prompt を組み立てる。"""
    lang_code = normalize_lang(lang)
    system_prompt = _read_arisa_file("system_prompt.txt") or get_consult_system_prompt(lang_code)
    boundary_lines = _read_arisa_file("boundary_lines.txt")
    style = _read_arisa_file("style.md")
    internal_flags = (
        f'MODE: "{ "PAID" if paid else "FREE" }"\n'
        f'FIRST_PAID_TURN: "{ "true" if first_paid_turn else "false" }"\n'
        f'LANG: "{lang_code}"\n'
        f'NEED_TYPE: "{need_type}"\n'
        f'CALLING: "{calling}"'
    )
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
