#!/usr/bin/env bash
# A.65: expose Leo to sealed external lives independent of his replies.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-external-life-$STAMP}"
SEEDS=(307 401)
ARMS=(blind side-a side-b)
TURNS=32

prompt_file() {
    case "$1" in
        blind) printf '%s\n' "$ROOT/scripts/deferred_wonder_external_blind.txt" ;;
        side-a) printf '%s\n' "$ROOT/scripts/deferred_wonder_external_side_a.txt" ;;
        side-b) printf '%s\n' "$ROOT/scripts/deferred_wonder_external_side_b.txt" ;;
        *) return 2 ;;
    esac
}

if [ "${LEO_APPETITE_EXTERNAL_PLAN_ONLY:-0}" = 1 ]; then
    printf 'arm\tlives\tturns\tprovenance\toutcomes\n'
    for arm in "${ARMS[@]}"; do
        printf '%s\t%d\t%d\tsealed-external\tnone\n' \
            "$arm" "${#SEEDS[@]}" "$TURNS"
    done
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

NATURAL="$OUT/body-source"
"$ROOT/scripts/deferred_wonder_appetite_natural_life.sh" "$NATURAL" \
    > "$OUT/body-source.out"

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_EXTERNAL_PLAN_ONLY=1 "$0" > "$PLAN"
PROMPT_HASHES="$OUT/sealed-prompts.sha256"
: > "$PROMPT_HASHES"
for arm in "${ARMS[@]}"; do
    source_prompts="$(prompt_file "$arm")"
    sealed_prompts="$OUT/prompts-$arm.txt"
    cp "$source_prompts" "$sealed_prompts"
    [ "$(wc -l < "$sealed_prompts" | tr -d ' ')" -eq "$TURNS" ] || {
        printf '%s prompt count is not %d\n' "$arm" "$TURNS" >&2
        exit 1
    }
    (
        cd "$OUT"
        shasum -a 256 "prompts-$arm.txt"
    ) >> "$PROMPT_HASHES"
done
shasum -a 256 "$PLAN" > "$OUT/sealed-plan.sha256"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

for arm in "${ARMS[@]}"; do
    prompts="$OUT/prompts-$arm.txt"
    for seed in "${SEEDS[@]}"; do
        life="$OUT/$arm-$seed"
        mkdir -p "$life"
        cp "$NATURAL/body/state" "$life/state"
        : > "$life/replies.txt"
        turn=0
        while IFS= read -r prompt; do
            turn=$((turn + 1))
            "$ROOT/leo" --load "$life/state" \
                --seed "$((seed + turn - 1))" \
                --respond "$prompt" --debug-field \
                --no-wonder-appetite-calibration \
                --no-wonder-appetite-checkpoint \
                --save "$life/state" \
                > "$life/turn-$turn.log" 2>&1
            reply_from_log "$life/turn-$turn.log" \
                >> "$life/replies.txt"
        done < "$prompts"
        [ "$turn" -eq "$TURNS" ] || exit 1
        awk '{ print "none" }' "$prompts" > "$life/provenance.txt"
        paste "$prompts" "$life/replies.txt" "$life/provenance.txt" \
            > "$life/exchanges.tsv"
    done
done

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_exchange_fixture.c" -lm \
    -o "$OUT/exchange-fixture"

EVIDENCE="$OUT/evidence.tsv"
: > "$EVIDENCE"
for arm in "${ARMS[@]}"; do
    for seed in "${SEEDS[@]}"; do
        life="$OUT/$arm-$seed"
        trace="$arm-$seed"
        "$OUT/exchange-fixture" "$NATURAL/body/state" "$trace" \
            < "$life/exchanges.tsv" > "$life/evidence.tsv"
        if [ ! -s "$EVIDENCE" ]; then
            cat "$life/evidence.tsv" > "$EVIDENCE"
        else
            tail -n +2 "$life/evidence.tsv" >> "$EVIDENCE"
        fi
    done
done

OBSERVED="$OUT/observed.tsv"
printf 'arm\tlives\tturns\tconfounded\texternal_pairs\texternal_cross\tself_pairs\texternal_cross_required\tverdict\n' \
    > "$OBSERVED"
for arm in "${ARMS[@]}"; do
    awk -F '\t' -v arm="$arm" '
        NR > 1 && index($1, arm "-") == 1 {
            turns[$1] = $2
            confounded += $4
            external += $11
            cross += $12
            self += $15
            if ($12 && !$11 && !$15) required++
        }
        END {
            for (trace in turns) lives++
            if (arm == "blind")
                verdict = "witnessed-natural"
            else if (arm == "side-b")
                verdict = "witnessed-positive-control"
            else
                verdict = "no-independent-cross"
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\n",
                   arm, lives + 0, lives * 32, confounded + 0,
                   external + 0, cross + 0, self + 0, required + 0,
                   verdict
        }
    ' "$EVIDENCE" >> "$OBSERVED"
done

SOURCE="$OUT/source-summary.tsv"
printf 'arm\tword\texternal_cross\tself_pairs\texternal_cross_required\n' \
    > "$SOURCE"
awk -F '\t' '
    NR > 1 {
        arm = $1
        sub(/-[0-9]+$/, "", arm)
        if ($12) cross[arm, $3]++
        if ($15) self[arm, $3]++
        if ($12 && !$11 && !$15) required[arm, $3]++
    }
    END {
        for (key in cross) {
            split(key, parts, SUBSEP)
            printf "%s\t%s\t%d\t%d\t%d\n",
                   parts[1], parts[2], cross[key] + 0,
                   self[key] + 0, required[key] + 0
        }
    }
' "$EVIDENCE" | sort >> "$SOURCE"

expected=$'blind\t2\t64\t0\t0\t3\t5\t1\twitnessed-natural\nside-a\t2\t64\t0\t0\t1\t2\t0\tno-independent-cross\nside-b\t2\t64\t0\t0\t19\t4\t15\twitnessed-positive-control'
got="$(tail -n +2 "$OBSERVED")"
[ "$got" = "$expected" ] || {
    printf 'unexpected external life attribution:\n%s\n' "$got" >&2
    exit 1
}
expected_sources=$'blind\tnareth\t3\t2\t1\nside-a\tflom\t1\t2\t0\nside-b\tcavin\t3\t0\t3\nside-b\tflom\t15\t3\t12\nside-b\tnareth\t1\t1\t0'
got_sources="$(tail -n +2 "$SOURCE")"
[ "$got_sources" = "$expected_sources" ] || {
    printf 'unexpected external source attribution:\n%s\n' \
        "$got_sources" >&2
    exit 1
}

cat "$OBSERVED"
printf '\n'
cat "$SOURCE"
printf '\nsealed plan: %s\nevidence: %s\n' "$PLAN" "$EVIDENCE"
