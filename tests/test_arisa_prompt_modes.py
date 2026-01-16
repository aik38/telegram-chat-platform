from __future__ import annotations

from pathlib import Path
from typing import Iterable

from bot import arisa_prompts
from bot.texts import ja as ja_texts


def _flatten_texts(value: object) -> Iterable[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, tuple):
        flattened: list[str] = []
        for item in value:
            flattened.extend(_flatten_texts(item))
        return flattened
    return []


def test_arisa_texts_avoid_choice_keywords() -> None:
    banned = ("安心", "刺激", "整理")

    arisa_attrs = [
        getattr(ja_texts, name)
        for name in dir(ja_texts)
        if name.startswith("ARISA_")
    ]
    arisa_texts: list[str] = []
    for value in arisa_attrs:
        arisa_texts.extend(_flatten_texts(value))

    for text in arisa_texts:
        for token in banned:
            assert token not in text

    files_to_check = list(Path("characters/arisa/prompts").glob("*.txt"))
    files_to_check.extend(
        [
            Path("characters/arisa/system_prompt.txt"),
            Path("characters/arisa/style.md"),
        ]
    )
    for prompt_file in files_to_check:
        contents = prompt_file.read_text(encoding="utf-8")
        for token in banned:
            assert token not in contents


def test_arisa_mode_selection_changes_prompt() -> None:
    base = arisa_prompts.load_prompt("base")
    romance = arisa_prompts.load_prompt("romance")
    sexy = arisa_prompts.load_prompt("sexy")

    romance_prompt = arisa_prompts.build_system_prompt("romance")
    assert base in romance_prompt
    assert romance in romance_prompt
    assert sexy not in romance_prompt

    sexy_prompt = arisa_prompts.build_system_prompt("sexy")
    assert base in sexy_prompt
    assert sexy in sexy_prompt
    assert romance not in sexy_prompt


def test_arisa_default_prompt_uses_light_style() -> None:
    base = arisa_prompts.load_prompt("base")
    default_prompt = arisa_prompts.build_system_prompt(None)
    assert base in default_prompt
    assert "ライトな彼女感" in default_prompt
