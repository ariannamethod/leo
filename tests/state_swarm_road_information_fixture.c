#define LEO_NO_MAIN
#include <errno.h>
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

static void destroy_leo(Leo *leo) {
    if (!leo) return;
    leo_free(leo);
    free(leo);
}

static int parse_u64(const char *text, uint64_t *value) {
    char *end = NULL;
    errno = 0;
    unsigned long long parsed = strtoull(text, &end, 10);
    if (errno || !end || *end) return 0;
    *value = (uint64_t)parsed;
    return 1;
}

static int parse_long(const char *text, long *value) {
    char *end = NULL;
    errno = 0;
    long parsed = strtol(text, &end, 10);
    if (errno || !end || *end) return 0;
    *value = parsed;
    return 1;
}

static int parse_float(const char *text, float *value) {
    char *end = NULL;
    errno = 0;
    float parsed = strtof(text, &end);
    if (errno || !end || *end || !isfinite(parsed)) return 0;
    *value = parsed;
    return 1;
}

static int parse_organs(const char *text, float organ[LEO_STATE_ORGANS]) {
    char copy[512];
    size_t len = strlen(text);
    if (!len || len >= sizeof copy) return 0;
    memcpy(copy, text, len + 1);
    char *cursor = copy;
    for (int i = 0; i < LEO_STATE_ORGANS; i++) {
        char *slash = strchr(cursor, '/');
        if (i + 1 < LEO_STATE_ORGANS) {
            if (!slash) return 0;
            *slash = 0;
        } else if (slash) {
            return 0;
        }
        if (!parse_float(cursor, &organ[i]) || organ[i] < 0.0f ||
            organ[i] > 1.001f)
            return 0;
        if (slash) cursor = slash + 1;
    }
    return 1;
}

static int visible_reply_equal(const char *reply, const char *expected) {
    size_t n = strcspn(reply, "\r\n\t");
    return strlen(expected) == n && !memcmp(reply, expected, n);
}

static int capture_observation(
        const char *state_path, uint64_t expected_turn, long seed,
        const char *prompt, const char *expected_reply,
        uint64_t expected_nearest_id, float expected_similarity,
        const float expected_organs[LEO_STATE_ORGANS],
        LeoStateWeight stable[LEO_STATE_SWARM_MAX],
        LeoStateWeight *observation) {
    srand((unsigned)seed);
    Leo *leo = load_leo(state_path);
    if (!leo || !leo->state_swarm ||
        leo->state_swarm->n != LEO_STATE_SWARM_MAX) {
        destroy_leo(leo);
        return 0;
    }
    memcpy(stable, leo->state_swarm->weights,
           sizeof(LeoStateWeight) * LEO_STATE_SWARM_MAX);
    leo_state_swarm_clear(leo->state_swarm);
    char reply[4096];
    leo_respond(leo, prompt, reply, sizeof reply);
    if (!visible_reply_equal(reply, expected_reply) ||
        leo->state_swarm->n != 1 ||
        leo->state_swarm_receipt.event != LEO_STATE_SWARM_BORN ||
        leo->state_swarm_receipt.turn != expected_turn) {
        destroy_leo(leo);
        return 0;
    }
    *observation = leo->state_swarm->weights[0];

    int best = 0;
    float best_similarity = -1.0f;
    float best_organs[LEO_STATE_ORGANS] = {0};
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        float organs[LEO_STATE_ORGANS];
        float similarity = leo_state_similarity_components(
            &stable[i], observation, organs);
        if (similarity > best_similarity) {
            best = i;
            best_similarity = similarity;
            memcpy(best_organs, organs, sizeof best_organs);
        }
    }
    int exact = stable[best].id == expected_nearest_id &&
        fabsf(best_similarity - expected_similarity) <= 0.0015f;
    for (int i = 0; i < LEO_STATE_ORGANS; i++)
        if (fabsf(best_organs[i] - expected_organs[i]) > 0.00002f)
            exact = 0;
    destroy_leo(leo);
    return exact;
}

static void activation_for(
        const LeoStateWeight stable[LEO_STATE_SWARM_MAX],
        const LeoStateWeight *observation,
        double activation[LEO_STATE_SWARM_MAX]) {
    double similarity[LEO_STATE_SWARM_MAX];
    double best = -1.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        similarity[i] = leo_state_similarity_components(
            &stable[i], observation, NULL);
        if (similarity[i] > best) best = similarity[i];
    }
    double total = 0.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        activation[i] = exp((similarity[i] - best) / 0.12);
        total += activation[i];
    }
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        activation[i] /= total;
}

static double entropy(const double value[LEO_STATE_SWARM_MAX]) {
    double result = 0.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        if (value[i] > 0.0) result -= value[i] * log(value[i]);
    return result;
}

static double cross_entropy(const double target[LEO_STATE_SWARM_MAX],
                            const double prediction[LEO_STATE_SWARM_MAX]) {
    double result = 0.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        result -= target[i] * log(fmax(prediction[i], 1e-6));
    return result;
}

static double brier(const double target[LEO_STATE_SWARM_MAX],
                    const double prediction[LEO_STATE_SWARM_MAX]) {
    double result = 0.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        double delta = target[i] - prediction[i];
        result += delta * delta;
    }
    return result;
}

static void print_vector(const double value[LEO_STATE_SWARM_MAX]) {
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        printf("%s%.9f", i ? "/" : "", value[i]);
}

static void print_matrix(
        const float value[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX]) {
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        for (int j = 0; j < LEO_STATE_SWARM_MAX; j++)
            printf("%s%.9f", i || j ? "/" : "", (double)value[i][j]);
}

int main(int argc, char **argv) {
    if (argc != 23) return 2;
    uint64_t anchor_turn = 0, future_turn = 0;
    uint64_t anchor_nearest = 0, future_nearest = 0;
    long anchor_seed = 0, future_seed = 0;
    float anchor_similarity = 0.0f, future_similarity = 0.0f;
    float anchor_organs[LEO_STATE_ORGANS];
    float future_organs[LEO_STATE_ORGANS];
    if (!parse_u64(argv[6], &anchor_turn) ||
        !parse_u64(argv[7], &future_turn) || future_turn != anchor_turn + 1 ||
        !parse_long(argv[9], &anchor_seed) ||
        !parse_u64(argv[13], &anchor_nearest) ||
        !parse_float(argv[14], &anchor_similarity) ||
        !parse_organs(argv[15], anchor_organs) ||
        !parse_long(argv[16], &future_seed) ||
        !parse_u64(argv[20], &future_nearest) ||
        !parse_float(argv[21], &future_similarity) ||
        !parse_organs(argv[22], future_organs))
        return 2;

    Leo *body = load_leo(argv[12]);
    if (!body || !body->state_swarm ||
        body->state_swarm->n != LEO_STATE_SWARM_MAX) {
        destroy_leo(body);
        return 1;
    }
    float transition[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX];
    memcpy(transition, body->state_swarm->transition, sizeof transition);
    destroy_leo(body);

    LeoStateWeight stable[LEO_STATE_SWARM_MAX];
    LeoStateWeight anchor_observation;
    if (!capture_observation(argv[12], anchor_turn, anchor_seed,
                             argv[10], argv[11], anchor_nearest,
                             anchor_similarity, anchor_organs, stable,
                             &anchor_observation))
        return 1;
    LeoStateWeight future_stable[LEO_STATE_SWARM_MAX];
    LeoStateWeight future_observation;
    if (!capture_observation(argv[19], future_turn, future_seed,
                             argv[17], argv[18], future_nearest,
                             future_similarity, future_organs, future_stable,
                             &future_observation))
        return 1;

    double anchor[LEO_STATE_SWARM_MAX];
    double target[LEO_STATE_SWARM_MAX];
    double conditional[LEO_STATE_SWARM_MAX] = {0};
    double destination[LEO_STATE_SWARM_MAX] = {0};
    double uniform[LEO_STATE_SWARM_MAX];
    double row[LEO_STATE_SWARM_MAX] = {0};
    activation_for(stable, &anchor_observation, anchor);
    activation_for(stable, &future_observation, target);
    double total = 0.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        for (int j = 0; j < LEO_STATE_SWARM_MAX; j++) {
            double edge = transition[i][j];
            row[i] += edge;
            destination[j] += edge;
            conditional[j] += anchor[i] * edge;
            total += edge;
        }
    double conditional_total = 0.0;
    for (int j = 0; j < LEO_STATE_SWARM_MAX; j++)
        conditional_total += conditional[j];
    if (total <= 0.0 || conditional_total <= 0.0) return 1;
    for (int j = 0; j < LEO_STATE_SWARM_MAX; j++) {
        conditional[j] /= conditional_total;
        destination[j] /= total;
        uniform[j] = 1.0 / LEO_STATE_SWARM_MAX;
    }

    double destination_entropy = entropy(destination);
    double information = 0.0;
    double mean_row_tv = 0.0;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        if (row[i] <= 0.0) continue;
        double tv = 0.0;
        for (int j = 0; j < LEO_STATE_SWARM_MAX; j++) {
            double edge = transition[i][j];
            if (edge > 0.0 && destination[j] > 0.0)
                information += (edge / total) *
                    log(edge / (row[i] * destination[j]));
            tv += fabs(edge / row[i] - destination[j]);
        }
        mean_row_tv += (row[i] / total) * 0.5 * tv;
    }
    double normalized_information = destination_entropy > 0.0 ?
        information / destination_entropy : 0.0;

    printf("%s\t%s\t%s\t%s\t%s\t%llu\t%llu\t%s\t",
           argv[1], argv[2], argv[3], argv[4], argv[5],
           (unsigned long long)anchor_turn,
           (unsigned long long)future_turn, argv[8]);
    print_matrix(transition);
    putchar('\t');
    print_vector(anchor);
    putchar('\t');
    print_vector(target);
    putchar('\t');
    print_vector(conditional);
    putchar('\t');
    print_vector(destination);
    printf("\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%s\t%s\n",
           total, destination_entropy, information, normalized_information,
           mean_row_tv, cross_entropy(target, conditional),
           cross_entropy(target, destination),
           cross_entropy(target, uniform), cross_entropy(target, anchor),
           brier(target, conditional), brier(target, destination),
           brier(target, uniform), brier(target, anchor), argv[17], argv[18]);
    return 0;
}
