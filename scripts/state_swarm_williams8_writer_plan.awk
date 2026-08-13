# Emit a per-life Williams design for eight writer-session blocks.

function fail() {
    fatal = 1
    exit 2
}

BEGIN {
    FS = OFS = "\t"
    # Paired bases cover every carryover in the session-5..8 score window;
    # the antipodal edge is the one symmetric repeat forced by 64 / 56.
    base_a[1] = 1; base_a[2] = 2; base_a[3] = 8; base_a[4] = 3
    base_a[5] = 7; base_a[6] = 4; base_a[7] = 6; base_a[8] = 5
    base_b[1] = 1; base_b[2] = 3; base_b[3] = 8; base_b[4] = 7
    base_b[5] = 2; base_b[6] = 6; base_b[7] = 4; base_b[8] = 5
    if (!primary_expected) primary_expected = 32
    if (!holdout_expected) holdout_expected = 32
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 5 || $1 != "kind" || $2 != "session" ||
            $3 != "order" || $4 != "texture" || $5 != "prompt") fail()
        next
    }
    if (NF != 5 || $1 !~ /^(writer|probe)$/ || $5 == "") fail()
    if ($1 == "probe") next
    if ($2 !~ /^[1-8]$/ || $3 !~ /^[1-8]$/ ||
        $4 !~ /^(home|storm|wonder|social)$/ ||
        writer_seen[$2 SUBSEP $3]++ || prompt_seen[$5]++) fail()
    writer_texture[$2 SUBSEP $3] = $4
    writer_prompt[$2 SUBSEP $3] = $5
    writer_rows++
    next
}

FNR == 1 {
    if (writer_rows != 64 || NF != 5 || $1 != "life" || $2 != "split" ||
        $3 != "base_seed" || $4 != "candidate_order" ||
        $5 != "enrollment_rank") fail()
    print "life", "split", "base_seed", "phase", "session", "order", \
        "texture", "run_seed", "prompt"
    next
}

{
    life = $1
    cohort = $2
    seed = $3
    rank = $5
    if (NF != 5 || life !~ /^[ph][0-9][0-9]$/ ||
        cohort !~ /^(primary|holdout)$/ || seed !~ /^[0-9]+$/ ||
        $4 !~ /^[0-9]+$/ || rank !~ /^[0-9]+$/ || rank < 1 ||
        life_seen[life]++ || seed_seen[seed]++ ||
        rank_seen[cohort SUBSEP rank]++ || rank != ++cohort_rows[cohort] ||
        (cohort == "primary" && life !~ /^p/) ||
        (cohort == "holdout" && life !~ /^h/)) fail()

    rotation = (rank - 1) % 8
    design_block = int((rank - 1) / 8) % 2
    score_block = int((rank - 1) / 16) + 1
    previous = 0
    for (chronological = 1; chronological <= 8; chronological++) {
        source_session = design_block == 0 ? base_a[chronological] : base_b[chronological]
        source_session = ((source_session - 1 + rotation) % 8) + 1
        position_count[cohort SUBSEP chronological SUBSEP source_session]++
        if (previous)
            carry_count[cohort SUBSEP previous SUBSEP source_session]++
        if (chronological >= 5) {
            score_position_count[cohort SUBSEP score_block SUBSEP chronological SUBSEP source_session]++
            score_carry_count[cohort SUBSEP score_block SUBSEP previous SUBSEP source_session]++
        }
        previous = source_session
        for (order = 1; order <= 8; order++) {
            key = source_session SUBSEP order
            if (!writer_seen[key]) fail()
            run_seed = seed + chronological * 100 + order
            print life, cohort, seed, "writer", chronological, order, \
                writer_texture[key], run_seed, writer_prompt[key]
            output_rows++
        }
    }
}

END {
    if (fatal) exit 2
    expected["primary"] = primary_expected
    expected["holdout"] = holdout_expected
    if (writer_rows != 64 || cohort_rows["primary"] != primary_expected ||
        cohort_rows["holdout"] != holdout_expected ||
        output_rows != (primary_expected + holdout_expected) * 64) fail()
    for (c = 1; c <= 2; c++) {
        cohort = c == 1 ? "primary" : "holdout"
        if (expected[cohort] % 16 != 0) fail()
        repeats = expected[cohort] / 8
        for (chronological = 1; chronological <= 8; chronological++)
            for (source_session = 1; source_session <= 8; source_session++)
                if (position_count[cohort SUBSEP chronological SUBSEP source_session] != repeats)
                    fail()
        for (source_session = 1; source_session <= 8; source_session++)
            for (destination = 1; destination <= 8; destination++) {
                observed = carry_count[cohort SUBSEP source_session SUBSEP destination] + 0
                if ((source_session == destination && observed != 0) ||
                    (source_session != destination && observed != repeats)) fail()
            }
        for (score_block = 1; score_block <= expected[cohort] / 16; score_block++) {
            for (chronological = 5; chronological <= 8; chronological++)
                for (source_session = 1; source_session <= 8; source_session++)
                    if (score_position_count[cohort SUBSEP score_block SUBSEP chronological SUBSEP source_session] != 2)
                        fail()
            for (source_session = 1; source_session <= 8; source_session++)
                for (destination = 1; destination <= 8; destination++) {
                    observed = score_carry_count[cohort SUBSEP score_block SUBSEP source_session SUBSEP destination] + 0
                    expected_pair = source_session == destination ? 0 : \
                        (destination == ((source_session - 1 + 4) % 8) + 1 ? 2 : 1)
                    if (observed != expected_pair) fail()
                }
        }
    }
}
