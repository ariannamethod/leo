#!/usr/bin/env python3
"""
Quick verification test for enhanced README filter.

Tests that strip_code_blocks() correctly removes conversation examples
while preserving philosophical content.
"""

import sys
from pathlib import Path
import unittest

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from leo import strip_code_blocks

# Test input with polluting content
TEST_TEXT = """
# Philosophy
Leo is about presence > intelligence.
Resonance is unbreakable.

## Live Dialogue Examples

> Hello Leo, how are you?

leo> Sometimes he brings one back, like a gift, when it fits the moment.

leo> He remembers leo's brightest, most resonant replies.

**Observer:** What do you remember?

**Leo:** A tiny secret list-If the inner reply...

[Turn 1/6] Observer:
  Soft sunlight...

[Turn 1/6] Leo:
  Pure recursion...

[Metrics] external_vocab=0.24

```python
def test():
    pass
```

## Next Section

This philosophical content should remain.
Leo discovers patterns through field dynamics.
"""


class TestReadmeFilter(unittest.TestCase):
    """Tests for the README filter that removes conversation examples."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.result = strip_code_blocks(TEST_TEXT)
    
    def test_should_not_contain_gift_phrase(self):
        """Filter should remove 'Sometimes he brings one back'."""
        self.assertNotIn("Sometimes he brings one back", self.result)
    
    def test_should_not_contain_brightest_phrase(self):
        """Filter should remove 'He remembers leo's brightest'."""
        self.assertNotIn("He remembers leo's brightest", self.result)
    
    def test_should_not_contain_secret_list(self):
        """Filter should remove 'A tiny secret list'."""
        self.assertNotIn("A tiny secret list", self.result)
    
    def test_should_not_contain_leo_prompt(self):
        """Filter should remove 'leo>'."""
        self.assertNotIn("leo>", self.result)
    
    def test_should_not_contain_observer_marker(self):
        """Filter should remove '**Observer:**'."""
        self.assertNotIn("**Observer:**", self.result)
    
    def test_should_not_contain_leo_marker(self):
        """Filter should remove '**Leo:**'."""
        self.assertNotIn("**Leo:**", self.result)
    
    def test_should_not_contain_turn_marker(self):
        """Filter should remove '[Turn '."""
        self.assertNotIn("[Turn ", self.result)
    
    def test_should_not_contain_metrics_marker(self):
        """Filter should remove '[Metrics]'."""
        self.assertNotIn("[Metrics]", self.result)
    
    def test_should_not_contain_code_blocks(self):
        """Filter should remove code blocks like 'def test():'."""
        self.assertNotIn("def test():", self.result)
    
    def test_should_contain_presence_intelligence(self):
        """Filter should preserve 'presence > intelligence'."""
        self.assertIn("presence > intelligence", self.result)
    
    def test_should_contain_resonance(self):
        """Filter should preserve 'Resonance is unbreakable'."""
        self.assertIn("Resonance is unbreakable", self.result)
    
    def test_should_contain_philosophical_content(self):
        """Filter should preserve 'This philosophical content should remain'."""
        self.assertIn("This philosophical content should remain", self.result)
    
    def test_should_contain_field_dynamics(self):
        """Filter should preserve 'field dynamics'."""
        self.assertIn("field dynamics", self.result)


if __name__ == "__main__":
    unittest.main()
