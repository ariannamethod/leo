#!/usr/bin/env bash
# A.133: replay the frozen A.132 meal with exactly-two-edge composition off/on.
set -Eeuo pipefail

trap 'rc=$?; printf "two-layer family composition matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-two-layer-family-composition-$STAMP}"
PLAN="${LEO_TWO_LAYER_FAMILY_COMPOSITION_PLAN:-$ROOT/scripts/two_layer_family_composition_natural_plan.tsv}"
EXPECTED="${LEO_TWO_LAYER_FAMILY_COMPOSITION_NATURAL:-$ROOT/scripts/two_layer_family_composition_natural.tsv}"
FROZEN="${LEO_TWO_LAYER_FAMILY_COMPOSITION_A132:-$ROOT/scripts/responsive_honest_wonder_a132_frozen.tsv}"
PROMPTS="$ROOT/scripts/fixtures/responsive_honest_wonder_a132_meal.txt"
PLAN_ONLY="${LEO_TWO_LAYER_FAMILY_COMPOSITION_PLAN_ONLY:-0}"
VERIFY="${LEO_TWO_LAYER_FAMILY_COMPOSITION_VERIFY:-1}"

[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_TWO_LAYER_FAMILY_COMPOSITION_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_TWO_LAYER_FAMILY_COMPOSITION_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ -s "$PLAN" ] && [ -s "$FROZEN" ] && [ -s "$PROMPTS" ] || { printf 'missing frozen A.133 input\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing frozen A.133 receipt: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"
cp "$PLAN" "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.133 two-layer family composition plan: %s\n' "$OUT"
    exit 0
fi

IFS=$'\t' read -r life seed fixture _prefix _api prompts_sha \
    a132_transcript a132_state _async_tx _async_state _mismatches < <(
        awk -F '\t' 'NR == 2 { print }' "$FROZEN")
[ "$life" = meal ] && [ "$seed" = 617 ] && \
    [ "$fixture" = scripts/fixtures/responsive_honest_wonder_a132_meal.txt ]
[ "$(shasum -a 256 "$PROMPTS" | awk '{print $1}')" = "$prompts_sha" ]

LEO_TWO_LAYER_FAMILY_COMPOSITION_VERIFY="$VERIFY" \
    "$ROOT/scripts/two_layer_family_composition_anatomy.sh" \
    "$OUT/anatomy" > "$OUT/anatomy.out"

while IFS=$'\t' read -r arm composition; do
    [ "$arm" != arm ] || continue
    destination="$OUT/lives/$arm"
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.133 LEO_NATURAL_LIFE=meal \
        LEO_NATURAL_ARM=replay LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Continue the exact A.131 meal fork.' \
        LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION="$composition" \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" \
        > "$OUT/lives/$arm.out"
done < "$OUT/plan.tsv"

mismatch_turns="$(paste \
    <(jq -r '[.turn,.leo] | @tsv' "$OUT/lives/control/dialogue.jsonl") \
    <(jq -r '[.turn,.leo] | @tsv' "$OUT/lives/candidate/dialogue.jsonl") |
    awk -F '\t' '$2 != $4 { print $1 }' | paste -sd, -)"
[ -n "$mismatch_turns" ] || mismatch_turns=none

printf 'arm\tlife\tseed\ttwo_layer_family_composition\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\treply_mismatch_turns\ta132_transcript_exact\ta132_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm composition; do
    [ "$arm" != arm ] || continue
    destination="$OUT/lives/$arm"
    transcript_sha="$(shasum -a 256 "$destination/visible_transcript.txt" | awk '{print $1}')"
    state_sha="$(shasum -a 256 "$destination/state/leo.state" | awk '{print $1}')"
    open="$(awk -F '\t' '$1 == "wonder_open_turns" {print $2}' "$destination/summary.txt")"
    questions="$(jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
          "@" + (.turn | tostring))] | join(",")
    ' "$destination/dialogue.jsonl")"
    [ -n "$questions" ] || questions=none
    arm_mismatches=none
    [ "$arm" = control ] || arm_mismatches="$mismatch_turns"
    transcript_exact=false; state_exact=false
    [ "$transcript_sha" != "$a132_transcript" ] || transcript_exact=true
    [ "$state_sha" != "$a132_state" ] || state_exact=true
    printf '%s\tmeal\t617\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$arm" "$composition" "$transcript_sha" "$state_sha" "$open" \
        "$questions" "$arm_mismatches" "$transcript_exact" "$state_exact" \
        >> "$OUT/natural.tsv"
done < "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 11 { exit 2 }
    $1 == "control" {
        control++
        if ($4 != 0 || $10 != "true" || $11 != "true") exit 2
    }
    $1 == "candidate" {
        candidate++
        if ($4 != 1 || $8 != "lentil@2" || $9 != "14,15,16,17" ||
            $10 != "false" || $11 != "false") exit 2
    }
    END { if (control != 1 || candidate != 1) exit 2 }
' "$OUT/natural.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/natural.tsv" || {
        diff -u "$EXPECTED" "$OUT/natural.tsv" >&2 || true
        printf 'A.133 frozen natural replay drift\n' >&2
        exit 2
    }
fi

cat "$OUT/natural.tsv"
printf 'result\ttwo-layer-family-composition-natural-exact\n'
printf 'A.133 two-layer family composition matrix: %s\n' "$OUT"
