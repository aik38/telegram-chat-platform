from bot.arisa_runtime import get_arisa_fallback_message


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
