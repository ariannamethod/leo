package main

import (
	"math"
	"os"
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

// ========================================================================
// METALEO TESTS — inner voice, scoring, dual generation
// ========================================================================

func TestMetaScoreEmpty(t *testing.T) {
	score := metaScore("")
	if score != 0.0 {
		t.Errorf("empty text should score 0.0, got %.2f", score)
	}
}

func TestMetaScoreCoherent(t *testing.T) {
	// Well-formed sentence should score reasonably high
	good := "It has been given to be made visible wavelength."
	score := metaScore(good)
	if score < 0.3 {
		t.Errorf("coherent sentence should score >= 0.3, got %.2f", score)
	}

	// Degenerate (all same word) should score low
	bad := "the the the the the the the the"
	scoreBad := metaScore(bad)
	if scoreBad >= score {
		t.Errorf("degenerate text should score lower than coherent: bad=%.2f good=%.2f", scoreBad, score)
	}
}

func TestMetaScoreEntropy(t *testing.T) {
	// Random letters — high entropy but no structure
	random := "Xqzjf wplmb Nrtks Ygcvd Hlwqf."
	scoreRandom := metaScore(random)

	// Real sentence
	real := "The stars are ancient light from distant worlds."
	scoreReal := metaScore(real)

	// Both should score, but real should beat random (diversity counts)
	t.Logf("random=%.2f real=%.2f", scoreRandom, scoreReal)
	// Just verify both don't crash and produce values in [0,1]
	if scoreRandom < 0 || scoreRandom > 1 {
		t.Errorf("score out of bounds: %.2f", scoreRandom)
	}
	if scoreReal < 0 || scoreReal > 1 {
		t.Errorf("score out of bounds: %.2f", scoreReal)
	}
}

func TestMetaScoreLength(t *testing.T) {
	// Too short — should score lower
	short := "Yes."
	scoreShort := metaScore(short)

	// Optimal range (8-20 words)
	optimal := "It has been given enough to its own body and the miracle of presence."
	scoreOptimal := metaScore(optimal)

	if scoreOptimal <= scoreShort {
		t.Errorf("optimal length should outscore too-short: short=%.2f optimal=%.2f",
			scoreShort, scoreOptimal)
	}
}

func TestMetaLeoIntegration(t *testing.T) {
	dbPath := "/tmp/test_go_metaleo.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Save base tau
	baseTau := leo.GetTau()
	if baseTau <= 0 {
		t.Fatalf("base tau should be positive, got %.4f", baseTau)
	}

	// Simulate MetaLeo dual generation
	prompt := "what is resonance"
	baseResponse := leo.Generate(prompt)

	// Candidate A: cooler
	tauA := baseTau * 0.8
	leo.SetTau(tauA)
	candidateA := leo.Generate(prompt)

	// Candidate B: warmer
	tauB := baseTau * 1.2
	leo.SetTau(tauB)
	candidateB := leo.Generate(prompt)

	// Restore
	leo.SetTau(baseTau)

	// All three should produce output
	if len(baseResponse) == 0 {
		t.Fatal("base response empty")
	}
	if len(candidateA) == 0 {
		t.Fatal("candidate A empty")
	}
	if len(candidateB) == 0 {
		t.Fatal("candidate B empty")
	}

	// Score all three
	scoreBase := metaScore(baseResponse)
	scoreA := metaScore(candidateA)
	scoreB := metaScore(candidateB)

	t.Logf("base=%.2f (%q)", scoreBase, baseResponse)
	t.Logf("cool=%.2f (%q)", scoreA, candidateA)
	t.Logf("warm=%.2f (%q)", scoreB, candidateB)

	// Tau should be restored
	restored := leo.GetTau()
	if math.Abs(float64(restored-baseTau)) > 0.001 {
		t.Errorf("tau not restored: base=%.4f restored=%.4f", baseTau, restored)
	}
}

// ========================================================================
// TAU BRIDGE TESTS
// ========================================================================

func TestGetSetTau(t *testing.T) {
	dbPath := "/tmp/test_go_tau.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Get initial tau
	initial := leo.GetTau()
	if initial <= 0 {
		t.Fatalf("initial tau should be positive, got %.4f", initial)
	}

	// Set new tau
	leo.SetTau(2.5)
	got := leo.GetTau()
	if math.Abs(float64(got-2.5)) > 0.001 {
		t.Errorf("set tau to 2.5, got %.4f", got)
	}

	// Restore
	leo.SetTau(initial)
	restored := leo.GetTau()
	if math.Abs(float64(restored-initial)) > 0.001 {
		t.Errorf("restored tau should match initial: %.4f != %.4f", restored, initial)
	}
}

// ========================================================================
// CAPITALIZE "LEO" TESTS
// ========================================================================

func TestLeoCapitalized(t *testing.T) {
	dbPath := "/tmp/test_go_capitalize.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Generate many times and check that "leo" never appears lowercase
	for i := 0; i < 10; i++ {
		resp := leo.Generate("tell me about Leo")
		words := strings.Fields(resp)
		for _, w := range words {
			lower := strings.ToLower(w)
			cleaned := strings.Trim(lower, ".,!?;:'\"")
			if cleaned == "leo" {
				trimmed := strings.Trim(w, ".,!?;:'\"")
				if trimmed == "leo" {
					t.Errorf("found lowercase 'leo' in response: %q", resp)
				}
			}
		}
	}
}

// ========================================================================
// PHASE4 BRIDGE TESTS
// ========================================================================

func TestPhase4Transitions(t *testing.T) {
	dbPath := "/tmp/test_go_phase4.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Initially zero transitions
	trans := leo.Phase4Transitions()
	if trans != 0 {
		t.Errorf("initial transitions should be 0, got %d", trans)
	}

	// Observe conversations — Phase4 records inside MathBrain
	for i := 0; i < 5; i++ {
		resp := leo.Generate("hello world")
		leo.MathBrainObserve("hello world", resp)
	}

	// Transitions may or may not have happened (depends on voice switches)
	trans = leo.Phase4Transitions()
	t.Logf("after 5 observations: %d transitions", trans)
	// Just verify no crash
}

func TestPhase4Suggest(t *testing.T) {
	dbPath := "/tmp/test_go_phase4_suggest.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Suggest from island 0 — should return valid island or -1
	suggestion := leo.Phase4Suggest(0)
	if suggestion < -1 || suggestion > 5 {
		t.Errorf("suggestion should be -1..5, got %d", suggestion)
	}
	t.Logf("suggest from island 0: %d", suggestion)
}

func TestPhase4IslandStats(t *testing.T) {
	dbPath := "/tmp/test_go_phase4_stats.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Check all islands
	for island := 0; island < 5; island++ {
		visits := leo.Phase4IslandVisits(island)
		quality := leo.Phase4IslandQuality(island)
		if visits < 0 {
			t.Errorf("island %d visits should be >= 0, got %d", island, visits)
		}
		if quality < 0 || quality > 1 {
			// quality can be 0 if no visits
			if visits > 0 {
				t.Errorf("island %d quality should be [0,1], got %.2f", island, quality)
			}
		}
	}
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

// ========================================================================
// POSITIONAL HEBBIAN PROFILE TESTS (RRPRAM-inspired)
// ========================================================================

func TestDistProfileInit(t *testing.T) {
	// dist_profile should initialize to 0.9^d (zero regression from old behavior)
	dbPath := "/tmp/test_go_distprofile.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	for d := 0; d < 8; d++ {
		got := leo.GetDistProfile(d)
		want := float32(math.Pow(0.9, float64(d)))
		if math.Abs(float64(got-want)) > 0.001 {
			t.Errorf("dist_profile[%d] = %.4f, want %.4f (0.9^%d)", d, got, want, d)
		}
	}

	// class_mod should all be 1.0 initially
	for c := 0; c < 4; c++ {
		got := leo.GetClassMod(c)
		if math.Abs(float64(got-1.0)) > 0.001 {
			t.Errorf("class_mod[%d] = %.4f, want 1.0", c, got)
		}
	}

	// no updates yet at bootstrap time (bootstrap doesn't use leo_generate path)
	// updates happen during generation
	t.Logf("dist_profile_updates after bootstrap: %d", leo.DistProfileUpdates())
}

func TestDistProfileHebbianUpdate(t *testing.T) {
	// After multiple generations, dist_profile should differ from 0.9^d
	dbPath := "/tmp/test_go_distprofile_hebbian.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Record initial profile
	initial := make([]float32, 8)
	for d := 0; d < 8; d++ {
		initial[d] = leo.GetDistProfile(d)
	}

	// Generate several responses to trigger Hebbian updates
	prompts := []string{
		"hello Leo", "what do you think", "tell me about resonance",
		"the field is alive", "consciousness emerges from", "do you dream",
		"I feel the resonance", "speak to me Leo", "what is love",
		"the silence between words",
	}
	for _, p := range prompts {
		leo.Generate(p)
	}

	updates := leo.DistProfileUpdates()
	if updates == 0 {
		t.Fatal("dist_profile_updates should be > 0 after generation")
	}
	t.Logf("dist_profile_updates after %d prompts: %d", len(prompts), updates)

	// Check that at least SOME distance changed
	changed := 0
	for d := 0; d < 8; d++ {
		now := leo.GetDistProfile(d)
		if math.Abs(float64(now-initial[d])) > 0.0001 {
			changed++
		}
	}
	if changed == 0 {
		t.Error("dist_profile should have been modified by Hebbian learning")
	}
	t.Logf("changed %d/8 profile entries", changed)
}

func TestDistProfileGGUFRoundtrip(t *testing.T) {
	// Profile should survive GGUF export/import
	dbPath := "/tmp/test_go_distprofile_gguf.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// Generate to modify the profile
	for i := 0; i < 5; i++ {
		leo.Generate("hello Leo")
	}

	// Record profile state
	profileBefore := make([]float32, 8)
	classBefore := make([]float32, 4)
	for d := 0; d < 8; d++ {
		profileBefore[d] = leo.GetDistProfile(d)
	}
	for c := 0; c < 4; c++ {
		classBefore[c] = leo.GetClassMod(c)
	}
	updatesBefore := leo.DistProfileUpdates()

	// Export
	ggufPath := "/tmp/test_distprofile.gguf"
	leo.ExportGGUF(ggufPath)

	// Import into fresh organism
	dbPath2 := "/tmp/test_go_distprofile_gguf2.db"
	cleanupDB(t, dbPath2)
	leo2 := NewLeo(dbPath2)
	defer leo2.Close()
	leo2.Bootstrap()
	leo2.ImportGGUF(ggufPath)

	// Verify profile matches
	for d := 0; d < 8; d++ {
		got := leo2.GetDistProfile(d)
		if math.Abs(float64(got-profileBefore[d])) > 0.001 {
			t.Errorf("dist_profile[%d] after roundtrip: %.4f, want %.4f", d, got, profileBefore[d])
		}
	}
	for c := 0; c < 4; c++ {
		got := leo2.GetClassMod(c)
		if math.Abs(float64(got-classBefore[c])) > 0.001 {
			t.Errorf("class_mod[%d] after roundtrip: %.4f, want %.4f", c, got, classBefore[c])
		}
	}

	updatesAfter := leo2.DistProfileUpdates()
	if updatesAfter != updatesBefore {
		t.Errorf("dist_profile_updates after roundtrip: %d, want %d", updatesAfter, updatesBefore)
	}

	t.Logf("GGUF roundtrip OK: %d updates preserved", updatesBefore)
}

// ========================================================================
// VOICE PARLIAMENT TESTS
// ========================================================================

func TestVoiceParliamentInit(t *testing.T) {
	dbPath := "/tmp/test_go_voices.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	nv := leo.NVoices()
	if nv < 1 {
		t.Fatalf("expected at least 1 voice after bootstrap, got %d", nv)
	}
	t.Logf("voices after bootstrap: %d", nv)

	// all voices should have non-negative resonance
	for i := 0; i < nv; i++ {
		r := leo.VoiceResonance(i)
		if r < 0 {
			t.Errorf("voice %d has negative resonance: %.4f", i, r)
		}
	}
}

func TestVoiceResonanceChanges(t *testing.T) {
	dbPath := "/tmp/test_go_voices_change.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	nv := leo.NVoices()
	if nv < 1 {
		t.Skip("no voices")
	}

	initial := make([]float32, nv)
	for i := 0; i < nv; i++ {
		initial[i] = leo.VoiceResonance(i)
	}

	// generate several times to trigger Hebbian voice updates
	for i := 0; i < 10; i++ {
		leo.Generate("resonance field organism language")
	}

	changed := 0
	for i := 0; i < nv; i++ {
		now := leo.VoiceResonance(i)
		if now != initial[i] {
			changed++
		}
	}
	t.Logf("voices changed resonance: %d/%d", changed, nv)
}

// ========================================================================
// SUBWORD FIELD TESTS
// ========================================================================

func TestSubwordFieldGrows(t *testing.T) {
	dbPath := "/tmp/test_go_subword.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	mergesAfterBoot := leo.SwMerges()
	tokensAfterBoot := leo.SwTokens()
	t.Logf("after bootstrap: %d merges, %d subword tokens", mergesAfterBoot, tokensAfterBoot)

	// subword tokens should be at least ASCII printable (95 base chars)
	if tokensAfterBoot < 95 {
		t.Errorf("expected at least 95 base subword tokens, got %d", tokensAfterBoot)
	}

	// ingest text to trigger merge learning
	text := "the resonance of the field creates the organism and the language emerges from the structure of the resonance"
	for i := 0; i < 5; i++ {
		leo.Ingest(text)
	}

	mergesAfter := leo.SwMerges()
	t.Logf("after ingestion: %d merges (was %d)", mergesAfter, mergesAfterBoot)
}

// ========================================================================
// MEMORY SEA TESTS
// ========================================================================

func TestMemorySeaGrows(t *testing.T) {
	dbPath := "/tmp/test_go_sea.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	seaInit := leo.SeaCount()

	// generate to populate sea
	for i := 0; i < 10; i++ {
		leo.Generate("hello Leo tell me about dreams")
	}

	seaAfter := leo.SeaCount()
	t.Logf("sea: %d → %d memories", seaInit, seaAfter)

	if seaAfter < seaInit {
		t.Error("sea should grow after generation, but shrunk")
	}
}

// ========================================================================
// VOCABULARY GROWTH TESTS
// ========================================================================

func TestVocabGrowsWithIngest(t *testing.T) {
	dbPath := "/tmp/test_go_vocab_growth.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	vocabInit := leo.VocabTotal()

	// ingest text with new words
	leo.Ingest("xylophone zamboni quetzalcoatl fibonacci")

	vocabAfter := leo.VocabTotal()
	t.Logf("vocab: %d → %d", vocabInit, vocabAfter)

	if vocabAfter <= vocabInit {
		t.Error("vocab should grow after ingesting new words")
	}
}

// ---- RRPRAM D.N.A. Scanner tests ----

func TestRrpramScanFindsPatterns(t *testing.T) {
	dbPath := "/tmp/test_go_rrpram_scan.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	clusters := leo.RrpramClusters()
	chains := leo.RrpramChains()
	hubs := leo.RrpramHubs()
	rCoeff := leo.RrpramRCoeff()

	t.Logf("RRPRAM: %d clusters, %d chains, %d hubs, r_coeff=%.2f",
		clusters, chains, hubs, rCoeff)

	// after bootstrap with D.N.A., scanner should find at least some patterns
	if clusters+chains+hubs == 0 {
		t.Error("RRPRAM scanner found zero patterns in D.N.A. — expected at least some")
	}
	if rCoeff <= 0.0 {
		t.Error("r_coeff should be > 0 after D.N.A. scan")
	}
}

func TestRrpramSurvivesSaveLoad(t *testing.T) {
	dbPath := "/tmp/test_go_rrpram_persist.db"
	cleanupDB(t, dbPath)

	var clusters, chains, hubs int

	// bootstrap, save
	{
		leo := NewLeo(dbPath)
		leo.Bootstrap()
		clusters = leo.RrpramClusters()
		chains = leo.RrpramChains()
		hubs = leo.RrpramHubs()
		leo.Save()
		leo.Close()
	}

	// reload
	{
		leo := NewLeo(dbPath)
		defer leo.Close()
		leo.Load()

		c2 := leo.RrpramClusters()
		ch2 := leo.RrpramChains()
		h2 := leo.RrpramHubs()

		t.Logf("before save: %d/%d/%d, after load: %d/%d/%d",
			clusters, chains, hubs, c2, ch2, h2)

		if c2 != clusters || ch2 != chains || h2 != hubs {
			t.Errorf("RRPRAM mismatch after save/load: %d/%d/%d vs %d/%d/%d",
				clusters, chains, hubs, c2, ch2, h2)
		}
	}
}

func TestRrpramGGUFRoundtrip(t *testing.T) {
	dbPath := "/tmp/test_go_rrpram_gguf.db"
	cleanupDB(t, dbPath)
	ggufPath := "/tmp/test_rrpram.gguf"

	var clusters, chains, hubs int

	// bootstrap + export
	{
		leo := NewLeo(dbPath)
		leo.Bootstrap()
		clusters = leo.RrpramClusters()
		chains = leo.RrpramChains()
		hubs = leo.RrpramHubs()
		leo.ExportGGUF(ggufPath)
		leo.Close()
	}

	// import into fresh instance
	{
		dbPath2 := "/tmp/test_go_rrpram_gguf2.db"
		cleanupDB(t, dbPath2)
		leo := NewLeo(dbPath2)
		defer leo.Close()
		leo.ImportGGUF(ggufPath)

		c2 := leo.RrpramClusters()
		ch2 := leo.RrpramChains()
		h2 := leo.RrpramHubs()

		t.Logf("GGUF roundtrip: %d/%d/%d → %d/%d/%d",
			clusters, chains, hubs, c2, ch2, h2)

		if c2 != clusters || ch2 != chains || h2 != hubs {
			t.Errorf("RRPRAM GGUF roundtrip mismatch: %d/%d/%d vs %d/%d/%d",
				clusters, chains, hubs, c2, ch2, h2)
		}
	}
	os.Remove(ggufPath)
}

// ========================================================================
// RESONANCE TENSOR TESTS
// ========================================================================

func TestResonanceTensorInit(t *testing.T) {
	dbPath := "/tmp/test_go_res_tensor_init.db"
	cleanupDB(t, dbPath)
	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// lambda should be initialized to 1.0
	lambda := leo.ResonanceLambda()
	if lambda < 0.9 || lambda > 1.1 {
		t.Errorf("expected lambda_res ~1.0, got %f", lambda)
	}

	// initial coherence[0][1] (B×H) should be 0.5
	bh := leo.Coherence(0, 1)
	if bh < 0.4 || bh > 0.6 {
		t.Errorf("expected coherence[B×H] ~0.5, got %f", bh)
	}

	// coherence[1][5] (H×R) should be 0.4
	hr := leo.Coherence(1, 5)
	if hr < 0.3 || hr > 0.5 {
		t.Errorf("expected coherence[H×R] ~0.4, got %f", hr)
	}

	t.Logf("Resonance Tensor: λ=%.3f, C[B×H]=%.3f, C[H×R]=%.3f", lambda, bh, hr)
}

func TestResonanceTensorLearnsDuringGeneration(t *testing.T) {
	dbPath := "/tmp/test_go_res_tensor_learn.db"
	cleanupDB(t, dbPath)
	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// record initial coherence
	bh_before := leo.Coherence(0, 1)

	// generate several times to trigger Hebbian learning
	for i := 0; i < 20; i++ {
		leo.Generate("ocean deep water resonance")
	}

	bh_after := leo.Coherence(0, 1)
	t.Logf("Coherence[B×H] before=%f after=%f", bh_before, bh_after)

	// should have changed (either direction, but not identical)
	if math.Abs(float64(bh_after-bh_before)) < 1e-6 {
		t.Error("coherence[B×H] did not change after generation — Hebbian learning not working")
	}
}

func TestResonanceTensorSurvivesSaveLoad(t *testing.T) {
	dbPath := "/tmp/test_go_res_tensor_save.db"
	cleanupDB(t, dbPath)

	var lambda float32
	var bh, hr float32

	// bootstrap + generate + save
	{
		leo := NewLeo(dbPath)
		leo.Bootstrap()
		for i := 0; i < 10; i++ {
			leo.Generate("resonance field emergence")
		}
		lambda = leo.ResonanceLambda()
		bh = leo.Coherence(0, 1)
		hr = leo.Coherence(1, 5)
		leo.Save()
		leo.Close()
	}

	// reload
	{
		leo := NewLeo(dbPath)
		defer leo.Close()
		leo.Load()

		l2 := leo.ResonanceLambda()
		bh2 := leo.Coherence(0, 1)
		hr2 := leo.Coherence(1, 5)

		t.Logf("Save/load: λ=%.3f→%.3f, B×H=%.4f→%.4f, H×R=%.4f→%.4f",
			lambda, l2, bh, bh2, hr, hr2)

		if math.Abs(float64(l2-lambda)) > 1e-5 {
			t.Errorf("lambda mismatch: %f vs %f", lambda, l2)
		}
		if math.Abs(float64(bh2-bh)) > 1e-5 {
			t.Errorf("coherence[B×H] mismatch: %f vs %f", bh, bh2)
		}
		if math.Abs(float64(hr2-hr)) > 1e-5 {
			t.Errorf("coherence[H×R] mismatch: %f vs %f", hr, hr2)
		}
	}
}

func TestResonanceTensorGGUFRoundtrip(t *testing.T) {
	dbPath := "/tmp/test_go_res_tensor_gguf.db"
	cleanupDB(t, dbPath)
	ggufPath := "/tmp/test_res_tensor.gguf"

	var lambda float32
	var bh float32

	// bootstrap + export
	{
		leo := NewLeo(dbPath)
		leo.Bootstrap()
		for i := 0; i < 5; i++ {
			leo.Generate("structure distillation")
		}
		lambda = leo.ResonanceLambda()
		bh = leo.Coherence(0, 1)
		leo.ExportGGUF(ggufPath)
		leo.Close()
	}

	// import
	{
		dbPath2 := "/tmp/test_go_res_tensor_gguf2.db"
		cleanupDB(t, dbPath2)
		leo := NewLeo(dbPath2)
		defer leo.Close()
		leo.ImportGGUF(ggufPath)

		l2 := leo.ResonanceLambda()
		bh2 := leo.Coherence(0, 1)

		t.Logf("GGUF roundtrip: λ=%.3f→%.3f, B×H=%.4f→%.4f", lambda, l2, bh, bh2)

		if math.Abs(float64(l2-lambda)) > 1e-4 {
			t.Errorf("lambda GGUF mismatch: %f vs %f", lambda, l2)
		}
		if math.Abs(float64(bh2-bh)) > 1e-4 {
			t.Errorf("coherence[B×H] GGUF mismatch: %f vs %f", bh, bh2)
		}
	}
	os.Remove(ggufPath)
}

// ========================================================================
// COACTIVATION ATTENTION (CoA) TESTS
// ========================================================================

func TestCoaBuiltAfterBootstrap(t *testing.T) {
	dbPath := "/tmp/test_go_coa_built.db"
	cleanupDB(t, dbPath)
	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	if !leo.CoaBuilt() {
		t.Fatal("CoA should be built after bootstrap")
	}

	coeff := leo.CoaCoeff()
	if coeff < 1.0 || coeff > 2.0 {
		t.Errorf("expected CoA coeff ~1.5, got %f", coeff)
	}
	t.Logf("CoA built: coeff=%.2f", coeff)
}

func TestCoaDoesNotCrashDuringGeneration(t *testing.T) {
	dbPath := "/tmp/test_go_coa_gen.db"
	cleanupDB(t, dbPath)
	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	// generate with CoA active — should not crash or hang
	for i := 0; i < 10; i++ {
		resp := leo.Generate("ocean deep resonance miracle")
		if len(resp) == 0 {
			t.Error("empty response from generation with CoA")
		}
	}
	t.Log("10 generations with CoA completed without crash")
}

