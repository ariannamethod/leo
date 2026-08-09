# A.97: measure pre-outcome authority carried by active transition rows.

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

BEGIN {
    FS = OFS = "\t"
    if (!discovery_expected) discovery_expected = 12
    if (!validation_expected) validation_expected = 15
    if (!feature_expected) feature_expected = 6
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 3 || $1 != "feature" || $2 != "kind" || $3 != "rank") fail()
        next
    }
    if (NF != 3 || $1 !~ /^[a-z][a-z0-9-]+$/ || feature_seen[$1]++ ||
        $2 !~ /^(coverage|active-kl|forecast-kl|survival|product|tv)$/ ||
        !integer($3) || rank_seen[$3]++) fail()
    features[++feature_count] = $1
    feature_kind[$1] = $2
    feature_rank[$1] = $3 + 0
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
    max_row_mass = 0
    for (i = 1; i <= 8; i++) {
        row_mass[i] = 0
        column[i] = 0
        rebuilt_raw[i] = 0
    }
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            row_mass[i] += edge
            column[j] += edge
            rebuilt_raw[j] += source[i] * edge
            total += edge
        }
    for (i = 1; i <= 8; i++) {
        raw_total += source[i] * row_mass[i]
        if (row_mass[i] > max_row_mass) max_row_mass = row_mass[i]
    }
    if (total <= 0 || raw_total <= 0 || max_row_mass <= 0 ||
        abs(total - $14) > 0.00001) fail()
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
        if (row_mass[i] <= 0) continue
        this_tv = 0
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            if (edge > 0 && destination[j] > 0)
                information += (edge / total) * log(edge / (row_mass[i] * destination[j]))
            this_tv += abs(edge / row_mass[i] - destination[j])
        }
        row_tv += (row_mass[i] / total) * 0.5 * this_tv
    }
    normalized_information = destination_entropy > 0 ? information / destination_entropy : 0
    raw_ce = ce(target, raw_prediction)
    destination_ce = ce(target, destination)
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

    coverage = raw_total / max_row_mass
    active_row_kl = 0
    for (i = 1; i <= 8; i++) {
        if (source[i] <= 0 || row_mass[i] <= 0) continue
        row_kl = 0
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            if (edge > 0) row_kl += (edge / row_mass[i]) * log((edge / row_mass[i]) / destination[j])
        }
        active_row_kl += (source[i] * row_mass[i] / raw_total) * row_kl
    }
    forecast_kl = 0
    forecast_tv = 0
    for (j = 1; j <= 8; j++) {
        if (raw_prediction[j] > 0)
            forecast_kl += raw_prediction[j] * log(raw_prediction[j] / destination[j])
        forecast_tv += abs(raw_prediction[j] - destination[j])
    }
    forecast_tv *= 0.5
    survival = active_row_kl > 0 ? forecast_kl / active_row_kl : 0
    product = coverage * forecast_kl
    route_gain = destination_ce - raw_ce

    if (!header++)
        print "cohort", "case", "arm", "life", "split", "feature", \
            "kind", "rank", "authority_score", "route_gain", "raw_ce", \
            "destination_ce", "source_entropy", "target_entropy"
    for (f = 1; f <= feature_count; f++) {
        feature = features[f]
        kind = feature_kind[feature]
        if (kind == "coverage") authority = coverage
        else if (kind == "active-kl") authority = active_row_kl
        else if (kind == "forecast-kl") authority = forecast_kl
        else if (kind == "survival") authority = survival
        else if (kind == "product") authority = product
        else if (kind == "tv") authority = forecast_tv
        else fail()
        print cohort, $3, $2, $4, $5, feature, kind, feature_rank[feature], \
            sprintf("%.9f", authority), sprintf("%.9f", route_gain), \
            sprintf("%.9f", raw_ce), sprintf("%.9f", destination_ce), \
            sprintf("%.9f", entropy(source)), sprintf("%.9f", entropy(target))
    }
    cohort_rows[cohort]++
}

END {
    if (fatal) exit 2
    if (feature_count != feature_expected ||
        cohort_rows["discovery"] != discovery_expected ||
        cohort_rows["validation"] != validation_expected) fail()
}
