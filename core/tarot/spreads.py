from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence


@dataclass(frozen=True)
class SpreadPosition:
    id: str
    label_ja: str
    meaning_ja: str


@dataclass(frozen=True)
class Spread:
    id: str
    name_ja: str
    positions: Sequence[SpreadPosition]


ONE_CARD = Spread(
    id="one_card",
    name_ja="1枚引き",
    positions=[
        SpreadPosition(
            id="main",
            label_ja="メインメッセージ",
            meaning_ja="質問者へのメインメッセージを示します。",
        ),
    ],
)

THREE_CARD_SITUATION = Spread(
    id="three_card_situation",
    name_ja="3枚引き（状況・障害・未来）",
    positions=[
        SpreadPosition("situation", "現在の状況", "いまの状況・前提を表します。"),
        SpreadPosition("obstacle", "障害や課題", "乗り越えるべき障害や課題を表します。"),
        SpreadPosition("future", "未来の可能性", "流れの先にある可能性を表します。"),
    ],
)

ALL_SPREADS: dict[str, Spread] = {
    ONE_CARD.id: ONE_CARD,
    THREE_CARD_SITUATION.id: THREE_CARD_SITUATION,
}

__all__ = ["SpreadPosition", "Spread", "ONE_CARD", "THREE_CARD_SITUATION", "ALL_SPREADS"]
