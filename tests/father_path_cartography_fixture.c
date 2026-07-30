#define LEO_NO_MAIN
#include "../leo.c"

typedef struct {
    float sum[GLYPH_COUNT];
    float max[GLYPH_COUNT];
    int words[GLYPH_COUNT];
    int32_t top_id[LEO_FLOW_CONSTELLATION];
    float top_weight[LEO_FLOW_CONSTELLATION];
} FieldMap;

static void field_map(
        const Leo *leo, const char *prompt, const int *p_ids, int p_n,
        const float *gravity, FieldMap *map) {
    memset(map, 0, sizeof *map);
    for (int k = 0; k < LEO_FLOW_CONSTELLATION; k++)
        map->top_id[k] = -1;
    leo_flow_field_constellation(
        leo, prompt, p_ids, p_n, gravity,
        map->top_id, map->top_weight);

    char seen[LEO_FLOW_CONSTELLATION * 32][LEO_HEARD_WORDLEN];
    float seen_weight[LEO_FLOW_CONSTELLATION * 32];
    int seen_glyph[LEO_FLOW_CONSTELLATION * 32];
    int n_seen = 0;
    memset(seen, 0, sizeof seen);
    memset(seen_weight, 0, sizeof seen_weight);

    for (int id = 0; id < leo->bpe.vocab_size; id++) {
        char word[LEO_HEARD_WORDLEN];
        if (gravity[id] <= 0.0f ||
            !leo_token_is_gravity_target(&leo->bpe, id) ||
            !leo_flow_token_word(&leo->bpe, id, word) ||
            leo_heard_count(&leo->heard, word) <= 0 ||
            leo_flow_prompt_has_word(prompt, word))
            continue;
        int glyph = leo_semtok_word(leo, word);
        if (!leo_glyph_concept(glyph)) continue;

        int at = -1;
        for (int i = 0; i < n_seen; i++)
            if (!strcmp(seen[i], word)) {
                at = i;
                break;
            }
        if (at >= 0) {
            if (gravity[id] > seen_weight[at])
                seen_weight[at] = gravity[id];
            continue;
        }
        if (n_seen >= (int)(sizeof seen / sizeof seen[0])) continue;
        strncpy(seen[n_seen], word, sizeof seen[n_seen] - 1);
        seen_weight[n_seen] = gravity[id];
        seen_glyph[n_seen] = glyph;
        n_seen++;
    }

    for (int i = 0; i < n_seen; i++) {
        int glyph = seen_glyph[i];
        map->sum[glyph] += seen_weight[i];
        if (seen_weight[i] > map->max[glyph])
            map->max[glyph] = seen_weight[i];
        map->words[glyph]++;
    }
}

static void print_top(const Leo *leo, const FieldMap *map) {
    int printed = 0;
    for (int k = 0; k < LEO_FLOW_CONSTELLATION; k++) {
        if (map->top_id[k] < 0) continue;
        char word[LEO_HEARD_WORDLEN];
        if (!leo_flow_token_word(&leo->bpe, map->top_id[k], word))
            continue;
        if (printed++) putchar('|');
        printf("%s:%.6f", word, (double)map->top_weight[k]);
    }
    if (!printed) printf("none");
}

static int observe(
        Leo *leo, const char *case_id, const char *variant,
        const char *phase, const char *prompt) {
    int p_ids[1024];
    int p_n = bpe_encode(
        &leo->bpe, (const uint8_t *)prompt, (int)strlen(prompt),
        p_ids, 1024);
    float *gravity = compute_prompt_gravity(leo, p_ids, p_n);
    if (!gravity) return 0;
    FieldMap map;
    field_map(leo, prompt, p_ids, p_n, gravity, &map);
    int man = semtok_find_glyph("man");
    int woman = semtok_find_glyph("woman");
    printf("%s\t%s\t%s\t%.6f\t%.6f\t%d\t%.6f\t%.6f\t%d\t",
           case_id, variant, phase,
           (double)map.sum[man], (double)map.max[man], map.words[man],
           (double)map.sum[woman], (double)map.max[woman],
           map.words[woman]);
    print_top(leo, &map);
    putchar('\n');
    free(gravity);
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: %s STATE CASE VARIANT PROMPT\n", argv[0]);
        return 2;
    }
    Leo *leo = malloc(sizeof *leo);
    if (!leo) return 2;
    leo_init(leo);
    if (!leo_load_state(leo, argv[1])) {
        fprintf(stderr, "cannot load state: %s\n", argv[1]);
        leo_free(leo);
        free(leo);
        return 2;
    }
    if (!observe(leo, argv[2], argv[3], "pre", argv[4])) {
        leo_free(leo);
        free(leo);
        return 2;
    }
    leo_ingest(leo, argv[4]);
    if (!observe(leo, argv[2], argv[3], "post", argv[4])) {
        leo_free(leo);
        free(leo);
        return 2;
    }
    leo_free(leo);
    free(leo);
    return 0;
}
