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
