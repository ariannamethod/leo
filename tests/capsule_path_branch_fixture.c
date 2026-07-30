#define LEO_NO_MAIN
#include "../leo.c"

static const char *curiosity_name(int outcome) {
    static const char *names[LEO_CURIOSITY_OUTCOME_COUNT] = {
        "none", "asked", "reasked", "resolved", "continued",
        "blocked-distress", "asked-deferred", "blocked-deferred",
        "address-guarded", "redirected", "queued-occupied",
        "no-candidate", "disabled"
    };
    if (outcome < 0 || outcome >= LEO_CURIOSITY_OUTCOME_COUNT)
        return "invalid";
    return names[outcome];
}

static int binary_arg(const char *value, int *out) {
    if (!strcmp(value, "0")) {
        *out = 0;
        return 1;
    }
    if (!strcmp(value, "1")) {
        *out = 1;
        return 1;
    }
    return 0;
}

static int next_prompt(FILE *fp, char *out, size_t cap) {
    if (!fgets(out, (int)cap, fp)) return 0;
    size_t n = strlen(out);
    while (n > 0 && (out[n - 1] == '\n' || out[n - 1] == '\r'))
        out[--n] = 0;
    return out[0] != 0;
}

int main(int argc, char **argv) {
    if (argc != 15) {
        fprintf(stderr,
                "usage: %s STATE CASE ARM VARIANT SEED CAUSE PROMPTS "
                "WORK_STATE PULL BE ASK MEANING DIARY CAPSULE\n",
                argv[0]);
        return 2;
    }
    const char *state = argv[1];
    const char *case_id = argv[2];
    const char *arm = argv[3];
    const char *variant = argv[4];
    long seed = strtol(argv[5], NULL, 10);
    int cause = atoi(argv[6]);
    const char *prompts_path = argv[7];
    const char *work_state = argv[8];
    if (!binary_arg(argv[9], &g_leo_gamma_pull_on) ||
        !binary_arg(argv[10], &g_leo_be_on) ||
        !binary_arg(argv[11], &g_leo_ask_on) ||
        !binary_arg(argv[12], &g_leo_spore_meaning_on) ||
        !binary_arg(argv[13], &g_leo_gamma_diary_on) ||
        !binary_arg(argv[14], &g_leo_capsule_on)) {
        fprintf(stderr, "factor values must be 0 or 1\n");
        return 2;
    }

    FILE *prompts = fopen(prompts_path, "rb");
    if (!prompts) {
        fprintf(stderr, "cannot open prompts: %s\n", prompts_path);
        return 2;
    }
    Leo *leo = malloc(sizeof *leo);
    if (!leo) {
        fclose(prompts);
        return 2;
    }
    leo_init(leo);
    if (!leo_load_state(leo, state)) {
        fprintf(stderr, "cannot load state: %s\n", state);
        leo_free(leo);
        free(leo);
        fclose(prompts);
        return 2;
    }

    int man = semtok_find_glyph("man");
    int woman = semtok_find_glyph("woman");
    char prompt[4096];
    for (int relative = 1; relative <= 4; relative++) {
        if (!next_prompt(prompts, prompt, sizeof prompt)) {
            fprintf(stderr, "prompt %d absent\n", relative);
            leo_free(leo);
            free(leo);
            fclose(prompts);
            return 2;
        }
        srand((unsigned)(seed + cause + relative - 2));
        char reply[2048];
        leo_respond(leo, prompt, reply, sizeof reply);
        char visible[2048];
        int visible_n = 0;
        while (reply[visible_n] && reply[visible_n] != '\n' &&
               reply[visible_n] != '\r' && reply[visible_n] != '\t') {
            visible[visible_n] = reply[visible_n];
            visible_n++;
        }
        visible[visible_n] = 0;
        int hist[GLYPH_COUNT];
        leo_school_glyph_votes(leo, visible, hist, 1);
        int confounded =
            leo_flow_prompt_has_word(prompt, "flom") ||
            leo_flow_prompt_has_word(visible, "flom");
        printf("%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%d"
               "\t%d\t%.9g\t%.9g\t%d\n",
               case_id, arm, variant, relative, prompt, visible,
               curiosity_name(leo->curiosity.outcome),
               leo->curiosity.candidate[0] ?
                   leo->curiosity.candidate : "none",
               hist[man] > 0, hist[woman] > 0, confounded,
               leo->gamma_primed, (double)leo->gamma_gap,
               (double)leo->debt, leo->n_spores);
        if (!leo_save_state(leo, work_state)) {
            fprintf(stderr, "cannot save state: %s\n", work_state);
            leo_free(leo);
            free(leo);
            fclose(prompts);
            return 2;
        }
        if (relative < 4) {
            leo_free(leo);
            leo_init(leo);
            if (!leo_load_state(leo, work_state)) {
                fprintf(stderr, "cannot reload state: %s\n", work_state);
                leo_free(leo);
                free(leo);
                fclose(prompts);
                return 2;
            }
        }
    }
    if (next_prompt(prompts, prompt, sizeof prompt)) {
        fprintf(stderr, "too many prompts\n");
        leo_free(leo);
        free(leo);
        fclose(prompts);
        return 2;
    }
    leo_free(leo);
    free(leo);
    fclose(prompts);
    return 0;
}
