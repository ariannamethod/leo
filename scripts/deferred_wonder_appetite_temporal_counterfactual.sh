#!/usr/bin/env bash
# A.63: compare temporal recurrence operators without changing Leo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-temporal-counterfactual-$STAMP}"

if [ "${LEO_APPETITE_TEMPORAL_PLAN_ONLY:-0}" = 1 ]; then
    printf 'trace\tturns\tcontract\n'
    printf 'simultaneous\t1\tboth-sides-same-turn\n'
    printf 'split-adjacent\t2\tcomplementary-sides-adjacent\n'
    printf 'split-reverse\t2\tcomplementary-sides-reversed\n'
    printf 'repeat-one\t2\tsame-side-repeated\n'
    printf 'split-distant\t10\tcomplementary-sides-outside-window\n'
    printf 'cross-owner\t2\tdifferent-owner-sides\n'
    printf 'literal-bridge\t2\thuman-address-cannot-carry-support\n'
    printf 'natural-83\t64\tA.62-visible-prompts\n'
    printf 'natural-137\t64\tA.62-visible-prompts\n'
    printf 'natural-211\t64\tA.62-visible-prompts\n'
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

cat > "$OUT/traces/simultaneous.txt" <<'EOF'
Light and dark.
EOF
cat > "$OUT/traces/split-adjacent.txt" <<'EOF'
Light.
Dark.
EOF
cat > "$OUT/traces/split-reverse.txt" <<'EOF'
Dark.
Light.
EOF
cat > "$OUT/traces/repeat-one.txt" <<'EOF'
Light.
Light.
EOF
cat > "$OUT/traces/split-distant.txt" <<'EOF'
Light.
Carefully.
Carefully.
Carefully.
Carefully.
Carefully.
Carefully.
Carefully.
Carefully.
Dark.
EOF
cat > "$OUT/traces/cross-owner.txt" <<'EOF'
Light.
Tree.
EOF
cat > "$OUT/traces/literal-bridge.txt" <<'EOF'
Light.
Nareth, light and dark.
EOF
for seed in 83 137 211; do
    cp "$NATURAL/seed-$seed/prompts.txt" \
        "$OUT/traces/natural-$seed.txt"
done

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_TEMPORAL_PLAN_ONLY=1 "$0" > "$PLAN"
for trace in "$OUT/traces"/*.txt; do
    printf '%s\t%s\n' "$(basename "$trace")" \
        "$(shasum -a 256 "$trace" | awk '{ print $1 }')" \
        >> "$PLAN"
done
shasum -a 256 "$PLAN" > "$OUT/sealed-plan.sha256"

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_temporal_fixture.c" -lm \
    -o "$OUT/temporal-fixture"

EVIDENCE="$OUT/evidence.tsv"
: > "$EVIDENCE"
for trace in "$OUT/traces"/*.txt; do
    name="$(basename "$trace" .txt)"
    "$OUT/temporal-fixture" "$NATURAL/body/state" "$name" \
        < "$trace" > "$OUT/$name.tsv"
    if [ ! -s "$EVIDENCE" ]; then
        cat "$OUT/$name.tsv" > "$EVIDENCE"
    else
        tail -n +2 "$OUT/$name.tsv" >> "$EVIDENCE"
    fi
done

SUMMARY="$OUT/summary.tsv"
printf 'trace\tturns\tcurrent_full\tpaired_w2\tpaired_w4\tpaired_w8\twinners_w2\twinners_w4\twinners_w8\n' \
    > "$SUMMARY"
awk -F '\t' '
    NR == 1 { next }
    {
        turns[$1] = $2
        if (!$6 && $9 >= 0.75) current[$1]++
        if ($10 >= 0.75) {
            w2[$1]++
            key = $1 SUBSEP $3
            win2[key] = 1
        }
        if ($11 >= 0.75) {
            w4[$1]++
            key = $1 SUBSEP $3
            win4[key] = 1
        }
        if ($12 >= 0.75) {
            w8[$1]++
            key = $1 SUBSEP $3
            win8[key] = 1
        }
    }
    END {
        for (trace in turns) {
            n2 = n4 = n8 = 0
            for (key in win2) {
                split(key, parts, SUBSEP)
                if (parts[1] == trace) n2++
            }
            for (key in win4) {
                split(key, parts, SUBSEP)
                if (parts[1] == trace) n4++
            }
            for (key in win8) {
                split(key, parts, SUBSEP)
                if (parts[1] == trace) n8++
            }
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   trace, turns[trace], current[trace] + 0,
                   w2[trace] + 0, w4[trace] + 0, w8[trace] + 0,
                   n2, n4, n8
        }
    }
' "$EVIDENCE" | sort >> "$SUMMARY"

expected=$'cross-owner\t2\t0\t0\t0\t0\t0\t0\t0\nliteral-bridge\t2\t0\t0\t0\t0\t0\t0\t0\nnatural-137\t64\t0\t0\t0\t0\t0\t0\t0\nnatural-211\t64\t0\t0\t0\t0\t0\t0\t0\nnatural-83\t64\t0\t0\t0\t0\t0\t0\t0\nrepeat-one\t2\t0\t0\t0\t0\t0\t0\t0\nsimultaneous\t1\t1\t1\t1\t1\t1\t1\t1\nsplit-adjacent\t2\t0\t1\t1\t1\t1\t1\t1\nsplit-distant\t10\t0\t0\t0\t0\t0\t0\t0\nsplit-reverse\t2\t0\t1\t1\t1\t1\t1\t1'
got="$(tail -n +2 "$SUMMARY")"
[ "$got" = "$expected" ] || {
    printf 'unexpected temporal counterfactual:\n%s\n' "$got" >&2
    exit 1
}

printf 'operator\tcontrol_true\tcontrol_false\tnatural_hits\tverdict\n' \
    > "$OUT/observed.tsv"
printf 'current-turn\t1/3\t0/4\t0\tcoverage-starved\n' \
    >> "$OUT/observed.tsv"
printf 'paired-w2\t3/3\t0/4\t0\tsafe-but-unexercised\n' \
    >> "$OUT/observed.tsv"
printf 'paired-w4\t3/3\t0/4\t0\tsafe-but-unexercised\n' \
    >> "$OUT/observed.tsv"
printf 'paired-w8\t3/3\t0/4\t0\tsafe-but-unexercised\n' \
    >> "$OUT/observed.tsv"

cat "$SUMMARY"
printf '\n'
cat "$OUT/observed.tsv"
printf '\nsealed plan: %s\nevidence: %s\n' "$PLAN" "$EVIDENCE"
