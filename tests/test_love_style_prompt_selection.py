from __future__ import annotations

from bot import arisa_prompts


def test_romance_prompt_selects_only_love_a() -> None:
    prompt = arisa_prompts.build_system_prompt("romance", love_style="LOVE_A")
    block_a, _ = arisa_prompts.select_romance_prompt("LOVE_A")
    block_b, _ = arisa_prompts.select_romance_prompt("LOVE_B")
    block_c, _ = arisa_prompts.select_romance_prompt("LOVE_C")
    assert block_a in prompt
    assert block_b not in prompt
    assert block_c not in prompt


def test_romance_prompt_selects_only_love_b() -> None:
    prompt = arisa_prompts.build_system_prompt("romance", love_style="LOVE_B")
    block_a, _ = arisa_prompts.select_romance_prompt("LOVE_A")
    block_b, _ = arisa_prompts.select_romance_prompt("LOVE_B")
    block_c, _ = arisa_prompts.select_romance_prompt("LOVE_C")
    assert block_b in prompt
    assert block_a not in prompt
    assert block_c not in prompt


def test_romance_prompt_selects_only_love_c() -> None:
    prompt = arisa_prompts.build_system_prompt("romance", love_style="LOVE_C")
    block_a, _ = arisa_prompts.select_romance_prompt("LOVE_A")
    block_b, _ = arisa_prompts.select_romance_prompt("LOVE_B")
    block_c, _ = arisa_prompts.select_romance_prompt("LOVE_C")
    assert block_c in prompt
    assert block_a not in prompt
    assert block_b not in prompt
