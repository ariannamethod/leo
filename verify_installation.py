#!/usr/bin/env python3
"""
LEO v1.0 Installation Verification Script

Run this after installing leo to verify everything is working correctly.
"""

import sys
import importlib.util

def check_module(name):
    """Check if a module is available."""
    spec = importlib.util.find_spec(name)
    return spec is not None

def main():
    print("=" * 70)
    print("LEO v1.0 - Installation Verification")
    print("=" * 70)
    print()
    
    # Check Python version
    print("1. Checking Python version...")
    version = sys.version_info
    if version.major == 3 and version.minor >= 8:
        print(f"   ✓ Python {version.major}.{version.minor}.{version.micro} (OK)")
    else:
        print(f"   ✗ Python {version.major}.{version.minor}.{version.micro} (requires 3.8+)")
        return False
    
    # Check core dependencies
    print("\n2. Checking core dependencies...")
    deps = {
        'numpy': 'NumPy (vector operations)',
        'sentencepiece': 'SentencePiece (subword tokenization)',
        'aiofiles': 'aiofiles (async file operations)',
        'gradio': 'Gradio (web interface)',
    }
    
    all_ok = True
    for module, description in deps.items():
        if check_module(module):
            print(f"   ✓ {description}")
        else:
            print(f"   ✗ {description} - NOT FOUND")
            all_ok = False
    
    if not all_ok:
        print("\n   Install missing dependencies with:")
        print("   pip install -r requirements.txt")
        return False
    
    # Check leo module
    print("\n3. Checking leo module...")
    try:
        import leo
        print(f"   ✓ leo.py imported successfully")
    except Exception as e:
        print(f"   ✗ Failed to import leo: {e}")
        return False
    
    # Check app module
    print("\n4. Checking app.py...")
    try:
        sys.path.insert(0, '.')
        from app import init_leo
        print(f"   ✓ app.py imported successfully")
    except Exception as e:
        print(f"   ✗ Failed to import app: {e}")
        return False
    
    # Quick initialization test
    print("\n5. Testing Leo initialization...")
    try:
        field = init_leo()
        vocab_size = len(field.vocab)
        print(f"   ✓ Leo initialized (vocab: {vocab_size} tokens)")
    except Exception as e:
        print(f"   ✗ Failed to initialize Leo: {e}")
        return False
    
    print("\n" + "=" * 70)
    print("✅ ALL CHECKS PASSED - LEO is ready!")
    print("=" * 70)
    print()
    print("Usage:")
    print("  • REPL:         python leo.py")
    print("  • One-shot:     python leo.py 'What is presence?'")
    print("  • Web UI:       python app.py")
    print()
    print("dedicated to Leo 🙌")
    print()
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
