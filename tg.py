import os
from dotenv import load_dotenv
from telegram import Update
from telegram.ext import Application, MessageHandler, ContextTypes, filters

from pitomadom import Pitomadom

load_dotenv()

bot = Pitomadom()

def process_update(update: Update, bot_instance: Pitomadom) -> None:
    text = update.message.text
    reply = bot_instance.interact(text)
    update.message.reply_text(reply)

async def handle(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    process_update(update, bot)

def main() -> None:
    token = os.environ["TELEGRAM_TOKEN"]
    application = Application.builder().token(token).build()
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle))
    application.run_polling()

if __name__ == "__main__":
    main()
