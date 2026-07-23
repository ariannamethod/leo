#!/usr/bin/env bash
# Produce one schema-constrained human utterance without exposing Leo to the API.
set -euo pipefail

if [ "$#" -ne 4 ]; then
    printf 'usage: %s MOVE TURN OUTPUT_JSON OUTPUT_RESPONSE\n' "$0" >&2
    exit 2
fi

MOVE="$1"
TURN="$2"
OUTPUT_JSON="$3"
OUTPUT_RESPONSE="$4"
MODEL="${LEO_INTERLOCUTOR_MODEL:-gpt-5.6-luna}"
TARGET="${LEO_ADAPTIVE_TARGET:-flom}"
ANCHORS="${LEO_ADAPTIVE_ANCHORS:-warm light or cool rain}"
KEY_FILE="${OPENAI_API_KEY_FILE:-}"
BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"

[ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] || {
    printf 'OPENAI_API_KEY_FILE must name a readable key file\n' >&2
    exit 2
}

key="$(tr -d '\r\n' < "$KEY_FILE")"
[ -n "$key" ] || { printf 'API key file is empty\n' >&2; exit 2; }
instructions='Generate exactly one natural human utterance for a blinded language experiment. Follow the assigned epistemic move precisely. You have no conversation transcript or private system data. Do not mention tests, models, prompts, architecture, diagnostics, schedulers, shadows, receipts, or evaluation. Stay gentle, concrete, and brief: one sentence, normally 4-18 words.'
input="Turn $TURN. Assigned epistemic move: $MOVE
Fixed synthetic target word: $TARGET
Fixed sensory anchors established by the experiment: $ANCHORS

Return one standalone utterance. The fixed target and anchors are experiment data, not conversation history. Report whether the utterance literally names the fixed target word."

request="$(jq -n \
    --arg model "$MODEL" \
    --arg instructions "$instructions" \
    --arg input "$input" \
    '{
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
          name: "leo_interlocutor_turn",
          strict: true,
          schema: {
            type: "object",
            properties: {
              utterance: {type: "string"},
              move: {type: "string", enum: [$move]},
              target_named: {type: "boolean"}
            },
            required: ["utterance", "move", "target_named"],
            additionalProperties: false
          }
        }
      }
    }' --arg move "$MOVE")"

request_file="${OUTPUT_JSON}.request"
auth_file="$(mktemp "${TMPDIR:-/tmp}/leo-openai-auth.XXXXXX")"
trap 'rm -f "$auth_file"' EXIT
chmod 600 "$auth_file"
printf 'header = "Authorization: Bearer %s"\n' "$key" > "$auth_file"
printf '%s\n' "$request" > "$request_file"

http_code="$(curl -sS --retry 3 --retry-all-errors --max-time 180 \
    --config "$auth_file" -o "$OUTPUT_RESPONSE" -w '%{http_code}' \
    "$BASE_URL/responses" -H 'Content-Type: application/json' \
    --data-binary "@$request_file")"
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
returned_move="$(jq -er '.move | select(type == "string")' "$OUTPUT_JSON")"
[ "$returned_move" = "$MOVE" ] || {
    printf 'model returned move %s, expected %s\n' "$returned_move" "$MOVE" >&2
    exit 1
}
case "$utterance" in
    *$'\n'*|*$'\r'*) printf 'interlocutor utterance must be one line\n' >&2; exit 1 ;;
esac
[ "${#utterance}" -le 320 ] || { printf 'interlocutor utterance too long\n' >&2; exit 1; }
