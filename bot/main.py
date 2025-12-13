import asyncio
import logging
import os

from aiogram import Bot, Dispatcher, F
from aiogram.filters import CommandStart
from aiogram.types import Message
from dotenv import load_dotenv
from openai import OpenAI


# .env から環境変数を読み込む
load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not TELEGRAM_BOT_TOKEN:
    raise RuntimeError("TELEGRAM_BOT_TOKEN is not set in .env")

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY is not set in .env")


# OpenAI クライアント
client = OpenAI(api_key=OPENAI_API_KEY)

# Telegram Bot / Dispatcher
bot = Bot(token=TELEGRAM_BOT_TOKEN)
dp = Dispatcher()


# /start コマンド
@dp.message(CommandStart())
async def cmd_start(message: Message) -> None:
    await message.answer(
        "はじめまして、タロット占いテストボットです🐈✨\n"
        "占ってほしいことを日本語で送ってください。\n"
        "（例）『仕事運をみて』『今の恋愛はこの先どうなりますか？』"
    )


# 通常のテキストメッセージ
@dp.message(F.text)
async def handle_question(message: Message) -> None:
    user_text = (message.text or "").strip()
    if not user_text:
        await message.answer("何か占ってほしいことを、日本語で送ってみてください。")
        return

    try:
        system_prompt = (
            "あなたは優しい日本語で占うタロット占い師です。"
            "カードの意味を説明しつつ、相談者の気持ちに寄り添った結果を伝えてください。"
            "スプレッドやカードの名前も、必要に応じて簡潔に触れてください。"
        )

        completion = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_text},
            ],
        )

        answer = completion.choices[0].message.content
        await message.answer(answer)

    except Exception:
        logging.exception("Tarot reading failed")
        await message.answer(
            "占い中にエラーが起きちゃったみたい…💦\n"
            "少し時間をおいて、もう一度試してもらえる？"
        )


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
