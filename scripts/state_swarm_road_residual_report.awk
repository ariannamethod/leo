# A.99: learn signed transition excess over a past-only destination prior.

function fail() {
    if (!fatal) print "road residual report rejected " FILENAME ":" FNR > "/dev/stderr"
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

BEGIN {
    FS = OFS = "\t"
    if (!policy_expected) policy_expected = 6
    if (!life_expected) life_expected = 18
    if (!writer_expected) writer_expected = 64
    if (!evaluation_start) evaluation_start = 49
    if (!score_min) score_min = 32
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 6 || $1 != "candidate" || $2 != "decay" ||
            $4 != "prior_alpha" || $6 != "rank") fail()
        next
    }
    if (NF != 6 || $1 !~ /^excess-[a-z0-9-]+$/ || policy_seen[$1]++ ||
        !number($2) || $2 <= 0 || $2 > 1 || !number($3) || $3 <= 0 ||
        !number($4) || $4 <= 0 || !number($5) || $5 <= 0 ||
        !integer($6) || rank_seen[$6]++) fail()
    policies[++policy_count] = $1
    decay[$1] = $2 + 0
    strength[$1] = $3 + 0
    alpha[$1] = $4 + 0
    shrinkage[$1] = $5 + 0
    rank[$1] = $6 + 0
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
        $17 != 1 || !integer($18) || !number($19) || !number($20) ||
        !number($21) || $22 == "" || $23 == "") fail()
    if (++life_rows[life] != $4 - 32) fail()

    ids($10, pre_id, 8)
    if (abs(vector($13, source, 8) - 1) > 0.00001 ||
        abs(vector($12, matrix, 64) - $14) > 0.00001 ||
        abs(members($11, post_id, target, 8) - 1) > 0.006) fail()

    total = 0
    raw_total = 0
    for (i = 1; i <= 8; i++) {
        row_mass[i] = 0
        column[i] = 0
        raw_prediction[i] = 0
    }
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            row_mass[i] += edge
            column[j] += edge
            raw_prediction[j] += source[i] * edge
            total += edge
        }
    for (j = 1; j <= 8; j++) raw_total += raw_prediction[j]
    if (abs(total - $14) > 0.00001 || raw_total <= 0) fail()
    for (j = 1; j <= 8; j++) {
        raw_prediction[j] /= raw_total
        destination[j] = column[j] / total
    }

    if (!(life in initialized)) {
        initialized[life] = 1
        for (p = 1; p <= policy_count; p++) {
            candidate = policies[p]
            for (j = 1; j <= 8; j++)
                destination_count[candidate SUBSEP life SUBSEP pre_id[j]] = column[j]
            for (i = 1; i <= 8; i++) {
                support[candidate SUBSEP life SUBSEP pre_id[i]] = row_mass[i]
                for (j = 1; j <= 8; j++)
                    excess[candidate SUBSEP life SUBSEP pre_id[i] SUBSEP pre_id[j]] = matrix[(i - 1) * 8 + j] - row_mass[i] * destination[j]
            }
        }
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
        for (p = 1; p <= policy_count; p++) {
            candidate = policies[p]
            delete destination_count[candidate SUBSEP life SUBSEP old_id]
            delete support[candidate SUBSEP life SUBSEP old_id]
            for (i = 1; i <= 8; i++) {
                delete excess[candidate SUBSEP life SUBSEP old_id SUBSEP pre_id[i]]
                delete excess[candidate SUBSEP life SUBSEP pre_id[i] SUBSEP old_id]
            }
        }
        censored[life]++
        next
    }

    for (i = 1; i <= 8; i++) if (pre_id[i] != post_id[i]) fail()
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
    destination_ce = ce(target, destination)
    raw_brier = brier(target, raw_prediction)
    destination_brier = brier(target, destination)

    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        shadow_total = 0
        for (j = 1; j <= 8; j++)
            shadow_total += destination_count[candidate SUBSEP life SUBSEP pre_id[j]]
        for (j = 1; j <= 8; j++)
            shadow_prior[j] = (destination_count[candidate SUBSEP life SUBSEP pre_id[j]] + alpha[candidate] / 8) / (shadow_total + alpha[candidate])

        for (j = 1; j <= 8; j++) {
            candidate_prediction[j] = shadow_prior[j]
            control_prediction[j] = destination[j]
            for (i = 1; i <= 8; i++) {
                candidate_prediction[j] += strength[candidate] * source[i] * excess[candidate SUBSEP life SUBSEP pre_id[i] SUBSEP pre_id[j]] / (shrinkage[candidate] + support[candidate SUBSEP life SUBSEP pre_id[i]])
                control_prediction[j] += strength[candidate] * source[i] * (matrix[(i - 1) * 8 + j] - row_mass[i] * destination[j]) / (shrinkage[candidate] + row_mass[i])
            }
        }
        normalize(candidate_prediction)
        normalize(control_prediction)
        candidate_ce = ce(target, candidate_prediction)
        control_ce = ce(target, control_prediction)
        candidate_brier = brier(target, candidate_prediction)
        control_brier = brier(target, control_prediction)

        if ($4 >= evaluation_start) {
            if (!header++)
                print "candidate", "decay", "strength", "rank", "cohort", \
                    "life", "split", "turn", "texture", "raw_ce", \
                    "candidate_ce", "control_ce", "destination_ce", \
                    "raw_brier", "candidate_brier", "control_brier", \
                    "destination_brier", "raw_ce_gain", "raw_brier_gain", \
                    "control_ce_gain", "control_brier_gain", \
                    "destination_ce_gain", "destination_brier_gain"
            print candidate, decay[candidate], strength[candidate], rank[candidate], \
                $1, life, $3, $4, $7, sprintf("%.9f", raw_ce), \
                sprintf("%.9f", candidate_ce), sprintf("%.9f", control_ce), \
                sprintf("%.9f", destination_ce), sprintf("%.9f", raw_brier), \
                sprintf("%.9f", candidate_brier), sprintf("%.9f", control_brier), \
                sprintf("%.9f", destination_brier), \
                sprintf("%.9f", raw_ce - candidate_ce), \
                sprintf("%.9f", raw_brier - candidate_brier), \
                sprintf("%.9f", control_ce - candidate_ce), \
                sprintf("%.9f", control_brier - candidate_brier), \
                sprintf("%.9f", destination_ce - candidate_ce), \
                sprintf("%.9f", destination_brier - candidate_brier)
            score_rows[candidate SUBSEP life]++
        }

        for (i = 1; i <= 8; i++) {
            destination_count[candidate SUBSEP life SUBSEP pre_id[i]] *= decay[candidate]
            support[candidate SUBSEP life SUBSEP pre_id[i]] *= decay[candidate]
            for (j = 1; j <= 8; j++)
                excess[candidate SUBSEP life SUBSEP pre_id[i] SUBSEP pre_id[j]] *= decay[candidate]
        }
        for (j = 1; j <= 8; j++)
            destination_count[candidate SUBSEP life SUBSEP pre_id[j]] += target[j]
        for (i = 1; i <= 8; i++) {
            support[candidate SUBSEP life SUBSEP pre_id[i]] += source[i]
            for (j = 1; j <= 8; j++)
                excess[candidate SUBSEP life SUBSEP pre_id[i] SUBSEP pre_id[j]] += source[i] * (target[j] - shadow_prior[j])
        }
    }
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
