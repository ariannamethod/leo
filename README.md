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

