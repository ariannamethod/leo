# A.110: gate complete four-probe surfaces before any loss is computed.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = OFS = "\t"
    if (!life_expected) life_expected = 32
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 8 || $1 != "cohort" || $4 != "writer_turns" ||
            $8 != "final_state_sha") fail()
        next
    }
    if (NF != 8 || $1 !~ /^(discovery|validation)$/ ||
        $2 !~ /^[ph][0-9][0-9]$/ || $3 !~ /^(primary|holdout)$/ ||
        $4 != 64 || $5 != "true" || $6 != "true" || life_seen[$2]++) fail()
    life_order[++life_count] = $2
    cohort[$2] = $1
    split_name[$2] = $3
    next
}

FILENAME == ARGV[2] {
    if (FNR == 1) {
        if (NF != 31 || $1 != "cohort" || $5 != "session" ||
            $6 != "order" || $8 != "event") fail()
        next
    }
    if (NF != 31 || !($2 in life_seen) || $1 != cohort[$2] ||
        $3 != split_name[$2]) fail()
    if ($5 >= 5 && $5 <= 8 && $6 >= 1 && $6 <= 4) {
        key = $2 SUBSEP $5
        writer_rows[key]++
        if ($8 != "updated" || $16 != 0) writer_invalid[key] = 1
    }
    next
}

FILENAME == ARGV[3] {
    if (FNR == 1) {
        if (NF != 27 || $1 != "cohort" || $5 != "session" ||
            $6 != "probe" || $9 != "event" ||
            $27 != "branch_pre_geometry_equal") fail()
        next
    }
    if (NF != 27 || !($2 in life_seen) || $1 != cohort[$2] ||
        $3 != split_name[$2]) fail()
    if ($5 >= 5 && $5 <= 8) {
        key = $2 SUBSEP $5
        probe_rows[key]++
        if ($9 != "updated" || $17 != 0 || $18 != 1 ||
            $26 != "true" || $27 != "true") probe_invalid[key] = 1
    }
    next
}

END {
    if (fatal || life_count != life_expected) exit 2
    print "cohort", "life", "split", "candidate_surfaces",
        "eligible_surfaces", "writer_censored", "probe_censored"
    for (n = 1; n <= life_count; n++) {
        life = life_order[n]
        eligible = writer_cut = probe_cut = 0
        for (session = 5; session <= 8; session++) {
            key = life SUBSEP session
            if (writer_rows[key] != 4 || probe_rows[key] != 4) fail()
            if (writer_invalid[key]) writer_cut++
            else if (probe_invalid[key]) probe_cut++
            else eligible++
        }
        print cohort[life], life, split_name[life], 4,
            eligible, writer_cut, probe_cut
    }
}
