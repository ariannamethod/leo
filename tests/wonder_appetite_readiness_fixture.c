#define LEO_NO_MAIN
#include "../leo.c"

static int add_outcome(
        Leo *leo, int policy, int verdict) {
    LeoWonderAppetiteCalibration *calibration =
        &leo->wonder_appetite_calibration;
    if (calibration->n >= LEO_WONDER_APPETITE_CALIB_RING)
        return 0;
    int slot = calibration->n;
    LeoWonderAppetiteCalibrationReceipt receipt;
    memset(&receipt, 0, sizeof receipt);
    receipt.proposed_turn = (uint64_t)(10 + slot * 4);
    receipt.deadline_turn =
        receipt.proposed_turn +
            LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.observed_turn = receipt.deadline_turn;
    receipt.appetite = 0.65f;
    receipt.policy = (uint8_t)policy;
    receipt.verdict = (uint8_t)verdict;
    receipt.observations = LEO_WONDER_APPETITE_CALIB_HORIZON;
    snprintf(receipt.word, sizeof receipt.word, "ready%02d", slot);

    if (policy == LEO_WONDER_APPETITE_POLICY_ELIGIBLE) {
        receipt.policy_n = LEO_WONDER_APPETITE_DRIFT_MIN_N;
        receipt.policy_reliability =
            LEO_WONDER_APPETITE_RELIABILITY_ALIGNED;
        receipt.policy_drift =
            LEO_WONDER_APPETITE_DRIFT_STABLE;
    }
    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED) {
        receipt.semantic_hits = 1;
        receipt.peak_recurrence =
            LEO_WONDER_APPETITE_RESONANCE_MIN;
        receipt.brier =
            (receipt.appetite - 1.0f) *
            (receipt.appetite - 1.0f);
    } else {
        receipt.brier = receipt.appetite * receipt.appetite;
    }
    if (!leo_wonder_appetite_calibration_valid(
            &receipt, receipt.observed_turn))
        return 0;

    calibration->receipts[calibration->ptr] = receipt;
    calibration->ptr =
        (calibration->ptr + 1) %
            LEO_WONDER_APPETITE_CALIB_RING;
    calibration->n++;
    leo->school.turn_clock = (long)receipt.observed_turn;
    return 1;
}

static int add_n(Leo *leo, int count, int policy, int verdict) {
    for (int i = 0; i < count; i++)
        if (!add_outcome(leo, policy, verdict))
            return 0;
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 3 ||
        (strcmp(argv[2], "candidate") &&
         strcmp(argv[2], "motion-unbounded") &&
         strcmp(argv[2], "restraint-unbounded") &&
         strcmp(argv[2], "both-unbounded"))) {
        fprintf(stderr,
                "usage: %s STATE candidate|motion-unbounded|restraint-unbounded|both-unbounded\n",
                argv[0]);
        return 2;
    }

    int motion_high =
        !strcmp(argv[2], "motion-unbounded") ||
        !strcmp(argv[2], "both-unbounded");
    int restraint_high =
        !strcmp(argv[2], "restraint-unbounded") ||
        !strcmp(argv[2], "both-unbounded");

    Leo leo;
    leo_init(&leo);
    leo_ingest(
        &leo,
        "The rain falls softly. His mother waits by the warm window. "
        "Leo hears the night and asks what the sea remembers. "
        "The child watches light move across the room.");

    int ok =
        add_n(
            &leo, motion_high ? 4 : 7,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            &leo, motion_high ? 4 : 1,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_FADED) &&
        add_n(
            &leo, restraint_high ? 4 : 1,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            &leo, restraint_high ? 4 : 7,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED) &&
        leo_save_state(&leo, argv[1]);
    leo_free(&leo);
    return ok ? 0 : 1;
}
