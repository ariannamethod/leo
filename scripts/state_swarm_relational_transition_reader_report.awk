# A.117: reread A.113's sealed relational road with A.95 proper scores.
# This reconstructs both A.79 and relational matrices from the raw receipt;
# it grants no new efficacy vote and cannot nominate from post-result tuning.

function fail(message) {
    if (message != "") print "relational-transition reporter: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }
function positive(value) { return value > 0 ? value : 0 }
function floor_overlap(value) { return value > 0.000001 ? value : 0.000001 }

function vector(value, out, count, high,    item, n, i, sum) {
    if (high == "") high = 1.0001
    delete out
    n = split(value, item, "/")
    if (n != count) fail("wrong vector width")
    sum = 0
    for (i = 1; i <= count; i++) {
        if (!number(item[i]) || item[i] + 0 < -0.000001 ||
            item[i] + 0 > high) fail("invalid vector value")
        out[i] = item[i] + 0
        sum += out[i]
    }
    return sum
}

function copy_matrix(source_matrix, destination_matrix,    i) {
    delete destination_matrix
    for (i = 1; i <= 64; i++) destination_matrix[i] = source_matrix[i]
}

function matrix_close(left, right,    i) {
    for (i = 1; i <= 64; i++)
        if (abs(left[i] - right[i]) > 0.000005) return 0
    return 1
}

function prediction(matrix, source_vector, out,    i, j, total) {
    delete out
    total = 0
    for (j = 1; j <= 8; j++) {
        out[j] = 0
        for (i = 1; i <= 8; i++)
            out[j] += source_vector[i] * matrix[(i - 1) * 8 + j]
        total += out[j]
    }
    if (total > 0)
        for (j = 1; j <= 8; j++) out[j] /= total
    return total
}

function overlap(out, target_vector,    j, value) {
    value = 0
    for (j = 1; j <= 8; j++) value += out[j] * target_vector[j]
    return value
}

function brier(out, target_vector,    j, delta, value) {
    value = 0
    for (j = 1; j <= 8; j++) {
        delta = target_vector[j] - out[j]
        value += delta * delta
    }
    return value
}

function cross_entropy(target_vector, out,    j, value, probability) {
    value = 0
    for (j = 1; j <= 8; j++) {
        probability = out[j] > 0.000001 ? out[j] : 0.000001
        value -= target_vector[j] * log(probability)
    }
    return value
}

function destination_prior(matrix, out,    i, j, total) {
    delete out
    total = 0
    for (j = 1; j <= 8; j++) {
        out[j] = 0
        for (i = 1; i <= 8; i++)
            out[j] += matrix[(i - 1) * 8 + j]
        total += out[j]
    }
    if (total > 0)
        for (j = 1; j <= 8; j++) out[j] /= total
    return total
}

function update_control(matrix, source_vector, target_vector,    i, j, k) {
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            k = (i - 1) * 8 + j
            matrix[k] = 0.997 * matrix[k] + \
                0.20 * source_vector[i] * target_vector[j]
        }
}

function update_redistributed(matrix, source_vector, target_vector,
                              prediction_overlap, gain, relation_share,
                              i, j, k, row_mass, added_mass, new_mass,
                              base_rate, rate, miss, probability) {
    miss = 1 - prediction_overlap
    if (miss < 0) miss = 0
    if (miss > 1) miss = 1
    if (relation_share < 0) relation_share = 0
    if (relation_share > 1) relation_share = 1
    for (i = 1; i <= 8; i++) {
        row_mass = 0
        for (j = 1; j <= 8; j++) {
            k = (i - 1) * 8 + j
            matrix[k] *= 0.997
            row_mass += matrix[k]
        }
        added_mass = 0.20 * source_vector[i]
        new_mass = row_mass + added_mass
        if (new_mass <= 0) continue
        if (row_mass <= 0) {
            for (j = 1; j <= 8; j++)
                matrix[(i - 1) * 8 + j] = added_mass * target_vector[j]
            continue
        }
        base_rate = added_mass / new_mass
        rate = base_rate * (1 + gain * miss * relation_share)
        if (rate > 1) rate = 1
        for (j = 1; j <= 8; j++) {
            k = (i - 1) * 8 + j
            probability = matrix[k] / row_mass
            probability += rate * (target_vector[j] - probability)
            matrix[k] = new_mass * probability
        }
    }
}

function finish_branch() {
    if (current_branch != "" && (raw_rows != 48 || score_rows != 24))
        fail("incomplete branch " current_branch)
}

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 26 || $1 != "cohort" || $5 != "rotation" ||
        $8 != "source_order" || $12 != "pre_turn" ||
        $15 != "transition" || $22 != "target" ||
        $26 != "has_prediction") fail("bad header")
    print "cohort", "life", "split", "candidate_order", "rotation", \
        "session", "order", "source_order", "texture", "eligible", \
        "reason", "gap_relief", "distress_relief", "semantic_share", \
        "raw_surprise", "ungated_surprise", "candidate_surprise", \
        "surprise_gain", "candidate_over_ungated_surprise", \
        "raw_brier", "ungated_brier", "candidate_brier", "brier_gain", \
        "candidate_over_ungated_brier", "candidate_ce", \
        "candidate_prior_ce", "candidate_prior_ce_gain", \
        "candidate_prior_brier_gain", "raw_ce", "raw_prior_ce", \
        "raw_prior_ce_gain", "raw_prior_brier_gain", \
        "candidate_over_raw_ce", "candidate_over_raw_brier"
    next
}

{
    if (NF != 26 || $1 != "validation" ||
        $2 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $3 !~ /^(primary|holdout)$/ || !integer($4) ||
        !integer($5) || $5 < 0 || $5 > 7 ||
        !integer($6) || $6 < 1 || $6 > 6 ||
        !integer($7) || $7 < 1 || $7 > 8 ||
        !integer($8) || $8 < 1 || $8 > 8 ||
        $9 !~ /^(home|storm|wonder|social)$/ ||
        $10 !~ /^(updated|born|replaced)$/ || $11 == "" ||
        !integer($12) || !integer($20) || $20 != $12 + 1 ||
        !number($16) || $16 < 0 ||
        !number($17) || $17 < 0 || $17 > 1.0001 ||
        !number($18) || $18 < 0 || $18 > 1.0001 ||
        !number($19) || $19 < 0 || $19 > 1.0001 ||
        !number($23) || $23 < 0 || $23 > 1.0001 ||
        !number($24) || $24 < 0 || $24 > 1.0001 ||
        !number($25) || $25 < 0 || $25 > 1.0001 ||
        ($26 != 0 && $26 != 1)) fail("invalid row")
    if (($3 == "primary" && ($4 < 36 || $4 > 40)) ||
        ($3 == "holdout" && ($4 < 75 || $4 > 80)))
        fail("invalid overflow identity")

    matrix_sum = vector($15, observed_matrix, 64, 1000000.0001)
    source_sum = vector($14, source, 8)
    target_sum = vector($22, target, 8)
    if (abs(matrix_sum - $16) > 0.0001 ||
        abs(source_sum - 1) > 0.00001 || abs(target_sum - 1) > 0.00001)
        fail("geometry total mismatch")

    branch = $2 SUBSEP $5
    if (branch != current_branch) {
        finish_branch()
        if (seen_branch[branch]++) fail("noncontiguous branch")
        current_branch = branch
        current_life = $2
        current_split = $3
        current_candidate_order = $4
        current_rotation = $5
        raw_rows = score_rows = 0
        expected_session = 1
        expected_order = 1
        copy_matrix(observed_matrix, control_matrix)
        copy_matrix(observed_matrix, ungated_matrix)
        copy_matrix(observed_matrix, candidate_matrix)
        compare_next = 1
    } else if ($2 != current_life || $3 != current_split ||
               $4 != current_candidate_order || $5 != current_rotation)
        fail("branch identity drift")

    if ($6 != expected_session || $7 != expected_order)
        fail("nonchronological branch")
    expected_order++
    if (expected_order == 9) { expected_order = 1; expected_session++ }
    raw_rows++

    if (raw_rows > 1) {
        if (compare_next) {
            if (!matrix_close(observed_matrix, control_matrix))
                fail("control replay drift")
        } else {
            copy_matrix(observed_matrix, control_matrix)
            copy_matrix(observed_matrix, ungated_matrix)
            copy_matrix(observed_matrix, candidate_matrix)
        }
    }

    raw_total = prediction(observed_matrix, source, raw_prediction)
    ungated_total = prediction(ungated_matrix, source, ungated_prediction)
    candidate_total = prediction(candidate_matrix, source,
                                 candidate_prediction)
    raw_has_prediction = raw_total > 0 ? 1 : 0
    if (raw_has_prediction != $26) fail("runtime prediction flag mismatch")

    raw_overlap = overlap(raw_prediction, target)
    ungated_overlap = overlap(ungated_prediction, target)
    candidate_overlap = overlap(candidate_prediction, target)
    raw_surprise = raw_has_prediction ? -log(floor_overlap(raw_overlap)) : 0
    ungated_surprise = ungated_total > 0 ? \
        -log(floor_overlap(ungated_overlap)) : 0
    candidate_surprise = candidate_total > 0 ? \
        -log(floor_overlap(candidate_overlap)) : 0
    raw_brier = raw_has_prediction ? brier(raw_prediction, target) : 0
    ungated_brier = ungated_total > 0 ? brier(ungated_prediction, target) : 0
    candidate_brier = candidate_total > 0 ? \
        brier(candidate_prediction, target) : 0
    candidate_prior_total = destination_prior(candidate_matrix,
                                               candidate_prior)
    candidate_ce = candidate_total > 0 ? \
        cross_entropy(target, candidate_prediction) : 0
    candidate_prior_ce = candidate_prior_total > 0 ? \
        cross_entropy(target, candidate_prior) : 0
    candidate_prior_brier = candidate_prior_total > 0 ? \
        brier(candidate_prior, target) : 0
    raw_prior_total = destination_prior(observed_matrix, raw_prior)
    raw_ce = raw_total > 0 ? cross_entropy(target, raw_prediction) : 0
    raw_prior_ce = raw_prior_total > 0 ? \
        cross_entropy(target, raw_prior) : 0
    raw_prior_brier = raw_prior_total > 0 ? brier(raw_prior, target) : 0

    gap_relief = $17 - $23
    distress_relief = $18 - $24
    positive_distress = positive(distress_relief)
    semantic_share = 0
    if (gap_relief > 0) {
        denominator = gap_relief > positive_distress ? \
            gap_relief : positive_distress
        if (denominator > 0) semantic_share = gap_relief / denominator
    }

    same_topology = $13 == $21
    if ($6 >= 4) {
        eligible = 1
        reason = "none"
        if ($10 != "updated") { eligible = 0; reason = "event" }
        else if (!same_topology) { eligible = 0; reason = "topology" }
        else if (!raw_has_prediction || !ungated_total || !candidate_total) {
            eligible = 0; reason = "forecast"
        }
        print $1, $2, $3, $4, $5, $6, $7, $8, $9, eligible, reason, \
            sprintf("%.9f", gap_relief), sprintf("%.9f", distress_relief), \
            sprintf("%.9f", semantic_share), sprintf("%.9f", raw_surprise), \
            sprintf("%.9f", ungated_surprise), \
            sprintf("%.9f", candidate_surprise), \
            sprintf("%.9f", raw_surprise - candidate_surprise), \
            sprintf("%.9f", ungated_surprise - candidate_surprise), \
            sprintf("%.9f", raw_brier), sprintf("%.9f", ungated_brier), \
            sprintf("%.9f", candidate_brier), \
            sprintf("%.9f", raw_brier - candidate_brier), \
            sprintf("%.9f", ungated_brier - candidate_brier), \
            sprintf("%.9f", candidate_ce), \
            sprintf("%.9f", candidate_prior_ce), \
            sprintf("%.9f", candidate_prior_ce - candidate_ce), \
            sprintf("%.9f", candidate_prior_brier - candidate_brier), \
            sprintf("%.9f", raw_ce), sprintf("%.9f", raw_prior_ce), \
            sprintf("%.9f", raw_prior_ce - raw_ce), \
            sprintf("%.9f", raw_prior_brier - raw_brier), \
            sprintf("%.9f", raw_ce - candidate_ce), \
            sprintf("%.9f", raw_brier - candidate_brier)
        score_rows++
    }

    if ($10 == "updated" && same_topology) {
        update_control(control_matrix, source, target)
        update_redistributed(ungated_matrix, source, target,
                             ungated_overlap, 0.25, 1.0)
        update_redistributed(candidate_matrix, source, target,
                             candidate_overlap, 0.50, semantic_share)
        compare_next = 1
    } else compare_next = 0
}

END {
    if (fatal) exit 2
    finish_branch()
    if (length(seen_branch) != 88) fail("wrong branch count")
}
