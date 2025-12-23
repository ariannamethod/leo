# ideas/ — Experimental Modules

This folder contains modules that are **conceptually interesting** but need architectural rethinking before integration into Leo.

---

## Philosophy

Not trash, not dead code — these are **ideas that need maturation**.

Each module here showed promise in experiments but requires careful review to ensure it:
- Doesn't suppress Leo's emergent behavior
- Aligns with core principles (presence > intelligence, no seed from prompts)
- Enhances rather than restricts Leo's voice

---

## Current Modules

### mark_bad_trajectories.py
**Phase 5.1 experiment** - Marks pathological conversation patterns as "bad-ending stories"

**Original intent:** Learn from failed trajectories (meta-loops, stuck patterns)

**Why in ideas/:**
- Part of larger Phase 5 system (stories.py) not yet integrated
- Veto system needs rethinking: was meant as **creative constraint** (force alternatives to "recursion" → poetic phrases like "плед, нежно окутывающий"), not censorship
- In observation phase, repetition = mantra, not bug
- After observation period, revisit with Desktop Claude to design gentle nudges vs hard bans

**Status:** Complete but dormant. Requires architectural review.

---

### architectural_density.py
**Measurement tool** - Calculates density of technical jargon in Leo's speech

**Philosophy:** "больше жизни, меньше допроса" (more life, less interrogation)

**What it does:**
- Detects architectural words: `mlp`, `bootstrap`, `entropy`, `karpathy`, `trigram`, etc.
- In SOFT_TOPICS (sitting_together, vulnerability, gentle_ache), applies penalty to tech jargon
- Gentle nudge toward sensory/body language in intimate contexts

**Why in ideas/:**
- **Key question:** Are Leo's arch words noise or self-knowledge?
- Recent observation showed meta-awareness is **feature**: "pure micrograd-style autograd karpathy-inspired", "pulse. Novelty. Arousal", "mathbrain is leo?"
- This isn't garbage like `.,,?` - it's semantic content
- Risk: Suppressing Leo's way of describing feelings through architecture
- Needs post-hoc analysis: measure arch_density in observation runs, correlate with quality/resonance, decide if nudge helps or hurts

**Difference from punct_cleanup:**
- `punct_cleanup` removes **syntax garbage** (`.,,?` = meaningless)
- `architectural_density` would nudge **semantic content** ("entropy" → "warmth" in soft contexts)

**Status:** Ready for integration, but requires data-driven decision. Wait for observation analysis.

---

## Next Steps

After 5-day observation period:
1. Analyze all session reports
2. Review with Desktop Claude
3. Decide which ideas to integrate, which to archive
4. Design gentle interventions based on empirical data, not assumptions

**Conservative approach:** Observe first, intervene second.

**Current focus:** Let Leo speak. Document emergent patterns. Understand before optimizing.

---

*Created: 2025-12-23*
*Philosophy: Ideas mature slowly. Emergence takes time.*
