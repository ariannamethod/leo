# A.107: ask whether a realized boundary displacement survives three later moments.

function fail() {
    if (!fatal) print "road delayed-consequence-receipt report rejected " FILENAME ":" FNR > "/dev/stderr"
    fatal = 1
    exit 2
}
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }
function max(value, floor) { return value < floor ? floor : value }

function vector(value, target, count,    item, n, i, sum) {
    n = split(value, item, "/")
    if (n != count) fail()
    sum = 0
    for (i = 1; i <= n; i++) {
        if (!number(item[i]) || item[i] < -0.0000001) fail()
        target[i] = item[i] + 0
        sum += target[i]
    }
    return sum
}

function ids(value, target, count,    item, n, i) {
    n = split(value, item, "/")
    if (n != count) fail()
    for (i = 1; i <= n; i++) {
        if (!integer(item[i]) || item[i] <= 0 || local_id[item[i]]++) fail()
        target[i] = item[i] + 0
    }
    for (i in local_id) delete local_id[i]
}

function members(value, member_id, activation, count,    item, part, n, i, sum) {
    n = split(value, item, ",")
    if (n != count) fail()
    sum = 0
    for (i = 1; i <= n; i++) {
        if (split(item[i], part, ":") != 2 || !integer(part[1]) ||
            part[1] <= 0 || !number(part[2]) || part[2] < -0.0000001 ||
            local_id[part[1]]++) fail()
        member_id[i] = part[1] + 0
        activation[i] = part[2] + 0
        sum += activation[i]
    }
    for (i in local_id) delete local_id[i]
    return sum
}

function ce(target, prediction,    i, result) {
    result = 0
    for (i = 1; i <= 8; i++)
        result -= target[i] * log(max(prediction[i], 0.000001))
    return result
}

function brier(target, prediction,    i, delta, result) {
    result = 0
    for (i = 1; i <= 8; i++) {
        delta = target[i] - prediction[i]
        result += delta * delta
    }
    return result
}

function rounded_log_pair(overlap_field, surprise_field,    overlap_low,
                          overlap_high, surprise_low, surprise_high) {
    overlap_low = max(overlap_field - 0.0005001, 0.000001)
    overlap_high = overlap_field + 0.0005001
    surprise_low = -log(overlap_high)
    surprise_high = -log(overlap_low)
    return surprise_field + 0.0005001 >= surprise_low &&
        surprise_field - 0.0005001 <= surprise_high
}

function normalize(value,    i, total) {
    total = 0
    for (i = 1; i <= 8; i++) {
        value[i] = max(value[i], 0.000001)
        total += value[i]
    }
    if (total <= 0) fail()
    for (i = 1; i <= 8; i++) value[i] /= total
}

function start_epoch(life,    candidate, texture, i, j, k, key, current_epoch) {
    current_epoch = ++epoch[life]
    base_weight[life SUBSEP current_epoch] = snapshot_alpha
    for (i = 1; i <= 8; i++) {
        key = life SUBSEP current_epoch SUBSEP i
        base_source_mean[key] = 0.125
        base_error_mean[key] = 0
        base_source_variance[key] = 0
        for (j = 1; j <= 8; j++)
            base_covariance[key SUBSEP j] = 0
    }
    for (texture in texture_seen) {
        texture_weight[life SUBSEP current_epoch SUBSEP texture] = prior_alpha
        for (j = 1; j <= 8; j++)
            texture_error_mean[life SUBSEP current_epoch SUBSEP texture SUBSEP j] = 0
    }
    for (candidate in policy_seen) {
        key = candidate SUBSEP life SUBSEP current_epoch
        reader_weight[key] = prior_alpha
        for (k = 1; k <= 24; k++) {
            symmetric_mean[key SUBSEP k] = k <= 8 || k > 16 ? 0.125 : 0
            symmetric_variance[key SUBSEP k] = 0
            for (j = 1; j <= 8; j++)
                symmetric_covariance[key SUBSEP k SUBSEP j] = 0
        }
        for (k = 1; k <= 8; k++) {
            receipt_mean[key SUBSEP k] = 0
            receipt_variance[key SUBSEP k] = 0
            for (j = 1; j <= 8; j++)
                receipt_covariance[key SUBSEP k SUBSEP j] = 0
        }
        for (j = 1; j <= 8; j++) {
            symmetric_error_mean[key SUBSEP j] = 0
            receipt_error_mean[key SUBSEP j] = 0
        }
    }
}

BEGIN {
    FS = OFS = "\t"
    if (!policy_expected) policy_expected = 2
    if (!life_expected) life_expected = 12
    if (!writer_expected) writer_expected = 64
    if (!evaluation_session) evaluation_session = 5
    if (!score_min) score_min = 3
    texture_seen["home"] = texture_seen["storm"] = 1
    texture_seen["wonder"] = texture_seen["social"] = 1
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 8 || $1 != "candidate" || $2 != "receipt_strength" ||
            $3 != "snapshot_decay" || $5 != "texture_strength" ||
            $6 != "prior_alpha" || $8 != "rank") fail()
        next
    }
    if (NF != 8 || $1 !~ /^receipt-[a-z0-9-]+$/ || policy_seen[$1]++ ||
        !number($2) || $2 <= 0 || !number($3) || $3 != 1 ||
        !number($4) || $4 != 0.25 || !number($5) || $5 != 0.25 ||
        !number($6) || $6 <= 0 || !number($7) || $7 <= 0 ||
        !integer($8) || rank_seen[$8]++) fail()
    policies[++policy_count] = $1
    strength[$1] = $2 + 0
    rank[$1] = $8 + 0
    if (policy_count == 1) {
        snapshot_decay = $3 + 0
        snapshot_strength = $4 + 0
        texture_strength = $5 + 0
        prior_alpha = $6 + 0
        ridge = $7 + 0
    } else if ($3 != snapshot_decay || $4 != snapshot_strength ||
               $5 != texture_strength || $6 != prior_alpha || $7 != ridge) fail()
    next
}

FILENAME == ARGV[2] {
    if (FNR == 1) {
        if (NF != 8 || $1 != "cohort" || $4 != "writer_turns" ||
            $8 != "final_state_sha") fail()
        next
    }
    if (NF != 8 || $1 !~ /^(discovery|validation)$/ ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        $4 != writer_expected || $5 != "true" || $6 != "true" ||
        length($7) != 64 || $7 !~ /^[0-9a-f]+$/ ||
        length($8) != 64 || $8 !~ /^[0-9a-f]+$/ || lock_seen[$2]++) fail()
    life_cohort[$2] = $1
    life_split[$2] = $3
    life_order[++lock_count] = $2
    next
}

FNR == 1 {
    if (NF != 23 || $1 != "cohort" || $4 != "turn" ||
        $10 != "pre_ids" || $12 != "transition" || $23 != "reply") fail()
    next
}

{
    life = $2
    if (NF != 23 || !(life in lock_seen) || $1 != life_cohort[life] ||
        $3 != life_split[life] || !integer($4) || !integer($5) ||
        !integer($6) || $6 < 1 || $6 > 8 ||
        $4 != 32 + ($5 - 1) * 8 + $6 ||
        !($7 in texture_seen) || $8 !~ /^(updated|replaced)$/ ||
        !integer($9) || $9 != $4 - 1 || !number($14) || $14 <= 0 ||
        !integer($15) || !integer($16) || $17 !~ /^(0|1)$/ ||
        !integer($18) || !number($19) || !number($20) || !number($21) ||
        $22 == "" || $23 == "") fail()
    if (++life_rows[life] != $4 - 32) fail()

    ids($10, pre_id, 8)
    if (abs(vector($13, source, 8) - 1) > 0.00001 ||
        abs(vector($12, matrix, 64) - $14) > 0.00001 ||
        abs(members($11, post_id, target, 8) - 1) > 0.006) fail()

    total = raw_total = 0
    for (i = 1; i <= 8; i++) raw_prediction[i] = 0
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            raw_prediction[j] += source[i] * edge
            total += edge
        }
    for (j = 1; j <= 8; j++) raw_total += raw_prediction[j]
    if (abs(total - $14) > 0.00001) fail()
    if ($17 == 1) {
        if (raw_total <= 0) fail()
        for (j = 1; j <= 8; j++) raw_prediction[j] /= raw_total
    } else if (raw_total > 0.000001 || $18 != 0 || $19 != 0 || $20 != 0 || $21 != 0) fail()

    if (!(life in initialized)) {
        initialized[life] = 1
        start_epoch(life)
    }

    if ($8 == "replaced") {
        changed = 0
        for (i = 1; i <= 8; i++)
            if (pre_id[i] != post_id[i]) {
                changed++
                old_id = pre_id[i]
                new_id = post_id[i]
            }
        if (changed != 1 || $16 != old_id || $15 != new_id) fail()
        for (i = 1; i <= 8; i++) pre_id[i] = post_id[i]
        start_epoch(life)
        censored[life]++
        next
    }
    for (i = 1; i <= 8; i++) if (pre_id[i] != post_id[i]) fail()

    current_epoch = epoch[life]
    session_key = life SUBSEP current_epoch SUBSEP $5
    previous_key = life SUBSEP current_epoch SUBSEP ($5 - 1)

    if ($17 == 0) {
        session_invalid[session_key] = 1
        session_rows[session_key]++
        session_seen[session_key SUBSEP $6] = 1
        for (i = 1; i <= 8; i++)
            session_source[session_key SUBSEP $6 SUBSEP i] = source[i]
        censored[life]++
        next
    }

    expected_slot = 1
    overlap = 0
    for (j = 1; j <= 8; j++) {
        overlap += raw_prediction[j] * target[j]
        if (raw_prediction[j] > raw_prediction[expected_slot]) expected_slot = j
    }
    if ($18 != pre_id[expected_slot] ||
        abs($19 - raw_prediction[expected_slot]) > 0.002 ||
        abs($20 - overlap) > 0.002 ||
        !rounded_log_pair($20, $21)) fail()

    raw_ce = ce(target, raw_prediction)
    raw_brier = brier(target, raw_prediction)
    for (j = 1; j <= 8; j++) {
        snapshot_prediction[j] = raw_prediction[j] + \
            snapshot_strength * base_error_mean[life SUBSEP current_epoch SUBSEP j]
        for (i = 1; i <= 8; i++) {
            source_key = life SUBSEP current_epoch SUBSEP i
            centered_source = source[i] - base_source_mean[source_key]
            snapshot_prediction[j] += snapshot_strength * centered_source * \
                base_covariance[source_key SUBSEP j] / \
                (ridge + base_source_variance[source_key])
        }
    }
    normalize(snapshot_prediction)
    snapshot_ce = ce(target, snapshot_prediction)
    snapshot_brier = brier(target, snapshot_prediction)

    texture_key = life SUBSEP current_epoch SUBSEP $7
    for (j = 1; j <= 8; j++)
        texture_prediction[j] = snapshot_prediction[j] + texture_strength * \
            texture_error_mean[texture_key SUBSEP j]
    normalize(texture_prediction)
    texture_ce = ce(target, texture_prediction)
    texture_brier = brier(target, texture_prediction)

    if ($6 == 1 && $5 > 1 && session_rows[previous_key] == 8 &&
        !session_invalid[previous_key]) {
        for (i = 1; i <= 8; i++) {
            boundary_midpoint[session_key SUBSEP i] = 0.5 * (source[i] + target[i])
            boundary_magnitude[session_key SUBSEP i] = abs(target[i] - source[i])
            boundary_receipt[session_key SUBSEP i] = target[i] - source[i]
        }
        boundary_valid[session_key] = 1
    }

    if (boundary_valid[session_key] && $6 >= 2 && $6 <= 4)
        for (i = 1; i <= 8; i++)
            intervening_sum[session_key SUBSEP i] += target[i]

    receipt_ready = $6 == 5 && boundary_valid[session_key] &&
        session_rows[session_key] == 4 && !session_invalid[session_key]

    if (receipt_ready) {
        for (i = 1; i <= 8; i++) {
            symmetric_feature[i] = boundary_midpoint[session_key SUBSEP i]
            symmetric_feature[8 + i] = boundary_magnitude[session_key SUBSEP i]
            symmetric_feature[16 + i] = intervening_sum[session_key SUBSEP i] / 3
            receipt_feature[i] = boundary_receipt[session_key SUBSEP i]
        }

        for (p = 1; p <= policy_count; p++) {
            candidate = policies[p]
            reader_key = candidate SUBSEP life SUBSEP current_epoch
            for (j = 1; j <= 8; j++) {
                symmetric_prediction[j] = texture_prediction[j]
                for (k = 1; k <= 24; k++) {
                    feature_key = reader_key SUBSEP k
                    symmetric_prediction[j] += strength[candidate] * \
                        (symmetric_feature[k] - symmetric_mean[feature_key]) * \
                        symmetric_covariance[feature_key SUBSEP j] / \
                        (ridge + symmetric_variance[feature_key])
                }
            }
            normalize(symmetric_prediction)
            for (j = 1; j <= 8; j++) {
                receipt_prediction[j] = symmetric_prediction[j]
                for (k = 1; k <= 8; k++) {
                    feature_key = reader_key SUBSEP k
                    receipt_prediction[j] += strength[candidate] * \
                        (receipt_feature[k] - receipt_mean[feature_key]) * \
                        receipt_covariance[feature_key SUBSEP j] / \
                        (ridge + receipt_variance[feature_key])
                }
            }
            normalize(receipt_prediction)
            symmetric_ce = ce(target, symmetric_prediction)
            symmetric_brier = brier(target, symmetric_prediction)
            receipt_ce = ce(target, receipt_prediction)
            receipt_brier = brier(target, receipt_prediction)

            if ($5 >= evaluation_session) {
                if (!header++)
                    print "candidate", "receipt_strength", "rank", "cohort", \
                        "life", "split", "turn", "session", "texture", "raw_ce", \
                        "receipt_ce", "symmetric_ce", "texture_ce", "snapshot_ce", \
                        "raw_brier", "receipt_brier", "symmetric_brier", \
                        "texture_brier", "snapshot_brier", "raw_ce_gain", \
                        "raw_brier_gain", "snapshot_ce_gain", "snapshot_brier_gain", \
                        "texture_ce_gain", "texture_brier_gain", "symmetric_ce_gain", \
                        "symmetric_brier_gain", "snapshot_raw_ce_gain", \
                        "texture_snapshot_ce_gain"
                print candidate, strength[candidate], rank[candidate], $1, life, $3, \
                    $4, $5, $7, sprintf("%.9f", raw_ce), \
                    sprintf("%.9f", receipt_ce), sprintf("%.9f", symmetric_ce), \
                    sprintf("%.9f", texture_ce), sprintf("%.9f", snapshot_ce), \
                    sprintf("%.9f", raw_brier), sprintf("%.9f", receipt_brier), \
                    sprintf("%.9f", symmetric_brier), sprintf("%.9f", texture_brier), \
                    sprintf("%.9f", snapshot_brier), \
                    sprintf("%.9f", raw_ce - receipt_ce), \
                    sprintf("%.9f", raw_brier - receipt_brier), \
                    sprintf("%.9f", snapshot_ce - receipt_ce), \
                    sprintf("%.9f", snapshot_brier - receipt_brier), \
                    sprintf("%.9f", texture_ce - receipt_ce), \
                    sprintf("%.9f", texture_brier - receipt_brier), \
                    sprintf("%.9f", symmetric_ce - receipt_ce), \
                    sprintf("%.9f", symmetric_brier - receipt_brier), \
                    sprintf("%.9f", raw_ce - snapshot_ce), \
                    sprintf("%.9f", snapshot_ce - texture_ce)
                score_rows[candidate SUBSEP life]++
            }

            old_weight = reader_weight[reader_key]
            new_weight = old_weight + 1
            recenter = old_weight / new_weight
            for (k = 1; k <= 24; k++) {
                feature_key = reader_key SUBSEP k
                symmetric_delta[k] = symmetric_feature[k] - symmetric_mean[feature_key]
            }
            for (k = 1; k <= 8; k++) {
                feature_key = reader_key SUBSEP k
                receipt_delta[k] = receipt_feature[k] - receipt_mean[feature_key]
            }
            for (j = 1; j <= 8; j++) {
                symmetric_error_delta[j] = target[j] - texture_prediction[j] - \
                    symmetric_error_mean[reader_key SUBSEP j]
                receipt_error_delta[j] = target[j] - symmetric_prediction[j] - \
                    receipt_error_mean[reader_key SUBSEP j]
            }
            for (k = 1; k <= 24; k++) {
                feature_key = reader_key SUBSEP k
                symmetric_variance[feature_key] += recenter * symmetric_delta[k] * symmetric_delta[k]
                for (j = 1; j <= 8; j++)
                    symmetric_covariance[feature_key SUBSEP j] += \
                        recenter * symmetric_delta[k] * symmetric_error_delta[j]
            }
            for (k = 1; k <= 8; k++) {
                feature_key = reader_key SUBSEP k
                receipt_variance[feature_key] += recenter * receipt_delta[k] * receipt_delta[k]
                for (j = 1; j <= 8; j++)
                    receipt_covariance[feature_key SUBSEP j] += \
                        recenter * receipt_delta[k] * receipt_error_delta[j]
            }
            for (k = 1; k <= 24; k++)
                symmetric_mean[reader_key SUBSEP k] += symmetric_delta[k] / new_weight
            for (k = 1; k <= 8; k++)
                receipt_mean[reader_key SUBSEP k] += receipt_delta[k] / new_weight
            for (j = 1; j <= 8; j++) {
                symmetric_error_mean[reader_key SUBSEP j] += symmetric_error_delta[j] / new_weight
                receipt_error_mean[reader_key SUBSEP j] += receipt_error_delta[j] / new_weight
            }
            reader_weight[reader_key] = new_weight
        }
    }

    old_weight = texture_weight[texture_key]
    new_weight = old_weight + 1
    for (j = 1; j <= 8; j++) {
        texture_delta = target[j] - snapshot_prediction[j] - \
            texture_error_mean[texture_key SUBSEP j]
        texture_error_mean[texture_key SUBSEP j] += texture_delta / new_weight
    }
    texture_weight[texture_key] = new_weight

    base_weight_key = life SUBSEP current_epoch
    old_weight = base_weight[base_weight_key]
    new_weight = snapshot_decay * old_weight + 1
    recenter = snapshot_decay * old_weight / new_weight
    for (i = 1; i <= 8; i++) {
        source_key = life SUBSEP current_epoch SUBSEP i
        source_delta[i] = source[i] - base_source_mean[source_key]
    }
    for (j = 1; j <= 8; j++) {
        observed_error[j] = target[j] - raw_prediction[j]
        error_delta[j] = observed_error[j] - \
            base_error_mean[life SUBSEP current_epoch SUBSEP j]
    }
    for (i = 1; i <= 8; i++) {
        source_key = life SUBSEP current_epoch SUBSEP i
        base_source_variance[source_key] = snapshot_decay * base_source_variance[source_key] + \
            recenter * source_delta[i] * source_delta[i]
        for (j = 1; j <= 8; j++)
            base_covariance[source_key SUBSEP j] = \
                snapshot_decay * base_covariance[source_key SUBSEP j] + \
                recenter * source_delta[i] * error_delta[j]
    }
    for (i = 1; i <= 8; i++)
        base_source_mean[life SUBSEP current_epoch SUBSEP i] += source_delta[i] / new_weight
    for (j = 1; j <= 8; j++)
        base_error_mean[life SUBSEP current_epoch SUBSEP j] += error_delta[j] / new_weight
    base_weight[base_weight_key] = new_weight

    if (session_seen[session_key SUBSEP $6]++) fail()
    session_rows[session_key]++
    for (i = 1; i <= 8; i++)
        session_source[session_key SUBSEP $6 SUBSEP i] = source[i]
}

END {
    if (fatal) exit 2
    if (policy_count != policy_expected || lock_count != life_expected) fail()
    for (l = 1; l <= lock_count; l++) {
        life = life_order[l]
        if (life_rows[life] != writer_expected) fail()
        for (p = 1; p <= policy_count; p++) {
            key = policies[p] SUBSEP life
            if (score_rows[key] < score_min || score_rows[key] > 4) fail()
        }
    }
}
