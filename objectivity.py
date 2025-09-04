import re
import requests
from urllib.parse import quote
from typing import List, Optional

USER_AGENT = "subjectivity/1.0 (+github.com/ariannamethod/subjectivity)"

# Вики не включаем в окно ответа. Оставлено как глубокий бэкап — но мы больше не используем его здесь.
# Всё «живое» окно собирается только из веб‑сниппетов.

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
    if 1 <= len(words) <= 4 and sum(w[0].isupper() for w in words) >= len(words) - 1:
        if not any(w.lower() in {"is", "are", "was", "were", "has", "have", "do", "does"} for w in words):
            return True
    return False


def _ddg_json(query: str) -> List[str]:
    """Лёгкий веб‑поиск через DuckDuckGo Instant Answer API (без ключей). Только разговорные сниппеты."""
    url = f"https://api.duckduckgo.com/?q={quote(query)}&format=json&no_html=1&no_redirect=1"
    out: List[str] = []
    try:
        r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=4)
        if r.status_code != 200:
            return out
        data = r.json()
    except Exception:
        return out

    def emit(s: Optional[str]):
        if not s:
            return
        s = re.sub(r"\s+", " ", s).strip()
        if len(s) < 5:
            return
        if _looks_like_glossary(s):
            return
        # убираем URL, мусорные хвосты
        if re.search(r"https?://", s):
            return
        out.append(s)

    # AbstractText
    emit(data.get("AbstractText"))

    # RelatedTopics (в т.ч. вложенные)
    def walk(items):
        for it in items or []:
            if isinstance(it, dict):
                if "Text" in it:
                    emit(it.get("Text"))
                if isinstance(it.get("Topics"), list):
                    walk(it["Topics"])
    walk(data.get("RelatedTopics"))

    # Уникализируем, ограничиваем 6
    uniq, seen = [], set()
    for s in out:
        k = s.lower()
        if k not in seen:
            seen.add(k)
            uniq.append(s)
    return uniq[:6]


def _build_queries(message: str) -> List[str]:
    msg = re.sub(r"\s+", " ", message.strip())
    base = [
        f"{msg} meaning in conversation",
        f"reply examples to \"{msg}\"",
        f"small talk lines about \"{msg}\"",
        f"how to respond to \"{msg}\"",
    ]
    # Если есть сущности с заглавной — добавим «мягкие» запросы
    caps = re.findall(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b", message)
    caps += re.findall(r"\b([A-Z]{2,})\b", message)
    caps = [c for c in caps if c not in {"I", "A", "The", "And", "Or"}]
    for c in caps[:2]:
        base += [f"{c} what to say short", f"{c} small talk quotes"]
    # Уникализируем/режем длину
    seen, out = set(), []
    for q in base:
        q = q[:128]
        if q not in seen:
            seen.add(q)
            out.append(q)
    return out[:6]


class Objectivity:
    def context_window(self, message: str, _tokens_ignored: List[str]) -> str:
        """
        Только веб‑сниппеты (DDG). Вики не включаем.
        Гарантируем, что если есть сеть — будет хотя бы 1 фраза.
        """
        snippets: List[str] = []
        for q in _build_queries(message):
            items = _ddg_json(q)
            for s in items:
                # Берём только первую законченную фразу
                parts = re.split(r"(?<=[.!?])\s+", s)
                if not parts:
                    continue
                phr = parts[0].strip()
                # фильтры: слишком коротко/цифропомои/URL
                if len(phr.split()) < 3:
                    continue
                if sum(ch.isdigit() for ch in phr) > 6:
                    continue
                if phr and phr not in snippets:
                    snippets.append(phr)
                if len(snippets) >= 6:
                    break
            if len(snippets) >= 6:
                break
        return "\n".join(snippets).strip()
