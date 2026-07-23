BEGIN { FS = OFS = "\t" }

NR == FNR {
    if (FNR > 1) session[$1 SUBSEP $2 SUBSEP $3] = $4
    next
}

FNR == 1 {
    print "scenario", "seed", "proposal_turn", "proposal_session", "action",
          "confidence", "observed_turn", "observed_session", "verdict"
    next
}

{
    proposal_session = session[$1 SUBSEP $2 SUBSEP $3]
    observed_session = session[$1 SUBSEP $2 SUBSEP $10]
    if (proposal_session != "" && observed_session != "" &&
        proposal_session != observed_session)
        print $1, $2, $3, proposal_session, $6, $8, $10,
              observed_session, $13
}
