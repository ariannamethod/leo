# A.115: admit the confirmed relational transition law as ordinary runtime
# only when default, explicit-on, and historical A.79 remain exactly bounded.

function fail(message) {
    if (message != "") print "relational-transition default verdict: " message > "/dev/stderr"
    fatal = 1
    exit 2
}

function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 14 || $1 != "life" || $2 != "split" ||
        $3 != "session" || $4 != "order" || $5 != "texture" ||
        $6 != "default_reference" || $7 != "legacy_reference" ||
        $8 != "overlap" || $9 != "semantic_share" ||
        $10 != "default_changed" || $11 != "default_on_exact" ||
        $12 != "transition_only" || $13 != "default_off_different" ||
        $14 != "same_reply") fail("bad header")
    next
}

{
    if (NF != 14 || $1 !~ /^(p3[6-9]|p40|h3[5-9]|h40)$/ ||
        $2 !~ /^(primary|holdout)$/ || !integer($3) || $3 < 1 || $3 > 6 ||
        !integer($4) || $4 < 1 || $4 > 8 ||
        $5 !~ /^(home|storm|wonder|social)$/ ||
        $6 !~ /^(exact|censored)$/ || $7 !~ /^(exact|censored)$/ ||
        !number($8) || $8 < 0 || $8 > 1.0001 ||
        !number($9) || $9 < 0 || $9 > 1.0001 ||
        ($10 != 0 && $10 != 1) || $11 != 1 || $12 != 1 ||
        ($13 != 0 && $13 != 1) || $14 != 1)
        fail("invalid row")
    expected_split = substr($1, 1, 1) == "p" ? "primary" : "holdout"
    if ($2 != expected_split) fail("life/split mismatch")
    key = $1 SUBSEP $3 SUBSEP $4
    if (seen[key]++) fail("duplicate turn")
    rows++
    life_rows[$1]++
    split_life[$2 SUBSEP $1] = 1
    if ($6 == "exact") default_exact++
    else default_censored++
    if ($7 == "exact") legacy_exact++
    else legacy_censored++
    if ($9 > 0) positive_share++
    if ($10) changed++
    if ($13) default_off_different++
}

END {
    if (fatal) exit 2
    if (rows != 528 || length(life_rows) != 11)
        fail("wrong admission population")
    for (life in life_rows)
        if (life_rows[life] != 48) fail("incomplete life")
    if (default_exact < 500 || default_exact + default_censored != 528 ||
        legacy_exact < 500 || legacy_exact + legacy_censored != 528 ||
        positive_share < 1 || changed < 1 || default_off_different < 1)
        fail("insufficient authority coverage")
    primary_lives = holdout_lives = 0
    for (key in split_life) {
        split(key, part, SUBSEP)
        if (part[1] == "primary") primary_lives++
        else if (part[1] == "holdout") holdout_lives++
    }
    if (primary_lives != 5 || holdout_lives != 6)
        fail("wrong split coverage")

    print "runtime_turns", rows
    print "default_reference_exact_turns", default_exact
    print "default_reference_censored_turns", default_censored
    print "legacy_reference_exact_turns", legacy_exact
    print "legacy_reference_censored_turns", legacy_censored
    print "positive_semantic_share_turns", positive_share
    print "default_changed_turns", changed
    print "default_off_different_turns", default_off_different
    print "default_explicit_on_mismatches", 0
    print "voice_mismatches", 0
    print "persisted_boundary_violations", 0
    print "result", "relational-transition-default-admitted"
}
