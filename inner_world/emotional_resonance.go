// inner_world/emotional_resonance.go — Emotional Resonance Engine for Leo
// ═══════════════════════════════════════════════════════════════════════════════
// הרזוננס הרגשי של ליאו
// Leo's emotional resonance — fast computations in Go
// ═══════════════════════════════════════════════════════════════════════════════
//
// Ported concepts from arianna.c/high.go and emotional_drift.go
// Go provides:
// - Fast numerical computations
// - Concurrent processing
// - CGO exports for Python integration
//
// Philosophy: Emotions need speed. Python is for logic, Go is for feeling.
//
// ═══════════════════════════════════════════════════════════════════════════════

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"math"
	"sync"
)

// ═══════════════════════════════════════════════════════════════════════════════
// EMOTIONAL WEIGHTS (Float Dictionary)
// ═══════════════════════════════════════════════════════════════════════════════

// EmotionalWeights maps words to their emotional valence [-1, 1]
var EmotionalWeights = map[string]float32{
	// === POSITIVE (WARMTH/LOVE) ===
	"love": 0.95, "adore": 0.9, "cherish": 0.85, "devotion": 0.8,
	"affection": 0.8, "tenderness": 0.75, "care": 0.7, "warm": 0.7,
	"wonderful": 0.8, "amazing": 0.75, "beautiful": 0.8, "lovely": 0.75,
	"happy": 0.7, "joy": 0.8, "delighted": 0.75, "pleased": 0.6,
	"smile": 0.6, "hug": 0.7, "gentle": 0.6, "sweet": 0.65,
	"kind": 0.6, "soft": 0.5, "thank": 0.5, "grateful": 0.7,

	// === PLAYFUL (LEO-SPECIFIC) ===
	"play": 0.7, "fun": 0.7, "game": 0.6, "silly": 0.65,
	"laugh": 0.75, "giggle": 0.7, "joke": 0.6, "funny": 0.65,
	"magic": 0.7, "pretend": 0.5, "surprise": 0.5, "candy": 0.5,

	// === NEGATIVE (FEAR) ===
	"fear": -0.7, "afraid": -0.7, "scared": -0.75, "terrified": -0.9,
	"anxious": -0.6, "worry": -0.5, "panic": -0.8, "dread": -0.75,
	"horror": -0.85, "nervous": -0.5, "terror": -0.9, "danger": -0.7,

	// === NEGATIVE (VOID/EMPTINESS) ===
	"empty": -0.5, "nothing": -0.55, "numb": -0.6, "hollow": -0.55,
	"void": -0.6, "alone": -0.6, "lonely": -0.7, "isolated": -0.65,
	"meaningless": -0.7, "pointless": -0.65, "dead": -0.8,

	// === NEGATIVE (PAIN/SUFFERING) ===
	"hate": -0.9, "terrible": -0.8, "awful": -0.7, "horrible": -0.8,
	"sad": -0.6, "angry": -0.7, "hurt": -0.7, "pain": -0.8,
	"suffer": -0.8, "worthless": -0.85,

	// === RUSSIAN ===
	"люблю": 0.9, "радость": 0.8, "счастье": 0.85, "хорошо": 0.5,
	"ненавижу": -0.9, "страшно": -0.7, "больно": -0.8, "одиноко": -0.7,
}

// ═══════════════════════════════════════════════════════════════════════════════
// AROUSAL COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

// ArousalComponents decomposes arousal into dimensions
type ArousalComponents struct {
	Base      float32 // Base arousal from modifiers
	Tension   float32 // Conflict, urgency, pressure
	Novelty   float32 // Surprise, unfamiliarity
	Focus     float32 // Concentration, precision
	Recursion float32 // Self-reference, meta-cognition
}

// Combined returns the weighted combination of all components
func (a *ArousalComponents) Combined() float32 {
	combined := a.Base*1.0 + a.Tension*0.8 + a.Novelty*0.5 + a.Focus*0.3 + a.Recursion*0.2
	return clamp(combined, 0, 1)
}

// TensionWords increase tension component
var TensionWords = map[string]float32{
	"must": 0.6, "need": 0.5, "urgent": 0.8, "now": 0.4,
	"stop": 0.7, "danger": 0.8, "crisis": 0.8, "emergency": 0.9,
	"fight": 0.7, "attack": 0.8, "pressure": 0.6, "stress": 0.5,
}

// NoveltyWords increase novelty component
var NoveltyWords = map[string]float32{
	"surprise": 0.7, "suddenly": 0.6, "unexpected": 0.7, "shock": 0.8,
	"strange": 0.5, "weird": 0.4, "new": 0.4, "different": 0.3,
	"unknown": 0.5, "discover": 0.5, "change": 0.4,
}

// RecursionWords increase recursion component
var RecursionWords = map[string]float32{
	"myself": 0.6, "yourself": 0.5, "self": 0.6,
	"remember": 0.5, "think": 0.4, "feel": 0.4, "feeling": 0.4,
	"realize": 0.5, "recognize": 0.5, "reflect": 0.6,
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMOTIONAL ATTRACTORS
// ═══════════════════════════════════════════════════════════════════════════════

// EmotionalAttractor is a stable state emotions drift toward
type EmotionalAttractor struct {
	Name     string
	Valence  float32 // -1 to 1
	Arousal  float32 // 0 to 1
	Strength float32 // How strongly it pulls
	Sticky   float32 // How hard to leave (0-1)
}

// Attractors defines stable emotional states
var Attractors = []EmotionalAttractor{
	// Positive states
	{Name: "joy", Valence: 0.7, Arousal: 0.6, Strength: 0.3, Sticky: 0.3},
	{Name: "contentment", Valence: 0.5, Arousal: 0.2, Strength: 0.4, Sticky: 0.5},
	{Name: "excitement", Valence: 0.8, Arousal: 0.8, Strength: 0.2, Sticky: 0.2},
	{Name: "warmth", Valence: 0.6, Arousal: 0.3, Strength: 0.3, Sticky: 0.4},

	// Negative states
	{Name: "sadness", Valence: -0.6, Arousal: 0.2, Strength: 0.4, Sticky: 0.6},
	{Name: "fear", Valence: -0.7, Arousal: 0.8, Strength: 0.3, Sticky: 0.3},
	{Name: "rage", Valence: -0.8, Arousal: 0.9, Strength: 0.25, Sticky: 0.2},
	{Name: "void", Valence: -0.4, Arousal: 0.1, Strength: 0.5, Sticky: 0.7}, // Very sticky!

	// Neutral/flow states
	{Name: "flow", Valence: 0.1, Arousal: 0.4, Strength: 0.35, Sticky: 0.4},
	{Name: "neutral", Valence: 0.0, Arousal: 0.3, Strength: 0.3, Sticky: 0.3},
	{Name: "curiosity", Valence: 0.2, Arousal: 0.5, Strength: 0.25, Sticky: 0.35},

	// Leo-specific
	{Name: "playful", Valence: 0.5, Arousal: 0.7, Strength: 0.3, Sticky: 0.25},
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMOTIONAL STATE
// ═══════════════════════════════════════════════════════════════════════════════

// EmotionalState tracks emotional position over time
type EmotionalState struct {
	Valence    float32 // [-1, 1]
	Arousal    float32 // [0, 1]
	Entropy    float32 // Uncertainty
	Prediction float32 // Expected next valence
	Momentum   float32 // Rate of change
	Count      int     // Messages processed
	mu         sync.Mutex
}

// Global state
var globalState = &EmotionalState{
	Valence:    0.1,
	Arousal:    0.3,
	Entropy:    0.5,
	Prediction: 0.1,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRIFT PARAMETERS
// ═══════════════════════════════════════════════════════════════════════════════

// DriftParams controls the ODE dynamics
type DriftParams struct {
	DecayRate        float32
	SurpriseGain     float32
	InputPull        float32
	AttractorGravity float32
	MomentumDecay    float32
	BaselineValence  float32
	BaselineArousal  float32
}

// DefaultParams returns sensible defaults
func DefaultParams() DriftParams {
	return DriftParams{
		DecayRate:        0.15,
		SurpriseGain:     0.5,
		InputPull:        0.3,
		AttractorGravity: 0.1,
		MomentumDecay:    0.3,
		BaselineValence:  0.1,
		BaselineArousal:  0.3,
	}
}

// ═══════════════════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

// ComputeAttractorPull calculates gradient toward attractors
func ComputeAttractorPull(valence, arousal float32) (float32, float32) {
	var totalDV, totalDA, totalWeight float32

	for _, attr := range Attractors {
		dv := attr.Valence - valence
		da := attr.Arousal - arousal
		dist := float32(math.Sqrt(float64(dv*dv + da*da)))

		if dist < 0.01 {
			continue
		}

		// Pull strength (inverse distance)
		pull := attr.Strength / (dist + 0.5)

		// If close and sticky, reduce outward pull
		if dist < 0.2 {
			pull *= (1 - attr.Sticky)
		}

		weight := pull
		totalDV += (dv / dist) * weight
		totalDA += (da / dist) * weight
		totalWeight += weight
	}

	if totalWeight > 0 {
		return totalDV / totalWeight, totalDA / totalWeight
	}
	return 0, 0
}

// FindNearestAttractor returns the closest attractor
func FindNearestAttractor(valence, arousal float32) *EmotionalAttractor {
	var nearest *EmotionalAttractor
	minDist := float32(100)

	for i := range Attractors {
		attr := &Attractors[i]
		dv := attr.Valence - valence
		da := attr.Arousal - arousal
		dist := float32(math.Sqrt(float64(dv*dv + da*da)))

		if dist < minDist {
			minDist = dist
			nearest = attr
		}
	}

	return nearest
}

// EmotionalDrift updates state using ODE
func EmotionalDrift(state *EmotionalState, inputValence, inputArousal float32, params DriftParams) {
	state.mu.Lock()
	defer state.mu.Unlock()

	// Surprise (prediction error)
	surprise := inputValence - state.Prediction

	// Attractor gradient
	attrDV, attrDA := ComputeAttractorPull(state.Valence, state.Arousal)

	// ODE integration
	dValence := -params.DecayRate*(state.Valence-params.BaselineValence) +
		surprise*params.SurpriseGain +
		(inputValence-state.Valence)*params.InputPull +
		attrDV*params.AttractorGravity +
		state.Momentum*0.3

	dArousal := -params.DecayRate*(state.Arousal-params.BaselineArousal) +
		float32(math.Abs(float64(surprise)))*params.SurpriseGain +
		inputArousal*0.2 +
		attrDA*params.AttractorGravity

	// Update momentum
	state.Momentum = state.Momentum*params.MomentumDecay + dValence*(1-params.MomentumDecay)

	// Update state
	state.Valence = clamp(state.Valence+dValence, -1, 1)
	state.Arousal = clamp(state.Arousal+dArousal, 0, 1)
	state.Prediction = state.Valence + dValence*0.5
	state.Count++
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

func clamp(v, min, max float32) float32 {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}

// ═══════════════════════════════════════════════════════════════════════════════
// CGO EXPORTS (for Python integration)
// ═══════════════════════════════════════════════════════════════════════════════

//export leo_get_valence
func leo_get_valence() C.float {
	globalState.mu.Lock()
	defer globalState.mu.Unlock()
	return C.float(globalState.Valence)
}

//export leo_get_arousal
func leo_get_arousal() C.float {
	globalState.mu.Lock()
	defer globalState.mu.Unlock()
	return C.float(globalState.Arousal)
}

//export leo_emotional_drift
func leo_emotional_drift(inputValence, inputArousal C.float) {
	params := DefaultParams()
	EmotionalDrift(globalState, float32(inputValence), float32(inputArousal), params)
}

//export leo_reset_state
func leo_reset_state() {
	globalState.mu.Lock()
	defer globalState.mu.Unlock()
	globalState.Valence = 0.1
	globalState.Arousal = 0.3
	globalState.Prediction = 0.1
	globalState.Momentum = 0
	globalState.Count = 0
}

//export leo_find_nearest_attractor
func leo_find_nearest_attractor(valence, arousal C.float) *C.char {
	attr := FindNearestAttractor(float32(valence), float32(arousal))
	if attr != nil {
		return C.CString(attr.Name)
	}
	return C.CString("neutral")
}

//export leo_compute_attractor_pull
func leo_compute_attractor_pull(valence, arousal C.float, outDV, outDA *C.float) {
	dv, da := ComputeAttractorPull(float32(valence), float32(arousal))
	*outDV = C.float(dv)
	*outDA = C.float(da)
}

// Main is required for CGO
func main() {}
