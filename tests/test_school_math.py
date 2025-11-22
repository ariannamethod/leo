#!/usr/bin/env python3
"""Tests for school_math module."""

import unittest

try:
    from school_math import try_answer_math, extract_candidate_expression, safe_eval, SCHOOL_MATH_AVAILABLE
    MATH_AVAILABLE = True
except ImportError:
    MATH_AVAILABLE = False


class TestSchoolMath(unittest.TestCase):
    """Test school_math module."""

    def setUp(self):
        if not MATH_AVAILABLE:
            self.skipTest("school_math.py not available")

    def test_simple_addition(self):
        """Test simple addition."""
        result = try_answer_math("2 + 2")
        self.assertEqual(result, "2 + 2 = 4")

    def test_simple_subtraction(self):
        """Test simple subtraction."""
        result = try_answer_math("10 - 3")
        self.assertEqual(result, "10 - 3 = 7")

    def test_simple_multiplication(self):
        """Test simple multiplication."""
        result = try_answer_math("3 * 5")
        self.assertEqual(result, "3 * 5 = 15")

    def test_simple_division(self):
        """Test simple division."""
        result = try_answer_math("35 / 7")
        self.assertEqual(result, "35 / 7 = 5")

    def test_question_format(self):
        """Test math in question format."""
        result = try_answer_math("what is 2 + 2?")
        self.assertEqual(result, "2 + 2 = 4")

    def test_float_result(self):
        """Test float result formatting."""
        result = try_answer_math("7 / 3")
        self.assertIsNotNone(result)
        self.assertIn("=", result)
        # Should contain approximate result
        self.assertIn("2.33", result)  # 7/3 ≈ 2.333...

    def test_division_by_zero(self):
        """Test division by zero returns None."""
        result = try_answer_math("5 / 0")
        self.assertIsNone(result)

    def test_non_math_text(self):
        """Test non-math text returns None."""
        result = try_answer_math("hello world")
        self.assertIsNone(result)

    def test_extract_candidate_expression(self):
        """Test expression extraction."""
        from school_math import extract_candidate_expression
        
        # Direct expression
        expr = extract_candidate_expression("2 + 2")
        self.assertEqual(expr, "2 + 2")
        
        # From question
        expr = extract_candidate_expression("what is 35 / 7?")
        self.assertEqual(expr, "35 / 7")
        
        # Non-math
        expr = extract_candidate_expression("hello")
        self.assertIsNone(expr)

    def test_safe_eval(self):
        """Test safe evaluation."""
        from school_math import safe_eval
        
        self.assertEqual(safe_eval("2 + 2"), 4.0)
        self.assertEqual(safe_eval("10 - 3"), 7.0)
        self.assertEqual(safe_eval("3 * 5"), 15.0)
        self.assertEqual(safe_eval("35 / 7"), 5.0)
        self.assertIsNone(safe_eval("5 / 0"))  # Division by zero
        self.assertIsNone(safe_eval("invalid"))


if __name__ == "__main__":
    unittest.main()

