package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
)

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

// StartWeb launches HTTP server for the web interface
func StartWeb(leo *Leo, port int) {
	// Serve leo.html from project root
	rootDir := ".."
	if _, err := os.Stat(filepath.Join(rootDir, "leo.html")); err != nil {
		rootDir = "."
	}

	// POST /api/chat — send message, get response
	http.HandleFunc("/api/chat", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST only", 405)
			return
		}

		var req chatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad json", 400)
			return
		}

		response := leo.Generate(req.Message)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(chatResponse{
			Response: response,
			Step:     leo.Step(),
			Vocab:    leo.Vocab(),
		})
	})

	// GET /api/stats — organism status
	http.HandleFunc("/api/stats", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(statsResponse{
			Step:  leo.Step(),
			Vocab: leo.Vocab(),
		})
	})

	// POST /api/dream — trigger dream cycle
	http.HandleFunc("/api/dream", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST only", 405)
			return
		}
		leo.Dream()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "dreamed"})
	})

	// GET / — serve leo.html
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, filepath.Join(rootDir, "leo.html"))
	})

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("[web] listening on http://localhost%s\n", addr)
	go http.ListenAndServe(addr, nil)
}
