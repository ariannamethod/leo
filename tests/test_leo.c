/* test_leo.c — step 0 unit tests (tokenizer + field + ingest).
 * Compiles leo.c with its main() excluded.
 *   cc -DLEO_NO_MAIN tests/test_leo.c -O2 -lm -Wall -Wextra -o tests/test_leo
 */
#ifndef LEO_NO_MAIN
#define LEO_NO_MAIN
#endif
#include "../leo.c"
#include <assert.h>

static int g_pass = 0, g_total = 0;
#if defined(__GNUC__) || defined(__clang__)
#define TEST_NOINLINE __attribute__((noinline))
#else
#define TEST_NOINLINE
#endif
#define CHECK(cond, name) do {                                  \
        g_total++;                                              \
        if (cond) { g_pass++; printf("  ok   %s\n", name); }    \
        else      { printf("  FAIL %s\n", name); }              \
    } while (0)

static Leo *g_test_leo_storage[256];
static size_t g_test_leo_storage_n;

static Leo *test_leo_alloc(void) {
    if (g_test_leo_storage_n >=
        sizeof g_test_leo_storage / sizeof g_test_leo_storage[0]) {
        fputs("test_leo: fixture storage registry exhausted\n", stderr);
        exit(2);
    }
    Leo *leo = malloc(sizeof *leo);
    if (!leo) {
        fputs("test_leo: cannot allocate a fixture body\n", stderr);
        exit(2);
    }
    g_test_leo_storage[g_test_leo_storage_n++] = leo;
    return leo;
}

static void test_leo_delete(Leo *leo) {
    if (!leo) return;
    leo_free(leo);
}

static void test_leo_release_storage(void) {
    for (size_t i = 0; i < g_test_leo_storage_n; i++)
        free(g_test_leo_storage[i]);
    g_test_leo_storage_n = 0;
}

/* walk callback: count successors */
static int succ_cb(int dst, float count, void *ud) {
    (void)dst; (void)count; (*(int *)ud)++; return 0;
}

static void seed_wonder_address_body(Leo *leo) {
    leo_init(leo);
    leo->school.turn_clock = 1;
    leo_deferred_wonder_remember(
        leo, "nareth", semtok_find_glyph("dark"),
        semtok_find_glyph("animal"), 1, NULL, NULL);
    leo->school.turn_clock = 2;
    leo_deferred_wonder_remember(
        leo, "flom", semtok_find_glyph("fire"),
        semtok_find_glyph("anger"), 1, NULL, NULL);
    leo->school.turn_clock = 3;
    strncpy(leo->school.pending, "suvin",
            sizeof leo->school.pending - 1);
    leo->school.pending_glyph = semtok_find_glyph("light");
    leo->school.pending_alt_glyph = semtok_find_glyph("cold");
    leo_wonder_open(leo, leo->school.pending,
                    leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

static void seed_wonder_redirection_body(Leo *leo) {
    seed_wonder_address_body(leo);
    int32_t field_token[LEO_PREWONDER_FIELD];
    float field_weight[LEO_PREWONDER_FIELD] = {0};
    for (int k = 0; k < LEO_PREWONDER_FIELD; k++) field_token[k] = -1;
    field_token[0] = 's';
    field_token[1] = 'u';
    field_weight[0] = 0.8f;
    field_weight[1] = 0.6f;
    leo_pending_wonder_origin_begin(
        leo, leo->school.pending, leo->school.pending_glyph,
        leo->school.pending_alt_glyph, 1, field_token, field_weight);
}

static void seed_wonder_negation_body(Leo *leo) {
    leo_init(leo);
    leo_ingest(
        leo,
        "the rain falls. his mother is warm. the cat drinks water.");
    leo->school.turn_clock = 1;
    strncpy(leo->school.pending, "zorble",
            sizeof leo->school.pending - 1);
    leo->school.pending_glyph = semtok_word("water");
    leo->school.pending_alt_glyph = semtok_word("animal");
    leo->school.pending_turns = 0;
    leo_pending_wonder_origin_begin(
        leo, leo->school.pending,
        leo->school.pending_glyph,
        leo->school.pending_alt_glyph,
        1, NULL, NULL);
    leo_wonder_open(
        leo, leo->school.pending,
        leo->school.pending_glyph,
        leo->school.pending_alt_glyph);
}

static long test_appetite_and_later_tail_size(const Leo *leo) {
    return (long)(2 * sizeof(int32_t) +
        leo->wonder_appetite_calibration.n *
            (int)sizeof(LeoWonderAppetiteCalibrationReceipt) +
        sizeof(LeoWonderAppetiteHoldouts) +
        sizeof(LeoWonderAppetiteAdmissions) +
        sizeof(LeoWonderAppetiteCheckpoints) +
        sizeof(LeoStateSwarm) +
        2 * sizeof(int32_t) +
        leo->school.n_learned * (int)sizeof(int8_t) +
        leo->school.n_wonders * (int)sizeof(int8_t));
}

static void test_state_swarm_turn(Leo *leo, uint64_t turn,
                                  int in_a, int in_b,
                                  int out_a, int out_b,
                                  float mix, float gap, uint8_t wonder,
                                  const char *reply) {
    if (!leo) return;
    LeoFlowSnapshot snapshot;
    memset(&snapshot, 0, sizeof snapshot);
    for (int k = 0; k < LEO_FLOW_CONSTELLATION; k++)
        snapshot.field_token[k] = -1;
    mix = clampf(mix, 0.0f, 1.0f);
    if (in_a >= 0 && in_a < GLYPH_COUNT) snapshot.perceived[in_a] = mix;
    if (in_b >= 0 && in_b < GLYPH_COUNT) snapshot.perceived[in_b] = 1.0f - mix;
    if (out_a >= 0 && out_a < GLYPH_COUNT) snapshot.expressed[out_a] = mix;
    if (out_b >= 0 && out_b < GLYPH_COUNT) snapshot.expressed[out_b] = 1.0f - mix;
    snapshot.gap_perceived = gap;
    snapshot.gap_expressed = gap;
    snapshot.field_token[0] = mix >= 0.5f ? 'w' : 'z';
    snapshot.field_weight[0] = fmaxf(mix, 1.0f - mix);
    snapshot.field_token[1] = mix >= 0.5f ? 'z' : 'w';
    snapshot.field_weight[1] = fminf(mix, 1.0f - mix);
    snapshot.turn = turn;
    snapshot.mode = LEO_MODE_WALK;
    snapshot.chamber = mix >= 0.5f ? LEO_CH_LOVE : LEO_CH_FEAR;
    snapshot.wonder = wonder;

    memset(leo->chamber_act, 0, sizeof leo->chamber_act);
    leo->chamber_act[LEO_CH_LOVE] = mix;
    leo->chamber_act[LEO_CH_FEAR] = 1.0f - mix;
    for (int d = 0; d < LEO_RET_DIM; d++)
        leo->retention_state[d] = 0.5f * (2.0f * mix - 1.0f);
    leo->mode = LEO_MODE_WALK;
    leo->school.turn_clock = (long)turn;
    leo->flow.snapshots[leo->flow.ptr] = snapshot;
    leo->flow.ptr = (leo->flow.ptr + 1) % LEO_FLOW_RING;
    if (leo->flow.n < LEO_FLOW_RING) leo->flow.n++;
    leo_state_swarm_observe(leo, reply);
}

static void test_add_appetite_calibration(
        Leo *leo, float appetite, int spoken, int verdict) {
    if (!leo ||
        leo->wonder_appetite_calibration.n >=
            LEO_WONDER_APPETITE_CALIB_RING)
        return;
    LeoWonderAppetiteCalibration *calibration =
        &leo->wonder_appetite_calibration;
    int slot = calibration->n;
    LeoWonderAppetiteCalibrationReceipt receipt;
    memset(&receipt, 0, sizeof receipt);
    receipt.proposed_turn = (uint64_t)(10 + slot * 4);
    receipt.deadline_turn =
        receipt.proposed_turn +
            LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.observed_turn = receipt.proposed_turn;
    receipt.appetite = appetite;
    receipt.spoken = spoken ? 1 : 0;
    receipt.wonder_id = spoken ? (uint64_t)(slot + 1) : 0;
    receipt.verdict = (uint8_t)verdict;
    snprintf(receipt.word, sizeof receipt.word, "r%02d", slot);

    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED) {
        receipt.observed_turn = receipt.deadline_turn;
        receipt.observations =
            LEO_WONDER_APPETITE_CALIB_HORIZON;
        receipt.semantic_hits = 1;
        receipt.peak_recurrence =
            LEO_WONDER_APPETITE_RESONANCE_MIN;
        float error = appetite - 1.0f;
        receipt.brier = error * error;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_GROUNDED) {
        receipt.observed_turn++;
        receipt.observations = 1;
        float error = appetite - 1.0f;
        receipt.brier = error * error;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_FADED) {
        receipt.observed_turn = receipt.deadline_turn;
        receipt.observations =
            LEO_WONDER_APPETITE_CALIB_HORIZON;
        receipt.brier = appetite * appetite;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_EXTERNAL) {
        receipt.observed_turn++;
        receipt.observations = 1;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_LOST) {
        receipt.observed_turn = receipt.deadline_turn;
        receipt.observations =
            LEO_WONDER_APPETITE_CALIB_HORIZON;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_UNSCORABLE) {
        receipt.observed_turn += 2;
    }

    calibration->receipts[slot] = receipt;
    calibration->n++;
    calibration->ptr =
        calibration->n % LEO_WONDER_APPETITE_CALIB_RING;
    if ((uint64_t)leo->school.turn_clock < receipt.observed_turn)
        leo->school.turn_clock = (long)receipt.observed_turn;
}

static void test_add_appetite_policy_outcome(
        Leo *leo, float appetite, int spoken,
        int policy, int verdict) {
    if (!leo ||
        leo->wonder_appetite_calibration.n >=
            LEO_WONDER_APPETITE_CALIB_RING)
        return;
    LeoWonderAppetiteCalibration *calibration =
        &leo->wonder_appetite_calibration;
    int slot = calibration->n;
    LeoWonderAppetiteCalibrationReceipt receipt;
    memset(&receipt, 0, sizeof receipt);
    receipt.proposed_turn = (uint64_t)(10 + slot * 4);
    receipt.deadline_turn =
        receipt.proposed_turn +
            LEO_WONDER_APPETITE_CALIB_HORIZON;
    receipt.observed_turn = receipt.proposed_turn;
    receipt.appetite = appetite;
    receipt.spoken = spoken ? 1 : 0;
    receipt.wonder_id = spoken ? (uint64_t)(slot + 1) : 0;
    receipt.policy = (uint8_t)policy;
    receipt.verdict = (uint8_t)verdict;
    snprintf(receipt.word, sizeof receipt.word, "p%02d", slot);

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
    } else if (
        policy == LEO_WONDER_APPETITE_POLICY_UNCALIBRATED) {
        receipt.policy_n = LEO_WONDER_APPETITE_DRIFT_MIN_N;
        receipt.policy_reliability =
            LEO_WONDER_APPETITE_RELIABILITY_OVER;
        receipt.policy_drift =
            LEO_WONDER_APPETITE_DRIFT_STABLE;
    }

    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED) {
        receipt.observed_turn = receipt.deadline_turn;
        receipt.observations =
            LEO_WONDER_APPETITE_CALIB_HORIZON;
        receipt.semantic_hits = 1;
        receipt.peak_recurrence =
            LEO_WONDER_APPETITE_RESONANCE_MIN;
        float error = appetite - 1.0f;
        receipt.brier = error * error;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_FADED) {
        receipt.observed_turn = receipt.deadline_turn;
        receipt.observations =
            LEO_WONDER_APPETITE_CALIB_HORIZON;
        receipt.brier = appetite * appetite;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_EXTERNAL) {
        receipt.observed_turn++;
        receipt.observations = 1;
    }

    calibration->receipts[slot] = receipt;
    calibration->n++;
    calibration->ptr =
        calibration->n % LEO_WONDER_APPETITE_CALIB_RING;
    if ((uint64_t)leo->school.turn_clock < receipt.observed_turn)
        leo->school.turn_clock = (long)receipt.observed_turn;
}

static void test_add_appetite_policy_outcome_after(
        Leo *leo, uint64_t proposed_turn,
        float appetite, int spoken,
        int policy, int verdict) {
    if (!leo) return;
    int slot = leo->wonder_appetite_calibration.n;
    test_add_appetite_policy_outcome(
        leo, appetite, spoken, policy, verdict);
    if (leo->wonder_appetite_calibration.n != slot + 1)
        return;
    LeoWonderAppetiteCalibrationReceipt *receipt =
        &leo->wonder_appetite_calibration.receipts[slot];
    receipt->proposed_turn = proposed_turn;
    receipt->deadline_turn =
        proposed_turn + LEO_WONDER_APPETITE_CALIB_HORIZON;
    if (verdict == LEO_WONDER_APPETITE_CALIB_SUSTAINED ||
        verdict == LEO_WONDER_APPETITE_CALIB_FADED ||
        verdict == LEO_WONDER_APPETITE_CALIB_LOST) {
        receipt->observed_turn = receipt->deadline_turn;
    } else if (
        verdict == LEO_WONDER_APPETITE_CALIB_GROUNDED ||
        verdict == LEO_WONDER_APPETITE_CALIB_EXTERNAL) {
        receipt->observed_turn = proposed_turn + 1;
    } else {
        receipt->observed_turn = proposed_turn;
    }
    if ((uint64_t)leo->school.turn_clock < receipt->observed_turn)
        leo->school.turn_clock = (long)receipt->observed_turn;
}

static void test_reset_appetite_policy_outcomes(Leo *leo) {
    if (!leo) return;
    memset(&leo->wonder_appetite_calibration, 0,
           sizeof leo->wonder_appetite_calibration);
}

static void test_add_appetite_readiness_cell(
        Leo *leo, float appetite, int spoken,
        int supported, int overreach,
        int missed, int restraint) {
    for (int i = 0; i < supported; i++)
        test_add_appetite_policy_outcome(
            leo, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < overreach; i++)
        test_add_appetite_policy_outcome(
            leo, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_FADED);
    for (int i = 0; i < missed; i++)
        test_add_appetite_policy_outcome(
            leo, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < restraint; i++)
        test_add_appetite_policy_outcome(
            leo, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED);
}

__attribute__((noinline))
static void test_wonder_appetite_drift_surface(void) {
    Leo *drift = malloc(sizeof *drift);
    static LeoWonderAppetiteDrift surface;
    static LeoWonderAppetiteReliability pooled;
    const LeoWonderAppetiteDriftCell *cell;
    CHECK(drift != NULL,
          "wonder-appetite-drift: heap fixture allocated");
    if (!drift) return;

    leo_init(drift);
    leo_wonder_appetite_drift(drift, &surface);
    CHECK(surface.measured == 0 &&
          surface.forming == 0 &&
          surface.cells[0].status ==
              LEO_WONDER_APPETITE_DRIFT_EMPTY,
          "wonder-appetite-drift: an empty diary invents no history");

    for (int i = 0; i < 7; i++)
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    leo_wonder_appetite_drift(drift, &surface);
    CHECK(surface.measured == 0 &&
          surface.forming == 1 &&
          surface.cells[0].n == 7 &&
          surface.cells[0].status ==
              LEO_WONDER_APPETITE_DRIFT_FORMING,
          "wonder-appetite-drift: seven outcomes cannot impersonate two eras");

    leo_free(drift);
    leo_init(drift);
    for (int i = 0; i < 5; i++)
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
    for (int i = 0; i < 4; i++)
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    leo_wonder_appetite_drift(drift, &surface);
    cell = &surface.cells[0];
    CHECK(surface.measured == 1 &&
          surface.rising == 1 &&
          cell->n == 9 &&
          cell->early_positives == 0 &&
          cell->recent_positives == 4 &&
          cell->status ==
              LEO_WONDER_APPETITE_DRIFT_RISING &&
          cell->recent_lower > cell->early_upper,
          "wonder-appetite-drift: fixed endpoints expose a rising return life");
    CHECK(fabsf(cell->return_shift - 1.0f) < 1e-6f &&
          fabsf(cell->appetite_shift) < 1e-6f &&
          fabsf(cell->gap_shift - 1.0f) < 1e-6f &&
          fabsf(cell->brier_shift + 0.30f) < 1e-6f,
          "wonder-appetite-drift: return, appetite, calibration, and Brier remain separate axes");

    leo_wonder_appetite_reliability(drift, &pooled);
    CHECK(pooled.cells[0].status ==
              LEO_WONDER_APPETITE_RELIABILITY_ALIGNED &&
          cell->status ==
              LEO_WONDER_APPETITE_DRIFT_RISING,
          "wonder-appetite-drift: chronology survives an aligned pooled cell");

    LeoWonderAppetiteCalibration *diary_before =
        malloc(sizeof *diary_before);
    LeoSchool *school_before = malloc(sizeof *school_before);
    LeoFlow *flow_before = malloc(sizeof *flow_before);
    if (diary_before)
        *diary_before = drift->wonder_appetite_calibration;
    if (school_before) *school_before = drift->school;
    if (flow_before) *flow_before = drift->flow;
    leo_wonder_appetite_drift(drift, &surface);
    CHECK(diary_before && school_before && flow_before &&
          !memcmp(diary_before,
                  &drift->wonder_appetite_calibration,
                  sizeof *diary_before) &&
          !memcmp(school_before, &drift->school,
                  sizeof *school_before) &&
          !memcmp(flow_before, &drift->flow,
                  sizeof *flow_before),
          "wonder-appetite-drift: reading change cannot rewrite Leo");
    free(diary_before);
    free(school_before);
    free(flow_before);

    leo_free(drift);
    leo_init(drift);
    for (int i = 0; i < 4; i++)
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < 4; i++)
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
    leo_wonder_appetite_drift(drift, &surface);
    cell = &surface.cells[0];
    CHECK(surface.falling == 1 &&
          cell->status ==
              LEO_WONDER_APPETITE_DRIFT_FALLING &&
          cell->recent_upper < cell->early_lower,
          "wonder-appetite-drift: the same evidence reversed is a falling life");

    leo_free(drift);
    leo_init(drift);
    for (int era = 0; era < 2; era++) {
        for (int i = 0; i < 3; i++)
            test_add_appetite_calibration(
                drift, era ? 0.69f : 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_SUSTAINED);
        test_add_appetite_calibration(
            drift, era ? 0.69f : 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
    }
    leo_wonder_appetite_drift(drift, &surface);
    cell = &surface.cells[0];
    CHECK(surface.stable == 1 &&
          cell->status ==
              LEO_WONDER_APPETITE_DRIFT_STABLE &&
          fabsf(cell->return_shift) < 1e-6f &&
          fabsf(cell->appetite_shift - 0.04f) < 1e-6f &&
          fabsf(cell->gap_shift + 0.04f) < 1e-6f,
          "wonder-appetite-drift: confidence may move while observed return stays stable");

    leo_free(drift);
    leo_init(drift);
    for (int i = 0; i < 4; i++) {
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
        test_add_appetite_calibration(
            drift, 0.65f, 1,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    }
    leo_wonder_appetite_drift(drift, &surface);
    CHECK(surface.measured == 0 &&
          surface.forming == 2 &&
          surface.cells[0].n == 4 &&
          surface.cells[
              LEO_WONDER_APPETITE_RELIABILITY_BINS].n == 4,
          "wonder-appetite-drift: spoken and unspoken chronology cannot lend each other evidence");

    leo_free(drift);
    leo_init(drift);
    for (int i = 0; i < 8; i++)
        test_add_appetite_calibration(
            drift, 0.65f, 0,
            i & 1 ?
                LEO_WONDER_APPETITE_CALIB_EXTERNAL :
                LEO_WONDER_APPETITE_CALIB_UNSCORABLE);
    leo_wonder_appetite_drift(drift, &surface);
    CHECK(surface.measured == 0 &&
          surface.forming == 0 &&
          surface.cells[0].n == 0,
          "wonder-appetite-drift: causal confounds cannot become an era");

    leo_free(drift);
    free(drift);
}

__attribute__((noinline))
static void test_wonder_appetite_shadow_policy(void) {
    Leo *leo = malloc(sizeof *leo);
    LeoWonderAppetiteCalibrationReceipt forecast;
    CHECK(leo != NULL,
          "wonder-appetite-policy: heap fixture allocated");
    if (!leo) return;

    leo_init(leo);
    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 0, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_FORMING &&
          forecast.policy_n == 0 &&
          forecast.policy_reliability ==
              LEO_WONDER_APPETITE_RELIABILITY_EMPTY &&
          forecast.policy_drift ==
              LEO_WONDER_APPETITE_DRIFT_EMPTY,
          "wonder-appetite-policy: an empty past abstains without inventing evidence");

    for (int era = 0; era < 2; era++) {
        for (int i = 0; i < 3; i++)
            test_add_appetite_calibration(
                leo, 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_SUSTAINED);
        test_add_appetite_calibration(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
    }
    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 0, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_ELIGIBLE &&
          forecast.policy_n == 8 &&
          forecast.policy_reliability ==
              LEO_WONDER_APPETITE_RELIABILITY_ALIGNED &&
          forecast.policy_drift ==
              LEO_WONDER_APPETITE_DRIFT_STABLE,
          "wonder-appetite-policy: only stable calibrated history becomes eligible");

    memset(&leo->wonder_appetite, 0, sizeof leo->wonder_appetite);
    leo->wonder_appetite.status = LEO_WONDER_APPETITE_SALIENT;
    leo->wonder_appetite.winner = 0;
    leo->wonder_appetite.n_candidates = 1;
    strcpy(leo->wonder_appetite.candidates[0].word, "future");
    leo->wonder_appetite.candidates[0].appetite = 0.65f;
    leo->school.turn_clock = 100;
    leo_wonder_appetite_calibrate(leo, "Quiet room.");
    const LeoWonderAppetiteCalibrationReceipt *born =
        leo_wonder_appetite_calibration_at(
            &leo->wonder_appetite_calibration, 8);
    CHECK(born &&
          born->verdict == LEO_WONDER_APPETITE_CALIB_PENDING &&
          born->policy == LEO_WONDER_APPETITE_POLICY_ELIGIBLE &&
          born->policy_n == 8,
          "wonder-appetite-policy: the real forecast birth freezes its prior evidence");
    CHECK(born &&
          leo_wonder_appetite_calibration_valid(born, 100),
          "wonder-appetite-policy: a coherent birth snapshot is valid state");
    LeoWonderAppetiteCalibrationReceipt corrupted =
        born ? *born : forecast;
    corrupted.policy_n = 7;
    CHECK(!born ||
          !leo_wonder_appetite_calibration_valid(&corrupted, 100),
          "wonder-appetite-policy: state validation rejects a policy that contradicts its evidence");
    CHECK(born &&
          leo_wonder_appetite_policy_result(born) ==
              LEO_WONDER_APPETITE_POLICY_RESULT_PENDING,
          "wonder-appetite-policy: a decision cannot grade its own unfinished future");
    corrupted = born ? *born : forecast;
    corrupted.verdict = LEO_WONDER_APPETITE_CALIB_EXTERNAL;
    corrupted.observed_turn++;
    corrupted.observations = 1;
    CHECK(born &&
          leo_wonder_appetite_policy_result(&corrupted) ==
              LEO_WONDER_APPETITE_POLICY_RESULT_CONFOUNDED,
          "wonder-appetite-policy: human intervention cannot reward or punish restraint");

    forecast.verdict = LEO_WONDER_APPETITE_CALIB_SUSTAINED;
    CHECK(leo_wonder_appetite_policy_result(&forecast) ==
              LEO_WONDER_APPETITE_POLICY_RESULT_SUPPORTED,
          "wonder-appetite-policy: eligible return becomes support");
    forecast.verdict = LEO_WONDER_APPETITE_CALIB_FADED;
    CHECK(leo_wonder_appetite_policy_result(&forecast) ==
              LEO_WONDER_APPETITE_POLICY_RESULT_OVERREACH,
          "wonder-appetite-policy: eligible silence exposes overreach");

    leo_free(leo);
    leo_init(leo);
    for (int i = 0; i < 4; i++)
        test_add_appetite_calibration(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
    for (int i = 0; i < 4; i++)
        test_add_appetite_calibration(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 0, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_DRIFTING &&
          forecast.policy_reliability ==
              LEO_WONDER_APPETITE_RELIABILITY_ALIGNED &&
          forecast.policy_drift ==
              LEO_WONDER_APPETITE_DRIFT_RISING,
          "wonder-appetite-policy: aligned totals cannot hide a moving life");
    forecast.verdict = LEO_WONDER_APPETITE_CALIB_SUSTAINED;
    CHECK(leo_wonder_appetite_policy_result(&forecast) ==
              LEO_WONDER_APPETITE_POLICY_RESULT_MISSED,
          "wonder-appetite-policy: living return after abstention remains a visible miss");
    forecast.verdict = LEO_WONDER_APPETITE_CALIB_FADED;
    CHECK(leo_wonder_appetite_policy_result(&forecast) ==
              LEO_WONDER_APPETITE_POLICY_RESULT_RESTRAINT,
          "wonder-appetite-policy: fading after abstention records restraint");

    leo_free(leo);
    leo_init(leo);
    for (int i = 0; i < 8; i++)
        test_add_appetite_calibration(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_FADED);
    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 0, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_UNCALIBRATED &&
          forecast.policy_reliability ==
              LEO_WONDER_APPETITE_RELIABILITY_OVER &&
          forecast.policy_drift ==
              LEO_WONDER_APPETITE_DRIFT_STABLE,
          "wonder-appetite-policy: stable overconfidence is still abstention");

    leo_free(leo);
    leo_init(leo);
    for (int i = 0; i < 8; i++)
        test_add_appetite_calibration(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 0, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_UNCALIBRATED &&
          forecast.policy_reliability ==
              LEO_WONDER_APPETITE_RELIABILITY_UNDER,
          "wonder-appetite-policy: stable underconfidence is measured, not silently promoted");

    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 1, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_FORMING &&
          forecast.policy_n == 0,
          "wonder-appetite-policy: unspoken evidence cannot authorize a spoken Wonder");

    int previous_policy = g_leo_wonder_appetite_policy_on;
    g_leo_wonder_appetite_policy_on = 0;
    memset(&forecast, 0, sizeof forecast);
    leo_wonder_appetite_policy_snapshot(leo, 0.65f, 0, &forecast);
    CHECK(forecast.policy ==
              LEO_WONDER_APPETITE_POLICY_NONE &&
          forecast.policy_n == 0,
          "wonder-appetite-policy: ablation leaves no hidden decision");
    g_leo_wonder_appetite_policy_on = previous_policy;

    leo_free(leo);
    free(leo);
}

__attribute__((noinline))
static void test_wonder_appetite_regret_surface(void) {
    Leo *leo = malloc(sizeof *leo);
    LeoWonderAppetiteRegret surface;
    CHECK(leo != NULL,
          "wonder-appetite-regret: heap fixture allocated");
    if (!leo) return;

    leo_init(leo);
    leo_wonder_appetite_regret(leo, &surface);
    CHECK(surface.scored == 0 &&
          surface.cells[0].status ==
              LEO_WONDER_APPETITE_REGRET_EMPTY,
          "wonder-appetite-regret: an empty diary invents no cost");

    for (int i = 0; i < 3; i++)
        test_add_appetite_policy_outcome(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    test_add_appetite_policy_outcome(
        leo, 0.65f, 0,
        LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
        LEO_WONDER_APPETITE_CALIB_FADED);
    test_add_appetite_policy_outcome(
        leo, 0.65f, 0,
        LEO_WONDER_APPETITE_POLICY_FORMING,
        LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < 3; i++)
        test_add_appetite_policy_outcome(
            leo, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED);
    leo_wonder_appetite_regret(leo, &surface);
    const LeoWonderAppetiteRegretCell *paired =
        &surface.cells[0];
    CHECK(paired->scored == 8 &&
          paired->eligible == 4 &&
          paired->abstained == 4 &&
          paired->supported == 3 &&
          paired->overreach == 1 &&
          paired->missed == 1 &&
          paired->restraint == 3 &&
          paired->status ==
              LEO_WONDER_APPETITE_REGRET_PAIRED,
          "wonder-appetite-regret: paired evidence preserves all four outcomes");
    CHECK(fabsf(paired->coverage - 0.5f) < 1e-6f &&
          fabsf(paired->overreach_rate - 0.25f) < 1e-6f &&
          fabsf(paired->missed_rate - 0.25f) < 1e-6f &&
          paired->overreach_lower < paired->overreach_rate &&
          paired->overreach_upper > paired->overreach_rate &&
          paired->missed_lower < paired->missed_rate &&
          paired->missed_upper > paired->missed_rate,
          "wonder-appetite-regret: coverage and both Wilson-bearing costs remain separate");

    for (int i = 0; i < 4; i++)
        test_add_appetite_policy_outcome(
            leo, 0.85f, 1,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < 2; i++)
        test_add_appetite_policy_outcome(
            leo, 0.85f, 0,
            LEO_WONDER_APPETITE_POLICY_DRIFTING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < 2; i++)
        test_add_appetite_policy_outcome(
            leo, 0.85f, 0,
            LEO_WONDER_APPETITE_POLICY_DRIFTING,
            LEO_WONDER_APPETITE_CALIB_FADED);
    leo_wonder_appetite_regret(leo, &surface);
    const LeoWonderAppetiteRegretCell *abstention =
        &surface.cells[2];
    const LeoWonderAppetiteRegretCell *eligible =
        &surface.cells[
            LEO_WONDER_APPETITE_RELIABILITY_BINS + 2];
    CHECK(abstention->status ==
              LEO_WONDER_APPETITE_REGRET_ABSTENTION_OBSERVED &&
          abstention->eligible == 0 &&
          abstention->abstained == 4 &&
          abstention->missed == 2 &&
          abstention->restraint == 2 &&
          eligible->status ==
              LEO_WONDER_APPETITE_REGRET_ELIGIBLE_OBSERVED &&
          eligible->eligible == 4 &&
          eligible->abstained == 0,
          "wonder-appetite-regret: spoken and unspoken arms cannot lend each other maturity");
    CHECK(surface.scored == 16 &&
          surface.eligible == 8 &&
          surface.abstained == 8 &&
          surface.supported == 7 &&
          surface.overreach == 1 &&
          surface.missed == 3 &&
          surface.restraint == 5 &&
          fabsf(surface.coverage - 0.5f) < 1e-6f &&
          fabsf(surface.overreach_rate - 0.125f) < 1e-6f &&
          fabsf(surface.missed_rate - 0.375f) < 1e-6f &&
          surface.paired_cells == 1 &&
          surface.eligible_observed_cells == 1 &&
          surface.abstention_observed_cells == 1,
          "wonder-appetite-regret: aggregate coverage cannot erase the stratified tradeoff");

    test_add_appetite_policy_outcome(
        leo, 0.75f, 0,
        LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
        LEO_WONDER_APPETITE_CALIB_PENDING);
    test_add_appetite_policy_outcome(
        leo, 0.75f, 0,
        LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
        LEO_WONDER_APPETITE_CALIB_EXTERNAL);
    test_add_appetite_policy_outcome(
        leo, 0.75f, 0,
        LEO_WONDER_APPETITE_POLICY_LEGACY,
        LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    test_add_appetite_policy_outcome(
        leo, 0.75f, 0,
        LEO_WONDER_APPETITE_POLICY_NONE,
        LEO_WONDER_APPETITE_CALIB_FADED);
    leo_wonder_appetite_regret(leo, &surface);
    CHECK(surface.scored == 16 &&
          surface.pending == 1 &&
          surface.confounded == 1 &&
          surface.legacy == 1 &&
          surface.none == 1 &&
          surface.cells[1].status ==
              LEO_WONDER_APPETITE_REGRET_EMPTY,
          "wonder-appetite-regret: pending, confounded, legacy, and ablated lives cannot price policy");

    LeoWonderAppetiteCalibration diary_before =
        leo->wonder_appetite_calibration;
    LeoSchool *school_before = malloc(sizeof *school_before);
    LeoFlow *flow_before = malloc(sizeof *flow_before);
    if (school_before) *school_before = leo->school;
    if (flow_before) *flow_before = leo->flow;
    leo_wonder_appetite_regret(leo, &surface);
    CHECK(school_before && flow_before &&
          !memcmp(&diary_before,
                  &leo->wonder_appetite_calibration,
                  sizeof diary_before) &&
          !memcmp(school_before, &leo->school,
                  sizeof *school_before) &&
          !memcmp(flow_before, &leo->flow,
                  sizeof *flow_before) &&
          LEO_STATE_VERSION == 28,
          "wonder-appetite-regret: observing cost rewrites no evidence, body, or state format");
    free(school_before);
    free(flow_before);

    leo_free(leo);
    free(leo);
}

__attribute__((noinline))
static void test_wonder_appetite_readiness_frontier(void) {
    Leo *leo = malloc(sizeof *leo);
    LeoWonderAppetiteReadiness frontier;
    CHECK(leo != NULL,
          "wonder-appetite-readiness: heap fixture allocated");
    if (!leo) return;

    leo_init(leo);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.candidate == 0 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_EMPTY,
          "wonder-appetite-readiness: an empty diary grants no candidacy");

    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 3, 0, 0, 3);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.forming == 1 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_FORMING,
          "wonder-appetite-readiness: two thin arms remain forming");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 7, 1, 0, 0);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.unpaired == 1 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_UNPAIRED,
          "wonder-appetite-readiness: one measured arm cannot authorize its absent twin");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 3, 1, 1, 3);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.observing == 1 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_OBSERVING &&
          frontier.cells[0].motion_headroom == 0.0f &&
          frontier.cells[0].restraint_headroom == 0.0f,
          "wonder-appetite-readiness: A.49 pairing is observation, not readiness");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 7, 1, 1, 7);
    leo_wonder_appetite_readiness(leo, &frontier);
    const LeoWonderAppetiteReadinessCell *candidate =
        &frontier.cells[0];
    CHECK(frontier.candidate == 1 &&
          candidate->status ==
              LEO_WONDER_APPETITE_READINESS_CANDIDATE &&
          candidate->eligible == 8 &&
          candidate->abstained == 8 &&
          fabsf(candidate->coverage - 0.5f) < 1e-6f &&
          candidate->overreach_upper <
              LEO_WONDER_APPETITE_READINESS_RISK_CEILING &&
          candidate->missed_upper <
              LEO_WONDER_APPETITE_READINESS_RISK_CEILING &&
          candidate->motion_headroom > 0.0f &&
          candidate->restraint_headroom > 0.0f,
          "wonder-appetite-readiness: both independently bounded arms become only a candidate");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 4, 4, 1, 7);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.motion_unbounded == 1 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_MOTION_UNBOUNDED,
          "wonder-appetite-readiness: overreach uncertainty keeps its own veto");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 7, 1, 4, 4);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.restraint_unbounded == 1 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_RESTRAINT_UNBOUNDED,
          "wonder-appetite-readiness: missed-continuation uncertainty keeps its own veto");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.65f, 0, 4, 4, 4, 4);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.both_unbounded == 1 &&
          frontier.cells[0].status ==
              LEO_WONDER_APPETITE_READINESS_BOTH_UNBOUNDED,
          "wonder-appetite-readiness: two uncertain debts cannot cancel");

    test_reset_appetite_policy_outcomes(leo);
    test_add_appetite_readiness_cell(
        leo, 0.85f, 1, 7, 1, 0, 0);
    test_add_appetite_readiness_cell(
        leo, 0.85f, 0, 0, 0, 1, 7);
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(frontier.candidate == 0 &&
          frontier.unpaired == 2 &&
          frontier.cells[2].status ==
              LEO_WONDER_APPETITE_READINESS_UNPAIRED &&
          frontier.cells[
              LEO_WONDER_APPETITE_RELIABILITY_BINS + 2].status ==
              LEO_WONDER_APPETITE_READINESS_UNPAIRED,
          "wonder-appetite-readiness: spoken and unspoken arms cannot form a synthetic pair");

    LeoWonderAppetiteCalibration diary_before =
        leo->wonder_appetite_calibration;
    LeoSchool *school_before = malloc(sizeof *school_before);
    LeoFlow *flow_before = malloc(sizeof *flow_before);
    if (school_before) *school_before = leo->school;
    if (flow_before) *flow_before = leo->flow;
    leo_wonder_appetite_readiness(leo, &frontier);
    CHECK(school_before && flow_before &&
          !memcmp(&diary_before,
                  &leo->wonder_appetite_calibration,
                  sizeof diary_before) &&
          !memcmp(school_before, &leo->school,
                  sizeof *school_before) &&
          !memcmp(flow_before, &leo->flow,
                  sizeof *flow_before) &&
          LEO_STATE_VERSION == 28,
          "wonder-appetite-readiness: candidacy rewrites no evidence, body, or state format");
    free(school_before);
    free(flow_before);

    leo_free(leo);
    free(leo);
}

static LeoWonderAppetiteHoldoutTrial *
test_open_appetite_holdout(Leo *leo, float appetite, int spoken) {
    if (!leo) return NULL;
    test_reset_appetite_policy_outcomes(leo);
    memset(&leo->wonder_appetite_holdouts, 0,
           sizeof leo->wonder_appetite_holdouts);
    test_add_appetite_readiness_cell(
        leo, appetite, spoken, 7, 1, 1, 7);
    leo_wonder_appetite_holdout_update(leo);
    int bin = leo_wonder_appetite_reliability_bin(appetite);
    int index = (spoken ? LEO_WONDER_APPETITE_RELIABILITY_BINS : 0) +
                bin;
    return &leo->wonder_appetite_holdouts.trials[index];
}

static LeoWonderAppetiteHoldoutTrial *
test_finish_appetite_holdout(
        Leo *leo, float appetite, int spoken,
        int supported, int overreach, int missed, int restraint,
        int confounded, int other) {
    LeoWonderAppetiteHoldoutTrial *trial =
        test_open_appetite_holdout(leo, appetite, spoken);
    test_add_appetite_readiness_cell(
        leo, appetite, spoken,
        supported, overreach, missed, restraint);
    for (int i = 0; i < confounded; i++)
        test_add_appetite_policy_outcome(
            leo, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_EXTERNAL);
    for (int i = 0; i < other; i++)
        test_add_appetite_policy_outcome(
            leo, appetite < 0.70f ? 0.75f : 0.65f, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    leo_wonder_appetite_holdout_update(leo);
    return trial;
}

__attribute__((noinline))
static void test_wonder_appetite_holdout_trial(void) {
    Leo *leo = malloc(sizeof *leo);
    CHECK(leo != NULL,
          "wonder-appetite-holdout: heap fixture allocated");
    if (!leo) return;

    int previous_holdout = g_leo_wonder_appetite_holdout_on;
    int previous_calibration =
        g_leo_wonder_appetite_calibration_on;
    int previous_policy = g_leo_wonder_appetite_policy_on;
    int previous_admission =
        g_leo_wonder_appetite_admission_on;
    g_leo_wonder_appetite_holdout_on = 1;
    g_leo_wonder_appetite_calibration_on = 1;
    g_leo_wonder_appetite_policy_on = 1;
    g_leo_wonder_appetite_admission_on = 1;

    LeoWonderAppetiteCalibrationReceipt upper_source = {0};
    LeoWonderAppetiteCalibrationReceipt lower_source = {0};
    snprintf(upper_source.word, sizeof upper_source.word, "Suvin");
    snprintf(lower_source.word, sizeof lower_source.word, "suvin");
    CHECK(leo_wonder_appetite_source_id(&upper_source) ==
              leo_wonder_appetite_source_id(&lower_source),
          "wonder-appetite-checkpoint: spelling case cannot counterfeit a second source");

    leo_init(leo);
    LeoWonderAppetiteHoldoutTrial *trial =
        test_open_appetite_holdout(leo, 0.65f, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_PENDING &&
          trial->opened_turn ==
              (uint64_t)leo->school.turn_clock &&
          trial->baseline_proposed_turn == 70 &&
          trial->attempts == 0,
          "wonder-appetite-holdout: a candidate freezes one readerless future boundary");
    LeoWonderAppetiteAdmissionReceipt *admission =
        &leo->wonder_appetite_admissions.receipts[0];
    CHECK(admission->status ==
              LEO_WONDER_APPETITE_ADMISSION_ATTESTED &&
          admission->opened_turn == trial->opened_turn &&
          admission->baseline_proposed_turn ==
              trial->baseline_proposed_turn &&
          admission->eligible == 8 &&
          admission->abstained == 8 &&
          admission->supported == 7 &&
          admission->overreach == 1 &&
          admission->missed == 1 &&
          admission->restraint == 7 &&
          leo_wonder_appetite_admission_valid(
              admission, trial),
          "wonder-appetite-admission: trial birth freezes the exact candidate geometry");
    LeoWonderAppetiteAdmissionReceipt admission_before =
        *admission;
    LeoWonderAppetiteCalibration diary_before =
        leo->wonder_appetite_calibration;
    LeoSchool *school_before = malloc(sizeof *school_before);
    LeoFlow *flow_before = malloc(sizeof *flow_before);
    if (school_before) *school_before = leo->school;
    if (flow_before) *flow_before = leo->flow;
    leo_wonder_appetite_holdout_update(leo);
    CHECK(trial && school_before && flow_before &&
          trial->attempts == 0 &&
          !memcmp(&admission_before, admission,
                  sizeof admission_before) &&
          !memcmp(&diary_before,
                  &leo->wonder_appetite_calibration,
                  sizeof diary_before) &&
          !memcmp(school_before, &leo->school,
                  sizeof *school_before) &&
          !memcmp(flow_before, &leo->flow,
                  sizeof *flow_before),
          "wonder-appetite-holdout: the qualifying past cannot grade its own trial or rewrite Leo");
    free(school_before);
    free(flow_before);

    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 7, 1, 1, 7, 0, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_CONFIRMED &&
          trial->attempts == 16 &&
          trial->matched == 16 &&
          trial->eligible == 8 &&
          trial->abstained == 8 &&
          trial->supported == 7 &&
          trial->overreach == 1 &&
          trial->missed == 1 &&
          trial->restraint == 7,
          "wonder-appetite-holdout: sixteen new balanced lives can confirm both bounds");
    LeoWonderAppetiteHoldoutTrial terminal = *trial;
    leo_wonder_appetite_holdout_update(leo);
    CHECK(!memcmp(&terminal, trial, sizeof terminal),
          "wonder-appetite-holdout: a terminal trial cannot restart on its favorable history");

    const char *state = "/tmp/leo_appetite_holdout_v25.state";
    const char *v22 = "/tmp/leo_appetite_holdout_v22.state";
    const char *v23 = "/tmp/leo_appetite_holdout_v23.state";
    const char *cut = "/tmp/leo_appetite_holdout_v23_cut.state";
    const char *bad = "/tmp/leo_appetite_holdout_v23_bad.state";
    const char *admission_cut =
        "/tmp/leo_appetite_admission_v24_cut.state";
    const char *admission_bad =
        "/tmp/leo_appetite_admission_v24_bad.state";
    int saved = leo_save_state(leo, state);
    Leo *woke = malloc(sizeof *woke);
    Leo *old = malloc(sizeof *old);
    Leo *damaged = malloc(sizeof *damaged);
    if (woke) leo_init(woke);
    if (old) leo_init(old);
    if (damaged) leo_init(damaged);
    CHECK(saved && woke && leo_load_state(woke, state) &&
          !memcmp(&woke->wonder_appetite_holdouts,
                  &leo->wonder_appetite_holdouts,
                  sizeof leo->wonder_appetite_holdouts) &&
          !memcmp(&woke->wonder_appetite_admissions,
                  &leo->wonder_appetite_admissions,
                  sizeof leo->wonder_appetite_admissions),
          "wonder-appetite-admission: trial and its admission proof survive current sleep exactly");

    int built_v22 = 0, built_v23 = 0;
    int built_cut = 0, built_bad = 0;
    int built_admission_cut = 0, built_admission_bad = 0;
    FILE *fi = fopen(state, "rb");
    if (fi) {
        fseek(fi, 0, SEEK_END);
        long size = ftell(fi);
        fseek(fi, 0, SEEK_SET);
        unsigned char *bytes =
            malloc(size > 0 ? (size_t)size : 1);
        if (bytes &&
            size > (long)(sizeof(LeoWonderAppetiteHoldouts) +
                          sizeof(LeoWonderAppetiteAdmissions) +
                          sizeof(LeoWonderAppetiteCheckpoints) +
                          sizeof(LeoStateSwarm) +
                          2 * sizeof(int32_t) +
                          leo->school.n_learned * sizeof(int8_t) +
                          leo->school.n_wonders * sizeof(int8_t)) &&
            (long)fread(bytes, 1, (size_t)size, fi) == size) {
            long checkpoint_tail =
                (long)(sizeof(LeoWonderAppetiteCheckpoints) +
                       sizeof(LeoStateSwarm) +
                       2 * sizeof(int32_t) +
                       leo->school.n_learned * sizeof(int8_t) +
                       leo->school.n_wonders * sizeof(int8_t));
            long admission_tail =
                (long)sizeof(LeoWonderAppetiteAdmissions);
            long holdout_tail =
                (long)sizeof(LeoWonderAppetiteHoldouts);
            long holdout_start =
                size - checkpoint_tail -
                    admission_tail - holdout_tail;
            uint32_t twenty_two = 22;
            memcpy(bytes + sizeof(uint32_t), &twenty_two,
                   sizeof twenty_two);
            FILE *fo = fopen(v22, "wb");
            long v22_size = holdout_start;
            if (fo) {
                built_v22 =
                    (long)fwrite(bytes, 1,
                                 (size_t)v22_size, fo) == v22_size;
                fclose(fo);
            }
            uint32_t twenty_three = 23;
            memcpy(bytes + sizeof(uint32_t), &twenty_three,
                   sizeof twenty_three);
            fo = fopen(v23, "wb");
            if (fo) {
                built_v23 =
                    (long)fwrite(
                        bytes, 1,
                        (size_t)(size - checkpoint_tail -
                                 admission_tail), fo) ==
                    size - checkpoint_tail - admission_tail;
                fclose(fo);
            }
            fo = fopen(cut, "wb");
            if (fo) {
                built_cut =
                    (long)fwrite(bytes, 1,
                                 (size_t)(size - checkpoint_tail -
                                          admission_tail - 1),
                                 fo) ==
                    size - checkpoint_tail - admission_tail - 1;
                fclose(fo);
            }
            uint32_t twenty_four = 24;
            memcpy(bytes + sizeof(uint32_t), &twenty_four,
                   sizeof twenty_four);
            fo = fopen(admission_cut, "wb");
            if (fo) {
                built_admission_cut =
                    (long)fwrite(bytes, 1,
                                 (size_t)(size - checkpoint_tail - 1),
                                 fo) ==
                    size - checkpoint_tail - 1;
                fclose(fo);
            }
            LeoWonderAppetiteAdmissions corrupted_admission;
            memcpy(
                &corrupted_admission,
                bytes + size - checkpoint_tail - admission_tail,
                sizeof corrupted_admission);
            corrupted_admission.receipts[0].supported = 4;
            corrupted_admission.receipts[0].overreach = 4;
            memcpy(
                bytes + size - checkpoint_tail - admission_tail,
                &corrupted_admission,
                sizeof corrupted_admission);
            fo = fopen(admission_bad, "wb");
            if (fo) {
                built_admission_bad =
                    (long)fwrite(bytes, 1,
                                 (size_t)(size - checkpoint_tail),
                                 fo) ==
                    size - checkpoint_tail;
                fclose(fo);
            }
            memcpy(
                bytes + size - checkpoint_tail - admission_tail,
                &leo->wonder_appetite_admissions,
                sizeof leo->wonder_appetite_admissions);
            memcpy(bytes + sizeof(uint32_t), &twenty_three,
                   sizeof twenty_three);
            LeoWonderAppetiteHoldouts corrupted;
            memcpy(
                &corrupted,
                bytes + holdout_start,
                sizeof corrupted);
            corrupted.trials[0].attempts = 15;
            memcpy(
                bytes + holdout_start,
                &corrupted, sizeof corrupted);
            fo = fopen(bad, "wb");
            if (fo) {
                built_bad =
                    (long)fwrite(bytes, 1,
                                 (size_t)(size - checkpoint_tail -
                                          admission_tail),
                                 fo) ==
                    size - checkpoint_tail - admission_tail;
                fclose(fo);
            }
        }
        free(bytes);
        fclose(fi);
    }
    CHECK(built_v22 && old && leo_load_state(old, v22) &&
          old->wonder_appetite_calibration.n ==
              leo->wonder_appetite_calibration.n &&
          old->wonder_appetite_holdouts.trials[0].status ==
              LEO_WONDER_APPETITE_HOLDOUT_EMPTY,
          "wonder-appetite-holdout: a v22 body migrates without invented future evidence");
    CHECK(built_v23 && old && leo_load_state(old, v23) &&
          !memcmp(&old->wonder_appetite_holdouts,
                  &leo->wonder_appetite_holdouts,
                  sizeof leo->wonder_appetite_holdouts) &&
          old->wonder_appetite_admissions.receipts[0].status ==
              LEO_WONDER_APPETITE_ADMISSION_EMPTY,
          "wonder-appetite-admission: a v23 trial lives without invented admission proof");
    CHECK(built_cut && damaged &&
          leo_load_state(damaged, cut) &&
          damaged->wonder_appetite_calibration.n ==
              leo->wonder_appetite_calibration.n &&
          damaged->wonder_appetite_holdouts.trials[0].status ==
              LEO_WONDER_APPETITE_HOLDOUT_EMPTY,
          "wonder-appetite-holdout: a corrupt v23 tail loses only its trial");
    CHECK(built_bad && damaged &&
          leo_load_state(damaged, bad) &&
          damaged->wonder_appetite_calibration.n ==
              leo->wonder_appetite_calibration.n &&
          damaged->wonder_appetite_holdouts.trials[0].status ==
              LEO_WONDER_APPETITE_HOLDOUT_EMPTY,
          "wonder-appetite-holdout: an impossible v23 verdict fails soft without rewriting history");
    CHECK(built_admission_cut && damaged &&
          leo_load_state(damaged, admission_cut) &&
          !memcmp(&damaged->wonder_appetite_holdouts,
                  &leo->wonder_appetite_holdouts,
                  sizeof leo->wonder_appetite_holdouts) &&
          damaged->wonder_appetite_admissions.receipts[0].status ==
              LEO_WONDER_APPETITE_ADMISSION_EMPTY,
          "wonder-appetite-admission: a truncated v24 proof loses no trial");
    CHECK(built_admission_bad && damaged &&
          leo_load_state(damaged, admission_bad) &&
          !memcmp(&damaged->wonder_appetite_holdouts,
                  &leo->wonder_appetite_holdouts,
                  sizeof leo->wonder_appetite_holdouts) &&
          damaged->wonder_appetite_admissions.receipts[0].status ==
              LEO_WONDER_APPETITE_ADMISSION_EMPTY,
          "wonder-appetite-admission: an unbounded admission claim fails soft");
    if (woke) { leo_free(woke); free(woke); }
    if (old) { leo_free(old); free(old); }
    if (damaged) { leo_free(damaged); free(damaged); }
    remove(state);
    remove(v22);
    remove(v23);
    remove(cut);
    remove(bad);
    remove(admission_cut);
    remove(admission_bad);

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 4, 4, 1, 7, 0, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_MOTION_FAILED,
          "wonder-appetite-holdout: future overreach can fail motion alone");

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 7, 1, 4, 4, 0, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_RESTRAINT_FAILED,
          "wonder-appetite-holdout: future misses can fail restraint alone");

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 4, 4, 4, 4, 0, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_BOTH_FAILED,
          "wonder-appetite-holdout: two future debts cannot cancel");

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 12, 0, 0, 0, 0, 4);
    CHECK(trial &&
          trial->attempts == 16 &&
          trial->eligible == 12 &&
          trial->abstained == 0 &&
          trial->other == 4 &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_COVERAGE_STARVED,
          "wonder-appetite-holdout: a fixed future cannot wait forever for its missing arm");

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 4, 0, 0, 4, 8, 0);
    CHECK(trial &&
          trial->attempts == 16 &&
          trial->matched == 8 &&
          trial->confounded == 8 &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_CONFIRMED,
          "wonder-appetite-holdout: confounds spend budget without impersonating either arm");

    leo_free(leo);
    leo_init(leo);
    trial = test_open_appetite_holdout(leo, 0.65f, 0);
    test_add_appetite_policy_outcome(
        leo, 0.65f, 0,
        LEO_WONDER_APPETITE_POLICY_LEGACY,
        LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    leo_wonder_appetite_holdout_update(leo);
    CHECK(trial &&
          trial->attempts == 1 &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_INVALIDATED,
          "wonder-appetite-holdout: a changed policy invalidates rather than rewrites the experiment");

    leo_free(leo);
    leo_init(leo);
    g_leo_wonder_appetite_admission_on = 0;
    trial = test_open_appetite_holdout(leo, 0.65f, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_PENDING &&
          leo->wonder_appetite_admissions.receipts[0].status ==
              LEO_WONDER_APPETITE_ADMISSION_EMPTY,
          "wonder-appetite-admission: ablation leaves the trial visibly unattested");
    g_leo_wonder_appetite_admission_on = 1;

    leo_free(leo);
    leo_init(leo);
    g_leo_wonder_appetite_holdout_on = 0;
    trial = test_open_appetite_holdout(leo, 0.65f, 0);
    CHECK(trial &&
          trial->status ==
              LEO_WONDER_APPETITE_HOLDOUT_EMPTY,
          "wonder-appetite-holdout: ablation prevents even the experimental ledger");

    g_leo_wonder_appetite_holdout_on = previous_holdout;
    g_leo_wonder_appetite_calibration_on =
        previous_calibration;
    g_leo_wonder_appetite_policy_on = previous_policy;
    g_leo_wonder_appetite_admission_on =
        previous_admission;
    leo_free(leo);
    free(leo);
}

static void test_add_appetite_transport_outcomes(
        Leo *leo, uint64_t boundary, float appetite, int spoken,
        int supported, int overreach, int missed, int restraint) {
    uint64_t proposed = boundary + 4;
    for (int i = 0; i < supported; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < overreach; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_FADED);
    for (int i = 0; i < missed; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < restraint; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED);
}

static uint64_t test_add_appetite_transport_epoch(
        Leo *leo, uint64_t proposed, float appetite, int spoken,
        int supported, int overreach, int missed, int restraint) {
    for (int i = 0; i < supported; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < overreach; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
            LEO_WONDER_APPETITE_CALIB_FADED);
    for (int i = 0; i < missed; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    for (int i = 0; i < restraint; i++, proposed += 4)
        test_add_appetite_policy_outcome_after(
            leo, proposed, appetite, spoken,
            LEO_WONDER_APPETITE_POLICY_FORMING,
            LEO_WONDER_APPETITE_CALIB_FADED);
    return proposed;
}

static LeoWonderAppetiteHoldoutTrial *
test_prepare_appetite_transport(Leo *leo) {
    LeoWonderAppetiteHoldoutTrial *trial =
        test_finish_appetite_holdout(
            leo, 0.65f, 0, 7, 1, 1, 7, 0, 0);
    test_reset_appetite_policy_outcomes(leo);
    return trial;
}

__attribute__((noinline))
static void test_wonder_appetite_transport_witness(void) {
    Leo *leo = malloc(sizeof *leo);
    Leo *before = malloc(sizeof *before);
    CHECK(leo && before,
          "wonder-appetite-transport: heap fixtures allocated");
    if (!leo || !before) {
        free(leo);
        free(before);
        return;
    }

    int previous_transport =
        g_leo_wonder_appetite_transport_on;
    int previous_holdout =
        g_leo_wonder_appetite_holdout_on;
    int previous_calibration =
        g_leo_wonder_appetite_calibration_on;
    int previous_policy =
        g_leo_wonder_appetite_policy_on;
    int previous_admission =
        g_leo_wonder_appetite_admission_on;
    g_leo_wonder_appetite_transport_on = 1;
    g_leo_wonder_appetite_holdout_on = 1;
    g_leo_wonder_appetite_calibration_on = 1;
    g_leo_wonder_appetite_policy_on = 1;
    g_leo_wonder_appetite_admission_on = 1;

    LeoWonderAppetiteTransport witness;
    leo_init(leo);
    leo_wonder_appetite_transport(leo, &witness);
    CHECK(witness.unattested == 0 &&
          witness.pending == 0 &&
          witness.refuted == 0 &&
          witness.observing == 0 &&
          witness.shifted == 0 &&
          witness.provisional == 0,
          "wonder-appetite-transport: an empty organism invents no applicability");

    LeoWonderAppetiteHoldoutTrial *trial =
        test_open_appetite_holdout(leo, 0.65f, 0);
    leo_wonder_appetite_transport(leo, &witness);
    CHECK(trial &&
          witness.pending == 1 &&
          witness.cells[0].status ==
              LEO_WONDER_APPETITE_TRANSPORT_PENDING,
          "wonder-appetite-transport: an unfinished future cannot describe the present");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    memset(&leo->wonder_appetite_admissions, 0,
           sizeof leo->wonder_appetite_admissions);
    leo_wonder_appetite_transport(leo, &witness);
    CHECK(trial &&
          witness.unattested == 1 &&
          witness.cells[0].status ==
              LEO_WONDER_APPETITE_TRANSPORT_UNATTESTED,
          "wonder-appetite-transport: a legacy trial cannot invent its vanished warrant");

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 4, 4, 1, 7, 0, 0);
    leo_wonder_appetite_transport(leo, &witness);
    CHECK(trial &&
          witness.refuted == 1 &&
          witness.cells[0].status ==
              LEO_WONDER_APPETITE_TRANSPORT_REFUTED,
          "wonder-appetite-transport: a failed holdout cannot be transported");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    uint64_t boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    test_add_appetite_transport_outcomes(
        leo, boundary, 0.65f, 0, 7, 1, 1, 7);
    *before = *leo;
    leo_wonder_appetite_transport(leo, &witness);
    const LeoWonderAppetiteTransportCell *cell =
        &witness.cells[0];
    CHECK(witness.provisional == 1 &&
          cell->after_proposed_turn == boundary &&
          cell->post_settled == 16 &&
          cell->exact == 16 &&
          cell->eligible == 8 &&
          cell->abstained == 8 &&
          cell->supported == 7 &&
          cell->overreach == 1 &&
          cell->missed == 1 &&
          cell->restraint == 7 &&
          fabsf(cell->overreach_upper - 0.4709f) < 1e-3f &&
          fabsf(cell->missed_upper - 0.4709f) < 1e-3f &&
          cell->motion_bounded &&
          cell->restraint_bounded &&
          cell->coverage_compatible &&
          cell->status ==
              LEO_WONDER_APPETITE_TRANSPORT_PROVISIONAL,
          "wonder-appetite-transport: a confirmed result remains applicable only on a new bounded life");
    CHECK(!memcmp(before, leo, sizeof *leo) &&
          LEO_STATE_VERSION == 28,
          "wonder-appetite-transport: reading applicability rewrites no body, evidence, or state format");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    test_add_appetite_transport_outcomes(
        leo, boundary, 0.65f, 0, 4, 4, 1, 7);
    leo_wonder_appetite_transport(leo, &witness);
    cell = &witness.cells[0];
    CHECK(witness.shifted == 1 &&
          !cell->motion_bounded &&
          cell->restraint_bounded &&
          cell->coverage_compatible,
          "wonder-appetite-transport: renewed overreach vetoes motion without pricing restraint");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    test_add_appetite_transport_outcomes(
        leo, boundary, 0.65f, 0, 7, 1, 4, 4);
    leo_wonder_appetite_transport(leo, &witness);
    cell = &witness.cells[0];
    CHECK(witness.shifted == 1 &&
          cell->motion_bounded &&
          !cell->restraint_bounded &&
          cell->coverage_compatible,
          "wonder-appetite-transport: renewed misses veto restraint without pricing motion");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    LeoWonderAppetiteAdmissionReceipt *admission =
        &leo->wonder_appetite_admissions.receipts[0];
    admission->eligible = 8;
    admission->abstained = 24;
    admission->supported = 7;
    admission->overreach = 1;
    admission->missed = 1;
    admission->restraint = 23;
    test_add_appetite_transport_outcomes(
        leo, boundary, 0.65f, 0, 23, 1, 1, 7);
    leo_wonder_appetite_transport(leo, &witness);
    cell = &witness.cells[0];
    CHECK(leo_wonder_appetite_admission_valid(
              admission, trial) &&
          witness.shifted == 1 &&
          cell->motion_bounded &&
          cell->restraint_bounded &&
          !cell->coverage_compatible &&
          cell->admission_coverage_upper <
              cell->current_coverage_lower,
          "wonder-appetite-transport: bounded errors cannot hide a displaced admission ecology");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    trial->eligible = 4;
    trial->abstained = 12;
    trial->supported = 4;
    trial->overreach = 0;
    trial->missed = 1;
    trial->restraint = 11;
    test_add_appetite_transport_outcomes(
        leo, boundary, 0.65f, 0, 23, 1, 1, 7);
    leo_wonder_appetite_transport(leo, &witness);
    cell = &witness.cells[0];
    CHECK(leo_wonder_appetite_holdout_valid(
              trial, (uint64_t)leo->school.turn_clock) &&
          witness.shifted == 1 &&
          cell->motion_bounded &&
          cell->restraint_bounded &&
          !cell->coverage_compatible &&
          cell->holdout_coverage_upper <
              cell->current_coverage_lower,
          "wonder-appetite-transport: bounded errors cannot hide a displaced holdout ecology");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    test_add_appetite_transport_outcomes(
        leo, boundary, 0.65f, 0, 7, 0, 0, 0);
    leo_wonder_appetite_transport(leo, &witness);
    CHECK(witness.observing == 1 &&
          witness.cells[0].status ==
              LEO_WONDER_APPETITE_TRANSPORT_OBSERVING,
          "wonder-appetite-transport: a thin present remains observation, not continuity");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    test_add_appetite_policy_outcome_after(
        leo, boundary + 4, 0.65f, 0,
        LEO_WONDER_APPETITE_POLICY_LEGACY,
        LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    leo_wonder_appetite_transport(leo, &witness);
    CHECK(witness.incompatible == 1 &&
          witness.cells[0].incompatible == 1 &&
          witness.cells[0].status ==
              LEO_WONDER_APPETITE_TRANSPORT_INCOMPATIBLE,
          "wonder-appetite-transport: a changed policy language breaks transport instead of translating history");

    g_leo_wonder_appetite_transport_on =
        previous_transport;
    g_leo_wonder_appetite_holdout_on = previous_holdout;
    g_leo_wonder_appetite_calibration_on =
        previous_calibration;
    g_leo_wonder_appetite_policy_on = previous_policy;
    g_leo_wonder_appetite_admission_on =
        previous_admission;
    leo_free(leo);
    free(leo);
    free(before);
}

__attribute__((noinline))
static void test_wonder_appetite_transport_chronology(void) {
    Leo *leo = malloc(sizeof *leo);
    Leo *before = malloc(sizeof *before);
    CHECK(leo && before,
          "wonder-appetite-transport-chronology: heap fixtures allocated");
    if (!leo || !before) {
        free(leo);
        free(before);
        return;
    }

    int previous_chronology =
        g_leo_wonder_appetite_transport_chronology_on;
    int previous_transport =
        g_leo_wonder_appetite_transport_on;
    int previous_holdout =
        g_leo_wonder_appetite_holdout_on;
    int previous_calibration =
        g_leo_wonder_appetite_calibration_on;
    int previous_policy =
        g_leo_wonder_appetite_policy_on;
    int previous_admission =
        g_leo_wonder_appetite_admission_on;
    g_leo_wonder_appetite_transport_chronology_on = 1;
    g_leo_wonder_appetite_transport_on = 1;
    g_leo_wonder_appetite_holdout_on = 1;
    g_leo_wonder_appetite_calibration_on = 1;
    g_leo_wonder_appetite_policy_on = 1;
    g_leo_wonder_appetite_admission_on = 1;

    LeoWonderAppetiteTransportChronology chronology;
    leo_init(leo);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(chronology.unattested == 0 &&
          chronology.pending == 0 &&
          chronology.refuted == 0 &&
          chronology.incompatible == 0 &&
          chronology.observing == 0 &&
          chronology.provisional == 0,
          "wonder-appetite-transport-chronology: an empty life invents no eras");

    LeoWonderAppetiteHoldoutTrial *trial =
        test_open_appetite_holdout(leo, 0.65f, 0);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(trial && chronology.pending == 1 &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_PENDING,
          "wonder-appetite-transport-chronology: chronology cannot precede its unfinished future");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    memset(&leo->wonder_appetite_admissions, 0,
           sizeof leo->wonder_appetite_admissions);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(trial && chronology.unattested == 1 &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_UNATTESTED,
          "wonder-appetite-transport-chronology: chronology cannot manufacture a vanished warrant");

    leo_free(leo);
    leo_init(leo);
    trial = test_finish_appetite_holdout(
        leo, 0.65f, 0, 4, 4, 1, 7, 0, 0);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(trial && chronology.refuted == 1 &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_REFUTED,
          "wonder-appetite-transport-chronology: a refuted future has no transport eras");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    uint64_t boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    uint64_t proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 7, 1, 1, 7);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 7, 1, 1, 7);
    *before = *leo;
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    const LeoWonderAppetiteTransportChronologyCell *cell =
        &chronology.cells[0];
    const LeoWonderAppetiteTransportEpoch *early =
        &cell->epochs[0];
    const LeoWonderAppetiteTransportEpoch *recent =
        &cell->epochs[1];
    CHECK(chronology.provisional == 1 &&
          cell->post_settled == 32 &&
          cell->aggregate_provisional &&
          cell->epoch_coverage_compatible &&
          early->attempts == 16 && recent->attempts == 16 &&
          early->last_proposed_turn <
              recent->first_proposed_turn &&
          early->eligible == 8 && early->abstained == 8 &&
          recent->eligible == 8 && recent->abstained == 8 &&
          fabsf(early->overreach_upper - 0.4709f) < 1e-3f &&
          fabsf(recent->missed_upper - 0.4709f) < 1e-3f &&
          early->motion_bounded && early->restraint_bounded &&
          recent->motion_bounded && recent->restraint_bounded &&
          early->history_coverage_compatible &&
          recent->history_coverage_compatible &&
          cell->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_PROVISIONAL,
          "wonder-appetite-transport-chronology: two bounded adjacent eras preserve only provisional continuity");
    CHECK(!memcmp(before, leo, sizeof *leo) &&
          LEO_STATE_VERSION == 28,
          "wonder-appetite-transport-chronology: reading eras rewrites no body, evidence, or state format");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 5, 3, 0, 8);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 8, 0, 0, 8);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    cell = &chronology.cells[0];
    CHECK(chronology.early_shifted == 1 &&
          cell->aggregate_provisional &&
          !cell->epochs[0].motion_bounded &&
          cell->epochs[1].motion_bounded &&
          cell->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_EARLY_SHIFTED,
          "wonder-appetite-transport-chronology: a good recent era cannot average away earlier overreach");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 8, 0, 0, 8);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 5, 3, 0, 8);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    cell = &chronology.cells[0];
    CHECK(chronology.recent_shifted == 1 &&
          cell->aggregate_provisional &&
          cell->epochs[0].motion_bounded &&
          !cell->epochs[1].motion_bounded &&
          cell->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_RECENT_SHIFTED,
          "wonder-appetite-transport-chronology: an earlier calm cannot average away recent overreach");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 5, 3, 0, 8);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 8, 0, 3, 5);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    cell = &chronology.cells[0];
    CHECK(chronology.both_shifted == 1 &&
          cell->aggregate_provisional &&
          !cell->epochs[0].motion_bounded &&
          cell->epochs[0].restraint_bounded &&
          cell->epochs[1].motion_bounded &&
          !cell->epochs[1].restraint_bounded &&
          cell->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_BOTH_SHIFTED,
          "wonder-appetite-transport-chronology: opposite era-local debts cannot cancel in a pooled present");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 11, 1, 0, 4);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 4, 0, 1, 11);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    cell = &chronology.cells[0];
    CHECK(chronology.ecology_shifted == 1 &&
          cell->aggregate_provisional &&
          cell->epochs[0].history_coverage_compatible &&
          cell->epochs[1].history_coverage_compatible &&
          !cell->epoch_coverage_compatible &&
          cell->epochs[1].coverage_upper <
              cell->epochs[0].coverage_lower &&
          cell->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_ECOLOGY_SHIFTED,
          "wonder-appetite-transport-chronology: a stable pooled coverage cannot hide an arm ecology inversion");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 4, 4, 0, 8);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 4, 4, 0, 8);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(chronology.aggregate_shifted == 1 &&
          !chronology.cells[0].aggregate_provisional &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_AGGREGATE_SHIFTED,
          "wonder-appetite-transport-chronology: chronology cannot overrule a failed pooled transport");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 8, 0, 0, 8);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 8, 0, 0, 7);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(chronology.observing == 1 &&
          chronology.cells[0].post_settled == 31 &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_OBSERVING,
          "wonder-appetite-transport-chronology: thirty-one lives cannot impersonate two eras");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    proposed = boundary + 4;
    proposed = test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 16, 0, 0, 0);
    test_add_appetite_transport_epoch(
        leo, proposed, 0.65f, 0, 8, 0, 0, 8);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(chronology.coverage_starved == 1 &&
          chronology.cells[0].epochs[0].abstained == 0 &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_COVERAGE_STARVED,
          "wonder-appetite-transport-chronology: an epoch cannot borrow its missing arm from another");

    leo_free(leo);
    leo_init(leo);
    trial = test_prepare_appetite_transport(leo);
    boundary =
        leo_wonder_appetite_holdout_terminal_boundary(trial);
    test_add_appetite_policy_outcome_after(
        leo, boundary + 4, 0.65f, 0,
        LEO_WONDER_APPETITE_POLICY_LEGACY,
        LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    leo_wonder_appetite_transport_chronology(
        leo, &chronology);
    CHECK(chronology.incompatible == 1 &&
          chronology.cells[0].epochs[0].incompatible == 1 &&
          chronology.cells[0].status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_INCOMPATIBLE,
          "wonder-appetite-transport-chronology: an era cannot translate a changed policy language");

    g_leo_wonder_appetite_transport_chronology_on =
        previous_chronology;
    g_leo_wonder_appetite_transport_on = previous_transport;
    g_leo_wonder_appetite_holdout_on = previous_holdout;
    g_leo_wonder_appetite_calibration_on =
        previous_calibration;
    g_leo_wonder_appetite_policy_on = previous_policy;
    g_leo_wonder_appetite_admission_on =
        previous_admission;
    leo_free(leo);
    free(leo);
    free(before);
}

enum {
    TEST_APPETITE_CHECKPOINT_PROVISIONAL = 0,
    TEST_APPETITE_CHECKPOINT_EARLY_SHIFT,
    TEST_APPETITE_CHECKPOINT_RECENT_SHIFT,
    TEST_APPETITE_CHECKPOINT_COVERAGE_STARVED,
    TEST_APPETITE_CHECKPOINT_SOURCE_STARVED,
    TEST_APPETITE_CHECKPOINT_PENDING,
    TEST_APPETITE_CHECKPOINT_MIXED,
    TEST_APPETITE_CHECKPOINT_INCOMPATIBLE
};

static void test_add_appetite_checkpoint_pattern(
        Leo *leo, int pattern) {
    if (!leo) return;
    LeoWonderAppetiteHoldoutTrial *trial =
        &leo->wonder_appetite_holdouts.trials[0];
    LeoWonderAppetiteCheckpointLane *lane =
        &leo->wonder_appetite_checkpoints.lanes[0];
    uint64_t boundary =
        lane->next_after_proposed_turn ?
            lane->next_after_proposed_turn :
            leo_wonder_appetite_holdout_terminal_boundary(trial);
    uint64_t proposed = boundary + 4;
    test_reset_appetite_policy_outcomes(leo);

    if (pattern == TEST_APPETITE_CHECKPOINT_PROVISIONAL ||
        pattern == TEST_APPETITE_CHECKPOINT_SOURCE_STARVED) {
        proposed = test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 7, 1, 1, 7);
        test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 7, 1, 1, 7);
    } else if (
        pattern == TEST_APPETITE_CHECKPOINT_EARLY_SHIFT) {
        proposed = test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 5, 3, 0, 8);
        test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 8, 0, 0, 8);
    } else if (
        pattern == TEST_APPETITE_CHECKPOINT_RECENT_SHIFT) {
        proposed = test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 8, 0, 0, 8);
        test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 5, 3, 0, 8);
    } else if (
        pattern == TEST_APPETITE_CHECKPOINT_COVERAGE_STARVED) {
        proposed = test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 16, 0, 0, 0);
        test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 8, 0, 0, 8);
    } else if (
        pattern == TEST_APPETITE_CHECKPOINT_PENDING) {
        proposed = test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 8, 0, 0, 8);
        test_add_appetite_transport_epoch(
            leo, proposed, 0.65f, 0, 8, 0, 0, 7);
    } else if (
        pattern == TEST_APPETITE_CHECKPOINT_MIXED) {
        for (int epoch = 0;
             epoch < LEO_WONDER_APPETITE_TRANSPORT_EPOCHS;
             epoch++) {
            proposed = test_add_appetite_transport_epoch(
                leo, proposed, 0.65f, 0, 4, 0, 0, 4);
            for (int i = 0; i < 4; i++, proposed += 4)
                test_add_appetite_policy_outcome_after(
                    leo, proposed, 0.65f, 0,
                    LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                    LEO_WONDER_APPETITE_CALIB_EXTERNAL);
            for (int i = 0; i < 4; i++, proposed += 4)
                test_add_appetite_policy_outcome_after(
                    leo, proposed, 0.75f, 0,
                    LEO_WONDER_APPETITE_POLICY_ELIGIBLE,
                    LEO_WONDER_APPETITE_CALIB_SUSTAINED);
        }
    } else if (
        pattern == TEST_APPETITE_CHECKPOINT_INCOMPATIBLE) {
        test_add_appetite_policy_outcome_after(
            leo, proposed, 0.65f, 0,
            LEO_WONDER_APPETITE_POLICY_LEGACY,
            LEO_WONDER_APPETITE_CALIB_SUSTAINED);
    }
    if (pattern == TEST_APPETITE_CHECKPOINT_SOURCE_STARVED)
        for (int i = 0;
             i < leo->wonder_appetite_calibration.n; i++)
            snprintf(
                leo->wonder_appetite_calibration.receipts[i].word,
                sizeof leo->wonder_appetite_calibration.receipts[i].word,
                "monowonder");
    leo_wonder_appetite_checkpoint_update(leo);
}

static void test_build_appetite_checkpoint_pair(
        Leo *leo, int first, int second) {
    leo_init(leo);
    test_prepare_appetite_transport(leo);
    test_add_appetite_checkpoint_pattern(leo, first);
    test_add_appetite_checkpoint_pattern(leo, second);
}

__attribute__((noinline))
static void test_wonder_appetite_transport_checkpoints(void) {
    Leo *leo = malloc(sizeof *leo);
    Leo *woke = malloc(sizeof *woke);
    Leo *old = malloc(sizeof *old);
    Leo *damaged = malloc(sizeof *damaged);
    CHECK(leo && woke && old && damaged,
          "wonder-appetite-checkpoint: heap fixtures allocated");
    if (!leo || !woke || !old || !damaged) {
        free(leo);
        free(woke);
        free(old);
        free(damaged);
        return;
    }

    int previous_checkpoint =
        g_leo_wonder_appetite_checkpoint_on;
    int previous_holdout =
        g_leo_wonder_appetite_holdout_on;
    int previous_calibration =
        g_leo_wonder_appetite_calibration_on;
    int previous_policy =
        g_leo_wonder_appetite_policy_on;
    int previous_admission =
        g_leo_wonder_appetite_admission_on;
    g_leo_wonder_appetite_checkpoint_on = 1;
    g_leo_wonder_appetite_holdout_on = 1;
    g_leo_wonder_appetite_calibration_on = 1;
    g_leo_wonder_appetite_policy_on = 1;
    g_leo_wonder_appetite_admission_on = 1;

    leo_init(leo);
    test_prepare_appetite_transport(leo);
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_PROVISIONAL);
    LeoWonderAppetiteCheckpointLane *lane =
        &leo->wonder_appetite_checkpoints.lanes[0];
    const LeoWonderAppetiteCheckpoint *first =
        leo_wonder_appetite_checkpoint_at(lane, 0);
    CHECK(first && lane->n == 1 &&
          lane->active.status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_EMPTY &&
          first->attempts ==
              LEO_WONDER_APPETITE_CHECKPOINT_BUDGET &&
          first->epochs[0].attempts == 16 &&
          first->epochs[1].attempts == 16 &&
          first->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_PROVISIONAL &&
          first->seen_proposed_turn[0] >
              first->after_proposed_turn &&
          first->seen_proposed_turn[31] ==
              first->through_proposed_turn &&
          leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: one raw 32-life budget closes with exact proposal identity");

    LeoWonderAppetiteCheckpointSequence sequence;
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(sequence.one == 1 &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_ONE,
          "wonder-appetite-checkpoint: one life remains one observation, not a regime");

    uint64_t first_through =
        first ? first->through_proposed_turn : 0;
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_PROVISIONAL);
    first = leo_wonder_appetite_checkpoint_at(lane, 0);
    const LeoWonderAppetiteCheckpoint *second =
        leo_wonder_appetite_checkpoint_at(lane, 1);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(first && second && lane->n == 2 &&
          first->through_proposed_turn == first_through &&
          second->after_proposed_turn == first_through &&
          second->seen_proposed_turn[0] > first_through &&
          first->seen_proposed_turn[31] <
              second->seen_proposed_turn[0] &&
          sequence.stable_provisional == 1 &&
          sequence.cells[0].same_signature &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_STABLE_PROVISIONAL &&
          leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: a second life begins strictly after the first and alone earns stable provisionality");

    LeoWonderAppetiteCheckpointLane lane_before = *lane;
    lane->history[0].seen_proposed_turn[1] =
        lane->history[0].seen_proposed_turn[0];
    CHECK(!leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: duplicate proposal identity invalidates the ledger");
    *lane = lane_before;
    lane->history[0].status =
        LEO_WONDER_APPETITE_CHRONOLOGY_AGGREGATE_SHIFTED;
    CHECK(!leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: a stored verdict cannot disagree with its raw counts");
    *lane = lane_before;
    lane->history[1].after_proposed_turn =
        lane->history[0].through_proposed_turn - 4;
    CHECK(!leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: overlapping lives cannot share evidence");
    *lane = lane_before;
    lane->history[1].through_proposed_turn =
        (uint64_t)leo->school.turn_clock + 4;
    lane->history[1].seen_proposed_turn[31] =
        lane->history[1].through_proposed_turn;
    lane->history[1].epochs[1].last_proposed_turn =
        lane->history[1].through_proposed_turn;
    lane->next_after_proposed_turn =
        lane->history[1].through_proposed_turn;
    CHECK(!leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: internally coherent evidence from a future turn is still impossible");
    *lane = lane_before;

    test_build_appetite_checkpoint_pair(
        leo, TEST_APPETITE_CHECKPOINT_PROVISIONAL,
        TEST_APPETITE_CHECKPOINT_EARLY_SHIFT);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(sequence.emerging_shift == 1 &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_EMERGING_SHIFT,
          "wonder-appetite-checkpoint: one changed life is an emerging shift, not a new law");

    leo_free(leo);
    test_build_appetite_checkpoint_pair(
        leo, TEST_APPETITE_CHECKPOINT_EARLY_SHIFT,
        TEST_APPETITE_CHECKPOINT_RECENT_SHIFT);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(sequence.persistent_shift == 1 &&
          !sequence.cells[0].same_signature &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_PERSISTENT_SHIFT,
          "wonder-appetite-checkpoint: two shifted lives persist even when their local debt changes face");

    leo_free(leo);
    test_build_appetite_checkpoint_pair(
        leo, TEST_APPETITE_CHECKPOINT_EARLY_SHIFT,
        TEST_APPETITE_CHECKPOINT_PROVISIONAL);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(sequence.recovered == 1 &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_RECOVERED,
          "wonder-appetite-checkpoint: a bounded life after a shift is visible as recovery");

    leo_free(leo);
    test_build_appetite_checkpoint_pair(
        leo, TEST_APPETITE_CHECKPOINT_PROVISIONAL,
        TEST_APPETITE_CHECKPOINT_COVERAGE_STARVED);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(sequence.insufficient == 1 &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_INSUFFICIENT,
          "wonder-appetite-checkpoint: an arm-starved life cannot vote for stability or change");

    leo_free(leo);
    leo_init(leo);
    test_prepare_appetite_transport(leo);
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_SOURCE_STARVED);
    lane = &leo->wonder_appetite_checkpoints.lanes[0];
    first = leo_wonder_appetite_checkpoint_at(lane, 0);
    LeoWonderAppetiteCheckpointSources sources;
    leo_wonder_appetite_checkpoint_sources(first, &sources);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(first &&
          first->status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_SOURCE_STARVED &&
          sources.distinct == 1 &&
          sources.max_attempts == 32 &&
          sources.epoch_distinct[0] == 1 &&
          sources.epoch_distinct[1] == 1 &&
          sources.epoch_max_attempts[0] == 16 &&
          sources.epoch_max_attempts[1] == 16 &&
          sequence.insufficient == 1 &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_INSUFFICIENT,
          "wonder-appetite-checkpoint: one recurring Wonder cannot impersonate a transport life");
    LeoWonderAppetiteCheckpointLane source_before = *lane;
    lane->history[0].seen_source_id[0] = 0;
    CHECK(!leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: a used attempt cannot lose its source identity");
    *lane = source_before;

    leo_free(leo);
    leo_init(leo);
    test_prepare_appetite_transport(leo);
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_PENDING);
    lane = &leo->wonder_appetite_checkpoints.lanes[0];
    CHECK(lane->n == 0 &&
          lane->active.status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_PENDING &&
          lane->active.attempts == 31 &&
          lane->active.epochs[0].attempts == 16 &&
          lane->active.epochs[1].attempts == 15 &&
          leo_wonder_appetite_checkpoints_valid(leo),
          "wonder-appetite-checkpoint: thirty-one settled attempts persist as an unfinished life");

    const char *state =
        "/tmp/leo_appetite_checkpoint_v26.state";
    const char *v25 =
        "/tmp/leo_appetite_checkpoint_v25.state";
    const char *v24 =
        "/tmp/leo_appetite_checkpoint_v24.state";
    const char *cut =
        "/tmp/leo_appetite_checkpoint_v26_cut.state";
    const char *bad =
        "/tmp/leo_appetite_checkpoint_v26_bad.state";
    int saved = leo_save_state(leo, state);
    leo_init(woke);
    CHECK(saved && leo_load_state(woke, state) &&
          !memcmp(&woke->wonder_appetite_checkpoints,
                  &leo->wonder_appetite_checkpoints,
                  sizeof leo->wonder_appetite_checkpoints),
          "wonder-appetite-checkpoint: an unfinished source-aware life survives current sleep exactly");

    int built_v25 = 0, built_v24 = 0;
    int built_cut = 0, built_bad = 0;
    FILE *fi = fopen(state, "rb");
    if (fi) {
        fseek(fi, 0, SEEK_END);
        long size = ftell(fi);
        fseek(fi, 0, SEEK_SET);
        unsigned char *bytes =
            malloc(size > 0 ? (size_t)size : 1);
        long checkpoint_tail =
            (long)sizeof(LeoWonderAppetiteCheckpoints);
        long state_tail = (long)(sizeof(LeoStateSwarm) +
            2 * sizeof(int32_t) +
            leo->school.n_learned * sizeof(int8_t) +
            leo->school.n_wonders * sizeof(int8_t));
        long checkpoint_start = size - state_tail - checkpoint_tail;
        if (bytes && checkpoint_start > 0 &&
            (long)fread(bytes, 1, (size_t)size, fi) == size) {
            uint32_t twenty_four = 24;
            memcpy(bytes + sizeof(uint32_t), &twenty_four,
                   sizeof twenty_four);
            FILE *fo = fopen(v24, "wb");
            if (fo) {
                built_v24 =
                    (long)fwrite(
                        bytes, 1,
                        (size_t)checkpoint_start, fo) ==
                    checkpoint_start;
                fclose(fo);
            }

            uint32_t twenty_five = 25;
            memcpy(bytes + sizeof(uint32_t), &twenty_five,
                   sizeof twenty_five);
            fo = fopen(v25, "wb");
            if (fo) {
                built_v25 =
                    (long)fwrite(
                        bytes, 1,
                        (size_t)checkpoint_start, fo) ==
                    checkpoint_start;
                fclose(fo);
            }

            uint32_t twenty_six = 26;
            memcpy(bytes + sizeof(uint32_t), &twenty_six,
                   sizeof twenty_six);
            fo = fopen(cut, "wb");
            if (fo) {
                built_cut =
                    (long)fwrite(
                        bytes, 1, (size_t)(size - state_tail - 1), fo) ==
                    size - state_tail - 1;
                fclose(fo);
            }

            LeoWonderAppetiteCheckpoints corrupted;
            memcpy(&corrupted,
                   bytes + checkpoint_start,
                   sizeof corrupted);
            corrupted.lanes[0].active.seen_source_id[0] = 0;
            memcpy(bytes + checkpoint_start,
                   &corrupted, sizeof corrupted);
            fo = fopen(bad, "wb");
            if (fo) {
                built_bad =
                    (long)fwrite(
                        bytes, 1, (size_t)(size - state_tail), fo) ==
                    size - state_tail;
                fclose(fo);
            }
        }
        free(bytes);
        fclose(fi);
    }

    leo_init(old);
    CHECK(built_v24 && leo_load_state(old, v24) &&
          old->wonder_appetite_checkpoints.lanes[0].n == 0 &&
          old->wonder_appetite_checkpoints.lanes[0].active.status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_EMPTY &&
          old->wonder_appetite_checkpoints.lanes[0].
              next_after_proposed_turn ==
                  leo->wonder_appetite_calibration.receipts[30].
                      proposed_turn,
          "wonder-appetite-checkpoint: v24 migration starts after existing history instead of inventing a checkpoint");

    leo_free(old);
    leo_init(old);
    CHECK(built_v25 && leo_load_state(old, v25) &&
          old->wonder_appetite_checkpoints.lanes[0].n == 0 &&
          old->wonder_appetite_checkpoints.lanes[0].active.status ==
              LEO_WONDER_APPETITE_CHRONOLOGY_EMPTY &&
          old->wonder_appetite_checkpoints.lanes[0].
              next_after_proposed_turn ==
                  leo->wonder_appetite_calibration.receipts[30].
                      proposed_turn,
          "wonder-appetite-checkpoint: v25 evidence restarts after history instead of inventing source identity");

    leo_init(damaged);
    CHECK(built_cut && leo_load_state(damaged, cut) &&
          !memcmp(&damaged->wonder_appetite_holdouts,
                  &leo->wonder_appetite_holdouts,
                  sizeof leo->wonder_appetite_holdouts) &&
          !memcmp(&damaged->wonder_appetite_admissions,
                  &leo->wonder_appetite_admissions,
                  sizeof leo->wonder_appetite_admissions) &&
          damaged->wonder_appetite_checkpoints.lanes[0].n == 0 &&
          damaged->wonder_appetite_checkpoints.lanes[0].
              next_after_proposed_turn ==
                  leo->wonder_appetite_calibration.receipts[30].
                      proposed_turn,
          "wonder-appetite-checkpoint: a truncated v26 ledger loses no body, trial, or admission");

    leo_free(damaged);
    leo_init(damaged);
    CHECK(built_bad && leo_load_state(damaged, bad) &&
          !memcmp(&damaged->wonder_appetite_holdouts,
                  &leo->wonder_appetite_holdouts,
                  sizeof leo->wonder_appetite_holdouts) &&
          damaged->wonder_appetite_checkpoints.lanes[0].n == 0 &&
          damaged->wonder_appetite_checkpoints.lanes[0].
              next_after_proposed_turn ==
                  leo->wonder_appetite_calibration.receipts[30].
                      proposed_turn,
          "wonder-appetite-checkpoint: corrupt source identity fails soft and cannot be replayed");
    remove(state);
    remove(v25);
    remove(v24);
    remove(cut);
    remove(bad);

    leo_free(leo);
    leo_init(leo);
    test_prepare_appetite_transport(leo);
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_MIXED);
    lane = &leo->wonder_appetite_checkpoints.lanes[0];
    first = leo_wonder_appetite_checkpoint_at(lane, 0);
    CHECK(first &&
          first->epochs[0].attempts == 16 &&
          first->epochs[0].exact == 8 &&
          first->epochs[0].confounded == 4 &&
          first->epochs[0].other == 4 &&
          first->epochs[1].attempts == 16 &&
          first->epochs[1].exact == 8 &&
          first->epochs[1].confounded == 4 &&
          first->epochs[1].other == 4,
          "wonder-appetite-checkpoint: confounds and other strata spend fixed time without impersonating either arm");

    leo_free(leo);
    leo_init(leo);
    test_prepare_appetite_transport(leo);
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_INCOMPATIBLE);
    lane = &leo->wonder_appetite_checkpoints.lanes[0];
    LeoWonderAppetiteCheckpointLane incompatible_before = *lane;
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_PROVISIONAL);
    leo_wonder_appetite_checkpoint_sequence(leo, &sequence);
    CHECK(lane->blocked && lane->n == 1 &&
          !memcmp(&incompatible_before, lane,
                  sizeof incompatible_before) &&
          sequence.incompatible == 1 &&
          sequence.cells[0].status ==
              LEO_WONDER_APPETITE_CHECKPOINT_SEQUENCE_INCOMPATIBLE,
          "wonder-appetite-checkpoint: changed policy language closes the lane instead of translating later evidence");

    leo_free(leo);
    leo_init(leo);
    test_prepare_appetite_transport(leo);
    g_leo_wonder_appetite_checkpoint_on = 0;
    test_add_appetite_checkpoint_pattern(
        leo, TEST_APPETITE_CHECKPOINT_PROVISIONAL);
    CHECK(!memcmp(&leo->wonder_appetite_checkpoints,
                  &(LeoWonderAppetiteCheckpoints){0},
                  sizeof leo->wonder_appetite_checkpoints),
          "wonder-appetite-checkpoint: ablation prevents the ledger rather than hiding a reader");

    g_leo_wonder_appetite_checkpoint_on = previous_checkpoint;
    g_leo_wonder_appetite_holdout_on = previous_holdout;
    g_leo_wonder_appetite_calibration_on =
        previous_calibration;
    g_leo_wonder_appetite_policy_on = previous_policy;
    g_leo_wonder_appetite_admission_on =
        previous_admission;
    leo_free(leo);
    leo_free(woke);
    leo_free(old);
    leo_free(damaged);
    free(leo);
    free(woke);
    free(old);
    free(damaged);
}

/* A.77: a comma starts a new School statement only when its right side
 * carries an independent subject-predicate clause. Contrast fragments,
 * dialogue markers, and adjective/concept lists remain one answer. */
__attribute__((noinline))
static void test_wonder_comma_scope(void) {
    Leo *scope = calloc(1, sizeof *scope);
    LeoSchoolAnswerEvidence *evidence =
        calloc(1, sizeof *evidence);
    char *out = calloc(1024, 1);
    CHECK(scope && evidence && out,
          "wonder-comma-scope: heap fixtures allocated");
    if (scope && evidence && out) {
        int water = semtok_word("water");
        int animal = semtok_word("animal");
        int music = semtok_word("music");
        int small = semtok_word("small");
        int fire = semtok_word("warm");
        LeoSchoolAnswerReference reference;

        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "a zorble is an animal, the river has water",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
              evidence->asserted[animal] == 1 &&
              evidence->asserted[water] == 0,
              "wonder-comma-scope: an explicit answer cannot inherit an independent comma tail");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "it is an animal, the river has water",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_ANAPHORIC &&
              evidence->asserted[animal] == 1 &&
              evidence->asserted[water] == 0,
              "wonder-comma-scope: anaphora cannot lend its reference to a new comma clause");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "it is an animal, the river isn't water",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_ANAPHORIC &&
              evidence->asserted[animal] == 1 &&
              evidence->rejected[water] == 0,
              "wonder-comma-scope: a contracted predicate still begins an independent clause");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "animal, the river has water",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_ELLIPTIC &&
              evidence->asserted[animal] == 1 &&
              evidence->asserted[water] == 0,
              "wonder-comma-scope: ellipsis ends before an independent comma clause");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "a zorble is not water, but animal",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
              evidence->rejected[water] == 1 &&
              evidence->asserted[animal] == 1,
              "wonder-comma-scope: a contrast fragment remains inside its answer");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "yes, it is music, the river has water",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_ANAPHORIC &&
              evidence->asserted[music] == 1 &&
              evidence->asserted[water] == 0,
              "wonder-comma-scope: a dialogue marker may introduce one anaphoric clause");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        reference = leo_school_answer_scope(
            scope,
            "a zorble is a small, warm animal",
            evidence);
        CHECK(reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
              evidence->asserted[small] == 1 &&
              evidence->asserted[fire] == 1 &&
              evidence->asserted[animal] == 1,
              "wonder-comma-scope: a concept list is not mistaken for a new clause");

        leo_free(scope);
        seed_wonder_negation_body(scope);
        leo_respond(
            scope,
            "it is an animal, the river has water",
            out, 1024);
        const LeoFlowSnapshot *flow =
            leo_flow_at(&scope->flow, scope->flow.n - 1);
        CHECK(leo_semtok_word(scope, "zorble") == animal &&
              flow && flow->perceived[water] > 0.0f,
              "wonder-comma-scope: excluded School life remains perceived by Flow");
    }
    if (scope) leo_free(scope);
    free(scope);
    free(evidence);
    free(out);
}

static TEST_NOINLINE void test_foundation(void) {
    /* 1. init state */
    Leo *leo = test_leo_alloc(); leo_init(leo);
    CHECK(leo->bpe.vocab_size == 256, "init: vocab_size == 256");
    CHECK(leo->bpe.n_merges == 0,     "init: n_merges == 0");
    CHECK(leo->cooc.total_tokens == 0, "init: total_tokens == 0");
    CHECK(g_leo_arc_on == 0, "voice recovery: random-fingerprint reply arc is opt-in");
    {
        float arc[LEO_RET_DIM];
        memcpy(arc, leo->w_embed + (size_t)'a' * LEO_RET_DIM, sizeof arc);
        CandCollector cc; memset(&cc, 0, sizeof cc);
        cc.leo = leo; cc.arc = arc;
        float off = leo_arc_bias(&cc, 'a');
        g_leo_arc_on = 1;
        float on = leo_arc_bias(&cc, 'a');
        g_leo_arc_on = 0;
        CHECK(off == 0.0f && on > 0.39f,
              "voice recovery: --arc can still enable the laboratory trajectory bias");
    }

    /* 2. encode/decode roundtrip with no merges (pure bytes) */
    {
        const char *s = "hi leo";
        int ids[16];
        int n = bpe_encode(&leo->bpe, (const uint8_t *)s, (int)strlen(s), ids, 16);
        char rebuilt[32] = {0};
        int p = 0;
        for (int i = 0; i < n; i++) {
            char b[LEO_MAX_TOKEN_LEN + 1];
            int l = bpe_decode_token(&leo->bpe, ids[i], b, sizeof(b));
            memcpy(rebuilt + p, b, (size_t)l); p += l;
        }
        rebuilt[p] = 0;
        CHECK(n == (int)strlen(s), "encode (no merges): one id per byte");
        CHECK(strcmp(rebuilt, s) == 0, "decode roundtrip reconstructs bytes");
    }

    /* 3. online merge learning: repetition births merges */
    {
        leo_ingest(leo, "the the the the the the the the");
        CHECK(leo->bpe.n_merges > 0,    "ingest: merges learned from repetition");
        CHECK(leo->bpe.vocab_size > 256, "ingest: vocab grew past 256 bytes");
        CHECK(leo->cooc.n_entries > 0,  "ingest: cooc populated");
        CHECK(leo->bigrams.n_entries > 0, "ingest: bigrams populated");
        CHECK(leo->trigrams.n_entries > 0, "ingest: trigrams populated");
        CHECK(leo->step == 31,          "ingest: step counts heard tokens (31 bytes, pre-merge)");
    }

    /* 4. encode after merges still roundtrips */
    {
        const char *s = "the";
        int ids[16];
        int n = bpe_encode(&leo->bpe, (const uint8_t *)s, (int)strlen(s), ids, 16);
        char rebuilt[32] = {0};
        int p = 0;
        for (int i = 0; i < n; i++) {
            char b[LEO_MAX_TOKEN_LEN + 1];
            int l = bpe_decode_token(&leo->bpe, ids[i], b, sizeof(b));
            memcpy(rebuilt + p, b, (size_t)l); p += l;
        }
        rebuilt[p] = 0;
        CHECK(strcmp(rebuilt, s) == 0, "decode roundtrip after merges");
        CHECK(n <= (int)strlen(s),     "merges compress the token stream");
    }

    /* 5. reverse index: a heard byte-token has successors. Bigrams are
     * recorded at ingest time on the byte stream (merges promote only at
     * the end of the batch), so byte 't' is a live bigram source. */
    {
        int succ = 0;
        bigram_walk_src(&leo->bigrams, (int)'t', succ_cb, &succ);
        CHECK(succ > 0, "bigram_walk_src finds successors of byte 't'");
    }

    /* 6. word-shape gates */
    CHECK(is_common_short_word((const uint8_t *)"the", 0, 3) == 1, "whitelist: 'the' is a word");
    CHECK(is_common_short_word((const uint8_t *)"leo", 0, 3) == 1, "whitelist: 'leo' is a word");
    CHECK(is_common_short_word((const uint8_t *)"xqz", 0, 3) == 0, "whitelist: 'xqz' is not");
    CHECK(is_alpha_only_bytes((const uint8_t *)"rain", 0, 4) == 1, "alpha-only: 'rain'");
    CHECK(is_alpha_only_bytes((const uint8_t *)"ra1n", 0, 4) == 0, "alpha-only: 'ra1n' no");

    /* 7. single-pair merge primitive (one-shot) works */
    {
        Leo *l2 = test_leo_alloc(); leo_init(l2);
        for (int i = 0; i < 5; i++) bpe_count_pair(&l2->bpe, 'a', 'b');
        int before = l2->bpe.n_merges;
        int got = bpe_learn_merge(&l2->bpe);
        CHECK(got == 1 && l2->bpe.n_merges == before + 1, "bpe_learn_merge promotes a hot pair");
        test_leo_delete(l2);
    }

    /* 8. decay shrinks counts, does not crash */
    {
        int before = leo->cooc.n_entries;
        cooc_decay(&leo->cooc, 0.5f);
        bigram_decay(&leo->bigrams, 0.5f);
        trigram_decay(&leo->trigrams, 0.5f);
        CHECK(leo->cooc.n_entries == before, "decay keeps entry count (counts shrink in place)");
    }

    test_leo_delete(leo);

}

static TEST_NOINLINE void test_voice_field_and_persistence(void) {
    /* 9. generation (step 1): coherent shape + reproducibility */
    {
        Leo *l3 = test_leo_alloc(); leo_init(l3);
        const char *mini =
            "Leo sat by the window. The rain was soft on the glass. "
            "He thinks about the sound. Leo likes the quiet house. "
            "The morning is warm. He remembers his mother. "
            "Leo walks slowly. The little book is open on the floor. ";
        for (int r = 0; r < 8; r++) leo_ingest(l3, mini);  /* merges + trigrams */

        char a[1024], b[1024];
        srand(7); int na = leo_generate(l3, a, sizeof(a));
        srand(7); int nb = leo_generate(l3, b, sizeof(b));
        CHECK(na > 0 && a[0] != 0, "generate: non-empty output");
        int L = (int)strlen(a);
        char last = L > 0 ? a[L - 1] : 0;
        CHECK(last == '.' || last == '!' || last == '?', "generate: ends on sentence punctuation");
        CHECK(!(a[0] >= 'a' && a[0] <= 'z'), "generate: first char not lowercase");
        CHECK(nb > 0 && strcmp(a, b) == 0, "generate: reproducible under same seed");

        char ch[2048];
        srand(11); int nc = leo_chain(l3, 3, ch, sizeof(ch));
        CHECK(nc > 0 && ch[0] != 0, "chain: multi-sentence non-empty");
        test_leo_delete(l3);
    }

}

static TEST_NOINLINE void test_heard_and_chambers(void) {
    /* 10. heard-word memory: whole surface-words counted, independent of BPE */
    {
        Leo *l4 = test_leo_alloc(); leo_init(l4);
        leo_ingest(l4, "the mother sang. the mother smiled. a window in the rain.");
        CHECK(leo_heard_count(&l4->heard, "mother") == 2, "heard: 'mother' counted twice");
        CHECK(leo_heard_count(&l4->heard, "window") == 1, "heard: 'window' counted once");
        CHECK(leo_heard_count(&l4->heard, "zxqwj")  == 0, "heard: unheard word is 0");
        test_leo_delete(l4);
    }

    /* 11. chamber discrimination: a short function word must NOT spurious-match
     *     an anchor by substring ('the' is inside 'mother' — it lit LOVE on
     *     every prompt before the fix). Exact and >=4 morphological matches
     *     still fire. feel_text memsets chamber_ext, so each call is isolated. */
    {
        Leo *l5 = test_leo_alloc(); leo_init(l5);
        leo_field_chambers_feel_text(l5, "the");
        CHECK(l5->chamber_ext[LEO_CH_LOVE] == 0.0f, "chambers: 'the' does NOT light LOVE (no substring into 'mother')");
        int any = 0;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) if (l5->chamber_ext[i] != 0.0f) any = 1;
        CHECK(!any, "chambers: 'the' lights no chamber (function word, no exact/>=4 match)");

        leo_field_chambers_feel_text(l5, "mother");
        CHECK(l5->chamber_ext[LEO_CH_LOVE] > 0.0f, "chambers: 'mother' lights LOVE (exact anchor)");

        leo_field_chambers_feel_text(l5, "dark");
        CHECK(l5->chamber_ext[LEO_CH_FEAR] > 0.0f, "chambers: 'dark' lights FEAR (exact anchor)");

        leo_field_chambers_feel_text(l5, "mothers");
        CHECK(l5->chamber_ext[LEO_CH_LOVE] > 0.0f, "chambers: 'mothers' still lights LOVE (>=4 morphological substring)");
        test_leo_delete(l5);
    }

    /* 12. breath: per-reply lexical decay + prune (continuity bundle, step 1) */
    {
        Leo *l6 = test_leo_alloc(); leo_init(l6);
        leo_ingest(l6, "the warm light. the warm light. the warm light.");
        int s0 = -1, d0 = -1; float before = 0.0f;
        for (int i = 0; i < l6->cooc.capacity; i++)
            if (l6->cooc.entries[i].count > 0.0f) {
                s0 = l6->cooc.entries[i].src; d0 = l6->cooc.entries[i].dst;
                before = l6->cooc.entries[i].count; break;
            }
        CHECK(before > 0.0f, "breath: field has a live cooc entry");
        leo_breath(l6);
        float after = cooc_get(&l6->cooc, s0, d0);
        CHECK(fabsf(after - before * LEO_LEX_DECAY_RATE) < 1e-4f,
              "breath: cooc count decays by exactly LEO_LEX_DECAY_RATE");
        /* prune: a sub-threshold entry drops, a strong one survives */
        cooc_update(&l6->cooc, 9001, 9002, 0.05f);
        cooc_prune_rebuild(&l6->cooc, LEO_LEX_PRUNE_THRESHOLD);
        CHECK(cooc_get(&l6->cooc, 9001, 9002) == 0.0f, "breath: prune drops a sub-threshold entry");
        CHECK(cooc_get(&l6->cooc, s0, d0) > 0.0f, "breath: prune keeps a strong entry");
        /* flag off -> leo_respond leaves the field undecayed (alien prompt:
         * its ingest touches only its own token pairs, not (s0,d0)) */
        g_leo_breath_on = 0;
        float pre = cooc_get(&l6->cooc, s0, d0);
        char r[1024];
        srand(5); leo_respond(l6, "zuzu kex", r, sizeof r);
        float post = cooc_get(&l6->cooc, s0, d0);
        g_leo_breath_on = 1;
        CHECK(post == pre, "breath: --no-breath leaves cooc undecayed through respond");
        test_leo_delete(l6);
    }


}

static TEST_NOINLINE void test_state_persistence(void) {
    /* 13. state persistence: save -> load round-trips the field (continuity
     *     bundle step 2). Compact serialization: every count + value is
     *     preserved exactly (the memory Leo carries forward); the voice
     *     survives load. Generation is NOT asserted byte-identical — the
     *     reverse-index chain order is not serialized, so sampling can differ
     *     at a tie (Leo carries a living field, not a frozen replay). */
    {
        const char *corpus =
            "The warm light fell on his mother's hands. "
            "Leo loves the warm light. His mother holds him close. "
            "The rain comes at night. Leo hears the rain on the window. "
            "He loves the rain and the warm light and his mother. "
            "The window is quiet. The night is quiet. Leo is small and warm.";
        Leo *a = test_leo_alloc(); leo_init(a);
        for (int r = 0; r < 4; r++) leo_ingest(a, corpus);
        leo_build_chamber_tags(a);
        leo_supertok_scan(a);

        const char *tmp = "/tmp/leo_state_roundtrip.bin";
        CHECK(leo_save_state(a, tmp) == 1, "state: save returns 1");

        Leo *b = test_leo_alloc(); leo_init(b);
        CHECK(leo_load_state(b, tmp) == 1, "state: load returns 1");
        CHECK(b->bpe.vocab_size    == a->bpe.vocab_size,    "state: vocab_size round-trips");
        CHECK(b->bpe.n_merges      == a->bpe.n_merges,      "state: n_merges round-trips");
        CHECK(b->cooc.total_tokens == a->cooc.total_tokens, "state: total_tokens round-trips");
        CHECK(b->cooc.n_entries    == a->cooc.n_entries,    "state: cooc entry count round-trips");
        CHECK(b->bigrams.n_entries == a->bigrams.n_entries, "state: bigram count round-trips");
        CHECK(b->trigrams.n_entries== a->trigrams.n_entries,"state: trigram count round-trips");
        /* exact value fidelity: every live cooc/bigram count reads back exactly */
        int cprobe = 0, cok = 0;
        for (int i = 0; i < a->cooc.capacity && cprobe < 4000; i++) {
            CoocEntry *e = &a->cooc.entries[i];
            if (e->count <= 0) continue;
            cprobe++; if (cooc_get(&b->cooc, e->src, e->dst) == e->count) cok++;
        }
        CHECK(cprobe > 0 && cok == cprobe, "state: every sampled cooc value is exact");
        int bprobe = 0, bok = 0;
        for (int i = 0; i < a->bigrams.capacity && bprobe < 4000; i++) {
            BigramEntry *e = &a->bigrams.entries[i];
            if (e->count <= 0) continue;
            bprobe++; if (bigram_get(&b->bigrams, e->src, e->dst) == e->count) bok++;
        }
        CHECK(bprobe > 0 && bok == bprobe, "state: every sampled bigram value is exact");
        CHECK(leo_heard_count(&b->heard,"warm")   == leo_heard_count(&a->heard,"warm"),
              "state: heard memory ('warm') round-trips");
        CHECK(leo_heard_count(&b->heard,"mother") == leo_heard_count(&a->heard,"mother"),
              "state: heard memory ('mother') round-trips");
        /* the voice survives load: a loaded organism speaks (not "...") */
        char rb[2048];
        srand(99); leo_respond(b, "the warm light", rb, sizeof rb);
        CHECK(rb[0] && strcmp(rb, "...") != 0, "state: loaded organism speaks");
        /* missing file -> clean failure, usable fresh Leo */
        Leo *c = test_leo_alloc(); leo_init(c);
        CHECK(leo_load_state(c, "/tmp/leo_state_does_not_exist_xyz.bin") == 0,
              "state: missing file -> load returns 0");
        test_leo_delete(a); test_leo_delete(b); test_leo_delete(c);
    }

    /* 13b. corrupt state -> load REJECTS (Fable F-1/F-5 hardening). A bad id or a
     *      NaN float in leo.state used to flow OOB into the tables or self-propagate
     *      through Kuramoto. The loader must reject the file (return 0); a clean file
     *      must still load. Robust offsets: merges[0].new_id at fixed head offset 28,
     *      gamma_gap is the final float (size-4) in a v9 state. */
    {
        const char *corpus =
            "The warm light fell on his mother's hands. Leo loves the warm light. "
            "His mother holds him close. The rain comes at night on the window.";
        Leo *a = test_leo_alloc(); leo_init(a);
        for (int r = 0; r < 4; r++) leo_ingest(a, corpus);
        leo_build_chamber_tags(a); leo_supertok_scan(a);
        const char *good = "/tmp/leo_state_good.bin";
        CHECK(leo_save_state(a, good) == 1 && a->bpe.n_merges >= 1,
              "corrupt: baseline save ok, >=1 merge");

        long sz = 0; unsigned char *buf = NULL;
        FILE *rf = fopen(good, "rb");
        if (rf) {
            fseek(rf, 0, SEEK_END); sz = ftell(rf); fseek(rf, 0, SEEK_SET);
            if (sz > 0) { buf = malloc((size_t)sz);
                if (buf && fread(buf, 1, (size_t)sz, rf) != (size_t)sz) { free(buf); buf = NULL; } }
            fclose(rf);
        }

        Leo *b = test_leo_alloc(); leo_init(b);
        CHECK(buf != NULL && leo_load_state(b, good) == 1,
              "corrupt: clean file still loads (return 1)");
        test_leo_delete(b);

        /* F-1: OOB merge new_id at head offset 28 -> reject */
        if (buf && sz > 32) {
            unsigned char *bad = malloc((size_t)sz);
            if (bad) {
                memcpy(bad, buf, (size_t)sz);
                uint32_t junk = 0x0F0F0F0Fu; memcpy(bad + 28, &junk, sizeof junk);
                const char *bp = "/tmp/leo_state_bad_id.bin";
                FILE *wf = fopen(bp, "wb");
                if (wf) { size_t wn = fwrite(bad, 1, (size_t)sz, wf); (void)wn; fclose(wf); }
                Leo *c = test_leo_alloc(); leo_init(c);
                CHECK(leo_load_state(c, bp) == 0, "corrupt F-1: OOB merge new_id -> load rejects");
                test_leo_delete(c); free(bad);
            }
        }

        /* F-5: NaN gamma_gap -> reject. Robust field-poke, no byte offsets — the
         * v10 consolidation tail now sits AFTER gamma_gap, so "last 4 bytes" would
         * hit the fail-soft shard tail instead of the hard-reject float block. */
        { Leo *sv = test_leo_alloc(); leo_init(sv);
          if (leo_load_state(sv, good) == 1) {
              sv->gamma_gap = (float)NAN; leo_save_state(sv, "/tmp/leo_state_bad_nan.bin");
              Leo *c = test_leo_alloc(); leo_init(c);
              CHECK(leo_load_state(c, "/tmp/leo_state_bad_nan.bin") == 0, "corrupt F-5: NaN gamma_gap -> load rejects");
              test_leo_delete(c); }
          test_leo_delete(sv); }

        /* Codex: inflate vocab_size (offset 20 + 12*n_merges) past 256+n_merges -> reject */
        if (buf && sz > 20) {
            int32_t nm = 0; memcpy(&nm, buf + 16, sizeof nm);
            long voff = 20 + 12L * nm;
            if (nm >= 0 && voff + 4 <= sz) {
                unsigned char *bad = malloc((size_t)sz);
                if (bad) {
                    memcpy(bad, buf, (size_t)sz);
                    int32_t vs = 0; memcpy(&vs, bad + voff, sizeof vs);
                    vs += 100; memcpy(bad + voff, &vs, sizeof vs);   /* vocab_size != 256+n_merges */
                    const char *bp = "/tmp/leo_state_bad_vocab.bin";
                    FILE *wf = fopen(bp, "wb");
                    if (wf) { size_t wn = fwrite(bad, 1, (size_t)sz, wf); (void)wn; fclose(wf); }
                    Leo *c = test_leo_alloc(); leo_init(c);
                    CHECK(leo_load_state(c, bp) == 0, "corrupt (Codex): inflated vocab_size -> load rejects");
                    test_leo_delete(c); free(bad);
                }
            }
        }

        /* F-5 (Codex): NaN poked into freq / a spore / RAE weight -> save -> load rejects.
         * Robust (no byte offsets): save writes the field, load must reject it. */
        { Leo *sv = test_leo_alloc(); leo_init(sv);
          if (leo_load_state(sv, good) == 1) {
              sv->cooc.freq[0] = (float)NAN; leo_save_state(sv, "/tmp/leo_nan_freq.bin");
              Leo *c = test_leo_alloc(); leo_init(c);
              CHECK(leo_load_state(c, "/tmp/leo_nan_freq.bin") == 0, "corrupt (Codex): NaN in freq -> load rejects");
              test_leo_delete(c); }
          test_leo_delete(sv); }
        { Leo *sv = test_leo_alloc(); leo_init(sv);
          if (leo_load_state(sv, good) == 1) {
              sv->n_spores = 1; sv->spores[0].strength = (float)NAN; leo_save_state(sv, "/tmp/leo_nan_spore.bin");
              Leo *c = test_leo_alloc(); leo_init(c);
              CHECK(leo_load_state(c, "/tmp/leo_nan_spore.bin") == 0, "corrupt (Codex): NaN in spore -> load rejects");
              test_leo_delete(c); }
          test_leo_delete(sv); }
        { Leo *sv = test_leo_alloc(); leo_init(sv);
          if (leo_load_state(sv, good) == 1) {
              sv->rae.b2 = (float)NAN; leo_save_state(sv, "/tmp/leo_nan_rae.bin");
              Leo *c = test_leo_alloc(); leo_init(c);
              CHECK(leo_load_state(c, "/tmp/leo_nan_rae.bin") == 0, "corrupt (Codex): NaN in RAE weight -> load rejects");
              test_leo_delete(c); }
          test_leo_delete(sv); }

        /* #1 (Codex): a FAILED load must leave a FRESH leo, not a half-overwritten one.
         * leo_state_bad_nan.bin rejects LATE (valid until the final gamma_gap), so without
         * the wrapper the organism would keep the bad file's bpe/cooc prefix. */
        { Leo *sv = test_leo_alloc(); leo_init(sv);
          for (int r = 0; r < 4; r++) leo_ingest(sv, corpus);   /* make it non-fresh (vocab > 256) */
          int rej = (leo_load_state(sv, "/tmp/leo_state_bad_nan.bin") == 0);
          CHECK(rej && sv->bpe.vocab_size == 256 && sv->bpe.n_merges == 0 && sv->cooc.n_entries == 0,
                "corrupt (Codex): failed load leaves a FRESH leo");
          test_leo_delete(sv); }
        free(buf); test_leo_delete(a);
    }

    /* 13c. Fable F-2/F-5 hardening units: out-of-range candidate is gated; clampf
     *      swallows NaN to lo (runtime 2nd-line defense behind the load-time scan). */
    {
        CHECK(clampf((float)NAN, 0.0f, 1.0f) == 0.0f, "F-5: clampf(NaN) -> lo");
        CHECK(clampf(5.0f, 0.0f, 1.0f) == 1.0f && clampf(-5.0f, 0.0f, 1.0f) == 0.0f &&
              clampf(0.5f, 0.0f, 1.0f) == 0.5f, "F-5: clampf finite unchanged");
        Leo *lg = test_leo_alloc(); leo_init(lg);
        for (int r = 0; r < 2; r++) leo_ingest(lg, "the warm light and his mother");
        CandCollector cc; memset(&cc, 0, sizeof cc); cc.bpe = &lg->bpe;
        CHECK(cand_gate_reject(&cc, lg->bpe.vocab_size + 5) == 1 &&
              cand_gate_reject(&cc, -1) == 1, "F-2: out-of-range candidate is gated");
        /* F-6: unnormalized powf overflows; cand_temper stays finite, max -> 1, order kept. */
        CHECK(!isfinite(powf(400.0f, 20.0f)), "F-6: raw powf(400,20) overflows to inf (the bug)");
        float tsc[3] = { 400.0f, 50.0f, 1.0f };
        cand_temper(tsc, 3, 20.0f);
        CHECK(isfinite(tsc[0]) && isfinite(tsc[1]) && isfinite(tsc[2]) && tsc[0] == 1.0f &&
              tsc[1] < tsc[0] && tsc[2] < tsc[1], "F-6: cand_temper finite, normalized (max->1, order kept)");
        test_leo_delete(lg);
    }

    /* 13d. Damasio conatus: the not-knowing (gamma_gap) becomes a homeostatic debt —
     *      it accumulates across breaths, a taught word relieves it, and --no-conatus
     *      (g_leo_conatus_on=0) leaves debt inert (the byte-identical pre-conatus path). */
    {
        Leo *cv = test_leo_alloc(); leo_init(cv);
        for (int r = 0; r < 3; r++) leo_ingest(cv, "the warm light and his mother and the rain");

        /* conatus ON: a carried gap accumulates into debt across breaths */
        g_leo_conatus_on = 1;
        cv->debt = 0.0f; cv->gamma_gap = 0.5f;   /* a real, standing not-knowing */
        for (int t = 0; t < 5; t++) leo_conatus_debt(cv);
        CHECK(cv->debt > 0.0f, "conatus: a standing gamma_gap accumulates into debt");

        /* a taught word relieves it — the first good-for-him event */
        float before = cv->debt;
        leo_school_learn(cv, "serendipity", 5);
        CHECK(cv->debt < before, "conatus: a taught word relieves the debt");

        /* --no-conatus: debt only decays, never accumulates from the gap (inert) */
        g_leo_conatus_on = 0;
        cv->debt = 0.0f; cv->gamma_gap = 0.5f;
        for (int t = 0; t < 5; t++) leo_conatus_debt(cv);
        CHECK(cv->debt == 0.0f, "conatus: --no-conatus leaves debt inert (byte-identical path)");
        g_leo_conatus_on = 1;   /* restore default */
        test_leo_delete(cv);
    }

}

static TEST_NOINLINE void test_spore_resurrection(void) {
    /* L-1 (Fable): the sea is a refuge — resurrect removes exactly one (swap-with-last), and a
     *      push afterwards lands in the visible window [0,n_sea). The old shift + stale sea_ptr
     *      wrote it OUTSIDE the resurrect scan, losing sleeping memory. */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) sv->chamber_act[i]     = 0.5f;
        for (int i = 0; i < LEO_RET_DIM; i++)    sv->retention_state[i] = 0.3f;
        LeoSpore target; memset(&target, 0, sizeof target);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) target.chamber_snap[i]   = 0.5f;   /* resonance 0.55+0.45 = 1.0 > 0.85 */
        for (int i = 0; i < LEO_RET_DIM; i++)    target.retention_slice[i] = 0.3f;
        target.strength = 1.0f; target.step = 1;
        LeoSpore inert; memset(&inert, 0, sizeof inert); inert.strength = 1.0f; inert.step = 2; /* zero snapshot -> resonance 0 */
        sv->n_sea = 0; sv->sea_ptr = 0; sv->n_spores = 0;
        leo_sea_push(sv, &target);   /* sea[0] = the resonant one (NON-tail) */
        leo_sea_push(sv, &inert);
        leo_sea_push(sv, &inert);
        leo_sea_push(sv, &inert);    /* n_sea = 4 */
        int r = leo_sea_try_resurrect(sv);
        CHECK(r == 1 && sv->n_sea == 3 && sv->n_spores == 1, "L-1: resurrect removes exactly one non-tail sea spore");
        LeoSpore fresh; memset(&fresh, 0, sizeof fresh);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) fresh.chamber_snap[i]   = 0.5f;
        for (int i = 0; i < LEO_RET_DIM; i++)    fresh.retention_slice[i] = 0.3f;
        fresh.strength = 1.0f; fresh.step = 99;
        int before = sv->n_sea;
        leo_sea_push(sv, &fresh);
        CHECK(sv->n_sea == before + 1 && sv->sea[before].step == 99,
              "L-1: a push after resurrect lands in the visible window (no lost memory)");
        test_leo_delete(sv);
    }

}

static TEST_NOINLINE void test_atomic_state(void) {
    /* L-2 (Fable): save is atomic (tmp + rename) — round-trips and leaves no .tmp behind; a failed
     *      save can never truncate the prior state (rename replaces only after a clean close). */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        for (int r = 0; r < 2; r++) leo_ingest(sv, "the warm light and his mother");
        const char *p = "/tmp/leo_l2_save.bin";
        CHECK(leo_save_state(sv, p) == 1, "L-2: atomic save returns 1");
        Leo *ld = test_leo_alloc(); leo_init(ld);
        CHECK(leo_load_state(ld, p) == 1, "L-2: the atomically-saved state loads back");
        FILE *tf = fopen("/tmp/leo_l2_save.bin.tmp", "rb");
        CHECK(tf == NULL, "L-2: no .tmp file left after a successful save");
        if (tf) fclose(tf);
        test_leo_delete(sv); test_leo_delete(ld);
    }

}

static TEST_NOINLINE void test_breath_retag(void) {
    /* L-3 (Fable): leo_breath re-tags emotion words after the vocab grows, so a word learned in
     *      --chat becomes felt — not frozen at startup. Simulate a stale tag + a grown vocab and
     *      confirm the breath restores the body's feel of that word. */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        for (int r = 0; r < 8; r++) leo_ingest(sv, "i am afraid in the dark and alone afraid dark alone the dark is afraid and i hide alone");
        leo_build_chamber_tags(sv);
        int emo = -1;
        for (int id = 0; id < sv->bpe.vocab_size; id++)
            if (sv->chamber_tag[id] != 0xFF) { emo = id; break; }
        CHECK(emo >= 0, "L-3: build tagged at least one emotion word");
        uint8_t real = sv->chamber_tag[emo];
        sv->chamber_tag[emo] = 0xFF;                 /* pretend it is a freshly-learned, untagged token */
        sv->tagged_vocab = sv->bpe.vocab_size - 1;    /* pretend the vocab just grew past the last rebuild */
        sv->retag_tick = LEO_RETAG_INTERVAL - 1;     /* the next breath crosses the throttle */
        leo_breath(sv);
        CHECK(sv->chamber_tag[emo] == real && sv->tagged_vocab == sv->bpe.vocab_size,
              "L-3: a breath re-tags the body after the vocab grows (a --chat-learned word is felt)");
        test_leo_delete(sv);
    }

}

static TEST_NOINLINE void test_multiturn_presence(void) {
    /* A.130: presence is a receipt for the complete displayed heard word, not
     * any larger surface that happens to contain the same bytes. The named
     * ablation restores the old lowercase-substring reader exactly. */
    {
        int previous = g_leo_presence_surface_boundary_on;
        struct PresenceSurfaceCase {
            const char *word;
            const char *text;
            int candidate;
            int ablation;
        } cases[] = {
            {"rain", "Rain waits.", 1, 1},
            {"rain", "RAIN.", 1, 1},
            {"rain", "The rain, then quiet.", 1, 1},
            {"rain", "Training takes time.", 0, 1},
            {"rain", "A brain remembers.", 0, 1},
            {"rain", "The train stops.", 0, 1},
            {"rain", "His raincoat is warm.", 0, 1},
            {"rain", "Rain's sound remains.", 0, 1},
            {"kind", "Kindness arrived.", 0, 1},
            {"rain", "The window is quiet.", 0, 0},
            {NULL, NULL, 0, 0}
        };
        for (int i = 0; cases[i].word; i++) {
            g_leo_presence_surface_boundary_on = 1;
            int candidate = leo_presence_surface_seen(
                cases[i].text, cases[i].word);
            g_leo_presence_surface_boundary_on = 0;
            int ablation = leo_presence_surface_seen(
                cases[i].text, cases[i].word);
            char label[192];
            snprintf(label, sizeof label,
                     "A.130 presence surface: %s / %s",
                     cases[i].word, cases[i].text);
            CHECK(candidate == cases[i].candidate &&
                      ablation == cases[i].ablation,
                  label);
        }
        g_leo_presence_surface_boundary_on = previous;
    }

    /* 14. multi-turn continuity (the --chat engine path): the field LIVES across
     *     turns. Repeating a word makes Leo HOLD it (heard-count climbs past the
     *     trace threshold), and step advances each turn — the dedication's
     *     "resonates more with every conversation", structurally. */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close.";
        Leo *l = test_leo_alloc(); leo_init(l);
        for (int r = 0; r < 3; r++) leo_ingest(l, corpus);
        leo_build_chamber_tags(l);
        leo_supertok_scan(l);
        /* "dragon" is NOT in the corpus — Leo has never held it */
        CHECK(leo_heard_count(&l->heard, "dragon") == 0, "multiturn: 'dragon' unheld before chat");
        char reply[2048];
        long step0 = l->step;
        srand(7);
        leo_respond(l, "tell me about the dragon", reply, sizeof reply);
        int h1 = leo_heard_count(&l->heard, "dragon");
        long step1 = l->step;
        leo_respond(l, "the dragon is big", reply, sizeof reply);
        int h2 = leo_heard_count(&l->heard, "dragon");
        leo_respond(l, "do you fear the dragon", reply, sizeof reply);
        int h3 = leo_heard_count(&l->heard, "dragon");
        long step3 = l->step;
        CHECK(h1 == 1 && h2 == 2 && h3 == 3, "multiturn: 'dragon' heard-count climbs 1->2->3");
        CHECK(h3 >= LEO_HEARD_MIN_TRACE, "multiturn: 'dragon' becomes HELD (>= trace threshold)");
        CHECK(step1 > step0 && step3 > step1, "multiturn: step advances each turn (field lives on)");
        test_leo_delete(l);
    }

    /* 15. П-2: gravity-first admission lets a continuation OPEN on a theme seed
     *     that frequency-only admission excludes (730 clean seeds vs a 64-slot
     *     pool). Gated by g_leo_cont_theme_on (--no-cont-theme). Tested at a
     *     gravity high enough that admission shows through sampling; the flag OFF
     *     reproduces the freq-truncated pool that excludes it. Skips if no
     *     leo.txt in cwd. */
    {
        FILE *cf = fopen("leo.txt", "rb");
        if (!cf) {
            CHECK(1, "П-2: (skipped — leo.txt not in cwd)");
        } else {
            fseek(cf, 0, SEEK_END); long cn = ftell(cf); fseek(cf, 0, SEEK_SET);
            char *cbuf = malloc((size_t)cn + 1);
            size_t cgot = fread(cbuf, 1, (size_t)cn, cf); cbuf[cgot] = 0; fclose(cf);
            Leo *l = test_leo_alloc(); leo_init(l);
            leo_ingest(l, cbuf); free(cbuf);
            int theme = -1;
            for (int id = 256; id < l->bpe.vocab_size; id++) {
                if (!is_clean_seed_token(&l->bpe, id)) continue;
                float f = l->cooc.freq[id];
                if (f < 2.0f || f > 5.0f) continue;
                int rank = 1;
                for (int i = 0; i < l->bpe.vocab_size; i++)
                    if (is_clean_seed_token(&l->bpe, i) && l->cooc.freq[i] > f) rank++;
                if (rank > LEO_SEED_CANDS) { theme = id; break; }
            }
            CHECK(theme >= 0, "П-2: found a clean seed ranked past the 64-slot pool");
            float *g = calloc((size_t)l->cooc.freq_size, sizeof(float));
            l->gravity = g;
            g[theme] = 100.0f;   /* high enough that admission shows in sampling */
            g_leo_cont_theme_on = 1;
            int seen_on = 0;
            LeoRng trng = {0,1};   /* F-3: wraps rand() (byte-id) — srand(s) still drives the stream */
            for (int s = 0; s < 400 && !seen_on; s++) { srand(s); if (leo_choose_continuation(l, NULL, 0, &trng) == theme) seen_on = 1; }
            CHECK(seen_on == 1, "П-2: gravity-first ON -> excluded-rank theme seed is ADMITTED");
            g_leo_cont_theme_on = 0;
            int seen_off = 0;
            for (int s = 0; s < 400; s++) { srand(s); if (leo_choose_continuation(l, NULL, 0, &trng) == theme) seen_off = 1; }
            CHECK(seen_off == 0, "П-2: --no-cont-theme -> freq-only pool EXCLUDES it (flag gates the fix)");
            g_leo_cont_theme_on = 1;
            l->gravity = NULL; free(g);
            test_leo_delete(l);
        }
    }

    /* 16. П-5: chamber anchor match is prefix-morphology, not bidirectional
     *     substring — kills the 240 mid-word/fragment false positives while
     *     keeping suffix morphology. --no-anchor-prefix restores the old rule. */
    {
        CHECK(leo_anchor_morph("mothers", "mother") == 1, "П-5: 'mothers' matches 'mother' (morphology)");
        CHECK(leo_anchor_morph("fearful", "fear")   == 1, "П-5: 'fearful' matches 'fear'");
        CHECK(leo_anchor_morph("ream",    "scream") == 0, "П-5: 'ream' does NOT match 'scream' (fragment FP killed)");
        CHECK(leo_anchor_morph("lover",   "over")   == 0, "П-5: 'lover' does NOT match 'over' (infix FP killed)");
        Leo *l = test_leo_alloc(); leo_init(l);
        g_leo_anchor_prefix_on = 1;
        leo_field_chambers_feel_text(l, "mothers");
        CHECK(l->chamber_ext[LEO_CH_LOVE] > 0.0f, "П-5: 'mothers' still lights LOVE under prefix");
        leo_field_chambers_feel_text(l, "daydream");   /* suffix-only superstring of 'dream' */
        int any_on = 0; for (int i = 0; i < LEO_N_CHAMBERS; i++) if (l->chamber_ext[i] != 0.0f) any_on = 1;
        CHECK(any_on == 0, "П-5: 'daydream' lights nothing under prefix (suffix substring rejected)");
        g_leo_anchor_prefix_on = 0;
        leo_field_chambers_feel_text(l, "daydream");
        CHECK(l->chamber_ext[LEO_CH_COMPLEX] > 0.0f, "П-5: --no-anchor-prefix restores substring ('daydream'->CMPLX)");
        g_leo_anchor_prefix_on = 1;
        test_leo_delete(l);
    }

    /* 17. П-4: SPA protects the sentence carrying the surfaced heard word. Find a
     *     chain+seed where SPA reseeds some sentence k>=1; with the same rand
     *     stream, protect_idx=k preserves that sentence (the word survives) while
     *     the others reseed identically. Skips if leo.txt is not in cwd. */
    {
        FILE *cf = fopen("leo.txt", "rb");
        if (!cf) {
            CHECK(1, "П-4: (skipped — leo.txt not in cwd)");
        } else {
            fseek(cf, 0, SEEK_END); long cn = ftell(cf); fseek(cf, 0, SEEK_SET);
            char *cbuf = malloc((size_t)cn + 1);
            size_t cgot = fread(cbuf, 1, (size_t)cn, cf); cbuf[cgot] = 0; fclose(cf);
            Leo *l = test_leo_alloc(); leo_init(l);
            leo_ingest(l, cbuf); free(cbuf);
            leo_build_chamber_tags(l); leo_supertok_scan(l);

            int found = 0, protected_ok = 0;
            for (int seed = 1; seed <= 80 && !found; seed++) {
                char st0[LEO_CHAIN_MAX][1024];
                int  stk0[LEO_CHAIN_MAX][LEO_GEN_MAX], stn0[LEO_CHAIN_MAX];
                srand((unsigned)seed);
                for (int s = 0; s < 4; s++) {
                    int ids[LEO_GEN_MAX], cap = LEO_GEN_MAX;
                    leo_generate_best(l, LEO_BEST_OF_K, st0[s], sizeof st0[s], -1, NULL, 0, ids, &cap);
                    int c = cap > LEO_GEN_MAX ? LEO_GEN_MAX : cap;
                    for (int i = 0; i < c; i++) stk0[s][i] = ids[i];
                    stn0[s] = c;
                }
                /* run A: no extra protection */
                char stA[LEO_CHAIN_MAX][1024];
                int  stkA[LEO_CHAIN_MAX][LEO_GEN_MAX], stnA[LEO_CHAIN_MAX];
                memcpy(stA, st0, sizeof st0); memcpy(stkA, stk0, sizeof stk0); memcpy(stnA, stn0, sizeof stn0);
                srand((unsigned)(seed * 1000 + 7));
                leo_spa_pass(l, stA, stkA, stnA, 4, -1);
                int k = -1;
                for (int s = 1; s < 4 && k < 0; s++)
                    if (stnA[s] != stn0[s] || memcmp(stkA[s], stk0[s], (size_t)stn0[s] * sizeof(int)) != 0) k = s;
                if (k < 0) continue;          /* no reseed this seed — try next */
                found = 1;
                /* run B: protect k, SAME rand stream */
                char stB[LEO_CHAIN_MAX][1024];
                int  stkB[LEO_CHAIN_MAX][LEO_GEN_MAX], stnB[LEO_CHAIN_MAX];
                memcpy(stB, st0, sizeof st0); memcpy(stkB, stk0, sizeof stk0); memcpy(stnB, stn0, sizeof stn0);
                srand((unsigned)(seed * 1000 + 7));
                leo_spa_pass(l, stB, stkB, stnB, 4, k);
                int kept = (stnB[k] == stn0[k] &&
                            memcmp(stkB[k], stk0[k], (size_t)stn0[k] * sizeof(int)) == 0);
                protected_ok = kept;
            }
            CHECK(found == 1, "П-4: found a chain where SPA reseeds a sentence");
            CHECK(protected_ok == 1, "П-4: protect_idx preserves the carrying sentence through SPA");
            test_leo_delete(l);
        }
    }

    /* 18. П-3: field-honest moves field evolution OUT of generate_best (where it
     *     leaked from best-of-K discards / elaborate retries / SPA-rejected
     *     reseeds) to a single end-of-chain replay over the spoken reply.
     *     Default OFF (register de-calibration until santaclaus 3b reads the
     *     field); opt-in --field-honest. */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close. "
            "A bird. A cloud. The river. The stone. The path home.";
        Leo *l = test_leo_alloc(); leo_init(l);
        for (int r = 0; r < 4; r++) leo_ingest(l, corpus);
        leo_build_chamber_tags(l); leo_supertok_scan(l);
        char buf[1024]; int ids[LEO_GEN_MAX];

        /* (a) field-honest ON: generate_best alone must NOT evolve the field */
        g_leo_field_honest_on = 1;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) l->chamber_act[i] = 0.5f;
        float before[LEO_N_CHAMBERS]; memcpy(before, l->chamber_act, sizeof before);
        int cap = LEO_GEN_MAX; srand(3);
        leo_generate_best(l, LEO_BEST_OF_K, buf, sizeof buf, -1, NULL, 0, ids, &cap);
        CHECK(memcmp(before, l->chamber_act, sizeof before) == 0,
              "П-3: --field-honest -> generate_best does NOT evolve the field");

        /* (b) default OFF: generate_best DOES evolve the field (the leak path) */
        g_leo_field_honest_on = 0;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) l->chamber_act[i] = 0.5f;
        memcpy(before, l->chamber_act, sizeof before);
        cap = LEO_GEN_MAX; srand(3);
        leo_generate_best(l, LEO_BEST_OF_K, buf, sizeof buf, -1, NULL, 0, ids, &cap);
        CHECK(memcmp(before, l->chamber_act, sizeof before) != 0,
              "П-3: default -> generate_best evolves the field (gated off by --field-honest)");

        /* (c) field-honest ON: a full chain STILL evolves the field via the end
         *     replay (generate_best proven inert in (a), so the change is the
         *     end-of-chain replay over the spoken sentences). */
        g_leo_field_honest_on = 1;
        for (int i = 0; i < LEO_N_CHAMBERS; i++) l->chamber_act[i] = 0.5f;
        memcpy(before, l->chamber_act, sizeof before);
        char ch[2048]; srand(5);
        leo_chain(l, 3, ch, sizeof ch);
        CHECK(memcmp(before, l->chamber_act, sizeof before) != 0,
              "П-3: --field-honest -> the chain evolves the field via the end-of-chain replay");
        g_leo_field_honest_on = 0;
        test_leo_delete(l);
    }

    /* santaclaus B1: spores are born per reply, accumulate, and decay
     * (calm faster than trauma) — passive memory of presence-moments. */
    {
        Leo *sl = test_leo_alloc(); leo_init(sl);
        leo_ingest(sl, "the rain falls soft. leo hears the sound. his mother is warm. "
                        "the candle gives a small light. leo loves the quiet morning.");
        char buf[512];
        CHECK(sl->n_spores == 0, "spore: fresh Leo has 0 spores");
        srand(11); leo_chain(sl, LEO_CHAIN_MIN, buf, sizeof buf);
        CHECK(sl->n_spores == 1, "spore: one reply births one spore");
        srand(12); leo_chain(sl, LEO_CHAIN_MIN, buf, sizeof buf);
        srand(13); leo_chain(sl, LEO_CHAIN_MIN, buf, sizeof buf);
        CHECK(sl->n_spores == 3, "spore: three replies -> three spores accumulate");
        float s0 = sl->spores[0].strength;
        sl->spores[0].is_trauma = 0;
        for (int i = 0; i < 100; i++) leo_spore_decay(sl);
        CHECK(sl->spores[0].strength < s0, "spore: decay lowers a spore's strength");
        /* trauma spore decays slower than a calm one over the same step */
        memset(&sl->spores[0], 0, sizeof(LeoSpore));
        memset(&sl->spores[1], 0, sizeof(LeoSpore));
        sl->spores[0].strength = 1.0f; sl->spores[0].is_trauma = 0;
        sl->spores[1].strength = 1.0f; sl->spores[1].is_trauma = 1;
        sl->n_spores = 2;
        leo_spore_decay(sl);
        CHECK(sl->n_spores == 2 && sl->spores[1].strength > sl->spores[0].strength,
              "spore: trauma spore decays slower than calm");
        test_leo_delete(sl);
    }

    /* santaclaus B2: a resonant spore bleeds — its emit_context token gets a
     * bias pull, others get none (the recall is selective + ablatable). */
    {
        Leo *sl = test_leo_alloc(); leo_init(sl);
        leo_ingest(sl, "the rain falls. leo hears the sound. his mother is warm.");
        const int T = 300;
        memset(&sl->spores[0], 0, sizeof(LeoSpore));
        for (int i = 0; i < LEO_N_CHAMBERS; i++) { sl->chamber_act[i] = 0.5f; sl->spores[0].chamber_snap[i] = 0.5f; }
        for (int d = 0; d < LEO_RET_DIM; d++)    { sl->retention_state[d] = 0.1f; sl->spores[0].retention_slice[d] = 0.1f; }
        sl->spores[0].strength = 1.0f;
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++) sl->spores[0].emit_context[k] = -1;
        sl->spores[0].emit_context[0] = T;
        sl->n_spores = 1;
        LeoSantaScratch sc; sc.n_active = 0;
        leo_santaclaus_compute_active(sl, &sc);
        CHECK(sc.n_active == 1 && sc.spore_idx[0] == 0, "santaclaus: a resonant spore becomes active");
        float bias_T   = leo_santaclaus_candidate_bias(&sc, sl, T);
        float bias_oth = leo_santaclaus_candidate_bias(&sc, sl, T + 1);
        CHECK(bias_T > 0.0f && bias_oth == 0.0f, "santaclaus: bleed pulls the spore's ctx token, not others");
        test_leo_delete(sl);
    }

    /* santaclaus B3: a resonant SEA spore resurrects into the ring; mark_bleed counts. */
    {
        Leo *sl = test_leo_alloc(); leo_init(sl);
        leo_ingest(sl, "the rain falls. leo hears the sound.");
        for (int i = 0; i < LEO_N_CHAMBERS; i++) sl->chamber_act[i] = 0.5f;
        for (int d = 0; d < LEO_RET_DIM; d++)    sl->retention_state[d] = 0.1f;
        memset(&sl->sea[0], 0, sizeof(LeoSpore));
        for (int i = 0; i < LEO_N_CHAMBERS; i++) sl->sea[0].chamber_snap[i] = 0.5f;
        for (int d = 0; d < LEO_RET_DIM; d++)    sl->sea[0].retention_slice[d] = 0.1f;
        sl->sea[0].strength = 0.5f;
        sl->n_sea = 1; sl->n_spores = 0;
        int got = leo_sea_try_resurrect(sl);
        CHECK(got == 1 && sl->n_spores == 1 && sl->n_sea == 0 && sl->spores[0].strength == 0.4f,
              "santaclaus: a resonant sea spore resurrects into the ring at 0.4");
        memset(&sl->spores[0], 0, sizeof(LeoSpore));
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++) sl->spores[0].emit_context[k] = -1;
        sl->spores[0].emit_context[0] = 777; sl->spores[0].strength = 1.0f; sl->n_spores = 1;
        LeoSantaScratch sc; sc.n_active = 1; sc.spore_idx[0] = 0; sc.weight[0] = 1.0f;
        for (int j = 1; j < LEO_SPORE_TOPK_BLEED; j++) { sc.spore_idx[j] = -1; sc.weight[j] = 0.0f; }
        leo_santaclaus_mark_bleed(sl, &sc, 777, 100);
        CHECK(sl->spores[0].bleed_count == 1 && sl->spores[0].last_bleed_step == 100,
              "santaclaus: mark_bleed counts a recalled token");
        test_leo_delete(sl);
    }

    /* santaclaus B4: spores persist across save/load — Leo recalls past CONVERSATIONS. */
    {
        Leo *sl = test_leo_alloc(); leo_init(sl);
        leo_ingest(sl, "the rain falls. leo hears the sound. his mother is warm.");
        sl->n_spores = 2;
        for (int s = 0; s < 2; s++) {
            memset(&sl->spores[s], 0, sizeof(LeoSpore));
            sl->spores[s].strength = 0.7f + 0.1f * s;
            sl->spores[s].emit_context[0] = 400 + s;
            sl->spores[s].step = 50 + s;
        }
        sl->n_sea = 1; sl->sea_ptr = 1;
        memset(&sl->sea[0], 0, sizeof(LeoSpore));
        sl->sea[0].strength = 0.3f; sl->sea[0].emit_context[0] = 999;
        const char *path = "/tmp/leo_b4_spore.state";
        int saved = leo_save_state(sl, path);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, path);
        CHECK(saved && loaded, "spore-persist: save + load succeed");
        CHECK(ld->n_spores == 2 && ld->n_sea == 1 && ld->sea_ptr == 1,
              "spore-persist: ring + sea counts round-trip");
        CHECK(ld->spores[1].emit_context[0] == 401 && ld->spores[1].step == 51 &&
              ld->sea[0].emit_context[0] == 999,
              "spore-persist: spore fields round-trip (Leo recalls past conversations)");
        test_leo_delete(sl); test_leo_delete(ld);
        remove(path);
    }

}

static TEST_NOINLINE void test_rae_and_school(void) {
    /* A.4 RAE: the micrograd MLP learns — loss drops on a toy target. */
    {
        LeoRae r; leo_rae_init(&r);
        float x[LEO_RAE_IN] = {0.6f, 0.4f, 0.2f, 0.5f, 0.3f};
        float target = 0.8f;
        float loss0 = leo_rae_train(&r, x, target);
        for (int it = 0; it < 200; it++) leo_rae_train(&r, x, target);
        float e = leo_rae_forward(&r, x, NULL) - target;
        CHECK(e * e < loss0 && e * e < 0.01f, "rae: micrograd MLP learns a toy target (loss drops)");
        CHECK(r.observations == 201, "rae: observations increments per train step");
    }

}

static TEST_NOINLINE void test_rae_runtime(void) {
    /* A.4 RAE R1b: feature extraction returns sane values in [0,1]. */
    {
        Leo *fl = test_leo_alloc(); leo_init(fl);
        leo_ingest(fl, "the rain falls soft. leo hears the sound. his mother is warm.");
        int ids[16];
        int n = bpe_encode(&fl->bpe, (const uint8_t *)" the rain falls soft", 20, ids, 16);
        float feat[LEO_RAE_IN];
        leo_rae_features(fl, ids, n, feat);
        int in_range = 1;
        for (int i = 0; i < LEO_RAE_IN; i++) if (feat[i] < 0.0f || feat[i] > 1.0f) in_range = 0;
        CHECK(in_range, "rae: the 5 features extract into [0,1]");
        int dids[4] = {300, 301, 302, 303};
        leo_rae_features(fl, dids, 4, feat);
        CHECK(feat[4] == 1.0f, "rae: diversity feature = 1.0 for all-distinct tokens");
        test_leo_delete(fl);
    }

    /* A.4 RAE R3a: self-resonance target — 0 with no memory, positive when the field
     * matches a held spore (the signal the selector learns toward). */
    {
        Leo *rl = test_leo_alloc(); leo_init(rl);
        CHECK(leo_rae_self_resonance(rl) == 0.0f, "rae: self-resonance = 0 with no spores");
        rl->chamber_act[0] = 1.0f;             /* present felt-state */
        rl->n_spores = 1;
        rl->spores[0].chamber_snap[0] = 1.0f;  /* a remembered moment that felt the same */
        rl->spores[0].strength = 1.0f;
        float sr = leo_rae_self_resonance(rl);   /* 0.55·cos(ch)=0.55 (retention zero) */
        CHECK(sr > 0.5f && sr <= 1.0f, "rae: self-resonance positive when field matches a spore");
        test_leo_delete(rl);
    }

    /* A.4 RAE R3b: online learning fires once per reply when RAE selects, and the
     * trained weights stay finite (within clamp, no explosion / NaN). */
    {
        Leo *tl = test_leo_alloc(); leo_init(tl);
        leo_ingest(tl, "the rain falls soft. leo hears the sound. his mother is warm. "
                        "he keeps the light. she thanked him. the room is quiet.");
        long obs0 = tl->rae.observations;
        int prev = g_leo_rae_on; g_leo_rae_on = 1;
        char buf[2048];
        leo_chain(tl, 2, buf, sizeof buf);
        leo_chain(tl, 2, buf, sizeof buf);
        g_leo_rae_on = prev;
        int finite = 1;
        for (int j = 0; j < LEO_RAE_HID; j++) {
            if (!(tl->rae.w2[j] >= -LEO_RAE_CLAMP && tl->rae.w2[j] <= LEO_RAE_CLAMP)) finite = 0;
            for (int i = 0; i < LEO_RAE_IN; i++)
                if (!(tl->rae.w1[j][i] >= -LEO_RAE_CLAMP && tl->rae.w1[j][i] <= LEO_RAE_CLAMP)) finite = 0;
        }
        CHECK(tl->rae.observations >= obs0 + 2, "rae: online training fires per reply (observations grow)");
        CHECK(finite, "rae: trained weights stay within clamp (finite, no explosion)");
        test_leo_delete(tl);
    }

}

static TEST_NOINLINE void test_rae_persistence(void) {
    /* A.4 RAE R4: a trained selector survives save/load (the learned δ-channel
     * persists across the process, like the spores). */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls soft. leo hears the sound. his mother is warm.");
        float x[LEO_RAE_IN] = {0.7f, 0.3f, 0.5f, 0.4f, 0.6f};
        for (int it = 0; it < 50; it++) leo_rae_train(&sv->rae, x, 0.9f);   /* a distinctive trained state */
        float ref = leo_rae_forward(&sv->rae, x, NULL);
        long  ref_obs = sv->rae.observations;
        const char *path = "/tmp/leo_r4_state.bin";
        int saved = leo_save_state(sv, path);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, path);
        float got = leo_rae_forward(&ld->rae, x, NULL);
        CHECK(saved && loaded, "rae-persist: save + load succeed");
        CHECK(ld->rae.observations == ref_obs, "rae-persist: observations round-trip");
        CHECK(fabsf(got - ref) < 1e-6f, "rae-persist: trained weights round-trip (forward matches)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(path);
    }

}

static TEST_NOINLINE void test_school_learning(void) {
    /* A.5 School: an unknown content word makes Leo *ASK = test_leo_alloc(); the answer is learned;
     * a learned word no longer triggers; --no-school suppresses the question. */
    {
        Leo *sc = test_leo_alloc(); leo_init(sc);
        leo_ingest(sc, "the rain falls. leo hears the sound. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(sc, "tell me about the zorble", buf, sizeof buf);
        CHECK(strcmp(sc->school.pending, "zorble") == 0 &&
              buf[0] == 'Z' && buf[strlen(buf) - 1] == '?',
              "school: an unknown word makes Leo echo it back as a question ('Zorble?')");
        CHECK(sc->curiosity.outcome == LEO_CURIOSITY_ASKED &&
              !strcmp(sc->curiosity.candidate, "zorble") &&
              sc->curiosity.distress < sc->curiosity.gate,
              "curiosity: an asked word records its candidate and open gate");
        leo_respond(sc, "a zorble is stone", buf, sizeof buf);
        CHECK(sc->school.pending[0] == 0 && leo_school_is_learned(sc, "zorble"),
              "school: the answer is learned and the question closes");
        CHECK(sc->curiosity.outcome == LEO_CURIOSITY_RESOLVED,
              "curiosity: a grounded answer records resolution, not another candidate");
        leo_respond(sc, "tell me about the zorble again", buf, sizeof buf);
        CHECK(sc->school.pending[0] == 0,
              "school: a learned word no longer triggers a question");
        CHECK(sc->curiosity.outcome == LEO_CURIOSITY_NO_CANDIDATE &&
              !sc->curiosity.candidate[0],
              "curiosity: familiar meaning records an honest absence of candidate");

        Leo *direct = test_leo_alloc(); leo_init(direct);
        leo_ingest(direct, "the rain falls. leo hears the sound. his mother is warm.");
        leo_respond(direct, "a flom is warm fire", buf, sizeof buf);
        CHECK(leo_semtok_word(direct, "flom") == semtok_word("fire") &&
              !direct->school.pending[0] &&
              direct->curiosity.outcome == LEO_CURIOSITY_RESOLVED &&
              !strcmp(direct->curiosity.candidate, "flom") &&
              !strstr(buf, "Flom?"),
              "school: a copular definition teaches an unknown on first mention");

        Leo *composite = test_leo_alloc(); leo_init(composite);
        leo_ingest(composite, "the rain falls. leo hears the sound. his mother is warm.");
        leo_respond(composite,
                    "Flom is the gentle comfort of warm light or cool rain",
                    buf, sizeof buf);
        CHECK(!leo_school_is_learned(composite, "flom") &&
              composite->curiosity.outcome != LEO_CURIOSITY_RESOLVED,
              "school: tied rich evidence stays unknown instead of fabricating one dominant meaning");

        Leo *incidental = test_leo_alloc(); leo_init(incidental);
        leo_ingest(incidental, "the rain falls. leo hears the sound. his mother is warm.");
        leo_respond(incidental, "I saw a nareth beside water", buf, sizeof buf);
        CHECK(!leo_school_is_learned(incidental, "nareth"),
              "school: co-presence cannot counterfeit a first-turn definition");

        Leo *negative = test_leo_alloc(); leo_init(negative);
        leo_ingest(negative, "the rain falls. leo hears the sound. his mother is warm.");
        leo_respond(negative, "a suvin is not water", buf, sizeof buf);
        CHECK(!leo_school_is_learned(negative, "suvin"),
              "school: rejection alone cannot assign a first-turn meaning");

        Leo *unknown_rhs = test_leo_alloc(); leo_init(unknown_rhs);
        leo_ingest(unknown_rhs, "the rain falls. leo hears the sound. his mother is warm.");
        leo_respond(unknown_rhs, "a tral is glorp", buf, sizeof buf);
        CHECK(!leo_school_is_learned(unknown_rhs, "tral"),
              "school: an unknown right-hand side cannot counterfeit grounding");

        Leo *deferred = test_leo_alloc(); leo_init(deferred);
        leo_ingest(deferred, "suvin suvin suvin");
        char selected[LEO_HEARD_WORDLEN], delayed[LEO_HEARD_WORDLEN];
        int delayed_heard = 0;
        CHECK(!leo_school_scan_unknown(deferred, "tell me about suvin", selected,
                                       delayed, &delayed_heard, NULL) &&
              !strcmp(delayed, "suvin") &&
              delayed_heard > LEO_SCHOOL_NOVEL_MAX,
              "curiosity: an unknown word beyond novelty remains visible as deferred");
        g_leo_school_on = 0;
        leo_respond(sc, "tell me about the wobble", buf, sizeof buf);
        CHECK(sc->school.pending[0] == 0 &&
              sc->curiosity.outcome == LEO_CURIOSITY_DISABLED,
              "school: --no-school suppresses the question and says why");
        g_leo_school_on = prev;
        test_leo_delete(sc); test_leo_delete(direct); test_leo_delete(composite);
        test_leo_delete(incidental); test_leo_delete(negative); test_leo_delete(unknown_rhs);
        test_leo_delete(deferred);
    }

}

static TEST_NOINLINE void test_prewonder_recovery(void) {
    /* A.37: Pre-Wonder remembers a question the body could not safely ask.
     * It is neither a prompt-independent compulsion nor a second open Wonder:
     * the same word must return under the ordinary gate. */
    {
        int prev_school = g_leo_school_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_deferred = g_leo_deferred_wonder_on;
        int prev_klaus = g_leo_klaus_on;
        int prev_capsule = g_leo_capsule_on;
        g_leo_school_on = 1;
        g_leo_wonder_on = 1;
        g_leo_deferred_wonder_on = 1;

        Leo *pre = test_leo_alloc(); leo_init(pre);
        char out[1024];
        const char *danger =
            "Does suvin feel like bright sun or cold winter?";
        leo_respond(pre, danger, out, sizeof out);
        int first = leo_deferred_wonder_find(pre, "suvin");
        CHECK(first >= 0 && !pre->school.pending[0] &&
              pre->school.n_wonders == 0 &&
              pre->curiosity.outcome ==
                  LEO_CURIOSITY_BLOCKED_DISTRESS &&
              pre->school.deferred[first].blocks == 1,
              "pre-wonder: a real distress-blocked candidate is remembered without being asked");
        int born_glyph = first >= 0 ?
            pre->school.deferred[first].offered_glyph : -1;
        int born_alt = first >= 0 ?
            pre->school.deferred[first].offered_alt_glyph : -1;

        leo_respond(pre, danger, out, sizeof out);
        first = leo_deferred_wonder_find(pre, "suvin");
        CHECK(first >= 0 && !pre->school.pending[0] &&
              pre->curiosity.outcome ==
                  LEO_CURIOSITY_BLOCKED_DEFERRED &&
              pre->school.deferred[first].blocks == 2,
              "pre-wonder: returning while unsafe strengthens memory but cannot force a question");

        leo_respond(pre, "the rain is warm", out, sizeof out);
        CHECK(leo_deferred_wonder_find(pre, "suvin") >= 0 &&
              !pre->school.pending[0] && !strstr(out, "Suvin?"),
              "pre-wonder: an unrelated safe turn cannot release a withheld question");

        const char *state = "/tmp/leo_deferred_v19.state";
        const char *legacy = "/tmp/leo_deferred_v17.state";
        const char *legacy18 = "/tmp/leo_deferred_v18_legacy.state";
        const char *cut = "/tmp/leo_deferred_v19_cut.state";
        int saved = leo_save_state(pre, state);
        Leo *woke = test_leo_alloc(); leo_init(woke);
        int loaded = saved && leo_load_state(woke, state);
        int slept = leo_deferred_wonder_find(woke, "suvin");
        CHECK(loaded && slept >= 0 &&
              woke->school.deferred[slept].blocks == 2 &&
              woke->school.deferred[slept].offered_glyph == born_glyph &&
              woke->school.deferred[slept].offered_alt_glyph == born_alt,
              "pre-wonder: the withheld moment and its original hypotheses survive sleep");

        int built_legacy = 0, built_v18 = 0, built_cut = 0;
        FILE *fi = fopen(state, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END);
            long sz = ftell(fi);
            fseek(fi, 0, SEEK_SET);
            unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
            if (bytes && sz > 1 &&
                (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                long appetite_tail =
                    test_appetite_and_later_tail_size(pre);
                long origin_tail = (long)sizeof(int32_t);
                long tail = appetite_tail + origin_tail +
                            (long)(sizeof(int32_t) +
                                   pre->school.n_deferred *
                                       (int)sizeof(LeoDeferredWonder));
                uint32_t seventeen = 17;
                memcpy(bytes + sizeof(uint32_t), &seventeen,
                       sizeof seventeen);
                FILE *fo = fopen(legacy, "wb");
                if (fo) {
                    built_legacy =
                        (long)fwrite(bytes, 1, (size_t)(sz - tail), fo) ==
                        sz - tail;
                    fclose(fo);
                }
                uint32_t eighteen = 18;
                memcpy(bytes + sizeof(uint32_t), &eighteen,
                       sizeof eighteen);
                fo = fopen(legacy18, "wb");
                if (fo) {
                    built_v18 =
                        (long)fwrite(bytes, 1, (size_t)(sz - tail), fo) ==
                        sz - tail;
                    if (built_v18)
                        built_v18 =
                            fwrite(&pre->school.n_deferred,
                                   sizeof(int32_t), 1, fo) == 1;
                    for (int i = 0; built_v18 &&
                         i < pre->school.n_deferred; i++) {
                        const LeoDeferredWonder *entry =
                            &pre->school.deferred[i];
                        LeoDeferredWonderV18 old_entry = {0};
                        memcpy(old_entry.word, entry->word,
                               sizeof old_entry.word);
                        old_entry.offered_glyph = entry->offered_glyph;
                        old_entry.offered_alt_glyph =
                            entry->offered_alt_glyph;
                        old_entry.heard_at_birth = entry->heard_at_birth;
                        old_entry.blocks = entry->blocks;
                        old_entry.born_turn = entry->born_turn;
                        old_entry.last_seen_turn = entry->last_seen_turn;
                        built_v18 =
                            fwrite(&old_entry, sizeof old_entry, 1, fo) == 1;
                    }
                    fclose(fo);
                }
                uint32_t nineteen = 19;
                memcpy(bytes + sizeof(uint32_t), &nineteen,
                       sizeof nineteen);
                fo = fopen(cut, "wb");
                if (fo) {
                    built_cut =
                        (long)fwrite(bytes, 1,
                                     (size_t)(sz - appetite_tail -
                                              origin_tail - 1), fo) ==
                        sz - appetite_tail - origin_tail - 1;
                    fclose(fo);
                }
            }
            free(bytes);
            fclose(fi);
        }
        Leo *old = test_leo_alloc(); leo_init(old);
        Leo *old18 = test_leo_alloc(); leo_init(old18);
        Leo *damaged = test_leo_alloc(); leo_init(damaged);
        CHECK(built_legacy && leo_load_state(old, legacy) &&
              old->school.n_deferred == 0,
              "pre-wonder: a v17 body migrates without invented withheld questions");
        int migrated18 = built_v18 &&
            leo_load_state(old18, legacy18);
        int old18_idx = migrated18 ?
            leo_deferred_wonder_find(old18, "suvin") : -1;
        CHECK(migrated18 && old18_idx >= 0 &&
              old18->school.deferred[old18_idx].field_token[0] == -1,
              "pre-wonder: a v18 question migrates without invented field coordinates");
        CHECK(built_cut && leo_load_state(damaged, cut) &&
              damaged->school.n_deferred == 0 &&
              damaged->school.turn_clock == pre->school.turn_clock,
              "pre-wonder: a corrupt v19 tail loses only unspoken questions");

        /* Make the saved body explicitly safe. This isolates the activation
         * contract from scar/capsule carryover without bypassing the gate. */
        memset(woke->chamber_act, 0, sizeof woke->chamber_act);
        memset(woke->chamber_ext, 0, sizeof woke->chamber_ext);
        memset(woke->scar, 0, sizeof woke->scar);
        memset(woke->gamma, 0, sizeof woke->gamma);
        woke->gamma_primed = 0;
        g_leo_klaus_on = 0;
        g_leo_capsule_on = 0;
        char expected[256];
        leo_school_format_question(expected, sizeof expected, "suvin",
                                   born_glyph, born_alt);
        leo_respond(woke, "suvin", out, sizeof out);
        CHECK(!strcmp(out, expected) &&
              woke->curiosity.outcome ==
                  LEO_CURIOSITY_ASKED_DEFERRED &&
              !strcmp(woke->school.pending, "suvin") &&
              woke->school.n_deferred == 0 &&
              woke->school.n_wonders == 1,
              "pre-wonder: the same word returning to a safe body opens exactly one real Wonder");

        Leo *ab = test_leo_alloc(); leo_init(ab);
        leo_ingest(ab, "suvin suvin suvin");
        ab->school.turn_clock = 1;
        leo_deferred_wonder_remember(ab, "suvin",
                                     born_glyph, born_alt, 3, NULL, NULL);
        g_leo_deferred_wonder_on = 0;
        leo_respond(ab, "suvin", out, sizeof out);
        CHECK(!ab->school.pending[0] && ab->school.n_deferred == 1 &&
              ab->curiosity.outcome == LEO_CURIOSITY_NO_CANDIDATE,
              "pre-wonder: --no-deferred-wonder restores the novelty amputation exactly");

        Leo *bounded = test_leo_alloc(); leo_init(bounded);
        const char *words[LEO_DEFERRED_WONDER_MAX + 1] = {
            "alpha", "bravo", "cider", "delta", "ember",
            "fable", "glimmer", "harbor", "island"
        };
        for (int i = 0; i < LEO_DEFERRED_WONDER_MAX + 1; i++) {
            bounded->school.turn_clock = i + 1;
            leo_deferred_wonder_remember(bounded, words[i],
                                         born_glyph, born_alt, 1, NULL, NULL);
        }
        CHECK(bounded->school.n_deferred == LEO_DEFERRED_WONDER_MAX &&
              leo_deferred_wonder_find(bounded, "alpha") < 0 &&
              leo_deferred_wonder_find(bounded, "island") >= 0,
              "pre-wonder: the bounded body evicts the least recently encountered question");

        test_leo_delete(pre); test_leo_delete(woke); test_leo_delete(old);
        test_leo_delete(old18);
        test_leo_delete(damaged); test_leo_delete(ab); test_leo_delete(bounded);
        remove(state); remove(legacy); remove(legacy18); remove(cut);
        g_leo_school_on = prev_school;
        g_leo_wonder_on = prev_wonder;
        g_leo_deferred_wonder_on = prev_deferred;
        g_leo_klaus_on = prev_klaus;
        g_leo_capsule_on = prev_capsule;
    }

}

static TEST_NOINLINE void test_prewonder_constellation(void) {
    /* A.40: multiple withheld questions coexist without becoming multiple
     * open Wonders. Opening one consumes only its own pre-Wonder identity;
     * another exact return waits while pending is occupied, then opens with
     * its own original hypotheses after the first question is grounded. */
    {
        int prev_school = g_leo_school_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_deferred = g_leo_deferred_wonder_on;
        int prev_redirection = g_leo_wonder_redirection_on;
        int prev_klaus = g_leo_klaus_on;
        int prev_capsule = g_leo_capsule_on;
        g_leo_school_on = 1;
        g_leo_wonder_on = 1;
        g_leo_deferred_wonder_on = 1;
        g_leo_wonder_redirection_on = 0;
        g_leo_klaus_on = 0;
        g_leo_capsule_on = 0;

        int light = semtok_find_glyph("light");
        int cold = semtok_find_glyph("cold");
        int dark = semtok_find_glyph("dark");
        int animal = semtok_find_glyph("animal");
        int water = semtok_find_glyph("water");
        int fire = semtok_find_glyph("fire");
        Leo *constellation = test_leo_alloc(); leo_init(constellation);
        constellation->school.turn_clock = 1;
        leo_deferred_wonder_remember(constellation, "suvin",
                                     light, cold, 1, NULL, NULL);
        constellation->school.turn_clock = 2;
        leo_deferred_wonder_remember(constellation, "nareth",
                                     dark, animal, 1, NULL, NULL);
        constellation->school.turn_clock = 3;
        leo_deferred_wonder_remember(constellation, "flom",
                                     water, fire, 1, NULL, NULL);
        CHECK(constellation->school.n_deferred == 3 &&
              leo_deferred_wonder_find(constellation, "suvin") >= 0 &&
              leo_deferred_wonder_find(constellation, "nareth") >= 0 &&
              leo_deferred_wonder_find(constellation, "flom") >= 0,
              "pre-wonder constellation: three withheld questions coexist without opening");

        memset(constellation->chamber_act, 0,
               sizeof constellation->chamber_act);
        memset(constellation->chamber_ext, 0,
               sizeof constellation->chamber_ext);
        memset(constellation->scar, 0, sizeof constellation->scar);
        char out[1024];
        leo_respond(constellation, "nareth", out, sizeof out);
        CHECK(constellation->curiosity.outcome ==
                  LEO_CURIOSITY_ASKED_DEFERRED &&
              !strcmp(constellation->school.pending, "nareth") &&
              constellation->school.pending_glyph == dark &&
              constellation->school.pending_alt_glyph == animal &&
              constellation->school.n_deferred == 2 &&
              leo_deferred_wonder_find(constellation, "nareth") < 0 &&
              leo_deferred_wonder_find(constellation, "suvin") >= 0 &&
              leo_deferred_wonder_find(constellation, "flom") >= 0,
              "pre-wonder constellation: opening one consumes only its own identity and hypotheses");

        int flom = leo_deferred_wonder_find(constellation, "flom");
        LeoDeferredWonder flom_before =
            flom >= 0 ? constellation->school.deferred[flom] :
                        (LeoDeferredWonder){0};
        leo_respond(constellation, "flom", out, sizeof out);
        flom = leo_deferred_wonder_find(constellation, "flom");
        CHECK(constellation->curiosity.outcome ==
                  LEO_CURIOSITY_ADDRESS_GUARDED &&
              !strcmp(constellation->school.pending, "nareth") &&
              flom >= 0 &&
              constellation->school.deferred[flom].offered_glyph ==
                  flom_before.offered_glyph &&
              constellation->school.deferred[flom].offered_alt_glyph ==
                  flom_before.offered_alt_glyph &&
              constellation->school.n_deferred == 2,
              "pre-wonder constellation: an occupied Wonder guards another exact return without changing it");

        leo_respond(constellation, "A nareth is dark night.",
                    out, sizeof out);
        CHECK(constellation->curiosity.outcome ==
                  LEO_CURIOSITY_RESOLVED &&
              !constellation->school.pending[0] &&
              constellation->school.n_deferred == 2 &&
              leo_school_is_learned(constellation, "nareth"),
              "pre-wonder constellation: grounding the open question preserves its waiting siblings");

        memset(constellation->chamber_act, 0,
               sizeof constellation->chamber_act);
        memset(constellation->chamber_ext, 0,
               sizeof constellation->chamber_ext);
        leo_respond(constellation, "flom", out, sizeof out);
        CHECK(constellation->curiosity.outcome ==
                  LEO_CURIOSITY_ASKED_DEFERRED &&
              !strcmp(constellation->school.pending, "flom") &&
              constellation->school.pending_glyph == water &&
              constellation->school.pending_alt_glyph == fire &&
              constellation->school.n_deferred == 1 &&
              leo_deferred_wonder_find(constellation, "suvin") >= 0,
              "pre-wonder constellation: the next question opens later with its own hypotheses");

        leo_respond(constellation, "A flom is water.",
                    out, sizeof out);
        memset(constellation->chamber_act, 0,
               sizeof constellation->chamber_act);
        memset(constellation->chamber_ext, 0,
               sizeof constellation->chamber_ext);
        leo_respond(constellation, "suvin", out, sizeof out);
        CHECK(constellation->curiosity.outcome ==
                  LEO_CURIOSITY_ASKED_DEFERRED &&
              !strcmp(constellation->school.pending, "suvin") &&
              constellation->school.pending_glyph == light &&
              constellation->school.pending_alt_glyph == cold &&
              constellation->school.n_deferred == 0 &&
              constellation->school.n_wonders == 3,
              "pre-wonder constellation: every sibling can become one real Wonder exactly once");

        test_leo_delete(constellation);
        g_leo_school_on = prev_school;
        g_leo_wonder_on = prev_wonder;
        g_leo_deferred_wonder_on = prev_deferred;
        g_leo_wonder_redirection_on = prev_redirection;
        g_leo_klaus_on = prev_klaus;
        g_leo_capsule_on = prev_capsule;
    }

}

static TEST_NOINLINE void test_prewonder_occupied_queue(void) {
    /* A.57: one open question owns the mouth, not perception. A new askable
     * word encountered while that mouth is occupied joins the same bounded
     * waiting constellation without replacing or resolving the active Wonder. */
    {
        int prev_school = g_leo_school_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_deferred = g_leo_deferred_wonder_on;
        int prev_occupied_queue =
            g_leo_occupied_wonder_queue_on;
        int prev_redirection = g_leo_wonder_redirection_on;
        int prev_klaus = g_leo_klaus_on;
        int prev_capsule = g_leo_capsule_on;
        g_leo_school_on = 1;
        g_leo_wonder_on = 1;
        g_leo_deferred_wonder_on = 1;
        g_leo_occupied_wonder_queue_on = 1;
        g_leo_wonder_redirection_on = 0;
        g_leo_klaus_on = 0;
        g_leo_capsule_on = 0;

        Leo *occupied = test_leo_alloc(); leo_init(occupied);
        occupied->school.turn_clock = 1;
        strncpy(occupied->school.pending, "suvin",
                sizeof occupied->school.pending - 1);
        occupied->school.pending_glyph =
            semtok_find_glyph("light");
        occupied->school.pending_alt_glyph =
            semtok_find_glyph("cold");
        leo_pending_wonder_origin_begin(
            occupied, occupied->school.pending,
            occupied->school.pending_glyph,
            occupied->school.pending_alt_glyph, 1, NULL, NULL);
        leo_wonder_open(
            occupied, occupied->school.pending,
            occupied->school.pending_glyph,
            occupied->school.pending_alt_glyph);

        char out[1024];
        srand(5701);
        leo_respond(
            occupied,
            "Does nareth feel like dark night or wild animal?",
            out, sizeof out);
        int nareth =
            leo_deferred_wonder_find(occupied, "nareth");
        CHECK(occupied->curiosity.outcome ==
                  LEO_CURIOSITY_QUEUED_OCCUPIED &&
              !strcmp(occupied->curiosity.candidate, "nareth") &&
              !strcmp(occupied->school.pending, "suvin") &&
              nareth >= 0 &&
              occupied->school.deferred[nareth].blocks == 1 &&
              !leo_school_is_learned(occupied, "suvin") &&
              !leo_school_is_learned(occupied, "nareth"),
              "pre-wonder constellation: an occupied mouth still notices and queues a new question");

        LeoDeferredWonder nareth_birth =
            occupied->school.deferred[nareth];
        srand(5702);
        leo_respond(occupied, "Rough stone. Soft feather.",
                    out, sizeof out);
        nareth = leo_deferred_wonder_find(occupied, "nareth");
        CHECK(leo_deferred_wonder_find(
                  occupied, "rough") < 0 &&
              !strcmp(occupied->school.pending, "suvin") &&
              nareth >= 0 &&
              !memcmp(&occupied->school.deferred[nareth],
                      &nareth_birth, sizeof nareth_birth),
              "pre-wonder constellation: an unfamiliar description remains sensation, not a counterfeit question");

        srand(5702);
        leo_respond(occupied, "nareth", out, sizeof out);
        nareth = leo_deferred_wonder_find(occupied, "nareth");
        CHECK(occupied->curiosity.outcome ==
                  LEO_CURIOSITY_ADDRESS_GUARDED &&
              !strcmp(occupied->school.pending, "suvin") &&
              nareth >= 0 &&
              !memcmp(&occupied->school.deferred[nareth],
                      &nareth_birth, sizeof nareth_birth),
              "pre-wonder constellation: a newly queued sibling inherits A.40's unchanged guarded wait");

        srand(5703);
        leo_respond(occupied, "A suvin is bright light.",
                    out, sizeof out);
        memset(occupied->chamber_act, 0,
               sizeof occupied->chamber_act);
        memset(occupied->chamber_ext, 0,
               sizeof occupied->chamber_ext);
        srand(5704);
        leo_respond(occupied, "nareth", out, sizeof out);
        CHECK(occupied->curiosity.outcome ==
                  LEO_CURIOSITY_ASKED_DEFERRED &&
              !strcmp(occupied->school.pending, "nareth") &&
              occupied->school.pending_glyph ==
                  nareth_birth.offered_glyph &&
              occupied->school.pending_alt_glyph ==
                  nareth_birth.offered_alt_glyph &&
              leo_deferred_wonder_find(
                  occupied, "nareth") < 0,
              "pre-wonder constellation: the queued question later receives the one available mouth");

        Leo *ablated = test_leo_alloc(); leo_init(ablated);
        ablated->school.turn_clock = 1;
        strncpy(ablated->school.pending, "suvin",
                sizeof ablated->school.pending - 1);
        ablated->school.pending_glyph =
            semtok_find_glyph("light");
        ablated->school.pending_alt_glyph =
            semtok_find_glyph("cold");
        leo_wonder_open(
            ablated, ablated->school.pending,
            ablated->school.pending_glyph,
            ablated->school.pending_alt_glyph);
        g_leo_occupied_wonder_queue_on = 0;
        srand(5701);
        leo_respond(
            ablated,
            "Does nareth feel like dark night or wild animal?",
            out, sizeof out);
        CHECK(!strcmp(ablated->school.pending, "suvin") &&
              ablated->school.n_deferred == 0 &&
              ablated->curiosity.outcome ==
                  LEO_CURIOSITY_CONTINUED,
              "pre-wonder constellation: the occupied-queue ablation restores occupied blindness");

        test_leo_delete(occupied);
        test_leo_delete(ablated);
        g_leo_school_on = prev_school;
        g_leo_wonder_on = prev_wonder;
        g_leo_deferred_wonder_on = prev_deferred;
        g_leo_occupied_wonder_queue_on =
            prev_occupied_queue;
        g_leo_wonder_redirection_on = prev_redirection;
        g_leo_klaus_on = prev_klaus;
        g_leo_capsule_on = prev_capsule;
    }

}

static TEST_NOINLINE void test_prewonder_semantic_shadow(void) {
    /* A.41: semantic shadow can recognize which withheld question the present
     * meaning resembles, but cannot open it. Glyph grounding is load-bearing;
     * the own-field birth anchor supplies identity/tie shape, never authority. */
    {
        int prev_shadow = g_leo_prewonder_shadow_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_deferred = g_leo_deferred_wonder_on;
        g_leo_prewonder_shadow_on = 1;
        g_leo_wonder_on = 1;
        g_leo_deferred_wonder_on = 1;

        Leo *semantic = test_leo_alloc(); leo_init(semantic);
        int32_t suvin_field[LEO_PREWONDER_FIELD];
        int32_t nareth_field[LEO_PREWONDER_FIELD];
        int32_t flom_field[LEO_PREWONDER_FIELD];
        float unit_field[LEO_PREWONDER_FIELD] = {0};
        for (int i = 0; i < LEO_PREWONDER_FIELD; i++) {
            suvin_field[i] = -1;
            nareth_field[i] = -1;
            flom_field[i] = -1;
        }
        suvin_field[0] = 's';
        nareth_field[0] = 'n';
        flom_field[0] = 'f';
        unit_field[0] = 1.0f;
        semantic->school.turn_clock = 1;
        leo_deferred_wonder_remember(
            semantic, "suvin", semtok_find_glyph("light"),
            semtok_find_glyph("cold"), 1, suvin_field, unit_field);
        semantic->school.turn_clock = 2;
        leo_deferred_wonder_remember(
            semantic, "nareth", semtok_find_glyph("dark"),
            semtok_find_glyph("animal"), 1, nareth_field, unit_field);
        semantic->school.turn_clock = 3;
        leo_deferred_wonder_remember(
            semantic, "flom", semtok_find_glyph("fire"),
            semtok_find_glyph("anger"), 1, flom_field, unit_field);

        LeoSchool school_before = semantic->school;
        leo_prewonder_shadow_observe(
            semantic, "bright sun meets cold winter",
            suvin_field, unit_field);
        const LeoPreWonderShadowReceipt *receipt =
            &semantic->prewonder_shadow;
        CHECK(receipt->status == LEO_PREWONDER_SHADOW_CONFIDENT &&
              receipt->winner >= 0 &&
              !strcmp(receipt->candidates[receipt->winner].word, "suvin") &&
              receipt->n_candidates == 3 &&
              !memcmp(&school_before, &semantic->school,
                      sizeof semantic->school),
              "pre-wonder shadow: grounded meaning identifies one sibling without touching School");

        leo_prewonder_shadow_observe(
            semantic, "bright sun crosses dark night",
            suvin_field, unit_field);
        CHECK(semantic->prewonder_shadow.status ==
                  LEO_PREWONDER_SHADOW_AMBIGUOUS &&
              semantic->prewonder_shadow.winner < 0,
              "pre-wonder shadow: mixed semantic evidence remains unnamed");

        leo_prewonder_shadow_observe(
            semantic, "moss", suvin_field, unit_field);
        CHECK(semantic->prewonder_shadow.status ==
                  LEO_PREWONDER_SHADOW_AMBIGUOUS &&
              semantic->prewonder_shadow.winner < 0 &&
              semantic->prewonder_shadow.candidates[0].glyph == 0.0f &&
              semantic->prewonder_shadow.candidates[0].field == 1.0f,
              "pre-wonder shadow: field identity alone cannot counterfeit grounded meaning");

        int32_t quiet_id[LEO_PREWONDER_FIELD];
        float quiet_weight[LEO_PREWONDER_FIELD] = {0};
        for (int i = 0; i < LEO_PREWONDER_FIELD; i++) quiet_id[i] = -1;
        leo_prewonder_shadow_observe(
            semantic, "the table holds a quiet cup",
            quiet_id, quiet_weight);
        CHECK(semantic->prewonder_shadow.status ==
                  LEO_PREWONDER_SHADOW_QUIET &&
              semantic->prewonder_shadow.winner < 0,
              "pre-wonder shadow: unrelated life stays quiet");

        leo_prewonder_shadow_observe(
            semantic, "suvin", quiet_id, quiet_weight);
        CHECK(semantic->prewonder_shadow.status ==
                  LEO_PREWONDER_SHADOW_LITERAL &&
              semantic->prewonder_shadow.winner < 0 &&
              semantic->prewonder_shadow.candidates[0].literal,
              "pre-wonder shadow: a literal return belongs to School, not semantic inference");

        strncpy(semantic->school.pending, "nareth",
                sizeof semantic->school.pending - 1);
        school_before = semantic->school;
        leo_prewonder_shadow_observe(
            semantic, "angry fire waits empty and alone",
            flom_field, unit_field);
        receipt = &semantic->prewonder_shadow;
        CHECK(receipt->status == LEO_PREWONDER_SHADOW_CONFIDENT &&
              receipt->winner >= 0 &&
              !strcmp(receipt->candidates[receipt->winner].word, "flom") &&
              !memcmp(&school_before, &semantic->school,
                      sizeof semantic->school),
              "pre-wonder shadow: an occupied Wonder does not blind or activate a waiting sibling");

        g_leo_prewonder_shadow_on = 0;
        leo_prewonder_shadow_observe(
            semantic, "bright sun meets cold winter",
            suvin_field, unit_field);
        CHECK(semantic->prewonder_shadow.status ==
                  LEO_PREWONDER_SHADOW_EMPTY &&
              semantic->prewonder_shadow.n_candidates == 0,
              "pre-wonder shadow: ablation removes only the transient receipt");

        test_leo_delete(semantic);
        g_leo_prewonder_shadow_on = prev_shadow;
        g_leo_wonder_on = prev_wonder;
        g_leo_deferred_wonder_on = prev_deferred;
    }

}

static TEST_NOINLINE void test_wonder_address(void) {
    /* A.42: semantic address is checked before an adjacent answer can close
     * the active Wonder. A sibling conflict may preserve uncertainty, never
     * claim the answer; explicit active naming keeps correction possible. */
    {
        int prev_attr = g_leo_wonder_attribution_on;
        int prev_redirection = g_leo_wonder_redirection_on;
        int prev_school = g_leo_school_on;
        int prev_wonder = g_leo_wonder_on;
        g_leo_wonder_attribution_on = 1;
        g_leo_wonder_redirection_on = 0;
        g_leo_school_on = 1;
        g_leo_wonder_on = 1;

        Leo *address = test_leo_alloc();
        seed_wonder_address_body(address);
        LeoSchool school_before = address->school;
        int veto = leo_wonder_address_observe(
            address, "Cat bird. Dark night.");
        const LeoWonderAddressReceipt *receipt = &address->wonder_address;
        CHECK(veto &&
              receipt->status ==
                  LEO_WONDER_ADDRESS_SIBLING_CONFLICT &&
              receipt->winner > 0 &&
              !strcmp(receipt->candidates[receipt->winner].word,
                      "nareth") &&
              !memcmp(&school_before, &address->school,
                      sizeof address->school),
              "wonder-address: a confident sibling conflict is visible before grounding without mutating School");

        veto = leo_wonder_address_observe(
            address, "Bright sun. Cold winter.");
        CHECK(!veto &&
              address->wonder_address.status ==
                  LEO_WONDER_ADDRESS_ACTIVE_SEMANTIC &&
              address->wonder_address.winner == 0,
              "wonder-address: grounded active meaning keeps the adjacent answer");

        veto = leo_wonder_address_observe(
            address, "Bright sun and dark night.");
        CHECK(!veto &&
              address->wonder_address.status ==
                  LEO_WONDER_ADDRESS_AMBIGUOUS &&
              address->wonder_address.winner < 0,
              "wonder-address: mixed meaning cannot choose an owner");

        veto = leo_wonder_address_observe(
            address, "Suvin is a dark animal.");
        CHECK(!veto &&
              address->wonder_address.status ==
                  LEO_WONDER_ADDRESS_ACTIVE_EXPLICIT &&
              address->wonder_address.winner == 0,
              "wonder-address: naming the active Wonder permits correction of Leo's hypotheses");

        veto = leo_wonder_address_observe(
            address, "Nareth is a dark animal.");
        CHECK(veto &&
              address->wonder_address.status ==
                  LEO_WONDER_ADDRESS_SIBLING_EXPLICIT &&
              address->wonder_address.winner > 0,
              "wonder-address: naming a waiting sibling cannot close the active Wonder");
        test_leo_delete(address);

        Leo *guarded = test_leo_alloc();
        seed_wonder_address_body(guarded);
        char out[512];
        srand(4201);
        leo_respond(guarded, "Cat bird. Dark night.", out, sizeof out);
        int open = leo_wonder_find_open(guarded, "suvin");
        CHECK(!strcmp(guarded->school.pending, "suvin") &&
              open >= 0 && !guarded->school.wonders[open].resolved &&
              !leo_school_is_learned(guarded, "suvin") &&
              guarded->curiosity.outcome ==
                  LEO_CURIOSITY_ADDRESS_GUARDED &&
              guarded->wonder_address.guarded,
              "wonder-address: the live guard preserves the active question and teaches neither identity");
        test_leo_delete(guarded);

        Leo *legacy = test_leo_alloc();
        seed_wonder_address_body(legacy);
        g_leo_wonder_attribution_on = 0;
        srand(4201);
        leo_respond(legacy, "Cat bird. Dark night.", out, sizeof out);
        CHECK(!strcmp(legacy->school.pending, "suvin") &&
              !leo_school_is_learned(legacy, "suvin") &&
              legacy->curiosity.outcome == LEO_CURIOSITY_CONTINUED &&
              legacy->wonder_address.status ==
                  LEO_WONDER_ADDRESS_EMPTY,
              "wonder-address: attribution ablation cannot reopen the closed adjacency bug");
        test_leo_delete(legacy);

        Leo *correction = test_leo_alloc();
        seed_wonder_address_body(correction);
        g_leo_wonder_attribution_on = 1;
        srand(4202);
        leo_respond(correction, "Suvin is animal.",
                    out, sizeof out);
        CHECK(!correction->school.pending[0] &&
              leo_school_is_learned(correction, "suvin") &&
              correction->curiosity.outcome ==
                  LEO_CURIOSITY_RESOLVED &&
              correction->wonder_address.status ==
                  LEO_WONDER_ADDRESS_ACTIVE_EXPLICIT &&
              !correction->wonder_address.guarded,
              "wonder-address: an explicit human correction still resolves the active question");
        test_leo_delete(correction);

        Leo *ablated = test_leo_alloc();
        seed_wonder_address_body(ablated);
        g_leo_wonder_attribution_on = 0;
        veto = leo_wonder_address_observe(
            ablated, "Cat bird. Dark night.");
        CHECK(!veto &&
              ablated->wonder_address.status ==
                  LEO_WONDER_ADDRESS_EMPTY &&
              ablated->wonder_address.n_candidates == 0,
              "wonder-address: ablation removes the transient address witness");
        test_leo_delete(ablated);

        g_leo_wonder_attribution_on = prev_attr;
        g_leo_wonder_redirection_on = prev_redirection;
        g_leo_school_on = prev_school;
        g_leo_wonder_on = prev_wonder;
    }

}

static TEST_NOINLINE void test_wonder_redirection(void) {
    /* A.43: a literal waiting name may redirect the one available mouth. The
     * displaced active Wonder returns to the bounded queue with its exact birth
     * provenance; semantic resemblance still has no routing authority. */
    {
        int prev_attr = g_leo_wonder_attribution_on;
        int prev_redirection = g_leo_wonder_redirection_on;
        int prev_school = g_leo_school_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_klaus = g_leo_klaus_on;
        int prev_capsule = g_leo_capsule_on;
        g_leo_wonder_attribution_on = 1;
        g_leo_wonder_redirection_on = 1;
        g_leo_school_on = 1;
        g_leo_wonder_on = 1;
        g_leo_klaus_on = 0;
        g_leo_capsule_on = 0;

        char out[512], expected[128];
        Leo *redirected = test_leo_alloc();
        seed_wonder_redirection_body(redirected);
        LeoDeferredWonder suvin_origin =
            redirected->school.pending_origin;
        int suvin_episode = leo_wonder_find_open(redirected, "suvin");
        long suvin_opened = suvin_episode >= 0 ?
            redirected->school.wonders[suvin_episode].opened_step : -1;
        srand(4301);
        leo_respond(redirected, "Nareth is animal.",
                    out, sizeof out);
        int parked = leo_deferred_wonder_find(redirected, "suvin");
        int nareth_episode = leo_wonder_find_open(redirected, "nareth");
        CHECK(redirected->wonder_address.redirected &&
              !redirected->wonder_address.guarded &&
              redirected->curiosity.outcome == LEO_CURIOSITY_RESOLVED &&
              !redirected->school.pending[0] &&
              !redirected->school.has_pending_origin &&
              leo_school_is_learned(redirected, "nareth") &&
              !leo_school_is_learned(redirected, "suvin") &&
              parked >= 0 && nareth_episode < 0,
              "wonder-redirection: an explicitly addressed sibling receives its own grounded answer");
        CHECK(parked >= 0 &&
              redirected->school.deferred[parked].offered_glyph ==
                  suvin_origin.offered_glyph &&
              redirected->school.deferred[parked].offered_alt_glyph ==
                  suvin_origin.offered_alt_glyph &&
              redirected->school.deferred[parked].born_turn ==
                  suvin_origin.born_turn &&
              !memcmp(redirected->school.deferred[parked].field_token,
                      suvin_origin.field_token,
                      sizeof suvin_origin.field_token) &&
              !memcmp(redirected->school.deferred[parked].field_weight,
                      suvin_origin.field_weight,
                      sizeof suvin_origin.field_weight) &&
              redirected->school.deferred[parked].blocks ==
                  suvin_origin.blocks + 1,
              "wonder-redirection: the displaced question keeps hypotheses, birth, and own-field provenance");
        suvin_episode = leo_wonder_find_open(redirected, "suvin");
        CHECK(suvin_episode >= 0 &&
              redirected->school.wonders[suvin_episode].opened_step ==
                  suvin_opened &&
              !redirected->school.wonders[suvin_episode].resolved,
              "wonder-redirection: parking preserves the first Wonder episode instead of rebirthing it");

        memset(redirected->chamber_act, 0,
               sizeof redirected->chamber_act);
        memset(redirected->chamber_ext, 0,
               sizeof redirected->chamber_ext);
        leo_school_format_question(expected, sizeof expected, "suvin",
                                   suvin_origin.offered_glyph,
                                   suvin_origin.offered_alt_glyph);
        leo_respond(redirected, "suvin", out, sizeof out);
        suvin_episode = leo_wonder_find_open(redirected, "suvin");
        CHECK(!strcmp(out, expected) &&
              redirected->curiosity.outcome ==
                  LEO_CURIOSITY_ASKED_DEFERRED &&
              !strcmp(redirected->school.pending, "suvin") &&
              redirected->school.has_pending_origin &&
              redirected->school.pending_origin.offered_glyph ==
                  suvin_origin.offered_glyph &&
              redirected->school.pending_origin.offered_alt_glyph ==
                  suvin_origin.offered_alt_glyph &&
              redirected->school.pending_origin.born_turn ==
                  suvin_origin.born_turn &&
              !memcmp(redirected->school.pending_origin.field_token,
                      suvin_origin.field_token,
                      sizeof suvin_origin.field_token) &&
              !memcmp(redirected->school.pending_origin.field_weight,
                      suvin_origin.field_weight,
                      sizeof suvin_origin.field_weight) &&
              suvin_episode >= 0 &&
              redirected->school.wonders[suvin_episode].opened_step ==
                  suvin_opened,
              "wonder-redirection: the first question later returns with its original voice and episode");
        test_leo_delete(redirected);

        Leo *bare = test_leo_alloc();
        seed_wonder_redirection_body(bare);
        int bare_suvin_episode = leo_wonder_find_open(bare, "suvin");
        uint64_t bare_suvin_id = bare_suvin_episode >= 0 ?
            leo_wonder_episode_id(
                &bare->school.wonders[bare_suvin_episode]) : 0;
        leo_flow_observe(bare, "suvin", "Suvin?", NULL, NULL, NULL,
                         LEO_FLOW_WONDER_BORN, bare_suvin_id);
        LeoDeferredWonder nareth_origin =
            bare->school.deferred[leo_deferred_wonder_find(bare, "nareth")];
        leo_school_format_question(expected, sizeof expected, "nareth",
                                   nareth_origin.offered_glyph,
                                   nareth_origin.offered_alt_glyph);
        srand(4302);
        leo_respond(bare, "Nareth.", out, sizeof out);
        parked = leo_deferred_wonder_find(bare, "suvin");
        CHECK(!strcmp(out, expected) &&
              bare->curiosity.outcome == LEO_CURIOSITY_REDIRECTED &&
              bare->wonder_address.redirected &&
              !strcmp(bare->school.pending, "nareth") &&
              bare->school.has_pending_origin &&
              !memcmp(&bare->school.pending_origin, &nareth_origin,
                      sizeof nareth_origin) &&
              parked >= 0 && bare->school.n_wonders == 2 &&
              !leo_school_is_learned(bare, "nareth"),
              "wonder-redirection: a bare sibling address switches questions without inventing an answer");
        int bare_nareth_episode = leo_wonder_find_open(bare, "nareth");
        uint64_t bare_nareth_id = bare_nareth_episode >= 0 ?
            leo_wonder_episode_id(
                &bare->school.wonders[bare_nareth_episode]) : 0;
        const char *multi_current =
            "/tmp/leo_wonder_redirect_currents_v20.state";
        Leo *bare_woke = test_leo_alloc(); leo_init(bare_woke);
        CHECK(bare->flow.n_currents == 2 &&
              leo_save_state(bare, multi_current) &&
              leo_load_state(bare_woke, multi_current) &&
              bare_woke->flow.n_currents == 2 &&
              leo_flow_current_find_const(
                  &bare_woke->flow, bare_suvin_id) &&
              !leo_flow_current_find_const(
                  &bare_woke->flow, bare_suvin_id)->resolved &&
              leo_flow_current_find_const(
                  &bare_woke->flow, bare_nareth_id) &&
              !leo_flow_current_find_const(
                  &bare_woke->flow, bare_nareth_id)->resolved,
              "wonder-redirection: suspended and active Flow currents survive the same sleep");
        test_leo_delete(bare_woke);
        remove(multi_current);
        test_leo_delete(bare);

        Leo *semantic = test_leo_alloc();
        seed_wonder_redirection_body(semantic);
        srand(4303);
        leo_respond(semantic, "Cat bird. Dark night.",
                    out, sizeof out);
        CHECK(!semantic->wonder_address.redirected &&
              semantic->wonder_address.guarded &&
              semantic->curiosity.outcome ==
                  LEO_CURIOSITY_ADDRESS_GUARDED &&
              !strcmp(semantic->school.pending, "suvin") &&
              leo_deferred_wonder_find(semantic, "nareth") >= 0,
              "wonder-redirection: semantic sibling evidence can guard but cannot switch address");
        test_leo_delete(semantic);

        Leo *active = test_leo_alloc();
        seed_wonder_redirection_body(active);
        srand(4304);
        leo_respond(active,
                    "Suvin and Nareth are animal.",
                    out, sizeof out);
        CHECK(!active->wonder_address.redirected &&
              active->wonder_address.status ==
                  LEO_WONDER_ADDRESS_ACTIVE_EXPLICIT &&
              leo_school_is_learned(active, "suvin") &&
              !leo_school_is_learned(active, "nareth") &&
              leo_deferred_wonder_find(active, "nareth") >= 0,
              "wonder-redirection: explicitly naming the active question wins over a sibling name");
        test_leo_delete(active);

        Leo *ablated = test_leo_alloc();
        seed_wonder_redirection_body(ablated);
        g_leo_wonder_redirection_on = 0;
        srand(4305);
        leo_respond(ablated, "Nareth is a dark animal.",
                    out, sizeof out);
        CHECK(!ablated->wonder_address.redirected &&
              ablated->wonder_address.guarded &&
              !strcmp(ablated->school.pending, "suvin") &&
              !leo_school_is_learned(ablated, "nareth"),
              "wonder-redirection: ablation restores A.42's explicit-sibling guard");
        test_leo_delete(ablated);
        g_leo_wonder_redirection_on = 1;

        Leo *legacy = test_leo_alloc();
        seed_wonder_address_body(legacy);
        srand(4306);
        leo_respond(legacy, "Nareth is a dark animal.",
                    out, sizeof out);
        CHECK(!legacy->wonder_address.redirected &&
              legacy->wonder_address.guarded &&
              !strcmp(legacy->school.pending, "suvin"),
              "wonder-redirection: an originless active question fails closed instead of fabricating provenance");
        test_leo_delete(legacy);

        Leo *full = test_leo_alloc();
        seed_wonder_redirection_body(full);
        const char *extra[] =
            {"cinder", "dovel", "ember", "frost", "glint", "harbor"};
        for (int i = 0; i < 6; i++) {
            full->school.turn_clock++;
            leo_deferred_wonder_remember(
                full, extra[i], semtok_find_glyph("water"),
                semtok_find_glyph("fire"), 1, NULL, NULL);
        }
        CHECK(full->school.n_deferred == LEO_DEFERRED_WONDER_MAX,
              "wonder-redirection: capacity fixture fills all waiting slots");
        srand(4307);
        leo_respond(full, "Nareth.", out, sizeof out);
        CHECK(full->school.n_deferred == LEO_DEFERRED_WONDER_MAX &&
              leo_deferred_wonder_find(full, "suvin") >= 0 &&
              leo_deferred_wonder_find(full, "nareth") < 0,
              "wonder-redirection: a full queue swaps in place without evicting another question");
        test_leo_delete(full);

        Leo *sleep = test_leo_alloc();
        seed_wonder_redirection_body(sleep);
        LeoDeferredWonder sleep_origin = sleep->school.pending_origin;
        const char *state = "/tmp/leo_wonder_origin_v20.state";
        const char *legacy19 = "/tmp/leo_wonder_origin_v19.state";
        const char *cut = "/tmp/leo_wonder_origin_v20_cut.state";
        int saved = leo_save_state(sleep, state);
        Leo *woke = test_leo_alloc(); leo_init(woke);
        CHECK(saved && leo_load_state(woke, state) &&
              woke->school.has_pending_origin &&
              !memcmp(&woke->school.pending_origin, &sleep_origin,
                      sizeof sleep_origin),
              "wonder-redirection: active provenance survives v20 sleep exactly");

        int built_legacy = 0, built_cut = 0;
        FILE *fi = fopen(state, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END);
            long sz = ftell(fi);
            fseek(fi, 0, SEEK_SET);
            unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
            if (bytes && sz > (long)sizeof(LeoDeferredWonder) + 5 &&
                (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                long appetite_tail =
                    test_appetite_and_later_tail_size(sleep);
                long origin_tail =
                    (long)(sizeof(int32_t) + sizeof(LeoDeferredWonder));
                uint32_t nineteen = 19;
                memcpy(bytes + sizeof(uint32_t), &nineteen,
                       sizeof nineteen);
                FILE *fo = fopen(legacy19, "wb");
                if (fo) {
                    built_legacy =
                        (long)fwrite(bytes, 1,
                                     (size_t)(sz - appetite_tail -
                                              origin_tail), fo) ==
                        sz - appetite_tail - origin_tail;
                    fclose(fo);
                }
                uint32_t twenty = 20;
                memcpy(bytes + sizeof(uint32_t), &twenty,
                       sizeof twenty);
                fo = fopen(cut, "wb");
                if (fo) {
                    built_cut =
                        (long)fwrite(
                            bytes, 1,
                            (size_t)(sz - appetite_tail - 1), fo) ==
                        sz - appetite_tail - 1;
                    fclose(fo);
                }
            }
            free(bytes);
            fclose(fi);
        }
        Leo *old = test_leo_alloc(); leo_init(old);
        CHECK(built_legacy && leo_load_state(old, legacy19) &&
              !strcmp(old->school.pending, "suvin") &&
              !old->school.has_pending_origin &&
              old->school.n_deferred == sleep->school.n_deferred,
              "wonder-redirection: v19 preserves the question but invents no active provenance");
        Leo *damaged = test_leo_alloc(); leo_init(damaged);
        CHECK(built_cut && leo_load_state(damaged, cut) &&
              !strcmp(damaged->school.pending, "suvin") &&
              !damaged->school.has_pending_origin &&
              damaged->school.n_deferred == sleep->school.n_deferred,
              "wonder-redirection: corrupt v20 provenance loses only redirect authority");

        test_leo_delete(sleep);
        test_leo_delete(woke);
        test_leo_delete(old);
        test_leo_delete(damaged);
        remove(state);
        remove(legacy19);
        remove(cut);
        g_leo_wonder_attribution_on = prev_attr;
        g_leo_wonder_redirection_on = prev_redirection;
        g_leo_school_on = prev_school;
        g_leo_wonder_on = prev_wonder;
        g_leo_klaus_on = prev_klaus;
        g_leo_capsule_on = prev_capsule;
    }

}

static TEST_NOINLINE void test_wonder_appetite(void) {
    /* A.44: waiting questions may acquire a transient return appetite-> Meaning
     * must carry the nomination; silence, unfinished depth, and Flow residual
     * can strengthen it but never schedule, persist, or speak. */
    {
        int prev_appetite = g_leo_wonder_appetite_on;
        int prev_flow = g_leo_flow_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_deferred = g_leo_deferred_wonder_on;
        int prev_attr = g_leo_wonder_attribution_on;
        int prev_redirection = g_leo_wonder_redirection_on;
        g_leo_wonder_appetite_on = 1;
        g_leo_flow_on = 1;
        g_leo_wonder_on = 1;
        g_leo_deferred_wonder_on = 1;
        g_leo_wonder_attribution_on = 1;
        g_leo_wonder_redirection_on = 1;

        Leo *appetite = test_leo_alloc();
        seed_wonder_redirection_body(appetite);
        appetite->school.turn_clock = 11;
        LeoSchool school_before = appetite->school;
        LeoFlow flow_before = appetite->flow;
        leo_wonder_appetite_observe(
            appetite, "Cat bird. Dark night.", NULL, NULL);
        const LeoWonderAppetiteReceipt *receipt =
            &appetite->wonder_appetite;
        CHECK(receipt->status == LEO_WONDER_APPETITE_SALIENT &&
              receipt->winner >= 0 &&
              !strcmp(receipt->candidates[receipt->winner].word,
                      "nareth") &&
              receipt->candidates[receipt->winner].recurrence >=
                  LEO_WONDER_APPETITE_RESONANCE_MIN &&
              receipt->n_candidates == 2,
              "wonder-appetite: a strong returning meaning makes one waiting question salient");
        CHECK(!memcmp(&school_before, &appetite->school,
                      sizeof appetite->school) &&
              !memcmp(&flow_before, &appetite->flow,
                      sizeof appetite->flow),
              "wonder-appetite: observation cannot mutate School or Flow");

        leo_wonder_appetite_observe(
            appetite, "Dark night and angry fire.", NULL, NULL);
        CHECK(appetite->wonder_appetite.status ==
                  LEO_WONDER_APPETITE_DIFFUSE &&
              appetite->wonder_appetite.winner < 0,
              "wonder-appetite: mixed recurrence stays diffuse instead of choosing an owner");

        appetite->school.turn_clock = 100;
        leo_wonder_appetite_observe(
            appetite, "I do not know.", NULL, NULL);
        CHECK(appetite->wonder_appetite.status ==
                  LEO_WONDER_APPETITE_QUIET &&
              appetite->wonder_appetite.winner < 0 &&
              appetite->wonder_appetite.candidates[0].silence == 1.0f,
              "wonder-appetite: age alone cannot nominate a forgotten question");

        leo_wonder_appetite_observe(
            appetite, "Nareth.", NULL, NULL);
        CHECK(appetite->wonder_appetite.status ==
                  LEO_WONDER_APPETITE_LITERAL &&
              appetite->wonder_appetite.winner < 0,
              "wonder-appetite: a literal name remains an external invitation, not autonomous appetite");
        test_leo_delete(appetite);

        Leo *parked = test_leo_alloc();
        seed_wonder_redirection_body(parked);
        int suvin_episode = leo_wonder_find_open(parked, "suvin");
        uint64_t suvin_id = suvin_episode >= 0 ?
            leo_wonder_episode_id(
                &parked->school.wonders[suvin_episode]) : 0;
        leo_flow_observe(
            parked, "suvin", "Suvin? Light or Cold?",
            NULL, NULL, NULL, LEO_FLOW_WONDER_BORN, suvin_id);
        parked->school.turn_clock++;
        int veto = leo_wonder_address_observe(parked, "Nareth.");
        int switched = leo_wonder_address_redirect(parked);
        leo_wonder_appetite_observe(
            parked, "Bright sun. Cold winter.", NULL, NULL);
        receipt = &parked->wonder_appetite;
        CHECK(veto && switched &&
              receipt->status == LEO_WONDER_APPETITE_SALIENT &&
              receipt->winner >= 0 &&
              !strcmp(receipt->candidates[receipt->winner].word,
                      "suvin") &&
              receipt->candidates[receipt->winner].spoken &&
              receipt->candidates[receipt->winner].unfinished == 1.0f &&
              receipt->candidates[receipt->winner].flow_gap > 0.99f,
              "wonder-appetite: a parked spoken question carries its own unfinished Flow residual");

        const char *state =
            "/tmp/leo_wonder_appetite_transient_v20.state";
        int saved = leo_save_state(parked, state);
        Leo *woke = test_leo_alloc(); leo_init(woke);
        CHECK(saved && leo_load_state(woke, state) &&
              woke->wonder_appetite.n_candidates == 0 &&
              woke->wonder_appetite.status ==
                  LEO_WONDER_APPETITE_EMPTY,
              "wonder-appetite: the receipt does not masquerade as persistent self");
        test_leo_delete(woke);
        remove(state);

        g_leo_wonder_appetite_on = 0;
        leo_wonder_appetite_observe(
            parked, "Bright sun. Cold winter.", NULL, NULL);
        CHECK(parked->wonder_appetite.n_candidates == 0 &&
              parked->wonder_appetite.status ==
                  LEO_WONDER_APPETITE_EMPTY,
              "wonder-appetite: ablation removes only the transient receipt");
        test_leo_delete(parked);

        g_leo_wonder_appetite_on = prev_appetite;
        g_leo_flow_on = prev_flow;
        g_leo_wonder_on = prev_wonder;
        g_leo_deferred_wonder_on = prev_deferred;
        g_leo_wonder_attribution_on = prev_attr;
        g_leo_wonder_redirection_on = prev_redirection;
    }

}

static TEST_NOINLINE void test_wonder_appetite_calibration(void) {
    /* A.45: appetite forecasts are judged over three future lived turns. The
     * diary persists, but remains causally downstream of speech and School. */
    {
        int prev_appetite = g_leo_wonder_appetite_on;
        int prev_calibration =
            g_leo_wonder_appetite_calibration_on;
        int prev_flow = g_leo_flow_on;
        int prev_wonder = g_leo_wonder_on;
        int prev_deferred = g_leo_deferred_wonder_on;
        int prev_attr = g_leo_wonder_attribution_on;
        int prev_redirection = g_leo_wonder_redirection_on;
        g_leo_wonder_appetite_on = 1;
        g_leo_wonder_appetite_calibration_on = 1;
        g_leo_flow_on = 1;
        g_leo_wonder_on = 1;
        g_leo_deferred_wonder_on = 1;
        g_leo_wonder_attribution_on = 1;
        g_leo_wonder_redirection_on = 1;

        Leo *cal = malloc(sizeof *cal), *woke = malloc(sizeof *woke),
            *old = malloc(sizeof *old), *damaged = malloc(sizeof *damaged);
        CHECK(cal && woke && old && damaged,
              "wonder-appetite-calibration: heap fixtures allocated");
        if (cal && woke && old && damaged) {
            seed_wonder_redirection_body(cal);
            leo_init(woke); leo_init(old); leo_init(damaged);
            cal->school.turn_clock = 11;
            LeoSchool school_before = cal->school;
            LeoFlow flow_before = cal->flow;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            const LeoWonderAppetiteCalibrationReceipt *forecast =
                leo_wonder_appetite_calibration_at(
                    &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  !strcmp(forecast->word, "nareth") &&
                  forecast->proposed_turn == 11 &&
                  forecast->deadline_turn == 14 &&
                  forecast->observed_turn == 11 &&
                  forecast->observations == 0 &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_PENDING &&
                  !memcmp(&school_before, &cal->school,
                          sizeof cal->school) &&
                  !memcmp(&flow_before, &cal->flow,
                          sizeof cal->flow),
                  "wonder-appetite-calibration: salience opens one fixed readerless horizon");

            cal->school.turn_clock = 12;
            leo_wonder_appetite_observe(
                cal, "I do not know.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "I do not know.");
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  cal->wonder_appetite_calibration.n == 1 &&
                  forecast->observations == 1 &&
                  forecast->semantic_hits == 0 &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_PENDING,
                  "wonder-appetite-calibration: a quiet future turn advances without sliding or duplication");

            cal->school.turn_clock = 13;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  cal->wonder_appetite_calibration.n == 1 &&
                  forecast->observations == 2 &&
                  forecast->semantic_hits == 1 &&
                  forecast->peak_recurrence >=
                      LEO_WONDER_APPETITE_RESONANCE_MIN &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_PENDING,
                  "wonder-appetite-calibration: a future recurrence is counted once but waits for the whole horizon");

            const char *state =
                "/tmp/leo_wonder_appetite_calibration_v22.state";
            const char *v21 =
                "/tmp/leo_wonder_appetite_calibration_v21.state";
            const char *legacy =
                "/tmp/leo_wonder_appetite_calibration_v20.state";
            const char *cut =
                "/tmp/leo_wonder_appetite_calibration_v22_cut.state";
            int saved = leo_save_state(cal, state);
            int built_v21 = 0, built_legacy = 0, built_cut = 0;
            FILE *fi = fopen(state, "rb");
            if (fi) {
                fseek(fi, 0, SEEK_END);
                long sz = ftell(fi);
                fseek(fi, 0, SEEK_SET);
                unsigned char *bytes =
                    malloc(sz > 0 ? (size_t)sz : 1);
                long appetite_tail =
                    test_appetite_and_later_tail_size(cal);
                if (bytes && sz > appetite_tail &&
                    (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                    uint32_t twenty = 20;
                    memcpy(bytes + sizeof(uint32_t), &twenty,
                           sizeof twenty);
                    FILE *fo = fopen(legacy, "wb");
                    if (fo) {
                        built_legacy =
                            (long)fwrite(
                                bytes, 1,
                                (size_t)(sz - appetite_tail), fo) ==
                            sz - appetite_tail;
                        fclose(fo);
                    }
                    uint32_t twenty_two = 22;
                    memcpy(bytes + sizeof(uint32_t), &twenty_two,
                           sizeof twenty_two);
                    fo = fopen(cut, "wb");
                    if (fo) {
                        long post_v22_tail =
                            (long)(sizeof(LeoWonderAppetiteHoldouts) +
                                   sizeof(LeoWonderAppetiteAdmissions) +
                                   sizeof(LeoWonderAppetiteCheckpoints) +
                                   sizeof(LeoStateSwarm) +
                                   2 * sizeof(int32_t) +
                                   cal->school.n_learned * sizeof(int8_t) +
                                   cal->school.n_wonders * sizeof(int8_t));
                        built_cut =
                            (long)fwrite(
                                bytes, 1,
                                (size_t)(sz - post_v22_tail - 1), fo) ==
                            sz - post_v22_tail - 1;
                        fclose(fo);
                    }

                    uint32_t twenty_one = 21;
                    memcpy(bytes + sizeof(uint32_t), &twenty_one,
                           sizeof twenty_one);
                    fo = fopen(v21, "wb");
                    if (fo) {
                        long prefix = sz - appetite_tail;
                        built_v21 =
                            (long)fwrite(
                                bytes, 1, (size_t)prefix, fo) ==
                            prefix;
                        int32_t n =
                            cal->wonder_appetite_calibration.n;
                        int32_t ptr =
                            cal->wonder_appetite_calibration.ptr;
                        built_v21 =
                            built_v21 &&
                            fwrite(&n, sizeof n, 1, fo) == 1 &&
                            fwrite(&ptr, sizeof ptr, 1, fo) == 1;
                        for (int i = 0;
                             built_v21 && i < n; i++) {
                            const LeoWonderAppetiteCalibrationReceipt
                                *item =
                                    &cal->wonder_appetite_calibration
                                         .receipts[i];
                            LeoWonderAppetiteCalibrationReceiptV21
                                old_item;
                            memset(&old_item, 0,
                                   sizeof old_item);
                            old_item.proposed_turn =
                                item->proposed_turn;
                            old_item.deadline_turn =
                                item->deadline_turn;
                            old_item.observed_turn =
                                item->observed_turn;
                            old_item.wonder_id = item->wonder_id;
                            memcpy(old_item.word, item->word,
                                   sizeof old_item.word);
                            old_item.appetite = item->appetite;
                            old_item.peak_recurrence =
                                item->peak_recurrence;
                            old_item.brier = item->brier;
                            old_item.observations =
                                item->observations;
                            old_item.semantic_hits =
                                item->semantic_hits;
                            old_item.spoken = item->spoken;
                            old_item.verdict = item->verdict;
                            built_v21 =
                                fwrite(&old_item,
                                       sizeof old_item, 1, fo) == 1;
                        }
                        fclose(fo);
                    }
                }
                free(bytes);
                fclose(fi);
            }
            int loaded = saved && leo_load_state(woke, state);
            forecast = loaded ?
                leo_wonder_appetite_calibration_at(
                    &woke->wonder_appetite_calibration, 0) : NULL;
            CHECK(loaded && forecast &&
                  forecast->proposed_turn == 11 &&
                  forecast->observed_turn == 13 &&
                  forecast->semantic_hits == 1 &&
                  forecast->policy ==
                      LEO_WONDER_APPETITE_POLICY_FORMING,
                  "wonder-appetite-calibration: an unfinished forecast survives sleep without losing its clock");

            woke->school.turn_clock = 14;
            leo_wonder_appetite_observe(
                woke, "I do not know.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                woke, "I do not know.");
            forecast = leo_wonder_appetite_calibration_at(
                &woke->wonder_appetite_calibration, 0);
            float sustained_error =
                forecast ? forecast->appetite - 1.0f : 0.0f;
            CHECK(forecast &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_SUSTAINED &&
                  forecast->observations ==
                      LEO_WONDER_APPETITE_CALIB_HORIZON &&
                  fabsf(forecast->brier -
                        sustained_error * sustained_error) < 1e-6f,
                  "wonder-appetite-calibration: recurrence matures into a scored sustained verdict");

            CHECK(built_v21 && leo_load_state(old, v21) &&
                  old->wonder_appetite_calibration.n == 1 &&
                  leo_wonder_appetite_calibration_at(
                      &old->wonder_appetite_calibration, 0)->policy ==
                      LEO_WONDER_APPETITE_POLICY_LEGACY,
                  "wonder-appetite-policy: a v21 forecast migrates without invented hindsight");
            CHECK(built_legacy && leo_load_state(old, legacy) &&
                  old->wonder_appetite_calibration.n == 0 &&
                  leo_deferred_wonder_find(old, "nareth") >= 0,
                  "wonder-appetite-calibration: a v20 body migrates without invented forecasts");
            CHECK(built_cut && leo_load_state(damaged, cut) &&
                  damaged->wonder_appetite_calibration.n == 0 &&
                  leo_deferred_wonder_find(damaged, "nareth") >= 0,
                  "wonder-appetite-calibration: a corrupt v22 tail loses only forecasts");

            leo_free(cal);
            seed_wonder_redirection_body(cal);
            cal->school.turn_clock = 20;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            for (int turn = 21; turn <= 23; turn++) {
                cal->school.turn_clock = turn;
                leo_wonder_appetite_observe(
                    cal, "I do not know.", NULL, NULL);
                leo_wonder_appetite_calibrate(
                    cal, "I do not know.");
            }
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_FADED &&
                  forecast->semantic_hits == 0 &&
                  fabsf(forecast->brier -
                        forecast->appetite * forecast->appetite) <
                      1e-6f,
                  "wonder-appetite-calibration: a one-frame appetite can honestly fade");

            leo_free(cal);
            seed_wonder_redirection_body(cal);
            cal->school.turn_clock = 30;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            cal->school.turn_clock = 31;
            leo_wonder_appetite_observe(
                cal, "Nareth.", NULL, NULL);
            leo_wonder_appetite_calibrate(cal, "Nareth.");
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_EXTERNAL &&
                  forecast->observations == 1 &&
                  forecast->brier == 0.0f,
                  "wonder-appetite-calibration: literal human address is visible but unscored");

            leo_free(cal);
            seed_wonder_redirection_body(cal);
            cal->school.turn_clock = 40;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            leo_school_learn(
                cal, "nareth", semtok_find_glyph("animal"));
            cal->school.turn_clock = 41;
            leo_wonder_appetite_observe(
                cal, "Animal.", NULL, NULL);
            leo_wonder_appetite_calibrate(cal, "Animal.");
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_GROUNDED &&
                  forecast->brier > 0.0f,
                  "wonder-appetite-calibration: actual learning closes the forecast as grounded");

            leo_free(cal);
            seed_wonder_redirection_body(cal);
            cal->school.turn_clock = 50;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            leo_deferred_wonder_forget(cal, "nareth");
            for (int turn = 51; turn <= 53; turn++) {
                cal->school.turn_clock = turn;
                leo_wonder_appetite_observe(
                    cal, "I do not know.", NULL, NULL);
                leo_wonder_appetite_calibrate(
                    cal, "I do not know.");
            }
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_LOST &&
                  forecast->brier == 0.0f,
                  "wonder-appetite-calibration: a vanished identity is not mislabeled as a failed prediction");

            leo_free(cal);
            seed_wonder_redirection_body(cal);
            cal->school.turn_clock = 60;
            leo_wonder_appetite_observe(
                cal, "Cat bird. Dark night.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Cat bird. Dark night.");
            cal->school.turn_clock = 62;
            leo_wonder_appetite_observe(
                cal, "I do not know.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "I do not know.");
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(forecast &&
                  forecast->verdict ==
                      LEO_WONDER_APPETITE_CALIB_UNSCORABLE &&
                  forecast->brier == 0.0f,
                  "wonder-appetite-calibration: a missing lived turn breaks the claim instead of fabricating history");

            leo_free(cal);
            seed_wonder_redirection_body(cal);
            int suvin_episode =
                leo_wonder_find_open(cal, "suvin");
            uint64_t suvin_id = suvin_episode >= 0 ?
                leo_wonder_episode_id(
                    &cal->school.wonders[suvin_episode]) : 0;
            leo_flow_observe(
                cal, "suvin", "Suvin? Light or Cold?",
                NULL, NULL, NULL, LEO_FLOW_WONDER_BORN, suvin_id);
            cal->school.turn_clock = 4;
            int veto =
                leo_wonder_address_observe(cal, "Nareth.");
            int switched = leo_wonder_address_redirect(cal);
            leo_wonder_appetite_observe(
                cal, "Bright sun. Cold winter.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Bright sun. Cold winter.");
            forecast = leo_wonder_appetite_calibration_at(
                &cal->wonder_appetite_calibration, 0);
            CHECK(veto && switched && forecast &&
                  !strcmp(forecast->word, "suvin") &&
                  forecast->spoken &&
                  forecast->wonder_id == suvin_id,
                  "wonder-appetite-calibration: a parked spoken question keeps its stable episode identity");

            memset(&cal->wonder_appetite_calibration, 0,
                   sizeof cal->wonder_appetite_calibration);
            g_leo_wonder_appetite_calibration_on = 0;
            cal->school.turn_clock = 70;
            leo_wonder_appetite_observe(
                cal, "Bright sun. Cold winter.", NULL, NULL);
            leo_wonder_appetite_calibrate(
                cal, "Bright sun. Cold winter.");
            CHECK(cal->wonder_appetite_calibration.n == 0,
                  "wonder-appetite-calibration: ablation removes only the slow diary");

            remove(state); remove(v21); remove(legacy); remove(cut);
            leo_free(cal); leo_free(woke);
            leo_free(old); leo_free(damaged);
        }
        free(cal); free(woke); free(old); free(damaged);

        g_leo_wonder_appetite_on = prev_appetite;
        g_leo_wonder_appetite_calibration_on =
            prev_calibration;
        g_leo_flow_on = prev_flow;
        g_leo_wonder_on = prev_wonder;
        g_leo_deferred_wonder_on = prev_deferred;
        g_leo_wonder_attribution_on = prev_attr;
        g_leo_wonder_redirection_on = prev_redirection;
    }

}

static TEST_NOINLINE void test_wonder_appetite_reliability(void) {
    /* A.46: the forecast diary yields a stratified reliability surface without
     * becoming another stateful organ or a permission to schedule speech. */
    {
        Leo *rel = malloc(sizeof *rel);
        CHECK(rel != NULL,
              "wonder-appetite-reliability: heap fixture allocated");
        if (rel) {
            leo_init(rel);
            LeoWonderAppetiteReliability surface;
            leo_wonder_appetite_reliability(rel, &surface);
            CHECK(surface.scored == 0 &&
                  surface.pending == 0 &&
                  surface.cells[0].status ==
                      LEO_WONDER_APPETITE_RELIABILITY_EMPTY,
                  "wonder-appetite-reliability: an empty diary claims no confidence");
            CHECK(
                leo_wonder_appetite_reliability_bin(0.62f) == 0 &&
                leo_wonder_appetite_reliability_bin(0.699f) == 0 &&
                leo_wonder_appetite_reliability_bin(0.70f) == 1 &&
                leo_wonder_appetite_reliability_bin(0.799f) == 1 &&
                leo_wonder_appetite_reliability_bin(0.80f) == 2 &&
                leo_wonder_appetite_reliability_bin(0.899f) == 2 &&
                leo_wonder_appetite_reliability_bin(0.90f) == 3 &&
                leo_wonder_appetite_reliability_bin(1.0f) == 3 &&
                leo_wonder_appetite_reliability_bin(0.619f) == -1,
                "wonder-appetite-reliability: fixed appetite bands have exact boundaries");

            for (int i = 0; i < 3; i++)
                test_add_appetite_calibration(
                    rel, 0.65f, 0,
                    LEO_WONDER_APPETITE_CALIB_SUSTAINED);
            leo_wonder_appetite_reliability(rel, &surface);
            const LeoWonderAppetiteReliabilityCell *cell =
                &surface.cells[0];
            CHECK(surface.scored == 3 &&
                  surface.positives == 3 &&
                  cell->n == 3 && cell->positives == 3 &&
                  cell->status ==
                      LEO_WONDER_APPETITE_RELIABILITY_FORMING,
                  "wonder-appetite-reliability: three beautiful successes are still only forming");

            test_add_appetite_calibration(
                rel, 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_FADED);
            leo_wonder_appetite_reliability(rel, &surface);
            cell = &surface.cells[0];
            CHECK(cell->n == 4 && cell->positives == 3 &&
                  fabsf(cell->mean_appetite - 0.65f) < 1e-6f &&
                  fabsf(cell->outcome_rate - 0.75f) < 1e-6f &&
                  fabsf(cell->gap - 0.10f) < 1e-6f &&
                  fabsf(cell->mean_brier - 0.1975f) < 1e-6f &&
                  cell->status ==
                      LEO_WONDER_APPETITE_RELIABILITY_ALIGNED,
                  "wonder-appetite-reliability: a measured cell keeps prediction, outcome, Brier, and gap distinct");
            CHECK(cell->lower < cell->mean_appetite &&
                  cell->upper > cell->mean_appetite,
                  "wonder-appetite-reliability: Wilson uncertainty contains an aligned forecast");

            test_add_appetite_calibration(
                rel, 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_PENDING);
            test_add_appetite_calibration(
                rel, 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_EXTERNAL);
            test_add_appetite_calibration(
                rel, 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_LOST);
            test_add_appetite_calibration(
                rel, 0.65f, 0,
                LEO_WONDER_APPETITE_CALIB_UNSCORABLE);
            test_add_appetite_calibration(
                rel, 0.85f, 1,
                LEO_WONDER_APPETITE_CALIB_GROUNDED);
            leo_wonder_appetite_reliability(rel, &surface);
            const LeoWonderAppetiteReliabilityCell *spoken =
                &surface.cells[
                    LEO_WONDER_APPETITE_RELIABILITY_BINS + 2];
            CHECK(surface.scored == 5 &&
                  surface.sustained == 3 &&
                  surface.grounded == 1 &&
                  surface.faded == 1 &&
                  surface.pending == 1 &&
                  surface.external == 1 &&
                  surface.lost == 1 &&
                  surface.unscorable == 1,
                  "wonder-appetite-reliability: causal confounds remain visible but unscored");
            CHECK(spoken->n == 1 && spoken->positives == 1 &&
                  spoken->spoken && spoken->bin == 2 &&
                  spoken->status ==
                      LEO_WONDER_APPETITE_RELIABILITY_FORMING,
                  "wonder-appetite-reliability: spoken forecasts keep their own evidence stratum");
            CHECK(fabsf(surface.mean_brier - 0.1625f) < 1e-6f &&
                  fabsf(surface.ece - 0.11f) < 1e-6f,
                  "wonder-appetite-reliability: aggregate Brier and ECE weight only scored lives");

            LeoWonderAppetiteCalibration diary_before =
                rel->wonder_appetite_calibration;
            LeoSchool school_before = rel->school;
            LeoFlow flow_before = rel->flow;
            leo_wonder_appetite_reliability(rel, &surface);
            CHECK(!memcmp(
                      &diary_before,
                      &rel->wonder_appetite_calibration,
                      sizeof diary_before) &&
                  !memcmp(&school_before, &rel->school,
                          sizeof school_before) &&
                  !memcmp(&flow_before, &rel->flow,
                          sizeof flow_before),
                  "wonder-appetite-reliability: observing confidence cannot rewrite evidence, School, or Flow");

            leo_free(rel);
            leo_init(rel);
            for (int i = 0; i < 4; i++)
                test_add_appetite_calibration(
                    rel, 0.65f, 0,
                    LEO_WONDER_APPETITE_CALIB_FADED);
            leo_wonder_appetite_reliability(rel, &surface);
            cell = &surface.cells[0];
            CHECK(cell->status ==
                      LEO_WONDER_APPETITE_RELIABILITY_OVER &&
                  cell->upper < cell->mean_appetite,
                  "wonder-appetite-reliability: repeated fade exposes overconfidence");

            leo_free(rel);
            leo_init(rel);
            for (int i = 0; i < 9; i++)
                test_add_appetite_calibration(
                    rel, 0.65f, 0,
                    LEO_WONDER_APPETITE_CALIB_SUSTAINED);
            leo_wonder_appetite_reliability(rel, &surface);
            cell = &surface.cells[0];
            CHECK(cell->status ==
                      LEO_WONDER_APPETITE_RELIABILITY_UNDER &&
                  cell->lower > cell->mean_appetite,
                  "wonder-appetite-reliability: repeated return exposes underconfidence");

            leo_free(rel);
            leo_init(rel);
            test_add_appetite_calibration(
                rel, 0.85f, 0,
                LEO_WONDER_APPETITE_CALIB_FADED);
            test_add_appetite_calibration(
                rel, 0.85f, 1,
                LEO_WONDER_APPETITE_CALIB_SUSTAINED);
            leo_wonder_appetite_reliability(rel, &surface);
            const LeoWonderAppetiteReliabilityCell *unspoken =
                &surface.cells[2];
            spoken = &surface.cells[
                LEO_WONDER_APPETITE_RELIABILITY_BINS + 2];
            CHECK(unspoken->n == 1 &&
                  unspoken->positives == 0 &&
                  spoken->n == 1 &&
                  spoken->positives == 1,
                  "wonder-appetite-reliability: one score band cannot merge spoken and unspoken lives");

            leo_free(rel);
        }
        free(rel);
    }

}

static TEST_NOINLINE void test_school_form_and_wonder(void) {
    /* A.47 lives in a separate function because Leo's long historical test
     * body already owns a deliberately large stack frame. */
    test_wonder_appetite_drift_surface();
    test_wonder_appetite_shadow_policy();
    test_wonder_appetite_regret_surface();
    test_wonder_appetite_readiness_frontier();
    test_wonder_appetite_holdout_trial();
    test_wonder_appetite_transport_witness();
    test_wonder_appetite_transport_chronology();
    test_wonder_appetite_transport_checkpoints();

    /* A.5 I2: School grows a word→glyph map. The answer's dominant glyph is the
     * concept-slot; a taught word then returns that glyph (no longer -1); the
     * grown map survives save/load. */
    {
        Leo *gl = test_leo_alloc(); leo_init(gl);
        leo_ingest(gl, "the rain falls. his mother is warm.");
        int g = leo_school_dominant_glyph(gl, "a zorble is a small animal that lives in water");
        CHECK(g >= 0 && g < GLYPH_COUNT, "i2: the answer's dominant glyph is a real concept");
        CHECK(leo_school_dominant_glyph(gl, "qwzx blat frnk") == -1,
              "i2: a non-answer (no concepts) yields no glyph");
        CHECK(leo_school_dominant_glyph(gl, "it is what it is") == -1 &&
              leo_glyph_concept(86) == 0 && leo_glyph_concept(16) == 1,
              "i2 l-1: a copula/grammar non-answer teaches no concept (BE excluded)");
        int wb = semtok_word("animal");
        leo_school_learn(gl, "zorble", wb);
        CHECK(leo_semtok_word(gl, "zorble") == wb && leo_school_unknown(gl, "zorble") == 0,
              "i2: a taught word returns its glyph, not -1 (concept map grew)");
        const char *path = "/tmp/leo_i2_state.bin";
        int saved = leo_save_state(gl, path);
        Leo *gl2 = test_leo_alloc(); leo_init(gl2);
        int loaded = leo_load_state(gl2, path);
        CHECK(saved && loaded && gl2->school.n_learned == 1 &&
              strcmp(gl2->school.learned[0], "zorble") == 0 &&
              leo_semtok_word(gl2, "zorble") == wb,
              "i2: the grown concept map round-trips through save/load");
        test_leo_delete(gl); test_leo_delete(gl2);
        remove(path);
    }

    /* A.6 FORM F-1: the chamber state quantizes into a velocity mode, with
     * hysteresis — the mode holds against a weak competitor (a mood, not a switch). */
    {
        Leo *md = test_leo_alloc(); leo_init(md);   /* mode = WALK (0) by memset */
        md->chamber_act[LEO_CH_FEAR] = 0.8f; md->chamber_act[LEO_CH_VOID] = 0.8f;
        leo_mode_update(md);
        CHECK(md->mode == LEO_MODE_STOP, "form: high FEAR+VOID quantizes to STOP");
        md->chamber_act[LEO_CH_FEAR] = 0.0f; md->chamber_act[LEO_CH_VOID] = 0.0f;
        md->chamber_act[LEO_CH_FLOW] = 1.0f;
        leo_mode_update(md);
        CHECK(md->mode == LEO_MODE_RUN, "form: high FLOW quantizes to RUN");
        /* now in RUN (score 0.30); WALK competitor at 0.40 beats by only 0.10 < margin 0.15 */
        md->chamber_act[LEO_CH_FLOW] = 0.30f;
        md->chamber_act[LEO_CH_LOVE] = 0.20f;
        leo_mode_update(md);
        CHECK(md->mode == LEO_MODE_RUN, "form: hysteresis holds the mode against a weak competitor");
        test_leo_delete(md);
    }

    /* A.6 FORM F-2: the mode gates elaboration — STOP/BREATHE hold (the breath),
     * WALK/RUN fill; off-form every mode is eligible (byte-identical). */
    {
        Leo *fm = test_leo_alloc(); leo_init(fm);
        int prev = g_leo_form_on;
        g_leo_form_on = 0; fm->mode = LEO_MODE_STOP;
        CHECK(leo_form_elaborates(fm) == 1, "form: off-form, every mode may elaborate (byte-identical)");
        g_leo_form_on = 1; fm->mode = LEO_MODE_STOP;
        CHECK(leo_form_elaborates(fm) == 0, "form: STOP holds — does not elaborate (the breath)");
        fm->mode = LEO_MODE_RUN;
        CHECK(leo_form_elaborates(fm) == 1, "form: RUN fills out the utterance");
        g_leo_form_on = prev;
        test_leo_delete(fm);
    }

    /* A.6 AML bridge: an external driver (an .aml VELOCITY operator) forces the
     * breath; leo_mode_update respects the override, and releasing it returns
     * autonomy. This is the C contract the AML compiler in leo/ariannamethod/ calls. */
    {
        Leo *br = test_leo_alloc(); leo_init(br);
        br->chamber_act[LEO_CH_FLOW] = 1.0f;     /* would autonomously be RUN */
        leo_mode_set(br, LEO_MODE_STOP);       /* the .aml operator forces STOP */
        leo_mode_update(br);
        CHECK(br->mode == LEO_MODE_STOP, "aml-bridge: a forced mode overrides the chambers");
        leo_mode_set(br, -1);                   /* release → autonomous */
        leo_mode_update(br);
        CHECK(br->mode == LEO_MODE_RUN, "aml-bridge: releasing the override returns autonomy");
        test_leo_delete(br);
    }

    /* A.5 School I3a: Leo hazards a guess from the prompt's context — "Word? Glyph?"
     * when confident (>= 2 supporting concept words), else the bare echo. */
    {
        Leo *gi = test_leo_alloc(); leo_init(gi);
        leo_ingest(gi, "the rain falls. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(gi, "is a zorble like a dog or a cat", buf, sizeof buf);
        CHECK(strstr(buf, "Zorble?") && strstr(buf, "Animal?"),
              "school i3a: a guess from context — 'Zorble? Animal?'");
        Leo *gi2 = test_leo_alloc(); leo_init(gi2);
        leo_ingest(gi2, "the rain falls. his mother is warm.");
        leo_respond(gi2, "tell me about the wobble", buf, sizeof buf);
        CHECK(strstr(buf, "Wobble?") && !strchr(buf + 7, '?'),
              "school i3a: a thin prompt gives the bare echo, no guess");
        g_leo_school_on = prev;
        test_leo_delete(gi); test_leo_delete(gi2);
    }

    /* A.5 E-1: a learned word VOTES — knowledge compounds (yesterday's lesson
     * grounds today's guess). */
    {
        Leo *e1 = test_leo_alloc(); leo_init(e1);
        leo_school_learn(e1, "zorble", semtok_word("animal"));   /* taught: zorble = animal */
        CHECK(leo_school_predict_glyph(e1, "is a zorble or a cat") == semtok_word("animal"),
              "e-1: a learned word votes — zorble + cat -> animal (knowledge compounds)");
        Leo *e2 = test_leo_alloc(); leo_init(e2);                                     /* without the lesson */
        CHECK(leo_school_predict_glyph(e2, "is a zorble or a cat") < 0,
              "e-1: without the lesson, one seed word alone is not a confident guess");
        test_leo_delete(e1); test_leo_delete(e2);
    }

    /* A.5 I3b: the answer's glyph wins the guess — Leo guesses, mama corrects. */
    {
        Leo *sp = test_leo_alloc(); leo_init(sp);
        leo_ingest(sp, "the rain falls. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(sp, "is a zorble like a dog or a cat", buf, sizeof buf);   /* guesses animal */
        leo_respond(sp, "no a zorble is water in the river and the sea", buf, sizeof buf);  /* answer: water */
        CHECK(leo_semtok_word(sp, "zorble") == semtok_word("water"),
              "school i3b: the answer's glyph wins the guess (mama corrects)");
        g_leo_school_on = prev;
        test_leo_delete(sp);
    }

    /* A.6 E-5: the velocity mode + the open guess survive save/load — the mood
     * Leo sleeps in is the mood he wakes in. */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        sv->mode = LEO_MODE_RUN;
        sv->school.pending_glyph = 16;   /* an open guess (animal) */
        const char *path = "/tmp/leo_e5_state.bin";
        int saved = leo_save_state(sv, path);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, path);
        CHECK(saved && loaded && ld->mode == LEO_MODE_RUN && ld->school.pending_glyph == 16,
              "e-5: the velocity mode + the open guess survive save/load (the mood sleeps)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(path);
    }

    /* A.6 E-2c: the guess track-record is counted — curiosity's hit-rate feeds the
     * quality target (curiosity as a learned policy). Two ask→answer cycles: one
     * lands (guess animal, answer animal), one misses (guess animal, answer water). */
    {
        Leo *c2 = test_leo_alloc(); leo_init(c2);
        leo_ingest(c2, "the rain falls. his mother is warm.");
        char buf[1024];
        int prev = g_leo_school_on; g_leo_school_on = 1;
        leo_respond(c2, "is a zorble like a dog or a cat", buf, sizeof buf);   /* guesses animal */
        leo_respond(c2, "a zorble is a dog and a cat", buf, sizeof buf);       /* answer: animal -> HIT */
        leo_respond(c2, "is a wobble like a dog or a cat", buf, sizeof buf);   /* guesses animal */
        leo_respond(c2, "no a wobble is water in the river and the sea", buf, sizeof buf); /* answer: water -> MISS */
        CHECK(c2->school.guesses == 2 && c2->school.guess_hits == 1,
              "e-2c: the guess track-record is counted (2 closed, 1 landed)");
        g_leo_school_on = prev;
        test_leo_delete(c2);
    }

}

static TEST_NOINLINE void test_wonder_persistence(void) {
    /* W-1/W-2: unfinished wonder is not a one-turn UI event. Its possible
     * meanings come from glyph evidence; a counter-question cannot erase it;
     * later resonance returns it, and a grounded human answer closes it. */
    {
        int prev_school = g_leo_school_on, prev_wonder = g_leo_wonder_on;
        g_leo_school_on = 1; g_leo_wonder_on = 1;
        int water = semtok_word("water"), animal = semtok_word("animal");
        Leo *w = test_leo_alloc(); leo_init(w);
        leo_ingest(w, "the rain falls. his mother is warm. the cat drinks water.");
        char out[1024];
        leo_respond(w, "is a zorble water or cat", out, sizeof out);
        CHECK(strstr(out, "Zorble?") && strstr(out, "Water or Animal?") &&
              w->school.pending_glyph == water && w->school.pending_alt_glyph == animal,
              "wonder: two lived glyphs form the question — no authored content phrase");
        CHECK(w->school.n_wonders == 1 && !w->school.wonders[0].resolved &&
              !strcmp(w->school.wonders[0].word, "zorble"),
              "wonder: opening a question births one unfinished episode");
        CHECK(leo_school_grounded_answer(
                  w, "I think about zorble", NULL, NULL) < 0,
              "wonder: talking about thinking is not a definition");

        char rel[LEO_HEARD_WORDLEN] = {0};
        CHECK(!leo_school_find_unknown(w, "does water feel like animal", rel),
              "wonder: relational 'like' is grammar, not an unfinished thing");
        leo_ingest(w, "stopped stopped stopped stopped stopped stopped stopped stopped stopped");
        CHECK(!leo_school_find_unknown(w, "water stopped animal", rel),
              "wonder: a corpus-familiar dedication word cannot become immortal not-knowing");
        leo_ingest(w, "resonance resonance resonance");
        CHECK(leo_school_find_unknown(w, "water resonance animal", rel) && !strcmp(rel, "resonance"),
              "wonder: a rare origin word remains askable just past the novelty gate");

        leo_respond(w, "I do not know", out, sizeof out);
        CHECK(!strcmp(w->school.pending, "zorble") && !leo_school_is_learned(w, "zorble") &&
              w->school.pending_turns == 1,
              "wonder: human not-knowing keeps the question unfinished");
        leo_respond(w, "what do you think?", out, sizeof out);
        CHECK(!strcmp(w->school.pending, "zorble") && !leo_school_is_learned(w, "zorble") &&
              w->school.pending_turns == 2,
              "wonder: a counter-question does not pretend to be an answer");
        leo_respond(w, "is it water?", out, sizeof out);
        CHECK(strstr(out, "Zorble?") && strstr(out, "Water or Animal?") &&
              w->school.pending_turns == 0 && w->school.wonders[0].returns == 1,
              "wonder: resonant water returns the unfinished question after silence");

        const char *open = "/tmp/leo_wonder_open_v13.state";
        const char *old = "/tmp/leo_wonder_open_v10.state";
        const char *compat = "/tmp/leo_wonder_open_v11.state";
        const char *v12 = "/tmp/leo_wonder_open_v12.state";
        const char *cut = "/tmp/leo_wonder_open_cut.state";
        const char *bad = "/tmp/leo_wonder_open_bad.state";
        int saved = leo_save_state(w, open), built_old = 0, built_compat = 0,
            built_v12 = 0, built_cut = 0, built_bad = 0;
        FILE *fi = fopen(open, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
            if (bytes && sz > 0 && (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                long v12tail = (long)(4 * sizeof(int32_t) + sizeof(uint64_t) +
                                      sizeof(LeoWonderEpisodeV27));
                long shadow_tail = (long)(2 * sizeof(int32_t) +
                                          w->shadow.n * (int)sizeof(LeoShadowReceipt));
                long calibration_tail = (long)(2 * sizeof(int32_t) +
                                               w->calibration.n * (int)sizeof(LeoCalibrationReceipt));
                long deferred_tail = (long)(sizeof(int32_t) +
                                             w->school.n_deferred *
                                                 (int)sizeof(LeoDeferredWonder));
                long origin_tail = (long)(sizeof(int32_t) +
                                           (w->school.has_pending_origin ?
                                            sizeof(LeoDeferredWonder) : 0));
                long appetite_tail =
                    test_appetite_and_later_tail_size(w);
                long current_flow = (long)(2 * sizeof(int32_t) +
                                           w->flow.n * (int)sizeof(LeoFlowSnapshot) +
                                           2 * sizeof(int32_t) +
                                           w->flow.n_currents * (int)sizeof(LeoFlowWonderCurrent) +
                                           shadow_tail + calibration_tail +
                                           deferred_tail + origin_tail +
                                           appetite_tail);
                if (sz > v12tail + current_flow) {
                    long flow_start = sz - current_flow;
                    long tail_start = flow_start - v12tail;
                    uint32_t ten = 10; memcpy(bytes + 4, &ten, sizeof ten);
                    FILE *fo = fopen(old, "wb");
                    if (fo) { built_old = (long)fwrite(bytes, 1, (size_t)tail_start, fo) == tail_start; fclose(fo); }

                    uint32_t eleven = 11; memcpy(bytes + 4, &eleven, sizeof eleven);
                    LeoWonderEpisode *cur = &w->school.wonders[0];
                    LeoWonderEpisodeV11 oldep = {0};
                    memcpy(oldep.word, cur->word, sizeof oldep.word);
                    oldep.offered_glyph = cur->offered_glyph;
                    oldep.offered_alt_glyph = cur->offered_alt_glyph;
                    oldep.answer_glyph = cur->answer_glyph;
                    oldep.resolved = cur->resolved;
                    oldep.returns = cur->returns;
                    oldep.opened_step = cur->opened_step;
                    oldep.closed_step = cur->closed_step;
                    fo = fopen(compat, "wb");
                    if (fo) {
                        long prefix = tail_start + (long)(4 * sizeof(int32_t));
                        built_compat = (long)fwrite(bytes, 1, (size_t)prefix, fo) == prefix &&
                                       fwrite(&oldep, sizeof oldep, 1, fo) == 1;
                        fclose(fo);
                    }

                    uint32_t twelve = 12; memcpy(bytes + 4, &twelve, sizeof twelve);
                    fo = fopen(v12, "wb");
                    if (fo) { built_v12 = (long)fwrite(bytes, 1, (size_t)flow_start, fo) == flow_start; fclose(fo); }
                    fo = fopen(cut, "wb");
                    if (fo) { built_cut = (long)fwrite(bytes, 1, (size_t)(flow_start - 4), fo) == flow_start - 4; fclose(fo); }
                    int32_t too_many = LEO_WONDER_RING + 1;
                    memcpy(bytes + tail_start + 2 * sizeof(int32_t), &too_many, sizeof too_many);
                    fo = fopen(bad, "wb");
                    if (fo) { built_bad = (long)fwrite(bytes, 1, (size_t)flow_start, fo) == flow_start; fclose(fo); }
                }
            }
            free(bytes); fclose(fi);
        }
        Leo *oldw = test_leo_alloc(); leo_init(oldw);
        int loaded_old = built_old && leo_load_state(oldw, old);
        CHECK(saved && loaded_old && !strcmp(oldw->school.pending, "zorble") &&
              oldw->school.pending_glyph == water && oldw->school.pending_alt_glyph == -1 &&
              oldw->school.n_wonders == 0,
              "wonder: a v10 body migrates with its old primary question intact");
        leo_respond(oldw, "I do not know", out, sizeof out);
        CHECK(oldw->school.n_wonders == 1 && !oldw->school.wonders[0].resolved &&
              !strcmp(oldw->school.wonders[0].word, "zorble"),
              "wonder: the first lived v10 turn materializes its surviving question");
        Leo *cutw = test_leo_alloc(); leo_init(cutw);
        int loaded_compat = built_compat && leo_load_state(cutw, compat);
        CHECK(loaded_compat && cutw->school.n_wonders == 1 &&
              cutw->school.wonders[0].recalls == 0 &&
              cutw->school.wonders[0].last_recalled_turn == 0,
              "wonder: a v11 episode migrates with returned-wonder fields clean");
        test_leo_delete(cutw); leo_init(cutw);
        int loaded_v12 = built_v12 && leo_load_state(cutw, v12);
        CHECK(loaded_v12 && cutw->school.n_wonders == 1 && cutw->flow.n == 0,
              "flow: a valid v12 body migrates with an empty temporal ledger");
        test_leo_delete(cutw); leo_init(cutw);
        int loaded_cut = built_cut && leo_load_state(cutw, cut);
        CHECK(loaded_cut && !strcmp(cutw->school.pending, "zorble") &&
              cutw->school.pending_alt_glyph == -1 && cutw->school.n_wonders == 0,
              "wonder: a truncated v12 ledger fails soft; the question still lives");
        Leo *badw = test_leo_alloc(); leo_init(badw);
        int loaded_bad = built_bad && leo_load_state(badw, bad);
        CHECK(loaded_bad && !strcmp(badw->school.pending, "zorble") &&
              badw->school.pending_alt_glyph == -1 && badw->school.n_wonders == 0,
              "wonder: an impossible v12 episode count fails soft; the question still lives");

        Leo *slept = test_leo_alloc(); leo_init(slept);
        int loaded = saved && leo_load_state(slept, open);
        CHECK(loaded && !strcmp(slept->school.pending, "zorble") &&
              slept->school.pending_alt_glyph == animal && slept->school.n_wonders == 1 &&
              slept->school.wonders[0].returns == 1,
              "wonder: the unfinished episode survives sleep with both hypotheses");
        leo_respond(slept, "a zorble is animal", out, sizeof out);
        CHECK(!slept->school.pending[0] && leo_semtok_word(slept, "zorble") == animal &&
              slept->school.wonders[0].resolved && slept->school.wonders[0].answer_glyph == animal,
              "wonder: a grounded human answer resolves the episode and grows meaning");
        CHECK(leo_save_state(slept, open), "wonder: a resolved episode saves");
        Leo *woke = test_leo_alloc(); leo_init(woke);
        CHECK(leo_load_state(woke, open) && woke->school.n_wonders == 1 &&
              woke->school.wonders[0].resolved && woke->school.wonders[0].answer_glyph == animal,
              "wonder: the resolved human-grounded episode survives another sleep");

        test_leo_delete(w); test_leo_delete(oldw); test_leo_delete(cutw); test_leo_delete(badw); test_leo_delete(slept); test_leo_delete(woke);
        remove(open); remove(old); remove(compat); remove(v12); remove(cut); remove(bad);
        g_leo_school_on = prev_school; g_leo_wonder_on = prev_wonder;
    }

}

static TEST_NOINLINE void test_natural_school_word_boundary(void) {
    /* A.119: natural typography cannot manufacture a teachable word. The
     * repair is deliberately School-local; the historical byte boundary
     * remains an exact named ablation. */
    Leo *boundary = test_leo_alloc();
    leo_init(boundary);
    char unknown[LEO_HEARD_WORDLEN] = {0};
    int previous = g_leo_school_natural_word_boundary_on;
    g_leo_school_natural_word_boundary_on = 1;

    CHECK(!leo_school_find_unknown(
              boundary, "you don't have to remember", unknown),
          "natural-word-boundary: ASCII contraction remains known");
    CHECK(!leo_school_find_unknown(
              boundary, "you don’t have to remember", unknown),
          "natural-word-boundary: curly contraction cannot manufacture don");
    CHECK(!leo_school_find_unknown(boundary, "what’s", unknown),
          "natural-word-boundary: contracted function word remains grammar");
    CHECK(!leo_school_find_unknown(boundary, "child’s", unknown),
          "natural-word-boundary: known possessive remains its known stem");
    CHECK(leo_school_find_unknown(boundary, "zorble’s", unknown) &&
              !strcmp(unknown, "zorble"),
          "natural-word-boundary: unknown possessive asks for its lexical body");
    CHECK(!leo_school_find_unknown(boundary, "‘child’", unknown),
          "natural-word-boundary: curly quotes preserve a known lexical body");
    CHECK(leo_school_find_unknown(boundary, "‘zorble’", unknown) &&
              !strcmp(unknown, "zorble"),
          "natural-word-boundary: curly quotes preserve an unknown lexical body");

    g_leo_school_natural_word_boundary_on = 0;
    CHECK(leo_school_find_unknown(
              boundary, "you don’t have to remember", unknown) &&
              !strcmp(unknown, "don"),
          "natural-word-boundary: explicit ablation restores the A.118 shard");

    g_leo_school_natural_word_boundary_on = previous;
    test_leo_delete(boundary);
}

static TEST_NOINLINE void test_school_lexical_family(void) {
    /* A.120: School refuses only a whole-word family relation backed by a
     * concept or by repeated hearing. Productive suffixes, closed irregular
     * bridges, and complete compounds share that evidence boundary. */
    Leo *family = test_leo_alloc();
    leo_init(family);
    int previous = g_leo_school_lexical_family_on;
    int previous_role = g_leo_school_lexical_role_on;
    g_leo_school_lexical_family_on = 1;
    g_leo_school_lexical_role_on = 0;

    static const char *const witnessed[] = {
        "belong", "calm", "respect", "dust", "neighbour", "brought", NULL
    };
    for (int i = 0; witnessed[i]; i++)
        for (int n = 0; n <= LEO_SCHOOL_NOVEL_MAX; n++)
            leo_heard_add(&family->heard, witnessed[i]);

    struct FamilyCase {
        const char *surface;
        const char *base;
        LeoSchoolFamilyEvidence evidence;
    } cases[] = {
        {"rainy", "rain", LEO_SCHOOL_FAMILY_MEANING},
        {"belonged", "belong", LEO_SCHOOL_FAMILY_HEARD},
        {"outdoors", "outdoor", LEO_SCHOOL_FAMILY_COMPOUND},
        {"dusty", "dust", LEO_SCHOOL_FAMILY_HEARD},
        {"calmer", "calm", LEO_SCHOOL_FAMILY_HEARD},
        {"respecting", "respect", LEO_SCHOOL_FAMILY_HEARD},
        {"loved", "love", LEO_SCHOOL_FAMILY_MEANING},
        {"making", "make", LEO_SCHOOL_FAMILY_MEANING},
        {"stopped", "stop", LEO_SCHOOL_FAMILY_MEANING},
        {"mothers", "mother", LEO_SCHOOL_FAMILY_MEANING},
        {"stories", "story", LEO_SCHOOL_FAMILY_MEANING},
        {"peaceful", "peace", LEO_SCHOOL_FAMILY_MEANING},
        {"kindness", "kind", LEO_SCHOOL_FAMILY_MEANING},
        {"happiness", "happy", LEO_SCHOOL_FAMILY_MEANING},
        {"bedroom", "bedroom", LEO_SCHOOL_FAMILY_COMPOUND},
        {"sunlight", "sunlight", LEO_SCHOOL_FAMILY_COMPOUND},
        {"neighbor", "neighbour", LEO_SCHOOL_FAMILY_HEARD},
        {"neighbors", "neighbour", LEO_SCHOOL_FAMILY_HEARD},
        {"loss", "lost", LEO_SCHOOL_FAMILY_MEANING},
        {"losses", "lost", LEO_SCHOOL_FAMILY_MEANING},
        {"bring", "brought", LEO_SCHOOL_FAMILY_HEARD},
        {"brings", "brought", LEO_SCHOOL_FAMILY_HEARD},
        {"lover", "love", LEO_SCHOOL_FAMILY_MEANING},
        {NULL, NULL, LEO_SCHOOL_FAMILY_NONE}
    };
    for (int i = 0; cases[i].surface; i++) {
        char base[LEO_HEARD_WORDLEN] = {0};
        char label[128];
        LeoSchoolFamilyEvidence evidence = leo_school_lexical_family(
            family, cases[i].surface, base);
        snprintf(label, sizeof label,
                 "lexical-family: %s reaches only its witnessed relative",
                 cases[i].surface);
        CHECK(evidence == cases[i].evidence &&
                  !strcmp(base, cases[i].base), label);
    }

    static const char *const refusals[] = {
        "beneath", "news", "moth", "thing", "without", "raincoat",
        "smooth", "fragile", "zorbled", NULL
    };
    for (int i = 0; refusals[i]; i++) {
        char base[LEO_HEARD_WORDLEN] = {0};
        char label[128];
        LeoSchoolFamilyEvidence evidence = leo_school_lexical_family(
            family, refusals[i], base);
        snprintf(label, sizeof label,
                 "lexical-family: %s cannot borrow an unwitnessed substring",
                 refusals[i]);
        CHECK(evidence == LEO_SCHOOL_FAMILY_NONE && !base[0], label);
    }

    leo_school_learn(family, "zorble", semtok_find_glyph("water"));
    char learned_base[LEO_HEARD_WORDLEN] = {0};
    CHECK(leo_school_lexical_family(family, "zorbled", learned_base) ==
              LEO_SCHOOL_FAMILY_MEANING && !strcmp(learned_base, "zorble"),
          "lexical-family: a human-taught root immediately grows a family");

    char unknown[LEO_HEARD_WORDLEN] = {0};
    CHECK(!leo_school_find_unknown(family, "rainy", unknown) &&
              !leo_school_find_unknown(family, "belonged", unknown) &&
              !leo_school_find_unknown(family, "outdoors", unknown) &&
              !leo_school_find_unknown(family, "neighbor", unknown) &&
              !leo_school_find_unknown(family, "loss", unknown) &&
              !leo_school_find_unknown(family, "bring", unknown),
          "lexical-family: witnessed relatives do not masquerade as School novelty");
    CHECK(leo_school_find_unknown(family, "beneath", unknown) &&
              !strcmp(unknown, "beneath") &&
              leo_school_find_unknown(family, "smooth", unknown) &&
              !strcmp(unknown, "smooth"),
          "lexical-family: unrelated whole words remain honest questions");

    g_leo_school_lexical_family_on = 0;
    CHECK(leo_school_find_unknown(family, "rainy", unknown) &&
              !strcmp(unknown, "rainy") &&
              leo_school_find_unknown(family, "belonged", unknown) &&
              !strcmp(unknown, "belonged") &&
              leo_school_find_unknown(family, "outdoors", unknown) &&
              !strcmp(unknown, "outdoors"),
          "lexical-family: explicit ablation restores surface-form questions");

    g_leo_school_lexical_family_on = previous;
    g_leo_school_lexical_role_on = previous_role;
    test_leo_delete(family);
}

static TEST_NOINLINE void test_school_family_heard_threshold(void) {
    /* A.131: heard familiarity may be split across the two witnessed ends of
     * one relation A.120 already admits. This neither invents a reverse edge
     * nor pools siblings, substrings, or an unwitnessed relative. */
    int previous = g_leo_school_family_heard_threshold_on;
    int previous_lexical = g_leo_school_lexical_family_on;
    int previous_role = g_leo_school_lexical_role_on;
    int previous_negative = g_leo_school_negative_family_on;
    int previous_reciprocal = g_leo_school_reciprocal_s_family_on;

    struct FamilyThresholdCase {
        const char *surface;
        const char *relative;
        int surface_heard;
        int relative_heard;
        int learned;
        LeoSchoolFamilyEvidence candidate;
        LeoSchoolFamilyEvidence ablation;
    } cases[] = {
        {"onions", "onion", 2, 2, 0,
         LEO_SCHOOL_FAMILY_HEARD, LEO_SCHOOL_FAMILY_NONE},
        {"zorbles", "zorble", 1, 2, 0,
         LEO_SCHOOL_FAMILY_HEARD, LEO_SCHOOL_FAMILY_NONE},
        {"zorbles", "zorble", 1, 1, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE},
        {"zorbles", "zorble", 3, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE},
        {"zorbles", "zorble", 1, 3, 0,
         LEO_SCHOOL_FAMILY_HEARD, LEO_SCHOOL_FAMILY_HEARD},
        {"zorbles", "zorble", 1, 0, 1,
         LEO_SCHOOL_FAMILY_MEANING, LEO_SCHOOL_FAMILY_MEANING},
        {"guided", "guide", 1, 2, 0,
         LEO_SCHOOL_FAMILY_HEARD, LEO_SCHOOL_FAMILY_NONE},
        {"neighbor", "neighbour", 1, 2, 0,
         LEO_SCHOOL_FAMILY_HEARD, LEO_SCHOOL_FAMILY_NONE},
        {"onion", "onions", 2, 2, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE},
        {"news", "new", 2, 2, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE},
        {"press", "pres", 2, 2, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE},
        {"rain", "training", 2, 2, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE},
        {NULL, NULL, 0, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, LEO_SCHOOL_FAMILY_NONE}
    };

    for (int i = 0; cases[i].surface; i++) {
        Leo *family = test_leo_alloc();
        leo_init(family);
        for (int n = 0; n < cases[i].surface_heard; n++)
            leo_heard_add(&family->heard, cases[i].surface);
        for (int n = 0; n < cases[i].relative_heard; n++)
            leo_heard_add(&family->heard, cases[i].relative);
        if (cases[i].learned)
            leo_school_learn(
                family, cases[i].relative, semtok_find_glyph("water"));

        char base[LEO_HEARD_WORDLEN] = {0};
        g_leo_school_family_heard_threshold_on = 1;
        LeoSchoolFamilyEvidence candidate = leo_school_lexical_family(
            family, cases[i].surface, base);
        g_leo_school_family_heard_threshold_on = 0;
        LeoSchoolFamilyEvidence ablation = leo_school_lexical_family(
            family, cases[i].surface, NULL);
        char label[192];
        snprintf(label, sizeof label,
                 "family-heard-threshold: %s -> %s stays bounded",
                 cases[i].surface, cases[i].relative);
        CHECK(candidate == cases[i].candidate &&
                  ablation == cases[i].ablation &&
                  (candidate == LEO_SCHOOL_FAMILY_NONE ||
                   !strcmp(base, cases[i].relative)),
              label);
        test_leo_delete(family);
    }

    Leo *interaction = test_leo_alloc();
    leo_init(interaction);
    for (int n = 0; n < 2; n++) {
        leo_heard_add(&interaction->heard, "onions");
        leo_heard_add(&interaction->heard, "onion");
    }
    g_leo_school_lexical_role_on = 0;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    for (int lexical = 0; lexical <= 1; lexical++) {
        for (int threshold = 0; threshold <= 1; threshold++) {
            char unknown[LEO_HEARD_WORDLEN] = {0};
            g_leo_school_lexical_family_on = lexical;
            g_leo_school_family_heard_threshold_on = threshold;
            int found = leo_school_find_unknown(
                interaction, "onions", unknown);
            char label[160];
            snprintf(label, sizeof label,
                     "family-heard-threshold: 2x2 lexical=%d threshold=%d",
                     lexical, threshold);
            CHECK(found == !(lexical && threshold) &&
                      (!found || !strcmp(unknown, "onions")),
                  label);
        }
    }

    g_leo_school_family_heard_threshold_on = previous;
    g_leo_school_lexical_family_on = previous_lexical;
    g_leo_school_lexical_role_on = previous_role;
    g_leo_school_negative_family_on = previous_negative;
    g_leo_school_reciprocal_s_family_on = previous_reciprocal;
    test_leo_delete(interaction);
}

static TEST_NOINLINE void test_school_two_layer_family_composition(void) {
    /* A.133 may follow exactly two relations already admitted by A.120. The
     * second edge still needs its own whole-word evidence; three thin nodes,
     * an unheard endpoint, or a path requiring a third edge cannot pool their
     * way into familiarity. */
    int previous = g_leo_school_two_layer_family_composition_on;
    int previous_lexical = g_leo_school_lexical_family_on;
    int previous_role = g_leo_school_lexical_role_on;
    int previous_negative = g_leo_school_negative_family_on;
    int previous_reciprocal = g_leo_school_reciprocal_s_family_on;
    int previous_threshold = g_leo_school_family_heard_threshold_on;
    g_leo_school_family_heard_threshold_on = 1;

    struct TwoLayerCase {
        const char *surface;
        const char *intermediate;
        const char *deep;
        int surface_heard;
        int intermediate_heard;
        int deep_heard;
        int deep_learned;
        int add_mean;
        LeoSchoolFamilyEvidence evidence;
        const char *base;
    } cases[] = {
        {"meaningful", "meaning", "mean", 1, 1, 7, 0, 0,
         LEO_SCHOOL_FAMILY_HEARD, "mean"},
        {"zorbledness", "zorbled", "zorble", 1, 1, 2, 0, 0,
         LEO_SCHOOL_FAMILY_HEARD, "zorble"},
        {"zorbledness", "zorbled", "zorble", 1, 1, 0, 1, 0,
         LEO_SCHOOL_FAMILY_MEANING, "zorble"},
        {"peacefully", "peaceful", "peace", 1, 1, 0, 0, 0,
         LEO_SCHOOL_FAMILY_MEANING, "peace"},
        {"kindnesses", "kindness", "kind", 1, 1, 0, 0, 0,
         LEO_SCHOOL_FAMILY_MEANING, "kind"},
        {"zorbledness", "zorbled", "zorble", 1, 1, 1, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {"zorbledness", "zorbled", "zorble", 3, 0, 0, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {"zorbledness", "zorbled", "zorble", 1, 3, 0, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {"zorbledness", "zorbled", "zorble", 1, 1, 1, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {"flimmedness", "flimmed", "flim", 1, 1, 0, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {"meaningfully", "meaningful", "meaning", 1, 1, 1, 0, 7,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {"newsworthy", "newsworth", "news", 1, 1, 7, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""},
        {NULL, NULL, NULL, 0, 0, 0, 0, 0,
         LEO_SCHOOL_FAMILY_NONE, ""}
    };

    for (int i = 0; cases[i].surface; i++) {
        Leo *family = test_leo_alloc();
        leo_init(family);
        for (int n = 0; n < cases[i].surface_heard; n++)
            leo_heard_add(&family->heard, cases[i].surface);
        for (int n = 0; n < cases[i].intermediate_heard; n++)
            leo_heard_add(&family->heard, cases[i].intermediate);
        for (int n = 0; n < cases[i].deep_heard; n++)
            leo_heard_add(&family->heard, cases[i].deep);
        for (int n = 0; n < cases[i].add_mean; n++)
            leo_heard_add(&family->heard, "mean");
        if (cases[i].deep_learned)
            leo_school_learn(
                family, cases[i].deep, semtok_find_glyph("water"));

        char base[LEO_HEARD_WORDLEN] = {0};
        LeoSchoolFamilyEvidence evidence =
            leo_school_two_layer_family_composition(
                family, cases[i].surface, base);
        char label[192];
        snprintf(label, sizeof label,
                 "two-layer-family: %s keeps exactly two admitted edges",
                 cases[i].surface);
        CHECK(evidence == cases[i].evidence &&
                  !strcmp(base, cases[i].base), label);
        test_leo_delete(family);
    }

    Leo *interaction = test_leo_alloc();
    leo_init(interaction);
    leo_heard_add(&interaction->heard, "meaningful");
    leo_heard_add(&interaction->heard, "meaning");
    for (int n = 0; n < 7; n++)
        leo_heard_add(&interaction->heard, "mean");
    g_leo_school_lexical_role_on = 0;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    for (int lexical = 0; lexical <= 1; lexical++) {
        for (int composition = 0; composition <= 1; composition++) {
            char unknown[LEO_HEARD_WORDLEN] = {0};
            g_leo_school_lexical_family_on = lexical;
            g_leo_school_two_layer_family_composition_on = composition;
            int found = leo_school_find_unknown(
                interaction, "meaningful", unknown);
            char label[176];
            snprintf(label, sizeof label,
                     "two-layer-family: 2x2 lexical=%d composition=%d",
                     lexical, composition);
            CHECK(found == !composition &&
                      (!found || !strcmp(unknown, "meaningful")), label);
        }
    }

    g_leo_school_two_layer_family_composition_on = previous;
    g_leo_school_lexical_family_on = previous_lexical;
    g_leo_school_lexical_role_on = previous_role;
    g_leo_school_negative_family_on = previous_negative;
    g_leo_school_reciprocal_s_family_on = previous_reciprocal;
    g_leo_school_family_heard_threshold_on = previous_threshold;
    test_leo_delete(interaction);
}

static TEST_NOINLINE void test_school_negative_family(void) {
    /* A.128: exact `un-` may compose with one already witnessed A.120
     * relative. The complete remainder must itself be known or reach a known
     * whole word; orthographic prefix resemblance alone remains askable. */
    Leo *family = test_leo_alloc();
    leo_init(family);
    int previous = g_leo_school_negative_family_on;
    int previous_lexical = g_leo_school_lexical_family_on;
    g_leo_school_negative_family_on = 1;
    g_leo_school_lexical_family_on = 1;
    for (int n = 0; n <= LEO_SCHOOL_NOVEL_MAX; n++)
        leo_heard_add(&family->heard, "hurry");
    leo_school_learn(
        family, "zorble", semtok_find_glyph("water"));

    struct NegativeFamilyCase {
        const char *surface;
        const char *base;
        LeoSchoolFamilyEvidence evidence;
    } cases[] = {
        {"unhurried", "hurry", LEO_SCHOOL_FAMILY_HEARD},
        {"unhappy", "happy", LEO_SCHOOL_FAMILY_MEANING},
        {"unloved", "love", LEO_SCHOOL_FAMILY_MEANING},
        {"unrainy", "rain", LEO_SCHOOL_FAMILY_MEANING},
        {"unzorbled", "zorble", LEO_SCHOOL_FAMILY_MEANING},
        {NULL, NULL, LEO_SCHOOL_FAMILY_NONE}
    };
    for (int i = 0; cases[i].surface; i++) {
        char base[LEO_HEARD_WORDLEN] = {0};
        char label[128];
        LeoSchoolFamilyEvidence evidence =
            leo_school_negative_family(
                family, cases[i].surface, base);
        snprintf(label, sizeof label,
                 "negative-family: %s reaches only its whole-word witness",
                 cases[i].surface);
        CHECK(evidence == cases[i].evidence &&
                  !strcmp(base, cases[i].base), label);
    }

    static const char *const refusals[] = {
        "unflimmed", "uncle", "unique", "union", "invisible",
        "unit", NULL
    };
    for (int i = 0; refusals[i]; i++) {
        char base[LEO_HEARD_WORDLEN] = {0};
        char label[128];
        LeoSchoolFamilyEvidence evidence =
            leo_school_negative_family(
                family, refusals[i], base);
        snprintf(label, sizeof label,
                 "negative-family: %s cannot borrow an un- substring",
                 refusals[i]);
        CHECK(evidence == LEO_SCHOOL_FAMILY_NONE && !base[0], label);
    }

    char unknown[LEO_HEARD_WORDLEN] = {0};
    CHECK(!leo_school_find_unknown(family, "unhurried", unknown) &&
              !leo_school_find_unknown(family, "unhappy", unknown) &&
              !leo_school_find_unknown(family, "unzorbled", unknown),
          "negative-family: witnessed relatives cannot masquerade as School novelty");
    CHECK(leo_school_find_unknown(family, "uncle", unknown) &&
              !strcmp(unknown, "uncle") &&
              leo_school_find_unknown(family, "unflimmed", unknown) &&
              !strcmp(unknown, "unflimmed"),
          "negative-family: indivisible and unwitnessed controls remain honest questions");

    g_leo_school_lexical_family_on = 0;
    CHECK(!leo_school_find_unknown(family, "unhurried", unknown),
          "negative-family: the composed witness does not borrow A.120's runtime switch");
    g_leo_school_negative_family_on = 0;
    CHECK(leo_school_find_unknown(family, "unhurried", unknown) &&
              !strcmp(unknown, "unhurried"),
          "negative-family: named ablation restores the A.127 surface question");

    g_leo_school_negative_family_on = previous;
    g_leo_school_lexical_family_on = previous_lexical;
    test_leo_delete(family);
}

static TEST_NOINLINE void test_school_reciprocal_s_family(void) {
    /* A.129: the reciprocal relation is one exact X -> Xs edge backed by
     * whole-word evidence. It is independently ablatable and never becomes a
     * general inflector, substring matcher, or source of semantic meaning. */
    Leo *family = test_leo_alloc();
    leo_init(family);
    int previous = g_leo_school_reciprocal_s_family_on;
    int previous_lexical = g_leo_school_lexical_family_on;
    int previous_role = g_leo_school_lexical_role_on;
    g_leo_school_reciprocal_s_family_on = 1;
    g_leo_school_lexical_family_on = 1;
    g_leo_school_lexical_role_on = 0;

    static const char *const witnessed[] = {
        "prefers", "zorbles", "news", "press", "always", "this", NULL
    };
    for (int i = 0; witnessed[i]; i++)
        for (int n = 0; n <= LEO_SCHOOL_NOVEL_MAX; n++)
            leo_heard_add(&family->heard, witnessed[i]);

    struct ReciprocalCase {
        const char *surface;
        const char *relative;
        LeoSchoolFamilyEvidence evidence;
    } cases[] = {
        {"prefer", "prefers", LEO_SCHOOL_FAMILY_HEARD},
        {"zorble", "", LEO_SCHOOL_FAMILY_NONE},
        {"flim", "", LEO_SCHOOL_FAMILY_NONE},
        {"narp", "", LEO_SCHOOL_FAMILY_NONE},
        {"new", "", LEO_SCHOOL_FAMILY_NONE},
        {"pres", "", LEO_SCHOOL_FAMILY_NONE},
        {"alway", "", LEO_SCHOOL_FAMILY_NONE},
        {"thi", "", LEO_SCHOOL_FAMILY_NONE},
        {"prefers", "", LEO_SCHOOL_FAMILY_NONE},
        {NULL, NULL, LEO_SCHOOL_FAMILY_NONE}
    };
    for (int i = 0; cases[i].surface; i++) {
        char relative[LEO_HEARD_WORDLEN] = {0};
        LeoSchoolFamilyEvidence evidence = leo_school_reciprocal_s_family(
            family, cases[i].surface, relative);
        CHECK(evidence == cases[i].evidence &&
                  !strcmp(relative, cases[i].relative),
              "reciprocal-s-family: each surface reaches only its complete Xs witness");
    }

    char unknown[LEO_HEARD_WORDLEN] = {0};
    CHECK(!leo_school_find_unknown(family, "prefer", unknown) &&
              leo_school_find_unknown(family, "zorble", unknown) &&
              !strcmp(unknown, "zorble"),
          "reciprocal-s-family: only a listed witnessed relative can silence novelty");
    CHECK(leo_school_find_unknown(family, "flim", unknown) &&
              !strcmp(unknown, "flim") &&
              leo_school_find_unknown(family, "narp", unknown) &&
              !strcmp(unknown, "narp") &&
              leo_school_find_unknown(family, "pres", unknown) &&
              !strcmp(unknown, "pres") &&
              leo_school_find_unknown(family, "alway", unknown) &&
              !strcmp(unknown, "alway"),
          "reciprocal-s-family: threshold and orthographic controls remain questions");

    leo_school_learn(family, "prefers", semtok_find_glyph("water"));
    char relative[LEO_HEARD_WORDLEN] = {0};
    CHECK(leo_school_reciprocal_s_family(family, "prefer", relative) ==
              LEO_SCHOOL_FAMILY_MEANING && !strcmp(relative, "prefers"),
          "reciprocal-s-family: an explicitly learned listed relative is meaning evidence");

    Leo *thin = test_leo_alloc();
    leo_init(thin);
    leo_heard_add(&thin->heard, "prefers");
    CHECK(leo_school_reciprocal_s_family(thin, "prefer", relative) ==
              LEO_SCHOOL_FAMILY_NONE,
          "reciprocal-s-family: one hearing stays below the evidence threshold");

    g_leo_school_lexical_family_on = 0;
    CHECK(!leo_school_find_unknown(family, "prefer", unknown),
          "reciprocal-s-family: reverse evidence does not borrow A.120's runtime switch");
    g_leo_school_reciprocal_s_family_on = 0;
    CHECK(leo_school_find_unknown(family, "prefer", unknown) &&
              !strcmp(unknown, "prefer"),
          "reciprocal-s-family: named ablation restores the A.128 question");

    g_leo_school_reciprocal_s_family_on = previous;
    g_leo_school_lexical_family_on = previous_lexical;
    g_leo_school_lexical_role_on = previous_role;
    test_leo_delete(thin);
    test_leo_delete(family);
}

static TEST_NOINLINE void test_school_lexical_role(void) {
    /* A.121: a whole word can carry grammar without naming a teachable thing.
     * The refusal reuses exact relational, polarity, and discourse witnesses;
     * it neither assigns a glyph nor searches inside larger words. */
    Leo *role = test_leo_alloc();
    leo_init(role);
    int previous = g_leo_school_lexical_role_on;
    g_leo_school_lexical_role_on = 1;

    struct RoleCase {
        const char *surface;
        LeoSchoolLexicalRole role;
        const char *witness;
    } cases[] = {
        {"across", LEO_SCHOOL_ROLE_RELATION, "through"},
        {"against", LEO_SCHOOL_ROLE_RELATION, "at"},
        {"along", LEO_SCHOOL_ROLE_RELATION, "through"},
        {"alongside", LEO_SCHOOL_ROLE_RELATION, "by"},
        {"among", LEO_SCHOOL_ROLE_RELATION, "between"},
        {"amongst", LEO_SCHOOL_ROLE_RELATION, "between"},
        {"around", LEO_SCHOOL_ROLE_RELATION, "about"},
        {"beneath", LEO_SCHOOL_ROLE_RELATION, "under"},
        {"beside", LEO_SCHOOL_ROLE_RELATION, "by"},
        {"beyond", LEO_SCHOOL_ROLE_RELATION, "over"},
        {"near", LEO_SCHOOL_ROLE_RELATION, "by"},
        {"nearby", LEO_SCHOOL_ROLE_RELATION, "by"},
        {"onto", LEO_SCHOOL_ROLE_RELATION, "on"},
        {"throughout", LEO_SCHOOL_ROLE_RELATION, "through"},
        {"toward", LEO_SCHOOL_ROLE_RELATION, "to"},
        {"towards", LEO_SCHOOL_ROLE_RELATION, "to"},
        {"underneath", LEO_SCHOOL_ROLE_RELATION, "under"},
        {"within", LEO_SCHOOL_ROLE_RELATION, "in"},
        {"neither", LEO_SCHOOL_ROLE_POLARITY, "not"},
        {"nor", LEO_SCHOOL_ROLE_POLARITY, "not"},
        {"without", LEO_SCHOOL_ROLE_POLARITY, "not"},
        {"however", LEO_SCHOOL_ROLE_DISCOURSE, "but"},
        {"instead", LEO_SCHOOL_ROLE_DISCOURSE, "but"},
        {"rather", LEO_SCHOOL_ROLE_DISCOURSE, "but"},
        {NULL, LEO_SCHOOL_ROLE_NONE, NULL}
    };
    for (int i = 0; cases[i].surface; i++) {
        const char *witness = NULL;
        char label[128];
        LeoSchoolLexicalRole observed =
            leo_school_lexical_role(cases[i].surface, &witness);
        snprintf(label, sizeof label,
                 "lexical-role: %s carries only its exact grammar role",
                 cases[i].surface);
        CHECK(observed == cases[i].role && witness &&
                  !strcmp(witness, cases[i].witness), label);
    }

    static const char *const refusals[] = {
        "underworld", "beneathness", "nearness", "surround",
        "withinness", "nothing", "toy", "smooth", "fragile", NULL
    };
    for (int i = 0; refusals[i]; i++) {
        const char *witness = NULL;
        char label[128];
        LeoSchoolLexicalRole observed =
            leo_school_lexical_role(refusals[i], &witness);
        snprintf(label, sizeof label,
                 "lexical-role: %s cannot borrow grammar from a substring",
                 refusals[i]);
        CHECK(observed == LEO_SCHOOL_ROLE_NONE && !witness, label);
    }

    char unknown[LEO_HEARD_WORDLEN] = {0};
    CHECK(!leo_school_find_unknown(role, "beneath nearby nor without however",
                                   unknown),
          "lexical-role: exact grammar cannot masquerade as School novelty");
    CHECK(leo_school_find_unknown(role, "underworld", unknown) &&
              !strcmp(unknown, "underworld") &&
              leo_school_find_unknown(role, "toy", unknown) &&
              !strcmp(unknown, "toy") &&
              leo_school_find_unknown(role, "smooth", unknown) &&
              !strcmp(unknown, "smooth") &&
              leo_school_find_unknown(role, "fragile", unknown) &&
              !strcmp(unknown, "fragile"),
          "lexical-role: exact-word controls remain honest questions");
    CHECK(leo_semtok_word(role, "beneath") < 0 &&
              !leo_school_is_learned(role, "beneath"),
          "lexical-role: refusing grammar invents no concept or lesson");

    g_leo_school_lexical_role_on = 0;
    CHECK(leo_school_find_unknown(role, "beneath", unknown) &&
              !strcmp(unknown, "beneath") &&
              leo_school_find_unknown(role, "nearby", unknown) &&
              !strcmp(unknown, "nearby") &&
              leo_school_find_unknown(role, "nor", unknown) &&
              !strcmp(unknown, "nor"),
          "lexical-role: explicit ablation restores A.120 questions");

    g_leo_school_lexical_role_on = previous;
    test_leo_delete(role);
}

static TEST_NOINLINE void test_wonder_ablation(void) {
    /* W-3 ablation: --no-wonder restores the exact old School semantics — one
     * primary guess only, and the next turn closes the pending UI question. */
    {
        int prev_school = g_leo_school_on, prev_wonder = g_leo_wonder_on;
        g_leo_school_on = 1; g_leo_wonder_on = 0;
        Leo *ab = test_leo_alloc(); leo_init(ab);
        leo_ingest(ab, "the rain falls. his mother is warm. the cat drinks water.");
        char out[1024];
        leo_respond(ab, "is a zorble water or cat", out, sizeof out);
        int old_shape = strstr(out, "Zorble?") && !strstr(out, " or ");
        leo_respond(ab, "qwzx blorf", out, sizeof out);
        CHECK(old_shape && !ab->school.pending[0] && ab->school.n_wonders == 0,
              "wonder: --no-wonder is the pre-wonder one-turn School contract");
        test_leo_delete(ab);
        g_leo_school_on = prev_school; g_leo_wonder_on = prev_wonder;
    }

}

static TEST_NOINLINE void test_wonder_negation(void) {
    /* A.74: School distinguishes a meaning the human asserts from one the
     * human rejects. Negative evidence may narrow Leo's live alternatives, but
     * it cannot resolve the Wonder or silently choose the surviving guess. */
    {
        Leo *neg = calloc(1, sizeof *neg);
        Leo *woke = calloc(1, sizeof *woke);
        Leo *address = calloc(1, sizeof *address);
        CHECK(neg && woke && address,
              "wonder-negation: heap fixtures allocated");
        if (neg && woke && address) {
            int prev_school = g_leo_school_on;
            int prev_wonder = g_leo_wonder_on;
            int prev_attribution =
                g_leo_wonder_attribution_on;
            g_leo_school_on = 1;
            g_leo_wonder_on = 1;
            g_leo_wonder_attribution_on = 1;
            int water = semtok_word("water");
            int animal = semtok_word("animal");
            char out[1024];

            seed_wonder_negation_body(neg);
            leo_respond(
                neg, "a zorble is not water",
                out, sizeof out);
            const LeoFlowSnapshot *negative_flow =
                leo_flow_at(&neg->flow, neg->flow.n - 1);
            CHECK(!leo_school_is_learned(neg, "zorble") &&
                  !strcmp(neg->school.pending, "zorble") &&
                  neg->school.pending_glyph == animal &&
                  neg->school.pending_alt_glyph == -1 &&
                  !neg->school.wonders[0].resolved,
                  "wonder-negation: rejecting water narrows the live question without resolving it");
            CHECK(negative_flow &&
                  negative_flow->perceived[water] > 0.0f &&
                  neg->school.pending_origin.offered_glyph ==
                      animal &&
                  neg->school.wonders[0].offered_glyph ==
                      animal,
                  "wonder-negation: rejected meaning remains perceived while School and provenance narrow");

            const char *path =
                "/tmp/leo_wonder_negation.state";
            int saved = leo_save_state(neg, path);
            leo_init(woke);
            int loaded =
                saved && leo_load_state(woke, path);
            CHECK(loaded &&
                  !strcmp(woke->school.pending, "zorble") &&
                  woke->school.pending_glyph == animal &&
                  woke->school.pending_alt_glyph == -1 &&
                  woke->school.has_pending_origin &&
                  woke->school.pending_origin.offered_glyph ==
                      animal &&
                  !woke->school.wonders[0].resolved,
                  "wonder-negation: narrowed uncertainty survives sleep without a new state tail");
            leo_respond(
                woke, "what is zorble?", out, sizeof out);
            CHECK(strstr(out, "Zorble? Animal?") &&
                  !strstr(out, "Water") &&
                  woke->school.wonders[0].returns == 1,
                  "wonder-negation: the next return asks only the surviving hypothesis");
            leo_respond(
                woke, "a zorble is animal",
                out, sizeof out);
            CHECK(!woke->school.pending[0] &&
                  leo_semtok_word(woke, "zorble") == animal &&
                  woke->school.wonders[0].resolved,
                  "wonder-negation: later positive evidence can still ground the narrowed question");

            /* A.135 freezes the zero-survivor edge witnessed by A.134. When
             * the only offered glyph is rejected, a later literal return is
             * the bare word: rejection cannot be resurrected as a guess. */
            leo_free(neg);
            seed_wonder_negation_body(neg);
            neg->school.pending_alt_glyph = -1;
            neg->school.pending_origin.offered_alt_glyph = -1;
            neg->school.wonders[0].offered_alt_glyph = -1;
            leo_respond(
                neg, "a zorble is not water",
                out, sizeof out);
            CHECK(!leo_school_is_learned(neg, "zorble") &&
                  !strcmp(neg->school.pending, "zorble") &&
                  neg->school.pending_glyph == -1 &&
                  neg->school.pending_alt_glyph == -1 &&
                  !neg->school.wonders[0].resolved,
                  "single-hypothesis rejection: no surviving guess is not a fabricated answer");
            leo_respond(
                neg, "what is zorble?",
                out, sizeof out);
            CHECK(!strcmp(out, "Zorble?") &&
                  neg->school.wonders[0].returns == 1 &&
                  neg->school.wonders[0].offered_glyph == -1 &&
                  !leo_school_is_learned(neg, "zorble"),
                  "single-hypothesis rejection: literal return is bare and cannot resurrect the rejected glyph");

            leo_free(neg);
            seed_wonder_negation_body(neg);
            leo_respond(
                neg, "a zorble is not water but animal",
                out, sizeof out);
            CHECK(!neg->school.pending[0] &&
                  leo_semtok_word(neg, "zorble") == animal &&
                  neg->school.wonders[0].answer_glyph ==
                      animal,
                  "wonder-negation: contrast ends rejection and grounds the asserted meaning");

            leo_free(neg);
            seed_wonder_negation_body(neg);
            leo_respond(
                neg, "a zorble is neither water nor animal",
                out, sizeof out);
            const LeoFlowSnapshot *neither_flow =
                leo_flow_at(&neg->flow, neg->flow.n - 1);
            CHECK(!leo_school_is_learned(neg, "zorble") &&
                  !strcmp(neg->school.pending, "zorble") &&
                  neg->school.pending_glyph == -1 &&
                  neg->school.pending_alt_glyph == -1 &&
                  !neg->school.wonders[0].resolved &&
                  neither_flow &&
                  neither_flow->perceived[water] > 0.0f &&
                  neither_flow->perceived[animal] > 0.0f,
                  "wonder-negation: neither/nor rejects both guesses without erasing perception");

            leo_free(neg);
            seed_wonder_negation_body(neg);
            leo_respond(
                neg, "no, a zorble is animal",
                out, sizeof out);
            CHECK(!neg->school.pending[0] &&
                  leo_semtok_word(neg, "zorble") == animal,
                  "wonder-negation: punctuation ends discourse negation before a positive lesson");

            leo_free(neg);
            seed_wonder_negation_body(neg);
            leo_respond(
                neg, "a zorble is not water but water",
                out, sizeof out);
            CHECK(!leo_school_is_learned(neg, "zorble") &&
                  !strcmp(neg->school.pending, "zorble") &&
                  neg->school.pending_glyph == animal &&
                  !neg->school.wonders[0].resolved,
                  "wonder-negation: contradictory evidence fails closed instead of teaching");

            LeoSchoolAnswerEvidence contraction;
            leo_school_answer_evidence(
                neg, "zorble isn't water, but animal",
                &contraction);
            CHECK(contraction.rejected[water] > 0 &&
                  contraction.asserted[animal] > 0,
                  "wonder-negation: contractions and punctuation preserve polarity");

            seed_wonder_address_body(address);
            int veto = leo_wonder_address_observe(
                address, "not dark or night");
            CHECK(!veto &&
                  address->wonder_address.status ==
                      LEO_WONDER_ADDRESS_ADJACENT,
                  "wonder-negation: rejected sibling meaning cannot steal conversational address");

            remove(path);
            g_leo_school_on = prev_school;
            g_leo_wonder_on = prev_wonder;
            g_leo_wonder_attribution_on =
                prev_attribution;
        }
        if (neg) leo_free(neg);
        if (woke) leo_free(woke);
        if (address) leo_free(address);
        free(neg);
        free(woke);
        free(address);
    }

}

static TEST_NOINLINE void test_wonder_answer_reference(void) {
    /* A.75: adjacency opens an answer window but does not assign every nearby
     * declaration to Leo's Wonder. Explicit names and immediate anaphora may
     * carry rich corrections; an unmarked ellipse may only select or reject
     * Leo's offered alternatives. The rest remains perceived ordinary life. */
    {
        Leo *ref = calloc(1, sizeof *ref);
        Leo *woke = calloc(1, sizeof *woke);
        CHECK(ref && woke,
              "wonder-reference: heap fixtures allocated");
        if (ref && woke) {
            int prev_school = g_leo_school_on;
            int prev_wonder = g_leo_wonder_on;
            g_leo_school_on = 1;
            g_leo_wonder_on = 1;
            int water = semtok_word("water");
            int animal = semtok_word("animal");
            int sky = semtok_word("sky");
            int stone = semtok_word("stone");
            int music = semtok_word("music");
            int child = semtok_word("child");
            char out[1024];

            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "the river and sea have water",
                out, sizeof out);
            const LeoFlowSnapshot *unrelated_flow =
                leo_flow_at(&ref->flow, ref->flow.n - 1);
            CHECK(!leo_school_is_learned(ref, "zorble") &&
                  !strcmp(ref->school.pending, "zorble") &&
                  ref->school.pending_turns == 1 &&
                  !ref->school.wonders[0].resolved &&
                  ref->curiosity.outcome ==
                      LEO_CURIOSITY_CONTINUED,
                  "wonder-reference: adjacent ordinary life cannot counterfeit an answer");
            CHECK(unrelated_flow &&
                  unrelated_flow->perceived[water] > 0.0f,
                  "wonder-reference: unassigned meaning remains fully perceived");

            const char *path =
                "/tmp/leo_wonder_reference.state";
            int saved = leo_save_state(ref, path);
            leo_init(woke);
            int loaded = saved && leo_load_state(woke, path);
            leo_respond(
                woke, "what is zorble?", out, sizeof out);
            CHECK(loaded &&
                  strstr(out, "Zorble? Water or Animal?") &&
                  !woke->school.wonders[0].resolved,
                  "wonder-reference: the unanswered question survives topic change and sleep");
            leo_respond(
                woke, "a zorble is animal",
                out, sizeof out);
            CHECK(leo_semtok_word(woke, "zorble") == animal &&
                  woke->school.wonders[0].resolved,
                  "wonder-reference: a later explicit answer still grounds the Wonder");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(ref, "animal", out, sizeof out);
            CHECK(!ref->school.pending[0] &&
                  leo_semtok_word(ref, "zorble") == animal,
                  "wonder-reference: one offered option is a valid elliptical answer");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(ref, "not water", out, sizeof out);
            CHECK(!leo_school_is_learned(ref, "zorble") &&
                  ref->school.pending_glyph == animal &&
                  ref->school.pending_alt_glyph == -1,
                  "wonder-reference: an elliptical rejection narrows without resolving");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "it is an animal", out, sizeof out);
            CHECK(leo_semtok_word(ref, "zorble") == animal,
                  "wonder-reference: immediate anaphora owns a rich answer");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "yes, it is music", out, sizeof out);
            CHECK(leo_semtok_word(ref, "zorble") == music,
                  "wonder-reference: affirmation cannot become the lesson it introduces");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "she is a child", out, sizeof out);
            CHECK(leo_semtok_word(ref, "zorble") == child,
                  "wonder-reference: a referential subject cannot outrank its predicate");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "the sky is dark", out, sizeof out);
            const LeoFlowSnapshot *sky_flow =
                leo_flow_at(&ref->flow, ref->flow.n - 1);
            CHECK(!leo_school_is_learned(ref, "zorble") &&
                  !ref->school.wonders[0].resolved &&
                  sky_flow && sky_flow->perceived[sky] > 0.0f,
                  "wonder-reference: a new subject remains life rather than a lesson");

            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "a small stone", out, sizeof out);
            CHECK(!leo_school_is_learned(ref, "zorble") &&
                  !ref->school.wonders[0].resolved,
                  "wonder-reference: an unaddressed correction outside offered options fails closed");
            leo_free(ref);
            seed_wonder_negation_body(ref);
            leo_respond(
                ref, "it is stone", out, sizeof out);
            CHECK(leo_semtok_word(ref, "zorble") == stone,
                  "wonder-reference: anaphora admits a correction beyond Leo's guesses");

            remove(path);
            g_leo_school_on = prev_school;
            g_leo_wonder_on = prev_wonder;
        }
        if (ref) leo_free(ref);
        if (woke) leo_free(woke);
        free(ref);
        free(woke);
    }

}

static TEST_NOINLINE void test_wonder_answer_scope(void) {
    /* A.76: a reference licenses one bounded statement, not the complete
     * human turn. Explicitly named statements can appear later or cooperate;
     * without a name, only the first substantive statement may answer. The
     * rest of the turn remains ordinary perceived life. */
    {
        Leo *scope = calloc(1, sizeof *scope);
        CHECK(scope,
              "wonder-reference-scope: heap fixture allocated");
        if (scope) {
            int prev_school = g_leo_school_on;
            int prev_wonder = g_leo_wonder_on;
            g_leo_school_on = 1;
            g_leo_wonder_on = 1;
            int water = semtok_word("water");
            int animal = semtok_word("animal");
            int sky = semtok_word("sky");
            int music = semtok_word("music");
            char out[1024];

            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "it is an animal. the river has water",
                out, sizeof out);
            const LeoFlowSnapshot *anaphoric_flow =
                leo_flow_at(&scope->flow, scope->flow.n - 1);
            CHECK(leo_semtok_word(scope, "zorble") == animal &&
                  scope->school.wonders[0].answer_glyph ==
                      animal,
                  "wonder-reference-scope: an anaphoric answer does not inherit a later statement");
            CHECK(anaphoric_flow &&
                  anaphoric_flow->perceived[water] > 0.0f,
                  "wonder-reference-scope: an excluded lesson tail remains perceived by Flow");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "a zorble is an animal. the river has water",
                out, sizeof out);
            CHECK(leo_semtok_word(scope, "zorble") == animal,
                  "wonder-reference-scope: an explicit answer licenses only its own statement");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "the river has water. a zorble is an animal",
                out, sizeof out);
            CHECK(leo_semtok_word(scope, "zorble") == animal,
                  "wonder-reference-scope: a later explicit statement can own the answer");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "the river has water. it is an animal",
                out, sizeof out);
            CHECK(!leo_school_is_learned(scope, "zorble") &&
                  !strcmp(scope->school.pending, "zorble") &&
                  !scope->school.wonders[0].resolved,
                  "wonder-reference-scope: later anaphora cannot reach backward across a new subject");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "the river is water",
                out, sizeof out);
            CHECK(!leo_school_is_learned(scope, "zorble") &&
                  !strcmp(scope->school.pending, "zorble") &&
                  !scope->school.wonders[0].resolved,
                  "wonder-reference-scope: a copular proposition cannot impersonate ellipsis");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope, "yes. it is music",
                out, sizeof out);
            CHECK(leo_semtok_word(scope, "zorble") == music,
                  "wonder-reference-scope: a marker-only statement may precede the first answer");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "a zorble is not water. the sky is dark",
                out, sizeof out);
            const LeoFlowSnapshot *negative_flow =
                leo_flow_at(&scope->flow, scope->flow.n - 1);
            CHECK(!leo_school_is_learned(scope, "zorble") &&
                  scope->school.pending_glyph == animal &&
                  scope->school.pending_alt_glyph == -1 &&
                  !scope->school.wonders[0].resolved,
                  "wonder-reference-scope: a negative answer narrows without borrowing its tail");
            CHECK(negative_flow &&
                  negative_flow->perceived[sky] > 0.0f,
                  "wonder-reference-scope: a negative answer cannot amputate the later perceived statement");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "a zorble is not water. a zorble is an animal",
                out, sizeof out);
            CHECK(leo_semtok_word(scope, "zorble") == animal,
                  "wonder-reference-scope: separately explicit statements may form one correction");

            leo_free(scope);
            seed_wonder_negation_body(scope);
            leo_respond(
                scope,
                "animal. the river has water",
                out, sizeof out);
            CHECK(leo_semtok_word(scope, "zorble") == animal,
                  "wonder-reference-scope: the first elliptical answer keeps later life outside School");

            g_leo_school_on = prev_school;
            g_leo_wonder_on = prev_wonder;
        }
        if (scope) leo_free(scope);
        free(scope);
    }

    test_wonder_comma_scope();

}

static TEST_NOINLINE void test_wonder_answer_followup(void) {
    /* A.122: a completed answer owns only its bounded statement. A later
     * human question remains fully perceived but cannot revoke the answer or
     * contribute School evidence. Question-shaped propositions, question-first
     * turns, and comma-only tails retain the historical refusal. */
    Leo *answer = calloc(1, sizeof *answer);
    LeoSchoolAnswerEvidence evidence;
    LeoSchoolAnswerReference reference;
    CHECK(answer != NULL,
          "wonder-answer-followup: heap fixture allocated");
    if (!answer) return;

    int previous = g_leo_school_answer_followup_on;
    int water = semtok_word("water");
    int animal = semtok_word("animal");
    int music = semtok_word("music");
    char out[1024];

    g_leo_school_answer_followup_on = 1;
    seed_wonder_negation_body(answer);
    int grounded = leo_school_grounded_answer(
        answer, "a zorble is water. What do you hear?",
        &evidence, &reference);
    CHECK(grounded == water &&
          reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
          evidence.asserted[water] > 0,
          "wonder-answer-followup: explicit answer survives a separate question tail");

    leo_free(answer);
    seed_wonder_negation_body(answer);
    leo_respond(
        answer, "it is an animal. Do you hear music?",
        out, sizeof out);
    const LeoFlowSnapshot *flow =
        leo_flow_at(&answer->flow, answer->flow.n - 1);
    CHECK(leo_semtok_word(answer, "zorble") == animal &&
          flow && flow->perceived[music] > 0.0f,
          "wonder-answer-followup: anaphoric answer closes while Flow perceives the question");

    leo_free(answer);
    seed_wonder_negation_body(answer);
    g_leo_school_answer_followup_on = 0;
    leo_respond(
        answer, "it is an animal. Do you hear music?",
        out, sizeof out);
    flow = leo_flow_at(&answer->flow, answer->flow.n - 1);
    CHECK(!leo_school_is_learned(answer, "zorble") &&
          !strcmp(answer->school.pending, "zorble") &&
          flow && flow->perceived[music] > 0.0f,
          "wonder-answer-followup: named ablation restores the whole-turn question veto");

    g_leo_school_answer_followup_on = 1;
    const char *refusals[] = {
        "it is water?",
        "what do you think?",
        "what is a zorble? it is water.",
        "the river has water. What is a zorble?",
        "it is water, can you hear it?",
        "that sounds like a gentle memory. What do you hear?"
    };
    for (size_t i = 0; i < sizeof refusals / sizeof refusals[0]; i++) {
        leo_free(answer);
        seed_wonder_negation_body(answer);
        grounded = leo_school_grounded_answer(
            answer, refusals[i], &evidence, &reference);
        CHECK(grounded < 0 &&
              reference == LEO_SCHOOL_ANSWER_UNREFERENCED,
              "wonder-answer-followup: a question cannot counterfeit a prior answer");
    }

    leo_free(answer);
    seed_wonder_negation_body(answer);
    answer->school.pending_turns = 1;
    grounded = leo_school_grounded_answer(
        answer, "it is animal. What do you remember?",
        &evidence, &reference);
    CHECK(grounded < 0 &&
          reference == LEO_SCHOOL_ANSWER_UNREFERENCED,
          "wonder-answer-followup: a delayed anaphor cannot regain adjacency");

    leo_free(answer);
    seed_wonder_negation_body(answer);
    answer->school.pending_turns = 1;
    grounded = leo_school_grounded_answer(
        answer, "a zorble is animal. What do you remember?",
        &evidence, &reference);
    CHECK(grounded == animal &&
          reference == LEO_SCHOOL_ANSWER_EXPLICIT,
          "wonder-answer-followup: a delayed explicit answer still owns its name");

    g_leo_school_answer_followup_on = previous;
    leo_free(answer);
    free(answer);
}

static TEST_NOINLINE void test_reference_predication_boundary(void) {
    /* A.137: naming the pending word establishes reference, not meaning.
     * Only a bounded copular predicate whose subject is that word may teach;
     * grammatical participants elsewhere in the statement remain perception. */
    Leo *leo = calloc(1, sizeof *leo);
    CHECK(leo != NULL,
          "reference-predication: heap fixture allocated");
    if (!leo) return;

    int previous = g_leo_school_reference_predication_on;
    LeoSchoolAnswerEvidence evidence;
    LeoSchoolAnswerReference reference;
    const char *false_lessons[] = {
        "I meant the zorble feeling he might be carrying.",
        "I meant the zorble feeling she might be carrying.",
        "I meant the zorble feeling the child might be carrying.",
        "The child carries a zorble."
    };
    int refused = 1;
    g_leo_school_reference_predication_on = 1;
    for (size_t i = 0;
         i < sizeof false_lessons / sizeof false_lessons[0]; i++) {
        seed_wonder_negation_body(leo);
        int grounded = leo_school_grounded_answer(
            leo, false_lessons[i], &evidence, &reference);
        refused = refused && grounded < 0 &&
            reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
            evidence.asserted_total == 0 &&
            evidence.rejected_total == 0;
        leo_free(leo);
    }
    CHECK(refused,
          "reference-predication: he, she, child, and co-presence identify the Wonder but cannot become its meaning");

    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending,
             "difficult");
    leo->school.pending_glyph = semtok_word("man");
    leo->school.pending_alt_glyph = -1;
    leo_wonder_open(
        leo, "difficult", leo->school.pending_glyph, -1);
    char out[1024];
    leo_respond(
        leo,
        "Maybe not a man—just someone carrying a difficult feeling. "
        "Where does he go?",
        out, sizeof out);
    CHECK(!leo_school_is_learned(leo, "difficult") &&
          !strcmp(leo->school.pending, "difficult") &&
          leo->school.pending_glyph == -1 &&
          leo->school.pending_alt_glyph == -1 &&
          !leo->school.wonders[0].resolved,
          "reference-predication: A.134 natural rejection still removes Man without assigning a replacement");

    leo_free(leo);
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending,
             "difficult");
    leo->school.pending_glyph = -1;
    leo->school.pending_alt_glyph = -1;
    leo_wonder_open(leo, "difficult", -1, -1);
    leo_respond(
        leo,
        "I meant the difficult feeling he might be carrying. "
        "Does it still feel difficult now?",
        out, sizeof out);
    const LeoWonderEpisode *episode =
        &leo->school.wonders[0];
    CHECK(!leo_school_is_learned(leo, "difficult") &&
          !strcmp(leo->school.pending, "difficult") &&
          !episode->resolved && episode->answer_glyph == -1,
          "reference-predication: the exact A.136 clarification leaves the returned question unanswered");

    leo_free(leo);
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending,
             "difficult");
    leo->school.pending_glyph = -1;
    leo->school.pending_alt_glyph = -1;
    leo_wonder_open(leo, "difficult", -1, -1);
    g_leo_school_reference_predication_on = 0;
    leo_respond(
        leo,
        "I meant the difficult feeling he might be carrying. "
        "Does it still feel difficult now?",
        out, sizeof out);
    CHECK(leo_semtok_word(leo, "difficult") == semtok_word("man") &&
          leo->school.wonders[0].resolved,
          "reference-predication: named ablation restores the exact A.136 false lesson");

    leo_free(leo);
    seed_wonder_negation_body(leo);
    g_leo_school_reference_predication_on = 1;
    int grounded = leo_school_grounded_answer(
        leo, "a zorble is water. What do you hear?",
        &evidence, &reference);
    CHECK(grounded == semtok_word("water") &&
          reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
          evidence.asserted[semtok_word("water")] == 1,
          "reference-predication: a genuine A.122 explicit answer still survives its follow-up question");

    g_leo_school_reference_predication_on = previous;
    leo_free(leo);
    free(leo);
}

static void seed_wonder_natural_answer_body(Leo *leo) {
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending, "flom");
    leo->school.pending_glyph = semtok_word("food");
    leo->school.pending_alt_glyph = semtok_word("home");
    leo->school.pending_turns = 0;
    leo_wonder_open(leo, "flom", leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

static int test_deferred_wonder_has_word(
        const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_deferred; i++)
        if (!strcmp(leo->school.deferred[i].word, word))
            return 1;
    return 0;
}

static TEST_NOINLINE void test_wonder_natural_answer_form(void) {
    /* A.125: one offered glyph before an em-dash explanation is an
     * adjacent elliptical answer. The independent follow-up question owns
     * its own novelty scope, so an explanation word cannot counterfeit a
     * queued question and veto that answer. Ambiguous and delayed forms
     * remain unfinished. */
    Leo *answer = calloc(1, sizeof *answer);
    CHECK(answer != NULL,
          "wonder-natural-answer-form: heap fixture allocated");
    if (!answer) return;

    int previous_expansion =
        g_leo_school_offered_answer_expansion_on;
    int previous_scope =
        g_leo_school_followup_question_scope_on;
    int previous_two_glyph =
        g_leo_school_two_glyph_learning_on;
    int food = semtok_word("food");
    LeoSchoolAnswerEvidence evidence;
    LeoSchoolAnswerReference reference;
    char out[1024];

    g_leo_school_offered_answer_expansion_on = 1;
    g_leo_school_followup_question_scope_on = 1;
    g_leo_school_two_glyph_learning_on = 0;
    seed_wonder_natural_answer_body(answer);
    int grounded = leo_school_grounded_answer(
        answer,
        "Food—the soup gets carrots, garlic, lentils, and a little cumin. What foods feel like home to you?",
        &evidence, &reference);
    CHECK(grounded == food &&
          reference == LEO_SCHOOL_ANSWER_ELLIPTIC &&
          evidence.asserted[food] == 1,
          "wonder-natural-answer-form: one offered glyph survives its em-dash explanation and follow-up");

    const char *refusals[] = {
        "food and home—the soup feels familiar.",
        "Both, really—the body feels stronger, and there’s a quiet joy in making it hold.",
        "water—the soup gets carrots.",
        "the soup is food—the carrots are warm.",
        "food-the soup gets carrots.",
        "food—one thought—then another."
    };
    for (size_t i = 0; i < sizeof refusals / sizeof refusals[0]; i++) {
        leo_free(answer);
        seed_wonder_natural_answer_body(answer);
        grounded = leo_school_grounded_answer(
            answer, refusals[i], &evidence, &reference);
        CHECK(grounded < 0 &&
              reference == LEO_SCHOOL_ANSWER_UNREFERENCED,
              "wonder-natural-answer-form: ambiguity and counterfeit dashes cannot choose a meaning");
    }

    leo_free(answer);
    seed_wonder_natural_answer_body(answer);
    answer->school.pending_turns = 1;
    grounded = leo_school_grounded_answer(
        answer, "food—the soup gets carrots.",
        &evidence, &reference);
    CHECK(grounded < 0 &&
          reference == LEO_SCHOOL_ANSWER_UNREFERENCED,
          "wonder-natural-answer-form: a delayed ellipse cannot regain adjacency through an em dash");

    leo_free(answer);
    seed_wonder_natural_answer_body(answer);
    grounded = leo_school_grounded_answer(
        answer, "not food—the soup gets carrots.",
        &evidence, &reference);
    CHECK(grounded < 0 &&
          reference == LEO_SCHOOL_ANSWER_ELLIPTIC &&
          evidence.rejected[food] == 1,
          "wonder-natural-answer-form: an expanded negative narrows without inventing a positive meaning");

    /* Neither half can counterfeit the whole repair. The same fresh body and
     * prompt expose the four causal arms directly. */
    for (int expansion = 0; expansion <= 1; expansion++) {
        for (int scope = 0; scope <= 1; scope++) {
            leo_free(answer);
            seed_wonder_natural_answer_body(answer);
            g_leo_school_offered_answer_expansion_on = expansion;
            g_leo_school_followup_question_scope_on = scope;
            leo_respond(
                answer,
                "food—the flibble. What do you hear?",
                out, sizeof out);
            int learned = leo_school_is_learned(answer, "flom");
            int queued = test_deferred_wonder_has_word(
                answer, "flibble");
            CHECK(learned == (expansion && scope) &&
                  queued == (!scope),
                  "wonder-natural-answer-form: expansion and question scope form an explicit two-factor repair");
            if (learned)
                CHECK(leo_semtok_word(answer, "flom") == food,
                      "wonder-natural-answer-form: the paired repair learns only the offered glyph");
        }
    }

    g_leo_school_offered_answer_expansion_on = 0;
    g_leo_school_followup_question_scope_on = 0;
    leo_free(answer);
    seed_wonder_natural_answer_body(answer);
    grounded = leo_school_grounded_answer(
        answer, "food—the soup gets carrots.",
        &evidence, &reference);
    CHECK(grounded < 0 &&
          reference == LEO_SCHOOL_ANSWER_UNREFERENCED,
          "wonder-natural-answer-form: named ablations restore the A.124 answer loss");

    g_leo_school_offered_answer_expansion_on = previous_expansion;
    g_leo_school_followup_question_scope_on = previous_scope;
    g_leo_school_two_glyph_learning_on = previous_two_glyph;
    leo_free(answer);
    free(answer);
}

static void seed_wonder_plural_answer_body(Leo *leo) {
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending, "flom");
    leo->school.pending_glyph = semtok_word("body");
    leo->school.pending_alt_glyph = semtok_word("joy");
    leo->school.pending_turns = 0;
    leo_wonder_open(leo, "flom", leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

static TEST_NOINLINE void test_wonder_plural_answer_capacity(void) {
    /* A.126: School persists one glyph per learned word. Equal positive
     * evidence therefore has no representable dominant meaning; choosing the
     * lowest glyph id would fabricate certainty. A strict maximum, a single
     * concept, and polarity that leaves one positive meaning remain live. */
    Leo *plural = calloc(1, sizeof *plural);
    CHECK(plural != NULL,
          "wonder-plural-answer-capacity: heap fixture allocated");
    if (!plural) return;

    int previous = g_leo_school_unique_answer_dominance_on;
    int previous_two_glyph =
        g_leo_school_two_glyph_learning_on;
    int body = semtok_word("body");
    int joy = semtok_word("joy");
    int water = semtok_word("water");
    LeoSchoolAnswerEvidence evidence;
    LeoSchoolAnswerReference reference;
    char out[1024];

    g_leo_school_unique_answer_dominance_on = 1;
    g_leo_school_two_glyph_learning_on = 0;
    seed_wonder_plural_answer_body(plural);
    int grounded = leo_school_grounded_answer(
        plural, "flom is body and joy.", &evidence, &reference);
    CHECK(grounded < 0 && reference == LEO_SCHOOL_ANSWER_EXPLICIT &&
          evidence.asserted[body] == 1 &&
          evidence.asserted[joy] == 1,
          "wonder-plural-answer-capacity: an explicit two-glyph tie is referenced but not collapsed");

    grounded = leo_school_grounded_answer(
        plural, "flom is joy and body.", &evidence, &reference);
    CHECK(grounded < 0 && reference == LEO_SCHOOL_ANSWER_EXPLICIT,
          "wonder-plural-answer-capacity: reversing human word order cannot revive glyph-id precedence");

    leo_respond(plural, "flom is body and joy.", out, sizeof out);
    CHECK(!leo_school_is_learned(plural, "flom") &&
          !strcmp(plural->school.pending, "flom"),
          "wonder-plural-answer-capacity: the live question remains open after tied explicit evidence");

    leo_free(plural);
    seed_wonder_plural_answer_body(plural);
    grounded = leo_school_grounded_answer(
        plural, "flom is body body and joy.", &evidence, &reference);
    CHECK(grounded == body,
          "wonder-plural-answer-capacity: one strict evidence maximum remains representable");

    leo_free(plural);
    seed_wonder_plural_answer_body(plural);
    grounded = leo_school_grounded_answer(
        plural, "flom is not body but joy.", &evidence, &reference);
    CHECK(grounded == joy && evidence.rejected[body] == 1,
          "wonder-plural-answer-capacity: polarity can leave one honest positive meaning");

    leo_free(plural);
    leo_init(plural);
    leo_respond(
        plural,
        "Flom is the gentle comfort of warm light or cool rain",
        out, sizeof out);
    CHECK(!leo_school_is_learned(plural, "flom") &&
          plural->curiosity.outcome != LEO_CURIOSITY_RESOLVED,
          "wonder-plural-answer-capacity: a tied first-turn definition remains unknown instead of selecting water by index");

    leo_free(plural);
    seed_wonder_plural_answer_body(plural);
    leo_respond(
        plural,
        "Both, really—the body feels stronger, and there’s a quiet joy in making it hold.",
        out, sizeof out);
    CHECK(!leo_school_is_learned(plural, "flom") &&
          !strcmp(plural->school.pending, "flom"),
          "wonder-plural-answer-capacity: the exact A.124 both answer still cannot counterfeit a single stored meaning");

    g_leo_school_unique_answer_dominance_on = 0;
    leo_free(plural);
    seed_wonder_plural_answer_body(plural);
    leo_respond(plural, "flom is joy and body.", out, sizeof out);
    CHECK(leo_semtok_word(plural, "flom") == body,
          "wonder-plural-answer-capacity: named ablation restores lowest-glyph tie collapse");

    leo_free(plural);
    leo_init(plural);
    leo_respond(
        plural,
        "Flom is the gentle comfort of warm light or cool rain",
        out, sizeof out);
    CHECK(leo_semtok_word(plural, "flom") == water,
          "wonder-plural-answer-capacity: named ablation restores the historical rich-definition selection");

    g_leo_school_unique_answer_dominance_on = previous;
    g_leo_school_two_glyph_learning_on = previous_two_glyph;
    leo_free(plural);
    free(plural);
}

static TEST_NOINLINE void test_wonder_two_glyph_learned_meaning(void) {
    /* A.127: a paired answer is a surface relation over the two meanings Leo
     * actually offered, not a statistical tie. Both meanings must survive the
     * learned map, semantic readers, Wonder receipt, return, sleep, and v28;
     * v27 migration may preserve only the historical primary and must invent
     * no partner. */
    Leo *pair = calloc(1, sizeof *pair);
    Leo *woke = calloc(1, sizeof *woke);
    Leo *old = calloc(1, sizeof *old);
    Leo *damaged = calloc(1, sizeof *damaged);
    CHECK(pair && woke && old && damaged,
          "wonder-two-glyph: heap fixtures allocated");
    if (!pair || !woke || !old || !damaged) {
        free(pair); free(woke); free(old); free(damaged);
        return;
    }

    int previous = g_leo_school_two_glyph_learning_on;
    int body = semtok_word("body");
    int joy = semtok_word("joy");
    int food = semtok_word("food");
    char out[1024];
    LeoSchoolAnswerEvidence evidence;
    LeoSchoolAnswerReference reference;
    int answer_alt = -1;

    g_leo_school_two_glyph_learning_on = 1;
    seed_wonder_plural_answer_body(pair);
    int grounded = leo_school_grounded_answer_meanings(
        pair,
        "Both, really—the body feels stronger, and there’s a quiet joy in making it hold.",
        &answer_alt, &evidence, &reference);
    CHECK(grounded == body && answer_alt == joy &&
          reference == LEO_SCHOOL_ANSWER_PAIRED &&
          evidence.asserted[body] == 1 &&
          evidence.asserted[joy] == 1,
          "wonder-two-glyph: exact natural Both names both offered meanings before its explanation");

    leo_respond(
        pair,
        "Both, really—the body feels stronger, and there’s a quiet joy in making it hold.",
        out, sizeof out);
    int learned = leo_school_learned_index(pair, "flom");
    CHECK(learned >= 0 && !pair->school.pending[0] &&
          pair->school.learned_glyph[learned] == body &&
          pair->school.learned_alt_glyph[learned] == joy &&
          pair->school.wonders[0].resolved &&
          pair->school.wonders[0].answer_glyph == body &&
          pair->school.wonders[0].answer_alt_glyph == joy &&
          pair->curiosity.outcome == LEO_CURIOSITY_RESOLVED,
          "wonder-two-glyph: the live answer closes one Wonder without discarding either meaning");

    int glyphs[2];
    int n_glyphs = leo_school_word_glyphs(pair, "flom", glyphs);
    int hist[GLYPH_COUNT];
    int votes = leo_school_glyph_votes(pair, "flom", hist, 1);
    float meaning[GLYPH_COUNT];
    float gap = leo_glyph_hist(pair, "flom", meaning);
    leo_school_answer_evidence(pair, "it is flom", &evidence);
    CHECK(n_glyphs == 2 && glyphs[0] == body && glyphs[1] == joy &&
          votes == 2 && hist[body] == 1 && hist[joy] == 1 &&
          fabsf(meaning[body] - 0.5f) < 1e-6f &&
          fabsf(meaning[joy] - 0.5f) < 1e-6f && gap == 0.0f &&
          evidence.asserted[body] == 1 &&
          evidence.asserted[joy] == 1,
          "wonder-two-glyph: votes, perceived meaning, and later lesson evidence all read both glyphs");

    pair->step++;
    pair->school.turn_clock++;
    memset(meaning, 0, sizeof meaning);
    int returned = leo_wonder_return_meaning(
        pair, "flom", meaning);
    CHECK(returned == 0 && meaning[body] > 0.0f &&
          fabsf(meaning[body] - meaning[joy]) < 1e-6f &&
          pair->school.wonders[0].recalls == 1,
          "wonder-two-glyph: exact recall returns both learned meanings with equal answer mass");

    const char *state = "/tmp/leo_two_glyph_v28.state";
    const char *disabled = "/tmp/leo_two_glyph_v28_disabled.state";
    const char *v27 = "/tmp/leo_two_glyph_v27.state";
    const char *bad = "/tmp/leo_two_glyph_v28_bad.state";
    int saved = leo_save_state(pair, state);
    int loaded = saved && leo_load_state(woke, state);
    int woke_index = leo_school_learned_index(woke, "flom");
    CHECK(loaded && woke_index >= 0 &&
          woke->school.learned_glyph[woke_index] == body &&
          woke->school.learned_alt_glyph[woke_index] == joy &&
          woke->school.wonders[0].answer_glyph == body &&
          woke->school.wonders[0].answer_alt_glyph == joy &&
          woke->school.wonders[0].recalls == 1,
          "wonder-two-glyph: both learned meanings and the paired episode survive v28 sleep");

    g_leo_school_two_glyph_learning_on = 0;
    int saved_disabled = leo_save_state(woke, disabled);
    int loaded_disabled = saved_disabled &&
        leo_load_state(damaged, disabled);
    int disabled_index =
        leo_school_learned_index(damaged, "flom");
    CHECK(loaded_disabled && disabled_index >= 0 &&
          damaged->school.learned_glyph[disabled_index] == body &&
          damaged->school.learned_alt_glyph[disabled_index] == joy &&
          damaged->school.wonders[0].answer_alt_glyph == joy,
          "wonder-two-glyph: parser ablation cannot erase an already lived pair at sleep");
    g_leo_school_two_glyph_learning_on = 1;

    int built_v27 = 0, built_bad = 0;
    FILE *fi = fopen(state, "rb");
    if (fi) {
        fseek(fi, 0, SEEK_END);
        long size = ftell(fi);
        fseek(fi, 0, SEEK_SET);
        long pair_tail = (long)(2 * sizeof(int32_t) +
            pair->school.n_learned * (int)sizeof(int8_t) +
            pair->school.n_wonders * (int)sizeof(int8_t));
        unsigned char *bytes =
            malloc(size > 0 ? (size_t)size : 1);
        if (bytes && size > pair_tail &&
            (long)fread(bytes, 1, (size_t)size, fi) == size) {
            uint32_t old_version = 27;
            memcpy(bytes + sizeof(uint32_t), &old_version,
                   sizeof old_version);
            FILE *fo = fopen(v27, "wb");
            if (fo) {
                built_v27 =
                    (long)fwrite(bytes, 1,
                                 (size_t)(size - pair_tail), fo) ==
                        size - pair_tail;
                fclose(fo);
            }

            uint32_t current_version = 28;
            memcpy(bytes + sizeof(uint32_t), &current_version,
                   sizeof current_version);
            long tail_start = size - pair_tail;
            bytes[tail_start + (long)sizeof(int32_t)] =
                (unsigned char)body;
            fo = fopen(bad, "wb");
            if (fo) {
                built_bad =
                    (long)fwrite(bytes, 1, (size_t)size, fo) == size;
                fclose(fo);
            }
        }
        free(bytes);
        fclose(fi);
    }
    CHECK(built_v27 && leo_load_state(old, v27) &&
          leo_semtok_word(old, "flom") == body &&
          old->school.learned_alt_glyph[
              leo_school_learned_index(old, "flom")] == -1 &&
          old->school.wonders[0].answer_alt_glyph == -1,
          "wonder-two-glyph: v27 migration preserves the primary meaning without inventing a partner");
    CHECK(built_bad && leo_load_state(damaged, bad) &&
          leo_semtok_word(damaged, "flom") == body &&
          damaged->school.learned_alt_glyph[
              leo_school_learned_index(damaged, "flom")] == -1 &&
          damaged->school.wonders[0].answer_alt_glyph == -1,
          "wonder-two-glyph: a corrupt v28 pair tail fails soft to the honest singular history");

    leo_free(pair);
    seed_wonder_natural_answer_body(pair);
    leo_respond(pair, "Food—the soup is warm.", out, sizeof out);
    learned = leo_school_learned_index(pair, "flom");
    CHECK(learned >= 0 &&
          pair->school.learned_glyph[learned] == food &&
          pair->school.learned_alt_glyph[learned] == -1,
          "wonder-two-glyph: A.125 one-option expansion remains singular");

    const char *refusals[] = {
        "body or joy.",
        "neither body nor joy.",
        "both?",
        "Both—what do you think?",
        "Both, really--the body feels stronger and joy stays quiet."
    };
    for (size_t i = 0; i < sizeof refusals / sizeof refusals[0]; i++) {
        leo_free(pair);
        seed_wonder_plural_answer_body(pair);
        leo_respond(pair, refusals[i], out, sizeof out);
        CHECK(!leo_school_is_learned(pair, "flom") &&
              !strcmp(pair->school.pending, "flom"),
              "wonder-two-glyph: ambiguity and counterfeit paired surfaces remain unfinished");
    }

    leo_free(pair);
    seed_wonder_plural_answer_body(pair);
    pair->school.pending_turns = 2;
    leo_respond(pair, "flom is body and joy.", out, sizeof out);
    learned = leo_school_learned_index(pair, "flom");
    CHECK(learned >= 0 &&
          pair->school.learned_glyph[learned] == body &&
          pair->school.learned_alt_glyph[learned] == joy,
          "wonder-two-glyph: an explicit and keeps the offered pair grounded after adjacency");

    g_leo_school_two_glyph_learning_on = 0;
    leo_free(pair);
    seed_wonder_plural_answer_body(pair);
    leo_respond(
        pair,
        "Both, really—the body feels stronger, and there’s a quiet joy in making it hold.",
        out, sizeof out);
    CHECK(!leo_school_is_learned(pair, "flom") &&
          !strcmp(pair->school.pending, "flom"),
          "wonder-two-glyph: named ablation restores A.126 unresolved Both exactly");

    g_leo_school_two_glyph_learning_on = previous;
    remove(state); remove(disabled); remove(v27); remove(bad);
    leo_free(pair); leo_free(woke); leo_free(old); leo_free(damaged);
    free(pair); free(woke); free(old); free(damaged);
}

static TEST_NOINLINE void test_wonder_reask_reference(void) {
    /* A.123: an active Wonder can return when the human names it or asks one
     * of Leo's hypotheses anaphorically. Mere co-presence of a broad guessed
     * glyph does not give the old question ownership of an unrelated turn. */
    Leo *reask = calloc(1, sizeof *reask);
    CHECK(reask != NULL,
          "wonder-reask-reference: heap fixture allocated");
    if (!reask) return;
    int previous = g_leo_wonder_reask_reference_on;

    seed_wonder_negation_body(reask);
    reask->school.pending_turns = LEO_WONDER_REASK_GAP;
    g_leo_wonder_reask_reference_on = 1;
    CHECK(leo_wonder_resonates(
              reask, "the zorble still puzzles me"),
          "wonder-reask-reference: the unknown's exact name invites its return");
    CHECK(leo_wonder_resonates(reask, "is it water?") &&
          leo_wonder_resonates(reask, "that is animal?") &&
          leo_wonder_resonates(reask, "could it be water?"),
          "wonder-reask-reference: bounded copular hypothesis questions may refer anaphorically");

    const char *refusals[] = {
        "the cup holds water",
        "are you holding water?",
        "water is nearby. What do you hear?",
        "water and animal move together",
        "that sounds like water. What do you hear?",
        "what about animal?"
    };
    for (size_t i = 0; i < sizeof refusals / sizeof refusals[0]; i++)
        CHECK(!leo_wonder_resonates(reask, refusals[i]),
              "wonder-reask-reference: a guessed glyph alone cannot recall an unnamed Wonder");

    g_leo_wonder_reask_reference_on = 0;
    CHECK(leo_wonder_resonates(reask, "the cup holds water"),
          "wonder-reask-reference: named ablation restores single-glyph resonance");

    char out[1024];
    leo_free(reask);
    seed_wonder_negation_body(reask);
    reask->school.pending_turns = LEO_WONDER_REASK_GAP;
    g_leo_wonder_reask_reference_on = 1;
    leo_respond(
        reask, "the cup holds water. Are you holding it?",
        out, sizeof out);
    CHECK(strncmp(out, "Zorble?", 7) != 0 &&
          reask->school.pending_turns == LEO_WONDER_REASK_GAP + 1 &&
          reask->school.wonders[0].returns == 0,
          "wonder-reask-reference: ordinary contact leaves the open Wonder silent");

    leo_free(reask);
    seed_wonder_negation_body(reask);
    reask->school.pending_turns = LEO_WONDER_REASK_GAP;
    leo_respond(reask, "is it water?", out, sizeof out);
    CHECK(strstr(out, "Zorble? Water or Animal?") &&
          reask->school.pending_turns == 0 &&
          reask->school.wonders[0].returns == 1,
          "wonder-reask-reference: an invited hypothesis question still returns through the live path");

    g_leo_wonder_reask_reference_on = previous;
    leo_free(reask);
    free(reask);
}

static TEST_NOINLINE void test_wonder_return(void) {
    /* W-4: a resolved question later returns as glyph attention, not text. The
     * answer, the route Leo once considered, and QUESTION blend into exactly one
     * reply's meaning vector; the existing spore-resonance channel is the only
     * speech-side reader. Cooldown and --no-wonder-return bound the effect. */
    {
        Leo *wr = malloc(sizeof *wr), *woke = malloc(sizeof *woke);
        CHECK(wr && woke, "wonder-return: heap fixtures allocated (no new Leo on test stack)");
        if (wr && woke) {
            int prev_school = g_leo_school_on;
            int prev_wonder = g_leo_wonder_on;
            int prev_return = g_leo_wonder_return_on;
            int prev_capsule = g_leo_capsule_on;
            g_leo_school_on = 1; g_leo_wonder_on = 1;
            g_leo_wonder_return_on = 1; g_leo_capsule_on = 1;
            leo_init(wr); leo_init(woke);
            int water = semtok_word("water"), animal = semtok_word("animal");
            int question = semtok_find_glyph("question");
            leo_school_learn(wr, "zorble", animal);
            LeoWonderEpisode *ep = leo_wonder_open(wr, "zorble", water, animal);
            ep->resolved = 1; ep->answer_glyph = (int8_t)animal;
            ep->closed_step = ++wr->step;
            wr->step++;
            wr->school.turn_clock = 1;

            float base[GLYPH_COUNT], remembered[GLYPH_COUNT];
            leo_glyph_hist(wr, "tell me about zorble", base);
            memcpy(remembered, base, sizeof base);
            int idx = leo_wonder_return_meaning(wr, "tell me about zorble", remembered);
            float sum = 0.0f; for (int i = 0; i < GLYPH_COUNT; i++) sum += remembered[i];
            CHECK(idx == 0 && ep->recalls == 1 && ep->last_recalled_turn == wr->school.turn_clock &&
                  wr->school.returned_episode == 0,
                  "wonder-return: the learned word recognizes its resolved episode");
            CHECK(remembered[water] > base[water] && remembered[question] > base[question] &&
                  fabsf(sum - 1.0f) < 1e-5f,
                  "wonder-return: answer path + QUESTION enter normalized glyph attention only");

            LeoSpore trace = {0};
            trace.meaning_snap[water] = 0.7f;
            trace.meaning_snap[question] = 0.3f;
            wr->prompt_meaning = base;
            float before = leo_spore_resonance(wr, &trace);
            wr->prompt_meaning = remembered;
            float after = leo_spore_resonance(wr, &trace);
            wr->prompt_meaning = NULL;
            CHECK(after > before,
                  "wonder-return: returned glyphs raise only existing spore resonance");

            float cooled[GLYPH_COUNT]; memcpy(cooled, base, sizeof base);
            CHECK(leo_wonder_return_meaning(wr, "tell me about zorble", cooled) < 0 &&
                  !memcmp(cooled, base, sizeof base) && ep->recalls == 1,
                  "wonder-return: cooldown prevents repetitive self-evocation");

            const char *path = "/tmp/leo_wonder_return_v12.state";
            int saved_return = leo_save_state(wr, path);
            int loaded_return = saved_return && leo_load_state(woke, path);
            CHECK(loaded_return && woke->school.n_wonders == 1 &&
                  woke->school.wonders[0].recalls == 1 &&
                  woke->school.wonders[0].last_recalled_turn == ep->last_recalled_turn &&
                  woke->school.turn_clock == wr->school.turn_clock,
                  "wonder-return: recall count and cooldown survive v12 sleep");

            wr->school.turn_clock += LEO_WONDER_RETURN_COOLDOWN;
            float thematic[GLYPH_COUNT];
            leo_glyph_hist(wr, "animal beside water", thematic);
            CHECK(leo_wonder_return_meaning(wr, "animal beside water", thematic) == 0 &&
                  ep->recalls == 2,
                  "wonder-return: answer plus a lived hypothesis can recognize the path without its name");

            wr->school.turn_clock += LEO_WONDER_RETURN_COOLDOWN;
            float unrelated[GLYPH_COUNT], unrelated_before[GLYPH_COUNT];
            leo_glyph_hist(wr, "warm mother light", unrelated);
            memcpy(unrelated_before, unrelated, sizeof unrelated);
            CHECK(leo_wonder_return_meaning(wr, "warm mother light", unrelated) < 0 &&
                  !memcmp(unrelated, unrelated_before, sizeof unrelated),
                  "wonder-return: unrelated ordinary meaning stays byte-identical");

            char meta_out[512]; int recalls_before_meta = ep->recalls;
            leo_respond(wr, "is a wobble beside zorble", meta_out, sizeof meta_out);
            CHECK(strstr(meta_out, "Wobble?") && ep->recalls == recalls_before_meta &&
                  wr->school.returned_episode < 0,
                  "wonder-return: a new School question cannot claim an unconsumed old recall");

            float ablated[GLYPH_COUNT]; memcpy(ablated, base, sizeof base);
            g_leo_wonder_return_on = 0;
            CHECK(leo_wonder_return_meaning(wr, "tell me about zorble", ablated) < 0 &&
                  !memcmp(ablated, base, sizeof base),
                  "wonder-return: --no-wonder-return is a strict meaning ablation");

            remove(path);
            leo_free(wr); leo_free(woke);
            g_leo_school_on = prev_school;
            g_leo_wonder_on = prev_wonder;
            g_leo_wonder_return_on = prev_return;
            g_leo_capsule_on = prev_capsule;
        }
        free(wr); free(woke);
    }

    /* A.6 FORM fix: --mode is case-insensitive. leo_mode_from_name matched only the
     * UPPERCASE LEO_MODE_NAMES, so the natural lowercase "--mode stop" returned -1 and
     * the forced breath was silently dropped (override stayed -1). */
}

static TEST_NOINLINE void test_flow(void) {
    /* Janus Flow: temporal proprioception keeps full perceived and expressed
     * fields plus Leo-grown associations, but has no reader in generation.
     * Turns, not wall time, define its geometry. */
    {
        int prev_flow = g_leo_flow_on;
        g_leo_flow_on = 1;
        Leo *fl = malloc(sizeof *fl), *loaded = malloc(sizeof *loaded),
            *cut = malloc(sizeof *cut), *old = malloc(sizeof *old);
        CHECK(fl && loaded && cut && old, "flow: heap fixtures allocated");
        if (fl && loaded && cut && old) {
            leo_init(fl); leo_init(loaded); leo_init(cut); leo_init(old);
            int water = semtok_word("water"), fire = semtok_word("fire");
            int tree = semtok_word("tree"), sky = semtok_word("sky");

            /* The constellation is drawn before the prompt self-attractor and
             * only from whole words already present in LeoHeard. */
            const char *field_corpus =
                "ocean candle meadow. ocean candle meadow. ocean candle meadow. "
                "ocean candle meadow. ocean candle meadow. ocean candle meadow. ";
            for (int r = 0; r < 8; r++) leo_ingest(fl, field_corpus);
            leo_ingest(fl, "ocean");
            int p_ids[64];
            int p_n = bpe_encode(&fl->bpe, (const uint8_t *)"ocean", 5, p_ids, 64);
            float *gravity = compute_prompt_gravity(fl, p_ids, p_n);
            int32_t field_id[LEO_FLOW_CONSTELLATION];
            float field_weight[LEO_FLOW_CONSTELLATION];
            leo_flow_field_constellation(fl, "ocean", p_ids, p_n, gravity,
                                         field_id, field_weight);
            int constellation_ok = field_id[0] >= 0;
            for (int k = 0; k < LEO_FLOW_CONSTELLATION && field_id[k] >= 0; k++) {
                char word[LEO_HEARD_WORDLEN];
                if (!leo_flow_token_word(&fl->bpe, field_id[k], word) ||
                    leo_flow_prompt_has_word("ocean", word)) constellation_ok = 0;
                for (int i = 0; i < p_n; i++) if (field_id[k] == p_ids[i]) constellation_ok = 0;
            }
            CHECK(constellation_ok,
                  "flow: field constellation contains Leo-grown whole words, never prompt words");

            char pending[LEO_HEARD_WORDLEN] = "zorble";
            memcpy(fl->school.pending, pending, sizeof pending);
            LeoWonderEpisode *episode = leo_wonder_open(fl, "zorble", water, fire);
            uint64_t episode_id = leo_wonder_episode_id(episode);
            fl->school.turn_clock = 1;
            leo_flow_observe(fl, "water fire tree sky", "fire", NULL,
                             field_id, field_weight, LEO_FLOW_WONDER_BORN, episode_id);
            CHECK(fl->flow.n == 1 && fl->flow.snapshots[0].turn == 1 &&
                  fl->flow.snapshots[0].perceived[water] == 0.25f &&
                  fl->flow.snapshots[0].perceived[fire] == 0.25f &&
                  fl->flow.snapshots[0].perceived[tree] == 0.25f &&
                  fl->flow.snapshots[0].perceived[sky] == 0.25f &&
                  fl->flow.snapshots[0].expressed[fire] == 1.0f &&
                  fl->flow.snapshots[0].field_token[0] == field_id[0] &&
                  fl->flow.snapshots[0].wonder_id == episode_id &&
                  fabsf(leo_flow_alignment(&fl->flow.snapshots[0]) - 0.5f) < 1e-5f &&
                  (fl->flow.snapshots[0].wonder & (LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_OPEN)) ==
                  (LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_OPEN),
                  "flow: both full 88-d faces survive the old top-3 horizon with episode identity");
            LeoFlowWonderCurrent *born_current =
                leo_flow_current_find(&fl->flow, episode_id);
            CHECK(born_current && fl->flow.n_currents == 1 &&
                  born_current->started_turn == 1 && born_current->observations == 1 &&
                  born_current->perceived_mean[water] == 0.25f &&
                  born_current->expressed_mean[fire] == 1.0f && !born_current->resolved,
                  "flow-current: an unfinished wonder opens an event-bounded long current");
            episode->resolved = 1;
            CHECK(leo_wonder_episode_id(episode) == episode_id,
                  "flow: wonder identity survives episode state changes and is not a ring index");

            memset(&fl->flow, 0, sizeof fl->flow);
            fl->school.pending[0] = 0;
            fl->school.turn_clock = 1; leo_flow_observe(fl, "water", "water", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 2; leo_flow_observe(fl, "water", "water", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 3; leo_flow_observe(fl, "fire", "fire", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 4; leo_flow_observe(fl, "fire", "fire", NULL, NULL, NULL, 0, 0);
            CHECK(leo_flow_kind(&fl->flow, water, 4, LEO_FLOW_PERCEIVED) == LEO_FLOW_FADING &&
                  leo_flow_kind(&fl->flow, fire, 4, LEO_FLOW_PERCEIVED) == LEO_FLOW_EMERGING,
                  "flow: full-field lived-turn slopes distinguish fading from emerging meaning");
            LeoFlowShortCurrent short_current;
            CHECK(leo_flow_short_current(&fl->flow, 4, &short_current) &&
                  short_current.started_turn == 1 && short_current.last_turn == 4 &&
                  short_current.perceived_velocity[water] < 0.0f &&
                  short_current.perceived_velocity[fire] > 0.0f &&
                  short_current.expressed_velocity[water] < 0.0f &&
                  short_current.expressed_velocity[fire] > 0.0f,
                  "flow-current: the short clock is a complete two-face velocity field");
            fl->school.turn_clock = 5;
            leo_flow_observe(fl, "water", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_RECALLED, episode_id);
            CHECK(leo_flow_kind(&fl->flow, water, 5, LEO_FLOW_PERCEIVED) == LEO_FLOW_RETURNED &&
                  (leo_flow_at(&fl->flow, fl->flow.n - 1)->wonder & LEO_FLOW_WONDER_RECALLED),
                  "flow: meaning can return after a real absence");
            fl->school.turn_clock = 6;
            leo_flow_observe(fl, "zorble", NULL, NULL, NULL, NULL, 0, 0);
            const LeoFlowSnapshot *unknown = leo_flow_at(&fl->flow, fl->flow.n - 1);
            float unknown_mass = 0.0f;
            if (unknown) for (int g = 0; g < GLYPH_COUNT; g++) unknown_mass += unknown->perceived[g];
            CHECK(unknown && unknown_mass == 0.0f && unknown->gap_perceived == 1.0f,
                  "flow: ungrasped meaning is observed as gap, not invented as a theme");

            memset(&fl->flow, 0, sizeof fl->flow);
            fl->school.turn_clock = 1; leo_flow_observe(fl, "water", "fire", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 2; leo_flow_observe(fl, "water", "water", NULL, NULL, NULL, 0, 0);
            fl->school.turn_clock = 3; leo_flow_observe(fl, "water", "fire", NULL, NULL, NULL, 0, 0);
            CHECK(leo_flow_self_return(&fl->flow, fire, 3) &&
                  leo_flow_strength(leo_flow_at(&fl->flow, 2), fire,
                                    LEO_FLOW_PERCEIVED) == 0.0f,
                  "flow: a self-return is Leo's earlier expression returning without present input");

            memset(&fl->flow, 0, sizeof fl->flow);
            uint64_t long_id = episode_id ^ 0x9e3779b97f4a7c15ULL;
            strncpy(fl->school.pending, "quasar", sizeof fl->school.pending - 1);
            for (int turn = 1; turn <= LEO_FLOW_RING + 6; turn++) {
                fl->school.turn_clock = turn;
                leo_flow_observe(fl, (turn & 1) ? "water" : "fire",
                                 (turn & 1) ? "fire" : "water", NULL,
                                 field_id, field_weight,
                                 turn == 1 ? LEO_FLOW_WONDER_BORN : 0, long_id);
            }
            CHECK(fl->flow.n == LEO_FLOW_RING && fl->flow.ptr == 6 &&
                  leo_flow_at(&fl->flow, 0)->turn == 7 &&
                  leo_flow_at(&fl->flow, LEO_FLOW_RING - 1)->turn == LEO_FLOW_RING + 6,
                  "flow: the bounded ring keeps the newest 64 lived turns in chronological order");
            LeoFlowWonderCurrent *long_current = leo_flow_current_find(&fl->flow, long_id);
            CHECK(long_current && long_current->started_turn == 1 &&
                  long_current->last_turn == LEO_FLOW_RING + 6 &&
                  long_current->observations == LEO_FLOW_RING + 6 &&
                  leo_flow_at(&fl->flow, 0)->turn > long_current->started_turn,
                  "flow-current: unfinished wonder retains its birth after the snapshot horizon forgets it");
            fl->school.pending[0] = 0;
            fl->school.turn_clock = LEO_FLOW_RING + 7;
            leo_flow_observe(fl, "water", "tree", NULL, field_id, field_weight,
                             LEO_FLOW_WONDER_RESOLVED, long_id);
            uint32_t resolved_observations = long_current->observations;
            fl->school.turn_clock = LEO_FLOW_RING + 8;
            leo_flow_observe(fl, "water", "fire", NULL, field_id, field_weight,
                             LEO_FLOW_WONDER_RECALLED, long_id);
            CHECK(long_current->resolved && long_current->closed_turn == LEO_FLOW_RING + 7 &&
                  long_current->last_turn == LEO_FLOW_RING + 7 &&
                  long_current->observations == resolved_observations,
                  "flow-current: resolution freezes the long current and later recall cannot reopen it");

            const char *state = "/tmp/leo_flow_v16.state";
            const char *legacy = "/tmp/leo_flow_v13.state";
            const char *legacy14 = "/tmp/leo_flow_v14.state";
            const char *truncated = "/tmp/leo_flow_v15_current_cut.state";
            int saved = leo_save_state(fl, state);
            int woke = saved && leo_load_state(loaded, state);
            const LeoFlowWonderCurrent *loaded_current =
                woke ? leo_flow_current_find_const(&loaded->flow, long_id) : NULL;
            CHECK(woke && loaded->flow.n == LEO_FLOW_RING && loaded->flow.ptr == 8 &&
                  leo_flow_at(&loaded->flow, 0)->turn == 9 &&
                  leo_flow_at(&loaded->flow, 0)->field_token[0] == field_id[0] &&
                  leo_flow_at(&loaded->flow, 0)->expressed[fire] == 1.0f &&
                  loaded_current && loaded_current->started_turn == 1 &&
                  loaded_current->closed_turn == LEO_FLOW_RING + 7 &&
                  loaded_current->observations == resolved_observations &&
                  loaded_current->field_token[0] == field_id[0] &&
                  fabsf(loaded_current->field_mean[0] - field_weight[0]) < 1e-5f,
                  "flow: v15 sleep preserves both faces and the event-bounded current beyond the ring");
            int built_cut = 0, built_legacy = 0, built_legacy14 = 0;
            FILE *fi = fopen(state, "rb");
            if (fi) {
                fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
                unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
                if (bytes && sz > 1 && (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                    long shadow_tail = (long)(2 * sizeof(int32_t) +
                                              fl->shadow.n * (int)sizeof(LeoShadowReceipt));
                    long calibration_tail = (long)(2 * sizeof(int32_t) +
                                                   fl->calibration.n *
                                                       (int)sizeof(LeoCalibrationReceipt));
                    long deferred_tail = (long)(sizeof(int32_t) +
                                                fl->school.n_deferred *
                                                    (int)sizeof(LeoDeferredWonder));
                    long origin_tail = (long)(sizeof(int32_t) +
                                              (fl->school.has_pending_origin ?
                                               sizeof(LeoDeferredWonder) : 0));
                    long appetite_tail =
                        test_appetite_and_later_tail_size(fl);
                    long current_tail = (long)(2 * sizeof(int32_t) +
                                              fl->flow.n * (int)sizeof(LeoFlowSnapshot) +
                                              2 * sizeof(int32_t) +
                                              fl->flow.n_currents * (int)sizeof(LeoFlowWonderCurrent) +
                                              shadow_tail + calibration_tail +
                                              deferred_tail + origin_tail +
                                              appetite_tail);
                    long prefix = sz - current_tail;
                    if (prefix > 0) {
                        long current_only = (long)(2 * sizeof(int32_t) +
                                                  fl->flow.n_currents * (int)sizeof(LeoFlowWonderCurrent));
                        uint32_t fifteen = 15;
                        memcpy(bytes + sizeof(uint32_t), &fifteen, sizeof fifteen);
                        FILE *fo = fopen(truncated, "wb");
                        if (fo) {
                            built_cut = (long)fwrite(bytes, 1,
                                                     (size_t)(sz - calibration_tail -
                                                              shadow_tail -
                                                              deferred_tail -
                                                              origin_tail -
                                                              appetite_tail - 1), fo) ==
                                        sz - calibration_tail - shadow_tail -
                                            deferred_tail - origin_tail -
                                            appetite_tail - 1;
                            fclose(fo);
                        }
                        uint32_t fourteen = 14;
                        memcpy(bytes + sizeof(uint32_t), &fourteen, sizeof fourteen);
                        fo = fopen(legacy14, "wb");
                        if (fo) {
                            built_legacy14 = (long)fwrite(bytes, 1,
                                                         (size_t)(sz - calibration_tail -
                                                                 shadow_tail -
                                                                 deferred_tail -
                                                                 origin_tail -
                                                                 appetite_tail -
                                                                 current_only), fo) ==
                                             sz - calibration_tail - shadow_tail -
                                                 deferred_tail - origin_tail -
                                                 appetite_tail -
                                                 current_only;
                            fclose(fo);
                        }
                        uint32_t thirteen = 13;
                        memcpy(bytes + sizeof(uint32_t), &thirteen, sizeof thirteen);
                        fo = fopen(legacy, "wb");
                        if (fo) {
                            int32_t n = fl->flow.n, ptr = fl->flow.ptr;
                            built_legacy = (long)fwrite(bytes, 1, (size_t)prefix, fo) == prefix &&
                                           fwrite(&n, sizeof n, 1, fo) == 1 &&
                                           fwrite(&ptr, sizeof ptr, 1, fo) == 1;
                            for (int i = 0; built_legacy && i < fl->flow.n; i++) {
                                const LeoFlowSnapshot *cur = &fl->flow.snapshots[i];
                                LeoFlowSnapshotV13 v13 = {0};
                                v13.turn = cur->turn;
                                leo_flow_top(cur->perceived, v13.glyph, v13.strength);
                                v13.gap = cur->gap_perceived;
                                v13.mode = cur->mode; v13.chamber = cur->chamber; v13.wonder = cur->wonder;
                                built_legacy = fwrite(&v13, sizeof v13, 1, fo) == 1;
                            }
                            fclose(fo);
                        }
                    }
                }
                free(bytes); fclose(fi);
            }
            CHECK(built_cut && leo_load_state(cut, truncated) &&
                  cut->flow.n == LEO_FLOW_RING && cut->flow.n_currents == 1 &&
                  leo_flow_current_at(&cut->flow, 0)->started_turn == 9 &&
                  leo_flow_current_at(&cut->flow, 0)->observations == 63 &&
                  leo_flow_current_at(&cut->flow, 0)->resolved &&
                  cut->school.turn_clock == fl->school.turn_clock,
                  "flow: a truncated v15 current tail preserves snapshots and rebuilds visible currents");
            leo_free(cut); leo_init(cut);
            CHECK(built_legacy14 && leo_load_state(cut, legacy14) &&
                  cut->flow.n_currents == 1 &&
                  leo_flow_current_at(&cut->flow, 0)->started_turn == 9 &&
                  leo_flow_current_at(&cut->flow, 0)->observations == 63 &&
                  leo_flow_current_at(&cut->flow, 0)->resolved,
                  "flow-current: v14 snapshots reconstruct the honest visible portion of a long current");
            int migrated = built_legacy && leo_load_state(old, legacy);
            const LeoFlowSnapshot *oldest = migrated ? leo_flow_at(&old->flow, 0) : NULL;
            float expressed_mass = 0.0f;
            if (oldest) for (int g = 0; g < GLYPH_COUNT; g++) expressed_mass += oldest->expressed[g];
            CHECK(migrated && old->flow.n == LEO_FLOW_RING && oldest && oldest->turn == 9 &&
                  oldest->perceived[water] == 1.0f && expressed_mass == 0.0f &&
                  oldest->field_token[0] == -1 && old->flow.n_currents == 0,
                  "flow: v13 top-3 history migrates into the perceived face without invented output");
            memset(&fl->flow, 0, sizeof fl->flow);
            for (int i = 1; i <= LEO_FLOW_CURRENT_RING + 6; i++) {
                fl->school.turn_clock = i;
                leo_flow_observe(fl, "water", "fire", NULL, NULL, NULL,
                                 LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_RESOLVED,
                                 (uint64_t)(1000 + i));
            }
            CHECK(fl->flow.n_currents == LEO_FLOW_CURRENT_RING &&
                  fl->flow.current_ptr == 6 &&
                  leo_flow_current_at(&fl->flow, 0)->wonder_id == 1007 &&
                  leo_flow_current_at(&fl->flow, LEO_FLOW_CURRENT_RING - 1)->wonder_id ==
                      1000 + LEO_FLOW_CURRENT_RING + 6,
                  "flow-current: the bounded long-current ring evicts the oldest completed paths");
            free(gravity);
            remove(state); remove(legacy); remove(legacy14); remove(truncated);
            leo_free(fl); leo_free(loaded); leo_free(cut); leo_free(old);
        }
        free(fl); free(loaded); free(cut); free(old);

        Leo *on = malloc(sizeof *on), *off = malloc(sizeof *off);
        CHECK(on && off, "flow: inert-voice fixtures allocated");
        if (on && off) {
            leo_init(on); leo_init(off);
            const char *corpus =
                "The warm light. His mother holds him. The rain at night. "
                "Leo loves the warm light and his mother and the rain. "
                "The window is quiet. Leo is small and warm and close.";
            for (int r = 0; r < 3; r++) { leo_ingest(on, corpus); leo_ingest(off, corpus); }
            leo_build_chamber_tags(on); leo_build_chamber_tags(off);
            leo_supertok_scan(on); leo_supertok_scan(off);
            const char *prompts[] = {"warm mother light", "rain at night", "quiet window", "warm light"};
            int same = 1;
            for (int i = 0; i < 4; i++) {
                char a[1024], b[1024];
                g_leo_flow_on = 1; srand(71 + i); leo_respond(on, prompts[i], a, sizeof a);
                g_leo_flow_on = 0; srand(71 + i); leo_respond(off, prompts[i], b, sizeof b);
                if (strcmp(a, b) != 0) same = 0;
            }
            CHECK(same && on->flow.n == 4 && off->flow.n == 0 &&
                  on->step == off->step &&
                  !memcmp(on->retention_state, off->retention_state, sizeof on->retention_state) &&
                  !memcmp(on->chamber_act, off->chamber_act, sizeof on->chamber_act) &&
                  !memcmp(on->gamma, off->gamma, sizeof on->gamma) &&
                  !memcmp(on->gamma_meaning, off->gamma_meaning, sizeof on->gamma_meaning),
                  "flow: default-on and --no-flow voices remain byte-identical across lived turns");
            leo_free(on); leo_free(off);
        }
        free(on); free(off);
        g_leo_flow_on = prev_flow;
    }

}

static TEST_NOINLINE void test_shadow_scheduler(void) {
    /* A.26b shadow scheduler: decisions are post-reply counterfactual receipts.
     * They may witness both clocks, but cannot touch School or generation. */
    {
        int prev_flow = g_leo_flow_on, prev_shadow = g_leo_shadow_on;
        g_leo_flow_on = 1;
        g_leo_shadow_on = 1;
        Leo *sh = malloc(sizeof *sh), *woke = malloc(sizeof *woke),
            *old = malloc(sizeof *old), *compat = malloc(sizeof *compat),
            *cut = malloc(sizeof *cut);
        CHECK(sh && woke && old && compat && cut, "shadow: heap fixtures allocated");
        if (sh && woke && old && compat && cut) {
            leo_init(sh); leo_init(woke); leo_init(old); leo_init(compat); leo_init(cut);
            int water = semtok_word("water"), fire = semtok_word("fire");
            strncpy(sh->school.pending, "zorble", sizeof sh->school.pending - 1);
            sh->school.pending_glyph = water;
            sh->school.pending_alt_glyph = fire;
            LeoWonderEpisode *ep = leo_wonder_open(sh, "zorble", water, fire);
            uint64_t id = leo_wonder_episode_id(ep);

            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "water fire", "fire", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_BORN, id);
            leo_shadow_calibrate(sh, "water fire");
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r0 = leo_shadow_at(&sh->shadow, 0);
            CHECK(r0 && r0->action == LEO_SHADOW_SPACE && r0->wonder_id == id &&
                  (r0->reasons & (LEO_SHADOW_REASON_OPEN | LEO_SHADOW_REASON_ASKED)) ==
                  (LEO_SHADOW_REASON_OPEN | LEO_SHADOW_REASON_ASKED),
                  "shadow: a question just voiced earns space, not an immediate re-ask");

            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "I do not know", NULL, NULL, NULL, NULL, 0, id);
            leo_shadow_calibrate(sh, "I do not know");
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r1 = leo_shadow_at(&sh->shadow, 1);
            CHECK(r1 && r1->action == LEO_SHADOW_HOLD && r1->gap < 0.01f &&
                  r1->grounded_mass == 0.0f &&
                  (r1->reasons & LEO_SHADOW_REASON_UNGROUNDED),
                  "shadow: known words for not-knowing cannot counterfeit grounded movement");
            const LeoCalibrationReceipt *c0 = leo_calibration_at(&sh->calibration, 0);
            CHECK(c0 && c0->proposal_turn == 1 && c0->observed_turn == 2 &&
                  c0->verdict == LEO_CALIB_CONFIRMED && c0->brier > 0.0f,
                  "shadow-calibration: space is confirmed when the next turn applies no pressure");

            sh->school.turn_clock = 3;
            leo_flow_observe(sh, "small room", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_REASKED, id);
            leo_shadow_calibrate(sh, "small room");
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r2 = leo_shadow_at(&sh->shadow, 2);
            CHECK(r2 && r2->action == LEO_SHADOW_SPACE &&
                  (r2->reasons & LEO_SHADOW_REASON_ASKED),
                  "shadow: a re-asked wonder again yields the next turn to the human");
            const LeoCalibrationReceipt *c1 = leo_calibration_at(&sh->calibration, 1);
            CHECK(c1 && c1->proposal_turn == 2 &&
                  c1->verdict == LEO_CALIB_FALSE_PRESSURE &&
                  c1->brier > r1->confidence * r1->confidence - 1e-6f,
                  "shadow-calibration: an immediate re-ask is visible as false pressure");

            sh->school.pending[0] = 0;
            sh->school.turn_clock = 4;
            leo_flow_observe(sh, "animal", "animal", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_RESOLVED, id);
            leo_shadow_calibrate(sh, "animal");
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r3 = leo_shadow_at(&sh->shadow, 3);
            CHECK(r3 && r3->action == LEO_SHADOW_RELEASE && r3->wonder_id == id &&
                  r3->reasons == LEO_SHADOW_REASON_RESOLVED && r3->confidence == 1.0f,
                  "shadow: grounded closure is acknowledged exactly as release");
            const LeoCalibrationReceipt *c2 = leo_calibration_at(&sh->calibration, 2);
            CHECK(c2 && c2->proposal_turn == 3 &&
                  c2->verdict == LEO_CALIB_CONFIRMED,
                  "shadow-calibration: space can end in grounding without becoming an error");

            sh->school.turn_clock = 5;
            leo_flow_observe(sh, "water", "fire", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_RECALLED, id);
            leo_shadow_calibrate(sh, "water");
            leo_shadow_observe(sh);
            const LeoShadowReceipt *r4 = leo_shadow_at(&sh->shadow, 4);
            CHECK(r4 && r4->action == LEO_SHADOW_NONE && r4->wonder_id == 0,
                  "shadow: later recall cannot counterfeit a second closure");
            const LeoCalibrationReceipt *c3 = leo_calibration_at(&sh->calibration, 3);
            CHECK(c3 && c3->proposal_turn == 4 &&
                  c3->verdict == LEO_CALIB_CONFIRMED && c3->brier == 0.0f &&
                  sh->calibration.n == 4,
                  "shadow-calibration: release survives recall without reopening the target");
            leo_shadow_calibrate(sh, "water");
            CHECK(sh->calibration.n == 4,
                  "shadow-calibration: one observed turn cannot judge a proposal twice");

            const char *state = "/tmp/leo_shadow_v17.state";
            const char *legacy = "/tmp/leo_shadow_v15.state";
            const char *legacy16 = "/tmp/leo_shadow_v16.state";
            const char *truncated = "/tmp/leo_shadow_v17_cut.state";
            sh->shadow.receipts[0].face_alignment = 1.0f + 1e-7f;
            int saved = leo_save_state(sh, state), built_old = 0,
                built_compat = 0, built_cut = 0;
            FILE *fi = fopen(state, "rb");
            if (fi) {
                fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
                unsigned char *bytes = malloc(sz > 0 ? (size_t)sz : 1);
                if (bytes && sz > 1 && (long)fread(bytes, 1, (size_t)sz, fi) == sz) {
                    long shadow_tail = (long)(2 * sizeof(int32_t) +
                                              sh->shadow.n * (int)sizeof(LeoShadowReceipt));
                    long calibration_tail = (long)(2 * sizeof(int32_t) +
                                                   sh->calibration.n *
                                                       (int)sizeof(LeoCalibrationReceipt));
                    long deferred_tail = (long)(sizeof(int32_t) +
                                                sh->school.n_deferred *
                                                    (int)sizeof(LeoDeferredWonder));
                    long origin_tail = (long)(sizeof(int32_t) +
                                              (sh->school.has_pending_origin ?
                                               sizeof(LeoDeferredWonder) : 0));
                    long appetite_tail =
                        test_appetite_and_later_tail_size(sh);
                    uint32_t fifteen = 15;
                    memcpy(bytes + sizeof(uint32_t), &fifteen, sizeof fifteen);
                    FILE *fo = fopen(legacy, "wb");
                    if (fo) {
                        built_old = (long)fwrite(bytes, 1,
                                                 (size_t)(sz - calibration_tail -
                                                          shadow_tail -
                                                          deferred_tail -
                                                          origin_tail -
                                                          appetite_tail), fo) ==
                                    sz - calibration_tail - shadow_tail -
                                        deferred_tail - origin_tail -
                                        appetite_tail;
                        fclose(fo);
                    }
                    uint32_t sixteen = 16;
                    memcpy(bytes + sizeof(uint32_t), &sixteen, sizeof sixteen);
                    fo = fopen(legacy16, "wb");
                    if (fo) {
                        built_compat = (long)fwrite(bytes, 1,
                                                    (size_t)(sz - calibration_tail -
                                                             deferred_tail -
                                                             origin_tail -
                                                             appetite_tail), fo) ==
                                       sz - calibration_tail - deferred_tail -
                                           origin_tail - appetite_tail;
                        fclose(fo);
                    }
                    uint32_t seventeen = 17;
                    memcpy(bytes + sizeof(uint32_t), &seventeen, sizeof seventeen);
                    fo = fopen(truncated, "wb");
                    if (fo) {
                        built_cut = (long)fwrite(bytes, 1,
                                                (size_t)(sz - deferred_tail -
                                                         origin_tail -
                                                         appetite_tail - 1), fo) ==
                                    sz - deferred_tail - origin_tail -
                                        appetite_tail - 1;
                        fclose(fo);
                    }
                }
                free(bytes); fclose(fi);
            }
            int loaded = saved && leo_load_state(woke, state);
            const LeoShadowReceipt *woke_release =
                loaded ? leo_shadow_at(&woke->shadow, 3) : NULL;
            CHECK(loaded && woke->shadow.n == 5 && woke_release &&
                  woke_release->action == LEO_SHADOW_RELEASE &&
                  woke_release->wonder_id == id && woke->calibration.n == 4 &&
                  leo_shadow_at(&woke->shadow, 0)->face_alignment == 1.0f &&
                  leo_calibration_at(&woke->calibration, 1)->verdict ==
                      LEO_CALIB_FALSE_PRESSURE,
                  "shadow-calibration: v17 sleep preserves verdicts and canonicalizes cosine epsilon");
            CHECK(built_old && leo_load_state(old, legacy) && old->flow.n == 5 &&
                  old->flow.n_currents == 1 && old->shadow.n == 0 &&
                  old->calibration.n == 0,
                  "shadow: a v15 body migrates without invented proposals");
            CHECK(built_compat && leo_load_state(compat, legacy16) &&
                  compat->flow.n == 5 && compat->shadow.n == 5 &&
                  compat->calibration.n == 0,
                  "shadow-calibration: a v16 body migrates without retroactive verdicts");
            CHECK(built_cut && leo_load_state(cut, truncated) && cut->flow.n == 5 &&
                  cut->flow.n_currents == 1 && cut->shadow.n == 5 &&
                  cut->calibration.n == 0,
                  "shadow-calibration: a corrupt v17 verdict tail preserves proposals and Flow");

            const char *pending_state = "/tmp/leo_shadow_pending_v17.state";
            leo_free(compat); leo_init(compat);
            strncpy(compat->school.pending, "sleeping", sizeof compat->school.pending - 1);
            uint64_t sleeping_id = 0x1717171717171717ULL;
            compat->school.turn_clock = 1;
            leo_flow_observe(compat, "water", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_BORN, sleeping_id);
            leo_shadow_calibrate(compat, "water"); leo_shadow_observe(compat);
            int pending_saved = leo_save_state(compat, pending_state);
            leo_free(cut); leo_init(cut);
            int pending_loaded = pending_saved && leo_load_state(cut, pending_state);
            cut->school.turn_clock = 2;
            leo_flow_observe(cut, "I do not know", NULL, NULL, NULL, NULL, 0,
                             sleeping_id);
            leo_shadow_calibrate(cut, "I do not know");
            const LeoCalibrationReceipt *after_sleep =
                leo_calibration_at(&cut->calibration, 0);
            CHECK(pending_loaded && after_sleep && after_sleep->proposal_turn == 1 &&
                  after_sleep->observed_turn == 2 &&
                  after_sleep->verdict == LEO_CALIB_CONFIRMED,
                  "shadow-calibration: an unevaluated proposal receives its next-turn verdict after sleep");

            for (int turn = 6; turn <= LEO_SHADOW_RING + 6; turn++) {
                sh->school.turn_clock = turn;
                leo_flow_observe(sh, "water", "water", NULL, NULL, NULL, 0, 0);
                leo_shadow_calibrate(sh, "water");
                leo_shadow_observe(sh);
            }
            CHECK(sh->shadow.n == LEO_SHADOW_RING && sh->shadow.ptr == 6 &&
                  leo_shadow_at(&sh->shadow, 0)->turn == 7 &&
                  leo_shadow_at(&sh->shadow, LEO_SHADOW_RING - 1)->turn ==
                      LEO_SHADOW_RING + 6,
                  "shadow: the receipt diary is bounded and chronologically ordered");

            memset(&sh->flow, 0, sizeof sh->flow);
            memset(&sh->shadow, 0, sizeof sh->shadow);
            memset(&sh->calibration, 0, sizeof sh->calibration);
            strncpy(sh->school.pending, "returnword", sizeof sh->school.pending - 1);
            LeoWonderEpisode *human_ep =
                leo_wonder_open(sh, "returnword", water, fire);
            uint64_t human_id = leo_wonder_episode_id(human_ep);
            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "What is a returnword?", "Returnword?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_BORN, human_id);
            leo_shadow_calibrate(sh, "What is a returnword?");
            leo_shadow_observe(sh);
            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "Do you remember returnword?", "Returnword?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_REASKED, human_id);
            leo_shadow_calibrate(sh, "Do you remember returnword?");
            const LeoCalibrationReceipt *human_return =
                leo_calibration_at(&sh->calibration, 0);
            CHECK(human_return && human_return->verdict == LEO_CALIB_UNSCORABLE &&
                  human_return->brier == 0.0f,
                  "shadow-calibration: a literal human invitation is not autonomous pressure");

            memset(&sh->flow, 0, sizeof sh->flow);
            memset(&sh->shadow, 0, sizeof sh->shadow);
            memset(&sh->calibration, 0, sizeof sh->calibration);
            strncpy(sh->school.pending, "fieldword", sizeof sh->school.pending - 1);
            LeoWonderEpisode *field_ep =
                leo_wonder_open(sh, "fieldword", water, fire);
            uint64_t field_id = leo_wonder_episode_id(field_ep);
            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "What is fieldword? Water or fire?", "Fieldword?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_BORN, field_id);
            leo_shadow_calibrate(sh, "What is fieldword? Water or fire?");
            leo_shadow_observe(sh);
            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "Could it be fire?", "Fieldword?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_REASKED, field_id);
            leo_shadow_calibrate(sh, "Could it be fire?");
            const LeoCalibrationReceipt *semantic_return =
                leo_calibration_at(&sh->calibration, 0);
            CHECK(semantic_return &&
                  semantic_return->verdict == LEO_CALIB_UNSCORABLE &&
                  semantic_return->brier == 0.0f,
                  "shadow-calibration: an anaphoric hypothesis question can invite a return without naming it");

            memset(&sh->flow, 0, sizeof sh->flow);
            memset(&sh->shadow, 0, sizeof sh->shadow);
            memset(&sh->calibration, 0, sizeof sh->calibration);
            strncpy(sh->school.pending, "controlword", sizeof sh->school.pending - 1);
            LeoWonderEpisode *control_ep =
                leo_wonder_open(sh, "controlword", water, fire);
            uint64_t control_id = leo_wonder_episode_id(control_ep);
            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "What is controlword? Water or fire?", "Controlword?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_BORN, control_id);
            leo_shadow_calibrate(sh, "What is controlword? Water or fire?");
            leo_shadow_observe(sh);
            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "The warm fire is here again", "Controlword?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_REASKED, control_id);
            leo_shadow_calibrate(sh, "The warm fire is here again");
            const LeoCalibrationReceipt *autonomous_return =
                leo_calibration_at(&sh->calibration, 0);
            CHECK(autonomous_return &&
                  autonomous_return->verdict == LEO_CALIB_FALSE_PRESSURE &&
                  autonomous_return->brier > 0.0f,
                  "shadow-calibration: a guessed glyph without reference leaves autonomous pressure scorable");

            const char *semantic_state = "/tmp/leo_shadow_semantic_invite_v17.state";
            leo_free(compat); leo_init(compat);
            strncpy(compat->school.pending, "sleepfield",
                    sizeof compat->school.pending - 1);
            LeoWonderEpisode *sleepfield_ep =
                leo_wonder_open(compat, "sleepfield", water, fire);
            uint64_t sleepfield_id = leo_wonder_episode_id(sleepfield_ep);
            compat->school.turn_clock = 1;
            leo_flow_observe(compat, "What is sleepfield? Water or fire?",
                             "Sleepfield?", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_BORN, sleepfield_id);
            leo_shadow_calibrate(compat, "What is sleepfield? Water or fire?");
            leo_shadow_observe(compat);
            int semantic_saved = leo_save_state(compat, semantic_state);
            leo_free(cut); leo_init(cut);
            int semantic_loaded = semantic_saved &&
                                  leo_load_state(cut, semantic_state);
            cut->school.turn_clock = 2;
            leo_flow_observe(cut, "Could it be water?", "Sleepfield?",
                             NULL, NULL, NULL, LEO_FLOW_WONDER_REASKED,
                             sleepfield_id);
            leo_shadow_calibrate(cut, "Could it be water?");
            const LeoCalibrationReceipt *semantic_after_sleep =
                leo_calibration_at(&cut->calibration, 0);
            CHECK(semantic_loaded && semantic_after_sleep &&
                  semantic_after_sleep->verdict == LEO_CALIB_UNSCORABLE &&
                  semantic_after_sleep->brier == 0.0f,
                  "shadow-calibration: semantic invitation survives sleep with its episode");

            memset(&sh->flow, 0, sizeof sh->flow);
            memset(&sh->shadow, 0, sizeof sh->shadow);
            memset(&sh->calibration, 0, sizeof sh->calibration);
            strncpy(sh->school.pending, "lost", sizeof sh->school.pending - 1);
            uint64_t lost_id = 0x1020304050607080ULL;
            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "water", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_BORN, lost_id);
            leo_shadow_calibrate(sh, "water"); leo_shadow_observe(sh);
            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "I do not know", NULL, NULL, NULL, NULL, 0, lost_id);
            leo_shadow_calibrate(sh, "I do not know"); leo_shadow_observe(sh);
            memset(&sh->flow, 0, sizeof sh->flow);   /* adversarial disappearance without resolve */
            sh->school.pending[0] = 0;
            sh->school.turn_clock = 3;
            leo_flow_observe(sh, "water", "water", NULL, NULL, NULL, 0, 0);
            leo_shadow_calibrate(sh, "water");
            const LeoCalibrationReceipt *missed =
                leo_calibration_at(&sh->calibration, sh->calibration.n - 1);
            CHECK(missed && missed->verdict == LEO_CALIB_MISSED_OPENING &&
                  missed->wonder_id == lost_id,
                  "shadow-calibration: a target lost without resolution is a missed opening");

            memset(&sh->flow, 0, sizeof sh->flow);
            memset(&sh->shadow, 0, sizeof sh->shadow);
            memset(&sh->calibration, 0, sizeof sh->calibration);
            uint64_t relapse_id = 0x9090909090909090ULL;
            sh->school.pending[0] = 0;
            sh->school.turn_clock = 1;
            leo_flow_observe(sh, "animal", "animal", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_BORN | LEO_FLOW_WONDER_RESOLVED,
                             relapse_id);
            leo_shadow_calibrate(sh, "animal"); leo_shadow_observe(sh);
            strncpy(sh->school.pending, "relapse", sizeof sh->school.pending - 1);
            sh->school.turn_clock = 2;
            leo_flow_observe(sh, "water", "water", NULL, NULL, NULL,
                             LEO_FLOW_WONDER_REASKED, relapse_id);
            leo_shadow_calibrate(sh, "water");
            const LeoCalibrationReceipt *relapse =
                leo_calibration_at(&sh->calibration, 0);
            CHECK(relapse && relapse->verdict == LEO_CALIB_RELEASE_RELAPSE,
                  "shadow-calibration: reopening a released identity is a relapse, not success");

            memset(&sh->flow, 0, sizeof sh->flow);
            memset(&sh->shadow, 0, sizeof sh->shadow);
            memset(&sh->calibration, 0, sizeof sh->calibration);
            int turn = 0;
            for (int cycle = 0; cycle < 24; cycle++) {
                uint64_t cycle_id = (uint64_t)(0x2000 + cycle);
                strncpy(sh->school.pending, "path", sizeof sh->school.pending - 1);
                sh->school.turn_clock = ++turn;
                leo_flow_observe(sh, "water", "water", NULL, NULL, NULL,
                                 LEO_FLOW_WONDER_BORN, cycle_id);
                leo_shadow_calibrate(sh, "water"); leo_shadow_observe(sh);
                sh->school.turn_clock = ++turn;
                leo_flow_observe(sh, "water", "water", NULL, NULL, NULL, 0, cycle_id);
                leo_shadow_calibrate(sh, "water"); leo_shadow_observe(sh);
                sh->school.pending[0] = 0;
                sh->school.turn_clock = ++turn;
                leo_flow_observe(sh, "animal", "animal", NULL, NULL, NULL,
                                 LEO_FLOW_WONDER_RESOLVED, cycle_id);
                leo_shadow_calibrate(sh, "animal"); leo_shadow_observe(sh);
                sh->school.turn_clock = ++turn;
                leo_flow_observe(sh, "water", "water", NULL, NULL, NULL,
                                 LEO_FLOW_WONDER_RECALLED, cycle_id);
                leo_shadow_calibrate(sh, "water"); leo_shadow_observe(sh);
            }
            const LeoCalibrationReceipt *oldest_cal =
                leo_calibration_at(&sh->calibration, 0);
            const LeoCalibrationReceipt *newest_cal =
                leo_calibration_at(&sh->calibration, LEO_CALIB_RING - 1);
            CHECK(sh->calibration.n == LEO_CALIB_RING && sh->calibration.ptr == 8 &&
                  oldest_cal && newest_cal &&
                  oldest_cal->proposal_turn < newest_cal->proposal_turn &&
                  newest_cal->observed_turn == (uint64_t)turn,
                  "shadow-calibration: verdict history is bounded without losing chronology");

            remove(state); remove(legacy); remove(legacy16); remove(truncated);
            remove(pending_state);
            leo_free(sh); leo_free(woke); leo_free(old); leo_free(compat); leo_free(cut);
        }
        free(sh); free(woke); free(old); free(compat); free(cut);

        Leo *on = malloc(sizeof *on), *off = malloc(sizeof *off);
        CHECK(on && off, "shadow: inert-voice fixtures allocated");
        if (on && off) {
            leo_init(on); leo_init(off);
            const char *corpus =
                "The warm light. His mother holds him. The rain at night. "
                "Leo loves the warm light and his mother and the rain. ";
            for (int r = 0; r < 3; r++) { leo_ingest(on, corpus); leo_ingest(off, corpus); }
            leo_build_chamber_tags(on); leo_build_chamber_tags(off);
            leo_supertok_scan(on); leo_supertok_scan(off);
            const char *prompts[] = {
                "is a zorble water or cat", "I do not know",
                "what do you think?", "a zorble is a small animal"
            };
            int same = 1;
            for (int i = 0; i < 4; i++) {
                char a[1024], b[1024];
                g_leo_shadow_on = 1; srand(183 + i); leo_respond(on, prompts[i], a, sizeof a);
                g_leo_shadow_on = 0; srand(183 + i); leo_respond(off, prompts[i], b, sizeof b);
                if (strcmp(a, b) != 0) same = 0;
            }
            CHECK(same && on->shadow.n == 4 && off->shadow.n == 0 &&
                  !memcmp(&on->flow, &off->flow, sizeof on->flow) &&
                  on->step == off->step &&
                  !memcmp(on->retention_state, off->retention_state,
                          sizeof on->retention_state) &&
                  !memcmp(on->chamber_act, off->chamber_act, sizeof on->chamber_act) &&
                  !memcmp(on->gamma, off->gamma, sizeof on->gamma) &&
                  !memcmp(on->gamma_meaning, off->gamma_meaning,
                          sizeof on->gamma_meaning),
                  "shadow: default-on and --no-shadow voices remain byte-identical");
            leo_free(on); leo_free(off);
        }
        free(on); free(off);
        g_leo_flow_on = prev_flow;
        g_leo_shadow_on = prev_shadow;
    }

    CHECK(leo_mode_from_name("stop") == LEO_MODE_STOP &&
          leo_mode_from_name("STOP") == LEO_MODE_STOP &&
          leo_mode_from_name("BreaThe") == LEO_MODE_BREATHE &&
          leo_mode_from_name("nope") == -1,
          "form: --mode name is case-insensitive (stop==STOP, garbage stays -1)");

}

static TEST_NOINLINE void test_klaus_and_gamma(void) {
    /* klaus-memory: scars accumulate on distress, decay on calm (the body remembers HOW). */
    {
        Leo *ks = test_leo_alloc(); leo_init(ks);
        leo_ingest(ks, "the rain falls. his mother is warm. he is afraid alone in the dark.");
        char buf[1024];
        int prev = g_leo_klaus_on; g_leo_klaus_on = 1;
        for (int t = 0; t < 6; t++)  leo_respond(ks, "i am so afraid alone lost in the dark", buf, sizeof buf);
        float fear_scar = ks->scar[LEO_CH_FEAR];
        for (int t = 0; t < 12; t++) leo_respond(ks, "my warm mother holds me close", buf, sizeof buf);
        float calm_scar = ks->scar[LEO_CH_FEAR];
        CHECK(fear_scar > 0.01f && calm_scar < fear_scar,
              "klaus: scar[FEAR] accumulates on distress, decays on calm");
        g_leo_klaus_on = prev;
        test_leo_delete(ks);
    }

    /* klaus-memory: the scars survive save/load (state v6). */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        sv->scar[LEO_CH_FEAR] = 0.42f;
        sv->scar[LEO_CH_VOID] = 0.17f;
        const char *path = "/tmp/leo_klaus_state.bin";
        int saved = leo_save_state(sv, path);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, path);
        CHECK(saved && loaded &&
              fabsf(ld->scar[LEO_CH_FEAR] - 0.42f) < 0.001f &&
              fabsf(ld->scar[LEO_CH_VOID] - 0.17f) < 0.001f,
              "klaus: scars survive save/load (v6)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(path);
    }

    /* klaus-memory: a v5 state (saved before scar existed) migrates into the v6 loader
     * with scar=0 — the organism survives a pure-append upgrade (decision B: persistent
     * memory = love). A real v5 file is the current save with version=5 and without EVERY appended
     * tail (v6 scar[], v7 gamma[]+primed, v8 gamma_meaning[]+gap); strip all and prove it migrates. */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        sv->scar[LEO_CH_FEAR] = 0.5f;   /* dropped when the v5 scar tail is stripped */
        const char *p6 = "/tmp/leo_v6_mig.bin", *p5 = "/tmp/leo_v5_mig.bin";
        int saved = leo_save_state(sv, p6);
        int built = 0;
        FILE *fi = fopen(p6, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
            long v5tail = (long)(LEO_N_CHAMBERS * sizeof(float)                       /* v6 scar[] */
                               + LEO_GAMMA_DIM * sizeof(float) + sizeof(int32_t)      /* + v7 gamma[]+primed */
                               + GLYPH_COUNT * sizeof(float) + sizeof(float));        /* + v8 gamma_meaning[]+gap */
            if (buf && sz > v5tail &&
                (long)fread(buf, 1, (size_t)sz, fi) == sz) {
                uint32_t five = 5; memcpy(buf + 4, &five, sizeof five);       /* version 7 -> 5 */
                long v5sz = sz - v5tail;                                      /* strip BOTH appended tails -> real v5 EOF */
                FILE *fo = fopen(p5, "wb");
                if (fo) { built = ((long)fwrite(buf, 1, (size_t)v5sz, fo) == v5sz); fclose(fo); }
            }
            free(buf); fclose(fi);
        }
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = built && leo_load_state(ld, p5);
        int scar_zero = 1;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) if (ld->scar[c] != 0.0f) scar_zero = 0;
        CHECK(saved && built && loaded && scar_zero,
              "klaus: a v5 state migrates into the v6 loader, scar=0 (B)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(p6); remove(p5);
    }

    /* E-11 γ-capsule: prior (pull) tints toward the running self only once primed; diary (absorb)
     * primes from the body, then EMA-evolves — the prior/diary split (Codex/Mythos). */
    {
        Leo *gc = test_leo_alloc(); leo_init(gc);
        leo_ingest(gc, "the rain falls. his mother is warm. he is afraid alone in the dark.");
        int prev = g_leo_capsule_on; g_leo_capsule_on = 1;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) gc->chamber_act[c] = 0.0f;
        gc->chamber_act[LEO_CH_FEAR] = 1.0f;   /* a strong-fear body */
        leo_gamma_pull(gc);                  /* unprimed → no pull */
        int no_pull_unprimed = fabsf(gc->chamber_act[LEO_CH_FEAR] - 1.0f) < 1e-6f;
        leo_gamma_absorb(gc);                /* diary primes from the body */
        int primed = gc->gamma_primed == 1 && fabsf(gc->gamma[LEO_CH_FEAR] - 1.0f) < 1e-6f;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) gc->chamber_act[c] = 0.0f;   /* now a calm body */
        leo_gamma_pull(gc);                  /* primed → running fear tints the present */
        int pulled = gc->chamber_act[LEO_CH_FEAR] > 0.0f;
        leo_gamma_absorb(gc);                /* EMA absorbs the calmer body */
        int evolved = gc->gamma[LEO_CH_FEAR] < 1.0f;
        CHECK(no_pull_unprimed && primed && pulled && evolved,
              "E-11: gamma prior pulls once primed, diary primes then evolves");
        g_leo_capsule_on = prev;
        test_leo_delete(gc);
    }

    /* E-11 γ-capsule: gamma round-trips save/load (whatever the current state version writes). */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        for (int c = 0; c < LEO_GAMMA_DIM; c++) sv->gamma[c] = 0.1f * (float)(c + 1);
        sv->gamma_primed = 1;
        const char *path = "/tmp/leo_gamma_v7.bin";
        int saved = leo_save_state(sv, path);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, path);
        int rt = 1;
        for (int c = 0; c < LEO_GAMMA_DIM; c++)
            if (fabsf(ld->gamma[c] - 0.1f * (float)(c + 1)) > 0.001f) rt = 0;
        CHECK(saved && loaded && rt && ld->gamma_primed == 1,
              "E-11: gamma capsule round-trips save/load");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(path);
    }

    /* E-11 γ-capsule: a v6 state (no gamma) migrates into the v7 loader — gamma stays 0 + unprimed,
     * so it primes from the body on the first reply. A v6 file is a v7 file with version=6 and
     * without the trailing gamma[]+primed tail. */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        sv->scar[LEO_CH_FEAR] = 0.3f;
        for (int c = 0; c < LEO_GAMMA_DIM; c++) sv->gamma[c] = 0.7f;
        sv->gamma_primed = 1;
        const char *p7 = "/tmp/leo_v7_mig.bin", *p6 = "/tmp/leo_v6_mig2.bin";
        int saved = leo_save_state(sv, p7);
        int built = 0;
        long tail = (long)(LEO_GAMMA_DIM * sizeof(float) + sizeof(int32_t)          /* v7 gamma[]+primed */
                         + GLYPH_COUNT * sizeof(float) + sizeof(float));            /* + v8 gamma_meaning[]+gap */
        FILE *fi = fopen(p7, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
            if (buf && sz > tail && (long)fread(buf, 1, (size_t)sz, fi) == sz) {
                uint32_t six = 6; memcpy(buf + 4, &six, sizeof six);          /* version 7 -> 6 */
                FILE *fo = fopen(p6, "wb");
                if (fo) { built = ((long)fwrite(buf, 1, (size_t)(sz - tail), fo) == sz - tail); fclose(fo); }
            }
            free(buf); fclose(fi);
        }
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = built && leo_load_state(ld, p6);
        int gamma_zero = ld->gamma_primed == 0;
        for (int c = 0; c < LEO_GAMMA_DIM; c++) if (ld->gamma[c] != 0.0f) gamma_zero = 0;
        int scar_ok = fabsf(ld->scar[LEO_CH_FEAR] - 0.3f) < 0.001f;            /* v6 scar still loads */
        CHECK(saved && built && loaded && gamma_zero && scar_ok,
              "E-11: a v6 state migrates into the v7 loader, gamma unprimed (B)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(p7); remove(p6);
    }

    /* E-11 meaning axis: known concepts raise gamma_meaning; unknown content words raise the gap
     * (Leo's darkmatter). PASSIVE — readout only. */
    {
        Leo *gm = test_leo_alloc(); leo_init(gm);
        leo_ingest(gm, "the rain falls. his mother is warm. fire and water and fear.");
        int prev = g_leo_capsule_on; g_leo_capsule_on = 1;
        leo_gamma_meaning(gm, "water and fire and love");   /* seed-map concepts */
        float sum = 0.0f;
        for (int i = 0; i < GLYPH_COUNT; i++) sum += gm->gamma_meaning[i];
        int concepts_rose = sum > 0.0f;
        float gap0 = gm->gamma_gap;
        for (int t = 0; t < 5; t++) leo_gamma_meaning(gm, "the zorblax grumbus");  /* unknown content words */
        int gap_rose = gm->gamma_gap > gap0;
        CHECK(concepts_rose && gap_rose,
              "E-11: meaning axis — concepts raise gamma_meaning, unknown raises the gap (darkmatter)");
        g_leo_capsule_on = prev;
        test_leo_delete(gm);
    }

    /* E-11 meaning axis: gamma_meaning + gamma_gap round-trip save/load (state v8). */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls.");
        for (int i = 0; i < GLYPH_COUNT; i++) sv->gamma_meaning[i] = 0.001f * (float)(i + 1);
        sv->gamma_gap = 0.37f;
        const char *path = "/tmp/leo_gmean_v8.bin";
        int saved = leo_save_state(sv, path);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, path);
        int rt = fabsf(ld->gamma_gap - 0.37f) < 0.001f;
        for (int i = 0; i < GLYPH_COUNT; i++)
            if (fabsf(ld->gamma_meaning[i] - 0.001f * (float)(i + 1)) > 0.0005f) rt = 0;
        CHECK(saved && loaded && rt,
              "E-11: meaning axis round-trips save/load (v8)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(path);
    }

    /* E-11 OOB guard: leo_glyph_concept rejects out-of-range glyph ids (a corrupt loaded
     * learned_glyph could be 88..127 → must not pass to hist[g]). */
    CHECK(!leo_glyph_concept(GLYPH_COUNT) && !leo_glyph_concept(127) && !leo_glyph_concept(-1)
          && leo_glyph_concept(0) && leo_glyph_concept(GLYPH_COUNT - 1),
          "E-11: leo_glyph_concept rejects out-of-range ids (hist OOB guard)");

    /* E-11 meaning axis: a v7 state (no meaning axis) migrates into the v8 loader — gamma_meaning
     * + gamma_gap stay 0. A v7 file is a v8 file with version=7 and without the trailing v8 tail. */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        sv->gamma_gap = 0.4f;                                  /* dropped when the v8 tail is stripped */
        for (int i = 0; i < GLYPH_COUNT; i++) sv->gamma_meaning[i] = 0.5f;
        const char *p8 = "/tmp/leo_v8_mig.bin", *p7 = "/tmp/leo_v7_mig2.bin";
        int saved = leo_save_state(sv, p8);
        int built = 0;
        long v8tail = (long)(GLYPH_COUNT * sizeof(float) + sizeof(float));   /* gamma_meaning[] + gap */
        FILE *fi = fopen(p8, "rb");
        if (fi) {
            fseek(fi, 0, SEEK_END); long sz = ftell(fi); fseek(fi, 0, SEEK_SET);
            unsigned char *buf = (unsigned char *)malloc(sz > 0 ? (size_t)sz : 1);
            if (buf && sz > v8tail && (long)fread(buf, 1, (size_t)sz, fi) == sz) {
                uint32_t seven = 7; memcpy(buf + 4, &seven, sizeof seven);   /* version 8 -> 7 */
                FILE *fo = fopen(p7, "wb");
                if (fo) { built = ((long)fwrite(buf, 1, (size_t)(sz - v8tail), fo) == sz - v8tail); fclose(fo); }
            }
            free(buf); fclose(fi);
        }
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = built && leo_load_state(ld, p7);
        int mean_zero = ld->gamma_gap == 0.0f;
        for (int i = 0; i < GLYPH_COUNT; i++) if (ld->gamma_meaning[i] != 0.0f) mean_zero = 0;
        CHECK(saved && built && loaded && mean_zero,
              "E-11: a v7 state migrates into the v8 loader, meaning axis 0 (B)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(p8); remove(p7);
    }

}

static TEST_NOINLINE void test_gamma_meaning_spores(void) {
    /* E-11 #3: the meaning axis joins santaclaus resonance — a spore whose birth-topic
     * matches the present topic outresonates one that does not; with no topic
     * (prompt_meaning NULL) the resonance is the pre-#3 chamber+retention blend. */
    {
        Leo *r = test_leo_alloc(); leo_init(r);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) r->chamber_act[i] = 0.5f;
        for (int d = 0; d < LEO_RET_DIM; d++) r->retention_state[d] = 0.5f;
        LeoSpore match, off;
        memset(&match, 0, sizeof match); memset(&off, 0, sizeof off);
        for (int i = 0; i < LEO_N_CHAMBERS; i++) { match.chamber_snap[i] = 0.5f; off.chamber_snap[i] = 0.5f; }
        for (int d = 0; d < LEO_RET_DIM; d++) { match.retention_slice[d] = 0.5f; off.retention_slice[d] = 0.5f; }
        match.meaning_snap[10] = 1.0f;   /* same glyph as the present topic */
        off.meaning_snap[40]   = 1.0f;   /* a different glyph */
        float topic[GLYPH_COUNT] = {0}; topic[10] = 1.0f;
        r->prompt_meaning = NULL;
        CHECK(leo_spore_resonance(r, &match) == leo_spore_resonance(r, &off),
              "E-11 #3: no topic (prompt_meaning NULL) -> meaning ignored, resonance equal");
        r->prompt_meaning = topic;
        CHECK(leo_spore_resonance(r, &match) > leo_spore_resonance(r, &off),
              "E-11 #3: topic-matching spore outresonates an off-topic one");
        r->prompt_meaning = NULL;
        test_leo_delete(r);
    }

    /* E-11 #3: meaning_snap round-trips save/load (state v9). */
    {
        Leo *sv = test_leo_alloc(); leo_init(sv);
        leo_ingest(sv, "the rain falls. his mother is warm.");
        LeoSpore sp; memset(&sp, 0, sizeof sp);
        sp.strength = 1.0f; sp.step = 7; sp.meaning_snap[5] = 0.25f; sp.meaning_snap[9] = 0.75f;
        sv->spores[0] = sp; sv->n_spores = 1;
        const char *p = "/tmp/leo_v9_spore.bin";
        int saved = leo_save_state(sv, p);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int loaded = leo_load_state(ld, p);
        CHECK(saved && loaded && ld->n_spores == 1
              && fabsf(ld->spores[0].meaning_snap[5] - 0.25f) < 1e-6f
              && fabsf(ld->spores[0].meaning_snap[9] - 0.75f) < 1e-6f,
              "E-11 #3: spore meaning_snap survives save/load (v9)");
        test_leo_delete(sv); test_leo_delete(ld);
        remove(p);
    }

    /* E-11 #3: a v<=8 spore record (LeoSporeV8, no meaning_snap) migrates into the new
     * LeoSpore — every old field is preserved and meaning_snap comes up 0. This is the
     * exact memcpy+memset the v<=8 load path runs per spore; it guards the frozen
     * LeoSporeV8 layout against drift from LeoSpore's prefix. */
    {
        LeoSpore born; memset(&born, 0, sizeof born);
        born.chamber_snap[2] = 0.6f; born.retention_slice[3] = 0.4f;
        born.emit_context[0] = 99; born.step = 123; born.last_bleed_step = 45;
        born.pain_snap = 0.2f; born.strength = 0.8f; born.bleed_count = 11; born.is_trauma = 1;
        born.meaning_snap[7] = 0.9f;                 /* the v9-only field */
        LeoSporeV8 ondisk;
        memcpy(&ondisk, &born, sizeof(LeoSporeV8));  /* what the old binary wrote: the first sizeof(V8) bytes */
        LeoSpore loaded; memset(&loaded, 0, sizeof loaded);
        memcpy(&loaded, &ondisk, sizeof(LeoSporeV8));               /* loader: read the old record */
        memset(loaded.meaning_snap, 0, sizeof loaded.meaning_snap); /* loader: zero the new field */
        int fields_ok = loaded.chamber_snap[2] == 0.6f && loaded.retention_slice[3] == 0.4f
                      && loaded.emit_context[0] == 99 && loaded.step == 123 && loaded.last_bleed_step == 45
                      && loaded.pain_snap == 0.2f && loaded.strength == 0.8f
                      && loaded.bleed_count == 11 && loaded.is_trauma == 1;
        int meaning_zero = 1;
        for (int i = 0; i < GLYPH_COUNT; i++) if (loaded.meaning_snap[i] != 0.0f) meaning_zero = 0;
        CHECK(fields_ok && meaning_zero, "E-11 #3: v<=8 spore migrates (fields kept, meaning_snap=0)");
    }

}

static TEST_NOINLINE void test_gamma_capsule_bias(void) {
    /* E-11 #4 BE: the capsule (running-self) lifts a token tagged to its chamber once primed;
     * 0 when unprimed, --no-be, or --no-capsule (so the ablations stay byte-identical). */
    {
        Leo *b = test_leo_alloc(); leo_init(b);
        b->chamber_tag = (uint8_t *)calloc(LEO_MAX_VOCAB, sizeof(uint8_t));
        for (int i = 0; i < (int)LEO_MAX_VOCAB; i++) b->chamber_tag[i] = 0xFF;  /* untagged */
        int tok = 100;                       /* a base byte token (< vocab_size 256 after init) */
        b->chamber_tag[tok] = (uint8_t)LEO_CH_LOVE;
        b->gamma_primed = 1;
        b->gamma[LEO_CH_LOVE] = 0.5f;         /* the capsule carries love */
        float on = leo_be_bias(b, tok);
        b->gamma_primed = 0;  float unprimed = leo_be_bias(b, tok);  b->gamma_primed = 1;
        g_leo_be_on = 0;     float be_off   = leo_be_bias(b, tok);  g_leo_be_on = 1;
        g_leo_capsule_on = 0; float cap_off  = leo_be_bias(b, tok); g_leo_capsule_on = 1;
        CHECK(on > 0.0f && unprimed == 0.0f && be_off == 0.0f && cap_off == 0.0f,
              "E-11 #4 BE: capsule lifts a tagged token once primed; 0 unprimed / --no-be / --no-capsule");
        test_leo_delete(b);   /* frees chamber_tag */
    }

    /* §4 origin-wound: born from the dedication, bleeds through the santaclaus channel
     * when the live body resonates with the wound. Lives outside spores[] (sentinel idx). */
    {
        Leo *lo = test_leo_alloc(); leo_init(lo);
        for (int r = 0; r < 12; r++) leo_ingest(lo, LEO_EMBEDDED_BOOTSTRAP);  /* learn the origin's own words as tokens */
        leo_build_chamber_tags(lo);   /* tag them so the wound selects its emotional whole words */
        leo_birth_origin_spore(lo);
        int nctx = 0;
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++) if (lo->origin_spore.emit_context[k] >= 0) nctx++;
        CHECK(lo->has_origin == 1 && lo->origin_spore.is_trauma == 1 && lo->origin_spore.strength > 0.0f
              && nctx > 0, "§4 origin: born from dedication (trauma, strength, own emotional words)");

        /* set the live chambers to the wound's felt body -> resonance 1.0 -> the wound
         * enters the bleed top-K (lo has no ordinary spores, so it is the only slot). */
        memcpy(lo->chamber_act, lo->origin_spore.chamber_snap, sizeof lo->chamber_act);
        LeoSantaScratch sc; leo_santaclaus_compute_active(lo, &sc);
        int origin_active = 0;
        for (int i = 0; i < sc.n_active; i++) if (sc.spore_idx[i] == LEO_ORIGIN_SPORE_IDX) origin_active = 1;
        CHECK(origin_active == 1, "§4 origin: a resonant body puts the wound in the bleed top-K");

        /* the wound bleeds its OWN words: a token in origin emit_context gets a positive bias */
        int wound_tok = -1;
        for (int k = 0; k < LEO_SPORE_CONTEXT_TOK; k++)
            if (lo->origin_spore.emit_context[k] >= 0) { wound_tok = lo->origin_spore.emit_context[k]; break; }
        CHECK(leo_santaclaus_candidate_bias(&sc, lo, wound_tok) > 0.0f,
              "§4 origin: the wound bleeds its own word (positive candidate bias)");

        /* ablation: --no-origin-spore -> not born -> never enters the bleed, even on the same body */
        g_leo_origin_on = 0;
        Leo *lo2 = test_leo_alloc(); leo_init(lo2);
        leo_ingest(lo2, "the warm light and the quiet window, a small kind voice, home she said");
        leo_birth_origin_spore(lo2);
        memcpy(lo2->chamber_act, lo->origin_spore.chamber_snap, sizeof lo2->chamber_act);
        LeoSantaScratch sc2; leo_santaclaus_compute_active(lo2, &sc2);
        int origin_active2 = 0;
        for (int i = 0; i < sc2.n_active; i++) if (sc2.spore_idx[i] == LEO_ORIGIN_SPORE_IDX) origin_active2 = 1;
        CHECK(lo2->has_origin == 0 && origin_active2 == 0,
              "§4 origin: --no-origin-spore -> wound never born, never bleeds");
        g_leo_origin_on = 1;   /* restore for any later test */
        test_leo_delete(lo); test_leo_delete(lo2);
    }

    /* §4/Codex-1: the wound's body is the dedication's ALONE — the same chamber_snap
     * whatever the ambient body happens to be when it is born (settle-from-rest). */
    {
        Leo *la = test_leo_alloc(); leo_init(la);
        leo_ingest(la, "the warm light and the quiet window, a small kind voice, home she said");
        for (int c = 0; c < LEO_N_CHAMBERS; c++) la->chamber_act[c] = 0.9f;   /* ambient body A */
        leo_birth_origin_spore(la);
        float snapA[LEO_N_CHAMBERS]; memcpy(snapA, la->origin_spore.chamber_snap, sizeof snapA);
        for (int c = 0; c < LEO_N_CHAMBERS; c++) la->chamber_act[c] = 0.1f;   /* ambient body B */
        leo_birth_origin_spore(la);
        int same = 1;
        for (int c = 0; c < LEO_N_CHAMBERS; c++) if (la->origin_spore.chamber_snap[c] != snapA[c]) same = 0;
        CHECK(same, "§4/Codex-1 origin: chamber_snap deterministic (independent of ambient body at birth)");
        test_leo_delete(la);
    }

    /* §4/Codex-2: leo_load_state re-births the runtime-only wound, so a DIRECT loader
     * (not just main) gets has_origin — the "re-born on load" invariant holds. */
    {
        Leo *ls = test_leo_alloc(); leo_init(ls);
        leo_ingest(ls, "the warm light and the quiet window, a small kind voice, home she said");
        const char *sp = "/tmp/leo_origin_test.state";
        leo_save_state(ls, sp);
        Leo *ld = test_leo_alloc(); leo_init(ld);
        int r = leo_load_state(ld, sp);
        CHECK(r == 1 && ld->has_origin == 1,
              "§4/Codex-2 origin: leo_load_state re-births the wound (has_origin after load)");
        test_leo_delete(ls); test_leo_delete(ld); remove(sp);
    }

    /* echo metric (external_vocab) — the Phase-5 "became a chatbot" detector.
     * Pure read-only over (prompt, reply); content word = alpha len>=3 non-stop. */
    {
        CHECK(leo_echo_ratio("castle dragon thunder", "castle dragon thunder") > 0.999f,
              "echo: full parrot of content-words == 1.0");
        CHECK(leo_echo_ratio("castle dragon", "sunshine laughter") == 0.0f,
              "echo: disjoint content-words == 0.0");
        float half = leo_echo_ratio("castle", "castle sunshine");
        CHECK(half > 0.499f && half < 0.501f,
              "echo: one of two reply content-words echoes -> 0.5");
        CHECK(leo_echo_ratio("the castle", "the meadow") == 0.0f,
              "echo: shared stop-word 'the' is not counted (content disjoint == 0.0)");
        CHECK(leo_echo_ratio("hello castle", "") == 0.0f,
              "echo: empty reply == 0.0 (no divide-by-zero)");
        /* Fable re-audit #3: function words (you/what/are) are excluded like School's
         * gate, not just the stop-list — a fully field-grown reply no longer reads as
         * high echo (without the leo_word_is_function gate this returns 0.6). */
        CHECK(leo_echo_ratio("what do you see", "you know what you are") == 0.0f,
              "echo: function-word overlap counts 0 (School gate, not just stop-list)");
    }

}

static TEST_NOINLINE void test_async_ring_and_consolidation(void) {
    /* Chunk-4: the ring-input generates read-only from its OWN PRNG — deterministic per
     * cycle-seed, isolated from the reply's global rand() stream (gr1==gr2), and it never
     * ages the step clock (a background thought does not touch the reply's state). */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close.";
        Leo *l = test_leo_alloc(); leo_init(l);
        for (int r = 0; r < 3; r++) leo_ingest(l, corpus);
        leo_build_chamber_tags(l); leo_supertok_scan(l);
        long step_before = l->step;
        char a[512], b[512];
        srand(11); int na = leo_generate_ring(l, 42, a, sizeof a); int gr1 = rand();
        srand(11); int nb = leo_generate_ring(l, 42, b, sizeof b); int gr2 = rand();
        CHECK(na > 0, "ring: produced an utterance");
        CHECK(na == nb && strcmp(a, b) == 0, "ring: same cycle-seed -> identical read-only utterance");
        CHECK(gr1 == gr2, "ring: full generate path drew from its OWN PRNG, left global rand() untouched");
        CHECK(l->step == step_before, "ring: read-only — generation did not advance the step clock");
        test_leo_delete(l);
    }

    /* stage-1 consolidation: observer / weight law / selection / decay / persistence.
     * Design: DESIGN_LEO_HEBBIAN_CONSOLIDATION_2026-07-19 (five audit holes closed). */
    {
        const char *corpus =
            "The warm light. His mother holds him. The rain at night. "
            "Leo loves the warm light and his mother and the rain. "
            "The window is quiet. Leo is small and warm and close.";
        Leo *l = test_leo_alloc(); leo_init(l);
        for (int r = 0; r < 3; r++) leo_ingest(l, corpus);
        leo_build_chamber_tags(l); leo_supertok_scan(l);
        int ids[32];
        int n = bpe_encode(&l->bpe, (const uint8_t *)" the warm light and his mother",
                           30, ids, 32);
        /* observer refuses an unlit body (arousal gate) */
        memset(l->chamber_act, 0, sizeof l->chamber_act);
        leo_consol_observe(l, ids, n);
        CHECK(l->n_shards == 0, "consol: observer refuses an unlit body (arousal below threshold)");
        /* observer births on a lit body + a coherent (thrice-heard) path */
        l->chamber_act[LEO_CH_LOVE] = 0.8f;
        leo_consol_observe(l, ids, n);
        CHECK(l->n_shards == 1, "consol: observer births a shard on lit body + coherent path");
        CHECK(l->shards[0].weight == LEO_CONSOL_W0 && l->shards[0].born_coh > 0.0f,
              "consol: shard born with W0 weight and a real born_coh");
        /* held coherence enters phase-lock (EMA hysteresis) */
        for (int r = 0; r < 30; r++) leo_consol_observe(l, ids, n);
        CHECK(l->consol_locked == 1, "consol: held coherence enters phase-lock (EMA hysteresis)");
        /* habituation (margin gate, calibrated 07-19): the SAME moment repeated
         * converges into the EMA (rate 0.16 → ~14 calls) and then STOPS birthing —
         * further identical observes leave the ring unchanged. */
        {
            int ns_before = l->n_shards;
            for (int r = 0; r < 10; r++) leo_consol_observe(l, ids, n);
            CHECK(l->n_shards == ns_before && ns_before < 31,
                  "consol: habituation — a repeated moment stops birthing (margin over held EMA)");
        }
        /* the weight law: log1p+clamp bounds a huge delta; a worse reliving cools */
        LeoShard wsh; memset(&wsh, 0, sizeof wsh); wsh.weight = LEO_CONSOL_W0; wsh.born_coh = 1.0f;
        for (int r = 0; r < 100; r++) leo_consol_absorb(&wsh, 1000.0f);
        CHECK(isfinite(wsh.weight) && wsh.weight <= LEO_CONSOL_WMAX + 1e-6f,
              "consol: log1p+clamp bounds runaway growth (no NaN, hard ceiling)");
        float w_before = wsh.weight;
        leo_consol_absorb(&wsh, 0.0f);
        CHECK(wsh.weight < w_before, "consol: a worse reliving cools the shard");
        /* decay forgets a weight below the drop floor (compact) */
        memset(&l->shards[0], 0, sizeof(LeoShard));
        l->shards[0].weight = 0.01f; l->n_shards = 1;
        leo_consol_decay(l);
        CHECK(l->n_shards == 0, "consol: decay forgets a weight below the drop floor");
        /* replay selection follows RESONANCE, never weight (anti rich-get-richer) */
        for (int d = 0; d < LEO_RET_DIM; d++) l->retention_state[d] = (d % 2) ? 0.5f : -0.5f;
        LeoShard far_sh; memset(&far_sh, 0, sizeof far_sh);
        far_sh.weight = 2.0f; far_sh.n = 1; far_sh.ids[0] = 301;
        for (int d = 0; d < LEO_RET_DIM; d++) far_sh.state[d] = -l->retention_state[d];
        LeoShard near_sh; memset(&near_sh, 0, sizeof near_sh);
        near_sh.weight = 0.1f; near_sh.n = 1; near_sh.ids[0] = 300;
        for (int d = 0; d < LEO_RET_DIM; d++) near_sh.state[d] = l->retention_state[d];
        l->shards[0] = far_sh; l->shards[1] = near_sh; l->n_shards = 2;
        CHECK(leo_consol_select(l) == 1,
              "consol: replay selection follows resonance, never weight (anti rich-get-richer)");
        /* The v10 consolidation section still roundtrips inside the current v11 state. */
        const char *sp = "/tmp/leo_consol_test.state";
        l->consol_coh_ema = 0.6f; l->consol_locked = 1;
        CHECK(leo_save_state(l, sp) == 1, "consol: current state saves its v10 shard section");
        Leo *l2 = test_leo_alloc(); leo_init(l2);
        CHECK(leo_load_state(l2, sp) == 1 && l2->n_shards == 2 &&
              l2->shards[1].ids[0] == 300 && l2->consol_locked == 1,
              "consol: current state roundtrips the v10 shard ring + sleep trigger");
        /* Half-write probe: build an exact v10 prefix, then cut its final
         * consolidation byte — the organism lives, shardless. */
        {
            FILE *tf = fopen(sp, "rb");
            fseek(tf, 0, SEEK_END); long fl = ftell(tf); fseek(tf, 0, SEEK_SET);
            char *fb = malloc((size_t)fl); fread(fb, 1, (size_t)fl, tf); fclose(tf);
            long after_v10 =
                (long)(4 * sizeof(int32_t) + sizeof(uint64_t) +
                       l->school.n_wonders *
                           (int)sizeof(LeoWonderEpisodeV27) +
                       2 * sizeof(int32_t) +
                       l->flow.n * (int)sizeof(LeoFlowSnapshot) +
                       2 * sizeof(int32_t) +
                       l->flow.n_currents *
                           (int)sizeof(LeoFlowWonderCurrent) +
                       2 * sizeof(int32_t) +
                       l->shadow.n * (int)sizeof(LeoShadowReceipt) +
                       2 * sizeof(int32_t) +
                       l->calibration.n *
                           (int)sizeof(LeoCalibrationReceipt) +
                       sizeof(int32_t) +
                       l->school.n_deferred *
                           (int)sizeof(LeoDeferredWonder) +
                       sizeof(int32_t) +
                       (l->school.has_pending_origin ?
                        sizeof(LeoDeferredWonder) : 0)) +
                test_appetite_and_later_tail_size(l);
            uint32_t ten = 10;
            memcpy(fb + sizeof(uint32_t), &ten, sizeof ten);
            tf = fopen(sp, "wb");
            fwrite(fb, 1, (size_t)(fl - after_v10 - 1), tf);
            fclose(tf);
            free(fb);
        }
        Leo *l3 = test_leo_alloc(); leo_init(l3);
        CHECK(leo_load_state(l3, sp) == 1 && l3->n_shards == 0,
              "consol: a truncated v10 section fails SOFT — organism lives, shards zero");
        test_leo_delete(l2); test_leo_delete(l3); remove(sp);
        test_leo_delete(l);
    }

}

static TEST_NOINLINE void test_state_swarm(void) {
    /* A.79: passive tiny weights over lived states and their transitions.
     * The organ learns after speech, survives sleep, and remains byte-inert. */
    {
        const char *corpus =
            "The warm light is quiet. The dark storm moves at night. "
            "Warm rain and cool water move through the small room.";
        int previous_swarm = g_leo_state_swarm_on;
        int previous_transition_plasticity =
            g_leo_state_transition_plasticity_on;
        int previous_relational_transition =
            g_leo_state_relational_transition_on;
        g_leo_state_swarm_on = 1;
        CHECK(g_leo_state_relational_transition_on == 1,
              "state-swarm relational transition: the confirmed runtime law is admitted by default");
        g_leo_state_transition_plasticity_on = 1;
        CHECK(fabsf(leo_state_transition_plasticity(1.0f, 1) - 1.0f) < 1e-6f &&
              fabsf(leo_state_transition_plasticity(0.0f, 1) - 1.25f) < 1e-6f &&
              fabsf(leo_state_transition_plasticity(0.5f, 1) - 1.125f) < 1e-6f &&
              fabsf(leo_state_transition_plasticity(0.0f, 0) - 1.0f) < 1e-6f &&
              fabsf(leo_state_transition_plasticity(NAN, 1) - 1.0f) < 1e-6f,
              "state-swarm plasticity: only a finite pre-update road miss can deepen the bounded step");
        g_leo_state_transition_plasticity_on = 0;
        CHECK(fabsf(leo_state_transition_plasticity(0.0f, 1) - 1.0f) < 1e-6f,
              "state-swarm plasticity: the dedicated ablation restores the A.79 learning rate");
        g_leo_state_transition_plasticity_on = 1;
        {
            float full_relation[LEO_STATE_OUTCOMES] =
                {0.0f, 0.20f, 0.40f, 0.0f};
            float partial_relation[LEO_STATE_OUTCOMES] =
                {0.0f, 0.40f, 0.20f, 0.0f};
            float closed_relation[LEO_STATE_OUTCOMES] =
                {0.0f, 0.20f, -0.10f, 0.0f};
            CHECK(fabsf(leo_state_relational_transition_share(full_relation) -
                        1.0f) < 1e-6f &&
                  fabsf(leo_state_relational_transition_share(partial_relation) -
                        0.5f) < 1e-6f &&
                  leo_state_relational_transition_share(closed_relation) == 0.0f,
                  "state-swarm relational transition: semantic closure is measured against positive distress relief without texture labels");

            LeoStateSwarm *road = calloc(1, sizeof *road);
            LeoStateSwarm *closed = calloc(1, sizeof *closed);
            LeoStateSwarm *disabled = calloc(1, sizeof *disabled);
            float source[LEO_STATE_SWARM_MAX] = {0.75f, 0.25f};
            float target[LEO_STATE_SWARM_MAX] = {0.25f, 0.75f};
            if (road && closed && disabled) {
                road->n = 2;
                road->transition[0][0] = 0.30f;
                road->transition[0][1] = 0.70f;
                road->transition[1][0] = 0.80f;
                road->transition[1][1] = 0.20f;
                *closed = *road;
                *disabled = *road;
                g_leo_state_relational_transition_on = 1;
                int applied = leo_state_relational_transition_update(
                    road, source, target, 0.20f, 1, full_relation);
                float row0_mass =
                    road->transition[0][0] + road->transition[0][1];
                float row1_mass =
                    road->transition[1][0] + road->transition[1][1];
                float legacy_row0_first =
                    (0.30f + 0.20f * 0.75f * 0.25f) / 1.15f;
                float legacy_row1_first =
                    (0.80f + 0.20f * 0.25f * 0.25f) / 1.05f;
                CHECK(applied && fabsf(row0_mass - 1.15f) < 1e-6f &&
                      fabsf(row1_mass - 1.05f) < 1e-6f &&
                      road->transition[0][0] / row0_mass < legacy_row0_first &&
                      road->transition[1][0] / row1_mass < legacy_row1_first,
                      "state-swarm relational transition: miss accelerates only conditional destination motion while preserving A.79 row mass");
                CHECK(!leo_state_relational_transition_update(
                          closed, source, target, 0.20f, 1,
                          closed_relation) &&
                      !memcmp(closed, disabled, sizeof *closed),
                      "state-swarm relational transition: a non-closing semantic gap is an exact A.79 ablation");
                g_leo_state_relational_transition_on = 0;
                CHECK(!leo_state_relational_transition_update(
                          disabled, source, target, 0.20f, 1,
                          full_relation) &&
                      disabled->transition[0][0] == 0.30f &&
                      disabled->transition[1][1] == 0.20f,
                      "state-swarm relational transition: the explicit ablation restores the inert A.79 path");
            } else {
                CHECK(0, "state-swarm relational transition: mass fixtures allocated");
                CHECK(0, "state-swarm relational transition: closed-gap fixtures allocated");
                CHECK(0, "state-swarm relational transition: ablation fixtures allocated");
            }
            free(road); free(closed); free(disabled);
        }
        g_leo_state_relational_transition_on = 0;
        Leo *state = malloc(sizeof *state);
        Leo *woke = malloc(sizeof *woke);
        Leo *old = malloc(sizeof *old);
        Leo *damaged = malloc(sizeof *damaged);
        int state_initialized = 0, woke_initialized = 0;
        int old_initialized = 0, damaged_initialized = 0;
        CHECK(state && woke && old && damaged,
              "state-swarm: heap fixtures allocated");
        if (state && woke && old && damaged) {
            leo_init(state);
            state_initialized = 1;
            leo_ingest(state, corpus);
            int water = semtok_find_glyph("water");
            int fire = semtok_find_glyph("fire");
            int light = semtok_find_glyph("light");
            int dark = semtok_find_glyph("dark");

            test_state_swarm_turn(state, 1, water, fire, light, dark,
                                  1.0f, 0.0f, 0, "The warm light.");
            CHECK(state->state_swarm && state->state_swarm->n == 1 &&
                  state->state_swarm_receipt.event == LEO_STATE_SWARM_BORN &&
                  state->state_swarm->weights[0].observations == 1,
                  "state-swarm: a first lived configuration births one unnamed tiny weight");
            CHECK(state->state_swarm_receipt.members == 1 &&
                  state->state_swarm_receipt.member_id[0] == 1 &&
                  fabsf(state->state_swarm_receipt.member_activation[0] - 1.0f) < 1e-6f &&
                  leo_state_organ_receipt(state) &&
                  !leo_state_organ_receipt(state)->valid[0] &&
                  !leo_state_organ_receipt(state)->nearest_valid &&
                  !state->state_swarm_receipt.nearest_id &&
                  !state->state_swarm_receipt.adjacent &&
                  !state->state_swarm_receipt.has_prediction,
                  "state-swarm: a birth exposes activation but does not launder self-similarity into organ evidence");

            test_state_swarm_turn(state, 2, water, fire, light, dark,
                                  1.0f, 0.0f, 0, "The warm light.");
            CHECK(state->state_swarm->n == 1 &&
                  state->state_swarm_receipt.event == LEO_STATE_SWARM_UPDATED &&
                  state->state_swarm->weights[0].observations == 2 &&
                  state->state_swarm_receipt.active == 1 &&
                  state->state_swarm_receipt.nearest_id == 1 &&
                  leo_state_organ_receipt(state) &&
                  leo_state_organ_receipt(state)->valid[0] &&
                  leo_state_organ_receipt(state)->nearest_valid,
                  "state-swarm: a repeated life deepens one state instead of multiplying names");
            {
                const float *organ =
                    leo_state_organ_receipt(state)->similarity[0];
                float reconstructed =
                    0.19f * organ[LEO_STATE_ORGAN_PERCEPTION] +
                    0.19f * organ[LEO_STATE_ORGAN_EXPRESSION] +
                    0.10f * organ[LEO_STATE_ORGAN_FIELD] +
                    0.20f * organ[LEO_STATE_ORGAN_BODY] +
                    0.18f * organ[LEO_STATE_ORGAN_RHYTHM] +
                    0.07f * organ[LEO_STATE_ORGAN_FORM] +
                    0.07f * organ[LEO_STATE_ORGAN_DARKMATTER];
                CHECK(fabsf(reconstructed -
                            state->state_swarm_receipt.similarity) < 1e-6f,
                      "state-swarm: seven organ witnesses reconstruct the unchanged holistic similarity");
            }
            CHECK(state->state_swarm_receipt.adjacent &&
                  !state->state_swarm_receipt.has_prediction &&
                  fabsf(state->state_swarm_receipt.observed_outcome
                            [LEO_STATE_OUTCOME_GROUNDED]) < 1e-6f,
                  "state-swarm: an adjacent turn records its consequence even before a learned edge can forecast it");

            test_state_swarm_turn(
                state, 3, water, fire, light, dark, 0.0f, 1.0f,
                LEO_FLOW_WONDER_RESOLVED, "The dark storm.");
            float first_fast_clock =
                state->state_swarm->weights[0].clocks[0];
            float first_transition =
                state->state_swarm->transition[0][1];
            CHECK(state->state_swarm->n == 2 &&
                  state->state_swarm_receipt.event == LEO_STATE_SWARM_BORN &&
                  state->state_swarm->transition[0][1] > 0.0f &&
                  state->state_swarm->outcome[0][1]
                      [LEO_STATE_OUTCOME_GROUNDED] > 0.0f,
                  "state-swarm: a distinct life births a second weight and records how the transition ended");
            CHECK(state->state_swarm_receipt.members == 2 &&
                  state->state_swarm_receipt.member_id[1] == 2 &&
                  fabsf(state->state_swarm_receipt.member_activation[1] - 1.0f) < 1e-6f &&
                  leo_state_organ_receipt(state) &&
                  leo_state_organ_receipt(state)->valid[0] &&
                  !leo_state_organ_receipt(state)->valid[1] &&
                  state->state_swarm_receipt.has_prediction &&
                  state->state_swarm_receipt.expected_id == 1 &&
                  state->state_swarm_receipt.prediction_overlap < 1e-6f &&
                  state->state_swarm_receipt.surprise > 10.0f &&
                  state->state_swarm_receipt.observed_outcome
                      [LEO_STATE_OUTCOME_GROUNDED] > 0.99f &&
                  fabsf(state->state_swarm_receipt.predicted_outcome
                            [LEO_STATE_OUTCOME_GROUNDED]) < 1e-6f,
                  "state-swarm: the witness scores a pre-update miss and keeps forecast separate from observed consequence");
            CHECK(first_fast_clock < 1.0f &&
                  state->state_swarm->weights[0].clocks[3] > first_fast_clock,
                  "state-swarm: unused experience fades on several clocks instead of one global decay");

            memcpy(state->state_swarm->weights[1].rhythm_dist,
                   state->state_swarm->weights[0].rhythm_dist,
                   sizeof state->state_swarm->weights[0].rhythm_dist);
            memcpy(state->state_swarm->weights[1].rhythm_class,
                   state->state_swarm->weights[0].rhythm_class,
                   sizeof state->state_swarm->weights[0].rhythm_class);
            test_state_swarm_turn(state, 4, water, fire, light, dark,
                                  0.5f, 0.5f, 0, "The warm light.");
            CHECK(state->state_swarm->n == 2 &&
                  state->state_swarm_receipt.active == 2 &&
                  state->state_swarm_receipt.entropy > 0.5f,
                  "state-swarm: an ambiguous turn may inhabit a swarm instead of a forced single state");
            CHECK(state->state_swarm->transition[0][1] < first_transition,
                  "state-swarm: an unvisited sequence edge cools instead of becoming permanent law");
            CHECK(state->state_swarm->updates == 4 &&
                  leo_state_swarm_valid(state),
                  "state-swarm: the four-turn state sequence remains finite and internally valid");

            const char *saved = "/tmp/leo_state_swarm_v28.state";
            const char *v26 = "/tmp/leo_state_swarm_v26.state";
            const char *cut = "/tmp/leo_state_swarm_v27_cut.state";
            const char *bad = "/tmp/leo_state_swarm_v27_bad.state";
            int saved_ok = leo_save_state(state, saved);
            leo_init(woke);
            woke_initialized = 1;
            CHECK(saved_ok && leo_load_state(woke, saved) &&
                  woke->state_swarm &&
                  !memcmp(woke->state_swarm, state->state_swarm,
                          sizeof *state->state_swarm),
                  "state-swarm: tiny weights, sequence, clocks, and outcomes survive sleep exactly");

            int built_v26 = 0, built_cut = 0, built_bad = 0;
            FILE *fi = fopen(saved, "rb");
            if (fi) {
                fseek(fi, 0, SEEK_END);
                long size = ftell(fi);
                fseek(fi, 0, SEEK_SET);
                long swarm_tail = (long)sizeof(LeoStateSwarm);
                long pair_tail = (long)(2 * sizeof(int32_t) +
                    state->school.n_learned * (int)sizeof(int8_t) +
                    state->school.n_wonders * (int)sizeof(int8_t));
                long v27_size = size - pair_tail;
                unsigned char *bytes =
                    malloc(size > 0 ? (size_t)size : 1);
                if (bytes && v27_size > swarm_tail &&
                    (long)fread(bytes, 1, (size_t)size, fi) == size) {
                    uint32_t version = 26;
                    memcpy(bytes + sizeof(uint32_t), &version,
                           sizeof version);
                    FILE *fo = fopen(v26, "wb");
                    if (fo) {
                        built_v26 =
                            (long)fwrite(bytes, 1,
                                         (size_t)(v27_size - swarm_tail), fo) ==
                                v27_size - swarm_tail;
                        fclose(fo);
                    }

                    version = 27;
                    memcpy(bytes + sizeof(uint32_t), &version,
                           sizeof version);
                    fo = fopen(cut, "wb");
                    if (fo) {
                        built_cut =
                            (long)fwrite(bytes, 1,
                                         (size_t)(v27_size - 1), fo) ==
                                v27_size - 1;
                        fclose(fo);
                    }

                    LeoStateSwarm corrupt;
                    memcpy(&corrupt,
                           bytes + v27_size - swarm_tail,
                           sizeof corrupt);
                    corrupt.n = LEO_STATE_SWARM_MAX + 1;
                    memcpy(bytes + v27_size - swarm_tail,
                           &corrupt, sizeof corrupt);
                    fo = fopen(bad, "wb");
                    if (fo) {
                        built_bad =
                            (long)fwrite(bytes, 1,
                                         (size_t)v27_size, fo) == v27_size;
                        fclose(fo);
                    }
                }
                free(bytes);
                fclose(fi);
            }

            leo_init(old);
            old_initialized = 1;
            CHECK(built_v26 && leo_load_state(old, v26) &&
                  old->state_swarm && old->state_swarm->n == 0 &&
                  old->state_swarm->next_id == 1 &&
                  old->flow.n == state->flow.n,
                  "state-swarm: a v26 body wakes without invented state experience");
            leo_init(damaged);
            damaged_initialized = 1;
            CHECK(built_cut && leo_load_state(damaged, cut) &&
                  damaged->state_swarm && damaged->state_swarm->n == 0 &&
                  damaged->flow.n == state->flow.n,
                  "state-swarm: a truncated v27 tail loses no earlier body or Flow life");
            leo_free(damaged);
            leo_init(damaged);
            CHECK(built_bad && leo_load_state(damaged, bad) &&
                  damaged->state_swarm && damaged->state_swarm->n == 0 &&
                  damaged->flow.n == state->flow.n,
                  "state-swarm: corrupt tiny weights fail soft without poisoning Leo");
            remove(saved); remove(v26); remove(cut); remove(bad);
        }

        Leo *full = malloc(sizeof *full);
        if (full) {
            leo_init(full);
            leo_ingest(full, corpus);
            full->state_swarm->n = LEO_STATE_SWARM_MAX;
            full->state_swarm->next_id = LEO_STATE_SWARM_MAX + 1;
            for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
                LeoStateWeight *weight = &full->state_swarm->weights[i];
                leo_state_weight_clear(weight);
                weight->id = (uint64_t)i + 1;
                weight->born_turn = weight->last_turn = 1;
                weight->observations = 1;
                weight->mode_mass[LEO_MODE_WALK] = 1.0f;
                for (int c = 0; c < LEO_STATE_CLOCKS; c++)
                    weight->clocks[c] = i == 0 ? 0.0f : 0.5f;
            }
            test_state_swarm_turn(
                full, 1, semtok_find_glyph("water"),
                semtok_find_glyph("fire"), semtok_find_glyph("light"),
                semtok_find_glyph("dark"), 1.0f, 1.0f, 0,
                "The warm light.");
            CHECK(full->state_swarm_receipt.event ==
                      LEO_STATE_SWARM_REPLACED &&
                  full->state_swarm_receipt.replaced_id == 1 &&
                  full->state_swarm->n == LEO_STATE_SWARM_MAX &&
                  full->state_swarm->weights[0].id ==
                      LEO_STATE_SWARM_MAX + 1 &&
                  full->state_swarm_receipt.nearest_id > 0 &&
                  leo_state_organ_receipt(full)->nearest_valid &&
                  leo_state_organ_receipt(full)->removed_valid &&
                  leo_state_swarm_valid(full),
                  "state-swarm: a full swarm replaces its weakest decayed coordinate, not its strongest memory");
            {
                const float *nearest =
                    leo_state_organ_receipt(full)->nearest_similarity;
                float reconstructed =
                    0.19f * nearest[LEO_STATE_ORGAN_PERCEPTION] +
                    0.19f * nearest[LEO_STATE_ORGAN_EXPRESSION] +
                    0.10f * nearest[LEO_STATE_ORGAN_FIELD] +
                    0.20f * nearest[LEO_STATE_ORGAN_BODY] +
                    0.18f * nearest[LEO_STATE_ORGAN_RHYTHM] +
                    0.07f * nearest[LEO_STATE_ORGAN_FORM] +
                    0.07f * nearest[LEO_STATE_ORGAN_DARKMATTER];
                CHECK(fabsf(reconstructed -
                            full->state_swarm_receipt.similarity) < 1e-6f,
                      "state-swarm: replacement preserves the nearest pre-update organ witness");
            }
            leo_free(full);
            free(full);
        } else {
            CHECK(0, "state-swarm: replacement fixture allocated");
        }

        Leo *plastic_on = malloc(sizeof *plastic_on);
        Leo *plastic_off = malloc(sizeof *plastic_off);
        CHECK(plastic_on && plastic_off,
              "state-swarm plasticity: paired road fixtures allocated");
        if (plastic_on && plastic_off) {
            leo_init(plastic_on); leo_init(plastic_off);
            leo_ingest(plastic_on, corpus); leo_ingest(plastic_off, corpus);
            int water = semtok_find_glyph("water");
            int fire = semtok_find_glyph("fire");
            int light = semtok_find_glyph("light");
            int dark = semtok_find_glyph("dark");
            for (int turn = 1; turn <= 3; turn++) {
                float mix = turn == 2 ? 0.0f : 1.0f;
                float gap = turn == 2 ? 1.0f : 0.0f;
                const char *reply = turn == 2 ?
                    "The dark storm." : "The warm light.";
                g_leo_state_transition_plasticity_on = 1;
                test_state_swarm_turn(plastic_on, (uint64_t)turn,
                                      water, fire, light, dark,
                                      mix, gap, 0, reply);
                test_state_swarm_turn(plastic_off, (uint64_t)turn,
                                      water, fire, light, dark,
                                      mix, gap, 0, reply);
            }
            CHECK(!memcmp(plastic_on->state_swarm, plastic_off->state_swarm,
                          sizeof *plastic_on->state_swarm),
                  "state-swarm plasticity: bodies remain exact before a mature road can forecast");

            g_leo_state_transition_plasticity_on = 1;
            test_state_swarm_turn(plastic_on, 4, water, fire, light, dark,
                                  0.75f, 0.25f, 0, "The warm light moves.");
            g_leo_state_transition_plasticity_on = 0;
            test_state_swarm_turn(plastic_off, 4, water, fire, light, dark,
                                  0.75f, 0.25f, 0, "The warm light moves.");

            int same_membership =
                plastic_on->state_swarm_receipt.members ==
                    plastic_off->state_swarm_receipt.members &&
                plastic_on->state_swarm_receipt.winner_id ==
                    plastic_off->state_swarm_receipt.winner_id &&
                plastic_on->state_swarm_receipt.event ==
                    plastic_off->state_swarm_receipt.event &&
                !memcmp(plastic_on->state_swarm_receipt.member_id,
                        plastic_off->state_swarm_receipt.member_id,
                        sizeof plastic_on->state_swarm_receipt.member_id) &&
                !memcmp(plastic_on->state_swarm_receipt.member_activation,
                        plastic_off->state_swarm_receipt.member_activation,
                        sizeof plastic_on->state_swarm_receipt.member_activation);
            CHECK(same_membership &&
                  plastic_on->state_swarm_receipt.has_prediction &&
                  plastic_off->state_swarm_receipt.has_prediction &&
                  fabsf(plastic_on->state_swarm_receipt.prediction_overlap -
                        plastic_off->state_swarm_receipt.prediction_overlap) < 1e-6f,
                  "state-swarm plasticity: the road cannot rewrite current membership or manufacture a forecast");
            g_leo_state_transition_plasticity_on = 1;
            float applied_plasticity = leo_state_transition_plasticity(
                plastic_on->state_swarm_receipt.prediction_overlap,
                plastic_on->state_swarm_receipt.has_prediction);
            g_leo_state_transition_plasticity_on = 0;
            CHECK(applied_plasticity > 1.0f &&
                  applied_plasticity <= 1.25f &&
                  memcmp(plastic_on->state_swarm->weights,
                         plastic_off->state_swarm->weights,
                         sizeof plastic_on->state_swarm->weights) &&
                  leo_state_swarm_valid(plastic_on) &&
                  leo_state_swarm_valid(plastic_off),
                  "state-swarm plasticity: surprise changes only the bounded post-membership prototype step");
            CHECK(!memcmp(&plastic_on->flow, &plastic_off->flow,
                          sizeof plastic_on->flow) &&
                  !memcmp(plastic_on->retention_state,
                          plastic_off->retention_state,
                          sizeof plastic_on->retention_state) &&
                  !memcmp(plastic_on->chamber_act,
                          plastic_off->chamber_act,
                          sizeof plastic_on->chamber_act),
                  "state-swarm plasticity: the internal learning fork reaches no older organ");
            leo_free(plastic_on); leo_free(plastic_off);
        }
        free(plastic_on); free(plastic_off);
        g_leo_state_transition_plasticity_on = 1;

        Leo *voice_on = malloc(sizeof *voice_on);
        Leo *voice_off = malloc(sizeof *voice_off);
        CHECK(voice_on && voice_off,
              "state-swarm: inert-voice fixtures allocated");
        if (voice_on && voice_off) {
            leo_init(voice_on); leo_init(voice_off);
            leo_ingest(voice_on, corpus); leo_ingest(voice_off, corpus);
            const char *prompts[] = {
                "What moves in the warm rain?",
                "The dark room remembers light.",
                "What do you still not know?"
            };
            int same_voice = 1;
            for (int i = 0; i < 3; i++) {
                char on[512], off[512];
                g_leo_state_swarm_on = 1;
                srand(790 + i);
                leo_respond(voice_on, prompts[i], on, sizeof on);
                g_leo_state_swarm_on = 0;
                srand(790 + i);
                leo_respond(voice_off, prompts[i], off, sizeof off);
                if (strcmp(on, off)) same_voice = 0;
            }
            CHECK(same_voice && voice_on->state_swarm->n > 0 &&
                  voice_off->state_swarm->n == 0 &&
                  !memcmp(&voice_on->flow, &voice_off->flow,
                          sizeof voice_on->flow) &&
                  !memcmp(voice_on->retention_state,
                          voice_off->retention_state,
                          sizeof voice_on->retention_state) &&
                  !memcmp(voice_on->chamber_act, voice_off->chamber_act,
                          sizeof voice_on->chamber_act),
                  "state-swarm: default-on and --no-state-swarm are byte-identical outside the shadow weights");
            leo_free(voice_on); leo_free(voice_off);
        }
        free(voice_on); free(voice_off);

        if (state_initialized) leo_free(state);
        if (woke_initialized) leo_free(woke);
        if (old_initialized) leo_free(old);
        if (damaged_initialized) leo_free(damaged);
        free(state); free(woke); free(old); free(damaged);
        g_leo_state_swarm_on = previous_swarm;
        g_leo_state_transition_plasticity_on =
            previous_transition_plasticity;
        g_leo_state_relational_transition_on =
            previous_relational_transition;
    }

}

int main(void) {
    printf("test_leo (step 0)\n");
    test_foundation();
    test_voice_field_and_persistence();
    test_heard_and_chambers();
    test_state_persistence();
    test_spore_resurrection();
    test_atomic_state();
    test_breath_retag();
    test_multiturn_presence();
    test_rae_and_school();
    test_rae_runtime();
    test_rae_persistence();
    test_school_learning();
    test_prewonder_recovery();
    test_prewonder_constellation();
    test_prewonder_occupied_queue();
    test_prewonder_semantic_shadow();
    test_wonder_address();
    test_wonder_redirection();
    test_wonder_appetite();
    test_wonder_appetite_calibration();
    test_wonder_appetite_reliability();
    test_school_form_and_wonder();
    test_natural_school_word_boundary();
    test_school_lexical_family();
    test_school_family_heard_threshold();
    test_school_two_layer_family_composition();
    test_school_negative_family();
    test_school_reciprocal_s_family();
    test_school_lexical_role();
    test_wonder_persistence();
    test_wonder_ablation();
    test_wonder_negation();
    test_wonder_answer_reference();
    test_wonder_answer_scope();
    test_wonder_answer_followup();
    test_reference_predication_boundary();
    test_wonder_natural_answer_form();
    test_wonder_plural_answer_capacity();
    test_wonder_two_glyph_learned_meaning();
    test_wonder_reask_reference();
    test_wonder_return();
    test_flow();
    test_shadow_scheduler();
    test_klaus_and_gamma();
    test_gamma_meaning_spores();
    test_gamma_capsule_bias();
    test_async_ring_and_consolidation();
    test_state_swarm();
    printf("\n%d/%d passed\n", g_pass, g_total);
    int result = (g_pass == g_total) ? 0 : 1;
    test_leo_release_storage();
    return result;
}
