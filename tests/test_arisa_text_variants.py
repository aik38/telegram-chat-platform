from bot.texts.i18n import t


def test_arisa_start_variants_avoid_choice_prompt():
    banned_phrases = {
        "ja": ["いま欲しいのは", "そのまま返して", "「安心」「刺激」「整理」"],
        "en": ["what do you want most", 'comfort", "thrill", or "clarity'],
        "pt": ["o que você mais quer", "“aconchego”, “emoção” ou “clareza”"],
    }
    for lang, phrases in banned_phrases.items():
        variants = t(lang, "ARISA_START_TEXT_VARIANTS")
        texts = [text for _, text in variants]
        for text in texts:
            for phrase in phrases:
                assert phrase.lower() not in text.lower()


def test_arisa_prompt_variants_avoid_choice_lists():
    banned_phrases = {
        "ja": ["癒し？ドキドキ？それとも安心感？"],
        "en": ["comfort, a thrill, or a sense of ease"],
        "pt": ["carinho, um frio na barriga ou mais calma"],
    }
    for lang, phrases in banned_phrases.items():
        sexy_prompts = t(lang, "ARISA_SEXY_PROMPTS")
        for prompt in sexy_prompts:
            for phrase in phrases:
                assert phrase.lower() not in prompt.lower()
