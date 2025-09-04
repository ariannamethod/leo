import types
import sys
import pathlib

sys.path.append(str(pathlib.Path(__file__).resolve().parents[1]))
import tg  # noqa: E402


def test_build_application(monkeypatch):
    class DummyApp:
        def __init__(self):
            self.handlers = []

        def add_handler(self, h):
            self.handlers.append(h)

    class DummyBuilder:
        def __init__(self):
            self.token_value = None

        def token(self, tok):
            self.token_value = tok
            return self

        def build(self):
            return DummyApp()

    dummy_builder = DummyBuilder()
    monkeypatch.setattr(tg, "ApplicationBuilder", lambda: dummy_builder)

    class DummyHandler:
        def __init__(self, filt, func):
            self.filt = filt
            self.func = func

    monkeypatch.setattr(tg, "MessageHandler", DummyHandler)
    monkeypatch.setattr(tg, "filters", types.SimpleNamespace(TEXT="TEXT"))

    app = tg.build_application("TOKEN")
    assert dummy_builder.token_value == "TOKEN"
    assert isinstance(app, DummyApp)
    assert len(app.handlers) == 1
