import os
from subjectivity import Subjectivity
from telegram.ext import ApplicationBuilder, MessageHandler, filters


def build_application(token: str):
    """Builds a Telegram application bound to the Subjectivity chatbot."""
    bot = Subjectivity()

    async def handle(update, context):
        text = update.message.text or ""
        reply = bot.reply(text)
        await update.message.reply_text(reply)

    app = ApplicationBuilder().token(token).build()
    app.add_handler(MessageHandler(filters.TEXT, handle))
    return app


def main():
    token = os.environ["TELEGRAM_TOKEN"]
    app = build_application(token)
    app.run_polling()


if __name__ == "__main__":
    main()
