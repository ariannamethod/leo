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

// ========================================================================
// TRAUMA → C BRIDGE TESTS (new: verify trauma reaches dario_compute)
// ========================================================================

func TestTraumaSetGet(t *testing.T) {
	dbPath := "/tmp/test_go_trauma_bridge.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Initially zero
	level := leo.GetTrauma()
	if level != 0.0 {
		t.Errorf("initial trauma should be 0.0, got %.2f", level)
	}

	// Set trauma
	leo.SetTrauma(0.7)
	level = leo.GetTrauma()
	if level < 0.69 || level > 0.71 {
		t.Errorf("trauma should be ~0.7, got %.4f", level)
	}

	// Clamped to [0, 1]
	leo.SetTrauma(5.0)
	level = leo.GetTrauma()
	if level > 1.01 {
		t.Errorf("trauma should be clamped to 1.0, got %.2f", level)
	}

	leo.SetTrauma(-1.0)
	level = leo.GetTrauma()
	if level < -0.01 {
		t.Errorf("trauma should be clamped to 0.0, got %.2f", level)
	}
}

func TestTraumaWeightSetGet(t *testing.T) {
	dbPath := "/tmp/test_go_trauma_weights.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Find a real token ID
	tid := leo.TokenID("leo")
	if tid < 0 {
		t.Skip("token 'leo' not in vocab after bootstrap")
	}

	// Initially zero
	w := leo.GetTraumaWeight(tid)
	if w != 0.0 {
		t.Errorf("initial trauma weight should be 0.0, got %.2f", w)
	}

	// Set weight
	leo.SetTraumaWeight(tid, 1.5)
	w = leo.GetTraumaWeight(tid)
	if w < 1.49 || w > 1.51 {
		t.Errorf("trauma weight should be ~1.5, got %.4f", w)
	}

	// Unknown token returns -1
	tid2 := leo.TokenID("xyzzynonexistent")
	if tid2 != -1 {
		t.Errorf("unknown token should return -1, got %d", tid2)
	}
}

func TestTraumaModulatesGeneration(t *testing.T) {
	// Verify that setting trauma level changes generation behavior.
	// We can't easily test the exact output, but we CAN verify:
	// 1. No crash with high trauma
	// 2. Generation still works
	// 3. With trauma weights set, generation still produces output
	dbPath := "/tmp/test_go_trauma_gen.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Generate baseline response
	resp1 := leo.Generate("who are you")
	if len(resp1) == 0 {
		t.Fatal("baseline generation should not be empty")
	}

	// Set high trauma + scar weights on bootstrap tokens
	leo.SetTrauma(0.9)

	// Set weights on known bootstrap tokens
	for _, word := range []string{"leo", "organism", "resonance", "field", "seed"} {
		tid := leo.TokenID(word)
		if tid >= 0 {
			leo.SetTraumaWeight(tid, 2.0)
		}
	}

	// Generate under trauma — should still work, no crash
	resp2 := leo.Generate("who are you")
	if len(resp2) == 0 {
		t.Fatal("generation under high trauma should not be empty")
	}

	t.Logf("baseline: %q", resp1)
	t.Logf("trauma:   %q", resp2)
}

func TestTraumaFullPipeline(t *testing.T) {
	// Full pipeline: conversation → overlap → score → SetTrauma → SetTraumaWeight → Generate
	dbPath := "/tmp/test_go_trauma_pipeline.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	bootstrapTokens := tokenize(bootstrapText)

	// Simulate a conversation that touches bootstrap themes
	prompt := "Leo is a language organism that resonates with presence"
	response := leo.Generate(prompt)

	// Run the trauma detection pipeline (what startTraumaWatch does)
	promptTokens := tokenize(prompt)
	replyTokens := tokenize(response)

	overlapRatio, overlapping := computeOverlap(promptTokens, replyTokens, bootstrapTokens)
	score := computeTraumaScore(overlapRatio, prompt, response)

	t.Logf("overlap=%.2f score=%.2f overlapping=%v", overlapRatio, score, overlapping)

	if score >= 0.3 {
		// Trauma event — set level
		traumaLevel := 0.5*score + 0.5*0.0 // first event, no prior level
		leo.SetTrauma(float32(traumaLevel))

		// Set per-token weights
		for tok := range overlapping {
			tid := leo.TokenID(tok)
			if tid >= 0 {
				leo.SetTraumaWeight(tid, float32(score))
			}
		}

		// Verify level was set
		got := leo.GetTrauma()
		if got < 0.1 {
			t.Errorf("trauma level should be set after event, got %.2f", got)
		}

		// Generate under trauma
		resp := leo.Generate("tell me about yourself")
		if len(resp) == 0 {
			t.Fatal("generation under trauma should produce output")
		}
		t.Logf("trauma response: %q", resp)
	} else {
		t.Log("no trauma triggered (score < 0.3) — test passes vacuously")
	}
}

// ========================================================================
// MATHBRAIN TESTS — body awareness MLP
// ========================================================================

func TestMathBrainObserve(t *testing.T) {
	dbPath := "/tmp/test_go_mathbrain.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Initially zero observations
	obs := leo.MathBrainObservations()
	if obs != 0 {
		t.Errorf("initial observations should be 0, got %d", obs)
	}

	// Observe a conversation
	leo.MathBrainObserve("hello Leo", "resonance is the key")
	obs = leo.MathBrainObservations()
	if obs != 1 {
		t.Errorf("after one observe, should be 1, got %d", obs)
	}

	// Observe more — loss should be finite
	for i := 0; i < 20; i++ {
		leo.MathBrainObserve("tell me about dreams", "dreams connect distant memories across time")
	}
	obs = leo.MathBrainObservations()
	if obs != 21 {
		t.Errorf("after 21 observations, got %d", obs)
	}

	loss := leo.MathBrainLoss()
	if loss < 0 || loss > 10 {
		t.Errorf("loss should be in reasonable range, got %.4f", loss)
	}
	t.Logf("after 21 obs: loss=%.4f tau_nudge=%.3f", loss, leo.MathBrainTauNudge())
}

func TestMathBrainRegulation(t *testing.T) {
	dbPath := "/tmp/test_go_mathbrain_reg.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Feed many boring conversations (low novelty, low arousal)
	for i := 0; i < 30; i++ {
		leo.MathBrainObserve("hello", "hello")
	}

	nudge := leo.MathBrainTauNudge()
	t.Logf("after boring conversations: tau_nudge=%.3f", nudge)
	// tau_nudge should be bounded
	if nudge < -0.2 || nudge > 0.2 {
		t.Errorf("tau_nudge should be in [-0.2, 0.2], got %.3f", nudge)
	}
}

func TestMathBrainDoesNotCrash(t *testing.T) {
	dbPath := "/tmp/test_go_mathbrain_stress.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Diverse conversations — should never crash or produce NaN
	prompts := []string{
		"WHO ARE YOU?!", // high arousal
		"",             // empty
		"the silence speaks softly in the dark corners of the room where nobody goes anymore",
		"Leo Leo Leo Leo Leo Leo", // trigger words
		"a",                        // minimal
	}
	for _, p := range prompts {
		resp := leo.Generate(p)
		leo.MathBrainObserve(p, resp)
	}

	obs := leo.MathBrainObservations()
	if obs != 5 {
		t.Errorf("expected 5 observations, got %d", obs)
	}

	loss := leo.MathBrainLoss()
	if loss < 0 {
		t.Errorf("loss should not be negative: %.4f", loss)
	}
}

func TestMathBrainWithTrauma(t *testing.T) {
	// MathBrain should work alongside trauma system
	dbPath := "/tmp/test_go_mathbrain_trauma.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Set trauma high
	leo.SetTrauma(0.8)

	// Observe under trauma
	leo.MathBrainObserve("who are you", "resonance organism field")

	// Should detect overwhelm (high trauma)
	nudge := leo.MathBrainTauNudge()
	t.Logf("under trauma: tau_nudge=%.3f (should be negative = cooling)", nudge)

	// Observe normal conversation
	leo.SetTrauma(0.0)
	leo.MathBrainObserve("hello friend", "the sun is warm today")
	nudge2 := leo.MathBrainTauNudge()
	t.Logf("no trauma: tau_nudge=%.3f", nudge2)
}

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
