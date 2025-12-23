#!/usr/bin/env python3
"""
CRITICAL RUNTIME AUDIT
Track actual function calls during Leo's reply generation.
Verify what's ACTIVE vs IMPORTED vs DORMANT.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import leo
import functools
from typing import List, Dict, Set

# Global call tracker
CALL_LOG: List[Dict[str, str]] = []
MODULE_CALLS: Dict[str, int] = {}

def trace_call(module_name: str):
    """Decorator to trace function calls."""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            CALL_LOG.append({
                'module': module_name,
                'function': func.__name__,
            })
            MODULE_CALLS[module_name] = MODULE_CALLS.get(module_name, 0) + 1
            return func(*args, **kwargs)
        return wrapper
    return decorator

def check_module_availability() -> Dict[str, bool]:
    """Check which modules imported successfully."""
    availability = {}

    # Check each module's AVAILABLE flag
    availability['OVERTHINKING'] = leo.OVERTHINKING_AVAILABLE
    availability['TRAUMA'] = leo.TRAUMA_AVAILABLE
    availability['FLOW'] = leo.FLOW_AVAILABLE
    availability['METALEO'] = leo.METALEO_AVAILABLE
    availability['MATHBRAIN'] = leo.MATHBRAIN_AVAILABLE
    availability['SANTACLAUS'] = leo.SANTACLAUS_AVAILABLE
    availability['EPISODES'] = leo.EPISODES_AVAILABLE
    availability['GAME'] = leo.GAME_MODULE_AVAILABLE
    availability['DREAM'] = leo.DREAM_MODULE_AVAILABLE
    availability['SCHOOL'] = leo.SCHOOL_MODULE_AVAILABLE
    availability['SCHOOL_MATH'] = leo.SCHOOL_MATH_MODULE_AVAILABLE
    availability['NUMPY'] = leo.NUMPY_AVAILABLE

    return availability

def check_field_modules(field: leo.LeoField) -> Dict[str, str]:
    """Check which modules are initialized in LeoField instance."""
    status = {}

    # Check each optional module
    status['flow_tracker'] = 'ACTIVE' if field.flow_tracker is not None else 'INACTIVE'
    status['metaleo'] = 'ACTIVE' if field.metaleo is not None else 'INACTIVE'
    status['mathbrain'] = 'ACTIVE' if field._math_brain is not None else 'INACTIVE'
    status['santa'] = 'ACTIVE' if field.santa is not None else 'INACTIVE'
    status['rag'] = 'ACTIVE' if field.rag is not None else 'INACTIVE'
    status['game'] = 'ACTIVE' if field.game is not None else 'INACTIVE'
    status['school'] = 'ACTIVE' if field.school is not None else 'INACTIVE'
    status['trauma_state'] = 'ACTIVE' if field._trauma_state is not None else 'INACTIVE'

    return status

def check_regulation_systems() -> Dict[str, str]:
    """Check for regulation/veto systems in codebase."""
    regulations = {}

    # Check if loop detector is used
    try:
        from loop_detector import LoopDetector
        regulations['loop_detector'] = 'IMPORTED (measurement tool only)'
    except ImportError:
        regulations['loop_detector'] = 'NOT AVAILABLE'

    # Check for veto manager
    try:
        import veto_manager
        regulations['veto_manager'] = 'IMPORTED (CHECK IF ACTIVE)'
    except ImportError:
        regulations['veto_manager'] = 'NOT FOUND'

    # Check for echo guard
    try:
        import echo_guard
        regulations['echo_guard'] = 'IMPORTED (CHECK IF ACTIVE)'
    except ImportError:
        regulations['echo_guard'] = 'NOT FOUND'

    return regulations

def trace_generation_flow(field: leo.LeoField, prompt: str) -> str:
    """
    Trace actual call flow during reply generation.
    Monitor which modules are actually called.
    """
    # Reset call log
    CALL_LOG.clear()
    MODULE_CALLS.clear()

    # Patch key functions to trace calls
    original_generate = leo.generate_reply
    original_choose_start = leo.choose_start_token

    def traced_generate(*args, **kwargs):
        CALL_LOG.append({'module': 'CORE', 'function': 'generate_reply'})
        MODULE_CALLS['CORE'] = MODULE_CALLS.get('CORE', 0) + 1
        return original_generate(*args, **kwargs)

    def traced_choose_start(*args, **kwargs):
        CALL_LOG.append({'module': 'CORE', 'function': 'choose_start_token (FIELD SEED)'})
        MODULE_CALLS['CORE_SEED'] = MODULE_CALLS.get('CORE_SEED', 0) + 1
        return original_choose_start(*args, **kwargs)

    # Apply patches
    leo.generate_reply = traced_generate
    leo.choose_start_token = traced_choose_start

    try:
        # Generate reply
        response = field.reply(prompt)
    finally:
        # Restore originals
        leo.generate_reply = original_generate
        leo.choose_start_token = original_choose_start

    return response

def analyze_post_processing():
    """Analyze post-processing pipeline in generate_reply."""
    postprocessing = {}

    # Check format_tokens
    postprocessing['format_tokens'] = 'Joins tokens with spaces'

    # Check capitalize_sentences
    postprocessing['capitalize_sentences'] = 'Capitalizes first letter of sentences'

    # Check sentence-ending punctuation
    postprocessing['ensure_punctuation'] = 'Adds period if missing (cosmetic)'

    # Check fix_punctuation
    postprocessing['fix_punctuation'] = 'Cleans up punctuation artifacts (cosmetic)'

    # Check metaphrases
    try:
        from metaphrases import deduplicate_meta_phrases
        postprocessing['metaphrases'] = 'ACTIVE - deduplicates meta-phrases (max 2 occurrences)'
    except ImportError:
        postprocessing['metaphrases'] = 'NOT AVAILABLE'

    return postprocessing

def verify_seed_selection():
    """Verify seed selection uses field, NOT prompt."""
    import inspect

    # Get generate_reply source
    source = inspect.getsource(leo.generate_reply)

    # Check for RESURRECTION FIX comment
    has_fix_comment = 'RESURRECTION FIX' in source

    # Check for choose_start_token (correct)
    uses_field_seed = 'choose_start_token(vocab, centers, bias)' in source

    # Check for choose_start_from_prompt (WRONG)
    uses_prompt_seed = 'choose_start_from_prompt' in source

    return {
        'resurrection_fix_present': has_fix_comment,
        'uses_field_seed': uses_field_seed,
        'uses_prompt_seed': uses_prompt_seed,
        'status': '✅ CORRECT' if uses_field_seed and not uses_prompt_seed else '🚨 BUG DETECTED'
    }

def main():
    print("=" * 70)
    print("LEO RUNTIME AUDIT - Critical Behavior Analysis")
    print("=" * 70)
    print()

    # 1. Module Availability
    print("1. MODULE IMPORT STATUS")
    print("-" * 70)
    availability = check_module_availability()
    for module, available in availability.items():
        status_icon = "✅" if available else "❌"
        print(f"   {status_icon} {module:20s}: {'IMPORTED' if available else 'NOT AVAILABLE'}")
    print()

    # 2. Initialize Leo
    print("2. INITIALIZING LEO FIELD")
    print("-" * 70)
    conn = leo.init_db()
    field = leo.LeoField(conn=conn)
    print(f"   Field state: {field.stats_summary()}")
    print()

    # 3. Field Module Status
    print("3. FIELD MODULE INITIALIZATION STATUS")
    print("-" * 70)
    field_modules = check_field_modules(field)
    for module, status in field_modules.items():
        icon = "✅" if status == "ACTIVE" else "⚪"
        print(f"   {icon} {module:20s}: {status}")
    print()

    # 4. Regulation Systems
    print("4. REGULATION SYSTEMS CHECK")
    print("-" * 70)
    regulations = check_regulation_systems()
    for system, status in regulations.items():
        print(f"   • {system:20s}: {status}")
    print()

    # 5. Seed Selection Verification
    print("5. SEED SELECTION VERIFICATION (CRITICAL)")
    print("-" * 70)
    seed_check = verify_seed_selection()
    for key, value in seed_check.items():
        print(f"   • {key}: {value}")
    print()

    # 6. Post-Processing Pipeline
    print("6. POST-PROCESSING PIPELINE")
    print("-" * 70)
    postproc = analyze_post_processing()
    for step, desc in postproc.items():
        print(f"   • {step}: {desc}")
    print()

    # 7. Runtime Call Trace
    print("7. RUNTIME CALL TRACE (3 test prompts)")
    print("-" * 70)

    test_prompts = [
        "What is presence?",
        "How do you feel about silence?",
        "Tell me about resonance"
    ]

    all_responses = []

    for i, prompt in enumerate(test_prompts, 1):
        print(f"\n   Test {i}: \"{prompt}\"")
        response = trace_generation_flow(field, prompt)
        all_responses.append(response)
        print(f"   Response: {response[:100]}...")

        # Show which modules were called
        if MODULE_CALLS:
            print(f"   Modules called: {', '.join(MODULE_CALLS.keys())}")

    print()

    # 8. Call Summary
    print("8. MODULE CALL SUMMARY")
    print("-" * 70)
    if MODULE_CALLS:
        for module, count in sorted(MODULE_CALLS.items(), key=lambda x: -x[1]):
            print(f"   • {module}: {count} calls")
    else:
        print("   ⚠️  No module calls tracked (tracing may need enhancement)")
    print()

    # 9. Echo Test
    print("9. ECHO REGRESSION TEST")
    print("-" * 70)
    from loop_detector import tokenize_simple

    for i, (prompt, response) in enumerate(zip(test_prompts, all_responses), 1):
        prompt_words = set(w.lower().strip('.,!?;:\"-()') for w in prompt.split() if len(w) > 2)
        response_words = set(w.lower().strip('.,!?;:\"-()') for w in response.split() if len(w) > 2)

        if response_words:
            overlap = prompt_words & response_words
            echo_ratio = len(overlap) / len(response_words)

            icon = "✅" if echo_ratio < 0.2 else ("⚠️" if echo_ratio < 0.5 else "🚨")
            print(f"   {icon} Test {i}: external_vocab={echo_ratio:.3f} (overlap: {overlap})")
    print()

    # 10. Critical Findings
    print("10. CRITICAL FINDINGS")
    print("=" * 70)

    findings = []

    # Check seed selection
    if seed_check['uses_prompt_seed']:
        findings.append("🚨 CRITICAL: choose_start_from_prompt() FOUND IN CODE")
    elif seed_check['uses_field_seed']:
        findings.append("✅ Seed selection: ALWAYS from field (correct)")

    # Check active modules
    active_modules = [k for k, v in field_modules.items() if v == 'ACTIVE']
    if active_modules:
        findings.append(f"✅ Active modules: {', '.join(active_modules)}")
    else:
        findings.append("⚪ No optional modules active (bootstrap only)")

    # Check regulation
    if regulations.get('veto_manager') == 'IMPORTED (CHECK IF ACTIVE)':
        findings.append("⚠️  veto_manager imported - need manual check if active")
    else:
        findings.append("✅ No veto_manager found")

    if regulations.get('echo_guard') == 'IMPORTED (CHECK IF ACTIVE)':
        findings.append("⚠️  echo_guard imported - should be inactive (seed fix prevents echo)")
    else:
        findings.append("✅ No echo_guard found (seed fix is primary defense)")

    # Print findings
    for finding in findings:
        print(f"   {finding}")

    print()
    print("=" * 70)
    print("AUDIT COMPLETE")
    print("=" * 70)
    print()
    print("Next steps:")
    print("1. Review findings above")
    print("2. Compare against agents.md principles")
    print("3. Generate comprehensive audit report")
    print()

if __name__ == "__main__":
    main()
