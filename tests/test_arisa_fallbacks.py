from bot.arisa_runtime import get_arisa_fallback_message, sanitize_arisa_reply


def test_arisa_fallbacks_vary_by_message_id():
    user_id = 4242
    messages = [101, 102, 103, 104]
    results = {
        get_arisa_fallback_message(
            lang="ja",
            calling="あなた",
            user_id=user_id,
            message_id=message_id,
        )
        for message_id in messages
    }

    assert len(results) > 1


def test_arisa_sanitize_replaces_prompt_leak() -> None:
    leaked = "MODE: \"PAID\"\nARISA_MODE: \"sexy\"\n## 返信の型\n..."
    result = sanitize_arisa_reply(
        leaked,
        lang="ja",
        calling="あなた",
        user_id=111,
        message_id=222,
    )
    assert "MODE:" not in result
    assert "返信の型" not in result


def test_arisa_sanitize_replaces_non_ja_heavy_output_in_ja_mode() -> None:
    broken = "यह एक परीक्षण है। यह पूरा उत्तर हिन्दी में है।"
    result = sanitize_arisa_reply(
        broken,
        lang="ja",
        calling="あなた",
        user_id=111,
        message_id=333,
    )
    assert result != broken
