import math
import random
import re
from typing import List

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
        charged = [t for t in tokens if t[0].isupper() or len(t) > 7]
        return charged or tokens[:3]

    def reply(self, message: str) -> str:
        metrics = self._metrics(message)
        tokens = self._charged_tokens(message)
        context = self.objectivity.context_window(message, tokens)
        response = self._craft_response(context)
        self.curiosity.remember(message, context, response, metrics)
        return response

    def _craft_response(self, context: str) -> str:
        words = re.findall(r"\b\w+\b", context)
        pairs = [
            (words[i], words[i + 1])
            for i in range(len(words) - 1)
            if len(words[i]) > 1
            and len(words[i + 1]) > 1
            and not ({words[i].lower(), words[i + 1].lower()} <= {"a", "the"})
        ]
        # Remove duplicate pairs to avoid repeated phrases
        seen = []
        unique_pairs = []
        for pair in pairs:
            if pair not in seen:
                seen.append(pair)
                unique_pairs.append(pair)
        random.shuffle(unique_pairs)
        sentences = []
        for a, b in unique_pairs[:2]:
            sentences.append(f"{a.capitalize()} {b.lower()}.")
        return " ".join(sentences)
