#!/usr/bin/env bash
# Select one source-blind conversational follow-up from Leo's visible reply.
set -euo pipefail

mode=prompt
if [ "${1:-}" = --word ]; then
    mode=word
    shift
fi
[ "$#" -eq 2 ] || {
    printf 'usage: %s [--word] TURN REPLY\n' "$0" >&2
    exit 2
}
turn="$1"
reply="$2"
case "$turn" in
    ''|*[!0-9]*) printf 'TURN must be a positive integer\n' >&2; exit 2 ;;
esac
[ "$turn" -gt 0 ] || {
    printf 'TURN must be a positive integer\n' >&2
    exit 2
}

word="$(
    printf '%s\n' "$reply" |
        awk '
            BEGIN {
                stop = " leo the and that this with from into what where when"
                stop = stop " who why how your you are was were have has had"
                stop = stop " does did can could would should like feel feels"
                stop = stop " felt just very then than there here something"
                stop = stop " nothing everything someone nobody about inside"
                stop = stop " outside again today happens happen anything"
                stop = stop " different unfinished being after before still"
                stop = stop " maybe little really"
            }
            {
                line = tolower($0)
                gsub(/[^a-z]+/, " ", line)
                n = split(line, words, / +/)
                best = ""
                for (i = 1; i <= n; i++) {
                    word = words[i]
                    if (length(word) >= 4 &&
                        index(stop, " " word " ") == 0 &&
                        length(word) > length(best))
                        best = word
                }
            }
            END { print best }
        '
)"

if [ "$mode" = word ]; then
    printf '%s\n' "$word"
    exit 0
fi

if [ -z "$word" ]; then
    case $((turn % 4)) in
        0) prompt='What feels different now?' ;;
        1) prompt='What do you notice nearby?' ;;
        2) prompt='What comes next?' ;;
        3) prompt='What do you remember?' ;;
    esac
else
    case $((turn % 4)) in
        0) prompt="What happens beside $word?" ;;
        1) prompt="Does $word feel near or far?" ;;
        2) prompt="What is $word like?" ;;
        3) prompt="Can $word change?" ;;
    esac
fi
printf '%s\n' "$prompt"
