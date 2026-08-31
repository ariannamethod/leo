#!/usr/bin/env bash
# A.138: return repaired Difficult? to a fresh visible-only interlocutor.
set -Eeuo pipefail

trap 'rc=$?; printf "responsive difficult after repair failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-responsive-difficult-after-repair-a138-$STAMP}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
PREFIX="$ROOT/scripts/fixtures/responsive_difficult_return_a136_prefix.txt"
EXPECTED_PREFIX="$ROOT/scripts/responsive_difficult_return_a136_prefix_expected.jsonl"
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

if [ ! -f "$API/dialogue.jsonl" ]; then
    LEO_NATURAL_REPLAY_FILE="$PREFIX" \
        LEO_NATURAL_PHASE=A.138 \
        LEO_NATURAL_QUESTION=responsive-difficult-after-repair \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=25 \
        LEO_NATURAL_OPENING='Continue the exact repaired difficult-return fork.' \
        LEO_NATURAL_REFERENCE_PREDICATION=1 \
        LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/prefix.out"
fi

jq -c '{turn, human, leo}' "$API/dialogue.jsonl" | sed -n '1,25p' \
    > "$OUT/prefix.actual.jsonl"
cmp -s "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl" || {
    printf 'repaired twenty-five-turn prefix did not reproduce exactly\n' >&2
    diff -u "$EXPECTED_PREFIX" "$OUT/prefix.actual.jsonl" >&2 || true
    exit 1
}

completed="$(wc -l < "$API/dialogue.jsonl" | tr -d ' ')"
if [ "$completed" -ge 25 ] && [ "$completed" -lt 35 ]; then
    OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
        LEO_NATURAL_PHASE=A.138 \
        LEO_NATURAL_QUESTION=responsive-difficult-after-repair \
        LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM=api \
        LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=35 \
        LEO_NATURAL_OPENING='Continue the exact repaired difficult-return fork.' \
        LEO_NATURAL_RESUME=1 \
        LEO_NATURAL_REFERENCE_PREDICATION=1 \
        LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
        "$ROOT/scripts/natural_life_probe.sh" "$API" > "$OUT/lives/api.out"
elif [ "$completed" -ne 35 ]; then
    printf 'unexpected completed turn count: %s\n' "$completed" >&2
    exit 2
fi

jq -e '.source == "frozen-prefix-then-responses-api-visible-transcript" and
       .replay_prefix_turns == 25 and .api_turns == 10 and
       .api_store == false and .transcript_visible_to_interlocutor == true and
       .diagnostics_visible_to_interlocutor == false and
       .school_reference_predication == true and
       .school_two_layer_family_composition == true' \
    "$API/manifest.json" >/dev/null

for arm in replay async-a async-b; do
    destination="$OUT/lives/$arm"
    async=0
    [ "$arm" = replay ] || async=1
    if [ ! -f "$destination/manifest.json" ]; then
        LEO_NATURAL_REPLAY_FILE="$API/prompts.txt" \
            LEO_NATURAL_PHASE=A.138 \
            LEO_NATURAL_QUESTION=responsive-difficult-after-repair \
            LEO_NATURAL_LIFE=meal LEO_NATURAL_ARM="$arm" \
            LEO_NATURAL_SEED=617 LEO_NATURAL_TURNS=35 \
            LEO_NATURAL_OPENING='Continue the exact repaired difficult-return fork.' \
            LEO_NATURAL_ASYNC="$async" \
            LEO_NATURAL_REFERENCE_PREDICATION=1 \
            LEO_NATURAL_TWO_LAYER_FAMILY_COMPOSITION=1 \
            "$ROOT/scripts/natural_life_probe.sh" "$destination" \
            > "$OUT/lives/$arm.out"
    fi
done

cmp -s "$API/visible_transcript.txt" "$OUT/lives/replay/visible_transcript.txt"
cmp -s "$API/state/leo.state" "$OUT/lives/replay/state/leo.state"
cmp -s "$OUT/lives/async-a/visible_transcript.txt" "$OUT/lives/async-b/visible_transcript.txt"
cmp -s "$OUT/lives/async-a/state/leo.state" "$OUT/lives/async-b/state/leo.state"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
reply_mismatches() {
    jq -n --slurpfile left "$1" --slurpfile right "$2" '
        [$left, $right] as [$l, $r] |
        if ($l | length) != ($r | length) then -1
        else [range(0; $l | length) | select($l[.].leo != $r[.].leo)] | length
        end
    '
}

MATRIX="$OUT/matrix.tsv"
printf 'life\tseed\tturns\tprefix_turns\tapi_turns\tapi_model\tsync_replay_exact\tasync_reproducible\tsync_async_reply_mismatches\tprompts_sha256\ttranscript_sha256\tstate_sha256\tasync_transcript_sha256\tasync_state_sha256\n' > "$MATRIX"
resolved_model="$(awk -F '\t' '$3 == 26 { print $8 }' "$API/sessions.tsv")"
printf 'meal\t617\t35\t25\t10\t%s\ttrue\ttrue\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$resolved_model" \
    "$(reply_mismatches "$API/dialogue.jsonl" "$OUT/lives/async-a/dialogue.jsonl")" \
    "$(sha256_file "$API/prompts.txt")" \
    "$(sha256_file "$API/visible_transcript.txt")" \
    "$(sha256_file "$API/state/leo.state")" \
    "$(sha256_file "$OUT/lives/async-a/visible_transcript.txt")" \
    "$(sha256_file "$OUT/lives/async-a/state/leo.state")" >> "$MATRIX"

cat "$MATRIX"
printf 'result\tresponsive-difficult-after-repair-observed-not-judged\n'
printf 'A.138 responsive difficult after repair: %s\n' "$OUT"
