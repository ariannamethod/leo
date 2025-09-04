import math
import re
import hashlib
import random
from collections import Counter, deque
from typing import List, Tuple

from objectivity import Objectivity
from curiosity import Curiosity

STOPWORDS = {
    "the","a","an","of","and","or","to","in","on","for","as","at","by","with","from",
    "is","are","was","were","be","been","being","this","that","it","its","into","than",
    "then","so","but","nor","if","because","while","when","where","which","who","whom"
}

FORBID_COMMA_BEFORE = {
    "is","are","was","were","am","be","been","being",
    "a","an","the","and","or","but","nor","of","to","in","on","for","as","at","by","with","from"
}

_PRONOUN_MAP = {
    "you": "i", "u": "i", "your": "my", "yours": "mine", "yourself": "myself", "yourselves": "ourselves",
    "i": "you", "me": "you", "my": "your", "mine": "yours", "myself": "yourself",
    "we": "you", "us": "you", "our": "your", "ours": "yours", "ourselves": "yourselves",
}

_DEF_MARKERS_SUBSTR = [
    " is a ", " is an ", " is the ", " was a ", " was an ",
    "notable people", "notable persons", "may refer to",
    "surname", "family name", "given name", "disambiguation",
    "capital is", "is the capital", "capital of",
    "programming language", "metropolitan areas",
    "population densities", "was born", "born in", "died in",
    "known for", "famous for", "best known",
]

class Subjectivity:
    """Main module evaluating messages and crafting responses."""

    def __init__(self):
        self.objectivity = Objectivity()
        self.curiosity = Curiosity()
        self._last_norms = deque(maxlen=4)

    # ---------- metrics ----------

    def _metrics(self, text: str):
        words = re.findall(r"\w+", text.lower())
        total = len(words) or 1
        counts = Counter(words)
        entropy = -sum((c / total) * math.log(c / total, 2) for c in counts.values())
        perplexity = 2 ** entropy
        resonance = sum(c for w, c in counts.items() if w.isalpha()) / total
        return {"perplexity": perplexity, "entropy": entropy, "resonance": resonance}

    def _charged_tokens(self, text: str) -> List[str]:
        tokens = re.findall(r"\b\w+\b", text)
        charged = [t for t in tokens if (t[:1].isupper() and len(t) > 1) or len(t) > 7]
        return charged or tokens[:3]

    # ---------- public ----------

    async def reply(self, message: str) -> str:
        metrics = self._metrics(message)
        tokens = self._charged_tokens(message)
        context = await self.objectivity.context_window(message, tokens)

        candidates = self._craft_candidates(message, context)

        seed = int(hashlib.sha256((message + "||" + context).encode("utf-8")).hexdigest(), 16)

        # Никаких шаблонов: если окно пустое/кандидатов нет — строим фразу из токенов пользователя (как в me)
        if not candidates:
            response = self._compose_from_user(message, seed=seed)
        else:
            # Берём первый, который не совпадает с последними
            response = candidates[0]
            for cand in candidates:
                if self._norm_repeat(cand) not in self._last_norms:
                    response = cand
                    break

        # Инверсия — только поверх уже собранной фразы
        if response and self._user_has_pronouns(message) and self._should_invert(response):
            response = self._invert_pronouns_text(response)

        self._last_norms.append(self._norm_repeat(response))
        self.curiosity.remember(message, context, response, metrics)
        return response

    # ---------- “me”-style composition when window is empty ----------

    def _compose_from_user(self, message: str, seed: int) -> str:
        rng = random.Random(seed)
        orig = message
        words = re.findall(r"\b\w+\b", orig)

        # преференция инвертированных местоимений (как в me.Engine._invert_pronouns)
        pref = [ _PRONOUN_MAP.get(w, w) for w in [w.lower() for w in words] ]
        pref = [p for p in pref if p not in {"the","a","an"}]

        # кандидаты: содержательные токены без стоп-слов, сначала «заряженные»
        charged_mask = [ (any(c.isupper() for c in w) and len(w)>1) or len(w)>7 for w in words ]
        content = [w.lower() for w in words if w.lower() not in STOPWORDS and len(w)>1]
        content_uniques = []
        seen = set()
        for i, w in enumerate(content):
            if w not in seen:
                seen.add(w)
                content_uniques.append((w, 2 if w in [lw for (lw, m) in zip([w for w in words], charged_mask) if m] else 1))
        # сортируем: заряженные выше, иначе по длине
        content_sorted = sorted(set(w for w,_ in content_uniques), key=lambda w: (-any(w==cw for cw,_ in content_uniques if _==2), -len(w)))

        # целевая длина (приближение той логики, что в me._lengths)
        target = self._target_len_from_metrics(orig)

        sent: List[str] = []
        used = set()

        # 1) добавим инвертированное местоимение, если уместно
        pronouns_core = {"i","you","we"}
        for p in pref:
            if p in pronouns_core and p not in used:
                sent.append(p)
                used.add(p)
                break

        # 2) добавим 1–2 заряженных токена
        for w in content_sorted:
            if len(sent) >= max(2, target//2):
                break
            if w not in used:
                sent.append(w)
                used.add(w)

        # 3) добираем случайной подвыборкой из контента
        pool = [w for w in content_sorted if w not in used]
        rng.shuffle(pool)
        for w in pool:
            if len(sent) >= target:
                break
            if w not in used and len(w) > 1:
                sent.append(w)
                used.add(w)

        # минимальные фильтры из me: без односимвольного конца, без подряд однобуквенных
        if sent and len(sent[-1]) == 1:
            sent = sent[:-1]
        clean: List[str] = []
        for w in sent:
            if clean and len(clean[-1]) == 1 and len(w) == 1:
                continue
            clean.append(w)

        if not clean:
            clean = [w.lower() for w in re.findall(r"\b\w+\b", orig)[:3]] or ["okay"]  # не шаблонный паттерн, это запасной источник токенов
        # финализация: капитализация и сохранение знака вопроса/восклицания из оригинала
        text = " ".join(clean).strip()
        if text:
            text = text[0].upper() + text[1:]
        end = "?"
        if "?" in orig:
            end = "?"
        elif "!" in orig:
            end = "!"
        else:
            end = "."
        text = self._cleanup(text)
        return self._finalize(text[:-1] if text.endswith(".") else text) if end in {"?","!"} else self._finalize(text)

    def _target_len_from_metrics(self, message: str) -> int:
        m = self._metrics(message)
        # 5..9 слов, слегка двигаем по перплексии/энтропии
        base = 7.0
        base += (m["perplexity"] - 5.0) * 0.1
        base += (m["entropy"] - 2.0) * 0.2
        n = int(round(max(5.0, min(9.0, base))))
        return n

    # ---------- candidates from window ----------

    def _craft_candidates(self, user_message: str, context: str) -> List[str]:
        context = (context or "").strip()
        if not context:
            return []

        seed = int(hashlib.sha256((user_message + "||" + context).encode("utf-8")).hexdigest(), 16)
        rng = random.Random(seed)

        sentences = self._split_sentences(context)
        clauses = self._extract_clause_candidates(sentences)
        if not clauses:
            return []

        window_words = [w.lower() for w in re.findall(r"\b\w+\b", context)]
        window_content = [w for w in window_words if w not in STOPWORDS]
        freq = {}
        for w in window_content:
            freq[w] = freq.get(w, 0) + 1

        scored = []
        for text, toks in clauses:
            s = self._score_clause(user_message, text, toks, freq)
            s += rng.uniform(0.0, 0.01)
            scored.append((s, text, toks))
        scored.sort(key=lambda x: x[0], reverse=True)

        out: List[str] = []
        if scored:
            t1 = scored[0][1]
            out.append(self._finalize(self._cleanup(t1)))
            for _, t2, k2 in scored[1:6]:
                if 3 <= len(k2) <= 9 and not self._redundant(t1, t2):
                    combo = f"{self._strip_terminal(t1)} — {self._strip_terminal(t2)}"
                    out.append(self._finalize(self._cleanup(combo)))
                    break

        for _, t, _ in scored[1:5]:
            out.append(self._finalize(self._cleanup(t)))

        seen = set()
        uniq = []
        for t in out:
            key = t.lower()
            if key not in seen:
                seen.add(key)
                uniq.append(t)
        return uniq

    # ---------- clause selection ----------

    def _split_sentences(self, text: str) -> List[str]:
        parts = re.split(r"(?<=[.!?])\s+|\n+", text.strip())
        return [p.strip() for p in parts if p.strip()]

    def _extract_clause_candidates(self, sentences: List[str]) -> List[Tuple[str, List[str]]]:
        out: List[Tuple[str, List[str]]] = []
        for s in sentences:
            toks = re.findall(r"\b\w+\b", s)
            wc = len(toks)
            if 7 <= wc <= 28 and not self._is_title_like(s):
                out.append((self._strip_terminal(s), toks))
            parts = re.split(r"\s*[,—–-]\s*", s)
            for p in parts:
                ptoks = re.findall(r"\b\w+\b", p)
                pw = len(ptoks)
                if 5 <= pw <= 14 and not self._is_title_like(p):
                    out.append((self._strip_terminal(p), ptoks))
        seen = set()
        uniq = []
        for t, toks in out:
            key = t.lower()
            if key not in seen:
                seen.add(key)
                uniq.append((t, toks))
        return uniq

    def _is_title_like(self, text: str) -> bool:
        words = re.findall(r"\b\w+\b", text)
        if not words:
            return True
        if len(words) <= 4 and sum(w[0].isupper() for w in words) >= len(words) - 1:
            if not any(w.lower() in {"is","are","was","were","has","have","do","does"} for w in words):
                return True
        return False

    def _strip_terminal(self, s: str) -> str:
        return re.sub(r"[.!?]+$", "", s.strip())

    def _redundant(self, a: str, b: str) -> bool:
        def norm(x: str) -> List[str]:
            return [w for w in re.findall(r"\w+", x.lower()) if w not in {"the","a","an"}]
        wa, wb = set(norm(a)), set(norm(b))
        inter = wa & wb
        return len(inter) >= max(2, min(len(wa), len(wb)) // 2)

    def _score_clause(self, user_message: str, clause_text: str, clause_tokens: List[str], window_freq: dict) -> float:
        user_all = re.findall(r"\b\w+\b", user_message.lower())
        clause_all = [w.lower() for w in clause_tokens]
        user_content = [w for w in user_all if w not in STOPWORDS]
        clause_content = [w for w in clause_all if w not in STOPWORDS]

        overlap = len(set(user_content) & set(clause_content))
        overlap_norm = overlap / max(1, len(set(user_content)))

        charged_user = set(
            w.lower() for w in re.findall(r"\b\w+\b", user_message)
            if (any(c.isupper() for c in w) and len(w) > 1) or len(w) > 7
        )
        charged_overlap = (len(charged_user & set(clause_content)) / max(1, len(charged_user))) if charged_user else 0.0

        a = user_content[:24]
        b = clause_content[:24]
        order = self._lcs_len(a, b) / max(1, min(len(a), len(b)))

        n = len(clause_tokens)
        length_score = max(0.0, 1.0 - (abs(12 - n) / 12.0))

        density = sum(window_freq.get(w, 0) for w in clause_content) / max(1, len(clause_content))

        dialog_bias = 1.0 if any(w in {"you","i","we"} for w in clause_content) else 0.0

        stop_ratio = (len(clause_all) - len(clause_content)) / max(1, len(clause_all))
        commas = clause_text.count(",")
        def_pen = self._definitional_penalty(clause_text)
        jacc = self._jaccard(set(user_content), set(clause_content))
        echo_pen = 1.0 if jacc >= 0.7 else (0.4 if jacc >= 0.5 else 0.0)
        digits_pen = 0.3 if sum(ch.isdigit() for ch in clause_text) >= 4 else 0.0

        score = (
            2.6 * overlap_norm +
            1.3 * charged_overlap +
            0.8  * order +
            0.35 * length_score +
            0.35 * density +
            0.35 * dialog_bias -
            0.45 * commas -
            0.55 * stop_ratio -
            1.20 * def_pen -
            0.90 * echo_pen -
            0.30 * digits_pen
        )
        return score

    def _jaccard(self, a: set, b: set) -> float:
        if not a and not b:
            return 0.0
        inter = len(a & b)
        union = len(a | b) or 1
        return inter / union

    def _definitional_penalty(self, text: str) -> float:
        t = " " + text.lower() + " "
        hits = sum(1 for m in _DEF_MARKERS_SUBSTR if m in t)
        starts_def = bool(re.match(r"^[A-Z][a-zA-Z\-]+(?: [A-Z][a-zA-Z\-]+)?\s+is\s+(?:a|an|the)\b", text))
        return hits * (1.0 if not starts_def else 1.6)

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

    # ---------- cleanup ----------

    def _cleanup(self, text: str) -> str:
        text = self._strip_parentheticals(text)
        text = self._collapse_adjacent_duplicates(text)
        text = self._normalize_dashes(text)
        text = self._clean_commas(text)
        text = self._dedup_phrases(text)
        text = self._limit_commas(text, 1)
        text = re.sub(r"\s{2,}", " ", text).strip()
        return text

    def _finalize(self, text: str) -> str:
        text = text.strip()
        if not text:
            return ""
        i = next((i for i, ch in enumerate(text) if ch.isalpha()), 0)
        text = text[:i] + text[i].upper() + text[i+1:]
        # если уже оканчивается на . ! ? — не трогаем
        if re.search(r"[.!?]$", text):
            return text
        return text + "."

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

    def _dedup_phrases(self, text: str) -> str:
        parts = re.split(r"\s*(?:—|,|;)\s*", self._strip_terminal(text))
        seen = set()
        out = []
        for p in parts:
            key = re.sub(r"^(the|a|an)\s+", "", p.strip(), flags=re.IGNORECASE).lower()
            if key and key not in seen:
                seen.add(key)
                out.append(p.strip())
        return ", ".join(out)

    def _limit_commas(self, text: str, k: int = 1) -> str:
        parts = text.split(",")
        if len(parts) - 1 <= k:
            return text
        return (parts[0] + ", " + " ".join(p.strip() for p in parts[1:])).strip()

    def _strip_parentheticals(self, text: str) -> str:
        text = re.sub(r"\s*\([^)]*\)", "", text)
        return re.sub(r"\s{2,}", " ", text).strip()

    # ---------- pronouns / repeat ----------

    def _user_has_pronouns(self, text: str) -> bool:
        return any(w.lower() in _PRONOUN_MAP for w in re.findall(r"\w+", text))

    def _should_invert(self, text: str) -> bool:
        """Decide if pronoun inversion would sound natural."""
        if any(pat in text.lower() for pat in ["what", "how", "why", "when", "where"]):
            return False
        if len(text.split()) < 3:
            return False
        return True

    def _invert_pronouns_text(self, text: str) -> str:
        # устойчивые пары, чтобы не было "How am YOU?"
        rules = [
            (r"\bare you\b", "am I"),  (r"\byou are\b", "I am"),
            (r"\bwere you\b", "was I"), (r"\byou were\b", "I was"),
            (r"\bhave you\b", "have I"), (r"\byou have\b", "I have"),
            (r"\bdo you\b", "do I"), (r"\byou do\b", "I do"),
            (r"\bcan you\b", "can I"), (r"\byou can\b", "I can"),
            (r"\bwill you\b", "will I"), (r"\byou will\b", "I will"),
            (r"\bwould you\b", "would I"), (r"\byou would\b", "I would"),
            (r"\bshould you\b", "should I"), (r"\byou should\b", "I should"),
            (r"\bdid you\b", "did I"), (r"\byou did\b", "I did"),
        ]
        def sub_case(m, repl):
            s = m.group(0)
            return repl[0].upper() + repl[1:] if s[0].isupper() else repl
        for pat, repl in rules:
            text = re.sub(pat, lambda m: sub_case(m, repl), text, flags=re.IGNORECASE)

        parts = re.findall(r"\w+|[^\w]+", text)
        out = []
        for p in parts:
            if re.fullmatch(r"\w+", p):
                low = p.lower()
                if low in _PRONOUN_MAP and low not in {"i", "me", "my", "mine", "myself", "we", "us", "our", "ours", "ourselves"}:
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

    def _norm_repeat(self, s: str) -> str:
        return re.sub(r"[\W_]+", "", s).lower()
