import re
import requests
from urllib.parse import quote
from typing import Dict, List, Optional, Tuple

USER_AGENT = "subjectivity/1.0 (+github.com/ariannamethod/subjectivity)"

class Objectivity:
    """Language-agnostic context window generator.

    Retrieves concise context from Wikipedia via Wikidata sitelinks:
      term -> Wikidata Q-id -> sitelinks -> best *wiki -> REST /page/summary
    Returns only plain text (title + extract), no links.
    Designed for CPU-only environments with strict byte budget.
    """

    def __init__(self, max_kb: int = 1, max_terms: int = 3, timeout_s: float = 6.0):
        self.max_bytes = max_kb * 1024
        self.max_terms = max_terms
        self.timeout_s = timeout_s
        self.lang_priority = [
            "en","ru","es","de","fr","it","pt","zh","ja","uk","pl","nl",
            "sv","cs","tr","ar","ko","he","fi","no","da","ro","hu","el","bg",
            "fa","hi","id","th"
        ]
        self._session = requests.Session()
        self._session.headers.update({"User-Agent": USER_AGENT})

    def context_window(self, message: str, tokens: List[str]) -> str:
        terms = self._prepare_terms(message, tokens)
        segments: List[str] = []
        seen_titles = set()

        for term in terms[: self.max_terms]:
            item = self._fetch_summary_via_wikidata(term)
            if not item:
                continue
            title, extract = item
            key = title.strip().lower()
            if key in seen_titles:
                continue
            seen_titles.add(key)
            seg = f"{title}\n{extract}" if title else extract
            if not seg:
                continue
            segments.append(seg)
            if self._encoded_len(segments) >= self.max_bytes:
                break

        context = "\n\n".join(segments).strip() or message
        return self._truncate_bytes(context, self.max_bytes)

    # ---------- term prep ----------

    def _prepare_terms(self, message: str, tokens: List[str]) -> List[str]:
        terms: List[str] = []
        terms += re.findall(r"\b[A-ZА-Я][a-zа-я]+\b", " ".join(tokens))
        terms += re.findall(r"\b[A-ZА-Я]{2,}\b", " ".join(tokens))
        seen = set()
        ordered: List[str] = []
        for t in terms or tokens or [message.strip()[:64]]:
            tt = t.strip()
            if not tt:
                continue
            if tt not in seen:
                seen.add(tt)
                ordered.append(tt)
        return ordered or [message.strip()[:64]]

    # ---------- Wikidata -> Wikipedia ----------

    def _fetch_summary_via_wikidata(self, term: str) -> Optional[Tuple[str, str]]:
        qid = self._wikidata_search(term)
        if not qid:
            return None
        ent = self._wikidata_entity(qid)
        if not ent:
            return None
        sitelinks = (ent.get("entities", {}).get(qid, {}).get("sitelinks", {}) or {})
        lang, title = self._pick_sitelink(sitelinks)
        if not lang or not title:
            return None
        return self._wikipedia_summary(lang, title)

    def _wikidata_search(self, term: str) -> Optional[str]:
        try:
            r = self._session.get(
                "https://www.wikidata.org/w/api.php",
                params={
                    "action": "wbsearchentities",
                    "format": "json",
                    "language": "en",
                    "type": "item",
                    "search": term,
                    "limit": 1,
                },
                timeout=self.timeout_s,
            )
            if r.status_code != 200:
                return None
            data = r.json()
            hits = data.get("search") or []
            return hits[0].get("id") if hits else None
        except Exception:
            return None

    def _wikidata_entity(self, qid: str) -> Optional[Dict]:
        try:
            r = self._session.get(
                f"https://www.wikidata.org/wiki/Special:EntityData/{qid}.json",
                timeout=self.timeout_s,
            )
            if r.status_code != 200:
                return None
            return r.json()
        except Exception:
            return None

    def _pick_sitelink(self, sitelinks: Dict) -> Tuple[Optional[str], Optional[str]]:
        for lang in self.lang_priority:
            key = f"{lang}wiki"
            if key in sitelinks:
                title = sitelinks[key].get("title") or ""
                if title:
                    return lang, title
        for k, v in sitelinks.items():
            if k.endswith("wiki"):
                lang = k[:-4]
                title = v.get("title") or ""
                if lang and title:
                    return lang, title
        return None, None

    def _wikipedia_summary(self, lang: str, title: str) -> Optional[Tuple[str, str]]:
        try:
            url = f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{quote(title.replace(' ', '_'))}"
            r = self._session.get(url, timeout=self.timeout_s)
            if r.status_code != 200:
                return None
            d = r.json()
            t = (d.get("title") or title).strip()
            extract = (d.get("extract") or "").strip()
            if not extract:
                return None
            return t, extract[:900]
        except Exception:
            return None

    # ---------- byte helpers ----------

    @staticmethod
    def _encoded_len(parts: List[str]) -> int:
        return len("\n\n".join(parts).encode("utf-8"))

    @staticmethod
    def _truncate_bytes(text: str, max_bytes: int) -> str:
        b = text.encode("utf-8")
        if len(b) <= max_bytes:
            return text
        cut = b[:max_bytes]
        while True:
            try:
                return cut.decode("utf-8", errors="ignore")
            except Exception:
                cut = cut[:-1]
