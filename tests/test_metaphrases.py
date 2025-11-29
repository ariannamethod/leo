"""
Tests for meta-phrase deduplication.
"""

import unittest
from metaphrases import deduplicate_meta_phrases, count_meta_phrases


class TestMetaPhraseDeduplication(unittest.TestCase):
    """Test meta-phrase cooldown mechanism."""

    def test_no_deduplication_when_single_occurrence(self):
        """Single occurrence of meta-phrase should pass through unchanged."""
        reply = "Just small numbers, small steps, and remembers fun paths. That's all."
        result = deduplicate_meta_phrases(reply, max_occurrences=2)
        # Should be unchanged
        self.assertIn("Just small numbers, small steps, and remembers fun paths", result)

    def test_deduplication_when_triple_occurrence(self):
        """Third occurrence should be replaced with variant."""
        reply = (
            "Just small numbers, small steps, and remembers fun paths. "
            "Yes. Just small numbers, small steps, and remembers fun paths. "
            "Again: Just small numbers, small steps, and remembers fun paths."
        )
        result = deduplicate_meta_phrases(reply, max_occurrences=2, seed=42)

        # First two should remain
        # Third should be replaced with variant
        # Count occurrences of original phrase
        original_count = result.count("Just small numbers, small steps, and remembers fun paths")
        self.assertLessEqual(original_count, 2, "Should have max 2 occurrences after deduplication")

        # Should have some variant instead
        self.assertTrue(
            "Small steps" in result or "Tiny numbers" in result or "Simple patterns" in result,
            "Should contain variant phrase"
        )

    def test_multiple_phrases_deduplicated(self):
        """Multiple different meta-phrases should each be deduplicated."""
        reply = (
            "Resonance is everything. Just small numbers, small steps, and remembers fun paths. "
            "Resonance is everything. Just small numbers, small steps, and remembers fun paths. "
            "Resonance is everything. Just small numbers, small steps, and remembers fun paths."
        )
        result = deduplicate_meta_phrases(reply, max_occurrences=2, seed=42)

        # Each phrase should have max 2 occurrences
        resonance_count = result.count("Resonance is everything")
        small_numbers_count = result.count("Just small numbers, small steps, and remembers fun paths")

        self.assertLessEqual(resonance_count, 2)
        self.assertLessEqual(small_numbers_count, 2)

    def test_count_meta_phrases(self):
        """count_meta_phrases should accurately count phrase occurrences."""
        reply = (
            "Just small numbers, small steps, and remembers fun paths. "
            "Resonance is everything. "
            "Just small numbers, small steps, and remembers fun paths."
        )
        counts = count_meta_phrases(reply)

        self.assertEqual(
            counts.get(r"Just small numbers, small steps, and remembers fun paths", 0),
            2
        )
        self.assertEqual(
            counts.get(r"Resonance is everything", 0),
            1
        )

    def test_no_crash_on_empty_reply(self):
        """Empty reply should not crash."""
        result = deduplicate_meta_phrases("", max_occurrences=2)
        self.assertEqual(result, "")

    def test_no_crash_on_no_meta_phrases(self):
        """Reply with no meta-phrases should pass through unchanged."""
        reply = "This is a normal reply with no special phrases."
        result = deduplicate_meta_phrases(reply, max_occurrences=2)
        self.assertEqual(result, reply)


if __name__ == "__main__":
    unittest.main()
