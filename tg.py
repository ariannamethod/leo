import os
import logging
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import Application, MessageHandler, ContextTypes, filters

from pitomadom import Pitomadom

load_dotenv()
logging.basicConfig(level=logging.INFO)

bot = Pitomadom()


async def process_update(update, bot_instance=None) -> None:
    """Handle a single Telegram update using the provided bot instance."""
    if not update or not getattr(update, "message", None) or not update.message.text:
        return
    bot_obj = bot_instance or bot
    reply = await bot_obj.interact(update.message.text)
    await update.message.reply_text(reply)


async def handle(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await process_update(update, bot)

def main() -> None:
    token = os.environ["TELEGRAM_TOKEN"]
    application = Application.builder().token(token).build()
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle))
    application.run_polling()

if __name__ == "__main__":
    main()
