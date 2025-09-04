import pathlib
import sys

sys.path.append(str(pathlib.Path(__file__).resolve().parents[1]))
import subjectivity  # noqa: E402


def test_metrics():
    s = subjectivity.Subjectivity()
    metrics = s._metrics("Hello world hello")
    assert set(metrics.keys()) == {"perplexity", "entropy", "resonance"}
    assert metrics["perplexity"] >= 1
    assert 0 <= metrics["resonance"] <= 1


def test_reply(monkeypatch):
    class DummyCuriosity:
        def remember(self, *args, **kwargs):
            pass

    monkeypatch.setattr(subjectivity, "Curiosity", lambda: DummyCuriosity())
    s = subjectivity.Subjectivity()

    def dummy_context(message, tokens):
        return "foo bar baz"

    monkeypatch.setattr(s.objectivity, "context_window", dummy_context)
    reply = s.reply("Hello world")
    assert isinstance(reply, str) and len(reply) > 0
