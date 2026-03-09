/*
 * leo.go — Inner World of the Language Emergent Organism
 *
 * Three autonomous goroutines that run continuously:
 *   1. Decay    — memory sea fades, old patterns weaken (every 30s)
 *   2. Dream    — connect distant memories, create new associations (every 5min)
 *   3. Crystallize — scan for super-tokens via PMI (every 2min)
 *
 * Plus: CGO bridge to leo.c, REPL with Go's readline,
 * and the async inner voice that speaks when nobody is talking.
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
	"fmt"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
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

	buf := make([]byte, 4096)
	cBuf := (*C.char)(unsafe.Pointer(&buf[0]))
	C.leo_bridge_generate(l.ptr, cPrompt, cBuf, 4096)

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

// ========================================================================
// INNER WORLD — autonomous goroutines
// ========================================================================

// startDecay — memory sea fades, old patterns weaken
func (l *Leo) startDecay() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-l.stopCh:
			return
		case <-ticker.C:
			l.mu.Lock()
			if l.alive {
				// Decay is implicit in the C code via sea_decay
				// Here we trigger periodic saves and light maintenance
			}
			l.mu.Unlock()
		}
	}
}

// startDream — connect distant memories, forge new associations
func (l *Leo) startDream() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-l.stopCh:
			return
		case <-ticker.C:
			l.Dream()
			fmt.Println("[inner] dreamed...")
		}
	}
}

// startCrystallize — scan for super-token formation via PMI
func (l *Leo) startCrystallize() {
	ticker := time.NewTicker(2 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-l.stopCh:
			return
		case <-ticker.C:
			// Crystallization happens inside C code periodically
			// Here we can trigger extra scans or log progress
			step := l.Step()
			vocab := l.Vocab()
			fmt.Printf("[inner] pulse: step=%d vocab=%d\n", step, vocab)
		}
	}
}

// startInnerVoice — Leo talks to himself when nobody is around
func (l *Leo) startInnerVoice() {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()

	prompts := []string{
		"what am I",
		"I remember",
		"something feels",
		"the resonance",
		"I wonder",
		"in the silence",
	}
	idx := 0

	for {
		select {
		case <-l.stopCh:
			return
		case <-ticker.C:
			prompt := prompts[idx%len(prompts)]
			idx++
			response := l.Generate(prompt)
			if len(response) > 0 {
				fmt.Printf("[inner voice] (%s) %s\n", prompt, response)
			}
		}
	}
}

// StartInnerWorld launches all autonomous goroutines
func (l *Leo) StartInnerWorld() {
	go l.startDecay()
	go l.startDream()
	go l.startCrystallize()
	go l.startInnerVoice()
	fmt.Println("[leo.go] inner world started: decay(30s) dream(5m) crystallize(2m) voice(10m)")
}

// ========================================================================
// MAIN — REPL with inner world
// ========================================================================

func main() {
	dbPath := "leo_state.db"

	// Parse args
	forceBootstrap := false
	webPort := 0
	for i, arg := range os.Args[1:] {
		switch arg {
		case "--db":
			if i+1 < len(os.Args)-1 {
				dbPath = os.Args[i+2]
			}
		case "--bootstrap":
			forceBootstrap = true
		case "--web":
			webPort = 3000
			if i+1 < len(os.Args)-1 {
				if p := os.Args[i+2]; len(p) > 0 && p[0] >= '0' && p[0] <= '9' {
					fmt.Sscanf(p, "%d", &webPort)
				}
			}
		}
	}

	fmt.Println("[leo.go] Language Emergent Organism v2 — Inner World")
	fmt.Println("[leo.go] The Dario Mechanism + autonomous inner life")

	leo := NewLeo(dbPath)

	// Graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\n[leo.go] saving and shutting down...")
		leo.Close()
		os.Exit(0)
	}()

	// Load or bootstrap
	if !forceBootstrap {
		if !leo.Load() {
			leo.Bootstrap()
		}
	} else {
		leo.Bootstrap()
	}

	// Start inner world
	leo.StartInnerWorld()

	// Start web interface if requested
	if webPort > 0 {
		StartWeb(leo, webPort)
	}

	// REPL
	fmt.Println("[leo.go] REPL ready. type /help for commands.")
	fmt.Println()

	scanner := bufio.NewScanner(os.Stdin)
	autosave := 0

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
				leo.Close()
				return
			case line == "/stats":
				leo.Stats()
			case line == "/dream":
				leo.Dream()
			case line == "/save":
				leo.Save()
				fmt.Println("[leo.go] saved.")
			case line == "/help":
				fmt.Println("  /stats   — show organism state")
				fmt.Println("  /dream   — run dream cycle")
				fmt.Println("  /save    — save state")
				fmt.Println("  /quit    — save and exit")
			default:
				fmt.Printf("  unknown command: %s\n", line)
			}
			continue
		}

		// Normal conversation
		response := leo.Generate(line)
		fmt.Printf("\nLeo: %s\n\n", response)

		autosave++
		if autosave%20 == 0 {
			leo.Save()
			fmt.Printf("[leo.go] autosaved (step %d)\n", leo.Step())
		}
	}

	leo.Close()
}
