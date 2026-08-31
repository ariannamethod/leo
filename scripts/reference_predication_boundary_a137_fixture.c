#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *name;
    const char *prompt;
    int pending_turns;
} ReferencePredicationCase;

static const ReferencePredicationCase CASES[] = {
    {"he-after", "I meant the zorble feeling he might be carrying.", 0},
    {"she-after", "I meant the zorble feeling she might be carrying.", 0},
    {"child-after", "I meant the zorble feeling the child might be carrying.", 0},
    {"pronoun-front", "He might be carrying the zorble feeling.", 0},
    {"co-present-child", "The child carries a zorble.", 0},
    {"bare-reference", "I meant zorble.", 0},
    {"natural-negative-correction", "Maybe not water—just someone carrying a zorble feeling. Where does he go?", 0},
    {"explicit-followup", "a zorble is water. What do you hear?", 0},
    {"delayed-explicit", "a zorble is animal. What do you remember?", 1},
    {"anaphoric-followup", "it is an animal. Do you hear music?", 0},
    {"elliptic-followup", "water. What do you hear?", 0},
    {"negative-followup", "a zorble is not water. Is it animal?", 0},
    {"tail-evidence-isolated", "a zorble is animal. Is it water?", 0},
    {"positive-definition", "a zorble is pain.", 0},
    {"paired-definition", "a zorble is water and animal.", 0},
    {NULL, NULL, 0}
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
    g_leo_school_negative_family_on = 0;
    g_leo_school_reciprocal_s_family_on = 0;
    g_leo_school_family_heard_threshold_on = 0;
    g_leo_school_two_layer_family_composition_on = 0;
    int water = semtok_word("water");

    puts("case\tprompt\tpending_turns\tcandidate_primary\tcandidate_alternate\tcandidate_reference\tcandidate_water_asserted\tcandidate_water_rejected\tcontrol_primary\tcontrol_alternate\tcontrol_reference\tcontrol_water_asserted\tcontrol_water_rejected");
    for (int i = 0; CASES[i].name; i++) {
        LeoSchoolAnswerEvidence candidate_evidence;
        LeoSchoolAnswerReference candidate_reference;
        int candidate_alternate = -1;
        seed_case(leo, CASES[i].pending_turns);
        g_leo_school_reference_predication_on = 1;
        int candidate_primary = leo_school_grounded_answer_meanings(
            leo, CASES[i].prompt, &candidate_alternate,
            &candidate_evidence, &candidate_reference);
        leo_free(leo);

        LeoSchoolAnswerEvidence control_evidence;
        LeoSchoolAnswerReference control_reference;
        int control_alternate = -1;
        seed_case(leo, CASES[i].pending_turns);
        g_leo_school_reference_predication_on = 0;
        int control_primary = leo_school_grounded_answer_meanings(
            leo, CASES[i].prompt, &control_alternate,
            &control_evidence, &control_reference);
        printf("%s\t%s\t%d\t%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%d\t%d\n",
               CASES[i].name, CASES[i].prompt,
               CASES[i].pending_turns,
               glyph_name(candidate_primary),
               glyph_name(candidate_alternate),
               reference_name(candidate_reference),
               candidate_evidence.asserted[water],
               candidate_evidence.rejected[water],
               glyph_name(control_primary),
               glyph_name(control_alternate),
               reference_name(control_reference),
               control_evidence.asserted[water],
               control_evidence.rejected[water]);
        leo_free(leo);
    }

    g_leo_school_reference_predication_on = 1;
    free(leo);
    return 0;
}
