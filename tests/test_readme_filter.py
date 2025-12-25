#!/usr/bin/env python3
"""
Quick verification test for enhanced README filter.

Tests that strip_code_blocks() correctly removes conversation examples
while preserving philosophical content.
"""

import sys
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from leo import strip_code_blocks

# Test input with polluting content
test_text = """
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

print("=" * 70)
print("TESTING ENHANCED README FILTER")
print("=" * 70)

result = strip_code_blocks(test_text)

print("\nFILTERED OUTPUT:")
print("-" * 70)
print(result)
print("-" * 70)

# Verification checks
print("\n" + "=" * 70)
print("VERIFICATION CHECKS")
print("=" * 70)

checks = [
    ("❌ SHOULD NOT contain", [
        "Sometimes he brings one back",
        "He remembers leo's brightest",
        "A tiny secret list",
        "leo>",
        "**Observer:**",
        "**Leo:**",
        "[Turn ",
        "[Metrics]",
        "def test():",
    ]),
    ("✅ SHOULD contain", [
        "presence > intelligence",
        "Resonance is unbreakable",
        "This philosophical content should remain",
        "field dynamics",
    ]),
]

all_passed = True

for check_type, phrases in checks:
    print(f"\n{check_type}:")
    for phrase in phrases:
        present = phrase in result
        expected = (check_type == "✅ SHOULD contain")

        if present == expected:
            status = "✅ PASS"
        else:
            status = "❌ FAIL"
            all_passed = False

        presence_str = "FOUND" if present else "NOT FOUND"
        print(f"  {status} - '{phrase}' - {presence_str}")

print("\n" + "=" * 70)
if all_passed:
    print("✅ ALL CHECKS PASSED - Filter working correctly!")
    sys.exit(0)
else:
    print("❌ SOME CHECKS FAILED - Filter needs adjustment")
    sys.exit(1)
