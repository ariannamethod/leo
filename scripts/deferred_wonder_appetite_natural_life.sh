#!/usr/bin/env bash
# A.62: measure appetite coverage in transcript-reactive ordinary dialogue.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-natural-life-$STAMP}"
SEEDS=(83 137 211)
TURNS=64
BIRTH_PROMPTS=(
    "Is suvin like rain or sea?"
    "Is nareth like light or dark?"
    "Is flom like mother or father?"
    "Is lume like tree or wind?"
    "Is tavin like book or pages?"
    "Is merel like window or door?"
    "Is porel like night or dream?"
    "Is cavin like love or heart?"
)
EMBODY_PROMPTS=(
    "nareth."
    "lume."
    "nareth."
    "lume."
    "nareth."
    "lume."
    "suvin."
)
SETTLE_PROMPTS=(
    "The room is quiet."
    "Rain touches the window."
    "A book waits on the table."
    "Someone walks beside the sea."
    "Morning enters through the door."
    "The candle burns slowly."
    "Birds move above the house."
    "Night comes gently."
)
TOTAL_DIALOGUE_TURNS=$((${#SEEDS[@]} * TURNS))

if [ "${LEO_APPETITE_NATURAL_LIFE_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\tbirth_turns\tembodiment_turns\tsettle_turns\tlives\tturns_per_life\tinterlocutor\tfuture_at_proposal\toutcome_assignment\n'
    printf 'natural-visible\t%d\t%d\t%d\t%d\t%d\tlocal-visible-followup-v1\tnot-born\tnone\n' \
        "${#BIRTH_PROMPTS[@]}" "${#EMBODY_PROMPTS[@]}" \
        "${#SETTLE_PROMPTS[@]}" "${#SEEDS[@]}" "$TURNS"
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/birth" "$OUT/body"

PLAN="$OUT/sealed-policy.tsv"
printf 'stage\tordinal\tseed\tcontract\n' > "$PLAN"
for i in "${!BIRTH_PROMPTS[@]}"; do
    printf 'birth\t%d\t0\t%s\n' "$((i + 1))" \
        "${BIRTH_PROMPTS[$i]}" >> "$PLAN"
done
for i in "${!EMBODY_PROMPTS[@]}"; do
    printf 'embody\t%d\t0\t%s\n' "$((i + 1))" \
        "${EMBODY_PROMPTS[$i]}" >> "$PLAN"
done
for i in "${!SETTLE_PROMPTS[@]}"; do
    printf 'settle\t%d\t0\t%s\n' "$((i + 1))" \
        "${SETTLE_PROMPTS[$i]}" >> "$PLAN"
done
for seed in "${SEEDS[@]}"; do
    printf 'dialogue\t64\t%d\tfirst-prompt-fixed; later-prompt-visible-reply-only\n' \
        "$seed" >> "$PLAN"
done
printf 'policy\t1\t0\tsha256:%s\n' "$(
    shasum -a 256 "$ROOT/scripts/leo_visible_followup.sh" |
        awk '{ print $1 }'
)" >> "$PLAN"
shasum -a 256 "$PLAN" > "$OUT/sealed-policy.sha256"

make -C "$ROOT" leo >/dev/null
"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_holdout_fixture.c" -lm \
    -o "$OUT/holdout-fixture"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

turn=0
for prompt in "${BIRTH_PROMPTS[@]}"; do
    turn=$((turn + 1))
    log="$OUT/birth/turn-$turn.log"
    if [ "$turn" -eq 1 ]; then
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --seed "$((20000 + turn))" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-calibration \
            --no-wonder-appetite-checkpoint \
            --save "$OUT/birth/state" > "$log" 2>&1
    else
        "$ROOT/leo" --load "$OUT/birth/state" \
            --seed "$((20000 + turn))" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-calibration \
            --no-wonder-appetite-checkpoint \
            --save "$OUT/birth/state" > "$log" 2>&1
    fi
done

birth_signature="$(
    sed -nE '
        s/.*\[pre-wonder:.*count=([0-9]+) pending=([^ ]+) episodes=([0-9]+) resolved=([0-9]+).*/\1\/\2\/\3\/\4/p
    ' "$OUT/birth/turn-${#BIRTH_PROMPTS[@]}.log"
)"
[ "$birth_signature" = 7/suvin/1/0 ] || {
    printf 'natural body birth contract failed: %s\n' "$birth_signature" >&2
    exit 1
}

cp "$OUT/birth/state" "$OUT/body/state"
body_turn=0
for prompt in "${EMBODY_PROMPTS[@]}" "${SETTLE_PROMPTS[@]}"; do
    body_turn=$((body_turn + 1))
    "$ROOT/leo" --load "$OUT/body/state" \
        --seed "$((21000 + body_turn))" \
        --respond "$prompt" --debug-field \
        --no-wonder-appetite-calibration \
        --no-wonder-appetite-checkpoint \
        --save "$OUT/body/state" \
        > "$OUT/body/turn-$body_turn.log" 2>&1
done

body_signature="$(
    sed -nE '
        s/.*\[pre-wonder:.*count=([0-9]+) pending=([^ ]+) episodes=([0-9]+) resolved=([0-9]+).*/\1\/\2\/\3\/\4/p
    ' "$OUT/body/turn-$body_turn.log"
)"
[ "$body_signature" = 7/none/3/1 ] || {
    printf 'natural embodiment contract failed: %s\n' "$body_signature" >&2
    exit 1
}
shasum -a 256 "$OUT/body/state" > "$OUT/body/state.sha256"

reply_equal=0
state_equal=0
prefix_equal=0
checkpoint_tail="$("$OUT/holdout-fixture" --checkpoint-tail-size)"
for seed in "${SEEDS[@]}"; do
    life="$OUT/seed-$seed"
    mkdir -p "$life/on" "$life/off"
    cp "$OUT/body/state" "$life/on/state"
    cp "$OUT/body/state" "$life/off/state"
    : > "$life/prompts.txt"
    : > "$life/replies.txt"
    : > "$life/visible-dialogue.txt"
    printf 'turn\tprior_reply_sha256\tselected_word\tprompt\n' \
        > "$life/policy.tsv"

    reply=""
    for local_turn in $(seq 1 "$TURNS"); do
        if [ "$local_turn" -eq 1 ]; then
            prompt="Hello Leo. What feels close today?"
            selected_word=none
            prior_sha=none
        else
            selected_word="$(
                "$ROOT/scripts/leo_visible_followup.sh" \
                    --word "$local_turn" "$reply"
            )"
            [ -n "$selected_word" ] || selected_word=none
            prompt="$(
                "$ROOT/scripts/leo_visible_followup.sh" \
                    "$local_turn" "$reply"
            )"
            prior_sha="$(
                printf '%s' "$reply" | shasum -a 256 |
                    awk '{ print $1 }'
            )"
        fi
        printf '%s\n' "$prompt" >> "$life/prompts.txt"
        printf '%d\t%s\t%s\t%s\n' \
            "$local_turn" "$prior_sha" "$selected_word" "$prompt" \
            >> "$life/policy.tsv"
        "$ROOT/leo" --load "$life/on/state" \
            --seed "$((seed + local_turn - 1))" \
            --respond "$prompt" --debug-field \
            --save "$life/on/state" \
            > "$life/on/turn-$local_turn.log" 2>&1
        reply="$(reply_from_log "$life/on/turn-$local_turn.log")"
        printf '%s\n' "$reply" >> "$life/replies.txt"
        printf 'human: %s\nleo: %s\n' "$prompt" "$reply" \
            >> "$life/visible-dialogue.txt"
    done

    local_turn=0
    while IFS= read -r prompt; do
        local_turn=$((local_turn + 1))
        "$ROOT/leo" --load "$life/off/state" \
            --seed "$((seed + local_turn - 1))" \
            --respond "$prompt" --debug-field \
            --no-wonder-appetite-checkpoint \
            --save "$life/off/state" \
            > "$life/off/turn-$local_turn.log" 2>&1
        on_reply="$(sed -n "${local_turn}p" "$life/replies.txt")"
        off_reply="$(reply_from_log "$life/off/turn-$local_turn.log")"
        [ "$on_reply" = "$off_reply" ] || {
            printf 'checkpoint writer changed seed %d turn %d reply\n' \
                "$seed" "$local_turn" >&2
            exit 1
        }
        reply_equal=$((reply_equal + 1))
    done < "$life/prompts.txt"
    [ "$local_turn" -eq "$TURNS" ] || exit 1

    if cmp -s "$life/on/state" "$life/off/state"; then
        state_equal=$((state_equal + 1))
    fi
    state_size="$(wc -c < "$life/on/state" | tr -d ' ')"
    prefix_size=$((state_size - checkpoint_tail))
    if [ "$prefix_size" -gt 0 ] &&
       cmp -s -n "$prefix_size" "$life/on/state" "$life/off/state"; then
        prefix_equal=$((prefix_equal + 1))
    fi
done

CANDIDATES="$OUT/candidate-turns.tsv"
printf 'seed\tlocal_turn\tbody_turn\tstatus\tword\tmargin\trecurrence\tsilence\tunfinished\tflow_gap\tappetite\tspoken\tliteral\n' \
    > "$CANDIDATES"
for seed in "${SEEDS[@]}"; do
    for local_turn in $(seq 1 "$TURNS"); do
        awk -v seed="$seed" -v local_turn="$local_turn" '
            /\[wonder-appetite: turn=/ {
                line = $0
                status = ""
                margin = 0
                body_turn = 0
                if (match(line, /turn=[0-9]+/))
                    body_turn = substr(line, RSTART + 5, RLENGTH - 5)
                if (match(line, /status=[^ ]+/))
                    status = substr(line, RSTART + 7, RLENGTH - 7)
                if (match(line, /margin=[^ ]+/))
                    margin = substr(line, RSTART + 7, RLENGTH - 7)
                sub(/^.*entries=/, "", line)
                sub(/\].*$/, "", line)
                n = split(line, items, /\|/)
                top = -1
                top_appetite = -1
                top_word = ""
                for (i = 1; i <= n; i++) {
                    split(items[i], values, /[:\/]/)
                    if (values[8] + 0) continue
                    appetite = values[6] + 0
                    if (top < 0 || appetite > top_appetite ||
                        (appetite == top_appetite &&
                         values[1] < top_word)) {
                        top = i
                        top_appetite = appetite
                        top_word = values[1]
                    }
                }
                split(items[top], values, /[:\/]/)
                printf "%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                       seed, local_turn, body_turn, status, values[1],
                       margin, values[2], values[3], values[4],
                       values[5], values[6], values[7], values[8]
            }
        ' "$OUT/seed-$seed/on/turn-$local_turn.log" >> "$CANDIDATES"
    done
done

FORECASTS="$OUT/forecasts.tsv"
printf 'seed\tword\tproposed_turn\tappetite\tspoken\tverdict\n' \
    > "$FORECASTS"
for seed in "${SEEDS[@]}"; do
    awk -v seed="$seed" '
        /\[wonder-appetite-calibration:/ {
            line = $0
            sub(/^.*entries=/, "", line)
            sub(/\].*$/, "", line)
            n = split(line, items, /\|/)
            for (i = 1; i <= n; i++) {
                split(items[i], values, /[:\/]/)
                verdict = values[10]
                if (verdict != "pending" &&
                    verdict != "sustained" &&
                    verdict != "faded" &&
                    verdict != "external" &&
                    verdict != "grounded")
                    continue
                key = values[1] "/" values[2] "/" verdict
                if (seen[key]++) continue
                printf "%d\t%s\t%s\t%s\t%s\t%s\n",
                       seed, values[1], values[2], values[5],
                       values[9], verdict
            }
        }
    ' "$OUT/seed-$seed/on"/turn-*.log >> "$FORECASTS"
done

NEAR="$OUT/near-misses.tsv"
printf 'seed\tlocal_turn\tword\tmargin\trecurrence\tappetite\tspoken\n' \
    > "$NEAR"
awk -F '\t' '
    NR > 1 && $6 >= 0.15 && $7 < 0.75 && $11 >= 0.62 {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               $1, $2, $5, $6, $7, $11, $12
    }
' "$CANDIDATES" >> "$NEAR"

candidate_rows=$(( $(wc -l < "$CANDIDATES") - 1 ))
forecast_rows=$(( $(wc -l < "$FORECASTS") - 1 ))
near_rows=$(( $(wc -l < "$NEAR") - 1 ))
diffuse="$(
    awk -F '\t' 'NR > 1 && $4 == "diffuse" { n++ }
                  END { print n + 0 }' "$CANDIDATES"
)"
IFS=$'\t' read -r max_recurrence max_appetite max_margin < <(
    awk -F '\t' '
        NR > 1 {
            if ($7 > recurrence) recurrence = $7
            if ($11 > appetite) appetite = $11
            if ($6 > margin) margin = $6
        }
        END {
            printf "%.3f\t%.3f\t%.3f\n",
                   recurrence, appetite, margin
        }
    ' "$CANDIDATES"
)
top_signature="$(
    awk -F '\t' '
        NR > 1 { count[$5]++ }
        END { for (word in count) print word ":" count[word] }
    ' "$CANDIDATES" | sort | awk '
        { printf "%s%s", separator, $0; separator = "|" }
        END { print "" }
    '
)"
near_signature="$(
    awk -F '\t' '
        NR == 2 {
            printf "%s/%s/%s/%s/%s/%s",
                   $1, $3, $4, $5, $6, $7
        }
    ' "$NEAR"
)"

[ "$candidate_rows" -eq "$TOTAL_DIALOGUE_TURNS" ] &&
[ "$forecast_rows" -eq 0 ] &&
[ "$diffuse" -eq "$TOTAL_DIALOGUE_TURNS" ] &&
[ "$near_rows" -eq 1 ] &&
[ "$max_recurrence" = 0.400 ] &&
[ "$max_appetite" = 0.670 ] &&
[ "$max_margin" = 0.220 ] &&
[ "$top_signature" = \
  "flom:1|lume:187|merel:2|nareth:2" ] &&
[ "$near_signature" = \
  "211/nareth/0.220/0.400/0.670/1" ] &&
[ "$reply_equal" -eq "$TOTAL_DIALOGUE_TURNS" ] &&
[ "$state_equal" -eq "${#SEEDS[@]}" ] &&
[ "$prefix_equal" -eq "${#SEEDS[@]}" ] || {
    printf 'natural appetite life contract failed\n' >&2
    exit 1
}

OBSERVED="$OUT/observed.tsv"
printf 'case\tlives\tdialogue_turns\tcandidate_rows\tdiffuse\tsalient_forecasts\tnear_misses\tmax_recurrence\tmax_appetite\tmax_margin\ttop_signature\tnear_signature\treply_equal\tstate_equal\tbody_prefix_equal\tverdict\n' \
    > "$OBSERVED"
printf 'natural-visible\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\tcoverage-starved\n' \
    "${#SEEDS[@]}" "$TOTAL_DIALOGUE_TURNS" "$candidate_rows" \
    "$diffuse" "$forecast_rows" "$near_rows" "$max_recurrence" \
    "$max_appetite" "$max_margin" "$top_signature" \
    "$near_signature" "$reply_equal" "$state_equal" \
    "$prefix_equal" >> "$OBSERVED"

cat "$OBSERVED"
printf '\nsealed policy: %s\ncandidate turns: %s\nnear misses: %s\n' \
    "$PLAN" "$CANDIDATES" "$NEAR"
