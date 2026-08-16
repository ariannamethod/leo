# A.111: score paired default/ablation roads from exact pre-update geometry.

function fail(message) {
    if (message != "") print "transition-plasticity reporter: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }

function vector(value, out, count, high,    item, n, i, sum) {
    if (high == "") high = 1.0001
    n = split(value, item, "/")
    if (n != count) fail("wrong vector width expected=" count " got=" n)
    sum = 0
    for (i = 1; i <= count; i++) {
        if (!number(item[i]) || item[i] + 0 < -0.000001 ||
            item[i] + 0 > high) fail("invalid vector value")
        out[i] = item[i] + 0
        sum += out[i]
    }
    return sum
}

function entropy(value,    i, result) {
    result = 0
    for (i = 1; i <= 8; i++)
        if (value[i] > 0) result -= value[i] * log(value[i])
    return result / log(8)
}

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 19 || $1 != "cohort" || $5 != "arm" ||
        $11 != "pre_turn" || $14 != "transition" ||
        $18 != "target" || $19 != "has_prediction")
        fail("bad header")
    next
}

{
    if (NF != 19 || $1 !~ /^(discovery|validation)$/ ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        !integer($4) || $4 < 1 || $4 > 32 || $5 !~ /^(on|off)$/ ||
        !integer($6) || $6 < 1 || $6 > 6 ||
        !integer($7) || $7 < 1 || $7 > 8 ||
        $8 !~ /^(home|storm|wonder|social)$/ ||
        $9 !~ /^(updated|born|replaced)$/ || $10 == "" ||
        !integer($11) || !integer($16) || $16 != $11 + 1 ||
        !number($15) || $15 < 0 || ($19 != 0 && $19 != 1))
        fail("invalid row")

    turn_key = $1 SUBSEP $2 SUBSEP $6 SUBSEP $7
    arm_key = turn_key SUBSEP $5
    if (seen_arm[arm_key]++) fail("duplicate arm turn")
    life_key = $1 SUBSEP $2
    life_arm_key = life_key SUBSEP $5
    life_arm_rows[life_arm_key]++
    if (!(life_key in seen_life)) {
        seen_life[life_key] = 1
        life_keys[++life_count] = life_key
    }

    source_sum = vector($13, source, 8)
    matrix_sum = vector($14, matrix, 64, 1000000.0001)
    target_sum = vector($18, target, 8)
    if (abs(source_sum - 1) > 0.00001 ||
        abs(target_sum - 1) > 0.00001 ||
        abs(matrix_sum - $15) > 0.0001)
        fail("geometry total mismatch")

    prediction_total = 0
    for (j = 1; j <= 8; j++) {
        prediction[j] = 0
        for (i = 1; i <= 8; i++)
            prediction[j] += source[i] * matrix[(i - 1) * 8 + j]
        prediction_total += prediction[j]
    }
    rebuilt_prediction = prediction_total > 0 ? 1 : 0
    if (rebuilt_prediction != $19) fail("runtime prediction flag mismatch")

    overlap = 0
    brier = 0
    if (rebuilt_prediction) {
        for (j = 1; j <= 8; j++) {
            prediction[j] /= prediction_total
            overlap += prediction[j] * target[j]
            delta = target[j] - prediction[j]
            brier += delta * delta
        }
    }
    surprise = rebuilt_prediction ? -log(overlap > 0.000001 ? overlap : 0.000001) : 0

    event[arm_key] = $9
    reply[arm_key] = $10
    pre_ids[arm_key] = $12
    post_ids[arm_key] = $17
    has_prediction[arm_key] = $19 + 0
    surprise_value[arm_key] = surprise
    brier_value[arm_key] = brier
    entropy_value[arm_key] = entropy(target)
    cohort[turn_key] = $1
    life[turn_key] = $2
    split_name[turn_key] = $3
    rank[turn_key] = $4
    session[turn_key] = $6
    turn_order[turn_key] = $7
    texture[turn_key] = $8
    if ($6 >= 4 && $5 == "on") turn_keys[++turn_count] = turn_key
}

END {
    if (fatal) exit 2
    for (i = 1; i <= life_count; i++) {
        key = life_keys[i]
        if (life_arm_rows[key SUBSEP "on"] != 48 ||
            life_arm_rows[key SUBSEP "off"] != 48)
            fail("incomplete paired life")
    }
    if (turn_count != life_count * 24) fail("incomplete evaluation window")

    print "cohort", "life", "split", "rank", "session", "order", \
        "texture", "eligible", "reason", "off_surprise", "on_surprise", \
        "surprise_gain", "off_brier", "on_brier", "brier_gain", \
        "off_entropy", "on_entropy", "entropy_delta", "reply_equal"

    for (n = 1; n <= turn_count; n++) {
        key = turn_keys[n]
        on_key = key SUBSEP "on"
        off_key = key SUBSEP "off"
        if (!(off_key in seen_arm)) fail("missing off arm")
        same_reply = reply[on_key] == reply[off_key]
        reason = "none"
        eligible = 1
        if (!same_reply) { eligible = 0; reason = "reply" }
        else if (event[on_key] != "updated" || event[off_key] != "updated") {
            eligible = 0; reason = "event"
        } else if (!has_prediction[on_key] || !has_prediction[off_key]) {
            eligible = 0; reason = "forecast"
        } else if (pre_ids[on_key] != post_ids[on_key] ||
                   pre_ids[off_key] != post_ids[off_key] ||
                   pre_ids[on_key] != pre_ids[off_key] ||
                   post_ids[on_key] != post_ids[off_key]) {
            eligible = 0; reason = "topology"
        }
        off_surprise = surprise_value[off_key]
        on_surprise = surprise_value[on_key]
        off_brier = brier_value[off_key]
        on_brier = brier_value[on_key]
        off_entropy = entropy_value[off_key]
        on_entropy = entropy_value[on_key]
        print cohort[key], life[key], split_name[key], rank[key], session[key], \
            turn_order[key], texture[key], eligible, reason, \
            sprintf("%.9f", off_surprise), sprintf("%.9f", on_surprise), \
            sprintf("%.9f", off_surprise - on_surprise), \
            sprintf("%.9f", off_brier), sprintf("%.9f", on_brier), \
            sprintf("%.9f", off_brier - on_brier), \
            sprintf("%.9f", off_entropy), sprintf("%.9f", on_entropy), \
            sprintf("%.9f", on_entropy - off_entropy), same_reply ? 1 : 0
    }
}
