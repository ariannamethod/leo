# A.112: replay one bounded redistribution law without changing Leo.

function fail(message) {
    if (message != "") print "transition-redistribution reporter: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }

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

function update_control(matrix, source_vector, target_vector,    i, j, k) {
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            k = (i - 1) * 8 + j
            matrix[k] = 0.997 * matrix[k] + \
                0.20 * source_vector[i] * target_vector[j]
        }
}

function update_candidate(matrix, source_vector, target_vector,
                          prediction_overlap,    i, j, k, row_mass,
                          added_mass, new_mass, base_rate, rate, miss,
                          probability) {
    miss = 1 - prediction_overlap
    if (miss < 0) miss = 0
    if (miss > 1) miss = 1
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
        rate = base_rate * (1 + 0.25 * miss)
        if (rate > 1) rate = 1
        for (j = 1; j <= 8; j++) {
            k = (i - 1) * 8 + j
            probability = matrix[k] / row_mass
            probability += rate * (target_vector[j] - probability)
            matrix[k] = new_mass * probability
        }
    }
}

function finish_life() {
    if (current_life != "" && (raw_rows != 48 || score_rows != 24))
        fail("incomplete life " current_life)
}

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 20 || $1 != "cohort" || $5 != "rotation" ||
        $8 != "source_order" || $12 != "pre_turn" ||
        $15 != "transition" || $19 != "target" ||
        $20 != "has_prediction") fail("bad header")
    print "cohort", "life", "split", "rank", "rotation", "session", \
        "order", "source_order", "texture", "eligible", "reason", \
        "raw_surprise", "candidate_surprise", "surprise_gain", \
        "raw_brier", "candidate_brier", "brier_gain"
    next
}

{
    if (NF != 20 || $1 != "discovery" ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        !integer($4) || $4 < 17 || $4 > 32 ||
        !integer($5) || $5 < 0 || $5 > 7 ||
        !integer($6) || $6 < 1 || $6 > 6 ||
        !integer($7) || $7 < 1 || $7 > 8 ||
        !integer($8) || $8 < 1 || $8 > 8 ||
        $9 !~ /^(home|storm|wonder|social)$/ ||
        $10 !~ /^(updated|born|replaced)$/ || $11 == "" ||
        !integer($12) || !integer($17) || $17 != $12 + 1 ||
        !number($16) || $16 < 0 || ($20 != 0 && $20 != 1))
        fail("invalid row")

    matrix_sum = vector($15, observed_matrix, 64, 1000000.0001)
    source_sum = vector($14, source, 8)
    target_sum = vector($19, target, 8)
    if (abs(matrix_sum - $16) > 0.0001 ||
        abs(source_sum - 1) > 0.00001 || abs(target_sum - 1) > 0.00001)
        fail("geometry total mismatch")

    if ($2 != current_life) {
        finish_life()
        if (seen_life[$2]++) fail("noncontiguous life")
        current_life = $2
        current_split = $3
        current_rank = $4
        current_rotation = $5
        raw_rows = score_rows = 0
        expected_session = 1
        expected_order = 1
        copy_matrix(observed_matrix, control_matrix)
        copy_matrix(observed_matrix, candidate_matrix)
        compare_next = 1
    } else if ($3 != current_split || $4 != current_rank ||
               $5 != current_rotation) fail("life identity drift")

    if ($6 != expected_session || $7 != expected_order)
        fail("nonchronological life")
    expected_order++
    if (expected_order == 9) { expected_order = 1; expected_session++ }
    raw_rows++

    if (raw_rows > 1) {
        if (compare_next) {
            if (!matrix_close(observed_matrix, control_matrix))
                fail("control replay drift")
        } else {
            copy_matrix(observed_matrix, control_matrix)
            copy_matrix(observed_matrix, candidate_matrix)
        }
    }

    raw_total = prediction(observed_matrix, source, raw_prediction)
    candidate_total = prediction(candidate_matrix, source,
                                 candidate_prediction)
    raw_has_prediction = raw_total > 0 ? 1 : 0
    candidate_has_prediction = candidate_total > 0 ? 1 : 0
    if (raw_has_prediction != $20) fail("runtime prediction flag mismatch")

    raw_overlap = overlap(raw_prediction, target)
    candidate_overlap = overlap(candidate_prediction, target)
    raw_surprise = raw_has_prediction ? \
        -log(raw_overlap > 0.000001 ? raw_overlap : 0.000001) : 0
    candidate_surprise = candidate_has_prediction ? \
        -log(candidate_overlap > 0.000001 ? candidate_overlap : 0.000001) : 0
    raw_brier = raw_has_prediction ? brier(raw_prediction, target) : 0
    candidate_brier = candidate_has_prediction ? \
        brier(candidate_prediction, target) : 0

    same_topology = $13 == $18
    if ($6 >= 4) {
        eligible = 1
        reason = "none"
        if ($10 != "updated") { eligible = 0; reason = "event" }
        else if (!same_topology) { eligible = 0; reason = "topology" }
        else if (!raw_has_prediction || !candidate_has_prediction) {
            eligible = 0; reason = "forecast"
        }
        print $1, $2, $3, $4, $5, $6, $7, $8, $9, eligible, reason, \
            sprintf("%.9f", raw_surprise), \
            sprintf("%.9f", candidate_surprise), \
            sprintf("%.9f", raw_surprise - candidate_surprise), \
            sprintf("%.9f", raw_brier), sprintf("%.9f", candidate_brier), \
            sprintf("%.9f", raw_brier - candidate_brier)
        score_rows++
    }

    if ($10 == "updated" && same_topology) {
        update_control(control_matrix, source, target)
        update_candidate(candidate_matrix, source, target, candidate_overlap)
        compare_next = 1
    } else {
        compare_next = 0
    }
}

END {
    if (fatal) exit 2
    finish_life()
    if (length(seen_life) != 32) fail("wrong life count")
}
