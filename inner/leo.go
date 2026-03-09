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

	fmt.Println("[leo.go] Language Emergent Organism v2 — Inner World")
	fmt.Println("[leo.go] The Dario Mechanism + autonomous inner life")

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

	// Start web interface if requested
	if *webPort > 0 {
		webServer = StartWeb(leo, *webPort)
	}

	// REPL
	fmt.Println("[leo.go] REPL ready. type /help for commands.")
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

		// Commands
		if line[0] == '/' {
			switch {
			case line == "/quit" || line == "/exit":
				fmt.Println("[leo.go] saving. resonance unbroken.")
				if webServer != nil {
					webServer.Shutdown()
				}
				leo.Close()
				return
			case line == "/stats":
				leo.Stats()
			case line == "/dream":
				leo.Dream()
				fmt.Println("[leo.go] dreamed.")
			case line == "/save":
				leo.Save()
				fmt.Println("[leo.go] saved.")
			case strings.HasPrefix(line, "/ingest "):
				text := strings.TrimPrefix(line, "/ingest ")
				leo.Ingest(text)
				fmt.Printf("[leo.go] ingested (%d vocab)\n", leo.Vocab())
			case line == "/help":
				fmt.Println("  /stats      — show organism state")
				fmt.Println("  /dream      — run dream cycle")
				fmt.Println("  /save       — save state")
				fmt.Println("  /ingest <t> — feed text into field")
				fmt.Println("  /quit       — save and exit")
			default:
				fmt.Printf("  unknown command: %s\n", line)
			}
			continue
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
