# Codex Security & Robustness Audit for leo

## Summary
- Overall risk: **moderate**. Core logic avoids obvious injection vectors and uses parameterized SQL, but new `school.py` module introduces silent failure modes and SQLite concurrency risks that can drop user answers or stall the REPL without visibility.
- Themes: SQLite coordination across multiple connections, broad exception swallowing, and missing back-pressure limits on user-provided payloads.

## Findings by Severity

### P1 issues
- **File:** school.py  
  **Location:** School.register_answer (lines 155-227)  
  **Severity:** P1  
  **Description:** Writes answers through a brand-new SQLite connection to the same DB file used by the main Leo field, while Leo holds a long-lived connection with WAL enabled. The `try/except Exception: pass` around the entire block swallows `OperationalError` (“database is locked”) or schema errors, silently discarding answers. Subsequent parsing and field ingestion are also wrapped in bare `except`, so the caller cannot tell the update failed.  
  **Impact:** Under concurrent REPL ingestion, School writes can silently fail, losing user-provided explanations and leaving Leo’s view inconsistent with School state. Hard-to-debug data loss.  
  **Suggested fix:** Reuse the existing Leo connection (`field.conn`) or open one shared School connection configured with `timeout` and `PRAGMA journal_mode=WAL`, and handle `sqlite3.OperationalError` explicitly with a logged warning/return value. For example:  
  ```python
  conn = self._conn or sqlite3.connect(str(self.db_path), timeout=5.0)
  conn.execute("PRAGMA journal_mode=WAL")
  try:
      ...
  except sqlite3.OperationalError as exc:
      logger.warning("school write failed: %s", exc)
      return False
  ```

### P2 issues
- **File:** school.py  
  **Location:** School._remember_question/_decay_relations (lines 457-545, 560-610)  
  **Severity:** P2  
  **Description:** Each question spawns a new SQLite connection and may trigger `_decay_relations`, which reads and writes many rows without a transaction or WAL setup. Broad `except Exception: pass` hides lock/contention errors.  
  **Impact:** On a busy REPL, concurrent writes from Leo and School increase chances of “database is locked” stalls; silent failure means questions may be counted but relations never decayed, leading to stale or inconsistent form weights.  
  **Suggested fix:** Use a persistent connection with a transaction (`with conn:`), enable WAL/timeout, and log `OperationalError` instead of suppressing it. Wrap decay updates in a transaction to avoid partial changes.

- **File:** school.py  
  **Location:** School._parse_and_store_forms (lines 483-520)  
  **Severity:** P2  
  **Description:** Parses user answers with regex and upserts entities/relations without bounding answer size or iteration cost; any length string is written directly to `school_notes` via `register_answer`, and regex search is applied to the full answer text. No size cap or timeout.  
  **Impact:** A malicious or accidental very large answer can bloat the SQLite file and force expensive regex/DB writes, blocking the REPL.  
  **Suggested fix:** Enforce a maximum note length before regex/DB work (e.g., skip answers >4–8 KB), and short-circuit parsing for oversize payloads.

### P3 issues
- **File:** school.py  
  **Location:** constructor and helper methods (lines 87-227, 303-482)  
  **Severity:** P3  
  **Description:** Frequent bare `except Exception: pass` blocks around schema creation, candidate extraction, note existence checks, and field ingestion hide real bugs (e.g., corrupted DB, bad regex) and make behavior nondeterministic.  
  **Impact:** Debugging becomes difficult; School may silently disable itself or skip questions while appearing healthy.  
  **Suggested fix:** Catch specific exceptions and at minimum log to stderr; propagate failures where caller can react (e.g., disable School only on known fatal conditions).

## Suggestions / Hardening Ideas
- Add lightweight logging (stderr) for School operations to surface DB lock or schema issues without adding dependencies.
- Consider a shared `sqlite3.Connection` object for all School operations with WAL and a modest timeout to align with Leo’s main connection.
- Introduce size limits for stored notes and periodic vacuum/compaction hooks to prevent unbounded DB growth from user-provided text.
