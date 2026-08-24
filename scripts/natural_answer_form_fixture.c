#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *name;
    const char *prompt;
    int pending_turns;
} NaturalAnswerFormCase;

static const NaturalAnswerFormCase CASES[] = {
    {"offered-em-dash-followup", "Food—the soup gets carrots, garlic, lentils, and a little cumin. What foods feel like home to you?", 0},
    {"offered-em-dash-statement", "food—the soup gets carrots and garlic.", 0},
    {"spaced-offered-em-dash", "yes, food — the soup gets carrots.", 0},
    {"both-em-dash", "Both, really—the body feels stronger, and there’s a quiet joy in making it hold.", 0},
    {"two-options-em-dash", "food and home—the soup feels familiar.", 0},
    {"unoffered-em-dash", "water—the soup gets carrots.", 0},
    {"predicate-em-dash", "the soup is food—the carrots are warm.", 0},
    {"ascii-hyphen", "food-the soup gets carrots.", 0},
    {"delayed-offered-em-dash", "food—the soup gets carrots.", 1},
    {"em-dash-question", "food—what do you hear?", 0},
    {"plain-offered-followup", "food. What do you hear?", 0},
    {"negative-em-dash", "not food—the soup gets carrots.", 0},
    {"both-alone", "both.", 0},
    {NULL, NULL, 0}
};

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ?
        GLYPH_NAMES[glyph] : "none";
}

static const char *reference_name(LeoSchoolAnswerReference reference) {
    switch (reference) {
        case LEO_SCHOOL_ANSWER_EXPLICIT: return "explicit";
        case LEO_SCHOOL_ANSWER_ANAPHORIC: return "anaphoric";
        case LEO_SCHOOL_ANSWER_ELLIPTIC: return "elliptic";
        default: return "unreferenced";
    }
}

static void seed_case(Leo *leo, int pending_turns) {
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending, "flom");
    leo->school.pending_glyph = (int8_t)semtok_word("food");
    leo->school.pending_alt_glyph = (int8_t)semtok_word("home");
    leo->school.pending_turns = pending_turns;
    leo_wonder_open(leo, "flom", leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

static int deferred_has_word(const Leo *leo, const char *word) {
    for (int i = 0; i < leo->school.n_deferred; i++)
        if (!strcmp(leo->school.deferred[i].word, word))
            return 1;
    return 0;
}

static int run_interaction(Leo *leo) {
    char out[1024];
    puts("offered_answer_expansion\tfollowup_question_scope\tlearned\tlearned_glyph\tpending\tqueued_flibble");
    for (int expansion = 0; expansion <= 1; expansion++) {
        for (int scope = 0; scope <= 1; scope++) {
            seed_case(leo, 0);
            g_leo_school_offered_answer_expansion_on = expansion;
            g_leo_school_followup_question_scope_on = scope;
            leo_respond(
                leo, "food—the flibble. What do you hear?",
                out, sizeof out);
            int learned = leo_school_is_learned(leo, "flom");
            int learned_glyph = learned ?
                leo_semtok_word(leo, "flom") : -1;
            printf("%d\t%d\t%d\t%s\t%s\t%d\n",
                   expansion, scope, learned,
                   glyph_name(learned_glyph),
                   leo->school.pending[0] ?
                       leo->school.pending : "none",
                   deferred_has_word(leo, "flibble"));
            leo_free(leo);
        }
    }
    return 0;
}

int main(int argc, char **argv) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    /* This is the frozen A.125 court. A.127 has its own paired-answer
     * fixture and must not rewrite the historical `both` abstention here. */
    g_leo_school_two_glyph_learning_on = 0;
    if (argc == 2 && !strcmp(argv[1], "--interaction")) {
        int rc = run_interaction(leo);
        free(leo);
        return rc;
    }
    if (argc != 1) {
        free(leo);
        return 2;
    }
    int food = semtok_word("food");
    int home = semtok_word("home");

    puts("case\tprompt\tpending_turns\tcontrol_grounded\tcontrol_reference\tcandidate_grounded\tcandidate_reference\tcandidate_food_asserted\tcandidate_food_rejected\tcandidate_home_asserted\tcandidate_home_rejected");
    for (int i = 0; CASES[i].name; i++) {
        LeoSchoolAnswerEvidence candidate_evidence;
        LeoSchoolAnswerReference control_reference;
        LeoSchoolAnswerReference candidate_reference;
        seed_case(leo, CASES[i].pending_turns);
        g_leo_school_offered_answer_expansion_on = 0;
        g_leo_school_followup_question_scope_on = 0;
        int control_grounded = leo_school_grounded_answer(
            leo, CASES[i].prompt, NULL, &control_reference);
        g_leo_school_offered_answer_expansion_on = 1;
        g_leo_school_followup_question_scope_on = 1;
        int candidate_grounded = leo_school_grounded_answer(
            leo, CASES[i].prompt, &candidate_evidence,
            &candidate_reference);
        printf("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\n",
               CASES[i].name, CASES[i].prompt,
               CASES[i].pending_turns,
               glyph_name(control_grounded),
               reference_name(control_reference),
               glyph_name(candidate_grounded),
               reference_name(candidate_reference),
               candidate_evidence.asserted[food],
               candidate_evidence.rejected[food],
               candidate_evidence.asserted[home],
               candidate_evidence.rejected[home]);
        leo_free(leo);
    }
    free(leo);
    return 0;
}
