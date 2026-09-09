#!/usr/bin/env bash
# A.145: replay the exact A.144 opening around School's existing affirmation grammar.
set -Eeuo pipefail

trap 'rc=$?; printf "affirmation role A.145 failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-affirmation-role-a145-$STAMP}"
PLAN="$ROOT/scripts/affirmation_role_a145_plan.tsv"
EXPECTED="$ROOT/scripts/affirmation_role_a145_expected.tsv"
FROZEN="$ROOT/scripts/affirmation_role_a145_frozen.tsv"

IFS=$'\t' read -r phase seed fixture plan_sha expected_sha prompts_sha \
    control_transcript_sha control_state_sha candidate_transcript_sha \
    candidate_state_sha turns frozen_reply_mismatches \
    frozen_prefix_mismatches frozen_control_questions \
    frozen_candidate_questions control_pending candidate_pending \
    control_wonders candidate_wonders control_deferred candidate_deferred \
    candidate_deferred_word finished_heard yeah_heard \
    candidate_finished_episode candidate_finished_resolved \
    candidate_yeah_episode candidate_yeah_learned candidate_sleep_exact \
    control_a144_exact api_turns \
    < <(awk -F '\t' 'NR == 2 { print }' "$FROZEN")
PROMPTS="$ROOT/$fixture"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[ "$phase" = A.145 ] && [ "$seed" = 542 ] && [ "$turns" = 6 ]
[ "$frozen_reply_mismatches" = 1 ] && [ "$frozen_prefix_mismatches" = 0 ]
[ "$candidate_sleep_exact" = true ] && [ "$control_a144_exact" = true ]
[ "$api_turns" = 0 ]
[ "$(sha256_file "$PLAN")" = "$plan_sha" ]
[ "$(sha256_file "$EXPECTED")" = "$expected_sha" ]
[ "$(sha256_file "$PROMPTS")" = "$prompts_sha" ]

[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
mkdir -p "$OUT/lives"

for arm in control candidate; do
    affirmation=1
    [ "$arm" = candidate ] || affirmation=0
    LEO_NATURAL_REPLAY_FILE="$PROMPTS" \
        LEO_NATURAL_PHASE=A.145 LEO_NATURAL_LIFE=ordinary \
        LEO_NATURAL_ARM=replay LEO_NATURAL_AFFIRMATION_ROLE="$affirmation" \
        LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
        LEO_NATURAL_OPENING='Judge the exact A.144 affirmation redirect.' \
        "$ROOT/scripts/natural_life_probe.sh" "$OUT/lives/$arm" \
        > "$OUT/lives/$arm.out"
done

cc "$ROOT/scripts/affirmation_role_a145_fixture.c" \
    -O2 -lm -Wall -Wextra -Wno-unused-function \
    -o "$OUT/fixture" -lpthread
"$OUT/fixture" \
    "$OUT/lives/control/state/leo.state" \
    "$OUT/lives/candidate/state/leo.state" \
    "$OUT/candidate-sleep.state" > "$OUT/anatomy.tsv"
cmp -s "$EXPECTED" "$OUT/anatomy.tsv" || {
    diff -u "$EXPECTED" "$OUT/anatomy.tsv" >&2 || true
    exit 2
}
cmp -s "$OUT/lives/candidate/state/leo.state" \
    "$OUT/candidate-sleep.state"

[ "$(sha256_file "$OUT/lives/control/visible_transcript.txt")" = \
    "$control_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/control/state/leo.state")" = \
    "$control_state_sha" ]
[ "$(sha256_file "$OUT/lives/candidate/visible_transcript.txt")" = \
    "$candidate_transcript_sha" ]
[ "$(sha256_file "$OUT/lives/candidate/state/leo.state")" = \
    "$candidate_state_sha" ]
jq -e '.school_lexical_role == true and
       .school_affirmation_role == false and .api_turns == 0' \
    "$OUT/lives/control/manifest.json" >/dev/null
jq -e '.school_lexical_role == true and
       .school_affirmation_role == true and .api_turns == 0' \
    "$OUT/lives/candidate/manifest.json" >/dev/null

questions_for() {
    jq -sr '
        [.[] | select(.leo | test("^[[:alpha:]]+\\?")) |
         ((.leo | capture("^(?<word>[[:alpha:]]+)\\?").word |
           ascii_downcase) + "@" + (.turn | tostring))] | join(",")
    ' "$1"
}

control_questions="$(questions_for "$OUT/lives/control/dialogue.jsonl")"
candidate_questions="$(questions_for "$OUT/lives/candidate/dialogue.jsonl")"
reply_mismatches="$(jq -n \
    --slurpfile control "$OUT/lives/control/dialogue.jsonl" \
    --slurpfile candidate "$OUT/lives/candidate/dialogue.jsonl" '
    [range(0; $control | length) |
     select($control[.].leo != $candidate[.].leo)] | length
')"
prefix_mismatches="$(jq -n \
    --slurpfile control "$OUT/lives/control/dialogue.jsonl" \
    --slurpfile candidate "$OUT/lives/candidate/dialogue.jsonl" '
    [range(0; 5) | select($control[.].leo != $candidate[.].leo)] | length
')"

[ "$control_questions" = "$frozen_control_questions" ]
[ "$candidate_questions" = "$frozen_candidate_questions" ]
[ "$reply_mismatches" = "$frozen_reply_mismatches" ]
[ "$prefix_mismatches" = "$frozen_prefix_mismatches" ]
printf 'metric\tvalue\n'
printf 'prompts_sha256\t%s\n' "$(sha256_file "$PROMPTS")"
printf 'control_transcript_sha256\t%s\n' "$(sha256_file "$OUT/lives/control/visible_transcript.txt")"
printf 'control_state_sha256\t%s\n' "$(sha256_file "$OUT/lives/control/state/leo.state")"
printf 'candidate_transcript_sha256\t%s\n' "$(sha256_file "$OUT/lives/candidate/visible_transcript.txt")"
printf 'candidate_state_sha256\t%s\n' "$(sha256_file "$OUT/lives/candidate/state/leo.state")"
printf 'anatomy_sha256\t%s\n' "$(sha256_file "$OUT/anatomy.tsv")"
printf 'control_questions\t%s\n' "$control_questions"
printf 'candidate_questions\t%s\n' "$candidate_questions"
printf 'reply_mismatches\t%s\n' "$reply_mismatches"
printf 'prefix_mismatches\t%s\n' "$prefix_mismatches"
printf 'candidate_sleep_exact\ttrue\n'
printf 'control_a144_exact\t%s\n' "$control_a144_exact"
printf 'api_turns\t%s\n' "$api_turns"
printf 'result\taffirmation-role-prevents-discourse-redirect-without-erasing-wonder\n'
printf 'A.145 affirmation role anatomy: %s\n' "$OUT"
