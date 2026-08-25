#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    const char *name;
    const char *prompt;
} WonderReaskReferenceCase;

static const WonderReaskReferenceCase CASES[] = {
    {"exact-statement", "the zorble still puzzles me"},
    {"exact-question", "what is zorble?"},
    {"anaphoric-inverted", "is it water?"},
    {"anaphoric-declarative", "that is animal?"},
    {"anaphoric-modal", "could it be water?"},
    {"plain-hypothesis", "the cup holds water"},
    {"other-subject-question", "are you holding water?"},
    {"nominal-subject-question", "is the stone water?"},
    {"prior-clause-only", "water is nearby. What do you hear?"},
    {"both-unreferenced", "water and animal move together"},
    {"sensory-anaphora", "that sounds like water. What do you hear?"},
    {"what-about", "what about animal?"},
    {"unrelated", "the room is quiet"},
    {NULL, NULL}
};

int main(void) {
    Leo *leo = calloc(1, sizeof *leo);
    if (!leo) return 2;
    g_leo_school_negative_family_on = 0;
    leo_init(leo);
    snprintf(leo->school.pending, sizeof leo->school.pending, "zorble");
    leo->school.pending_glyph = (int8_t)semtok_word("water");
    leo->school.pending_alt_glyph = (int8_t)semtok_word("animal");
    LeoWonderEpisode *episode = leo_wonder_open(
        leo, leo->school.pending,
        leo->school.pending_glyph,
        leo->school.pending_alt_glyph);
    uint64_t wonder_id = leo_wonder_episode_id(episode);

    puts("case\tprompt\tdefault_reask\tdefault_shadow_invite\tablation_reask\tablation_shadow_invite");
    for (int i = 0; CASES[i].name; i++) {
        g_leo_wonder_reask_reference_on = 1;
        int default_reask = leo_wonder_resonates(leo, CASES[i].prompt);
        int default_shadow = leo_wonder_prompt_invites(
            leo, wonder_id, CASES[i].prompt);
        g_leo_wonder_reask_reference_on = 0;
        int ablation_reask = leo_wonder_resonates(leo, CASES[i].prompt);
        int ablation_shadow = leo_wonder_prompt_invites(
            leo, wonder_id, CASES[i].prompt);
        printf("%s\t%s\t%d\t%d\t%d\t%d\n",
               CASES[i].name, CASES[i].prompt,
               default_reask, default_shadow,
               ablation_reask, ablation_shadow);
    }

    g_leo_wonder_reask_reference_on = 1;
    leo_free(leo);
    free(leo);
    return 0;
}
