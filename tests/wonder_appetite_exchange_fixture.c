#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    int external_a;
    int external_b;
    int reflected_a;
    int reflected_b;
    int leo_a;
    int leo_b;
} ExchangeClock;

typedef struct {
    int external;
    int external_cross;
    int reflected;
    int reflected_cross;
    int self;
} ExchangePair;

static int recent(int turn, int seen, int window) {
    return seen > 0 && turn >= seen && turn - seen < window;
}

static ExchangePair exchange_pair(
        int turn, const ExchangeClock *clock, int window, int eligible) {
    ExchangePair pair = {0, 0, 0, 0, 0};
    if (!eligible) return pair;

    int ea = recent(turn, clock->external_a, window);
    int eb = recent(turn, clock->external_b, window);
    int ra = recent(turn, clock->reflected_a, window);
    int rb = recent(turn, clock->reflected_b, window);
    int la = recent(turn, clock->leo_a, window);
    int lb = recent(turn, clock->leo_b, window);
    pair.external = ea && eb;
    pair.external_cross = (ea && lb) || (eb && la);
    pair.reflected = ra && rb;
    pair.reflected_cross = (ra && lb) || (rb && la);
    pair.self = la && lb;
    return pair;
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

    ExchangeClock clocks[LEO_DEFERRED_WONDER_MAX];
    memset(clocks, 0, sizeof clocks);
    char line[4096];
    int turn = 0;

    printf("trace\tturn\tword\tconfounded\texternal_a\texternal_b\t"
           "reflected_a\treflected_b\tleo_a\tleo_b\t"
           "external_w1\texternal_cross_w1\treflected_w1\t"
           "reflected_cross_w1\tself_w1\t"
           "external_w2\texternal_cross_w2\treflected_w2\t"
           "reflected_cross_w2\tself_w2\t"
           "external_w4\texternal_cross_w4\treflected_w4\t"
           "reflected_cross_w4\tself_w4\t"
           "external_w8\texternal_cross_w8\treflected_w8\t"
           "reflected_cross_w8\tself_w8\n");
    while (fgets(line, sizeof line, stdin)) {
        size_t n = strlen(line);
        while (n > 0 &&
               (line[n - 1] == '\n' || line[n - 1] == '\r'))
            line[--n] = 0;
        char *reply = strchr(line, '\t');
        if (!reply) {
            fprintf(stderr, "trace row %d has no reply separator\n", turn + 1);
            free(leo);
            return 2;
        }
        *reply++ = 0;
        char *selected = strchr(reply, '\t');
        if (!selected) {
            fprintf(stderr, "trace row %d has no provenance separator\n",
                    turn + 1);
            free(leo);
            return 2;
        }
        *selected++ = 0;
        const char *prompt = line;
        turn++;

        int human_hist[GLYPH_COUNT];
        int reflected_hist[GLYPH_COUNT];
        int leo_hist[GLYPH_COUNT];
        leo_school_glyph_votes(leo, prompt, human_hist, 1);
        memset(reflected_hist, 0, sizeof reflected_hist);
        if (strcmp(selected, "none"))
            leo_school_glyph_votes(leo, selected, reflected_hist, 1);
        leo_school_glyph_votes(leo, reply, leo_hist, 1);

        for (int i = 0; i < leo->school.n_deferred; i++) {
            const LeoDeferredWonder *entry = &leo->school.deferred[i];
            ExchangeClock *clock = &clocks[i];
            int a = entry->offered_glyph;
            int b = entry->offered_alt_glyph;
            int eligible =
                a >= 0 && a < GLYPH_COUNT &&
                b >= 0 && b < GLYPH_COUNT && a != b;
            int confounded =
                leo_flow_prompt_has_word(prompt, entry->word) ||
                leo_flow_prompt_has_word(reply, entry->word);
            int ra =
                a >= 0 && a < GLYPH_COUNT && reflected_hist[a] > 0;
            int rb =
                b >= 0 && b < GLYPH_COUNT && reflected_hist[b] > 0;
            int ea =
                a >= 0 && a < GLYPH_COUNT &&
                human_hist[a] > reflected_hist[a];
            int eb =
                b >= 0 && b < GLYPH_COUNT &&
                human_hist[b] > reflected_hist[b];
            int la = a >= 0 && a < GLYPH_COUNT && leo_hist[a] > 0;
            int lb = b >= 0 && b < GLYPH_COUNT && leo_hist[b] > 0;
            if (!confounded) {
                if (ea) clock->external_a = turn;
                if (eb) clock->external_b = turn;
                if (ra) clock->reflected_a = turn;
                if (rb) clock->reflected_b = turn;
                if (la) clock->leo_a = turn;
                if (lb) clock->leo_b = turn;
            }

            ExchangePair w1 = confounded ?
                (ExchangePair){0, 0, 0, 0, 0} :
                exchange_pair(turn, clock, 1, eligible);
            ExchangePair w2 = confounded ?
                (ExchangePair){0, 0, 0, 0, 0} :
                exchange_pair(turn, clock, 2, eligible);
            ExchangePair w4 = confounded ?
                (ExchangePair){0, 0, 0, 0, 0} :
                exchange_pair(turn, clock, 4, eligible);
            ExchangePair w8 = confounded ?
                (ExchangePair){0, 0, 0, 0, 0} :
                exchange_pair(turn, clock, 8, eligible);

            printf("%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t"
                   "%d\t%d\t%d\t%d\t%d\t"
                   "%d\t%d\t%d\t%d\t%d\t"
                   "%d\t%d\t%d\t%d\t%d\t"
                   "%d\t%d\t%d\t%d\t%d\n",
                   argv[2], turn, entry->word, confounded,
                   ea, eb, ra, rb, la, lb,
                   w1.external, w1.external_cross,
                   w1.reflected, w1.reflected_cross, w1.self,
                   w2.external, w2.external_cross,
                   w2.reflected, w2.reflected_cross, w2.self,
                   w4.external, w4.external_cross,
                   w4.reflected, w4.reflected_cross, w4.self,
                   w8.external, w8.external_cross,
                   w8.reflected, w8.reflected_cross, w8.self);
        }
    }

    free(leo);
    return 0;
}
