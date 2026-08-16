# A.110: predict a four-probe counterfactual response surface from the signed path into one checkpoint.

function fail() {
    if (!fatal) {
        print "road counterfactual-susceptibility report rejected " FILENAME ":" FNR > "/dev/stderr"
        if (reject_context != "")
            print "context " reject_context > "/dev/stderr"
    }
    fatal = 1
    exit 2
}
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
function abs(value) { return value < 0 ? -value : value }
function max(value, floor) { return value < floor ? floor : value }

function parse_vector(value, key, count, allow_negative,    item, n, i, sum) {
    n = split(value, item, "/")
    if (n != count) fail()
    sum = 0
    for (i = 1; i <= n; i++) {
        if (!number(item[i]) || (!allow_negative && item[i] < -0.0000001)) fail()
        vector_value[key SUBSEP i] = item[i] + 0
        sum += vector_value[key SUBSEP i]
    }
    return sum
}

function parse_ids(value, key, count,    item, n, i) {
    n = split(value, item, "/")
    if (n != count) fail()
    for (i = 1; i <= n; i++) {
        if (!integer(item[i]) || item[i] <= 0 || local_id[item[i]]++) fail()
        id_value[key SUBSEP i] = item[i] + 0
    }
    for (i in local_id) delete local_id[i]
}

function parse_members(value, key, count,    item, part, n, i, sum) {
    n = split(value, item, ",")
    if (n != count) fail()
    sum = 0
    for (i = 1; i <= n; i++) {
        if (split(item[i], part, ":") != 2 || !integer(part[1]) ||
            part[1] <= 0 || !number(part[2]) || part[2] < -0.0000001 ||
            local_id[part[1]]++) fail()
        member_id[key SUBSEP i] = part[1] + 0
        target_value[key SUBSEP i] = part[2] + 0
        sum += target_value[key SUBSEP i]
    }
    for (i in local_id) delete local_id[i]
    return sum
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

function normalize_block(value, block,    j, d, total) {
    total = 0
    for (j = 1; j <= 8; j++) {
        d = (block - 1) * 8 + j
        value[d] = max(value[d], 0.000001)
        total += value[d]
    }
    if (total <= 0) fail()
    for (j = 1; j <= 8; j++) {
        d = (block - 1) * 8 + j
        value[d] /= total
    }
}

function ce32(target, prediction,    d, result) {
    result = 0
    for (d = 1; d <= 32; d++)
        result -= target[d] * log(max(prediction[d], 0.000001))
    return result / 4
}

function brier32(target, prediction,    d, delta, result) {
    result = 0
    for (d = 1; d <= 32; d++) {
        delta = target[d] - prediction[d]
        result += delta * delta
    }
    return result / 4
}

function ce_block(target, prediction, block,    j, d, result) {
    result = 0
    for (j = 1; j <= 8; j++) {
        d = (block - 1) * 8 + j
        result -= target[d] * log(max(prediction[d], 0.000001))
    }
    return result
}

function initialize_epoch(life, current_epoch,    key, candidate, texture, i, j, k, d) {
    key = life SUBSEP current_epoch
    if (epoch_initialized[key]++) return

    base_weight[key] = prior_alpha
    for (i = 1; i <= 8; i++) {
        base_source_mean[key SUBSEP i] = 0.125
        base_source_variance[key SUBSEP i] = 0
        for (j = 1; j <= 8; j++)
            base_covariance[key SUBSEP i SUBSEP j] = 0
    }
    for (j = 1; j <= 8; j++)
        base_error_mean[key SUBSEP j] = 0

    for (texture in texture_seen) {
        texture_weight[key SUBSEP texture] = prior_alpha
        for (j = 1; j <= 8; j++)
            texture_error_mean[key SUBSEP texture SUBSEP j] = 0
    }

    for (candidate in policy_seen) {
        reader_key = candidate SUBSEP key
        reader_weight[reader_key] = prior_alpha
        for (k = 1; k <= 24; k++) {
            symmetric_mean[reader_key SUBSEP k] = (k <= 8 || k > 16) ? 0.125 : 0
            symmetric_variance[reader_key SUBSEP k] = 0
            path_mean[reader_key SUBSEP k] = 0
            path_variance[reader_key SUBSEP k] = 0
            for (d = 1; d <= 32; d++) {
                symmetric_covariance[reader_key SUBSEP k SUBSEP d] = 0
                path_covariance[reader_key SUBSEP k SUBSEP d] = 0
            }
        }
        for (d = 1; d <= 32; d++) {
            symmetric_error_mean[reader_key SUBSEP d] = 0
            path_error_mean[reader_key SUBSEP d] = 0
        }
    }
}

function process_surface(life, session,    surface_key, current_epoch, epoch_key,
                         source_key, matrix_key, i, j, k, p, d, edge, total,
                         raw_total, expected_slot, overlap, candidate, reader_key,
                         feature_key, old_weight, new_weight, recenter, texture,
                         texture_key, raw_ce, raw_brier, snapshot_ce, snapshot_brier,
                         texture_ce, texture_brier, symmetric_ce, symmetric_brier,
                         path_ce, path_brier, history_count, centroid, delta) {
    surface_key = life SUBSEP session
    reject_context = "life=" life " session=" session " stage=surface-contract"
    current_epoch = writer_epoch[surface_key SUBSEP 4]
    if (!current_epoch || surface_invalid[surface_key]) {
        censored_surfaces[life]++
        return
    }
    for (p = 1; p <= 4; p++)
        if (!probe_seen[surface_key SUBSEP p]) {
            censored_surfaces[life]++
            return
        }

    for (i = 1; i <= 8; i++) {
        symmetric_feature[i] = 0.5 * (writer_target[surface_key SUBSEP 1 SUBSEP i] + \
                                      writer_target[surface_key SUBSEP 4 SUBSEP i])
        symmetric_feature[8 + i] = abs(writer_target[surface_key SUBSEP 4 SUBSEP i] - \
                                         writer_target[surface_key SUBSEP 1 SUBSEP i])
        symmetric_feature[16 + i] = 0.5 * (writer_target[surface_key SUBSEP 2 SUBSEP i] + \
                                           writer_target[surface_key SUBSEP 3 SUBSEP i])
        path_feature[i] = writer_target[surface_key SUBSEP 2 SUBSEP i] - \
                          writer_target[surface_key SUBSEP 1 SUBSEP i]
        path_feature[8 + i] = writer_target[surface_key SUBSEP 3 SUBSEP i] - \
                              writer_target[surface_key SUBSEP 2 SUBSEP i]
        path_feature[16 + i] = writer_target[surface_key SUBSEP 4 SUBSEP i] - \
                               writer_target[surface_key SUBSEP 3 SUBSEP i]
    }

    source_key = surface_key SUBSEP "source"
    matrix_key = surface_key SUBSEP "matrix"
    total = raw_total = 0
    for (j = 1; j <= 8; j++) raw_common[j] = 0
    for (i = 1; i <= 8; i++)
        for (j = 1; j <= 8; j++) {
            edge = probe_matrix[matrix_key SUBSEP ((i - 1) * 8 + j)]
            raw_common[j] += probe_source[source_key SUBSEP i] * edge
            total += edge
        }
    for (j = 1; j <= 8; j++) raw_total += raw_common[j]
    if (abs(total - probe_transition_total[surface_key]) > 0.00001 ||
        raw_total <= 0) fail()
    for (j = 1; j <= 8; j++) raw_common[j] /= raw_total

    expected_slot = 1
    for (j = 2; j <= 8; j++)
        if (raw_common[j] > raw_common[expected_slot]) expected_slot = j

    for (p = 1; p <= 4; p++) {
        probe_key = surface_key SUBSEP p
        overlap = 0
        for (j = 1; j <= 8; j++) {
            d = (p - 1) * 8 + j
            target32[d] = probe_target[probe_key SUBSEP j]
            raw32[d] = raw_common[j]
            overlap += raw_common[j] * target32[d]
        }
        if (probe_expected[probe_key] != probe_pre_id[probe_key SUBSEP expected_slot] ||
            abs(probe_expected_probability[probe_key] - raw_common[expected_slot]) > 0.002 ||
            abs(probe_overlap[probe_key] - overlap) > 0.002 ||
            !rounded_log_pair(probe_overlap[probe_key], probe_surprise[probe_key])) fail()
    }

    reject_context = "life=" life " session=" session " stage=prediction-contract"
    initialize_epoch(life, current_epoch)
    epoch_key = life SUBSEP current_epoch
    history_count = surface_history[epoch_key] + 0

    for (j = 1; j <= 8; j++) {
        snapshot_common[j] = raw_common[j] + \
            snapshot_strength * base_error_mean[epoch_key SUBSEP j]
        for (i = 1; i <= 8; i++)
            snapshot_common[j] += snapshot_strength * \
                (probe_source[source_key SUBSEP i] - \
                 base_source_mean[epoch_key SUBSEP i]) * \
                base_covariance[epoch_key SUBSEP i SUBSEP j] / \
                (ridge + base_source_variance[epoch_key SUBSEP i])
    }
    for (j = 1; j <= 8; j++) scratch8[j] = snapshot_common[j]
    total = 0
    for (j = 1; j <= 8; j++) {
        scratch8[j] = max(scratch8[j], 0.000001)
        total += scratch8[j]
    }
    for (j = 1; j <= 8; j++) snapshot_common[j] = scratch8[j] / total

    for (p = 1; p <= 4; p++) {
        texture = probe_texture[p]
        texture_key = epoch_key SUBSEP texture
        for (j = 1; j <= 8; j++) {
            d = (p - 1) * 8 + j
            snapshot32[d] = snapshot_common[j]
            texture32[d] = snapshot_common[j] + \
                texture_strength * texture_error_mean[texture_key SUBSEP j]
        }
        normalize_block(texture32, p)
    }

    raw_ce = ce32(target32, raw32)
    raw_brier = brier32(target32, raw32)
    snapshot_ce = ce32(target32, snapshot32)
    snapshot_brier = brier32(target32, snapshot32)
    texture_ce = ce32(target32, texture32)
    texture_brier = brier32(target32, texture32)

    for (p = 1; p <= policy_count; p++) {
        candidate = policies[p]
        reader_key = candidate SUBSEP epoch_key
        for (d = 1; d <= 32; d++) {
            symmetric32[d] = texture32[d]
            for (k = 1; k <= 24; k++) {
                feature_key = reader_key SUBSEP k
                symmetric32[d] += strength[candidate] * \
                    (symmetric_feature[k] - symmetric_mean[feature_key]) * \
                    symmetric_covariance[feature_key SUBSEP d] / \
                    (ridge + symmetric_variance[feature_key])
            }
        }
        for (p2 = 1; p2 <= 4; p2++) normalize_block(symmetric32, p2)

        for (d = 1; d <= 32; d++) {
            path32[d] = symmetric32[d]
            for (k = 1; k <= 24; k++) {
                feature_key = reader_key SUBSEP k
                path32[d] += strength[candidate] * \
                    (path_feature[k] - path_mean[feature_key]) * \
                    path_covariance[feature_key SUBSEP d] / \
                    (ridge + path_variance[feature_key])
            }
        }
        for (p2 = 1; p2 <= 4; p2++) normalize_block(path32, p2)

        symmetric_ce = ce32(target32, symmetric32)
        symmetric_brier = brier32(target32, symmetric32)
        path_ce = ce32(target32, path32)
        path_brier = brier32(target32, path32)

        if (session >= evaluation_session) {
            if (!header++)
                print "candidate", "path_strength", "rank", "cohort", "life", "split",
                    "session", "history_surfaces", "raw_ce", "path_ce", "symmetric_ce",
                    "texture_ce", "snapshot_ce", "raw_brier", "path_brier",
                    "symmetric_brier", "texture_brier", "snapshot_brier",
                    "raw_ce_gain", "raw_brier_gain", "snapshot_ce_gain",
                    "snapshot_brier_gain", "texture_ce_gain", "texture_brier_gain",
                    "symmetric_ce_gain", "symmetric_brier_gain",
                    "snapshot_raw_ce_gain", "texture_snapshot_ce_gain",
                    "home_path_ce_gain", "storm_path_ce_gain",
                    "wonder_path_ce_gain", "social_path_ce_gain"
            print candidate, strength[candidate], rank[candidate], life_cohort[life],
                life, life_split[life], session, history_count,
                sprintf("%.9f", raw_ce), sprintf("%.9f", path_ce),
                sprintf("%.9f", symmetric_ce), sprintf("%.9f", texture_ce),
                sprintf("%.9f", snapshot_ce), sprintf("%.9f", raw_brier),
                sprintf("%.9f", path_brier), sprintf("%.9f", symmetric_brier),
                sprintf("%.9f", texture_brier), sprintf("%.9f", snapshot_brier),
                sprintf("%.9f", raw_ce - path_ce),
                sprintf("%.9f", raw_brier - path_brier),
                sprintf("%.9f", snapshot_ce - path_ce),
                sprintf("%.9f", snapshot_brier - path_brier),
                sprintf("%.9f", texture_ce - path_ce),
                sprintf("%.9f", texture_brier - path_brier),
                sprintf("%.9f", symmetric_ce - path_ce),
                sprintf("%.9f", symmetric_brier - path_brier),
                sprintf("%.9f", raw_ce - snapshot_ce),
                sprintf("%.9f", snapshot_ce - texture_ce),
                sprintf("%.9f", ce_block(target32, symmetric32, 1) - \
                                  ce_block(target32, path32, 1)),
                sprintf("%.9f", ce_block(target32, symmetric32, 2) - \
                                  ce_block(target32, path32, 2)),
                sprintf("%.9f", ce_block(target32, symmetric32, 3) - \
                                  ce_block(target32, path32, 3)),
                sprintf("%.9f", ce_block(target32, symmetric32, 4) - \
                                  ce_block(target32, path32, 4))
            score_rows[candidate SUBSEP life]++
        }

        old_weight = reader_weight[reader_key]
        new_weight = old_weight + 1
        recenter = old_weight / new_weight
        for (k = 1; k <= 24; k++) {
            feature_key = reader_key SUBSEP k
            symmetric_delta[k] = symmetric_feature[k] - symmetric_mean[feature_key]
            path_delta[k] = path_feature[k] - path_mean[feature_key]
        }
        for (d = 1; d <= 32; d++) {
            symmetric_error_delta[d] = target32[d] - texture32[d] - \
                symmetric_error_mean[reader_key SUBSEP d]
            path_error_delta[d] = target32[d] - symmetric32[d] - \
                path_error_mean[reader_key SUBSEP d]
        }
        for (k = 1; k <= 24; k++) {
            feature_key = reader_key SUBSEP k
            symmetric_variance[feature_key] += \
                recenter * symmetric_delta[k] * symmetric_delta[k]
            path_variance[feature_key] += \
                recenter * path_delta[k] * path_delta[k]
            for (d = 1; d <= 32; d++) {
                symmetric_covariance[feature_key SUBSEP d] += \
                    recenter * symmetric_delta[k] * symmetric_error_delta[d]
                path_covariance[feature_key SUBSEP d] += \
                    recenter * path_delta[k] * path_error_delta[d]
            }
            symmetric_mean[feature_key] += symmetric_delta[k] / new_weight
            path_mean[feature_key] += path_delta[k] / new_weight
        }
        for (d = 1; d <= 32; d++) {
            symmetric_error_mean[reader_key SUBSEP d] += \
                symmetric_error_delta[d] / new_weight
            path_error_mean[reader_key SUBSEP d] += path_error_delta[d] / new_weight
        }
        reader_weight[reader_key] = new_weight
    }

    for (p = 1; p <= 4; p++) {
        texture = probe_texture[p]
        texture_key = epoch_key SUBSEP texture
        old_weight = texture_weight[texture_key]
        new_weight = old_weight + 1
        for (j = 1; j <= 8; j++) {
            d = (p - 1) * 8 + j
            delta = target32[d] - snapshot32[d] - \
                texture_error_mean[texture_key SUBSEP j]
            texture_error_mean[texture_key SUBSEP j] += delta / new_weight
        }
        texture_weight[texture_key] = new_weight
    }

    old_weight = base_weight[epoch_key]
    new_weight = snapshot_decay * old_weight + 1
    recenter = snapshot_decay * old_weight / new_weight
    for (i = 1; i <= 8; i++)
        base_source_delta[i] = probe_source[source_key SUBSEP i] - \
            base_source_mean[epoch_key SUBSEP i]
    for (j = 1; j <= 8; j++) {
        centroid = 0
        for (p = 1; p <= 4; p++) centroid += target32[(p - 1) * 8 + j] / 4
        base_error_delta[j] = centroid - raw_common[j] - \
            base_error_mean[epoch_key SUBSEP j]
    }
    for (i = 1; i <= 8; i++) {
        base_source_variance[epoch_key SUBSEP i] = \
            snapshot_decay * base_source_variance[epoch_key SUBSEP i] + \
            recenter * base_source_delta[i] * base_source_delta[i]
        for (j = 1; j <= 8; j++)
            base_covariance[epoch_key SUBSEP i SUBSEP j] = \
                snapshot_decay * base_covariance[epoch_key SUBSEP i SUBSEP j] + \
                recenter * base_source_delta[i] * base_error_delta[j]
        base_source_mean[epoch_key SUBSEP i] += base_source_delta[i] / new_weight
    }
    for (j = 1; j <= 8; j++)
        base_error_mean[epoch_key SUBSEP j] += base_error_delta[j] / new_weight
    base_weight[epoch_key] = new_weight
    surface_history[epoch_key]++
    eligible_surfaces[life]++
}

BEGIN {
    FS = OFS = "\t"
    if (!policy_expected) policy_expected = 2
    if (!life_expected) life_expected = 32
    if (!writer_expected) writer_expected = 64
    if (!probe_expected_rows) probe_expected_rows = 32
    if (!evaluation_session) evaluation_session = 5
    if (!score_min) score_min = 2
    texture_seen["home"] = texture_seen["storm"] = 1
    texture_seen["wonder"] = texture_seen["social"] = 1
    probe_texture[1] = "home"; probe_texture[2] = "storm"
    probe_texture[3] = "wonder"; probe_texture[4] = "social"
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 8 || $1 != "candidate" || $2 != "path_strength" ||
            $3 != "snapshot_decay" || $5 != "texture_strength" ||
            $6 != "prior_alpha" || $8 != "rank") fail()
        next
    }
    if (NF != 8 || $1 !~ /^susceptibility-path-[a-z0-9-]+$/ ||
        policy_seen[$1]++ || !number($2) || $2 <= 0 ||
        !number($3) || $3 != 1 || !number($4) || $4 != 0.25 ||
        !number($5) || $5 != 0.25 || !number($6) || $6 <= 0 ||
        !number($7) || $7 <= 0 || !integer($8) || rank_seen[$8]++) fail()
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
    current_writer_epoch[$2] = 1
    next
}

FILENAME == ARGV[3] {
    if (FNR == 1) {
        if (NF != 31 || $1 != "cohort" || $4 != "turn" ||
            $10 != "pre_ids" || $12 != "transition" || $31 != "reply") fail()
        next
    }
    life = $2
    if (NF != 31 || !(life in lock_seen) || $1 != life_cohort[life] ||
        $3 != life_split[life] || !integer($4) || !integer($5) ||
        !integer($6) || $6 < 1 || $6 > 8 ||
        $4 != 32 + ($5 - 1) * 8 + $6 || !($7 in texture_seen) ||
        $8 !~ /^(updated|replaced)$/ || !integer($9) || $9 != $4 - 1 ||
        !number($14) || $14 <= 0 || !integer($15) || !integer($16) ||
        $17 !~ /^(0|1)$/ || !integer($18) || !number($19) ||
        !number($20) || !number($21) || $30 == "" || $31 == "") fail()
    if (++writer_rows[life] != $4 - 32) fail()

    writer_key = "writer" SUBSEP life SUBSEP $5 SUBSEP $6
    parse_ids($10, writer_key SUBSEP "pre", 8)
    if (abs(parse_vector($13, writer_key SUBSEP "source", 8, 0) - 1) > 0.00001 ||
        abs(parse_vector($12, writer_key SUBSEP "matrix", 64, 0) - $14) > 0.00001 ||
        abs(parse_members($11, writer_key SUBSEP "post", 8) - 1) > 0.006) fail()

    changed = 0
    for (i = 1; i <= 8; i++)
        if (id_value[writer_key SUBSEP "pre" SUBSEP i] != \
            member_id[writer_key SUBSEP "post" SUBSEP i]) changed++
    if (($8 == "updated" && (changed != 0 || $16 != 0)) ||
        ($8 == "replaced" && (changed != 1 || $16 == 0))) fail()
    if ($8 == "replaced") current_writer_epoch[life]++
    writer_epoch[life SUBSEP $5 SUBSEP $6] = current_writer_epoch[life]
    writer_event[life SUBSEP $5 SUBSEP $6] = $8
    for (i = 1; i <= 8; i++)
        writer_target[life SUBSEP $5 SUBSEP $6 SUBSEP i] = \
            target_value[writer_key SUBSEP "post" SUBSEP i]
    next
}

FILENAME == ARGV[4] {
    if (FNR == 1) {
        if (NF != 27 || $1 != "cohort" || $5 != "session" ||
            $6 != "probe" || $11 != "pre_ids" || $27 != "branch_pre_geometry_equal") fail()
        next
    }
    life = $2
    if (NF != 27 || !(life in lock_seen) || $1 != life_cohort[life] ||
        $3 != life_split[life] || !integer($4) || !integer($5) ||
        !integer($6) || $6 < 1 || $6 > 4 || $7 != probe_texture[$6] ||
        !integer($8) || $9 !~ /^(updated|replaced)$/ || !integer($10) ||
        $10 != 32 + ($5 - 1) * 8 + 4 || $4 != $10 + 1 ||
        !number($15) || $15 <= 0 || !integer($16) || !integer($17) ||
        $18 !~ /^(0|1)$/ || !integer($19) || !number($20) ||
        !number($21) || !number($22) || $23 == "" || $24 == "" ||
        length($25) != 64 || $25 !~ /^[0-9a-f]+$/ ||
        $26 != "true" || $27 != "true") fail()

    surface_key = life SUBSEP $5
    probe_key = surface_key SUBSEP $6
    if (probe_seen[probe_key]++) fail()
    probe_parse_key = "probe" SUBSEP probe_key
    parse_ids($11, probe_parse_key SUBSEP "pre", 8)
    if (abs(parse_vector($14, probe_parse_key SUBSEP "source", 8, 0) - 1) > 0.00001 ||
        abs(parse_vector($13, probe_parse_key SUBSEP "matrix", 64, 0) - $15) > 0.00001 ||
        abs(parse_members($12, probe_parse_key SUBSEP "post", 8) - 1) > 0.006) fail()

    if (!surface_probe_count[surface_key]++) {
        surface_pre_ids[surface_key] = $11
        surface_source[surface_key] = $14
        surface_matrix[surface_key] = $13
        surface_total[surface_key] = $15
        surface_checkpoint[surface_key] = $25
        for (i = 1; i <= 8; i++)
            probe_source[surface_key SUBSEP "source" SUBSEP i] = \
                vector_value[probe_parse_key SUBSEP "source" SUBSEP i]
        for (i = 1; i <= 64; i++)
            probe_matrix[surface_key SUBSEP "matrix" SUBSEP i] = \
                vector_value[probe_parse_key SUBSEP "matrix" SUBSEP i]
        probe_transition_total[surface_key] = $15 + 0
    } else if ($11 != surface_pre_ids[surface_key] ||
               $14 != surface_source[surface_key] ||
               $13 != surface_matrix[surface_key] ||
               $15 != surface_total[surface_key] ||
               $25 != surface_checkpoint[surface_key]) fail()

    for (i = 1; i <= 8; i++) {
        probe_pre_id[probe_key SUBSEP i] = \
            id_value[probe_parse_key SUBSEP "pre" SUBSEP i]
        probe_target[probe_key SUBSEP i] = \
            target_value[probe_parse_key SUBSEP "post" SUBSEP i]
    }
    probe_expected[probe_key] = $19 + 0
    probe_expected_probability[probe_key] = $20 + 0
    probe_overlap[probe_key] = $21 + 0
    probe_surprise[probe_key] = $22 + 0

    changed = 0
    for (i = 1; i <= 8; i++)
        if (probe_pre_id[probe_key SUBSEP i] != \
            member_id[probe_parse_key SUBSEP "post" SUBSEP i]) changed++
    if (($9 == "updated" && (changed != 0 || $17 != 0)) ||
        ($9 == "replaced" && (changed != 1 || $17 == 0))) fail()
    if ($9 != "updated" || $18 != 1) surface_invalid[surface_key] = 1
    next
}

END {
    if (fatal || policy_count != policy_expected || lock_count != life_expected) exit 2
    for (l = 1; l <= lock_count; l++) {
        life = life_order[l]
        if (writer_rows[life] != writer_expected) fail()
        for (session = 1; session <= 8; session++) {
            surface_key = life SUBSEP session
            reject_context = "life=" life " session=" session " stage=anatomy"
            if (surface_probe_count[surface_key] != 4) fail()
            reject_context = "life=" life " session=" session " stage=path-anatomy"
            epoch4 = writer_epoch[surface_key SUBSEP 4]
            for (order = 1; order <= 4; order++) {
                writer_key = surface_key SUBSEP order
                if (!writer_epoch[writer_key] || writer_event[writer_key] != "updated" ||
                    writer_epoch[writer_key] != epoch4)
                    surface_invalid[surface_key] = 1
            }
            reject_context = "life=" life " session=" session " stage=checkpoint-identity"
            for (i = 1; i <= 8; i++)
                if (probe_pre_id[surface_key SUBSEP 1 SUBSEP i] != \
                    member_id["writer" SUBSEP life SUBSEP session SUBSEP 4 SUBSEP "post" SUBSEP i])
                    fail()
            process_surface(life, session)
        }
        reject_context = "life=" life " stage=score-count"
        if (eligible_surfaces[life] < score_min) fail()
        for (p = 1; p <= policy_count; p++)
            if (score_rows[policies[p] SUBSEP life] < score_min ||
                score_rows[policies[p] SUBSEP life] > 4) fail()
    }
    if (!header) fail()
}
