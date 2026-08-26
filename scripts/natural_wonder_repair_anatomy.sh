#!/usr/bin/env bash
# A.119: replay the A.118 lives and separate four natural-Wonder boundaries.
set -Eeuo pipefail

trap 'rc=$?; printf "natural Wonder anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-wonder-anatomy-$STAMP}"
CASES="${LEO_NATURAL_WONDER_CASES:-$ROOT/scripts/natural_wonder_repair_cases.tsv}"
PLAN_ONLY="${LEO_NATURAL_PLAN_ONLY:-0}"
EXPECT_A118="${LEO_NATURAL_EXPECT_A118:-0}"
LEXICAL_FAMILY="${LEO_NATURAL_LEXICAL_FAMILY:-0}"
LEXICAL_ROLE="${LEO_NATURAL_LEXICAL_ROLE:-0}"
ANSWER_FOLLOWUP="${LEO_NATURAL_ANSWER_FOLLOWUP:-0}"

[ -s "$CASES" ] || { printf 'missing natural Wonder cases: %s\n' "$CASES" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_NATURAL_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$EXPECT_A118" = 0 ] || [ "$EXPECT_A118" = 1 ] || { printf 'LEO_NATURAL_EXPECT_A118 must be 0 or 1\n' >&2; exit 2; }
[ "$LEXICAL_FAMILY" = 0 ] || [ "$LEXICAL_FAMILY" = 1 ] || { printf 'LEO_NATURAL_LEXICAL_FAMILY must be 0 or 1\n' >&2; exit 2; }
[ "$LEXICAL_ROLE" = 0 ] || [ "$LEXICAL_ROLE" = 1 ] || { printf 'LEO_NATURAL_LEXICAL_ROLE must be 0 or 1\n' >&2; exit 2; }
[ "$ANSWER_FOLLOWUP" = 0 ] || [ "$ANSWER_FOLLOWUP" = 1 ] || { printf 'LEO_NATURAL_ANSWER_FOLLOWUP must be 0 or 1\n' >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

PLAN="$OUT/plan.tsv"
NATURAL="$OUT/natural.tsv"
ANATOMY="$OUT/anatomy.tsv"
BIN="$OUT/natural-wonder-fixture"

awk -F '\t' -v OFS='\t' '
    NR == 1 {
        if (NF != 8 || $1 != "life" || $2 != "seed" ||
            $3 != "fixture" || $4 != "prompts_sha256" ||
            $8 != "a118_questions") exit 2
        print
        next
    }
    NF != 8 || $1 !~ /^[a-z]+$/ || $2 !~ /^[0-9]+$/ ||
        $3 == "" || $4 !~ /^[0-9a-f]{64}$/ ||
        $5 !~ /^[0-9a-f]{64}$/ || $6 !~ /^[0-9a-f]{64}$/ ||
        $7 !~ /^[0-9]+$/ || $8 == "" || seen[$1]++ { exit 2 }
    { print; rows++ }
    END { if (rows != 3) exit 2 }
' "$CASES" > "$PLAN"

while IFS=$'\t' read -r life seed fixture prompts_sha transcript_sha state_sha open_turns questions; do
    [ "$life" != life ] || continue
    fixture_path="$ROOT/$fixture"
    [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
    actual_sha="$(shasum -a 256 "$fixture_path" | awk '{print $1}')"
    [ "$actual_sha" = "$prompts_sha" ] || { printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2; }
    [ "$(wc -l < "$fixture_path" | tr -d ' ')" -eq 24 ] || { printf 'fixture turn drift: %s\n' "$life" >&2; exit 2; }
done < "$PLAN"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.119 natural Wonder anatomy plan: %s\n' "$OUT"
    exit 0
fi

cc "$ROOT/scripts/natural_wonder_repair_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function -o "$BIN" -lpthread
"$BIN" > "$ANATOMY"

printf 'life\tseed\tprompts_sha256\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta118_transcript_exact\ta118_state_exact\n' > "$NATURAL"
while IFS=$'\t' read -r life seed fixture prompts_sha a118_transcript_sha a118_state_sha a118_open questions; do
    [ "$life" != life ] || continue
    destination="$OUT/lives/$life"
    LEO_NATURAL_REPLAY_FILE="$ROOT/$fixture" LEO_NATURAL_LIFE="$life" \
        LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_LEXICAL_FAMILY="$LEXICAL_FAMILY" \
        LEO_NATURAL_LEXICAL_ROLE="$LEXICAL_ROLE" \
        LEO_NATURAL_ANSWER_FOLLOWUP="$ANSWER_FOLLOWUP" \
        LEO_NATURAL_WONDER_REASK_REFERENCE=0 \
        LEO_NATURAL_OFFERED_ANSWER_EXPANSION=0 \
        LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=0 \
        LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=0 \
        LEO_NATURAL_TWO_GLYPH_LEARNING=0 \
        LEO_NATURAL_NEGATIVE_FAMILY=0 \
        LEO_NATURAL_RECIPROCAL_S_FAMILY=0 \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" > "$OUT/lives/$life.out"
    transcript_sha="$(shasum -a 256 "$destination/visible_transcript.txt" | awk '{print $1}')"
    state_sha="$(shasum -a 256 "$destination/state/leo.state" | awk '{print $1}')"
    open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' "$destination/summary.txt")"
    observed_questions="$(jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
          "@" + (.turn | tostring))] | join(",")
    ' "$destination/dialogue.jsonl")"
    transcript_exact=false
    state_exact=false
    [ "$transcript_sha" != "$a118_transcript_sha" ] || transcript_exact=true
    [ "$state_sha" != "$a118_state_sha" ] || state_exact=true
    if [ "$EXPECT_A118" = 1 ]; then
        [ "$transcript_exact" = true ] && [ "$state_exact" = true ] &&
            [ "$open" = "$a118_open" ] && [ "$observed_questions" = "$questions" ] || {
            printf 'A.118 natural witness drift: %s\n' "$life" >&2
            exit 1
        }
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$life" "$seed" "$prompts_sha" "$transcript_sha" "$state_sha" \
        "$open" "$observed_questions" "$transcript_exact" "$state_exact" >> "$NATURAL"
done < "$PLAN"

cat "$ANATOMY"
cat "$NATURAL"
printf 'result\tnatural-wonder-boundaries-separated\n'
printf 'A.119 natural Wonder anatomy: %s\n' "$OUT"
