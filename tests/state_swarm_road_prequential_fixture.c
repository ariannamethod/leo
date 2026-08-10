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

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    Leo *leo = load_leo(argv[1]);
    if (!leo || !leo->state_swarm ||
        leo->state_swarm->n != LEO_STATE_SWARM_MAX ||
        !leo->state_swarm->has_previous) {
        if (leo) {
            leo_free(leo);
            free(leo);
        }
        return 1;
    }

    const LeoStateSwarm *swarm = leo->state_swarm;
    double activation_total = 0.0;
    double transition_total = 0.0;
    printf("%llu\t", (unsigned long long)swarm->previous_turn);
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++) {
        printf("%s%llu", i ? "/" : "",
               (unsigned long long)swarm->weights[i].id);
        activation_total += swarm->previous_activation[i];
    }
    putchar('\t');
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        printf("%s%.9f", i ? "/" : "",
               (double)swarm->previous_activation[i]);
    putchar('\t');
    for (int i = 0; i < LEO_STATE_SWARM_MAX; i++)
        for (int j = 0; j < LEO_STATE_SWARM_MAX; j++) {
            double edge = swarm->transition[i][j];
            printf("%s%.9f", i || j ? "/" : "", edge);
            transition_total += edge;
        }
    printf("\t%.9f\n", transition_total);

    int valid = fabs(activation_total - 1.0) <= 0.001 &&
        transition_total > 0.0;
    leo_free(leo);
    free(leo);
    return valid ? 0 : 1;
}
