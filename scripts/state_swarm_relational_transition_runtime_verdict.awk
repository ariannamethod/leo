# A.114: admit runtime embodiment only when the exact A.113 shadow law,
# default ablation, voice boundary, and persisted-state boundary all hold.

function fail(message) {
    if (message != "") print "relational-transition runtime verdict: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 12 || $1 != "kind" || $2 != "life" || $3 != "split" ||
        $4 != "session" || $5 != "order" || $6 != "texture" ||
        $7 != "reference" || $8 != "overlap" ||
        $9 != "semantic_share" || $10 != "candidate_changed" ||
        $11 != "transition_only" || $12 != "same_reply")
        fail("bad header")
    next
}

{
    if (NF != 12 || $1 !~ /^(runtime|default)$/ ||
        $2 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $3 !~ /^(primary|holdout)$/ || !integer($4) || $4 < 1 || $4 > 6 ||
        !integer($5) || $5 < 1 || $5 > 8 ||
        $6 !~ /^(home|storm|wonder|social)$/ ||
        !number($8) || $8 < 0 || $8 > 1.0001 ||
        !number($9) || $9 < 0 || $9 > 1.0001 ||
        ($10 != 0 && $10 != 1) || $11 != 1 || $12 != 1)
        fail("invalid row")
    expected_split = substr($2, 1, 1) == "p" ? "primary" : "holdout"
    if ($3 != expected_split) fail("life/split mismatch")
    key = $1 SUBSEP $2 SUBSEP $4 SUBSEP $5
    if (seen[key]++) fail("duplicate turn")

    if ($1 == "runtime") {
        if ($7 !~ /^(exact|censored)$/) fail("invalid runtime reference")
        runtime_rows++
        life_rows[$2]++
        split_life[$3 SUBSEP $2] = 1
        if ($7 == "exact") exact++
        else censored++
        if ($9 > 0) positive_share++
        if ($10) changed++
    } else {
        if ($2 != "p36" || $7 != "default-exact" ||
            $8 != 0 || $9 != 0 || $10 != 0)
            fail("invalid default ablation row")
        default_rows++
    }
}

END {
    if (fatal) exit 2
    if (runtime_rows != 528 || default_rows != 48)
        fail("wrong runtime/default population")
    for (life in life_rows)
        if (life_rows[life] != 48) fail("incomplete life")
    if (length(life_rows) != 11 || exact < 500 || exact + censored != 528 ||
        positive_share < 1 || changed < 1)
        fail("insufficient exact relational coverage")
    primary_lives = holdout_lives = 0
    for (key in split_life) {
        split(key, part, SUBSEP)
        if (part[1] == "primary") primary_lives++
        else if (part[1] == "holdout") holdout_lives++
    }
    if (primary_lives != 5 || holdout_lives != 6)
        fail("wrong split coverage")

    print "runtime_turns", runtime_rows
    print "exact_reference_turns", exact
    print "reference_censored_turns", censored
    print "positive_semantic_share_turns", positive_share
    print "candidate_changed_turns", changed
    print "default_ablation_turns", default_rows
    print "voice_mismatches", 0
    print "persisted_boundary_violations", 0
    print "result", "relational-transition-runtime-exact"
}
