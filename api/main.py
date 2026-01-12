import logging
import os

from fastapi import FastAPI

from api.db import apply_migrations

from api.routers import common_backend, line_webhook, stripe, tg_prince
from api.services.line_prince import get_line_prince_config
from core.env_utils import (
    infer_provider,
    load_environment,
    mask_secret,
    validate_model_base_url,
)
from core.llm_client import get_openai_base_url

logger = logging.getLogger(__name__)

app = FastAPI()


def _get_env_model(name: str, fallback: str) -> str:
    raw = os.getenv(name)
    if raw is None:
        return fallback
    raw = raw.strip()
    return raw or fallback


def _log_env_status() -> None:
    dotenv_path = load_environment()
    dotenv_file = os.getenv("DOTENV_FILE") or ".env"
    openai_model = _get_env_model("OPENAI_MODEL", "gpt-4o-mini")
    line_openai_model = _get_env_model("LINE_OPENAI_MODEL", openai_model)
    openai_base_url = get_openai_base_url() or "default"
    validate_model_base_url(get_openai_base_url(), openai_model, "OPENAI_MODEL")
    validate_model_base_url(
        get_openai_base_url(), line_openai_model, "LINE_OPENAI_MODEL"
    )
    provider = infer_provider(get_openai_base_url())
    line_prince_config = get_line_prince_config()
    logger.info(
        "Environment secrets (masked) -> OPENAI_API_KEY=%s LINE_CHANNEL_ACCESS_TOKEN=%s LINE_CHANNEL_SECRET=%s",
        mask_secret(os.getenv("OPENAI_API_KEY")),
        mask_secret(os.getenv("LINE_CHANNEL_ACCESS_TOKEN")),
        mask_secret(os.getenv("LINE_CHANNEL_SECRET")),
    )
    logger.info("Environment source -> DOTENV_FILE=%s dotenv_path=%s", dotenv_file, dotenv_path)
    # Example: OpenAI runtime config -> base_url=https://api.openai.com model=gpt-4o-mini line_model=gpt-4o-mini provider=openai
    logger.info(
        "OpenAI runtime config -> base_url=%s model=%s line_model=%s provider=%s",
        openai_base_url,
        openai_model,
        line_openai_model,
        provider,
    )
    logger.info(
        "LINE prince config -> base_url_host=%s model=%s provider=%s",
        line_prince_config["base_url_host"],
        line_prince_config["model"],
        line_prince_config["provider"],
    )


@app.get("/api/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health")
async def health_check_root() -> dict[str, bool]:
    return {"ok": True}


@app.on_event("startup")
def run_migrations() -> None:
    _log_env_status()
    apply_migrations()


app.include_router(line_webhook.router)
app.include_router(stripe.router)
app.include_router(tg_prince.router)
app.include_router(common_backend.router)
