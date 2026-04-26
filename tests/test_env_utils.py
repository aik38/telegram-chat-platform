from core.env_utils import infer_provider


def test_infer_provider_openrouter():
    assert infer_provider("https://openrouter.ai/api/v1") == "openrouter"
