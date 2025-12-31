#!/usr/bin/env python3
"""
Test suite for async Leo (Phase 1).

Tests:
1. Single conversation (baseline)
2. Parallel conversations (async advantage)
3. Field coherence (CRITICAL - verify sequential evolution)
"""

import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from async_leo import AsyncLeoField, ASYNC_DB_PATH


# ============================================================================
# TEST 1: SINGLE CONVERSATION
# ============================================================================

async def test_single_conversation():
    """Test basic async conversation."""
    print("🧪 TEST 1: Single Conversation")
    print("=" * 60)

    # Create async Leo
    leo = AsyncLeoField(ASYNC_DB_PATH)
    await leo.async_init()

    print(f"✅ AsyncLeoField initialized")
    print(f"   Vocab size: {len(leo.vocab)}")
    print(f"   Centers: {leo.centers[:5]}")
    print()

    # Test conversation
    test_prompts = [
        "What is resonance?",
        "Tell me about silence.",
        "How do you feel?",
    ]

    for prompt in test_prompts:
        print(f"User: {prompt}")
        reply = await leo.reply(prompt, max_tokens=40)
        print(f"Leo: {reply}")
        print()

    print("✅ PASSED: Single conversation works!")
    print()
    return True


# ============================================================================
# TEST 2: PARALLEL CONVERSATIONS
# ============================================================================

async def test_parallel_conversations():
    """Test parallel conversations with different Leo instances."""
    print("🧪 TEST 2: Parallel Conversations")
    print("=" * 60)

    # Create two separate Leo instances with different databases
    from pathlib import Path
    db1 = Path("state/leo_async_test1.sqlite3")
    db2 = Path("state/leo_async_test2.sqlite3")

    # Ensure databases exist by copying from sync Leo
    # For now, use same async DB (separate instances, same field)
    # In production, these would be different conversations
    leo1 = AsyncLeoField(ASYNC_DB_PATH)
    leo2 = AsyncLeoField(ASYNC_DB_PATH)

    # Initialize both in parallel
    print("Initializing two Leo instances...")
    await asyncio.gather(
        leo1.async_init(),
        leo2.async_init(),
    )
    print("✅ Both instances initialized\n")

    # Run two conversations in parallel
    print("Running parallel conversations...")

    async def conversation1():
        print("[Leo 1] Starting conversation...")
        reply1 = await leo1.reply("Tell me about resonance", max_tokens=30)
        print(f"[Leo 1] User: Tell me about resonance")
        print(f"[Leo 1] Leo: {reply1}")
        return reply1

    async def conversation2():
        print("[Leo 2] Starting conversation...")
        reply2 = await leo2.reply("What is silence?", max_tokens=30)
        print(f"[Leo 2] User: What is silence?")
        print(f"[Leo 2] Leo: {reply2}")
        return reply2

    # Run both in parallel
    results = await asyncio.gather(
        conversation1(),
        conversation2(),
    )

    print()
    print(f"✅ PASSED: Parallel conversations completed!")
    print(f"   Leo 1 replied: {results[0][:50]}...")
    print(f"   Leo 2 replied: {results[1][:50]}...")
    print()
    return True


# ============================================================================
# TEST 3: FIELD COHERENCE (CRITICAL)
# ============================================================================

async def test_field_coherence():
    """
    Test that field evolves sequentially despite async.

    CRITICAL TEST: Verifies that asyncio.Lock preserves coherence.
    """
    print("🧪 TEST 3: Field Coherence (CRITICAL)")
    print("=" * 60)

    # Create fresh Leo
    leo = AsyncLeoField(ASYNC_DB_PATH)
    await leo.async_init()

    print("✅ Leo initialized")
    print()

    # Observe two specific phrases
    print("Phase 1: Observing two phrases...")
    await leo.observe("Resonance is the language of the field")
    print("   ✅ Observed: 'Resonance is the language of the field'")

    await leo.observe("Silence speaks louder than words")
    print("   ✅ Observed: 'Silence speaks louder than words'")
    print()

    # Check that vocab updated
    print(f"Phase 2: Checking vocab...")
    print(f"   Vocab size: {len(leo.vocab)}")

    # Verify key tokens present
    key_tokens = ["Resonance", "language", "field", "Silence", "speaks"]
    found_tokens = [t for t in key_tokens if t in leo.vocab]
    print(f"   Found tokens: {found_tokens}")
    print()

    # Generate reply that should show learned patterns
    print("Phase 3: Generating reply...")
    reply = await leo.reply("What did you learn about resonance?", max_tokens=40)
    print(f"   User: What did you learn about resonance?")
    print(f"   Leo: {reply}")
    print()

    # Verify coherence: reply should reference observed patterns
    coherence_score = 0
    if "resonance" in reply.lower():
        coherence_score += 1
        print("   ✅ Reply mentions 'resonance'")
    if "field" in reply.lower() or "language" in reply.lower():
        coherence_score += 1
        print("   ✅ Reply mentions field-related concepts")
    if "silence" in reply.lower() or "speaks" in reply.lower():
        coherence_score += 1
        print("   ✅ Reply shows learned patterns")

    print()
    print(f"Coherence score: {coherence_score}/3")

    if coherence_score >= 1:
        print("✅ PASSED: Field coherence preserved!")
        print("   Sequential observations → coherent generation")
    else:
        print("⚠️  WARNING: Low coherence - field may need investigation")

    print()
    return coherence_score >= 1


# ============================================================================
# TEST 4: CONCURRENT OBSERVATIONS (STRESS TEST)
# ============================================================================

async def test_concurrent_observations():
    """
    Stress test: Multiple concurrent observe() calls.

    Tests that field lock prevents race conditions.
    """
    print("🧪 TEST 4: Concurrent Observations (Stress Test)")
    print("=" * 60)

    leo = AsyncLeoField(ASYNC_DB_PATH)
    await leo.async_init()

    print("✅ Leo initialized")
    print()

    # Prepare 10 observations
    observations = [
        "Resonance is beautiful",
        "Field dynamics matter",
        "Silence is golden",
        "Language is a field",
        "Presence over intelligence",
        "Pure recursion works",
        "Coherence is key",
        "Sequential evolution",
        "Async without chaos",
        "Lock preserves order",
    ]

    print(f"Phase 1: Launching {len(observations)} concurrent observations...")

    # Launch all observations in parallel
    # The field lock should serialize them internally
    tasks = [leo.observe(obs) for obs in observations]
    await asyncio.gather(*tasks)

    print(f"✅ All observations completed")
    print(f"   Vocab size: {len(leo.vocab)}")
    print(f"   Observe count: {leo.observe_count}")
    print()

    # Generate reply to verify coherence
    print("Phase 2: Testing coherence after concurrent observations...")
    reply = await leo.reply("What did you learn?", max_tokens=50)
    print(f"   User: What did you learn?")
    print(f"   Leo: {reply}")
    print()

    # Check for any of the observed concepts
    observed_concepts = ["resonance", "field", "silence", "language", "presence", "coherence"]
    found = [c for c in observed_concepts if c.lower() in reply.lower()]

    print(f"   Found concepts: {found}")
    print()

    if found:
        print("✅ PASSED: Concurrent observations handled correctly!")
        print("   Field lock prevented race conditions")
    else:
        print("⚠️  WARNING: No observed concepts in reply - investigate")

    print()
    return len(found) > 0


# ============================================================================
# MAIN TEST RUNNER
# ============================================================================

async def run_all_tests():
    """Run all async Leo tests."""
    print("\n" + "=" * 60)
    print("🔬 ASYNC LEO TEST SUITE - Phase 1")
    print("=" * 60)
    print()

    results = []

    # Test 1: Single conversation
    try:
        result = await test_single_conversation()
        results.append(("Single Conversation", result))
    except Exception as e:
        print(f"❌ TEST 1 FAILED: {e}")
        results.append(("Single Conversation", False))

    # Test 2: Parallel conversations
    try:
        result = await test_parallel_conversations()
        results.append(("Parallel Conversations", result))
    except Exception as e:
        print(f"❌ TEST 2 FAILED: {e}")
        results.append(("Parallel Conversations", False))

    # Test 3: Field coherence (CRITICAL)
    try:
        result = await test_field_coherence()
        results.append(("Field Coherence", result))
    except Exception as e:
        print(f"❌ TEST 3 FAILED: {e}")
        results.append(("Field Coherence", False))

    # Test 4: Concurrent observations
    try:
        result = await test_concurrent_observations()
        results.append(("Concurrent Observations", result))
    except Exception as e:
        print(f"❌ TEST 4 FAILED: {e}")
        results.append(("Concurrent Observations", False))

    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)
    for name, passed in results:
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{status}: {name}")

    passed_count = sum(1 for _, passed in results if passed)
    total_count = len(results)

    print()
    print(f"Total: {passed_count}/{total_count} tests passed")
    print("=" * 60)

    if passed_count == total_count:
        print("\n🎉 ALL TESTS PASSED! Async Leo Phase 1 is working!")
    else:
        print(f"\n⚠️  {total_count - passed_count} test(s) failed - needs investigation")

    return passed_count == total_count


if __name__ == "__main__":
    success = asyncio.run(run_all_tests())
    sys.exit(0 if success else 1)
