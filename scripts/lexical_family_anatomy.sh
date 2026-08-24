#!/usr/bin/env bash
# A.120: replay the A.119 lives around School's witnessed lexical-family law.
set -Eeuo pipefail

trap 'rc=$?; printf "lexical-family anatomy failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-lexical-family-anatomy-$STAMP}"
CASES="${LEO_LEXICAL_FAMILY_CASES:-$ROOT/scripts/lexical_family_cases.tsv}"
PLAN_ONLY="${LEO_LEXICAL_PLAN_ONLY:-0}"
FAMILY="${LEO_LEXICAL_FAMILY:-1}"
LEXICAL_ROLE="${LEO_LEXICAL_ROLE:-0}"
ANSWER_FOLLOWUP="${LEO_ANSWER_FOLLOWUP:-0}"
EXPECT="${LEO_LEXICAL_EXPECT:-none}"

[ -s "$CASES" ] || { printf 'missing lexical-family cases: %s\n' "$CASES" >&2; exit 2; }
[ "$PLAN_ONLY" = 0 ] || [ "$PLAN_ONLY" = 1 ] || { printf 'LEO_LEXICAL_PLAN_ONLY must be 0 or 1\n' >&2; exit 2; }
[ "$FAMILY" = 0 ] || [ "$FAMILY" = 1 ] || { printf 'LEO_LEXICAL_FAMILY must be 0 or 1\n' >&2; exit 2; }
[ "$LEXICAL_ROLE" = 0 ] || [ "$LEXICAL_ROLE" = 1 ] || { printf 'LEO_LEXICAL_ROLE must be 0 or 1\n' >&2; exit 2; }
[ "$ANSWER_FOLLOWUP" = 0 ] || [ "$ANSWER_FOLLOWUP" = 1 ] || { printf 'LEO_ANSWER_FOLLOWUP must be 0 or 1\n' >&2; exit 2; }
case "$EXPECT" in none|a119|a120) ;; *) printf 'LEO_LEXICAL_EXPECT must be none, a119, or a120\n' >&2; exit 2;; esac
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

PLAN="$OUT/plan.tsv"
NATURAL="$OUT/natural.tsv"
ANATOMY="$OUT/anatomy.tsv"
BIN="$OUT/lexical-family-fixture"

awk -F '\t' -v OFS='\t' '
    NR == 1 {
        if (NF != 12 || $1 != "life" || $2 != "seed" ||
            $3 != "fixture" || $4 != "prompts_sha256" ||
            $8 != "a119_questions" || $12 != "a120_questions") exit 2
        print
        next
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

while IFS=$'\t' read -r life seed fixture prompts_sha _a119_transcript _a119_state _a119_open _a119_questions _a120_transcript _a120_state _a120_open _a120_questions; do
    [ "$life" != life ] || continue
    fixture_path="$ROOT/$fixture"
    [ -f "$fixture_path" ] || { printf 'missing fixture: %s\n' "$fixture_path" >&2; exit 2; }
    actual_sha="$(shasum -a 256 "$fixture_path" | awk '{print $1}')"
    [ "$actual_sha" = "$prompts_sha" ] || { printf 'fixture SHA drift: %s\n' "$life" >&2; exit 2; }
    [ "$(wc -l < "$fixture_path" | tr -d ' ')" -eq 24 ] || { printf 'fixture turn drift: %s\n' "$life" >&2; exit 2; }
done < "$PLAN"

if [ "$PLAN_ONLY" = 1 ]; then
    printf 'A.120 lexical-family anatomy plan: %s\n' "$OUT"
    exit 0
fi

cc "$ROOT/scripts/lexical_family_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function -o "$BIN" -lpthread
"$BIN" > "$ANATOMY"

printf 'life\tseed\tprompts_sha256\ttranscript_sha256\tstate_sha256\twonder_open_turns\tschool_questions\ta119_transcript_exact\ta119_state_exact\ta120_transcript_exact\ta120_state_exact\n' > "$NATURAL"
while IFS=$'\t' read -r life seed fixture prompts_sha a119_transcript a119_state a119_open a119_questions a120_transcript a120_state a120_open a120_questions; do
    [ "$life" != life ] || continue
    destination="$OUT/lives/$life"
    LEO_NATURAL_REPLAY_FILE="$ROOT/$fixture" LEO_NATURAL_LIFE="$life" \
        LEO_NATURAL_ARM=replay LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_LEXICAL_FAMILY="$FAMILY" \
        LEO_NATURAL_LEXICAL_ROLE="$LEXICAL_ROLE" \
        LEO_NATURAL_ANSWER_FOLLOWUP="$ANSWER_FOLLOWUP" \
        LEO_NATURAL_WONDER_REASK_REFERENCE=0 \
        LEO_NATURAL_OFFERED_ANSWER_EXPANSION=0 \
        LEO_NATURAL_FOLLOWUP_QUESTION_SCOPE=0 \
        LEO_NATURAL_UNIQUE_ANSWER_DOMINANCE=0 \
        "$ROOT/scripts/natural_life_probe.sh" "$destination" > "$OUT/lives/$life.out"
    transcript_sha="$(shasum -a 256 "$destination/visible_transcript.txt" | awk '{print $1}')"
    state_sha="$(shasum -a 256 "$destination/state/leo.state" | awk '{print $1}')"
    open="$(awk -F '\t' '$1 == "wonder_open_turns" { print $2 }' "$destination/summary.txt")"
    observed_questions="$(jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word | ascii_downcase) +
          "@" + (.turn | tostring))] | join(",")
    ' "$destination/dialogue.jsonl")"
    a119_transcript_exact=false; a119_state_exact=false
    a120_transcript_exact=false; a120_state_exact=false
    [ "$transcript_sha" != "$a119_transcript" ] || a119_transcript_exact=true
    [ "$state_sha" != "$a119_state" ] || a119_state_exact=true
    [ "$transcript_sha" != "$a120_transcript" ] || a120_transcript_exact=true
    [ "$state_sha" != "$a120_state" ] || a120_state_exact=true
    if [ "$EXPECT" = a119 ]; then
        [ "$a119_transcript_exact" = true ] && [ "$a119_state_exact" = true ] &&
            [ "$open" = "$a119_open" ] && [ "$observed_questions" = "$a119_questions" ] || {
            printf 'A.119 lexical-family control drift: %s\n' "$life" >&2; exit 1;
        }
    elif [ "$EXPECT" = a120 ]; then
        [ "$a120_transcript_exact" = true ] && [ "$a120_state_exact" = true ] &&
            [ "$open" = "$a120_open" ] && [ "$observed_questions" = "$a120_questions" ] || {
            printf 'A.120 lexical-family witness drift: %s\n' "$life" >&2; exit 1;
        }
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$life" "$seed" "$prompts_sha" "$transcript_sha" "$state_sha" \
        "$open" "$observed_questions" "$a119_transcript_exact" \
        "$a119_state_exact" "$a120_transcript_exact" "$a120_state_exact" >> "$NATURAL"
done < "$PLAN"

cat "$ANATOMY"
cat "$NATURAL"
printf 'result\tlexical-family-boundary-measured\n'
printf 'A.120 lexical-family anatomy: %s\n' "$OUT"
