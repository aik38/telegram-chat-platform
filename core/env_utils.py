from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv

_GEMINI_HOST = "generativelanguage.googleapis.com"
_OPENAI_HOST = "api.openai.com"


def resolve_dotenv_path() -> Path:
    dotenv_file = os.getenv("DOTENV_FILE")
    if dotenv_file:
        return Path(dotenv_file).expanduser()
    return Path(__file__).resolve().parents[1] / ".env"


def _validate_env_file(path: Path) -> None:
    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.lower().startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            raise RuntimeError(
                f"Invalid env line (missing '=') in {path} at line {line_number}: {raw_line}"
            )


def load_environment() -> Path:
    path = resolve_dotenv_path()
    if os.getenv("DOTENV_FILE") and not path.exists():
        raise RuntimeError(f"DOTENV_FILE is set but file not found: {path}")
    if path.exists():
        _validate_env_file(path)
        load_dotenv(path, override=False)
    return path


def infer_provider(base_url: str | None) -> str:
    if not base_url:
        return "openai"
    host = (urlparse(base_url).hostname or "").lower()
    if _GEMINI_HOST in host or "googleapis" in host:
        return "gemini"
    if _OPENAI_HOST in host:
        return "openai"
    return "custom"


def validate_model_base_url(base_url: str | None, model: str, label: str) -> None:
    if not base_url:
        return
    base_url_lower = base_url.lower()
    model_lower = model.strip().lower()
    if _GEMINI_HOST in base_url_lower and model_lower.startswith(("gpt-", "o1-")):
        raise RuntimeError(
            f"{label} mismatch: OPENAI_BASE_URL points to Gemini but model '{model}' looks like OpenAI."
        )
    if _OPENAI_HOST in base_url_lower and model_lower.startswith("gemini-"):
        raise RuntimeError(
            f"{label} mismatch: OPENAI_BASE_URL points to OpenAI but model '{model}' looks like Gemini."
        )
