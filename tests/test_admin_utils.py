from bot.paywall import arisa_chat_allowed
from core.admin import configure_admin_user_ids, is_admin_user, parse_admin_ids


def test_admin_parsing_and_arisa_bypass():
    admin_ids = parse_admin_ids("8385379400, 123")
    assert admin_ids == {8385379400, 123}

    configure_admin_user_ids(admin_ids)
    try:
        assert is_admin_user(8385379400)
        assert arisa_chat_allowed(8385379400, available_credits=0)
        assert not arisa_chat_allowed(999, available_credits=0)
    finally:
        configure_admin_user_ids(None)
