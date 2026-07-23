#!/usr/bin/env bash
# Balanced target x anchor x seed matrix for the local visible-branch policy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${1:-$ROOT/scripts/visible_branch_cases.tsv}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${2:-${TMPDIR:-/tmp}/leo-visible-branch-matrix-$STAMP}"
SEED_SPEC="${LEO_MATRIX_SEEDS:-83 137 211}"
MIN_HEARD="${LEO_MATRIX_MIN_HEARD:-5}"

[ -f "$CASES" ] || { printf 'missing matrix cases: %s\n' "$CASES" >&2; exit 2; }
[ ! -e "$OUT" ] || { printf 'output path already exists: %s\n' "$OUT" >&2; exit 2; }
case "$MIN_HEARD" in ''|*[!0-9]*) printf 'LEO_MATRIX_MIN_HEARD must be an integer\n' >&2; exit 2 ;; esac

read -r -a seeds <<< "$SEED_SPEC"
[ "${#seeds[@]}" -eq 3 ] || { printf 'local-v1 matrix requires exactly three seeds\n' >&2; exit 2; }
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
[ "${#case_ids[@]}" -eq 3 ] || { printf 'local-v1 matrix requires exactly three cases\n' >&2; exit 2; }

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
printf 'cell\trow\tseed\ttarget\tanchor_case\tanchor_a\tanchor_b\n' > "$PLAN"
for row in 0 1 2; do
    for col in 0 1 2; do
        anchor_idx=$(( (row + col) % 3 ))
        cell="r$((row + 1))c$((col + 1))-${targets[$col]}-${case_ids[$anchor_idx]}"
        printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\n' \
            "$cell" "$((row + 1))" "${seeds[$row]}" "${targets[$col]}" \
            "${case_ids[$anchor_idx]}" "${anchors_a[$anchor_idx]}" \
            "${anchors_b[$anchor_idx]}" >> "$PLAN"
    done
done
if [ "${LEO_MATRIX_PLAN_ONLY:-0}" = 1 ]; then
    cat "$PLAN"
    exit 0
fi

MATRIX="$OUT/matrix.tsv"
RECEIPTS="$OUT/receipts.tsv"
EDGES="$OUT/sleep_edges.tsv"
printf 'cell\trow\tseed\ttarget\tanchor_case\tanchor_a\tanchor_b\ttranscript_sha256\tproposals\tscored\tunscorable\tpending\tconfirmed\tfalse_pressure\trelease_confirmed\ttarget_questions\tsleep_crossing\tbranches\toutput\n' > "$MATRIX"

first=1
for row in 0 1 2; do
    seed="${seeds[$row]}"
    for col in 0 1 2; do
        anchor_idx=$(( (row + col) % 3 ))
        target="${targets[$col]}"
        anchor_case="${case_ids[$anchor_idx]}"
        anchor_a="${anchors_a[$anchor_idx]}"
        anchor_b="${anchors_b[$anchor_idx]}"
        cell="r$((row + 1))c$((col + 1))-${target}-${anchor_case}"
        life="$OUT/lives/$cell"

        LEO_VISIBLE_BRANCH_POLICY=local-v1 \
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
        sleep_crossing="$(( $(wc -l < "$life/sleep_edges.tsv") - 1 ))"
        branches="$(jq -sr 'map(.branch) | join(",")' "$life"/policy/*.json)"

        printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\n' \
            "$cell" "$((row + 1))" "$seed" "$target" "$anchor_case" \
            "$anchor_a" "$anchor_b" "$transcript_sha" "$proposals" "$scored" \
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
printf '\ncells=9 sleep-crossing=%d\nmatrix: %s\nreceipts: %s\n' \
    "$(( $(wc -l < "$EDGES") - 1 ))" "$MATRIX" "$RECEIPTS"
