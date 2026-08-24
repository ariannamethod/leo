#define LEO_NO_MAIN
#include "../leo.c"

typedef enum {
    PLURAL_PENDING = 0,
    PLURAL_SAME_TURN
} PluralAnswerPath;

typedef struct {
    PluralAnswerPath path;
    const char *name;
    const char *prompt;
} PluralAnswerCase;

static const PluralAnswerCase CASES[] = {
    {PLURAL_PENDING, "natural-both-expansion", "Both, really—the body feels stronger, and there’s a quiet joy in making it hold."},
    {PLURAL_PENDING, "bare-both", "both."},
    {PLURAL_PENDING, "two-offered-ellipse", "body and joy."},
    {PLURAL_PENDING, "explicit-tie-body-first", "flom is body and joy."},
    {PLURAL_PENDING, "explicit-tie-joy-first", "flom is joy and body."},
    {PLURAL_PENDING, "explicit-unique-dominant", "flom is body body and joy."},
    {PLURAL_PENDING, "explicit-one", "flom is joy."},
    {PLURAL_PENDING, "explicit-negative-narrow", "flom is not body but joy."},
    {PLURAL_PENDING, "elliptic-neither", "neither body nor joy."},
    {PLURAL_SAME_TURN, "definition-one-concept", "a flom is warm fire"},
    {PLURAL_SAME_TURN, "definition-tie-body-first", "a flom is body and joy"},
    {PLURAL_SAME_TURN, "definition-tie-joy-first", "a flom is joy and body"},
    {PLURAL_SAME_TURN, "definition-rich-tie", "Flom is the gentle comfort of warm light or cool rain"},
    {PLURAL_SAME_TURN, "definition-unique-dominant", "a flom is body body and joy"},
    {PLURAL_SAME_TURN, "definition-negative-narrow", "a flom is not body but joy"},
    {0, NULL, NULL}
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

static void seed_pending(Leo *leo) {
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending, "flom");
    leo->school.pending_glyph = semtok_word("body");
    leo->school.pending_alt_glyph = semtok_word("joy");
    leo->school.pending_turns = 0;
    leo_wonder_open(leo, "flom", leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

static void evidence_maximum(
        const LeoSchoolAnswerEvidence *evidence,
        int *max_count, int *max_ties) {
    *max_count = 0;
    *max_ties = 0;
    for (int glyph = 0; glyph < GLYPH_COUNT; glyph++) {
        if (evidence->rejected[glyph] > 0 ||
            evidence->asserted[glyph] <= 0)
            continue;
        if (evidence->asserted[glyph] > *max_count) {
            *max_count = evidence->asserted[glyph];
            *max_ties = 1;
        } else if (evidence->asserted[glyph] == *max_count) {
            (*max_ties)++;
        }
    }
}

int main(int argc, char **argv) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    const char *arm = "candidate";
    if (argc == 2 && !strcmp(argv[1], "--ablation")) {
        arm = "control";
        g_leo_school_unique_answer_dominance_on = 0;
    } else if (argc != 1) {
        free(leo);
        return 2;
    }
    int body = semtok_word("body");
    int joy = semtok_word("joy");

    puts("arm\tpath\tcase\tprompt\treference\tselected_glyph\tmax_count\tmax_ties\tasserted_body\tasserted_joy\trejected_body\trejected_joy");
    for (int i = 0; CASES[i].name; i++) {
        LeoSchoolAnswerEvidence evidence;
        LeoSchoolAnswerReference reference =
            LEO_SCHOOL_ANSWER_UNREFERENCED;
        int selected;
        if (CASES[i].path == PLURAL_PENDING) {
            seed_pending(leo);
            selected = leo_school_grounded_answer(
                leo, CASES[i].prompt, &evidence, &reference);
        } else {
            leo_init(leo);
            selected = leo_school_same_turn_grounding(
                leo, CASES[i].prompt, "flom", &evidence);
        }
        int max_count, max_ties;
        evidence_maximum(&evidence, &max_count, &max_ties);
        printf("%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n",
               arm,
               CASES[i].path == PLURAL_PENDING ? "pending" : "same-turn",
               CASES[i].name, CASES[i].prompt,
               CASES[i].path == PLURAL_PENDING ?
                   reference_name(reference) : "definition",
               glyph_name(selected), max_count, max_ties,
               evidence.asserted[body], evidence.asserted[joy],
               evidence.rejected[body], evidence.rejected[joy]);
        leo_free(leo);
    }
    free(leo);
    return 0;
}
