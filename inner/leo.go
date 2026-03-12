/*
 * leo.go — Inner World of the Language Emergent Organism
 *
 * Autonomous goroutines that run continuously:
 *   1. Dream    — connect distant memories, create new associations (every 5min)
 *   2. Crystallize — scan for super-token formation via PMI (every 2min)
 *   3. InnerVoice — Leo talks to himself when nobody is around (every 10min)
 *   4. Autosave — periodic state persistence (every 5min)
 *
 * Plus: CGO bridge to leo.c, REPL with Go's readline,
 * and the web interface for browser-based interaction.
 *
 * leo.c works alone. leo.go adds the inner world.
 * Like consciousness emerging from neurons — not required, but transformative.
 *
 * Build: go build -o leo_inner .
 * (requires: leo.c compiled as leo.o with -DLEO_LIB)
 */

package main

/*
#cgo CFLAGS: -O2
#cgo LDFLAGS: -lm -lsqlite3 -lpthread
#include <stdlib.h>

// Forward declarations matching leo.c public API
typedef struct Leo Leo;

// We need the struct size for allocation, but CGO can't see the full struct.
// Solution: leo.c provides a constructor that returns a heap-allocated Leo*.

// Bridge functions — defined below, call into leo.o
extern void* leo_bridge_create(const char *db_path);
extern void  leo_bridge_destroy(void *leo);
extern void  leo_bridge_bootstrap(void *leo);
extern void  leo_bridge_load(void *leo);
extern void  leo_bridge_save(void *leo);
extern void  leo_bridge_ingest(void *leo, const char *text);
extern int   leo_bridge_generate(void *leo, const char *prompt, char *out, int max_len);
extern void  leo_bridge_dream(void *leo);
extern void  leo_bridge_stats(void *leo);
extern int   leo_bridge_step(void *leo);
extern int   leo_bridge_vocab(void *leo);
extern int   leo_bridge_bootstrapped(void *leo);
extern void  leo_bridge_export_gguf(void *leo, const char *path);
extern int   leo_bridge_import_gguf(void *leo, const char *path);
extern void  leo_bridge_log_conversation(void *leo, const char *prompt, const char *response);
extern void  leo_bridge_log_episode(void *leo, const char *event_type, const char *content, const char *metadata);
extern int   leo_bridge_conversation_count(void *leo);
extern int   leo_bridge_episode_count(void *leo, const char *event_type);

// MathBrain bridge
extern void  leo_bridge_mathbrain_observe(void *leo, const char *prompt, const char *response);
extern float leo_bridge_mathbrain_loss(void *leo);
extern int   leo_bridge_mathbrain_observations(void *leo);
extern float leo_bridge_mathbrain_tau_nudge(void *leo);

// Phase4 bridge
extern int   leo_bridge_phase4_transitions(void *leo);
extern int   leo_bridge_phase4_suggest(void *leo, int from_island);
extern int   leo_bridge_phase4_island_visits(void *leo, int island);
extern float leo_bridge_phase4_island_quality(void *leo, int island);

// Temperature bridge (for MetaLeo)
extern float leo_bridge_get_tau(void *leo);
extern void  leo_bridge_set_tau(void *leo, float tau);

// Trauma bridge
extern void  leo_bridge_set_trauma(void *leo, float level);
extern float leo_bridge_get_trauma(void *leo);
extern void  leo_bridge_set_trauma_weight(void *leo, int token_id, float weight);
extern float leo_bridge_get_trauma_weight(void *leo, int token_id);
extern int   leo_bridge_token_id(void *leo, const char *word);

// Positional Hebbian profile bridge
extern float leo_bridge_get_dist_profile(void *leo, int d);
extern float leo_bridge_get_class_mod(void *leo, int c);
extern int   leo_bridge_dist_profile_updates(void *leo);
*/
import "C"

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"unsafe"
)

// Leo wraps the C organism with Go's inner world
type Leo struct {
	ptr    unsafe.Pointer
	mu     sync.Mutex
	alive  bool
	stopCh chan struct{}
}

// NewLeo creates a new organism
func NewLeo(dbPath string) *Leo {
	cPath := C.CString(dbPath)
	defer C.free(unsafe.Pointer(cPath))

	ptr := C.leo_bridge_create(cPath)
	if ptr == nil {
		fmt.Fprintf(os.Stderr, "[leo.go] failed to create organism\n")
		os.Exit(1)
	}

	return &Leo{
		ptr:    ptr,
		alive:  true,
		stopCh: make(chan struct{}),
	}
}

// Close saves and destroys
func (l *Leo) Close() {
	l.mu.Lock()
	defer l.mu.Unlock()
	if !l.alive {
		return
	}
	l.alive = false
	close(l.stopCh)
	C.leo_bridge_save(l.ptr)
	C.leo_bridge_destroy(l.ptr)
	l.ptr = nil
}

// Bootstrap initializes from embedded seed + leo.txt
func (l *Leo) Bootstrap() {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_bootstrap(l.ptr)
}

// Load tries to load saved state
func (l *Leo) Load() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_load(l.ptr)
	return C.leo_bridge_bootstrapped(l.ptr) != 0
}

// Save persists state
func (l *Leo) Save() {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_save(l.ptr)
}

// Ingest processes text into the field
func (l *Leo) Ingest(text string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	cText := C.CString(text)
	defer C.free(unsafe.Pointer(cText))
	C.leo_bridge_ingest(l.ptr, cText)
}

// Generate produces a response
func (l *Leo) Generate(prompt string) string {
	l.mu.Lock()
	defer l.mu.Unlock()

	cPrompt := C.CString(prompt)
	defer C.free(unsafe.Pointer(cPrompt))

	const maxLen = 8192
	buf := make([]byte, maxLen)
	cBuf := (*C.char)(unsafe.Pointer(&buf[0]))
	C.leo_bridge_generate(l.ptr, cPrompt, cBuf, maxLen)

	return C.GoString(cBuf)
}

// Dream runs one dream cycle
func (l *Leo) Dream() {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_dream(l.ptr)
}

// Stats prints organism stats
func (l *Leo) Stats() {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_stats(l.ptr)
}

// Step returns current step count
func (l *Leo) Step() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_step(l.ptr))
}

// Vocab returns current vocab size
func (l *Leo) Vocab() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_vocab(l.ptr))
}

// ExportGGUF exports the organism as a GGUF spore
func (l *Leo) ExportGGUF(path string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))
	C.leo_bridge_export_gguf(l.ptr, cPath)
}

// ImportGGUF loads a GGUF spore into the organism
func (l *Leo) ImportGGUF(path string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))
	return C.leo_bridge_import_gguf(l.ptr, cPath) == 0
}

// LogConversation records a conversation turn in SQLite
func (l *Leo) LogConversation(prompt, response string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	cPrompt := C.CString(prompt)
	cResp := C.CString(response)
	defer C.free(unsafe.Pointer(cPrompt))
	defer C.free(unsafe.Pointer(cResp))
	C.leo_bridge_log_conversation(l.ptr, cPrompt, cResp)
}

// LogEpisode records an episode in SQLite
func (l *Leo) LogEpisode(eventType, content, metadata string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	cType := C.CString(eventType)
	cContent := C.CString(content)
	cMeta := C.CString(metadata)
	defer C.free(unsafe.Pointer(cType))
	defer C.free(unsafe.Pointer(cContent))
	defer C.free(unsafe.Pointer(cMeta))
	C.leo_bridge_log_episode(l.ptr, cType, cContent, cMeta)
}

// ConversationCount returns the number of logged conversations
func (l *Leo) ConversationCount() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_conversation_count(l.ptr))
}

// EpisodeCount returns the number of logged episodes (optionally filtered by type)
func (l *Leo) EpisodeCount(eventType string) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	if eventType == "" {
		return int(C.leo_bridge_episode_count(l.ptr, nil))
	}
	cType := C.CString(eventType)
	defer C.free(unsafe.Pointer(cType))
	return int(C.leo_bridge_episode_count(l.ptr, cType))
}

// MathBrainObserve feeds a conversation to the body awareness MLP.
// Computes metrics, trains the MLP, produces regulation output.
func (l *Leo) MathBrainObserve(prompt, response string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	cPrompt := C.CString(prompt)
	cResp := C.CString(response)
	defer C.free(unsafe.Pointer(cPrompt))
	defer C.free(unsafe.Pointer(cResp))
	C.leo_bridge_mathbrain_observe(l.ptr, cPrompt, cResp)
}

// MathBrainLoss returns the running loss of the body awareness MLP.
func (l *Leo) MathBrainLoss() float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_mathbrain_loss(l.ptr))
}

// MathBrainObservations returns how many times the MLP has been trained.
func (l *Leo) MathBrainObservations() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_mathbrain_observations(l.ptr))
}

// MathBrainTauNudge returns the current temperature adjustment from body awareness.
func (l *Leo) MathBrainTauNudge() float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_mathbrain_tau_nudge(l.ptr))
}

// SetTrauma sets the organism's trauma level (0.0–1.0).
// Called from traumaWatch goroutine to feed trauma into dario_compute().
func (l *Leo) SetTrauma(level float32) {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_set_trauma(l.ptr, C.float(level))
}

// GetTrauma returns the current trauma level.
func (l *Leo) GetTrauma() float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_get_trauma(l.ptr))
}

// SetTraumaWeight sets a per-token trauma weight (scar).
func (l *Leo) SetTraumaWeight(tokenID int, weight float32) {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_set_trauma_weight(l.ptr, C.int(tokenID), C.float(weight))
}

// GetTraumaWeight returns the trauma weight for a token.
func (l *Leo) GetTraumaWeight(tokenID int) float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_get_trauma_weight(l.ptr, C.int(tokenID)))
}

// Phase4Transitions returns the number of recorded island transitions.
func (l *Leo) Phase4Transitions() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_phase4_transitions(l.ptr))
}

// Phase4Suggest returns the best island to transition to from the given island.
func (l *Leo) Phase4Suggest(fromIsland int) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_phase4_suggest(l.ptr, C.int(fromIsland)))
}

// Phase4IslandVisits returns how many times an island was visited.
func (l *Leo) Phase4IslandVisits(island int) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_phase4_island_visits(l.ptr, C.int(island)))
}

// Phase4IslandQuality returns the running quality average for an island.
func (l *Leo) Phase4IslandQuality(island int) float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_phase4_island_quality(l.ptr, C.int(island)))
}

// TokenID looks up a token's ID by its word string. Returns -1 if not found.
func (l *Leo) TokenID(word string) int {
	l.mu.Lock()
	defer l.mu.Unlock()
	cWord := C.CString(word)
	defer C.free(unsafe.Pointer(cWord))
	return int(C.leo_bridge_token_id(l.ptr, cWord))
}

// GetTau returns the current base temperature.
func (l *Leo) GetTau() float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_get_tau(l.ptr))
}

// SetTau sets the base temperature (used by MetaLeo for dual generation).
func (l *Leo) SetTau(tau float32) {
	l.mu.Lock()
	defer l.mu.Unlock()
	C.leo_bridge_set_tau(l.ptr, C.float(tau))
}

// GetDistProfile returns the positional Hebbian weight at distance d.
func (l *Leo) GetDistProfile(d int) float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_get_dist_profile(l.ptr, C.int(d)))
}

// GetClassMod returns the class modifier for token class c.
func (l *Leo) GetClassMod(c int) float32 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return float32(C.leo_bridge_get_class_mod(l.ptr, C.int(c)))
}

// DistProfileUpdates returns how many Hebbian updates the profile has received.
func (l *Leo) DistProfileUpdates() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return int(C.leo_bridge_dist_profile_updates(l.ptr))
}

// Inner world goroutines (startInnerVoice, startAutosave, startDreamDialog,
// startTraumaWatch, startOverthinking, startThemeFlow, StartInnerWorld)
// are defined in inner_world.go

// ========================================================================
// MAIN — REPL with inner world
// ========================================================================

func main() {
	dbPath := flag.String("db", "leo_state.db", "path to SQLite state database")
	forceBootstrap := flag.Bool("bootstrap", false, "force bootstrap even if saved state exists")
	webPort := flag.Int("web", 0, "start web interface on given port (0 = disabled, default 3000 if flag present without value)")
	enableVoice := flag.Bool("voice", false, "enable inner voice goroutine (debug: Leo talks to himself every 10min)")
	flag.Parse()

	// --web without value defaults to 3000
	if *webPort == 0 {
		for _, arg := range os.Args[1:] {
			if arg == "--web" || arg == "-web" {
				*webPort = 3000
				break
			}
		}
	}

	fmt.Println("[leo] Language Emergent Organism")

	leo := NewLeo(*dbPath)

	var webServer *WebServer

	// Graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\n[leo.go] saving and shutting down...")
		if webServer != nil {
			webServer.Shutdown()
		}
		leo.Close()
		os.Exit(0)
	}()

	// Load or bootstrap
	if !*forceBootstrap {
		if !leo.Load() {
			leo.Bootstrap()
		}
	} else {
		leo.Bootstrap()
	}

	// Start inner world
	leo.StartInnerWorld()

	// Start inner voice if requested (debug only)
	if *enableVoice {
		leo.StartInnerVoice()
	}

	// Start web interface if requested
	if *webPort > 0 {
		webServer = StartWeb(leo, *webPort)
	}

	// REPL
	fmt.Println("[leo] ready.")
	fmt.Println()

	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Print("you> ")
		if !scanner.Scan() {
			break
		}

		line := strings.TrimSpace(scanner.Text())
		if len(line) == 0 {
			continue
		}

		// The only user-facing command is /quit. Everything else is internal.
		if line == "/quit" || line == "/exit" {
			fmt.Println("[leo] saving. resonance unbroken.")
			if webServer != nil {
				webServer.Shutdown()
			}
			leo.Close()
			return
		}

		// Normal conversation
		response := leo.Generate(line)
		fmt.Printf("\nLeo: %s\n\n", response)

		// Notify inner world goroutines
		leo.NotifyConversation(line, response)
	}

	if webServer != nil {
		webServer.Shutdown()
	}
	leo.Close()
}
