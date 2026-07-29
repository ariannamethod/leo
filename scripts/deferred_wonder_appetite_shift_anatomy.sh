#!/usr/bin/env bash
# A.60: ask whether A.59's outcomes were identifiable at proposal time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-deferred-wonder-appetite-shift-anatomy-$STAMP}"

if [ "${LEO_APPETITE_SHIFT_ANATOMY_PLAN_ONLY:-0}" = 1 ]; then
    printf 'case\tlife_turns\tcontinuation_forecasts\toutcome_assignment\tcomparison\tplan_visibility\n'
    printf 'hidden-future\t600\t98\tround-source-parity\texact-proposal-feature-multiset\tsealed-before-replies\n'
    exit 0
fi

[ ! -e "$OUT" ] || {
    printf 'output path already exists: %s\n' "$OUT" >&2
    exit 2
}
mkdir -p "$OUT"

"$ROOT/scripts/deferred_wonder_appetite_source_cadence_life.sh" \
    "$OUT/life" > "$OUT/life-receipt.txt"

PLAN="$OUT/life/sealed-plan.tsv"
ACQUISITION_TURNS="$(
    awk -F '\t' '$2 == "acquire" { turn = $1 }
                  END { print turn + 0 }' "$PLAN"
)"
CONTINUATION_TURNS="$(
    awk -F '\t' '$2 == "continue" { n++ }
                  END { print n + 0 }' "$PLAN"
)"
FIRST_CLOCK="$(
    awk '
        /\[wonder-appetite: turn=/ {
            if (match($0, /turn=[0-9]+/)) {
                print substr($0, RSTART + 5, RLENGTH - 5)
                exit
            }
        }
    ' "$OUT/life/on/turn-1.log"
)"
PROPOSAL_OFFSET=$((FIRST_CLOCK - 1))

SETTLED="$OUT/settled.tsv"
printf 'word\tproposed_turn\tdeadline_turn\tobserved_turn\tappetite\tpeak_recurrence\tsemantic_hits\tobservations\tspoken\tverdict\tbrier\n' \
    > "$SETTLED"
for turn in $(seq 1 "$CONTINUATION_TURNS"); do
    awk -v offset="$PROPOSAL_OFFSET" '
        /\[wonder-appetite-calibration:/ &&
        /\/(sustained|faded)\// {
            line = $0
            sub(/^.*entries=/, "", line)
            sub(/\].*$/, "", line)
            split(line, values, /[:\/]/)
            if (values[2] <= offset) next
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                   values[1], values[2], values[3], values[4],
                   values[5], values[6], values[7], values[8],
                   values[9], values[10], values[11]
        }
    ' "$OUT/life/on/turn-$turn.log" >> "$SETTLED"
done

PROPOSALS="$OUT/proposal-outcomes.tsv"
printf 'word\tproposed_turn\tverdict\treceipt_appetite\tstatus\tmargin\trecurrence\tsilence\tunfinished\tflow_gap\tcandidate_appetite\tspoken\tliteral\n' \
    > "$PROPOSALS"
while IFS=$'\t' read -r word proposed deadline observed receipt_appetite \
        peak hits observations spoken verdict brier; do
    [ "$word" = word ] && continue
    local_turn=$((proposed - PROPOSAL_OFFSET))
    awk -v word="$word" -v proposed="$proposed" \
        -v verdict="$verdict" -v receipt_appetite="$receipt_appetite" '
        /\[wonder-appetite: turn=/ {
            line = $0
            status = margin = ""
            if (match(line, /status=[^ ]+/))
                status = substr(line, RSTART + 7, RLENGTH - 7)
            if (match(line, /margin=[^ ]+/))
                margin = substr(line, RSTART + 7, RLENGTH - 7)
            sub(/^.*entries=/, "", line)
            sub(/\].*$/, "", line)
            n = split(line, items, /\|/)
            for (i = 1; i <= n; i++) {
                split(items[i], values, /[:\/]/)
                if (values[1] != word) continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                       word, proposed, verdict, receipt_appetite,
                       status, margin, values[2], values[3],
                       values[4], values[5], values[6],
                       values[7], values[8]
            }
        }
    ' "$OUT/life/on/turn-$local_turn.log" >> "$PROPOSALS"
done < "$SETTLED"

feature_multiset() {
    local verdict="$1"
    awk -F '\t' -v verdict="$verdict" '
        NR > 1 && $3 == verdict {
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                   $5, $6, $7, $8, $9, $10, $11, $12, $13
        }
    ' "$PROPOSALS" | sort
}

feature_multiset sustained > "$OUT/sustained-features.tsv"
feature_multiset faded > "$OUT/faded-features.tsv"
features_equal=0
cmp -s "$OUT/sustained-features.tsv" "$OUT/faded-features.tsv" &&
    features_equal=1

sustained="$(
    awk -F '\t' 'NR > 1 && $3 == "sustained" { n++ }
                  END { print n + 0 }' "$PROPOSALS"
)"
faded="$(
    awk -F '\t' 'NR > 1 && $3 == "faded" { n++ }
                  END { print n + 0 }' "$PROPOSALS"
)"
settled=$((sustained + faded))
proposal_rows=$(( $(wc -l < "$PROPOSALS") - 1 ))

margin_signature() {
    local verdict="$1"
    awk -F '\t' -v verdict="$verdict" '
        NR > 1 && $3 == verdict { count[$6]++ }
        END {
            separator = ""
            for (margin in count) {
                values[n++] = margin
            }
            for (i = 0; i < n; i++)
                for (j = i + 1; j < n; j++)
                    if (values[j] + 0 < values[i] + 0) {
                        tmp = values[i]
                        values[i] = values[j]
                        values[j] = tmp
                    }
            for (i = 0; i < n; i++) {
                margin = values[i]
                printf "%s%s:%d", separator, margin, count[margin]
                separator = "|"
            }
            printf "\n"
        }
    ' "$PROPOSALS"
}

sustained_margins="$(margin_signature sustained)"
faded_margins="$(margin_signature faded)"
feature_vector="$(
    awk -F '\t' '
        NR == 2 {
            printf "%s/%s/%s/%s/%s/%s/%s/%s",
                   $5, $7, $8, $9, $10, $11, $12, $13
        }
    ' "$PROPOSALS"
)"
distinct_vectors="$(
    awk -F '\t' '
        NR > 1 {
            key = $5 FS $7 FS $8 FS $9 FS $10 FS $11 FS $12 FS $13
            seen[key] = 1
        }
        END { for (key in seen) n++; print n + 0 }
    ' "$PROPOSALS"
)"

probability="$(
    awk -F '\t' 'NR == 2 { print $11 }' "$PROPOSALS"
)"
empirical_rate="$(
    awk -v sustained="$sustained" -v settled="$settled" \
        'BEGIN { printf "%.3f", sustained / settled }'
)"
expected_brier="$(
    awk -v p="$probability" -v sustained="$sustained" \
        -v faded="$faded" -v settled="$settled" '
        BEGIN {
            brier = (sustained * (p - 1.0) * (p - 1.0) + faded * p * p) / settled
            printf "%.3f", brier
        }
    '
)"

FINAL_LOG="$OUT/life/on/turn-$CONTINUATION_TURNS.log"
IFS=$'\t' read -r observed_probability observed_rate observed_brier \
    reliability_status < <(
        awk '
            /\[wonder-appetite-reliability:/ {
                line = $0
                if (match(line, /cells=u62-70:[^]]+/)) {
                    cell = substr(line, RSTART + 13, RLENGTH - 13)
                    split(cell, values, "/")
                    print values[3] "\t" values[4] "\t" values[7] "\t" values[9]
                }
            }
        ' "$FINAL_LOG"
    )
holdout_status="$(
    awk '
        /\[wonder-appetite-holdout:/ {
            if (match($0, /cells=u62-70:[^]]+/)) {
                cell = substr($0, RSTART + 13, RLENGTH - 13)
                split(cell, values, "/")
                print values[17]
            }
        }
    ' "$FINAL_LOG"
)"
sequence_status="$(
    awk '
        /\[wonder-appetite-checkpoint-sequence:/ {
            if (match($0, /cells=u62-70:[^]]+/)) {
                cell = substr($0, RSTART + 13, RLENGTH - 13)
                split(cell, values, "/")
                print values[5]
            }
        }
    ' "$FINAL_LOG"
)"

[ "$ACQUISITION_TURNS" -eq 208 ] &&
[ "$CONTINUATION_TURNS" -eq 392 ] &&
[ "$proposal_rows" -eq "$settled" ] &&
[ "$settled" -eq 98 ] &&
[ "$sustained" -eq 49 ] &&
[ "$faded" -eq 49 ] &&
[ "$features_equal" -eq 1 ] &&
[ "$distinct_vectors" -eq 1 ] &&
[ "$sustained_margins" = "0.220:35|0.440:14" ] &&
[ "$faded_margins" = "$sustained_margins" ] &&
[ "$feature_vector" = \
  "salient/0.800/1.000/0.500/0.000/0.690/0/0" ] &&
[ "$probability" = 0.690 ] &&
[ "$empirical_rate" = 0.500 ] &&
[ "$expected_brier" = 0.286 ] &&
[ "$observed_probability" = "$probability" ] &&
[ "$observed_rate" = "$empirical_rate" ] &&
[ "$observed_brier" = "$expected_brier" ] &&
[ "$reliability_status" = over ] &&
[ "$holdout_status" = confirmed ] &&
[ "$sequence_status" = persistent-shift ] || {
    printf 'shift anatomy contract failed\n' >&2
    exit 1
}

OBSERVED="$OUT/observed.tsv"
printf 'case\tsettled\tsustained\tfaded\tfeature_multiset_equal\tdistinct_feature_vectors\tsustained_margins\tfaded_margins\tproposal_vector\tforecast_probability\tempirical_rate\texpected_brier\tobserved_brier\treliability_status\tholdout_status\tsequence_status\n' \
    > "$OBSERVED"
printf 'hidden-future\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$settled" "$sustained" "$faded" "$features_equal" \
    "$distinct_vectors" "$sustained_margins" "$faded_margins" \
    "$feature_vector" "$probability" "$empirical_rate" \
    "$expected_brier" "$observed_brier" "$reliability_status" \
    "$holdout_status" "$sequence_status" >> "$OBSERVED"

cat "$OBSERVED"
printf '\nsettled receipts: %s\nproposal/outcome join: %s\nlife receipt: %s\n' \
    "$SETTLED" "$PROPOSALS" "$OUT/life-receipt.txt"
