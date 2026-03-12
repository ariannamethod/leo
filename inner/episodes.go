/*
 * episodes.go — Episodic RAG for Leo's inner life
 *
 * Ported from Python's episodes.py (RAGBrain).
 *
 * Leo remembers specific moments: prompt + reply + internal state metrics.
 * This is his episodic memory — structured recall of his own experiences.
 *
 * Architecture:
 *   - Event-driven goroutine: after each conversation, store an episode
 *     with metrics (entropy, novelty, arousal, trauma, quality, tau nudge)
 *   - Similarity search: cosine distance over metric vectors
 *   - Feedback: when similar past episodes had low quality, nudge exploration
 *
 * Storage: uses Leo's existing SQLite database via C bridge.
 * Silent fail on all errors — episodes must never break Leo.
 */

package main

import (
	"fmt"
	"math"
	"strings"
)

// EpisodeMetrics captures Leo's internal state at the moment of a conversation.
type EpisodeMetrics struct {
	Entropy   float64 // character-level entropy of response (normalized)
	Novelty   float64 // unique word ratio in response
	Arousal   float64 // emotional valence magnitude
	Trauma    float64 // current trauma level
	Quality   float64 // metaScore of the response
	TauNudge  float64 // MathBrain's temperature adjustment
	VocabSize int     // vocabulary at this moment
	Step      int     // organism step count
	WordCount int     // response word count
	RepRate   float64 // repetition rate (adjacent duplicate words)
}

// episodeToVector converts metrics to a float slice for cosine distance.
func episodeToVector(m EpisodeMetrics) []float64 {
	return []float64{
		m.Entropy,
		m.Novelty,
		m.Arousal,
		m.Trauma,
		m.Quality,
		m.TauNudge + 0.5, // shift from [-0.2,0.2] to [0.3,0.7]
		math.Min(1.0, float64(m.WordCount)/30.0),
		m.RepRate,
	}
}

// cosineDistance computes 1 - cosine_similarity between two vectors.
func cosineDistance(a, b []float64) float64 {
	if len(a) != len(b) || len(a) == 0 {
		return 1.0
	}
	var dot, na, nb float64
	for i := range a {
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	}
	na = math.Sqrt(na)
	nb = math.Sqrt(nb)
	if na == 0 || nb == 0 {
		return 1.0
	}
	return 1.0 - dot/(na*nb)
}

// charEntropy computes character-level Shannon entropy of text.
func charEntropy(text string) float64 {
	if len(text) == 0 {
		return 0.0
	}
	freq := make(map[rune]int)
	total := 0
	for _, ch := range strings.ToLower(text) {
		freq[ch]++
		total++
	}
	entropy := 0.0
	for _, count := range freq {
		p := float64(count) / float64(total)
		if p > 0 {
			entropy -= p * math.Log2(p)
		}
	}
	return entropy
}

// repetitionRate computes fraction of adjacent duplicate words.
func repetitionRate(text string) float64 {
	words := strings.Fields(text)
	if len(words) < 2 {
		return 0.0
	}
	reps := 0
	for i := 1; i < len(words); i++ {
		if strings.ToLower(words[i]) == strings.ToLower(words[i-1]) {
			reps++
		}
	}
	return float64(reps) / float64(len(words)-1)
}

// computeEpisodeMetrics extracts metrics from a conversation.
func computeEpisodeMetrics(l *Leo, prompt, response string) EpisodeMetrics {
	words := strings.Fields(response)
	unique := make(map[string]bool)
	for _, w := range words {
		unique[strings.ToLower(w)] = true
	}

	novelty := 0.0
	if len(words) > 0 {
		novelty = float64(len(unique)) / float64(len(words))
	}

	arousal := math.Abs(EmotionalValence(prompt + " " + response))
	entropy := charEntropy(response)
	normEntropy := math.Min(1.0, entropy/6.6)

	return EpisodeMetrics{
		Entropy:   normEntropy,
		Novelty:   novelty,
		Arousal:   arousal,
		Trauma:    float64(l.GetTrauma()),
		Quality:   metaScore(response),
		TauNudge:  float64(l.MathBrainTauNudge()),
		VocabSize: l.Vocab(),
		Step:      l.Step(),
		WordCount: len(words),
		RepRate:   repetitionRate(response),
	}
}

// EpisodeStore holds episodes in memory (ring buffer) for similarity search.
// Uses Leo's existing SQLite for durable storage via LogEpisode().
type EpisodeStore struct {
	episodes []storedEpisode
	maxSize  int
}

type storedEpisode struct {
	prompt  string
	reply   string
	metrics EpisodeMetrics
}

// SimilarEpisode is a past episode with its distance to the query.
type SimilarEpisode struct {
	Prompt   string
	Reply    string
	Quality  float64
	Distance float64
}

// EpisodeSummary aggregates stats of similar past episodes.
type EpisodeSummary struct {
	Count      int
	AvgQuality float64
	MaxQuality float64
	MeanDist   float64
}

func newEpisodeStore(maxSize int) *EpisodeStore {
	return &EpisodeStore{
		episodes: make([]storedEpisode, 0, maxSize),
		maxSize:  maxSize,
	}
}

func (es *EpisodeStore) store(prompt, reply string, m EpisodeMetrics) {
	ep := storedEpisode{prompt: prompt, reply: reply, metrics: m}
	if len(es.episodes) >= es.maxSize {
		// Ring buffer: evict oldest
		es.episodes = append(es.episodes[1:], ep)
	} else {
		es.episodes = append(es.episodes, ep)
	}
}

func (es *EpisodeStore) querySimilar(m EpisodeMetrics, topK int) []SimilarEpisode {
	if len(es.episodes) == 0 {
		return nil
	}

	queryVec := episodeToVector(m)

	type scored struct {
		ep   SimilarEpisode
		dist float64
	}
	var results []scored

	for _, stored := range es.episodes {
		epVec := episodeToVector(stored.metrics)
		dist := cosineDistance(queryVec, epVec)
		results = append(results, scored{
			ep: SimilarEpisode{
				Prompt:   stored.prompt,
				Reply:    stored.reply,
				Quality:  stored.metrics.Quality,
				Distance: dist,
			},
			dist: dist,
		})
	}

	// Sort by distance (insertion sort, small N)
	for i := 1; i < len(results); i++ {
		for j := i; j > 0 && results[j].dist < results[j-1].dist; j-- {
			results[j], results[j-1] = results[j-1], results[j]
		}
	}

	if topK > 0 && len(results) > topK {
		results = results[:topK]
	}

	out := make([]SimilarEpisode, len(results))
	for i, r := range results {
		out[i] = r.ep
	}
	return out
}

func (es *EpisodeStore) getSummary(m EpisodeMetrics, topK int) EpisodeSummary {
	similar := es.querySimilar(m, topK)
	if len(similar) == 0 {
		return EpisodeSummary{MeanDist: 1.0}
	}

	var sumQ, maxQ, sumD float64
	for _, ep := range similar {
		sumQ += ep.Quality
		sumD += ep.Distance
		if ep.Quality > maxQ {
			maxQ = ep.Quality
		}
	}

	return EpisodeSummary{
		Count:      len(similar),
		AvgQuality: sumQ / float64(len(similar)),
		MaxQuality: maxQ,
		MeanDist:   sumD / float64(len(similar)),
	}
}

// startEpisodes is the event-driven goroutine for episodic memory.
func (l *Leo) startEpisodes() {
	events := l.subscribe("episodes")
	store := newEpisodeStore(500) // keep last 500 episodes in memory

	for {
		select {
		case <-l.stopCh:
			return

		case ev := <-events:
			// Compute metrics for this conversation
			metrics := computeEpisodeMetrics(l, ev.Prompt, ev.Response)

			// Store in memory ring buffer
			store.store(ev.Prompt, ev.Response, metrics)

			// Also log to Leo's SQLite journal (durable)
			meta := fmt.Sprintf(
				"{\"entropy\":%.3f,\"novelty\":%.3f,\"arousal\":%.3f,\"trauma\":%.3f,\"quality\":%.3f,\"tau_nudge\":%.3f,\"rep_rate\":%.3f}",
				metrics.Entropy, metrics.Novelty, metrics.Arousal,
				metrics.Trauma, metrics.Quality, metrics.TauNudge, metrics.RepRate)
			l.LogEpisode("episode_rag", ev.Prompt, meta)

			// Query similar past episodes
			summary := store.getSummary(metrics, 10)

			// Feedback: if similar episodes had low quality, nudge exploration
			if summary.Count >= 5 && summary.AvgQuality < 0.3 {
				currentTau := l.GetTau()
				l.SetTau(currentTau * 1.05) // 5% warmer — try something different
			}

			// Log periodically
			total := len(store.episodes)
			if total > 0 && total%25 == 0 {
				fmt.Printf("[episodes] %d stored | similar: %d, avg_quality=%.2f, mean_dist=%.2f\n",
					total, summary.Count, summary.AvgQuality, summary.MeanDist)
			}
		}
	}
}
