from bot import arisa_runtime

def test_classify_need_by_keywords():
    assert arisa_runtime.classify_need("安心したい") == "calm"
    assert arisa_runtime.classify_need("あんしんしたい") == "calm"
    assert arisa_runtime.classify_need("刺激がほしい") == "tease"
    assert arisa_runtime.classify_need("しげきがほしい") == "tease"
    assert arisa_runtime.classify_need("整理したい") == "clarify"
    assert arisa_runtime.classify_need("せいりしたい") == "clarify"
    assert arisa_runtime.classify_need("安心と刺激、どっちも") == "calm"
    assert arisa_runtime.classify_need("今日は疲れた") is None


def test_resolve_need_type_defaults_to_unknown():
    assert arisa_runtime.resolve_arisa_need_type(None, "今日は疲れた") == "unknown"


def test_get_user_calling():
    assert arisa_runtime.get_user_calling(paid=True, known_name="Arisa") == "Arisaさん"
    assert arisa_runtime.get_user_calling(paid=True, known_name=None) == "あなた"
    assert arisa_runtime.get_user_calling(paid=False, known_name="Arisa") == "あなた"
    assert arisa_runtime.get_user_calling(paid=False, known_name=None) == "あなた"
