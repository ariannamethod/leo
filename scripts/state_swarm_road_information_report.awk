# A.95: reconstruct every proper score and transition-information witness.

function fail() {
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

BEGIN { FS = OFS = "\t"; if (!expected) expected = 30 }

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 16 || $1 != "pair" || $2 != "arm" ||
            $6 != "anchor_turn" || $13 != "a92_reply_equal" ||
            $16 != "geometry_equal") fail()
        next
    }
    key = $1 SUBSEP $2
    if (NF != 16 || seen_lock[key]++ || $1 !~ /^[0-9][0-9]$/ ||
        $2 !~ /^(event|ecology)$/ || $4 !~ /^[ph][0-9][0-9]$/ ||
        $5 !~ /^(primary|holdout)$/ || !integer($6) || !integer($7) ||
        $6 + $7 != 96) fail()
    for (i = 8; i <= 12; i++)
        if (length($i) != 64 || $i !~ /^[0-9a-f]+$/) fail()
    for (i = 13; i <= 16; i++) if ($i != "true") fail()
    anchor[key] = $3
    life[key] = $4
    split_name[key] = $5
    anchor_turn[key] = $6 + 0
    locks++
    next
}

FNR == 1 {
    if (NF != 28 || $1 != "pair" || $9 != "transition" ||
        $13 != "destination_prior" || $16 != "mutual_information" ||
        $19 != "conditional_ce" || $23 != "conditional_brier" ||
        $28 != "reply") fail()
    next
}

{
    key = $1 SUBSEP $2
    if (NF != 28 || !(key in anchor) || seen_score[key]++ ||
        $3 != anchor[key] || $4 != life[key] || $5 != split_name[key] ||
        !integer($6) || !integer($7) || $6 != anchor_turn[key] ||
        $7 != $6 + 1 || $8 !~ /^(home|storm|wonder|social)$/ ||
        $27 == "" || $28 == "") fail()
    if (abs(vector($9, matrix, 64) - $14) > 0.00001 ||
        abs(vector($10, source, 8) - 1) > 0.00001 ||
        abs(vector($11, target, 8) - 1) > 0.00001 ||
        abs(vector($12, conditional, 8) - 1) > 0.00001 ||
        abs(vector($13, destination, 8) - 1) > 0.00001) fail()
    for (i = 14; i <= 26; i++) if (!number($i)) fail()

    total = 0
    conditional_total = 0
    for (i = 1; i <= 8; i++) {
        row[i] = 0
        column[i] = 0
        rebuilt[i] = 0
    }
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            row[i] += edge
            column[j] += edge
            rebuilt[j] += source[i] * edge
            total += edge
        }
    for (j = 1; j <= 8; j++) conditional_total += rebuilt[j]
    if (total <= 0 || conditional_total <= 0 || abs(total - $14) > 0.00001)
        fail()
    for (j = 1; j <= 8; j++) {
        rebuilt[j] /= conditional_total
        prior[j] = column[j] / total
        uniform[j] = 0.125
        if (abs(rebuilt[j] - conditional[j]) > 0.000002 ||
            abs(prior[j] - destination[j]) > 0.000002) fail()
    }

    h = entropy(prior)
    mi = 0
    tv = 0
    for (i = 1; i <= 8; i++) {
        if (row[i] <= 0) continue
        row_tv = 0
        for (j = 1; j <= 8; j++) {
            edge = matrix[(i - 1) * 8 + j]
            if (edge > 0 && prior[j] > 0)
                mi += (edge / total) * log(edge / (row[i] * prior[j]))
            row_tv += abs(edge / row[i] - prior[j])
        }
        tv += (row[i] / total) * 0.5 * row_tv
    }
    nmi = h > 0 ? mi / h : 0
    target_h = entropy(target)
    cond_ce = ce(target, conditional)
    dest_ce = ce(target, destination)
    uniform_ce = ce(target, uniform)
    persist_ce = ce(target, source)
    cond_brier = brier(target, conditional)
    dest_brier = brier(target, destination)
    uniform_brier = brier(target, uniform)
    persist_brier = brier(target, source)
    if (abs(h - $15) > 0.000002 || abs(mi - $16) > 0.000002 ||
        abs(nmi - $17) > 0.000002 || abs(tv - $18) > 0.000002 ||
        abs(cond_ce - $19) > 0.000002 || abs(dest_ce - $20) > 0.000002 ||
        abs(uniform_ce - $21) > 0.000002 ||
        abs(persist_ce - $22) > 0.000002 ||
        abs(cond_brier - $23) > 0.000002 ||
        abs(dest_brier - $24) > 0.000002 ||
        abs(uniform_brier - $25) > 0.000002 ||
        abs(persist_brier - $26) > 0.000002) fail()

    if (!header++)
        print "pair", "arm", "anchor", "life", "split", "anchor_turn", \
              "conditional_ce", "destination_ce", "uniform_ce", \
              "persistence_ce", "conditional_brier", "destination_brier", \
              "uniform_brier", "persistence_brier", \
              "destination_ce_gain", "destination_brier_gain", \
              "uniform_ce_gain", "uniform_brier_gain", "normalized_mi", \
              "mean_row_tv", "destination_entropy", "target_entropy"
    print $1, $2, $3, $4, $5, $6, sprintf("%.9f", cond_ce), \
          sprintf("%.9f", dest_ce), sprintf("%.9f", uniform_ce), \
          sprintf("%.9f", persist_ce), sprintf("%.9f", cond_brier), \
          sprintf("%.9f", dest_brier), sprintf("%.9f", uniform_brier), \
          sprintf("%.9f", persist_brier), sprintf("%.9f", dest_ce - cond_ce), \
          sprintf("%.9f", dest_brier - cond_brier), \
          sprintf("%.9f", uniform_ce - cond_ce), \
          sprintf("%.9f", uniform_brier - cond_brier), \
          sprintf("%.9f", nmi), sprintf("%.9f", tv), sprintf("%.9f", h), \
          sprintf("%.9f", target_h)
    scores++
}

END {
    if (fatal) exit 2
    if (locks != expected || scores != expected) fail()
}
