#!/usr/bin/env bash
# A.130: replay all three A.129 lives with and without exact displayed-word presence.
set -Eeuo pipefail

trap 'rc=$?; printf "presence-surface-boundary matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-presence-surface-boundary-$STAMP}"
CASES="${LEO_PRESENCE_SURFACE_BOUNDARY_NATURAL_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
A129="${LEO_PRESENCE_SURFACE_BOUNDARY_A129:-$ROOT/scripts/reciprocal_s_family_expected.tsv}"
EXPECTED="${LEO_PRESENCE_SURFACE_BOUNDARY_EXPECTED:-$ROOT/scripts/presence_surface_boundary_expected.tsv}"
PLAN_ONLY="${LEO_PRESENCE_SURFACE_BOUNDARY_PLAN_ONLY:-0}"
VERIFY="${LEO_PRESENCE_SURFACE_BOUNDARY_VERIFY:-1}"

[ -s "$CASES" ] || { printf 'missing frozen natural cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$A129" ] || { printf 'missing A.129 frozen replay: %s\n' "$A129" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_PRESENCE_SURFACE_BOUNDARY_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_PRESENCE_SURFACE_BOUNDARY_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.130 frozen replay: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\tpresence_surface_boundary\n'
    printf 'control\t0\n'
    printf 'candidate\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.130 presence surface boundary plan: %s\n' "$OUT"
    exit 0
fi

LEO_PRESENCE_SURFACE_BOUNDARY_VERIFY="$VERIFY" \
    "$ROOT/scripts/presence_surface_boundary_anatomy.sh" \
    "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\tpresence_surface_boundary\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta129_transcript_exact\ta129_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm boundary; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        a129_row="$(awk -F '\t' -v life="$life" '$1 == "candidate" && $2 == life {print; found++} END {if (found != 1) exit 2}' "$A129")"
        IFS=$'\t' read -r _a129_arm _a129_life _a129_seed _a129_reciprocal a129_transcript a129_state _a129_open _a129_questions _a128_tx _a128_state <<< "$a129_row"
        [ "$seed" = "$_a129_seed" ] || { printf 'A.129 seed drift: %s\n' "$life" >&2; exit 2; }

        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.130 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION=1 \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=1 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=1 \
            LEO_NATURAL_TWO_GLYPH_LEARNING=1 \
            LEO_NATURAL_NEGATIVE_FAMILY=1 \
            LEO_NATURAL_RECIPROCAL_S_FAMILY=1 \
            LEO_NATURAL_PRESENCE_SURFACE_BOUNDARY="$boundary" \
            LEO_NATURAL_FAMILY_HEARD_THRESHOLD=0 \
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
        [ "$transcript_sha" != "$a129_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a129_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$boundary" \
            "$transcript_sha" "$state_sha" "$open" "$questions" \
            "$transcript_exact" "$state_exact" >> "$OUT/natural.tsv"
    done < "$CASES"
done < "$OUT/plan.tsv"

awk -F '\t' '
    NR == 1 { next }
    NF != 10 { exit 2 }
    { rows++; exact += ($9 == "true" && $10 == "true") }
    END { if (rows != 6 || exact != 6) exit 2 }
' "$OUT/natural.tsv"

if [ "$VERIFY" = 1 ]; then
    cmp -s "$EXPECTED" "$OUT/natural.tsv" || {
        diff -u "$EXPECTED" "$OUT/natural.tsv" >&2 || true
        printf 'A.130 frozen natural replay drift\n' >&2
        exit 2
    }
fi

cat "$OUT/natural.tsv"
printf 'result\tpresence-surface-boundary-natural-exact\n'
printf 'A.130 presence surface boundary matrix: %s\n' "$OUT"
