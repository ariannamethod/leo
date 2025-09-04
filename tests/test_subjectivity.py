import pytest
import math
import re

from subjectivity import Subjectivity


def test_metrics_entropy_perplexity():
    text = "Hello hello world"
    s = Subjectivity()
    metrics = s._metrics(text)

    freq = [2 / 3, 1 / 3]
    expected_entropy = -sum(p * math.log(p, 2) for p in freq)
    expected_perplexity = 2 ** expected_entropy

    assert metrics["entropy"] == pytest.approx(expected_entropy)
    assert metrics["perplexity"] == pytest.approx(expected_perplexity)
    assert metrics["resonance"] == 1.0


def test_pronoun_inversion_helpers():
    s = Subjectivity()
    assert s._should_invert("You are fine") is True
    assert not s._should_invert("What are you doing")
    assert s._invert_pronouns_text("You are nice") == "I am nice"


def _old_metrics(text: str):
    words = re.findall(r"\w+", text.lower())
    total = len(words) or 1
    freq = {w: words.count(w) / total for w in set(words)}
    entropy = -sum(p * math.log(p, 2) for p in freq.values())
    perplexity = 2 ** entropy
    resonance = sum(1 for w in words if w.isalpha()) / total
    return {"perplexity": perplexity, "entropy": entropy, "resonance": resonance}


def test_metrics_invariance():
    s = Subjectivity()
    texts = [
        "Hello hello world 123",
        "Numbers 1 2 3 and letters abc ABC",
    ]
    for text in texts:
        metrics = s._metrics(text)
        expected = _old_metrics(text)
        assert metrics["entropy"] == pytest.approx(expected["entropy"])
        assert metrics["perplexity"] == pytest.approx(expected["perplexity"])
        assert metrics["resonance"] == pytest.approx(expected["resonance"])
