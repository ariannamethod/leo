#!/usr/bin/env python3
"""
build_school_bootstrap.py — One-shot Genesis script

Builds a minimal conceptual geometry and saves it as JSON.
This is a one-time act. After that, raw datasets can be deleted.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Hardcoded seed (minimal geometry)
SEED_DATA = {
    "entities": [
        {"id": 1, "name": "Earth", "kind": "planet", "display_name": "Earth"},
        {"id": 2, "name": "France", "kind": "country", "display_name": "France"},
        {"id": 3, "name": "Paris", "kind": "city", "display_name": "Paris"},
        {"id": 4, "name": "United Kingdom", "kind": "country", "display_name": "United Kingdom"},
        {"id": 5, "name": "UK", "kind": "country", "display_name": "UK"},
        {"id": 6, "name": "London", "kind": "city", "display_name": "London"},
        {"id": 7, "name": "Germany", "kind": "country", "display_name": "Germany"},
        {"id": 8, "name": "Berlin", "kind": "city", "display_name": "Berlin"},
        {"id": 9, "name": "Russia", "kind": "country", "display_name": "Russia"},
        {"id": 10, "name": "Moscow", "kind": "city", "display_name": "Moscow"},
    ],
    "relations": [
        {"subject": "Paris", "relation": "capital_of", "object": "France"},
        {"subject": "London", "relation": "capital_of", "object": "United Kingdom"},
        {"subject": "Berlin", "relation": "capital_of", "object": "Germany"},
        {"subject": "Moscow", "relation": "capital_of", "object": "Russia"},
    ],
    "examples": [
        "We live on planet Earth.",
        "Earth is a planet.",
        "France is a country.",
        "Paris is the capital of France.",
        "The United Kingdom is a country.",
        "London is the capital of the United Kingdom.",
        "Germany is a country.",
        "Berlin is the capital of Germany.",
        "Russia is a country.",
        "Moscow is the capital of Russia.",
        "2 + 2 = 4.",
        "3 * 5 = 15.",
        "10 - 3 = 7.",
        "35 / 7 = 5.",
    ],
}


def build_bootstrap(output_path: Path) -> None:
    """Build bootstrap JSON from seed data."""
    # Convert relations to use entity names (will be resolved at load time)
    relations = []
    for rel in SEED_DATA["relations"]:
        relations.append({
            "subject": rel["subject"],
            "relation": rel["relation"],
            "object": rel["object"],
        })
    
    bootstrap = {
        "entities": SEED_DATA["entities"],
        "relations": relations,
        "examples": SEED_DATA["examples"],
    }
    
    # Validate size limits
    if len(bootstrap["entities"]) > 50:
        print("Warning: More than 50 entities in bootstrap", file=sys.stderr)
    
    if len(bootstrap["relations"]) > 100:
        print("Warning: More than 100 relations in bootstrap", file=sys.stderr)
    
    # Write JSON
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(bootstrap, f, indent=2, ensure_ascii=False)
    
    print(f"Bootstrap created: {output_path}")
    print(f"  Entities: {len(bootstrap['entities'])}")
    print(f"  Relations: {len(bootstrap['relations'])}")
    print(f"  Examples: {len(bootstrap['examples'])}")


def main():
    """Main entry point."""
    # Determine output path
    script_dir = Path(__file__).parent.parent
    output_path = script_dir / "state" / "school_bootstrap.json"
    
    try:
        build_bootstrap(output_path)
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

