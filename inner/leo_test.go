package main

import (
	"os"
	"strings"
	"testing"
)

// cleanupDB removes test database files (including WAL/SHM/journal)
func cleanupDB(t *testing.T, path string) {
	t.Helper()
	t.Cleanup(func() {
		for _, suffix := range []string{"", "-journal", "-wal", "-shm", ".state"} {
			os.Remove(path + suffix)
		}
	})
}

func TestNewLeo(t *testing.T) {
	dbPath := "/tmp/test_go_leo.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	if leo.ptr == nil {
		t.Fatal("Leo pointer should not be nil")
	}
	if !leo.alive {
		t.Fatal("Leo should be alive after creation")
	}
}

func TestBootstrap(t *testing.T) {
	dbPath := "/tmp/test_go_bootstrap.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()

	vocab := leo.Vocab()
	if vocab < 100 {
		t.Fatalf("vocab should be >100 after bootstrap, got %d", vocab)
	}

	step := leo.Step()
	if step < 100 {
		t.Fatalf("step should be >100 after bootstrap, got %d", step)
	}
}

func TestGenerate(t *testing.T) {
	dbPath := "/tmp/test_go_generate.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()
	response := leo.Generate("hello Leo")

	if len(response) == 0 {
		t.Fatal("response should not be empty")
	}

	words := strings.Fields(response)
	if len(words) < 2 {
		t.Fatalf("response should have at least 2 words, got %d: %q", len(words), response)
	}
}

func TestIngest(t *testing.T) {
	dbPath := "/tmp/test_go_ingest.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()
	vocabBefore := leo.Vocab()

	leo.Ingest("extraordinary magnificent unprecedented spectacular")

	vocabAfter := leo.Vocab()
	if vocabAfter <= vocabBefore {
		t.Fatalf("vocab should grow after ingest: before=%d after=%d", vocabBefore, vocabAfter)
	}
}

func TestSaveLoad(t *testing.T) {
	dbPath := "/tmp/test_go_saveload.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	leo.Bootstrap()
	leo.Ingest("testing save and load")
	step1 := leo.Step()
	vocab1 := leo.Vocab()
	leo.Save()
	leo.Close()

	// Reload
	leo2 := NewLeo(dbPath)
	if !leo2.Load() {
		t.Fatal("load should succeed")
	}

	step2 := leo2.Step()
	vocab2 := leo2.Vocab()

	if step2 != step1 {
		t.Fatalf("step should be preserved: %d != %d", step2, step1)
	}
	if vocab2 != vocab1 {
		t.Fatalf("vocab should be preserved: %d != %d", vocab2, vocab1)
	}

	leo2.Close()
}

func TestDream(t *testing.T) {
	dbPath := "/tmp/test_go_dream.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()
	leo.Generate("what is resonance")

	// Dream should not panic
	leo.Dream()
}

func TestMultipleGenerations(t *testing.T) {
	dbPath := "/tmp/test_go_multi.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()

	prompts := []string{
		"hello Leo",
		"tell me about dreams",
		"what is resonance",
		"I believe in miracles",
	}

	for _, prompt := range prompts {
		response := leo.Generate(prompt)
		if len(response) == 0 {
			t.Fatalf("empty response for prompt %q", prompt)
		}
	}

	vocab := leo.Vocab()
	if vocab < 100 {
		t.Fatalf("vocab should be substantial after bootstrap + conversations: %d", vocab)
	}
}
