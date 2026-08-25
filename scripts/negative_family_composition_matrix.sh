#!/usr/bin/env bash
# A.128: replay the three A.127 lives with and without negative-family composition.
set -Eeuo pipefail

trap 'rc=$?; printf "negative family composition matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-negative-family-composition-$STAMP}"
CASES="${LEO_NEGATIVE_FAMILY_COMPOSITION_NATURAL_CASES:-$ROOT/scripts/natural_life_second_generation_frozen.tsv}"
A127="${LEO_NEGATIVE_FAMILY_COMPOSITION_A127:-$ROOT/scripts/two_glyph_learned_meaning_expected.tsv}"
EXPECTED="${LEO_NEGATIVE_FAMILY_COMPOSITION_EXPECTED:-$ROOT/scripts/negative_family_composition_expected.tsv}"
PLAN_ONLY="${LEO_NEGATIVE_FAMILY_COMPOSITION_PLAN_ONLY:-0}"
VERIFY="${LEO_NEGATIVE_FAMILY_COMPOSITION_VERIFY:-1}"

[ -s "$CASES" ] || { printf 'missing frozen natural cases: %s\n' "$CASES" >&2; exit 2; }
[ -s "$A127" ] || { printf 'missing A.127 frozen replay: %s\n' "$A127" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_NEGATIVE_FAMILY_COMPOSITION_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ "$VERIFY" = 1 ] || { printf 'LEO_NEGATIVE_FAMILY_COMPOSITION_VERIFY must be 0 or 1\n' >&2; exit 2; }
[ "$VERIFY" = 0 ] || [ -s "$EXPECTED" ] || { printf 'missing A.128 frozen replay: %s\n' "$EXPECTED" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

{
    printf 'arm\tnegative_family\n'
    printf 'control\t0\n'
    printf 'candidate\t1\n'
} > "$OUT/plan.tsv"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.128 negative family composition plan: %s\n' "$OUT"
    exit 0
fi

LEO_NEGATIVE_FAMILY_COMPOSITION_VERIFY="$VERIFY" \
    "$ROOT/scripts/negative_family_composition_anatomy.sh" \
    "$OUT/anatomy" > "$OUT/anatomy.out"

printf 'arm\tlife\tseed\tnegative_family\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta127_transcript_exact\ta127_state_exact\n' > "$OUT/natural.tsv"
while IFS=$'\t' read -r arm negative; do
    [ "$arm" != arm ] || continue
    while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
        [ "$life" != life ] || continue
        fixture_path="$ROOT/$fixture"
        [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
        [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
            printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
        }
        a127_row="$(awk -F '\t' -v life="$life" '$1 == "candidate" && $2 == life {print; found++} END {if (found != 1) exit 2}' "$A127")"
        IFS=$'\t' read -r _a127_arm _a127_life _a127_seed _a127_pair a127_transcript a127_state _a127_open _a127_questions _a126_tx _a126_state <<< "$a127_row"
        [ "$seed" = "$_a127_seed" ] || { printf 'A.127 seed drift: %s\n' "$life" >&2; exit 2; }

        destination="$OUT/lives/$arm/$life"
        LEO_NATURAL_REPLAY_FILE="$fixture_path" \
            LEO_NATURAL_PHASE=A.128 LEO_NATURAL_LIFE="$life" \
            LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" \
            LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OFFERED_ANSWER_EXPANSION=1 \
            LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=1 \
            LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=1 \
            LEO_NATURAL_TWO_GLYPH_LEARNING=1 \
            LEO_NATURAL_NEGATIVE_FAMILY="$negative" \
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
        [ "$transcript_sha" != "$a127_transcript" ] || transcript_exact=true
        [ "$state_sha" != "$a127_state" ] || state_exact=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$arm" "$life" "$seed" "$negative" \
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
        printf 'A.128 frozen natural replay drift\n' >&2
        exit 2
    }
fi

cat "$OUT/natural.tsv"
printf 'result\tnegative-family-composition-natural-exact\n'
printf 'A.128 negative family composition matrix: %s\n' "$OUT"
