import os
import logging
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import Application, MessageHandler, ContextTypes, filters

from pitomadom import Pitomadom

load_dotenv()
logging.basicConfig(level=logging.INFO)

bot = Pitomadom()

async def handle(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message or not update.message.text:
        return
    text = update.message.text
    reply = bot.interact(text)
    await update.message.reply_text(reply)

def main() -> None:
    token = os.environ["TELEGRAM_TOKEN"]
    application = Application.builder().token(token).build()
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle))
    application.run_polling()

if __name__ == "__main__":
    main()
