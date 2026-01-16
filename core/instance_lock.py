from __future__ import annotations

import atexit
import ctypes
import hashlib
import json
import logging
import os
import signal
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

LOCK_DIR = Path(__file__).resolve().parents[1] / ".locks"


@dataclass
class LockHandle:
    path: Path
    data: dict[str, Any]
    released: bool = False
    previous_handlers: dict[int, Any] = field(default_factory=dict)

    def update(self, **fields: Any) -> None:
        if self.released:
            return
        for key, value in fields.items():
            if value is not None:
                self.data[key] = value
        _write_lock_file(self.path, self.data)

    def release(self) -> None:
        if self.released:
            return
        self.released = True
        for signum, previous in self.previous_handlers.items():
            signal.signal(signum, previous)
        try:
            self.path.unlink()
        except FileNotFoundError:
            return


def acquire_bot_lock(
    app: str,
    token: str,
    provider: str,
    dotenv_file: str,
) -> LockHandle:
    if not token:
        raise RuntimeError("TELEGRAM_BOT_TOKEN is required to acquire a bot lock.")
    safe_app = _sanitize_app(app)
    lock_name = f"telegram_{safe_app}_{_short_token_hash(token)}.lock"
    lock_path = _ensure_lock_dir() / lock_name
    lock_data = _build_lock_data(
        app=safe_app,
        provider=provider,
        dotenv_file=dotenv_file,
    )

    for _attempt in range(2):
        try:
            _create_lock_file(lock_path, lock_data)
            handle = LockHandle(path=lock_path, data=lock_data)
            _register_release_handlers(handle)
            return handle
        except FileExistsError:
            existing = _read_lock_file(lock_path)
            existing_pid = _coerce_int(existing.get("pid")) if existing else None
            if existing_pid and _is_pid_alive(existing_pid):
                logger.info(
                    "Bot already running; exiting. app=%s pid=%s lock=%s",
                    safe_app,
                    existing_pid,
                    lock_path,
                )
                raise SystemExit(0)
            logger.warning(
                "Stale bot lock detected; recreating. app=%s lock=%s",
                safe_app,
                lock_path,
            )
            try:
                lock_path.unlink()
            except FileNotFoundError:
                pass

    raise RuntimeError(f"Failed to acquire bot lock: {lock_path}")


def _build_lock_data(app: str, provider: str, dotenv_file: str) -> dict[str, Any]:
    return {
        "pid": os.getpid(),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "app": app,
        "provider": provider,
        "dotenv_file": str(Path(dotenv_file).expanduser().resolve()),
        "git_sha": _get_git_sha(),
        "bot_username": None,
        "bot_id": None,
    }


def _create_lock_file(path: Path, data: dict[str, Any]) -> None:
    flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY
    fd = os.open(path, flags)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False)
        handle.flush()
        os.fsync(handle.fileno())


def _read_lock_file(path: Path) -> dict[str, Any]:
    try:
        contents = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return {}
    if not contents.strip():
        return {}
    try:
        data = json.loads(contents)
    except json.JSONDecodeError:
        return {}
    if isinstance(data, dict):
        return data
    return {}


def _write_lock_file(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def _ensure_lock_dir() -> Path:
    LOCK_DIR.mkdir(parents=True, exist_ok=True)
    return LOCK_DIR


def _sanitize_app(app: str) -> str:
    return "".join(ch if ch.isalnum() or ch in {"-", "_"} else "-" for ch in app.lower())


def _short_token_hash(token: str) -> str:
    digest = hashlib.sha1(token.encode("utf-8")).hexdigest()
    return digest[:10]


def _get_git_sha() -> str:
    repo_root = Path(__file__).resolve().parents[1]
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return "unknown"
    if result.returncode != 0:
        return "unknown"
    sha = result.stdout.strip()
    return sha or "unknown"


def _register_release_handlers(handle: LockHandle) -> None:
    atexit.register(handle.release)
    for signame in ("SIGINT", "SIGTERM"):
        if not hasattr(signal, signame):
            continue
        signum = getattr(signal, signame)
        previous = signal.getsignal(signum)
        handle.previous_handlers[signum] = previous

        def _handler(sig: int, _frame: object, prev: Any = previous) -> None:
            handle.release()
            if callable(prev):
                prev(sig, _frame)
                return
            raise SystemExit(0)

        signal.signal(signum, _handler)


def _is_pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if os.name == "nt":
        return _is_pid_alive_windows(pid)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def _is_pid_alive_windows(pid: int) -> bool:
    process_query = 0x1000
    handle = ctypes.windll.kernel32.OpenProcess(process_query, False, pid)
    if handle == 0:
        return False
    ctypes.windll.kernel32.CloseHandle(handle)
    return True


def _coerce_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
