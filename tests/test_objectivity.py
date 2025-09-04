import objectivity
from objectivity import Objectivity


def test_ignored_tokens_not_in_queries(monkeypatch):
    sent_queries = []

    def fake_ddg_json(query):
        sent_queries.append(query)
        return []

    monkeypatch.setattr(objectivity, "_ddg_json", fake_ddg_json)

    obj = Objectivity()
    obj.context_window("banana", ["banana"])

    assert sent_queries == []


def test_mixed_queries_filter(monkeypatch):
    sent_queries = []

    def fake_ddg_json(query):
        sent_queries.append(query)
        return []

    monkeypatch.setattr(objectivity, "_ddg_json", fake_ddg_json)

    obj = Objectivity()
    obj.context_window("How to make salad", ["responding"])

    assert sent_queries  # other queries should remain
    assert all("responding" not in q for q in sent_queries)


def test_filtered_tokens_removed_before_query_building(monkeypatch):
    sent_queries = []

    def fake_ddg_json(query):
        sent_queries.append(query)
        return []

    monkeypatch.setattr(objectivity, "_ddg_json", fake_ddg_json)

    obj = Objectivity()
    obj.context_window("talk about banana", ["banana"])

    assert sent_queries
    assert all("banana" not in q.lower() for q in sent_queries)


def test_snippets_skip_ignored_tokens(monkeypatch):
    monkeypatch.setattr(
        objectivity,
        "_build_conversation_queries",
        lambda message: ["dummy"],
    )

    def fake_ddg_json(query):
        return ["banana is great", "I think we should talk"]

    monkeypatch.setattr(objectivity, "_ddg_json", fake_ddg_json)

    obj = Objectivity()
    result = obj.context_window("any message", ["banana"])

    assert "banana" not in result.lower()
    assert "i think we should talk" in result.lower()

