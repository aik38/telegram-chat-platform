from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence
import random

from .cards import TarotCard, ALL_CARDS
from .spreads import Spread


@dataclass(frozen=True)
class DrawnCard:
    card: TarotCard
    is_reversed: bool
    position_id: str


def orientation_label(is_reversed: bool) -> str:
    return "逆位置" if is_reversed else "正位置"


def draw_cards(spread: Spread, *, rng: random.Random | None = None) -> list[DrawnCard]:
    """Spread のポジション数だけカードをランダムに引く。"""
    if rng is None:
        rng = random.Random()

    cards = rng.sample(list(ALL_CARDS), k=len(spread.positions))
    results: list[DrawnCard] = []
    for card, pos in zip(cards, spread.positions):
        is_reversed = bool(rng.getrandbits(1))
        results.append(DrawnCard(card=card, is_reversed=is_reversed, position_id=pos.id))
    return results


__all__ = ["DrawnCard", "draw_cards", "orientation_label"]
