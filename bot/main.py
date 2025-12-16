import asyncio
import json
import logging
import random
from typing import Iterable

from aiogram import Bot, Dispatcher
from aiogram.filters import CommandStart
from aiogram.types import Message
from openai import (
    APIConnectionError,
    APIError,
    APITimeoutError,
    AuthenticationError,
    BadRequestError,
    OpenAI,
    PermissionDeniedError,
    RateLimitError,
)

from core.config import OPENAI_API_KEY, TELEGRAM_BOT_TOKEN
from core.logging import setup_logging
from core.tarot import (
    ONE_CARD,
    THREE_CARD_SITUATION,
    draw_cards,
    orientation_label,
)
from core.tarot.spreads import Spread


bot = Bot(token=TELEGRAM_BOT_TOKEN)
dp = Dispatcher()
client = OpenAI(api_key=OPENAI_API_KEY)

logger = logging.getLogger(__name__)


def build_general_chat_messages(user_query: str) -> list[dict[str, str]]:
    """通常チャットモードの system prompt を組み立てる。"""
    system_prompt = (
        "あなたは日本語で会話する優しいチャットパートナーです。"
        "次の禁止事項を必ず守ってください:\n"
        "- 通常チャットモードでは、タロットカードを引いたふりをしてはいけません。\n"
        "- 『カード』『タロット』『スプレッド』『大アルカナ』『小アルカナ』などの占い用語を使わないでください。\n"
        "- 占いのような断定的未来予測は避け、相談者の気持ちを受け止めるカウンセリング寄りの返答にしてください。\n"
        "- 返信は300〜600文字程度を目安に、落ち着いて丁寧なトーンを保ってください。\n"
        "- 重たい相談にも寄り添い、相手を責めずに安心できる表現を選んでください。"
    )
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_query},
    ]


async def call_openai_with_retry(messages: Iterable[dict[str, str]]) -> tuple[str, bool]:
    prepared_messages = list(messages)
    max_attempts = 3
    base_delay = 1.5

    for attempt in range(1, max_attempts + 1):
        try:
            completion = await asyncio.get_running_loop().run_in_executor(
                None,
                lambda: client.chat.completions.create(
                    model="gpt-4o-mini", messages=prepared_messages
                ),
            )
            answer = completion.choices[0].message.content
            return answer, False
        except (AuthenticationError, PermissionDeniedError, BadRequestError) as exc:
            logger.exception("Fatal OpenAI error: %s", exc)
            return (
                "システム側の設定で問題が起きています。"
                "少し時間をおいて、もう一度試してもらえますか？",
                True,
            )
        except (APITimeoutError, APIConnectionError, RateLimitError) as exc:
            logger.warning(
                "Transient OpenAI error on attempt %s/%s: %s",
                attempt,
                max_attempts,
                exc,
                exc_info=True,
            )
            if attempt == max_attempts:
                break
        except APIError as exc:
            logger.warning(
                "APIError on attempt %s/%s (status=%s): %s",
                attempt,
                max_attempts,
                getattr(exc, "status", None),
                exc,
                exc_info=True,
            )
            if getattr(exc, "status", 500) >= 500 and attempt < max_attempts:
                pass
            else:
                return (
                    "占いの処理で問題が発生しました。"
                    "少し時間をおいて、もう一度試していただけるとうれしいです。",
                    True,
                )

        delay = base_delay * (2 ** (attempt - 1))
        delay += random.uniform(0, 0.5)
        await asyncio.sleep(delay)

    return (
        "通信がうまくいかなかったみたいです。"
        "少し時間をおいて、もう一度試してもらえますか？",
        False,
    )


def _preview_text(text: str, limit: int = 80) -> str:
    if len(text) <= limit:
        return text
    return text[:limit] + "..."


def is_tarot_mode(text: str) -> bool:
    lowered = text.lower()
    return "占って" in text or lowered.startswith("/tarot")


def choose_spread(user_query: str) -> Spread:
    hints = ["3枚", "３枚", "三枚", "3card", "3 カード"]
    if any(hint in user_query for hint in hints):
        return THREE_CARD_SITUATION
    return ONE_CARD


def build_tarot_messages(
    *, spread: Spread, user_query: str, drawn_cards: list[dict[str, str]]
) -> list[dict[str, str]]:
    tarot_system_prompt = (
        "あなたは日本語で回答するタロット占い師です。"
        "以下のカード情報を必ず先に列挙し、各ポジション名とカード名・正逆を明示してから解釈を述べてください。\n"
        "- 与えられたカード以外を勝手に作らないこと。\n"
        "- 必ず『引いたカードは次の通りです』のような導入を入れ、ポジション順にカード名と正位置/逆位置を示すこと。\n"
        "- その後で質問内容に沿って、カードのキーワードを活かしながら優しく解釈してください。"
    )

    tarot_payload = {
        "spread_id": spread.id,
        "spread_name_ja": spread.name_ja,
        "positions": drawn_cards,
        "user_question": user_query,
    }

    return [
        {"role": "system", "content": tarot_system_prompt},
        {"role": "assistant", "content": json.dumps(tarot_payload, ensure_ascii=False, indent=2)},
        {"role": "user", "content": user_query},
    ]


@dp.message(CommandStart())
async def cmd_start(message: Message) -> None:
    await message.answer(
        "こんにちは、AIタロット占いボットの akolasia_tarot_bot です🌿\n"
        "ゆったりと心を整えながら、気になることをお話しくださいね。\n\n"
        "◆ 相談できるメニュー\n"
        "・恋愛運の占い（片思い、結婚のタイミングなど）\n"
        "・仕事や転職の占い（職場の人間関係も歓迎）\n"
        "・金運やお金にまつわる相談\n"
        "・今日 / 明日の運勢や全体運\n"
        "・テーマがまとまっていなくても、感じていることをそのまま話してOKです\n\n"
        "◆ 使い方の例\n"
        "・『今の恋愛はこの先どうなりますか？』\n"
        "・『明日の恋人の機嫌はどうかな？』\n"
        "・『転職した方が良いか迷っています』\n"
        "・『最近、何となく気持ちが落ち着きません』\n"
        "・『占って』とメッセージに入れるとタロット占いモードになります\n"
        "・それ以外のメッセージには、いつもの雑談や相談相手としてお話しします\n\n"
        "◆ やさしいお願い\n"
        "医療・法律・投資の判断は専門家に相談してください。\n"
        "占いは心の整理と気づきのヒントで、結果を保証するものではありません。\n"
        "不安が強いときは無理に信じすぎず、自分を大切にしてくださいね。",
    )


async def handle_tarot_reading(message: Message, user_query: str) -> None:
    logger.info(
        "Handling message",
        extra={
            "mode": "tarot",
            "user_id": message.from_user.id if message.from_user else None,
            "text_preview": _preview_text(user_query),
        },
    )

    spread = choose_spread(user_query)
    rng = random.Random()
    drawn = draw_cards(spread, rng=rng)

    drawn_payload: list[dict[str, str]] = []
    position_lookup = {pos.id: pos for pos in spread.positions}
    for item in drawn:
        position = position_lookup[item.position_id]
        keywords = (
            item.card.keywords_reversed_ja
            if item.is_reversed
            else item.card.keywords_upright_ja
        )
        drawn_payload.append(
            {
                "id": position.id,
                "label_ja": position.label_ja,
                "meaning_ja": position.meaning_ja,
                "card": {
                    "id": item.card.id,
                    "name_ja": item.card.name_ja,
                    "name_en": item.card.name_en,
                    "orientation": "reversed" if item.is_reversed else "upright",
                    "orientation_label_ja": orientation_label(item.is_reversed),
                    "keywords_ja": list(keywords),
                },
            }
        )

    messages = build_tarot_messages(
        spread=spread,
        user_query=user_query,
        drawn_cards=drawn_payload,
    )

    try:
        answer, fatal = await call_openai_with_retry(messages)
    except Exception:
        logger.exception("Unexpected error during tarot reading")
        await message.answer(
            "占いの準備で少しつまずいてしまいました。\n"
            "時間をおいて、もう一度話しかけてもらえるとうれしいです。"
        )
        return

    if fatal:
        await message.answer(
            answer
            + "\n\nご不便をおかけしてごめんなさい。時間をおいて再度お試しください。"
        )
        return

    await message.answer(answer)


async def handle_general_chat(message: Message, user_query: str) -> None:
    logger.info(
        "Handling message",
        extra={
            "mode": "chat",
            "user_id": message.from_user.id if message.from_user else None,
            "text_preview": _preview_text(user_query),
        },
    )

    try:
        answer, fatal = await call_openai_with_retry(build_general_chat_messages(user_query))
        if fatal:
            await message.answer(
                answer
                + "\n\nご不便をおかけしてごめんなさい。時間をおいて再度お試しください。"
            )
            return
        await message.answer(answer)
    except Exception:
        logger.exception("Unexpected error during general chat")
        await message.answer(
            "すみません、今ちょっと調子が悪いみたいです…\n"
            "少し時間をおいてから、もう一度メッセージを送ってもらえると助かります。"
        )


@dp.message()
async def handle_message(message: Message) -> None:
    text = (message.text or "").strip()

    if text.startswith("/start"):
        return

    if not text:
        await message.answer(
            "気になることをもう少し詳しく教えてくれるとうれしいです。"
        )
        return

    if is_tarot_mode(text):
        await handle_tarot_reading(message, user_query=text)
    else:
        await handle_general_chat(message, user_query=text)


async def main() -> None:
    setup_logging()
    logger.info("Starting akolasia_tarot_bot")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
