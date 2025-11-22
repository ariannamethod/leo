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



Claude:
---

## Implementation instructions for Cursor / Codex (school.py only)

Read the Codex audit above as context.  
Now, **apply ONLY the following changes**, and nothing beyond that.

### 0. Scope / hard limits

- **Do NOT change leo's architecture.**
- **Do NOT add any new dependencies** (no new Python packages, no external services).
- **Do NOT introduce JSON configs, bootstraps or datasets.**
- **Do NOT touch any other files** outside `school.py`, unless there is an obvious, test-breaking bug that *must* be fixed to keep leo running.
- School v1 is **English-only** in its form logic (city, country, planet, capital_of).  
  Do not add language-specific templates for other languages.

The goal: make `school.py` **safer and more robust**, without making it smarter, heavier or more complicated.

---

### 1. SQLite: one persistent connection for School

Right now `school.py` opens new SQLite connections in several methods (`register_answer`, `_remember_question`, `_parse_and_store_forms`, `_decay_relations`, etc.) and swallows all exceptions.

Change this to:

1. In `School.__init__`, create **one persistent connection** and store it as `self._conn`:

   ```python
   self._conn = sqlite3.connect(str(self.db_path), timeout=5.0)
   self._conn.execute("PRAGMA journal_mode=WAL")
   self._conn.execute("PRAGMA synchronous=NORMAL")

Assume leo is single-threaded; you do NOT need extra threading tricks here.
	2.	Replace all sqlite3.connect(...) calls in school.py with use of self._conn.
	•	Use cur = self._conn.cursor() everywhere.
	•	Use self._conn.commit() where needed.
	3.	Where you do read–write sequences (_ensure_schema, register_answer, _remember_question, _decay_relations, _parse_and_store_forms), wrap them in a simple transaction pattern:

cur = self._conn.cursor()
try:
    # DB work...
    self._conn.commit()
except sqlite3.OperationalError as e:
    print(f"[school] sqlite operational error: {e}")
    # fail fast and return, do NOT raise
    return
except Exception as e:
    print(f"[school] unexpected school db error: {e}")
    return


	4.	Do NOT swallow all exceptions silently.
	•	At minimum, log to stderr via print("[school] ...") and return.
	•	It is OK for School to gracefully disable itself if the DB is clearly broken, but do NOT crash leo.

If you need to keep the SCHOOL_AVAILABLE flag, only set it to False on truly fatal initialization errors (e.g., schema cannot be created).

⸻

2. Limit stored note size and parsing cost

User answers can be arbitrarily long. We must not let a huge paste block leo or blow up the DB.

Add:
	•	A module-level constant, for example:

MAX_NOTE_LEN = 4096  # bytes or characters; keep it simple


	•	In register_answer, before any DB writes or _parse_and_store_forms:

if len(human_answer) > MAX_NOTE_LEN:
    human_answer = human_answer[:MAX_NOTE_LEN]
    # optionally add a small suffix like " [truncated]" but keep it simple


	•	Also add a cheap guard before _parse_and_store_forms:
	•	If len(human_answer) is larger than some lighter threshold (for example, > MAX_NOTE_LEN before truncation), you can skip _parse_and_store_forms entirely and just store the raw note.
	•	The idea: no heavy regex/DB work on giant blocks of text.

Do NOT introduce streaming, chunking, or any complex mechanisms.
Just a hard cap and a simple conditional.

⸻

3. Fix _pick_new_token behavior (no pointless re-asks)

Current _pick_new_token version in school.py was adjusted to respect _has_note, but make sure the logic is exactly:
	•	If we already have a non-NULL note for a token, never ask about it again.
	•	Do not use times_asked for selection anymore; note IS NOT NULL is enough as a stop condition.
	•	Still keep the guard that avoids asking the same token twice in a row.

Pseudocode target:

for token, display in candidates:
    if self._last_token_asked and token == self._last_token_asked:
        continue
    if self._has_note(token):
        continue
    return token, display
return None, None

No randomness, no extra ranking logic.

⸻

4. Question shape: NO templates, NO “What is X?”

Very important behavioral constraint:
	•	SchoolQuestion.text must remain just "{display}?"
Example: "London?", "Mars?", etc.
	•	Do NOT change it to "What is London?" or any other template.
	•	Do NOT add language-specific paraphrases or teaching phrases.
	•	The School is allowed to echo the word and nothing more.
It is forbidden to start injecting teacher-like phrases.

So this is correct and must stay:

return SchoolQuestion(
    token=token,
    display=display,
    text=f"{display}?",
)

Any change to this shape is out of scope and not allowed.

⸻

5. Regex parsing for forms: keep it minimal

In _parse_and_store_forms we only support English patterns for School v1:
	•	"X is the capital of Y" → entities + capital_of
	•	"It is a city/country/planet" → entity kind

You may:
	•	Clean up the code to only keep these patterns.
	•	Ensure they use case-insensitive matching where appropriate.
	•	Reuse the persistent connection (self._conn) and follow the same error-handling style as in section 1.

You must NOT:
	•	Add new languages, new verbose templates, or a bunch of new forms.
	•	Introduce any new tables.
	•	Invent a larger ontology.

The point is to keep it as a tiny, explicit, English-only scaffold.

⸻

6. Decay logic: safe transaction, same semantics

For _decay_relations(now):
	•	Use self._conn instead of a fresh connection.
	•	Wrap the whole read–update–delete loop in a single transaction with proper error handling (as described above).
	•	Keep the existing semantics:
	•	confidence *= 0.99 ** days_ago
	•	delete relations where confidence < 0.1.

Do not introduce new fields or metrics. Just make the existing logic safer and atomic.

⸻

7. Tests and final check
	•	Run the existing test suite for leo (whatever is already set up in this repo).
	•	If you add tests, only add:
	•	Small tests for:
	•	MAX_NOTE_LEN truncation behavior,
	•	_pick_new_token skip-when-note-exists semantics,
	•	basic _parse_and_store_forms path for "X is the capital of Y".
	•	Do not build a large new test framework, do not introduce fixtures that change leo’s architecture.

When done, keep the diff as small and local as possible:
	•	Only school.py (and maybe a small test_school.py or equivalent test file) should change.

