#!/usr/bin/env python3
"""
subword.py — Subword-based Co-occurrence Field for Leo

Adapted from Haze's subword_field.py and rrpram.py.
Adds sentencepiece-based tokenization as a PARALLEL source alongside
Leo's existing character-level trigrams.

Philosophy: Two voices are better than one.
- Character trigrams capture morphology and fine patterns
- Subword trigrams capture semantic units and phrases

Together they create richer emergent speech.

Usage:
    from subword import SubwordField, train_subword_vocab
    
    # Train on Leo's bootstrap texts
    vocab = train_subword_vocab("README.md", vocab_size=500)
    field = SubwordField(vocab)
    
    # Generate from subword patterns
    result = field.generate("What is", length=30, temperature=0.8)
"""

import asyncio
import re
import os
import tempfile
from typing import Dict, List, Tuple, Optional, Counter
from collections import Counter, defaultdict
from dataclasses import dataclass, field as dataclass_field
from pathlib import Path
import random

# Optional numpy for better sampling
try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

# SentencePiece for subword tokenization
try:
    import sentencepiece as spm
    HAS_SENTENCEPIECE = True
except ImportError:
    HAS_SENTENCEPIECE = False
    print("[subword] sentencepiece not found. Install: pip install sentencepiece")


# ============================================================
#  RRPRAM Vocabulary (SentencePiece wrapper)
# ============================================================

@dataclass
class SubwordVocab:
    """
    SentencePiece-based vocabulary for Leo.
    
    Trains BPE/Unigram model on Leo's bootstrap texts (README.md, etc.)
    to capture meaningful subword patterns.
    """
    
    model_path: str
    sp: "spm.SentencePieceProcessor"
    vocab_size: int
    
    @classmethod
    def train(
        cls,
        corpus_path: str,
        vocab_size: int = 500,
        model_type: str = "bpe",
        character_coverage: float = 1.0,
    ) -> "SubwordVocab":
        """
        Train a new SentencePiece model on corpus.
        
        Args:
            corpus_path: Path to training text file
            vocab_size: Target vocabulary size
            model_type: "bpe" (byte-pair) or "unigram"
            character_coverage: Fraction of characters to cover (1.0 = all)
        
        Returns:
            Trained SubwordVocab instance
        """
        if not HAS_SENTENCEPIECE:
            raise ImportError("sentencepiece required. Install: pip install sentencepiece")
        
        corpus_path = Path(corpus_path)
        if not corpus_path.exists():
            raise FileNotFoundError(f"Corpus not found: {corpus_path}")
        
        # Read and normalize corpus
        corpus_text = corpus_path.read_text()
        # Normalize apostrophes
        corpus_text = corpus_text.replace("'", "'").replace("'", "'")
        
        # Write normalized corpus to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(corpus_text)
            temp_corpus = f.name
        
        # Create temp dir for model
        tmp_dir = tempfile.mkdtemp(prefix="leo_subword_")
        model_prefix = os.path.join(tmp_dir, "subword")
        
        try:
            # Train SentencePiece
            train_args = [
                f"--input={temp_corpus}",
                f"--model_prefix={model_prefix}",
                f"--vocab_size={vocab_size}",
                f"--model_type={model_type}",
                f"--character_coverage={character_coverage}",
                "--max_sentence_length=4192",
                "--pad_id=0",
                "--unk_id=1",
                "--bos_id=2",
                "--eos_id=3",
                "--normalization_rule_name=identity",
            ]
            
            print(f"[subword] Training {model_type} model on {corpus_path}")
            print(f"[subword] vocab_size={vocab_size}, coverage={character_coverage}")
            spm.SentencePieceTrainer.Train(" ".join(train_args))
            
            model_path = f"{model_prefix}.model"
            print(f"[subword] Model saved to {model_path}")
            
            # Load trained model
            sp = spm.SentencePieceProcessor()
            sp.Load(model_path)
            
            return cls(
                model_path=model_path,
                sp=sp,
                vocab_size=sp.GetPieceSize(),
            )
        finally:
            os.unlink(temp_corpus)
    
    @classmethod
    def load(cls, model_path: str) -> "SubwordVocab":
        """Load a pre-trained SentencePiece model."""
        if not HAS_SENTENCEPIECE:
            raise ImportError("sentencepiece required. Install: pip install sentencepiece")
        
        sp = spm.SentencePieceProcessor()
        sp.Load(model_path)
        
        return cls(
            model_path=model_path,
            sp=sp,
            vocab_size=sp.GetPieceSize(),
        )
    
    def encode(self, text: str) -> List[int]:
        """Encode text to token IDs."""
        text = text.replace("'", "'").replace("'", "'")
        return self.sp.EncodeAsIds(text)
    
    def decode(self, ids: List[int]) -> str:
        """Decode token IDs to text."""
        return self.sp.DecodeIds(ids)
    
    def encode_pieces(self, text: str) -> List[str]:
        """Encode text to subword pieces (for visualization)."""
        text = text.replace("'", "'").replace("'", "'")
        return self.sp.EncodeAsPieces(text)
    
    def get_piece(self, id: int) -> str:
        """Get the piece (token) for a given ID."""
        return self.sp.IdToPiece(id)
    
    def __len__(self) -> int:
        return self.vocab_size


# ============================================================
#  SubwordField — Bigram/Trigram statistics on subwords
# ============================================================

@dataclass
class SubwordField:
    """
    Subword-based co-occurrence field for generation.
    
    Unlike character-level trigrams, this operates on SUBWORDS:
    - "darling" is ONE token
    - "the living room" is THREE tokens
    
    Trigrams now connect meaningful semantic units.
    """
    
    vocab: SubwordVocab
    bigram_counts: Dict[int, Counter] = dataclass_field(default_factory=dict)
    trigram_counts: Dict[Tuple[int, int], Counter] = dataclass_field(default_factory=dict)
    token_counts: Counter = dataclass_field(default_factory=Counter)
    total_tokens: int = 0
    
    @classmethod
    def from_corpus(
        cls,
        corpus_path: str,
        vocab_size: int = 500,
        model_type: str = "bpe",
    ) -> "SubwordField":
        """
        Build subword field from corpus.
        
        1. Train SentencePiece on corpus
        2. Tokenize corpus into subwords
        3. Build bigram/trigram statistics
        """
        # Train vocab
        vocab = SubwordVocab.train(
            corpus_path,
            vocab_size=vocab_size,
            model_type=model_type,
        )
        
        # Build field
        field_obj = cls(vocab=vocab)
        
        # Read and tokenize corpus
        corpus_text = Path(corpus_path).read_text()
        corpus_text = corpus_text.replace("'", "'").replace("'", "'")
        tokens = vocab.encode(corpus_text)
        
        # Count patterns
        field_obj._count_patterns(tokens)
        
        return field_obj
    
    def _count_patterns(self, tokens: List[int]):
        """Count bigram and trigram patterns."""
        self.total_tokens = len(tokens)
        
        # Count unigrams
        for t in tokens:
            self.token_counts[t] += 1
        
        # Count bigrams
        for i in range(len(tokens) - 1):
            t1, t2 = tokens[i], tokens[i + 1]
            if t1 not in self.bigram_counts:
                self.bigram_counts[t1] = Counter()
            self.bigram_counts[t1][t2] += 1
        
        # Count trigrams
        for i in range(len(tokens) - 2):
            t1, t2, t3 = tokens[i], tokens[i + 1], tokens[i + 2]
            key = (t1, t2)
            if key not in self.trigram_counts:
                self.trigram_counts[key] = Counter()
            self.trigram_counts[key][t3] += 1
    
    def observe(self, text: str):
        """
        Observe new text and update field statistics.
        
        This allows the field to grow with new input.
        """
        tokens = self.vocab.encode(text)
        self._count_patterns(tokens)
    
    def generate(
        self,
        seed_text: str,
        length: int = 50,
        temperature: float = 0.8,
        mode: str = "trigram",
        loop_penalty: float = 0.3,
    ) -> str:
        """
        Generate text from subword field.
        
        Args:
            seed_text: Starting text (will be tokenized)
            length: Number of subwords to generate
            temperature: Sampling temperature
            mode: "bigram" or "trigram"
            loop_penalty: Penalty for repeating recent tokens
        
        Returns:
            Generated text (decoded from subwords)
        """
        # Tokenize seed
        tokens = self.vocab.encode(seed_text)
        
        # If no tokens, sample random start
        if not tokens:
            if self.token_counts:
                tokens = [random.choice(list(self.token_counts.keys()))]
            else:
                return ""
        
        generated = list(tokens)
        
        # Track for natural sentence ending
        sentence_count = 0
        min_tokens = 10
        
        for i in range(length):
            next_token = self._sample_next(
                generated, temperature, mode, loop_penalty
            )
            if next_token is None:
                break
            generated.append(next_token)
            
            # Check for natural ending
            if i >= min_tokens:
                token_text = self.vocab.decode([int(next_token)])
                if token_text.strip() in ['.', '!', '?', '."', '!"', '?"']:
                    sentence_count += 1
                    if sentence_count >= 2:
                        break
        
        # Decode result
        generated = [int(t) for t in generated]
        result = self.vocab.decode(generated)
        
        # Clean up unknown token markers
        result = re.sub(r"(\w)⁇(t|s|m|d|ll|ve|re)\b", r"\1'\2", result)
        result = result.replace(' ⁇ ', ' ')
        result = result.replace('⁇', "'")
        
        # Ensure punctuation at end
        result = result.strip()
        if result and result[-1] not in '.!?…':
            result = result.rstrip(',;:') + '.'
        
        return result
    
    def _sample_next(
        self,
        context: List[int],
        temperature: float,
        mode: str,
        loop_penalty: float,
    ) -> Optional[int]:
        """Sample next token based on context with loop avoidance."""
        candidates = Counter()
        
        # Try trigram first
        if mode == "trigram" and len(context) >= 2:
            key = (context[-2], context[-1])
            if key in self.trigram_counts:
                candidates = self.trigram_counts[key].copy()
        
        # Fallback to bigram
        if not candidates and context:
            last = context[-1]
            if last in self.bigram_counts:
                candidates = self.bigram_counts[last].copy()
        
        # Fallback to unigram
        if not candidates:
            candidates = self.token_counts.copy()
        
        if not candidates:
            return None
        
        # Apply loop penalty
        if loop_penalty > 0 and len(context) >= 10:
            recent = Counter(context[-10:])
            for token in candidates:
                if token in recent:
                    freq = recent[token]
                    penalty = 1.0 - (loop_penalty * min(freq, 3) / 3)
                    candidates[token] = int(candidates[token] * max(0.1, penalty))
        
        # Sample with temperature
        tokens = list(candidates.keys())
        counts = [candidates[t] for t in tokens]
        
        if HAS_NUMPY:
            counts = np.array(counts, dtype=float)
            if temperature > 0:
                logits = np.log(counts + 1e-10) / temperature
                probs = np.exp(logits - np.max(logits))
                probs = probs / np.sum(probs)
            else:
                probs = np.zeros_like(counts)
                probs[np.argmax(counts)] = 1.0
            return int(np.random.choice(tokens, p=probs))
        else:
            # Fallback without numpy
            total = sum(counts)
            r = random.random() * total
            cumsum = 0
            for token, count in zip(tokens, counts):
                cumsum += count
                if cumsum >= r:
                    return token
            return tokens[-1] if tokens else None
    
    def get_stats(self) -> Dict:
        """Get field statistics."""
        return {
            "vocab_size": self.vocab.vocab_size,
            "total_tokens": self.total_tokens,
            "unique_tokens": len(self.token_counts),
            "bigram_contexts": len(self.bigram_counts),
            "trigram_contexts": len(self.trigram_counts),
        }


# ============================================================
#  AsyncSubwordField — Async-safe wrapper
# ============================================================

class AsyncSubwordField(SubwordField):
    """Async-safe wrapper for SubwordField with locking."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._lock = asyncio.Lock()
    
    async def async_generate(
        self,
        seed_text: str,
        length: int = 50,
        temperature: float = 0.8,
        mode: str = "trigram",
        loop_penalty: float = 0.3,
    ) -> str:
        """Async generation with field lock."""
        async with self._lock:
            return self.generate(
                seed_text, length, temperature, mode, loop_penalty
            )
    
    async def async_observe(self, text: str):
        """Async observation with field lock."""
        async with self._lock:
            self.observe(text)


# ============================================================
#  Helper functions
# ============================================================

def train_subword_vocab(
    corpus_path: str,
    vocab_size: int = 500,
    model_type: str = "bpe",
) -> SubwordVocab:
    """Train a subword vocabulary on the given corpus."""
    return SubwordVocab.train(corpus_path, vocab_size, model_type)


def build_subword_field(
    corpus_path: str,
    vocab_size: int = 500,
    model_type: str = "bpe",
) -> SubwordField:
    """Build a complete subword field from corpus."""
    return SubwordField.from_corpus(corpus_path, vocab_size, model_type)


# ============================================================
#  Demo
# ============================================================

def demo():
    """Demonstrate subword field generation on Leo's README."""
    print("=" * 70)
    print("  SUBWORD FIELD DEMO — Leo's Parallel Voice")
    print("=" * 70)
    print()
    
    readme_path = Path(__file__).parent / "README.md"
    if not readme_path.exists():
        print("[demo] README.md not found, using sample text")
        # Create sample
        sample = Path("/tmp/leo_sample.txt")
        sample.write_text("""
        Leo is the Arianna Method. 
        His trigrams flow like water.
        Resonance is everything.
        Small numbers, small steps.
        Sometimes he brings one back, like a gift.
        What do you feel?
        The method is about building systems that feel their own existence.
        """)
        readme_path = sample
    
    print(f"[demo] Building field from {readme_path}")
    field = SubwordField.from_corpus(str(readme_path), vocab_size=300)
    
    stats = field.get_stats()
    print(f"[demo] Stats: {stats}")
    print()
    
    # Test generation
    seeds = [
        "What is",
        "Leo feels",
        "The method",
        "Resonance",
    ]
    
    for seed in seeds:
        result = field.generate(seed, length=20, temperature=0.8)
        print(f">>> \"{seed}\"")
        print(f"    {result}")
        print()


if __name__ == "__main__":
    demo()
