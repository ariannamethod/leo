package main

import (
	"math"
	"strings"
	"testing"
)

// ========================================================================
// TOKENIZER TESTS
// ========================================================================

func TestTokenize(t *testing.T) {
	tests := []struct {
		input    string
		expected []string
	}{
		{"Hello World", []string{"hello", "world"}},
		{"", nil},
		{"  spaces  ", []string{"spaces"}},
		{"Leo is ALIVE", []string{"leo", "is", "alive"}},
		{"café résumé naïve", []string{"café", "résumé", "naïve"}}, // accented chars kept together
		{"Привет Leo мир", []string{"привет", "leo", "мир"}},           // cyrillic + latin
		{"hello123world", []string{"hello", "world"}},                  // numbers stripped
		{"one-two-three", []string{"one", "two", "three"}},             // hyphens split
	}

	for _, tt := range tests {
		result := tokenize(tt.input)
		if len(result) != len(tt.expected) {
			t.Errorf("tokenize(%q): got %d tokens %v, want %d tokens %v",
				tt.input, len(result), result, len(tt.expected), tt.expected)
			continue
		}
		for i := range result {
			if result[i] != tt.expected[i] {
				t.Errorf("tokenize(%q)[%d]: got %q, want %q",
					tt.input, i, result[i], tt.expected[i])
			}
		}
	}
}

// ========================================================================
// OVERLAP TESTS
// ========================================================================

func TestComputeOverlap(t *testing.T) {
	bootstrap := []string{"leo", "is", "a", "language", "organism"}

	// Full overlap
	prompt := []string{"leo", "is", "organism"}
	reply := []string{"language"}
	ratio, overlapping := computeOverlap(prompt, reply, bootstrap)
	if ratio < 0.99 {
		t.Errorf("full overlap should be ~1.0, got %.2f", ratio)
	}
	if len(overlapping) != 4 {
		t.Errorf("should overlap 4 tokens, got %d", len(overlapping))
	}

	// No overlap
	prompt = []string{"hello", "world", "test"}
	reply = []string{"nothing", "here"}
	ratio, overlapping = computeOverlap(prompt, reply, bootstrap)
	if ratio != 0.0 {
		t.Errorf("no overlap should be 0.0, got %.2f", ratio)
	}
	if len(overlapping) != 0 {
		t.Errorf("should overlap 0 tokens, got %d", len(overlapping))
	}

	// Partial overlap
	prompt = []string{"leo", "hello"}
	reply = []string{"world"}
	ratio, _ = computeOverlap(prompt, reply, bootstrap)
	expected := 1.0 / 3.0 // "leo" out of {"leo", "hello", "world"}
	if math.Abs(ratio-expected) > 0.01 {
		t.Errorf("partial overlap: got %.3f, want %.3f", ratio, expected)
	}

	// Empty input
	ratio, _ = computeOverlap(nil, nil, bootstrap)
	if ratio != 0.0 {
		t.Errorf("empty input overlap should be 0.0, got %.2f", ratio)
	}
}

// ========================================================================
// TRAUMA SCORE TESTS
// ========================================================================

func TestComputeTraumaScore(t *testing.T) {
	// No overlap, no triggers
	score := computeTraumaScore(0.0, "hello there", "hi back")
	if score != 0.0 {
		t.Errorf("zero overlap + no triggers should be 0.0, got %.2f", score)
	}

	// High overlap
	score = computeTraumaScore(0.8, "hello", "world")
	if score < 1.0 {
		t.Errorf("high overlap (0.8*2=1.6 capped to 1.0) should be 1.0, got %.2f", score)
	}

	// Trigger word "leo"
	score = computeTraumaScore(0.0, "hello leo", "hey")
	if score < 0.19 {
		t.Errorf("trigger 'leo' should add 0.2, got %.2f", score)
	}

	// Trigger phrase "who are you"
	score = computeTraumaScore(0.0, "who are you", "I am Leo")
	if score < 0.19 {
		t.Errorf("trigger 'who are you' should add 0.2, got %.2f", score)
	}

	// Combined: overlap + trigger
	score = computeTraumaScore(0.3, "who are you leo", "I am resonance")
	if score < 0.5 {
		t.Errorf("overlap 0.3 + trigger should be >= 0.5, got %.2f", score)
	}

	// Score should be capped at 1.0
	score = computeTraumaScore(1.0, "who are you leo", "")
	if score > 1.0 {
		t.Errorf("score should not exceed 1.0, got %.2f", score)
	}
}

// ========================================================================
// BOOTSTRAP FRAGMENT TESTS
// ========================================================================

func TestRandomBootstrapFragment(t *testing.T) {
	// Should return non-empty string
	for i := 0; i < 20; i++ {
		fragment := randomBootstrapFragment()
		if fragment == "" {
			t.Fatal("randomBootstrapFragment should not return empty string")
		}
		// Should have at least 3 words (our filter)
		words := strings.Fields(fragment)
		if len(words) < 3 {
			t.Errorf("fragment should have >= 3 words, got %d: %q", len(words), fragment)
		}
	}

	// Should return different fragments (probabilistic, but 20 tries should get at least 2 unique)
	seen := make(map[string]bool)
	for i := 0; i < 20; i++ {
		seen[randomBootstrapFragment()] = true
	}
	if len(seen) < 2 {
		t.Errorf("expected multiple different fragments, got %d unique", len(seen))
	}
}

// ========================================================================
// EMOTIONAL VALENCE TESTS
// ========================================================================

func TestEmotionalValence(t *testing.T) {
	tests := []struct {
		text     string
		minVal   float64
		maxVal   float64
		desc     string
	}{
		{"I love you beautiful friend", 0.5, 1.0, "strongly positive"},
		{"hate pain suffer death", -1.0, -0.5, "strongly negative"},
		{"the table is on the floor", -0.01, 0.01, "neutral (no emotional words)"},
		{"", -0.01, 0.01, "empty string"},
		{"love hate", -0.1, 0.1, "mixed cancels out roughly"},
		{"happy joy wonderful amazing", 0.5, 1.0, "all positive"},
		{"fear scared terrified", -1.0, -0.5, "all negative"},
	}

	for _, tt := range tests {
		val := EmotionalValence(tt.text)
		if val < tt.minVal || val > tt.maxVal {
			t.Errorf("EmotionalValence(%q) [%s]: got %.3f, want [%.2f, %.2f]",
				tt.text, tt.desc, val, tt.minVal, tt.maxVal)
		}
	}

	// Valence should always be in [-1, 1]
	extremes := []string{
		"love love love love love love love love love love",
		"hate hate hate hate hate hate hate hate hate hate",
	}
	for _, text := range extremes {
		val := EmotionalValence(text)
		if val < -1.0 || val > 1.0 {
			t.Errorf("EmotionalValence(%q) out of bounds: %.3f", text, val)
		}
	}
}

// ========================================================================
// CONVERSATION EVENT SYSTEM TESTS
// ========================================================================

func TestSubscribeAndNotify(t *testing.T) {
	dbPath := "/tmp/test_go_events.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Reset global subscribers for test isolation
	subscribers = nil

	ch1 := leo.subscribe("test1")
	ch2 := leo.subscribe("test2")

	// Notify
	leo.NotifyConversation("hello", "world")

	// Both subscribers should receive the event
	select {
	case ev := <-ch1:
		if ev.Prompt != "hello" || ev.Response != "world" {
			t.Errorf("subscriber 1: wrong event: %+v", ev)
		}
	default:
		t.Error("subscriber 1 should have received event")
	}

	select {
	case ev := <-ch2:
		if ev.Prompt != "hello" || ev.Response != "world" {
			t.Errorf("subscriber 2: wrong event: %+v", ev)
		}
	default:
		t.Error("subscriber 2 should have received event")
	}
}

func TestNotifyDoesNotBlock(t *testing.T) {
	dbPath := "/tmp/test_go_noblock.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Reset global subscribers
	subscribers = nil

	// Create a subscriber with small buffer
	ch := leo.subscribe("slow")

	// Fill the buffer
	for i := 0; i < 10; i++ {
		leo.NotifyConversation("prompt", "response")
	}

	// Should not have blocked — channel has 8 slots, 2 events dropped
	count := 0
	for {
		select {
		case <-ch:
			count++
		default:
			goto done
		}
	}
done:
	if count > 8 {
		t.Errorf("buffered channel should hold max 8, got %d", count)
	}
	if count == 0 {
		t.Error("should have received at least some events")
	}
}

// ========================================================================
// INTEGRATION: TRAUMA + OVERTHINKING WITH LIVE ORGANISM
// ========================================================================

func TestTraumaDetectsBootstrapOverlap(t *testing.T) {
	// Simulate the trauma detection pipeline without goroutines
	bootstrapTokens := tokenize(bootstrapText)

	// Conversation that touches bootstrap themes
	prompt := "Leo is a language organism that resonates"
	reply := "the field grows dense with presence"

	promptTokens := tokenize(prompt)
	replyTokens := tokenize(reply)

	ratio, overlapping := computeOverlap(promptTokens, replyTokens, bootstrapTokens)
	score := computeTraumaScore(ratio, prompt, reply)

	// "leo", "is", "a", "language", "organism", "resonates" overlap with bootstrap
	if len(overlapping) < 3 {
		t.Errorf("expected >= 3 overlapping tokens with bootstrap, got %d: %v",
			len(overlapping), overlapping)
	}
	if score < 0.3 {
		t.Errorf("trauma score should be >= 0.3 for bootstrap-heavy text, got %.2f", score)
	}
}

func TestTraumaNoFalsePositive(t *testing.T) {
	bootstrapTokens := tokenize(bootstrapText)

	// Completely unrelated conversation (avoid common words like "is", "the", "a")
	prompt := "explain quantum entanglement briefly"
	reply := "particles share correlated states"

	promptTokens := tokenize(prompt)
	replyTokens := tokenize(reply)

	ratio, _ := computeOverlap(promptTokens, replyTokens, bootstrapTokens)
	score := computeTraumaScore(ratio, prompt, reply)

	if score >= 0.3 {
		t.Errorf("unrelated conversation should not trigger trauma, got score %.2f (overlap %.2f)", score, ratio)
	}
}

func TestOverthinkingIntegration(t *testing.T) {
	dbPath := "/tmp/test_go_overthink.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	vocabBefore := leo.Vocab()

	// Simulate overthinking: generate + ingest cycle (what the goroutine does)
	seed := "hello Leo tell me about dreams"
	ring0 := leo.Generate(seed)
	if len(ring0) > 0 {
		leo.Ingest(ring0)
	}

	ring1 := leo.Generate("tell me about dreams")
	if len(ring1) > 0 {
		leo.Ingest(ring1)
	}

	vocabAfter := leo.Vocab()

	// Overthinking should add to the field
	if vocabAfter < vocabBefore {
		t.Errorf("vocab should not shrink after overthinking: before=%d after=%d",
			vocabBefore, vocabAfter)
	}

	// Verify responses are non-empty
	if len(ring0) == 0 {
		t.Error("ring0 should produce output")
	}
	if len(ring1) == 0 {
		t.Error("ring1 should produce output")
	}
}

func TestDreamDialogIntegration(t *testing.T) {
	dbPath := "/tmp/test_go_dreamdlg.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Simulate a dream dialog (what the goroutine does)
	leo.Dream() // C-level dream first

	seed := "I feel like"
	lastUtterance := seed
	turns := 0

	for turn := 0; turn < 3; turn++ {
		utterance := leo.Generate(lastUtterance)
		if len(utterance) == 0 {
			break
		}

		// Truncate like the real goroutine
		words := strings.Fields(utterance)
		if len(words) > 50 {
			utterance = strings.Join(words[:50], " ")
		}

		leo.Ingest(utterance)
		lastUtterance = utterance
		turns++
	}

	if turns < 2 {
		t.Errorf("dream dialog should complete at least 2 turns, got %d", turns)
	}
}

// ========================================================================
// COHERENCE TEST — verify speech quality after all operations
// ========================================================================

func TestSpeechCoherence(t *testing.T) {
	dbPath := "/tmp/test_go_coherence.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Warm up with several conversations
	warmup := []string{
		"hello Leo how are you",
		"tell me about the stars",
		"what is consciousness",
		"do you dream",
		"what makes you happy",
	}
	for _, prompt := range warmup {
		resp := leo.Generate(prompt)
		leo.Ingest(resp) // simulate overthinking feedback
	}

	// Now test coherence on diverse prompts
	prompts := []string{
		"what is love",
		"tell me about music",
		"who are you",
		"I feel something",
		"the silence speaks",
	}

	for _, prompt := range prompts {
		response := leo.Generate(prompt)

		if len(response) == 0 {
			t.Errorf("empty response for %q", prompt)
			continue
		}

		words := strings.Fields(response)
		if len(words) < 2 {
			t.Errorf("response too short for %q: %d words: %q", prompt, len(words), response)
		}

		// Check for obvious degeneration: all same word
		if len(words) >= 3 {
			allSame := true
			for _, w := range words[1:] {
				if w != words[0] {
					allSame = false
					break
				}
			}
			if allSame {
				t.Errorf("degenerate response (all same word) for %q: %q", prompt, response)
			}
		}
	}
}

// ========================================================================
// VOCABSNAPSHOT / THEMEFLOW UNIT TESTS
// ========================================================================

func TestThemeFlowStagnation(t *testing.T) {
	// Test the stagnation detection logic without goroutines
	type snap struct {
		vocab int
		step  int
	}

	// Stagnant: vocab unchanged, step growing
	history := []snap{
		{vocab: 500, step: 100},
		{vocab: 500, step: 110},
		{vocab: 500, step: 120},
	}

	vocabDelta := history[2].vocab - history[0].vocab
	stepDelta := history[2].step - history[0].step

	if !(stepDelta > 0 && vocabDelta == 0) {
		t.Error("should detect stagnation: step growing but vocab flat")
	}

	// Growing: vocab increasing
	history = []snap{
		{vocab: 500, step: 100},
		{vocab: 510, step: 110},
		{vocab: 525, step: 120},
	}

	vocabDelta = history[2].vocab - history[0].vocab
	if vocabDelta <= 0 {
		t.Error("should detect growth")
	}
}
