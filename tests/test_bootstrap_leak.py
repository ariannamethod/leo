#!/usr/bin/env python3
"""
Regression tests for bootstrap leak detection.

After adding meta-bootstraps (module docstrings), Leo sometimes "spoke in bootstrap"
instead of natural replies. This test suite ensures internal meta-text stays internal.
"""

import unittest
import tempfile
import os
from pathlib import Path

try:
    from leo import LeoField, _is_bootstrap_leak
    LEO_AVAILABLE = True
except ImportError:
    LEO_AVAILABLE = False


@unittest.skipIf(not LEO_AVAILABLE, "leo not available")
class TestBootstrapLeakDetection(unittest.TestCase):
    """Test _is_bootstrap_leak() helper function."""

    def test_normal_reply_not_leak(self):
        """Normal Leo replies should not be flagged as leaks."""
        normal_replies = [
            "Hello! How are you?",
            "I am Leo, a language organism.",
            "Presence is more important than intelligence.",
            "Let me think about that.",
            "Resonance happens when patterns align.",
        ]
        for reply in normal_replies:
            self.assertFalse(_is_bootstrap_leak(reply), f"False positive for: {reply}")

    def test_bootstrap_phrase_detected(self):
        """Direct bootstrap phrases should be detected."""
        leak_replies = [
            "These conversations are private never shown to user.",
            "Active observation with influence phase mathbrain watches.",
            "— GAME — conversational rhythm awareness or.",
            "Imaginary friend layer for Leo talks about origin.",
        ]
        for reply in leak_replies:
            self.assertTrue(_is_bootstrap_leak(reply), f"Missed leak: {reply}")

    def test_module_file_references_detected(self):
        """File references like 'game.py' should be detected."""
        leak_replies = [
            "The game.py module handles sequences.",
            "See metaleo.py for inner voice routing.",
            "mathbrain.py: body awareness layer",
        ]
        for reply in leak_replies:
            self.assertTrue(_is_bootstrap_leak(reply), f"Missed file ref: {reply}")

    def test_readme_style_markers_detected(self):
        """README-style section markers should be detected."""
        leak_replies = [
            "— MATHBRAIN — knows how to count",
            "— DREAM — imaginary friend layer",
            "— SCHOOL — School of Forms",
        ]
        for reply in leak_replies:
            self.assertTrue(_is_bootstrap_leak(reply), f"Missed marker: {reply}")

    def test_high_module_density_detected(self):
        """Replies with too many module keywords should be flagged."""
        # Many module keywords in short text
        leak_reply = "mathbrain metaleo game dream school santa"
        self.assertTrue(_is_bootstrap_leak(leak_reply))

        # Same keywords but in longer natural text (OK)
        natural_reply = (
            "I have several layers like mathbrain and metaleo, "
            "plus game, dream, and school modules, and even santa for memory. "
            "But I use them naturally, not just listing names. "
            "Each one helps me understand different aspects of language and presence."
        )
        # This should pass (density < 15%)
        self.assertFalse(_is_bootstrap_leak(natural_reply))

    def test_empty_or_short_text_not_leak(self):
        """Empty or very short text should not be flagged."""
        self.assertFalse(_is_bootstrap_leak(""))
        self.assertFalse(_is_bootstrap_leak("   "))
        self.assertFalse(_is_bootstrap_leak("Yes"))


@unittest.skipIf(not LEO_AVAILABLE, "leo not available")
class TestBootstrapLeakIntegration(unittest.TestCase):
    """Integration tests: ensure Leo doesn't leak bootstrap in real replies."""

    def setUp(self):
        """Create temporary Leo instance."""
        from leo import init_db

        # Create in-memory DB (like other tests do)
        self.conn = init_db()
        # Create LeoField
        self.leo = LeoField(self.conn)

    def tearDown(self):
        """Clean up connection."""
        self.conn.close()

    def test_hello_greeting_no_leak(self):
        """Simple greeting should not trigger bootstrap leak."""
        prompts = [
            "Hello Leo, how are you feeling today?",
            "Hi there!",
            "Good morning Leo",
        ]
        for prompt in prompts:
            reply = self.leo.reply(prompt, max_tokens=40)
            self.assertFalse(
                _is_bootstrap_leak(reply),
                f"Bootstrap leak in reply to '{prompt}': {reply}"
            )

    def test_school_question_no_leak(self):
        """Asking about School of Forms should not leak internal docs."""
        prompts = [
            "What is the School of Forms?",
            "Tell me about school",
        ]
        for prompt in prompts:
            reply = self.leo.reply(prompt, max_tokens=40)
            self.assertFalse(
                _is_bootstrap_leak(reply),
                f"Bootstrap leak in reply to '{prompt}': {reply}"
            )
            # Also check specific forbidden phrases
            reply_lower = reply.lower()
            self.assertNotIn("private never shown to user", reply_lower)
            self.assertNotIn("— game —", reply_lower)
            self.assertNotIn("— school —", reply_lower)

    def test_meta_question_no_leak(self):
        """Questions about Leo's architecture should not leak raw bootstrap."""
        prompts = [
            "How do you work?",
            "What are your internal layers?",
            "Tell me about your modules",
        ]
        for prompt in prompts:
            reply = self.leo.reply(prompt, max_tokens=40)
            self.assertFalse(
                _is_bootstrap_leak(reply),
                f"Bootstrap leak in reply to '{prompt}': {reply}"
            )

    def test_multiple_turns_no_leak(self):
        """Multiple conversation turns should not accumulate leaks."""
        conversation = [
            "Hello Leo",
            "What is resonance?",
            "Tell me about language",
            "How do you feel?",
        ]
        for prompt in conversation:
            reply = self.leo.reply(prompt, max_tokens=40)
            self.assertFalse(
                _is_bootstrap_leak(reply),
                f"Bootstrap leak after multiple turns in reply to '{prompt}': {reply}"
            )

    def test_fallback_replies_are_safe(self):
        """Fallback replies should be simple and safe."""
        # Manually test with a reply that would trigger leak detection
        # (not calling leo.reply since we can't force a leak easily)
        safe_fallbacks = ["Yes.", "I see.", "Listening.", "Continue.", "Go on.", "Understood."]
        for fallback in safe_fallbacks:
            self.assertFalse(_is_bootstrap_leak(fallback))


if __name__ == '__main__':
    unittest.main()
