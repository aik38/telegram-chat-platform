import os
from typing import Optional

from openai import OpenAI


def _get_openai_base_url() -> Optional[str]:
    base_url = os.getenv("OPENAI_BASE_URL")
    if base_url is None:
        return None
    base_url = base_url.strip()
    return base_url or None


def get_openai_base_url() -> Optional[str]:
    return _get_openai_base_url()


def make_openai_client(api_key: str | None) -> OpenAI | None:
    if not api_key:
        return None
    base_url = _get_openai_base_url()
    if base_url:
        return OpenAI(api_key=api_key, base_url=base_url)
    return OpenAI(api_key=api_key)
