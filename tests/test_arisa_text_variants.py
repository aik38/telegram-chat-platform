from bot.texts.i18n import t


def _contains_choice_triad(text: str, tokens: tuple[str, ...]) -> bool:
    lowered = text.lower()
    return all(token.lower() in lowered for token in tokens)


def test_arisa_start_variants_avoid_choice_prompt():
    banned_triads = {
        "ja": ("安心", "刺激", "整理"),
        "en": ("comfort", "thrill", "clarity"),
        "pt": ("aconchego", "emoção", "clareza"),
    }
    banned_phrases = {
        "ja": ["「安心」「刺激」「整理」"],
        "en": ['"comfort", "thrill", or "clarity"'],
        "pt": ["“aconchego”, “emoção” ou “clareza”"],
    }
    for lang, phrases in banned_phrases.items():
        variants = t(lang, "ARISA_START_TEXT_VARIANTS")
        texts = [text for _, text in variants]
        for text in texts:
            assert not _contains_choice_triad(text, banned_triads[lang])
            for phrase in phrases:
                assert phrase.lower() not in text.lower()


def test_arisa_prompt_variants_avoid_choice_lists():
    banned_triads = {
        "ja": ("安心", "刺激", "整理"),
        "en": ("comfort", "thrill", "clarity"),
        "pt": ("aconchego", "emoção", "clareza"),
    }
    banned_phrases = {
        "ja": ["癒し？ドキドキ？それとも"],
        "en": ["comfort, a thrill, or a sense of ease"],
        "pt": ["carinho, um frio na barriga ou mais calma"],
    }
    for lang, phrases in banned_phrases.items():
        sexy_prompts = t(lang, "ARISA_SEXY_PROMPTS")
        for prompt in sexy_prompts:
            assert not _contains_choice_triad(prompt, banned_triads[lang])
            for phrase in phrases:
                assert phrase.lower() not in prompt.lower()
