# A.91: select two disjoint near-gate controls for every replay-locked event.

function fail() {
    fatal = 1
    exit 2
}

function integer(value) {
    return value ~ /^[0-9]+$/
}

function number(value) {
    return value ~ /^[0-9]+([.][0-9]+)?$/
}

function absolute(value) {
    return value < 0 ? -value : value
}

function better_organism(candidate, best, margin_gap, texture_mismatch,
                         turn_gap) {
    if (!best) return 1
    if (margin_gap < best_margin_gap - 0.0000001) return 1
    if (absolute(margin_gap - best_margin_gap) > 0.0000001) return 0
    if (texture_mismatch < best_texture_mismatch) return 1
    if (texture_mismatch > best_texture_mismatch) return 0
    if (turn_gap < best_turn_gap) return 1
    if (turn_gap > best_turn_gap) return 0
    if (control_turn[candidate] < control_turn[best]) return 1
    if (control_turn[candidate] > control_turn[best]) return 0
    return control_run_seed[candidate] < control_run_seed[best]
}

function better_ecology(candidate, best, margin_gap, seed_gap) {
    if (!best) return 1
    if (margin_gap < best_margin_gap - 0.0000001) return 1
    if (absolute(margin_gap - best_margin_gap) > 0.0000001) return 0
    if (seed_gap < best_seed_gap) return 1
    if (seed_gap > best_seed_gap) return 0
    if (control_life[candidate] < control_life[best]) return 1
    if (control_life[candidate] > control_life[best]) return 0
    return control_run_seed[candidate] < control_run_seed[best]
}

BEGIN {
    FS = OFS = "\t"
    gate = 0.40
    ceiling = 0.45
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 20 || $1 != "event" || $6 != "trigger_turn" ||
            $10 != "run_seed" || $13 != "similarity" || $20 != "reply")
            fail()
        next
    }
    if (NF != 20 || seen_event[$1]++ ||
        $1 != sprintf("%s-t%03d", $2, $6) ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        !integer($4) || !integer($5) || !integer($6) || !integer($7) ||
        !integer($8) || $9 !~ /^(home|storm|wonder|social)$/ ||
        !integer($10) || !number($13) || $13 + 0 >= gate ||
        $19 == "" || $20 == "") fail()
    event_n++
    event_id[event_n] = $1
    event_life[event_n] = $2
    event_split[event_n] = $3
    event_base_seed[event_n] = $4
    event_rank[event_n] = $5
    event_turn[event_n] = $6
    event_session[event_n] = $7
    event_order[event_n] = $8
    event_texture[event_n] = $9
    event_run_seed[event_n] = $10
    event_similarity[event_n] = $13 + 0
    event_prompt[event_n] = $19
    event_reply[event_n] = $20
    event_index[$1] = event_n
    relevant_life[$2] = 1
    next
}

FILENAME == ARGV[2] {
    if (FNR == 1) {
        if (NF != 19 || $1 != "event" || $6 != "trigger_turn" ||
            $16 != "state_equal" || $19 != "reply_equal") fail()
        next
    }
    index_value = event_index[$1]
    if (NF != 19 || !index_value || seen_lock[$1]++ ||
        $2 != event_life[index_value] || $3 != event_split[index_value] ||
        $4 != event_base_seed[index_value] ||
        $6 != event_turn[index_value] || $7 != event_session[index_value] ||
        $8 != event_order[index_value] || $9 != event_texture[index_value] ||
        $10 != event_run_seed[index_value]) fail()
    for (i = 16; i <= 19; i++) if ($i != "true") fail()
    locks++
    next
}

FNR == 1 {
    if (NF != 34 || $1 != "life" || $4 != "phase" || $9 != "turn" ||
        $13 != "event" || $14 != "similarity" || $33 != "prompt" ||
        $34 != "reply") fail()
    next
}

{
    if (NF != 34 || $1 !~ /^[ph][0-9][0-9]$/ ||
        $2 !~ /^(primary|holdout)$/ || !integer($3) || $4 != "writer" ||
        !integer($5) || !integer($6) ||
        $7 !~ /^(home|storm|wonder|social)$/ || !integer($8) ||
        !integer($9) || $13 !~ /^(updated|replaced)$/ || !number($14) ||
        $33 == "" || $34 == "" || seen_writer[$1 SUBSEP $9]++) fail()
    writer_rows++
    if ($13 != "updated" || $14 + 0 < gate || $14 + 0 >= ceiling)
        next
    control_n++
    control_life[control_n] = $1
    control_split[control_n] = $2
    control_base_seed[control_n] = $3
    control_turn[control_n] = $9
    control_session[control_n] = $5
    control_order[control_n] = $6
    control_texture[control_n] = $7
    control_run_seed[control_n] = $8
    control_similarity[control_n] = $14 + 0
    control_prompt[control_n] = $33
    control_reply[control_n] = $34
}

END {
    if (fatal) exit 2
    if (event_n != expected || locks != event_n || writer_rows != writer_expected)
        fail()

    for (i = 1; i <= event_n; i++) {
        best = 0
        for (j = 1; j <= control_n; j++) {
            if (organism_used[j] || control_life[j] != event_life[i])
                continue
            margin_gap = absolute((gate - event_similarity[i]) - (control_similarity[j] - gate))
            texture_mismatch = control_texture[j] == event_texture[i] ? 0 : 1
            turn_gap = absolute(control_turn[j] - event_turn[i])
            if (better_organism(j, best, margin_gap, texture_mismatch,
                                turn_gap)) {
                best = j
                best_margin_gap = margin_gap
                best_texture_mismatch = texture_mismatch
                best_turn_gap = turn_gap
            }
        }
        if (!best) fail()
        organism_used[best] = 1
        organism_pick[i] = best
    }

    for (i = 1; i <= event_n; i++) {
        best = 0
        for (j = 1; j <= control_n; j++) {
            if (organism_used[j] || ecology_used[j] ||
                control_life[j] == event_life[i] ||
                control_split[j] != event_split[i] ||
                control_session[j] != event_session[i] ||
                control_order[j] != event_order[i] ||
                control_texture[j] != event_texture[i]) continue
            margin_gap = absolute((gate - event_similarity[i]) - (control_similarity[j] - gate))
            seed_gap = absolute(control_base_seed[j] - event_base_seed[i])
            if (better_ecology(j, best, margin_gap, seed_gap)) {
                best = j
                best_margin_gap = margin_gap
                best_seed_gap = seed_gap
            }
        }
        if (!best) fail()
        ecology_used[best] = 1
        ecology_pick[i] = best
    }

    print "pair", "event", "event_life", "split", "event_base_seed",
          "event_turn", "event_session", "event_order", "event_texture",
          "event_run_seed", "event_similarity", "event_margin",
          "event_prompt", "event_reply", "organism_control",
          "organism_turn", "organism_session", "organism_order",
          "organism_texture", "organism_run_seed", "organism_similarity",
          "organism_margin", "organism_margin_gap", "organism_texture_match",
          "organism_turn_gap", "organism_prompt", "organism_reply",
          "ecology_control", "ecology_life", "ecology_base_seed",
          "ecology_turn", "ecology_session", "ecology_order",
          "ecology_texture", "ecology_run_seed", "ecology_similarity",
          "ecology_margin", "ecology_margin_gap", "ecology_seed_gap",
          "ecology_prompt", "ecology_reply"

    for (i = 1; i <= event_n; i++) {
        organism = organism_pick[i]
        ecology = ecology_pick[i]
        organism_texture_match = control_texture[organism] == event_texture[i] ? "true" : "false"
        printf "%02d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\t%d\t%.3f\t%.3f\t%s\t%s",
               i, event_id[i], event_life[i], event_split[i],
               event_base_seed[i], event_turn[i], event_session[i],
               event_order[i], event_texture[i], event_run_seed[i],
               event_similarity[i], gate - event_similarity[i],
               event_prompt[i], event_reply[i]
        printf "\t%s-t%03d\t%d\t%d\t%d\t%s\t%d\t%.3f\t%.3f\t%.6f\t%s\t%d\t%s\t%s",
               control_life[organism], control_turn[organism],
               control_turn[organism], control_session[organism],
               control_order[organism], control_texture[organism],
               control_run_seed[organism], control_similarity[organism],
               control_similarity[organism] - gate,
               absolute((gate - event_similarity[i]) - (control_similarity[organism] - gate)),
               organism_texture_match,
               absolute(control_turn[organism] - event_turn[i]),
               control_prompt[organism], control_reply[organism]
        printf "\t%s-t%03d\t%s\t%d\t%d\t%d\t%d\t%s\t%d\t%.3f\t%.3f\t%.6f\t%d\t%s\t%s\n",
               control_life[ecology], control_turn[ecology],
               control_life[ecology], control_base_seed[ecology],
               control_turn[ecology], control_session[ecology],
               control_order[ecology], control_texture[ecology],
               control_run_seed[ecology], control_similarity[ecology],
               control_similarity[ecology] - gate,
               absolute((gate - event_similarity[i]) - (control_similarity[ecology] - gate)),
               absolute(control_base_seed[ecology] - event_base_seed[i]),
               control_prompt[ecology], control_reply[ecology]
    }
}
