#!/bin/bash
# make_neoleo.sh -- Assemble neoleo.c from leo.c + leo.h
#
# neoleo.c = complete organism in a single C file
# DNA arrays embedded inline, no external headers needed
#
# Usage: ./tools/make_neoleo.sh [leo.h path]
#        Output: neoleo.c in current directory

set -e

LEO_H="${1:-leo.h}"
LEO_C="leo.c"
OUT="neoleo.c"

if [ ! -f "$LEO_C" ]; then
    echo "error: $LEO_C not found (run from project root)" >&2
    exit 1
fi

if [ ! -f "$LEO_H" ]; then
    echo "error: $LEO_H not found (run extract_dna.go first)" >&2
    exit 1
fi

echo "[neoleo] assembling $OUT from $LEO_C + $LEO_H"

{
    cat <<'HEADER'
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

    # Insert leo.h contents (skip guards and header comments)
    grep -v '^#ifndef LEO_DNA_H' "$LEO_H" | \
    grep -v '^#define LEO_DNA_H' | \
    grep -v '^#endif' | \
    grep -v '^ \* leo\.h' | \
    grep -v '^ \* Auto-generated' | \
    grep -v '^ \* DO NOT EDIT' | \
    grep -v '^ \* Arianna' | \
    grep -v 'θ'

    cat <<'SEPARATOR'

/* ==================================================================
 * LEO -- Language Emergent Organism
 * ================================================================ */

SEPARATOR

    # Insert leo.c, removing the #include "leo.h" / "leo_dna.h" line
    grep -v '#include "leo.h"' "$LEO_C" | \
    grep -v '#include "leo_dna.h"'

} > "$OUT"

SIZE=$(wc -c < "$OUT")
LINES=$(wc -l < "$OUT")

echo "[neoleo] done: $OUT ($LINES lines, $SIZE bytes)"
echo "[neoleo] build: cc neoleo.c -O2 -lm -lsqlite3 -lpthread -o neoleo"
