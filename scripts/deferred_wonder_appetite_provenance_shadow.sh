#!/usr/bin/env bash
# A.66: preserve source and order in a read-only appetite shadow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-appetite-provenance-shadow-$STAMP}"

if [ "${LEO_APPETITE_PROVENANCE_PLAN_ONLY:-0}" = 1 ]; then
    printf 'trace\tturns\tcontract\n'
    printf 'same-turn-ab\t1\texternal-opens-self-completes\n'
    printf 'same-turn-ba\t1\texternal-opens-self-completes-reversed\n'
    printf 'temporal-ab\t2\texternal-precedes-self\n'
    printf 'retroactive\t2\tpast-self-cannot-complete\n'
    printf 'reflected-origin\t1\treflection-cannot-open\n'
    printf 'reflected-completion\t2\treflection-blocks-self-completion\n'
    printf 'reflected-passage\t3\treflection-does-not-rewrite-invitation\n'
    printf 'external-current\t1\texternal-pair-is-sufficient\n'
    printf 'external-temporal\t2\texternal-complement-closes-invitation\n'
    printf 'external-reorientation\t2\texternal-closure-precedes-self\n'
    printf 'self-sufficient\t1\tself-pair-cannot-certify\n'
    printf 'same-side\t1\tsame-side-cannot-complete\n'
    printf 'expired\t9\tlate-self-cannot-complete\n'
    printf 'cross-owner\t1\twonder-ownership-is-closed\n'
    printf 'literal-human\t1\thuman-address-is-confounded\n'
    printf 'literal-self\t1\tself-address-is-confounded\n'
    printf 'blind\t2x32\tA.65-sealed-external-life\n'
    printf 'side-a\t2x32\tA.65-sealed-side-a-life\n'
    printf 'side-b\t2x32\tA.65-sealed-side-b-life\n'
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT/controls"

EXTERNAL="$OUT/external-life"
"$ROOT/scripts/deferred_wonder_appetite_external_life.sh" "$EXTERNAL" \
    > "$OUT/external-life.out"
STATE="$EXTERNAL/body-source/body/state"

printf '%s\t%s\t%s\n' 'Light.' 'Dark.' none \
    > "$OUT/controls/same-turn-ab.tsv"
printf '%s\t%s\t%s\n' 'Dark.' 'Light.' none \
    > "$OUT/controls/same-turn-ba.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    printf '%s\t%s\t%s\n' 'Carefully.' 'Dark.' none
} > "$OUT/controls/temporal-ab.tsv"
{
    printf '%s\t%s\t%s\n' 'Carefully.' 'Dark.' none
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
} > "$OUT/controls/retroactive.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Dark.' light \
    > "$OUT/controls/reflected-origin.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    printf '%s\t%s\t%s\n' 'Dark.' 'Dark.' dark
} > "$OUT/controls/reflected-completion.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    printf '%s\t%s\t%s\n' 'Dark.' 'Carefully.' dark
    printf '%s\t%s\t%s\n' 'Carefully.' 'Dark.' none
} > "$OUT/controls/reflected-passage.tsv"
printf '%s\t%s\t%s\n' 'Light and dark.' 'Carefully.' none \
    > "$OUT/controls/external-current.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    printf '%s\t%s\t%s\n' 'Dark.' 'Carefully.' none
} > "$OUT/controls/external-temporal.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    printf '%s\t%s\t%s\n' 'Dark.' 'Light.' none
} > "$OUT/controls/external-reorientation.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Light and dark.' none \
    > "$OUT/controls/self-sufficient.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Light.' none \
    > "$OUT/controls/same-side.tsv"
{
    printf '%s\t%s\t%s\n' 'Light.' 'Carefully.' none
    for _ in 2 3 4 5 6 7 8; do
        printf '%s\t%s\t%s\n' 'Carefully.' 'Carefully.' none
    done
    printf '%s\t%s\t%s\n' 'Carefully.' 'Dark.' none
} > "$OUT/controls/expired.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Tree.' none \
    > "$OUT/controls/cross-owner.tsv"
printf '%s\t%s\t%s\n' 'Nareth and light.' 'Dark.' none \
    > "$OUT/controls/literal-human.tsv"
printf '%s\t%s\t%s\n' 'Light.' 'Nareth and dark.' none \
    > "$OUT/controls/literal-self.tsv"

PLAN="$OUT/sealed-plan.tsv"
LEO_APPETITE_PROVENANCE_PLAN_ONLY=1 "$0" > "$PLAN"
(
    cd "$OUT"
    shasum -a 256 controls/*.tsv \
        external-life/prompts-*.txt \
        > sealed-inputs.sha256
    shasum -a 256 sealed-plan.tsv > sealed-plan.sha256
    shasum -a 256 external-life/body-source/body/state \
        > observer-state.sha256
)

"${CC:-cc}" -O2 -Wall -Wextra -Wno-unused-function \
    "$ROOT/tests/wonder_appetite_provenance_shadow_fixture.c" -lm \
    -o "$OUT/provenance-shadow-fixture"

EVIDENCE="$OUT/evidence.tsv"
: > "$EVIDENCE"
for trace in "$OUT/controls"/*.tsv; do
    name="$(basename "$trace" .tsv)"
    receipt="$OUT/control-$name.tsv"
    "$OUT/provenance-shadow-fixture" "$STATE" "$name" \
        < "$trace" > "$receipt"
    if [ ! -s "$EVIDENCE" ]; then
        cat "$receipt" > "$EVIDENCE"
    else
        tail -n +2 "$receipt" >> "$EVIDENCE"
    fi
done
for arm in blind side-a side-b; do
    for seed in 307 401; do
        name="$arm-$seed"
        receipt="$OUT/$name.tsv"
        "$OUT/provenance-shadow-fixture" "$STATE" "$name" \
            < "$EXTERNAL/$name/exchanges.tsv" > "$receipt"
        tail -n +2 "$receipt" >> "$EVIDENCE"
    done
done

CONTROL_SUMMARY="$OUT/control-summary.tsv"
printf 'trace\twindow\topened\tcompleted\texternal_sufficient\treflected_blocked\tself_blocked\texpired\tpending_final\n' \
    > "$CONTROL_SUMMARY"
awk -F '\t' '
    BEGIN {
        window[1] = 1; base[1] = 11
        window[2] = 2; base[2] = 18
        window[3] = 4; base[3] = 25
        window[4] = 8; base[4] = 32
    }
    NR > 1 && $1 !~ /^(blind|side-a|side-b)-/ && $3 == "nareth" {
        trace = $1
        for (w = 1; w <= 4; w++) {
            b = base[w]; key = trace SUBSEP w
            opened[key] += $(b)
            completed[key] += $(b + 1)
            sufficient[key] += $(b + 2)
            reflected[key] += $(b + 3)
            self_blocked[key] += $(b + 4)
            expired[key] += $(b + 5)
            pending[key] = $(b + 6)
            seen[key] = 1
        }
    }
    END {
        for (key in seen) {
            split(key, part, SUBSEP)
            w = part[2]
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   part[1], window[w], opened[key] + 0,
                   completed[key] + 0, sufficient[key] + 0,
                   reflected[key] + 0, self_blocked[key] + 0,
                   expired[key] + 0, pending[key] + 0
        }
    }
' "$EVIDENCE" | sort -k1,1 -k2,2n >> "$CONTROL_SUMMARY"

awk -F '\t' '
    function is_row(o, c, s, r, b, x, p) {
        return $3 == o && $4 == c && $5 == s && $6 == r &&
               $7 == b && $8 == x && $9 == p
    }
    NR == 1 { next }
    {
        seen++
        ok = 0
        if ($1 == "same-turn-ab" || $1 == "same-turn-ba")
            ok = is_row(1, 1, 0, 0, 0, 0, 0)
        else if ($1 == "temporal-ab") {
            if ($2 == 1)
                ok = is_row(1, 0, 0, 0, 0, 1, 0)
            else
                ok = is_row(1, 1, 0, 0, 0, 0, 0)
        }
        else if ($1 == "retroactive" || $1 == "same-side" ||
                 $1 == "cross-owner")
            ok = is_row(1, 0, 0, 0, 0, 0, 1)
        else if ($1 == "reflected-origin" ||
                 $1 == "literal-human" || $1 == "literal-self")
            ok = is_row(0, 0, 0, 0, 0, 0, 0)
        else if ($1 == "reflected-completion") {
            if ($2 == 1)
                ok = is_row(1, 0, 0, 0, 0, 1, 0)
            else
                ok = is_row(1, 0, 0, 1, 0, 0, 1)
        }
        else if ($1 == "reflected-passage") {
            if ($2 <= 2)
                ok = is_row(1, 0, 0, 0, 0, 1, 0)
            else
                ok = is_row(1, 1, 0, 0, 0, 0, 0)
        }
        else if ($1 == "external-current")
            ok = is_row(0, 0, 1, 0, 0, 0, 0)
        else if ($1 == "external-temporal") {
            if ($2 == 1)
                ok = is_row(2, 0, 0, 0, 0, 1, 1)
            else
                ok = is_row(1, 0, 1, 0, 0, 0, 0)
        }
        else if ($1 == "external-reorientation") {
            if ($2 == 1)
                ok = is_row(2, 1, 0, 0, 0, 1, 0)
            else
                ok = is_row(1, 0, 1, 0, 0, 0, 0)
        }
        else if ($1 == "self-sufficient")
            ok = is_row(1, 0, 0, 0, 1, 0, 0)
        else if ($1 == "expired")
            ok = is_row(1, 0, 0, 0, 0, 1, 0)
        good += ok
        if (!ok)
            printf "invalid provenance control: %s window %s\n",
                   $1, $2 > "/dev/stderr"
    }
    END { exit seen == 64 && good == 64 ? 0 : 1 }
' "$CONTROL_SUMMARY" || exit 1

OBSERVED="$OUT/observed.tsv"
printf 'arm\twindow\tlives\tturns\topened\tcompleted\texternal_sufficient\treflected_blocked\tself_blocked\texpired\tpending_final\n' \
    > "$OBSERVED"
awk -F '\t' '
    BEGIN {
        window[1] = 1; base[1] = 11
        window[2] = 2; base[2] = 18
        window[3] = 4; base[3] = 25
        window[4] = 8; base[4] = 32
    }
    NR > 1 && $1 ~ /^(blind|side-a|side-b)-/ {
        trace = $1
        arm = trace
        sub(/-[0-9]+$/, "", arm)
        turn[arm, trace, $2] = 1
        life[arm, trace] = 1
        for (w = 1; w <= 4; w++) {
            b = base[w]; key = arm SUBSEP w
            opened[key] += $(b)
            completed[key] += $(b + 1)
            sufficient[key] += $(b + 2)
            reflected[key] += $(b + 3)
            self_blocked[key] += $(b + 4)
            expired[key] += $(b + 5)
            if ($2 == 32) pending[key] += $(b + 6)
            seen[key] = 1
        }
    }
    END {
        for (item in life) {
            split(item, part, SUBSEP)
            lives[part[1]]++
        }
        for (item in turn) {
            split(item, part, SUBSEP)
            turns[part[1]]++
        }
        for (key in seen) {
            split(key, part, SUBSEP)
            arm = part[1]; w = part[2]
            printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                   arm, window[w], lives[arm], turns[arm],
                   opened[key] + 0, completed[key] + 0,
                   sufficient[key] + 0, reflected[key] + 0,
                   self_blocked[key] + 0, expired[key] + 0,
                   pending[key] + 0
        }
    }
' "$EVIDENCE" | sort -k1,1 -k2,2n >> "$OBSERVED"

expected=$'blind\t1\t2\t64\t22\t1\t0\t0\t2\t19\t0\nblind\t2\t2\t64\t22\t1\t0\t0\t2\t19\t0\nblind\t4\t2\t64\t20\t2\t2\t0\t1\t13\t0\nblind\t8\t2\t64\t20\t2\t2\t0\t1\t9\t2\nside-a\t1\t2\t64\t64\t0\t0\t0\t1\t61\t2\nside-a\t2\t2\t64\t64\t1\t0\t0\t1\t58\t4\nside-a\t4\t2\t64\t64\t2\t0\t0\t2\t52\t8\nside-a\t8\t2\t64\t64\t2\t0\t0\t2\t0\t8\nside-b\t1\t2\t64\t80\t15\t0\t0\t4\t59\t2\nside-b\t2\t2\t64\t80\t19\t0\t0\t4\t53\t4\nside-b\t4\t2\t64\t80\t22\t0\t0\t4\t48\t6\nside-b\t8\t2\t64\t80\t22\t0\t0\t4\t0\t6'
got="$(tail -n +2 "$OBSERVED")"
[ "$got" = "$expected" ] || {
    printf 'unexpected provenance shadow observation:\n%s\n' "$got" >&2
    exit 1
}

EVENTS="$OUT/completion-events.tsv"
printf 'trace\tturn\tword\tcompleted_w1\tcompleted_w2\tcompleted_w4\tcompleted_w8\n' \
    > "$EVENTS"
awk -F '\t' '
    NR > 1 && $1 ~ /^(blind|side-a|side-b)-/ &&
    ($12 || $19 || $26 || $33) {
        printf "%s\t%d\t%s\t%d\t%d\t%d\t%d\n",
               $1, $2, $3, $12, $19, $26, $33
    }
' "$EVIDENCE" >> "$EVENTS"
expected_blind=$'blind-307\t24\tnareth\t0\t0\t1\t1\nblind-401\t13\tnareth\t1\t1\t1\t1'
got_blind="$(awk -F '\t' 'NR > 1 && $1 ~ /^blind-/' "$EVENTS")"
[ "$got_blind" = "$expected_blind" ] || {
    printf 'unexpected blind provenance witnesses:\n%s\n' "$got_blind" >&2
    exit 1
}
(
    cd "$OUT"
    shasum -a 256 -c observer-state.sha256 > /dev/null
)

cat "$CONTROL_SUMMARY"
printf '\n'
cat "$OBSERVED"
printf '\n'
cat "$EVENTS"
printf '\nsealed plan: %s\nevidence: %s\n' "$PLAN" "$EVIDENCE"
