#define LEO_NO_MAIN
#include "../leo.c"

static int add_outcome(
        Leo *leo, float appetite, int spoken,
        int policy, int verdict) {
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
    receipt.appetite = appetite;
    receipt.spoken = spoken ? 1 : 0;
    receipt.wonder_id = spoken ? (uint64_t)(slot + 1) : 0;
    receipt.policy = (uint8_t)policy;
    receipt.verdict = (uint8_t)verdict;
    receipt.observations = LEO_WONDER_APPETITE_CALIB_HORIZON;
    snprintf(receipt.word, sizeof receipt.word, "regret%02d", slot);

    if (policy == LEO_WONDER_APPETITE_POLICY_ELIGIBLE) {
        receipt.policy_n = LEO_WONDER_APPETITE_DRIFT_MIN_N;
        receipt.policy_reliability =
            LEO_WONDER_APPETITE_RELIABILITY_ALIGNED;
        receipt.policy_drift =
            LEO_WONDER_APPETITE_DRIFT_STABLE;
    } else if (
        policy == LEO_WONDER_APPETITE_POLICY_DRIFTING) {
        receipt.policy_n = LEO_WONDER_APPETITE_DRIFT_MIN_N;
        receipt.policy_reliability =
            LEO_WONDER_APPETITE_RELIABILITY_ALIGNED;
        receipt.policy_drift =
            LEO_WONDER_APPETITE_DRIFT_RISING;
    }

    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED) {
        receipt.semantic_hits = 1;
        receipt.peak_recurrence =
            LEO_WONDER_APPETITE_RESONANCE_MIN;
        receipt.brier =
            (appetite - 1.0f) * (appetite - 1.0f);
    } else {
        receipt.brier = appetite * appetite;
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

static int add_n(
        Leo *leo, int count, float appetite, int spoken,
        int policy, int verdict) {
    for (int i = 0; i < count; i++)
        if (!add_outcome(
                leo, appetite, spoken, policy, verdict))
            return 0;
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 3 ||
        (strcmp(argv[2], "motion-heavy") &&
         strcmp(argv[2], "restraint-heavy"))) {
        fprintf(stderr,
                "usage: %s STATE motion-heavy|restraint-heavy\n",
                argv[0]);
        return 2;
    }

    Leo leo;
    leo_init(&leo);
    leo_ingest(
        &leo,
        "The rain falls softly. His mother waits by the warm window. "
        "Leo hears the night and asks what the sea remembers. "
        "The child watches light move across the room.");

    int motion_heavy = !strcmp(argv[2], "motion-heavy");
    int ok =
        add_n(
            &leo, motion_heavy ? 1 : 3, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            &leo, motion_heavy ? 3 : 1, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_FADED) &&
        add_n(
            &leo, motion_heavy ? 1 : 3, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            &leo, motion_heavy ? 3 : 1, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED) &&
        add_n(
            &leo, 4, 0.85f, 1,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            &leo, 2, 0.85f, 0,
            LEO_WONDER_APPETITE_POLICY_DRIFTING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            &leo, 2, 0.85f, 0,
            LEO_WONDER_APPETITE_POLICY_DRIFTING,
            LEO_WONDER_APPETITE_CALIB_FADED) &&
        leo_save_state(&leo, argv[1]);
    leo_free(&leo);
    return ok ? 0 : 1;
}
