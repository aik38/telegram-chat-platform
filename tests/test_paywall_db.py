from __future__ import annotations

import importlib
from datetime import datetime, timedelta, timezone

import pytest


@pytest.fixture
def db(monkeypatch, tmp_path):
    db_path = tmp_path / "test.db"
    monkeypatch.setenv("SQLITE_DB_PATH", str(db_path))
    import core.db as db_module

    db = importlib.reload(db_module)
    yield db


def test_grant_purchase_adds_tickets(db):
    base = datetime(2024, 1, 1, tzinfo=timezone.utc)
    user_id = 123
    db.ensure_user(user_id, now=base)

    db.grant_purchase(user_id, "TICKET_3", now=base)
    db.grant_purchase(user_id, "TICKET_7", now=base)
    db.grant_purchase(user_id, "TICKET_10", now=base)

    user = db.get_user(user_id)
    assert user is not None
    assert user.tickets_3 == 1
    assert user.tickets_7 == 1
    assert user.tickets_10 == 1


def test_grant_purchase_extends_premium_from_current_end(db):
    base = datetime(2024, 1, 1, tzinfo=timezone.utc)
    user_id = 456
    db.ensure_user(user_id, now=base)

    db.grant_purchase(user_id, "PASS_7D", now=base)
    first_until = db.get_user(user_id).premium_until
    assert first_until == base + timedelta(days=7)

    later = base + timedelta(days=3)
    db.grant_purchase(user_id, "PASS_7D", now=later)
    second_until = db.get_user(user_id).premium_until
    assert second_until == first_until + timedelta(days=7)

    even_later = base + timedelta(days=30)
    db.grant_purchase(user_id, "PASS_30D", now=even_later)
    third_until = db.get_user(user_id).premium_until
    assert third_until == even_later + timedelta(days=30)


def test_consume_ticket_reduces_balance(db):
    base = datetime(2024, 1, 1, tzinfo=timezone.utc)
    user_id = 789
    db.ensure_user(user_id, now=base)

    db.grant_purchase(user_id, "TICKET_3", now=base)
    assert db.consume_ticket(user_id, ticket="tickets_3")
    assert not db.consume_ticket(user_id, ticket="tickets_3")


def test_payment_events_and_latest_payment(db):
    base = datetime(2024, 1, 1, tzinfo=timezone.utc)
    user_id = 999
    db.ensure_user(user_id, now=base)

    event = db.log_payment_event(
        user_id=user_id,
        event_type="buy_click",
        sku="TICKET_3",
        payload="test",
        now=base,
    )
    assert event.event_type == "buy_click"
    assert event.sku == "TICKET_3"

    first_payment, _ = db.log_payment(
        user_id=user_id,
        sku="TICKET_3",
        stars=100,
        telegram_payment_charge_id="ch_1",
        provider_payment_charge_id=None,
        now=base + timedelta(minutes=1),
    )
    _, _ = db.log_payment(
        user_id=user_id,
        sku="PASS_7D",
        stars=200,
        telegram_payment_charge_id="ch_2",
        provider_payment_charge_id=None,
        now=base + timedelta(minutes=2),
    )

    latest = db.get_latest_payment(user_id)
    assert latest is not None
    assert latest.telegram_payment_charge_id == "ch_2"
    assert latest.created_at > first_payment.created_at


def test_check_db_health_detects_missing_file(db, tmp_path):
    db_path = tmp_path / "missing.db"
    db.DB_PATH = str(db_path)
    if db_path.exists():
        db_path.unlink()
    ok, messages = db.check_db_health()
    assert ok is False
    assert any("missing" in msg for msg in messages)
