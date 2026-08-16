#!/usr/bin/env bash
# A.109: test whether an unexpected realized consequence survives the full signed path that followed it.
set -Eeuo pipefail

trap 'rc=$?; printf "road delayed-outcome-receipt runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
RESERVOIR="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_SOURCE:-/private/tmp/leo-state-swarm-outcome-receipt-reservoir-a109-r1-20260816}"
A101="${LEO_STATE_OUTCOME_RECEIPT_A101_SOURCE:-/private/tmp/leo-state-swarm-road-error-memory-a101-r1-20260810}"
A103="${LEO_STATE_OUTCOME_RECEIPT_A103_SOURCE:-/private/tmp/leo-state-swarm-road-episode-memory-a103-r2-20260813}"
A104="${LEO_STATE_OUTCOME_RECEIPT_A104_SOURCE:-/private/tmp/leo-state-swarm-road-ordered-episode-a104-r1-20260813}"
A105="${LEO_STATE_OUTCOME_RECEIPT_A105_SOURCE:-/private/tmp/leo-state-swarm-road-episode-consequence-a105-r1-20260813}"
A106="${LEO_STATE_OUTCOME_RECEIPT_A106_SOURCE:-/private/tmp/leo-state-swarm-road-counterbalanced-consequence-a106-r2-20260813}"
A107="${LEO_STATE_OUTCOME_RECEIPT_A107_SOURCE:-/private/tmp/leo-state-swarm-road-delayed-consequence-receipt-a107-r1-20260813}"
A108="${LEO_STATE_OUTCOME_RECEIPT_A108_SOURCE:-/private/tmp/leo-state-swarm-road-delayed-receipt-path-a108-r2-20260815}"
JOBS="${LEO_STATE_OUTCOME_RECEIPT_JOBS:-4}"
AGGREGATE_ONLY="${LEO_STATE_OUTCOME_RECEIPT_AGGREGATE_ONLY:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-road-delayed-outcome-receipt-$STAMP}"

CANDIDATES="$ROOT/scripts/state_swarm_outcome_receipt_reservoir_candidates.tsv"
WARM_CASES="$ROOT/scripts/state_swarm_settled_warmup_cases.tsv"
WRITER_CASES="$ROOT/scripts/state_swarm_alphabet_cases.tsv"
REPORTER="$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk"
PLANNER="$ROOT/scripts/state_swarm_williams8_writer_plan.awk"
PROSPECTIVE="$ROOT/scripts/state_swarm_prospective_incidence_matrix.sh"
RESERVOIR_WRAPPER="$ROOT/scripts/state_swarm_outcome_receipt_reservoir_matrix.sh"
ELIGIBILITY_REPORTER="$ROOT/scripts/state_swarm_delayed_receipt_eligibility.awk"
RECEIPT_REPORTER="$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_report.awk"
RECEIPT_LIFE="$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_life.awk"
RECEIPT_SUMMARY="$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_summary.awk"
RECEIPT_SELECTOR="$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_select.awk"
RECEIPT_VERDICT="$ROOT/scripts/state_swarm_road_delayed_outcome_receipt_verdict.awk"
LEO_SOURCE="$ROOT/leo.c"
LEO_CORPUS="$ROOT/leo.txt"
AML_SOURCE="$ROOT/ariannamethod/ariannamethod.c"
AML_HEADER="$ROOT/ariannamethod/ariannamethod.h"
DIALOGUE_REPORTER="$ROOT/scripts/state_swarm_dialogue_report.awk"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_road_prequential_fixture.c"
EXPECTED_CANDIDATES_SHA="${LEO_STATE_OUTCOME_RECEIPT_CANDIDATES_SHA:-1ffcfdfac5fc13facb08a762f8e2c8240d534eef305be88623b6779b23d0487c}"
EXPECTED_WARM_CASES_SHA="${LEO_STATE_OUTCOME_RECEIPT_WARM_CASES_SHA:-1f6e57f2ab55660b8a4cf2cc3e0a2769fa96ffd00ad0d8623e699b318acb4c0b}"
EXPECTED_WRITER_CASES_SHA="${LEO_STATE_OUTCOME_RECEIPT_WRITER_CASES_SHA:-cfa13bb521d91a6a9f3db7fc278927f9120cd699fe72ce1a149307c170ea45e2}"
EXPECTED_REPORTER_SHA="${LEO_STATE_OUTCOME_RECEIPT_REPORTER_SHA:-4667e61986b9fd43c62098786ddc28c9d79ecf5dfd1f74ecd1128b587005af80}"
EXPECTED_PLANNER_SHA="${LEO_STATE_OUTCOME_RECEIPT_PLANNER_SHA:-2ccdaaeb73abad66c5f359dc927cb12a813a66f9489bf9017ba32728fd16b2a5}"
EXPECTED_PROSPECTIVE_SHA="${LEO_STATE_OUTCOME_RECEIPT_PROSPECTIVE_SHA:-648c4202fc2c86d495b9e97568d9b982940beac7058f196f2c96fb9b40a9a181}"
EXPECTED_RESERVOIR_WRAPPER_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_WRAPPER_SHA:-9ef4564fbc06a8a8ae3eb7a0b458ff3305457096de4b6f609e5b47262a25695c}"
EXPECTED_ELIGIBILITY_REPORTER_SHA="${LEO_STATE_OUTCOME_RECEIPT_ELIGIBILITY_REPORTER_SHA:-737dc716b751ab475cbafc0640a3eab47c8e8ce620d5c6aba3be1dbe4d67065b}"
EXPECTED_RECEIPT_REPORTER_SHA="${LEO_STATE_OUTCOME_RECEIPT_RECEIPT_REPORTER_SHA:-ad663e279e9c92ff44d8a98c54007eb12e56792d2c66d6923187776806d0af55}"
EXPECTED_RECEIPT_LIFE_SHA="${LEO_STATE_OUTCOME_RECEIPT_RECEIPT_LIFE_SHA:-2c945db4ea824d076821db4d17032ac397f32b246430ac50aec39310fb24d9ca}"
EXPECTED_RECEIPT_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_RECEIPT_SUMMARY_SHA:-6481fa1e62ac85e84ab358a2b8c45ec3067abf62b55f2a38e12b9a928c4a3911}"
EXPECTED_RECEIPT_SELECTOR_SHA="${LEO_STATE_OUTCOME_RECEIPT_RECEIPT_SELECTOR_SHA:-87106b485e75c5b5ef5513230b2ba62822928f37f63175a071138601072e391c}"
EXPECTED_RECEIPT_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_RECEIPT_VERDICT_SHA:-84c9073066ef100682d692255e75148b97e5fe3393df51edd56dfe921c09170d}"
EXPECTED_LEO_SOURCE_SHA="${LEO_STATE_OUTCOME_RECEIPT_LEO_SOURCE_SHA:-755f5f0a1e803f36b29ead5517086137af3696baf1959ad34bbca940316b8e73}"
EXPECTED_LEO_CORPUS_SHA="${LEO_STATE_OUTCOME_RECEIPT_LEO_CORPUS_SHA:-98b3052353fc30e8bd08d3c2368ca1aaea41f9fb45b5f7cc2c6a17b78a9b4c19}"
EXPECTED_AML_SOURCE_SHA="${LEO_STATE_OUTCOME_RECEIPT_AML_SOURCE_SHA:-a5cdb03356c9a51cbc8cc664333381cb975bd8c38622f30d293bb93e62ecb54d}"
EXPECTED_AML_HEADER_SHA="${LEO_STATE_OUTCOME_RECEIPT_AML_HEADER_SHA:-b333a334658bbd1516cd9be79ca78c9e0cfd8acbfb90372a3c24af32cc0cca4a}"
EXPECTED_DIALOGUE_REPORTER_SHA="${LEO_STATE_OUTCOME_RECEIPT_DIALOGUE_REPORTER_SHA:-35e393658785740430eec603459dac5ec3bfc1dc8bbac37f531de16582fe4c5e}"
EXPECTED_FIXTURE_SOURCE_SHA="${LEO_STATE_OUTCOME_RECEIPT_FIXTURE_SOURCE_SHA:-6876954c90540ed92aa91a8beb47b433cee231207796b7d84c42c9f2dd9afa47}"
EXPECTED_RESERVOIR_SCREEN_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_SCREEN_PLAN_SHA:-1e9205f155e15982c49563cb961d67f31f4dd630ce7279f2ae44dee0d27488fa}"
EXPECTED_RESERVOIR_WARM_RECEIPTS_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_WARM_RECEIPTS_SHA:-0a5219e2ec0efd879e3671dc04122a9b72d066d457bde325c29445f69d8b61de}"
EXPECTED_RESERVOIR_ENROLLMENT_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_ENROLLMENT_SHA:-30439b18ef7f0b76c82bd35da753ebece51f7b26a7bb6c0cf96ff6f5e7b07f0b}"
EXPECTED_RESERVOIR_WRITER_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_WRITER_PLAN_SHA:-7e4a40024907f99ebb5d1e8a1a1d3d9ca5ac6cb01269ff040be81f127190c57a}"
EXPECTED_RESERVOIR_WRITER_RECEIPTS_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_WRITER_RECEIPTS_SHA:-a10b03100b5ee13ce0658c7572ca9a1741f26c42f6c41b9892c8814ef4ab23d1}"
EXPECTED_RESERVOIR_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_RESERVOIR_VERDICT_SHA:-ffa012e2b2846e9eda099172bb93fb15954da68d9d30ef5797727b143439274a}"

A101_POLICIES="$A101/policies.tsv"
A101_DISCOVERY_PLAN="$A101/discovery-plan.tsv"
A101_VALIDATION_PLAN="$A101/validation-plan.tsv"
A101_DISCOVERY_SUMMARY="$A101/discovery-summary.tsv"
A101_SELECTION="$A101/selection.tsv"
A101_VERDICT="$A101/verdict.txt"
EXPECTED_A101_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A101_POLICIES_SHA:-89736f8e4681db85b8c516f8095c16786d2e13ed1edbd4d3203244baff5529ab}"
EXPECTED_A101_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A101_DISCOVERY_PLAN_SHA:-ebe356a8b3055c6467a163a38e3893c115bfd39ca13ab6cff56ac802f013b860}"
EXPECTED_A101_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A101_VALIDATION_PLAN_SHA:-259be3140c58c7706f985283734cc0c57b99d2d46f6221c17ee0adad6c026a82}"
EXPECTED_A101_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A101_DISCOVERY_SUMMARY_SHA:-05daa176f90ece7e6eb94016a9bb8e1122f7df0f1c6b2528e8d68643bb8fbb7a}"
EXPECTED_A101_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A101_SELECTION_SHA:-0933c24077634e0e993a4019c628eecb5331138ebd6a26bde4eed99741c3364b}"
EXPECTED_A101_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A101_VERDICT_SHA:-24053340a58e648b569de83255970334ad4fbb87e2f3d694bb1187203c0ffb29}"

A103_POLICIES="$A103/policies.tsv"
A103_SOURCE_RECEIPT="$A103/source-receipt.tsv"
A103_DISCOVERY_PLAN="$A103/discovery-plan.tsv"
A103_VALIDATION_PLAN="$A103/validation-plan.tsv"
A103_DISCOVERY_SUMMARY="$A103/discovery-summary.tsv"
A103_SELECTION="$A103/selection.tsv"
A103_VERDICT="$A103/verdict.txt"
EXPECTED_A103_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_POLICIES_SHA:-a6a2e5f56ea3b33f166d9ec7869a78dbeebecc7f0545855060bdc7311d254272}"
EXPECTED_A103_SOURCE_RECEIPT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_SOURCE_RECEIPT_SHA:-2ccf516531fd8d046cdbd8a9c79f3fda59c5ee49595181244f9f644602325cfd}"
EXPECTED_A103_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_DISCOVERY_PLAN_SHA:-4e96a373c7e099f159d7e8655a54c4b55d3668e76c7c97796bada65a17cbb8a0}"
EXPECTED_A103_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_VALIDATION_PLAN_SHA:-4e311548121664b65f8988368ca0dcddf5908dc0fc84c35cab09d03249618d98}"
EXPECTED_A103_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_DISCOVERY_SUMMARY_SHA:-76d8424893e2a120da82e632b098cdd709b536617030590b3ff3f5a5940e1fed}"
EXPECTED_A103_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_SELECTION_SHA:-51d3ab48d0f19dea16a7f6309eb2c86110cc9e47b0b9e320e7ba36b8fb356637}"
EXPECTED_A103_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A103_VERDICT_SHA:-6e7e0b5dd7672006e6296831e5a0bc71c6e4e13351029c7732c3dc66c2b0b192}"

A104_POLICIES="$A104/policies.tsv"
A104_SOURCE_RECEIPT="$A104/source-receipt.tsv"
A104_DISCOVERY_PLAN="$A104/discovery-plan.tsv"
A104_VALIDATION_PLAN="$A104/validation-plan.tsv"
A104_DISCOVERY_SUMMARY="$A104/discovery-summary.tsv"
A104_SELECTION="$A104/selection.tsv"
A104_VERDICT="$A104/verdict.txt"
EXPECTED_A104_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_POLICIES_SHA:-7e0f0587d53651d637674dc73ef1cd69bef396be6f35c55c31101eb8bc915b6d}"
EXPECTED_A104_SOURCE_RECEIPT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_SOURCE_RECEIPT_SHA:-0a5d8c07893296ddeb591baabf8c2c32721fe98c499580288a418e747c8973ee}"
EXPECTED_A104_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_DISCOVERY_PLAN_SHA:-b4ff5f967346fb796e19e86370fdb5f73639be3fe956d95699398e7f81e2e169}"
EXPECTED_A104_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_VALIDATION_PLAN_SHA:-79802ab37ca79bfe669a8c1ef8e836cd5749c4aae151a511289ac1fef2182a46}"
EXPECTED_A104_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_DISCOVERY_SUMMARY_SHA:-920f385dfb98b78bb93d60245261ecde4db9003321981a6f96248a546151fe7c}"
EXPECTED_A104_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_SELECTION_SHA:-13c87f6f4f16d776994cfcc7ff20288bb3472ee59d1f8e75f6e849b758dea8f6}"
EXPECTED_A104_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A104_VERDICT_SHA:-60b876a9cc510ac7f4f732d0328b26aa76f79c95b46eef47e3268bea62c65520}"

A105_POLICIES="$A105/policies.tsv"
A105_SOURCE_RECEIPT="$A105/source-receipt.tsv"
A105_DISCOVERY_PLAN="$A105/discovery-plan.tsv"
A105_VALIDATION_PLAN="$A105/validation-plan.tsv"
A105_DISCOVERY_SUMMARY="$A105/discovery-summary.tsv"
A105_SELECTION="$A105/selection.tsv"
A105_VERDICT="$A105/verdict.txt"
EXPECTED_A105_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_POLICIES_SHA:-ab3aa8c577b93466b02f657113c654cd4357d4ecf0f09d458f4ebb0cf172f7c4}"
EXPECTED_A105_SOURCE_RECEIPT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_SOURCE_RECEIPT_SHA:-ad55334596982dca3cba6b275fc3ead9ab3a4812ee45512b2c101e0610154110}"
EXPECTED_A105_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_DISCOVERY_PLAN_SHA:-4476c0b318e5fc418d6eb819b51e9acbc55a95862adbc4cf98c0cd81794a4e75}"
EXPECTED_A105_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_VALIDATION_PLAN_SHA:-82fc866a958b81c8520933f09836815fb9283fb0d78e88fba0c9cbcc1288d754}"
EXPECTED_A105_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_DISCOVERY_SUMMARY_SHA:-00f9f1adb3512f6e066016ee371324b34b58646922ce50b5f0b85803f2daab6f}"
EXPECTED_A105_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_SELECTION_SHA:-da33255ff64af6b03c69258ac04eab40bd4f928c32aeeca4d9559978a299efdd}"
EXPECTED_A105_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A105_VERDICT_SHA:-689d2a884897eaf48041f0ec004fcc836474a86a4f0eea2da71ac56356968722}"

A106_POLICIES="$A106/policies.tsv"
A106_DESIGN="$A106/design.tsv"
A106_SOURCE_RECEIPT="$A106/source-receipt.tsv"
A106_DISCOVERY_PLAN="$A106/discovery-plan.tsv"
A106_VALIDATION_PLAN="$A106/validation-plan.tsv"
A106_DISCOVERY_SUMMARY="$A106/discovery-summary.tsv"
A106_SELECTION="$A106/selection.tsv"
A106_VERDICT="$A106/verdict.txt"
EXPECTED_A106_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_POLICIES_SHA:-ab3aa8c577b93466b02f657113c654cd4357d4ecf0f09d458f4ebb0cf172f7c4}"
EXPECTED_A106_DESIGN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_DESIGN_SHA:-2364fc67b61764c5f4ab5232b6bc028116e84a634c169a0a157f69c2743b89ea}"
EXPECTED_A106_SOURCE_RECEIPT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_SOURCE_RECEIPT_SHA:-816b16d88adfc2fa8ea478ea3a047aaae3e675063dfdfb21204af9f37d34473d}"
EXPECTED_A106_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_DISCOVERY_PLAN_SHA:-b1b5e0b15d7fc7309f1993e986a8887ec5910bbcb18231b4794b3929d7f70221}"
EXPECTED_A106_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_VALIDATION_PLAN_SHA:-75fb4a949636787b8e37cf1ead9cb49c906256b71d5bc80dce857f726a3f38a4}"
EXPECTED_A106_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_DISCOVERY_SUMMARY_SHA:-f75bbc50e8a01296d5098f98f415bc556bdeaf60bb3328a89e310e8f5b5bdce2}"
EXPECTED_A106_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_SELECTION_SHA:-6ab08012cd7438e3e13651685a1a872fde61551909432452b903f4073612d32e}"
EXPECTED_A106_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A106_VERDICT_SHA:-46ffc17fdc85413ef607467e3eb2c6a199e56f142ffb020f65253770b1059c79}"

A107_POLICIES="$A107/policies.tsv"
A107_DESIGN="$A107/design.tsv"
A107_SOURCE_RECEIPT="$A107/source-receipt.tsv"
A107_ELIGIBILITY="$A107/eligibility.tsv"
A107_DISCOVERY_PLAN="$A107/discovery-plan.tsv"
A107_VALIDATION_PLAN="$A107/validation-plan.tsv"
A107_DISCOVERY_SUMMARY="$A107/discovery-summary.tsv"
A107_SELECTION="$A107/selection.tsv"
A107_VERDICT="$A107/verdict.txt"
EXPECTED_A107_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_POLICIES_SHA:-1fb66525a9253fb290ff9499ab2c68eb50a6c1f2a9bac04650784964839d4f03}"
EXPECTED_A107_DESIGN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_DESIGN_SHA:-df452ccf3adfd84bb25397f5fbc0fd20c6f6f89ab7e2039d1a0ca288f7fb5460}"
EXPECTED_A107_SOURCE_RECEIPT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_SOURCE_RECEIPT_SHA:-aec21cafcd86565376b88c95836e5122fd84f8b7e8429039569f41102e4bfa9e}"
EXPECTED_A107_ELIGIBILITY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_ELIGIBILITY_SHA:-1a810ef004e958962c75092b70046b8904526ecac2bfb412b0eb646bb0f25f9c}"
EXPECTED_A107_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_DISCOVERY_PLAN_SHA:-1ed6f34695340e9ec51496c00e6bd21819ab6b0bb793fa23e69370bd3dc15976}"
EXPECTED_A107_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_VALIDATION_PLAN_SHA:-b346a479df49cc428a29ba82c65b56596c9a0cd02123ab3e428c50cddea50af8}"
EXPECTED_A107_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_DISCOVERY_SUMMARY_SHA:-4e44193ed17e8ec277f13631f786b81abf14f4a3447de6a5f14c66bf63cbf59c}"
EXPECTED_A107_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_SELECTION_SHA:-17fafb230fdccc028cf28710668f5971ce43da7d97bbd67017889b44cb0fc767}"
EXPECTED_A107_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A107_VERDICT_SHA:-7d37146aa4fe3e8144e01c84656a0839b3a1c01027181c999d6b214ef23b3999}"

A108_POLICIES="$A108/policies.tsv"
A108_DESIGN="$A108/design.tsv"
A108_SOURCE_RECEIPT="$A108/source-receipt.tsv"
A108_ELIGIBILITY="$A108/eligibility.tsv"
A108_DISCOVERY_PLAN="$A108/discovery-plan.tsv"
A108_VALIDATION_PLAN="$A108/validation-plan.tsv"
A108_DISCOVERY_SUMMARY="$A108/discovery-summary.tsv"
A108_SELECTION="$A108/selection.tsv"
A108_VERDICT="$A108/verdict.txt"
EXPECTED_A108_POLICIES_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_POLICIES_SHA:-9014644c801dbe3d27922c1c1c0ea50f085718e9b6a01fe78a39c9ee44377339}"
EXPECTED_A108_DESIGN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_DESIGN_SHA:-61cf26ade69857f79bf6a02f91bb03100ccb548639ffe8368e0fc326fd365e67}"
EXPECTED_A108_SOURCE_RECEIPT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_SOURCE_RECEIPT_SHA:-f7a2ffe89804a61e2801ca7318b8740308f676630932c91f63c04c845afe374a}"
EXPECTED_A108_ELIGIBILITY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_ELIGIBILITY_SHA:-fc68b48a74ee6537ad0b4fe878942c88ba75120c566f4d1dbbe9cf59df770481}"
EXPECTED_A108_DISCOVERY_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_DISCOVERY_PLAN_SHA:-3a46d645312a84880c58cb634a2c58a2771de56da142dcc56a0d33b0ea1fe5ec}"
EXPECTED_A108_VALIDATION_PLAN_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_VALIDATION_PLAN_SHA:-b90e4ed0ec65987aab95dfa33b6b762345328fc9123b0af36503d258d928dd1d}"
EXPECTED_A108_DISCOVERY_SUMMARY_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_DISCOVERY_SUMMARY_SHA:-fbd08c0656e658be9a5b787852aa2ef35b6ed40528f4a2aaf2d435d1662d155d}"
EXPECTED_A108_SELECTION_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_SELECTION_SHA:-c5455ca10ef0d958e9edb000f6c680add59378d719c87c28f1914e6be743cf71}"
EXPECTED_A108_VERDICT_SHA="${LEO_STATE_OUTCOME_RECEIPT_A108_VERDICT_SHA:-ec9a8628b58026bcc225cadc119413e4a72383d52ea07836384f1ef8e74aefdb}"

case "$JOBS" in
    ''|*[!0-9]*|0) printf 'invalid road delayed-outcome-receipt jobs: %s\n' "$JOBS" >&2; exit 2 ;;
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

seal "$CANDIDATES" "$EXPECTED_CANDIDATES_SHA" "A.109 reservoir candidates"
seal "$WARM_CASES" "$EXPECTED_WARM_CASES_SHA" "A.109 warm cases"
seal "$WRITER_CASES" "$EXPECTED_WRITER_CASES_SHA" "A.109 writer cases"
seal "$REPORTER" "$EXPECTED_REPORTER_SHA" "A.109 reservoir reporter"
seal "$PLANNER" "$EXPECTED_PLANNER_SHA" "A.109 Williams planner"
seal "$PROSPECTIVE" "$EXPECTED_PROSPECTIVE_SHA" "A.109 prospective runner"
seal "$RESERVOIR_WRAPPER" "$EXPECTED_RESERVOIR_WRAPPER_SHA" "A.109 reservoir wrapper"
seal "$ELIGIBILITY_REPORTER" "$EXPECTED_ELIGIBILITY_REPORTER_SHA" "A.109 eligibility reporter"
seal "$RECEIPT_REPORTER" "$EXPECTED_RECEIPT_REPORTER_SHA" "A.109 receipt reporter"
seal "$RECEIPT_LIFE" "$EXPECTED_RECEIPT_LIFE_SHA" "A.109 receipt life reducer"
seal "$RECEIPT_SUMMARY" "$EXPECTED_RECEIPT_SUMMARY_SHA" "A.109 receipt summary"
seal "$RECEIPT_SELECTOR" "$EXPECTED_RECEIPT_SELECTOR_SHA" "A.109 receipt selector"
seal "$RECEIPT_VERDICT" "$EXPECTED_RECEIPT_VERDICT_SHA" "A.109 receipt verdict"
seal "$LEO_SOURCE" "$EXPECTED_LEO_SOURCE_SHA" "A.109 Leo source"
seal "$LEO_CORPUS" "$EXPECTED_LEO_CORPUS_SHA" "A.109 Leo corpus"
seal "$AML_SOURCE" "$EXPECTED_AML_SOURCE_SHA" "A.109 AML source"
seal "$AML_HEADER" "$EXPECTED_AML_HEADER_SHA" "A.109 AML header"
seal "$DIALOGUE_REPORTER" "$EXPECTED_DIALOGUE_REPORTER_SHA" "A.109 dialogue reporter"
seal "$FIXTURE_SOURCE" "$EXPECTED_FIXTURE_SOURCE_SHA" "A.109 geometry fixture"
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
seal "$A106_POLICIES" "$EXPECTED_A106_POLICIES_SHA" "A.106 policies"
seal "$A106_DESIGN" "$EXPECTED_A106_DESIGN_SHA" "A.106 design"
seal "$A106_SOURCE_RECEIPT" "$EXPECTED_A106_SOURCE_RECEIPT_SHA" "A.106 source receipt"
seal "$A106_DISCOVERY_PLAN" "$EXPECTED_A106_DISCOVERY_PLAN_SHA" "A.106 discovery plan"
seal "$A106_VALIDATION_PLAN" "$EXPECTED_A106_VALIDATION_PLAN_SHA" "A.106 validation plan"
seal "$A106_DISCOVERY_SUMMARY" "$EXPECTED_A106_DISCOVERY_SUMMARY_SHA" "A.106 discovery summary"
seal "$A106_SELECTION" "$EXPECTED_A106_SELECTION_SHA" "A.106 selection"
seal "$A106_VERDICT" "$EXPECTED_A106_VERDICT_SHA" "A.106 verdict"
seal "$A107_POLICIES" "$EXPECTED_A107_POLICIES_SHA" "A.107 policies"
seal "$A107_DESIGN" "$EXPECTED_A107_DESIGN_SHA" "A.107 design"
seal "$A107_SOURCE_RECEIPT" "$EXPECTED_A107_SOURCE_RECEIPT_SHA" "A.107 source receipt"
seal "$A107_ELIGIBILITY" "$EXPECTED_A107_ELIGIBILITY_SHA" "A.107 eligibility"
seal "$A107_DISCOVERY_PLAN" "$EXPECTED_A107_DISCOVERY_PLAN_SHA" "A.107 discovery plan"
seal "$A107_VALIDATION_PLAN" "$EXPECTED_A107_VALIDATION_PLAN_SHA" "A.107 validation plan"
seal "$A107_DISCOVERY_SUMMARY" "$EXPECTED_A107_DISCOVERY_SUMMARY_SHA" "A.107 discovery summary"
seal "$A107_SELECTION" "$EXPECTED_A107_SELECTION_SHA" "A.107 selection"
seal "$A107_VERDICT" "$EXPECTED_A107_VERDICT_SHA" "A.107 verdict"
seal "$A108_POLICIES" "$EXPECTED_A108_POLICIES_SHA" "A.108 policies"
seal "$A108_DESIGN" "$EXPECTED_A108_DESIGN_SHA" "A.108 design"
seal "$A108_SOURCE_RECEIPT" "$EXPECTED_A108_SOURCE_RECEIPT_SHA" "A.108 source receipt"
seal "$A108_ELIGIBILITY" "$EXPECTED_A108_ELIGIBILITY_SHA" "A.108 eligibility"
seal "$A108_DISCOVERY_PLAN" "$EXPECTED_A108_DISCOVERY_PLAN_SHA" "A.108 discovery plan"
seal "$A108_VALIDATION_PLAN" "$EXPECTED_A108_VALIDATION_PLAN_SHA" "A.108 validation plan"
seal "$A108_DISCOVERY_SUMMARY" "$EXPECTED_A108_DISCOVERY_SUMMARY_SHA" "A.108 discovery summary"
seal "$A108_SELECTION" "$EXPECTED_A108_SELECTION_SHA" "A.108 selection"
seal "$A108_VERDICT" "$EXPECTED_A108_VERDICT_SHA" "A.108 verdict"
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
grep -q '^result no-independent-delayed-receipt-candidate$' "$A108_VERDICT" || {
    printf 'A.108 is not the sealed signed-path negative result\n' >&2; exit 2;
}
for forbidden in selected-policy.tsv validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A108/$forbidden" ] || {
        printf 'A.108 validation was already opened: %s\n' "$A108/$forbidden" >&2
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
grep -q '^result no-episode-consequence-candidate$' "$A106_VERDICT" || {
    printf 'A.106 is not the sealed counterbalanced negative result\n' >&2; exit 2;
}
for forbidden in selected-policy.tsv validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A106/$forbidden" ] || {
        printf 'A.106 validation was already opened: %s\n' "$A106/$forbidden" >&2
        exit 2
    }
done
grep -q '^result no-delayed-receipt-candidate$' "$A107_VERDICT" || {
    printf 'A.107 is not the sealed delayed-receipt negative result\n' >&2; exit 2;
}
for forbidden in selected-policy.tsv validation-locks.tsv validation-witnesses.tsv \
    validation-scores.tsv validation-life-summary.tsv; do
    [ ! -e "$A107/$forbidden" ] || {
        printf 'A.107 validation was already opened: %s\n' "$A107/$forbidden" >&2
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
        printf 'outcome receipt reservoir source missing during aggregate-only replay: %s\n' "$RESERVOIR" >&2
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
    [ -s "$path" ] || { printf 'incomplete outcome receipt reservoir source: %s\n' "$path" >&2; exit 2; }
done
seal "$SCREEN_PLAN" "$EXPECTED_RESERVOIR_SCREEN_PLAN_SHA" "A.109 reservoir screen plan"
seal "$WARM_RECEIPTS" "$EXPECTED_RESERVOIR_WARM_RECEIPTS_SHA" "A.109 reservoir warm receipts"
seal "$ENROLLMENT" "$EXPECTED_RESERVOIR_ENROLLMENT_SHA" "A.109 reservoir enrollment"
seal "$WRITER_PLAN" "$EXPECTED_RESERVOIR_WRITER_PLAN_SHA" "A.109 reservoir writer plan"
seal "$WRITER_RECEIPTS" "$EXPECTED_RESERVOIR_WRITER_RECEIPTS_SHA" "A.109 reservoir writer receipts"
seal "$RESERVOIR_VERDICT" "$EXPECTED_RESERVOIR_VERDICT_SHA" "A.109 reservoir verdict"
grep -q '^result=balanced-reservoir-anatomy-admissible$' "$RESERVOIR_VERDICT" || {
    printf 'outcome receipt reservoir failed its own admission\n' >&2
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
    printf 'outcome receipt reservoir does not balance the scored calendar\n' >&2
    exit 2
}

DISCOVERY_PLAN="$OUT/discovery-plan.tsv"
VALIDATION_PLAN="$OUT/validation-plan.tsv"
POLICIES="$OUT/policies.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
ELIGIBILITY="$OUT/eligibility.tsv"
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
FIXTURE="$OUT/road-delayed-outcome-receipt-fixture"

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
    printf 'candidate\treceipt_strength\tsnapshot_decay\tsnapshot_strength\ttexture_strength\tprior_alpha\tvariance_ridge\trank\n'
    printf 'outcome-receipt-path-light\t0.10\t1.00\t0.25\t0.25\t1\t1\t1\n'
    printf 'outcome-receipt-path-gentle\t0.25\t1.00\t0.25\t0.25\t1\t1\t2\n'
}

write_design() {
    printf 'constraint\tvalue\n'
    printf 'calendar\tpaired-williams8\n'
    printf 'reservoir-generation\tr1-after-a108-r2\n'
    printf 'discovery-lives\t32\n'
    printf 'validation-lives\t32\n'
    printf 'lives-per-split\t16\n'
    printf 'evaluation-session\t5\n'
    printf 'target-order\t5\n'
    printf 'intervening-orders\t2-4\n'
    printf 'symmetric-control\tmidpoint+magnitude+intervening-mean\n'
    printf 'signed-path-control\torder1-to-order2+order2-to-order3+order3-to-order4\n'
    printf 'outcome-channels\tgrounded+distress-relief+gap-relief+alignment-delta\n'
    printf 'outcome-receipt\tboundary-observed-minus-preupdate-road-forecast\n'
    printf 'outcome-normalization\tgrounded-div-1+continuous-div-2\n'
    printf 'future-target\torder5-post-state\n'
    printf 'outcome-receipt-residual\tafter-signed-path-control\n'
    printf 'minimum-scored-receipts\t2\n'
    printf 'required-life-wins\t22\n'
    printf 'required-split-wins\t10\n'
    printf 'required-path-ce-gain\t0.001000000\n'
    printf 'required-path-brier-gain\t0.000250000\n'
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
    printf 'eligibility-reporter\t%s\n' "$EXPECTED_ELIGIBILITY_REPORTER_SHA"
    printf 'receipt-reporter\t%s\n' "$EXPECTED_RECEIPT_REPORTER_SHA"
    printf 'receipt-life-reducer\t%s\n' "$EXPECTED_RECEIPT_LIFE_SHA"
    printf 'receipt-summary\t%s\n' "$EXPECTED_RECEIPT_SUMMARY_SHA"
    printf 'receipt-selector\t%s\n' "$EXPECTED_RECEIPT_SELECTOR_SHA"
    printf 'receipt-verdict\t%s\n' "$EXPECTED_RECEIPT_VERDICT_SHA"
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
    printf 'a106-policies\t%s\n' "$EXPECTED_A106_POLICIES_SHA"
    printf 'a106-design\t%s\n' "$EXPECTED_A106_DESIGN_SHA"
    printf 'a106-source-receipt\t%s\n' "$EXPECTED_A106_SOURCE_RECEIPT_SHA"
    printf 'a106-discovery-plan\t%s\n' "$EXPECTED_A106_DISCOVERY_PLAN_SHA"
    printf 'a106-validation-plan\t%s\n' "$EXPECTED_A106_VALIDATION_PLAN_SHA"
    printf 'a106-discovery-summary\t%s\n' "$EXPECTED_A106_DISCOVERY_SUMMARY_SHA"
    printf 'a106-selection\t%s\n' "$EXPECTED_A106_SELECTION_SHA"
    printf 'a106-verdict\t%s\n' "$EXPECTED_A106_VERDICT_SHA"
    printf 'a107-policies\t%s\n' "$EXPECTED_A107_POLICIES_SHA"
    printf 'a107-design\t%s\n' "$EXPECTED_A107_DESIGN_SHA"
    printf 'a107-source-receipt\t%s\n' "$EXPECTED_A107_SOURCE_RECEIPT_SHA"
    printf 'a107-eligibility\t%s\n' "$EXPECTED_A107_ELIGIBILITY_SHA"
    printf 'a107-discovery-plan\t%s\n' "$EXPECTED_A107_DISCOVERY_PLAN_SHA"
    printf 'a107-validation-plan\t%s\n' "$EXPECTED_A107_VALIDATION_PLAN_SHA"
    printf 'a107-discovery-summary\t%s\n' "$EXPECTED_A107_DISCOVERY_SUMMARY_SHA"
    printf 'a107-selection\t%s\n' "$EXPECTED_A107_SELECTION_SHA"
    printf 'a107-verdict\t%s\n' "$EXPECTED_A107_VERDICT_SHA"
    printf 'a108-policies\t%s\n' "$EXPECTED_A108_POLICIES_SHA"
    printf 'a108-design\t%s\n' "$EXPECTED_A108_DESIGN_SHA"
    printf 'a108-source-receipt\t%s\n' "$EXPECTED_A108_SOURCE_RECEIPT_SHA"
    printf 'a108-eligibility\t%s\n' "$EXPECTED_A108_ELIGIBILITY_SHA"
    printf 'a108-discovery-plan\t%s\n' "$EXPECTED_A108_DISCOVERY_PLAN_SHA"
    printf 'a108-validation-plan\t%s\n' "$EXPECTED_A108_VALIDATION_PLAN_SHA"
    printf 'a108-discovery-summary\t%s\n' "$EXPECTED_A108_DISCOVERY_SUMMARY_SHA"
    printf 'a108-selection\t%s\n' "$EXPECTED_A108_SELECTION_SHA"
    printf 'a108-verdict\t%s\n' "$EXPECTED_A108_VERDICT_SHA"
}

write_eligibility() {
    awk -v life_expected=64 -f "$ELIGIBILITY_REPORTER" \
        "$ENROLLMENT" "$WRITER_RECEIPTS"
}

check_eligibility() {
    awk -F '\t' '
        NR == 1 {
            if (NF != 7 || $1 != "cohort" || $6 != "scored_receipts") exit 2
            next
        }
        {
            rows++; cohort[$1]++; split_count[$3]++
            if ($1 !~ /^(discovery|validation)$/ ||
                $3 !~ /^(primary|holdout)$/ || $6 < 2 || $6 > 4) exit 2
            if (!minimum || $6 < minimum) minimum = $6
        }
        END {
            if (rows != 64 || cohort["discovery"] != 32 ||
                cohort["validation"] != 32 || split_count["primary"] != 32 ||
                split_count["holdout"] != 32 || minimum != 2) exit 2
        }
    ' "$1"
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$DISCOVERY_PLAN" "$VALIDATION_PLAN" "$POLICIES" "$DESIGN" \
        "$SOURCE_RECEIPT" "$ELIGIBILITY" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES"; do
        [ -s "$path" ] || { printf 'incomplete delayed-outcome-receipt run: %s\n' "$path" >&2; exit 2; }
    done
    write_discovery_plan | cmp -s - "$DISCOVERY_PLAN" || { printf 'A.109 discovery plan diverged\n' >&2; exit 2; }
    write_validation_plan | cmp -s - "$VALIDATION_PLAN" || { printf 'A.109 validation plan diverged\n' >&2; exit 2; }
    write_policies | cmp -s - "$POLICIES" || { printf 'A.109 policy ledger diverged\n' >&2; exit 2; }
    write_design | cmp -s - "$DESIGN" || { printf 'A.109 design ledger diverged\n' >&2; exit 2; }
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT" || { printf 'A.109 source receipt diverged\n' >&2; exit 2; }
    write_eligibility | cmp -s - "$ELIGIBILITY" || { printf 'A.109 eligibility ledger diverged\n' >&2; exit 2; }
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/replays"
    write_discovery_plan > "$DISCOVERY_PLAN"
    write_validation_plan > "$VALIDATION_PLAN"
    write_policies > "$POLICIES"
    write_design > "$DESIGN"
    write_source_receipt > "$SOURCE_RECEIPT"
    write_eligibility > "$ELIGIBILITY"
fi
check_eligibility "$ELIGIBILITY"

if [ "${LEO_STATE_OUTCOME_RECEIPT_PLAN_ONLY:-0}" = 1 ]; then
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
                    $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31,
                    $32, $33, $34 }
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
    printf 'cohort\tlife\tsplit\tturn\tsession\torder\ttexture\tevent\tpre_turn\tpre_ids\tpost_members\ttransition\tsource\ttransition_total\twinner\treplaced\thas_prediction\texpected\texpected_probability\toverlap\tsurprise\tobserved_grounded\tobserved_distress_relief\tobserved_gap_relief\tobserved_alignment_delta\tforecast_grounded\tforecast_distress_relief\tforecast_gap_relief\tforecast_alignment_delta\tprompt\treply\n' > "$witnesses"
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
    -f "$RECEIPT_REPORTER" \
    "$POLICIES" "$DISCOVERY_LOCKS" "$DISCOVERY_WITNESSES" > "$DISCOVERY_SCORES"
awk -v policy_expected=2 -v life_expected=32 -v min_receipts=2 \
    -f "$RECEIPT_LIFE" \
    "$DISCOVERY_SCORES" > "$DISCOVERY_LIFE"
awk -v policy_expected=2 -v discovery_expected=32 -v validation_expected=32 \
    -f "$RECEIPT_SUMMARY" \
    "$DISCOVERY_LIFE" > "$DISCOVERY_SUMMARY"
awk -v policy_expected=2 -v expected=32 -v life_win_required=22 -v split_win_required=10 \
    -f "$RECEIPT_SELECTOR" \
    "$DISCOVERY_SUMMARY" > "$SELECTION"

selected="$(awk -F '\t' 'NR == 2 { print $1 }' "$SELECTION")"
[ -n "$selected" ] || { printf 'A.109 selection is empty\n' >&2; exit 2; }

if [ "$selected" != none ]; then
    { sed -n '1p' "$POLICIES"; awk -F '\t' -v selected="$selected" '$1 == selected' "$POLICIES"; } \
        > "$SELECTED_POLICY"
    [ "$(wc -l < "$SELECTED_POLICY" | tr -d ' ')" -eq 2 ] || {
        printf 'selected delayed-outcome-receipt policy is not unique\n' >&2; exit 2;
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
        -f "$RECEIPT_REPORTER" \
        "$SELECTED_POLICY" "$VALIDATION_LOCKS" "$VALIDATION_WITNESSES" > "$VALIDATION_SCORES"
    awk -v policy_expected=1 -v life_expected=32 -v min_receipts=2 \
        -f "$RECEIPT_LIFE" \
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
    -f "$RECEIPT_SUMMARY" \
    "$LIFE_SUMMARY" > "$CANDIDATE_SUMMARY"
awk -v expected=32 -v life_win_required=22 -v split_win_required=10 \
    -f "$RECEIPT_VERDICT" \
    "$SELECTION" "$CANDIDATE_SUMMARY" > "$VERDICT"

cat "$CANDIDATE_SUMMARY"; printf '\n'; cat "$SELECTION"; printf '\n'; cat "$VERDICT"
printf '\nreservoir-source: %s\nrun: %s\n' "$RESERVOIR" "$OUT"
