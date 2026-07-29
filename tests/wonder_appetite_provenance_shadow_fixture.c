#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    int from_a;
    int from_b;
} ShadowLane;

typedef struct {
    int opened;
    int completed;
    int external_sufficient;
    int reflected_blocked;
    int self_blocked;
    int expired;
    int pending;
} ShadowEvent;

static void expire_invitation(
        int turn, int window, int *opened, ShadowEvent *event) {
    if (*opened > 0 && turn - *opened >= window) {
        *opened = 0;
        event->expired++;
    }
}

static ShadowEvent shadow_step(
        int turn, int window, ShadowLane *lane,
        int eligible, int confounded,
        int external_a, int external_b,
        int reflected_a, int reflected_b,
        int self_a, int self_b) {
    ShadowEvent event = {0, 0, 0, 0, 0, 0, 0};
    expire_invitation(turn, window, &lane->from_a, &event);
    expire_invitation(turn, window, &lane->from_b, &event);

    if (!eligible || confounded) {
        event.pending = !!lane->from_a + !!lane->from_b;
        return event;
    }

    /*
     * If the outside supplies both sides, either in this prompt or by
     * completing a still-open invitation, Leo's reply is not required.
     * Close the provenance lane before considering current self evidence.
     */
    if ((external_a && external_b) ||
        (external_a && lane->from_b) ||
        (external_b && lane->from_a)) {
        event.external_sufficient = 1;
        lane->from_a = 0;
        lane->from_b = 0;
        event.pending = 0;
        return event;
    }

    if (external_a) {
        lane->from_a = turn;
        event.opened++;
    }
    if (external_b) {
        lane->from_b = turn;
        event.opened++;
    }

    if (self_a && self_b) {
        if (lane->from_a || lane->from_b)
            event.self_blocked = 1;
        lane->from_a = 0;
        lane->from_b = 0;
        event.pending = 0;
        return event;
    }

    if (lane->from_a && self_b) {
        if (reflected_b) {
            event.reflected_blocked++;
        } else {
            event.completed++;
            lane->from_a = 0;
        }
    }
    if (lane->from_b && self_a) {
        if (reflected_a) {
            event.reflected_blocked++;
        } else {
            event.completed++;
            lane->from_b = 0;
        }
    }

    event.pending = !!lane->from_a + !!lane->from_b;
    return event;
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

    static const int windows[] = {1, 2, 4, 8};
    ShadowLane lanes[LEO_DEFERRED_WONDER_MAX][4];
    memset(lanes, 0, sizeof lanes);
    char line[4096];
    int turn = 0;

    printf("trace\tturn\tword\tconfounded\texternal_a\texternal_b\t"
           "reflected_a\treflected_b\tself_a\tself_b");
    for (int w = 0; w < 4; w++)
        printf("\topened_w%d\tcompleted_w%d\texternal_sufficient_w%d\t"
               "reflected_blocked_w%d\tself_blocked_w%d\texpired_w%d\t"
               "pending_w%d",
               windows[w], windows[w], windows[w], windows[w],
               windows[w], windows[w], windows[w]);
    printf("\n");

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
        int self_hist[GLYPH_COUNT];
        leo_school_glyph_votes(leo, prompt, human_hist, 1);
        memset(reflected_hist, 0, sizeof reflected_hist);
        if (strcmp(selected, "none"))
            leo_school_glyph_votes(leo, selected, reflected_hist, 1);
        leo_school_glyph_votes(leo, reply, self_hist, 1);

        for (int i = 0; i < leo->school.n_deferred; i++) {
            const LeoDeferredWonder *entry = &leo->school.deferred[i];
            int a = entry->offered_glyph;
            int b = entry->offered_alt_glyph;
            int eligible =
                a >= 0 && a < GLYPH_COUNT &&
                b >= 0 && b < GLYPH_COUNT && a != b;
            int confounded =
                leo_flow_prompt_has_word(prompt, entry->word) ||
                leo_flow_prompt_has_word(reply, entry->word);
            int reflected_a =
                a >= 0 && a < GLYPH_COUNT && reflected_hist[a] > 0;
            int reflected_b =
                b >= 0 && b < GLYPH_COUNT && reflected_hist[b] > 0;
            int external_a =
                a >= 0 && a < GLYPH_COUNT &&
                human_hist[a] > reflected_hist[a];
            int external_b =
                b >= 0 && b < GLYPH_COUNT &&
                human_hist[b] > reflected_hist[b];
            int self_a =
                a >= 0 && a < GLYPH_COUNT && self_hist[a] > 0;
            int self_b =
                b >= 0 && b < GLYPH_COUNT && self_hist[b] > 0;

            printf("%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
                   argv[2], turn, entry->word, confounded,
                   external_a, external_b, reflected_a, reflected_b,
                   self_a, self_b);
            for (int w = 0; w < 4; w++) {
                ShadowEvent event = shadow_step(
                    turn, windows[w], &lanes[i][w],
                    eligible, confounded,
                    external_a, external_b,
                    reflected_a, reflected_b,
                    self_a, self_b);
                printf("\t%d\t%d\t%d\t%d\t%d\t%d\t%d",
                       event.opened, event.completed,
                       event.external_sufficient,
                       event.reflected_blocked, event.self_blocked,
                       event.expired, event.pending);
            }
            printf("\n");
        }
    }

    free(leo);
    return 0;
}
