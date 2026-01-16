import json
import os
from pathlib import Path

import pytest

from core import instance_lock


def _read_lock(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_acquire_lock_creates_file(tmp_path, monkeypatch):
    monkeypatch.setattr(instance_lock, "LOCK_DIR", tmp_path)
    handle = instance_lock.acquire_bot_lock(
        app="tarot",
        token="token-123",
        provider="openai",
        dotenv_file=".env",
    )
    try:
        assert handle.path.exists()
        data = _read_lock(handle.path)
        assert data["pid"] == os.getpid()
        assert data["app"] == "tarot"
    finally:
        handle.release()


def test_acquire_lock_exits_when_pid_alive(tmp_path, monkeypatch):
    monkeypatch.setattr(instance_lock, "LOCK_DIR", tmp_path)
    monkeypatch.setattr(instance_lock, "_is_pid_alive", lambda _pid: True)
    lock_name = f"telegram_tarot_{instance_lock._short_token_hash('token-123')}.lock"
    lock_path = tmp_path / lock_name
    lock_path.write_text(
        json.dumps(
            {
                "pid": 12345,
                "started_at": "2024-01-01T00:00:00+00:00",
                "app": "tarot",
                "provider": "openai",
                "dotenv_file": "/tmp/.env",
                "git_sha": "unknown",
                "bot_username": None,
                "bot_id": None,
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(SystemExit) as excinfo:
        instance_lock.acquire_bot_lock(
            app="tarot",
            token="token-123",
            provider="openai",
            dotenv_file=".env",
        )
    assert excinfo.value.code == 0


def test_acquire_lock_replaces_stale_lock(tmp_path, monkeypatch):
    monkeypatch.setattr(instance_lock, "LOCK_DIR", tmp_path)
    monkeypatch.setattr(instance_lock, "_is_pid_alive", lambda _pid: False)
    lock_name = f"telegram_tarot_{instance_lock._short_token_hash('token-123')}.lock"
    lock_path = tmp_path / lock_name
    lock_path.write_text(
        json.dumps(
            {
                "pid": 12345,
                "started_at": "2024-01-01T00:00:00+00:00",
                "app": "tarot",
                "provider": "openai",
                "dotenv_file": "/tmp/.env",
                "git_sha": "unknown",
                "bot_username": None,
                "bot_id": None,
            }
        ),
        encoding="utf-8",
    )
    handle = instance_lock.acquire_bot_lock(
        app="tarot",
        token="token-123",
        provider="openai",
        dotenv_file=".env",
    )
    try:
        data = _read_lock(handle.path)
        assert data["pid"] == os.getpid()
        assert data["app"] == "tarot"
    finally:
        handle.release()
