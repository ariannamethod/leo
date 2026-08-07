# A.91: apply the same frozen seven-organ anatomy to events and controls.

function fail() {
    print "invalid A.91 observation/projection at line " NR > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) {
    return value ~ /^[0-9]+$/
}

function number(value) {
    return value ~ /^-?[0-9]+([.][0-9]+)?$/
}

function absolute(value) {
    return value < 0 ? -value : value
}

function vector(value, target,    part, n, i) {
    delete target
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

function parse_candidates(members, organs, event, winner, displaced, removed,
                          member, organ_item, member_n, organ_n, i, j, colon,
                          id, activation, raw, nas, winner_seen, displaced_seen,
                          parsed) {
    delete candidate_id
    delete candidate_organ
    candidate_n = 0
    member_n = split(members, member, ",")
    organ_n = split(organs, organ_item, ",")
    if (member_n != 8 || organ_n != member_n) fail()
    if (event == "replaced") {
        if (!integer(displaced) || displaced < 1 || !vector(removed, removed_value))
            fail()
    } else if (displaced != 0 || removed != "na") fail()

    for (i = 1; i <= member_n; i++) {
        colon = index(member[i], ":")
        if (!colon) fail()
        id = substr(member[i], 1, colon - 1)
        activation = substr(member[i], colon + 1)
        if (!integer(id) || id < 1 || !number(activation) ||
            activation < 0 || activation > 1.001) fail()
        if (id == winner) winner_seen = 1
        if (id == displaced) displaced_seen = 1

        colon = index(organ_item[i], ":")
        if (!colon || substr(organ_item[i], 1, colon - 1) != id) fail()
        raw = substr(organ_item[i], colon + 1)
        candidate_n++
        if (raw == "na") {
            nas++
            if (event != "replaced" || id != winner) fail()
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
    if (!winner_seen) fail()
    if (event == "replaced") {
        if (nas != 1 || displaced_seen) fail()
    } else if (nas != 0) fail()
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

NR == 1 {
    if (NF != 31 || $1 != "observation" || $3 != "family" ||
        $13 != "event" || $18 != "nearest_organs" || $21 != "organs" ||
        $28 != "state_equal" || $31 != "reply_equal") fail()
    print "observation", "pair", "family", "source_id", "life", "split",
          "turn", "texture", "organ", "organ_weight", "original_nearest",
          "original_similarity", "nearest_organ_similarity",
          "projected_nearest", "projected_similarity", "delta", "fate",
          "nearest_changed", "prompt", "reply"
    next
}

{
    if (NF != 31 || seen_observation[$1]++ || $2 !~ /^[0-9][0-9]$/ ||
        $3 !~ /^(event|organism|ecology)$/ || $4 == "" ||
        $5 !~ /^[ph][0-9][0-9]$/ || $6 !~ /^(primary|holdout)$/ ||
        !integer($7) || !integer($8) || !integer($9) || !integer($10) ||
        $11 !~ /^(home|storm|wonder|social)$/ || !integer($12) ||
        $13 !~ /^(replaced|updated)$/ || !number($14) ||
        !integer($15) || !integer($16) || !integer($17) ||
        $20 == "" || $21 == "" || $22 == "" || $23 == "") fail()
    for (i = 25; i <= 27; i++)
        if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) fail()
    for (i = 28; i <= 31; i++) if ($i != "true") fail()
    if (($3 == "event" && $13 != "replaced") ||
        ($3 != "event" && $13 != "updated")) fail()

    parse_candidates($20, $21, $13, $15, $16, $19)
    if (!vector($18, nearest_value)) fail()
    original_nearest = best_candidate(0)
    original_similarity = chosen_score
    if (original_nearest != $17 || absolute(original_similarity - $14) > 0.0015)
        fail()
    nearest_slot = chosen_slot
    for (organ = 1; organ <= 7; organ++)
        if (absolute(candidate_organ[nearest_slot, organ] - nearest_value[organ]) > 0.000001)
            fail()

    for (omit = 1; omit <= 7; omit++) {
        projected_nearest = best_candidate(omit)
        projected_similarity = chosen_score
        if (absolute(projected_similarity - 0.40) < 0.002)
            fate = "boundary"
        else if (projected_similarity < 0.40)
            fate = "replacement"
        else
            fate = "update"
        nearest_changed = projected_nearest == original_nearest ? "false" : "true"
        print $1, $2, $3, $4, $5, $6, $8, $11, organ_name[omit],
              organ_weight[omit], original_nearest,
              sprintf("%.6f", original_similarity),
              sprintf("%.6f", nearest_value[omit]), projected_nearest,
              sprintf("%.6f", projected_similarity),
              sprintf("%.6f", projected_similarity - original_similarity),
              fate, nearest_changed, $22, $23
    }
    family_count[$3]++
    observations++
}

END {
    if (fatal) exit 2
    if (observations != expected * 3 || family_count["event"] != expected ||
        family_count["organism"] != expected || family_count["ecology"] != expected)
        fail()
}
