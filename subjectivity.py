import math
import re
import hashlib
from typing import List, Tuple

from objectivity import Objectivity
from curiosity import Curiosity

class Subjectivity:
    """Main module evaluating messages and crafting responses."""

    def __init__(self):
        self.objectivity = Objectivity()
        self.curiosity = Curiosity()

    def _metrics(self, text: str):
        words = re.findall(r"\w+", text.lower())
        total = len(words) or 1
        freq = {w: words.count(w) / total for w in set(words)}
        entropy = -sum(p * math.log(p, 2) for p in freq.values())
        perplexity = 2 ** entropy
        resonance = sum(1 for w in words if w.isalpha()) / total
        return {"perplexity": perplexity, "entropy": entropy, "resonance": resonance}

    def _charged_tokens(self, text: str) -> List[str]:
        tokens = re.findall(r"\b\w+\b", text)
        charged = [t for t in tokens if (t[:1].isupper() and len(t) > 1) or len(t) > 7]
        return charged or tokens[:3]

    def reply(self, message: str) -> str:
        metrics = self._metrics(message)
        tokens = self._charged_tokens(message)
        context = self.objectivity.context_window(message, tokens)
        response = self._craft_response(context)
        self.curiosity.remember(message, context, response, metrics)
        return response

    # ---------- Phrase Composer with punctuation ----------

    def _craft_response(self, context: str) -> str:
        words = re.findall(r"\b\w+\b", context)
        if not words:
            return ""

        bigrams = self._unique_bigrams(words)
        if not bigrams:
            sent = self._format_sentence(" ".join(words[:6]))
            return sent

        seed = int(hashlib.sha256(context.encode("utf-8")).hexdigest(), 16)

        clauses = []
        idx = 0
        step = max(1, seed % 5)  # 1..4
        while idx < len(bigrams) and len(clauses) < 3:
            a, b = bigrams[idx]
            clause = f"{a} {b}"
            if not clauses or clauses[-1].split()[-1].lower() != a.lower():
                clauses.append(clause)
            idx += step

        if not clauses:
            clauses = [f"{a} {b}" for a, b in bigrams[:2]]

        sentence = self._join_clauses_with_punct(clauses, seed)
        return self._format_sentence(sentence)

    def _unique_bigrams(self, words: List[str]) -> List[Tuple[str, str]]:
        pairs = []
        seen = set()
        for i in range(len(words) - 1):
            a, b = words[i], words[i + 1]
            if len(a) < 2 or len(b) < 2:
                continue
            if {a.lower(), b.lower()} <= {"a", "the", "and", "of"}:
                continue
            key = (a.lower(), b.lower())
            if key not in seen:
                seen.add(key)
                pairs.append((a, b))
        return pairs

    def _join_clauses_with_punct(self, clauses: List[str], seed: int) -> str:
        punct_schemes = [
            [", ", " — ", "."],
            ["; ", ", ", "."],
            [" — ", ", ", "."],
            [", ", ", ", "."],
        ]
        scheme = punct_schemes[seed % len(punct_schemes)]
        out = []
        for i, c in enumerate(clauses):
            out.append(c)
            if i < len(clauses) - 1:
                out.append(scheme[i % (len(scheme) - 1)])
        out.append(".")
        text = "".join(out)
        text = re.sub(r"\s{2,}", " ", text)
        text = re.sub(r"([.!?])\.+$", r"\1", text)
        return text.strip()

    def _format_sentence(self, text: str) -> str:
        text = text.strip()
        if not text:
            return ""
        text = text[0].upper() + text[1:]
        if not re.search(r"[.!?]$", text):
            text += "."
        return text
