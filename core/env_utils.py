from __future__ import annotations

import os
from pathlib import Path
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


def mask_secret(value: str | None, prefix: int = 2, suffix: int = 2) -> str:
    if not value:
        return "missing"
    trimmed = value.strip()
    if not trimmed:
        return "missing"
    if len(trimmed) <= prefix + suffix:
        return "*" * len(trimmed)
    return f"{trimmed[:prefix]}***{trimmed[-suffix:]}"


def infer_provider(base_url: str | None) -> str:
    if not base_url:
        return "openai"
    base_url_lower = base_url.lower()
    if _GEMINI_HOST in base_url_lower:
        return "gemini"
    if _OPENAI_HOST in base_url_lower:
        return "openai"
    return "custom"


def validate_model_base_url(base_url: str | None, model: str, label: str) -> None:
    if not base_url:
        return
    provider = infer_provider(base_url)
    model_lower = model.strip().lower()
    if provider == "gemini" and model_lower.startswith("gpt-"):
        raise RuntimeError(
            f"{label} mismatch: OPENAI_BASE_URL points to Gemini but model '{model}' looks like OpenAI."
        )
    if provider == "openai" and model_lower.startswith("gemini-"):
        raise RuntimeError(
            f"{label} mismatch: OPENAI_BASE_URL points to OpenAI but model '{model}' looks like Gemini."
        )
