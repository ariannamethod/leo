#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-natural-life-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

printf '{"turn":1,"human":"The room is quiet.","leo":"Rain waits by the window.","debug_secret":"state-swarm-private"}\n' \
    > "$TMP/history.jsonl"
LEO_NATURAL_REQUEST_ONLY=1 \
    "$ROOT/scripts/natural_interlocutor_turn.sh" 2 "$TMP/history.jsonl" \
    "Begin quietly." "$TMP/turn-02.json" "$TMP/turn-02.response.json" \
    >/dev/null
request="$TMP/turn-02.json.request.json"
jq -e '
    .store == false and .reasoning.effort == "low" and
    .text.format.type == "json_schema" and .text.format.strict == true and
    (.input | contains("human: The room is quiet.")) and
    (.input | contains("leo: Rain waits by the window.")) and
    (.input | contains("state-swarm-private") | not)
' "$request" >/dev/null

printf '%s\n' \
    'The room is quiet tonight.' \
    'Do you remember rain on the window?' \
    'The little light is still awake.' \
    'What would you call that sound?' > "$TMP/prompts.txt"

for arm in first second; do
    LEO_NATURAL_REPLAY_FILE="$TMP/prompts.txt" \
        LEO_NATURAL_LIFE=test LEO_NATURAL_ARM=replay \
        LEO_NATURAL_SEED=911 LEO_NATURAL_TURNS=4 \
        "$ROOT/scripts/natural_life_probe.sh" "$TMP/$arm" >/dev/null
done
cmp -s "$TMP/first/visible_transcript.txt" "$TMP/second/visible_transcript.txt"
cmp -s "$TMP/first/state/leo.state" "$TMP/second/state/leo.state"
grep -q '^result[[:space:]]natural-life-observed-not-judged$' "$TMP/first/summary.txt"
jq -e '.source == "frozen-visible-replay" and .api_store == null and
       .diagnostics_visible_to_interlocutor == false and
       .school_natural_word_boundary == true and
       .school_lexical_family == true and
       .school_lexical_role == true and
       .school_answer_followup == true and
       .wonder_reask_reference == true and
       .school_offered_answer_expansion == true and
       .school_followup_question_scope == true and
       .school_unique_answer_dominance == true and
       .school_two_glyph_learning == true' "$TMP/first/manifest.json" >/dev/null

sed -n '1,2p' "$TMP/prompts.txt" > "$TMP/prompts-first-two.txt"
LEO_NATURAL_REPLAY_FILE="$TMP/prompts-first-two.txt" \
    LEO_NATURAL_LIFE=test LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=911 LEO_NATURAL_TURNS=2 \
    "$ROOT/scripts/natural_life_probe.sh" "$TMP/resumed" >/dev/null
LEO_NATURAL_REPLAY_FILE="$TMP/prompts.txt" LEO_NATURAL_RESUME=1 \
    LEO_NATURAL_LIFE=test LEO_NATURAL_ARM=replay \
    LEO_NATURAL_SEED=911 LEO_NATURAL_TURNS=4 \
    "$ROOT/scripts/natural_life_probe.sh" "$TMP/resumed" >/dev/null
cmp -s "$TMP/first/visible_transcript.txt" "$TMP/resumed/visible_transcript.txt"
cmp -s "$TMP/first/state/leo.state" "$TMP/resumed/state/leo.state"
jq -e '.process_resumed == true and .resumed_at_turn == 3' \
    "$TMP/resumed/manifest.json" >/dev/null

LEO_NATURAL_PLAN_ONLY=1 LEO_NATURAL_TURNS=4 \
    "$ROOT/scripts/natural_life_matrix.sh" "$TMP/plan" >/dev/null
grep -q $'^planned_api_turns\t12$' "$TMP/plan/design.tsv"
grep -q $'^automatic_http_retries\t3$' "$TMP/plan/design.tsv"
grep -q $'^maximum_http_attempts\t48$' "$TMP/plan/design.tsv"
grep -q $'^phase\tA.118$' "$TMP/plan/design.tsv"
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]

LEO_NATURAL_PLAN_ONLY=1 LEO_NATURAL_PHASE=A.124 \
    LEO_NATURAL_QUESTION=what-does-repaired-Leo-do-in-fresh-ordinary-life \
    LEO_NATURAL_CURL_RETRIES=0 \
    LEO_NATURAL_TURNS=4 \
    "$ROOT/scripts/natural_life_matrix.sh" "$TMP/second-generation-plan" >/dev/null
grep -q $'^phase\tA.124$' "$TMP/second-generation-plan/design.tsv"
grep -q $'^question\twhat-does-repaired-Leo-do-in-fresh-ordinary-life$' \
    "$TMP/second-generation-plan/design.tsv"
grep -q $'^maximum_http_attempts\t12$' \
    "$TMP/second-generation-plan/design.tsv"

frozen="$ROOT/scripts/natural_life_second_generation_frozen.tsv"
awk -F '\t' '
    NR == 1 {
        if (NF != 9 || $1 != "life" || $3 != "fixture" ||
            $4 != "prompts_sha256" || $9 != "sync_async_reply_mismatches") exit 2
        next
    }
    NF != 9 || $1 !~ /^[a-z]+$/ || $2 !~ /^[0-9]+$/ ||
        $4 !~ /^[0-9a-f]{64}$/ || $5 !~ /^[0-9a-f]{64}$/ ||
        $6 !~ /^[0-9a-f]{64}$/ || $7 !~ /^[0-9a-f]{64}$/ ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^[0-9]+$/ { exit 2 }
    { rows++ }
    END { if (rows != 3) exit 2 }
' "$frozen"
while IFS=$'\t' read -r life seed fixture prompts_sha rest; do
    [ "$life" != life ] || continue
    [ "$(shasum -a 256 "$ROOT/$fixture" | awk '{print $1}')" = "$prompts_sha" ]
done < "$frozen"

printf 'natural-life probe contracts: ok\n'
