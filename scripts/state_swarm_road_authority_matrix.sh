#!/usr/bin/env bash
# A.97: ask whether a transition row earns authority before its outcome exists.
set -Eeuo pipefail

trap 'rc=$?; printf "road authority runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
A96="${LEO_STATE_AUTHORITY_A96_SOURCE:-/private/tmp/leo-state-swarm-road-readout-a96-r1-20260810}"
DISCOVERY_EXPECTED="${LEO_STATE_AUTHORITY_DISCOVERY_EXPECTED:-12}"
VALIDATION_EXPECTED="${LEO_STATE_AUTHORITY_VALIDATION_EXPECTED:-15}"
AGGREGATE_ONLY="${LEO_STATE_AUTHORITY_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-authority-$STAMP}"

A96_DISCOVERY="$A96/discovery-witnesses.tsv"
A96_VALIDATION="$A96/validation-witnesses.tsv"
EXPECTED_DISCOVERY_SHA="${LEO_STATE_AUTHORITY_DISCOVERY_SHA:-1d5c6fd6ea1ed42a0a0d17263551427860226f25bb9297a60e0e2b9d9eaf04ad}"
EXPECTED_VALIDATION_SHA="${LEO_STATE_AUTHORITY_VALIDATION_SHA:-6d155803cca27adb117b908575bfeac206c3096fdf05bba3c974fee306692303}"

case "$DISCOVERY_EXPECTED:$VALIDATION_EXPECTED" in
    *[!0-9:]*|0:*|*:0) printf 'invalid road authority dimensions\n' >&2; exit 2 ;;
esac

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

seal() {
    local path="$1" expected="$2" label="$3"
    [ -s "$path" ] && [ "$(sha256_file "$path")" = "$expected" ] || {
        printf '%s is not the sealed source: %s\n' "$label" "$path" >&2
        exit 2
    }
}

seal "$A96_DISCOVERY" "$EXPECTED_DISCOVERY_SHA" "A.96 discovery witnesses"
seal "$A96_VALIDATION" "$EXPECTED_VALIDATION_SHA" "A.96 validation witnesses"

FEATURES="$OUT/features.tsv"
DISCOVERY="$OUT/discovery-witnesses.tsv"
VALIDATION="$OUT/validation-witnesses.tsv"
SCORES="$OUT/authority-scores.tsv"
SELECTION="$OUT/selection.tsv"
VERDICT="$OUT/verdict.txt"

write_features() {
    printf 'feature\tkind\trank\n'
    printf 'row-coverage\tcoverage\t1\n'
    printf 'active-row-kl\tactive-kl\t2\n'
    printf 'forecast-kl\tforecast-kl\t3\n'
    printf 'survival\tsurvival\t4\n'
    printf 'coverage-forecast-kl\tproduct\t5\n'
    printf 'forecast-tv\ttv\t6\n'
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$FEATURES" "$DISCOVERY" "$VALIDATION"; do
        [ -s "$path" ] || {
            printf 'incomplete road authority run: %s\n' "$OUT" >&2
            exit 2
        }
    done
    write_features | cmp -s - "$FEATURES" || {
        printf 'A.97 feature ledger diverged\n' >&2
        exit 2
    }
    seal "$DISCOVERY" "$EXPECTED_DISCOVERY_SHA" "copied discovery witnesses"
    seal "$VALIDATION" "$EXPECTED_VALIDATION_SHA" "copied validation witnesses"
else
    [ ! -e "$OUT" ] || {
        printf 'output path already exists: %s\n' "$OUT" >&2
        exit 2
    }
    mkdir -p "$OUT"
    write_features > "$FEATURES"
    cp "$A96_DISCOVERY" "$DISCOVERY"
    cp "$A96_VALIDATION" "$VALIDATION"
fi

if [ "${LEO_STATE_AUTHORITY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$FEATURES"
    exit 0
fi

awk -v discovery_expected="$DISCOVERY_EXPECTED" \
    -v validation_expected="$VALIDATION_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_authority_report.awk" \
    "$FEATURES" "$DISCOVERY" "$VALIDATION" > "$SCORES"
awk -v expected="$DISCOVERY_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_authority_select.awk" \
    "$SCORES" > "$SELECTION"
awk -v expected="$VALIDATION_EXPECTED" \
    -f "$ROOT/scripts/state_swarm_road_authority_verdict.awk" \
    "$SELECTION" "$SCORES" > "$VERDICT"

cat "$SELECTION"
printf '\n'
cat "$VERDICT"
printf '\nsource-a96: %s\nrun: %s\n' "$A96" "$OUT"
