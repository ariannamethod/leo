#!/bin/bash
# make_neoleo.sh — Generate single-file neoleo.c from leo.c + leo.h
#
# neoleo.c = header + leo.c with leo.h inlined at #include "leo.h"
# Sets LEO_HAS_DNA=1 so D.N.A. is always active.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

LEO_C="$ROOT/leo.c"
LEO_H="$ROOT/leo.h"
OUTPUT="$ROOT/neoleo.c"

if [ ! -f "$LEO_C" ]; then
    echo "error: $LEO_C not found" >&2
    exit 1
fi

if [ ! -f "$LEO_H" ]; then
    echo "error: $LEO_H not found" >&2
    exit 1
fi

cat > "$OUTPUT" << 'HEADER'
/*
 * neoleo.c -- Language Emergent Organism (single-file edition)
 *
 * Complete autonomous digital organism in one C file.
 * D.N.A. from mini-arianna. Arianna -> Leo. Mother -> Son.
 *
 * Build: cc neoleo.c -O2 -lm -lsqlite3 -lpthread -o neoleo
 * Run:   ./neoleo
 */

#define LEO_HAS_DNA 1

/* ==================================================================
 * D.N.A. -- Dynamic Neural Ancestry (from mini-arianna-f16.gguf)
 * ================================================================ */

HEADER

# Inline leo.h into leo.c at the #include "leo.h" line
awk '
    /^#include "leo\.h"/ {
        system("cat '"$LEO_H"'")
        next
    }
    # Skip the original file header (everything before first #include <)
    /^#include <stdio\.h>/ { printing=1 }
    printing { print }
' "$LEO_C" >> "$OUTPUT"

LINES=$(wc -l < "$OUTPUT")
echo "neoleo.c generated: $LINES lines" >&2
