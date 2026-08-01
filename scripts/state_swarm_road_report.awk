# A.81: score Leo's prospective road forecast against fixed readerless controls.

function clamp_overlap(value) {
    return value < 0.000001 ? 0.000001 : value
}

function parse_members(value, cell, turn,    item, n, i, split_at, id, mass) {
    n = split(value, item, ",")
    for (i = 1; i <= n; i++) {
        split_at = index(item[i], ":")
        if (!split_at) exit 2
        id = substr(item[i], 1, split_at - 1) + 0
        mass = substr(item[i], split_at + 1) + 0
        activation[cell SUBSEP turn SUBSEP id] = mass
        if (id > max_id[cell]) max_id[cell] = id
    }
}

function dot_turns(cell, left, right,    id, total) {
    total = 0
    for (id = 1; id <= max_id[cell]; id++)
        total += activation[cell SUBSEP left SUBSEP id] * activation[cell SUBSEP right SUBSEP id]
    return total
}

BEGIN {
    FS = "\t"
    OFS = "\t"
}

NR == 1 { next }
$4 != "writer" { next }
{
    cell = $1
    cohort[cell] = $2
    seed[cell] = $3
    session = $5 + 0
    order = $6 + 0
    turn = ++turns[cell]
    if (turn != $9 + 0 || session < 1 || session > 6 || order < 1 || order > 8)
        exit 2

    parse_members($16, cell, turn)
    key = cell SUBSEP session
    rows[key]++
    states[key] = $10 + 0
    if ($13 == "born") births[key]++
    else if ($13 == "updated") updates[key]++
    else if ($13 == "replaced") replacements[key]++
    else exit 2

    if ($20 + 0 == 1) {
        predictions[key]++
        raw[key] += $24 + 0
        uniform[key] += log($10 + 0)
        mae[key] += ((($25 - $29) < 0 ? -($25 - $29) : ($25 - $29)) + (($26 - $30) < 0 ? -($26 - $30) : ($26 - $30)) + (($27 - $31) < 0 ? -($27 - $31) : ($27 - $31)) + (($28 - $32) < 0 ? -($28 - $32) : ($28 - $32))) / 4

        overlap = dot_turns(cell, turn - 1, turn)
        persistence[key] += -log(clamp_overlap(overlap))

        overlap = 0
        for (id = 1; id <= max_id[cell]; id++)
            overlap += (marginal[cell SUBSEP id] / (turn - 1)) * activation[cell SUBSEP turn SUBSEP id]
        marginal_score[key] += -log(clamp_overlap(overlap))

        position_count = position_seen[cell SUBSEP order] + 0
        if (position_count > 0) {
            overlap = 0
            for (id = 1; id <= max_id[cell]; id++)
                overlap += (position_mass[cell SUBSEP order SUBSEP id] / position_count) * activation[cell SUBSEP turn SUBSEP id]
            position_score[key] += -log(clamp_overlap(overlap))
            position_coverage[key]++
        }

        kernel_weight = 0
        kernel_overlap = 0
        for (target_turn = 2; target_turn < turn; target_turn++) {
            source_similarity = dot_turns(cell, turn - 1, target_turn - 1)
            if (source_similarity <= 0.000001) continue
            target_overlap = dot_turns(cell, target_turn, turn)
            kernel_weight += source_similarity
            kernel_overlap += source_similarity * target_overlap
        }
        if (kernel_weight > 0.000001) {
            kernel_score[key] += -log(clamp_overlap(kernel_overlap / kernel_weight))
            kernel_coverage[key]++
        }
    }

    for (id = 1; id <= max_id[cell]; id++) {
        mass = activation[cell SUBSEP turn SUBSEP id]
        marginal[cell SUBSEP id] += mass
        position_mass[cell SUBSEP order SUBSEP id] += mass
    }
    position_seen[cell SUBSEP order]++
}

END {
    if (turns["river"] != 48 || turns["window"] != 48 ||
        turns["lantern"] != 48 || length(turns) != 3)
        exit 2
    for (cell in turns)
        for (session = 1; session <= 6; session++) {
            key = cell SUBSEP session
            if (rows[key] != 8) exit 2
            n = predictions[key]
            position_mean = position_coverage[key] ? position_score[key] / position_coverage[key] : 0
            kernel_mean = kernel_coverage[key] ? kernel_score[key] / kernel_coverage[key] : 0
            printf "%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%.6f\t%d\t%.6f\n",
                   cell, cohort[cell], seed[cell], session, rows[key],
                   states[key], births[key] + 0, updates[key] + 0,
                   replacements[key] + 0, n + 0,
                   n ? raw[key] / n : 0,
                   n ? uniform[key] / n : 0,
                   n ? (raw[key] - uniform[key]) / n : 0,
                   n ? persistence[key] / n : 0,
                   n ? marginal_score[key] / n : 0,
                   position_mean,
                   position_coverage[key] + 0,
                   kernel_mean,
                   kernel_coverage[key] + 0,
                   n ? mae[key] / n : 0
        }
}
