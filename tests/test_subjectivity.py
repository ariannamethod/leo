import pytest
import math

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
