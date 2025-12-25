#!/usr/bin/env python3
"""
QUARANTINE TEST - README Bootstrap Pollution Hypothesis

Creates fresh Leo state WITHOUT README bootstrap to test if verbal tics
are caused by README pollution or something deeper.

HYPOTHESIS:
- README contains conversation examples: "Sometimes he brings one back..."
- strip_code_blocks() doesn't filter `leo>` prefixed lines
- Leo ingests these examples thinking they're HIS speech
- SANTACLAUS amplifies them → verbal tics

TEST:
- Fresh state WITHOUT README
- Short observation run
- Check: Do verbal tics still appear?

EXPECTED:
- NO tics → README pollution confirmed
- STILL tics → Deeper problem
"""

import sqlite3
import sys
import tempfile
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from leo import init_db, set_meta, EMBEDDED_BOOTSTRAP, ingest_text


def create_quarantine_state(db_path: Path) -> sqlite3.Connection:
    """
    Create fresh Leo state WITHOUT README bootstrap.

    Sets readme_bootstrap_done=1 flag BEFORE leo.py can read README.
    This prevents README pollution while keeping EMBEDDED_BOOTSTRAP.
    """
    print(f"[quarantine] Creating fresh state: {db_path}")

    # Create connection directly (init_db uses global DB_PATH)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # Initialize schema (copy from init_db logic)
    cur.execute("PRAGMA journal_mode=WAL")

    # Create tables
    cur.execute("""
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            token TEXT UNIQUE
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS bigrams (
            src_id INTEGER,
            dst_id INTEGER,
            count INTEGER,
            PRIMARY KEY (src_id, dst_id)
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS trigrams (
            first_id INTEGER,
            second_id INTEGER,
            third_id INTEGER,
            count INTEGER,
            PRIMARY KEY (first_id, second_id, third_id)
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS co_occurrence (
            word_id INTEGER,
            context_id INTEGER,
            count INTEGER,
            PRIMARY KEY (word_id, context_id)
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            origin TEXT,
            quality REAL,
            emotional REAL,
            created_at INTEGER,
            last_used_at INTEGER,
            use_count INTEGER DEFAULT 0,
            cluster_id INTEGER
        )
    """)

    conn.commit()

    # Ingest EMBEDDED_BOOTSTRAP (safe, small seed)
    print("[quarantine] Ingesting EMBEDDED_BOOTSTRAP only...")
    ingest_text(conn, EMBEDDED_BOOTSTRAP)

    # SET FLAG EARLY - prevent README bootstrap
    print("[quarantine] Setting readme_bootstrap_done=1 (SKIP README)")
    set_meta(conn, "readme_bootstrap_done", "1")

    conn.commit()
    print("[quarantine] Fresh state created WITHOUT README")

    return conn


def main():
    """Create quarantine test database."""

    # Use state directory but different filename
    state_dir = Path(__file__).parent.parent / "state"
    quarantine_db = state_dir / "leo_quarantine.sqlite3"

    # Remove old test DB if exists
    if quarantine_db.exists():
        print(f"[quarantine] Removing old test DB: {quarantine_db}")
        quarantine_db.unlink()

    # Create fresh quarantine state
    conn = create_quarantine_state(quarantine_db)

    # Verify flag is set
    from leo import get_meta
    flag = get_meta(conn, "readme_bootstrap_done")
    assert flag == "1", "Flag not set correctly!"

    # Count tokens (should be ONLY from EMBEDDED_BOOTSTRAP)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM tokens")
    token_count = cur.fetchone()[0]

    print(f"\n[quarantine] SUCCESS!")
    print(f"  DB path: {quarantine_db}")
    print(f"  Token count: {token_count} (EMBEDDED_BOOTSTRAP only)")
    print(f"  README bootstrap: SKIPPED ✓")
    print(f"\nReady for observation run with quarantine DB!")

    conn.close()


if __name__ == "__main__":
    main()
