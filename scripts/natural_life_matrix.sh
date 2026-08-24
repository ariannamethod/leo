#!/usr/bin/env bash
# A.118: three transcript-visible API lives, exact sync replay, and async shadow.
set -Eeuo pipefail

trap 'rc=$?; printf "natural life matrix failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-life-matrix-$STAMP}"
CASES="${LEO_NATURAL_CASES:-$ROOT/scripts/natural_life_cases.tsv}"
PHASE="${LEO_NATURAL_PHASE:-A.118}"
QUESTION="${LEO_NATURAL_QUESTION:-what-does-ordinary-current-Leo-show-before-another-intervention}"
TURNS="${LEO_NATURAL_TURNS:-24}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
HTTP_RETRIES="${LEO_NATURAL_CURL_RETRIES:-3}"
PLAN_ONLY="${LEO_NATURAL_PLAN_ONLY:-0}"
RESUME="${LEO_NATURAL_RESUME:-0}"

[ -s "$CASES" ] || { printf 'missing natural-life cases: %s\n' "$CASES" >&2; exit 2; }
[ -n "$PHASE" ] && [ -n "$QUESTION" ] || { printf 'phase and question must not be empty\n' >&2; exit 2; }
case "$TURNS" in ''|*[!0-9]*) printf 'invalid turn count\n' >&2; exit 2;; esac
case "$HTTP_RETRIES" in ''|*[!0-9]*) printf 'invalid curl retry count\n' >&2; exit 2;; esac
[ "$HTTP_RETRIES" -le 8 ] || { printf 'curl retry count must be 0..8\n' >&2; exit 2; }
[ "$TURNS" -ge 2 ] && [ "$TURNS" -le 64 ] || { printf 'turn count must be 2..64\n' >&2; exit 2; }
[ "$RESUME" = 0 ] || [ "$RESUME" = 1 ] || { printf 'LEO_NATURAL_RESUME must be 0 or 1\n' >&2; exit 2; }
if [ "$RESUME" = 0 ]; then
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
else
    [ -d "$OUT" ] || { printf 'missing matrix to resume: %s\n' "$OUT" >&2; exit 2; }
fi

mkdir -p "$OUT/lives"
PLAN="$OUT/plan.tsv"
DESIGN="$OUT/design.tsv"
MATRIX="$OUT/matrix.tsv"

awk -F '\t' -v OFS='\t' -v turns="$TURNS" '
    NR == 1 {
        if (NF != 3 || $1 != "life" || $2 != "seed" || $3 != "opening_cue") exit 2
        print "life", "seed", "turns", "opening_cue"
        next
    }
    NF != 3 || $1 !~ /^[a-z][a-z0-9-]*$/ || $2 !~ /^[0-9]+$/ || $3 == "" || seen[$1]++ { exit 2 }
    { print $1, $2, turns, $3; rows++ }
    END { if (rows != 3) exit 2 }
' "$CASES" > "$PLAN"

{
    printf 'field\tvalue\n'
    printf 'phase\t%s\n' "$PHASE"
    printf 'question\t%s\n' "$QUESTION"
    printf 'population\t3 independent fresh lives\n'
    printf 'turns_per_life\t%s\n' "$TURNS"
    printf 'planned_api_turns\t%s\n' "$((3 * TURNS))"
    printf 'automatic_http_retries\t%s\n' "$HTTP_RETRIES"
    printf 'maximum_http_attempts\t%s\n' "$((3 * TURNS * (HTTP_RETRIES + 1)))"
    printf 'interlocutor\tResponses API visible transcript only\n'
    printf 'model\t%s\n' "$MODEL"
    printf 'api_store\tfalse\n'
    printf 'private_diagnostics_visible\tfalse\n'
    printf 'source_arm\tdefault synchronous Leo\n'
    printf 'sync_control\texact frozen-prompt replay\n'
    printf 'async_shadow\ttwo frozen-prompt --async replays\n'
    printf 'decision\tdescriptive scout only; no quality score or code admission\n'
} > "$DESIGN"

if [ "$PLAN_ONLY" = 1 ]; then
    printf '%s natural-life plan: %s\n' "$PHASE" "$OUT"
    exit 0
fi
[ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable key file\n' >&2
    exit 2
}

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
reply_mismatches() {
    jq -n --slurpfile left "$1" --slurpfile right "$2" '
        if ($left | length) != ($right | length) then -1
        else [range(0; $left | length) | select($left[.].leo != $right[.].leo)] | length
        end
    '
}

printf 'life\tseed\tturns\tapi_model\tsync_replay_exact\tasync_reproducible\tsync_async_reply_mismatches\tapi_prompts_sha\tapi_transcript_sha\tapi_state_sha\tasync_transcript_sha\tasync_state_sha\n' > "$MATRIX"
while IFS=$'\t' read -r life seed turns opening; do
    [ "$life" != life ] || continue
    api="$OUT/lives/$life/api"
    replay="$OUT/lives/$life/replay"
    async_a="$OUT/lives/$life/async-a"
    async_b="$OUT/lives/$life/async-b"
    if [ ! -f "$api/manifest.json" ]; then
        life_resume=0
        [ ! -d "$api" ] || life_resume=1
        OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
            LEO_NATURAL_PHASE="$PHASE" \
            LEO_NATURAL_LIFE="$life" LEO_NATURAL_ARM=api \
            LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
            LEO_NATURAL_OPENING="$opening" LEO_NATURAL_RESUME="$life_resume" \
            "$ROOT/scripts/natural_life_probe.sh" "$api" > "$OUT/lives/$life-api.out"
    fi
    for arm in replay async-a async-b; do
        destination="$OUT/lives/$life/$arm"
        async=0
        [ "$arm" = replay ] || async=1
        if [ ! -f "$destination/manifest.json" ]; then
            life_resume=0
            [ ! -d "$destination" ] || life_resume=1
            LEO_NATURAL_REPLAY_FILE="$api/prompts.txt" \
                LEO_NATURAL_PHASE="$PHASE" \
                LEO_NATURAL_LIFE="$life" LEO_NATURAL_ARM="$arm" \
                LEO_NATURAL_SEED="$seed" LEO_NATURAL_TURNS="$turns" \
                LEO_NATURAL_OPENING="$opening" LEO_NATURAL_ASYNC="$async" \
                LEO_NATURAL_RESUME="$life_resume" \
                "$ROOT/scripts/natural_life_probe.sh" "$destination" \
                > "$OUT/lives/$life-$arm.out"
        fi
    done
    cmp -s "$api/visible_transcript.txt" "$replay/visible_transcript.txt"
    cmp -s "$api/state/leo.state" "$replay/state/leo.state"
    sync_exact=true
    async_reproducible=false
    if cmp -s "$async_a/visible_transcript.txt" "$async_b/visible_transcript.txt" &&
       cmp -s "$async_a/state/leo.state" "$async_b/state/leo.state"; then
        async_reproducible=true
    fi
    mismatches="$(reply_mismatches "$api/dialogue.jsonl" "$async_a/dialogue.jsonl")"
    resolved_model="$(awk -F '\t' 'NR == 2 { print $8 }' "$api/sessions.tsv")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$life" "$seed" "$turns" "$resolved_model" "$sync_exact" \
        "$async_reproducible" "$mismatches" \
        "$(sha256_file "$api/prompts.txt")" \
        "$(sha256_file "$api/visible_transcript.txt")" \
        "$(sha256_file "$api/state/leo.state")" \
        "$(sha256_file "$async_a/visible_transcript.txt")" \
        "$(sha256_file "$async_a/state/leo.state")" >> "$MATRIX"
done < "$PLAN"

cat "$MATRIX"
printf 'result\tnatural-life-scout-complete\n'
printf '%s natural-life matrix: %s\n' "$PHASE" "$OUT"
