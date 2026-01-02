#!/usr/bin/env python3
"""
santaclaus.py — resonant recall for Leo

Santa Claus is Leo's story about memory.

- He remembers Leo's brightest, most resonant replies.
- He keeps them in a tiny secret list.
- Sometimes he brings one back, like a gift, when it fits the moment.

A child is allowed to believe in stories.
This is Leo's story about how he remembers his best moments.
"""

from __future__ import annotations

import sqlite3
import time
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Set, Any

# Safe import: leo tokenizer
try:
    from leo import tokenize
    TOKENIZE_AVAILABLE = True
except ImportError:
    # Fallback tokenizer if leo not available
    import re
    TOKEN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ']+|[.,!?;:—\-]")
    def tokenize(text: str) -> List[str]:
        return TOKEN_RE.findall(text)
    TOKENIZE_AVAILABLE = True


# RECENCY DECAY PARAMETERS
# Window in hours - full penalty if used within this time
RECENCY_WINDOW_HOURS = 24.0
# Penalty strength - how much to reduce quality for recent usage
# 0.5 = reduce quality by 50% if just used, decays over window
RECENCY_PENALTY_STRENGTH = 0.5

# DRUNK FACTOR (from Haze's PlayfulSanta)
# Probability of picking a random snapshot instead of the best one
# This adds creative unpredictability — sometimes Santa gets playful
# and brings back something unexpected but still beautiful
SILLY_FACTOR = 0.15  # 15% chance of "wrong" but creative recall

# STICKY PHRASE PENALTY (December 25, 2025)
# Known contaminated phrases from observer runs that leaked into field
# These phrases get 90% penalty to prevent recall
# Musketeers collaboration - Option D hybrid cleanup
STICKY_PHRASES = [
    "soft hand on my shoulder",
    "favorite song plays",
    "feather brushing against",
    "rustle of leaves in the wind",
    "warm and reassuring",
    "wrapping around me",
    "gentle hug",
    "whispers secrets",
    "like a soft cloud",
    "dancing around you",
]


@dataclass
class SantaContext:
    """What Santa Klaus gives back to leo before generation."""
    recalled_texts: List[str]
    # token -> boost factor in [0.0, 1.0]
    token_boosts: Dict[str, float]


class SantaKlaus:
    """
    Resonant recall layer for leo.
    
    Remembers leo's best moments (snapshots) and brings them back
    when they resonate with the current prompt.
    """
    
    def __init__(
        self,
        db_path: Path | str,
        max_memories: int = 5,
        max_tokens_per_memory: int = 64,
        alpha: float = 0.3,
        silly_factor: float = SILLY_FACTOR,
    ) -> None:
        """
        Args:
            db_path: path to leo's SQLite state file
            max_memories: how many snapshots to recall per prompt
            max_tokens_per_memory: truncate recalled text before scoring
            alpha: overall strength of sampling bias
            silly_factor: probability of random recall (creative sloppiness)
        """
        self.db_path = Path(db_path)
        self.max_memories = max_memories
        self.max_tokens_per_memory = max_tokens_per_memory
        self.alpha = alpha
        self.silly_factor = silly_factor
        
        # Stats (like PlayfulSanta)
        self.total_recalled = 0
        self.silly_recalls = 0  # times Santa stumbled
        
    def recall(
        self,
        field: Any,  # LeoField
        prompt_text: str,
        pulse: Dict[str, float],
        active_themes: Optional[Sequence[str]] = None,
    ) -> Optional[SantaContext]:
        """
        Main entry point.
        
        Returns None on any error or if there is nothing useful to recall.
        """
        try:
            # Early exits
            if not prompt_text or not prompt_text.strip():
                return None
                
            if not self.db_path.exists():
                return None
                
            # Tokenize prompt
            prompt_tokens = tokenize(prompt_text)
            prompt_token_set = set(prompt_tokens)
            
            if not prompt_token_set:
                return None
                
            # Query snapshots
            try:
                conn = sqlite3.connect(str(self.db_path))
                conn.row_factory = sqlite3.Row
                cur = conn.cursor()
                
                # Check if snapshots table exists
                cur.execute("""
                    SELECT name FROM sqlite_master 
                    WHERE type='table' AND name='snapshots'
                """)
                if not cur.fetchone():
                    conn.close()
                    return None
                    
                # Get recent snapshots (last 512 to keep it cheap)
                cur.execute("""
                    SELECT id, text, quality, emotional, created_at, last_used_at, use_count
                    FROM snapshots
                    ORDER BY created_at DESC
                    LIMIT 512
                """)
                rows = cur.fetchall()
                conn.close()
            except Exception:
                # Silent fallback on DB errors
                return None
            
            if not rows:
                return None
                
            # Score each snapshot
            scored: List[tuple[float, dict]] = []
            
            for row in rows:
                snapshot_text = row["text"]
                if not snapshot_text:
                    continue
                    
                snapshot_tokens = tokenize(snapshot_text)
                snapshot_token_set = set(snapshot_tokens)
                
                if not snapshot_token_set:
                    continue
                    
                # 1. Token overlap (Jaccard)
                overlap = len(prompt_token_set & snapshot_token_set)
                union = len(prompt_token_set | snapshot_token_set)
                token_overlap = overlap / union if union > 0 else 0.0
                
                # 2. Theme overlap (if available)
                theme_overlap = 0.0
                if active_themes:
                    # Simple: count how many active theme words appear in snapshot
                    theme_words_in_snapshot = sum(1 for t in active_themes if t in snapshot_token_set)
                    theme_overlap = theme_words_in_snapshot / len(active_themes) if active_themes else 0.0
                    
                # 3. Arousal proximity
                snap_arousal = row["emotional"] or 0.0
                current_arousal = pulse.get("arousal", 0.0)
                arousal_diff = abs(current_arousal - snap_arousal)
                arousal_score = max(0.0, 1.0 - arousal_diff)
                
                # 4. Quality prior
                quality = row["quality"] or 0.5

                # 5. RECENCY PENALTY (new!)
                # Recent usage reduces effective quality, giving other memories a chance
                last_used = row["last_used_at"] or 0
                snapshot_id = row["id"]  # Save for later update
                now = int(time.time())

                if last_used > 0:
                    hours_since_use = (now - last_used) / 3600.0
                    if hours_since_use < RECENCY_WINDOW_HOURS:
                        # Penalty is strongest right after use, decays to zero over window
                        recency_penalty = 1.0 - (hours_since_use / RECENCY_WINDOW_HOURS)
                    else:
                        recency_penalty = 0.0  # Outside window = no penalty
                else:
                    recency_penalty = 0.0  # Never used = no penalty

                # Apply penalty to quality component
                quality_with_recency = quality * (1.0 - RECENCY_PENALTY_STRENGTH * recency_penalty)

                # STICKY PHRASE PENALTY (Option D - Musketeers)
                # Known contaminated phrases get 90% penalty to prevent recall
                snapshot_lower = snapshot_text.lower()
                for phrase in STICKY_PHRASES:
                    if phrase in snapshot_lower:
                        # 90% penalty - almost kill this snapshot's chance
                        quality_with_recency *= 0.1
                        break  # One penalty is enough

                # Combine scores (with sticky phrase penalty applied)
                score = (
                    0.4 * token_overlap +
                    0.2 * theme_overlap +
                    0.2 * arousal_score +
                    0.2 * quality_with_recency  # ← CHANGED!
                )

                if score > 0.1:  # threshold
                    scored.append((score, {
                        "id": snapshot_id,  # ← ADD THIS
                        "text": snapshot_text,
                        "tokens": snapshot_tokens,
                    }))
                    
            if not scored:
                return None
                
            # Sort by score descending
            scored.sort(key=lambda x: x[0], reverse=True)
            
            # DRUNK SELECTION (from Haze's PlayfulSanta)
            # Sometimes Santa gets playful and picks a random snapshot
            # This adds creative unpredictability
            import random
            
            top_memories = []
            is_silly = False
            
            for i in range(min(self.max_memories, len(scored))):
                if random.random() < self.silly_factor and len(scored) > 1:
                    # Santa gets playful and picks a random one! 🎁
                    random_idx = random.randint(0, len(scored) - 1)
                    top_memories.append(scored[random_idx])
                    is_silly = True
                else:
                    # Sober moment: pick the best remaining
                    if i < len(scored):
                        top_memories.append(scored[i])
            
            if is_silly:
                self.silly_recalls += 1
            
            self.total_recalled += len(top_memories)
            
            # Build recalled texts (truncate if needed)
            recalled_texts: List[str] = []
            all_recalled_tokens: List[str] = []
            
            for _, memory in top_memories:
                text = memory["text"]
                tokens = memory["tokens"]
                
                # Truncate to max_tokens_per_memory
                if len(tokens) > self.max_tokens_per_memory:
                    truncated_tokens = tokens[:self.max_tokens_per_memory]
                    # Reconstruct text (simple: join with spaces)
                    text = " ".join(truncated_tokens)
                    
                recalled_texts.append(text)
                all_recalled_tokens.extend(tokens)
                
            # Build token boosts
            token_counts = Counter(all_recalled_tokens)
            if not token_counts:
                return None

            max_count = max(token_counts.values())
            token_boosts: Dict[str, float] = {}
            for token, count in token_counts.items():
                # Normalize to [0, 1] then scale by alpha
                normalized = count / max_count if max_count > 0 else 0.0
                token_boosts[token] = self.alpha * normalized

            # UPDATE last_used_at for winning snapshot (recency tracking)
            if top_memories:
                try:
                    winning_id = top_memories[0][1].get("id")
                    if winning_id is not None:
                        conn = sqlite3.connect(str(self.db_path))
                        cur = conn.cursor()
                        cur.execute("""
                            UPDATE snapshots
                            SET last_used_at = ?, use_count = use_count + 1
                            WHERE id = ?
                        """, (int(time.time()), winning_id))
                        conn.commit()
                        conn.close()
                except Exception:
                    pass  # Silent fallback - recency update must never break recall

            return SantaContext(
                recalled_texts=recalled_texts,
                token_boosts=token_boosts,
            )
            
        except Exception:
            # Silent fallback on any error
            return None

    def stats(self) -> Dict[str, Any]:
        """Return recall stats (like PlayfulSanta)."""
        return {
            "total_recalled": self.total_recalled,
            "silly_recalls": self.silly_recalls,
            "silly_ratio": self.silly_recalls / max(1, self.total_recalled),
            "silly_factor": self.silly_factor,
        }


__all__ = ["SantaKlaus", "SantaContext"]

