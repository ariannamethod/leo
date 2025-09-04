from unittest.mock import Mock

from pitomadom import Pitomadom


def test_interact_flow():
    bot = Pitomadom()

    bot.subjectivity.reply = Mock(return_value="hello world")
    bot.infinity.add = Mock()
    bot.connections.related_tokens = Mock(return_value=["foo", "hello"])

    result = bot.interact("hi")

    bot.subjectivity.reply.assert_called_once_with("hi")
    bot.infinity.add.assert_called_once_with("hello world")
    bot.connections.related_tokens.assert_called_once_with("hello world")
    assert result == "hello world foo."
