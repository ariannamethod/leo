#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *name;
    const char *prompt;
    int pending_turns;
} AnswerFollowupCase;

static const AnswerFollowupCase CASES[] = {
    {"explicit-followup", "a zorble is water. What do you hear?", 0},
    {"anaphoric-followup", "it is water. What do you hear?", 0},
    {"elliptic-followup", "water. What do you hear?", 0},
    {"exclamation-followup", "it is animal! What do you hear?", 0},
    {"semicolon-followup", "a zorble is animal; What do you hear?", 0},
    {"question-shaped", "it is water?", 0},
    {"counter-question", "what do you think?", 0},
    {"question-first", "what is a zorble? it is water.", 0},
    {"tail-names-target", "the river has water. What is a zorble?", 0},
    {"comma-question", "it is water, can you hear it?", 0},
    {"sensory-anaphora", "that sounds like a gentle memory. What do you hear?", 0},
    {"delayed-anaphora", "it is animal. What do you remember?", 1},
    {"delayed-explicit", "a zorble is animal. What do you remember?", 1},
    {"negative-followup", "a zorble is not water. Is it animal?", 0},
    {"tail-evidence-isolated", "a zorble is animal. Is it water?", 0},
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
    snprintf(leo->school.pending, sizeof leo->school.pending, "zorble");
    leo->school.pending_glyph = (int8_t)semtok_word("water");
    leo->school.pending_alt_glyph = (int8_t)semtok_word("animal");
    leo->school.pending_turns = pending_turns;
    leo_wonder_open(leo, "zorble", leo->school.pending_glyph,
                    leo->school.pending_alt_glyph);
}

int main(void) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    int water = semtok_word("water");
    int animal = semtok_word("animal");

    puts("case\tprompt\tpending_turns\tdefault_grounded\tdefault_reference\tdefault_water_asserted\tdefault_water_rejected\tdefault_animal_asserted\tablation_grounded\tablation_reference");
    for (int i = 0; CASES[i].name; i++) {
        LeoSchoolAnswerEvidence evidence;
        LeoSchoolAnswerReference reference;
        seed_case(leo, CASES[i].pending_turns);
        g_leo_school_answer_followup_on = 1;
        int default_grounded = leo_school_grounded_answer(
            leo, CASES[i].prompt, &evidence, &reference);
        int water_asserted = evidence.asserted[water];
        int water_rejected = evidence.rejected[water];
        int animal_asserted = evidence.asserted[animal];
        const char *default_reference = reference_name(reference);

        g_leo_school_answer_followup_on = 0;
        int ablation_grounded = leo_school_grounded_answer(
            leo, CASES[i].prompt, NULL, &reference);
        printf("%s\t%s\t%d\t%s\t%s\t%d\t%d\t%d\t%s\t%s\n",
               CASES[i].name, CASES[i].prompt, CASES[i].pending_turns,
               glyph_name(default_grounded), default_reference,
               water_asserted, water_rejected, animal_asserted,
               glyph_name(ablation_grounded), reference_name(reference));
        leo_free(leo);
    }

    g_leo_school_answer_followup_on = 1;
    free(leo);
    return 0;
}
