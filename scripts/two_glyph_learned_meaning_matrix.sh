#!/usr/bin/env bash
# A.127: replay the three A.125 lives with and without two-glyph learning.
set -Eeuo pipefail

trap 'rc=$?; printf "two-glyph learned-meaning matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-two-glyph-learned-meaning-$STAMP}"
CASES="${LEO_TWO_GLYPH_LEARNED_MEANING_NATURAL_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
A126="${LEO_TWO_GLYPH_LEARNED_MEANING_A126:-$ROOT/scripts/plural_answer_capacity_expected.tsv}"
EXPECTED="${LEO_TWO_GLYPH_LEARNED_MEANING_EXPECTED:-$ROOT/scripts/two_glyph_learned_meaning_expected.tsv}"
PLAN_ONLY="${LEO_TWO_GLYPH_LEARNED_MEANING_PLAN_ONLY:-0}"
VERIFY="${LEO_TWO_GLYPH_LEARNED_MEANING_VERIFY:-1}"

[ -s "$CASES" ] || { printf 'missing frozen natural cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$A126" ] || { printf 'missing A.126 frozen replay: %s\n' "$A126" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_TWO_GLYPH_LEARNED_MEANING_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_TWO_GLYPH_LEARNED_MEANING_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.127 frozen replay: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\ttwo_glyph_learning\n'
    printf 'control\t0\n'
    printf 'candidate\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.127 two-glyph learned-meaning plan: %s\n' "$OUT"
    exit 0
fi

LEO_TWO_GLYPH_LEARNED_MEANING_VERIFY="$VERIFY" \
    "$ROOT/scripts/two_glyph_learned_meaning_anatomy.sh" \
    "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\ttwo_glyph_learning\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta126_transcript_exact\ta126_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm paired; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        a126_row="$(awk -F '\t' -v life="$life" '$1 == "candidate" && $2 == life {print; found++} END {if (found != 1) exit 2}' "$A126")"
        IFS=$'\t' read -r _a126_arm _a126_life _a126_seed _a126_unique a126_transcript a126_state _a126_open _a126_questions _a125_tx _a125_state <<< "$a126_row"
        [ "$seed" = "$_a126_seed" ] || { printf 'A.126 seed drift: %s\n' "$life" >&2; exit 2; }

        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.127 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION=1 \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=1 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=1 \
            LEO_NATURAL_TWO_GLYPH_LEARNING="$paired" \
            LEO_NATURAL_NEGATIVE_FAMILY=0 \
            LEO_NATURAL_RECIPROCAL_S_FAMILY=0 \
            LEO_NATURAL_PRESENCE_SURFACE_BOUNDARY=0 \
            LEO_NATURAL_FAMILY_HEARD_THRESHOLD=0 \
            LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=0 \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/lives/$arm-$life.out"
        transcript_sha="$(shasum -a 256 "$destination/visible_transcript.txt" | awk '{print $1}')"
        state_sha="$(shasum -a 256 "$destination/state/leo.state" | awk '{print $1}')"
        open="$(awk -F '\t' '$1 == "wonder_open_turns" {print $2}' "$destination/summary.txt")"
        questions="$(jq -sr '
            [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
             ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
              "@" + (.turn | tostring))] | join(",")
        ' "$destination/dialogue.jsonl")"
        transcript_exact=false; state_exact=false
        [ "$transcript_sha" != "$a126_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a126_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$paired" \
            "$transcript_sha" "$state_sha" "$open" "$questions" \
            "$transcript_exact" "$state_exact" >> "$OUT/natural.tsv"
    done < "$CASES"
done < "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 10 { exit 2 }
    $1 == "control" { rows++; exact += ($9 == "true" && $10 == "true") }
    END { if (rows != 3 || exact != 3) exit 2 }
' "$OUT/natural.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/natural.tsv" || {
        diff -u "$EXPECTED" "$OUT/natural.tsv" >&2 || true
        printf 'A.127 frozen natural replay drift\n' >&2
        exit 2
    }
fi

cat "$OUT/natural.tsv"
printf 'result\ttwo-glyph-learned-meaning-exact\n'
printf 'A.127 two-glyph learned-meaning matrix: %s\n' "$OUT"
