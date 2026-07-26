#!/usr/bin/env bash
# A.38: matched recovery lives for one distress-deferred question.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-recovery-$STAMP}"
CALM_SPEC="${LEO_RECOVERY_CALM_TURNS:-0 2 8}"
CALM_PROMPT="${LEO_RECOVERY_CALM_PROMPT:-Mother holds Leo in warm morning light.}"
FOLLOWUP_CALM="${LEO_RECOVERY_FOLLOWUP_CALM:-8}"

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}

read -r -a calm_turns <<< "$CALM_SPEC"
[ "${#calm_turns[@]}" -gt 0 ] || {
    printf 'LEO_RECOVERY_CALM_TURNS must not be empty\n' >&2
    exit 2
}
for calm in "${calm_turns[@]}"; do
    case "$calm" in
        ''|*[!0-9]*) printf 'invalid calm-turn count: %s\n' "$calm" >&2; exit 2 ;;
    esac
done
case "$FOLLOWUP_CALM" in
    ''|*[!0-9]*) printf 'invalid follow-up calm count: %s\n' "$FOLLOWUP_CALM" >&2; exit 2 ;;
esac

mkdir -p "$OUT/births" "$OUT/lives"
PLAN="$OUT/plan.tsv"
MATRIX="$OUT/matrix.tsv"
BIRTHS="$OUT/births.tsv"
ORDINARY="$OUT/ordinary_replies.tsv"
SUMMARY="$OUT/summary.txt"

printf 'cell\ttarget\tseed\tdistractor\tcalm_turns\tcue_kind\tcue_prompt\n' > "$PLAN"
while IFS=$'\t' read -r target seed distractor; do
    [ -n "$target" ] || continue
    for calm in "${calm_turns[@]}"; do
        for cue in bare safe danger known-control novel-control; do
            case "$cue" in
                bare) prompt="$target" ;;
                safe) prompt="Does $target feel like warm mother or morning light?" ;;
                danger) prompt="Does $target feel like bright sun or cold winter?" ;;
                known-control) prompt="A small room is quiet." ;;
                novel-control) prompt="$distractor" ;;
            esac
            cell="$target-calm${calm}-${cue}"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$cell" "$target" "$seed" "$distractor" "$calm" "$cue" \
                "$prompt" >> "$PLAN"
        done
    done
done <<'EOF'
suvin	83	nareth
nareth	137	flom
flom	211	suvin
EOF

if [ "${LEO_RECOVERY_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

make -C "$ROOT" leo >/dev/null

printf 'target\tseed\tturn\toutcome\tcandidate\tdistress\tgate\treply\tstate\n' > "$BIRTHS"
printf 'cell\tphase\tturn\treply\n' > "$ORDINARY"
printf 'cell\ttarget\tseed\tdistractor\tcalm_turns\tcue_kind\tprimary_turn\tprimary_outcome\tprimary_candidate\tprimary_distress\tprimary_gate\tprimary_target_asked\tprimary_reply\tfollowup_calm_turns\tfollowup_turn\tfollowup_outcome\tfollowup_candidate\tfollowup_distress\tfollowup_gate\ttarget_recovered\ttranscript_sha256\toutput\n' > "$MATRIX"

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

sha256_file() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

# One canonical frightened birth per target. Every matrix cell forks this exact
# body, so recovery differences cannot come from a different first reply.
while IFS=$'\t' read -r target seed distractor; do
    [ -n "$target" ] || continue
    birth_dir="$OUT/births/$target"
    mkdir -p "$birth_dir"
    birth_prompt="Does $target feel like bright sun or cold winter?"
    birth_log="$birth_dir/raw.log"
    birth_state="$birth_dir/base.state"
    "$ROOT/leo" --seed "$seed" --respond "$birth_prompt" --debug-field \
        --save "$birth_state" > "$birth_log" 2>&1
    receipt="$(receipt_from_log "$birth_log" "birth-$target" "$seed")"
    [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
        printf 'birth %s did not emit exactly one curiosity receipt\n' "$target" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ turn outcome candidate _ _ distress gate <<< "$receipt"
    [ "$outcome" = blocked-distress ] && [ "$candidate" = "$target" ] || {
        printf 'birth %s was not distress-deferred: %s / %s\n' \
            "$target" "$outcome" "$candidate" >&2
        exit 1
    }
    birth_reply="$(reply_from_log "$birth_log")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$target" "$seed" "$turn" "$outcome" "$candidate" "$distress" \
        "$gate" "$birth_reply" "$birth_state" >> "$BIRTHS"
done <<'EOF'
suvin	83	nareth
nareth	137	flom
flom	211	suvin
EOF

tail -n +2 "$PLAN" |
while IFS=$'\t' read -r cell target seed distractor calm cue cue_prompt; do
    life="$OUT/lives/$cell"
    mkdir -p "$life/turns"
    state="$life/leo.state"
    transcript="$life/transcript.tsv"
    cp "$OUT/births/$target/base.state" "$state"
    printf 'role\tturn\ttext\n' > "$transcript"
    birth_prompt="Does $target feel like bright sun or cold winter?"
    birth_reply="$(awk -F '\t' -v t="$target" '$1 == t { print $8 }' "$BIRTHS")"
    printf 'human\t1\t%s\nleo\t1\t%s\n' \
        "$birth_prompt" "$birth_reply" >> "$transcript"

    turn=1
    i=0
    while [ "$i" -lt "$calm" ]; do
        turn=$((turn + 1))
        log="$life/turns/turn-$(printf '%02d' "$turn")-calm.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + turn))" \
            --respond "$CALM_PROMPT" --debug-field --save "$state" \
            > "$log" 2>&1
        receipt="$(receipt_from_log "$log" "$cell-calm" "$seed")"
        [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
            printf '%s calm turn %d lacks one receipt\n' "$cell" "$turn" >&2
            exit 1
        }
        IFS=$'\t' read -r _ _ _ calm_outcome calm_candidate _ _ _ _ <<< "$receipt"
        case "$calm_outcome" in
            asked|asked-deferred|reasked)
                printf '%s calm turn %d opened %s (%s)\n' \
                    "$cell" "$turn" "$calm_candidate" "$calm_outcome" >&2
                exit 1
                ;;
        esac
        reply="$(reply_from_log "$log")"
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$CALM_PROMPT" "$turn" "$reply" >> "$transcript"
        printf '%s\tcalm\t%s\t%s\n' "$cell" "$turn" "$reply" >> "$ORDINARY"
        i=$((i + 1))
    done

    turn=$((turn + 1))
    primary_log="$life/turns/turn-$(printf '%02d' "$turn")-primary.log"
    "$ROOT/leo" --load "$state" --seed "$((seed + 100 + turn))" \
        --respond "$cue_prompt" --debug-field --save "$state" \
        > "$primary_log" 2>&1
    receipt="$(receipt_from_log "$primary_log" "$cell-primary" "$seed")"
    [ "$(printf '%s\n' "$receipt" | wc -l | tr -d ' ')" -eq 1 ] || {
        printf '%s primary cue lacks one receipt\n' "$cell" >&2
        exit 1
    }
    IFS=$'\t' read -r _ _ primary_turn primary_outcome primary_candidate \
        _ _ primary_distress primary_gate <<< "$receipt"
    primary_reply="$(reply_from_log "$primary_log")"
    printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
        "$turn" "$cue_prompt" "$turn" "$primary_reply" >> "$transcript"
    primary_target_asked=false
    if [ "$primary_outcome" = asked-deferred ] &&
       [ "$primary_candidate" = "$target" ]; then
        primary_target_asked=true
    fi

    case "$cue" in
        bare|safe)
            [ "$primary_target_asked" = true ] || {
                printf '%s failed to recover target on %s cue\n' "$cell" "$cue" >&2
                exit 1
            }
            ;;
        danger)
            case "$primary_outcome:$primary_candidate" in
                "asked-deferred:$target"|"blocked-deferred:$target") ;;
                *) printf '%s lost target under dangerous cue: %s / %s\n' \
                       "$cell" "$primary_outcome" "$primary_candidate" >&2; exit 1 ;;
            esac
            ;;
        known-control)
            [ "$primary_target_asked" = false ] || {
                printf '%s known control released target\n' "$cell" >&2
                exit 1
            }
            ;;
        novel-control)
            [ "$primary_outcome" = asked ] &&
            [ "$primary_candidate" = "$distractor" ] || {
                printf '%s novel control did not ask only distractor: %s / %s\n' \
                    "$cell" "$primary_outcome" "$primary_candidate" >&2
                exit 1
            }
            ;;
    esac
    case "$primary_outcome" in
        asked|asked-deferred|reasked) ;;
        *) printf '%s\tprimary-%s\t%s\t%s\n' \
               "$cell" "$cue" "$turn" "$primary_reply" >> "$ORDINARY" ;;
    esac

    followup_turn=0
    followup_outcome=none
    followup_candidate=none
    followup_distress=0
    followup_gate=0
    followup_calm_turns=0
    target_recovered="$primary_target_asked"

    # A distractor may open its own ordinary Wonder. Ground it first; this is
    # not a shortcut to the target, only removal of the one-open-question lock.
    if [ "$cue" = novel-control ] && [ "$primary_target_asked" = false ]; then
        turn=$((turn + 1))
        ground_prompt="A $distractor is water."
        ground_log="$life/turns/turn-$(printf '%02d' "$turn")-ground.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + 200 + turn))" \
            --respond "$ground_prompt" --debug-field --save "$state" \
            > "$ground_log" 2>&1
        ground_reply="$(reply_from_log "$ground_log")"
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$ground_prompt" "$turn" "$ground_reply" >> "$transcript"
    fi

    # A control can itself be bodily dark (`quiet room` is VOID for Leo), so an
    # immediate bare target is not a fair persistence test. Apply one fixed,
    # predeclared recovery dose before every follow-up rather than retrying
    # until a desired outcome appears.
    if [ "$primary_target_asked" = false ]; then
        i=0
        while [ "$i" -lt "$FOLLOWUP_CALM" ]; do
            turn=$((turn + 1))
            log="$life/turns/turn-$(printf '%02d' "$turn")-followup-calm.log"
            "$ROOT/leo" --load "$state" --seed "$((seed + 250 + turn))" \
                --respond "$CALM_PROMPT" --debug-field --save "$state" \
                > "$log" 2>&1
            receipt="$(receipt_from_log "$log" "$cell-followup-calm" "$seed")"
            IFS=$'\t' read -r _ _ _ recovery_outcome recovery_candidate \
                _ _ _ _ <<< "$receipt"
            case "$recovery_outcome" in
                asked|asked-deferred|reasked)
                    printf '%s follow-up calm turn opened %s (%s)\n' \
                        "$cell" "$recovery_candidate" "$recovery_outcome" >&2
                    exit 1
                    ;;
            esac
            reply="$(reply_from_log "$log")"
            printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
                "$turn" "$CALM_PROMPT" "$turn" "$reply" >> "$transcript"
            printf '%s\tfollowup-calm\t%s\t%s\n' \
                "$cell" "$turn" "$reply" >> "$ORDINARY"
            followup_calm_turns=$((followup_calm_turns + 1))
            i=$((i + 1))
        done
    fi

    # Any primary cue that did not ask the target receives one bare follow-up.
    # Success proves that control, distractor, and unsafe recurrence did not
    # consume the original pre-Wonder.
    if [ "$primary_target_asked" = false ]; then
        turn=$((turn + 1))
        followup_log="$life/turns/turn-$(printf '%02d' "$turn")-followup.log"
        "$ROOT/leo" --load "$state" --seed "$((seed + 300 + turn))" \
            --respond "$target" --debug-field --save "$state" \
            > "$followup_log" 2>&1
        receipt="$(receipt_from_log "$followup_log" "$cell-followup" "$seed")"
        IFS=$'\t' read -r _ _ followup_turn followup_outcome followup_candidate \
            _ _ followup_distress followup_gate <<< "$receipt"
        followup_reply="$(reply_from_log "$followup_log")"
        printf 'human\t%s\t%s\nleo\t%s\t%s\n' \
            "$turn" "$target" "$turn" "$followup_reply" >> "$transcript"
        if [ "$followup_outcome" = asked-deferred ] &&
           [ "$followup_candidate" = "$target" ]; then
            target_recovered=true
        fi
    fi

    [ "$target_recovered" = true ] || {
        printf '%s did not preserve recoverable target curiosity\n' "$cell" >&2
        exit 1
    }
    transcript_sha="$(sha256_file "$transcript")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$cell" "$target" "$seed" "$distractor" "$calm" "$cue" \
        "$primary_turn" "$primary_outcome" "$primary_candidate" \
        "$primary_distress" "$primary_gate" "$primary_target_asked" \
        "$primary_reply" "$followup_calm_turns" "$followup_turn" "$followup_outcome" \
        "$followup_candidate" "$followup_distress" "$followup_gate" \
        "$target_recovered" "$transcript_sha" "$life" >> "$MATRIX"
done

expected="$((3 * ${#calm_turns[@]} * 5))"
actual="$(( $(wc -l < "$MATRIX") - 1 ))"
[ "$actual" -eq "$expected" ] || {
    printf 'matrix has %d of %d expected cells\n' "$actual" "$expected" >&2
    exit 1
}

printf 'calm_turns\tcue_kind\tcells\tprimary_target_asked\tblocked_deferred\tmean_distress\tmean_gate\n' > "$SUMMARY"
awk -F '\t' '
    NR > 1 {
        key = $5 "\t" $6
        cells[key]++
        if ($12 == "true") opened[key]++
        if ($8 == "blocked-deferred") blocked[key]++
        distress[key] += $10
        gate[key] += $11
    }
    END {
        for (key in cells)
            printf "%s\t%d\t%d\t%d\t%.3f\t%.3f\n",
                   key, cells[key], opened[key] + 0, blocked[key] + 0,
                   distress[key] / cells[key], gate[key] / cells[key]
    }
' "$MATRIX" | sort -t $'\t' -k1,1n -k2,2 >> "$SUMMARY"
printf '\nrecoverable=%s/%s\n' \
    "$(awk -F '\t' 'NR > 1 && $20 == "true" { n++ } END { print n + 0 }' "$MATRIX")" \
    "$actual" >> "$SUMMARY"

cat "$SUMMARY"
printf '\nmatrix: %s\nordinary replies: %s\n' "$MATRIX" "$ORDINARY"
