from bot.arisa_runtime import DEFAULT_ARISA_NEED_TYPE, get_arisa_fallback_message


def test_arisa_fallbacks_vary_by_message_id():
    user_id = 4242
    messages = [101, 102, 103, 104]
    results = {
        get_arisa_fallback_message(
            lang="ja",
            need_type=DEFAULT_ARISA_NEED_TYPE,
            calling="あなた",
            user_id=user_id,
            message_id=message_id,
        )
        for message_id in messages
    }

    assert len(results) > 1
