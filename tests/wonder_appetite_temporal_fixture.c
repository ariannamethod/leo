#define LEO_NO_MAIN
#include "../leo.c"

enum {
    TEMPORAL_W2 = 2,
    TEMPORAL_W4 = 4,
    TEMPORAL_W8 = 8
};

static int within_window(int turn, int seen, int window) {
    return seen > 0 && turn >= seen && turn - seen < window;
}

static float paired_recurrence(
        int turn, int seen_a, int seen_b, int window, int eligible) {
    if (!eligible ||
        !within_window(turn, seen_a, window) ||
        !within_window(turn, seen_b, window))
        return 0.0f;
    return 0.8f;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s STATE TRACE\n", argv[0]);
        return 2;
    }

    Leo *leo = (Leo *)malloc(sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, argv[1])) {
        fprintf(stderr, "cannot load state: %s\n", argv[1]);
        free(leo);
        return 2;
    }

    int seen_a[LEO_DEFERRED_WONDER_MAX] = {0};
    int seen_b[LEO_DEFERRED_WONDER_MAX] = {0};
    char prompt[2048];
    int turn = 0;

    printf("trace\tturn\tword\tglyph_a\tglyph_b\tliteral\thit_a\thit_b\t"
           "current_glyph\tpaired_w2\tpaired_w4\tpaired_w8\n");
    while (fgets(prompt, sizeof prompt, stdin)) {
        size_t n = strlen(prompt);
        while (n > 0 &&
               (prompt[n - 1] == '\n' || prompt[n - 1] == '\r'))
            prompt[--n] = 0;
        turn++;

        int hist[GLYPH_COUNT];
        int total = leo_school_glyph_votes(leo, prompt, hist, 1);
        for (int i = 0; i < leo->school.n_deferred; i++) {
            const LeoDeferredWonder *entry = &leo->school.deferred[i];
            int a = entry->offered_glyph;
            int b = entry->offered_alt_glyph;
            int eligible =
                a >= 0 && a < GLYPH_COUNT &&
                b >= 0 && b < GLYPH_COUNT && a != b;
            int literal =
                leo_flow_prompt_has_word(prompt, entry->word);
            int hit_a =
                a >= 0 && a < GLYPH_COUNT && hist[a] > 0;
            int hit_b =
                b >= 0 && b < GLYPH_COUNT && hist[b] > 0;
            if (!literal && hit_a) seen_a[i] = turn;
            if (!literal && hit_b) seen_b[i] = turn;

            float current = 0.8f * leo_wonder_glyph_evidence(
                hist, total, a, b);
            printf("%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%.3f\t"
                   "%.3f\t%.3f\t%.3f\n",
                   argv[2], turn, entry->word, a, b, literal,
                   hit_a, hit_b, (double)current,
                   literal ? 0.0 :
                       (double)paired_recurrence(
                           turn, seen_a[i], seen_b[i],
                           TEMPORAL_W2, eligible),
                   literal ? 0.0 :
                       (double)paired_recurrence(
                           turn, seen_a[i], seen_b[i],
                           TEMPORAL_W4, eligible),
                   literal ? 0.0 :
                       (double)paired_recurrence(
                           turn, seen_a[i], seen_b[i],
                           TEMPORAL_W8, eligible));
        }
    }

    free(leo);
    return 0;
}
