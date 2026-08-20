#define LEO_NO_MAIN
#include "../leo.c"

static Leo *load_leo(const char *path) {
    Leo *leo = malloc(sizeof *leo);
    if (!leo) return NULL;
    leo_init(leo);
    if (!leo_load_state(leo, path)) {
        leo_free(leo);
        free(leo);
        return NULL;
    }
    return leo;
}

static float reference_clamp(float value, float low, float high) {
    return value < low ? low : (value > high ? high : value);
}

static float reference_share(const float outcome[LEO_STATE_OUTCOMES]) {
    float gap = fmaxf(outcome[LEO_STATE_OUTCOME_GAP_RELIEF], 0.0f);
    float distress = fmaxf(
        outcome[LEO_STATE_OUTCOME_DISTRESS_RELIEF], 0.0f);
    float denominator = fmaxf(gap, distress);
    return denominator > 0.0f ?
        reference_clamp(gap / denominator, 0.0f, 1.0f) : 0.0f;
}

static void reference_legacy_write(
        float transition[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX],
        const float source[LEO_STATE_SWARM_MAX],
        const float target[LEO_STATE_SWARM_MAX], uint32_t n) {
    for (uint32_t i = 0; i < n; i++)
        for (uint32_t j = 0; j < n; j++) {
            float pair = source[i] * target[j];
            if (pair <= 1e-6f) continue;
            transition[i][j] = reference_clamp(
                transition[i][j] + 0.20f * pair,
                0.0f, 1000000.0f);
        }
}

/* This is deliberately independent of leo_state_relational_transition_update.
 * It re-states the sealed A.113 law from exact persisted inputs. */
static int reference_relational_write(
        float transition[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX],
        const float source[LEO_STATE_SWARM_MAX],
        const float target[LEO_STATE_SWARM_MAX], uint32_t n,
        float overlap, const float outcome[LEO_STATE_OUTCOMES]) {
    float miss = 1.0f - reference_clamp(overlap, 0.0f, 1.0f);
    float share = reference_share(outcome);
    float extra = 0.50f * miss * share;
    if (!(extra > 0.0f) || !isfinite(extra)) {
        reference_legacy_write(transition, source, target, n);
        return 0;
    }
    for (uint32_t i = 0; i < n; i++) {
        float row_mass = 0.0f;
        for (uint32_t j = 0; j < n; j++) row_mass += transition[i][j];
        float added_mass = 0.20f * source[i];
        float new_mass = row_mass + added_mass;
        if (!(new_mass > 0.0f) || !isfinite(new_mass)) continue;
        if (!(row_mass > 0.0f)) {
            for (uint32_t j = 0; j < n; j++)
                transition[i][j] = added_mass * target[j];
            continue;
        }
        float rate = (added_mass / new_mass) * (1.0f + extra);
        rate = reference_clamp(rate, 0.0f, 1.0f);
        for (uint32_t j = 0; j < n; j++) {
            float probability = transition[i][j] / row_mass;
            probability += rate * (target[j] - probability);
            transition[i][j] = new_mass * probability;
        }
    }
    return 1;
}

static int same_topology(const LeoStateSwarm *before,
                         const LeoStateSwarm *after) {
    if (before->n != after->n) return 0;
    for (uint32_t i = 0; i < before->n; i++)
        if (before->weights[i].id != after->weights[i].id) return 0;
    return 1;
}

static int compare_reference(const char *before_path,
                             const char *after_path) {
    Leo *before = load_leo(before_path);
    Leo *after = load_leo(after_path);
    if (!before || !after || !before->state_swarm || !after->state_swarm) {
        if (before) { leo_free(before); free(before); }
        if (after) { leo_free(after); free(after); }
        return 1;
    }
    const LeoStateSwarm *pre = before->state_swarm;
    const LeoStateSwarm *post = after->state_swarm;
    if (!pre->has_previous || !post->has_previous ||
        post->previous_turn != pre->previous_turn + 1 ||
        !same_topology(pre, post)) {
        printf("censored\t0.000000000\t0.000000000\t0\n");
        leo_free(before); free(before);
        leo_free(after); free(after);
        return 0;
    }

    float expected[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX];
    float control[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX];
    memcpy(expected, pre->transition, sizeof expected);
    for (uint32_t i = 0; i < pre->n; i++)
        for (uint32_t j = 0; j < pre->n; j++)
            expected[i][j] *= 0.997f;
    memcpy(control, expected, sizeof control);

    float prediction[LEO_STATE_SWARM_MAX] = {0};
    float prediction_total = 0.0f;
    for (uint32_t i = 0; i < pre->n; i++)
        for (uint32_t j = 0; j < pre->n; j++) {
            float edge = pre->previous_activation[i] * expected[i][j];
            prediction[j] += edge;
            prediction_total += edge;
        }
    float overlap = 0.0f;
    int has_prediction = prediction_total > 0.0f;
    if (has_prediction)
        for (uint32_t j = 0; j < pre->n; j++) {
            prediction[j] /= prediction_total;
            overlap += prediction[j] * post->previous_activation[j];
        }
    float outcome[LEO_STATE_OUTCOMES] = {
        0.0f,
        reference_clamp(pre->previous_distress - post->previous_distress,
                        -1.0f, 1.0f),
        reference_clamp(pre->previous_gap - post->previous_gap,
                        -1.0f, 1.0f),
        reference_clamp(post->previous_alignment - pre->previous_alignment,
                        -1.0f, 1.0f)
    };
    int changed = 0;
    if (has_prediction)
        changed = reference_relational_write(
            expected, pre->previous_activation, post->previous_activation,
            pre->n, overlap, outcome);
    else
        reference_legacy_write(
            expected, pre->previous_activation, post->previous_activation,
            pre->n);
    reference_legacy_write(
        control, pre->previous_activation, post->previous_activation, pre->n);
    if (memcmp(expected, post->transition, sizeof expected) != 0) {
        fprintf(stderr, "runtime transition bytes differ from A.113 reference\n");
        leo_free(before); free(before);
        leo_free(after); free(after);
        return 1;
    }
    changed = changed && memcmp(expected, control, sizeof expected) != 0;
    printf("%s\t%.9f\t%.9f\t%d\n",
           has_prediction ? "exact" : "censored", (double)overlap,
           (double)reference_share(outcome), changed);
    leo_free(before); free(before);
    leo_free(after); free(after);
    return 0;
}

static unsigned char *read_file(const char *path, size_t *size_out) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long length = ftell(f);
    if (length < 0 || fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return NULL;
    }
    unsigned char *bytes = malloc((size_t)length);
    if (!bytes || fread(bytes, 1, (size_t)length, f) != (size_t)length) {
        free(bytes);
        fclose(f);
        return NULL;
    }
    fclose(f);
    *size_out = (size_t)length;
    return bytes;
}

static int compare_transition_only(const char *left_path,
                                   const char *right_path) {
    size_t left_size = 0, right_size = 0;
    unsigned char *left = read_file(left_path, &left_size);
    unsigned char *right = read_file(right_path, &right_size);
    if (!left || !right || left_size != right_size ||
        left_size < sizeof(LeoStateSwarm)) {
        free(left); free(right);
        return 1;
    }
    size_t prefix = left_size - sizeof(LeoStateSwarm);
    LeoStateSwarm left_tail, right_tail;
    memcpy(&left_tail, left + prefix, sizeof left_tail);
    memcpy(&right_tail, right + prefix, sizeof right_tail);
    memset(left_tail.transition, 0, sizeof left_tail.transition);
    memset(right_tail.transition, 0, sizeof right_tail.transition);
    int same = memcmp(left, right, prefix) == 0 &&
        memcmp(&left_tail, &right_tail, sizeof left_tail) == 0;
    free(left); free(right);
    if (!same) {
        fprintf(stderr, "candidate changed persisted bytes outside transition\n");
        return 1;
    }
    puts("transition-only");
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    if (!strcmp(argv[1], "reference"))
        return compare_reference(argv[2], argv[3]);
    if (!strcmp(argv[1], "transition-only"))
        return compare_transition_only(argv[2], argv[3]);
    return 2;
}
