#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *name;
    const char *prompt;
    int pending_turns;
} CautiousPairCase;

static const CautiousPairCase CASES[] = {
    {"a141-exact", "Both, maybe: the light is here now, and we can simply listen.", 0},
    {"both-maybe", "Both, maybe.", 0},
    {"both-perhaps", "Both, perhaps.", 0},
    {"lowercase", "both, maybe.", 0},
    {"joined-pair-maybe", "Light and now, maybe.", 0},
    {"separate-followup", "Both, maybe. What do you remember?", 0},
    {"emdash-explanation", "Both, perhaps—the light remains and now stays.", 0},
    {"colon-third-explanation", "Both, maybe: water remains elsewhere.", 0},
    {"legacy-bare-both", "Both.", 0},
    {"legacy-single-light", "Light.", 0},
    {"legacy-really-emdash", "Both, really—the light remains and now stays.", 0},
    {"legacy-explicit-pair", "Simply is light and now.", 0},
    {"refuse-question", "Both, maybe?", 0},
    {"refuse-negation", "Both, maybe not.", 0},
    {"refuse-preposed", "Maybe both.", 0},
    {"refuse-doubled", "Both, maybe, perhaps.", 0},
    {"refuse-third-before", "Both water, maybe.", 0},
    {"refuse-duplicate-both", "Both both, maybe.", 0},
    {"refuse-disjunction", "Both, maybe, or light.", 0},
    {"refuse-repeated-option", "Light light and now, maybe.", 0},
    {"refuse-late-ellipse", "Both, maybe.", 1},
};

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ?
        GLYPH_NAMES[glyph] : "none";
}

static const LeoWonderEpisode *episode_for(
        const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_wonders; i++)
        if (!strcmp(leo->school.wonders[i].word, word))
            return &leo->school.wonders[i];
    return NULL;
}

static void print_row(
        const char *arm, const char *name, int enabled,
        const char *prompt, int pending_before,
        const Leo *leo) {
    const LeoWonderEpisode *episode =
        episode_for(leo, "simply");
    int learned[2] = {-1, -1};
    int n_learned = leo_school_word_glyphs(
        leo, "simply", learned);
    printf("%s\t%s\t%d\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%d\t%d\n",
           arm, name, enabled, prompt, pending_before,
           n_learned > 0 ? glyph_name(learned[0]) : "none",
           n_learned > 1 ? glyph_name(learned[1]) : "none",
           episode ? glyph_name(episode->answer_glyph) : "none",
           episode ? glyph_name(episode->answer_alt_glyph) : "none",
           episode ? episode->resolved : -1,
           leo->school.pending[0] ? leo->school.pending : "none",
           glyph_name(leo->school.pending_glyph),
           glyph_name(leo->school.pending_alt_glyph),
           leo->school.pending_turns,
           leo->school.n_wonders);
}

static int run_case(
        const char *arm, int enabled, const char *state,
        const CautiousPairCase *test) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, state)) {
        leo_free(leo);
        free(leo);
        return 3;
    }
    g_leo_school_cautious_pair_on = enabled;
    leo->school.pending_turns = test->pending_turns;
    char out[1024];
    leo_respond(leo, test->prompt, out, sizeof out);
    print_row(
        arm, test->name, enabled, test->prompt,
        test->pending_turns, leo);
    leo_free(leo);
    free(leo);
    return 0;
}

static int save_exact_candidate(
        const char *state, const char *saved) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, state)) {
        leo_free(leo);
        free(leo);
        return 3;
    }
    g_leo_school_cautious_pair_on = 1;
    char out[1024];
    leo_respond(leo, CASES[0].prompt, out, sizeof out);
    int ok = leo_save_state(leo, saved);
    leo_free(leo);
    free(leo);
    return ok ? 0 : 4;
}

static int inspect_sleep(const char *saved) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, saved)) {
        leo_free(leo);
        free(leo);
        return 3;
    }
    print_row("candidate", "sleep", 1, "none", -1, leo);
    leo_free(leo);
    free(leo);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    const char *turn5 = argv[1];
    const char *saved = argv[2];

    puts("arm\tcase\tcautious_pair\tprompt\tpending_before\tlearned_primary\tlearned_alternate\tanswer_primary\tanswer_alternate\tresolved\tpending\toffered_primary\toffered_alternate\tpending_after\twonders");
    for (int enabled = 1; enabled >= 0; enabled--) {
        const char *arm = enabled ? "candidate" : "control";
        for (size_t i = 0; i < sizeof CASES / sizeof CASES[0]; i++)
            if (run_case(arm, enabled, turn5, &CASES[i]))
                return 3;
    }
    if (save_exact_candidate(turn5, saved)) return 4;
    if (inspect_sleep(saved)) return 5;
    g_leo_school_cautious_pair_on = 1;
    return 0;
}
