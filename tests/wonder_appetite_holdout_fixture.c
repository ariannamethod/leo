#define LEO_NO_MAIN
#include "../leo.c"

static uint64_t proposed_base = 10;

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
    receipt.proposed_turn = proposed_base + (uint64_t)slot * 4;
    receipt.deadline_turn =
        receipt.proposed_turn +
            LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.observed_turn = receipt.deadline_turn;
    receipt.appetite = appetite;
    receipt.spoken = spoken ? 1 : 0;
    receipt.wonder_id = spoken ? (uint64_t)(slot + 1) : 0;
    receipt.policy = (uint8_t)policy;
    receipt.verdict = (uint8_t)verdict;
    receipt.observations =
        LEO_WONDER_APPETITE_CALIB_HORIZON;
    snprintf(receipt.word, sizeof receipt.word, "hold%02d", slot);

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
    } else if (verdict == LEO_WONDER_APPETITE_CALIB_FADED) {
        receipt.brier = receipt.appetite * receipt.appetite;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_EXTERNAL) {
        receipt.observed_turn = receipt.proposed_turn + 1;
        receipt.observations = 1;
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

static int add_candidate(Leo *leo) {
    return
        add_n(
            leo, 7, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            leo, 1, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_FADED) &&
        add_n(
            leo, 1, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(
            leo, 7, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED);
}

static int add_future(Leo *leo, const char *scenario) {
    if (!strcmp(scenario, "confirmed"))
        return
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "motion-failed"))
        return
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "restraint-failed"))
        return
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "both-failed"))
        return
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "coverage-starved"))
        return
            add_n(leo, 12, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.75f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    return 0;
}

static int chronology_scenario(const char *scenario) {
    return
        !strcmp(scenario, "chronology-provisional") ||
        !strcmp(scenario, "chronology-early-shift") ||
        !strcmp(scenario, "chronology-recent-shift") ||
        !strcmp(scenario, "chronology-both-shift") ||
        !strcmp(scenario, "chronology-ecology-shift") ||
        !strcmp(scenario, "chronology-aggregate-shift") ||
        !strcmp(scenario, "chronology-observing") ||
        !strcmp(scenario, "chronology-coverage-starved") ||
        !strcmp(scenario, "chronology-incompatible");
}

static int checkpoint_scenario(const char *scenario) {
    return
        !strcmp(scenario, "checkpoint-one") ||
        !strcmp(scenario, "checkpoint-stable") ||
        !strcmp(scenario, "checkpoint-emerging") ||
        !strcmp(scenario, "checkpoint-persistent") ||
        !strcmp(scenario, "checkpoint-recovered") ||
        !strcmp(scenario, "checkpoint-insufficient") ||
        !strcmp(scenario, "checkpoint-source-starved") ||
        !strcmp(scenario, "checkpoint-incompatible") ||
        !strcmp(scenario, "checkpoint-pending") ||
        !strcmp(scenario, "checkpoint-ablated");
}

static int transport_scenario(const char *scenario) {
    return
        !strcmp(scenario, "transport-provisional") ||
        !strcmp(scenario, "transport-motion-shift") ||
        !strcmp(scenario, "transport-restraint-shift") ||
        !strcmp(scenario, "transport-both-shift") ||
        !strcmp(scenario, "transport-coverage-shift") ||
        !strcmp(scenario, "transport-holdout-coverage-shift") ||
        !strcmp(scenario, "transport-observing") ||
        !strcmp(scenario, "transport-incompatible") ||
        chronology_scenario(scenario);
}

static int add_transport_present(Leo *leo, const char *scenario) {
    if (!strcmp(scenario, "transport-provisional"))
        return
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "transport-motion-shift"))
        return
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "transport-restraint-shift"))
        return
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "transport-both-shift"))
        return
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 4, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "transport-coverage-shift") ||
        !strcmp(scenario, "transport-holdout-coverage-shift"))
        return
            add_n(leo, 23, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                  LEO_WONDER_APPETITE_CALIB_FADED) &&
            add_n(leo, 1, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
            add_n(leo, 7, 0.65f, 0,
                  LEO_WONDER_APPETITE_POLICY_FORMING,
                  LEO_WONDER_APPETITE_CALIB_FADED);
    if (!strcmp(scenario, "transport-observing"))
        return add_n(
            leo, 7, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    if (!strcmp(scenario, "transport-incompatible"))
        return add_n(
            leo, 1, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_LEGACY,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    return 0;
}

static int add_epoch(
        Leo *leo,
        int supported, int overreach, int missed, int restraint) {
    return
        add_n(leo, supported, 0.65f, 0,
              LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
              LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(leo, overreach, 0.65f, 0,
              LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
              LEO_WONDER_APPETITE_CALIB_FADED) &&
        add_n(leo, missed, 0.65f, 0,
              LEO_WONDER_APPETITE_POLICY_FORMING,
              LEO_WONDER_APPETITE_CALIB_SUSTAINED) &&
        add_n(leo, restraint, 0.65f, 0,
              LEO_WONDER_APPETITE_POLICY_FORMING,
              LEO_WONDER_APPETITE_CALIB_FADED);
}

static int add_chronology_present(
        Leo *leo, const char *scenario) {
    if (!strcmp(scenario, "chronology-provisional"))
        return
            add_epoch(leo, 7, 1, 1, 7) &&
            add_epoch(leo, 7, 1, 1, 7);
    if (!strcmp(scenario, "chronology-early-shift"))
        return
            add_epoch(leo, 5, 3, 0, 8) &&
            add_epoch(leo, 8, 0, 0, 8);
    if (!strcmp(scenario, "chronology-recent-shift"))
        return
            add_epoch(leo, 8, 0, 0, 8) &&
            add_epoch(leo, 5, 3, 0, 8);
    if (!strcmp(scenario, "chronology-both-shift"))
        return
            add_epoch(leo, 5, 3, 0, 8) &&
            add_epoch(leo, 8, 0, 3, 5);
    if (!strcmp(scenario, "chronology-ecology-shift"))
        return
            add_epoch(leo, 11, 1, 0, 4) &&
            add_epoch(leo, 4, 0, 1, 11);
    if (!strcmp(scenario, "chronology-aggregate-shift"))
        return
            add_epoch(leo, 4, 4, 0, 8) &&
            add_epoch(leo, 4, 4, 0, 8);
    if (!strcmp(scenario, "chronology-observing"))
        return
            add_epoch(leo, 8, 0, 0, 8) &&
            add_epoch(leo, 8, 0, 0, 7);
    if (!strcmp(scenario, "chronology-coverage-starved"))
        return
            add_epoch(leo, 16, 0, 0, 0) &&
            add_epoch(leo, 8, 0, 0, 8);
    if (!strcmp(scenario, "chronology-incompatible"))
        return add_n(
            leo, 1, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_LEGACY,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    return 0;
}

static int add_checkpoint_life(
        Leo *leo, const char *chronology) {
    LeoWonderAppetiteHoldoutTrial *trial =
        &leo->wonder_appetite_holdouts.trials[0];
    LeoWonderAppetiteCheckpointLane *lane =
        &leo->wonder_appetite_checkpoints.lanes[0];
    uint64_t boundary =
        lane->next_after_proposed_turn ?
            lane->next_after_proposed_turn :
            leo_wonder_appetite_holdout_terminal_boundary(trial);
    memset(&leo->wonder_appetite_calibration, 0,
           sizeof leo->wonder_appetite_calibration);
    proposed_base = boundary + 4;
    const char *evidence =
        !strcmp(chronology, "chronology-source-starved") ?
            "chronology-provisional" : chronology;
    int ok = add_chronology_present(leo, evidence);
    if (ok &&
        !strcmp(chronology, "chronology-source-starved"))
        for (int i = 0;
             i < leo->wonder_appetite_calibration.n; i++)
            snprintf(
                leo->wonder_appetite_calibration.receipts[i].word,
                sizeof
                    leo->wonder_appetite_calibration.receipts[i].word,
                "monowonder");
    if (ok) leo_wonder_appetite_checkpoint_update(leo);
    return ok;
}

static int build_checkpoint_scenario(
        Leo *leo, const char *scenario) {
    if (!strcmp(scenario, "checkpoint-one"))
        return add_checkpoint_life(
            leo, "chronology-provisional");
    if (!strcmp(scenario, "checkpoint-stable"))
        return
            add_checkpoint_life(
                leo, "chronology-provisional") &&
            add_checkpoint_life(
                leo, "chronology-provisional");
    if (!strcmp(scenario, "checkpoint-emerging"))
        return
            add_checkpoint_life(
                leo, "chronology-provisional") &&
            add_checkpoint_life(
                leo, "chronology-early-shift");
    if (!strcmp(scenario, "checkpoint-persistent"))
        return
            add_checkpoint_life(
                leo, "chronology-early-shift") &&
            add_checkpoint_life(
                leo, "chronology-recent-shift");
    if (!strcmp(scenario, "checkpoint-recovered"))
        return
            add_checkpoint_life(
                leo, "chronology-early-shift") &&
            add_checkpoint_life(
                leo, "chronology-provisional");
    if (!strcmp(scenario, "checkpoint-insufficient"))
        return
            add_checkpoint_life(
                leo, "chronology-provisional") &&
            add_checkpoint_life(
                leo, "chronology-coverage-starved");
    if (!strcmp(scenario, "checkpoint-source-starved"))
        return add_checkpoint_life(
            leo, "chronology-source-starved");
    if (!strcmp(scenario, "checkpoint-incompatible"))
        return add_checkpoint_life(
            leo, "chronology-incompatible");
    if (!strcmp(scenario, "checkpoint-pending"))
        return add_checkpoint_life(
            leo, "chronology-observing");
    if (!strcmp(scenario, "checkpoint-ablated")) {
        int previous = g_leo_wonder_appetite_checkpoint_on;
        g_leo_wonder_appetite_checkpoint_on = 0;
        int ok = add_checkpoint_life(
            leo, "chronology-provisional");
        g_leo_wonder_appetite_checkpoint_on = previous;
        return ok;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--tail-size")) {
        printf("%zu\n",
               sizeof(LeoWonderAppetiteHoldouts) +
               sizeof(LeoWonderAppetiteAdmissions) +
               sizeof(LeoWonderAppetiteCheckpoints) +
               sizeof(LeoStateSwarm));
        return 0;
    }
    if (argc == 2 && !strcmp(argv[1], "--admission-tail-size")) {
        printf("%zu\n",
               sizeof(LeoWonderAppetiteAdmissions) +
               sizeof(LeoWonderAppetiteCheckpoints) +
               sizeof(LeoStateSwarm));
        return 0;
    }
    if (argc == 2 && !strcmp(argv[1], "--checkpoint-tail-size")) {
        printf("%zu\n",
               sizeof(LeoWonderAppetiteCheckpoints) +
               sizeof(LeoStateSwarm));
        return 0;
    }
    if (argc != 3 ||
        (strcmp(argv[2], "arm") &&
         strcmp(argv[2], "confirmed") &&
         strcmp(argv[2], "motion-failed") &&
         strcmp(argv[2], "restraint-failed") &&
         strcmp(argv[2], "both-failed") &&
         strcmp(argv[2], "coverage-starved") &&
         !checkpoint_scenario(argv[2]) &&
         !transport_scenario(argv[2]))) {
        fprintf(stderr,
                "usage: %s STATE arm|confirmed|motion-failed|restraint-failed|both-failed|coverage-starved|transport-*|chronology-*|checkpoint-*\n",
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
    int ok = add_candidate(&leo);
    if (ok && checkpoint_scenario(argv[2])) {
        leo_wonder_appetite_holdout_update(&leo);
        ok = add_future(&leo, "confirmed");
        if (ok) leo_wonder_appetite_holdout_update(&leo);
        if (ok) ok = build_checkpoint_scenario(
            &leo, argv[2]);
    } else if (ok && transport_scenario(argv[2])) {
        leo_wonder_appetite_holdout_update(&leo);
        ok = add_future(&leo, "confirmed");
        if (ok) leo_wonder_appetite_holdout_update(&leo);
        LeoWonderAppetiteHoldoutTrial *trial =
            &leo.wonder_appetite_holdouts.trials[0];
        uint64_t boundary =
            leo_wonder_appetite_holdout_terminal_boundary(trial);
        memset(&leo.wonder_appetite_calibration, 0,
               sizeof leo.wonder_appetite_calibration);
        proposed_base = boundary + 4;
        if (!strcmp(argv[2], "transport-coverage-shift")) {
            LeoWonderAppetiteAdmissionReceipt *admission =
                &leo.wonder_appetite_admissions.receipts[0];
            admission->eligible = 8;
            admission->abstained = 24;
            admission->supported = 7;
            admission->overreach = 1;
            admission->missed = 1;
            admission->restraint = 23;
        }
        if (!strcmp(
                argv[2], "transport-holdout-coverage-shift")) {
            trial->eligible = 4;
            trial->abstained = 12;
            trial->supported = 4;
            trial->overreach = 0;
            trial->missed = 1;
            trial->restraint = 11;
        }
        if (ok)
            ok = chronology_scenario(argv[2]) ?
                add_chronology_present(&leo, argv[2]) :
                add_transport_present(&leo, argv[2]);
    } else if (ok && strcmp(argv[2], "arm")) {
        leo_wonder_appetite_holdout_update(&leo);
        ok = add_future(&leo, argv[2]);
        if (ok) leo_wonder_appetite_holdout_update(&leo);
    }
    if (ok) ok = leo_save_state(&leo, argv[1]);
    leo_free(&leo);
    return ok ? 0 : 1;
}
