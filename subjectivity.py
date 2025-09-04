import math
import re
import hashlib
import random
from typing import List, Tuple

from objectivity import Objectivity
from curiosity import Curiosity

# Стоп-слова для контентного пересечения
STOPWORDS = {
    "the","a","an","of","and","or","to","in","on","for","as","at","by","with","from",
    "is","are","was","were","be","been","being","this","that","it","its","into","than",
    "then","so","but","nor","if","because","while","when","where","which","who","whom"
}

# Запятая не должна стоять перед этими словами
FORBID_COMMA_BEFORE = {
    "is","are","was","were","am","be","been","being",
    "a","an","the","and","or","but","nor","of","to","in","on","for","as","at","by","with","from"
}

# Инверсия местоимений (как в me), регистр сохраняем
_PRONOUN_MAP = {
    "you": "i", "u": "i", "your": "my", "yours": "mine", "yourself": "myself", "yourselves": "ourselves",
    "i": "you", "me": "you", "my": "your", "mine": "yours", "myself": "yourself",
    "we": "you", "us": "you", "our": "your", "ours": "yours", "ourselves": "yourselves",
}

# Маркеры «справочности», которые нужно понижать
_DEF_MARKERS_SUBSTR = [
    " is a ", " is an ", " is the ",
    "notable people", "notable persons",
    "surname", "family name", "given name",
    "capital is", "is the capital",
    "programming language", "metropolitan areas",
    "population densities", "was born", "born in", "died in",
]

class Subjectivity:
    """Main module evaluating messages and crafting responses."""

    def __init__(self):
        self.objectivity = Objectivity()
        self.curiosity = Curiosity()
        self._last_norm: str = ""  # для анти‑повтора между репликами

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

        # Кандидаты (уже очищенные и с пунктуацией), отсортированы по убыванию score
        candidates = self._craft_candidates(message, context)

        # Выбираем первый, который не совпадает с прошлым выводом
        response = candidates[0] if candidates else ""
        for cand in candidates:
            if self._norm_repeat(cand) != self._last_norm:
                response = cand
                break

        # Инверсия местоимений — только если юзер их использовал
        if self._user_has_pronouns(message):
            response = self._invert_pronouns_text(response)

        # Обновляем анти‑повтор
        self._last_norm = self._norm_repeat(response)

        self.curiosity.remember(message, context, response, metrics)
        return response

    # ---------- core: build ranked candidates from the whole context window ----------

    def _craft_candidates(self, user_message: str, context: str) -> List[str]:
        if not context.strip():
            fallback = self._format_sentence(self._collapse_adjacent_duplicates(user_message.strip()) or "Okay")
            return [fallback]

        seed = int(hashlib.sha256((user_message + "||" + context).encode("utf-8")).hexdigest(), 16)
        rng = random.Random(seed)

        sentences = self._split_sentences(context)
        # Клаузные кандидаты: целые предложения и под‑клаузы из запятых/тире
        clauses = self._extract_clause_candidates(sentences)

        if not clauses:
            fallback = self._format_sentence(self._cleanup(" ".join(re.findall(r"\w+", context))[:120]))
            return [fallback]

        # Частоты контент‑слов по ОКНУ для «дообучаемости» на лету
        window_words = [w.lower() for w in re.findall(r"\b\w+\b", context)]
        window_content = [w for w in window_words if w not in STOPWORDS]
        freq = {}
        for w in window_content:
            freq[w] = freq.get(w, 0) + 1

        scored = []
        for text, toks in clauses:
            s = self._score_clause(user_message, text, toks, freq)
            s += rng.uniform(0.0, 0.01)  # детерминированный tie‑break
            scored.append((s, text, toks))

        scored.sort(key=lambda x: x[0], reverse=True)

        # Соберём финальные варианты:
        # 1) топ‑клаузу как отдельное предложение
        # 2) если есть короткая — сцепим топ1 — топ2
        out: List[str] = []

        if scored:
            top1_text, top1_toks = scored[0][1], scored[0][2]
            out.append(self._finalize(self._cleanup(top1_text)))

            # ищем короткий хвост для «—»
            tail = next((t for _, t, toks in scored[1:6] if 2 <= len(toks) <= 7 and not self._redundant(top1_text, t)), None)
            if tail:
                combo = f"{top1_text} — {self._strip_terminal(tail)}"
                out.append(self._finalize(self._cleanup(combo)))

        # Добавим ещё 1‑2 одиночных альтернативы (без сочетания), чтобы анти‑повтору было из чего выбирать
        for _, t, _ in scored[1:4]:
            out.append(self._finalize(self._cleanup(t)))

        # Уникализируем и вернём
        seen = set()
        uniq: List[str] = []
        for t in out:
            key = t.lower()
            if key not in seen:
                seen.add(key)
                uniq.append(t)
        return uniq or ["Okay."]

    # ---------- clause selection helpers ----------

    def _split_sentences(self, text: str) -> List[str]:
        return [p.strip() for p in re.split(r"(?<=[.!?])\s+", text.strip()) if p.strip()]

    def _extract_clause_candidates(self, sentences: List[str]) -> List[Tuple[str, List[str]]]:
        out: List[Tuple[str, List[str]]] = []
        for s in sentences:
            toks = re.findall(r"\b\w+\b", s)
            wc = len(toks)
            if 6 <= wc <= 28:
                out.append((self._strip_terminal(s), toks))
            # под‑клаузы через запятые/тире
            parts = re.split(r"\s*[,—–-]\s*", s)
            for p in parts:
                ptoks = re.findall(r"\b\w+\b", p)
                pw = len(ptoks)
                if 4 <= pw <= 14:
                    out.append((self._strip_terminal(p), ptoks))
        # Дедуп по lcase
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

    def _score_clause(self, user_message: str, clause_text: str, clause_tokens: List[str], window_freq: dict) -> float:
        # Подготовка множеств
        user_all = re.findall(r"\b\w+\b", user_message.lower())
        clause_all = [w.lower() for w in clause_tokens]
        user_content = [w for w in user_all if w not in STOPWORDS]
        clause_content = [w for w in clause_all if w not in STOPWORDS]

        # Пересечение содержательных токенов
        overlap = len(set(user_content) & set(clause_content))
        overlap_norm = overlap / max(1, len(set(user_content)))

        # «Заряженные» токены из пользовательского текста (капс/длина)
        charged_user = set(
            w.lower() for w in re.findall(r"\b\w+\b", user_message)
            if (any(c.isupper() for c in w) and len(w) > 1) or len(w) > 7
        )
        charged_overlap = (len(charged_user & set(clause_content)) / max(1, len(charged_user))) if charged_user else 0.0

        # Порядок (LCS) по контент‑словам
        a = user_content[:24]
        b = clause_content[:24]
        order = self._lcs_len(a, b) / max(1, min(len(a), len(b)))

        # Длина (sweet spot ~12 слов)
        n = len(clause_tokens)
        length_score = max(0.0, 1.0 - (abs(12 - n) / 12.0))

        # Плотность по окну (дообучаемость): суммарные частоты контент‑слов этой клаузы
        density = sum(window_freq.get(w, 0) for w in clause_content) / max(1, len(clause_content))

        # Штрафы
        stop_ratio = (len(clause_all) - len(clause_content)) / max(1, len(clause_all))
        commas = clause_text.count(",")
        def_pen = self._definitional_penalty(clause_text)

        # Итог
        score = (
            2.4 * overlap_norm +     # сильнее тянемся к словам юзера
            1.2 * charged_overlap +
            0.8 * order +
            0.35 * length_score +
            0.30 * density -
            0.35 * commas -
            0.50 * stop_ratio -
            1.10 * def_pen          # жестко давим «справочник»
        )
        return score

    def _definitional_penalty(self, text: str) -> float:
        t = " " + text.lower() + " "
        hits = sum(1 for m in _DEF_MARKERS_SUBSTR if m in t)
        # Усиливаем, если начинается с «ProperNoun is a/an/the …»
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

    # ---------- cleanup / punctuation ----------

    def _cleanup(self, text: str) -> str:
        text = self._strip_parentheticals(text)
        text = self._collapse_adjacent_duplicates(text)
        text = self._normalize_dashes(text)
        text = self._clean_commas(text)
        text = self._limit_commas(text, 1)
        text = re.sub(r"\s{2,}", " ", text).strip()
        return text

    def _finalize(self, text: str) -> str:
        text = text.strip()
        if not text:
            return ""
        # Капитализация первой буквы
        i = next((i for i, ch in enumerate(text) if ch.isalpha()), 0)
        text = text[:i] + text[i].upper() + text[i+1:]
        # Терминатор
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

    # ---------- pronouns and anti-repeat ----------

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

    def _norm_repeat(self, s: str) -> str:
        # Нормализуем для сравнения повторов между репликами
        return re.sub(r"[\W_]+", "", s).lower()
