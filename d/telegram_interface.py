from pitomadom import Pitomadom


def process_update(update, bot=None):
    """Handle a Telegram update by delegating to Pitomadom.

    Parameters
    ----------
    update: object
        An object with a ``message`` attribute containing ``text`` and
        ``reply_text``.
    bot: Pitomadom, optional
        Bot instance used to generate a response. A new ``Pitomadom``
        is created if none is provided.
    """
    bot = bot or Pitomadom()
    text = getattr(getattr(update, 'message', None), 'text', '')
    response = bot.interact(text)
    update.message.reply_text(response)
    return response
