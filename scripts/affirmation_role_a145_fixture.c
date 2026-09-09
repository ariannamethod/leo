#define LEO_NO_MAIN
#include "../leo.c"

static const char *role_name(LeoSchoolLexicalRole role) {
    switch (role) {
        case LEO_SCHOOL_ROLE_RELATION: return "relation";
        case LEO_SCHOOL_ROLE_POLARITY: return "polarity";
        case LEO_SCHOOL_ROLE_DISCOURSE: return "discourse";
        default: return "none";
    }
}

static const LeoWonderEpisode *episode_for(
        const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_wonders; i++)
        if (!strcmp(leo->school.wonders[i].word, word))
            return &leo->school.wonders[i];
    return NULL;
}

static int deferred_for(const Leo *leo, const char *word) {
    return leo_deferred_wonder_find(leo, word) >= 0;
}

static void print_direct(Leo *leo, const char *surface) {
    const char *witness = NULL;
    char unknown[LEO_HEARD_WORDLEN] = {0};
    int previous = g_leo_school_affirmation_role_on;
    g_leo_school_affirmation_role_on = 1;
    LeoSchoolLexicalRole role =
        leo_school_lexical_role(surface, &witness);
    int candidate_found =
        leo_school_find_unknown(leo, surface, unknown);
    char candidate[LEO_HEARD_WORDLEN] = {0};
    if (candidate_found)
        strncpy(candidate, unknown, sizeof candidate - 1);
    g_leo_school_affirmation_role_on = 0;
    int control_found =
        leo_school_find_unknown(leo, surface, unknown);
    printf("direct\t%s\t%s\t%s\t%s\t%s\t%d\tnone\tnone\tnone\tnone\tnone\tnone\tnone\tnone\tnone\n",
           surface, role_name(role), witness ? witness : "none",
           candidate_found ? candidate : "none",
           control_found ? unknown : "none",
           leo_semtok_word(leo, surface) >= 0 ? 1 : 0);
    g_leo_school_affirmation_role_on = previous;
}

static int print_state(const char *arm, const char *path) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, path)) {
        leo_free(leo);
        free(leo);
        return 3;
    }
    const LeoWonderEpisode *finished = episode_for(leo, "finished");
    const LeoWonderEpisode *yeah = episode_for(leo, "yeah");
    const char *deferred_word = leo->school.n_deferred > 0 ?
        leo->school.deferred[0].word : "none";
    printf("state\t%s\t%s\t%d\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
           arm,
           leo->school.pending[0] ? leo->school.pending : "none",
           leo->school.pending_turns,
           leo->school.n_wonders,
           leo->school.n_deferred,
           deferred_word,
           finished ? 1 : 0,
           finished ? finished->resolved : -1,
           yeah ? 1 : 0,
           yeah ? yeah->resolved : -1,
           deferred_for(leo, "finished"),
           deferred_for(leo, "yeah"),
           leo_heard_count(&leo->heard, "finished"),
           leo_heard_count(&leo->heard, "yeah"),
           leo_school_is_learned(leo, "yeah"));
    leo_free(leo);
    free(leo);
    return 0;
}

static int save_again(const char *source, const char *saved) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, source)) {
        leo_free(leo);
        free(leo);
        return 3;
    }
    int ok = leo_save_state(leo, saved);
    leo_free(leo);
    free(leo);
    return ok ? 0 : 4;
}

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    Leo *direct = calloc(1, sizeof *direct);
    if (!direct) return 2;
    leo_init(direct);
    puts("kind\tidentity\trole_or_pending\twitness_or_pending_turns\tcandidate_or_wonders\tcontrol_or_deferred_count\tknown_or_deferred_word\tfinished_episode\tfinished_resolved\tyeah_episode\tyeah_resolved\tfinished_deferred\tyeah_deferred\tfinished_heard\tyeah_heard\tyeah_learned");
    static const char *const surfaces[] = {
        "yes", "yeah", "yep", "okay", "ok",
        "finished", "zorble", "fragile", "somehow", "sure",
        "yeahness", "okayish", NULL
    };
    for (int i = 0; surfaces[i]; i++)
        print_direct(direct, surfaces[i]);
    leo_free(direct);
    free(direct);

    if (print_state("control", argv[1])) return 3;
    if (print_state("candidate", argv[2])) return 4;
    if (save_again(argv[2], argv[3])) return 5;
    if (print_state("candidate-sleep", argv[3])) return 6;
    g_leo_school_affirmation_role_on = 1;
    return 0;
}
