import importlib

import pytest


i18n = importlib.import_module("bot.texts.i18n")


@pytest.mark.parametrize(
    "code,expected",
    [
        (None, "ja"),
        ("", "ja"),
        ("JA", "ja"),
        ("en", "en"),
        ("en-US", "en"),
        ("pt", "pt"),
        ("pt-br", "pt"),
        ("pt_BR", "pt"),
        ("unknown", "ja"),
    ],
)
def test_normalize_lang(code, expected):
    assert i18n.normalize_lang(code) == expected


def test_t_falls_back_to_ja():
    result = i18n.t("en", "MAX_QUESTION_CHARS")
    assert result == i18n.LANG_MAP["ja"]["MAX_QUESTION_CHARS"]


def test_t_returns_key_when_missing_everywhere():
    assert i18n.t("en", "MISSING_KEY") == "MISSING_KEY"


def test_t_formats_when_kwargs_present():
    # Use a simple text that has a format placeholder
    i18n.LANG_MAP["en"]["GREETING"] = "Hello {name}"
    assert i18n.t("en", "GREETING", name="World") == "Hello World"

