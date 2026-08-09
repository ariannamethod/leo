#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-liminal-trace-select.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HASH='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
printf 'pair\tarm\tanchor\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tprompt\treply\n' > "$TMP/selection.tsv"
printf 'pair\tarm\tanchor\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tprompt\treply\tpre_state\tpost_state\tfinal_state\tpre_sha\tpost_sha\tfinal_sha\n' > "$TMP/plan.tsv"
printf 'pair\tarm\tanchor\tlife\tsplit\tanchor_turn\tfuture_turns\tpre_sha\tpost_sha\tfinal_sha\treproduced_sha\treply_equal\tstate_equal\n' > "$TMP/locks.tsv"

for i in $(seq 1 15); do
    printf -v pair '%02d' "$i"
    if [ "$i" -le 7 ]; then prefix=p; split=primary; else prefix=h; split=holdout; fi
    turn=68
    if [ "$i" -eq 15 ]; then turn=94; fi
    future=$((96 - turn))
    for arm in event ecology; do
        if [ "$arm" = event ]; then offset=0; else offset=30; fi
        n=$((i + offset))
        printf -v life '%s%02d' "$prefix" "$n"
        printf -v anchor '%s-t%03d' "$life" "$turn"
        seed=$((100000 + n))
        printf '%s\t%s\t%s\t%s\t%s\t%d\t%d\t5\t4\tsocial\t%d\tprompt %s\treply %s\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$seed" "$turn" \
            "$((seed + 504))" "$pair" "$arm" >> "$TMP/selection.tsv"
        printf '%s\t%s\t%s\t%s\t%s\t%d\t%d\t5\t4\tsocial\t%d\tprompt %s\treply %s\t/pre/%s\t/post/%s\t/final/%s\t%s\t%s\t%s\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$seed" "$turn" \
            "$((seed + 504))" "$pair" "$arm" "$anchor" "$anchor" "$life" \
            "$HASH" "$HASH" "$HASH" >> "$TMP/plan.tsv"
        printf '%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\ttrue\ttrue\n' \
            "$pair" "$arm" "$anchor" "$life" "$split" "$turn" "$future" \
            "$HASH" "$HASH" "$HASH" "$HASH" >> "$TMP/locks.tsv"
    done
done

awk -f "$ROOT/scripts/state_swarm_liminal_trace_select.awk" \
    "$TMP/selection.tsv" "$TMP/plan.tsv" "$TMP/locks.tsv" \
    > "$TMP/trace-plan.tsv"
awk -F '\t' '
    NR == 1 { if (NF != 19 || $1 != "pair" || $19 != "final_sha") exit 1; next }
    { pairs[$1]++; arms[$1 SUBSEP $2]++ }
    END {
        if (NR != 29 || length(pairs) != 14) exit 1
        for (i = 1; i <= 14; i++) {
            p = sprintf("%02d", i)
            if (pairs[p] != 2 || arms[p SUBSEP "event"] != 1 ||
                arms[p SUBSEP "ecology"] != 1) exit 1
        }
        if ("15" in pairs) exit 1
    }
' "$TMP/trace-plan.tsv"

sed '2s/true$/false/' "$TMP/locks.tsv" > "$TMP/unlocked.tsv"
if awk -f "$ROOT/scripts/state_swarm_liminal_trace_select.awk" \
    "$TMP/selection.tsv" "$TMP/plan.tsv" "$TMP/unlocked.tsv" \
    >/dev/null 2>&1; then
    printf 'liminal trace selector accepted a false A.92 lock\n' >&2
    exit 1
fi

printf 'state-swarm liminal trace selector: ok\n'
