package main

import (
	"math"
	"testing"
)

// ========================================================================
// EPISODIC MEMORY TESTS
// ========================================================================

func TestCosineDistance(t *testing.T) {
	// Identical vectors → distance 0
	a := []float64{1, 2, 3}
	d := cosineDistance(a, a)
	if math.Abs(d) > 0.001 {
		t.Errorf("identical vectors should have distance ~0, got %.4f", d)
	}

	// Orthogonal vectors → distance 1
	b := []float64{1, 0, 0}
	c := []float64{0, 1, 0}
	d = cosineDistance(b, c)
	if math.Abs(d-1.0) > 0.001 {
		t.Errorf("orthogonal vectors should have distance ~1, got %.4f", d)
	}

	// Opposite vectors → distance 2
	e := []float64{1, 0, 0}
	f := []float64{-1, 0, 0}
	d = cosineDistance(e, f)
	if math.Abs(d-2.0) > 0.001 {
		t.Errorf("opposite vectors should have distance ~2, got %.4f", d)
	}

	// Empty → distance 1
	d = cosineDistance(nil, nil)
	if d != 1.0 {
		t.Errorf("empty vectors should have distance 1.0, got %.4f", d)
	}

	// Zero vector → distance 1
	d = cosineDistance([]float64{0, 0, 0}, []float64{1, 2, 3})
	if d != 1.0 {
		t.Errorf("zero vector should have distance 1.0, got %.4f", d)
	}
}

func TestCharEntropy(t *testing.T) {
	// Empty
	if charEntropy("") != 0.0 {
		t.Error("empty string should have 0 entropy")
	}

	// Single char repeated
	e := charEntropy("aaaaaaa")
	if e != 0.0 {
		t.Errorf("single char repeated should have 0 entropy, got %.4f", e)
	}

	// English text should have entropy ~4.0-4.5
	e = charEntropy("the quick brown fox jumps over the lazy dog")
	if e < 3.0 || e > 5.5 {
		t.Errorf("English text entropy should be ~3.5-4.5, got %.4f", e)
	}
}

func TestRepetitionRate(t *testing.T) {
	// No repetition
	r := repetitionRate("hello world foo bar")
	if r != 0.0 {
		t.Errorf("no repetition should be 0.0, got %.4f", r)
	}

	// All same
	r = repetitionRate("the the the the")
	if r != 1.0 {
		t.Errorf("all same should be 1.0, got %.4f", r)
	}

	// Some repetition
	r = repetitionRate("hello hello world world")
	if math.Abs(r-2.0/3.0) > 0.01 {
		t.Errorf("expected ~0.667, got %.4f", r)
	}

	// Single word
	r = repetitionRate("hello")
	if r != 0.0 {
		t.Errorf("single word should be 0.0, got %.4f", r)
	}
}

func TestEpisodeStore(t *testing.T) {
	store := newEpisodeStore(10)

	// Store some episodes
	for i := 0; i < 5; i++ {
		m := EpisodeMetrics{
			Entropy:   float64(i) * 0.2,
			Novelty:   0.8,
			Quality:   float64(i) * 0.15,
			WordCount: 10 + i,
		}
		store.store("prompt", "reply", m)
	}

	if len(store.episodes) != 5 {
		t.Fatalf("expected 5 episodes, got %d", len(store.episodes))
	}

	// Query similar — should return results sorted by distance
	query := EpisodeMetrics{
		Entropy:   0.4,
		Novelty:   0.8,
		Quality:   0.3,
		WordCount: 12,
	}
	similar := store.querySimilar(query, 3)
	if len(similar) != 3 {
		t.Fatalf("expected 3 similar, got %d", len(similar))
	}

	// Results should be sorted by distance (ascending)
	for i := 1; i < len(similar); i++ {
		if similar[i].Distance < similar[i-1].Distance {
			t.Errorf("results not sorted: [%d]=%.4f < [%d]=%.4f",
				i, similar[i].Distance, i-1, similar[i-1].Distance)
		}
	}
}

func TestEpisodeStoreRingBuffer(t *testing.T) {
	store := newEpisodeStore(3) // small buffer

	// Store 5 episodes — oldest 2 should be evicted
	for i := 0; i < 5; i++ {
		m := EpisodeMetrics{Step: i}
		store.store("p", "r", m)
	}

	if len(store.episodes) != 3 {
		t.Fatalf("ring buffer should hold max 3, got %d", len(store.episodes))
	}

	// Oldest should be step=2 (0 and 1 evicted)
	if store.episodes[0].metrics.Step != 2 {
		t.Errorf("oldest episode should be step=2, got %d", store.episodes[0].metrics.Step)
	}
}

func TestEpisodeSummary(t *testing.T) {
	store := newEpisodeStore(100)

	// Empty store
	summary := store.getSummary(EpisodeMetrics{}, 5)
	if summary.Count != 0 || summary.MeanDist != 1.0 {
		t.Errorf("empty summary: count=%d meanDist=%.2f", summary.Count, summary.MeanDist)
	}

	// Add episodes with known quality
	for i := 0; i < 10; i++ {
		m := EpisodeMetrics{
			Entropy: 0.5,
			Novelty: 0.7,
			Quality: float64(i) * 0.1, // 0.0 to 0.9
		}
		store.store("p", "r", m)
	}

	query := EpisodeMetrics{Entropy: 0.5, Novelty: 0.7, Quality: 0.5}
	summary = store.getSummary(query, 5)

	if summary.Count != 5 {
		t.Errorf("expected 5 similar, got %d", summary.Count)
	}
	if summary.MaxQuality <= 0 {
		t.Error("max quality should be > 0")
	}
	if summary.AvgQuality <= 0 {
		t.Error("avg quality should be > 0")
	}
}

func TestComputeEpisodeMetrics(t *testing.T) {
	dbPath := "/tmp/test_go_episode_metrics.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	response := leo.Generate("hello Leo")
	metrics := computeEpisodeMetrics(leo, "hello Leo", response)

	// Entropy should be > 0 for real text
	if metrics.Entropy <= 0 {
		t.Errorf("entropy should be > 0, got %.4f", metrics.Entropy)
	}

	// Novelty should be > 0 (at least some unique words)
	if metrics.Novelty <= 0 {
		t.Errorf("novelty should be > 0, got %.4f", metrics.Novelty)
	}

	// Quality should be computed by metaScore
	if metrics.Quality <= 0 {
		t.Errorf("quality should be > 0, got %.4f", metrics.Quality)
	}

	// WordCount should match
	if metrics.WordCount < 2 {
		t.Errorf("word count should be >= 2, got %d", metrics.WordCount)
	}

	// Step should be > 0 after bootstrap
	if metrics.Step <= 0 {
		t.Errorf("step should be > 0, got %d", metrics.Step)
	}

	t.Logf("metrics: entropy=%.3f novelty=%.3f arousal=%.3f quality=%.3f words=%d",
		metrics.Entropy, metrics.Novelty, metrics.Arousal, metrics.Quality, metrics.WordCount)
}

func TestEpisodesIntegration(t *testing.T) {
	dbPath := "/tmp/test_go_episodes_integ.db"
	cleanupDB(t, dbPath)

	leo := NewLeo(dbPath)
	defer leo.Close()
	leo.Bootstrap()

	store := newEpisodeStore(100)

	// Simulate 10 conversations
	prompts := []string{
		"hello Leo", "what is love", "tell me about stars",
		"who are you", "do you dream", "what is music",
		"I feel something", "the silence speaks",
		"tell me about resonance", "what is consciousness",
	}

	for _, prompt := range prompts {
		response := leo.Generate(prompt)
		metrics := computeEpisodeMetrics(leo, prompt, response)
		store.store(prompt, response, metrics)
	}

	if len(store.episodes) != 10 {
		t.Fatalf("expected 10 episodes, got %d", len(store.episodes))
	}

	// Query for something similar to a resonance question
	resonanceMetrics := computeEpisodeMetrics(leo, "resonance field", leo.Generate("resonance field"))
	similar := store.querySimilar(resonanceMetrics, 3)

	if len(similar) != 3 {
		t.Fatalf("expected 3 similar, got %d", len(similar))
	}

	// All distances should be in [0, 2] (cosine distance range)
	for _, ep := range similar {
		if ep.Distance < 0 || ep.Distance > 2.0 {
			t.Errorf("distance out of range: %.4f", ep.Distance)
		}
	}

	t.Logf("top 3 similar to 'resonance field':")
	for i, ep := range similar {
		t.Logf("  %d. dist=%.3f quality=%.2f prompt=%q", i+1, ep.Distance, ep.Quality, ep.Prompt)
	}
}
