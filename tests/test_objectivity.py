from objectivity import _ddg_json


class DummyResponse:
    def __init__(self, data, status=200):
        self.data = data
        self.status_code = status

    def json(self):
        return self.data


def test_glossary_filtered():
    data = {"AbstractText": "Python is a programming language."}

    def fetch(url, headers=None, timeout=None):
        return DummyResponse(data)

    assert _ddg_json("python", fetch=fetch) == []


def test_snippet_first_sentence_selected():
    data = {"AbstractText": "I think you should try the cake. It's delicious and popular."}

    def fetch(url, headers=None, timeout=None):
        return DummyResponse(data)

    assert _ddg_json("cake", fetch=fetch) == ["I think you should try the cake."]
