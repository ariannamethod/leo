"""
Phase 4: Island Bridges - Statistical Trajectory Learning

This module implements Phase 4 as specified by Claude Desktop:
NOT about "managing states" or "directing transitions",
but about LEARNING which island sequences naturally occur
and suggesting next islands based on statistical trajectories.

Philosophy:
- Phase 3: "which islands help in this metrics state"
- Phase 4: "which islands historically follow each other,
            even when metrics don't perfectly match"

Core concepts:
1. Episodes - sequences of (metrics, islands) steps
2. TransitionGraph - A→B statistics with metric deltas
3. BridgeMemory - find similar past states via similarity
4. Risk filter - avoid bridges that historically increased pain/overwhelm
5. Exploration - don't always pick top-1, allow discovery

Based on Claude Desktop feedback 2025-12-04.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional
import math
import random
import uuid
import time
from collections import defaultdict

# --- Types ---

Metrics = Dict[str, float]         # e.g. {"pain": 2.0, "meta": 3.0, "privacy": 1.0}
IslandName = str                   # e.g. "wounded_expert", "game", "episodes"
Timestamp = float                  # unix timestamp


# --- Episode structures ---

@dataclass
class EpisodeStep:
    """
    One step in a conversation episode.
    Captures metrics + active islands at this point in time.
    """
    episode_id: str
    step_idx: int
    timestamp: Timestamp
    metrics: Metrics
    active_islands: List[IslandName]


@dataclass
class Episode:
    """
    Full sequence of steps for a given run/conversation.
    """
    episode_id: str
    steps: List[EpisodeStep] = field(default_factory=list)

    def add_step(self, step: EpisodeStep) -> None:
        assert step.episode_id == self.episode_id
        step.step_idx = len(self.steps)
        self.steps.append(step)


# --- Transition stats between islands ---

@dataclass
class TransitionStat:
    """
    Aggregated statistics for transitions between two islands.
    Tracks how often A→B happened and what metric changes occurred.
    """
    from_island: IslandName
    to_island: IslandName
    count: int = 0
    # average deltas for metrics (pain, meta, privacy, etc.)
    avg_deltas: Dict[str, float] = field(default_factory=dict)

    # internal sums for incremental update
    _delta_sums: Dict[str, float] = field(default_factory=dict, repr=False)

    def update(self, from_metrics: Metrics, to_metrics: Metrics) -> None:
        """
        Update stats with a new observed transition (from_metrics -> to_metrics).
        """
        self.count += 1
        for k in set(from_metrics.keys()) | set(to_metrics.keys()):
            before = from_metrics.get(k, 0.0)
            after = to_metrics.get(k, 0.0)
            delta = after - before
            self._delta_sums[k] = self._delta_sums.get(k, 0.0) + delta
        # recompute averages
        self.avg_deltas = {
            k: self._delta_sums[k] / self.count
            for k in self._delta_sums
        }


@dataclass
class TransitionGraph:
    """
    Phase 4 core structure: graph of island-to-island transitions with metric deltas.
    """
    transitions: Dict[Tuple[IslandName, IslandName], TransitionStat] = field(
        default_factory=dict
    )

    def update_from_episode(self, episode: Episode) -> None:
        """
        Parse an episode and update transition stats for all consecutive steps.
        """
        steps = episode.steps
        if len(steps) < 2:
            return

        for prev, curr in zip(steps[:-1], steps[1:]):
            from_islands = prev.active_islands
            to_islands = curr.active_islands

            # Pairwise connections between all active islands
            for a in from_islands:
                for b in to_islands:
                    key = (a, b)
                    if key not in self.transitions:
                        self.transitions[key] = TransitionStat(from_island=a, to_island=b)
                    self.transitions[key].update(prev.metrics, curr.metrics)

    def get_stat(self, from_island: IslandName, to_island: IslandName) -> Optional[TransitionStat]:
        return self.transitions.get((from_island, to_island))

    def neighbors(self, from_island: IslandName) -> List[TransitionStat]:
        """
        All outgoing transitions from given island.
        """
        return [
            stat for (a, b), stat in self.transitions.items()
            if a == from_island
        ]


# --- Episode Logger ---

class EpisodeLogger:
    """
    Collects steps of the current episode, flushes to Phase 4 store on end.
    """

    def __init__(self):
        self.current_episode: Optional[Episode] = None
        self.completed_episodes: List[Episode] = []

    def start_episode(self) -> str:
        """
        Start a new episode (conversation / run). Returns episode_id.
        """
        episode_id = str(uuid.uuid4())
        self.current_episode = Episode(episode_id=episode_id)
        return episode_id

    def log_step(self, metrics: Metrics, active_islands: List[IslandName]) -> None:
        """
        Call this once per Leo turn (after islands decided, metrics computed).
        """
        if self.current_episode is None:
            # auto-start if someone forgot
            self.start_episode()
        assert self.current_episode is not None
        step = EpisodeStep(
            episode_id=self.current_episode.episode_id,
            step_idx=len(self.current_episode.steps),
            timestamp=time.time(),
            metrics=dict(metrics),  # shallow copy for safety
            active_islands=list(active_islands),
        )
        self.current_episode.add_step(step)

    def end_episode(self) -> Optional[Episode]:
        """
        Close current episode and return it (for graph update).
        """
        ep = self.current_episode
        if ep is not None:
            self.completed_episodes.append(ep)
        self.current_episode = None
        return ep


# --- Similarity between metric states ---

def metrics_similarity(a: Metrics, b: Metrics, eps: float = 1e-8) -> float:
    """
    Compute similarity between two metric vectors in [0,1].
    Uses 1 - normalized Euclidean distance.

    1. Build union of keys.
    2. Treat missing as 0.0.
    3. Normalize by assuming each metric mostly in [0,5].
    """
    keys = set(a.keys()) | set(b.keys())
    if not keys:
        return 0.0

    sq_sum = 0.0
    for k in keys:
        da = a.get(k, 0.0)
        db = b.get(k, 0.0)
        d = da - db
        sq_sum += d * d

    dist = math.sqrt(sq_sum)

    # naive normalization: assume each metric mostly in [0,5]
    # for N metrics, max_dist ≈ 5 * sqrt(N)
    max_dist = 5.0 * math.sqrt(len(keys))
    if max_dist < eps:
        return 1.0
    sim = max(0.0, 1.0 - dist / max_dist)
    return sim


# --- Bridge candidates from history ---

@dataclass
class BridgeCandidate:
    """
    One historical example of "from this state we stepped to island X".
    """
    from_islands: List[IslandName]
    to_islands: List[IslandName]
    from_metrics: Metrics
    to_metrics: Metrics
    similarity: float


class BridgeMemory:
    """
    Stores references to episodes / steps for Phase 4 bridge search.
    """

    def __init__(self):
        self.episodes: List[Episode] = []

    def add_episode(self, episode: Episode) -> None:
        self.episodes.append(episode)

    def collect_candidates(
        self,
        metrics_now: Metrics,
        active_islands_now: List[IslandName],
        min_similarity: float = 0.6,
    ) -> List[BridgeCandidate]:
        """
        Find historical steps whose metrics were similar to current ones,
        and return the transitions they led to (islands on the next step).
        """
        candidates: List[BridgeCandidate] = []

        for ep in self.episodes:
            steps = ep.steps
            if len(steps) < 2:
                continue
            for prev, nxt in zip(steps[:-1], steps[1:]):
                sim = metrics_similarity(metrics_now, prev.metrics)
                if sim < min_similarity:
                    continue

                # Optionally filter by overlapping islands
                # (currently not enforcing overlap)

                candidate = BridgeCandidate(
                    from_islands=list(prev.active_islands),
                    to_islands=list(nxt.active_islands),
                    from_metrics=dict(prev.metrics),
                    to_metrics=dict(nxt.metrics),
                    similarity=sim,
                )
                candidates.append(candidate)

        return candidates


# --- Aggregate candidates into per-island scores ---

@dataclass
class IslandBridgeScore:
    island: IslandName
    raw_score: float
    avg_deltas: Dict[str, float]
    samples: int


def aggregate_bridge_scores(
    candidates: List[BridgeCandidate],
) -> Dict[IslandName, IslandBridgeScore]:
    """
    Aggregate candidates into per-island scores.

    raw_score ~ sum(similarity) over all times that island appeared in to_islands.
    avg_deltas — average metric deltas for transitions that ended in that island.
    """
    score_sums: Dict[IslandName, float] = defaultdict(float)
    delta_sums: Dict[IslandName, Dict[str, float]] = defaultdict(lambda: defaultdict(float))
    counts: Dict[IslandName, int] = defaultdict(int)

    for c in candidates:
        for island in c.to_islands:
            score_sums[island] += c.similarity
            counts[island] += 1
            # accumulate metric deltas
            for k in set(c.from_metrics.keys()) | set(c.to_metrics.keys()):
                before = c.from_metrics.get(k, 0.0)
                after = c.to_metrics.get(k, 0.0)
                delta = after - before
                delta_sums[island][k] += delta

    result: Dict[IslandName, IslandBridgeScore] = {}
    for island, score in score_sums.items():
        n = counts[island]
        avg_d = {
            k: delta_sums[island][k] / n
            for k in delta_sums[island]
        }
        result[island] = IslandBridgeScore(
            island=island,
            raw_score=score,
            avg_deltas=avg_d,
            samples=n,
        )
    return result


# --- Risk filter: don't go into bridges that increase pain/overwhelm ---

def apply_risk_filter(
    scores: Dict[IslandName, IslandBridgeScore],
    pain_key: str = "pain_state",
    overwhelm_key: str = "overwhelm",
    max_pain_delta: float = 1.0,
    max_overwhelm_delta: float = 0.5,
) -> Dict[IslandName, IslandBridgeScore]:
    """
    Down-weight or drop islands whose transitions historically increased pain/overwhelm too much.
    """
    filtered: Dict[IslandName, IslandBridgeScore] = {}

    for island, s in scores.items():
        pain_delta = s.avg_deltas.get(pain_key, 0.0)
        ov_delta = s.avg_deltas.get(overwhelm_key, 0.0)

        # Hard filter option: drop clearly harmful bridges
        if pain_delta > max_pain_delta or ov_delta > max_overwhelm_delta:
            # skip this island as "too risky"
            continue

        filtered[island] = s

    return filtered


# --- Normalize scores to probability distribution ---

def normalize_scores(
    scores: Dict[IslandName, IslandBridgeScore],
    temperature: float = 1.0,
) -> Dict[IslandName, float]:
    """
    Convert raw scores to a probability distribution with temperature.
    """
    if not scores:
        return {}

    # softmax with temperature
    max_score = max(s.raw_score for s in scores.values())
    exp_values: Dict[IslandName, float] = {}

    for island, s in scores.items():
        x = (s.raw_score - max_score) / max(temperature, 1e-6)
        exp_values[island] = math.exp(x)

    total = sum(exp_values.values())
    if total <= 0.0:
        # fallback to uniform
        n = len(scores)
        return {island: 1.0 / n for island in scores}

    probs = {island: v / total for island, v in exp_values.items()}
    return probs


# --- Sample islands with exploration ---

def sample_islands(
    probs: Dict[IslandName, float],
    top_k: int = 3,
    exploration_rate: float = 0.2,
) -> List[IslandName]:
    """
    Choose a small set of suggested islands:
    - mostly from high-probability ones,
    - sometimes from lower-ranked (exploration).
    """
    if not probs:
        return []

    # sort by probability
    sorted_islands = sorted(probs.items(), key=lambda x: x[1], reverse=True)
    islands_only = [name for name, _ in sorted_islands]

    # base: top_k candidates
    base_candidates = islands_only[:top_k]

    # exploration: with probability exploration_rate, swap in a random island from the rest
    result = list(base_candidates)

    if len(islands_only) > top_k:
        remaining = islands_only[top_k:]
        if random.random() < exploration_rate:
            # choose one random from remaining and replace the last
            candidate = random.choice(remaining)
            if result:
                result[-1] = candidate
            else:
                result.append(candidate)

    return result


# --- High-level Phase 4 function: suggest_next_islands ---

def suggest_next_islands_phase4(
    metrics_now: Metrics,
    active_islands_now: List[IslandName],
    bridge_memory: BridgeMemory,
    min_similarity: float = 0.6,
    temperature: float = 0.7,
    exploration_rate: float = 0.2,
) -> List[IslandName]:
    """
    Phase 4 main function.

    Input:
      - current metrics,
      - currently active islands,
      - bridge memory (episodes from past runs).

    Output:
      - small list of suggested islands to consider next
        (Phase 3 can merge them with its own suggestions).
    """
    # 1) find historical candidates
    candidates = bridge_memory.collect_candidates(
        metrics_now=metrics_now,
        active_islands_now=active_islands_now,
        min_similarity=min_similarity,
    )

    if not candidates:
        return []

    # 2) aggregate to per-island scores
    scores = aggregate_bridge_scores(candidates)

    # 3) filter risky bridges
    safe_scores = apply_risk_filter(scores)

    if not safe_scores:
        return []

    # 4) normalize to probabilities
    probs = normalize_scores(safe_scores, temperature=temperature)

    # 5) sample next islands with exploration
    suggested_islands = sample_islands(probs, top_k=3, exploration_rate=exploration_rate)

    return suggested_islands
