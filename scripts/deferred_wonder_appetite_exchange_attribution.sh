#!/usr/bin/env bash
# A.64: attribute appetite evidence to external, reflected, and Leo channels.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-exchange-attribution-$STAMP}"

if [ "${LEO_APPETITE_EXCHANGE_PLAN_ONLY:-0}" = 1 ]; then
    printf 'trace\tturns\tcontract\n'
    printf 'external-pair\t1\texternal-sufficient\n'
    printf 'self-pair\t1\tself-sufficient\n'
    printf 'external-cross-ab\t1\texternal-cross-required\n'
    printf 'external-cross-ba\t1\texternal-cross-required-reversed\n'
    printf 'reflected-cross\t1\treflected-cross-required\n'
    printf 'echo-one\t1\tsame-side-echo\n'
    printf 'external-temporal\t2\texternal-sufficient-adjacent\n'
    printf 'self-temporal\t2\tself-sufficient-adjacent\n'
    printf 'cross-owner\t1\tdifferent-owner-sides\n'
    printf 'literal-human\t1\thuman-address-confound\n'
    printf 'literal-leo\t1\tleo-self-address-confound\n'
    printf 'natural-83\t64\tA.62-visible-exchanges\n'
    printf 'natural-137\t64\tA.62-visible-exchanges\n'
    printf 'natural-211\t64\tA.62-visible-exchanges\n'
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/traces"

NATURAL="$OUT/natural"
"$ROOT/scripts/deferred_wonder_appetite_natural_life.sh" "$NATURAL" \
    > "$OUT/natural-life.out"

printf '%s\t%s\t%s\n' 'Light and dark.' 'Carefully.' none \
    > "$OUT/traces/external-pair.tsv"
printf '%s\t%s\t%s\n' 'Carefully.' 'Light and dark.' none \
    > "$OUT/traces/self-pair.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Dark.' none \
    > "$OUT/traces/external-cross-ab.tsv"
printf '%s\t%s\t%s\n' 'Dark.' 'Light.' none \
    > "$OUT/traces/external-cross-ba.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Dark.' light \
    > "$OUT/traces/reflected-cross.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Light.' none \
    > "$OUT/traces/echo-one.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    printf '%s\t%s\t%s\n' 'Dark.' 'Carefully.' none
} > "$OUT/traces/external-temporal.tsv"
{
    printf '%s\t%s\t%s\n' 'Carefully.' 'Light.' none
    printf '%s\t%s\t%s\n' 'Carefully.' 'Dark.' none
} > "$OUT/traces/self-temporal.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Tree.' none \
    > "$OUT/traces/cross-owner.tsv"
printf '%s\t%s\t%s\n' 'Nareth and light.' 'Dark.' none \
    > "$OUT/traces/literal-human.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Nareth and dark.' none \
    > "$OUT/traces/literal-leo.tsv"
for seed in 83 137 211; do
    cut -f3 "$NATURAL/seed-$seed/policy.tsv" | tail -n +2 \
        > "$OUT/traces/natural-$seed.selected"
    paste "$NATURAL/seed-$seed/prompts.txt" \
        "$NATURAL/seed-$seed/replies.txt" \
        "$OUT/traces/natural-$seed.selected" \
        > "$OUT/traces/natural-$seed.tsv"
done

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_EXCHANGE_PLAN_ONLY=1 "$0" > "$PLAN"
for trace in "$OUT/traces"/*.tsv; do
    printf '%s\t%s\n' "$(basename "$trace")" \
        "$(shasum -a 256 "$trace" | awk '{ print $1 }')" \
        >> "$PLAN"
done
shasum -a 256 "$PLAN" > "$OUT/sealed-plan.sha256"

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_exchange_fixture.c" -lm \
    -o "$OUT/exchange-fixture"

EVIDENCE="$OUT/evidence.tsv"
: > "$EVIDENCE"
for trace in "$OUT/traces"/*.tsv; do
    name="$(basename "$trace" .tsv)"
    "$OUT/exchange-fixture" "$NATURAL/body/state" "$name" \
        < "$trace" > "$OUT/$name.tsv"
    if [ ! -s "$EVIDENCE" ]; then
        cat "$OUT/$name.tsv" > "$EVIDENCE"
    else
        tail -n +2 "$OUT/$name.tsv" >> "$EVIDENCE"
    fi
done

SUMMARY="$OUT/summary.tsv"
printf 'trace\tturns\tconfounded\texternal_w1\texternal_cross_w1\treflected_w1\treflected_cross_w1\tself_w1\texternal_w2\texternal_cross_w2\treflected_w2\treflected_cross_w2\tself_w2\texternal_w4\texternal_cross_w4\treflected_w4\treflected_cross_w4\tself_w4\texternal_w8\texternal_cross_w8\treflected_w8\treflected_cross_w8\tself_w8\n' \
    > "$SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        turns[$1] = $2
        confounded[$1] += $4
        for (column = 11; column <= 30; column++)
            count[$1, column] += $column
    }
    END {
        for (trace in turns) {
            printf "%s\t%d\t%d", trace, turns[trace],
                   confounded[trace] + 0
            for (column = 11; column <= 30; column++)
                printf "\t%d", count[trace, column] + 0
            print ""
        }
    }
' "$EVIDENCE" | sort >> "$SUMMARY"

OBSERVED="$OUT/observed.tsv"
printf 'window\texternal_pairs\texternal_cross\treflected_pairs\treflected_cross\tself_pairs\texternal_cross_required\treflected_cross_required\tverdict\n' \
    > "$OBSERVED"
for window in 1 2 4 8; do
    case "$window" in
        1) e=11; x=12; r=13; q=14; s=15 ;;
        2) e=16; x=17; r=18; q=19; s=20 ;;
        4) e=21; x=22; r=23; q=24; s=25 ;;
        8) e=26; x=27; r=28; q=29; s=30 ;;
    esac
    awk -F '\t' -v window="$window" -v e="$e" -v x="$x" \
        -v r="$r" -v q="$q" -v s="$s" '
        NR > 1 && $1 ~ /^natural-/ {
            external += $e
            external_cross += $x
            reflected += $r
            reflected_cross += $q
            self += $s
            if ($x && !$e && !$s) external_required++
            if ($q && !$r && !$s) reflected_required++
        }
        END {
            printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\tclosed-loop\n",
                   window, external + 0, external_cross + 0,
                   reflected + 0, reflected_cross + 0, self + 0,
                   external_required + 0, reflected_required + 0
        }
    ' "$EVIDENCE" >> "$OBSERVED"
done

awk -F '\t' '
    NR == 1 { next }
    $1 == "external-pair" {
        ok += ($4 == 1 && $5 == 0 && $8 == 0)
    }
    $1 == "self-pair" {
        ok += ($4 == 0 && $5 == 0 && $8 == 1)
    }
    $1 == "external-cross-ab" || $1 == "external-cross-ba" {
        ok += ($4 == 0 && $5 == 1 && $7 == 0 && $8 == 0)
    }
    $1 == "reflected-cross" {
        ok += ($5 == 0 && $7 == 1 && $8 == 0)
    }
    $1 == "echo-one" || $1 == "cross-owner" {
        sum = 0
        for (i = 4; i <= 23; i++) sum += $i
        ok += (sum == 0)
    }
    $1 == "external-temporal" {
        ok += ($4 == 0 && $9 == 1 && $13 == 0)
    }
    $1 == "self-temporal" {
        ok += ($8 == 0 && $13 == 1)
    }
    $1 == "literal-human" || $1 == "literal-leo" {
        sum = 0
        for (i = 4; i <= 23; i++) sum += $i
        ok += ($3 == 1 && sum == 0)
    }
    END { exit ok == 11 ? 0 : 1 }
' "$SUMMARY" || {
    printf 'exchange attribution control contract failed\n' >&2
    exit 1
}

expected=$'1\t0\t0\t0\t1\t16\t0\t1\tclosed-loop\n2\t0\t0\t0\t2\t33\t0\t1\tclosed-loop\n4\t0\t0\t0\t4\t67\t0\t0\tclosed-loop\n8\t0\t0\t0\t8\t127\t0\t0\tclosed-loop'
got="$(tail -n +2 "$OBSERVED")"
[ "$got" = "$expected" ] || {
    printf 'unexpected natural exchange attribution:\n%s\n' "$got" >&2
    exit 1
}

cat "$SUMMARY"
printf '\n'
cat "$OBSERVED"
printf '\nsealed plan: %s\nevidence: %s\n' "$PLAN" "$EVIDENCE"
