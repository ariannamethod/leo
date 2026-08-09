# A.97: nominate one row-authority threshold using discovery only.

function fail() { fatal = 1; exit 2 }
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }

BEGIN {
    FS = OFS = "\t"
    if (!expected) expected = 12
    if (!feature_expected) feature_expected = 6
    if (!high_expected) high_expected = 6
    if (!win_required) win_required = 4
    if (!gain_required) gain_required = 0.015
    if (!separation_required) separation_required = 0.010
    epsilon = 0.000000000001
}

NR == 1 {
    if (NF != 14 || $1 != "cohort" || $6 != "feature" ||
        $9 != "authority_score" || $14 != "target_entropy") fail()
    next
}

$1 == "discovery" {
    if (NF != 14 || $2 == "" || $3 !~ /^(event|ecology)$/ ||
        $5 != "primary" || $6 !~ /^[a-z][a-z0-9-]+$/ ||
        $7 !~ /^(coverage|active-kl|forecast-kl|survival|product|tv)$/ ||
        !integer($8) || !number($9) || !number($10) ||
        seen[$6 SUBSEP $2]++) fail()
    feature = $6
    if (!(feature in feature_seen)) {
        feature_seen[feature] = 1
        features[++feature_count] = feature
        kinds[feature] = $7
        ranks[feature] = $8 + 0
        if (rank_seen[$8]++) fail()
    } else if (kinds[feature] != $7 || ranks[feature] != $8) fail()
    count[feature]++
    cases[feature SUBSEP count[feature]] = $2
    score[feature SUBSEP $2] = $9 + 0
    gain[feature SUBSEP $2] = $10 + 0
}

END {
    if (fatal) exit 2
    if (feature_count != feature_expected || high_expected * 2 != expected) fail()
    qualified = 0
    for (f = 1; f <= feature_count; f++) {
        feature = features[f]
        if (count[feature] != expected) fail()
        for (i = 1; i <= expected; i++) order[i] = cases[feature SUBSEP i]
        for (i = 1; i < expected; i++) {
            best = i
            for (j = i + 1; j <= expected; j++) {
                left = order[j]
                right = order[best]
                if (score[feature SUBSEP left] > score[feature SUBSEP right] + epsilon ||
                    (abs(score[feature SUBSEP left] - score[feature SUBSEP right]) <= epsilon && left < right)) best = j
            }
            swap = order[i]; order[i] = order[best]; order[best] = swap
        }
        high_sum = 0
        low_sum = 0
        high_wins = 0
        for (i = 1; i <= high_expected; i++) {
            value = gain[feature SUBSEP order[i]]
            high_sum += value
            if (value > 0) high_wins++
        }
        for (i = high_expected + 1; i <= expected; i++)
            low_sum += gain[feature SUBSEP order[i]]
        high_mean = high_sum / high_expected
        low_mean = low_sum / (expected - high_expected)
        separation = high_mean - low_mean
        boundary_high = score[feature SUBSEP order[high_expected]]
        boundary_low = score[feature SUBSEP order[high_expected + 1]]
        strict_boundary = boundary_high > boundary_low + epsilon
        if (strict_boundary && high_wins >= win_required &&
            high_mean >= gain_required && separation >= separation_required) {
            threshold = (boundary_high + boundary_low) / 2
            qualified++
            if (!selected || separation > best_separation + epsilon ||
                (abs(separation - best_separation) <= epsilon && ranks[feature] < best_rank)) {
                selected = feature
                best_kind = kinds[feature]
                best_rank = ranks[feature]
                best_threshold = threshold
                best_wins = high_wins
                best_high_mean = high_mean
                best_low_mean = low_mean
                best_separation = separation
            }
        }
        delete order
    }

    print "feature", "kind", "rank", "threshold", "discovery_arms", \
        "high_arms", "high_wins", "high_mean_gain", "low_mean_gain", \
        "separation", "qualified_features", "result"
    if (selected)
        print selected, best_kind, best_rank, sprintf("%.9f", best_threshold), \
            expected, high_expected, best_wins, sprintf("%.9f", best_high_mean), \
            sprintf("%.9f", best_low_mean), sprintf("%.9f", best_separation), \
            qualified, "candidate-nominated"
    else
        print "none", "none", 0, "0.000000000", expected, high_expected, 0, \
            "0.000000000", "0.000000000", "0.000000000", 0, \
            "no-row-authority-candidate"
}
