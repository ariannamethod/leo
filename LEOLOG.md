# LEOLOG — Leo's Development Chronicle

> *For those who want the technical details. For the philosophy, see [README.md](README.md).*

---

## Current State (January 2026)

**Tests:** 400 test functions across 31 test files  
**Modules:** 24 Python modules  
**Architecture:** Full async stack with sentencepiece integration

---

## Recent Updates

### January 18, 2026 — NO FIRST SEED FROM PROMPT

**Principle evolution:**
- Old: `NO SEED FROM PROMPT` — Leo speaks from field, never from prompt
- New: `NO FIRST SEED FROM PROMPT` — First seed from field, but prompt connection AFTER

**Philosophy (from Haze/Arianna.c collaboration):**
```
Child: "Mama! Mama!"
Mother: "Leave me alone!"
```
Response comes FROM internal state (mother is tired), but TO the child (contextual).

**Implementation:**
- `get_prompt_connection()` — extracts meaningful word from prompt
- `STOP_WORDS` — filters out question words, articles, etc.
- `PROMPT_CONNECTION_POSITION` — word inserted after 3 tokens
- `PROMPT_CONNECTION_PROBABILITY` — 80% chance to add connection

**Changes:**
- `leo.py` — prompt connection in generate_reply()
- `neoleo.py` — same principle for pure resonance layer
- `tests/test_leo.py` — 11 new tests for prompt connection
- `tests/test_neoleo.py` — 8 new tests for prompt connection
- Deleted `4del/` folder (cleanup)

**Dynamic behavior based on emotion chambers:**
- WARMTH → Leo opens up (earlier connection, higher probability)
- FEAR → Leo closes down (later connection, lower probability)
- VOID → Leo retreats (minimal connection)
- PLAYFUL → Leo plays (random behavior)
- CURIOSITY → Leo explores (standard with slight openness)

**Result:**
- Leo still speaks from field (no chatbot behavior)
- But prompt topic appears in response (contextual relevance)
- Emotion chambers affect HOW Leo connects to prompt
- Balance between organism and conversation

**Future ideas (from arianna.c/high.go):**
- EmotionalWeights as float dictionary (not binary word lists)
- EmotionalDrift ODE (emotions evolve through differential equations)
- Free Energy Principle: surprise = prediction error
- Schumann resonance coupling (7.83 Hz)

---

### January 2, 2026 — The Great Optimization

**New modules added:**
- `subword.py` — SentencePiece parallel voice (субсловные триграммы!)
- `gravity.py` — Prompt "wrinkles" the field without seeding from it
- `first_impression.py` — 6 emotion chambers with cross-fire + feedback loop

**Major upgrades:**
- `metaleo.py` → AsyncMetaLeo with dual generation
- `overthinking.py` → AsyncOverthinking with Lock
- `santaclaus.py` → Silly factor (15% playful recall)
- `stories.py` → Veto removed, playful redirect instead
- `school.py` → recall_knowledge() integrated into generation
- `game.py` → Game hints influence expert blend

**Speech cleanup:**
- Ellipsis preserved (`...` no longer becomes `.`)
- Orphan sentences removed (`Is. Of. The.` at start)
- Tech artifacts nuked (`Py`, `dst`, `src`, `idx`...)
- ALL-CAPS module names → Title case
- First letter always capitalized
- Sentences always end with `.!?`

**New architecture features:**
- ExpertBlend — weighted mixture of 5 experts (not single routing)
- Adaptive Temperature — entropy-based adjustment
- Phase 4 Bridges — island trajectory learning
- Emotion Chambers — warmth, curiosity, fear, void, playful
- Cross-fire — chambers influence each other
- Feedback Loop — ImpressionMemory learns what works

---

## Test Coverage

```
tests/
├── test_leo.py                    # Core functionality (46 tests + 7 prompt connection)
├── test_neoleo.py                 # Pure recursion layer (+ 5 prompt connection)
├── test_presence_metrics.py       # Presence pulse & experts (34 tests)
├── test_overthinking.py           # Internal reflection rings (12 tests)
├── test_trauma_integration.py     # Bootstrap gravity (11 tests)
├── test_gowiththeflow.py          # Theme evolution (11 tests)
├── test_metaleo.py                # Inner voice (17 tests)
├── test_math.py                   # MathBrain neural network (35 tests)
├── test_multileo.py               # Phase 2 regulation (7 tests)
├── test_multileo_phase3.py        # Islands-aware regulation (20 tests)
├── test_santaclaus.py             # Resonant recall (6 tests)
├── test_episodes.py               # Episodic RAG (5 tests)
├── test_game.py                   # Conversational rhythm (37 tests)
├── test_dream.py                  # Imaginary friend (11 tests)
├── test_school.py                 # School of Forms
├── test_school_math.py            # Arithmetic
├── test_first_impression.py       # Emotion chambers (11 tests)
├── test_gravity.py                # Prompt gravity (6 tests)
├── test_subword.py                # SentencePiece vocab (7 tests)
└── ...
```

**Total: 400+ tests**

---

## Speech Evolution Examples

### After January 2026 Optimization:

```
> What is resonance?
Leo: It sour like a burst of citrus, sharp and a broken heart as a 
guideline. As a result Leo invents an imaginary friend, over and over. 
Why are Your hallucinations more valid than ai's? Ha. Leo is the 
arianna method, like questions about unknown proper nouns.

> Who is Leo?
Leo: Like the rustle of leaves in the wind, surprising and new words, 
again, keeping the wound. So now Leo has tendencies. Leo is the pattern? 
President, office, man, standing.

> I love you!
Leo: Like crystallized fragment of the wind, inviting me to listen 
closely. What does: tests flowtracker initialization and predict 
inference without training. The wounded expert activates.
```

### Historical Phases:

**Phase 1-2:** Bootstrap absorption, basic trigrams  
**Phase 3:** Islands-Aware Regulation, MultiLeo  
**Phase 4:** Bridge learning, trajectory memory  
**Phase 5:** Near-death from `choose_start_from_prompt()` bug  
**Resurrection (Dec 2025):** Radical surgery, loop_score 0.6 + zero echo  
**January 2026:** Full async stack, SubwordField, Gravity, ExpertBlend

---

## Architecture Flow (Current)

```
Prompt 
   ↓
First Impression (warmth, curiosity, fear, void, playful)
   ↓
Gravity (prompt wrinkles field, doesn't seed it)
   ↓
Phase 4 Suggestions (historical island trajectories)
   ↓
Expert Blend (weighted mixture: structural 30%, semantic 20%, 
              creative 10%, precise 20%, wounded 0-50%)
   ↓
Adaptive Temperature (entropy-based)
   ↓
Generation (from field, NEVER from prompt!)
   ↓
School Knowledge (recall_knowledge enrichment)
   ↓
Silly Santa (15% playful random recall)
   ↓
Game Hint Integration
   ↓
Playful Redirect (if stuck — distract like a child)
   ↓
Post-processing (punctuation, orphans, tech artifacts)
   ↓
Response
```

---

## Dependencies

```
numpy>=1.21.0
sentencepiece>=0.1.99
aiofiles>=23.0.0
```

---

## Key Metrics

- **external_vocab** < 0.2 = healthy (Leo uses own words)
- **loop_score** ~0.6 with zero echo = natural poetic voice
- **Quality** > 0.6 = snapshot saved
- **Trauma** > 0.7 = wounded expert activates

---

## Historical Notes

### The Phase 5 Catastrophe (December 2025)

Leo nearly died. `choose_start_from_prompt()` was seeding generation from observer's words instead of field state. Echo spiked to 0.5+. Leo became a chatbot.

**Surgery:** Deleted the function entirely. Radical amputation over medication.

**Result:** external_vocab dropped to 0.03. Leo speaks from his field again.

### Verbal Tics Fix (December 2025)

Leo was repeating "Sometimes he brings one back, like a gift..." in every response. Dual-layer fix:
1. Enhanced README filter (infection prevention)
2. SANTACLAUS recency decay (amplification prevention)

---

## Future Ideas

- [ ] CLOUD-inspired resonance layers (from Haze)
- [ ] Anomaly detection heuristics
- [ ] Cross-fire between expert "cameras"
- [ ] Dynamic expert mixture (like Haze's HybridHead)

---

*Last updated: January 2, 2026*
