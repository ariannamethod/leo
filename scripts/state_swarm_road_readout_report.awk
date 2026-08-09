# A.96: reconstruct each transformed source readout from full witnesses.

function fail() { fatal = 1; exit 2 }
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

function entropy(value,    i, result) {
    result = 0
    for (i = 1; i <= 8; i++)
        if (value[i] > 0) result -= value[i] * log(value[i])
    return result
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

function transform(source, kind, parameter, result,
                   i, j, best, total, selected_count) {
    for (i = 1; i <= 8; i++) result[i] = 0
    if (kind == "power") {
        for (i = 1; i <= 8; i++) result[i] = source[i] ^ parameter
    } else if (kind == "topk") {
        for (i in chosen) delete chosen[i]
        for (selected_count = 1; selected_count <= parameter; selected_count++) {
            best = 0
            for (i = 1; i <= 8; i++)
                if (!(i in chosen) &&
                    (!best || source[i] > source[best] + 0.000000000001 ||
                     (abs(source[i] - source[best]) <= 0.000000000001 &&
                      i < best)))
                    best = i
            if (!best) fail()
            chosen[best] = 1
            result[best] = source[best]
        }
    } else {
        fail()
    }
    total = 0
    for (i = 1; i <= 8; i++) total += result[i]
    if (total <= 0) fail()
    for (i = 1; i <= 8; i++) result[i] /= total
}

BEGIN {
    FS = OFS = "\t"
    if (!discovery_expected) discovery_expected = 12
    if (!validation_expected) validation_expected = 15
    if (!candidate_expected) candidate_expected = 8
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 4 || $1 != "candidate" || $2 != "kind" ||
            $3 != "parameter" || $4 != "rank") fail()
        next
    }
    if (NF != 4 || $1 !~ /^(power-[0-9]p[0-9]+|top-[1-8])$/ ||
        candidate_seen[$1]++ || $2 !~ /^(power|topk)$/ ||
        !number($3) || $3 <= 0 || !integer($4) || rank_seen[$4]++) fail()
    if (($2 == "topk" && ($3 != int($3) || $3 > 8)) ||
        ($2 == "power" && $3 <= 1)) fail()
    candidates[++candidate_count] = $1
    candidate_kind[$1] = $2
    candidate_parameter[$1] = $3 + 0
    candidate_rank[$1] = $4 + 0
    next
}

FNR == 1 {
    if (NF != 28 || $1 != "pair" || $5 != "split" ||
        $9 != "transition" || $13 != "destination_prior" ||
        $19 != "conditional_ce" || $28 != "reply") fail()
    next
}

{
    cohort = FILENAME == ARGV[2] ? "discovery" : "validation"
    if (NF != 28 || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology|organism)$/ ||
        (cohort == "discovery" && $2 == "organism") ||
        (cohort == "validation" && $2 != "organism") ||
        $5 !~ /^(primary|holdout)$/ ||
        (cohort == "discovery" && $5 != "primary") ||
        !integer($6) || !integer($7) || $7 != $6 + 1 ||
        $8 !~ /^(home|storm|wonder|social)$/ || $27 == "" || $28 == "" ||
        witness_seen[cohort SUBSEP $2 SUBSEP $3]++) fail()

    if (abs(vector($9, matrix, 64) - $14) > 0.00001 ||
        abs(vector($10, source, 8) - 1) > 0.00001 ||
        abs(vector($11, target, 8) - 1) > 0.00001 ||
        abs(vector($12, raw_prediction, 8) - 1) > 0.00001 ||
        abs(vector($13, destination, 8) - 1) > 0.00001) fail()
    for (i = 14; i <= 26; i++) if (!number($i)) fail()

    total = 0
    raw_total = 0
    for (i = 1; i <= 8; i++) {
        row[i] = 0
        column[i] = 0
        rebuilt_raw[i] = 0
    }
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            row[i] += edge
            column[j] += edge
            rebuilt_raw[j] += source[i] * edge
            total += edge
        }
    for (j = 1; j <= 8; j++) raw_total += rebuilt_raw[j]
    if (total <= 0 || raw_total <= 0 || abs(total - $14) > 0.00001) fail()
    for (j = 1; j <= 8; j++) {
        rebuilt_raw[j] /= raw_total
        rebuilt_destination[j] = column[j] / total
        if (abs(rebuilt_raw[j] - raw_prediction[j]) > 0.000002 ||
            abs(rebuilt_destination[j] - destination[j]) > 0.000002) fail()
    }

    destination_entropy = entropy(destination)
    information = 0
    row_tv = 0
    for (i = 1; i <= 8; i++) {
        if (row[i] <= 0) continue
        this_tv = 0
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            if (edge > 0 && destination[j] > 0)
                information += (edge / total) * log(edge / (row[i] * destination[j]))
            this_tv += abs(edge / row[i] - destination[j])
        }
        row_tv += (row[i] / total) * 0.5 * this_tv
    }
    normalized_information = destination_entropy > 0 ? information / destination_entropy : 0
    raw_ce = ce(target, raw_prediction)
    destination_ce = ce(target, destination)
    uniform_ce = 0
    for (i = 1; i <= 8; i++) uniform[i] = 0.125
    uniform_ce = ce(target, uniform)
    persistence_ce = ce(target, source)
    raw_brier = brier(target, raw_prediction)
    destination_brier = brier(target, destination)
    uniform_brier = brier(target, uniform)
    persistence_brier = brier(target, source)
    if (abs(destination_entropy - $15) > 0.000002 ||
        abs(information - $16) > 0.000002 ||
        abs(normalized_information - $17) > 0.000002 ||
        abs(row_tv - $18) > 0.000002 || abs(raw_ce - $19) > 0.000002 ||
        abs(destination_ce - $20) > 0.000002 ||
        abs(uniform_ce - $21) > 0.000002 ||
        abs(persistence_ce - $22) > 0.000002 ||
        abs(raw_brier - $23) > 0.000002 ||
        abs(destination_brier - $24) > 0.000002 ||
        abs(uniform_brier - $25) > 0.000002 ||
        abs(persistence_brier - $26) > 0.000002) fail()

    if (!header++)
        print "cohort", "case", "arm", "life", "split", "candidate", \
            "kind", "parameter", "rank", "raw_ce", "candidate_ce", \
            "destination_ce", "raw_brier", "candidate_brier", \
            "destination_brier", "raw_ce_gain", "raw_brier_gain", \
            "destination_ce_gain", "destination_brier_gain", \
            "source_entropy", "target_entropy"
    for (c = 1; c <= candidate_count; c++) {
        candidate = candidates[c]
        transform(source, candidate_kind[candidate],
                  candidate_parameter[candidate], adjusted)
        prediction_total = 0
        for (j = 1; j <= 8; j++) {
            prediction[j] = 0
            for (i = 1; i <= 8; i++)
                prediction[j] += adjusted[i] * matrix[(i - 1) * 8 + j]
            prediction_total += prediction[j]
        }
        if (prediction_total <= 0) fail()
        for (j = 1; j <= 8; j++) prediction[j] /= prediction_total
        candidate_ce = ce(target, prediction)
        candidate_brier = brier(target, prediction)
        print cohort, $3, $2, $4, $5, candidate, \
            candidate_kind[candidate], candidate_parameter[candidate], \
            candidate_rank[candidate], sprintf("%.9f", raw_ce), \
            sprintf("%.9f", candidate_ce), sprintf("%.9f", destination_ce), \
            sprintf("%.9f", raw_brier), sprintf("%.9f", candidate_brier), \
            sprintf("%.9f", destination_brier), \
            sprintf("%.9f", raw_ce - candidate_ce), \
            sprintf("%.9f", raw_brier - candidate_brier), \
            sprintf("%.9f", destination_ce - candidate_ce), \
            sprintf("%.9f", destination_brier - candidate_brier), \
            sprintf("%.9f", entropy(source)), sprintf("%.9f", entropy(target))
    }
    cohort_rows[cohort]++
}

END {
    if (fatal) exit 2
    if (candidate_count != candidate_expected ||
        cohort_rows["discovery"] != discovery_expected ||
        cohort_rows["validation"] != validation_expected) fail()
}
