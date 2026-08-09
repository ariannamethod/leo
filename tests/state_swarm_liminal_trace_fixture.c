#define LEO_LIMINAL_FIXTURE_NO_MAIN
#include "state_swarm_liminal_trajectory_fixture.c"

#define LEO_LIMINAL_TRACE_MAGIC 0x3339414cu /* "LA93" */
#define LEO_LIMINAL_TRACE_BUILD 3

typedef struct {
    uint32_t magic;
    uint32_t build_count;
    uint64_t anchor_turn;
    LeoStateWeight stable[LEO_STATE_SWARM_MAX];
    LeoStateWeight anchor;
    LeoStateWeight build[LEO_LIMINAL_TRACE_BUILD];
    LeoStateWeight forward;
    LeoStateWeight reverse;
} LeoLiminalTrace;

static int trace_load(const char *path, LeoLiminalTrace *trace) {
    FILE *file = fopen(path, "rb");
    int ok = file && fread(trace, sizeof *trace, 1, file) == 1 &&
        fgetc(file) == EOF;
    if (file) fclose(file);
    return ok && trace->magic == LEO_LIMINAL_TRACE_MAGIC &&
        trace->build_count <= LEO_LIMINAL_TRACE_BUILD;
}

static int trace_save(const char *path, const LeoLiminalTrace *trace) {
    FILE *file = fopen(path, "wb");
    int ok = file && fwrite(trace, sizeof *trace, 1, file) == 1;
    if (file) ok = fclose(file) == 0 && ok;
    return ok;
}

static int trace_parse_observation_args(
        int argc, char **argv, uint64_t *turn, long *seed,
        uint64_t *nearest_id, float *similarity,
        float organs[LEO_STATE_ORGANS]) {
    return argc == 11 && parse_u64(argv[3], turn) &&
        parse_long(argv[4], seed) && parse_u64(argv[8], nearest_id) &&
        parse_float(argv[9], similarity) && parse_organs(argv[10], organs);
}

static int trace_start(int argc, char **argv) {
    uint64_t turn = 0, nearest_id = 0;
    long seed = 0;
    float similarity = 0.0f;
    float organs[LEO_STATE_ORGANS];
    if (!trace_parse_observation_args(argc, argv, &turn, &seed,
                                      &nearest_id, &similarity, organs))
        return 2;

    LeoLiminalTrace trace;
    memset(&trace, 0, sizeof trace);
    trace.magic = LEO_LIMINAL_TRACE_MAGIC;
    trace.anchor_turn = turn;
    if (!capture_observation(argv[7], turn, seed, argv[5], argv[6],
                             nearest_id, similarity, organs, trace.stable,
                             &trace.anchor)) {
        fprintf(stderr, "trace anchor geometry replay mismatch: %s\n", argv[7]);
        return 1;
    }
    trace.forward = trace.anchor;
    trace.reverse = trace.anchor;
    return trace_save(argv[2], &trace) ? 0 : 2;
}

static void trace_build_ordered(LeoLiminalTrace *trace) {
    trace->forward = trace->anchor;
    trace->reverse = trace->anchor;
    for (int i = 0; i < LEO_LIMINAL_TRACE_BUILD; i++)
        leo_state_weight_update(&trace->forward, &trace->build[i], 1.0f,
                                trace->anchor_turn + (uint64_t)i + 1);
    for (int i = 0; i < LEO_LIMINAL_TRACE_BUILD; i++)
        leo_state_weight_update(
            &trace->reverse,
            &trace->build[LEO_LIMINAL_TRACE_BUILD - 1 - i], 1.0f,
            trace->anchor_turn + (uint64_t)i + 1);
}

static int trace_absorb(int argc, char **argv) {
    uint64_t turn = 0, nearest_id = 0;
    long seed = 0;
    float similarity = 0.0f;
    float organs[LEO_STATE_ORGANS];
    if (!trace_parse_observation_args(argc, argv, &turn, &seed,
                                      &nearest_id, &similarity, organs))
        return 2;
    LeoLiminalTrace trace;
    if (!trace_load(argv[2], &trace) ||
        trace.build_count >= LEO_LIMINAL_TRACE_BUILD ||
        turn != trace.anchor_turn + trace.build_count + 1)
        return 2;

    LeoStateWeight current[LEO_STATE_SWARM_MAX];
    LeoStateWeight observation;
    if (!capture_observation(argv[7], turn, seed, argv[5], argv[6],
                             nearest_id, similarity, organs, current,
                             &observation)) {
        fprintf(stderr, "trace build geometry replay mismatch: turn=%llu\n",
                (unsigned long long)turn);
        return 1;
    }
    trace.build[trace.build_count++] = observation;
    if (trace.build_count == LEO_LIMINAL_TRACE_BUILD)
        trace_build_ordered(&trace);
    return trace_save(argv[2], &trace) ? 0 : 2;
}

static int trace_score(int argc, char **argv) {
    if (argc != 17) return 2;
    LeoLiminalTrace trace;
    if (!trace_load(argv[2], &trace) ||
        trace.build_count != LEO_LIMINAL_TRACE_BUILD)
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
        !parse_organs(argv[16], organs) || anchor_turn != trace.anchor_turn ||
        relative < 4 || relative > 8 || future_turn != anchor_turn + relative)
        return 2;

    LeoStateWeight current[LEO_STATE_SWARM_MAX];
    LeoStateWeight observation;
    if (!capture_observation(argv[13], future_turn, seed, argv[11], argv[12],
                             nearest_id, similarity, organs, current,
                             &observation)) {
        fprintf(stderr, "trace score geometry replay mismatch: %s turn=%llu\n",
                argv[5], (unsigned long long)future_turn);
        return 1;
    }

    float forward_organs[LEO_STATE_ORGANS];
    float reverse_organs[LEO_STATE_ORGANS];
    float stable_organs[LEO_STATE_ORGANS] = {0};
    float forward_similarity = leo_state_similarity_components(
        &trace.forward, &observation, forward_organs);
    float reverse_similarity = leo_state_similarity_components(
        &trace.reverse, &observation, reverse_organs);
    int best = 0;
    float stable_similarity = -1.0f;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        float candidate[LEO_STATE_ORGANS];
        float value = leo_state_similarity_components(
            &trace.stable[i], &observation, candidate);
        if (value > stable_similarity) {
            best = i;
            stable_similarity = value;
            memcpy(stable_organs, candidate, sizeof stable_organs);
        }
    }
    int directional_nearest =
        forward_similarity > stable_similarity + 1e-7f &&
        forward_similarity > reverse_similarity + 1e-7f;
    int support = directional_nearest &&
        forward_similarity >= LEO_STATE_REPLACE_GATE;
    int strong = directional_nearest &&
        forward_similarity >= LEO_STATE_NOVELTY_GATE;
    printf("%s\t%s\t%s\t%llu\t%llu\t%llu\t%s\t%.6f\t%.6f\t%.6f\t%llu\t%.6f\t%.6f\t%.6f\t%s\t%s\t%s\t",
           argv[3], argv[4], argv[5], (unsigned long long)anchor_turn,
           (unsigned long long)future_turn, (unsigned long long)relative,
           argv[9], (double)forward_similarity, (double)reverse_similarity,
           (double)stable_similarity,
           (unsigned long long)trace.stable[best].id,
           (double)(forward_similarity - stable_similarity),
           (double)(reverse_similarity - stable_similarity),
           (double)(forward_similarity - reverse_similarity),
           directional_nearest ? "true" : "false",
           support ? "true" : "false", strong ? "true" : "false");
    print_organs(forward_organs);
    putchar('\t');
    print_organs(reverse_organs);
    putchar('\t');
    print_organs(stable_organs);
    printf("\t%s\t%s\n", argv[11], argv[12]);
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && !strcmp(argv[1], "start")) return trace_start(argc, argv);
    if (argc > 1 && !strcmp(argv[1], "absorb")) return trace_absorb(argc, argv);
    if (argc > 1 && !strcmp(argv[1], "score")) return trace_score(argc, argv);
    fprintf(stderr, "usage: %s start|absorb|score ...\n", argv[0]);
    return 2;
}
