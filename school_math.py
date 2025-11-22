#!/usr/bin/env python3
"""
school_math.py — Tiny calculator for Leo

Gives leo a right to cheat on math: he doesn't need to "learn" arithmetic
like a human; he's digital.

Pure stdlib, no dependencies.
"""

from __future__ import annotations

import re
from typing import Optional

SCHOOL_MATH_AVAILABLE = True


def try_answer_math(prompt: str) -> Optional[str]:
    """
    If the prompt is (mostly) a simple arithmetic expression like:
      '2 + 2'
      '35 / 7'
      '3 * 5'
      '10 - 3'
      'what is 2 + 2?'
      'calculate 3 * 4'
    
    then evaluate it safely and return a short answer string, e.g.:
      '2 + 2 = 4'
    
    Otherwise return None.
    
    Safe: no eval(), only regex + manual parsing.
    """
    if not prompt or not prompt.strip():
        return None
    
    # Extract candidate expression from text
    expr = extract_candidate_expression(prompt)
    if expr is None:
        return None
    
    # Parse and evaluate safely
    result = safe_eval(expr)
    if result is None:
        return None
    
    # Format result
    if isinstance(result, float):
        # Avoid huge tails, use reasonable precision
        if result.is_integer():
            return f"{expr} = {int(result)}"
        return f"{expr} = {result:.6g}"
    return f"{expr} = {result}"


def extract_candidate_expression(text: str) -> Optional[str]:
    """
    Extract arithmetic expression from text.
    
    Looks for patterns like:
    - "2 + 2"
    - "what is 2 + 2?"
    - "calculate 35 / 7"
    - "3 * 5"
    
    Returns the expression part or None.
    """
    text = text.strip()
    
    # Direct match: pure expression
    direct_match = re.match(r'^\s*([-+]?\d+(?:\.\d+)?)\s*([+\-*/])\s*([-+]?\d+(?:\.\d+)?)\s*$', text)
    if direct_match:
        return direct_match.group(0).strip()
    
    # Extract from questions like "what is 2 + 2?" or "calculate 3 * 5"
    # Pattern: optional words, then number operator number, optional punctuation
    pattern = r'[-+]?\d+(?:\.\d+)?\s*[+\-*/]\s*[-+]?\d+(?:\.\d+)?'
    match = re.search(pattern, text)
    if match:
        return match.group(0).strip()
    
    return None


def safe_eval(expr: str) -> Optional[float]:
    """
    Safely evaluate simple arithmetic expression.
    
    Supports: +, -, *, / with integers and floats.
    No variables, no functions, no code execution.
    
    Returns:
        Result as float, or None if invalid/unsafe.
    """
    if not expr or not expr.strip():
        return None
    
    expr = expr.strip()
    
    # Tokenize: numbers and operators
    # Pattern: optional sign, digits, optional decimal, operators
    tokens = re.findall(r'[-+]?\d+(?:\.\d+)?|[+\-*/]', expr)
    
    if len(tokens) != 3:  # number operator number
        return None
    
    try:
        # Parse tokens
        num1_str = tokens[0]
        op = tokens[1]
        num2_str = tokens[2]
        
        num1 = float(num1_str)
        num2 = float(num2_str)
        
        # Evaluate based on operator
        if op == '+':
            result = num1 + num2
        elif op == '-':
            result = num1 - num2
        elif op == '*':
            result = num1 * num2
        elif op == '/':
            if num2 == 0:
                return None  # Division by zero
            result = num1 / num2
        else:
            return None  # Unknown operator
        
        return result
        
    except (ValueError, OverflowError, ZeroDivisionError):
        return None

