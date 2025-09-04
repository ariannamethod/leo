import os
import re
import requests
from urllib.parse import quote
from typing import List, Optional

USER_AGENT = "subjectivity/1.0 (+github.com/ariannamethod/subjectivity)"

# Вики оставлена только как глубокий бэкап (не для окна ответа)
WIKI_REST_SUMMARY = "https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}"
WIKI_LANGS = ["en", "uk", "he", "es", "pl", "de", "fr", "ru"]


def _looks_like_glossary(text: str) -> bool:
    t = " " + text.lower() + " "
    bad = [
        " is a ", " is an ", " is the ", " was a ", " was an ",
        "notable people", "family name", "given name", "surname",
        "capital is", "is the capital", "programming language",
        "population", "metropolitan areas",
    ]
    if any(b in t for b in bad):
        return True
    words = re.findall(r"\b\w+\b", text)
    # короткие заголовки без глаголов
    if 1 <= len(words) <= 4 and sum(w[0].isupper() for w in words) >= len(words) - 1:
        if not any(w.lower() in {"is", "are", "was", "were", "has", "have", "do", "does"} for w in words):
            return True
    return False


def _ddg_json(query: str) -> List[str]:
    """Лёгкий веб‑поиск через DuckDuckGo Instant Answer API (без ключей)."""
    url = f"https://api.duckduckgo.com/?q={quote(query)}&format=json&no_html=1&no_redirect=1"
    try:
        r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=4)
        if r.status_code != 200:
            return []
        data = r.json()
    except Exception:
        return []

    out: List[str] = []

    def add(s: Optional[str]):
        if not s:
            return
        s = re.sub(r"\s+", " ", s).strip()
        if not s:
            return
        if len(s) < 5:
            return
        if _looks_like_glossary(s):
            return
        out.append(s)

    # AbstractText иногда даёт 1–2 фразы
    add(data.get("AbstractText"))

    # RelatedTopics -> список «Text», иногда вложен в подсписки
    def walk_topics(items):
        for it in items or []:
            if isinstance(it, dict):
                if "Text" in it:
                    add(it.get("Text"))
                if "Topics" in it and isinstance(it["Topics"], list):
                    walk_topics(it["Topics"])

    walk_topics(data.get("RelatedTopics"))

    # Часто DDG даёт много мусора — ограничим до первых 6
    uniq = []
    seen = set()
    for s in out:
        k = s.lower()
        if k not in seen:
            seen.add(k)
            uniq.append(s)
    return uniq[:6]


def _build_queries(message: str) -> List[str]:
    msg = message.strip()
    words = re.findall(r"\b\w+\b", msg.lower())
    q: List[str] = []

    # Хиты для smalltalk — объяснение и «как ответить»
    # Примеры: "how are you?", "you love berlin?" и т.п.
    q.append(f"what does \"{msg}\" mean in conversation and how to reply")
    q.append(f"small talk reply to \"{msg}\" examples")

    # Если есть Capitalized или многословные сущности — отдельные «мягкие» запросы
    caps = re.findall(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b", message)
    caps += re.findall(r"\b([A-Z]{2,})\b", message)
    caps = [c for c in caps if c not in {"I", "A", "The", "And", "Or"}]
    for c in caps[:2]:
        q.append(f"{c} small talk what to say")
        q.append(f"why people like {c} quotes short")

    # Укорачиваем слишком длинные запросы
    cleaned = []
    for s in q:
        s = re.sub(r"\s+", " ", s).strip()
        if len(s) > 128:
            s = s[:128]
        cleaned.append(s)
    # Уникализируем, сохраняя порядок
    seen = set()
    uniq = []
    for s in cleaned:
        if s not in seen:
            seen.add(s)
            uniq.append(s)
    return uniq[:4]


def _fetch_wiki_backup(term: str) -> Optional[str]:
    for lang in WIKI_LANGS:
        url = WIKI_REST_SUMMARY.format(lang=lang, title=quote(term))
        try:
            r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=3)
            if r.status_code == 200:
                data = r.json()
                extract = (data.get("extract") or "").strip()
                if not extract:
                    continue
                parts = re.split(r"(?<=[.!?])\s+", extract)
                short = " ".join(parts[:2]).strip()
                if short:
                    return short
        except Exception:
            continue
    return None


class Objectivity:
    def context_window(self, message: str, tokens: List[str]) -> str:
        """
        Строим окно только из веб‑сниппетов DDG.
        Вики — только как глубокий бэкап, и не включается, если есть хоть что-то с веба.
        """
        queries = _build_queries(message)
        snippets: List[str] = []
        for q in queries:
            items = _ddg_json(q)
            for s in items:
                # Отрезаем «лишние хвосты», стараемся держать 1 коротную фразу
                parts = re.split(r"(?<=[.!?])\s+", s)
                if parts:
                    snippet = parts[0].strip()
                    # убираем явные URL, скобки, строки с длинными цифрами
                    if re.search(r"https?://", snippet):
                        continue
                    if sum(ch.isdigit() for ch in snippet) > 6:
                        continue
                    if len(snippet.split()) < 3:
                        continue
                    if snippet and snippet not in snippets:
                        snippets.append(snippet)
                if len(snippets) >= 6:
                    break
            if len(snippets) >= 6:
                break

        # Если совсем пусто — попробуем 1 короткий бэкап из Вики, но НЕ как «дефиницию»
        # и всё равно отдаём это в окно (после фильтров _looks_like_glossary возвращать не будем).
        if not snippets:
            # Берём Capitalized из сообщения, иначе ничего.
            caps = re.findall(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b", message)
            caps += re.findall(r"\b([A-Z]{2,})\b", message)
            caps = [c for c in caps if c not in {"I", "A", "The", "And", "Or"}]
            for c in caps[:1]:
                wb = _fetch_wiki_backup(c)
                if wb and not _looks_like_glossary(wb):
                    snippets.append(wb)

        # Возвращаем «свежее» окно (Вики попадёт сюда только при полном отсутствии веб‑результатов)
        return "\n".join(snippets).strip()
