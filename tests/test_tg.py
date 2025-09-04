from types import SimpleNamespace
from unittest.mock import Mock

from tg import process_update


def test_process_update_calls_bot_and_replies():
    bot = Mock()
    bot.interact.return_value = "pong"

    message = Mock(text="ping")
    update = SimpleNamespace(message=message)

    process_update(update, bot)

    bot.interact.assert_called_once_with("ping")
    message.reply_text.assert_called_once_with("pong")
