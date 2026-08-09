#define LEO_LIMINAL_FIXTURE_NO_MAIN
#include "state_swarm_liminal_trajectory_fixture.c"

#define LEO_TRANSITION_CONSEQUENCE_MAGIC 0x3439414cu /* "LA94" */

typedef struct {
    uint32_t magic;
    uint32_t members;
    uint64_t anchor_turn;
    LeoStateWeight stable[LEO_STATE_SWARM_MAX];
    float transition[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX];
    float outcome[LEO_STATE_SWARM_MAX][LEO_STATE_SWARM_MAX]
                 [LEO_STATE_OUTCOMES];
    float anchor_activation[LEO_STATE_SWARM_MAX];
    float anchor_similarity;
    float anchor_entropy;
} LeoTransitionConsequence;

static int graph_save(const char *path,
                      const LeoTransitionConsequence *graph) {
    FILE *file = fopen(path, "wb");
    int ok = file && fwrite(graph, sizeof *graph, 1, file) == 1;
    if (file) ok = fclose(file) == 0 && ok;
    return ok;
}

static int graph_load(const char *path, LeoTransitionConsequence *graph) {
    FILE *file = fopen(path, "rb");
    int ok = file && fread(graph, sizeof *graph, 1, file) == 1 &&
        fgetc(file) == EOF;
    if (file) fclose(file);
    return ok && graph->magic == LEO_TRANSITION_CONSEQUENCE_MAGIC &&
        graph->members == LEO_STATE_SWARM_MAX;
}

static void graph_activation(
        const LeoStateWeight stable[LEO_STATE_SWARM_MAX],
        const LeoStateWeight *observation,
        float activation[LEO_STATE_SWARM_MAX], float *best_similarity,
        float *entropy) {
    float similarity[LEO_STATE_SWARM_MAX];
    float best = -1.0f;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        similarity[i] = leo_state_similarity_components(
            &stable[i], observation, NULL);
        if (similarity[i] > best) best = similarity[i];
    }
    float total = 0.0f;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        activation[i] = expf((similarity[i] - best) / 0.12f);
        total += activation[i];
    }
    float h = 0.0f;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        activation[i] = total > 0.0f ? activation[i] / total : 0.0f;
        if (activation[i] > 0.0f)
            h -= activation[i] * logf(activation[i]);
    }
    *best_similarity = best;
    *entropy = h / logf((float)LEO_STATE_SWARM_MAX);
}

static void graph_predict(
        const LeoTransitionConsequence *graph,
        const float from[LEO_STATE_SWARM_MAX],
        const float to[LEO_STATE_SWARM_MAX], float *mass, float *overlap,
        float forecast[LEO_STATE_OUTCOMES]) {
    float prediction[LEO_STATE_SWARM_MAX] = {0};
    memset(forecast, 0, sizeof(float) * LEO_STATE_OUTCOMES);
    *mass = 0.0f;
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        for (int j = 0; j < LEO_STATE_SWARM_MAX; j++) {
            float edge = from[i] * graph->transition[i][j];
            prediction[j] += edge;
            *mass += edge;
            for (int o = 0; o < LEO_STATE_OUTCOMES; o++)
                forecast[o] += edge * graph->outcome[i][j][o];
        }
    *overlap = 0.0f;
    if (*mass <= 0.0f) return;
    for (int j = 0; j < LEO_STATE_SWARM_MAX; j++) {
        prediction[j] /= *mass;
        *overlap += prediction[j] * to[j];
    }
    for (int o = 0; o < LEO_STATE_OUTCOMES; o++) forecast[o] /= *mass;
}

static int graph_start(int argc, char **argv) {
    if (argc != 11) return 2;
    uint64_t turn = 0, nearest_id = 0;
    long seed = 0;
    float similarity = 0.0f;
    float organs[LEO_STATE_ORGANS];
    if (!parse_u64(argv[3], &turn) || !parse_long(argv[4], &seed) ||
        !parse_u64(argv[8], &nearest_id) ||
        !parse_float(argv[9], &similarity) ||
        !parse_organs(argv[10], organs))
        return 2;

    Leo *body = load_leo(argv[7]);
    if (!body || !body->state_swarm ||
        body->state_swarm->n != LEO_STATE_SWARM_MAX) {
        destroy_leo(body);
        return 1;
    }
    LeoTransitionConsequence graph;
    memset(&graph, 0, sizeof graph);
    graph.magic = LEO_TRANSITION_CONSEQUENCE_MAGIC;
    graph.members = LEO_STATE_SWARM_MAX;
    graph.anchor_turn = turn;
    memcpy(graph.transition, body->state_swarm->transition,
           sizeof graph.transition);
    memcpy(graph.outcome, body->state_swarm->outcome,
           sizeof graph.outcome);
    destroy_leo(body);

    LeoStateWeight observation;
    if (!capture_observation(argv[7], turn, seed, argv[5], argv[6],
                             nearest_id, similarity, organs, graph.stable,
                             &observation)) {
        fprintf(stderr, "transition anchor replay mismatch: %s\n", argv[7]);
        return 1;
    }
    graph_activation(graph.stable, &observation, graph.anchor_activation,
                     &graph.anchor_similarity, &graph.anchor_entropy);
    return graph_save(argv[2], &graph) ? 0 : 2;
}

static int graph_score(int argc, char **argv) {
    if (argc != 21) return 2;
    LeoTransitionConsequence graph;
    if (!graph_load(argv[2], &graph)) return 2;

    uint64_t anchor_turn = 0, future_turn = 0, relative = 0, nearest_id = 0;
    long seed = 0;
    float similarity = 0.0f;
    float organs[LEO_STATE_ORGANS];
    float actual[LEO_STATE_OUTCOMES];
    if (!parse_u64(argv[6], &anchor_turn) ||
        !parse_u64(argv[7], &future_turn) ||
        !parse_u64(argv[8], &relative) || !parse_long(argv[10], &seed) ||
        !parse_u64(argv[14], &nearest_id) ||
        !parse_float(argv[15], &similarity) ||
        !parse_organs(argv[16], organs) ||
        anchor_turn != graph.anchor_turn || relative != 1 ||
        future_turn != anchor_turn + 1)
        return 2;
    for (int o = 0; o < LEO_STATE_OUTCOMES; o++)
        if (!parse_float(argv[17 + o], &actual[o]) ||
            actual[o] < -1.0001f || actual[o] > 1.0001f)
            return 2;

    LeoStateWeight current[LEO_STATE_SWARM_MAX];
    LeoStateWeight observation;
    if (!capture_observation(argv[13], future_turn, seed, argv[11], argv[12],
                             nearest_id, similarity, organs, current,
                             &observation)) {
        fprintf(stderr, "transition future replay mismatch: %s turn=%llu\n",
                argv[5], (unsigned long long)future_turn);
        return 1;
    }
    float next_activation[LEO_STATE_SWARM_MAX];
    float next_similarity = 0.0f, next_entropy = 0.0f;
    graph_activation(graph.stable, &observation, next_activation,
                     &next_similarity, &next_entropy);

    float mass = 0.0f, overlap = 0.0f;
    float reverse_mass = 0.0f, reverse_overlap = 0.0f;
    float forecast[LEO_STATE_OUTCOMES];
    float reverse_forecast[LEO_STATE_OUTCOMES];
    graph_predict(&graph, graph.anchor_activation, next_activation,
                  &mass, &overlap, forecast);
    graph_predict(&graph, next_activation, graph.anchor_activation,
                  &reverse_mass, &reverse_overlap, reverse_forecast);
    float outcome_mae = 0.0f;
    for (int o = 0; o < LEO_STATE_OUTCOMES; o++)
        outcome_mae += fabsf(forecast[o] - actual[o]);
    outcome_mae /= LEO_STATE_OUTCOMES;
    float transition_debt = 1.0f - overlap;
    float joint_debt = transition_debt * outcome_mae;

    printf("%s\t%s\t%s\t%llu\t%llu\t%s\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f",
           argv[3], argv[4], argv[5], (unsigned long long)anchor_turn,
           (unsigned long long)future_turn, argv[9],
           (double)graph.anchor_similarity, (double)graph.anchor_entropy,
           (double)next_similarity, (double)next_entropy, (double)mass,
           (double)overlap, (double)reverse_mass, (double)reverse_overlap,
           (double)transition_debt, (double)(overlap - reverse_overlap));
    for (int o = 0; o < LEO_STATE_OUTCOMES; o++)
        printf("\t%.6f", (double)forecast[o]);
    for (int o = 0; o < LEO_STATE_OUTCOMES; o++)
        printf("\t%.6f", (double)actual[o]);
    printf("\t%.6f\t%.6f\t%s\t%s\n", (double)outcome_mae,
           (double)joint_debt, argv[11], argv[12]);
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && !strcmp(argv[1], "start")) return graph_start(argc, argv);
    if (argc > 1 && !strcmp(argv[1], "score")) return graph_score(argc, argv);
    fprintf(stderr, "usage: %s start|score ...\n", argv[0]);
    return 2;
}
