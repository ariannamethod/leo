import math
import re
import hashlib
import random
from typing import List, Tuple, Optional

from objectivity import Objectivity
from curiosity import Curiosity


STOPWORDS = {
    "the","a","an","of","and","or","to","in","on","for","as","at","by","with","from",
    "is","are","was","were","be","been","being","this","that","it","its","into","than",
    "then","so","but","nor","if","because","while","when","where","which","who","whom"
}

# Forbid comma before these words (", is", ", the", ", and" -> fix)
FORBID_COMMA_BEFORE = {
    "is","are","was","were","am","be","been","being",
    "a","an","the","and","or","but","nor","of","to","in","on","for","as","at","by","with","from"
}

# Pronoun inversion map (like in `me`), expanded a bit; case preserved at runtime
_PRONOUN_MAP = {
    "you": "i", "u": "i", "your": "my", "yours": "mine", "yourself": "myself", "yourselves": "ourselves",
    "i": "you", "me": "you", "my": "your", "mine": "yours", "myself": "yourself",
    "we": "you", "us": "you", "our": "your", "ours": "yours", "ourselves": "yourselves",
}


class Subjectivity:
    """Main module evaluating messages and crafting responses."""

    def __init__(self):
        self.objectivity = Objectivity()
        self.curiosity = Curiosity()

    # ---------- metrics ----------

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

    # ---------- public ----------

    def reply(self, message: str) -> str:
        metrics = self._metrics(message)
        tokens = self._charged_tokens(message)
        context = self.objectivity.context_window(message, tokens)

        response = self._craft_response(message, context)

        # Optional pronoun inversion (as in `me`) only if user used pronouns
        if self._user_has_pronouns(message):
            response = self._invert_pronouns_text(response)

        self.curiosity.remember(message, context, response, metrics)
        return response

    # ---------- core composer (anchor- and metric-based) ----------

    def _craft_response(self, user_message: str, context: str) -> str:
        # Fallbacks
        if not context.strip():
            return self._format_sentence(self._collapse_adjacent_duplicates(user_message.strip()) or "Okay")

        seed = int(hashlib.sha256((user_message + "||" + context).encode("utf-8")).hexdigest(), 16)
        rng = random.Random(seed)

        sentences = self._split_sentences(context)
        candidates = self._extract_clause_candidates(sentences)

        if not candidates:
            # As a last resort, short echo from context cleaned
            return self._format_sentence(self._cleanup(" ".join(re.findall(r"\w+", context))[:120]))

        scored = []
        for text, tokens in candidates:
            s = self._score_clause(user_message, text, tokens)
            # slightly break ties deterministically
            s += rng.uniform(0.0, 0.01)
            scored.append((s, text, tokens))
        scored.sort(key=lambda x: x[0], reverse=True)

        # Pick top 1–2 clauses, join with dash/comma depending on length
        chosen_texts: List[str] = []
        total_words = 0
        for _, t, toks in scored:
            w = len(toks)
            if not chosen_texts:
                chosen_texts.append(t)
                total_words += w
            else:
                # Only add a second tiny clause if short and not redundant
                if 2 <= w <= 7 and total_words + w <= 22 and not self._redundant(chosen_texts[0], t):
                    chosen_texts.append(t)
                    break
            if total_words >= 20:
                break

        if not chosen_texts:
            chosen_texts = [scored[0][1]]

        text = self._join_with_punct(chosen_texts)
        text = self._cleanup(text)
        return self._format_sentence(text)

    # ---------- clause selection ----------

    def _split_sentences(self, text: str) -> List[str]:
        return [p.strip() for p in re.split(r"(?<=[.!?])\s+", text.strip()) if p.strip()]

    def _extract_clause_candidates(self, sentences: List[str]) -> List[Tuple[str, List[str]]]:
        out: List[Tuple[str, List[str]]] = []
        for s in sentences:
            # produce the sentence itself if reasonable
            toks = re.findall(r"\b\w+\b", s)
            wc = len(toks)
            if 6 <= wc <= 28:
                out.append((self._strip_terminal(s), toks))
            # split by commas and dashes into sub-clauses
            parts = re.split(r"\s*[,—–-]\s*", s)
            for p in parts:
                ptoks = re.findall(r"\b\w+\b", p)
                pw = len(ptoks)
                if 4 <= pw <= 14:
                    out.append((self._strip_terminal(p), ptoks))
        # Deduplicate by lowercase text
        seen = set()
        uniq = []
        for t, toks in out:
            key = t.lower()
            if key not in seen:
                seen.add(key)
                uniq.append((t, toks))
        return uniq

    def _strip_terminal(self, s: str) -> str:
        return re.sub(r"[.!?]+$", "", s.strip())

    def _redundant(self, a: str, b: str) -> bool:
        wa = set(re.findall(r"\w+", a.lower()))
        wb = set(re.findall(r"\w+", b.lower()))
        inter = wa & wb
        return len(inter) >= max(2, min(len(wa), len(wb)) // 2)

    def _score_clause(self, user_message: str, clause_text: str, clause_tokens: List[str]) -> float:
        # Token sets
        user_words_all = re.findall(r"\b\w+\b", user_message.lower())
        clause_words_all = [w.lower() for w in clause_tokens]
        user_content = [w for w in user_words_all if w not in STOPWORDS]
        clause_content = [w for w in clause_words_all if w not in STOPWORDS]

        # Overlap
        overlap = len(set(user_content) & set(clause_content))
        overlap_norm = overlap / max(1, len(set(user_content)))

        # Charged overlap (upper/long) from original user text
        charged_user = set(
            w.lower() for w in re.findall(r"\b\w+\b", user_message)
            if (any(c.isupper() for c in w) and len(w) > 1) or len(w) > 7
        )
        charged_overlap = len(charged_user & set(clause_content)) / max(1, len(charged_user)) if charged_user else 0.0

        # Order coherence via LCS on content words (cap length to keep O(n*m) small)
        a = user_content[:24]
        b = clause_content[:24]
        lcs = self._lcs_len(a, b)
        order = lcs / max(1, min(len(a), len(b)))

        # Length preference (sweet spot around 12 words)
        n = len(clause_tokens)
        length_score = 1.0 - (abs(12 - n) / 12.0)
        length_score = max(0.0, length_score)

        # Stopword ratio penalty
        stop_ratio = (len(clause_words_all) - len(clause_content)) / max(1, len(clause_words_all))

        # Comma penalty
        comma_pen = clause_text.count(",")

        score = (
            2.0 * overlap_norm +
            1.0 * charged_overlap +
            0.8 * order +
            0.3 * length_score -
            0.5 * stop_ratio -
            0.2 * comma_pen
        )
        return score

    def _lcs_len(self, a: List[str], b: List[str]) -> int:
        if not a or not b:
            return 0
        dp = [0] * (len(b) + 1)
        for i in range(1, len(a) + 1):
            prev = 0
            for j in range(1, len(b) + 1):
                tmp = dp[j]
                if a[i - 1] == b[j - 1]:
                    dp[j] = prev + 1
                else:
                    dp[j] = max(dp[j], dp[j - 1])
                prev = tmp
        return dp[-1]

    def _join_with_punct(self, clauses: List[str]) -> str:
        if not clauses:
            return ""
        if len(clauses) == 1:
            return clauses[0]
        # Two clauses: prefer em dash if second is short, else comma
        second_words = len(re.findall(r"\w+", clauses[1]))
        if second_words <= 6:
            return f"{clauses[0]} — {clauses[1]}"
        return f"{clauses[0]}, {clauses[1]}"

    # ---------- cleanup and punctuation ----------

    def _cleanup(self, text: str) -> str:
        text = self._strip_parentheticals(text)
        text = self._collapse_adjacent_duplicates(text)
        text = self._normalize_dashes(text)
        text = self._clean_commas(text)
        text = self._limit_commas(text, 1)
        text = re.sub(r"\s{2,}", " ", text).strip()
        return text

    def _format_sentence(self, text: str) -> str:
        text = text.strip()
        if not text:
            return ""
        # Capitalize first alpha char
        i = next((i for i, ch in enumerate(text) if ch.isalpha()), 0)
        text = text[:i] + text[i].upper() + text[i+1:]
        # Remove duplicate terminal punctuation and force period
        text = re.sub(r"([.!?])\1+$", r"\1", text)
        text = re.sub(r"[!?]+$", ".", text)
        if not re.search(r"[.!?]$", text):
            text += "."
        return text

    def _collapse_adjacent_duplicates(self, text: str) -> str:
        return re.sub(r"\b(\w+)(\s+\1\b)+", r"\1", text, flags=re.IGNORECASE)

    def _normalize_dashes(self, text: str) -> str:
        text = re.sub(r"\s*-\s*", " — ", text)
        text = re.sub(r"\s*—\s*", " — ", text)
        text = re.sub(r"\s+—\s+—\s+", " — ", text)
        return text

    def _clean_commas(self, text: str) -> str:
        def fix(m):
            before, word = m.group(1), m.group(2)
            if word.lower() in FORBID_COMMA_BEFORE:
                return before + " " + word
            return before + ", " + word
        text = re.sub(r"(\w)\s*,\s*(\w+)", fix, text)
        text = re.sub(r",\s+(and|or|but)\s*\.", r" \1.", text, flags=re.IGNORECASE)
        text = re.sub(r",\s*\.", ".", text)
        text = re.sub(r",\s*,+", ", ", text)
        return text

    def _limit_commas(self, text: str, k: int = 1) -> str:
        parts = text.split(",")
        if len(parts) - 1 <= k:
            return text
        return (parts[0] + ", " + " ".join(p.strip() for p in parts[1:])).strip()

    def _strip_parentheticals(self, text: str) -> str:
        text = re.sub(r"\s*\([^)]*\)", "", text)
        return re.sub(r"\s{2,}", " ", text).strip()

    # ---------- pronoun inversion ----------

    def _user_has_pronouns(self, text: str) -> bool:
        return any(w.lower() in _PRONOUN_MAP for w in re.findall(r"\w+", text))

    def _invert_pronouns_text(self, text: str) -> str:
        parts = re.findall(r"\w+|[^\w]+", text)
        out = []
        for p in parts:
            if re.fullmatch(r"\w+", p):
                low = p.lower()
                if low in _PRONOUN_MAP:
                    repl = _PRONOUN_MAP[low]
                    out.append(self._preserve_case(p, repl))
                else:
                    out.append(p)
            else:
                out.append(p)
        return "".join(out)

    def _preserve_case(self, src: str, repl: str) -> str:
        if src.isupper():
            return repl.upper()
        if src[0].isupper():
            return repl.capitalize()
        return repl.lower()
