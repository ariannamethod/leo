#!/usr/bin/env bash
# A.144: a second wholly fresh ordinary visible-only life.
set -Eeuo pipefail

trap 'rc=$?; printf "second fresh ordinary life failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-second-fresh-ordinary-life-a144-$STAMP}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
API="$OUT/lives/api"
FROZEN_PROMPTS="$ROOT/scripts/fixtures/second_fresh_ordinary_life_a144_ordinary.txt"
API_TURNS="$ROOT/scripts/second_fresh_ordinary_life_a144_api_turns.tsv"

[ -n "$KEY_FILE" ] && [ -s "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable nonempty key file\n' >&2
    exit 2
}
[ ! -e "$OUT" ] || [ -d "$OUT" ] || {
    printf 'output path is not a directory: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/lives"

if [ ! -f "$API/dialogue.jsonl" ]; then
    OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
        LEO_NATURAL_PHASE=A.144 \
        LEO_NATURAL_QUESTION=second-fresh-ordinary-life \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Begin with one ordinary concrete observation from daily life.' \
        "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/api.out"
else
    completed="$(wc -l < "$API/dialogue.jsonl" | tr -d ' ')"
    if [ "$completed" -ge 1 ] && [ "$completed" -lt 24 ]; then
        OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
            LEO_NATURAL_PHASE=A.144 \
            LEO_NATURAL_QUESTION=second-fresh-ordinary-life \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
            LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OPENING='Begin with one ordinary concrete observation from daily life.' \
            LEO_NATURAL_RESUME=1 \
            "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/api.out"
    elif [ "$completed" -ne 24 ]; then
        printf 'unexpected completed turn count: %s\n' "$completed" >&2
        exit 2
    fi
fi

jq -e '.source == "responses-api-visible-transcript" and
       .replay_prefix_turns == 0 and .api_turns == 24 and
       .api_store == false and .transcript_visible_to_interlocutor == true and
       .diagnostics_visible_to_interlocutor == false and
       .school_cautious_pair == true' "$API/manifest.json" >/dev/null

cmp -s "$FROZEN_PROMPTS" "$API/prompts.txt"
printf 'turn\tutterance\tstance\treply_reference\tmodel\n' \
    > "$OUT/api-turns.actual.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
    NR > 1 { print $3, $5, $6, $7, $8 }
' "$API/sessions.tsv" >> "$OUT/api-turns.actual.tsv"
cmp -s "$API_TURNS" "$OUT/api-turns.actual.tsv"

receipt_count=0
for response in "$API"/api/turn-*.response.json; do
    jq -e '.status == "completed" and .store == false and
           (.model | type) == "string"' "$response" >/dev/null
    receipt_count=$((receipt_count + 1))
done
[ "$receipt_count" -eq 24 ]

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$API/prompts.txt" \
            LEO_NATURAL_PHASE=A.144 \
            LEO_NATURAL_QUESTION=second-fresh-ordinary-life \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
            LEO_NATURAL_SEED=542 LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OPENING='Replay the frozen second ordinary life.' \
            LEO_NATURAL_ASYNC="$async" \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/lives/$arm.out"
    fi
done

cmp -s "$API/visible_transcript.txt" "$OUT/lives/replay/visible_transcript.txt"
cmp -s "$API/state/leo.state" "$OUT/lives/replay/state/leo.state"
cmp -s "$OUT/lives/async-a/visible_transcript.txt" \
    "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" \
    "$OUT/lives/async-b/state/leo.state"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
reply_mismatches() {
    jq -n --slurpfile left "$1" --slurpfile right "$2" '
        [$left, $right] as [$l, $r] |
        if ($l | length) != ($r | length) then -1
        else [range(0; $l | length) |
              select($l[.].leo != $r[.].leo)] | length
        end
    '
}

MATRIX="$OUT/matrix.tsv"
printf 'life\tseed\tturns\tapi_turns\tapi_model\tsync_replay_exact\tasync_reproducible\tsync_async_reply_mismatches\tprompts_sha256\ttranscript_sha256\tstate_sha256\tasync_transcript_sha256\tasync_state_sha256\n' > "$MATRIX"
resolved_model="$(awk -F '\t' '$3 == 1 { print $8 }' "$API/sessions.tsv")"
printf 'ordinary\t542\t24\t24\t%s\ttrue\ttrue\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$resolved_model" \
    "$(reply_mismatches "$API/dialogue.jsonl" \
        "$OUT/lives/async-a/dialogue.jsonl")" \
    "$(sha256_file "$API/prompts.txt")" \
    "$(sha256_file "$API/visible_transcript.txt")" \
    "$(sha256_file "$API/state/leo.state")" \
    "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" \
    "$(sha256_file "$OUT/lives/async-a/state/leo.state")" >> "$MATRIX"

cat "$MATRIX"
printf 'result\tsecond-fresh-ordinary-life-observed-not-judged\n'
printf 'A.144 second fresh ordinary life: %s\n' "$OUT"
