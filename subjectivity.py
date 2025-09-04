import math
import re
import hashlib
import random
from collections import deque
from typing import List, Tuple

from objectivity import Objectivity
from curiosity import Curiosity

STOPWORDS = {
“the”,“a”,“an”,“of”,“and”,“or”,“to”,“in”,“on”,“for”,“as”,“at”,“by”,“with”,“from”,
“is”,“are”,“was”,“were”,“be”,“been”,“being”,“this”,“that”,“it”,“its”,“into”,“than”,
“then”,“so”,“but”,“nor”,“if”,“because”,“while”,“when”,“where”,“which”,“who”,“whom”
}

FORBID_COMMA_BEFORE = {
“is”,“are”,“was”,“were”,“am”,“be”,“been”,“being”,
“a”,“an”,“the”,“and”,“or”,“but”,“nor”,“of”,“to”,“in”,“on”,“for”,“as”,“at”,“by”,“with”,“from”
}

_PRONOUN_MAP = {
“you”: “i”, “u”: “i”, “your”: “my”, “yours”: “mine”, “yourself”: “myself”, “yourselves”: “ourselves”,
“i”: “you”, “me”: “you”, “my”: “your”, “mine”: “yours”, “myself”: “yourself”,
“we”: “you”, “us”: “you”, “our”: “your”, “ours”: “yours”, “ourselves”: “yourselves”,
}

_DEF_MARKERS_SUBSTR = [
“ is a “, “ is an “, “ is the “, “ was a “, “ was an “,
“notable people”, “notable persons”, “may refer to”,
“surname”, “family name”, “given name”, “disambiguation”,
“capital is”, “is the capital”, “capital of”,
“programming language”, “metropolitan areas”,
“population densities”, “was born”, “born in”, “died in”,
“known for”, “famous for”, “best known”,
]

class Subjectivity:
“”“Main module evaluating messages and crafting responses.”””

```
def __init__(self):
    self.objectivity = Objectivity()
    self.curiosity = Curiosity()
    self._last_norms = deque(maxlen=4)

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

    candidates = self._craft_candidates(message, context)
    
    seed = int(hashlib.sha256((message + "||" + context).encode("utf-8")).hexdigest(), 16)

    # NO TEMPLATES: if window empty/no candidates — build from user tokens (me-style)
    if not candidates:
        response = self._compose_from_user(message, seed=seed)
    else:
        # Take first that doesn't repeat recent outputs
        response = candidates[0]
        for cand in candidates:
            if self._norm_repeat(cand) not in self._last_norms:
                response = cand
                break

    # Inversion — only AFTER we have a real composed phrase, and only if natural
    if response and self._user_has_pronouns(message) and self._should_invert(response):
        response = self._invert_pronouns_text(response)

    self._last_norms.append(self._norm_repeat(response))
    self.curiosity.remember(message, context, response, metrics)
    return response

# ---------- me-style composition when window is empty ----------

def _compose_from_user(self, message: str, seed: int) -> str:
    """Build reply from user tokens when no external context available. Pure me-style."""
    rng = random.Random(seed)
    words = [w.lower() for w in re.findall(r"\b\w+\b", message)]
    
    # Build candidates pool (like retrieve() fallback)
    candidates = [w for w in words if w not in STOPWORDS and len(w) > 1]
    if not candidates:
        candidates = words[:5] or ["hmm", "yes", "maybe", "really"]
    
    # Target length (simplified me._lengths logic)
    target_length = self._target_len_from_metrics(message)
    
    used: set = set()
    
    # Pronoun mapping (exact me style)  
    pronouns = {'you': 'i', 'u': 'i', 'i': 'you', 'me': 'you', 'we': 'you'}
    pronoun = next((pronouns[w] for w in words if w in pronouns), None)
    
    # me2me preference: try flipped-perspective tokens first
    pref = self._invert_pronouns(words)
    
    rng.shuffle(candidates)
    sent: List[str] = []
    
    # Add pronoun if found and not used
    if pronoun and pronoun not in used:
        sent.append(pronoun)
        used.add(pronoun)
        
    # Add preference tokens (me2me style)
    if pref:
        for w in pref:
            if len(sent) >= target_length:
                break
            if w in words or w in used:
                continue
            if len(w) == 1:
                continue
            sent.append(w)
            used.add(w)
    
    # Fill with candidates
    for w in candidates:
        if len(sent) >= target_length:
            break
        if w in words or w in used:
            continue
        if w == 'the' and len(sent) > 0:
            w = 'the'  # Keep me's quirky 'the' logic
        sent.append(w)
        used.add(w)
    
    # Fill to target length
    while len(sent) < target_length:
        choice = rng.choice(candidates) if candidates else 'hmm'
        if choice not in sent and choice not in words and choice not in used:
            sent.append(choice)
            used.add(choice)
    
    # me's end fix: single char at end becomes 'hmm'
    if sent and len(sent[-1]) == 1:
        sent[-1] = 'hmm'
    
    # Capitalization (me style)
    if sent:
        sent[0] = sent[0].capitalize()
    
    # Preserve original punctuation
    end_punct = "."
    if "?" in message:
        end_punct = "?"
    elif "!" in message:
        end_punct = "!"
        
    text = ' '.join(sent)
    return text + end_punct if text else "Hmm."

def _target_len_from_metrics(self, message: str) -> int:
    """Calculate target length based on message metrics."""
    m = self._metrics(message)
    # Base 5-9 words, adjust by perplexity/entropy
    base = 7.0
    base += (m["perplexity"] - 5.0) * 0.1
    base += (m["entropy"] - 2.0) * 0.2
    return int(round(max(5.0, min(9.0, base))))

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
    for text, tokens in clauses:
        score = self._score_clause(user_message, text, tokens, freq)
        score += rng.uniform(0.0, 0.01)  # tie-breaker
        scored.append((score, text, tokens))
        
    scored.sort(key=lambda x: x[0], reverse=True)

    candidates: List[str] = []
    if scored:
        best_text = scored[0][1]
        candidates.append(self._finalize(self._cleanup(best_text)))
        
        # Try combinations with other high-scoring clauses
        for _, text2, tokens2 in scored[1:6]:
            if 3 <= len(tokens2) <= 9 and not self._redundant(best_text, text2):
                combo = f"{self._strip_terminal(best_text)} — {self._strip_terminal(text2)}"
                candidates.append(self._finalize(self._cleanup(combo)))
                break

    # Add other top candidates
    for _, text, _ in scored[1:5]:
        candidates.append(self._finalize(self._cleanup(text)))

    # Remove duplicates
    seen = set()
    unique = []
    for text in candidates:
        key = text.lower()
        if key not in seen:
            seen.add(key)
            unique.append(text)
            
    return unique

# ---------- clause selection ----------

def _split_sentences(self, text: str) -> List[str]:
    parts = re.split(r"(?<=[.!?])\s+|\n+", text.strip())
    return [p.strip() for p in parts if p.strip()]

def _extract_clause_candidates(self, sentences: List[str]) -> List[Tuple[str, List[str]]]:
    candidates: List[Tuple[str, List[str]]] = []
    
    for sentence in sentences:
        tokens = re.findall(r"\b\w+\b", sentence)
        word_count = len(tokens)
        
        # Full sentences (if not too title-like)
        if 7 <= word_count <= 28 and not self._is_title_like(sentence):
            candidates.append((self._strip_terminal(sentence), tokens))
            
        # Sub-clauses split by punctuation
        parts = re.split(r"\s*[,—–-]\s*", sentence)
        for part in parts:
            part_tokens = re.findall(r"\b\w+\b", part)
            part_words = len(part_tokens)
            if 5 <= part_words <= 14 and not self._is_title_like(part):
                candidates.append((self._strip_terminal(part), part_tokens))

    # Remove duplicates
    seen = set()
    unique = []
    for text, tokens in candidates:
        key = text.lower()
        if key not in seen:
            seen.add(key)
            unique.append((text, tokens))
            
    return unique

def _is_title_like(self, text: str) -> bool:
    """Detect title-like text that should be avoided."""
    words = re.findall(r"\b\w+\b", text)
    if not words:
        return True
        
    # Short phrases with mostly caps (likely titles)
    if len(words) <= 4 and sum(w[0].isupper() for w in words) >= len(words) - 1:
        if not any(w.lower() in {"is", "are", "was", "were", "has", "have", "do", "does"} for w in words):
            return True
            
    return False

def _strip_terminal(self, text: str) -> str:
    return re.sub(r"[.!?]+$", "", text.strip())

def _redundant(self, text1: str, text2: str) -> bool:
    """Check if two texts are too similar."""
    def normalize(text: str) -> List[str]:
        return [w for w in re.findall(r"\w+", text.lower()) if w not in {"the", "a", "an"}]
        
    words1, words2 = set(normalize(text1)), set(normalize(text2))
    intersection = words1 & words2
    return len(intersection) >= max(2, min(len(words1), len(words2)) // 2)

def _score_clause(self, user_message: str, clause_text: str, clause_tokens: List[str], window_freq: dict) -> float:
    """Score clause relevance for smalltalk (anti-glossary, pro-dialog)."""
    user_all = re.findall(r"\b\w+\b", user_message.lower())
    clause_all = [w.lower() for w in clause_tokens]
    user_content = [w for w in user_all if w not in STOPWORDS]
    clause_content = [w for w in clause_all if w not in STOPWORDS]

    # Content word overlap
    overlap = len(set(user_content) & set(clause_content))
    overlap_norm = overlap / max(1, len(set(user_content)))

    # Charged token overlap (capitalized or long words)
    charged_user = set(
        w.lower() for w in re.findall(r"\b\w+\b", user_message)
        if (any(c.isupper() for c in w) and len(w) > 1) or len(w) > 7
    )
    charged_overlap = (len(charged_user & set(clause_content)) / max(1, len(charged_user))) if charged_user else 0.0

    # Word order preservation
    user_seq = user_content[:24]
    clause_seq = clause_content[:24]
    order_score = self._lcs_len(user_seq, clause_seq) / max(1, min(len(user_seq), len(clause_seq)))

    # Length preference (moderate length is better)
    token_count = len(clause_tokens)
    length_score = max(0.0, 1.0 - (abs(12 - token_count) / 12.0))

    # Window frequency (how common these words are in context)
    density = sum(window_freq.get(w, 0) for w in clause_content) / max(1, len(clause_content))

    # Dialog bias (prefer conversational pronouns)
    dialog_bias = 1.0 if any(w in {"you", "i", "we"} for w in clause_content) else 0.0

    # Penalties
    stop_ratio = (len(clause_all) - len(clause_content)) / max(1, len(clause_all))
    comma_count = clause_text.count(",")
    definition_penalty = self._definitional_penalty(clause_text)
    
    # Anti-echo penalty (too similar to user input)
    jaccard = self._jaccard(set(user_content), set(clause_content))
    echo_penalty = 1.0 if jaccard >= 0.7 else (0.4 if jaccard >= 0.5 else 0.0)
    
    # Numbers/dates penalty (factual-looking)
    digits_penalty = 0.3 if sum(ch.isdigit() for ch in clause_text) >= 4 else 0.0

    # Combine scores
    score = (
        2.6 * overlap_norm +
        1.3 * charged_overlap +
        0.8 * order_score +
        0.35 * length_score +
        0.35 * density +
        0.35 * dialog_bias -
        0.45 * comma_count -
        0.55 * stop_ratio -
        1.20 * definition_penalty -
        0.90 * echo_penalty -
        0.30 * digits_penalty
    )
    
    return score

def _jaccard(self, set1: set, set2: set) -> float:
    """Jaccard similarity between two sets."""
    if not set1 and not set2:
        return 0.0
    intersection = len(set1 & set2)
    union = len(set1 | set2) or 1
    return intersection / union

def _definitional_penalty(self, text: str) -> float:
    """Penalty for definition-like text."""
    text_padded = " " + text.lower() + " "
    hits = sum(1 for marker in _DEF_MARKERS_SUBSTR if marker in text_padded)
    
    # Extra penalty for classic definition patterns
    starts_definition = bool(re.match(r"^[A-Z][a-zA-Z\-]+(?: [A-Z][a-zA-Z\-]+)?\s+is\s+(?:a|an|the)\b", text))
    return hits * (1.6 if starts_definition else 1.0)

def _lcs_len(self, seq1: List[str], seq2: List[str]) -> int:
    """Longest common subsequence length."""
    if not seq1 or not seq2:
        return 0
        
    dp = [0] * (len(seq2) + 1)
    for i in range(1, len(seq1) + 1):
        prev = 0
        for j in range(1, len(seq2) + 1):
            temp = dp[j]
            if seq1[i - 1] == seq2[j - 1]:
                dp[j] = prev + 1
            else:
                dp[j] = max(dp[j], dp[j - 1])
            prev = temp
    return dp[-1]

# ---------- cleanup ----------

def _cleanup(self, text: str) -> str:
    """Clean up text while preserving conversational flow."""
    text = self._strip_parentheticals(text)
    text = self._collapse_adjacent_duplicates(text)
    text = self._normalize_dashes(text)
    text = self._clean_commas(text)
    text = self._dedup_phrases(text)
    text = self._limit_commas(text, 1)
    text = re.sub(r"\s{2,}", " ", text).strip()
    return text

def _finalize(self, text: str, end_punct: str = ".") -> str:
    """Finalize text with proper capitalization and punctuation."""
    text = text.strip()
    if not text:
        return ""
        
    # Capitalize first letter
    first_alpha = next((i for i, ch in enumerate(text) if ch.isalpha()), 0)
    if first_alpha < len(text):
        text = text[:first_alpha] + text[first_alpha].upper() + text[first_alpha+1:]
    
    # Handle punctuation
    if re.search(r"[.!?]$", text):
        return text
    return text + end_punct

def _collapse_adjacent_duplicates(self, text: str) -> str:
    return re.sub(r"\b(\w+)(\s+\1\b)+", r"\1", text, flags=re.IGNORECASE)

def _normalize_dashes(self, text: str) -> str:
    text = re.sub(r"\s*-\s*", " — ", text)
    text = re.sub(r"\s*—\s*", " — ", text)
    text = re.sub(r"\s+—\s+—\s+", " — ", text)
    return text

def _clean_commas(self, text: str) -> str:
    def fix_comma(match):
        before, word = match.group(1), match.group(2)
        if word.lower() in FORBID_COMMA_BEFORE:
            return before + " " + word
        return before + ", " + word
        
    text = re.sub(r"(\w)\s*,\s*(\w+)", fix_comma, text)
    text = re.sub(r",\s+(and|or|but)\s*\.", r" \1.", text, flags=re.IGNORECASE)
    text = re.sub(r",\s*\.", ".", text)
    text = re.sub(r",\s*,+", ", ", text)
    return text

def _dedup_phrases(self, text: str) -> str:
    """Remove duplicate phrases."""
    parts = re.split(r"\s*(?:—|,|;)\s*", self._strip_terminal(text))
    seen = set()
    unique_parts = []
    
    for part in parts:
        # Normalize for comparison (remove articles)
        key = re.sub(r"^(the|a|an)\s+", "", part.strip(), flags=re.IGNORECASE).lower()
        if key and key not in seen:
            seen.add(key)
            unique_parts.append(part.strip())
            
    return ", ".join(unique_parts)

def _limit_commas(self, text: str, max_commas: int = 1) -> str:
    """Limit number of commas in text."""
    parts = text.split(",")
    if len(parts) - 1 <= max_commas:
        return text
    return (parts[0] + ", " + " ".join(p.strip() for p in parts[1:])).strip()

def _strip_parentheticals(self, text: str) -> str:
    text = re.sub(r"\s*\([^)]*\)", "", text)
    return re.sub(r"\s{2,}", " ", text).strip()

# ---------- pronoun inversion ----------

def _user_has_pronouns(self, text: str) -> bool:
    return any(w.lower() in _PRONOUN_MAP for w in re.findall(r"\w+", text))

def _should_invert(self, text: str) -> bool:
    """Decide if pronoun inversion would sound natural."""
    # Don't invert if already sounds like a question or statement
    if any(pattern in text.lower() for pattern in ["what", "how", "why", "when", "where"]):
        return False
    # Don't invert very short responses
    if len(text.split()) < 3:
        return False
    return True

def _invert_pronouns_text(self, text: str) -> str:
    """Carefully invert pronouns while preserving grammar."""
    # Handle common patterns first
    patterns = [
        (r"\bare you\b", "am I"), (r"\byou are\b", "I am"),
        (r"\bwere you\b", "was I"), (r"\byou were\b", "I was"),
        (r"\bhave you\b", "have I"), (r"\byou have\b", "I have"),
        (r"\bdo you\b", "do I"), (r"\byou do\b", "I do"),
        (r"\bcan you\b", "can I"), (r"\byou can\b", "I can"),
        (r"\bwill you\b", "will I"), (r"\byou will\b", "I will"),
        (r"\bwould you\b", "would I"), (r"\byou would\b", "I would"),
        (r"\bshould you\b", "should I"), (r"\byou should\b", "I should"),
        (r"\bdid you\b", "did I"), (r"\byou did\b", "I did"),
    ]
    
    def preserve_case(match, replacement):
        original = match.group(0)
        return replacement[0].upper() + replacement[1:] if original[0].isupper() else replacement
        
    for pattern, replacement in patterns:
        text = re.sub(pattern, lambda m: preserve_case(m, replacement), text, flags=re.IGNORECASE)

    # Handle remaining individual pronouns
    tokens = re.findall(r"\w+|[^\w]+", text)
    result = []
    
    for token in tokens:
        if re.fullmatch(r"\w+", token):
            lower = token.lower()
            if lower in _PRONOUN_MAP:
                replacement = _PRONOUN_MAP[lower]
                result.append(self._preserve_case(token, replacement))
            else:
                result.append(token)
        else:
            result.append(token)
            
    return "".join(result)

def _preserve_case(self, original: str, replacement: str) -> str:
    """Preserve the case pattern of original in replacement."""
    if original.isupper():
        return replacement.upper()
    elif original[0].isupper():
        return replacement.capitalize()
    else:
        return replacement.lower()

def _norm_repeat(self, text: str) -> str:
    """Normalize text for repetition detection."""
    return re.sub(r"[\W_]+", "", text).lower()