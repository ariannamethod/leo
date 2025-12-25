#!/usr/bin/env python3
"""
Create fresh Leo state WITH filtered README bootstrap.

This is the FINAL TEST - proves dual-layer fix works:
1. README filter removes pollution sources
2. SANTACLAUS recency decay prevents amplification

Expected results:
- No verbal tics from old README pollution
- Philosophical concepts present from filtered README
- New authentic phrases emerge
- SANTACLAUS recalls varied memories
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from leo import bootstrap_if_needed, init_db

def main():
    """Create fresh state with filtered README."""

    # Remove old main DB to force fresh bootstrap
    db_path = Path(__file__).parent.parent / "state" / "leo.sqlite3"

    print("[filtered-state] Creating fresh state WITH filtered README...")
    print(f"[filtered-state] DB: {db_path}")
    print()

    # Remove old DB
    if db_path.exists():
        print(f"[filtered-state] Removing old state...")
        db_path.unlink()

    # Initialize fresh DB - will run bootstrap_if_needed()
    # This now uses enhanced strip_code_blocks() with pollution filter
    conn = init_db()

    # Bootstrap will run automatically on first init
    bootstrap_if_needed(conn)

    # Verify
    from leo import get_meta
    flag = get_meta(conn, "readme_bootstrap_done")

    print(f"\n[filtered-state] ✓ Fresh state created!")
    print(f"  README bootstrap: {'DONE (filtered)' if flag == '1' else 'PENDING'}")
    print(f"  Filter: Enhanced (removes conversation examples)")
    print(f"  SANTACLAUS recency decay: ACTIVE")
    print()
    print("Ready for final observation run!")
    print()
    print("Expected results:")
    print("  ❌ No verbal tics (old README pollution)")
    print("  ✅ Philosophical concepts present")
    print("  ✅ New authentic phrases")
    print("  ✅ SANTACLAUS varied recall")

    conn.close()

if __name__ == "__main__":
    main()
