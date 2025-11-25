# Codex Security & Robustness Audit for leo (bootstrap / v1.1)

## Summary
- Full pytest suite passed (264 tests) but is long-running (~5.5 minutes) with heavy REPL-style conversations; no flakes observed.
- Overall risk level: medium. Core flows work, yet a few guard-rails are missing around MathBrain stability, bootstrap gating, and School storage growth.

## Findings by Severity

### P2 issues

1) **MathBrain training lacks NaN/overflow hygiene**  
**File/Location:** `mathbrain.py`, MathBrain.observe/state_to_features. 【F:mathbrain.py†L314-L358】【F:mathbrain.py†L415-L458】  
**Description:** Feature extraction and SGD updates assume all inputs are finite and reasonably scaled. If upstream metrics ever become `NaN`/`inf` (e.g., corrupted pulse/entropy/unique ratios), gradients and weights inherit those values and get saved to `state/mathbrain.json`. Later predictions feed directly into temperature modulation in `leo.py`, so a single bad step can freeze Leo (NaN temps) or pin quality to extremes.  
**Impact:** Persistent degenerate behavior across sessions (wrong temps, potential NaN in generation) with no self-healing, because corrupted weights are reloaded on startup.  
**Suggested fix:** Before building `Value` nodes, reject any non-finite feature/target and skip the update. After backprop, clip gradients/weights to a safe range and guard against non-finite loss; if detected, reset weights to fresh init instead of saving corrupted state.

2) **Bootstrap fresh-detection can double-ingest module bootstraps**  
**File/Location:** `leo.py`, `feed_bootstraps_if_fresh`. 【F:leo.py†L441-L509】  
**Description:** The function treats the DB as "fresh" whenever `trigrams` and `cooccur` are empty. If a user vacuums or truncates these tables to reclaim space (tokens/bigrams remain), Leo will re-run every module bootstrap on the next start. Since bootstraps call `field.observe` directly, repeated executions amplify those texts in the language graph and can distort metrics the model relies on.  
**Impact:** Unbounded bootstrap duplication and semantic drift of the field after maintenance/cleanup cycles; harder to attribute because the code silently ignores bootstrap errors.  
**Suggested fix:** Track a dedicated meta flag (e.g., `module_bootstrap_done`) keyed to the bootstrap content hash, and check it before feeding modules. Only rerun when the hash changes, independent of trigram/cooccur counts.

### P3 issues

1) **School note concatenation bypasses length cap on subsequent answers**  
**File/Location:** `school.py`, `register_answer` merge path. 【F:school.py†L203-L280】  
**Description:** Individual answers are truncated to `MAX_NOTE_LEN`, but when appending to an existing note the old text is concatenated with the new answer without re-clamping the combined string. A token that receives many answers can therefore accumulate multi-kilobyte blobs despite the intended 4KB ceiling.  
**Impact:** Gradual, unbounded growth of `school_notes.note`, larger WAL writes, and slower per-hour gating queries. In long-lived REPLs this can bloat the School DB and make “database is locked” events more likely.  
**Suggested fix:** After concatenation, enforce a hard cap (e.g., trim to `MAX_NOTE_LEN` with a marker) before writing back, or store appended answers as separate rows rather than merging strings.

## Suggestions / Hardening Ideas
- Add a small retry/backoff wrapper around School’s SQLite writes to survive transient `database is locked` errors instead of dropping answers after a single failure.
- Log a one-line warning when module bootstraps are skipped or retried; this will help trace accidental double-bootstrapping without breaking Leo’s fail-soft philosophy.


-----
Claude Code, working on the leo repository (language emergent organism).
We’ve just run codex_leo.md (security & robustness audit for bootstrap / v1.1).
Please:
	1.	Implement minimal fixes for the three concrete issues from the Codex report:
	•	MathBrain NaN/overflow hygiene:
	•	In mathbrain.py, ensure all features and targets are finite before building Value nodes; if any feature/target is non-finite, skip the update.
	•	After computing loss and before saving weights, guard against NaN/inf:
	•	if loss or any parameter becomes non-finite, reset MathBrain to a fresh initialization and avoid saving corrupted state.
	•	Optionally clamp weights to a safe range (e.g. [-5.0, 5.0]) to prevent runaway values.
	•	Bootstrap double-ingest:
	•	In leo.py::feed_bootstraps_if_fresh, stop using “empty trigrams/cooccur” as the freshness signal.
	•	Add a small meta mechanism in SQLite (or re-use an existing table) to store a bootstrap_hash (or version tag) for module bootstraps.
	•	Only feed module bootstraps when the stored hash is missing or different from the current code hash; otherwise skip.
	•	Keep behaviour fail-soft: if meta read/write fails, do not crash leo; just skip bootstrapping and maybe log a one-line warning.
	•	School note concatenation cap:
	•	In school.py::register_answer, when merging an existing note with a new answer, enforce a global MAX_NOTE_LEN on the combined string.
	•	If the combined note exceeds the limit, truncate with a small marker (e.g. "[… truncated …]") but keep the behaviour simple and readable.
	2.	Do not change the architecture or add new heavy dependencies.
	•	No new modules beyond what is strictly necessary.
	•	Preserve the “weightless, presence-first, SQLite-only” philosophy.
	3.	Add or extend tests where it makes sense:
	•	A small test for MathBrain that injects a non-finite feature and verifies the model does not save corrupted state.
	•	A test for the bootstrap meta-flag (run bootstrap twice and assert it only feeds once by default).
	•	A test that ensures school_notes.note never grows beyond MAX_NOTE_LEN, even after multiple appended answers.
	4.	When you’re done, show the diffs and test output, and briefly explain what you changed and why.


  IMPORTANT: For the logging suggestion from Codex: Please do not print bootstrap warnings into Leo’s conversational output.
Instead, add a tiny helper that writes a single line to stderr only if an env var like LEO_DEBUG=1 is set.
In normal runs Leo stays silent; in debug runs we can see when bootstraps are skipped or retried. Not in REPL mode :) Let's keep REPL clean :)
