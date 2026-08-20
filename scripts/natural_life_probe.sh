#!/usr/bin/env bash
# A.118: one visible natural life, one real save/exit/load boundary per turn.
set -Eeuo pipefail

trap 'rc=$?; printf "natural life failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-natural-life-$STAMP}"
LIFE="${LEO_NATURAL_LIFE:-natural}"
ARM="${LEO_NATURAL_ARM:-api}"
BASE_SEED="${LEO_NATURAL_SEED:-211}"
TURNS="${LEO_NATURAL_TURNS:-24}"
OPENING="${LEO_NATURAL_OPENING:-Begin with one quiet, concrete observation from ordinary life.}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
REPLAY_FILE="${LEO_NATURAL_REPLAY_FILE:-}"
ASYNC="${LEO_NATURAL_ASYNC:-0}"
RESUME="${LEO_NATURAL_RESUME:-0}"

case "$ARM" in api|replay|async-a|async-b) ;; *) printf 'invalid arm: %s\n' "$ARM" >&2; exit 2;; esac
case "$BASE_SEED" in ''|*[!0-9]*) printf 'invalid seed\n' >&2; exit 2;; esac
case "$TURNS" in ''|*[!0-9]*) printf 'invalid turn count\n' >&2; exit 2;; esac
[ "$TURNS" -ge 2 ] && [ "$TURNS" -le 64 ] || { printf 'turn count must be 2..64\n' >&2; exit 2; }
[ "$ASYNC" = 0 ] || [ "$ASYNC" = 1 ] || { printf 'LEO_NATURAL_ASYNC must be 0 or 1\n' >&2; exit 2; }
[ "$RESUME" = 0 ] || [ "$RESUME" = 1 ] || { printf 'LEO_NATURAL_RESUME must be 0 or 1\n' >&2; exit 2; }
[ -n "$LIFE" ] && [ -n "$OPENING" ] || { printf 'life and opening must not be empty\n' >&2; exit 2; }
if [ -n "$REPLAY_FILE" ]; then
    [ -f "$REPLAY_FILE" ] || { printf 'missing replay file: %s\n' "$REPLAY_FILE" >&2; exit 2; }
else
    [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] || {
        printf 'OPENAI_API_KEY_FILE must name a readable key file\n' >&2
        exit 2
    }
fi
BIN="$OUT/leo.natural"
STATE="$OUT/state/leo.state"
HISTORY="$OUT/dialogue.jsonl"
PROMPTS="$OUT/prompts.txt"
TRANSCRIPT="$OUT/visible_transcript.txt"
SESSIONS="$OUT/sessions.tsv"
TURNS_TSV="$OUT/turns.tsv"
SUMMARY="$OUT/summary.txt"
COMBINED="$OUT/raw/all.log"

if [ "$RESUME" = 0 ]; then
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/api" "$OUT/raw" "$OUT/state"
    cc "$ROOT/leo.c" -O2 -lm -Wall -Wextra -o "$BIN" -lpthread
    : > "$HISTORY"
    : > "$PROMPTS"
    : > "$TRANSCRIPT"
    : > "$COMBINED"
    printf 'life\tarm\tturn\tsession_seed\thuman\tapi_stance\tapi_reply_reference\tapi_model\n' > "$SESSIONS"
    start_turn=1
    resume_from_json=null
else
    [ -d "$OUT" ] && [ -x "$BIN" ] && [ -s "$STATE" ] &&
        [ -f "$HISTORY" ] && [ -f "$PROMPTS" ] &&
        [ -f "$TRANSCRIPT" ] && [ -f "$SESSIONS" ] && [ -f "$COMBINED" ] || {
        printf 'incomplete resume body: %s\n' "$OUT" >&2
        exit 2
    }
    completed="$(wc -l < "$HISTORY" | tr -d ' ')"
    [ "$completed" -ge 1 ] && [ "$completed" -lt "$TURNS" ] || {
        printf 'resume has %s completed turns for a %s-turn life\n' "$completed" "$TURNS" >&2
        exit 2
    }
    jq -es --argjson completed "$completed" '
        length == $completed and
        all(to_entries[];
            (.value.turn == (.key + 1)) and
            ((.value.human | type) == "string") and
            ((.value.leo | type) == "string"))
    ' "$HISTORY" >/dev/null || { printf 'invalid resume history\n' >&2; exit 2; }
    [ "$(wc -l < "$PROMPTS" | tr -d ' ')" -eq "$completed" ] &&
        [ "$(wc -l < "$SESSIONS" | tr -d ' ')" -eq $((completed + 1)) ] &&
        cmp -s <(jq -r .human "$HISTORY") "$PROMPTS" &&
        cmp -s <(jq -r '"human: " + .human + "\nleo: " + .leo' "$HISTORY") "$TRANSCRIPT" || {
        printf 'resume transcript receipts disagree\n' >&2
        exit 2
    }
    start_turn=$((completed + 1))
    resume_from_json=$start_turn
    printf 'resuming %s at turn %d\n' "$LIFE" "$start_turn" >&2
fi

for ((turn = start_turn; turn <= TURNS; turn++)); do
    session_seed=$((BASE_SEED + turn - 1))
    if [ -n "$REPLAY_FILE" ]; then
        utterance="$(awk -v want="$turn" 'NF && $0 != "/quit" && $0 != "/exit" {
            n++; if (n == want) { print; exit }
        }' "$REPLAY_FILE")"
        [ -n "$utterance" ] || { printf 'replay has no turn %d\n' "$turn" >&2; exit 2; }
        stance=replay
        reference_json=null
        resolved_model=replay
    else
        turn_json="$OUT/api/turn-$(printf '%02d' "$turn").json"
        response_json="$OUT/api/turn-$(printf '%02d' "$turn").response.json"
        OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
            "$ROOT/scripts/natural_interlocutor_turn.sh" \
            "$turn" "$HISTORY" "$OPENING" "$turn_json" "$response_json"
        utterance="$(jq -er .utterance "$turn_json")"
        stance="$(jq -er .stance "$turn_json")"
        reference_json="$(jq -r .reply_reference "$turn_json")"
        resolved_model="$(jq -er .model "$response_json")"
    fi
    case "$utterance" in *$'\t'*|*$'\n'*|*$'\r'*) printf 'turn %d is not TSV-safe\n' "$turn" >&2; exit 2;; esac

    input="$OUT/raw/turn-$(printf '%02d' "$turn").input"
    raw="$OUT/raw/turn-$(printf '%02d' "$turn").log"
    printf '%s\n/quit\n' "$utterance" > "$input"
    args=(--chat --seed "$session_seed" --save "$STATE" --debug-field)
    if [ "$turn" -eq 1 ]; then
        args=(--corpus "$ROOT/leo.txt" "${args[@]}")
    else
        args=(--load "$STATE" "${args[@]}")
    fi
    [ "$ASYNC" = 0 ] || args+=(--async)
    "$BIN" "${args[@]}" < "$input" > "$raw" 2>&1
    if [ "$turn" -gt 1 ]; then
        grep -Fq "[leo] loaded state from $STATE" "$raw" || {
            printf 'turn %d did not load its prior body\n' "$turn" >&2
            exit 1
        }
    fi
    [ -s "$STATE" ] || { printf 'state missing after turn %d\n' "$turn" >&2; exit 1; }
    reply="$(awk -f "$ROOT/scripts/leo_visible_reply.awk" "$raw")"
    [ -n "$reply" ] || { printf 'empty reply at turn %d\n' "$turn" >&2; exit 1; }
    echo_value="$(awk -F 'external_vocab=' '/\[echo: external_vocab=/ {
        split($2, part, /[ ]/); print part[1]; exit
    }' "$raw")"
    [ -n "$echo_value" ] || { printf 'missing echo receipt at turn %d\n' "$turn" >&2; exit 1; }
    wonder_open=false
    grep -q '\[wonder: .* open,' "$raw" && wonder_open=true
    state_event="$(awk '/\[state-swarm: turn=/ {
        start = index($0, " event=")
        if (start) {
            tail = substr($0, start + 7)
            split(tail, part, /[ ]/)
            event = part[1]
        }
    } END { print (event == "" ? "none" : event) }' "$raw")"

    printf '%s\n' "$utterance" >> "$PROMPTS"
    printf 'human: %s\nleo: %s\n' "$utterance" "$reply" >> "$TRANSCRIPT"
    jq -cn --argjson turn "$turn" --arg human "$utterance" --arg leo "$reply" \
        --argjson session_seed "$session_seed" --argjson echo "$echo_value" \
        --argjson wonder_open "$wonder_open" --arg state_event "$state_event" \
        --arg api_stance "$stance" --argjson api_reply_reference "$reference_json" \
        '{turn: $turn, session_seed: $session_seed, human: $human, leo: $leo,
          echo: $echo, wonder_open: $wonder_open, state_event: $state_event,
          api_stance: $api_stance, api_reply_reference: $api_reply_reference}' \
        >> "$HISTORY"
    printf '%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\n' \
        "$LIFE" "$ARM" "$turn" "$session_seed" "$utterance" "$stance" \
        "$reference_json" "$resolved_model" >> "$SESSIONS"
    printf '===== turn %d =====\n' "$turn" >> "$COMBINED"
    cat "$raw" >> "$COMBINED"
done

if [ -n "$REPLAY_FILE" ]; then
    replay_turns="$(awk 'NF && $0 != "/quit" && $0 != "/exit" { n++ } END { print n + 0 }' "$REPLAY_FILE")"
    [ "$replay_turns" -eq "$TURNS" ] || {
        printf 'replay has %d turns, expected %d\n' "$replay_turns" "$TURNS" >&2
        exit 2
    }
fi

printf 'life\tarm\tturn\tsession_seed\thuman\tleo\thuman_words\tleo_words\tleo_chars\tleo_question\texact_repeat\techo\twonder_open\tstate_event\tapi_stance\tapi_reply_reference\n' > "$TURNS_TSV"
jq -sr --arg life "$LIFE" --arg arm "$ARM" '
    def words: gsub("[[:space:]]+"; " ") | split(" ") | map(select(length > 0)) | length;
    . as $rows |
    to_entries[] |
    .key as $i | .value as $row |
    [$life, $arm, $row.turn, $row.session_seed, $row.human, $row.leo,
     ($row.human | words), ($row.leo | words), ($row.leo | length),
     (if ($row.leo | contains("?")) then 1 else 0 end),
     (if $i == 0 then 0 elif $row.leo == $rows[$i - 1].leo then 1 else 0 end),
     $row.echo, (if $row.wonder_open then 1 else 0 end),
     $row.state_event, $row.api_stance,
     (if $row.api_reply_reference == null then "null"
      else ($row.api_reply_reference | tostring) end)] | @tsv
' "$HISTORY" >> "$TURNS_TSV"
awk -v expected_turns="$TURNS" -f "$ROOT/scripts/natural_life_summary.awk" \
    "$TURNS_TSV" > "$SUMMARY"

source=responses-api-visible-transcript
[ -z "$REPLAY_FILE" ] || source=frozen-visible-replay
state_sha="$(shasum -a 256 "$STATE" | awk '{print $1}')"
transcript_sha="$(shasum -a 256 "$TRANSCRIPT" | awk '{print $1}')"
prompts_sha="$(shasum -a 256 "$PROMPTS" | awk '{print $1}')"
jq -n --arg life "$LIFE" --arg arm "$ARM" --arg model "$MODEL" \
    --arg opening "$OPENING" --arg source "$source" \
    --arg state_sha "$state_sha" --arg transcript_sha "$transcript_sha" \
    --arg prompts_sha "$prompts_sha" --argjson base_seed "$BASE_SEED" \
    --argjson turns "$TURNS" --argjson async "$ASYNC" \
    --argjson resumed "$RESUME" --argjson resumed_from "$resume_from_json" \
    '{phase: "A.118", life: $life, arm: $arm, model_requested: $model,
      opening_cue: $opening, source: $source, base_seed: $base_seed,
      turns: $turns, async: ($async == 1), api_store: (if $source == "responses-api-visible-transcript" then false else null end),
      process_resumed: ($resumed == 1), resumed_at_turn: $resumed_from,
      transcript_visible_to_interlocutor: ($source == "responses-api-visible-transcript"),
      diagnostics_visible_to_interlocutor: false,
      state_sha256: $state_sha, transcript_sha256: $transcript_sha,
      prompts_sha256: $prompts_sha}' > "$OUT/manifest.json"

cat "$SUMMARY"
printf 'visible transcript: %s\nmanifest: %s\n' "$TRANSCRIPT" "$OUT/manifest.json"
