# Extract the complete visible reply from one single-turn `leo --chat` log.

/^you> leo> / {
    found = 1
    in_reply = 1
    reply = substr($0, length("you> leo> ") + 1)
    next
}

/^     \[/ { in_reply = 0 }
/^you> / { in_reply = 0 }

in_reply {
    reply = reply "\n" $0
    next
}

END {
    if (!found || reply == "") exit 1
    print reply
}
