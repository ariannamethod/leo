#!/usr/bin/env python3
"""
decay_monitor.py - Track contamination decay over time.

Run daily to check if sticky phrases are fading from Leo's speech.

Usage:
    python tests/decay_monitor.py

Musketeers collaboration - Option D monitoring tool
"""

import sqlite3
import json
from datetime import datetime
from pathlib import Path

STICKY_PHRASES = [
    "soft hand on my shoulder",
    "favorite song plays",
    "feather brushing against",
    "rustle of leaves in the wind",
    "warm and reassuring",
    "wrapping around me",
    "gentle hug",
    "whispers secrets",
    "like a soft cloud",
    "dancing around you",
]

def check_snapshots(db_path: str = "state/leo.sqlite3") -> dict:
    """Count snapshots containing sticky phrases."""
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    results = {}
    for phrase in STICKY_PHRASES:
        cur.execute(
            "SELECT COUNT(*) FROM snapshots WHERE text LIKE ?",
            (f"%{phrase}%",)
        )
        results[phrase] = cur.fetchone()[0]

    cur.execute("SELECT COUNT(*) FROM snapshots")
    results["total_snapshots"] = cur.fetchone()[0]

    conn.close()
    return results

def check_episodes(db_path: str = "state/leo_rag.sqlite3") -> dict:
    """Count episodes containing sticky phrases."""
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    results = {}
    for phrase in STICKY_PHRASES:
        cur.execute(
            "SELECT COUNT(*) FROM episodes WHERE prompt LIKE ? OR reply LIKE ?",
            (f"%{phrase}%", f"%{phrase}%")
        )
        results[phrase] = cur.fetchone()[0]

    cur.execute("SELECT COUNT(*) FROM episodes")
    results["total_episodes"] = cur.fetchone()[0]

    conn.close()
    return results

def main():
    """Run decay monitoring check."""
    timestamp = datetime.now().isoformat()

    print(f"\n{'='*70}")
    print(f"DECAY MONITOR - {timestamp}")
    print('='*70)

    print("\n📊 SNAPSHOTS (leo.sqlite3):")
    snapshots = check_snapshots()
    for phrase, count in snapshots.items():
        if phrase != "total_snapshots":
            status = "✅" if count == 0 else "❌"
            print(f"  {status} '{phrase}': {count}")
    print(f"  Total snapshots: {snapshots['total_snapshots']}")

    print("\n📊 EPISODES (leo_rag.sqlite3):")
    episodes = check_episodes()
    for phrase, count in episodes.items():
        if phrase != "total_episodes":
            status = "✅" if count == 0 else "❌"
            print(f"  {status} '{phrase}': {count}")
    print(f"  Total episodes: {episodes['total_episodes']}")

    # Calculate contamination score
    total_contaminated = sum(
        v for k, v in snapshots.items() if k != "total_snapshots"
    ) + sum(
        v for k, v in episodes.items() if k != "total_episodes"
    )

    print(f"\n🎯 CONTAMINATION SCORE: {total_contaminated}")
    if total_contaminated == 0:
        print("✅ CLEAN! Field is decontaminated.")
    elif total_contaminated < 10:
        print("⚠️ LOW - Continue monitoring.")
    else:
        print("❌ HIGH - Consider additional cleanup.")

    print('='*70 + '\n')

    # Save to log file for tracking over time
    log_file = Path("tests/decay_log.jsonl")
    log_entry = {
        "timestamp": timestamp,
        "snapshots": snapshots,
        "episodes": episodes,
        "contamination_score": total_contaminated,
    }

    with open(log_file, "a") as f:
        f.write(json.dumps(log_entry) + "\n")

    print(f"📝 Log saved to: {log_file}")

if __name__ == "__main__":
    main()
