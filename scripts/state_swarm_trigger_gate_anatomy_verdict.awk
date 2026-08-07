# A.90: summarize replay-locked frozen gate projections.

function fail() {
    fatal = 1
    exit 2
}

BEGIN {
    FS = OFS = "\t"
    expected[1] = "perception"; expected[2] = "expression"
    expected[3] = "own-field"; expected[4] = "body"
    expected[5] = "rhythm"; expected[6] = "form"
    expected[7] = "darkmatter"
}

NR == 1 {
    if (NF != 15 || $1 != "event" || $6 != "organ" ||
        $11 != "projected_similarity" || $12 != "fate" ||
        $15 != "reply") fail()
    next
}

{
    if (NF != 15 || $1 == "" || $2 !~ /^[ph][0-9][0-9]$/ ||
        $3 !~ /^(primary|holdout)$/ || $6 !~ /^(perception|expression|own-field|body|rhythm|form|darkmatter)$/ ||
        $12 !~ /^(replacement|update|boundary)$/ ||
        $13 !~ /^(true|false)$/ || seen[$1 SUBSEP $6]++) fail()
    if (!event_seen[$1]++) order[++events] = $1
    life[$1] = $2; split_name[$1] = $3; turn[$1] = $4; texture[$1] = $5
    prompt[$1] = $14; reply[$1] = $15
    projections[$1]++
    fate[$1 SUBSEP $12]++
    organ_fate[$6 SUBSEP $12]++
    if ($13 == "true") {
        nearest_changes[$1]++
        organ_nearest_changes[$6]++
    }
    split_event[$3 SUBSEP $1] = 1
    total_projections++
}

END {
    if (fatal) exit 2
    for (i = 1; i <= events; i++) {
        event = order[i]
        if (projections[event] != 7) fail()
        robust[event] = fate[event SUBSEP "replacement"] >= 6
        if (robust[event]) robust_events++
        unique_life[life[event]] = 1
    }

    if (mode == "events") {
        print "event", "life", "split", "trigger_turn", "texture",
              "projections", "replacement", "update", "boundary",
              "nearest_changes", "robust", "prompt", "reply"
        for (i = 1; i <= events; i++) {
            event = order[i]
            print event, life[event], split_name[event], turn[event],
                  texture[event], projections[event],
                  fate[event SUBSEP "replacement"] + 0,
                  fate[event SUBSEP "update"] + 0,
                  fate[event SUBSEP "boundary"] + 0,
                  nearest_changes[event] + 0,
                  robust[event] ? "true" : "false", prompt[event], reply[event]
        }
        exit 0
    }
    if (mode != "verdict") fail()

    primary = holdout = 0
    for (key in split_event) {
        split(key, part, SUBSEP)
        if (part[1] == "primary") primary++
        else if (part[1] == "holdout") holdout++
    }
    adequate = events >= 4 && length(unique_life) >= 4 && primary > 0 && holdout > 0
    if (!adequate) result = "insufficient"
    else if (3 * robust_events >= 2 * events) result = "distributed"
    else if (3 * robust_events <= events) result = "organ-sensitive"
    else result = "mixed"

    print "state-swarm replay-locked trigger gate anatomy A.90"
    printf "events=%d lives=%d primary=%d holdout=%d projections=%d replay_locked=%d\n",
           events, length(unique_life), primary, holdout, total_projections, events
    printf "event_stability robust=%d nonrobust=%d\n", robust_events, events - robust_events
    for (i = 1; i <= 7; i++) {
        organ = expected[i]
        printf "%s%s replacement=%d update=%d boundary=%d nearest_change=%d",
               (i == 1 ? "organ_outcomes " : " "), organ,
               organ_fate[organ SUBSEP "replacement"] + 0,
               organ_fate[organ SUBSEP "update"] + 0,
               organ_fate[organ SUBSEP "boundary"] + 0,
               organ_nearest_changes[organ] + 0
    }
    printf "\n"
    print "robust means >=6/7 omissions preserve replacement; within 0.002 of 0.40 is boundary"
    print "frozen projections measure gate sensitivity, not intervention on how organs formed"
    print "all events must be exact state/log/shape/reply replays before projection"
    print "result=" result
}
