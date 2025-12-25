#!/usr/bin/env python3
"""
QUARANTINE TEST RUNNER

Runs observation session with fresh Leo state WITHOUT README bootstrap.

This tests the hypothesis that verbal tics come from README pollution
rather than SANTACLAUS feedback loops.
"""

import os
import sys
import sqlite3
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

# CRITICAL: Override leo.DB_PATH BEFORE importing leo
import leo
quarantine_db = Path(__file__).parent.parent / "state" / "leo_quarantine.sqlite3"
leo.DB_PATH = quarantine_db

print(f"[quarantine-runner] Using DB: {quarantine_db}")
print(f"[quarantine-runner] README bootstrap: SKIPPED (flag set in DB)")
print()

# Now import heyleogpt_gpt (it will use overridden DB_PATH)
from tests import heyleogpt_gpt

# Check DB exists
if not quarantine_db.exists():
    print("[ERROR] Quarantine DB not found!")
    print("Run: python3 tests/quarantine_test.py first")
    sys.exit(1)

# Verify README flag is set
conn = sqlite3.connect(str(quarantine_db))
cur = conn.cursor()
cur.execute("SELECT value FROM meta WHERE key = 'readme_bootstrap_done'")
row = cur.fetchone()
conn.close()

if not row or row[0] != "1":
    print("[ERROR] README bootstrap flag not set in quarantine DB!")
    sys.exit(1)

print("[quarantine-runner] ✓ Verified: README bootstrap skipped")
print()

# Run observation
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run quarantine observation test")
    parser.add_argument(
        "--topics",
        default="tests/topics_quarantine_short.json",
        help="Topics JSON file (default: short quarantine test)"
    )
    args = parser.parse_args()

    print(f"[quarantine-runner] Topics: {args.topics}")
    print(f"[quarantine-runner] Starting observation...")
    print("=" * 70)
    print()

    # Set API key from environment or fallback
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("[ERROR] OPENAI_API_KEY not set")
        sys.exit(1)

    # Run observer (will use leo.DB_PATH which we overrode)
    observer = heyleogpt_gpt.HeyLeoGPTObserver(api_key=api_key, topics_path=args.topics)
    observer.run_all_conversations()

    print()
    print("=" * 70)
    print("[quarantine-runner] Test complete!")
    print()
    print("CHECK FOR VERBAL TICS:")
    print('  - "Sometimes he brings one back, like a gift..."')
    print('  - "He remembers leo\'s brightest, most resonant replies"')
    print('  - "Leo discovers what feels big or important..."')
    print()
    print("IF NO TICS → README pollution confirmed ✓")
    print("IF STILL TICS → Deeper problem exists")
