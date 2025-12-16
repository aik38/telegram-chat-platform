from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Sequence


class Arcana(str, Enum):
    """種別: 大アルカナ or 小アルカナ"""

    MAJOR = "major"
    MINOR = "minor"


class Suit(str, Enum):
    """小アルカナのスート。大アルカナの場合は None を使用する。"""

    WANDS = "wands"
    CUPS = "cups"
    SWORDS = "swords"
    PENTACLES = "pentacles"


@dataclass(frozen=True)
class TarotCard:
    """タロットカードのメタ情報。IDは ``<arcana>_<number>_<name>`` 形式。"""

    id: str
    name_ja: str
    name_en: str
    arcana: Arcana
    suit: Suit | None
    number: int | None
    keywords_upright_ja: Sequence[str]
    keywords_reversed_ja: Sequence[str]


MAJOR_ARCANA_DATA: tuple[tuple, ...] = (
    ("major_00_fool", "愚者", "The Fool", 0, ["自由", "好奇心", "冒険"], ["無計画", "衝動", "迷走"]),
    ("major_01_magician", "魔術師", "The Magician", 1, ["創造", "行動", "集中"], ["準備不足", "疑念", "停滞"]),
    ("major_02_high_priestess", "女教皇", "The High Priestess", 2, ["直感", "静寂", "知恵"], ["混乱", "秘密", "無関心"]),
    ("major_03_empress", "女帝", "The Empress", 3, ["豊かさ", "育む", "安心"], ["過保護", "停滞", "依存"]),
    ("major_04_emperor", "皇帝", "The Emperor", 4, ["安定", "統率", "責任"], ["硬直", "独裁", "支配"]),
    ("major_05_hierophant", "法王", "The Hierophant", 5, ["伝統", "学び", "指導"], ["形式的", "頑固", "視野の狭さ"]),
    ("major_06_lovers", "恋人たち", "The Lovers", 6, ["選択", "調和", "愛"], ["迷い", "依存", "不一致"]),
    ("major_07_chariot", "戦車", "The Chariot", 7, ["勝利", "前進", "意志"], ["暴走", "挫折", "衝突"]),
    ("major_08_strength", "力", "Strength", 8, ["勇気", "忍耐", "内なる強さ"], ["弱気", "不安", "焦り"]),
    ("major_09_hermit", "隠者", "The Hermit", 9, ["探求", "熟考", "内省"], ["孤立", "停滞", "閉塞"]),
    ("major_10_wheel_of_fortune", "運命の輪", "Wheel of Fortune", 10, ["転機", "チャンス", "循環"], ["停滞", "タイミングのズレ", "流れ待ち"]),
    ("major_11_justice", "正義", "Justice", 11, ["公平", "調整", "判断"], ["偏り", "決断回避", "不均衡"]),
    ("major_12_hanged_man", "吊された男", "The Hanged Man", 12, ["献身", "視点変更", "受容"], ["犠牲感", "停滞", "無力感"]),
    ("major_13_death", "死神", "Death", 13, ["終わり", "リセット", "変容"], ["抵抗", "停滞", "未練"]),
    ("major_14_temperance", "節制", "Temperance", 14, ["調和", "バランス", "節度"], ["極端", "不調和", "焦り"]),
    ("major_15_devil", "悪魔", "The Devil", 15, ["誘惑", "執着", "欲望"], ["解放", "依存からの脱却", "再出発"]),
    ("major_16_tower", "塔", "The Tower", 16, ["崩壊", "目覚め", "衝撃"], ["回避", "損害軽減", "軌道修正"]),
    ("major_17_star", "星", "The Star", 17, ["希望", "癒し", "インスピレーション"], ["失望", "不安", "現実的課題"]),
    ("major_18_moon", "月", "The Moon", 18, ["潜在意識", "揺らぎ", "感受性"], ["錯覚", "不安定", "疑念"]),
    ("major_19_sun", "太陽", "The Sun", 19, ["成功", "喜び", "明確"], ["空元気", "過信", "消耗"]),
    ("major_20_judgement", "審判", "Judgement", 20, ["復活", "評価", "目覚め"], ["迷い", "評価への不安", "停滞"]),
    ("major_21_world", "世界", "The World", 21, ["達成", "統合", "完成"], ["未完", "次の課題", "焦り"]),
)


MINOR_BASE_KEYWORDS: dict[Suit, tuple[Sequence[str], Sequence[str]]] = {
    Suit.WANDS: (["情熱", "創造", "行動"], ["焦り", "散漫", "消耗"]),
    Suit.CUPS: (["感情", "共感", "愛情"], ["依存", "過敏", "停滞"]),
    Suit.SWORDS: (["思考", "決断", "真実"], ["衝突", "不安", "混乱"]),
    Suit.PENTACLES: (["安定", "実務", "成長"], ["停滞", "怠慢", "過度な心配"]),
}


MINOR_NAME_TABLE: dict[Suit, dict[int, tuple[str, str]]] = {
    Suit.WANDS: {
        1: ("ワンドのエース", "Ace of Wands"),
        2: ("ワンドの2", "Two of Wands"),
        3: ("ワンドの3", "Three of Wands"),
        4: ("ワンドの4", "Four of Wands"),
        5: ("ワンドの5", "Five of Wands"),
        6: ("ワンドの6", "Six of Wands"),
        7: ("ワンドの7", "Seven of Wands"),
        8: ("ワンドの8", "Eight of Wands"),
        9: ("ワンドの9", "Nine of Wands"),
        10: ("ワンドの10", "Ten of Wands"),
        11: ("ワンドのペイジ", "Page of Wands"),
        12: ("ワンドのナイト", "Knight of Wands"),
        13: ("ワンドのクイーン", "Queen of Wands"),
        14: ("ワンドのキング", "King of Wands"),
    },
    Suit.CUPS: {
        1: ("カップのエース", "Ace of Cups"),
        2: ("カップの2", "Two of Cups"),
        3: ("カップの3", "Three of Cups"),
        4: ("カップの4", "Four of Cups"),
        5: ("カップの5", "Five of Cups"),
        6: ("カップの6", "Six of Cups"),
        7: ("カップの7", "Seven of Cups"),
        8: ("カップの8", "Eight of Cups"),
        9: ("カップの9", "Nine of Cups"),
        10: ("カップの10", "Ten of Cups"),
        11: ("カップのペイジ", "Page of Cups"),
        12: ("カップのナイト", "Knight of Cups"),
        13: ("カップのクイーン", "Queen of Cups"),
        14: ("カップのキング", "King of Cups"),
    },
    Suit.SWORDS: {
        1: ("ソードのエース", "Ace of Swords"),
        2: ("ソードの2", "Two of Swords"),
        3: ("ソードの3", "Three of Swords"),
        4: ("ソードの4", "Four of Swords"),
        5: ("ソードの5", "Five of Swords"),
        6: ("ソードの6", "Six of Swords"),
        7: ("ソードの7", "Seven of Swords"),
        8: ("ソードの8", "Eight of Swords"),
        9: ("ソードの9", "Nine of Swords"),
        10: ("ソードの10", "Ten of Swords"),
        11: ("ソードのペイジ", "Page of Swords"),
        12: ("ソードのナイト", "Knight of Swords"),
        13: ("ソードのクイーン", "Queen of Swords"),
        14: ("ソードのキング", "King of Swords"),
    },
    Suit.PENTACLES: {
        1: ("ペンタクルのエース", "Ace of Pentacles"),
        2: ("ペンタクルの2", "Two of Pentacles"),
        3: ("ペンタクルの3", "Three of Pentacles"),
        4: ("ペンタクルの4", "Four of Pentacles"),
        5: ("ペンタクルの5", "Five of Pentacles"),
        6: ("ペンタクルの6", "Six of Pentacles"),
        7: ("ペンタクルの7", "Seven of Pentacles"),
        8: ("ペンタクルの8", "Eight of Pentacles"),
        9: ("ペンタクルの9", "Nine of Pentacles"),
        10: ("ペンタクルの10", "Ten of Pentacles"),
        11: ("ペンタクルのペイジ", "Page of Pentacles"),
        12: ("ペンタクルのナイト", "Knight of Pentacles"),
        13: ("ペンタクルのクイーン", "Queen of Pentacles"),
        14: ("ペンタクルのキング", "King of Pentacles"),
    },
}


MINOR_VARIATION_KEYWORDS: dict[int, tuple[Sequence[str], Sequence[str]]] = {
    1: (["始まり", "可能性", "芽生え"], ["停滞", "見落とし", "足踏み"]),
    2: (["選択", "計画", "均衡"], ["優柔不断", "不安定", "足並みの乱れ"]),
    3: (["成長", "協力", "拡大"], ["遅延", "誤解", "不一致"]),
    4: (["安定", "祝福", "基盤"], ["停滞", "退屈", "閉塞"]),
    5: (["課題", "競争", "葛藤"], ["衝突", "損失", "孤立"]),
    6: (["調和", "成功", "助力"], ["承認待ち", "優越感", "依存"]),
    7: (["防衛", "挑戦", "粘り強さ"], ["不安", "孤立", "疲労"]),
    8: (["スピード", "変化", "展開"], ["混乱", "停滞", "遅れ"]),
    9: (["粘り", "備え", "慎重"], ["過剰防衛", "不信", "疲弊"]),
    10: (["負担", "達成前", "責任"], ["重圧", "行き詰まり", "放棄"]),
    11: (["好奇心", "メッセージ", "学び"], ["未熟", "不安定", "軽率"]),
    12: (["行動", "情熱", "進展"], ["衝動", "不安定", "焦り"]),
    13: (["受容", "直感", "安心"], ["過敏", "嫉妬", "揺らぎ"]),
    14: (["リーダー", "成熟", "責任"], ["固執", "支配", "過剰管理"]),
}


# 生成処理
major_cards: list[TarotCard] = [
    TarotCard(
        id=data[0],
        name_ja=data[1],
        name_en=data[2],
        arcana=Arcana.MAJOR,
        suit=None,
        number=data[3],
        keywords_upright_ja=data[4],
        keywords_reversed_ja=data[5],
    )
    for data in MAJOR_ARCANA_DATA
]

minor_cards: list[TarotCard] = []
for suit, names in MINOR_NAME_TABLE.items():
    suit_keywords = MINOR_BASE_KEYWORDS[suit]
    for number, name_pair in names.items():
        variation_keywords = MINOR_VARIATION_KEYWORDS[number]
        card_id = f"minor_{suit.value}_{number:02d}"
        if number == 1:
            card_id += "_ace"
        elif number >= 11:
            label = {11: "page", 12: "knight", 13: "queen", 14: "king"}[number]
            card_id += f"_{label}"
        card = TarotCard(
            id=card_id,
            name_ja=name_pair[0],
            name_en=name_pair[1],
            arcana=Arcana.MINOR,
            suit=suit,
            number=number,
            keywords_upright_ja=(*suit_keywords[0], *variation_keywords[0]),
            keywords_reversed_ja=(*suit_keywords[1], *variation_keywords[1]),
        )
        minor_cards.append(card)

ALL_CARDS: tuple[TarotCard, ...] = tuple(major_cards + minor_cards)
CARD_BY_ID: dict[str, TarotCard] = {card.id: card for card in ALL_CARDS}

__all__ = [
    "Arcana",
    "Suit",
    "TarotCard",
    "ALL_CARDS",
    "CARD_BY_ID",
]
