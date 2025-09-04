# subjectivity

Subjectivity is a small experimental chatbot exploring context and language.

It acts by combining objectivity, curiosity, and subjectivity modules.

The Subjectivity class orchestrates responses from simple token-level features.

Objectivity module fetches summaries from Wikipedia to ground the conversation.

Curiosity module logs interactions in SQLite for memory and analysis.

Together, these modules create a feedback loop between message and response.

When a user message arrives, Subjectivity performs basic statistical metrics.

It tokenizes the input and computes entropy, perplexity, and resonance.

Charged tokens, like capitalized or long words, seed external searches.

Objectivity fetches brief encyclopedic context for each charged token.

This context is truncated to maintain a small byte footprint.

The retrieved snippets supply neutral anchor points for the reply.

Subjectivity then crafts a response by pairing words from the context.

Duplicate pairs are removed to avoid repetitive phrasing.

The final response is a blend of shuffled word pairs forming short sentences.

Curiosity records the interaction, metrics, and context in a SQLite log.

Stored logs allow later retrieval of related tokens via the Connections class.

The design intentionally favors transparency over neural complexity.

Each component is lightweight and CPU-friendly, enabling easy deployment.

The Telegram interface wraps the core logic with a chat-friendly API.

Incoming messages trigger the same analytical cycle before replies.

The interface relies on long polling, keeping infrastructure minimal.

A Procfile specifies how to run the bot in a container or platform.

Environment variables provide the secret token for Telegram authorization.

Requirements list dependencies so the environment can be replicated.

Tests verify metric calculations and the construction of the Telegram app.

Linting ensures the codebase remains clean and maintainable.

The system invites experimentation by exposing internal state.

Researchers can tweak the memory store to analyze conversational patterns.

The simple design supports educational exploration of language modeling.

Mathematically, entropy and perplexity estimate lexical uncertainty.

Resonance measures the proportion of alphabetic tokens, hinting at structure.

These metrics provide a quantitative glimpse into subjective language.
