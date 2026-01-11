import os
from pathlib import Path

from dotenv import load_dotenv

dotenv_path = Path(
    os.getenv("DOTENV_FILE", Path(__file__).resolve().parents[1] / ".env")
)
load_dotenv(dotenv_path, override=False)

import logging

from fastapi import FastAPI

from api.db import apply_migrations

from api.routers import common_backend, line_webhook, stripe, tg_prince
from api.services.line_prince import get_line_prince_config
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
    openai_model = _get_env_model("OPENAI_MODEL", "gpt-4o-mini")
    line_openai_model = _get_env_model("LINE_OPENAI_MODEL", openai_model)
    openai_base_url = get_openai_base_url() or "default"
    line_prince_config = get_line_prince_config()
    logger.info(
        "Environment flags -> OPENAI_API_KEY set: %s, LINE_CHANNEL_ACCESS_TOKEN set: %s, LINE_CHANNEL_SECRET set: %s",
        bool(os.getenv("OPENAI_API_KEY")),
        bool(os.getenv("LINE_CHANNEL_ACCESS_TOKEN")),
        bool(os.getenv("LINE_CHANNEL_SECRET")),
    )
    logger.info(
        "OpenAI config",
        extra={
            "mode": "startup",
            "openai_base_url": openai_base_url,
            "openai_model": openai_model,
            "line_openai_model": line_openai_model,
        },
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


@app.on_event("startup")
def run_migrations() -> None:
    _log_env_status()
    apply_migrations()


app.include_router(line_webhook.router)
app.include_router(stripe.router)
app.include_router(tg_prince.router)
app.include_router(common_backend.router)
