# A.91: compare centered organ polarity across two matched-control axes.

function fail() {
    print "invalid A.91 projection/verdict at line " NR > "/dev/stderr"
    fatal = 1
    exit 2
}

BEGIN {
    FS = OFS = "\t"
    if (!sign_required) sign_required = 15
    if (!mean_required) mean_required = 0.01
    organ_order[1] = "perception"; organ_order[2] = "expression"
    organ_order[3] = "own-field"; organ_order[4] = "body"
    organ_order[5] = "rhythm"; organ_order[6] = "form"
    organ_order[7] = "darkmatter"
    family_order[1] = "event"; family_order[2] = "organism"
    family_order[3] = "ecology"
}

NR == 1 {
    if (NF != 20 || $1 != "observation" || $3 != "family" ||
        $9 != "organ" || $13 != "nearest_organ_similarity" ||
        $16 != "delta" || $17 != "fate" || $20 != "reply") fail()
    next
}

{
    if (NF != 20 || $2 !~ /^[0-9][0-9]$/ ||
        $3 !~ /^(event|organism|ecology)$/ ||
        $9 !~ /^(perception|expression|own-field|body|rhythm|form|darkmatter)$/ ||
        $13 !~ /^-?[0-9]+([.][0-9]+)?$/ ||
        $16 !~ /^-?[0-9]+([.][0-9]+)?$/ ||
        $17 !~ /^(replacement|update|boundary)$/ ||
        seen[$1 SUBSEP $9]++) fail()
    observation = $1
    pair = $2
    family = $3
    if (!observation_seen[observation]++) {
        observations++
        observation_pair[observation] = pair
        observation_family[observation] = family
        observation_source[observation] = $4
        if (!pair_seen[pair]++) pair_order[++pairs] = pair
        pair_observation[pair SUBSEP family] = observation
        family_observations[family]++
    } else if (observation_pair[observation] != pair ||
               observation_family[observation] != family ||
               observation_source[observation] != $4) fail()
    observation_organs[observation]++
    organ_delta[observation SUBSEP $9] = $16 + 0
    organ_nearest[observation SUBSEP $9] = $13 + 0
    family_organ_delta[family SUBSEP $9] += $16
    family_organ_nearest[family SUBSEP $9] += $13
    family_organ_fate[family SUBSEP $9 SUBSEP $17]++
}

END {
    if (fatal) exit 2
    if (pairs != expected || observations != expected * 3) fail()
    for (observation in observation_seen) {
        if (observation_organs[observation] != 7) fail()
        novelty = (organ_delta[observation SUBSEP "perception"] + organ_delta[observation SUBSEP "expression"] + organ_delta[observation SUBSEP "own-field"]) / 3.0
        continuity = (organ_delta[observation SUBSEP "rhythm"] + organ_delta[observation SUBSEP "darkmatter"]) / 2.0
        polarity[observation] = novelty - continuity
    }

    for (i = 1; i <= pairs; i++) {
        pair = pair_order[i]
        event = pair_observation[pair SUBSEP "event"]
        organism = pair_observation[pair SUBSEP "organism"]
        ecology = pair_observation[pair SUBSEP "ecology"]
        if (!event || !organism || !ecology) fail()
        organism_diff[pair] = polarity[event] - polarity[organism]
        ecology_diff[pair] = polarity[event] - polarity[ecology]
        organism_sum += organism_diff[pair]
        ecology_sum += ecology_diff[pair]
        if (organism_diff[pair] > 0.0000005) organism_positive++
        else if (organism_diff[pair] < -0.0000005) organism_negative++
        else organism_tie++
        if (ecology_diff[pair] > 0.0000005) ecology_positive++
        else if (ecology_diff[pair] < -0.0000005) ecology_negative++
        else ecology_tie++
    }
    organism_mean = organism_sum / pairs
    ecology_mean = ecology_sum / pairs
    organism_strong = organism_positive >= sign_required && organism_mean >= mean_required
    ecology_strong = ecology_positive >= sign_required && ecology_mean >= mean_required
    organism_reverse = organism_negative >= sign_required && organism_mean <= -mean_required
    ecology_reverse = ecology_negative >= sign_required && ecology_mean <= -mean_required

    if (mode == "pairs") {
        print "pair", "event", "event_polarity", "organism_control",
              "organism_polarity", "organism_difference",
              "ecology_control", "ecology_polarity", "ecology_difference"
        for (i = 1; i <= pairs; i++) {
            pair = pair_order[i]
            event = pair_observation[pair SUBSEP "event"]
            organism = pair_observation[pair SUBSEP "organism"]
            ecology = pair_observation[pair SUBSEP "ecology"]
            print pair, observation_source[event], sprintf("%.6f", polarity[event]),
                  observation_source[organism], sprintf("%.6f", polarity[organism]),
                  sprintf("%.6f", organism_diff[pair]),
                  observation_source[ecology], sprintf("%.6f", polarity[ecology]),
                  sprintf("%.6f", ecology_diff[pair])
        }
        exit 0
    }
    if (mode != "verdict") fail()

    if (organism_strong && ecology_strong)
        result = "crossing-specific-organ-polarity"
    else if (organism_reverse || ecology_reverse)
        result = "unexpected-polarity-reversal"
    else if (organism_strong || ecology_strong)
        result = "control-axis-confounded"
    else
        result = "near-gate-polarity-not-distinguished"

    print "state-swarm dual matched near-gate controls A.91"
    printf "pairs=%d observations=%d projections=%d event=%d organism=%d ecology=%d\n",
           pairs, observations, observations * 7,
           family_observations["event"], family_observations["organism"],
           family_observations["ecology"]
    printf "polarity organism positive=%d negative=%d tie=%d mean_difference=%.6f strong=%s\n",
           organism_positive, organism_negative, organism_tie, organism_mean,
           organism_strong ? "true" : "false"
    printf "polarity ecology positive=%d negative=%d tie=%d mean_difference=%.6f strong=%s\n",
           ecology_positive, ecology_negative, ecology_tie, ecology_mean,
           ecology_strong ? "true" : "false"
    for (f = 1; f <= 3; f++) {
        family = family_order[f]
        printf "family=%s", family
        for (o = 1; o <= 7; o++) {
            organ = organ_order[o]
            printf " %s_nearest=%.6f %s_delta=%.6f %s_fate=%d/%d/%d",
                   organ, family_organ_nearest[family SUBSEP organ] / expected,
                   organ, family_organ_delta[family SUBSEP organ] / expected,
                   organ,
                   family_organ_fate[family SUBSEP organ SUBSEP "replacement"] + 0,
                   family_organ_fate[family SUBSEP organ SUBSEP "update"] + 0,
                   family_organ_fate[family SUBSEP organ SUBSEP "boundary"] + 0
        }
        printf "\n"
    }
    print "polarity=mean(delta perception,expression,own-field)-mean(delta rhythm,darkmatter)"
    printf "strong means >=%d/%d positive paired differences and mean difference >=%.3f\n",
           sign_required, expected, mean_required
    print "organism controls share a life; ecology controls share split, prompt slot, texture, and text"
    print "all 38 controls are disjoint updates in the sealed [0.400,0.450) band"
    print "result=" result
}
