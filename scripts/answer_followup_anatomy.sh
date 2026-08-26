#!/usr/bin/env bash
# A.122: replay A.121 and measure one bounded answer before a human question.
set -Eeuo pipefail

trap 'rc=$?; printf "answer-followup anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-answer-followup-anatomy-$STAMP}"
CASES="${LEO_ANSWER_FOLLOWUP_NATURAL_CASES:-$ROOT/scripts/answer_followup_natural_cases.tsv}"
PLAN_ONLY="${LEO_ANSWER_FOLLOWUP_PLAN_ONLY:-0}"
FOLLOWUP="${LEO_ANSWER_FOLLOWUP:-1}"
EXPECT="${LEO_ANSWER_FOLLOWUP_EXPECT:-none}"

[ -s "$CASES" ] || { printf 'missing answer-followup natural cases: %s\n' "$CASES" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_ANSWER_FOLLOWUP_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$FOLLOWUP" = 0 ] || [ "$FOLLOWUP" = 1 ] || { printf 'LEO_ANSWER_FOLLOWUP must be 0 or 1\n' >&2; exit 2; }
case "$EXPECT" in none|a121|a122) ;; *) printf 'LEO_ANSWER_FOLLOWUP_EXPECT must be none, a121, or a122\n' >&2; exit 2;; esac
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

PLAN="$OUT/plan.tsv"
NATURAL="$OUT/natural.tsv"
ANATOMY="$OUT/anatomy.tsv"
BIN="$OUT/answer-followup-fixture"

awk -F '\t' -v OFS='\t' '
    NR == 1 {
        if (NF != 12 || $1 != "life" || $2 != "seed" ||
            $3 != "fixture" || $4 != "prompts_sha256" ||
            $8 != "a121_questions" || $12 != "a122_questions") exit 2
        print; next
    }
    NF != 12 || $1 !~ /^[a-z]+$/ || $2 !~ /^[0-9]+$/ ||
        $3 == "" || $4 !~ /^[0-9a-f]{64}$/ ||
        $5 !~ /^[0-9a-f]{64}$/ || $6 !~ /^[0-9a-f]{64}$/ ||
        $7 !~ /^[0-9]+$/ || $8 == "" ||
        $9 !~ /^[0-9a-f]{64}$/ || $10 !~ /^[0-9a-f]{64}$/ ||
        $11 !~ /^[0-9]+$/ || $12 == "" || seen[$1]++ { exit 2 }
    { print; rows++ }
    END { if (rows != 3) exit 2 }
' "$CASES" > "$PLAN"

while IFS=$'\t' read -r life seed fixture prompts_sha _rest; do
    [ "$life" != life ] || continue
    fixture_path="$ROOT/$fixture"
    [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
    [ "$(shasum -a 256 "$fixture_path" | awk '{print $1}')" = "$prompts_sha" ] || {
        printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2;
    }
    [ "$(wc -l < "$fixture_path" | tr -d ' ')" -eq 24 ] || {
        printf 'fixture turn drift: %s\n' "$life" >&2; exit 2;
    }
done < "$PLAN"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.122 answer-followup anatomy plan: %s\n' "$OUT"
    exit 0
fi

cc "$ROOT/scripts/answer_followup_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function -o "$BIN" -lpthread
"$BIN" > "$ANATOMY"
cmp -s "$ROOT/scripts/answer_followup_cases.tsv" "$ANATOMY"

printf 'life\tseed\tprompts_sha256\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta121_transcript_exact\ta121_state_exact\ta122_transcript_exact\ta122_state_exact\n' > "$NATURAL"
while IFS=$'\t' read -r life seed fixture prompts_sha a121_transcript a121_state a121_open a121_questions a122_transcript a122_state a122_open a122_questions; do
    [ "$life" != life ] || continue
    destination="$OUT/lives/$life"
    LEO_NATURAL_REPLAY_FILE="$ROOT/$fixture" LEO_NATURAL_LIFE="$life" \
        LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_LEXICAL_FAMILY=1 LEO_NATURAL_LEXICAL_ROLE=1 \
        LEO_NATURAL_ANSWER_FOLLOWUP="$FOLLOWUP" \
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
    open="$(awk -F '\t' '$1 == "wonder_open_turns" {print $2}' "$destination/summary.txt")"
    observed_questions="$(jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
          "@" + (.turn | tostring))] | join(",")
    ' "$destination/dialogue.jsonl")"
    a121_transcript_exact=false; a121_state_exact=false
    a122_transcript_exact=false; a122_state_exact=false
    [ "$transcript_sha" != "$a121_transcript" ] || a121_transcript_exact=true
    [ "$state_sha" != "$a121_state" ] || a121_state_exact=true
    [ "$transcript_sha" != "$a122_transcript" ] || a122_transcript_exact=true
    [ "$state_sha" != "$a122_state" ] || a122_state_exact=true
    if [ "$EXPECT" = a121 ]; then
        [ "$a121_transcript_exact" = true ] && [ "$a121_state_exact" = true ] &&
            [ "$open" = "$a121_open" ] && [ "$observed_questions" = "$a121_questions" ] || {
            printf 'A.121 answer-followup control drift: %s\n' "$life" >&2; exit 1;
        }
    elif [ "$EXPECT" = a122 ]; then
        [ "$a122_transcript_exact" = true ] && [ "$a122_state_exact" = true ] &&
            [ "$open" = "$a122_open" ] && [ "$observed_questions" = "$a122_questions" ] || {
            printf 'A.122 answer-followup witness drift: %s\n' "$life" >&2; exit 1;
        }
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$life" "$seed" "$prompts_sha" "$transcript_sha" "$state_sha" \
        "$open" "$observed_questions" "$a121_transcript_exact" \
        "$a121_state_exact" "$a122_transcript_exact" "$a122_state_exact" >> "$NATURAL"
done < "$PLAN"

cat "$ANATOMY"
cat "$NATURAL"
printf 'result\tbounded-answer-before-followup-measured\n'
printf 'A.122 answer-followup anatomy: %s\n' "$OUT"
