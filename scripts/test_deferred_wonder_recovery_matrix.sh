#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-recovery-matrix-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/plan"
LEO_RECOVERY_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_recovery_matrix.sh" "$OUT" \
    > "$TMP/plan.out"

cmp -s "$OUT/plan.tsv" "$TMP/plan.out"
awk -F '\t' '
    NR == 1 {
        if ($1 != "cell" || $2 != "target" || $3 != "seed" ||
            $4 != "distractor" || $5 != "calm_turns" ||
            $6 != "cue_kind" || $7 != "cue_prompt")
            exit 1
        next
    }
    {
        cells++
        targets[$2]++
        seeds[$3]++
        calm[$5]++
        cues[$6]++
        target_calm_cue[$2 SUBSEP $5 SUBSEP $6]++
    }
    END {
        if (cells != 45 || length(targets) != 3 || length(seeds) != 3 ||
            length(calm) != 3 || length(cues) != 5 ||
            length(target_calm_cue) != 45)
            exit 1
        if (calm[0] != 15 || calm[2] != 15 || calm[8] != 15)
            exit 1
        for (key in targets) if (targets[key] != 15) exit 1
        for (key in seeds) if (seeds[key] != 15) exit 1
        for (key in cues) if (cues[key] != 9) exit 1
        for (key in target_calm_cue)
            if (target_calm_cue[key] != 1) exit 1
    }
' "$TMP/plan.out"

if LEO_RECOVERY_CALM_TURNS='0 nope 8' \
    LEO_RECOVERY_PLAN_ONLY=1 \
    "$ROOT/scripts/deferred_wonder_recovery_matrix.sh" "$TMP/bad-plan" \
    > "$TMP/bad.out" 2> "$TMP/bad.err"; then
    printf 'invalid calm-turn specification was accepted\n' >&2
    exit 1
fi
grep -Fq 'invalid calm-turn count: nope' "$TMP/bad.err"

printf 'deferred Wonder recovery matrix plan: ok\n'
