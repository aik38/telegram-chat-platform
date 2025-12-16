import random

from core.tarot import (
    ALL_CARDS,
    CARD_BY_ID,
    ONE_CARD,
    THREE_CARD_SITUATION,
    HEXAGRAM,
    CELTIC_CROSS,
    draw_cards,
)


def test_card_count_and_uniqueness():
    assert len(ALL_CARDS) == 78
    assert len(set(card.id for card in ALL_CARDS)) == 78
    assert set(CARD_BY_ID.keys()) == set(card.id for card in ALL_CARDS)


def test_draw_counts_and_orientation_type():
    rng = random.Random(0)
    one_draw = draw_cards(ONE_CARD, rng=rng)
    assert len(one_draw) == 1
    assert isinstance(one_draw[0].is_reversed, bool)

    rng_two = random.Random(1)
    three_draw = draw_cards(THREE_CARD_SITUATION, rng=rng_two)
    assert len(three_draw) == 3
    assert all(isinstance(card.is_reversed, bool) for card in three_draw)


def test_extended_spread_lengths():
    assert len(HEXAGRAM.positions) == 7
    assert len(CELTIC_CROSS.positions) == 10
