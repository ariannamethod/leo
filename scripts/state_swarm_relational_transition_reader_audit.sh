#!/usr/bin/env bash
# A.117: sealed aggregate reread of A.113 under the A.95 reader question.
set -Eeuo pipefail

trap 'rc=$?; printf "relational reader audit failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${LEO_STATE_RELATIONAL_READER_SOURCE:-/private/tmp/leo-state-swarm-relational-transition-a113-r1-20260818}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${LEO_STATE_RELATIONAL_READER_OUT:-${TMPDIR:-/tmp}/leo-state-swarm-relational-transition-reader-$STAMP}"
AGGREGATE_ONLY="${LEO_STATE_RELATIONAL_READER_AGGREGATE_ONLY:-0}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            [ "$#" -ge 2 ] || { printf 'missing value for --source\n' >&2; exit 2; }
            SOURCE="$2"
            shift 2
            ;;
        --out)
            [ "$#" -ge 2 ] || { printf 'missing value for --out\n' >&2; exit 2; }
            OUT="$2"
            shift 2
            ;;
        --aggregate-only)
            AGGREGATE_ONLY=1
            shift
            ;;
        *)
            printf 'usage: %s [--source DIR] [--out DIR] [--aggregate-only]\n' "$0" >&2
            exit 2
            ;;
    esac
done

SOURCE_DESIGN="$SOURCE/design.tsv"
SOURCE_RECEIPT="$SOURCE/source-receipt.tsv"
SOURCE_PLAN="$SOURCE/validation-plan.tsv"
SOURCE_RAW="$SOURCE/validation-raw.tsv"
SOURCE_SCORES="$SOURCE/validation-scores.tsv"
SOURCE_LIFE="$SOURCE/validation-life-summary.tsv"
SOURCE_VERDICT="$SOURCE/verdict.txt"

EXPECTED_SOURCE_DESIGN_SHA=74c3a9350d65dec5e89fe710c314e3a39e164ea8fe24f7819664666bc8cd5d21
EXPECTED_SOURCE_RECEIPT_SHA=c35df9a6dbfbc1a8b5b4f1e7a53817a35573cc01d453a818a444b0f7987ddaa2
EXPECTED_SOURCE_PLAN_SHA=02b87539322ddafbcf2f7c9959019dcbacf53595120223f1c72ed8edd59b6d92
EXPECTED_SOURCE_RAW_SHA=4c27e634fe56d8f3fecc1d550b5d3ec6e75cc4e3a9e8af17ffb7f4638714e932
EXPECTED_SOURCE_SCORES_SHA=c400656836de8a8a4ab573516769135c2cdf9593af5a641f553cd54b152de8ad
EXPECTED_SOURCE_LIFE_SHA=89fc974c41a7baa883fa952ca95d104292899e4ddbb64977e5d18a193e09094a
EXPECTED_SOURCE_VERDICT_SHA=bf77884723d4abd760e84fa8819749ea9692de8259877dc4aa8ffa977c0432d5

REPORTER="$ROOT/scripts/state_swarm_relational_transition_reader_report.awk"
LIFE_REPORTER="$ROOT/scripts/state_swarm_relational_transition_reader_life.awk"
VERDICT_REPORTER="$ROOT/scripts/state_swarm_relational_transition_reader_verdict.awk"
DESIGN="$OUT/design.tsv"
LOCK="$OUT/source-lock.tsv"
SCORES="$OUT/reader-scores.tsv"
LIFE="$OUT/reader-life-summary.tsv"
VERDICT="$OUT/verdict.txt"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
seal() {
    local path="$1" expected="$2" label="$3" actual
    [ -s "$path" ] || { printf 'missing %s: %s\n' "$label" "$path" >&2; exit 2; }
    actual="$(sha256_file "$path")"
    [ "$actual" = "$expected" ] || {
        printf '%s SHA mismatch: expected=%s actual=%s\n' "$label" "$expected" "$actual" >&2
        exit 2
    }
}

seal "$SOURCE_DESIGN" "$EXPECTED_SOURCE_DESIGN_SHA" "A.113 design"
seal "$SOURCE_RECEIPT" "$EXPECTED_SOURCE_RECEIPT_SHA" "A.113 source receipt"
seal "$SOURCE_PLAN" "$EXPECTED_SOURCE_PLAN_SHA" "A.113 validation plan"
seal "$SOURCE_RAW" "$EXPECTED_SOURCE_RAW_SHA" "A.113 raw receipt"
seal "$SOURCE_SCORES" "$EXPECTED_SOURCE_SCORES_SHA" "A.113 scores"
seal "$SOURCE_LIFE" "$EXPECTED_SOURCE_LIFE_SHA" "A.113 life summary"
seal "$SOURCE_VERDICT" "$EXPECTED_SOURCE_VERDICT_SHA" "A.113 verdict"
grep -q '^result[[:space:]]relational-transition-redistribution-confirmed$' \
    "$SOURCE_VERDICT"

write_design() {
    printf 'field\tvalue\n'
    printf 'phase\tA.117\n'
    printf 'question\tmay-the-admitted-relational-road-reenter-reader-work\n'
    printf 'source\tA.113 sealed raw receipt only\n'
    printf 'new_process_turns\t0\n'
    printf 'new_efficacy_votes\t0\n'
    printf 'reader_score\tsoft-target cross-entropy and Brier\n'
    printf 'reader_baseline\teach road own destination prior\n'
    printf 'population_unit\tone equal vote per sealed overflow life\n'
    printf 'candidate\tA.113 relational half-gain road\n'
    printf 'historical_control\tA.79 raw co-activation road\n'
    printf 'required_reader_life_wins\t8 of 11\n'
    printf 'required_primary_reader_wins\t4 of 5\n'
    printf 'required_holdout_reader_wins\t4 of 6\n'
    printf 'required_population_sign\tpositive both proper scores\n'
    printf 'required_split_sign\tpositive both proper scores\n'
    printf 'required_texture_sign\tpositive all four in CE\n'
    printf 'required_position_sign\tpositive all eight in CE\n'
    printf 'required_old-road_relation\tcandidate remains positive over A.79\n'
    printf 'authority\tnomination only; no speech reader admission\n'
}

write_lock() {
    printf 'artifact\tsha256\n'
    printf 'A.113-design\t%s\n' "$EXPECTED_SOURCE_DESIGN_SHA"
    printf 'A.113-source-receipt\t%s\n' "$EXPECTED_SOURCE_RECEIPT_SHA"
    printf 'A.113-validation-plan\t%s\n' "$EXPECTED_SOURCE_PLAN_SHA"
    printf 'A.113-validation-raw\t%s\n' "$EXPECTED_SOURCE_RAW_SHA"
    printf 'A.113-validation-scores\t%s\n' "$EXPECTED_SOURCE_SCORES_SHA"
    printf 'A.113-validation-life-summary\t%s\n' "$EXPECTED_SOURCE_LIFE_SHA"
    printf 'A.113-verdict\t%s\n' "$EXPECTED_SOURCE_VERDICT_SHA"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DESIGN" "$LOCK" "$SCORES" "$LIFE" "$VERDICT"; do
        [ -s "$path" ] || { printf 'incomplete A.117 aggregate source: %s\n' "$path" >&2; exit 2; }
    done
    write_design | cmp -s - "$DESIGN" || { printf 'A.117 design drift\n' >&2; exit 2; }
    write_lock | cmp -s - "$LOCK" || { printf 'A.117 source lock drift\n' >&2; exit 2; }
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT"
    write_design > "$DESIGN"
    write_lock > "$LOCK"
fi

awk -f "$REPORTER" "$SOURCE_RAW" > "$SCORES"
cut -f1-24 "$SCORES" | cmp -s - "$SOURCE_SCORES" || {
    printf 'A.117 failed to reconstruct A.113 score columns exactly\n' >&2
    exit 2
}
awk -f "$LIFE_REPORTER" "$SCORES" > "$LIFE"
awk -f "$VERDICT_REPORTER" "$SCORES" "$LIFE" > "$VERDICT"
cat "$VERDICT"
printf 'A.117 sealed reader audit: %s\n' "$OUT"
