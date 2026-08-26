#define LEO_NO_MAIN
#include "../leo.c"

typedef enum {
    TWO_GLYPH_PENDING = 0,
    TWO_GLYPH_SAME_TURN
} TwoGlyphPath;

typedef struct {
    const char *name;
    TwoGlyphPath path;
    int pending_turns;
    const char *offered;
    const char *offered_alt;
    const char *prompt;
} TwoGlyphCase;

static const TwoGlyphCase CASES[] = {
    {"natural-both-expansion", TWO_GLYPH_PENDING, 0, "body", "joy", "Both, really—the body feels stronger, and there’s a quiet joy in making it hold."},
    {"bare-both", TWO_GLYPH_PENDING, 0, "body", "joy", "both."},
    {"offered-and", TWO_GLYPH_PENDING, 0, "body", "joy", "body and joy."},
    {"offered-and-reversed", TWO_GLYPH_PENDING, 0, "body", "joy", "joy and body."},
    {"offered-or", TWO_GLYPH_PENDING, 0, "body", "joy", "body or joy."},
    {"neither", TWO_GLYPH_PENDING, 0, "body", "joy", "neither body nor joy."},
    {"both-question", TWO_GLYPH_PENDING, 0, "body", "joy", "both?"},
    {"delayed-both", TWO_GLYPH_PENDING, 2, "body", "joy", "both."},
    {"single-offer-both", TWO_GLYPH_PENDING, 0, "body", NULL, "both."},
    {"duplicate-offer-both", TWO_GLYPH_PENDING, 0, "body", "body", "both."},
    {"single-food-expansion", TWO_GLYPH_PENDING, 0, "food", "home", "Food—the soup is warm."},
    {"explicit-and", TWO_GLYPH_PENDING, 2, "body", "joy", "flom is body and joy."},
    {"explicit-or", TWO_GLYPH_PENDING, 2, "body", "joy", "flom is body or joy."},
    {"same-turn-and", TWO_GLYPH_SAME_TURN, 0, NULL, NULL, "a flom is body and joy"},
    {"same-turn-rich-tie", TWO_GLYPH_SAME_TURN, 0, NULL, NULL, "Flom is the gentle comfort of warm light or cool rain"},
    {"both-followup", TWO_GLYPH_PENDING, 0, "body", "joy", "Both. What do you think?"},
    {"both-question-explanation", TWO_GLYPH_PENDING, 0, "body", "joy", "Both—what do you think?"},
    {"ascii-hyphen-both", TWO_GLYPH_PENDING, 0, "body", "joy", "Both, really--the body feels stronger and joy stays quiet."},
    {NULL, 0, 0, NULL, NULL, NULL}
};

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ?
        GLYPH_NAMES[glyph] : "none";
}

static const char *reference_name(
        LeoSchoolAnswerReference reference) {
    switch (reference) {
        case LEO_SCHOOL_ANSWER_EXPLICIT: return "explicit";
        case LEO_SCHOOL_ANSWER_ANAPHORIC: return "anaphoric";
        case LEO_SCHOOL_ANSWER_ELLIPTIC: return "elliptic";
        case LEO_SCHOOL_ANSWER_PAIRED: return "paired";
        default: return "unreferenced";
    }
}

static void seed_pending(Leo *leo, const TwoGlyphCase *item) {
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending, "flom");
    leo->school.pending_glyph = item->offered ?
        semtok_word(item->offered) : -1;
    leo->school.pending_alt_glyph = item->offered_alt ?
        semtok_word(item->offered_alt) : -1;
    leo->school.pending_turns = item->pending_turns;
    leo_wonder_open(leo, "flom", leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

int main(int argc, char **argv) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    const char *arm = "candidate";
    if (argc == 2 && !strcmp(argv[1], "--ablation")) {
        arm = "control";
        g_leo_school_two_glyph_learning_on = 0;
    } else if (argc != 1) {
        free(leo);
        return 2;
    }

    puts("arm\tcase\tpath\tprompt\treference\tgrounded\tgrounded_alt\tlearned\tprimary\talternate\tpending\tepisode_resolved\tepisode_answer\tepisode_answer_alt\tprojected_primary\tprojected_alternate");
    for (int i = 0; CASES[i].name; i++) {
        const TwoGlyphCase *item = &CASES[i];
        LeoSchoolAnswerEvidence evidence;
        LeoSchoolAnswerReference reference =
            LEO_SCHOOL_ANSWER_UNREFERENCED;
        int grounded = -1, grounded_alt = -1;
        if (item->path == TWO_GLYPH_PENDING) {
            seed_pending(leo, item);
            grounded = leo_school_grounded_answer_meanings(
                leo, item->prompt, &grounded_alt,
                &evidence, &reference);
        } else {
            leo_init(leo);
            grounded = leo_school_same_turn_grounding(
                leo, item->prompt, "flom", &evidence);
        }

        char out[1024];
        srand(12700 + i);
        leo_respond(leo, item->prompt, out, sizeof out);
        int learned = leo_school_learned_index(leo, "flom");
        int primary = learned >= 0 ?
            leo->school.learned_glyph[learned] : -1;
        int alternate = learned >= 0 ?
            leo->school.learned_alt_glyph[learned] : -1;
        int episode = item->path == TWO_GLYPH_PENDING &&
            leo->school.n_wonders > 0 ? 0 : -1;
        int resolved = episode >= 0 ?
            leo->school.wonders[episode].resolved : 0;
        int answer = episode >= 0 ?
            leo->school.wonders[episode].answer_glyph : -1;
        int answer_alt = episode >= 0 ?
            leo->school.wonders[episode].answer_alt_glyph : -1;
        int projected[2];
        int n_projected = leo_school_word_glyphs(
            leo, "flom", projected);
        printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\n",
               arm, item->name,
               item->path == TWO_GLYPH_PENDING ?
                   "pending" : "same-turn",
               item->prompt, reference_name(reference),
               glyph_name(grounded), glyph_name(grounded_alt),
               learned >= 0 ? "yes" : "no",
               glyph_name(primary), glyph_name(alternate),
               leo->school.pending[0] ? leo->school.pending : "none",
               resolved, glyph_name(answer), glyph_name(answer_alt),
               n_projected > 0 ? glyph_name(projected[0]) : "none",
               n_projected > 1 ? glyph_name(projected[1]) : "none");
        leo_free(leo);
    }
    free(leo);
    return 0;
}
