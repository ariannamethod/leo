# A.90: project each replay-locked trigger through seven frozen organ omissions.

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

function vector(value, target,    part, n, i) {
    n = split(value, part, "/")
    if (n != 7) return 0
    for (i = 1; i <= 7; i++) {
        if (!number(part[i]) || part[i] + 0 < 0 || part[i] + 0 > 1.001)
            return 0
        target[i] = part[i] + 0
    }
    return 1
}

function candidate_score(slot, omit,    organ, total, retained) {
    total = retained = 0
    for (organ = 1; organ <= 7; organ++) {
        if (organ == omit) continue
        total += organ_weight[organ] * candidate_organ[slot, organ]
        retained += organ_weight[organ]
    }
    return retained > 0 ? total / retained : 0
}

function best_candidate(omit,    slot, score, best_score) {
    chosen_slot = 0
    best_score = -1
    for (slot = 1; slot <= candidate_n; slot++) {
        score = candidate_score(slot, omit)
        if (score > best_score + 0.0000001) {
            best_score = score
            chosen_slot = slot
        }
    }
    chosen_score = best_score
    return candidate_id[chosen_slot]
}

function parse_candidates(members, organs, trigger_new, displaced, removed,
                          member, organ_item, member_n, organ_n, i, j, colon,
                          id, activation, organ_id, raw, nas, displaced_seen,
                          trigger_seen, parsed) {
    candidate_n = 0
    member_n = split(members, member, ",")
    organ_n = split(organs, organ_item, ",")
    if (member_n != 8 || organ_n != member_n || !vector(removed, removed_value))
        fail()
    for (i = 1; i <= member_n; i++) {
        colon = index(member[i], ":")
        if (!colon) fail()
        id = substr(member[i], 1, colon - 1)
        activation = substr(member[i], colon + 1)
        if (!integer(id) || id < 1 || !number(activation) ||
            activation < 0 || activation > 1.001) fail()
        if (id == displaced) displaced_seen = 1
        if (id == trigger_new) trigger_seen = 1

        colon = index(organ_item[i], ":")
        if (!colon || substr(organ_item[i], 1, colon - 1) != id) fail()
        raw = substr(organ_item[i], colon + 1)
        candidate_n++
        if (raw == "na") {
            nas++
            if (id != trigger_new) fail()
            candidate_id[candidate_n] = displaced
            for (j = 1; j <= 7; j++)
                candidate_organ[candidate_n, j] = removed_value[j]
        } else {
            if (!vector(raw, parsed)) fail()
            candidate_id[candidate_n] = id
            for (j = 1; j <= 7; j++)
                candidate_organ[candidate_n, j] = parsed[j]
        }
        for (j = 1; j < candidate_n; j++)
            if (candidate_id[j] == candidate_id[candidate_n]) fail()
    }
    if (nas != 1 || displaced_seen || !trigger_seen) fail()
}

BEGIN {
    FS = OFS = "\t"
    organ_weight[1] = 0.19; organ_name[1] = "perception"
    organ_weight[2] = 0.19; organ_name[2] = "expression"
    organ_weight[3] = 0.10; organ_name[3] = "own-field"
    organ_weight[4] = 0.20; organ_name[4] = "body"
    organ_weight[5] = 0.18; organ_name[5] = "rhythm"
    organ_weight[6] = 0.07; organ_name[6] = "form"
    organ_weight[7] = 0.07; organ_name[7] = "darkmatter"
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 19 || $1 != "event" || $6 != "trigger_turn" ||
            $11 != "pretrigger_sha" || $19 != "reply_equal") fail()
        next
    }
    if (NF != 19 || seen_lock[$1]++ || $2 !~ /^[ph][0-9][0-9]$/ ||
        $3 !~ /^(primary|holdout)$/) fail()
    for (i = 4; i <= 10; i++)
        if (i != 9 && !integer($i)) fail()
    if ($9 !~ /^(home|storm|wonder|social)$/) fail()
    for (i = 11; i <= 15; i++)
        if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) fail()
    for (i = 16; i <= 19; i++) if ($i != "true") fail()
    lock_life[$1] = $2; lock_split[$1] = $3; lock_seed[$1] = $4
    lock_rank[$1] = $5; lock_turn[$1] = $6; lock_session[$1] = $7
    lock_order[$1] = $8; lock_texture[$1] = $9; lock_run_seed[$1] = $10
    locks++
    next
}

FNR == 1 {
    if (NF != 20 || $1 != "event" || $11 != "displaced_id" ||
        $12 != "trigger_new_id" || $20 != "reply") fail()
    print "event", "life", "split", "trigger_turn", "texture", "organ",
          "organ_weight", "original_nearest", "original_similarity",
          "projected_nearest", "projected_similarity", "fate",
          "nearest_changed", "prompt", "reply"
    next
}

{
    if (NF != 20 || !seen_lock[$1] || seen_trigger[$1]++ ||
        $2 != lock_life[$1] || $3 != lock_split[$1] || $4 != lock_seed[$1] ||
        $5 != lock_rank[$1] || $6 != lock_turn[$1] ||
        $7 != lock_session[$1] || $8 != lock_order[$1] ||
        $9 != lock_texture[$1] || $10 != lock_run_seed[$1] ||
        !integer($11) || $11 < 1 || !integer($12) || $12 < 1 ||
        !number($13) || $13 > 0.4001 || !integer($14) ||
        $17 == "" || $18 == "" || $19 == "" || $20 == "") fail()

    parse_candidates($17, $18, $12, $11, $16)
    original_nearest = best_candidate(0)
    original_similarity = chosen_score
    if (original_nearest != $14 || absolute(original_similarity - $13) > 0.0015)
        fail()

    for (omit = 1; omit <= 7; omit++) {
        projected_nearest = best_candidate(omit)
        if (absolute(chosen_score - 0.40) < 0.002)
            fate = "boundary"
        else if (chosen_score < 0.40)
            fate = "replacement"
        else
            fate = "update"
        print $1, $2, $3, $6, $9, organ_name[omit], organ_weight[omit],
              original_nearest, sprintf("%.6f", original_similarity),
              projected_nearest, sprintf("%.6f", chosen_score), fate,
              (projected_nearest == original_nearest ? "false" : "true"),
              $19, $20
    }
    triggers++
}

END {
    if (fatal) exit 2
    if (triggers != locks || length(seen_trigger) != length(seen_lock)) fail()
}
