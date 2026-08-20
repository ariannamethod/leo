#!/usr/bin/env bash
# A.115: admit the confirmed A.113/A.114 road law as the reversible default.
set -Eeuo pipefail

trap 'rc=$?; printf "relational-transition default runner failed: line=%s rc=%s command=%s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${CC:-cc}"
SOURCE="${LEO_STATE_RELATIONAL_DEFAULT_SOURCE:-/private/tmp/leo-state-swarm-susceptibility-reservoir-a110-r2-20260816}"
A113="${LEO_STATE_RELATIONAL_DEFAULT_A113:-/private/tmp/leo-state-swarm-relational-transition-a113-r1-20260818}"
A114="${LEO_STATE_RELATIONAL_DEFAULT_A114:-/private/tmp/leo-state-swarm-relational-transition-runtime-a114-r1-20260820}"
AGGREGATE_ONLY="${LEO_STATE_RELATIONAL_DEFAULT_AGGREGATE_ONLY:-0}"
JOBS="${LEO_STATE_RELATIONAL_DEFAULT_JOBS:-4}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-relational-transition-default-$STAMP}"

A113_VERDICT="$A113/verdict.txt"
A114_PLAN="$A114/runtime-plan.tsv"
A114_DESIGN="$A114/design.tsv"
A114_SOURCE_RECEIPT="$A114/source-receipt.tsv"
A114_RAW="$A114/runtime-raw.tsv"
A114_VERDICT="$A114/verdict.txt"
FIXTURE_SOURCE="$ROOT/tests/state_swarm_relational_transition_runtime_fixture.c"
REPORTER="$ROOT/scripts/state_swarm_relational_transition_default_verdict.awk"
PLAN="$OUT/admission-plan.tsv"
DESIGN="$OUT/design.tsv"
SOURCE_RECEIPT="$OUT/source-receipt.tsv"
RAW="$OUT/admission-raw.tsv"
VERDICT="$OUT/verdict.txt"
FIXTURE="$OUT/state-swarm-relational-transition-default-fixture"

EXPECTED_A113_VERDICT_SHA=bf77884723d4abd760e84fa8819749ea9692de8259877dc4aa8ffa977c0432d5
EXPECTED_A114_PLAN_SHA=6328b592d636a6fe4924b69f8756f98925c2d1147027f6a5d63a4fb2910a27f3
EXPECTED_A114_DESIGN_SHA=facb12da7de4719053cd2afa9db42062efab760364fe71841a139c7caa63246d
EXPECTED_A114_SOURCE_RECEIPT_SHA=c35df9a6dbfbc1a8b5b4f1e7a53817a35573cc01d453a818a444b0f7987ddaa2
EXPECTED_A114_RAW_SHA=d0c5a5e8a1c5a7e063807164ca3045705d7075de2301277a984658526a565a40
EXPECTED_A114_VERDICT_SHA=e1c6d24a9e16434928622c235aad9285a2501f30b3629adf32f18238bfd3f3f9

case "$JOBS" in ''|*[!0-9]*) printf 'invalid jobs: %s\n' "$JOBS" >&2; exit 2;; esac
[ "$JOBS" -ge 1 ] || { printf 'jobs must be positive\n' >&2; exit 2; }

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

seal "$A113_VERDICT" "$EXPECTED_A113_VERDICT_SHA" "A.113 confirmation"
seal "$A114_PLAN" "$EXPECTED_A114_PLAN_SHA" "A.114 runtime plan"
seal "$A114_DESIGN" "$EXPECTED_A114_DESIGN_SHA" "A.114 design"
seal "$A114_SOURCE_RECEIPT" "$EXPECTED_A114_SOURCE_RECEIPT_SHA" "A.114 source receipt"
seal "$A114_RAW" "$EXPECTED_A114_RAW_SHA" "A.114 runtime receipt"
seal "$A114_VERDICT" "$EXPECTED_A114_VERDICT_SHA" "A.114 exact-runtime verdict"
grep -q '^result[[:space:]]relational-transition-redistribution-confirmed$' "$A113_VERDICT"
grep -q '^result[[:space:]]relational-transition-runtime-exact$' "$A114_VERDICT"

write_plan() {
    awk -F '\t' -v OFS='\t' '
        NR == 1 { print; next }
        { print; rows++; life[$1]++ }
        END {
            if (rows != 528 || length(life) != 11) exit 2
            for (name in life) if (life[name] != 48) exit 2
        }
    ' "$A114_PLAN"
}

write_design() {
    printf 'field\tvalue\n'
    printf 'decision\trelational-transition-default-admission\n'
    printf 'efficacy_authority\tA.113 sealed independent confirmation\n'
    printf 'embodiment_authority\tA.114 exact runtime proof\n'
    printf 'new_efficacy_claim\tnone; sealed lives are not re-voted\n'
    printf 'default_arm\tordinary invocation\n'
    printf 'identity_arm\t--state-relational-transition\n'
    printf 'historical_control\t--no-state-relational-transition\n'
    printf 'prototype_plasticity\texplicitly off in every arm\n'
    printf 'runtime_lives\t11 (5 primary + 6 holdout)\n'
    printf 'runtime_turns_per_life\t48\n'
    printf 'default_reference\tindependent exact A.113 float replay\n'
    printf 'control_reference\tindependent exact historical A.79 replay\n'
    printf 'default_identity\tcomplete state and reply cmp after every turn\n'
    printf 'ablation_boundary\tall saved bytes except transition must match\n'
    printf 'voice_boundary\tall three replies must match after every turn\n'
}

write_source_receipt() {
    printf 'life\tsplit\tcandidate_order\tstate_sha\n'
    awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 "\t" $4 }' \
        "$PLAN" | while IFS=$'\t' read -r life split candidate_order; do
        local body="$SOURCE/candidates/$life/leo.state"
        [ -s "$body" ] || { printf 'missing source body: %s\n' "$body" >&2; exit 2; }
        printf '%s\t%s\t%s\t%s\n' "$life" "$split" "$candidate_order" \
            "$(sha256_file "$body")"
    done
}

reply_from_log() {
    awk '/leo> / { sub(/^.*leo> /, ""); gsub(/\t/, "\\t"); print; exit }' "$1"
}

run_life() {
    local life="$1" split="$2"
    local life_dir="$OUT/replays/$split-$life"
    local source_body="$SOURCE/candidates/$life/leo.state"
    local ordinary="$life_dir/default.state"
    local explicit_on="$life_dir/on.state"
    local explicit_off="$life_dir/off.state"
    local raw="$life_dir/raw.tsv"
    mkdir -p "$life_dir/default" "$life_dir/on" "$life_dir/off"
    cp "$source_body" "$ordinary"
    cp "$source_body" "$explicit_on"
    cp "$source_body" "$explicit_off"
    : > "$raw"

    while IFS=$'\t' read -r plan_life plan_split base_seed candidate_order \
            rotation session order source_order texture run_seed prompt; do
        [ "$plan_life" = life ] && continue
        local stem="s${session}-$(printf '%02d' "$order")-${texture}"
        local default_before="$life_dir/default/$stem.before.state"
        local off_before="$life_dir/off/$stem.before.state"
        local default_log="$life_dir/default/$stem.log"
        local on_log="$life_dir/on/$stem.log"
        local off_log="$life_dir/off/$stem.log"
        cp "$ordinary" "$default_before"
        cp "$explicit_off" "$off_before"

        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$ordinary" \
            --seed "$run_seed" --respond "$prompt" --save "$ordinary" \
            --no-state-transition-plasticity > "$default_log" 2>&1
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$explicit_on" \
            --seed "$run_seed" --respond "$prompt" --save "$explicit_on" \
            --state-relational-transition --no-state-transition-plasticity \
            > "$on_log" 2>&1
        "$ROOT/leo" --corpus "$ROOT/leo.txt" --load "$explicit_off" \
            --seed "$run_seed" --respond "$prompt" --save "$explicit_off" \
            --no-state-relational-transition --no-state-transition-plasticity \
            > "$off_log" 2>&1

        local default_result default_reference overlap semantic_share default_changed
        local legacy_result legacy_reference ignored1 ignored2 ignored3
        default_result="$("$FIXTURE" reference "$default_before" "$ordinary")"
        legacy_result="$("$FIXTURE" legacy-reference "$off_before" "$explicit_off")"
        IFS=$'\t' read -r default_reference overlap semantic_share default_changed \
            <<< "$default_result"
        IFS=$'\t' read -r legacy_reference ignored1 ignored2 ignored3 \
            <<< "$legacy_result"
        [ "$default_reference" = exact ] || [ "$default_reference" = censored ]
        [ "$legacy_reference" = exact ] || [ "$legacy_reference" = censored ]

        local default_on_exact=0 transition_only=0 default_off_different=0
        cmp -s "$ordinary" "$explicit_on" && default_on_exact=1
        [ "$("$FIXTURE" transition-only "$ordinary" "$explicit_off")" = \
            transition-only ] && transition_only=1
        if ! cmp -s "$ordinary" "$explicit_off"; then default_off_different=1; fi

        local default_reply on_reply off_reply same_reply=0
        default_reply="$(reply_from_log "$default_log")"
        on_reply="$(reply_from_log "$on_log")"
        off_reply="$(reply_from_log "$off_log")"
        [ -n "$default_reply" ] && [ "$default_reply" = "$on_reply" ] && \
            [ "$default_reply" = "$off_reply" ] && same_reply=1

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$life" "$split" "$session" "$order" "$texture" \
            "$default_reference" "$legacy_reference" "$overlap" \
            "$semantic_share" "$default_changed" "$default_on_exact" \
            "$transition_only" "$default_off_different" "$same_reply" >> "$raw"
    done < <(awk -F '\t' -v life="$life" 'NR == 1 || $1 == life' "$PLAN")
    [ "$(wc -l < "$raw" | tr -d ' ')" -eq 48 ]
}

replay() {
    local running=0
    local -a pids=()
    while IFS=$'\t' read -r life split; do
        run_life "$life" "$split" &
        pids+=("$!")
        running=$((running + 1))
        if [ "$running" -ge "$JOBS" ]; then
            for pid in "${pids[@]}"; do wait "$pid"; done
            pids=()
            running=0
        fi
    done < <(awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 }' "$PLAN")
    if [ "$running" -gt 0 ]; then
        for pid in "${pids[@]}"; do wait "$pid"; done
    fi

    printf 'life\tsplit\tsession\torder\ttexture\tdefault_reference\tlegacy_reference\toverlap\tsemantic_share\tdefault_changed\tdefault_on_exact\ttransition_only\tdefault_off_different\tsame_reply\n' > "$RAW"
    while IFS=$'\t' read -r life split; do
        cat "$OUT/replays/$split-$life/raw.tsv" >> "$RAW"
    done < <(awk -F '\t' 'NR > 1 && !seen[$1]++ { print $1 "\t" $2 }' "$PLAN")
}

if [ "$AGGREGATE_ONLY" = 1 ]; then
    for path in "$PLAN" "$DESIGN" "$SOURCE_RECEIPT" "$RAW"; do
        [ -s "$path" ] || { printf 'incomplete A.115 aggregate source: %s\n' "$path" >&2; exit 2; }
    done
    write_plan | cmp -s - "$PLAN"
    write_design | cmp -s - "$DESIGN"
    write_source_receipt | cmp -s - "$SOURCE_RECEIPT"
else
    [ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
    mkdir -p "$OUT/replays"
    write_plan > "$PLAN"
    write_design > "$DESIGN"
    write_source_receipt > "$SOURCE_RECEIPT"
    cmp -s "$SOURCE_RECEIPT" "$A114_SOURCE_RECEIPT"
    make -C "$ROOT" leo >/dev/null
    "$CC" "$FIXTURE_SOURCE" -O2 -lm -Wall -Wextra -Wno-unused-function \
        -o "$FIXTURE" -lpthread
    replay
fi

awk -f "$REPORTER" "$RAW" > "$VERDICT"
cat "$VERDICT"
