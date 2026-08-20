# A.118: descriptive observations only; no quality score and no admission vote.

function fail(message) {
    if (message != "") print "natural life summary: " message > "/dev/stderr"
    fatal = 1
    exit 2
}
function integer(value) { return value ~ /^[0-9]+$/ }
function number(value) { return value ~ /^[0-9]+([.][0-9]+)?$/ }

BEGIN { FS = OFS = "\t" }

NR == 1 {
    if (NF != 16 || $1 != "life" || $3 != "turn" || $6 != "leo" ||
        $11 != "exact_repeat" || $12 != "echo" ||
        $16 != "api_reply_reference") fail("bad header")
    next
}

{
    if (NF != 16 || $1 == "" || $2 !~ /^(api|replay|async-a|async-b)$/ ||
        !integer($3) || $3 != rows + 1 || !integer($4) ||
        $5 == "" || $6 == "" || !integer($7) || !integer($8) ||
        !integer($9) || ($10 != 0 && $10 != 1) ||
        ($11 != 0 && $11 != 1) || !number($12) || $12 < 0 || $12 > 1.0001 ||
        ($13 != 0 && $13 != 1) ||
        $14 !~ /^(born|updated|replaced|none)$/ || $15 == "" ||
        $16 !~ /^(true|false|null)$/) fail("invalid row")
    if (!rows) { life = $1; arm = $2 }
    else if ($1 != life || $2 != arm) fail("identity drift")
    rows++
    human_words += $7
    leo_words += $8
    leo_chars += $9
    questions += $10
    repeats += $11
    echo += $12
    wonder += $13
    event[$14]++
    stance[$15]++
    if ($16 == "true") references++
}

END {
    if (fatal) exit 2
    if (!rows || (expected_turns && rows != expected_turns)) fail("wrong turn count")
    print "life", life
    print "arm", arm
    print "turns", rows
    printf "mean_human_words\t%.3f\n", human_words / rows
    printf "mean_leo_words\t%.3f\n", leo_words / rows
    printf "mean_leo_chars\t%.3f\n", leo_chars / rows
    print "leo_question_turns", questions
    print "exact_consecutive_replies", repeats
    printf "mean_external_echo\t%.6f\n", echo / rows
    print "wonder_open_turns", wonder
    print "state_births", event["born"] + 0
    print "state_updates", event["updated"] + 0
    print "state_replacements", event["replaced"] + 0
    print "api_reply_references", references + 0
    for (i = 1; i <= 8; i++) {
        name = i == 1 ? "open" : i == 2 ? "follow" : i == 3 ? "clarify" : \
            i == 4 ? "answer" : i == 5 ? "comfort" : i == 6 ? "challenge" : \
            i == 7 ? "shift" : "close"
        print "api_stance_" name, stance[name] + 0
    }
    print "result", "natural-life-observed-not-judged"
}
