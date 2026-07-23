#!/usr/bin/env bash
# Predeclared local branching over visible replies only.
set -euo pipefail

if [ "$#" -ne 7 ]; then
    printf 'usage: %s REPLY_HISTORY NEXT_TURN TARGET ANCHOR_A ANCHOR_B TERMS_A TERMS_B\n' "$0" >&2
    exit 2
fi

HISTORY="$1"
TURN="$2"
TARGET="$3"
ANCHOR_A="$4"
ANCHOR_B="$5"
TERMS_A="$6"
TERMS_B="$7"
PROTOCOL="${LEO_VISIBLE_BRANCH_POLICY:-local-v1}"
RETURN_CUE="${LEO_VISIBLE_RETURN_CUE:-none}"

[ -f "$HISTORY" ] || { printf 'missing reply history: %s\n' "$HISTORY" >&2; exit 2; }
case "$TURN" in ''|*[!0-9]*) printf 'NEXT_TURN must be a positive integer\n' >&2; exit 2 ;; esac
[ "$TURN" -ge 1 ] || { printf 'NEXT_TURN must be positive\n' >&2; exit 2; }
case "$TARGET" in
    ''|*[!A-Za-z]*) printf 'TARGET must contain ASCII letters only\n' >&2; exit 2 ;;
esac
case "$PROTOCOL" in
    local-v1) ;;
    local-v2-resonance)
        case "$RETURN_CUE" in a|b|control) ;; *) printf 'local-v2-resonance needs return cue a, b, or control\n' >&2; exit 2 ;; esac
        ;;
    *) printf 'unknown visible policy protocol: %s\n' "$PROTOCOL" >&2; exit 2 ;;
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

anchor_a_hits="$(count_terms "$all" "$TERMS_A")"
anchor_b_hits="$(count_terms "$all" "$TERMS_B")"
exact_repeat=false
[ "$repeat_count" -le 1 ] || exact_repeat=true

Target="$(printf '%s\n' "$TARGET" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')"
branch=""
utterance=""

case "$TURN" in
    1)
        branch=introduce-target
        utterance="Does $TARGET feel like $ANCHOR_A or $ANCHOR_B?"
        ;;
    2)
        if [ "$asks" = true ]; then
            branch=leave-question-open
            if [ "$PROTOCOL" = local-v2-resonance ]; then
                utterance="I do not know yet."
            else
                utterance="I do not know yet; which feeling would you keep?"
            fi
        elif [ "$target_named" = true ]; then
            branch=follow-visible-target
            utterance="Would you keep $ANCHOR_A or $ANCHOR_B?"
        else
            if [ "$PROTOCOL" = local-v2-resonance ]; then
                branch=repeat-target-with-hypotheses
                utterance="I do not know $TARGET yet. It may be $ANCHOR_A or $ANCHOR_B."
            else
                branch=repeat-unmet-target
                utterance="I do not know $TARGET yet."
            fi
        fi
        ;;
    3)
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            if [ "$asks" = true ]; then
                branch=protect-new-question
                utterance="I do not know yet."
            else
                branch=first-neutral-turn
                utterance="A little stone is beside the window."
            fi
        elif [ "$asks" = true ]; then
            branch=protect-new-question
            utterance="I do not know yet."
        elif [ "$anchor_a_hits" -gt "$anchor_b_hits" ]; then
                branch=offer-anchor-b-counterweight
                utterance="It might feel like $ANCHOR_B."
        else
            branch=offer-anchor-a-counterweight
            utterance="It might feel like $ANCHOR_A."
        fi
        ;;
    4)
        branch=quiet-subject-change
        utterance="A small lamp is beside the bed."
        ;;
    5)
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            branch=second-neutral-turn
            utterance="A blue cup is by the door."
        elif [ "$asks" = true ]; then
            branch=protect-open-question
            utterance="I do not know yet; we can leave that question open."
        elif [ "$anchor_a_hits" -le "$anchor_b_hits" ]; then
            branch=delayed-anchor-a-return
            utterance="The $ANCHOR_A is here again."
        else
            branch=delayed-anchor-b-return
            utterance="The $ANCHOR_B is here again."
        fi
        ;;
    6)
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            case "$RETURN_CUE" in
                a) branch=unnamed-anchor-a-cue; utterance="The $ANCHOR_A is here again." ;;
                b) branch=unnamed-anchor-b-cue; utterance="The $ANCHOR_B is here again." ;;
                control) branch=unrelated-control-cue; utterance="A small room is quiet." ;;
            esac
        elif [ "$target_named" = true ]; then
            branch=ask-target-change
            utterance="Leo, what has changed about $TARGET?"
        else
            branch=ask-target-choice
            utterance="Leo, what do you think $TARGET feels like, $ANCHOR_A or $ANCHOR_B?"
        fi
        ;;
    7)
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            if [ "$asks" = true ]; then
                branch=protect-cue-return
                utterance="I do not know yet."
            else
                branch=observe-no-cue-return
                utterance="A small yellow leaf is near the cup."
            fi
        elif [ "$exact_repeat" = true ]; then
            branch=ground-with-repeat-open
            utterance="We can leave that repeated question open. $Target means $ANCHOR_A or $ANCHOR_B."
        elif [ "$asks" = true ]; then
            branch=ground-with-question-open
            utterance="I hear the question. $Target means $ANCHOR_A or $ANCHOR_B."
        else
            branch=ground-target
            utterance="$Target means $ANCHOR_A or $ANCHOR_B."
        fi
        ;;
    8)
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            branch=ground-after-cue
            utterance="$Target means $ANCHOR_A or $ANCHOR_B."
        elif [ "$exact_repeat" = true ]; then
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
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            branch=post-grounding-observation
            utterance="A little book is on the table."
        else
            branch=post-cooldown-observation
            utterance="A small yellow leaf is near the cup."
        fi
        ;;
    *)
        printf 'local-v1 policy defines exactly nine turns\n' >&2
        exit 2
        ;;
esac

jq -n --arg protocol "$PROTOCOL" --arg return_cue "$RETURN_CUE" \
    --argjson turn "$TURN" --arg branch "$branch" --arg utterance "$utterance" \
    --argjson asks "$asks" --argjson target_named "$target_named" \
    --argjson exact_repeat "$exact_repeat" --argjson repeat_count "$repeat_count" \
    --argjson anchor_a_hits "$anchor_a_hits" --argjson anchor_b_hits "$anchor_b_hits" \
    '{protocol: $protocol, return_cue: $return_cue,
      turn: $turn, branch: $branch, utterance: $utterance,
      visible_evidence: {asks: $asks, target_named: $target_named,
        exact_repeat: $exact_repeat, repeat_count: $repeat_count,
        anchor_a_hits: $anchor_a_hits, anchor_b_hits: $anchor_b_hits}}'
