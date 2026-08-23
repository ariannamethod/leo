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
       .school_natural_word_boundary == true' "$TMP/first/manifest.json" >/dev/null

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
grep -q $'^maximum_api_calls\t12$' "$TMP/plan/design.tsv"
[ "$(wc -l < "$TMP/plan/plan.tsv" | tr -d ' ')" -eq 4 ]

printf 'natural-life probe contracts: ok\n'
