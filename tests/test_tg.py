import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock

from tg import process_update


def test_process_update_calls_bot_and_replies():
    bot = AsyncMock()
    bot.interact.return_value = "pong"

    message = SimpleNamespace(text="ping", reply_text=AsyncMock())
    update = SimpleNamespace(message=message)

    asyncio.run(process_update(update, bot))

    bot.interact.assert_awaited_once_with("ping")
    message.reply_text.assert_awaited_once_with("pong")
