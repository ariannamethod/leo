#!/usr/bin/env bash
# A.143: give the exact post-A.142 body a fresh visible-only continuation.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive after cautious failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-after-cautious-a143-$STAMP}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
PREFIX="$ROOT/scripts/fixtures/responsive_after_cautious_a143_prefix.txt"
EXPECTED_PREFIX="$ROOT/scripts/responsive_after_cautious_a143_prefix_expected.jsonl"
FROZEN_PROMPTS="$ROOT/scripts/fixtures/responsive_after_cautious_a143_ordinary.txt"
API_TURNS="$ROOT/scripts/responsive_after_cautious_a143_api_turns.tsv"
API="$OUT/lives/api"

[ -n "$KEY_FILE" ] && [ -s "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable nonempty key file\n' >&2
    exit 2
}
[ ! -e "$OUT" ] || [ -d "$OUT" ] || {
    printf 'output path is not a directory: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/lives"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

if [ ! -f "$API/dialogue.jsonl" ]; then
    LEO_NATURAL_REPLAY_FILE="$PREFIX" \
        LEO_NATURAL_PHASE=A.143 \
        LEO_NATURAL_QUESTION=responsive-after-cautious \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=853 LEO_NATURAL_TURNS=6 \
        LEO_NATURAL_OPENING='Continue the exact ordinary life after its cautious paired answer.' \
        "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/prefix.out"
fi

jq -c '{turn, human, leo}' "$API/dialogue.jsonl" | sed -n '1,6p' \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl" || {
    printf 'post-cautious six-turn prefix did not reproduce exactly\n' >&2
    diff -u "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl" >&2 || true
    exit 1
}
completed="$(wc -l < "$API/dialogue.jsonl" | tr -d ' ')"
if [ "$completed" -eq 6 ]; then
    [ "$(sha256_file "$API/visible_transcript.txt")" = \
        "$(awk -F '\t' '$1 == "source_transcript_sha256" { print $2 }' \
            "$ROOT/scripts/responsive_after_cautious_a143_plan.tsv")" ]
    [ "$(sha256_file "$API/state/leo.state")" = \
        "$(awk -F '\t' '$1 == "source_state_sha256" { print $2 }' \
            "$ROOT/scripts/responsive_after_cautious_a143_plan.tsv")" ]
fi
if [ "$completed" -ge 6 ] && [ "$completed" -lt 24 ]; then
    OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
        LEO_NATURAL_PHASE=A.143 \
        LEO_NATURAL_QUESTION=responsive-after-cautious \
        LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=853 LEO_NATURAL_TURNS=24 \
        LEO_NATURAL_OPENING='Continue the exact ordinary life after its cautious paired answer.' \
        LEO_NATURAL_RESUME=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/api.out"
elif [ "$completed" -ne 24 ]; then
    printf 'unexpected completed turn count: %s\n' "$completed" >&2
    exit 2
fi

cmp -s "$FROZEN_PROMPTS" "$API/prompts.txt"
printf 'turn\tutterance\tstance\treply_reference\tmodel\n' \
    > "$OUT/api-turns.actual.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
    NR > 1 && $3 >= 7 { print $3, $5, $6, $7, $8 }
' "$API/sessions.tsv" >> "$OUT/api-turns.actual.tsv"
cmp -s "$API_TURNS" "$OUT/api-turns.actual.tsv"

receipt_count=0
for response in "$API"/api/turn-*.response.json; do
    jq -e '.status == "completed" and .store == false and
           (.model | type) == "string"' "$response" >/dev/null
    receipt_count=$((receipt_count + 1))
done
[ "$receipt_count" -eq 18 ]

jq -e '.source == "frozen-prefix-then-responses-api-visible-transcript" and
       .replay_prefix_turns == 6 and .api_turns == 18 and
       .api_store == false and .transcript_visible_to_interlocutor == true and
       .diagnostics_visible_to_interlocutor == false and
       .school_cautious_pair == true' "$API/manifest.json" >/dev/null

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$API/prompts.txt" \
            LEO_NATURAL_PHASE=A.143 \
            LEO_NATURAL_QUESTION=responsive-after-cautious \
            LEO_NATURAL_LIFE=ordinary LEO_NATURAL_ARM="$arm" \
            LEO_NATURAL_SEED=853 LEO_NATURAL_TURNS=24 \
            LEO_NATURAL_OPENING='Continue the exact ordinary life after its cautious paired answer.' \
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
printf 'life\tseed\tturns\tprefix_turns\tapi_turns\tapi_model\tsync_replay_exact\tasync_reproducible\tsync_async_reply_mismatches\tprompts_sha256\ttranscript_sha256\tstate_sha256\tasync_transcript_sha256\tasync_state_sha256\n' > "$MATRIX"
resolved_model="$(awk -F '\t' '$3 == 7 { print $8 }' "$API/sessions.tsv")"
printf 'ordinary\t853\t24\t6\t18\t%s\ttrue\ttrue\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$resolved_model" \
    "$(reply_mismatches "$API/dialogue.jsonl" \
        "$OUT/lives/async-a/dialogue.jsonl")" \
    "$(sha256_file "$API/prompts.txt")" \
    "$(sha256_file "$API/visible_transcript.txt")" \
    "$(sha256_file "$API/state/leo.state")" \
    "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" \
    "$(sha256_file "$OUT/lives/async-a/state/leo.state")" >> "$MATRIX"

cat "$MATRIX"
printf 'result\tresponsive-after-cautious-observed-not-judged\n'
printf 'A.143 responsive after cautious: %s\n' "$OUT"
