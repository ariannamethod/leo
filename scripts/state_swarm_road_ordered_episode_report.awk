# A.104: ask whether an ordered path explains error beyond unordered adjacency.

function fail() {
    if (!fatal) print "road ordered-episode report rejected " FILENAME ":" FNR > "/dev/stderr"
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

function normalize(value,    i, total) {
    total = 0
    for (i = 1; i <= 8; i++) {
        value[i] = max(value[i], 0.000001)
        total += value[i]
    }
    if (total <= 0) fail()
    for (i = 1; i <= 8; i++) value[i] /= total
}

function start_epoch(life,    candidate, i, j, k, key, trace_key, current_epoch) {
    current_epoch = ++epoch[life]
    has_previous[life] = 0
    base_weight[life SUBSEP current_epoch] = snapshot_alpha
    for (i = 1; i <= 8; i++) {
        key = life SUBSEP current_epoch SUBSEP pre_id[i]
        base_source_mean[key] = 0.125
        base_error_mean[key] = 0
        base_source_variance[key] = 0
        for (j = 1; j <= 8; j++)
            base_covariance[key SUBSEP pre_id[j]] = 0
    }
    for (candidate in policy_seen) {
        trace_key = candidate SUBSEP life SUBSEP current_epoch
        reader_weight[trace_key] = alpha[candidate]
        path_trace_weight[trace_key] = 0
        for (i = 1; i <= 8; i++)
            for (j = 1; j <= 8; j++) {
                k = (i - 1) * 8 + j
                unordered_mean[trace_key SUBSEP k] = 0.015625
                arrow_mean[trace_key SUBSEP k] = 0
            }
    }
}

function advance_paths(life, current_epoch,    candidate, i, j, k, trace_key) {
    if (!has_previous[life]) return 0
    for (candidate in policy_seen) {
        trace_key = candidate SUBSEP life SUBSEP current_epoch
        for (i = 1; i <= 8; i++)
            for (j = 1; j <= 8; j++) {
                k = (i - 1) * 8 + j
                path_trace[trace_key SUBSEP k] = \
                    path_decay[candidate] * path_trace[trace_key SUBSEP k] + \
                    previous_source[life SUBSEP i] * source[j]
            }
        path_trace_weight[trace_key] = \
            path_decay[candidate] * path_trace_weight[trace_key] + 1
    }
    return 1
}

function remember_source(life,    i) {
    for (i = 1; i <= 8; i++) previous_source[life SUBSEP i] = source[i]
    has_previous[life] = 1
}

BEGIN {
    FS = OFS = "\t"
    if (!policy_expected) policy_expected = 6
    if (!life_expected) life_expected = 12
    if (!writer_expected) writer_expected = 64
    if (!evaluation_start) evaluation_start = 49
    if (!score_min) score_min = 32
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 8 || $1 != "candidate" || $2 != "path_decay" ||
            $4 != "snapshot_decay" || $6 != "prior_alpha" || $8 != "rank") fail()
        next
    }
    if (NF != 8 || $1 !~ /^path-[a-z0-9-]+$/ || policy_seen[$1]++ ||
        !number($2) || $2 < 0 || $2 > 1 || !number($3) || $3 <= 0 ||
        !number($4) || $4 != 1 || !number($5) || $5 != 0.25 ||
        !number($6) || $6 <= 0 || !number($7) || $7 <= 0 ||
        !integer($8) || rank_seen[$8]++) fail()
    policies[++policy_count] = $1
    path_decay[$1] = $2 + 0
    path_strength[$1] = $3 + 0
    alpha[$1] = $6 + 0
    ridge[$1] = $7 + 0
    rank[$1] = $8 + 0
    if (policy_count == 1) {
        snapshot_decay = $4 + 0
        snapshot_strength = $5 + 0
        snapshot_alpha = $6 + 0
        snapshot_ridge = $7 + 0
    } else if ($4 != snapshot_decay || $5 != snapshot_strength ||
               $6 != snapshot_alpha || $7 != snapshot_ridge) fail()
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
        $7 !~ /^(home|storm|wonder|social)$/ ||
        $8 !~ /^(updated|replaced)$/ || !integer($9) || $9 != $4 - 1 ||
        !number($14) || $14 <= 0 || !integer($15) || !integer($16) ||
        $17 !~ /^(0|1)$/ || !integer($18) || !number($19) || !number($20) ||
        !number($21) || $22 == "" || $23 == "") fail()
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
    path_ready = advance_paths(life, current_epoch)
    if ($17 == 0) {
        remember_source(life)
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
        abs($21 + log(max(overlap, 0.000001))) > 0.003) fail()

    raw_ce = ce(target, raw_prediction)
    raw_brier = brier(target, raw_prediction)
    for (j = 1; j <= 8; j++) {
        destination_key = life SUBSEP current_epoch SUBSEP pre_id[j]
        snapshot_prediction[j] = raw_prediction[j] + snapshot_strength * base_error_mean[destination_key]
        for (i = 1; i <= 8; i++) {
            source_key = life SUBSEP current_epoch SUBSEP pre_id[i]
            centered_source = source[i] - base_source_mean[source_key]
            snapshot_prediction[j] += snapshot_strength * centered_source * \
                base_covariance[source_key SUBSEP pre_id[j]] / \
                (snapshot_ridge + base_source_variance[source_key])
        }
    }
    normalize(snapshot_prediction)
    snapshot_ce = ce(target, snapshot_prediction)
    snapshot_brier = brier(target, snapshot_prediction)

    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        trace_key = candidate SUBSEP life SUBSEP current_epoch
        if (path_ready)
            for (i = 1; i <= 8; i++)
                for (m = 1; m <= 8; m++) {
                    k = (i - 1) * 8 + m
                    reverse = (m - 1) * 8 + i
                    path_context[k] = path_trace[trace_key SUBSEP k] / path_trace_weight[trace_key]
                    reverse_context = path_trace[trace_key SUBSEP reverse] / path_trace_weight[trace_key]
                    unordered_context[k] = 0.5 * (path_context[k] + reverse_context)
                    arrow_context[k] = 0.5 * (path_context[k] - reverse_context)
                }
        for (j = 1; j <= 8; j++) {
            unordered_prediction[j] = snapshot_prediction[j]
            if (path_ready)
                for (k = 1; k <= 64; k++) {
                    path_key = trace_key SUBSEP k
                    centered_unordered = unordered_context[k] - unordered_mean[path_key]
                    unordered_prediction[j] += path_strength[candidate] * \
                        centered_unordered * unordered_covariance[path_key SUBSEP pre_id[j]] / \
                        (ridge[candidate] + unordered_variance[path_key])
                }
        }
        normalize(unordered_prediction)
        for (j = 1; j <= 8; j++) {
            ordered_prediction[j] = unordered_prediction[j]
            if (path_ready)
                for (k = 1; k <= 64; k++) {
                    path_key = trace_key SUBSEP k
                    centered_arrow = arrow_context[k] - arrow_mean[path_key]
                    ordered_prediction[j] += path_strength[candidate] * \
                        centered_arrow * arrow_covariance[path_key SUBSEP pre_id[j]] / \
                        (ridge[candidate] + arrow_variance[path_key])
                }
        }
        normalize(ordered_prediction)
        ordered_ce = ce(target, ordered_prediction)
        unordered_ce = ce(target, unordered_prediction)
        ordered_brier = brier(target, ordered_prediction)
        unordered_brier = brier(target, unordered_prediction)

        if (path_ready && $4 >= evaluation_start) {
            if (!header++)
                print "candidate", "path_decay", "path_strength", "rank", \
                    "cohort", "life", "split", "turn", "texture", "raw_ce", \
                    "ordered_ce", "unordered_ce", "snapshot_ce", "raw_brier", \
                    "ordered_brier", "unordered_brier", "snapshot_brier", \
                    "raw_ce_gain", "raw_brier_gain", "snapshot_ce_gain", \
                    "snapshot_brier_gain", "unordered_ce_gain", \
                    "unordered_brier_gain", "snapshot_raw_ce_gain", \
                    "snapshot_raw_brier_gain"
            print candidate, path_decay[candidate], path_strength[candidate], \
                rank[candidate], $1, life, $3, $4, $7, sprintf("%.9f", raw_ce), \
                sprintf("%.9f", ordered_ce), sprintf("%.9f", unordered_ce), \
                sprintf("%.9f", snapshot_ce), sprintf("%.9f", raw_brier), \
                sprintf("%.9f", ordered_brier), sprintf("%.9f", unordered_brier), \
                sprintf("%.9f", snapshot_brier), \
                sprintf("%.9f", raw_ce - ordered_ce), \
                sprintf("%.9f", raw_brier - ordered_brier), \
                sprintf("%.9f", snapshot_ce - ordered_ce), \
                sprintf("%.9f", snapshot_brier - ordered_brier), \
                sprintf("%.9f", unordered_ce - ordered_ce), \
                sprintf("%.9f", unordered_brier - ordered_brier), \
                sprintf("%.9f", raw_ce - snapshot_ce), \
                sprintf("%.9f", raw_brier - snapshot_brier)
            score_rows[candidate SUBSEP life]++
        }

        if (path_ready) {
            weight_key = trace_key
            old_weight = reader_weight[weight_key]
            new_weight = old_weight + 1
            recenter = old_weight / new_weight
            for (k = 1; k <= 64; k++) {
                path_key = trace_key SUBSEP k
                unordered_delta[k] = unordered_context[k] - unordered_mean[path_key]
                arrow_delta[k] = arrow_context[k] - arrow_mean[path_key]
            }
            for (j = 1; j <= 8; j++) {
                destination_key = trace_key SUBSEP pre_id[j]
                unordered_error[j] = target[j] - snapshot_prediction[j]
                arrow_error[j] = target[j] - unordered_prediction[j]
                unordered_error_delta[j] = \
                    unordered_error[j] - unordered_error_mean[destination_key]
                arrow_error_delta[j] = arrow_error[j] - arrow_error_mean[destination_key]
            }
            for (k = 1; k <= 64; k++) {
                path_key = trace_key SUBSEP k
                unordered_variance[path_key] += \
                    recenter * unordered_delta[k] * unordered_delta[k]
                arrow_variance[path_key] += recenter * arrow_delta[k] * arrow_delta[k]
                for (j = 1; j <= 8; j++)
                    {
                        unordered_covariance[path_key SUBSEP pre_id[j]] += \
                            recenter * unordered_delta[k] * unordered_error_delta[j]
                        arrow_covariance[path_key SUBSEP pre_id[j]] += \
                            recenter * arrow_delta[k] * arrow_error_delta[j]
                    }
            }
            for (k = 1; k <= 64; k++) {
                path_key = trace_key SUBSEP k
                unordered_mean[path_key] += unordered_delta[k] / new_weight
                arrow_mean[path_key] += arrow_delta[k] / new_weight
            }
            for (j = 1; j <= 8; j++) {
                destination_key = trace_key SUBSEP pre_id[j]
                unordered_error_mean[destination_key] += unordered_error_delta[j] / new_weight
                arrow_error_mean[destination_key] += arrow_error_delta[j] / new_weight
            }
            reader_weight[weight_key] = new_weight
        }
    }

    base_weight_key = life SUBSEP current_epoch
    old_weight = base_weight[base_weight_key]
    new_weight = snapshot_decay * old_weight + 1
    recenter = snapshot_decay * old_weight / new_weight
    for (i = 1; i <= 8; i++) {
        source_key = life SUBSEP current_epoch SUBSEP pre_id[i]
        source_delta[i] = source[i] - base_source_mean[source_key]
    }
    for (j = 1; j <= 8; j++) {
        destination_key = life SUBSEP current_epoch SUBSEP pre_id[j]
        observed_error[j] = target[j] - raw_prediction[j]
        error_delta[j] = observed_error[j] - base_error_mean[destination_key]
    }
    for (i = 1; i <= 8; i++) {
        source_key = life SUBSEP current_epoch SUBSEP pre_id[i]
        base_source_variance[source_key] = snapshot_decay * base_source_variance[source_key] + \
            recenter * source_delta[i] * source_delta[i]
        for (j = 1; j <= 8; j++)
            base_covariance[source_key SUBSEP pre_id[j]] = \
                snapshot_decay * base_covariance[source_key SUBSEP pre_id[j]] + \
                recenter * source_delta[i] * error_delta[j]
    }
    for (i = 1; i <= 8; i++) {
        source_key = life SUBSEP current_epoch SUBSEP pre_id[i]
        base_source_mean[source_key] += source_delta[i] / new_weight
    }
    for (j = 1; j <= 8; j++) {
        destination_key = life SUBSEP current_epoch SUBSEP pre_id[j]
        base_error_mean[destination_key] += error_delta[j] / new_weight
    }
    base_weight[base_weight_key] = new_weight
    remember_source(life)
}

END {
    if (fatal) exit 2
    if (policy_count != policy_expected || lock_count != life_expected) fail()
    for (l = 1; l <= lock_count; l++) {
        life = life_order[l]
        if (life_rows[life] != writer_expected) fail()
        for (p = 1; p <= policy_count; p++) {
            key = policies[p] SUBSEP life
            if (score_rows[key] < score_min ||
                score_rows[key] > 32 + writer_expected - evaluation_start + 1) fail()
        }
    }
}
