package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const maxRequestBody = 1 << 20 // 1MB limit

type chatRequest struct {
	Message string `json:"message"`
}

type chatResponse struct {
	Response string `json:"response"`
	Step     int    `json:"step"`
	Vocab    int    `json:"vocab"`
}

type statsResponse struct {
	Step  int `json:"step"`
	Vocab int `json:"vocab"`
}

// WebServer wraps http.Server for graceful shutdown
type WebServer struct {
	server *http.Server
}

// cors adds CORS headers for cross-origin requests
func cors(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(200)
			return
		}
		next(w, r)
	}
}

// StartWeb launches HTTP server for the web interface and returns a WebServer for shutdown
func StartWeb(leo *Leo, port int) *WebServer {
	mux := http.NewServeMux()

	// Serve leo.html from project root
	rootDir := ".."
	if _, err := os.Stat(filepath.Join(rootDir, "leo.html")); err != nil {
		rootDir = "."
	}

	// POST /api/chat — send message, get response
	mux.HandleFunc("/api/chat", cors(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST only", 405)
			return
		}

		var req chatRequest
		limited := io.LimitReader(r.Body, maxRequestBody)
		if err := json.NewDecoder(limited).Decode(&req); err != nil {
			http.Error(w, "bad json", 400)
			return
		}

		if len(req.Message) == 0 {
			http.Error(w, "empty message", 400)
			return
		}

		response := leo.Generate(req.Message)

		// Notify inner world goroutines
		leo.NotifyConversation(req.Message, response)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(chatResponse{
			Response: response,
			Step:     leo.Step(),
			Vocab:    leo.Vocab(),
		})
	}))

	// GET /api/stats — organism status
	mux.HandleFunc("/api/stats", cors(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(statsResponse{
			Step:  leo.Step(),
			Vocab: leo.Vocab(),
		})
	}))

	// POST /api/dream — trigger dream cycle
	mux.HandleFunc("/api/dream", cors(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST only", 405)
			return
		}
		leo.Dream()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "dreamed"})
	}))

	// POST /api/ingest — feed text into field
	mux.HandleFunc("/api/ingest", cors(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST only", 405)
			return
		}

		var req struct {
			Text string `json:"text"`
		}
		limited := io.LimitReader(r.Body, maxRequestBody)
		if err := json.NewDecoder(limited).Decode(&req); err != nil {
			http.Error(w, "bad json", 400)
			return
		}

		if len(req.Text) == 0 {
			http.Error(w, "empty text", 400)
			return
		}

		leo.Ingest(req.Text)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status": "ingested",
			"vocab":  leo.Vocab(),
		})
	}))

	// POST /api/save — persist state
	mux.HandleFunc("/api/save", cors(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST only", 405)
			return
		}
		leo.Save()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "saved"})
	}))

	// GET /api/health — liveness check
	mux.HandleFunc("/api/health", cors(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"alive": true,
			"step":  leo.Step(),
			"vocab": leo.Vocab(),
		})
	}))

	// GET / — serve leo.html
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, filepath.Join(rootDir, "leo.html"))
	})

	addr := fmt.Sprintf(":%d", port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
	}

	ws := &WebServer{server: srv}

	fmt.Printf("[web] listening on http://localhost%s\n", addr)
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Fprintf(os.Stderr, "[web] server error: %v\n", err)
		}
	}()

	return ws
}

// Shutdown gracefully stops the web server
func (ws *WebServer) Shutdown() {
	if ws == nil || ws.server == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	ws.server.Shutdown(ctx)
}
