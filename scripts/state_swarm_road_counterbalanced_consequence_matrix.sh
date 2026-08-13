#!/usr/bin/env bash
# A.106: test whether an episode's ending predicts its later consequence.
set -Eeuo pipefail

trap 'rc=$?; printf "road counterbalanced-consequence runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
RESERVOIR="${LEO_STATE_COUNTERBALANCED_RESERVOIR_SOURCE:-/private/tmp/leo-state-swarm-counterbalanced-episode-reservoir-a106-r2-20260813}"
A101="${LEO_STATE_COUNTERBALANCED_A101_SOURCE:-/private/tmp/leo-state-swarm-road-error-memory-a101-r1-20260810}"
A103="${LEO_STATE_COUNTERBALANCED_A103_SOURCE:-/private/tmp/leo-state-swarm-road-episode-memory-a103-r2-20260813}"
A104="${LEO_STATE_COUNTERBALANCED_A104_SOURCE:-/private/tmp/leo-state-swarm-road-ordered-episode-a104-r1-20260813}"
A105="${LEO_STATE_COUNTERBALANCED_A105_SOURCE:-/private/tmp/leo-state-swarm-road-episode-consequence-a105-r1-20260813}"
JOBS="${LEO_STATE_COUNTERBALANCED_JOBS:-4}"
AGGREGATE_ONLY="${LEO_STATE_COUNTERBALANCED_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-counterbalanced-consequence-$STAMP}"

CANDIDATES="$ROOT/scripts/state_swarm_counterbalanced_episode_reservoir_candidates.tsv"
WARM_CASES="$ROOT/scripts/state_swarm_settled_warmup_cases.tsv"
WRITER_CASES="$ROOT/scripts/state_swarm_alphabet_cases.tsv"
REPORTER="$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk"
PLANNER="$ROOT/scripts/state_swarm_williams8_writer_plan.awk"
PROSPECTIVE="$ROOT/scripts/state_swarm_prospective_incidence_matrix.sh"
RESERVOIR_WRAPPER="$ROOT/scripts/state_swarm_counterbalanced_episode_reservoir_matrix.sh"
CONSEQUENCE_REPORTER="$ROOT/scripts/state_swarm_road_episode_consequence_report.awk"
CONSEQUENCE_LIFE="$ROOT/scripts/state_swarm_road_episode_consequence_life.awk"
CONSEQUENCE_SUMMARY="$ROOT/scripts/state_swarm_road_episode_consequence_summary.awk"
CONSEQUENCE_SELECTOR="$ROOT/scripts/state_swarm_road_episode_consequence_select.awk"
CONSEQUENCE_VERDICT="$ROOT/scripts/state_swarm_road_counterbalanced_consequence_verdict.awk"
LEO_SOURCE="$ROOT/leo.c"
LEO_CORPUS="$ROOT/leo.txt"
AML_SOURCE="$ROOT/ariannamethod/ariannamethod.c"
AML_HEADER="$ROOT/ariannamethod/ariannamethod.h"
DIALOGUE_REPORTER="$ROOT/scripts/state_swarm_dialogue_report.awk"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_road_prequential_fixture.c"
EXPECTED_CANDIDATES_SHA="${LEO_STATE_COUNTERBALANCED_CANDIDATES_SHA:-550566b661466910f96dc2a82f691038b53fc6af77f4cb35a64281d4aad258be}"
EXPECTED_WARM_CASES_SHA="${LEO_STATE_COUNTERBALANCED_WARM_CASES_SHA:-1f6e57f2ab55660b8a4cf2cc3e0a2769fa96ffd00ad0d8623e699b318acb4c0b}"
EXPECTED_WRITER_CASES_SHA="${LEO_STATE_COUNTERBALANCED_WRITER_CASES_SHA:-cfa13bb521d91a6a9f3db7fc278927f9120cd699fe72ce1a149307c170ea45e2}"
EXPECTED_REPORTER_SHA="${LEO_STATE_COUNTERBALANCED_REPORTER_SHA:-4667e61986b9fd43c62098786ddc28c9d79ecf5dfd1f74ecd1128b587005af80}"
EXPECTED_PLANNER_SHA="${LEO_STATE_COUNTERBALANCED_PLANNER_SHA:-2ccdaaeb73abad66c5f359dc927cb12a813a66f9489bf9017ba32728fd16b2a5}"
EXPECTED_PROSPECTIVE_SHA="${LEO_STATE_COUNTERBALANCED_PROSPECTIVE_SHA:-648c4202fc2c86d495b9e97568d9b982940beac7058f196f2c96fb9b40a9a181}"
EXPECTED_RESERVOIR_WRAPPER_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_WRAPPER_SHA:-7af80431f93ef7a59a2d9c54e9ea6f3577c8d30c4a052c9f735b300efa02fee7}"
EXPECTED_CONSEQUENCE_REPORTER_SHA="${LEO_STATE_COUNTERBALANCED_CONSEQUENCE_REPORTER_SHA:-4ce44c182fe0360797e61b636655c879877a6893240c84fd16b1a6e70336bc44}"
EXPECTED_CONSEQUENCE_LIFE_SHA="${LEO_STATE_COUNTERBALANCED_CONSEQUENCE_LIFE_SHA:-667d63b9a7a27e41a84b43370189dbb2d2bbba2c64b74b7b5bb60caebd03181d}"
EXPECTED_CONSEQUENCE_SUMMARY_SHA="${LEO_STATE_COUNTERBALANCED_CONSEQUENCE_SUMMARY_SHA:-100858067d03f8415c3325b1de06b31ebbfd1ed92b71ec241ac2c27a4e07fec5}"
EXPECTED_CONSEQUENCE_SELECTOR_SHA="${LEO_STATE_COUNTERBALANCED_CONSEQUENCE_SELECTOR_SHA:-5dc6bf618c5b438e44145cd1dcbeea465585c49ab302cab2ec84334815335b57}"
EXPECTED_CONSEQUENCE_VERDICT_SHA="${LEO_STATE_COUNTERBALANCED_CONSEQUENCE_VERDICT_SHA:-296b6aa4fdfc347bae0e689fa25827872a9a72b41a7c8dd01ea17be766e4ea61}"
EXPECTED_LEO_SOURCE_SHA="${LEO_STATE_COUNTERBALANCED_LEO_SOURCE_SHA:-755f5f0a1e803f36b29ead5517086137af3696baf1959ad34bbca940316b8e73}"
EXPECTED_LEO_CORPUS_SHA="${LEO_STATE_COUNTERBALANCED_LEO_CORPUS_SHA:-98b3052353fc30e8bd08d3c2368ca1aaea41f9fb45b5f7cc2c6a17b78a9b4c19}"
EXPECTED_AML_SOURCE_SHA="${LEO_STATE_COUNTERBALANCED_AML_SOURCE_SHA:-a5cdb03356c9a51cbc8cc664333381cb975bd8c38622f30d293bb93e62ecb54d}"
EXPECTED_AML_HEADER_SHA="${LEO_STATE_COUNTERBALANCED_AML_HEADER_SHA:-b333a334658bbd1516cd9be79ca78c9e0cfd8acbfb90372a3c24af32cc0cca4a}"
EXPECTED_DIALOGUE_REPORTER_SHA="${LEO_STATE_COUNTERBALANCED_DIALOGUE_REPORTER_SHA:-35e393658785740430eec603459dac5ec3bfc1dc8bbac37f531de16582fe4c5e}"
EXPECTED_FIXTURE_SOURCE_SHA="${LEO_STATE_COUNTERBALANCED_FIXTURE_SOURCE_SHA:-6876954c90540ed92aa91a8beb47b433cee231207796b7d84c42c9f2dd9afa47}"
EXPECTED_RESERVOIR_SCREEN_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_SCREEN_PLAN_SHA:-f9c90b125ff3c4b24b55eb81247c6d2ededbdc788578b9af5af60d0ed86de84a}"
EXPECTED_RESERVOIR_WARM_RECEIPTS_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_WARM_RECEIPTS_SHA:-8efb10f804bb226dcda7225beb5cffe7652cd0feaa95be75471d0f85f5c272e1}"
EXPECTED_RESERVOIR_ENROLLMENT_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_ENROLLMENT_SHA:-2ea1d820e3f66110855f27e54961ce07e453d997351b843d02f968f1ca513ea9}"
EXPECTED_RESERVOIR_WRITER_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_WRITER_PLAN_SHA:-a14473b75881c161448e053e4cedd04cf0cecaf5b98c80c0e6d038dc067e057a}"
EXPECTED_RESERVOIR_WRITER_RECEIPTS_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_WRITER_RECEIPTS_SHA:-7e7eab0478b0c6715e6630c4848f067db29b424ccaa1255938b99b696f4a5360}"
EXPECTED_RESERVOIR_VERDICT_SHA="${LEO_STATE_COUNTERBALANCED_RESERVOIR_VERDICT_SHA:-330626f119ea809b1601cedbfc58242a08a6285faf9e29c9a95ac2a4dd3882c2}"

A101_POLICIES="$A101/policies.tsv"
A101_DISCOVERY_PLAN="$A101/discovery-plan.tsv"
A101_VALIDATION_PLAN="$A101/validation-plan.tsv"
A101_DISCOVERY_SUMMARY="$A101/discovery-summary.tsv"
A101_SELECTION="$A101/selection.tsv"
A101_VERDICT="$A101/verdict.txt"
EXPECTED_A101_POLICIES_SHA="${LEO_STATE_COUNTERBALANCED_A101_POLICIES_SHA:-89736f8e4681db85b8c516f8095c16786d2e13ed1edbd4d3203244baff5529ab}"
EXPECTED_A101_DISCOVERY_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A101_DISCOVERY_PLAN_SHA:-ebe356a8b3055c6467a163a38e3893c115bfd39ca13ab6cff56ac802f013b860}"
EXPECTED_A101_VALIDATION_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A101_VALIDATION_PLAN_SHA:-259be3140c58c7706f985283734cc0c57b99d2d46f6221c17ee0adad6c026a82}"
EXPECTED_A101_DISCOVERY_SUMMARY_SHA="${LEO_STATE_COUNTERBALANCED_A101_DISCOVERY_SUMMARY_SHA:-05daa176f90ece7e6eb94016a9bb8e1122f7df0f1c6b2528e8d68643bb8fbb7a}"
EXPECTED_A101_SELECTION_SHA="${LEO_STATE_COUNTERBALANCED_A101_SELECTION_SHA:-0933c24077634e0e993a4019c628eecb5331138ebd6a26bde4eed99741c3364b}"
EXPECTED_A101_VERDICT_SHA="${LEO_STATE_COUNTERBALANCED_A101_VERDICT_SHA:-24053340a58e648b569de83255970334ad4fbb87e2f3d694bb1187203c0ffb29}"

A103_POLICIES="$A103/policies.tsv"
A103_SOURCE_RECEIPT="$A103/source-receipt.tsv"
A103_DISCOVERY_PLAN="$A103/discovery-plan.tsv"
A103_VALIDATION_PLAN="$A103/validation-plan.tsv"
A103_DISCOVERY_SUMMARY="$A103/discovery-summary.tsv"
A103_SELECTION="$A103/selection.tsv"
A103_VERDICT="$A103/verdict.txt"
EXPECTED_A103_POLICIES_SHA="${LEO_STATE_COUNTERBALANCED_A103_POLICIES_SHA:-a6a2e5f56ea3b33f166d9ec7869a78dbeebecc7f0545855060bdc7311d254272}"
EXPECTED_A103_SOURCE_RECEIPT_SHA="${LEO_STATE_COUNTERBALANCED_A103_SOURCE_RECEIPT_SHA:-2ccf516531fd8d046cdbd8a9c79f3fda59c5ee49595181244f9f644602325cfd}"
EXPECTED_A103_DISCOVERY_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A103_DISCOVERY_PLAN_SHA:-4e96a373c7e099f159d7e8655a54c4b55d3668e76c7c97796bada65a17cbb8a0}"
EXPECTED_A103_VALIDATION_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A103_VALIDATION_PLAN_SHA:-4e311548121664b65f8988368ca0dcddf5908dc0fc84c35cab09d03249618d98}"
EXPECTED_A103_DISCOVERY_SUMMARY_SHA="${LEO_STATE_COUNTERBALANCED_A103_DISCOVERY_SUMMARY_SHA:-76d8424893e2a120da82e632b098cdd709b536617030590b3ff3f5a5940e1fed}"
EXPECTED_A103_SELECTION_SHA="${LEO_STATE_COUNTERBALANCED_A103_SELECTION_SHA:-51d3ab48d0f19dea16a7f6309eb2c86110cc9e47b0b9e320e7ba36b8fb356637}"
EXPECTED_A103_VERDICT_SHA="${LEO_STATE_COUNTERBALANCED_A103_VERDICT_SHA:-6e7e0b5dd7672006e6296831e5a0bc71c6e4e13351029c7732c3dc66c2b0b192}"

A104_POLICIES="$A104/policies.tsv"
A104_SOURCE_RECEIPT="$A104/source-receipt.tsv"
A104_DISCOVERY_PLAN="$A104/discovery-plan.tsv"
A104_VALIDATION_PLAN="$A104/validation-plan.tsv"
A104_DISCOVERY_SUMMARY="$A104/discovery-summary.tsv"
A104_SELECTION="$A104/selection.tsv"
A104_VERDICT="$A104/verdict.txt"
EXPECTED_A104_POLICIES_SHA="${LEO_STATE_COUNTERBALANCED_A104_POLICIES_SHA:-7e0f0587d53651d637674dc73ef1cd69bef396be6f35c55c31101eb8bc915b6d}"
EXPECTED_A104_SOURCE_RECEIPT_SHA="${LEO_STATE_COUNTERBALANCED_A104_SOURCE_RECEIPT_SHA:-0a5d8c07893296ddeb591baabf8c2c32721fe98c499580288a418e747c8973ee}"
EXPECTED_A104_DISCOVERY_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A104_DISCOVERY_PLAN_SHA:-b4ff5f967346fb796e19e86370fdb5f73639be3fe956d95699398e7f81e2e169}"
EXPECTED_A104_VALIDATION_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A104_VALIDATION_PLAN_SHA:-79802ab37ca79bfe669a8c1ef8e836cd5749c4aae151a511289ac1fef2182a46}"
EXPECTED_A104_DISCOVERY_SUMMARY_SHA="${LEO_STATE_COUNTERBALANCED_A104_DISCOVERY_SUMMARY_SHA:-920f385dfb98b78bb93d60245261ecde4db9003321981a6f96248a546151fe7c}"
EXPECTED_A104_SELECTION_SHA="${LEO_STATE_COUNTERBALANCED_A104_SELECTION_SHA:-13c87f6f4f16d776994cfcc7ff20288bb3472ee59d1f8e75f6e849b758dea8f6}"
EXPECTED_A104_VERDICT_SHA="${LEO_STATE_COUNTERBALANCED_A104_VERDICT_SHA:-60b876a9cc510ac7f4f732d0328b26aa76f79c95b46eef47e3268bea62c65520}"

A105_POLICIES="$A105/policies.tsv"
A105_SOURCE_RECEIPT="$A105/source-receipt.tsv"
A105_DISCOVERY_PLAN="$A105/discovery-plan.tsv"
A105_VALIDATION_PLAN="$A105/validation-plan.tsv"
A105_DISCOVERY_SUMMARY="$A105/discovery-summary.tsv"
A105_SELECTION="$A105/selection.tsv"
A105_VERDICT="$A105/verdict.txt"
EXPECTED_A105_POLICIES_SHA="${LEO_STATE_COUNTERBALANCED_A105_POLICIES_SHA:-ab3aa8c577b93466b02f657113c654cd4357d4ecf0f09d458f4ebb0cf172f7c4}"
EXPECTED_A105_SOURCE_RECEIPT_SHA="${LEO_STATE_COUNTERBALANCED_A105_SOURCE_RECEIPT_SHA:-ad55334596982dca3cba6b275fc3ead9ab3a4812ee45512b2c101e0610154110}"
EXPECTED_A105_DISCOVERY_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A105_DISCOVERY_PLAN_SHA:-4476c0b318e5fc418d6eb819b51e9acbc55a95862adbc4cf98c0cd81794a4e75}"
EXPECTED_A105_VALIDATION_PLAN_SHA="${LEO_STATE_COUNTERBALANCED_A105_VALIDATION_PLAN_SHA:-82fc866a958b81c8520933f09836815fb9283fb0d78e88fba0c9cbcc1288d754}"
EXPECTED_A105_DISCOVERY_SUMMARY_SHA="${LEO_STATE_COUNTERBALANCED_A105_DISCOVERY_SUMMARY_SHA:-00f9f1adb3512f6e066016ee371324b34b58646922ce50b5f0b85803f2daab6f}"
EXPECTED_A105_SELECTION_SHA="${LEO_STATE_COUNTERBALANCED_A105_SELECTION_SHA:-da33255ff64af6b03c69258ac04eab40bd4f928c32aeeca4d9559978a299efdd}"
EXPECTED_A105_VERDICT_SHA="${LEO_STATE_COUNTERBALANCED_A105_VERDICT_SHA:-689d2a884897eaf48041f0ec004fcc836474a86a4f0eea2da71ac56356968722}"

case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid road counterbalanced-consequence jobs: %s\n' "$JOBS" >&2; exit 2 ;;
esac
case "$AGGREGATE_ONLY" in
    0|1) ;;
    *) printf 'invalid aggregate-only value: %s\n' "$AGGREGATE_ONLY" >&2; exit 2 ;;
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

seal "$CANDIDATES" "$EXPECTED_CANDIDATES_SHA" "A.106 reservoir candidates"
seal "$WARM_CASES" "$EXPECTED_WARM_CASES_SHA" "A.106 warm cases"
seal "$WRITER_CASES" "$EXPECTED_WRITER_CASES_SHA" "A.106 writer cases"
seal "$REPORTER" "$EXPECTED_REPORTER_SHA" "A.106 reservoir reporter"
seal "$PLANNER" "$EXPECTED_PLANNER_SHA" "A.106 Williams planner"
seal "$PROSPECTIVE" "$EXPECTED_PROSPECTIVE_SHA" "A.106 prospective runner"
seal "$RESERVOIR_WRAPPER" "$EXPECTED_RESERVOIR_WRAPPER_SHA" "A.106 reservoir wrapper"
seal "$CONSEQUENCE_REPORTER" "$EXPECTED_CONSEQUENCE_REPORTER_SHA" "A.106 consequence reporter"
seal "$CONSEQUENCE_LIFE" "$EXPECTED_CONSEQUENCE_LIFE_SHA" "A.106 consequence life reducer"
seal "$CONSEQUENCE_SUMMARY" "$EXPECTED_CONSEQUENCE_SUMMARY_SHA" "A.106 consequence summary"
seal "$CONSEQUENCE_SELECTOR" "$EXPECTED_CONSEQUENCE_SELECTOR_SHA" "A.106 consequence selector"
seal "$CONSEQUENCE_VERDICT" "$EXPECTED_CONSEQUENCE_VERDICT_SHA" "A.106 consequence verdict"
seal "$LEO_SOURCE" "$EXPECTED_LEO_SOURCE_SHA" "A.106 Leo source"
seal "$LEO_CORPUS" "$EXPECTED_LEO_CORPUS_SHA" "A.106 Leo corpus"
seal "$AML_SOURCE" "$EXPECTED_AML_SOURCE_SHA" "A.106 AML source"
seal "$AML_HEADER" "$EXPECTED_AML_HEADER_SHA" "A.106 AML header"
seal "$DIALOGUE_REPORTER" "$EXPECTED_DIALOGUE_REPORTER_SHA" "A.106 dialogue reporter"
seal "$FIXTURE_SOURCE" "$EXPECTED_FIXTURE_SOURCE_SHA" "A.106 geometry fixture"
seal "$A101_POLICIES" "$EXPECTED_A101_POLICIES_SHA" "A.101 policies"
seal "$A101_DISCOVERY_PLAN" "$EXPECTED_A101_DISCOVERY_PLAN_SHA" "A.101 discovery plan"
seal "$A101_VALIDATION_PLAN" "$EXPECTED_A101_VALIDATION_PLAN_SHA" "A.101 validation plan"
seal "$A101_DISCOVERY_SUMMARY" "$EXPECTED_A101_DISCOVERY_SUMMARY_SHA" "A.101 discovery summary"
seal "$A101_SELECTION" "$EXPECTED_A101_SELECTION_SHA" "A.101 selection"
seal "$A101_VERDICT" "$EXPECTED_A101_VERDICT_SHA" "A.101 verdict"
seal "$A103_POLICIES" "$EXPECTED_A103_POLICIES_SHA" "A.103 policies"
seal "$A103_SOURCE_RECEIPT" "$EXPECTED_A103_SOURCE_RECEIPT_SHA" "A.103 source receipt"
seal "$A103_DISCOVERY_PLAN" "$EXPECTED_A103_DISCOVERY_PLAN_SHA" "A.103 discovery plan"
seal "$A103_VALIDATION_PLAN" "$EXPECTED_A103_VALIDATION_PLAN_SHA" "A.103 validation plan"
seal "$A103_DISCOVERY_SUMMARY" "$EXPECTED_A103_DISCOVERY_SUMMARY_SHA" "A.103 discovery summary"
seal "$A103_SELECTION" "$EXPECTED_A103_SELECTION_SHA" "A.103 selection"
seal "$A103_VERDICT" "$EXPECTED_A103_VERDICT_SHA" "A.103 verdict"
seal "$A104_POLICIES" "$EXPECTED_A104_POLICIES_SHA" "A.104 policies"
seal "$A104_SOURCE_RECEIPT" "$EXPECTED_A104_SOURCE_RECEIPT_SHA" "A.104 source receipt"
seal "$A104_DISCOVERY_PLAN" "$EXPECTED_A104_DISCOVERY_PLAN_SHA" "A.104 discovery plan"
seal "$A104_VALIDATION_PLAN" "$EXPECTED_A104_VALIDATION_PLAN_SHA" "A.104 validation plan"
seal "$A104_DISCOVERY_SUMMARY" "$EXPECTED_A104_DISCOVERY_SUMMARY_SHA" "A.104 discovery summary"
seal "$A104_SELECTION" "$EXPECTED_A104_SELECTION_SHA" "A.104 selection"
seal "$A104_VERDICT" "$EXPECTED_A104_VERDICT_SHA" "A.104 verdict"
seal "$A105_POLICIES" "$EXPECTED_A105_POLICIES_SHA" "A.105 policies"
seal "$A105_SOURCE_RECEIPT" "$EXPECTED_A105_SOURCE_RECEIPT_SHA" "A.105 source receipt"
seal "$A105_DISCOVERY_PLAN" "$EXPECTED_A105_DISCOVERY_PLAN_SHA" "A.105 discovery plan"
seal "$A105_VALIDATION_PLAN" "$EXPECTED_A105_VALIDATION_PLAN_SHA" "A.105 validation plan"
seal "$A105_DISCOVERY_SUMMARY" "$EXPECTED_A105_DISCOVERY_SUMMARY_SHA" "A.105 discovery summary"
seal "$A105_SELECTION" "$EXPECTED_A105_SELECTION_SHA" "A.105 selection"
seal "$A105_VERDICT" "$EXPECTED_A105_VERDICT_SHA" "A.105 verdict"
for forbidden in validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A101/$forbidden" ] || {
        printf 'A.101 validation was already opened: %s\n' "$A101/$forbidden" >&2
        exit 2
    }
done
grep -q '^result no-episode-memory-candidate$' "$A103_VERDICT" || {
    printf 'A.103 is not the sealed negative result\n' >&2; exit 2;
}
for forbidden in selected-policy.tsv validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A103/$forbidden" ] || {
        printf 'A.103 validation was already opened: %s\n' "$A103/$forbidden" >&2
        exit 2
    }
done
grep -q '^result no-episode-consequence-candidate$' "$A105_VERDICT" || {
    printf 'A.105 is not the sealed negative result\n' >&2; exit 2;
}
for forbidden in selected-policy.tsv validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A105/$forbidden" ] || {
        printf 'A.105 validation was already opened: %s\n' "$A105/$forbidden" >&2
        exit 2
    }
done
grep -q '^result no-ordered-path-candidate$' "$A104_VERDICT" || {
    printf 'A.104 is not the sealed negative result\n' >&2; exit 2;
}
for forbidden in selected-policy.tsv validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A104/$forbidden" ] || {
        printf 'A.104 validation was already opened: %s\n' "$A104/$forbidden" >&2
        exit 2
    }
done

awk -F '\t' '
    $1 == "err-cumulative-gentle" {
        rows++
        if ($2 != 1 || $3 != 0.25 || $4 != 1 || $5 != "discovery" ||
            $6 != 6 || $8 != 5 || $9 != 6 || $10 != 0.002035234 ||
            $12 != 0.002201537) exit 2
    }
    END { if (rows != 1) exit 2 }
' "$A101_DISCOVERY_SUMMARY" || {
    printf 'A.101 snapshot law is not the sealed rank-one discovery law\n' >&2
    exit 2
}

if [ ! -d "$RESERVOIR" ]; then
    [ "$AGGREGATE_ONLY" = 0 ] || {
        printf 'counterbalanced reservoir source missing during aggregate-only replay: %s\n' "$RESERVOIR" >&2
        exit 2
    }
    LEO_STATE_PROSPECTIVE_JOBS="$JOBS" \
        "$RESERVOIR_WRAPPER" \
        "$RESERVOIR" > "$RESERVOIR.stdout"
fi

SCREEN_PLAN="$RESERVOIR/screen-plan.tsv"
WARM_RECEIPTS="$RESERVOIR/warm-receipts.tsv"
ENROLLMENT="$RESERVOIR/enrollment.tsv"
WRITER_PLAN="$RESERVOIR/writer-plan.tsv"
WRITER_RECEIPTS="$RESERVOIR/writer-receipts.tsv"
RESERVOIR_VERDICT="$RESERVOIR/verdict.txt"
for path in "$SCREEN_PLAN" "$WARM_RECEIPTS" "$ENROLLMENT" \
    "$WRITER_PLAN" "$WRITER_RECEIPTS" "$RESERVOIR_VERDICT"; do
    [ -s "$path" ] || { printf 'incomplete counterbalanced reservoir source: %s\n' "$path" >&2; exit 2; }
done
seal "$SCREEN_PLAN" "$EXPECTED_RESERVOIR_SCREEN_PLAN_SHA" "A.106 reservoir screen plan"
seal "$WARM_RECEIPTS" "$EXPECTED_RESERVOIR_WARM_RECEIPTS_SHA" "A.106 reservoir warm receipts"
seal "$ENROLLMENT" "$EXPECTED_RESERVOIR_ENROLLMENT_SHA" "A.106 reservoir enrollment"
seal "$WRITER_PLAN" "$EXPECTED_RESERVOIR_WRITER_PLAN_SHA" "A.106 reservoir writer plan"
seal "$WRITER_RECEIPTS" "$EXPECTED_RESERVOIR_WRITER_RECEIPTS_SHA" "A.106 reservoir writer receipts"
seal "$RESERVOIR_VERDICT" "$EXPECTED_RESERVOIR_VERDICT_SHA" "A.106 reservoir verdict"
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$RESERVOIR_VERDICT" || {
    printf 'counterbalanced reservoir failed its own admission\n' >&2
    exit 2
}
awk -F '\t' '
    NR == 1 { if (NF != 5 || $1 != "life" || $5 != "enrollment_rank") exit 2; next }
    { rows++; split_count[$2]++; if ($2 !~ /^(primary|holdout)$/) exit 2 }
    END { if (rows != 64 || split_count["primary"] != 32 || split_count["holdout"] != 32) exit 2 }
' "$ENROLLMENT"
awk -F '\t' '
    FILENAME == ARGV[1] {
        if (FNR == 1) next
        if ($1 == "writer") source_session[$5] = $2
        next
    }
    FILENAME == ARGV[2] {
        if (FNR == 1) next
        life_split[$1] = $2; life_rank[$1] = $5
        next
    }
    FNR == 1 {
        if (NF != 9 || $1 != "life" || $5 != "session" || $9 != "prompt") exit 2
        next
    }
    {
        source = source_session[$9]
        cohort_split = life_split[$1]
        rank = life_rank[$1]
        cohort = rank <= 16 ? "discovery" : "validation"
        if (!source || cohort_split !~ /^(primary|holdout)$/ || rank < 1 || rank > 32 ||
            $2 != cohort_split || $4 != "writer" || $5 < 1 || $5 > 8 ||
            $6 < 1 || $6 > 8 || ++life_rows[$1] != ($5 - 1) * 8 + $6) exit 2
        if ($6 == 1) {
            position[cohort_split SUBSEP cohort SUBSEP $5 SUBSEP source]++
            if ($5 > 1)
                carry[cohort_split SUBSEP cohort SUBSEP previous[$1] SUBSEP source]++
            if ($5 >= 5)
                score_carry[cohort_split SUBSEP cohort SUBSEP previous[$1] SUBSEP source]++
            previous[$1] = source
        }
        rows++
    }
    END {
        if (rows != 4096 || length(life_rows) != 64) exit 2
        for (life in life_rows) if (life_rows[life] != 64) exit 2
        for (s = 1; s <= 2; s++) {
            cohort_split = s == 1 ? "primary" : "holdout"
            for (c = 1; c <= 2; c++) {
                cohort = c == 1 ? "discovery" : "validation"
                for (chronological = 1; chronological <= 8; chronological++)
                    for (source = 1; source <= 8; source++)
                        if (position[cohort_split SUBSEP cohort SUBSEP chronological SUBSEP source] != 2)
                            exit 2
                for (source = 1; source <= 8; source++)
                    for (destination = 1; destination <= 8; destination++) {
                        full = carry[cohort_split SUBSEP cohort SUBSEP source SUBSEP destination] + 0
                        scored = score_carry[cohort_split SUBSEP cohort SUBSEP source SUBSEP destination] + 0
                        full_expected = source == destination ? 0 : 2
                        scored_expected = source == destination ? 0 : \
                            (destination == ((source - 1 + 4) % 8) + 1 ? 2 : 1)
                        if (full != full_expected || scored != scored_expected) exit 2
                    }
            }
        }
    }
' "$WRITER_CASES" "$ENROLLMENT" "$WRITER_PLAN" || {
    printf 'counterbalanced reservoir does not balance the scored calendar\n' >&2
    exit 2
}

DISCOVERY_PLAN="$OUT/discovery-plan.tsv"
VALIDATION_PLAN="$OUT/validation-plan.tsv"
POLICIES="$OUT/policies.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
DISCOVERY_LOCKS="$OUT/discovery-locks.tsv"
DISCOVERY_WITNESSES="$OUT/discovery-witnesses.tsv"
DISCOVERY_SCORES="$OUT/discovery-scores.tsv"
DISCOVERY_LIFE="$OUT/discovery-life-summary.tsv"
DISCOVERY_SUMMARY="$OUT/discovery-summary.tsv"
SELECTION="$OUT/selection.tsv"
SELECTED_POLICY="$OUT/selected-policy.tsv"
VALIDATION_LOCKS="$OUT/validation-locks.tsv"
VALIDATION_WITNESSES="$OUT/validation-witnesses.tsv"
VALIDATION_SCORES="$OUT/validation-scores.tsv"
VALIDATION_LIFE="$OUT/validation-life-summary.tsv"
LIFE_SUMMARY="$OUT/life-summary.tsv"
CANDIDATE_SUMMARY="$OUT/candidate-summary.tsv"
VERDICT="$OUT/verdict.txt"
FIXTURE="$OUT/road-counterbalanced-consequence-fixture"

write_discovery_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 { print "cohort", $0; next }
        $5 >= 1 && $5 <= 16 { print "discovery", $0; rows++; split_count[$2]++ }
        END {
            if (rows != 32 || split_count["primary"] != 16 ||
                split_count["holdout"] != 16) exit 2
        }
    ' "$ENROLLMENT"
}

write_validation_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 { print "cohort", $0; next }
        $5 >= 17 && $5 <= 32 { print "validation", $0; rows++; split_count[$2]++ }
        END {
            if (rows != 32 || split_count["primary"] != 16 ||
                split_count["holdout"] != 16) exit 2
        }
    ' "$ENROLLMENT"
}

write_policies() {
    printf 'candidate\tconsequence_strength\tsnapshot_decay\tsnapshot_strength\ttexture_strength\tprior_alpha\tvariance_ridge\trank\n'
    printf 'consequence-light\t0.10\t1.00\t0.25\t0.25\t1\t1\t1\n'
    printf 'consequence-gentle\t0.25\t1.00\t0.25\t0.25\t1\t1\t2\n'
}

write_design() {
    printf 'constraint\tvalue\n'
    printf 'calendar\tpaired-williams8\n'
    printf 'discovery-lives\t32\n'
    printf 'validation-lives\t32\n'
    printf 'lives-per-split\t16\n'
    printf 'evaluation-session\t5\n'
    printf 'minimum-scored-episodes\t2\n'
    printf 'required-life-wins\t22\n'
    printf 'required-split-wins\t10\n'
    printf 'scored-nonself-pairs-per-split\t56\n'
    printf 'scored-antipodal-pair-repeats\t2\n'
    printf 'scored-other-pair-repeats\t1\n'
}

write_source_receipt() {
    printf 'source\tsha256\n'
    printf 'reservoir-candidates\t%s\n' "$EXPECTED_CANDIDATES_SHA"
    printf 'reservoir-warm-cases\t%s\n' "$EXPECTED_WARM_CASES_SHA"
    printf 'reservoir-writer-cases\t%s\n' "$EXPECTED_WRITER_CASES_SHA"
    printf 'reservoir-reporter\t%s\n' "$EXPECTED_REPORTER_SHA"
    printf 'williams-planner\t%s\n' "$EXPECTED_PLANNER_SHA"
    printf 'prospective-runner\t%s\n' "$EXPECTED_PROSPECTIVE_SHA"
    printf 'reservoir-wrapper\t%s\n' "$EXPECTED_RESERVOIR_WRAPPER_SHA"
    printf 'consequence-reporter\t%s\n' "$EXPECTED_CONSEQUENCE_REPORTER_SHA"
    printf 'consequence-life-reducer\t%s\n' "$EXPECTED_CONSEQUENCE_LIFE_SHA"
    printf 'consequence-summary\t%s\n' "$EXPECTED_CONSEQUENCE_SUMMARY_SHA"
    printf 'consequence-selector\t%s\n' "$EXPECTED_CONSEQUENCE_SELECTOR_SHA"
    printf 'consequence-verdict\t%s\n' "$EXPECTED_CONSEQUENCE_VERDICT_SHA"
    printf 'leo-source\t%s\n' "$EXPECTED_LEO_SOURCE_SHA"
    printf 'leo-corpus\t%s\n' "$EXPECTED_LEO_CORPUS_SHA"
    printf 'aml-source\t%s\n' "$EXPECTED_AML_SOURCE_SHA"
    printf 'aml-header\t%s\n' "$EXPECTED_AML_HEADER_SHA"
    printf 'dialogue-reporter\t%s\n' "$EXPECTED_DIALOGUE_REPORTER_SHA"
    printf 'geometry-fixture\t%s\n' "$EXPECTED_FIXTURE_SOURCE_SHA"
    printf 'reservoir-screen-plan\t%s\n' "$(sha256_file "$SCREEN_PLAN")"
    printf 'reservoir-warm-receipts\t%s\n' "$(sha256_file "$WARM_RECEIPTS")"
    printf 'reservoir-enrollment\t%s\n' "$(sha256_file "$ENROLLMENT")"
    printf 'reservoir-writer-plan\t%s\n' "$(sha256_file "$WRITER_PLAN")"
    printf 'reservoir-writer-receipts\t%s\n' "$(sha256_file "$WRITER_RECEIPTS")"
    printf 'reservoir-verdict\t%s\n' "$(sha256_file "$RESERVOIR_VERDICT")"
    printf 'a101-policies\t%s\n' "$EXPECTED_A101_POLICIES_SHA"
    printf 'a101-discovery-plan\t%s\n' "$EXPECTED_A101_DISCOVERY_PLAN_SHA"
    printf 'a101-validation-plan\t%s\n' "$EXPECTED_A101_VALIDATION_PLAN_SHA"
    printf 'a101-discovery-summary\t%s\n' "$EXPECTED_A101_DISCOVERY_SUMMARY_SHA"
    printf 'a101-selection\t%s\n' "$EXPECTED_A101_SELECTION_SHA"
    printf 'a101-verdict\t%s\n' "$EXPECTED_A101_VERDICT_SHA"
    printf 'a103-policies\t%s\n' "$EXPECTED_A103_POLICIES_SHA"
    printf 'a103-source-receipt\t%s\n' "$EXPECTED_A103_SOURCE_RECEIPT_SHA"
    printf 'a103-discovery-plan\t%s\n' "$EXPECTED_A103_DISCOVERY_PLAN_SHA"
    printf 'a103-validation-plan\t%s\n' "$EXPECTED_A103_VALIDATION_PLAN_SHA"
    printf 'a103-discovery-summary\t%s\n' "$EXPECTED_A103_DISCOVERY_SUMMARY_SHA"
    printf 'a103-selection\t%s\n' "$EXPECTED_A103_SELECTION_SHA"
    printf 'a103-verdict\t%s\n' "$EXPECTED_A103_VERDICT_SHA"
    printf 'a104-policies\t%s\n' "$EXPECTED_A104_POLICIES_SHA"
    printf 'a104-source-receipt\t%s\n' "$EXPECTED_A104_SOURCE_RECEIPT_SHA"
    printf 'a104-discovery-plan\t%s\n' "$EXPECTED_A104_DISCOVERY_PLAN_SHA"
    printf 'a104-validation-plan\t%s\n' "$EXPECTED_A104_VALIDATION_PLAN_SHA"
    printf 'a104-discovery-summary\t%s\n' "$EXPECTED_A104_DISCOVERY_SUMMARY_SHA"
    printf 'a104-selection\t%s\n' "$EXPECTED_A104_SELECTION_SHA"
    printf 'a104-verdict\t%s\n' "$EXPECTED_A104_VERDICT_SHA"
    printf 'a105-policies\t%s\n' "$EXPECTED_A105_POLICIES_SHA"
    printf 'a105-source-receipt\t%s\n' "$EXPECTED_A105_SOURCE_RECEIPT_SHA"
    printf 'a105-discovery-plan\t%s\n' "$EXPECTED_A105_DISCOVERY_PLAN_SHA"
    printf 'a105-validation-plan\t%s\n' "$EXPECTED_A105_VALIDATION_PLAN_SHA"
    printf 'a105-discovery-summary\t%s\n' "$EXPECTED_A105_DISCOVERY_SUMMARY_SHA"
    printf 'a105-selection\t%s\n' "$EXPECTED_A105_SELECTION_SHA"
    printf 'a105-verdict\t%s\n' "$EXPECTED_A105_VERDICT_SHA"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DISCOVERY_PLAN" "$VALIDATION_PLAN" "$POLICIES" "$DESIGN" \
        "$SOURCE_RECEIPT" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"; do
        [ -s "$path" ] || { printf 'incomplete counterbalanced-consequence run: %s\n' "$path" >&2; exit 2; }
    done
    write_discovery_plan | cmp -s - "$DISCOVERY_PLAN" || { printf 'A.106 discovery plan diverged\n' >&2; exit 2; }
    write_validation_plan | cmp -s - "$VALIDATION_PLAN" || { printf 'A.106 validation plan diverged\n' >&2; exit 2; }
    write_policies | cmp -s - "$POLICIES" || { printf 'A.106 policy ledger diverged\n' >&2; exit 2; }
    write_design | cmp -s - "$DESIGN" || { printf 'A.106 design ledger diverged\n' >&2; exit 2; }
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT" || { printf 'A.106 source receipt diverged\n' >&2; exit 2; }
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/replays"
    write_discovery_plan > "$DISCOVERY_PLAN"
    write_validation_plan > "$VALIDATION_PLAN"
    write_policies > "$POLICIES"
    write_design > "$DESIGN"
    write_source_receipt > "$SOURCE_RECEIPT"
fi

if [ "${LEO_STATE_COUNTERBALANCED_PLAN_ONLY:-0}" = 1 ]; then
    cat "$DISCOVERY_PLAN"; printf '\n'; cat "$VALIDATION_PLAN"; printf '\n'; cat "$POLICIES"; printf '\n'; cat "$DESIGN"
    exit 0
fi

normalize_log() {
    sed -E \
        -e 's|^\[leo step0\] ingest corpus .*$|[leo step0] ingest corpus NORMALIZED|' \
        -e 's|^\[leo\] loaded state from .*$|[leo] loaded state from BODY|' \
        -e 's|^\[leo\] saved state to .* \(step=|[leo] saved state to BODY (step=|' \
        "$1"
}

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); print; exit }' "$1"
}

run_life() {
    local cohort="$1" wanted_life="$2" wanted_split="$3" base_seed="$4"
    local life_dir="$OUT/replays/$wanted_split-$wanted_life"
    local state="$life_dir/leo.state"
    local source_body="$RESERVOIR/candidates/$wanted_life/leo.state"
    local generated_all="$life_dir/generated.normalized"
    local source_all="$life_dir/source.normalized"
    local life_witnesses="$life_dir/witnesses.tsv"
    local life_lock="$life_dir/lock.tsv"
    local rows=0
    mkdir -p "$life_dir"
    : > "$generated_all"; : > "$source_all"; : > "$life_witnesses"

    while IFS=$'\t' read -r life split warm_base phase session order texture run_seed prompt; do
        [ "$life" = "$wanted_life" ] && [ "$split" = "$wanted_split" ] || continue
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local generated="$life_dir/current.log"
        local canonical="$RESERVOIR/candidates/$life/warm-logs/$stem.log"
        local args=("$ROOT/leo" --corpus "$ROOT/leo.txt")
        [ -s "$state" ] && args+=(--load "$state")
        args+=(--seed "$run_seed" --respond "$prompt" --debug-field --save "$state")
        "${args[@]}" > "$generated" 2>&1
        normalize_log "$generated" >> "$generated_all"
        normalize_log "$canonical" >> "$source_all"
        rows=$((rows + 1))
    done < "$SCREEN_PLAN"
    [ "$rows" -eq 32 ] || return 1

    rows=0
    while IFS=$'\t' read -r life split writer_base phase session order texture run_seed prompt; do
        [ "$life" = "$wanted_life" ] && [ "$split" = "$wanted_split" ] || continue
        local turn=$((32 + (session - 1) * 8 + order))
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local generated="$life_dir/current.log"
        local canonical="$RESERVOIR/candidates/$life/writer-logs/$stem.log"
        local geometry="$life_dir/geometry.tsv"
        local generated_receipt="$life_dir/generated-receipt.tsv"
        local source_receipt="$life_dir/source-receipt.tsv"
        local reply
        "$FIXTURE" "$state" > "$geometry"
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$state" \
            --seed "$run_seed" --respond "$prompt" --debug-field --save "$state" \
            > "$generated" 2>&1
        normalize_log "$generated" >> "$generated_all"
        normalize_log "$canonical" >> "$source_all"
        reply="$(reply_from_log "$generated")"
        [ -n "$reply" ] || return 1
        awk -v cell="$life" -v cohort="$split" -v base_seed="$base_seed" \
            -v phase=writer -v session="$session" -v order="$order" \
            -v texture="$texture" -v run_seed="$run_seed" -v prompt="$prompt" \
            -v reply="$reply" -f "$ROOT/scripts/state_swarm_dialogue_report.awk" \
            "$generated" > "$generated_receipt"
        awk -F '\t' -v life="$life" -v wanted_split="$split" -v turn="$turn" \
            'NR == 1 { next } $1 == life && $2 == wanted_split && $9 == turn { print; rows++ }
             END { if (rows != 1) exit 2 }' "$WRITER_RECEIPTS" > "$source_receipt"
        cmp -s "$generated_receipt" "$source_receipt" || return 1
        IFS=$'\t' read -r pre_turn pre_ids source transition transition_total < "$geometry"
        awk -F '\t' -v OFS='\t' -v cohort="$cohort" -v pre_turn="$pre_turn" \
            -v pre_ids="$pre_ids" -v transition="$transition" -v source="$source" \
            -v transition_total="$transition_total" '
            { print cohort, $1, $2, $9, $5, $6, $7, $13, pre_turn, pre_ids,
                    $16, transition, source, transition_total, $12, $19, $20,
                    $21, $22, $23, $24, $33, $34 }
        ' "$generated_receipt" >> "$life_witnesses"
        rows=$((rows + 1))
    done < "$WRITER_PLAN"
    [ "$rows" -eq 64 ] || return 1
    cmp -s "$generated_all" "$source_all" || return 1
    cmp -s "$state" "$source_body" || return 1
    printf '%s\t%s\t%s\t64\ttrue\ttrue\t%s\t%s\n' \
        "$cohort" "$wanted_life" "$wanted_split" \
        "$(sha256_file "$generated_all")" "$(sha256_file "$state")" > "$life_lock"
    rm -f "$life_dir/current.log" "$life_dir/geometry.tsv" \
        "$life_dir/generated-receipt.tsv" "$life_dir/source-receipt.tsv"
}

replay_plan() {
    local plan="$1" locks="$2" witnesses="$3"
    local pids=() running=0
    while IFS=$'\t' read -r cohort life split base_seed candidate_order enrollment_rank; do
        run_life "$cohort" "$life" "$split" "$base_seed" &
        pids+=("$!"); running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=(); running=0
        fi
    done < <(tail -n +2 "$plan")
    if [ "$running" -gt 0 ]; then for pid in "${pids[@]}"; do wait "$pid"; done; fi

    printf 'cohort\tlife\tsplit\twriter_turns\twarm_writer_equal\tfinal_state_equal\tnormalized_log_sha\tfinal_state_sha\n' > "$locks"
    printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tprompt\treply\n' > "$witnesses"
    while IFS=$'\t' read -r cohort life split base_seed candidate_order enrollment_rank; do
        cat "$OUT/replays/$split-$life/lock.tsv" >> "$locks"
        cat "$OUT/replays/$split-$life/witnesses.tsv" >> "$witnesses"
    done < <(tail -n +2 "$plan")
}

if [ "$AGGREGATE_ONLY" != 1 ]; then
    make -C "$ROOT" leo >/dev/null
    "$CC" "$ROOT/tests/state_swarm_road_prequential_fixture.c" \
        -O2 -lm -Wall -Wextra -Wno-unused-function -o "$FIXTURE" -lpthread
    replay_plan "$DISCOVERY_PLAN" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"
fi

awk -v policy_expected=2 -v life_expected=32 -v writer_expected=64 \
    -v evaluation_session=5 -v score_min=2 \
    -f "$CONSEQUENCE_REPORTER" \
    "$POLICIES" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES" > "$DISCOVERY_SCORES"
awk -v policy_expected=2 -v life_expected=32 -v min_episodes=2 \
    -f "$CONSEQUENCE_LIFE" \
    "$DISCOVERY_SCORES" > "$DISCOVERY_LIFE"
awk -v policy_expected=2 -v discovery_expected=32 -v validation_expected=32 \
    -f "$CONSEQUENCE_SUMMARY" \
    "$DISCOVERY_LIFE" > "$DISCOVERY_SUMMARY"
awk -v policy_expected=2 -v expected=32 -v life_win_required=22 -v split_win_required=10 \
    -f "$CONSEQUENCE_SELECTOR" \
    "$DISCOVERY_SUMMARY" > "$SELECTION"

selected="$(awk -F '\t' 'NR == 2 { print $1 }' "$SELECTION")"
[ -n "$selected" ] || { printf 'A.106 selection is empty\n' >&2; exit 2; }

if [ "$selected" != none ]; then
    { sed -n '1p' "$POLICIES"; awk -F '\t' -v selected="$selected" '$1 == selected' "$POLICIES"; } \
        > "$SELECTED_POLICY"
    [ "$(wc -l < "$SELECTED_POLICY" | tr -d ' ')" -eq 2 ] || {
        printf 'selected counterbalanced-consequence policy is not unique\n' >&2; exit 2;
    }
    if [ "$AGGREGATE_ONLY" != 1 ]; then
        replay_plan "$VALIDATION_PLAN" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES"
    else
        for path in "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES"; do
            [ -s "$path" ] || { printf 'selected candidate lacks validation evidence: %s\n' "$path" >&2; exit 2; }
        done
    fi
    awk -v policy_expected=1 -v life_expected=32 -v writer_expected=64 \
        -v evaluation_session=5 -v score_min=2 \
        -f "$CONSEQUENCE_REPORTER" \
        "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" > "$VALIDATION_SCORES"
    awk -v policy_expected=1 -v life_expected=32 -v min_episodes=2 \
        -f "$CONSEQUENCE_LIFE" \
        "$VALIDATION_SCORES" > "$VALIDATION_LIFE"
    { sed -n '1p' "$DISCOVERY_LIFE"; tail -n +2 "$DISCOVERY_LIFE"; tail -n +2 "$VALIDATION_LIFE"; } \
        > "$LIFE_SUMMARY"
else
    for path in "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" \
        "$VALIDATION_SCORES" "$VALIDATION_LIFE"; do
        [ ! -e "$path" ] || { printf 'no-candidate run exposed validation artifact: %s\n' "$path" >&2; exit 2; }
    done
    cp "$DISCOVERY_LIFE" "$LIFE_SUMMARY"
fi

rm -f "$FIXTURE"
awk -v policy_expected=2 -v discovery_expected=32 -v validation_expected=32 \
    -f "$CONSEQUENCE_SUMMARY" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -v expected=32 -v life_win_required=22 -v split_win_required=10 \
    -f "$CONSEQUENCE_VERDICT" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"; printf '\n'; cat "$SELECTION"; printf '\n'; cat "$VERDICT"
printf '\nreservoir-source: %s\nrun: %s\n' "$RESERVOIR" "$OUT"
