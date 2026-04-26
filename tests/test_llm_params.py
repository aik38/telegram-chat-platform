from core.llm_params import build_chat_kwargs


def test_build_chat_kwargs_filters_gemini():
    kwargs = {
        "model": "gemini-pro",
        "messages": [{"role": "user", "content": "hi"}],
        "temperature": 0.4,
        "top_p": 0.9,
        "frequency_penalty": 0.2,
        "presence_penalty": 0.1,
        "logit_bias": {"1": -1},
    }

    filtered = build_chat_kwargs("gemini", kwargs)

    assert "frequency_penalty" not in filtered
    assert "presence_penalty" not in filtered
    assert "logit_bias" not in filtered
    assert filtered["model"] == "gemini-pro"
    assert filtered["top_p"] == 0.9


def test_build_chat_kwargs_keeps_openai():
    kwargs = {
        "model": "gpt-4o-mini",
        "messages": [{"role": "user", "content": "hi"}],
        "frequency_penalty": 0.2,
        "presence_penalty": 0.1,
    }

    filtered = build_chat_kwargs("openai", kwargs)

    assert filtered == kwargs


def test_build_chat_kwargs_filters_openrouter():
    kwargs = {
        "model": "openrouter/auto",
        "messages": [{"role": "user", "content": "hi"}],
        "temperature": 0.4,
        "top_p": 0.9,
        "frequency_penalty": 0.2,
        "presence_penalty": 0.1,
        "stream": True,
        "logit_bias": {"1": -1},
    }

    filtered = build_chat_kwargs("openrouter", kwargs)

    assert "logit_bias" not in filtered
    assert filtered["model"] == "openrouter/auto"
    assert filtered["stream"] is True
    assert filtered["top_p"] == 0.9
