/*
 * leo_bridge.c — CGO bridge between leo.go and leo.c
 *
 * Thin wrapper that provides heap-allocated Leo + safe accessors.
 * Compiled together with leo.c (both with -DLEO_LIB).
 *
 * go build uses this automatically via CGO.
 */

#define LEO_LIB
#include "../leo.c"

/* Create a heap-allocated Leo organism */
void* leo_bridge_create(const char *db_path) {
    Leo *leo = calloc(1, sizeof(Leo));
    if (!leo) return NULL;
    leo_init(leo, db_path);
    return leo;
}

/* Destroy and free */
void leo_bridge_destroy(void *ptr) {
    if (!ptr) return;
    Leo *leo = (Leo *)ptr;
    leo_free(leo);
    free(leo);
}

/* Bootstrap from embedded seed + leo.txt */
void leo_bridge_bootstrap(void *ptr) {
    leo_bootstrap((Leo *)ptr);
}

/* Load saved state */
void leo_bridge_load(void *ptr) {
    leo_load((Leo *)ptr);
}

/* Save state */
void leo_bridge_save(void *ptr) {
    leo_save((Leo *)ptr);
}

/* Ingest text */
void leo_bridge_ingest(void *ptr, const char *text) {
    leo_ingest((Leo *)ptr, text);
}

/* Generate response */
int leo_bridge_generate(void *ptr, const char *prompt, char *out, int max_len) {
    return leo_generate((Leo *)ptr, prompt, out, max_len);
}

/* Dream cycle */
void leo_bridge_dream(void *ptr) {
    leo_dream((Leo *)ptr);
}

/* Print stats */
void leo_bridge_stats(void *ptr) {
    leo_stats((Leo *)ptr);
}

/* Get current step */
int leo_bridge_step(void *ptr) {
    return ((Leo *)ptr)->step;
}

/* Get vocab size */
int leo_bridge_vocab(void *ptr) {
    return ((Leo *)ptr)->tok.n_words;
}

/* Check if bootstrapped */
int leo_bridge_bootstrapped(void *ptr) {
    return ((Leo *)ptr)->bootstrapped;
}

/* Export GGUF spore */
void leo_bridge_export_gguf(void *ptr, const char *path) {
    leo_export_gguf((Leo *)ptr, path);
}

/* Import GGUF spore */
int leo_bridge_import_gguf(void *ptr, const char *path) {
    return leo_import_gguf((Leo *)ptr, path);
}

/* Log conversation to SQLite */
void leo_bridge_log_conversation(void *ptr, const char *prompt, const char *response) {
    leo_db_log_conversation((Leo *)ptr, prompt, response);
}

/* Log episode to SQLite */
void leo_bridge_log_episode(void *ptr, const char *event_type,
                            const char *content, const char *metadata) {
    leo_db_log_episode((Leo *)ptr, event_type, content, metadata);
}

/* Get conversation count */
int leo_bridge_conversation_count(void *ptr) {
    return leo_db_conversation_count((Leo *)ptr);
}

/* Get episode count */
int leo_bridge_episode_count(void *ptr, const char *event_type) {
    return leo_db_episode_count((Leo *)ptr, event_type);
}
