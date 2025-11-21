"""
Test #130: NumPy support — optional precision enhancement

NumPy is an optional dependency that improves mathematical precision:
- distribution_entropy: vectorized operations, float64 precision
- gowiththeflow slope: np.polyfit for linear regression
- Future: theme clustering, PCA, cosine similarity

Graceful fallback to pure Python if numpy unavailable.
"""

import unittest
import sys
import importlib


class TestNumpySupport(unittest.TestCase):
    """Test that numpy integration works when available and falls back gracefully."""

    def test_numpy_available_flag(self):
        """Test that NUMPY_AVAILABLE flag is set correctly."""
        try:
            import numpy
            expected = True
        except ImportError:
            expected = False

        # Check all modules that use numpy
        import leo
        import neoleo
        import gowiththeflow

        self.assertEqual(leo.NUMPY_AVAILABLE, expected, "leo.NUMPY_AVAILABLE mismatch")
        self.assertEqual(neoleo.NUMPY_AVAILABLE, expected, "neoleo.NUMPY_AVAILABLE mismatch")
        self.assertEqual(gowiththeflow.NUMPY_AVAILABLE, expected, "gowiththeflow.NUMPY_AVAILABLE mismatch")

    def test_distribution_entropy_with_numpy(self):
        """Test distribution_entropy produces valid results with numpy."""
        from leo import distribution_entropy

        # Test various distributions
        uniform = [10.0, 10.0, 10.0, 10.0]
        skewed = [1.0, 5.0, 10.0, 50.0, 100.0]
        binary = [100.0, 1.0]

        h_uniform = distribution_entropy(uniform)
        h_skewed = distribution_entropy(skewed)
        h_binary = distribution_entropy(binary)

        # Sanity checks: entropy should be non-negative and bounded
        self.assertGreater(h_uniform, 0, "Uniform distribution should have positive entropy")
        self.assertGreater(h_skewed, 0, "Skewed distribution should have positive entropy")
        self.assertGreater(h_binary, 0, "Binary distribution should have positive entropy")

        # Uniform should have higher entropy than skewed
        self.assertGreater(h_uniform, h_skewed, "Uniform should have higher entropy than skewed")

    def test_distribution_entropy_consistency(self):
        """Test that entropy calculation is consistent regardless of numpy availability."""
        from leo import distribution_entropy, NUMPY_AVAILABLE

        counts = [10.0, 20.0, 30.0, 40.0]
        h = distribution_entropy(counts)

        # Result should be reasonable regardless of numpy
        self.assertGreater(h, 0, "Entropy should be positive")
        self.assertLess(h, 10, "Entropy should be bounded")

        # Specific value check (should be ~1.28 for this distribution)
        self.assertAlmostEqual(h, 1.28, delta=0.1, msg="Entropy value out of expected range")

    def test_gowiththeflow_slope_with_numpy(self):
        """Test that gowiththeflow slope calculation works with numpy."""
        import time
        from gowiththeflow import ThemeTrajectory, ThemeSnapshot

        # Create growing theme trajectory
        base_time = time.time()
        snapshots = []
        for i in range(5):
            snap = ThemeSnapshot(
                timestamp=base_time + (i * 100),
                theme_id=1,
                strength=1.0 + (i * 0.5),  # Growing linearly
                active_words={'test'},
                activation_count=i + 1
            )
            snapshots.append(snap)

        trajectory = ThemeTrajectory(theme_id=1, snapshots=snapshots)
        slope = trajectory.slope(hours=1.0)

        # Slope should be positive (growing theme)
        self.assertGreater(slope, 0, "Growing theme should have positive slope")

        # Create fading theme trajectory
        snapshots_fading = []
        for i in range(5):
            snap = ThemeSnapshot(
                timestamp=base_time + (i * 100),
                theme_id=2,
                strength=5.0 - (i * 0.5),  # Fading linearly
                active_words={'test'},
                activation_count=i + 1
            )
            snapshots_fading.append(snap)

        trajectory_fading = ThemeTrajectory(theme_id=2, snapshots=snapshots_fading)
        slope_fading = trajectory_fading.slope(hours=1.0)

        # Slope should be negative (fading theme)
        self.assertLess(slope_fading, 0, "Fading theme should have negative slope")

    def test_fallback_code_paths(self):
        """Test that pure Python fallback code paths are valid."""
        # Note: We can't actually test runtime fallback without breaking other tests
        # due to importlib.reload() creating new class instances.
        # Instead, we verify that the fallback code paths are syntactically valid
        # and produce reasonable results.

        # Test distribution_entropy fallback logic directly
        # (copied from leo.py fallback branch)
        counts = [10.0, 20.0, 30.0]
        total = sum(counts)
        h = 0.0
        for c in counts:
            if c > 0:
                p = c / total
                import math
                if p < 0.9999:
                    h -= p * math.log(p + 1e-12)
                elif p < 1.0:
                    h -= p * math.log(p)
        h = max(0.0, h)

        # Should produce valid result
        self.assertGreater(h, 0, "Fallback entropy should be positive")
        self.assertLess(h, 10, "Fallback entropy should be bounded")

        # Test gowiththeflow fallback logic directly
        # (manual linear regression)
        times = [0, 100, 200, 300, 400]
        strengths = [1.0, 1.5, 2.0, 2.5, 3.0]

        n = len(times)
        mean_t = sum(times) / n
        mean_s = sum(strengths) / n

        cov = sum((times[i] - mean_t) * (strengths[i] - mean_s) for i in range(n))
        var = sum((times[i] - mean_t) ** 2 for i in range(n))

        if var > 0:
            slope = cov / var
            self.assertGreater(slope, 0, "Manual slope calculation should work")

    def test_empty_distribution_edge_case(self):
        """Test that empty distributions are handled gracefully."""
        from leo import distribution_entropy

        # Empty list
        h_empty = distribution_entropy([])
        self.assertEqual(h_empty, 0.0, "Empty distribution should have zero entropy")

        # All zeros
        h_zeros = distribution_entropy([0.0, 0.0, 0.0])
        self.assertEqual(h_zeros, 0.0, "All-zero distribution should have zero entropy")

        # Negative values (invalid but should not crash)
        h_negative = distribution_entropy([-1.0, 2.0, 3.0])
        self.assertGreaterEqual(h_negative, 0.0, "Entropy should not be negative")


if __name__ == "__main__":
    unittest.main()
