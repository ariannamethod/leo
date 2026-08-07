#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/leo-liminal-select.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HASH='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

printf 'pair\tevent\tevent_life\tsplit\tevent_base_seed\tevent_turn\tevent_session\tevent_order\tevent_texture\tevent_run_seed\tevent_similarity\tevent_margin\tevent_prompt\tevent_reply\torganism_control\torganism_turn\torganism_session\torganism_order\torganism_texture\torganism_run_seed\torganism_similarity\torganism_margin\torganism_margin_gap\torganism_texture_match\torganism_turn_gap\torganism_prompt\torganism_reply\tecology_control\tecology_life\tecology_base_seed\tecology_turn\tecology_session\tecology_order\tecology_texture\tecology_run_seed\tecology_similarity\tecology_margin\tecology_margin_gap\tecology_seed_gap\tecology_prompt\tecology_reply\n' > "$TMP/matches.tsv"
printf 'event\tlife\tsplit\tbase_seed\tenrollment_rank\ttrigger_turn\tsession\torder\ttexture\trun_seed\tpretrigger_sha\tdisplaced_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$TMP/event-locks.tsv"
printf 'control\tpair\tfamily\tlife\tsplit\tbase_seed\tturn\tsession\torder\ttexture\trun_seed\tprecontrol_sha\tupdated_sha\tsource_log_sha\treplay_log_sha\tnormalized_sha\tlife_state_equal\tstate_equal\tlog_equal\tshape_equal\treply_equal\n' > "$TMP/control-locks.tsv"

for i in $(seq 1 19); do
    printf -v pair '%02d' "$i"
    if [ "$i" -le 10 ]; then
        printf -v event_life 'p%02d' "$i"
        printf -v ecology_life 'p%02d' "$((i + 20))"
        split=primary
    else
        printf -v event_life 'h%02d' "$((i - 10))"
        printf -v ecology_life 'h%02d' "$((i + 10))"
        split=holdout
    fi
    if [ "$i" -le 15 ]; then turn=68; else turn=96; fi
    event="$event_life-t$(printf '%03d' "$turn")"
    organism="$event_life-t040"
    ecology="$ecology_life-t$(printf '%03d' "$turn")"
    event_seed=$((200000 + i))
    ecology_seed=$((300000 + i))
    prompt="shared prompt $pair"
    printf '%s\t%s\t%s\t%s\t%d\t%d\t5\t4\tsocial\t%d\t0.390\t0.010\t%s\tevent reply %s\t%s\t40\t2\t4\tstorm\t%d\t0.420\t0.020\t0.010\tfalse\t28\torganism prompt %s\torganism reply %s\t%s\t%s\t%d\t%d\t5\t4\tsocial\t%d\t0.420\t0.020\t0.010\t100000\t%s\tecology reply %s\n' \
        "$pair" "$event" "$event_life" "$split" "$event_seed" "$turn" \
        "$event_seed" "$prompt" "$pair" "$organism" "$event_seed" \
        "$pair" "$pair" "$ecology" "$ecology_life" "$ecology_seed" \
        "$turn" "$ecology_seed" "$prompt" "$pair" >> "$TMP/matches.tsv"
    printf '%s\t%s\t%s\t%d\t1\t%d\t5\t4\tsocial\t%d\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\n' \
        "$event" "$event_life" "$split" "$event_seed" "$turn" \
        "$event_seed" "$HASH" "$HASH" "$HASH" "$HASH" "$HASH" \
        >> "$TMP/event-locks.tsv"
    printf '%s\t%s\torganism\t%s\t%s\t%d\t40\t2\t4\tstorm\t%d\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\ttrue\n' \
        "$organism" "$pair" "$event_life" "$split" "$event_seed" \
        "$event_seed" "$HASH" "$HASH" "$HASH" "$HASH" "$HASH" \
        >> "$TMP/control-locks.tsv"
    printf '%s\t%s\tecology\t%s\t%s\t%d\t%d\t5\t4\tsocial\t%d\t%s\t%s\t%s\t%s\t%s\ttrue\ttrue\ttrue\ttrue\ttrue\n' \
        "$ecology" "$pair" "$ecology_life" "$split" "$ecology_seed" \
        "$turn" "$ecology_seed" "$HASH" "$HASH" "$HASH" "$HASH" \
        "$HASH" >> "$TMP/control-locks.tsv"
done

awk -f "$ROOT/scripts/state_swarm_liminal_confirmation_select.awk" \
    "$TMP/matches.tsv" "$TMP/event-locks.tsv" "$TMP/control-locks.tsv" \
    > "$TMP/selection.tsv"

awk -F '\t' '
    NR == 1 { if (NF != 13 || $1 != "pair" || $2 != "arm" || $13 != "reply") exit 1; next }
    { count[$1]++; arms[$1 SUBSEP $2]++ }
    END {
        if (NR != 31) exit 1
        for (i = 1; i <= 15; i++) {
            pair = sprintf("%02d", i)
            if (count[pair] != 2 || arms[pair SUBSEP "event"] != 1 ||
                arms[pair SUBSEP "ecology"] != 1) exit 1
        }
        for (i = 16; i <= 19; i++)
            if (sprintf("%02d", i) in count) exit 1
    }
' "$TMP/selection.tsv"

awk -F '\t' 'BEGIN { OFS = FS } NR == 3 { $3 = "organism" } { print }' \
    "$TMP/control-locks.tsv" > "$TMP/bad-control-locks.tsv"
if awk -f "$ROOT/scripts/state_swarm_liminal_confirmation_select.awk" \
    "$TMP/matches.tsv" "$TMP/event-locks.tsv" \
    "$TMP/bad-control-locks.tsv" >/dev/null 2>&1; then
    printf 'liminal selector accepted an ecology lock with the wrong family\n' >&2
    exit 1
fi

printf 'state-swarm liminal confirmation selector: ok\n'
