package main

import (
	"strings"
	"testing"
)

func TestNewLeo(t *testing.T) {
	leo := NewLeo("/tmp/test_go_leo.db")
	defer leo.Close()

	if leo.ptr == nil {
		t.Fatal("Leo pointer should not be nil")
	}
	if !leo.alive {
		t.Fatal("Leo should be alive after creation")
	}
}

func TestBootstrap(t *testing.T) {
	leo := NewLeo("/tmp/test_go_bootstrap.db")
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
	leo := NewLeo("/tmp/test_go_generate.db")
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
	leo := NewLeo("/tmp/test_go_ingest.db")
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
	leo := NewLeo("/tmp/test_go_saveload.db")
	leo.Bootstrap()
	leo.Ingest("testing save and load")
	step1 := leo.Step()
	vocab1 := leo.Vocab()
	leo.Save()
	leo.Close()

	// Reload
	leo2 := NewLeo("/tmp/test_go_saveload.db")
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
	leo := NewLeo("/tmp/test_go_dream.db")
	defer leo.Close()

	leo.Bootstrap()
	leo.Generate("what is resonance")

	// Dream should not panic
	leo.Dream()
}

func TestMultipleGenerations(t *testing.T) {
	leo := NewLeo("/tmp/test_go_multi.db")
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
	if vocab <= 255 {
		t.Fatalf("vocab should grow beyond bootstrap: %d", vocab)
	}
}
