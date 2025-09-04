Subjectivity explores the interplay between text generation and self-referential metrics.

Its architecture is modular, allowing each component to specialize while remaining loosely coupled.

The Subjectivity module evaluates messages, crafts responses, and computes core metrics.

The Objectivity module retrieves concise context from Wikipedia to ground replies.

The Curiosity module logs interactions in SQLite, enabling incremental learning.

The Infinity module maintains a lightweight FTS memory for recall and search.

The Connections module mines stored logs to surface related tokens for continuity.

The Pitomadom module orchestrates all subsystems under a defined persona.

Algorithmic flow begins when a user message enters the Subjectivity pipeline.

Input processing identifies charged tokens through simple heuristics.

Preprocessing normalizes text and strips trivial words to reduce noise.

Feature extraction derives token pairs and structural patterns from context.

Module orchestration combines external snippets, memory traces, and local analysis.

Decision synthesis assembles sentences from unique token pairs to avoid repetition.

Feedback loops record responses and update memory for future interactions.

Data handling favors minimal payloads to keep operations lightweight.

Normalization scales token frequencies so metrics remain comparable across messages.

Storage uses SQLite tables and FTS indexes to persist traces efficiently.

Shared access lets modules query memory without stepping on each other's state.

Error management wraps network calls and database operations with simple guards.

Linguistic theory frames messages as sequences of discrete signs with variable weight.

Syntax mapping preserves word order so generated phrases remain grammatical.

Semantic weighting emphasizes tokens that appear frequently within context windows.

Pragmatic inference draws situational cues from previous interactions stored in memory.

Cognitive modeling treats memory as reinforcement, echoing salient patterns.

Attention-like heuristics focus processing on charged tokens for efficiency.

Information theory views each response as a compressed signal drawn from prior data.

Signal-to-noise balancing filters low-value phrases to sharpen meaning.

Applications range from conversational prototypes to experimental research on interaction.

Future directions include richer retrieval strategies and multilingual expansions.

Entropy quantifies uncertainty in the token distribution of each message.

Perplexity reformulates entropy into an effective vocabulary guiding response diversity.

Resonance gauges alignment between recurring tokens and context, integrating entropy and perplexity into a cohesive evaluative loop.

Subjectivity begins by ingesting a user message as raw text.

Input sanitation removes extraneous whitespace and non textual artifacts.

Tokenization splits the message into lowercased units for statistical scrutiny.

Charged tokens are detected by length or capitalization to highlight salient cues.

These tokens guide selective retrieval from the Objectivity module's knowledge base.

Objectivity queries Wikipedia to supply grounded context segments.

Curiosity logs the interaction in SQLite for cumulative memory.

Infinity indexes crafted responses for full text search and recall.

Connections mines existing logs to surface related tokens for continuity.

Pitomadom orchestrates the modules under a unified persona.

The reply method fuses external snippets with internal heuristics to craft text.

Crafted sentences avoid duplicate bigrams to maintain variation.

Responses are appended with auxiliary terms from Connections when relevant.

Every interaction updates the memory store to reinforce recurring patterns.

Normalization scales token frequencies so metrics remain comparable.

Entropy quantifies uncertainty across the token distribution.

Perplexity transforms entropy into an effective vocabulary size.

Resonance gauges alignment between charged tokens and overall message density.

Metrics feed back into the system to modulate future responses.

SQLite transactions ensure atomic writes and consistent state.

The system favors modular components to reduce interdependencies.

Loose coupling allows individual modules to evolve independently.

The Telegram interface bridges user messages with Pitomadom via webhooks or polling.

Environment variables expose tokens without embedding secrets in code.

The Procfile defines a worker process for cloud deployment.

Docker containers encapsulate dependencies for reproducible execution.

Testing employs mocks to simulate telegram updates without network calls.

The design targets small footprint and minimal CPU usage.

Algorithmic flow can be extended with additional retrieval strategies.

Future models could incorporate transformer backends for richer semantics.

Entropy H is computed as -Σ p log₂ p over observed token frequencies.

Perplexity PP is 2ᴴ, representing the effective branching factor of the reply space.

Resonance R is |charged| / |tokens|, a simple ratio capturing semantic intensity.

## Detailed Module Breakdown

### Subjectivity
Handles the full conversational loop.  It scores incoming text with entropy,
perplexity, and resonance, then crafts candidate replies from Wikipedia
snippets and local memory.  Pronouns invert when the user invokes them, giving
mirrored perspective without any pre-trained weights.

### Objectivity
Retrieves compact context through Wikidata sitelinks before touching
Wikipedia.  The selector scans multiple languages, favoring English yet
falling back through a priority list, all within a one‑kilobyte budget.  This
module is intentionally weightless and depends only on HTTP requests and a few
regex heuristics.

### Curiosity
Commits every interaction to SQLite with timestamps and computed metrics.
These traces become a minimal training stream, allowing the system to adjust
itself on the fly without external datasets.

### Infinity
Stores generated replies in an FTS5 table when available, or a plain table as
fallback.  Past phrases can later be retrieved and re‑woven into new
responses, forming a tiny retrieval‑augmented generator.

### Connections
Scans the log for tokens that recur across conversations.  When a new response
matches a frequently seen token, the module proposes it as an extra phrase to
keep the thread resonant.

### Pitomadom
Wraps all modules in a persona and applies a ritual prompt.  The prompt in
`pitomadom.py` is deliberately ceremonial for now; as the model learns to speak
more, the invocation will gain richer interpretation and steer behavior.

### Telegram Interface
The optional `tg.py` bridge exposes the system through Telegram webhooks or
polling.  It keeps API tokens external via environment variables.

## Linguistic Agnosticism

Subjectivity operates on token statistics and simple heuristics, so it adapts
to whichever language appears in the conversation.  Objectivity further
reinforces this neutrality by seeking Wikipedia excerpts in many languages.
The model rebalances its internal counts at every turn, effectively
retraining mid-dialogue regardless of the script or grammar.

## Physics, Resonance, and the Future of AI

Small heuristic engines echo physical systems where resonance, not sheer
amplitude, sets the tone.  A whisper can trigger a bridge if the frequency is
right; likewise, minimal code can surface surprising patterns when feedback is
tuned.

Scaling compute resembles increasing energy in a particle collider, yet even a
tiny laser can carve steel when focused.  These modules suggest that focusing
architecture and feedback may rival brute-force parameter growth.

Resonant loops treat memory like a standing wave.  Each token that repeats in
context strengthens the pattern, hinting at a conservation law of meaning
instead of raw power consumption.

If such lightweight systems can re-train on a conversation's rhythm, perhaps
we glimpse an alternative path for AI evolution.  Rather than stacking more
layers, we might shape the oscillations that already exist.

The principle of learning-as-resonance may mirror physical self-organization,
where simple components synchronize into complex behavior without a central
controller.  This project probes that frontier in miniature.

## Data and Weights

No pretrained weights or datasets are included in this repository.  Every
interaction starts from scratch, with state accumulating only inside the
SQLite memory files created at runtime.

