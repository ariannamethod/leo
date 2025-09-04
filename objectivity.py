import re
import requests
from urllib.parse import quote
from typing import Dict, List, Optional, Tuple

USER_AGENT = "subjectivity/1.0 (+github.com/ariannamethod/subjectivity)"

WIKI_REST_SUMMARY = "https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}"

# Языки, которые иногда всплывают в реальном трафике; сначала en как дефолт
WIKI_LANGS = ["en", "uk", "he", "es", "pl", "de", "fr", "ru"]


def _pick_cap_spans(message: str) -> List[str]:
    # Берём только куски, где слова с заглавной: "New York", "Berlin", "United Arab Emirates", "R"
    # Игнорируем одиночные служебные "I", "A" и т.п.
    spans = []
    # многословные сущности
    for m in re.finditer(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b", message):
        spans.append(m.group(1))
    # одиночные токены в капсе (например, R, XAI, GPT), длина >= 2 либо один символ, который не I/A
    for m in re.finditer(r"\b([A-Z]{2,})\b", message):
        spans.append(m.group(1))
    # одиночные TitleCase длиной >= 3 (Berlin, London)
    for m in re.finditer(r"\b([A-Z][a-z]{2,})\b", message):
        spans.append(m.group(1))
    # фильтры
    bad = {"I", "A", "The", "And", "Or"}
    spans = [s for s in spans if s not in bad]
    # уникализируем, сохраняя порядок появления
    seen = set()
    out = []
    for s in spans:
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out[:3]  # больше не нужно — перегружает окно


def _looks_like_glossary(text: str) -> bool:
    t = " " + text.lower() + " "
    # дефиниционные и "фамильные" шаблоны — выкидываем
    bad = [
        " is a ", " is an ", " is the ", "was a ", "was an ",
        "surname", "family name", "given name",
        "notable people", "notable persons",
        "capital is", "is the capital",
        "programming language",
    ]
    if any(b in t for b in bad):
        return True
    # Очень короткие заголовки/титлы без глаголов
    words = re.findall(r"\b\w+\b", text)
    if 1 <= len(words) <= 4 and sum(w[0].isupper() for w in words) >= len(words) - 1:
        return True
    return False


class Objectivity:
    def _fetch_summary(self, term: str) -> Optional[str]:
        # Пробуем несколько языков, пока не найдём нормальный summary
        for lang in WIKI_LANGS:
            url = WIKI_REST_SUMMARY.format(lang=lang, title=quote(term))
            try:
                r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=3)
                if r.status_code == 200:
                    data = r.json()
                    extract = data.get("extract") or ""
                    if extract and not _looks_like_glossary(extract):
                        # берём первые 1–2 предложения
                        parts = re.split(r"(?<=[.!?])\s+", extract.strip())
                        short = " ".join(parts[:2]).strip()
                        if short:
                            return short
            except Exception:
                continue
        return None

    def context_window(self, message: str, tokens: List[str]) -> str:
        # ВАЖНО: больше не ищем по каждому слову.
        # Только капспаны/TitleCase из исходного сообщения юзера.
        terms = _pick_cap_spans(message)
        if not terms:
            # Нет имён собственных — не загружаем Википедию, пусть решает композер.
            return ""

        snippets: List[str] = []
        for t in terms[:2]:  # максимум 2 запроса
            s = self._fetch_summary(t)
            if s:
                snippets.append(s)

        # Если ничего годного с Вики — пустая строка, композер не привязан к Вики-жёстко
        return ("\n".join(snippets)).strip()
