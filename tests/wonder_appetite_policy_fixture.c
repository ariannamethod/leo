#define LEO_NO_MAIN
#include "../leo.c"

static void add_scored(
        Leo *leo, float appetite, int verdict) {
    LeoWonderAppetiteCalibration *calibration =
        &leo->wonder_appetite_calibration;
    int slot = calibration->n;
    LeoWonderAppetiteCalibrationReceipt receipt;
    memset(&receipt, 0, sizeof receipt);
    receipt.proposed_turn = (uint64_t)(10 + slot * 4);
    receipt.deadline_turn =
        receipt.proposed_turn + LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.observed_turn = receipt.deadline_turn;
    snprintf(receipt.word, sizeof receipt.word, "history%02d", slot);
    receipt.appetite = appetite;
    receipt.observations = LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.verdict = (uint8_t)verdict;
    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED) {
        receipt.semantic_hits = 1;
        receipt.peak_recurrence =
            LEO_WONDER_APPETITE_RESONANCE_MIN;
        receipt.brier =
            (appetite - 1.0f) * (appetite - 1.0f);
    } else {
        receipt.brier = appetite * appetite;
    }
    calibration->receipts[calibration->ptr] = receipt;
    calibration->ptr =
        (calibration->ptr + 1) %
            LEO_WONDER_APPETITE_CALIB_RING;
    calibration->n++;
}

static int add_policy_forecast(
        Leo *leo, float appetite, int verdict) {
    LeoWonderAppetiteCalibration *calibration =
        &leo->wonder_appetite_calibration;
    LeoWonderAppetiteCalibrationReceipt receipt;
    memset(&receipt, 0, sizeof receipt);
    receipt.proposed_turn = 42;
    receipt.deadline_turn =
        receipt.proposed_turn + LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.observed_turn = receipt.deadline_turn;
    strcpy(receipt.word, "policy");
    receipt.appetite = appetite;
    receipt.observations = LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.verdict = (uint8_t)verdict;
    leo_wonder_appetite_policy_snapshot(
        leo, appetite, 0, &receipt);
    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED) {
        receipt.semantic_hits = 1;
        receipt.peak_recurrence =
            LEO_WONDER_APPETITE_RESONANCE_MIN;
        receipt.brier =
            (appetite - 1.0f) * (appetite - 1.0f);
    } else {
        receipt.brier = appetite * appetite;
    }
    if (!leo_wonder_appetite_calibration_valid(&receipt, 45))
        return 0;
    calibration->receipts[calibration->ptr] = receipt;
    calibration->ptr =
        (calibration->ptr + 1) %
            LEO_WONDER_APPETITE_CALIB_RING;
    calibration->n++;
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 4 ||
        (strcmp(argv[2], "stable") && strcmp(argv[2], "rising")) ||
        (strcmp(argv[3], "sustained") && strcmp(argv[3], "faded"))) {
        fprintf(stderr,
                "usage: %s STATE stable|rising sustained|faded\n",
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
    if (!strcmp(argv[2], "stable")) {
        for (int era = 0; era < 2; era++) {
            for (int i = 0; i < 3; i++)
                add_scored(
                    &leo, 0.65f,
                    LEO_WONDER_APPETITE_CALIB_SUSTAINED);
            add_scored(
                &leo, 0.65f,
                LEO_WONDER_APPETITE_CALIB_FADED);
        }
    } else {
        for (int i = 0; i < 4; i++)
            add_scored(
                &leo, 0.65f,
                LEO_WONDER_APPETITE_CALIB_FADED);
        for (int i = 0; i < 4; i++)
            add_scored(
                &leo, 0.65f,
                LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    }

    int verdict = !strcmp(argv[3], "sustained") ?
        LEO_WONDER_APPETITE_CALIB_SUSTAINED :
        LEO_WONDER_APPETITE_CALIB_FADED;
    leo.school.turn_clock = 45;
    int ok = add_policy_forecast(&leo, 0.65f, verdict) &&
             leo_save_state(&leo, argv[1]);
    leo_free(&leo);
    return ok ? 0 : 1;
}
