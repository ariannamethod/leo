#define LEO_NO_MAIN
#include "../leo.c"

static const char *glyph_name(int glyph) {
    return glyph >= 0 && glyph < GLYPH_COUNT ? GLYPH_NAMES[glyph] : "none";
}

static const char *reference_name(LeoSchoolAnswerReference reference) {
    switch (reference) {
        case LEO_SCHOOL_ANSWER_EXPLICIT: return "explicit";
        case LEO_SCHOOL_ANSWER_ANAPHORIC: return "anaphoric";
        case LEO_SCHOOL_ANSWER_ELLIPTIC: return "elliptic";
        default: return "unreferenced";
    }
}

static void print_unknown(Leo *leo, const char *name, const char *text) {
    char unknown[LEO_HEARD_WORDLEN] = {0};
    int found = leo_school_find_unknown(leo, text, unknown);
    printf("lexical\t%s\t%s\n", name, found ? unknown : "none");
}

static void print_answer(Leo *leo, const char *name, const char *text) {
    LeoSchoolAnswerEvidence evidence;
    LeoSchoolAnswerReference scoped_reference = LEO_SCHOOL_ANSWER_UNREFERENCED;
    LeoSchoolAnswerReference grounded_reference = LEO_SCHOOL_ANSWER_UNREFERENCED;
    LeoSchoolAnswerReference scope =
        leo_school_answer_scope(leo, text, &evidence);
    int grounded = leo_school_grounded_answer(
        leo, text, NULL, &grounded_reference);
    scoped_reference = scope;
    printf("answer\t%s\tscope=%s\tgrounded=%s\tgrounded_reference=%s\n",
           name, reference_name(scoped_reference), glyph_name(grounded),
           reference_name(grounded_reference));
}

int main(void) {
    Leo *leo = calloc(1, sizeof *leo);
    Leo *answer = calloc(1, sizeof *answer);
    if (!leo || !answer) return 2;
    leo_init(leo);
    leo_init(answer);

    print_unknown(leo, "ascii-contraction", "you don't have to remember");
    print_unknown(leo, "curly-contraction", "you don’t have to remember");
    print_unknown(leo, "curly-function-contraction", "what’s");
    print_unknown(leo, "known-curly-possessive", "child’s");
    print_unknown(leo, "unknown-curly-possessive", "zorble’s");
    print_unknown(leo, "known-curly-quoted", "‘child’");
    print_unknown(leo, "unknown-curly-quoted", "‘zorble’");
    g_leo_school_natural_word_boundary_on = 0;
    print_unknown(leo, "curly-contraction-ablation", "you don’t have to remember");
    g_leo_school_natural_word_boundary_on = 1;
    print_unknown(leo, "beneath", "beneath");
    print_unknown(leo, "rainy", "rainy");
    print_unknown(leo, "belonged", "belonged");

    snprintf(answer->school.pending, sizeof answer->school.pending, "zorble");
    answer->school.pending_glyph = (int8_t)semtok_word("water");
    answer->school.pending_alt_glyph = (int8_t)semtok_word("animal");
    answer->school.pending_turns = 0;
    leo_wonder_open(answer, "zorble", answer->school.pending_glyph,
                    answer->school.pending_alt_glyph);
    print_answer(answer, "answer-then-followup",
                 "a zorble is water. What do you hear?");
    print_answer(answer, "anaphora-then-followup",
                 "it is water. What do you hear?");
    print_answer(answer, "counter-question", "what do you think?");
    print_answer(answer, "question-shaped-proposition", "it is water?");

    snprintf(leo->school.pending, sizeof leo->school.pending, "beneath");
    leo->school.pending_glyph = (int8_t)semtok_word("fire");
    leo->school.pending_alt_glyph = (int8_t)semtok_word("see");
    printf("reask\tbeneath-literal\t%d\n",
           leo_wonder_resonates(leo, "can you feel it beneath you?"));
    printf("reask\tbeneath-hypothesis-only\t%d\n",
           leo_wonder_resonates(leo, "what story did someone read to you?"));
    snprintf(leo->school.pending, sizeof leo->school.pending, "rainy");
    leo->school.pending_glyph = (int8_t)semtok_word("light");
    leo->school.pending_alt_glyph = (int8_t)semtok_word("person");
    printf("reask\trainy-hypothesis-only\t%d\n",
           leo_wonder_resonates(
               leo, "what is walking near Leo—the sound, a person, or something else?"));

    leo_free(leo);
    leo_free(answer);
    free(leo);
    free(answer);
    return 0;
}
