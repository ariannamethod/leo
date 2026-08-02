# A.82: readerless held-out classification of state texture and temporal order.

function parse_members(value, cell, turn,    item, n, i, split_at, id, mass) {
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split_at = index(item[i], ":")
        if (!split_at) exit 2
        id = substr(item[i], 1, split_at - 1) + 0
        mass = substr(item[i], split_at + 1) + 0
        activation[cell SUBSEP turn SUBSEP id] = mass
        if (id > max_id[cell]) max_id[cell] = id
    }
}

function texture_similarity(cell, label, turn,    id, p, q, total) {
    total = 0
    for (id = 1; id <= max_id[cell]; id++) {
        p = texture_mass[cell SUBSEP label SUBSEP id] / texture_count[cell SUBSEP label]
        q = activation[cell SUBSEP turn SUBSEP id]
        if (p > 0 && q > 0) total += sqrt(p * q)
    }
    return total
}

function position_similarity(cell, position, turn,    id, p, q, total) {
    total = 0
    for (id = 1; id <= max_id[cell]; id++) {
        p = position_mass[cell SUBSEP position SUBSEP id] / position_count[cell SUBSEP position]
        q = activation[cell SUBSEP turn SUBSEP id]
        if (p > 0 && q > 0) total += sqrt(p * q)
    }
    return total
}

function joint_similarity(cell, label, position, turn,    id, p, q, total) {
    total = 0
    for (id = 1; id <= max_id[cell]; id++) {
        p = joint_mass[cell SUBSEP label SUBSEP position SUBSEP id]
        q = activation[cell SUBSEP turn SUBSEP id]
        if (p > 0 && q > 0) total += sqrt(p * q)
    }
    return total
}

function abs(value) { return value < 0 ? -value : value }

BEGIN {
    FS = "\t"
    OFS = "\t"
    texture_name[1] = "home"
    texture_name[2] = "storm"
    texture_name[3] = "wonder"
    texture_name[4] = "social"
}

NR == 1 { next }
$4 != "writer" { next }
{
    cell = $1
    cohort[cell] = $2
    seed[cell] = $3
    session = $5 + 0
    position = $6 + 0
    texture = $7
    turn = ++turns[cell]
    if (turn + turn_offset != $9 + 0 || session < 1 || session > 8 ||
        position < 1 || position > 8)
        exit 2
    parse_members($16, cell, turn)

    if ($13 == "born") {
        if (session <= 4) acquisition_births[cell]++
        else holdout_births[cell]++
    } else if ($13 == "replaced") {
        if (session <= 4) acquisition_replacements[cell]++
        else holdout_replacements[cell]++
    } else if ($13 != "updated") {
        exit 2
    }

    if (session <= 4) {
        texture_count[cell SUBSEP texture]++
        position_count[cell SUBSEP position]++
        joint_count[cell SUBSEP texture SUBSEP position]++
        for (id = 1; id <= max_id[cell]; id++) {
            mass = activation[cell SUBSEP turn SUBSEP id]
            texture_mass[cell SUBSEP texture SUBSEP id] += mass
            position_mass[cell SUBSEP position SUBSEP id] += mass
            joint_mass[cell SUBSEP texture SUBSEP position SUBSEP id] += mass
        }
        next
    }

    holdout[cell]++
    best_texture = ""
    best_texture_score = -1
    best_other_texture = -1
    texture_tie = 0
    for (candidate = 1; candidate <= 4; candidate++) {
        label = texture_name[candidate]
        score = texture_similarity(cell, label, turn)
        if (label == texture) true_texture_score = score
        else if (score > best_other_texture) best_other_texture = score
        if (score > best_texture_score + 0.0000001) {
            best_texture_score = score
            best_texture = label
            texture_tie = 0
        } else if (abs(score - best_texture_score) <= 0.0000001) {
            texture_tie = 1
        }
    }
    if (!texture_tie && best_texture == texture) texture_hit[cell]++
    texture_margin[cell] += true_texture_score - best_other_texture
    texture_similarity_sum[cell] += true_texture_score

    best_position = 0
    best_position_score = -1
    best_other_position = -1
    position_tie = 0
    for (candidate = 1; candidate <= 8; candidate++) {
        score = position_similarity(cell, candidate, turn)
        if (candidate == position) true_position_score = score
        else if (score > best_other_position) best_other_position = score
        if (score > best_position_score + 0.0000001) {
            best_position_score = score
            best_position = candidate
            position_tie = 0
        } else if (abs(score - best_position_score) <= 0.0000001) {
            position_tie = 1
        }
    }
    if (!position_tie && best_position == position) position_hit[cell]++
    position_margin[cell] += true_position_score - best_other_position
    position_similarity_sum[cell] += true_position_score

    best_joint_texture = ""
    best_joint_position = 0
    best_joint_score = -1
    best_other_joint = -1
    joint_tie = 0
    for (candidate = 1; candidate <= 4; candidate++) {
        label = texture_name[candidate]
        for (candidate_position = 1; candidate_position <= 8; candidate_position++) {
            score = joint_similarity(cell, label, candidate_position, turn)
            if (label == texture && candidate_position == position)
                true_joint_score = score
            else if (score > best_other_joint) best_other_joint = score
            if (score > best_joint_score + 0.0000001) {
                best_joint_score = score
                best_joint_texture = label
                best_joint_position = candidate_position
                joint_tie = 0
            } else if (abs(score - best_joint_score) <= 0.0000001) {
                joint_tie = 1
            }
        }
    }
    if (!joint_tie && best_joint_texture == texture &&
        best_joint_position == position)
        joint_hit[cell]++
    joint_margin[cell] += true_joint_score - best_other_joint
    joint_similarity_sum[cell] += true_joint_score
    final_states[cell] = $10 + 0
}

END {
    if (turns["river"] != 64 || turns["window"] != 64 ||
        turns["lantern"] != 64 || length(turns) != 3)
        exit 2
    for (cell in turns) {
        for (candidate = 1; candidate <= 4; candidate++) {
            label = texture_name[candidate]
            if (texture_count[cell SUBSEP label] != 8) exit 2
            for (position = 1; position <= 8; position++)
                if (joint_count[cell SUBSEP label SUBSEP position] != 1)
                    exit 2
        }
        for (position = 1; position <= 8; position++)
            if (position_count[cell SUBSEP position] != 4) exit 2
        if (holdout[cell] != 32) exit 2

        texture_accuracy = texture_hit[cell] / holdout[cell]
        position_accuracy = position_hit[cell] / holdout[cell]
        joint_accuracy = joint_hit[cell] / holdout[cell]
        texture_mean_margin = texture_margin[cell] / holdout[cell]
        position_mean_margin = position_margin[cell] / holdout[cell]
        joint_mean_margin = joint_margin[cell] / holdout[cell]
        texture_pass = texture_accuracy >= 0.50 && texture_mean_margin >= 0.02
        position_pass = position_accuracy >= 0.25 && position_mean_margin >= 0.01
        joint_pass = joint_accuracy >= 0.125 && joint_mean_margin >= 0.005

        if (holdout_births[cell] > 1 || holdout_replacements[cell] > 0)
            verdict = "unstable-geometry"
        else if (texture_pass && position_pass) verdict = "factorized"
        else if (texture_pass) verdict = "texture-alphabet"
        else if (position_pass) verdict = "order-alphabet"
        else if (joint_pass) verdict = "entangled"
        else verdict = "unformed"

        printf "%s\t%s\t%s\t%d\t%d\t%.6f\t%.6f\t%.6f\t%d\t%.6f\t%.6f\t%.6f\t%d\t%.6f\t%.6f\t%.6f\t%d\t%d\t%d\t%d\t%d\t%s\n",
               cell, cohort[cell], seed[cell], holdout[cell],
               texture_hit[cell] + 0, texture_accuracy,
               texture_mean_margin, texture_similarity_sum[cell] / holdout[cell],
               position_hit[cell] + 0, position_accuracy,
               position_mean_margin, position_similarity_sum[cell] / holdout[cell],
               joint_hit[cell] + 0, joint_accuracy, joint_mean_margin,
               joint_similarity_sum[cell] / holdout[cell], final_states[cell],
               acquisition_births[cell] + 0, holdout_births[cell] + 0,
               acquisition_replacements[cell] + 0,
               holdout_replacements[cell] + 0, verdict
    }
}
