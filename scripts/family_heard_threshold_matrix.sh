#!/usr/bin/env bash
# A.131: replay the three A.130 lives with pairwise heard evidence on/off.
set -Eeuo pipefail

trap 'rc=$?; printf "family-heard-threshold matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-family-heard-threshold-$STAMP}"
CASES="${LEO_FAMILY_HEARD_THRESHOLD_NATURAL_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
A130="${LEO_FAMILY_HEARD_THRESHOLD_A130:-$ROOT/scripts/presence_surface_boundary_expected.tsv}"
EXPECTED="${LEO_FAMILY_HEARD_THRESHOLD_EXPECTED:-$ROOT/scripts/family_heard_threshold_expected.tsv}"
PLAN_ONLY="${LEO_FAMILY_HEARD_THRESHOLD_PLAN_ONLY:-0}"
VERIFY="${LEO_FAMILY_HEARD_THRESHOLD_VERIFY:-1}"

[ -s "$CASES" ] || { printf 'missing frozen natural cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$A130" ] || { printf 'missing A.130 frozen replay: %s\n' "$A130" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_FAMILY_HEARD_THRESHOLD_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_FAMILY_HEARD_THRESHOLD_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.131 frozen replay: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\tfamily_heard_threshold\n'
    printf 'control\t0\n'
    printf 'candidate\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.131 family heard threshold plan: %s\n' "$OUT"
    exit 0
fi

LEO_FAMILY_HEARD_THRESHOLD_VERIFY="$VERIFY" \
    "$ROOT/scripts/family_heard_threshold_anatomy.sh" \
    "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\tfamily_heard_threshold\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta130_transcript_exact\ta130_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm threshold; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        a130_row="$(awk -F '\t' -v life="$life" '$1 == "candidate" && $2 == life {print; found++} END {if (found != 1) exit 2}' "$A130")"
        IFS=$'\t' read -r _a130_arm _a130_life _a130_seed _a130_boundary a130_transcript a130_state _a130_open _a130_questions _a129_tx _a129_state <<< "$a130_row"
        [ "$seed" = "$_a130_seed" ] || { printf 'A.130 seed drift: %s\n' "$life" >&2; exit 2; }

        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.131 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION=1 \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=1 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=1 \
            LEO_NATURAL_TWO_GLYPH_LEARNING=1 \
            LEO_NATURAL_NEGATIVE_FAMILY=1 \
            LEO_NATURAL_RECIPROCAL_S_FAMILY=1 \
            LEO_NATURAL_PRESENCE_SURFACE_BOUNDARY=1 \
            LEO_NATURAL_FAMILY_HEARD_THRESHOLD="$threshold" \
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
        [ "$transcript_sha" != "$a130_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a130_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$threshold" \
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
        printf 'A.131 frozen natural replay drift\n' >&2
        exit 2
    }
fi

cat "$OUT/natural.tsv"
printf 'result\tfamily-heard-threshold-natural-exact\n'
printf 'A.131 family heard threshold matrix: %s\n' "$OUT"
