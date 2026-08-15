# A.107: count delayed-receipt windows without reading any predictive score.

function fail() { fatal = 1; exit 2 }
function integer(value) { return value ~ /^[0-9]+$/ }

BEGIN { FS = OFS = "\t"; if (!life_expected) life_expected = 64 }

FILENAME == ARGV[1] {
    if (FNR == 1) {
        if (NF != 5 || $1 != "life" || $2 != "split" ||
            $5 != "enrollment_rank") fail()
        next
    }
    if (NF != 5 || $1 !~ /^[ph][0-9][0-9]$/ ||
        $2 !~ /^(primary|holdout)$/ || !integer($5) || $5 < 1 || $5 > 32 ||
        enrolled[$1]++) fail()
    life_order[++enrollment_rows] = $1
    split_name[$1] = $2
    rank[$1] = $5 + 0
    cohort[$1] = $5 <= 16 ? "discovery" : "validation"
    next
}

FNR == 1 {
    if (NF != 34 || $1 != "life" || $5 != "session" || $6 != "order" ||
        $13 != "event" || $20 != "has_prediction" || $34 != "reply") fail()
    next
}

{
    life = $1
    if (NF != 34 || !(life in enrolled) || $2 != split_name[life] ||
        !integer($5) || $5 < 1 || $5 > 8 || !integer($6) || $6 < 1 || $6 > 8 ||
        ++life_rows[life] != ($5 - 1) * 8 + $6 ||
        $13 !~ /^(updated|replaced)$/ || $20 !~ /^(0|1)$/) fail()

    if (!(life in epoch)) epoch[life] = 1
    if ($13 == "replaced") {
        epoch[life]++
        censored[life]++
        next
    }

    key = life SUBSEP epoch[life] SUBSEP $5
    previous = life SUBSEP epoch[life] SUBSEP ($5 - 1)
    if ($20 == 0) {
        invalid[key] = 1
        rows[key]++
        censored[life]++
        next
    }

    if ($6 == 1 && $5 > 1 && rows[previous] == 8 && !invalid[previous])
        boundary[key] = 1
    if ($6 == 5 && boundary[key] && rows[key] == 4 && !invalid[key]) {
        total[life]++
        if ($5 >= 5) scored[life]++
    }
    rows[key]++
}

END {
    if (fatal || enrollment_rows != life_expected) exit 2
    print "cohort", "life", "split", "enrollment_rank", "total_receipts", \
        "scored_receipts", "censored_rows"
    for (i = 1; i <= enrollment_rows; i++) {
        life = life_order[i]
        if (life_rows[life] != 64) fail()
        print cohort[life], life, split_name[life], rank[life], total[life] + 0, \
            scored[life] + 0, censored[life] + 0
    }
}
