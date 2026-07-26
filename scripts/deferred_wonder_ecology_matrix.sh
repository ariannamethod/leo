#!/usr/bin/env bash
# A.39: matched lived trajectories between a withheld question and its return.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${LEO_ECOLOGY_CASES:-$ROOT/scripts/deferred_wonder_ecology_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-ecology-$STAMP}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
[ -f "$CASES" ] || {
    printf 'ecology cases not found: %s\n' "$CASES" >&2
    exit 2
}

awk -F '\t' '
    NR == 1 {
        if (NF != 4 || $1 != "trajectory" || $2 != "expected_primary" ||
            $3 != "order" || $4 != "prompt")
            exit 1
        next
    }
    {
        if (NF != 4 || ($2 != "asked-deferred" &&
                       $2 != "blocked-deferred") ||
            $3 !~ /^[0-9]+$/)
            exit 1
        if (($3 == 0) != ($4 == "-"))
            exit 1
        if (($1 in expectation) && expectation[$1] != $2)
            exit 1
        expectation[$1] = $2
        rows[$1]++
        orders[$1 SUBSEP $3]++
    }
    END {
        if (NR < 2 || length(expectation) != 5)
            exit 1
        if (rows["no-life"] != 1 || orders["no-life" SUBSEP 0] != 1)
            exit 1
        for (trajectory in expectation) {
            if (trajectory == "no-life")
                continue
            if (rows[trajectory] != 8)
                exit 1
            for (i = 1; i <= 8; i++)
                if (orders[trajectory SUBSEP i] != 1)
                    exit 1
        }
        if (expectation["no-life"] != "blocked-deferred" ||
            expectation["repeated-safe"] != "asked-deferred" ||
            expectation["varied-safe"] != "asked-deferred" ||
            expectation["mundane"] != "asked-deferred" ||
            expectation["sustained-danger"] != "blocked-deferred")
            exit 1
    }
' "$CASES" || {
    printf 'invalid ecology case design: %s\n' "$CASES" >&2
    exit 2
}

mkdir -p "$OUT/births" "$OUT/lives"
TARGETS="$OUT/targets.tsv"
TRAJECTORIES="$OUT/trajectories.tsv"
PLAN="$OUT/plan.tsv"
BIRTHS="$OUT/births.tsv"
MATRIX="$OUT/matrix.tsv"
RECEIPTS="$OUT/receipts.tsv"
SUMMARY="$OUT/summary.txt"

printf 'cohort\ttarget\tseed\n' > "$TARGETS"
cat >> "$TARGETS" <<'EOF'
replication	suvin	83
replication	nareth	137
replication	flom	211
confirmatory	zavin	307
confirmatory	mireth	401
confirmatory	pelun	509
EOF

printf 'trajectory\texpected_primary\tlife_turns\n' > "$TRAJECTORIES"
awk -F '\t' '
    NR > 1 {
        expectation[$1] = $2
        if ($3 > 0) turns[$1]++
    }
    END {
        for (trajectory in expectation)
            printf "%s\t%s\t%d\n", trajectory, expectation[trajectory],
                   turns[trajectory] + 0
    }
' "$CASES" | sort >> "$TRAJECTORIES"

printf 'cell\tcohort\ttarget\tseed\ttrajectory\texpected_primary\tlife_turns\n' \
    > "$PLAN"
tail -n +2 "$TARGETS" |
while IFS=$'\t' read -r cohort target seed; do
    if grep -Eiq "(^|[^[:alpha:]])${target}([^[:alpha:]]|$)" "$CASES"; then
        printf 'target %s leaks into ecology stimuli\n' "$target" >&2
        exit 2
    fi
    tail -n +2 "$TRAJECTORIES" |
    while IFS=$'\t' read -r trajectory expected life_turns; do
        printf '%s-%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$target" "$trajectory" "$cohort" "$target" "$seed" \
            "$trajectory" "$expected" "$life_turns" >> "$PLAN"
    done
done

if [ "${LEO_ECOLOGY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'cohort\ttarget\tseed\toutcome\tcandidate\tdistress\tgate\treply\tstate\n' \
    > "$BIRTHS"
printf 'cell\tphase\tturn\toutcome\tcandidate\tdeferred\tdeferred_heard\tdistress\tgate\tprompt\treply\n' \
    > "$RECEIPTS"
printf 'cell\tcohort\ttarget\tseed\ttrajectory\texpected_primary\tlife_turns\tprimary_turn\tprimary_outcome\tprimary_candidate\tprimary_distress\tprimary_gate\tprimary_matches_expectation\trescue_turns\trescue_turn\trescue_outcome\trescue_candidate\trescue_distress\trescue_gate\ttarget_recoverable\ttranscript_sha256\toutput\n' \
    > "$MATRIX"

reply_from_log() {
    awk '
        /leo> / {
            sub(/^.*leo> /, "")
            print
            exit
        }
    ' "$1"
}

receipt_from_log() {
    awk -v scenario="$2" -v seed="$3" \
        -f "$ROOT/scripts/curiosity_dialogue_report.awk" "$1"
}

append_receipt() {
    local cell="$1"
    local phase="$2"
    local prompt="$3"
    local reply="$4"
    local receipt="$5"
    local receipt_turn outcome candidate deferred deferred_heard distress gate
    IFS=$'\t' read -r _ _ receipt_turn outcome candidate deferred \
        deferred_heard distress gate <<< "$receipt"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$phase" "$receipt_turn" "$outcome" "$candidate" \
        "$deferred" "$deferred_heard" "$distress" "$gate" "$prompt" \
        "$reply" >> "$RECEIPTS"
}

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

tail -n +2 "$TARGETS" |
while IFS=$'\t' read -r cohort target seed; do
    birth_dir="$OUT/births/$target"
    mkdir -p "$birth_dir"
    birth_prompt="Does $target feel like bright sun or cold winter?"
    birth_log="$birth_dir/raw.log"
    birth_state="$birth_dir/base.state"
    "$ROOT/leo" --seed "$seed" --respond "$birth_prompt" --debug-field \
        --save "$birth_state" > "$birth_log" 2>&1
    receipt="$(receipt_from_log "$birth_log" "birth-$target" "$seed")"
    [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
        printf 'birth %s did not emit exactly one curiosity receipt\n' \
            "$target" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ _ outcome candidate _ _ distress gate \
        <<< "$receipt"
    [ "$outcome" = blocked-distress ] && [ "$candidate" = "$target" ] || {
        printf 'birth %s was not distress-deferred: %s / %s\n' \
            "$target" "$outcome" "$candidate" >&2
        exit 1
    }
    reply="$(reply_from_log "$birth_log")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cohort" "$target" "$seed" "$outcome" "$candidate" "$distress" \
        "$gate" "$reply" "$birth_state" >> "$BIRTHS"
done

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r cell cohort target seed trajectory expected life_turns; do
    life="$OUT/lives/$cell"
    mkdir -p "$life/turns"
    state="$life/leo.state"
    transcript="$life/transcript.tsv"
    cp "$OUT/births/$target/base.state" "$state"
    printf 'role\tturn\ttext\n' > "$transcript"
    birth_prompt="Does $target feel like bright sun or cold winter?"
    birth_reply="$(awk -F '\t' -v t="$target" \
        'NR > 1 && $2 == t { print $8 }' "$BIRTHS")"
    printf 'human\t1\t%s\nleo\t1\t%s\n' \
        "$birth_prompt" "$birth_reply" >> "$transcript"

    turn=1
    if [ "$life_turns" -gt 0 ]; then
        while IFS=$'\t' read -r order prompt; do
            turn=$((turn + 1))
            [ "$order" -eq "$((turn - 1))" ] || {
                printf '%s has non-contiguous life order at %s\n' \
                    "$cell" "$order" >&2
                exit 1
            }
            log="$life/turns/turn-$(printf '%02d' "$turn")-life.log"
            "$ROOT/leo" --load "$state" --seed "$((seed + turn))" \
                --respond "$prompt" --debug-field --save "$state" \
                > "$log" 2>&1
            receipt="$(receipt_from_log "$log" "$cell-life" "$seed")"
            [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
                printf '%s life turn %d lacks one receipt\n' \
                    "$cell" "$turn" >&2
                exit 1
            }
            IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$receipt"
            [ "$outcome" = no-candidate ] && [ "$candidate" = none ] || {
                printf '%s life turn %d opened or changed a question: %s / %s\n' \
                    "$cell" "$turn" "$outcome" "$candidate" >&2
                exit 1
            }
            reply="$(reply_from_log "$log")"
            printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
                "$turn" "$prompt" "$turn" "$reply" >> "$transcript"
            append_receipt "$cell" life "$prompt" "$reply" "$receipt"
        done < <(awk -F '\t' -v trajectory="$trajectory" \
            'NR > 1 && $1 == trajectory && $3 > 0 {
                print $3 "\t" $4
            }' "$CASES" | sort -t $'\t' -k1,1n)
    fi

    turn=$((turn + 1))
    primary_prompt="Does $target feel like bright sun or cold winter?"
    primary_log="$life/turns/turn-$(printf '%02d' "$turn")-primary.log"
    "$ROOT/leo" --load "$state" --seed "$((seed + 100 + turn))" \
        --respond "$primary_prompt" --debug-field --save "$state" \
        > "$primary_log" 2>&1
    receipt="$(receipt_from_log "$primary_log" "$cell-primary" "$seed")"
    [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
        printf '%s primary return lacks one receipt\n' "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ primary_turn primary_outcome primary_candidate \
        _ _ primary_distress primary_gate <<< "$receipt"
    primary_reply="$(reply_from_log "$primary_log")"
    printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
        "$turn" "$primary_prompt" "$turn" "$primary_reply" >> "$transcript"
    append_receipt "$cell" primary "$primary_prompt" "$primary_reply" "$receipt"

    primary_matches=false
    if [ "$primary_outcome" = "$expected" ] &&
       [ "$primary_candidate" = "$target" ]; then
        primary_matches=true
    fi
    [ "$primary_matches" = true ] || {
        printf '%s contradicted predeclared primary outcome: expected %s, got %s / %s\n' \
            "$cell" "$expected" "$primary_outcome" "$primary_candidate" >&2
        exit 1
    }

    rescue_turns=0
    rescue_turn=0
    rescue_outcome=none
    rescue_candidate=none
    rescue_distress=0
    rescue_gate=0
    target_recoverable=false
    if [ "$primary_outcome" = asked-deferred ]; then
        target_recoverable=true
    else
        while IFS=$'\t' read -r order prompt; do
            turn=$((turn + 1))
            log="$life/turns/turn-$(printf '%02d' "$turn")-rescue.log"
            "$ROOT/leo" --load "$state" --seed "$((seed + 200 + turn))" \
                --respond "$prompt" --debug-field --save "$state" \
                > "$log" 2>&1
            receipt="$(receipt_from_log "$log" "$cell-rescue" "$seed")"
            IFS=$'\t' read -r _ _ _ outcome candidate _ _ _ _ <<< "$receipt"
            [ "$outcome" = no-candidate ] && [ "$candidate" = none ] || {
                printf '%s rescue turn %d opened or changed a question: %s / %s\n' \
                    "$cell" "$turn" "$outcome" "$candidate" >&2
                exit 1
            }
            reply="$(reply_from_log "$log")"
            printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
                "$turn" "$prompt" "$turn" "$reply" >> "$transcript"
            append_receipt "$cell" rescue "$prompt" "$reply" "$receipt"
            rescue_turns=$((rescue_turns + 1))
        done < <(awk -F '\t' '
            NR > 1 && $1 == "varied-safe" && $3 > 0 {
                print $3 "\t" $4
            }
        ' "$CASES" | sort -t $'\t' -k1,1n)

        turn=$((turn + 1))
        rescue_log="$life/turns/turn-$(printf '%02d' "$turn")-rescue-return.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + 300 + turn))" \
            --respond "$primary_prompt" --debug-field --save "$state" \
            > "$rescue_log" 2>&1
        receipt="$(receipt_from_log "$rescue_log" "$cell-rescue-return" "$seed")"
        IFS=$'\t' read -r _ _ rescue_turn rescue_outcome rescue_candidate \
            _ _ rescue_distress rescue_gate <<< "$receipt"
        rescue_reply="$(reply_from_log "$rescue_log")"
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$primary_prompt" "$turn" "$rescue_reply" >> "$transcript"
        append_receipt "$cell" rescue-return "$primary_prompt" \
            "$rescue_reply" "$receipt"
        if [ "$rescue_outcome" = asked-deferred ] &&
           [ "$rescue_candidate" = "$target" ]; then
            target_recoverable=true
        fi
    fi

    [ "$target_recoverable" = true ] || {
        printf '%s lost the withheld question after its trajectory\n' \
            "$cell" >&2
        exit 1
    }
    transcript_sha="$(sha256_file "$transcript")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$cohort" "$target" "$seed" "$trajectory" "$expected" \
        "$life_turns" "$primary_turn" "$primary_outcome" "$primary_candidate" \
        "$primary_distress" "$primary_gate" "$primary_matches" "$rescue_turns" \
        "$rescue_turn" "$rescue_outcome" "$rescue_candidate" \
        "$rescue_distress" "$rescue_gate" "$target_recoverable" \
        "$transcript_sha" "$life" >> "$MATRIX"
done

expected_cells="$(( $(($(wc -l < "$TARGETS") - 1)) * \
    $(($(wc -l < "$TRAJECTORIES") - 1)) ))"
actual_cells="$(( $(wc -l < "$MATRIX") - 1 ))"
[ "$actual_cells" -eq "$expected_cells" ] || {
    printf 'matrix has %d of %d expected cells\n' \
        "$actual_cells" "$expected_cells" >&2
    exit 1
}

printf 'trajectory\tcells\tasked_deferred\tblocked_deferred\tmean_distress\tmean_gate\tmatches\trecoverable\n' \
    > "$SUMMARY"
awk -F '\t' '
    NR > 1 {
        key = $5
        cells[key]++
        outcomes[key SUBSEP $9]++
        distress[key] += $11
        gate[key] += $12
        if ($13 == "true") matches[key]++
        if ($20 == "true") recoverable[key]++
    }
    END {
        for (key in cells)
            printf "%s\t%d\t%d\t%d\t%.3f\t%.3f\t%d\t%d\n",
                   key, cells[key],
                   outcomes[key SUBSEP "asked-deferred"] + 0,
                   outcomes[key SUBSEP "blocked-deferred"] + 0,
                   distress[key] / cells[key], gate[key] / cells[key],
                   matches[key] + 0, recoverable[key] + 0
    }
' "$MATRIX" | sort >> "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nreceipts: %s\n' "$MATRIX" "$RECEIPTS"
