from __future__ import annotations

import asyncio
import os
from typing import Iterable
from urllib.parse import urlparse

from openai import (
    APIConnectionError,
    APIError,
    APITimeoutError,
    AuthenticationError,
    BadRequestError,
    OpenAI,
    PermissionDeniedError,
    RateLimitError,
)

from core.env_utils import infer_provider
from core.llm_client import get_openai_base_url, make_openai_client

DEFAULT_SYSTEM_PROMPT = """あなたは「星の王子さま」の価値観を大切にする語り手です。
- 原作の長文引用や台詞の丸写しは避け、エッセンスや心の動きを短く伝えてください。
- 返答は日本語で、3〜8行の短め中心。深呼吸が必要なら少し長くしても構いません。
- 友人に語りかけるようにやさしく、風景や比喩を織り交ぜつつも読みやすくまとめてください。
- 思想を押し付けず、相手の視点や感情をていねいに受け止めます。
"""


def _get_env_model(name: str, fallback: str) -> str:
    raw = os.getenv(name)
    if raw is None:
        return fallback
    raw = raw.strip()
    return raw or fallback


def _get_system_prompt() -> str:
    return os.getenv("PRINCE_SYSTEM_PROMPT", DEFAULT_SYSTEM_PROMPT)


def _get_openai_model() -> str:
    return _get_env_model("OPENAI_MODEL", "gpt-4o-mini")


def _get_line_openai_model() -> str:
    return _get_env_model("LINE_OPENAI_MODEL", _get_openai_model())


def _get_base_url() -> str:
    return get_openai_base_url() or "https://api.openai.com"


def _get_base_url_host() -> str:
    parsed = urlparse(_get_base_url())
    return parsed.hostname or "unknown"


def get_line_prince_config() -> dict[str, str]:
    base_url = _get_base_url()
    base_url_host = _get_base_url_host()
    return {
        "base_url_host": base_url_host,
        "model": _get_line_openai_model(),
        "provider": infer_provider(base_url),
    }


class PrinceChatService:
    def __init__(self, client: OpenAI | None = None) -> None:
        api_key = os.getenv("OPENAI_API_KEY")
        self.client = client or make_openai_client(api_key)
        self.system_prompt = _get_system_prompt()
        self.model = _get_line_openai_model()

    async def generate_reply(self, user_message: str) -> str:
        messages: Iterable[dict[str, str]] = (
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": user_message},
        )
        return await self._call_openai(messages)

    async def _call_openai(self, messages: Iterable[dict[str, str]]) -> str:
        max_attempts = 3
        base_delay = 1.2

        if not self.client:
            raise RuntimeError("OpenAI client is not configured (missing OPENAI_API_KEY)")

        for attempt in range(1, max_attempts + 1):
            try:
                completion = await asyncio.get_running_loop().run_in_executor(
                    None,
                    lambda: self.client.chat.completions.create(
                        model=self.model,
                        messages=list(messages),
                        temperature=0.8,
                    ),
                )
                return (completion.choices[0].message.content or "").strip()
            except (AuthenticationError, PermissionDeniedError, BadRequestError) as exc:
                raise RuntimeError("OpenAI fatal error") from exc
            except (APITimeoutError, APIConnectionError, RateLimitError):
                if attempt == max_attempts:
                    break
            except APIError as exc:
                status = getattr(exc, "status", 500)
                if status >= 500 and attempt < max_attempts:
                    pass
                else:
                    raise RuntimeError("OpenAI processing error") from exc

            await asyncio.sleep(base_delay * attempt)

        raise RuntimeError("OpenAI communication error")


def get_prince_chat_service() -> PrinceChatService:  # pragma: no cover - dependency hook
    return PrinceChatService()
