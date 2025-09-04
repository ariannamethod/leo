import re
import requests
from urllib.parse import quote

class Objectivity:
    """Minimal context window generator.

    Fetches small snippets from Wikipedia based on charged tokens.
    Designed for CPU-only environments.
    """

    def __init__(self, max_kb: int = 1):
        self.max_bytes = max_kb * 1024

    def context_window(self, message: str, tokens):
        segments = []
        for token in tokens:
            text = self._wiki_summary(token)
            if text:
                segments.append(text)
            if sum(len(s.encode('utf-8')) for s in segments) >= self.max_bytes:
                break
        context = " ".join(segments) or message
        return context[: self.max_bytes]

    def _wiki_summary(self, term: str) -> str:
        lang = 'ru' if re.search(r'[А-Яа-я]', term) else 'en'
        url = f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{quote(term)}"
        try:
            r = requests.get(url, timeout=5)
            if r.status_code == 200:
                data = r.json()
                return data.get('extract', '')[:512]
        except Exception:
            pass
        return ""
