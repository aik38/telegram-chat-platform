import pytest

from core import prompts


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("🇺🇸 English", "ja"),
        ("Português", "ja"),
    ],
)
def test_prompt_language_normalization_defaults_to_ja_for_display_names(raw, expected):
    assert prompts._normalize_lang(raw) == expected
