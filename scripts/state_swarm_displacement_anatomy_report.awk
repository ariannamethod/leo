# A.86: classify fate stability under seven leave-one-organ-out projections.

function fail() {
    fatal = 1
    exit 2
}

function number(value) {
    return value ~ /^-?[0-9]+([.][0-9]+)?$/
}

function unsigned_number(value) {
    return value ~ /^[0-9]+$/
}

function abs(value) {
    return value < 0 ? -value : value
}

function member_mass(value, wanted,    item, pair, n, i) {
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split(item[i], pair, ":")
        if (pair[1] + 0 == wanted) return pair[2] + 0
    }
    return 0
}

function member_present(value, wanted,    item, pair, n, i) {
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split(item[i], pair, ":")
        if (pair[1] + 0 == wanted) return 1
    }
    return 0
}

function other_max(value, wanted,    item, pair, n, i, best, mass) {
    best = 0
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split(item[i], pair, ":")
        mass = pair[2] + 0
        if (pair[1] + 0 != wanted && mass > best) best = mass
    }
    return best
}

function parse_vector(value, target,    part, n, i) {
    n = split(value, part, "/")
    if (n != 7) fail()
    for (i = 1; i <= 7; i++) {
        if (!number(part[i]) || part[i] + 0 < 0 || part[i] + 0 > 1.001)
            fail()
        target[i] = part[i] + 0
    }
}

function candidate_score(slot, omit,    organ, total, retained) {
    total = 0
    retained = 0
    for (organ = 1; organ <= 7; organ++) {
        if (organ == omit) continue
        total += organ_weight[organ] * candidate_organ[slot, organ]
        retained += organ_weight[organ]
    }
    return retained > 0 ? total / retained : 0
}

function best_candidate(omit,    i, score, best_score) {
    chosen_index = 0
    best_score = -1
    for (i = 1; i <= candidate_n; i++) {
        score = candidate_score(i, omit)
        if (score > best_score + 0.0000001) {
            best_score = score
            chosen_index = i
        }
    }
    chosen_score = best_score
    return candidate_id[chosen_index]
}

function classify_projection(omit, trigger_new,    winner_id) {
    winner_id = best_candidate(omit)
    if (abs(chosen_score - 0.40) < 0.002) return "boundary"
    if (chosen_score < 0.40) return "rebirth"
    return winner_id == trigger_new ? "trigger-capture" : "survivor-return"
}

function parse_candidates(members, event, winner, replaced, removed_raw,
                          organs,    member_item, organ_item, n, i, j,
                          colon, member_id, organ_id, raw, invalid,
                          removed_value) {
    for (i = 1; i <= candidate_n; i++) {
        candidate_id[i] = 0
        for (j = 1; j <= 7; j++) candidate_organ[i, j] = 0
    }
    candidate_n = 0
    n = split(members, member_item, ",")
    if (n != 8 || split(organs, organ_item, ",") != n) fail()
    if (event == "replaced") parse_vector(removed_raw, removed_value)
    invalid = 0
    for (i = 1; i <= n; i++) {
        colon = index(member_item[i], ":")
        if (!colon) fail()
        member_id = substr(member_item[i], 1, colon - 1)
        if (!unsigned_number(member_id) || member_id < 1) fail()
        colon = index(organ_item[i], ":")
        if (!colon) fail()
        organ_id = substr(organ_item[i], 1, colon - 1)
        raw = substr(organ_item[i], colon + 1)
        if (organ_id != member_id) fail()
        candidate_n++
        if (raw == "na") {
            invalid++
            if (event != "replaced" || member_id != winner || replaced < 1)
                fail()
            candidate_id[candidate_n] = replaced
            for (j = 1; j <= 7; j++)
                candidate_organ[candidate_n, j] = removed_value[j]
        } else {
            candidate_id[candidate_n] = member_id
            parse_vector(raw, parsed_value)
            for (j = 1; j <= 7; j++)
                candidate_organ[candidate_n, j] = parsed_value[j]
        }
        for (j = 1; j < candidate_n; j++)
            if (candidate_id[j] == candidate_id[candidate_n]) fail()
    }
    if ((event == "updated" && invalid != 0) ||
        (event == "replaced" && invalid != 1)) fail()
}

BEGIN {
    FS = "\t"
    OFS = "\t"
    organ_weight[1] = 0.19; organ_name[1] = "perception"
    organ_weight[2] = 0.19; organ_name[2] = "expression"
    organ_weight[3] = 0.10; organ_name[3] = "own-field"
    organ_weight[4] = 0.20; organ_name[4] = "body"
    organ_weight[5] = 0.18; organ_name[5] = "rhythm"
    organ_weight[6] = 0.07; organ_name[6] = "form"
    organ_weight[7] = 0.07; organ_name[7] = "darkmatter"
    print "event", "life", "split", "settled", "base_seed",
          "trigger_turn", "displaced_id", "trigger_new_id", "probe",
          "kind", "control_old_mass", "control_margin", "qualified",
          "fate", "nearest_id", "nearest_similarity", "without_perception",
          "without_expression", "without_own_field", "without_body",
          "without_rhythm", "without_form", "without_darkmatter",
          "stable_organs", "robust", "flip_organs", "prompt", "reply"
}

NR == 1 { next }
{
    if (NF != 33 || $1 == "" || $2 !~ /^h[0-9][0-9]$/ ||
        $3 != "holdout" || ($4 != "true" && $4 != "false") ||
        !unsigned_number($5) || !unsigned_number($6) ||
        !unsigned_number($7) || !unsigned_number($8) ||
        $9 !~ /^[12]$/ || $10 !~ /^(exact-birth|exact-anchor)$/ ||
        !unsigned_number($11) || $12 != $6 + 1 || $22 != $12 ||
        $13 !~ /^(updated|replaced)$/ ||
        $23 !~ /^(updated|replaced)$/ || $32 == "" || $33 == "") fail()

    old_mass = member_mass($16, $7)
    margin = old_mass - other_max($16, $7)
    qualified = $13 == "updated" && $14 == $7 &&
                old_mass >= 0.20 && margin >= 0.02
    if (member_present($26, $7)) fail()

    if ($23 == "replaced") fate = "rebirth"
    else if ($24 == $8) fate = "trigger-capture"
    else fate = "survivor-return"

    parse_candidates($26, $23, $24, $27, $30, $31)
    parse_vector($29, nearest_value)
    nearest_score = 0
    for (organ = 1; organ <= 7; organ++)
        nearest_score += organ_weight[organ] * nearest_value[organ]
    if (abs(nearest_score - $25) > 0.0015) fail()
    best_id = best_candidate(0)
    if (best_id != $28 || abs(chosen_score - nearest_score) > 0.0015) fail()
    if (($23 == "updated" && ($24 != $28 || chosen_score < 0.398)) ||
        ($23 == "replaced" && chosen_score > 0.4001)) fail()

    stable = 0
    flips = ""
    for (organ = 1; organ <= 7; organ++) {
        projected[organ] = classify_projection(organ, $8)
        if (projected[organ] == fate) stable++
        else flips = flips (flips ? "," : "") organ_name[organ] ":" projected[organ]
    }
    if (!flips) flips = "none"
    robust = stable >= 6

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.6f\t%.6f\t%s\t%s\t%s\t%.6f",
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
           old_mass, margin, qualified ? "true" : "false", fate, $28, $25
    for (organ = 1; organ <= 7; organ++) printf "\t%s", projected[organ]
    printf "\t%d\t%s\t%s\t%s\t%s\n", stable,
           robust ? "true" : "false", flips, $32, $33
}

END {
    if (fatal) exit 2
}
