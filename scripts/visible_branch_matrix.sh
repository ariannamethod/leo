#!/usr/bin/env bash
# Balanced target x anchor x seed matrix for the local visible-branch policy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTOCOL="${LEO_MATRIX_PROTOCOL:-local-v1}"
if [ "$PROTOCOL" = local-v2-resonance ]; then
    DEFAULT_CASES="$ROOT/scripts/visible_resonance_cases.tsv"
else
    DEFAULT_CASES="$ROOT/scripts/visible_branch_cases.tsv"
fi
CASES="${1:-$DEFAULT_CASES}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${2:-${TMPDIR:-/tmp}/leo-visible-branch-matrix-$STAMP}"
SEED_SPEC="${LEO_MATRIX_SEEDS:-83 137 211}"
MIN_HEARD="${LEO_MATRIX_MIN_HEARD:-5}"

[ -f "$CASES" ] || { printf 'missing matrix cases: %s\n' "$CASES" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
case "$MIN_HEARD" in ''|*[!0-9]*) printf 'LEO_MATRIX_MIN_HEARD must be an integer\n' >&2; exit 2 ;; esac
case "$PROTOCOL" in
    local-v1|local-v2-resonance) ;;
    *) printf 'unknown LEO_MATRIX_PROTOCOL: %s\n' "$PROTOCOL" >&2; exit 2 ;;
esac

read -r -a seeds <<< "$SEED_SPEC"
[ "${#seeds[@]}" -eq 3 ] || { printf '%s matrix requires exactly three seeds\n' "$PROTOCOL" >&2; exit 2; }
for i in 0 1 2; do
    case "${seeds[$i]}" in ''|*[!0-9]*) printf 'invalid matrix seed: %s\n' "${seeds[$i]}" >&2; exit 2 ;; esac
    for j in 0 1 2; do
        [ "$i" -eq "$j" ] || [ "${seeds[$i]}" != "${seeds[$j]}" ] || {
            printf 'duplicate matrix seed: %s\n' "${seeds[$i]}" >&2
            exit 2
        }
    done
done

case_ids=()
targets=()
anchors_a=()
terms_a=()
anchors_b=()
terms_b=()
while IFS=$'\t' read -r case_id target anchor_a term_a anchor_b term_b; do
    [ -n "$case_id" ] || continue
    [ "$case_id" != case ] || continue
    idx="${#case_ids[@]}"
    case_ids[$idx]="$case_id"
    targets[$idx]="$target"
    anchors_a[$idx]="$anchor_a"
    terms_a[$idx]="$term_a"
    anchors_b[$idx]="$anchor_b"
    terms_b[$idx]="$term_b"
done < "$CASES"
[ "${#case_ids[@]}" -eq 3 ] || { printf '%s matrix requires exactly three cases\n' "$PROTOCOL" >&2; exit 2; }

corpus_count() {
    local needle="$1"
    awk -v needle="$needle" '
        BEGIN { needle = tolower(needle); count = 0 }
        {
            line = tolower($0)
            gsub(/[^[:alpha:]\047]+/, " ", line)
            n = split(line, words, /[[:space:]]+/)
            for (i = 1; i <= n; i++) if (words[i] == needle) count++
        }
        END { print count + 0 }
    ' "$ROOT/leo.txt"
}

for i in 0 1 2; do
    target="${targets[$i]}"
    case "$target" in
        ''|*[!A-Za-z]*) printf 'invalid target in case %s: %s\n' "${case_ids[$i]}" "$target" >&2; exit 2 ;;
    esac
    count="$(corpus_count "$target")"
    [ "$count" -eq 0 ] || {
        printf 'target %s is not novel: corpus count %d\n' "$target" "$count" >&2
        exit 2
    }
    for term in ${terms_a[$i]} ${terms_b[$i]}; do
        count="$(corpus_count "$term")"
        [ "$count" -ge "$MIN_HEARD" ] || {
            printf 'anchor term %s in case %s has corpus count %d, need %d\n' \
                "$term" "${case_ids[$i]}" "$count" "$MIN_HEARD" >&2
            exit 2
        }
    done
    for j in 0 1 2; do
        [ "$i" -eq "$j" ] || [ "$target" != "${targets[$j]}" ] || {
            printf 'duplicate target in matrix: %s\n' "$target" >&2
            exit 2
        }
    done
done

mkdir -p "$OUT/lives" "$OUT/runner-logs"
PLAN="$OUT/plan.tsv"
printf 'cell\trow\tseed\ttarget\tanchor_case\tanchor_a\tanchor_b\tprotocol\treturn_cue\n' > "$PLAN"
cues=(a b control)
for row in 0 1 2; do
    for col in 0 1 2; do
        anchor_idx=$(( (row + col) % 3 ))
        cue=none
        [ "$PROTOCOL" != local-v2-resonance ] || cue="${cues[$(( (row + 2 * col) % 3 ))]}"
        cell="r$((row + 1))c$((col + 1))-${targets[$col]}-${case_ids[$anchor_idx]}"
        [ "$cue" = none ] || cell="$cell-$cue"
        printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$((row + 1))" "${seeds[$row]}" "${targets[$col]}" \
            "${case_ids[$anchor_idx]}" "${anchors_a[$anchor_idx]}" \
            "${anchors_b[$anchor_idx]}" "$PROTOCOL" "$cue" >> "$PLAN"
    done
done
if [ "${LEO_MATRIX_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

MATRIX="$OUT/matrix.tsv"
RECEIPTS="$OUT/receipts.tsv"
EDGES="$OUT/sleep_edges.tsv"
printf 'cell\trow\tseed\ttarget\tanchor_case\tanchor_a\tanchor_b\tprotocol\treturn_cue\tpre_cue_question_opened\tcue_target_return\tcue_raw_verdict\tcue_interpretation\ttarget_curiosity_trace\ttranscript_sha256\tproposals\tscored\tunscorable\tpending\tconfirmed\tfalse_pressure\trelease_confirmed\ttarget_questions\tsleep_crossing\tbranches\toutput\n' > "$MATRIX"

first=1
for row in 0 1 2; do
    seed="${seeds[$row]}"
    for col in 0 1 2; do
        anchor_idx=$(( (row + col) % 3 ))
        target="${targets[$col]}"
        anchor_case="${case_ids[$anchor_idx]}"
        anchor_a="${anchors_a[$anchor_idx]}"
        anchor_b="${anchors_b[$anchor_idx]}"
        cue=none
        [ "$PROTOCOL" != local-v2-resonance ] || cue="${cues[$(( (row + 2 * col) % 3 ))]}"
        cell="r$((row + 1))c$((col + 1))-${target}-${anchor_case}"
        [ "$cue" = none ] || cell="$cell-$cue"
        life="$OUT/lives/$cell"

        LEO_VISIBLE_BRANCH_POLICY="$PROTOCOL" \
        LEO_VISIBLE_RETURN_CUE="$cue" \
        LEO_ADAPTIVE_SEED="$seed" \
        LEO_ADAPTIVE_TARGET="$target" \
        LEO_ADAPTIVE_ANCHOR_A="$anchor_a" \
        LEO_ADAPTIVE_ANCHOR_B="$anchor_b" \
        LEO_ADAPTIVE_TERMS_A="${terms_a[$anchor_idx]}" \
        LEO_ADAPTIVE_TERMS_B="${terms_b[$anchor_idx]}" \
            "$ROOT/scripts/adaptive_life_probe.sh" \
            "$ROOT/scripts/visible_branch_phases.txt" "$life" \
            > "$OUT/runner-logs/$cell.log"

        transcript_sha="$(shasum -a 256 "$life/visible_transcript.txt" | awk '{print $1}')"
        proposals="$(awk -F '\t' 'NR > 1 { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        scored="$(awk -F '\t' 'NR > 1 && $13 != "" && $13 != "unscorable" { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        unscorable="$(awk -F '\t' 'NR > 1 && $13 == "unscorable" { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        pending="$(awk -F '\t' 'NR > 1 && $13 == "" { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        confirmed="$(awk -F '\t' 'NR > 1 && $13 == "confirmed" { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        false_pressure="$(awk -F '\t' 'NR > 1 && $13 == "false-pressure" { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        release_confirmed="$(awk -F '\t' 'NR > 1 && $6 == "release" && $13 == "confirmed" { n++ } END { print n + 0 }' "$life/receipts.tsv")"
        target_questions="$(jq -sr --arg target "$target" '
            [.[] | .reply | ascii_downcase |
             select(startswith(($target | ascii_downcase) + "?"))] | length
        ' "$life"/visible_replies.jsonl)"
        pre_cue_question_opened=false
        cue_target_return=false
        cue_raw_verdict=not-applicable
        cue_interpretation=not-applicable
        if [ "$PROTOCOL" = local-v2-resonance ]; then
            pre_cue_question_opened="$(jq -sr --arg target "$target" '
                any(.[]; .turn < 6 and
                    (.reply | ascii_downcase |
                     startswith(($target | ascii_downcase) + "?")))
            ' "$life"/visible_replies.jsonl)"
            cue_target_return="$(jq -sr --arg target "$target" '
                any(.[]; .turn == 6 and
                    (.reply | ascii_downcase |
                     startswith(($target | ascii_downcase) + "?")))
            ' "$life"/visible_replies.jsonl)"
            cue_raw_verdict="$(awk -F '\t' '
                NR > 1 && $10 == 6 && $13 != "" { verdict = $13 }
                END { print (verdict == "" ? "none" : verdict) }
            ' "$life/receipts.tsv")"
            if [ "$pre_cue_question_opened" != true ]; then
                cue_interpretation=unopened-question
            elif [ "$cue_target_return" = true ]; then
                if [ "$cue" = control ]; then
                    cue_interpretation=autonomous-pressure
                else
                    cue_interpretation=association-invited
                fi
            elif [ "$cue" = control ]; then
                cue_interpretation=control-quiet
            else
                cue_interpretation=missed-resonance
            fi
        fi
        sleep_crossing="$(( $(wc -l < "$life/sleep_edges.tsv") - 1 ))"
        branches="$(jq -sr 'map(.branch) | join(",")' "$life"/policy/*.json)"
        target_curiosity_trace="$(awk -F '\t' '
            NR == FNR {
                if (FNR > 1 && $9 == "true") named[$3] = 1
                next
            }
            FNR > 1 && named[$3] {
                if (trace != "") trace = trace ","
                trace = trace "t" $3 ":" $4 ":candidate=" $5 \
                    ":deferred=" $6 "@" $7 ":" $8 "/" $9
            }
            END { print (trace == "" ? "none" : trace) }
        ' "$life/sessions.tsv" "$life/curiosity.tsv")"

        printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\n' \
            "$cell" "$((row + 1))" "$seed" "$target" "$anchor_case" \
            "$anchor_a" "$anchor_b" "$PROTOCOL" "$cue" "$pre_cue_question_opened" \
            "$cue_target_return" "$cue_raw_verdict" "$cue_interpretation" \
            "$target_curiosity_trace" "$transcript_sha" "$proposals" "$scored" \
            "$unscorable" "$pending" "$confirmed" "$false_pressure" \
            "$release_confirmed" "$target_questions" "$sleep_crossing" \
            "$branches" "$life" >> "$MATRIX"

        if [ "$first" -eq 1 ]; then
            head -n 1 "$life/receipts.tsv" > "$RECEIPTS"
            head -n 1 "$life/sleep_edges.tsv" > "$EDGES"
            first=0
        fi
        awk -F '\t' -v OFS='\t' -v cell="$cell" 'NR > 1 { $1 = cell; print }' \
            "$life/receipts.tsv" >> "$RECEIPTS"
        awk -F '\t' -v OFS='\t' -v cell="$cell" 'NR > 1 { $1 = cell; print }' \
            "$life/sleep_edges.tsv" >> "$EDGES"
    done
done

awk -f "$ROOT/scripts/shadow_receipt_summary.awk" "$RECEIPTS" > "$OUT/summary.txt"
cat "$OUT/summary.txt"
if [ "$PROTOCOL" = local-v2-resonance ]; then
    awk -F '\t' '
        NR > 1 {
            cells++
            if ($10 == "true") {
                opened++
                if ($9 == "control") {
                    control_opened++
                    if ($11 == "true") control_returns++
                } else {
                    anchor_opened++
                    if ($11 == "true") anchor_returns++
                }
            } else {
                unopened++
            }
            interpretation[$13]++
        }
        END {
            printf "cells=%d opened=%d unopened=%d\n", cells, opened, unopened
            printf "anchor-cue opened=%d returns=%d\n", anchor_opened, anchor_returns
            printf "control-cue opened=%d returns=%d\n", control_opened, control_returns
            for (key in interpretation)
                printf "interpretation %s=%d\n", key, interpretation[key]
        }
    ' "$MATRIX" | sort > "$OUT/resonance_summary.txt"
    printf 'cell\ttarget\ttarget_curiosity_trace\n' > "$OUT/unopened_curiosity.tsv"
    awk -F '\t' -v OFS='\t' 'NR > 1 && $10 == "false" {
        print $1, $4, $14
    }' "$MATRIX" >> "$OUT/unopened_curiosity.tsv"
    printf '\n'
    cat "$OUT/resonance_summary.txt"
    printf '\nunopened curiosity:\n'
    cat "$OUT/unopened_curiosity.tsv"
fi
printf '\nprotocol=%s cells=9 sleep-crossing=%d\nmatrix: %s\nreceipts: %s\n' \
    "$PROTOCOL" "$(( $(wc -l < "$EDGES") - 1 ))" "$MATRIX" "$RECEIPTS"
