import asyncio
import objectivity
from objectivity import Objectivity


def test_ignored_tokens_not_in_queries(monkeypatch):
    sent_queries = []

    async def fake_ddg_json(query):
        sent_queries.append(query)
        return []

    monkeypatch.setattr(objectivity, "_ddg_json", fake_ddg_json)

    obj = Objectivity()
    asyncio.run(obj.context_window("talk about banana", ["banana"]))

    assert sent_queries == []


def test_mixed_queries_filter(monkeypatch):
    sent_queries = []

    async def fake_ddg_json(query):
        sent_queries.append(query)
        return []

    monkeypatch.setattr(objectivity, "_ddg_json", fake_ddg_json)

    obj = Objectivity()
    asyncio.run(obj.context_window("How to make salad", ["responding"]))

    assert sent_queries  # other queries should remain
    assert all("responding" not in q for q in sent_queries)

