#!/usr/bin/env bash
# A.129: replay the three A.128 lives with and without the closed reciprocal final-s witness.
set -Eeuo pipefail

trap 'rc=$?; printf "reciprocal-s-family matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-reciprocal-s-family-$STAMP}"
CASES="${LEO_RECIPROCAL_S_FAMILY_NATURAL_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
A128="${LEO_RECIPROCAL_S_FAMILY_A128:-$ROOT/scripts/negative_family_composition_expected.tsv}"
EXPECTED="${LEO_RECIPROCAL_S_FAMILY_EXPECTED:-$ROOT/scripts/reciprocal_s_family_expected.tsv}"
PLAN_ONLY="${LEO_RECIPROCAL_S_FAMILY_PLAN_ONLY:-0}"
VERIFY="${LEO_RECIPROCAL_S_FAMILY_VERIFY:-1}"

[ -s "$CASES" ] || { printf 'missing frozen natural cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$A128" ] || { printf 'missing A.128 frozen replay: %s\n' "$A128" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_RECIPROCAL_S_FAMILY_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_RECIPROCAL_S_FAMILY_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.129 frozen replay: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\treciprocal_s_family\n'
    printf 'control\t0\n'
    printf 'candidate\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.129 reciprocal final-s family plan: %s\n' "$OUT"
    exit 0
fi

LEO_RECIPROCAL_S_FAMILY_VERIFY="$VERIFY" \
    "$ROOT/scripts/reciprocal_s_family_anatomy.sh" \
    "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\treciprocal_s_family\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta128_transcript_exact\ta128_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm reciprocal; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        a128_row="$(awk -F '\t' -v life="$life" '$1 == "candidate" && $2 == life {print; found++} END {if (found != 1) exit 2}' "$A128")"
        IFS=$'\t' read -r _a128_arm _a128_life _a128_seed _a128_negative a128_transcript a128_state _a128_open _a128_questions _a127_tx _a127_state <<< "$a128_row"
        [ "$seed" = "$_a128_seed" ] || { printf 'A.128 seed drift: %s\n' "$life" >&2; exit 2; }

        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.129 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION=1 \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=1 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=1 \
            LEO_NATURAL_TWO_GLYPH_LEARNING=1 \
            LEO_NATURAL_NEGATIVE_FAMILY=1 \
            LEO_NATURAL_RECIPROCAL_S_FAMILY="$reciprocal" \
            LEO_NATURAL_PRESENCE_SURFACE_BOUNDARY=0 \
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
        [ "$transcript_sha" != "$a128_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a128_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$reciprocal" \
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
        printf 'A.129 frozen natural replay drift\n' >&2
        exit 2
    }
fi

cat "$OUT/natural.tsv"
printf 'result\treciprocal-s-family-natural-exact\n'
printf 'A.129 reciprocal final-s family matrix: %s\n' "$OUT"
