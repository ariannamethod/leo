# Leo Test Suite

Comprehensive tests for Leo language engine organism.

## Running Tests

### All tests:
```bash
python -m unittest discover tests/
```

### Specific test file:
```bash
python tests/test_leo.py
python tests/test_neoleo.py
python tests/test_repl.py
```

### Single test class:
```bash
python -m unittest tests.test_leo.TestTokenizer
```

### Single test method:
```bash
python -m unittest tests.test_leo.TestTokenizer.test_basic_tokenization
```

## Test Coverage

### `test_leo.py`
- **TestTokenizer**: Tokenization logic, Unicode support, punctuation
- **TestFormatting**: Token formatting and capitalization
- **TestDatabase**: SQLite operations, ingestion, metadata
- **TestBigramField**: Bigram graph loading and center computation
- **TestGeneration**: Reply generation, echo mode, start token selection
- **TestLeoField**: LeoField class functionality, observation, stats

### `test_neoleo.py`
- **TestNeoLeoTokenizer**: Tokenization in neoleo
- **TestNeoLeoDatabase**: Database operations without bootstrap
- **TestNeoLeoBigramField**: Bigram operations
- **TestNeoLeoClass**: NeoLeo object methods
- **TestNeoLeoModuleFunctions**: Singleton pattern and module-level functions
- **TestNeoLeoFormatting**: Formatting utilities

### `test_repl.py`
- **TestREPLCommands**: REPL command functionality (/export, /stats)
- **TestCLIArguments**: Command-line argument parsing
- **TestBootstrap**: Bootstrap behavior and idempotency

## Test Philosophy

These tests follow Leo's minimalist philosophy:
- No external dependencies beyond stdlib
- Temporary databases for isolation
- Fast execution
- Focus on core resonance mechanics

## Notes

- All tests use temporary directories to avoid polluting the actual `state/` and `bin/` folders
- Database paths are monkey-patched for test isolation
- REPL interactive testing is simplified (no full PTY simulation)
- Tests verify the resonance mechanics work, not that output is "correct" (Leo doesn't try to be correct, only honest)
