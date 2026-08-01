# A.83: readerless held-out classification from each similarity organ alone.

function numeric(value) {
    return value ~ /^-?[0-9]+([.][0-9]+)?$/
}

function clear_group(    key) {
    for (key in current_id) delete current_id[key]
    for (key in current_similarity) delete current_similarity[key]
    current_members = 0
    current_invalid = 0
}

function texture_similarity(cell, organ, label,    id, p, q, sum) {
    sum = 0.0
    for (id = 1; id <= max_id[cell]; id++) {
        p = texture_proto[cell, organ, label, id] / texture_count[cell, organ, label]
        q = current_activation[organ, id] + 0.0
        sum += sqrt(p * q)
    }
    return sum
}

function position_similarity(cell, organ, label,    id, p, q, sum) {
    sum = 0.0
    for (id = 1; id <= max_id[cell]; id++) {
        p = position_proto[cell, organ, label, id] / position_count[cell, organ, label]
        q = current_activation[organ, id] + 0.0
        sum += sqrt(p * q)
    }
    return sum
}

function process_group(    organ, i, id, value, maximum, total, activation,
                           label, score, correct, best_other) {
    if (!have_group) return
    if (current_members != group_states) exit 2
    if (group_session <= 4) {
        for (organ = 1; organ <= 7; organ++)
            if (current_invalid) acquisition_excluded[group_cell, organ]++
    } else {
        for (organ = 1; organ <= 7; organ++)
            if (current_invalid) holdout_excluded[group_cell, organ]++
    }
    if (current_invalid) return

    for (organ = 1; organ <= 7; organ++) {
        maximum = -1.0
        for (i = 1; i <= current_members; i++) {
            id = current_id[i]
            value = current_similarity[organ, id]
            if (value > maximum) maximum = value
        }
        total = 0.0
        for (i = 1; i <= current_members; i++) {
            id = current_id[i]
            activation = exp((current_similarity[organ, id] - maximum) / 0.12)
            current_activation[organ, id] = activation
            total += activation
        }
        if (total <= 0.0) exit 2
        for (i = 1; i <= current_members; i++) {
            id = current_id[i]
            current_activation[organ, id] /= total
        }

        if (group_session <= 4) {
            acquisition_turns[group_cell, organ]++
            texture_count[group_cell, organ, group_texture]++
            position_count[group_cell, organ, group_order]++
            for (i = 1; i <= current_members; i++) {
                id = current_id[i]
                activation = current_activation[organ, id]
                texture_proto[group_cell, organ, group_texture, id] += activation
                position_proto[group_cell, organ, group_order, id] += activation
            }
            continue
        }

        holdout_turns[group_cell, organ]++
        correct = texture_similarity(group_cell, organ, group_texture)
        best_other = -1.0
        for (label = 1; label <= 4; label++) {
            score = texture_similarity(group_cell, organ, texture_name[label])
            if (texture_name[label] != group_texture && score > best_other)
                best_other = score
        }
        if (correct > best_other + 1e-9) texture_hits[group_cell, organ]++
        texture_margin[group_cell, organ] += correct - best_other
        texture_similarity_sum[group_cell, organ] += correct

        correct = position_similarity(group_cell, organ, group_order)
        best_other = -1.0
        for (label = 1; label <= 8; label++) {
            score = position_similarity(group_cell, organ, label)
            if (label != group_order && score > best_other) best_other = score
        }
        if (correct > best_other + 1e-9) position_hits[group_cell, organ]++
        position_margin[group_cell, organ] += correct - best_other
        position_similarity_sum[group_cell, organ] += correct
    }
    for (i in current_activation) delete current_activation[i]
}

BEGIN {
    FS = OFS = "\t"
    texture_name[1] = "home"
    texture_name[2] = "storm"
    texture_name[3] = "wonder"
    texture_name[4] = "social"
    organ_name[1] = "perception"
    organ_name[2] = "expression"
    organ_name[3] = "own-field"
    organ_name[4] = "body"
    organ_name[5] = "rhythm"
    organ_name[6] = "form"
    organ_name[7] = "darkmatter"
}

NR == 1 {
    if (NF != 23 || $1 != "cell" || $4 != "phase" || $9 != "turn" ||
        $12 != "member_id" || $14 != "organ_valid" ||
        $15 != "perception" || $21 != "darkmatter" || $23 != "reply")
        exit 2
    next
}

{
    if (NF != 23 || $4 != "writer" || $5 !~ /^[0-9]+$/ ||
        $6 !~ /^[0-9]+$/ || $6 < 1 || $6 > 8 ||
        $7 !~ /^(home|storm|wonder|social)$/ || $9 !~ /^[0-9]+$/ ||
        $11 !~ /^[0-9]+$/ || $11 < 1 || $11 > 8 ||
        $12 !~ /^[0-9]+$/ || ($14 != 0 && $14 != 1)) exit 2
    key = $1 SUBSEP $9
    if (have_group && key != group_key) {
        process_group()
        clear_group()
    }
    if (!have_group || key != group_key) {
        have_group = 1
        group_key = key
        group_cell = $1
        group_cohort = $2
        group_seed = $3
        group_session = $5 + 0
        group_order = $6 + 0
        group_texture = $7
        group_states = $11 + 0
        cells[$1] = 1
        cohort[$1] = $2
        seed[$1] = $3
    } else if ($1 != group_cell || $2 != group_cohort || $3 != group_seed ||
               $5 + 0 != group_session || $6 + 0 != group_order ||
               $7 != group_texture || $11 + 0 != group_states) exit 2

    id = $12 + 0
    for (i = 1; i <= current_members; i++) if (current_id[i] == id) exit 2
    current_id[++current_members] = id
    if (id > max_id[$1]) max_id[$1] = id
    if ($14 == 0) {
        current_invalid++
        for (organ = 1; organ <= 7; organ++)
            if ($(14 + organ) != "na") exit 2
    } else {
        for (organ = 1; organ <= 7; organ++) {
            value = $(14 + organ)
            if (!numeric(value) || value < 0 || value > 1.001) exit 2
            current_similarity[organ, id] = value + 0.0
        }
    }
}

END {
    if (NR < 2) exit 2
    process_group()
    for (cell in cells) {
        for (organ = 1; organ <= 7; organ++) {
            min_texture = 1000000
            for (label = 1; label <= 4; label++) {
                count = texture_count[cell, organ, texture_name[label]] + 0
                if (count < min_texture) min_texture = count
            }
            min_position = 1000000
            for (label = 1; label <= 8; label++) {
                count = position_count[cell, organ, label] + 0
                if (count < min_position) min_position = count
            }
            held = holdout_turns[cell, organ] + 0
            texture_accuracy = held ? texture_hits[cell, organ] / held : 0
            position_accuracy = held ? position_hits[cell, organ] / held : 0
            texture_mean_margin = held ? texture_margin[cell, organ] / held : 0
            position_mean_margin = held ? position_margin[cell, organ] / held : 0
            texture_pass = texture_accuracy >= 0.50 &&
                           texture_mean_margin >= 0.02
            position_pass = position_accuracy >= 0.25 &&
                            position_mean_margin >= 0.01
            texture_sufficient = held == 32 &&
                                 holdout_excluded[cell, organ] == 0 &&
                                 min_texture >= 4
            position_sufficient = held == 32 &&
                                  holdout_excluded[cell, organ] == 0 &&
                                  min_position >= 2
            texture_pass = texture_sufficient && texture_pass
            position_pass = position_sufficient && position_pass
            if (!texture_sufficient && !position_sufficient)
                verdict = "insufficient"
            else if (texture_pass && position_pass) verdict = "factorized"
            else if (texture_pass) verdict = "texture-bearing"
            else if (position_pass) verdict = "position-bearing"
            else if (!texture_sufficient) verdict = "texture-insufficient"
            else if (!position_sufficient) verdict = "position-insufficient"
            else verdict = "unformed"
            printf "%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%.6f\t%d\t%.6f\t%.6f\t%.6f\t%s\n",
                   cell, cohort[cell], seed[cell], organ_name[organ],
                   acquisition_turns[cell, organ] + 0,
                   acquisition_excluded[cell, organ] + 0,
                   min_texture, min_position, held,
                   holdout_excluded[cell, organ] + 0,
                   texture_hits[cell, organ] + 0, texture_accuracy,
                   texture_mean_margin,
                   held ? texture_similarity_sum[cell, organ] / held : 0,
                   position_hits[cell, organ] + 0, position_accuracy,
                   position_mean_margin,
                   held ? position_similarity_sum[cell, organ] / held : 0,
                   verdict
        }
    }
}
