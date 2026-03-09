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

func TestSQLiteJournal(t *testing.T) {
	dbPath := "/tmp/test_go_sqlite.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()

	// After bootstrap, there should be a bootstrap episode
	epCount := leo.EpisodeCount("bootstrap")
	if epCount < 1 {
		t.Fatalf("expected at least 1 bootstrap episode, got %d", epCount)
	}

	// Generate a conversation — it should be logged
	convsBefore := leo.ConversationCount()
	leo.Generate("hello Leo how are you")
	convsAfter := leo.ConversationCount()

	if convsAfter <= convsBefore {
		t.Fatalf("conversation count should increase after Generate: before=%d after=%d",
			convsBefore, convsAfter)
	}

	// Manual episode logging
	leo.LogEpisode("test", "test content", "{\"key\":\"value\"}")
	testEps := leo.EpisodeCount("test")
	if testEps != 1 {
		t.Fatalf("expected 1 test episode, got %d", testEps)
	}

	// Total episodes should be > 0
	totalEps := leo.EpisodeCount("")
	if totalEps < 2 {
		t.Fatalf("expected at least 2 total episodes, got %d", totalEps)
	}
}

func TestGGUFExportImport(t *testing.T) {
	dbPath := "/tmp/test_go_gguf.db"
	ggufPath := "/tmp/test_leo_spore.gguf"
	cleanupDB(t, dbPath)
	t.Cleanup(func() { os.Remove(ggufPath) })

	// Create and bootstrap organism
	leo := NewLeo(dbPath)
	leo.Bootstrap()
	leo.Generate("resonance is the key to everything")
	leo.Generate("dreams connect distant memories")
	stepBefore := leo.Step()
	vocabBefore := leo.Vocab()

	// Export GGUF spore
	leo.ExportGGUF(ggufPath)
	leo.Close()

	// Verify file exists and has reasonable size
	info, err := os.Stat(ggufPath)
	if err != nil {
		t.Fatalf("GGUF file not created: %v", err)
	}
	if info.Size() < 1024 {
		t.Fatalf("GGUF file too small: %d bytes", info.Size())
	}

	// Import into fresh organism
	dbPath2 := "/tmp/test_go_gguf_import.db"
	cleanupDB(t, dbPath2)
	leo2 := NewLeo(dbPath2)
	defer leo2.Close()

	if !leo2.ImportGGUF(ggufPath) {
		t.Fatal("GGUF import failed")
	}

	stepAfter := leo2.Step()
	if stepAfter != stepBefore {
		t.Fatalf("step mismatch after import: exported=%d imported=%d", stepBefore, stepAfter)
	}

	// The imported organism should be able to generate
	response := leo2.Generate("tell me about resonance")
	if len(response) == 0 {
		t.Fatal("imported organism should be able to generate")
	}

	t.Logf("export: step=%d vocab=%d, import: step=%d, file=%d bytes",
		stepBefore, vocabBefore, stepAfter, info.Size())
}

func TestSQLitePersistsAcrossRestart(t *testing.T) {
	dbPath := "/tmp/test_go_sqlite_persist.db"
	cleanupDB(t, dbPath)

	// Session 1: create and have conversations
	leo := NewLeo(dbPath)
	leo.Bootstrap()
	leo.Generate("first conversation")
	leo.Generate("second conversation")
	leo.Save()
	count1 := leo.ConversationCount()
	leo.Close()

	// Session 2: conversations should still be there
	leo2 := NewLeo(dbPath)
	leo2.Load()
	count2 := leo2.ConversationCount()
	leo2.Close()

	if count2 != count1 {
		t.Fatalf("conversation count should persist: session1=%d session2=%d", count1, count2)
	}
	if count2 < 2 {
		t.Fatalf("expected at least 2 conversations, got %d", count2)
	}
}

func TestGGUFRoundtripGenerationQuality(t *testing.T) {
	dbPath := "/tmp/test_go_gguf_quality.db"
	ggufPath := "/tmp/test_leo_quality.gguf"
	cleanupDB(t, dbPath)
	t.Cleanup(func() { os.Remove(ggufPath) })

	// Train organism with specific content
	leo := NewLeo(dbPath)
	leo.Bootstrap()
	for i := 0; i < 5; i++ {
		leo.Ingest("resonance is the fundamental mechanism of understanding")
		leo.Ingest("dreams connect distant memories across time")
	}
	leo.Generate("what is resonance")
	leo.ExportGGUF(ggufPath)
	leo.Close()

	// Import and verify the organism can still generate coherently
	dbPath2 := "/tmp/test_go_gguf_quality_import.db"
	cleanupDB(t, dbPath2)
	leo2 := NewLeo(dbPath2)
	defer leo2.Close()

	if !leo2.ImportGGUF(ggufPath) {
		t.Fatal("import failed")
	}

	// Generate should produce non-empty response
	resp := leo2.Generate("resonance")
	if len(resp) == 0 {
		t.Fatal("imported organism should generate from trained content")
	}
	t.Logf("imported organism response: %q", resp)
}

func TestSQLiteEpisodeTypes(t *testing.T) {
	dbPath := "/tmp/test_go_episode_types.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()

	// Log different episode types
	leo.LogEpisode("dream", "dreamed of distant stars", "{\"turns\":3}")
	leo.LogEpisode("dream", "dreamed of the ocean", "{\"turns\":4}")
	leo.LogEpisode("trauma", "origin gravity pull", "{\"score\":0.5}")
	leo.LogEpisode("overthink", "ring 0 echo", "{}")
	leo.LogEpisode("ingest", "fed new text", "{\"lines\":10}")

	// Verify counts per type
	if n := leo.EpisodeCount("dream"); n != 2 {
		t.Fatalf("expected 2 dream episodes, got %d", n)
	}
	if n := leo.EpisodeCount("trauma"); n != 1 {
		t.Fatalf("expected 1 trauma episode, got %d", n)
	}
	if n := leo.EpisodeCount("overthink"); n != 1 {
		t.Fatalf("expected 1 overthink episode, got %d", n)
	}
	if n := leo.EpisodeCount("ingest"); n != 1 {
		t.Fatalf("expected 1 ingest episode, got %d", n)
	}

	// Total should be 5 + 1 (bootstrap)
	total := leo.EpisodeCount("")
	if total < 6 {
		t.Fatalf("expected at least 6 total episodes, got %d", total)
	}
}

func TestGGUFExportLogsEpisode(t *testing.T) {
	dbPath := "/tmp/test_go_gguf_episode.db"
	ggufPath := "/tmp/test_leo_ep.gguf"
	cleanupDB(t, dbPath)
	t.Cleanup(func() { os.Remove(ggufPath) })

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()

	exportsBefore := leo.EpisodeCount("gguf_export")
	leo.ExportGGUF(ggufPath)
	exportsAfter := leo.EpisodeCount("gguf_export")

	if exportsAfter != exportsBefore+1 {
		t.Fatalf("export should log episode: before=%d after=%d", exportsBefore, exportsAfter)
	}
}

func TestDreamLogsEpisode(t *testing.T) {
	dbPath := "/tmp/test_go_dream_ep.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()

	leo.Bootstrap()
	// Need some conversations for sea memories
	leo.Generate("the ocean is deep and vast")
	leo.Generate("dreams connect memories across time")
	leo.Generate("the stars are ancient light")

	dreamsBefore := leo.EpisodeCount("dream")
	leo.Dream()
	dreamsAfter := leo.EpisodeCount("dream")

	if dreamsAfter != dreamsBefore+1 {
		t.Fatalf("dream should log episode: before=%d after=%d", dreamsBefore, dreamsAfter)
	}
}

func TestMultiSessionJournal(t *testing.T) {
	dbPath := "/tmp/test_go_multisession.db"
	cleanupDB(t, dbPath)

	// Session 1
	leo := NewLeo(dbPath)
	leo.Bootstrap()
	leo.Generate("session one greeting")
	leo.Generate("session one question")
	leo.Save()
	leo.Close()

	// Session 2
	leo2 := NewLeo(dbPath)
	leo2.Load()
	leo2.Generate("session two begins")
	leo2.Generate("session two continues")
	leo2.Generate("session two ends")
	leo2.Save()
	convs := leo2.ConversationCount()
	leo2.Close()

	// Should have all 5 conversations across sessions
	if convs < 5 {
		t.Fatalf("expected at least 5 conversations across 2 sessions, got %d", convs)
	}

	// Session 3: verify count persists
	leo3 := NewLeo(dbPath)
	leo3.Load()
	convs3 := leo3.ConversationCount()
	leo3.Close()

	if convs3 != convs {
		t.Fatalf("conversation count should persist: session2=%d session3=%d", convs, convs3)
	}
}
