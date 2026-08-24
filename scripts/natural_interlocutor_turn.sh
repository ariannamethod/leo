#!/usr/bin/env bash
# A.118: let an API model continue only Leo's visible conversation.
set -Eeuo pipefail

if [ "$#" -ne 5 ]; then
    printf 'usage: %s TURN HISTORY_JSONL OPENING_CUE OUTPUT_JSON OUTPUT_RESPONSE\n' "$0" >&2
    exit 2
fi

TURN="$1"
HISTORY="$2"
OPENING="$3"
OUTPUT_JSON="$4"
OUTPUT_RESPONSE="$5"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
REQUEST_ONLY="${LEO_NATURAL_REQUEST_ONLY:-0}"
HTTP_RETRIES="${LEO_NATURAL_CURL_RETRIES:-3}"
REQUEST_FILE="${OUTPUT_JSON}.request.json"

case "$TURN" in ''|*[!0-9]*) printf 'turn must be a positive integer\n' >&2; exit 2;; esac
[ "$TURN" -ge 1 ] || { printf 'turn must be positive\n' >&2; exit 2; }
case "$HTTP_RETRIES" in ''|*[!0-9]*) printf 'curl retries must be a non-negative integer\n' >&2; exit 2;; esac
[ "$HTTP_RETRIES" -le 8 ] || { printf 'curl retries must be 0..8\n' >&2; exit 2; }
[ -f "$HISTORY" ] || { printf 'missing visible history: %s\n' "$HISTORY" >&2; exit 2; }
[ -n "$OPENING" ] || { printf 'opening cue must not be empty\n' >&2; exit 2; }

jq -es --argjson turn "$TURN" '
    length == ($turn - 1) and
    all(to_entries[];
        ((.value | type) == "object") and
        (.value.turn == (.key + 1)) and
        ((.value.human | type) == "string") and
        (.value.human | length > 0) and
        ((.value.leo | type) == "string") and
        (.value.leo | length > 0))
' "$HISTORY" >/dev/null || {
    printf 'visible history is incomplete or has an invalid schema\n' >&2
    exit 2
}

instructions="You are the human participant in a blinded natural conversation with Leo, a small non-assistant language organism. Continue only from the visible dialogue supplied in this request. Treat Leo's words as speech worth answering, not as output to grade. Be gentle, concrete, curious, and emotionally ordinary; you may clarify, follow, answer, disagree softly, or change subject when that is natural. Do not test Leo, teach toward a hidden target, imitate his broken grammar, diagnose him, narrate the experiment, or mention models, prompts, architecture, state, memory internals, scores, receipts, evaluation, or API calls. Return one short human utterance, normally 3-22 words and never more than one line."

request="$(jq -n \
    --arg model "$MODEL" \
    --arg instructions "$instructions" \
    --arg opening "$OPENING" \
    --argjson turn "$TURN" \
    --slurpfile history "$HISTORY" '
    ($history | map("human: " + .human + "\nleo: " + .leo) | join("\n")) as $visible |
    (if $turn == 1 then
        "This is turn 1. Opening cue: " + $opening +
        "\nThere is no prior dialogue. Begin naturally."
     else
        "This is turn " + ($turn | tostring) +
        ". Continue the visible conversation below. Do not assume anything else.\n\n" +
        $visible
     end) as $input |
    {
      model: $model,
      store: false,
      reasoning: {effort: "low"},
      max_output_tokens: 256,
      instructions: $instructions,
      input: $input,
      text: {
        verbosity: "low",
        format: {
          type: "json_schema",
          name: "leo_natural_interlocutor_turn",
          strict: true,
          schema: {
            type: "object",
            properties: {
              utterance: {type: "string"},
              stance: {
                type: "string",
                enum: ["open", "follow", "clarify", "answer", "comfort", "challenge", "shift", "close"]
              },
              reply_reference: {type: "boolean"}
            },
            required: ["utterance", "stance", "reply_reference"],
            additionalProperties: false
          }
        }
      }
    }')"
printf '%s\n' "$request" > "$REQUEST_FILE"

if [ "$REQUEST_ONLY" = 1 ]; then
    printf 'natural interlocutor request: %s\n' "$REQUEST_FILE"
    exit 0
fi

[ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable key file\n' >&2
    exit 2
}
key="$(tr -d '\r\n' < "$KEY_FILE")"
[ -n "$key" ] || { printf 'API key file is empty\n' >&2; exit 2; }

auth_file="$(mktemp "${TMPDIR:-/tmp}/leo-natural-openai-auth.XXXXXX")"
trap 'rm -f "$auth_file"' EXIT
chmod 600 "$auth_file"
printf 'header = "Authorization: Bearer %s"\n' "$key" > "$auth_file"

http_code="$(curl -sS --retry "$HTTP_RETRIES" --retry-all-errors --max-time 180 \
    --config "$auth_file" -o "$OUTPUT_RESPONSE" -w '%{http_code}' \
    "$BASE_URL/responses" -H 'Content-Type: application/json' \
    --data-binary "@$REQUEST_FILE")"
if [ "$http_code" != 200 ]; then
    printf 'OpenAI Responses API returned HTTP %s: ' "$http_code" >&2
    jq -r '.error.message // "unknown error"' "$OUTPUT_RESPONSE" >&2
    exit 1
fi

jq -er '
    [.output[]? | select(.type == "message") | .content[]? |
     select(.type == "output_text") | .text] | join("")
' "$OUTPUT_RESPONSE" | jq -e . > "$OUTPUT_JSON"

utterance="$(jq -er '.utterance | select(type == "string" and length > 0)' "$OUTPUT_JSON")"
stance="$(jq -er '.stance | select(type == "string")' "$OUTPUT_JSON")"
reference_type="$(jq -r '.reply_reference | type' "$OUTPUT_JSON")"
case "$stance" in
    open|follow|clarify|answer|comfort|challenge|shift|close) ;;
    *) printf 'invalid interlocutor stance: %s\n' "$stance" >&2; exit 1;;
esac
[ "$reference_type" = boolean ] || {
    printf 'interlocutor returned no reply_reference boolean\n' >&2
    exit 1
}
case "$utterance" in
    *$'\n'*|*$'\r'*|*$'\t'*)
        printf 'interlocutor utterance must be one TSV-safe line\n' >&2
        exit 1
        ;;
    /quit|/exit|/save\ *)
        printf 'interlocutor utterance cannot be a Leo command\n' >&2
        exit 1
        ;;
esac
[ "${#utterance}" -le 320 ] || {
    printf 'interlocutor utterance too long\n' >&2
    exit 1
}
