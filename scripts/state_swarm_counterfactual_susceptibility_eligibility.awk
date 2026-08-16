# A.110: preregister response-surface eligibility from writer anatomy alone.

function fail() { fatal = 1; exit 2 }

BEGIN {
    FS = OFS = "\t"
    if (!life_expected) life_expected = 64
}

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 5 || $1 != "life" || $2 != "split" ||
            $5 != "enrollment_rank") fail()
        next
    }
    if (NF != 5 || $1 !~ /^[ph][0-9][0-9]$/ ||
        $2 !~ /^(primary|holdout)$/ || $5 < 1 || $5 > 32 ||
        enrollment_seen[$1]++) fail()
    life_order[++life_count] = $1
    split_name[$1] = $2
    rank[$1] = $5
    cohort[$1] = $5 <= 16 ? "discovery" : "validation"
    next
}

FNR == 1 {
    if (NF != 34 || $1 != "life" || $5 != "session" ||
        $13 != "event" || $19 != "replaced" || $34 != "reply") fail()
    next
}

{
    life = $1
    if (NF != 34 || !(life in enrollment_seen) || $2 != split_name[life] ||
        $5 < 1 || $5 > 8 || $6 < 1 || $6 > 8 ||
        ++writer_rows[life] != ($5 - 1) * 8 + $6 ||
        $13 !~ /^(updated|replaced)$/ || $19 !~ /^[0-9]+$/) fail()
    if ($5 >= 5 && $6 <= 4) {
        key = life SUBSEP $5
        surface_rows[key]++
        if ($13 != "updated" || $19 != 0) surface_invalid[key] = 1
    }
}

END {
    if (fatal || life_count != life_expected) exit 2
    print "cohort", "life", "split", "enrollment_rank",
        "candidate_surfaces", "scored_surfaces", "censored_sessions"
    for (n = 1; n <= life_count; n++) {
        life = life_order[n]
        if (writer_rows[life] != 64) fail()
        scored = censored = 0
        for (session = 5; session <= 8; session++) {
            key = life SUBSEP session
            if (surface_rows[key] != 4) fail()
            if (surface_invalid[key]) censored++
            else scored++
        }
        print cohort[life], life, split_name[life], rank[life], 4, scored, censored
    }
}
