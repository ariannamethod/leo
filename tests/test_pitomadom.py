import asyncio
from unittest.mock import Mock, AsyncMock

from pitomadom import Pitomadom


def test_interact_flow():
    bot = Pitomadom()

    bot.subjectivity.reply = AsyncMock(return_value="hello world")
    bot.infinity.add = Mock()
    bot.connections.related_tokens = Mock(return_value=["foo", "hello"])

    result = asyncio.run(bot.interact("hi"))

    bot.subjectivity.reply.assert_called_once_with("hi")
    bot.infinity.add.assert_called_once_with("hello world")
    bot.connections.related_tokens.assert_called_once_with("hello world")
    assert result == "hello world foo."
