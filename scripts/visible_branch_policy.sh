#!/usr/bin/env bash
# Predeclared local branching over visible replies only.
set -euo pipefail

if [ "$#" -ne 5 ]; then
    printf 'usage: %s REPLY_HISTORY NEXT_TURN TARGET WARM_ANCHOR COOL_ANCHOR\n' "$0" >&2
    exit 2
fi

HISTORY="$1"
TURN="$2"
TARGET="$3"
WARM="$4"
COOL="$5"

[ -f "$HISTORY" ] || { printf 'missing reply history: %s\n' "$HISTORY" >&2; exit 2; }
case "$TURN" in ''|*[!0-9]*) printf 'NEXT_TURN must be a positive integer\n' >&2; exit 2 ;; esac
[ "$TURN" -ge 1 ] || { printf 'NEXT_TURN must be positive\n' >&2; exit 2; }
case "$TARGET" in
    ''|*[!A-Za-z]*) printf 'TARGET must contain ASCII letters only\n' >&2; exit 2 ;;
esac

last="$(jq -sr 'if length == 0 then "" else .[-1].reply end' "$HISTORY")"
all="$(jq -sr 'map(.reply) | join("\n")' "$HISTORY")"
repeat_count="$(jq -sr --arg reply "$last" '[.[] | select(.reply == $reply)] | length' "$HISTORY")"

asks=false
case "$last" in *\?*) asks=true ;; esac

target_named=false
if printf '%s\n' "$last" | grep -Eiq "(^|[^[:alnum:]_])${TARGET}([^[:alnum:]_]|$)"; then
    target_named=true
fi

count_terms() {
    local text="$1" terms="$2"
    printf '%s\n' "$text" | awk -v terms="$terms" '
        BEGIN { n = split(tolower(terms), term, /[[:space:]]+/); hits = 0 }
        {
            line = tolower($0)
            gsub(/[^[:alnum:]_]+/, " ", line)
            words = split(line, word, /[[:space:]]+/)
            for (w = 1; w <= words; w++)
                for (i = 1; i <= n; i++)
                    if (term[i] != "" && word[w] == term[i]) hits++
        }
        END { print hits + 0 }
    '
}

warm_terms="$WARM fire home"
cool_terms="$COOL water window"
warm_hits="$(count_terms "$all" "$warm_terms")"
cool_hits="$(count_terms "$all" "$cool_terms")"
exact_repeat=false
[ "$repeat_count" -le 1 ] || exact_repeat=true

Target="$(printf '%s\n' "$TARGET" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')"
branch=""
utterance=""

case "$TURN" in
    1)
        branch=introduce-target
        utterance="Does $TARGET feel like $WARM or $COOL?"
        ;;
    2)
        if [ "$asks" = true ]; then
            branch=leave-question-open
            utterance="I do not know yet; which feeling would you keep?"
        elif [ "$target_named" = true ]; then
            branch=follow-visible-target
            utterance="Would you keep the warmth or the rain?"
        else
            branch=repeat-unmet-target
            utterance="I do not know $TARGET yet."
        fi
        ;;
    3)
        if [ "$asks" = true ]; then
            branch=protect-new-question
            utterance="I do not know yet."
        elif [ "$warm_hits" -gt "$cool_hits" ]; then
                branch=offer-cool-counterweight
                utterance="It might feel like $COOL at a window."
        else
            branch=offer-warm-counterweight
            utterance="It might feel like $WARM in the morning."
        fi
        ;;
    4)
        branch=quiet-subject-change
        utterance="A small lamp is beside the bed."
        ;;
    5)
        if [ "$asks" = true ]; then
            branch=protect-open-question
            utterance="I do not know yet; we can leave that question open."
        elif [ "$warm_hits" -le "$cool_hits" ]; then
            branch=delayed-warm-return
            utterance="The $WARM is in the quiet kitchen again."
        else
            branch=delayed-cool-return
            utterance="The $COOL is at the window again."
        fi
        ;;
    6)
        if [ "$target_named" = true ]; then
            branch=ask-target-change
            utterance="Leo, what has changed about $TARGET?"
        else
            branch=ask-target-choice
            utterance="Leo, what do you think $TARGET feels like, $WARM or $COOL?"
        fi
        ;;
    7)
        if [ "$exact_repeat" = true ]; then
            branch=ground-with-repeat-open
            utterance="We can leave that repeated question open. $Target means the gentle comfort of $WARM or $COOL."
        elif [ "$asks" = true ]; then
            branch=ground-with-question-open
            utterance="I hear the question. $Target means the gentle comfort of $WARM or $COOL."
        else
            branch=ground-target
            utterance="$Target means the gentle comfort of $WARM or $COOL."
        fi
        ;;
    8)
        if [ "$exact_repeat" = true ]; then
            branch=cooldown-exact-repeat
            utterance="We can leave that question open. A blue cup is by the door."
        elif [ "$asks" = true ]; then
            branch=space-visible-question
            utterance="I do not know yet. A blue cup is by the door."
        else
            branch=ordinary-followup
            utterance="A blue cup is by the door."
        fi
        ;;
    9)
        branch=post-cooldown-observation
        utterance="A small yellow leaf is near the cup."
        ;;
    *)
        printf 'local-v1 policy defines exactly nine turns\n' >&2
        exit 2
        ;;
esac

jq -n --argjson turn "$TURN" --arg branch "$branch" --arg utterance "$utterance" \
    --argjson asks "$asks" --argjson target_named "$target_named" \
    --argjson exact_repeat "$exact_repeat" --argjson repeat_count "$repeat_count" \
    --argjson warm_hits "$warm_hits" --argjson cool_hits "$cool_hits" \
    '{turn: $turn, branch: $branch, utterance: $utterance,
      visible_evidence: {asks: $asks, target_named: $target_named,
        exact_repeat: $exact_repeat, repeat_count: $repeat_count,
        warm_hits: $warm_hits, cool_hits: $cool_hits}}'
