#!/usr/bin/env bash
# Let an API model create transcript-blind human utterances while Leo lives locally.
# Every turn is a real save/process-exit/reload boundary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOVES="${1:-$ROOT/scripts/adaptive_moves.txt}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${2:-${TMPDIR:-/tmp}/leo-adaptive-life-$STAMP}"
BASE_SEED="${LEO_ADAPTIVE_SEED:-83}"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
TARGET="${LEO_ADAPTIVE_TARGET:-flom}"
ANCHOR_A="${LEO_ADAPTIVE_ANCHOR_A:-${LEO_ADAPTIVE_WARM_ANCHOR:-warm light}}"
ANCHOR_B="${LEO_ADAPTIVE_ANCHOR_B:-${LEO_ADAPTIVE_COOL_ANCHOR:-cool rain}}"
TERMS_A="${LEO_ADAPTIVE_TERMS_A:-$ANCHOR_A}"
TERMS_B="${LEO_ADAPTIVE_TERMS_B:-$ANCHOR_B}"
ANCHORS="${LEO_ADAPTIVE_ANCHORS:-$ANCHOR_A or $ANCHOR_B}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
REPLAY_FILE="${LEO_INTERLOCUTOR_REPLAY_FILE:-}"
BRANCH_POLICY="${LEO_VISIBLE_BRANCH_POLICY:-}"
BIN="$OUT/leo.adaptive"
STATE="$OUT/state/leo.state"
TRANSCRIPT="$OUT/visible_transcript.txt"
PROMPTS="$OUT/prompts.txt"
COMBINED="$OUT/raw/all.log"
ROWS="$OUT/receipts.tsv"
SESSIONS="$OUT/sessions.tsv"
EDGES="$OUT/sleep_edges.tsv"
HISTORY="$OUT/visible_replies.jsonl"

[ -z "$REPLAY_FILE" ] || [ -z "$BRANCH_POLICY" ] || {
    printf 'replay and visible branch policy are mutually exclusive\n' >&2
    exit 2
}
if [ -n "$BRANCH_POLICY" ]; then
    [ "$BRANCH_POLICY" = local-v1 ] || [ "$BRANCH_POLICY" = local-v2-resonance ] || {
        printf 'unknown LEO_VISIBLE_BRANCH_POLICY: %s\n' "$BRANCH_POLICY" >&2
        exit 2
    }
elif [ -n "$REPLAY_FILE" ]; then
    [ -f "$REPLAY_FILE" ] || { printf 'missing replay file: %s\n' "$REPLAY_FILE" >&2; exit 2; }
else
    [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] || {
        printf 'OPENAI_API_KEY_FILE must name a readable key file\n' >&2
        exit 2
    }
fi
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
case "$TARGET" in
    ''|*[!A-Za-z]*) printf 'LEO_ADAPTIVE_TARGET must contain ASCII letters only\n' >&2; exit 2 ;;
esac
mkdir -p "$OUT/api" "$OUT/policy" "$OUT/raw" "$OUT/state"
cc "$ROOT/leo.c" -O2 -lm -Wall -Wextra -o "$BIN" -lpthread
: > "$TRANSCRIPT"
: > "$PROMPTS"
: > "$COMBINED"
: > "$HISTORY"
printf 'scenario\tseed\tturn\tsession\tsession_seed\tprompt\tmove\ttarget\ttarget_named\ttarget_named_reported\tapi_model\n' > "$SESSIONS"

turn=0
while IFS= read -r move; do
    [ -n "$move" ] || continue
    case "$move" in \#*) continue ;; esac
    turn=$((turn + 1))
    session_seed=$((BASE_SEED + turn - 1))
    move_used="$move"
    if [ -n "$BRANCH_POLICY" ]; then
        policy_json="$OUT/policy/turn-$(printf '%02d' "$turn").json"
        "$ROOT/scripts/visible_branch_policy.sh" "$HISTORY" "$turn" \
            "$TARGET" "$ANCHOR_A" "$ANCHOR_B" "$TERMS_A" "$TERMS_B" \
            > "$policy_json"
        utterance="$(jq -er .utterance "$policy_json")"
        move_used="$(jq -er .branch "$policy_json")"
        target_named_reported=not-applicable
        resolved_model="local-visible-policy-$BRANCH_POLICY"
    elif [ -n "$REPLAY_FILE" ]; then
        utterance="$(awk -v want="$turn" '
            NF && $0 != "/quit" && $0 != "/exit" { n++; if (n == want) { print; exit } }
        ' "$REPLAY_FILE")"
        [ -n "$utterance" ] || { printf 'replay file has no turn %d\n' "$turn" >&2; exit 2; }
        target_named_reported=not-applicable
        resolved_model=replay
    else
        turn_json="$OUT/api/turn-$(printf '%02d' "$turn").json"
        response_json="$OUT/api/turn-$(printf '%02d' "$turn").response.json"
        OPENAI_API_KEY_FILE="$KEY_FILE" LEO_INTERLOCUTOR_MODEL="$MODEL" \
            LEO_ADAPTIVE_TARGET="$TARGET" LEO_ADAPTIVE_ANCHORS="$ANCHORS" \
            "$ROOT/scripts/openai_interlocutor_turn.sh" \
            "$move" "$turn" "$turn_json" "$response_json"
        utterance="$(jq -er .utterance "$turn_json")"
        target_named_reported="$(jq -r '.target_named | select(type == "boolean")' "$turn_json")"
        [ "$target_named_reported" = true ] || [ "$target_named_reported" = false ] || {
            printf 'turn %d returned no target_named boolean\n' "$turn" >&2
            exit 1
        }
        resolved_model="$(jq -er '.model' "$response_json")"
    fi
    target_named=false
    if printf '%s\n' "$utterance" | grep -Eiq "(^|[^[:alnum:]_])${TARGET}([^[:alnum:]_]|$)"; then
        target_named=true
    fi
    input="$OUT/raw/turn-$(printf '%02d' "$turn").input"
    raw="$OUT/raw/turn-$(printf '%02d' "$turn").log"
    printf '%s\n/quit\n' "$utterance" > "$input"
    if [ "$turn" -eq 1 ]; then
        "$BIN" --corpus "$ROOT/leo.txt" --chat --seed "$session_seed" \
            --save "$STATE" < "$input" > "$raw" 2>&1
    else
        "$BIN" --load "$STATE" --chat --seed "$session_seed" \
            --save "$STATE" < "$input" > "$raw" 2>&1
        grep -Fq "[leo] loaded state from $STATE" "$raw" || {
            printf 'turn %d did not load its prior state\n' "$turn" >&2
            exit 1
        }
    fi
    [ -s "$STATE" ] || { printf 'state missing after turn %d\n' "$turn" >&2; exit 1; }
    reply="$(awk -f "$ROOT/scripts/leo_visible_reply.awk" "$raw")"

    printf '%s\n' "$utterance" >> "$PROMPTS"
    printf 'human: %s\nleo: %s\n' "$utterance" "$reply" >> "$TRANSCRIPT"
    jq -cn --argjson turn "$turn" --arg reply "$reply" \
        '{turn: $turn, reply: $reply}' >> "$HISTORY"
    printf 'adaptive\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$BASE_SEED" "$turn" "$turn" "$session_seed" "$utterance" \
        "$move_used" "$TARGET" "$target_named" "$target_named_reported" \
        "$resolved_model" >> "$SESSIONS"
    printf '===== turn %d =====\n' "$turn" >> "$COMBINED"
    cat "$raw" >> "$COMBINED"
done < "$MOVES"

[ "$turn" -gt 1 ] || { printf 'adaptive move plan needs at least two turns\n' >&2; exit 1; }
if [ -n "$REPLAY_FILE" ]; then
    replay_turns="$(awk 'NF && $0 != "/quit" && $0 != "/exit" { n++ } END { print n + 0 }' "$REPLAY_FILE")"
    [ "$replay_turns" -eq "$turn" ] || {
        printf 'replay has %d turns but move plan has %d\n' "$replay_turns" "$turn" >&2
        exit 2
    }
fi
printf '/quit\n' >> "$PROMPTS"
printf 'scenario\tseed\tproposal_turn\tprompt\treply\taction\ttarget\tconfidence\treasons\tobserved_turn\tnext_prompt\tnext_reply\tverdict\n' > "$ROWS"
awk -v scenario=adaptive -v seed="$BASE_SEED" -v prompt_file="$PROMPTS" \
    -f "$ROOT/scripts/shadow_dialogue_report.awk" "$COMBINED" >> "$ROWS"
awk -f "$ROOT/scripts/shadow_receipt_summary.awk" "$ROWS" > "$OUT/summary.txt"
awk -f "$ROOT/scripts/shadow_sleep_edges.awk" "$SESSIONS" "$ROWS" > "$EDGES"

api_called=true
source=responses-api
[ -z "$REPLAY_FILE" ] || { api_called=false; source=frozen-replay; }
[ -z "$BRANCH_POLICY" ] || { api_called=false; source="local-visible-policy-$BRANCH_POLICY"; }
jq_cue="${LEO_VISIBLE_RETURN_CUE:-none}"
jq -n --arg model "$MODEL" --arg target "$TARGET" --arg anchors "$ANCHORS" \
    --arg anchor_a "$ANCHOR_A" --arg anchor_b "$ANCHOR_B" \
    --arg terms_a "$TERMS_A" --arg terms_b "$TERMS_B" \
    --arg return_cue "$jq_cue" \
    --arg source "$source" --argjson api_called "$api_called" \
    --argjson base_seed "$BASE_SEED" --argjson turns "$turn" \
    '{model_requested: $model, target: $target, anchors: $anchors,
      anchor_a: $anchor_a, anchor_b: $anchor_b,
      terms_a: $terms_a, terms_b: $terms_b,
      return_cue: $return_cue,
      base_seed: $base_seed, turns: $turns,
      interlocutor_source: $source, api_called: $api_called,
      api_store: (if $api_called then false else null end),
      transcript_visible_to_interlocutor: false,
      diagnostics_visible_to_interlocutor: false}' \
    > "$OUT/manifest.json"

cat "$OUT/summary.txt"
printf '\nturns=%d sleep-crossing=%d\n' "$turn" "$(( $(wc -l < "$EDGES") - 1 ))"
printf 'visible transcript: %s\nreceipts: %s\n' "$TRANSCRIPT" "$ROWS"
if [ -n "$BRANCH_POLICY" ]; then
    printf 'interlocutor: local visible-branch policy %s (no API calls)\n' "$BRANCH_POLICY"
elif [ -n "$REPLAY_FILE" ]; then
    printf 'interlocutor: frozen replay (no API calls)\n'
else
    printf 'API records: %s/api\n' "$OUT"
fi
