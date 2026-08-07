#define LEO_NO_MAIN
#include <errno.h>
#include "../leo.c"

#define LEO_LIMINAL_FROZEN_MAGIC 0x3239414cu /* "LA92" */

typedef struct {
    uint32_t magic;
    uint32_t members;
    uint64_t anchor_turn;
    LeoStateWeight stable[LEO_STATE_SWARM_MAX];
    LeoStateWeight candidate;
} LeoLiminalFrozen;

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
        if (!parse_float(cursor, &organ[i]) ||
            organ[i] < 0.0f || organ[i] > 1.001f)
            return 0;
        if (slash) cursor = slash + 1;
    }
    return 1;
}

static void print_organs(const float organ[LEO_STATE_ORGANS]) {
    for (int i = 0; i < LEO_STATE_ORGANS; i++)
        printf("%s%.6f", i ? "/" : "", (double)organ[i]);
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

    /* State swarm has no generation reader. Replaying with only this shadow
     * organ empty captures the raw lived observation as a newborn weight. */
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
    if (!exact) {
        fprintf(stderr,
                "geometry expected nearest=%llu similarity=%.6f got nearest=%llu similarity=%.6f organs=",
                (unsigned long long)expected_nearest_id,
                (double)expected_similarity,
                (unsigned long long)stable[best].id,
                (double)best_similarity);
        for (int i = 0; i < LEO_STATE_ORGANS; i++)
            fprintf(stderr, "%s%.6f", i ? "/" : "",
                    (double)best_organs[i]);
        fputc('\n', stderr);
    }
    destroy_leo(leo);
    return exact;
}

static int freeze_anchor(int argc, char **argv) {
    if (argc != 11) return 2;
    const char *out = argv[2];
    uint64_t turn = 0, nearest_id = 0;
    long seed = 0;
    float similarity = 0.0f;
    float organs[LEO_STATE_ORGANS];
    if (!parse_u64(argv[3], &turn) || !parse_long(argv[4], &seed) ||
        !parse_u64(argv[8], &nearest_id) ||
        !parse_float(argv[9], &similarity) ||
        !parse_organs(argv[10], organs))
        return 2;

    LeoLiminalFrozen frozen;
    memset(&frozen, 0, sizeof frozen);
    frozen.magic = LEO_LIMINAL_FROZEN_MAGIC;
    frozen.members = LEO_STATE_SWARM_MAX;
    frozen.anchor_turn = turn;
    if (!capture_observation(argv[7], turn, seed, argv[5], argv[6],
                             nearest_id, similarity, organs, frozen.stable,
                             &frozen.candidate)) {
        fprintf(stderr, "anchor geometry replay mismatch: %s\n", argv[7]);
        return 1;
    }
    FILE *file = fopen(out, "wb");
    int ok = file && fwrite(&frozen, sizeof frozen, 1, file) == 1;
    if (file) ok = fclose(file) == 0 && ok;
    return ok ? 0 : 2;
}

static int project_future(int argc, char **argv) {
    if (argc != 17) return 2;
    LeoLiminalFrozen frozen;
    FILE *file = fopen(argv[2], "rb");
    int loaded = file && fread(&frozen, sizeof frozen, 1, file) == 1 &&
        fgetc(file) == EOF;
    if (file) fclose(file);
    if (!loaded || frozen.magic != LEO_LIMINAL_FROZEN_MAGIC ||
        frozen.members != LEO_STATE_SWARM_MAX)
        return 2;

    uint64_t anchor_turn = 0, future_turn = 0, relative = 0, nearest_id = 0;
    long seed = 0;
    float similarity = 0.0f;
    float organs[LEO_STATE_ORGANS];
    if (!parse_u64(argv[6], &anchor_turn) ||
        !parse_u64(argv[7], &future_turn) ||
        !parse_u64(argv[8], &relative) || !parse_long(argv[10], &seed) ||
        !parse_u64(argv[14], &nearest_id) ||
        !parse_float(argv[15], &similarity) ||
        !parse_organs(argv[16], organs) || anchor_turn != frozen.anchor_turn ||
        relative < 1 || relative > 8 || future_turn != anchor_turn + relative)
        return 2;

    LeoStateWeight current[LEO_STATE_SWARM_MAX];
    LeoStateWeight observation;
    if (!capture_observation(argv[13], future_turn, seed, argv[11], argv[12],
                             nearest_id, similarity, organs, current,
                             &observation)) {
        fprintf(stderr, "future geometry replay mismatch: %s turn=%llu\n",
                argv[5], (unsigned long long)future_turn);
        return 1;
    }

    float candidate_organs[LEO_STATE_ORGANS];
    float candidate_similarity = leo_state_similarity_components(
        &frozen.candidate, &observation, candidate_organs);
    int best = 0;
    float best_similarity = -1.0f;
    float best_organs[LEO_STATE_ORGANS] = {0};
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        float candidate[LEO_STATE_ORGANS];
        float value = leo_state_similarity_components(
            &frozen.stable[i], &observation, candidate);
        if (value > best_similarity) {
            best = i;
            best_similarity = value;
            memcpy(best_organs, candidate, sizeof best_organs);
        }
    }
    int candidate_nearest = candidate_similarity > best_similarity + 1e-7f;
    int support = candidate_nearest &&
        candidate_similarity >= LEO_STATE_REPLACE_GATE;
    int confirmation = candidate_nearest &&
        candidate_similarity >= LEO_STATE_NOVELTY_GATE;
    printf("%s\t%s\t%s\t%llu\t%llu\t%llu\t%s\t%.6f\t%.6f\t%.6f\t%llu\t%s\t%s\t%s\t",
           argv[3], argv[4], argv[5], (unsigned long long)anchor_turn,
           (unsigned long long)future_turn, (unsigned long long)relative,
           argv[9], (double)candidate_similarity, (double)best_similarity,
           (double)(candidate_similarity - best_similarity),
           (unsigned long long)frozen.stable[best].id,
           candidate_nearest ? "true" : "false",
           support ? "true" : "false",
           confirmation ? "true" : "false");
    print_organs(candidate_organs);
    putchar('\t');
    print_organs(best_organs);
    printf("\t%s\t%s\n", argv[11], argv[12]);
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && !strcmp(argv[1], "freeze"))
        return freeze_anchor(argc, argv);
    if (argc > 1 && !strcmp(argv[1], "project"))
        return project_future(argc, argv);
    fprintf(stderr, "usage: %s freeze|project ...\n", argv[0]);
    return 2;
}
